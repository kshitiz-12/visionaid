const fs = require('fs');

const projectRef = 'fogmbmvvvzemdcyywsrd';
const path = '.env';
const text = fs.readFileSync(path, 'utf8');

function fixLine(line) {
  if (!line.startsWith('DATABASE_URL=') && !line.startsWith('DIRECT_URL=')) {
    return line;
  }

  const eq = line.indexOf('=');
  const key = line.slice(0, eq);
  let url = line.slice(eq + 1).trim();

  if (
    (url.startsWith('"') && url.endsWith('"')) ||
    (url.startsWith("'") && url.endsWith("'"))
  ) {
    url = url.slice(1, -1);
  }

  const u = new URL(url);
  const pass = decodeURIComponent(u.password);

  let user = u.username;
  if (!user.includes('.')) {
    user = `postgres.${projectRef}`;
  }

  const port = key === 'DIRECT_URL' ? '5432' : '6543';
  const params = new URLSearchParams(u.searchParams);

  if (key === 'DATABASE_URL') {
    params.set('pgbouncer', 'true');
  } else {
    params.delete('pgbouncer');
  }
  params.set('sslmode', 'require');

  const qs = params.toString();
  const rebuilt = `postgresql://${user}:${encodeURIComponent(pass)}@${u.hostname}:${port}${u.pathname}${qs ? `?${qs}` : ''}`;
  return `${key}=${rebuilt}`;
}

const out = text.split(/\r?\n/).map(fixLine).join('\n');
fs.writeFileSync(path, out.endsWith('\n') ? out : `${out}\n`);
console.log('FIXED_ENV_USERNAMES');
