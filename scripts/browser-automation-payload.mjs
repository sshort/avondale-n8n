import process from 'node:process';

function readPath(source, rawPath) {
  const segments = String(rawPath).split('.');
  let current = source;

  for (const segment of segments) {
    if (!current || typeof current !== 'object' || !Object.hasOwn(current, segment)) {
      return '';
    }
    current = current[segment];
  }

  return typeof current === 'string' ? current.trim() : '';
}

function readFirstPayloadString(payload, paths) {
  for (const candidatePath of paths) {
    const value = readPath(payload, candidatePath);
    if (value) {
      return value;
    }
  }

  return '';
}

export function parseExporterPayload() {
  const raw = String(process.env.EXPORTER_PAYLOAD_JSON ?? '').trim();
  if (!raw) {
    return {};
  }

  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

export function applyPayloadEnv(payload, envName, paths) {
  if (process.env[envName]) {
    return process.env[envName];
  }

  const value = readFirstPayloadString(payload, paths);
  if (value) {
    process.env[envName] = value;
    return value;
  }

  return '';
}

export const clubSparkCredentialFields = {
  CLUBSPARK_EMAIL: [
    'credentials.clubspark.email',
    'credentials.clubSpark.email',
    'clubspark.email',
    'clubSpark.email',
    'clubsparkEmail',
    'clubSparkEmail',
  ],
  CLUBSPARK_PASSWORD: [
    'credentials.clubspark.password',
    'credentials.clubSpark.password',
    'clubspark.password',
    'clubSpark.password',
    'clubsparkPassword',
    'clubSparkPassword',
  ],
  LTA_USERNAME: [
    'credentials.lta.username',
    'lta.username',
    'ltaUsername',
  ],
  LTA_PASSWORD: [
    'credentials.lta.password',
    'lta.password',
    'ltaPassword',
  ],
};
