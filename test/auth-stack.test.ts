import * as cdk from 'aws-cdk-lib';
import { Template, Match } from 'aws-cdk-lib/assertions';
import { AuthStack } from '../lib/auth-stack';

describe('AuthStack', () => {
  let app: cdk.App;
  let stack: AuthStack;
  let template: Template;

  beforeEach(() => {
    app = new cdk.App();
    stack = new AuthStack(app, 'TestAuthStack', {
      env: { account: '123456789012', region: 'ap-south-1' },
    });
    template = Template.fromStack(stack);
  });

  test('creates Cognito User Pool configured for rider self-signup with email', () => {
    template.resourceCountIs('AWS::Cognito::UserPool', 1);

    template.hasResourceProperties('AWS::Cognito::UserPool', {
      UserPoolName: 'GroupNav-Riders',
      AutoVerifiedAttributes: Match.arrayWith(['email']),
      UsernameAttributes: Match.arrayWith(['email']),
      Policies: {
        PasswordPolicy: {
          MinimumLength: 8,
          RequireLowercase: true,
          RequireNumbers: true,
          RequireUppercase: true,
          RequireSymbols: false,
        },
      },
    });
  });

  test('creates mobile User Pool Client without client secret', () => {
    template.resourceCountIs('AWS::Cognito::UserPoolClient', 1);

    template.hasResourceProperties('AWS::Cognito::UserPoolClient', {
      ClientName: 'GroupNav-MobileClient',
      GenerateSecret: false,
      ExplicitAuthFlows: Match.arrayWith([
        'ALLOW_USER_PASSWORD_AUTH',
        'ALLOW_USER_SRP_AUTH',
        'ALLOW_REFRESH_TOKEN_AUTH',
      ]),
      PreventUserExistenceErrors: 'ENABLED',
    });
  });

  test('creates Cognito Identity Pool rejecting unauthenticated identities', () => {
    template.resourceCountIs('AWS::Cognito::IdentityPool', 1);

    template.hasResourceProperties('AWS::Cognito::IdentityPool', {
      AllowUnauthenticatedIdentities: false,
      CognitoIdentityProviders: Match.arrayWith([
        Match.objectLike({
          ClientId: Match.objectLike({
            Ref: Match.stringLikeRegexp('UserPoolClient.*'),
          }),
        }),
      ]),
    });
  });

  test('creates Amazon Location Service Map and Geofence Collection', () => {
    template.resourceCountIs('AWS::Location::Map', 1);
    template.hasResourceProperties('AWS::Location::Map', {
      MapName: 'GroupNavMap',
      Configuration: {
        Style: 'VectorEsriNavigation',
      },
    });

    template.resourceCountIs('AWS::Location::GeofenceCollection', 1);
    template.hasResourceProperties('AWS::Location::GeofenceCollection', {
      CollectionName: 'GroupNavGeofenceCollection',
    });
  });

  test('creates Authenticated Role with Web Identity Federation and role attachment', () => {
    template.resourceCountIs('AWS::Cognito::IdentityPoolRoleAttachment', 1);

    template.hasResourceProperties('AWS::IAM::Role', {
      RoleName: 'GroupNav-Cognito-Authenticated-Role',
      AssumeRolePolicyDocument: {
        Statement: Match.arrayWith([
          Match.objectLike({
            Action: 'sts:AssumeRoleWithWebIdentity',
            Effect: 'Allow',
            Principal: {
              Federated: 'cognito-identity.amazonaws.com',
            },
            Condition: {
              StringEquals: {
                'cognito-identity.amazonaws.com:aud': {
                  Ref: Match.stringLikeRegexp('IdentityPool.*'),
                },
              },
              'ForAnyValue:StringLike': {
                'cognito-identity.amazonaws.com:amr': 'authenticated',
              },
            },
          }),
        ]),
      },
    });
  });

  test('attaches strictly scoped Location Service policy (read-only tiles & geofence evaluation)', () => {
    template.hasResourceProperties('AWS::IAM::Policy', {
      PolicyName: 'GroupNav-Rider-Location-Access',
      PolicyDocument: {
        Statement: Match.arrayWith([
          Match.objectLike({
            Action: [
              'geo:GetMapTile',
              'geo:GetMapSprites',
              'geo:GetMapGlyphs',
              'geo:GetMapStyleDescriptor',
            ],
            Effect: 'Allow',
            Resource: {
              'Fn::GetAtt': [Match.stringLikeRegexp('LocationMap.*'), 'Arn'],
            },
          }),
          Match.objectLike({
            Action: 'geo:BatchEvaluateGeofences',
            Effect: 'Allow',
            Resource: {
              'Fn::GetAtt': [Match.stringLikeRegexp('GeofenceCollection.*'), 'Arn'],
            },
          }),
        ]),
      },
    });
  });

  test('attaches per-rider scoped IoT telemetry policy', () => {
    template.hasResourceProperties('AWS::IAM::Policy', {
      PolicyName: 'GroupNav-Rider-IoT-Telemetry',
      PolicyDocument: {
        Statement: Match.arrayWith([
          Match.objectLike({
            Action: 'iot:Connect',
            Effect: 'Allow',
          }),
          Match.objectLike({
            Action: 'iot:Publish',
            Effect: 'Allow',
          }),
        ]),
      },
    });
  });

  test('exports essential client configuration outputs', () => {
    template.hasOutput('UserPoolId', {});
    template.hasOutput('UserPoolClientId', {});
    template.hasOutput('IdentityPoolId', {});
    template.hasOutput('CognitoRegion', {});
    template.hasOutput('MapName', {});
    template.hasOutput('MapArn', {});
    template.hasOutput('GeofenceCollectionName', {});
    template.hasOutput('GeofenceCollectionArn', {});
    template.hasOutput('AuthenticatedRoleArn', {});
  });
});
