import * as cdk from 'aws-cdk-lib';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as iot from 'aws-cdk-lib/aws-iot';
import * as location from 'aws-cdk-lib/aws-location';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import { Construct } from 'constructs';

export interface AuthStackProps extends cdk.StackProps {
  /**
   * Name of the Amazon Location Service Map. Defaults to GroupNavMap.
   */
  mapName?: string;
  /**
   * Name of the Amazon Location Service Geofence Collection. Defaults to GroupNavGeofenceCollection.
   */
  geofenceCollectionName?: string;
  /**
   * Name of the Amazon Location Service Route Calculator. Defaults to GroupNavRouteCalculator.
   */
  routeCalculatorName?: string;
  /**
   * Name of the Amazon Location Service Place Index. Defaults to GroupNavPlaceIndex.
   */
  placeIndexName?: string;
}

export class AuthStack extends cdk.Stack {
  /** Cognito User Pool for rider registration and authentication */
  public readonly userPool: cognito.UserPool;

  /** Cognito User Pool Client for mobile (Flutter) authentication */
  public readonly userPoolClient: cognito.UserPoolClient;

  /** Cognito Identity Pool issuing temporary AWS credentials to riders */
  public readonly identityPool: cognito.CfnIdentityPool;

  /** IAM Role assumed by authenticated riders */
  public readonly authenticatedRole: iam.Role;

  /** Amazon Location Service Map resource */
  public readonly map: location.CfnMap;

  /** Amazon Location Service Geofence Collection */
  public readonly geofenceCollection: location.CfnGeofenceCollection;

  /** Amazon Location Service Route Calculator */
  public readonly routeCalculator: location.CfnRouteCalculator;

  /** Amazon Location Service Place Index */
  public readonly placeIndex: location.CfnPlaceIndex;

  /** DynamoDB table storing real pack room state, rosters, and geofence config */
  public readonly packsTable: dynamodb.Table;

  constructor(scope: Construct, id: string, props?: AuthStackProps) {
    super(scope, id, props);

    const mapName = props?.mapName ?? 'GroupNavMap';
    const geofenceCollectionName = props?.geofenceCollectionName ?? 'GroupNavGeofenceCollection';
    const routeCalculatorName = props?.routeCalculatorName ?? 'GroupNavRouteCalculator';
    const placeIndexName = props?.placeIndexName ?? 'GroupNavPlaceIndex';

    // 1. Cognito User Pool (Section 3.2)
    // Manages rider identities, email verification, and secure authentication.
    this.userPool = new cognito.UserPool(this, 'UserPool', {
      userPoolName: 'GroupNav-Riders',
      selfSignUpEnabled: true,
      signInAliases: {
        email: true,
        username: false,
      },
      autoVerify: {
        email: true,
      },
      standardAttributes: {
        email: {
          required: true,
          mutable: true,
        },
        fullname: {
          required: false,
          mutable: true,
        },
      },
      passwordPolicy: {
        minLength: 8,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits: true,
        requireSymbols: false,
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      removalPolicy: cdk.RemovalPolicy.DESTROY, // Suitable for hackathon development
    });

    // 2. Cognito User Pool Client (Section 3.2)
    // Dedicated client for the mobile Flutter application.
    // generateSecret is strictly false because mobile client applications cannot securely protect a client secret.
    this.userPoolClient = new cognito.UserPoolClient(this, 'UserPoolClient', {
      userPool: this.userPool,
      userPoolClientName: 'GroupNav-MobileClient',
      generateSecret: false,
      authFlows: {
        userPassword: true,
        userSrp: true,
      },
      preventUserExistenceErrors: true,
    });

    // 3. Cognito Identity Pool (Section 3.2)
    // Exchanges Cognito ID tokens for temporary, scoped AWS IAM credentials.
    this.identityPool = new cognito.CfnIdentityPool(this, 'IdentityPool', {
      identityPoolName: 'GroupNav_IdentityPool',
      allowUnauthenticatedIdentities: false,
      cognitoIdentityProviders: [
        {
          clientId: this.userPoolClient.userPoolClientId,
          providerName: this.userPool.userPoolProviderName,
        },
      ],
    });

    // 4. Amazon Location Service Resources (Section 3.3)
    this.map = new location.CfnMap(this, 'LocationMap', {
      mapName,
      description: 'GroupNav vector map for mobile navigation display',
      configuration: {
        style: 'VectorEsriNavigation',
      },
      pricingPlan: 'RequestBasedUsage',
    });

    this.geofenceCollection = new location.CfnGeofenceCollection(this, 'GeofenceCollection', {
      collectionName: geofenceCollectionName,
      description: 'GroupNav geofence collection for pack proximity monitoring',
      pricingPlan: 'RequestBasedUsage',
    });

    this.routeCalculator = new location.CfnRouteCalculator(this, 'RouteCalculator', {
      calculatorName: routeCalculatorName,
      dataSource: 'Esri',
      description: 'GroupNav route calculator for multi-waypoint road navigation',
      pricingPlan: 'RequestBasedUsage',
    });

    this.placeIndex = new location.CfnPlaceIndex(this, 'PlaceIndex', {
      indexName: placeIndexName,
      dataSource: 'Esri',
      description: 'GroupNav place index for tactical landmark and address search',
      pricingPlan: 'RequestBasedUsage',
    });

    // 5. DynamoDB Pack Rooms Table
    // Persistent store for real convoy rooms, host assignments, geofence radius, and active member rosters
    this.packsTable = new dynamodb.Table(this, 'GroupNavPacksTable', {
      tableName: 'groupnav-packs',
      partitionKey: {
        name: 'packCode',
        type: dynamodb.AttributeType.STRING,
      },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // 6. Scoped Authenticated IAM Role (Section 3.3 & Section 5.1)
    this.authenticatedRole = new iam.Role(this, 'CognitoAuthenticatedRole', {
      roleName: 'GroupNav-Cognito-Authenticated-Role',
      description: 'Scoped IAM role for authenticated GroupNav mobile riders',
      assumedBy: new iam.FederatedPrincipal(
        'cognito-identity.amazonaws.com',
        {
          StringEquals: {
            'cognito-identity.amazonaws.com:aud': this.identityPool.ref,
          },
          'ForAnyValue:StringLike': {
            'cognito-identity.amazonaws.com:amr': 'authenticated',
          },
        },
        'sts:AssumeRoleWithWebIdentity'
      ),
    });

    // Location Service permissions
    const locationPolicy = new iam.Policy(this, 'RiderLocationPolicy', {
      policyName: 'GroupNav-Rider-Location-Access',
      statements: [
        new iam.PolicyStatement({
          sid: 'AllowGetMapTiles',
          effect: iam.Effect.ALLOW,
          actions: [
            'geo:GetMapGlyphs',
            'geo:GetMapSprites',
            'geo:GetMapStyleDescriptor',
            'geo:GetMapTile',
          ],
          resources: [this.map.attrArn],
        }),
        new iam.PolicyStatement({
          sid: 'AllowGeofenceEvaluation',
          effect: iam.Effect.ALLOW,
          actions: [
            'geo:BatchEvaluateGeofences',
            'geo:GetGeofence',
            'geo:ListGeofences',
          ],
          resources: [this.geofenceCollection.attrArn],
        }),
        new iam.PolicyStatement({
          sid: 'AllowCalculateRoute',
          effect: iam.Effect.ALLOW,
          actions: [
            'geo:CalculateRoute',
            'geo:CalculateRouteMatrix',
          ],
          resources: [this.routeCalculator.attrArn],
        }),
        new iam.PolicyStatement({
          sid: 'AllowSearchPlaceIndex',
          effect: iam.Effect.ALLOW,
          actions: [
            'geo:SearchPlaceIndexForText',
            'geo:SearchPlaceIndexForPosition',
            'geo:SearchPlaceIndexForSuggestions',
          ],
          resources: [this.placeIndex.attrArn],
        }),
      ],
    });
    this.authenticatedRole.attachInlinePolicy(locationPolicy);

    // Grant DynamoDB pack CRUD permissions to authenticated riders
    this.packsTable.grantReadWriteData(this.authenticatedRole);

    // IoT Core Pub/Sub policies
    const iotPolicy = new iam.Policy(this, 'RiderIotTelemetryPolicy', {
      policyName: 'GroupNav-Rider-IoT-Telemetry',
      statements: [
        new iam.PolicyStatement({
          sid: 'AllowIotConnect',
          effect: iam.Effect.ALLOW,
          actions: ['iot:Connect'],
          resources: [
            cdk.Fn.join('', [
              'arn:',
              cdk.Aws.PARTITION,
              ':iot:',
              cdk.Aws.REGION,
              ':',
              cdk.Aws.ACCOUNT_ID,
              ':client/*',
            ]),
          ],
        }),
        new iam.PolicyStatement({
          sid: 'AllowIotTelemetryPubSub',
          effect: iam.Effect.ALLOW,
          actions: ['iot:Publish', 'iot:Subscribe', 'iot:Receive'],
          resources: [
            cdk.Fn.join('', [
              'arn:',
              cdk.Aws.PARTITION,
              ':iot:',
              cdk.Aws.REGION,
              ':',
              cdk.Aws.ACCOUNT_ID,
              ':topic/groupnav/*',
            ]),
            cdk.Fn.join('', [
              'arn:',
              cdk.Aws.PARTITION,
              ':iot:',
              cdk.Aws.REGION,
              ':',
              cdk.Aws.ACCOUNT_ID,
              ':topicfilter/groupnav/*',
            ]),
          ],
        }),
      ],
    });
    this.authenticatedRole.attachInlinePolicy(iotPolicy);

    // IoT Core Resource Policy
    // This is required in ADDITION to the IAM role policy above.
    // For Cognito Identity Pool + IoT Core MQTT over WebSocket (SigV4), AWS IoT Core
    // checks BOTH the IAM policy on the Cognito role AND an IoT Core resource policy
    // attached to the principal. Without this, IoT Core closes the connection after
    // the MQTT CONNECT packet with no CONNACK (silent auth failure).
    const iotCorePolicy = new iot.CfnPolicy(this, 'GroupNavRiderIotCorePolicy', {
      policyName: 'GroupNav-Rider-IoT-Access',
      policyDocument: {
        Version: '2012-10-17',
        Statement: [
          {
            Effect: 'Allow',
            Action: 'iot:Connect',
            Resource: `arn:aws:iot:${cdk.Aws.REGION}:${cdk.Aws.ACCOUNT_ID}:client/*`,
          },
          {
            Effect: 'Allow',
            Action: ['iot:Publish', 'iot:Receive'],
            Resource: `arn:aws:iot:${cdk.Aws.REGION}:${cdk.Aws.ACCOUNT_ID}:topic/groupnav/*`,
          },
          {
            Effect: 'Allow',
            Action: 'iot:Subscribe',
            Resource: `arn:aws:iot:${cdk.Aws.REGION}:${cdk.Aws.ACCOUNT_ID}:topicfilter/groupnav/*`,
          },
        ],
      },
    });

    // Attach Authenticated Role to Identity Pool
    new cognito.CfnIdentityPoolRoleAttachment(this, 'IdentityPoolRoleAttachment', {
      identityPoolId: this.identityPool.ref,
      roles: {
        authenticated: this.authenticatedRole.roleArn,
      },
    });

    // 7. CloudFormation Outputs
    new cdk.CfnOutput(this, 'UserPoolId', {
      value: this.userPool.userPoolId,
      description: 'Cognito User Pool ID',
    });

    new cdk.CfnOutput(this, 'UserPoolClientId', {
      value: this.userPoolClient.userPoolClientId,
      description: 'Cognito User Pool Client ID for mobile Flutter client',
    });

    new cdk.CfnOutput(this, 'IdentityPoolId', {
      value: this.identityPool.ref,
      description: 'Cognito Identity Pool ID',
    });

    new cdk.CfnOutput(this, 'CognitoRegion', {
      value: this.region,
      description: 'AWS Region for Cognito authentication',
    });

    new cdk.CfnOutput(this, 'MapName', {
      value: this.map.mapName,
      description: 'Amazon Location Service Map Name',
    });

    new cdk.CfnOutput(this, 'MapArn', {
      value: this.map.attrArn,
      description: 'Amazon Location Service Map ARN',
    });

    new cdk.CfnOutput(this, 'GeofenceCollectionName', {
      value: this.geofenceCollection.collectionName,
      description: 'Amazon Location Service Geofence Collection Name',
    });

    new cdk.CfnOutput(this, 'GeofenceCollectionArn', {
      value: this.geofenceCollection.attrArn,
      description: 'Amazon Location Service Geofence Collection ARN',
    });

    new cdk.CfnOutput(this, 'RouteCalculatorName', {
      value: this.routeCalculator.calculatorName,
      description: 'Amazon Location Service Route Calculator Name',
    });

    new cdk.CfnOutput(this, 'RouteCalculatorArn', {
      value: this.routeCalculator.attrArn,
      description: 'Amazon Location Service Route Calculator ARN',
    });

    new cdk.CfnOutput(this, 'PlaceIndexName', {
      value: this.placeIndex.indexName,
      description: 'Amazon Location Service Place Index Name',
    });

    new cdk.CfnOutput(this, 'PlaceIndexArn', {
      value: this.placeIndex.attrArn,
      description: 'Amazon Location Service Place Index ARN',
    });

    new cdk.CfnOutput(this, 'PackTableName', {
      value: this.packsTable.tableName,
      description: 'DynamoDB table for GroupNav Pack Rooms',
    });

    new cdk.CfnOutput(this, 'AuthenticatedRoleArn', {
      value: this.authenticatedRole.roleArn,
      description: 'IAM Role ARN for authenticated riders',
    });

    // 8. Lambda Function for IoT Policy Attachment
    const attachIotPolicyHandler = new lambda.Function(this, 'AttachIotPolicyHandler', {
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset('lambda/attach-iot-policy'),
      environment: {
        IOT_POLICY_NAME: iotCorePolicy.policyName!,
      },
    });

    // Grant Lambda permissions to attach IoT policies
    attachIotPolicyHandler.addToRolePolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['iot:AttachPrincipalPolicy'],
      // AttachPrincipalPolicy resource must be the policy being attached or '*'
      resources: [
        cdk.Fn.join('', [
          'arn:', cdk.Aws.PARTITION, ':iot:', cdk.Aws.REGION, ':', cdk.Aws.ACCOUNT_ID,
          ':policy/', iotCorePolicy.policyName!
        ])
      ],
    }));

    // 9. API Gateway for IoT Policy Attachment
    const attachPolicyApi = new apigateway.RestApi(this, 'AttachPolicyApi', {
      restApiName: 'GroupNav IoT Policy API',
      description: 'API for attaching IoT Core policies to authenticated Cognito identities',
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: ['POST', 'OPTIONS'],
        allowHeaders: ['*'],
      },
    });

    const attachPolicyResource = attachPolicyApi.root.addResource('attach-policy');
    attachPolicyResource.addMethod(
      'POST',
      new apigateway.LambdaIntegration(attachIotPolicyHandler),
      {
        authorizationType: apigateway.AuthorizationType.IAM,
      }
    );

    new cdk.CfnOutput(this, 'AttachPolicyApiEndpoint', {
      value: attachPolicyApi.url,
      description: 'API Gateway Endpoint for attaching IoT Policy',
    });
  }
}
