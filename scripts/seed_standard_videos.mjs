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
    title: 'Bible Study Methods: Discovering Truth in Scripture',
    author: 'ALIVE Media',
    category: 'Bible Study',
    language: 'en',
    duration: '18:30',
    description:
      'A comprehensive biblical guide to studying Scripture with authentic context, cross-referencing, and prayerful reflection. Learn inductive study methods and personal devotional depth.',
    aspect_ratio: '16:9',
    video_url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    thumbnail_url:
      'https://images.unsplash.com/photo-1507692049790-de58290a4334?q=80&w=870&auto=format&fit=crop',
    notes:
      "Key takeaways: 1. Pray before opening God's Word. 2. Observe historical context. 3. Correlate with Spirit of Prophecy and Scripture cross-references. 4. Apply directly to daily Christian life.",
    is_active: true,
  },
  {
    id: 'vid_reclaiming_gods_pattern',
    title: "Reclaiming God's Pattern: The Biblical Strategy for Mission",
    author: 'Pastor Agana',
    category: 'MEC',
    language: 'en',
    duration: '48:15',
    description:
      "Presented at the Alive Nigeria Mission Empowerment Conference 2019, 'All or Nothing,' in Owerri, Nigeria. Explores God's blueprint for reaching the unreached through centers of influence and consecrated professional talent.",
    aspect_ratio: '16:9',
    video_url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    thumbnail_url:
      'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?q=80&w=870&auto=format&fit=crop',
    notes:
      "Key points: Biblical tour of W3 evangelism; reaching higher classes first to mobilize resources for the wider population; Adam and Eve's surrendered dominion restored through the Gospel.",
    is_active: true,
  },
  {
    id: 'vid_ministry_of_healing',
    title: 'The Ministry of Healing: Medical Missionary Evangelism',
    author: 'ALIVE Health Ministry',
    category: 'Health & Wholeness',
    language: 'en',
    duration: '24:40',
    description:
      'Discover how plant-based nutrition, natural therapeutic remedies, and compassionate health outreach serve as the right arm of the Gospel message across Nigerian communities.',
    aspect_ratio: '16:9',
    video_url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    thumbnail_url:
      'https://images.unsplash.com/photo-1498837167922-ddd27525d352?q=80&w=870&auto=format&fit=crop',
    notes:
      'Core Principles: NEWSTART (Nutrition, Exercise, Water, Sunlight, Temperance, Air, Rest, Trust in Divine Power). Practical plant-based demonstrations included.',
    is_active: true,
  },
];

async function seedVideos() {
  console.log('Seeding standard videos into Appwrite collection `videos`...');
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
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    // Include optional fields if already active
    if (v.duration) body.duration = v.duration;
    if (v.aspect_ratio) body.aspect_ratio = v.aspect_ratio;
    if (v.notes) body.notes = v.notes;

    try {
      const res = await fetch(
        `${endpoint}/v1/databases/${databaseId}/collections/videos/documents`,
        {
          method: 'POST',
          headers,
          body: JSON.stringify({ documentId, data: body }),
        }
      );
      const data = await res.json();
      if (res.ok) {
        console.log(`+ Created video: "${v.title}" (ID: ${documentId})`);
      } else if (res.status === 409) {
        console.log(`= Video already exists: "${v.title}" (ID: ${documentId})`);
      } else {
        console.error(`! Error creating "${v.title}":`, data.message || data);
      }
    } catch (e) {
      console.error(`! Network error creating "${v.title}":`, e.message);
    }
  }
  console.log('Video seeding complete.');
}

seedVideos();

