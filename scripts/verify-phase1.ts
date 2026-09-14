import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

// Read deployed client config
const configPath = path.join(__dirname, '..', 'client-config.json');
if (!fs.existsSync(configPath)) {
  console.error('client-config.json not found! Run deployment first.');
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const region = config.region;
const userPoolId = config.cognito.userPoolId;
const clientId = config.cognito.userPoolClientId;
const identityPoolId = config.cognito.identityPoolId;
const mapName = config.location.mapName;

const testUser = `verifier-${Date.now()}@groupnav.local`;
const testPassword = 'GroupNav2026!TestPass';

function runAws(cmd: string): string {
  const fullCmd = `aws ${cmd} --region ${region}`;
  return execSync(fullCmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
}

async function main() {
  console.log('====================================================');
  console.log('  GroupNav Phase 1: Live Cloud Verification');
  console.log('====================================================');
  console.log(`Region: ${region}`);
  console.log(`User Pool: ${userPoolId}`);
  console.log(`Client ID: ${clientId}`);
  console.log(`Identity Pool: ${identityPoolId}`);
  console.log(`Map: ${mapName}`);
  console.log('----------------------------------------------------');

  try {
    // 1. Register test rider in Cognito User Pool
    console.log(`\n[1/5] Registering test rider: ${testUser}...`);
    const signUpOut = JSON.parse(
      runAws(
        `cognito-idp sign-up --client-id ${clientId} --username "${testUser}" --password "${testPassword}" --user-attributes Name=email,Value="${testUser}"`
      )
    );
    console.log(`  ✓ Registered successfully (UserSub: ${signUpOut.UserSub})`);

    // 2. Admin confirm user
    console.log('\n[2/5] Admin confirming rider sign-up...');
    runAws(`cognito-idp admin-confirm-sign-up --user-pool-id ${userPoolId} --username "${testUser}"`);
    console.log('  ✓ Rider confirmed');

    // 3. Authenticate and retrieve ID token
    console.log('\n[3/5] Authenticating rider via USER_PASSWORD_AUTH...');
    const authOut = JSON.parse(
      runAws(
        `cognito-idp initiate-auth --client-id ${clientId} --auth-flow USER_PASSWORD_AUTH --auth-parameters USERNAME="${testUser}",PASSWORD="${testPassword}"`
      )
    );
    const idToken = authOut.AuthenticationResult.IdToken;
    console.log(`  ✓ Authentication successful (Retrieved IdToken of length ${idToken.length})`);

    // 4. Exchange IdToken for temporary AWS IAM credentials via Identity Pool
    console.log('\n[4/5] Exchanging IdToken for temporary AWS IAM credentials...');
    const providerName = `cognito-idp.${region}.amazonaws.com/${userPoolId}`;
    const getIdOut = JSON.parse(
      runAws(
        `cognito-identity get-id --identity-pool-id ${identityPoolId} --logins "${providerName}=${idToken}"`
      )
    );
    const identityId = getIdOut.IdentityId;
    console.log(`  ✓ Obtained Cognito Identity ID: ${identityId}`);

    const credsOut = JSON.parse(
      runAws(
        `cognito-identity get-credentials-for-identity --identity-id ${identityId} --logins "${providerName}=${idToken}"`
      )
    );
    const creds = credsOut.Credentials;
    const maskedKey = creds.AccessKeyId.substring(0, 4) + '****************';
    console.log(`  ✓ Temporary AWS Access Key ID: ${maskedKey}`);
    console.log(`  ✓ Session Expiration: ${creds.Expiration}`);

    // 5. Test Amazon Location Service access using temporary credentials
    console.log('\n[5/5] Testing Amazon Location Service access with rider credentials...');
    const tempTilePath = path.join(__dirname, '..', 'temp-map-tile.pbf');
    const tempStylePath = path.join(__dirname, '..', 'temp-map-style.json');

    const envWithCreds = {
      ...process.env,
      AWS_ACCESS_KEY_ID: creds.AccessKeyId,
      AWS_SECRET_ACCESS_KEY: creds.SecretKey,
      AWS_SESSION_TOKEN: creds.SessionToken,
    };

    // Test A: Get Map Style Descriptor
    const styleCmd = `aws location get-map-style-descriptor --map-name ${mapName} "${tempStylePath}" --region ${region}`;
    execSync(styleCmd, {
      env: envWithCreds,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    const styleSize = fs.statSync(tempStylePath).size;
    console.log(`  ✓ Successfully fetched Map Style Descriptor (${styleSize} bytes)`);

    // Test B: Get Map Tile (z=0, x=0, y=0)
    const tileCmd = `aws location get-map-tile --map-name ${mapName} --z "0" --x "0" --y "0" "${tempTilePath}" --region ${region}`;
    execSync(tileCmd, {
      env: envWithCreds,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    const tileSize = fs.statSync(tempTilePath).size;
    console.log(`  ✓ Successfully fetched Map Vector Tile at z=0, x=0, y=0 (${tileSize} bytes)`);

    // Cleanup temp files
    if (fs.existsSync(tempStylePath)) fs.unlinkSync(tempStylePath);
    if (fs.existsSync(tempTilePath)) fs.unlinkSync(tempTilePath);

    console.log('\n====================================================');
    console.log('  VERIFICATION RESULT: ALL 5 PHASES PASSED 100%!');
    console.log('====================================================');
  } catch (err: any) {
    console.error('\n❌ Verification failed:', err.message);
    if (err.stderr) {
      console.error('STDERR:', err.stderr.toString());
    }
    process.exit(1);
  } finally {
    // Cleanup test user
    console.log('\n[Cleanup] Deleting test rider from Cognito User Pool...');
    try {
      runAws(`cognito-idp admin-delete-user --user-pool-id ${userPoolId} --username "${testUser}"`);
      console.log('  ✓ Test user cleaned up.');
    } catch {
      // ignore cleanup error
    }
    // Also cleanup earlier manual test user if present
    try {
      runAws(`cognito-idp admin-delete-user --user-pool-id ${userPoolId} --username "test-rider-phase1@groupnav.local"`);
    } catch {}
  }
}

main();
