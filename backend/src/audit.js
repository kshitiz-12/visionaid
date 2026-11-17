import fs from 'fs';
import path from 'path';
import { config } from './config.js';

const auditPath = () => path.join(config.dataDir, 'audit.jsonl');

/** Append-only evidence log for viva / review. */
export function audit(event, payload = {}) {
  try {
    fs.mkdirSync(config.dataDir, { recursive: true });
    const row = {
      ts: new Date().toISOString(),
      event,
      ...payload,
    };
    fs.appendFileSync(auditPath(), `${JSON.stringify(row)}\n`, 'utf8');
  } catch {
    // never break the agent for audit failures
  }
}

export function readRecentAudit(limit = 50) {
  try {
    if (!fs.existsSync(auditPath())) return [];
    const lines = fs.readFileSync(auditPath(), 'utf8').trim().split('\n').filter(Boolean);
    return lines.slice(-limit).map((l) => JSON.parse(l));
  } catch {
    return [];
  }
}
