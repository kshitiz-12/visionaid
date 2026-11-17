export function log(level, message, meta) {
  const line = {
    ts: new Date().toISOString(),
    level,
    message,
    ...(meta ? { meta } : {}),
  };
  const text = JSON.stringify(line);
  if (level === 'error') {
    console.error(text);
  } else {
    console.log(text);
  }
}

export const logger = {
  info: (m, meta) => log('info', m, meta),
  warn: (m, meta) => log('warn', m, meta),
  error: (m, meta) => log('error', m, meta),
};
