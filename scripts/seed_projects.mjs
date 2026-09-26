/**
 * Seeds the `projects` collection from the Dart fallbacks in
 * `lib/config/donation_defaults.dart` (Impact Hub, Vehicle Purchase, Media
 * Studio).
 *
 * Why: the collection is EMPTY in production, so the donation purpose pipeline
 * has nothing to resolve a `project_id` against -- a receipt falls back to
 * "General Support" even when the donor picked a project, and the project's
 * `raised` counter can never increment.
 *
 * The app already falls back to the Dart list when the collection is empty, so
 * this makes the two agree.
 *
 * Idempotent: an existing project is left alone unless --force is passed, so
 * re-running will not wipe progress recorded in `raised`.
 *
 *   node scripts/seed_projects.mjs [--force]
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
const tableId = process.env.APPWRITE_PROJECTS_COLLECTION_ID || 'projects';
const force = process.argv.includes('--force');

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

// Mirrors donationFallbackProjects. `raised` is the one field that must NOT be
// overwritten on a routine re-run: it is live giving progress.
const PROJECTS = [
  {
    $id: 'impact_hub_center',
    title: 'Impact Hub Center',
    summary: 'A central hub for training, discipleship, and community engagement.',
    description:
      'A central hub for training, discipleship, and community engagement.',
    category: '',
    type: 'project',
    status: 'active',
    target_amount: 35000000,
    raised: 8384400,
    amount_raised: 8384400,
    currency: 'NGN',
    image_url: 'assets/images/impact_hub_3d_view.png',
    fund_update_title: 'Progress so far',
    fund_update_text:
      'Seed funding has helped prepare the project scope, early planning, and ministry coordination for the hub.',
    priority: 1,
    is_active: true,
  },
  {
    $id: 'vehicle_purchase',
    title: 'Vehicle Purchase',
    summary:
      'Reliable transportation for mission trips and logistics across Nigeria.',
    description:
      'Reliable transportation for mission trips and logistics across Nigeria.',
    category: '',
    type: 'project',
    status: 'active',
    target_amount: 18000000,
    raised: 0,
    amount_raised: 0,
    currency: 'NGN',
    image_url:
      'https://images.unsplash.com/photo-1597685204565-110abf469a1e?q=80&w=870&auto=format&fit=crop',
    priority: 2,
    is_active: true,
  },
  {
    $id: 'media_studio_setup',
    title: 'Media Studio Setup',
    summary:
      'Equipping the ministry with high-quality media production capabilities.',
    description:
      'Equipping the ministry with high-quality media production capabilities.',
    category: '',
    type: 'project',
    status: 'planning',
    target_amount: 9000000,
    raised: 0,
    amount_raised: 0,
    currency: 'NGN',
    image_url:
      'https://images.unsplash.com/photo-1769699167906-a44d5ae50abb?q=80&w=387&auto=format&fit=crop',
    priority: 3,
    is_active: true,
  },
];

const path = `/databases/${databaseId}/collections/${tableId}/documents`;
const existing = await api('GET', `${path}?limit=200`);
const byId = new Map((existing.documents || []).map((d) => [d.$id, d]));
const now = new Date().toISOString();

let created = 0;
let skipped = 0;

for (const project of PROJECTS) {
  const prior = byId.get(project.$id);
  // Appwrite 1.7 wants the id outside the `data` envelope.
  const { $id: docId, ...fields } = project;
  const data = { ...fields, created_at: now, updated_at: now };

  if (prior && !force) {
    // Never clobber recorded giving progress on a routine re-run.
    console.log(`  = ${docId} (exists, raised=${prior.raised})`);
    skipped++;
    continue;
  }

  if (prior) {
    // Keep the real figure; refresh only the descriptive fields.
    data.raised = prior.raised ?? fields.raised;
    data.amount_raised = prior.amount_raised ?? fields.amount_raised;
    await api('PATCH', `${path}/${prior.$id}`, { data });
    console.log(`  ~ ${docId} (updated)`);
  } else {
    await api('POST', path, { documentId: docId, data });
    console.log(`  + ${docId} (created)`);
    created++;
  }
}

const after = await api('GET', `${path}?limit=200`);
console.log(
  `\n${tableId}: ${created} created, ${skipped} skipped, ` +
    `${(after.documents || []).length} total.`,
);
console.log(
  'Retire a project by setting is_active=false and status=completed: the ' +
    'donation screen hides it while its history stays in the admin report.',
);
