import fs from 'node:fs';

if (fs.existsSync('.env')) {
  const envContent = fs.readFileSync('.env', 'utf8');
  for (const line of envContent.split(/\r?\n/)) {
    if (!line || line.startsWith('#')) continue;
    const idx = line.indexOf('=');
    if (idx > 0) {
      const k = line.slice(0, idx).trim();
      const v = line.slice(idx + 1).trim();
      if (!process.env[k]) process.env[k] = v;
    }
  }
}

const endpoint = (process.env.APPWRITE_ENDPOINT || 'https://api.alivenigeria.org/v1').replace(/\/$/, '');
const projectId = process.env.APPWRITE_PROJECT_ID || '6a3bef53002f5090dedf';
const databaseId = process.env.APPWRITE_DATABASE_ID || '6a089307002e54291a32';
const apiKey = process.env.APPWRITE_API_KEY;

const usersCollectionId = '6a08943100226f5b4963';
const chatChannelsCollectionId = '6a08f1c70032affbc00d';

if (!apiKey) {
  throw new Error('APPWRITE_API_KEY is required');
}

const headers = {
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey,
  'Content-Type': 'application/json',
};

async function appwriteReq(path, options = {}) {
  const url = `${endpoint}${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      ...headers,
      ...(options.headers || {}),
    },
  });
  return res;
}

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function ensureMaritalStatusAttribute() {
  console.log('--- Checking marital_status attribute in users collection ---');
  const getRes = await appwriteReq(
    `/databases/${databaseId}/collections/${usersCollectionId}/attributes/marital_status`
  );
  if (getRes.status === 200) {
    const attr = await getRes.json();
    console.log('marital_status attribute already exists:', attr.status);
    return;
  }

  // Delete legacy unused column home_contact if attribute limit is reached
  console.log('Freeing slot by removing legacy unused home_contact attribute...');
  const delRes = await appwriteReq(
    `/databases/${databaseId}/collections/${usersCollectionId}/attributes/home_contact`,
    { method: 'DELETE' }
  );
  console.log('Delete home_contact status:', delRes.status);
  await sleep(4000);

  console.log('Creating marital_status attribute in users collection...');
  const createRes = await appwriteReq(
    `/databases/${databaseId}/collections/${usersCollectionId}/attributes/string`,
    {
      method: 'POST',
      body: JSON.stringify({
        key: 'marital_status',
        size: 32,
        required: false,
        default: 'single',
        array: false,
      }),
    }
  );
  if (!createRes.ok) {
    console.error('Failed to create marital_status attribute:', await createRes.text());
    return;
  }
  console.log('Attribute creation initiated. Waiting for availability...');
  for (let i = 0; i < 20; i++) {
    await sleep(2000);
    const chk = await appwriteReq(
      `/databases/${databaseId}/collections/${usersCollectionId}/attributes/marital_status`
    );
    if (chk.ok) {
      const body = await chk.json();
      if (body.status === 'available') {
        console.log('marital_status is available!');
        break;
      }
    }
  }
}

async function getAllUsers() {
  console.log('--- Fetching all registered users ---');
  let users = [];
  let offset = 0;
  const limit = 100;
  while (true) {
    const res = await appwriteReq(
      `/databases/${databaseId}/collections/${usersCollectionId}/documents?limit=${limit}&offset=${offset}`
    );
    if (!res.ok) {
      throw new Error(`Failed to list users: ${res.status} ${await res.text()}`);
    }
    const data = await res.json();
    users = users.concat(data.documents);
    if (data.documents.length < limit) break;
    offset += limit;
  }
  console.log(`Found ${users.length} total users in database.`);
  return users;
}

const TARGET_CHANNELS = [
  {
    $id: 'channel_general',
    name: 'General',
    description: 'General fellowship & discussion channel for all ALIVE Nigeria members.',
    type: 'general',
  },
  {
    $id: 'channel_singles',
    name: 'Singles Fellowship',
    description: 'Fellowship and community channel for single brethren in ALIVE Nigeria.',
    type: 'team',
  },
  {
    $id: 'channel_married',
    name: 'Couples & Married Fellowship',
    description: 'Fellowship and support channel for married brethren and couples in ALIVE Nigeria.',
    type: 'team',
  },
  {
    $id: 'channel_coordinators',
    name: 'Chapter Coordinators',
    description: 'Leadership coordination channel for ALIVE Nigeria chapter coordinators.',
    type: 'coordinators',
  },
  {
    $id: 'channel_donors',
    name: 'Donors & Partners Fellowship',
    description: 'Special channel for donors, partners, and supporters of ALIVE Nigeria ministry.',
    type: 'team',
  },
];

async function syncChannels(users) {
  console.log('--- Syncing Chat Channels & Member Distribution ---');

  const adminIds = users
    .filter((u) => u.role === 'admin' || (u.email && u.email.includes('admin')))
    .map((u) => u.$id);

  const allUserIds = users.filter((u) => !u.is_archived).map((u) => u.$id);
  const singleUserIds = users
    .filter((u) => !u.is_archived && (u.marital_status === 'single' || !u.marital_status || u.marital_status === ''))
    .map((u) => u.$id);
  const marriedUserIds = users
    .filter((u) => !u.is_archived && u.marital_status === 'married')
    .map((u) => u.$id);
  const coordinatorUserIds = users
    .filter((u) => !u.is_archived && u.role === 'coordinator')
    .map((u) => u.$id);
  const donorUserIds = users
    .filter((u) => !u.is_archived && (u.commitment_type === 'financial' || u.commitment_type === 'both' || u.role === 'admin'))
    .map((u) => u.$id);

  console.log(`Distribution: Total=${allUserIds.length}, Singles=${singleUserIds.length}, Married=${marriedUserIds.length}, Coordinators=${coordinatorUserIds.length}, Donors=${donorUserIds.length}`);

  for (const def of TARGET_CHANNELS) {
    let members = [];
    if (def.$id === 'channel_general') members = allUserIds;
    else if (def.$id === 'channel_singles') members = singleUserIds;
    else if (def.$id === 'channel_married') members = marriedUserIds;
    else if (def.$id === 'channel_coordinators') members = coordinatorUserIds;
    else if (def.$id === 'channel_donors') members = donorUserIds;

    const getRes = await appwriteReq(
      `/databases/${databaseId}/collections/${chatChannelsCollectionId}/documents/${def.$id}`
    );
    const existing = getRes.ok ? await getRes.json() : null;

    const payload = {
      name: def.name,
      description: def.description,
      type: def.type,
      is_archived: false,
      members: members.slice(0, 100),
      admins: adminIds.slice(0, 50),
      updated_at: new Date().toISOString(),
    };

    if (existing) {
      console.log(`Updating channel: ${def.name} (${def.$id}) with ${payload.members.length} members...`);
      const updRes = await appwriteReq(
        `/databases/${databaseId}/collections/${chatChannelsCollectionId}/documents/${def.$id}`,
        {
          method: 'PATCH',
          body: JSON.stringify({ data: payload }),
        }
      );
      if (!updRes.ok) {
        console.error(`Failed to update ${def.name}:`, await updRes.text());
      } else {
        console.log(`Updated ${def.name} successfully.`);
      }
    } else {
      console.log(`Creating channel: ${def.name} (${def.$id}) with ${payload.members.length} members...`);
      const createRes = await appwriteReq(
        `/databases/${databaseId}/collections/${chatChannelsCollectionId}/documents`,
        {
          method: 'POST',
          body: JSON.stringify({
            documentId: def.$id,
            data: {
              ...payload,
              created_at: new Date().toISOString(),
            },
            permissions: ['read("any")', 'update("users")', 'delete("users")'],
          }),
        }
      );
      if (!createRes.ok) {
        console.error(`Failed to create ${def.name}:`, await createRes.text());
      } else {
        console.log(`Created ${def.name} successfully.`);
      }
    }
  }

  console.log('--- Channels sync completed successfully! ---');
}

async function main() {
  await ensureMaritalStatusAttribute();
  const users = await getAllUsers();
  await syncChannels(users);
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
