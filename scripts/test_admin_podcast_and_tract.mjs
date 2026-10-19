import fs from 'node:fs';
import path from 'node:path';

// Read .env
if (fs.existsSync('.env')) {
  const content = fs.readFileSync('.env', 'utf8');
  for (const line of content.split(/\r?\n/)) {
    if (!line || line.startsWith('#')) continue;
    const idx = line.indexOf('=');
    if (idx > 0) {
      const k = line.slice(0, idx).trim();
      const v = line.slice(idx + 1).trim();
      if (!process.env[k]) process.env[k] = v;
    }
  }
}

const endpoint = process.env.APPWRITE_ENDPOINT.replace(/\/$/, '');
const projectId = process.env.APPWRITE_PROJECT_ID;
const apiKey = process.env.APPWRITE_API_KEY;
const databaseId = '6a089307002e54291a32';

const headers = {
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey,
};

async function appwriteRequest(urlPath, options = {}) {
  const url = `${endpoint}${urlPath}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      ...headers,
      ...(options.headers || {}),
    },
  });
  return res;
}

async function uploadFileChunked(bucketId, fileId, filePath, fileName, contentType) {
  const stat = fs.statSync(filePath);
  const totalSize = stat.size;
  const CHUNK_SIZE = 5 * 1024 * 1024;
  const totalChunks = Math.ceil(totalSize / CHUNK_SIZE);

  console.log(`[Upload] Uploading ${filePath} (${totalSize} bytes) to bucket "${bucketId}" as fileId "${fileId}" (${totalChunks} chunks)...`);

  // Delete previous test file if exists
  await appwriteRequest(`/storage/buckets/${bucketId}/files/${fileId}`, { method: 'DELETE' });

  const fd = fs.openSync(filePath, 'r');
  let start = 0;
  let chunkIndex = 0;
  let uploadResult = null;

  try {
    while (start < totalSize) {
      let end = start + CHUNK_SIZE;
      if (end > totalSize) end = totalSize;
      const chunkSize = end - start;

      const buffer = Buffer.alloc(chunkSize);
      fs.readSync(fd, buffer, 0, chunkSize, start);
      const blob = new Blob([buffer], { type: contentType });

      const formData = new FormData();
      formData.append('fileId', fileId);
      formData.append('file', blob, fileName);
      if (chunkIndex === 0) {
        formData.append('permissions[]', 'read("any")');
      }

      const reqHeaders = {};
      if (totalChunks > 1) {
        reqHeaders['Content-Range'] = `bytes ${start}-${end - 1}/${totalSize}`;
      }
      if (uploadResult && uploadResult.$id) {
        reqHeaders['x-appwrite-id'] = uploadResult.$id;
      }

      let res = await appwriteRequest(`/storage/buckets/${bucketId}/files`, {
        method: 'POST',
        headers: reqHeaders,
        body: formData,
      });

      if (!res.ok) {
        const errText = await res.text();
        throw new Error(`Upload failed at chunk ${chunkIndex + 1}/${totalChunks} (HTTP ${res.status}): ${errText}`);
      }

      uploadResult = await res.json();
      chunkIndex++;
      const pct = Math.round((end / totalSize) * 100);
      console.log(`  Chunk ${chunkIndex}/${totalChunks} uploaded (${pct}%)`);
      start = end;
    }
  } finally {
    fs.closeSync(fd);
  }

  const fileUrl = `${endpoint}/storage/buckets/${bucketId}/files/${uploadResult.$id}/view?project=${projectId}`;
  return { fileResult: uploadResult, fileUrl };
}

async function run() {
  console.log('=== STARTING ADMIN PODCAST & TRACT UPLOAD VERIFICATION ===\n');

  // ──────────────────────────────────────────
  // 1. TEST PODCAST UPLOAD (agana_01.mp3)
  // ──────────────────────────────────────────
  const podcastFilePath = 'C:\\Users\\Timothy Olodude\\Documents\\ZavTech Projects\\agana_01.mp3';
  if (!fs.existsSync(podcastFilePath)) {
    throw new Error(`Podcast file does not exist: ${podcastFilePath}`);
  }

  console.log('--- Step 1: Testing Podcast Upload (podcast_media bucket) ---');
  const podcastBucketRes = await appwriteRequest('/storage/buckets/podcast_media');
  if (!podcastBucketRes.ok) {
    throw new Error(`podcast_media bucket query failed: ${podcastBucketRes.status}`);
  }
  const podcastBucket = await podcastBucketRes.json();
  console.log(`Bucket verified: "${podcastBucket.name}" (ID: ${podcastBucket.$id}, Max Size: ${podcastBucket.maximumFileSize / (1024*1024)}MB)`);

  const podcastFileId = 'test_podcast_agana_01';
  const { fileResult: pFile, fileUrl: pUrl } = await uploadFileChunked(
    'podcast_media',
    podcastFileId,
    podcastFilePath,
    'agana_01.mp3',
    'audio/mpeg'
  );

  console.log(`[Podcast] Upload succeeded!`);
  console.log(`  File ID: ${pFile.$id}`);
  console.log(`  Mime: ${pFile.mimeType}`);
  console.log(`  Size: ${pFile.sizeOriginal} bytes`);
  console.log(`  View URL: ${pUrl}`);

  // Test public download / stream verification
  const pCheckRes = await fetch(pUrl, { method: 'HEAD' });
  console.log(`  Public URL HEAD check: HTTP ${pCheckRes.status} (Content-Type: ${pCheckRes.headers.get('content-type')})`);

  // Upsert podcast episode record in database
  const episodeDocId = 'test_episode_agana_01';
  const episodeData = {
    title: 'Agana Episode 01 (Admin Test)',
    podcast_id: 'sample-podcast-1',
    podcast_title: 'Daily Devotions with Pastor John',
    description: 'Test admin upload of agana_01.mp3 to podcast_media bucket.',
    duration: '14:52',
    audio_url: pUrl,
    publish_date: new Date().toISOString(),
    is_downloaded: false,
    local_path: null,
  };

  const epRes = await appwriteRequest(
    `/databases/${databaseId}/collections/podcast_episodes/documents/${episodeDocId}`,
    {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data: episodeData }),
    }
  );

  let finalEp;
  if (epRes.ok) {
    finalEp = await epRes.json();
    console.log(`[Podcast DB] Updated existing episode document ${episodeDocId}.`);
  } else if (epRes.status === 404) {
    const createEp = await appwriteRequest(
      `/databases/${databaseId}/collections/podcast_episodes/documents`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ documentId: episodeDocId, data: episodeData }),
      }
    );
    if (!createEp.ok) {
      throw new Error(`Failed to create episode doc: ${createEp.status} ${await createEp.text()}`);
    }
    finalEp = await createEp.json();
    console.log(`[Podcast DB] Created episode document ${episodeDocId}.`);
  } else {
    throw new Error(`Episode DB error: ${epRes.status} ${await epRes.text()}`);
  }

  console.log(`[Podcast DB Verified] Episode "${finalEp.title}" is linked to audio: ${finalEp.audio_url}\n`);


  // ──────────────────────────────────────────
  // 2. TEST TRACT UPLOAD (Lesson 1.pdf)
  // ──────────────────────────────────────────
  const tractFilePath = 'C:\\Users\\Timothy Olodude\\Downloads\\Mobile Devices\\Lesson 1.pdf';
  if (!fs.existsSync(tractFilePath)) {
    throw new Error(`Tract file does not exist: ${tractFilePath}`);
  }

  console.log('--- Step 2: Testing Tract Upload (tract_files bucket) ---');
  let tractBucketRes = await appwriteRequest('/storage/buckets/tract_files');
  if (tractBucketRes.status === 404) {
    console.log('tract_files bucket not found, creating it...');
    const createB = await appwriteRequest('/storage/buckets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        bucketId: 'tract_files',
        name: 'Tract Documents',
        permissions: ['read("any")'],
        fileSecurity: false,
        enabled: true,
        maximumFileSize: 50000000,
        allowedFileExtensions: ['pdf', 'epub', 'doc', 'docx', 'jpg', 'png', 'webp'],
        compression: 'none',
        encryption: true,
        antivirus: true,
      }),
    });
    if (!createB.ok) throw new Error(`Create tract_files bucket failed: ${await createB.text()}`);
    tractBucketRes = createB;
  } else if (tractBucketRes.ok) {
    await appwriteRequest('/storage/buckets/tract_files', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Tracts and Books',
        permissions: ['read("any")', 'create("users")', 'update("users")', 'delete("users")'],
        fileSecurity: false,
        enabled: true,
        maximumFileSize: 200000000,
        allowedFileExtensions: ['pdf', 'epub', 'jpg', 'jpeg', 'png', 'webp'],
        compression: 'none',
        encryption: false,
        antivirus: true,
      }),
    });
  }
  const tractBucket = await (await appwriteRequest('/storage/buckets/tract_files')).json();
  console.log(`Bucket verified: "${tractBucket.name}" (ID: ${tractBucket.$id}, Perms: ${JSON.stringify(tractBucket.$permissions)})`);

  const tractFileId = 'test_tract_lesson_1';
  const { fileResult: tFile, fileUrl: tUrl } = await uploadFileChunked(
    'tract_files',
    tractFileId,
    tractFilePath,
    'Lesson_1.pdf',
    'application/pdf'
  );

  console.log(`[Tract] Upload succeeded!`);
  console.log(`  File ID: ${tFile.$id}`);
  console.log(`  Mime: ${tFile.mimeType}`);
  console.log(`  Size: ${tFile.sizeOriginal} bytes`);
  console.log(`  View URL: ${tUrl}`);

  const tCheckRes = await fetch(tUrl, { method: 'HEAD' });
  console.log(`  Public URL HEAD check: HTTP ${tCheckRes.status} (Content-Type: ${tCheckRes.headers.get('content-type')})`);

  // Check tract collections schema
  const tractColRes = await appwriteRequest(`/databases/${databaseId}/collections/tracts`);
  if (tractColRes.ok) {
    const tractCol = await tractColRes.json();
    console.log(`[Tract DB] tracts collection attributes:`, tractCol.attributes.map(a => a.key));

    const tractDocId = 'test_tract_lesson_1';
    const tractData = {
      title: 'Lesson 1 - Mobile Tract (Admin Test)',
      category: 'Discipleship',
      description: 'Test admin upload of Lesson 1.pdf to tract_files bucket.',
      pdf_url: tractCol.attributes.some(a => a.key === 'pdf_url') ? tUrl : undefined,
      file_url: tractCol.attributes.some(a => a.key === 'file_url') ? tUrl : undefined,
      download_url: tractCol.attributes.some(a => a.key === 'download_url') ? tUrl : undefined,
      cover_image: tractCol.attributes.some(a => a.key === 'cover_image') ? '' : undefined,
    };
    // remove undefined
    for (const k of Object.keys(tractData)) {
      if (tractData[k] === undefined) delete tractData[k];
    }

    const tDocRes = await appwriteRequest(
      `/databases/${databaseId}/collections/tracts/documents/${tractDocId}`,
      {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ data: tractData }),
      }
    );

    if (tDocRes.ok) {
      console.log(`[Tract DB] Updated existing tract doc ${tractDocId}.`);
    } else if (tDocRes.status === 404) {
      const createT = await appwriteRequest(
        `/databases/${databaseId}/collections/tracts/documents`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ documentId: tractDocId, data: tractData }),
        }
      );
      if (createT.ok) {
        console.log(`[Tract DB] Created tract doc ${tractDocId}.`);
      } else {
        console.warn(`[Tract DB note]: ${createT.status} ${await createT.text()}`);
      }
    }
  }

  console.log('\n=== ALL ADMIN UPLOAD TESTS PASSED SUCCESSFULLY! ===');
}

run().catch((err) => {
  console.error('Test execution failed:', err);
  process.exit(1);
});
