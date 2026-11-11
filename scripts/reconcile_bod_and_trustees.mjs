import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

if (existsSync(resolve(process.cwd(), '.env'))) {
  for (const line of readFileSync(resolve(process.cwd(), '.env'), 'utf8').split(/\r?\n/)) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2].trim().replace(/^['"]|['"]$/g, '');
  }
}

const endpoint = (process.env.APPWRITE_ENDPOINT || '').replace(/\/v1\/?$/, '');
const headers = {
  'X-Appwrite-Project': process.env.APPWRITE_PROJECT_ID,
  'X-Appwrite-Key': process.env.APPWRITE_API_KEY,
  'Content-Type': 'application/json',
};
const dbId = process.env.APPWRITE_DATABASE_ID;
const usersCollectionId = '6a08943100226f5b4963';

// 1. Update Okechukwu Elechi's profile role to 'bod'
const elechiUserId = '6af371a672420765763b';
const patchUserRes = await fetch(
  `${endpoint}/v1/databases/${dbId}/collections/${usersCollectionId}/documents/${elechiUserId}`,
  {
    method: 'PATCH',
    headers,
    body: JSON.stringify({
      data: {
        role: 'bod',
        full_name: 'Okechukwu Elechi',
        updated_at: new Date().toISOString(),
      },
    }),
  }
);
console.log(`[User Profile] Okechukwu Elechi (${elechiUserId}) role -> bod: HTTP ${patchUserRes.status}`);

// 2. Fetch existing org_office_holders documents
const res = await fetch(`${endpoint}/v1/databases/${dbId}/collections/org_office_holders/documents?limit=200`, { headers });
const data = await res.json();
const existingDocs = data.documents || [];

// Delete existing documents to have clean, accurate classification
for (const doc of existingDocs) {
  await fetch(`${endpoint}/v1/databases/${dbId}/collections/org_office_holders/documents/${doc.$id}`, {
    method: 'DELETE',
    headers,
  });
}
console.log(`Cleaned ${existingDocs.length} previous office holder records.`);

// 3. Exact Trustees: Jerry Kwarba (Chair), Imoh Imeh
const trustees = [
  { office_id: 'trustee', office_title: 'Chairman, Board of Trustees', full_name: 'Jerry Kwarba', email: '', user_id: '' },
  { office_id: 'trustee', office_title: 'Trustee', full_name: 'Imoh Imeh', email: '', user_id: '' },
];

// Exact Board of Directors
const directors = [
  { office_id: 'executive_president', office_title: 'Executive President & Chairman', full_name: 'Nwoko Patience Mfon', email: 'jamespat84@gmail.com', user_id: '' },
  { office_id: 'secretary', office_title: 'Secretary & Communication Director', full_name: 'Caleb Peters', email: 'peterscaleb50@gmail.com', user_id: '6abceded858b8dff1858' },
  { office_id: 'speaker', office_title: 'Speaker & Director, AMTC', full_name: 'Godstime Esuku', email: 'deovolente52@gmail.com', user_id: '6ad7c8bf4cbbd6a3395a' },
  { office_id: 'treasurer', office_title: 'Treasurer & Director of Logistics', full_name: 'Timothy Olodude', email: 'dammyolodude@gmail.com', user_id: '6a875b8ec9a90f0a6a55' },
  { office_id: 'director_evangelism', office_title: 'Director of Evangelism & Programming', full_name: 'Emenike Ekechi', email: 'praiseelechi@gmail.com', user_id: '' },
  { office_id: 'bod', office_title: 'Director (BOD)', full_name: 'Okechukwu Elechi', email: 'okechukwuelechi33@gmail.com', user_id: elechiUserId },
  { office_id: 'bod', office_title: 'Director (BOD & Trustee)', full_name: 'Imoh Imeh', email: '', user_id: '' },
  { office_id: 'bod', office_title: 'Director (BOD)', full_name: 'Ajibade Ayodeji', email: '', user_id: '' },
  { office_id: 'bod', office_title: 'Director (BOD)', full_name: 'Fatola Samson', email: '', user_id: '' },
  { office_id: 'bod', office_title: 'Director (BOD)', full_name: 'Bassey Etido', email: '', user_id: '' },
  { office_id: 'bod', office_title: 'Director (BOD)', full_name: 'Joshua Umahi', email: '', user_id: '' },
  { office_id: 'bod', office_title: 'Director (BOD)', full_name: 'Frank A', email: '', user_id: '' },
  { office_id: 'bod', office_title: 'Director (BOD)', full_name: 'Emeka Okoro', email: '', user_id: '' },
  { office_id: 'bod', office_title: 'Director (BOD)', full_name: 'Nancy Elechi', email: '', user_id: '' },
];

async function insertHolder(item) {
  const payload = {
    office_id: item.office_id,
    office_title: item.office_title,
    scope: 'national',
    chapter_id: '',
    user_id: item.user_id || '',
    full_name: item.full_name,
    email: item.email || '',
    supervisor_user_id: '',
    supervisor_name: item.office_id === 'trustee' ? 'Board of Trustees' : 'Executive President',
    term_start: new Date().toISOString(),
    term_end: new Date(Date.now() + 365 * 24 * 3600 * 1000 * 3).toISOString(),
    ended_reason: '',
    is_current: true,
    created_at: new Date().toISOString(),
  };

  const createRes = await fetch(`${endpoint}/v1/databases/${dbId}/collections/org_office_holders/documents`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      documentId: 'unique()',
      data: payload,
    }),
  });
  const resBody = await createRes.json();
  console.log(`[org_office_holders] Created ${item.full_name} (${item.office_title}): HTTP ${createRes.status} ${createRes.status !== 201 ? JSON.stringify(resBody) : ''}`);
}

console.log('\n--- Inserting Trustees ---');
for (const t of trustees) {
  await insertHolder(t);
}

console.log('\n--- Inserting Directors ---');
for (const d of directors) {
  await insertHolder(d);
}

// 4. Ensure Okechukwu Elechi is in channel_bod
const rowId = `channel_bod_${elechiUserId}`;
await fetch(`${endpoint}/v1/tablesdb/${dbId}/tables/channel_members/rows`, {
  method: 'POST',
  headers,
  body: JSON.stringify({
    rowId,
    data: {
      channel_id: 'channel_bod',
      user_id: elechiUserId,
      joined_at: new Date().toISOString(),
    },
  }),
});
console.log(`✅ Ensured Okechukwu Elechi is a member of channel_bod.`);

console.log('\n🎉 Reconciled successfully!');
