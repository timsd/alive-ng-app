/**
 * Mirrors the office registry from `lib/config/org_structure.dart` into the
 * `org_offices` table, so the running app can route by office instead of by a
 * hard-coded name.
 *
 * The Dart registry is the source of truth; this script is kept in step with it
 * by hand. It is idempotent: an unchanged office is left alone, and tenure
 * history is appended only when an office is first seen.
 *
 *   node scripts/seed_org_offices.mjs
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
const headers = {
  'X-Appwrite-Project': process.env.APPWRITE_PROJECT_ID,
  'X-Appwrite-Key': process.env.APPWRITE_API_KEY,
  'Content-Type': 'application/json',
};
const databaseId = process.env.APPWRITE_DATABASE_ID;

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


// ── The registry, mirroring lib/config/org_structure.dart ───────────────────
// Chain: Board of Trustees -> President -> the director-level offices.
// A body with several holders is ONE office with a members list: routing and
// the org_offices key are both `office_id`, so a repeated id would break them.
const OFFICES = [
  {
    id: 'board_of_trustees',
    title: 'Board of Trustees',
    reportsTo: null,
    holder: 'Jerry Kwarba',
    members: [
      'Jerry Kwarba', 'Okey Elechi', 'Imoh Imeh', 'Ajibade Ayodeji',
      'Fatola Samson', 'Bassey Etido', 'Joshua Umahi', 'Frank A', 'Emeka', 'Nancy Elechi',
    ],
  },
  {
    id: 'trustee',
    title: 'Trustee (Board Member)',
    reportsTo: 'board_of_trustees',
    holder: 'Jerry Kwarba',
  },
  { id: 'executive_president', title: 'Executive President', reportsTo: 'board_of_trustees', holder: 'Nwoko Patience Mfon' },
  { id: 'secretary', title: 'Secretary', reportsTo: 'executive_president', holder: 'Caleb Peters' },
  { id: 'communication_director', title: 'Communication Director', reportsTo: 'executive_president', holder: 'Caleb Peters' },
  { id: 'speaker', title: 'Speaker', reportsTo: 'executive_president', holder: 'Godstime Esuku' },
  { id: 'director_amtc', title: 'Director, ALIVE Mission Training Center (AMTC)', reportsTo: 'executive_president', holder: 'Godstime Esuku' },
  { id: 'treasurer', title: 'Treasurer', reportsTo: 'executive_president', holder: 'Timothy Olodude' },
  { id: 'director_logistics', title: 'Director of Logistics', reportsTo: 'executive_president', holder: 'Timothy Olodude' },
  { id: 'director_evangelism', title: 'Director of Evangelism', reportsTo: 'executive_president', holder: 'Emenike Ekechi' },
  { id: 'director_programming', title: 'Director of Programming', reportsTo: 'executive_president', holder: 'Emenike Ekechi' },
  { id: 'director_health', title: 'Director of Health', reportsTo: 'executive_president', holder: 'Emenike Ekechi' },
];

// Every director-level office is supervised by a trustee.
const SUPERVISOR_OFFICE = 'trustee';

const now = new Date().toISOString();
const officesPath = `/databases/${databaseId}/collections/org_offices/documents`;
const holdersPath = `/databases/${databaseId}/collections/org_office_holders/documents`;

const existing = await api('GET', `${officesPath}?limit=200`);
const byOfficeId = new Map((existing.documents || []).map((d) => [d.office_id, d]));

let created = 0;
let updated = 0;

for (const office of OFFICES) {
  const isDirectorLevel =
    office.reportsTo === 'executive_president' || office.reportsTo === 'trustee';

  const data = {
    office_id: office.id,
    title: office.title,
    scope: 'national',
    chapter_id: '',
    office_type: office.id.includes('director') ? 'director' : 'office',
    holder_name: office.holder,
    // Comma-separated, so a body with several holders stays one office row.
    notes: (office.members ?? []).join(', '),
    holder_email: '',
    holder_user_id: '',
    // Directors report to the President but are SUPERVISED by a trustee.
    supervisor_office_id: isDirectorLevel
      ? SUPERVISOR_OFFICE
      : (office.reportsTo ?? ''),
    is_active: true,
    term_start: now,
    term_end: '',
    notes: '',
    created_at: now,
    updated_at: now,
  };

  const prior = byOfficeId.get(office.id);
  if (prior) {
    if (
      prior.holder_name === data.holder_name &&
      prior.supervisor_office_id === data.supervisor_office_id
    ) {
      console.log(`  = ${office.id} (unchanged)`);
      continue;
    }
    await api('PATCH', `${officesPath}/${prior.$id}`, { data });
    console.log(`  ~ ${office.id} (updated)`);
    updated++;
  } else {
    // Appwrite 1.7 expects the document body nested under `data`.
    await api('POST', officesPath, {
      documentId: office.id,
      data,
    });
    console.log(`  + ${office.id} (created)`);
    created++;
  }

  // Record tenure history the first time an office is seen.
  if (!prior) {
    await api('POST', holdersPath, {
      documentId: `${office.id}-${Date.now()}`,
      data: {
        office_id: office.id,
        office_title: office.title,
        scope: 'national',
        chapter_id: '',
        user_id: '',
        full_name: office.holder,
        email: '',
        supervisor_user_id: '',
        supervisor_name: 'Trustee',
        term_start: now,
        term_end: '',
        ended_reason: '',
        is_current: true,
        created_at: now,
      },
    });
  }
}

console.log(
  `\nSeeded ${OFFICES.length} office(s): ${created} created, ${updated} updated.`,
);
