/**
 * Provisions the tables the app's Dart code already references but which do not
 * exist in Appwrite yet.
 *
 * Discovery: every Discipleship table, plus leadership records and backups,
 * were referenced by the app but absent from the project, so those screens
 * could never load or save anything.
 *
 * Safe to re-run: existing tables and columns are left alone.
 *
 *   node scripts/ensure_org_schema.mjs
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

function loadDotEnv(filePath = resolve(process.cwd(), '.env')) {
  if (!existsSync(filePath)) return;
  for (const rawLine of readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const [rawKey, ...valueParts] = line.split('=');
    const key = rawKey.trim();
    if (!key || process.env[key] !== undefined) continue;
    process.env[key] = valueParts.join('=').trim().replace(/^['"]|['"]$/g, '');
  }
}

loadDotEnv();

const endpoint = (process.env.APPWRITE_ENDPOINT || '').replace(/\/v1\/?$/, '');
const projectId = process.env.APPWRITE_PROJECT_ID;
const apiKey = process.env.APPWRITE_API_KEY;
const databaseId = process.env.APPWRITE_DATABASE_ID;

for (const [name, value] of Object.entries({ endpoint, projectId, apiKey, databaseId })) {
  if (!value) throw new Error(`Missing ${name} in .env`);
}

const headers = {
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey,
  'Content-Type': 'application/json',
};

async function api(method, path, body) {
  let lastErr;
  for (let attempt = 1; attempt <= 4; attempt++) {
    try {
      const res = await fetch(`${endpoint}/v1${path}`, {
        method,
        headers,
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      const text = await res.text();
      let json = {};
      try { json = text ? JSON.parse(text) : {}; } catch { /* keep raw */ }
      if (!res.ok) {
        const err = new Error(json.message || text || `HTTP ${res.status}`);
        err.status = res.status;
        throw err;
      }
      return json;
    } catch (e) {
      if (e.status) throw e;
      lastErr = e;
      if (attempt < 4) await new Promise((r) => setTimeout(r, 1500 * attempt));
    }
  }
  throw lastErr;
}

const S = (size = 512) => ({ type: 'string', size });
// Every column is optional. Spreading REQ into a column spec would inject a
// bogus `required` KEY, so the flag is set explicitly when the body is built.
const DT = { type: 'datetime' };
const BOOL = { type: 'boolean' };

// ── Apply ────────────────────────────────────────────────────────────────────
// (the SCHEMA constant is declared above; this section executes it)

async function ensureTable(table, columns) {
  const colPath = `/databases/${databaseId}/collections/${table}/attributes`;
  try {
    await api('GET', `/databases/${databaseId}/collections/${table}`);
    console.log(`  = ${table} (exists)`);
  } catch (e) {
    if (e.status !== 404) throw e;
    await api('POST', `/databases/${databaseId}/collections`, {
      collectionId: table,
      name: table,
      permissions: ['read("any")', 'create("users")', 'update("users")', 'delete("users")'],
      documentSecurity: false,
      enabled: true,
    });
    console.log(`  + ${table} (created)`);
  }

  const listed = await api('GET', `${colPath}?limit=1000`);
  const have = new Set((listed.attributes || []).map((a) => a.key || a.attributeKey || a.name));

  for (const [key, col] of Object.entries(columns)) {
    if (have.has(key)) continue;
    const body = {
      key,
      required: col.required ?? false,
      xss: false,
      encrypt: false,
    };
    // Appwrite 1.7 routes attribute creation per TYPE, e.g. ".../attributes/string".
    let path;
    if (col.type === 'string') {
      path = `${colPath}/string`;
      body.size = col.size ?? 512;
    } else if (col.type === 'datetime') {
      path = `${colPath}/datetime`;
    } else if (col.type === 'boolean') {
      path = `${colPath}/boolean`;
      body.default = false;
    } else {
      path = `${colPath}/${col.type}`;
    }
    // `...REQ` on a column spec spreads a `required` KEY, not the value, so a
    // bogus `required: "required"` string was being POSTed as its own column.
    if (col.required !== undefined) body.required = col.required;
    try {
      await api('POST', path, body);
      console.log(`      + ${key} (${col.type})`);
    } catch (err) {
      console.log(`      ! ${key}: ${err.message.split('\n')[0]}`);
    }
  }
}

// ── Runner ───────────────────────────────────────────────────────────────────
// Declared here as a function so it can be invoked at the very bottom of the
// file, once `SCHEMA` above has been initialised.
async function main() {
  console.log('Ensuring organisation / discipleship schema...\n');
  for (const [table, columns] of Object.entries(SCHEMA)) {
    await ensureTable(table, columns);
  }
  console.log('\nDone. Safe to re-run.');
}

// ── Schema ───────────────────────────────────────────────────────────────────
// Reporting lines are modelled explicitly so access control comes from the app's
// role, never from who knows which email address:
//
//   member -> chapter coordinator -> director -> president -> board of trustees
//
// A director is supervised by a trustee. Every office holder is a row in
// `org_offices` with a TERM (term_start/term_end), so a change of person closes
// the old row and opens a new one instead of overwriting history.
const SCHEMA = {
  // A chapter-scoped or national office, and who currently holds it.
  // chapter_id is null for national offices.
  org_offices: {
    office_id: S(128),            // stable slug, e.g. 'chapter_coordinator'
    title: S(200),
    scope: S(32),                 // 'chapter' | 'national'
    chapter_id: S(64),
    office_type: S(32),           // coordinator | director | president | trustee
    holder_user_id: S(64),        // null when vacant
    holder_name: S(200),
    holder_email: S(200),
    supervisor_office_id: S(128), // the office this one reports into
    supervisor_user_id: S(64),    // direct supervisor, e.g. a trustee
    term_start: DT,
    term_end: DT,
    is_active: BOOL,
    notes: S(1000),
    created_at: DT,
    updated_at: DT,
  },

  // Immutable tenure history: "who held this office, and when".
  org_office_holders: {
    office_id: S(128),
    office_title: S(200),
    scope: S(32),
    chapter_id: S(64),
    user_id: S(64),
    full_name: S(200),
    email: S(200),
    supervisor_user_id: S(64),
    supervisor_name: S(200),
    term_start: DT,
    term_end: DT,
    ended_reason: S(200),         // term_ended | replaced | resigned
    is_current: BOOL,
    created_at: DT,
  },

  // Reports a worker submits; an officer/coordinator answers.
  discipleship_reports: {
    disciple_maker_id: S(64),
    disciple_maker_name: S(200),
    chapter_id: S(64),
    routed_office_id: S(128),
    routed_office_title: S(200),
    routed_officer_id: S(64),
    routed_officer_name: S(200),
    supervisor_id: S(64),
    report_period: S(64),
    report_type: S(64),
    summary: S(4000),
    metrics: S(4000),
    status: S(32),                // draft | submitted | reviewed
    feedback: S(4000),
    feedback_officer_name: S(200),
    feedback_at: DT,
    submitted_at: DT,
    created_at: DT,
    updated_at: DT,
  },

  discipleship_contacts: {
    name: S(200),
    email: S(200),
    phone: S(64),
    level: S(64),
    chapter_id: S(64),
    owner_user_id: S(64),
    notes: S(2000),
    last_contacted_at: DT,
    created_at: DT,
  },

};

await main();
