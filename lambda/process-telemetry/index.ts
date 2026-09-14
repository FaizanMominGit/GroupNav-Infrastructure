import { Client as PgClient } from 'pg';
import { createClient as createRedisClient } from 'redis';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

interface TelemetryPayload {
  riderId?: string;
  latitude: number;
  longitude: number;
  heading?: number;
  speed?: number;
  timestamp?: number | string;
}

interface IoTEvent {
  [key: string]: any;
}

const smClient = new SecretsManagerClient({});

// Cached DB credentials in execution container
let cachedDbConfig: { user: string; host: string; database: string; password: string; port: number } | null = null;

async function getDbCredentials() {
  if (cachedDbConfig) {
    return cachedDbConfig;
  }
  const secretArn = process.env.AURORA_SECRET_ARN;
  if (!secretArn) {
    throw new Error('AURORA_SECRET_ARN environment variable is not defined');
  }

  const response = await smClient.send(new GetSecretValueCommand({ SecretId: secretArn }));
  if (!response.SecretString) {
    throw new Error('Aurora secret string is empty');
  }

  const parsed = JSON.parse(response.SecretString);
  cachedDbConfig = {
    user: parsed.username,
    password: parsed.password,
    host: parsed.host || process.env.AURORA_CLUSTER_ENDPOINT || '',
    database: parsed.dbname || 'postgres',
    port: parseInt(parsed.port || '5432', 10),
  };
  return cachedDbConfig;
}

export async function handler(event: IoTEvent): Promise<{ statusCode: number; body: string }> {
  console.log('Received IoT telemetry event:', JSON.stringify(event));

  // Extract payload fields
  const latitude = typeof event.latitude === 'number' ? event.latitude : parseFloat(event.latitude);
  const longitude = typeof event.longitude === 'number' ? event.longitude : parseFloat(event.longitude);
  const riderId = event.riderId || event.rider_id || 'anonymous-rider';
  const heading = typeof event.heading === 'number' ? event.heading : 0;
  const speed = typeof event.speed === 'number' ? event.speed : 0;
  const timestamp = event.timestamp ? new Date(event.timestamp).toISOString() : new Date().toISOString();

  if (isNaN(latitude) || isNaN(longitude) || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    console.error('Invalid geospatial coordinates received:', { latitude, longitude });
    throw new Error(`Invalid GPS coordinates: lat=${latitude}, lon=${longitude}`);
  }

  const redisHost = process.env.REDIS_ENDPOINT;
  const redisPort = process.env.REDIS_PORT || '6379';

  // 1. Write to ElastiCache Redis (GEOADD)
  if (redisHost) {
    const redis = createRedisClient({
      url: `redis://${redisHost}:${redisPort}`,
      socket: { connectTimeout: 3000 },
    });

    try {
      await redis.connect();
      // GEOADD key longitude latitude member
      await redis.geoAdd('riders', {
        longitude,
        latitude,
        member: riderId,
      });
      console.log(`Successfully indexed rider ${riderId} at (${longitude}, ${latitude}) in Redis`);
    } catch (redisErr: any) {
      console.error('Redis GEOADD failed:', redisErr.message);
      throw redisErr;
    } finally {
      await redis.disconnect().catch(() => {});
    }
  }

  // 2. Write to Aurora PostgreSQL (Per-invocation connection strategy for scale-to-zero)
  const dbConfig = await getDbCredentials();
  const pg = new PgClient({
    ...dbConfig,
    connectionTimeoutMillis: 5000,
    ssl: { rejectUnauthorized: false },
  });

  try {
    await pg.connect();

    // Ensure schema exists
    await pg.query(`
      CREATE TABLE IF NOT EXISTS rider_telemetry (
        id BIGSERIAL PRIMARY KEY,
        rider_id VARCHAR(128) NOT NULL,
        heading NUMERIC(6, 2),
        speed NUMERIC(6, 2),
        recorded_at TIMESTAMPTZ NOT NULL,
        geom GEOGRAPHY(Point, 4326) NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_rider_telemetry_geom ON rider_telemetry USING GIST (geom);
    `);

    // Insert telemetry with PostGIS point
    await pg.query(
      `INSERT INTO rider_telemetry (rider_id, heading, speed, recorded_at, geom)
       VALUES ($1, $2, $3, $4, ST_SetSRID(ST_MakePoint($5, $6), 4326))`,
      [riderId, heading, speed, timestamp, longitude, latitude]
    );

    console.log(`Successfully recorded rider ${riderId} telemetry in Aurora`);
  } catch (pgErr: any) {
    console.error('Aurora write failed:', pgErr.message);
    throw pgErr;
  } finally {
    // Explicitly end connection per invocation so Aurora ACU can scale to zero
    await pg.end().catch(() => {});
  }

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Telemetry processed successfully',
      riderId,
      coordinates: [longitude, latitude],
    }),
  };
}
