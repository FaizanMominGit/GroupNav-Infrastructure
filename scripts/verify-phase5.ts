import {
  CloudWatchClient,
  GetDashboardCommand,
  DescribeAlarmsCommand,
} from '@aws-sdk/client-cloudwatch';
import {
  CloudFormationClient,
  DescribeStacksCommand,
} from '@aws-sdk/client-cloudformation';

const REGION = process.env.AWS_REGION || 'ap-south-1';
const cw = new CloudWatchClient({ region: REGION });
const cfn = new CloudFormationClient({ region: REGION });

async function getStackOutputs(stackName: string): Promise<Record<string, string>> {
  try {
    const res = await cfn.send(new DescribeStacksCommand({ StackName: stackName }));
    const outputs = res.Stacks?.[0]?.Outputs || [];
    const map: Record<string, string> = {};
    for (const o of outputs) {
      if (o.OutputKey && o.OutputValue) {
        map[o.OutputKey] = o.OutputValue;
      }
    }
    return map;
  } catch (err: any) {
    console.error(`[ERROR] Could not retrieve outputs for ${stackName}: ${err.message}`);
    process.exit(1);
  }
}

async function main() {
  console.log('====================================================');
  console.log('  GROUPNAV PHASE 5 OBSERVABILITY LIVE VERIFICATION');
  console.log('====================================================\n');

  console.log(`[1/3] Reading ObservabilityStack outputs from CloudFormation (${REGION})...`);
  const outputs = await getStackOutputs('ObservabilityStack');
  const dashboardName = outputs.DashboardName || 'GroupNav-Operational-Dashboard';
  console.log(`  ✓ Dashboard Name: ${dashboardName}`);
  console.log(`  ✓ Lambda Error Alarm: ${outputs.LambdaErrorAlarmArn || 'N/A'}`);
  console.log(`  ✓ Aurora Connection Alarm: ${outputs.AuroraConnectionAlarmArn || 'N/A'}`);
  console.log(`  ✓ DLQ Alarm: ${outputs.DlqAlarmArn || 'N/A'}\n`);

  console.log('[2/3] Verifying CloudWatch Dashboard definition and widgets...');
  const dashboardRes = await cw.send(new GetDashboardCommand({ DashboardName: dashboardName }));
  if (!dashboardRes.DashboardBody) {
    throw new Error('Dashboard body is empty!');
  }
  const body = JSON.parse(dashboardRes.DashboardBody);
  const widgetCount = body.widgets?.length || 0;
  console.log(`  ✓ Successfully fetched dashboard body (${widgetCount} configured widgets)`);
  for (const w of body.widgets || []) {
    const title = w.properties?.title || w.type;
    console.log(`    - Widget [${w.type}]: "${title}"`);
  }
  console.log();

  console.log('[3/3] Verifying CloudWatch Alarms status and thresholds...');
  const alarmsRes = await cw.send(
    new DescribeAlarmsCommand({
      AlarmNames: [
        'GroupNav-LambdaErrorAlarm',
        'GroupNav-AuroraConnectionSaturationAlarm',
        'GroupNav-DeadLetterQueueAlarm',
      ],
    }),
  );

  const alarms = alarmsRes.MetricAlarms || [];
  console.log(`  ✓ Found ${alarms.length} active metric alarms in CloudWatch:`);
  for (const a of alarms) {
    console.log(
      `    - Alarm: ${a.AlarmName} | State: ${a.StateValue} | Metric: ${a.MetricName} (Threshold: >= ${a.Threshold})`,
    );
  }

  if (alarms.length < 3) {
    throw new Error(`Expected 3 alarms, but found ${alarms.length}`);
  }

  console.log('\n====================================================');
  console.log('  PHASE 5 VERIFICATION PASSED: OBSERVABILITY READY');
  console.log('====================================================');
}

main().catch((err) => {
  console.error('[FATAL ERROR] Phase 5 Verification failed:', err);
  process.exit(1);
});
