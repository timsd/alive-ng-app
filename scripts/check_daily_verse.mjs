import fs from 'fs';

const env = Object.fromEntries(
  fs.readFileSync('.env', 'utf8')
    .split('\n')
    .filter(l => l.includes('=') && !l.startsWith('#'))
    .map(l => {
      const idx = l.indexOf('=');
      return [l.slice(0, idx).trim(), l.slice(idx + 1).trim()];
    })
);

const endpoint = env.APPWRITE_ENDPOINT || 'https://api.alivenigeria.org/v1';
const projectId = env.APPWRITE_PROJECT_ID;
const apiKey = env.APPWRITE_API_KEY;
const databaseId = env.APPWRITE_DATABASE_ID || '6a089307002e54291a32';

async function main() {
  const headers = {
    'X-Appwrite-Project': projectId,
    'X-Appwrite-Key': apiKey,
    'Content-Type': 'application/json',
  };

  const cRes = await fetch(`${endpoint}/databases/${databaseId}/collections`, { headers });
  const cData = await cRes.json();
  console.log('All collections:', (cData.collections || []).map(c => ({ id: c.$id, name: c.name })));

  if (dv) {
    const dRes = await fetch(`${endpoint}/databases/${databaseId}/collections/${dv.$id}/documents`, { headers });
    const dData = await dRes.json();
    console.log('Total documents:', dData.total);
    console.log('Recent verses:', (dData.documents || []).slice(0, 5).map(d => ({
      id: d.$id,
      date: d.date,
      ref: d.reference,
      verse: d.verse?.slice(0, 50)
    })));
  }
}

main().catch(console.error);
