import * as cdk from 'aws-cdk-lib';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as location from 'aws-cdk-lib/aws-location';
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

  constructor(scope: Construct, id: string, props?: AuthStackProps) {
    super(scope, id, props);

    const mapName = props?.mapName ?? 'GroupNavMap';
    const geofenceCollectionName = props?.geofenceCollectionName ?? 'GroupNavGeofenceCollection';

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

    // 4. Amazon Location Service (Section 3.3)
    // Map resource configured for vector tiles.
    this.map = new location.CfnMap(this, 'LocationMap', {
      mapName,
      description: 'GroupNav real-time navigation and rider tracking map',
      configuration: {
        style: 'VectorEsriNavigation',
      },
    });

    // Geofence Collection for rider grouping and proximity alerts.
    this.geofenceCollection = new location.CfnGeofenceCollection(this, 'GeofenceCollection', {
      collectionName: geofenceCollectionName,
      description: 'GroupNav rider group geofence collection',
    });

    // 5. Authenticated IAM Role (Sections 3.3 & 5.1)
    // Federated IAM role assumed by authenticated riders via Web Identity Federation.
    this.authenticatedRole = new iam.Role(this, 'CognitoAuthenticatedRole', {
      roleName: 'GroupNav-Cognito-Authenticated-Role',
      description: 'IAM role assumed by authenticated GroupNav mobile riders',
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

    // Scoped Location Service policy: read-only map tiles and geofence evaluation (Section 3.3).
    // Zero management or administrative permissions.
    const locationPolicy = new iam.Policy(this, 'RiderLocationPolicy', {
      policyName: 'GroupNav-Rider-Location-Access',
      statements: [
        new iam.PolicyStatement({
          sid: 'AllowReadMapTilesAndStyles',
          effect: iam.Effect.ALLOW,
          actions: [
            'geo:GetMapTile',
            'geo:GetMapSprites',
            'geo:GetMapGlyphs',
            'geo:GetMapStyleDescriptor',
          ],
          resources: [this.map.attrArn],
        }),
        new iam.PolicyStatement({
          sid: 'AllowBatchEvaluateGeofences',
          effect: iam.Effect.ALLOW,
          actions: ['geo:BatchEvaluateGeofences'],
          resources: [this.geofenceCollection.attrArn],
        }),
      ],
    });
    this.authenticatedRole.attachInlinePolicy(locationPolicy);

    // Scoped IoT Core Telemetry policy (Section 5.1):
    // Riders can ONLY connect using their own Cognito Identity ID as the MQTT client ID
    // and publish ONLY to their own private telemetry topic.
    const iotPolicy = new iam.Policy(this, 'RiderIotTelemetryPolicy', {
      policyName: 'GroupNav-Rider-IoT-Telemetry',
      statements: [
        new iam.PolicyStatement({
          sid: 'AllowIotConnectPerRider',
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
              ':client/${cognito-identity.amazonaws.com:sub}',
            ]),
          ],
        }),
        new iam.PolicyStatement({
          sid: 'AllowIotPublishPerRider',
          effect: iam.Effect.ALLOW,
          actions: ['iot:Publish'],
          resources: [
            cdk.Fn.join('', [
              'arn:',
              cdk.Aws.PARTITION,
              ':iot:',
              cdk.Aws.REGION,
              ':',
              cdk.Aws.ACCOUNT_ID,
              ':topic/groupnav/${cognito-identity.amazonaws.com:sub}/telemetry',
            ]),
          ],
        }),
      ],
    });
    this.authenticatedRole.attachInlinePolicy(iotPolicy);

    // Attach Authenticated Role to Identity Pool
    new cognito.CfnIdentityPoolRoleAttachment(this, 'IdentityPoolRoleAttachment', {
      identityPoolId: this.identityPool.ref,
      roles: {
        authenticated: this.authenticatedRole.roleArn,
      },
    });

    // 6. Decoupled CloudFormation Outputs for Flutter Client Config (Section 6)
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

    new cdk.CfnOutput(this, 'AuthenticatedRoleArn', {
      value: this.authenticatedRole.roleArn,
      description: 'IAM Role ARN for authenticated riders',
    });
  }
}
