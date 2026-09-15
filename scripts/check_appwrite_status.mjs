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

const headers = {
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey,
  'Content-Type': 'application/json',
};

async function main() {
  const bRes = await fetch(endpoint + '/storage/buckets', { headers });
  const bData = await bRes.json();
  const bucket = bData.buckets.find(b => b.name.toLowerCase().includes('android'));
  console.log('Bucket:', bucket ? { id: bucket.$id, name: bucket.name } : 'Not found');
  if (bucket) {
    const fRes = await fetch(endpoint + `/storage/buckets/${bucket.$id}/files`, { headers });
    const fData = await fRes.json();
    console.log('Files in bucket:', fData.files.map(f => ({
      id: f.$id,
      name: f.name,
      sizeBytes: f.sizeOriginal,
      mimeType: f.mimeType
    })));
  }
}

main().catch(console.error);
