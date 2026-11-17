import AsyncStorage from '@react-native-async-storage/async-storage';

const KEY = 'orion_api_base';
const DEFAULT = 'http://10.0.2.2:8787'; // Android emulator → host PC

export type CommandResult = {
  ok: boolean;
  spoken: string;
  intentType?: string;
  pending?: Record<string, unknown> | null;
};

export async function getBaseUrl() {
  return (await AsyncStorage.getItem(KEY)) || DEFAULT;
}

export async function setBaseUrl(url: string) {
  await AsyncStorage.setItem(KEY, url.replace(/\/$/, ''));
}

async function u(path: string) {
  const base = await getBaseUrl();
  return `${base}${path}`;
}

export async function health() {
  const res = await fetch(await u('/api/health'));
  return res.json();
}

export async function startBrowser() {
  await fetch(await u('/api/browser/start'), { method: 'POST' });
}

export async function sendCommand(spoken: string): Promise<CommandResult> {
  const res = await fetch(await u('/api/command'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ spoken }),
  });
  const json = await res.json();
  return {
    ok: json.ok !== false && res.status < 400,
    spoken: String(json.spoken || 'No spoken reply.').trim(),
    intentType: json.intent?.type,
    pending: json.pending ?? null,
  };
}
