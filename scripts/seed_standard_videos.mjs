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

const standardVideos = [
  {
    id: 'vid_bible_study_methods',
    title: "I Searched for Real Worship... Then My Life Changed Forever | Comfort's Testimony",
    author: 'Comfort / ALIVE-Nigeria',
    category: 'Bible Study',
    language: 'en',
    duration: '14:22',
    description:
      'Comfort shares her powerful testimony with ALIVE-Nigeria of searching for authentic biblical worship, discovering Christ, and how truth transformed her life and purpose.',
    aspect_ratio: '16:9',
    video_url: 'https://youtu.be/5SRS-q6g2TE',
    thumbnail_url: 'https://img.youtube.com/vi/5SRS-q6g2TE/hqdefault.jpg',
    notes:
      "Comfort's personal testimony from ALIVE-Nigeria. Highlights the joy of finding biblical truth, surrendering to Jesus Christ, and sharing the Gospel across campuses and cities.",
    is_active: true,
  },
  {
    id: 'vid_reclaiming_gods_pattern',
    title: "God's gift of health - Rodney Bowes",
    author: 'Rodney Bowes',
    category: 'Health & Wholeness',
    language: 'en',
    duration: '43:50',
    description:
      "Brother Rodney Bowes presents God's timeless design for physical, mental, and spiritual health, showing how the health message acts as the entering wedge for the Gospel.",
    aspect_ratio: '16:9',
    video_url: 'https://youtu.be/NZjz4qSr6NQ',
    thumbnail_url: 'https://img.youtube.com/vi/NZjz4qSr6NQ/hqdefault.jpg',
    notes:
      "Core principles of God's design for health: nutrition, lifestyle restoration, disease prevention, and using health evangelism to open hearts for Christ.",
    is_active: true,
  },
];

async function seedVideos() {
  console.log('Updating standard videos in Appwrite collection `videos`...');
  for (const v of standardVideos) {
    const documentId = v.id;
    const body = {
      title: v.title,
      author: v.author,
      category: v.category,
      language: v.language,
      video_url: v.video_url,
      thumbnail_url: v.thumbnail_url,
      description: v.description,
      is_active: v.is_active,
      updated_at: new Date().toISOString(),
    };
    if (v.duration) body.duration = v.duration;
    if (v.aspect_ratio) body.aspect_ratio = v.aspect_ratio;
    if (v.notes) body.notes = v.notes;

    try {
      // First try to PATCH (update existing)
      const patchRes = await fetch(
        `${endpoint}/v1/databases/${databaseId}/collections/videos/documents/${documentId}`,
        {
          method: 'PATCH',
          headers,
          body: JSON.stringify({ data: body }),
        }
      );
      if (patchRes.ok) {
        console.log(`+ Updated video metadata: "${v.title}" (ID: ${documentId})`);
        continue;
      }

      // If document didn't exist, create it
      const createRes = await fetch(
        `${endpoint}/v1/databases/${databaseId}/collections/videos/documents`,
        {
          method: 'POST',
          headers,
          body: JSON.stringify({
            documentId,
            data: { ...body, created_at: new Date().toISOString() },
          }),
        }
      );
      const data = await createRes.json();
      if (createRes.ok) {
        console.log(`+ Created video: "${v.title}" (ID: ${documentId})`);
      } else {
        console.error(`! Error on "${v.title}":`, data.message || data);
      }
    } catch (e) {
      console.error(`! Network error updating "${v.title}":`, e.message);
    }
  }
  console.log('Video sync complete.');
}

seedVideos();
