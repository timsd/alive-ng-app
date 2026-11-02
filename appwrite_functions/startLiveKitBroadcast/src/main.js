import { EgressClient } from 'livekit-server-sdk';

const SERVICE_URL = (process.env.LIVEKIT_URL || 'wss://livekit.alivenigeria.org')
  .replace(/\/$/, '');
const YOUTUBE_INGEST = 'rtmp://a.rtmp.youtube.com/live2';

const roomPolicies = {
  general: { room: 'alive-meet-community', roles: null },
  prayer: { room: 'alive-meet-prayer', roles: null },
  leadership: {
    room: 'alive-meet-leadership',
    roles: ['coordinator', 'leader', 'director', 'bod', 'trustee', 'admin'],
  },
  board: {
    room: 'alive-meet-board',
    roles: ['director', 'bod', 'trustee', 'admin'],
  },
};

// Users with these roles may Go Live to YouTube.
const BROADCAST_ROLES = ['director', 'bod', 'trustee', 'leader', 'coordinator', 'admin'];

async function getRole(userId, req) {
  const endpoint = process.env.APPWRITE_ENDPOINT?.replace(/\/$/, '');
  const projectId = process.env.APPWRITE_PROJECT_ID;
  const databaseId = process.env.APPWRITE_DATABASE_ID;
  const apiKey =
    req?.headers?.['x-appwrite-key'] ||
    process.env.APPWRITE_FUNCTION_API_KEY;
  const usersTableId = process.env.APPWRITE_USERS_TABLE_ID || '6a08943100226f5b4963';
  if (!endpoint || !projectId || !databaseId || !apiKey || !usersTableId) {
    throw new Error('Broadcast role verification is not configured.');
  }
  const headers = {
    'X-Appwrite-Project': projectId,
    'X-Appwrite-Key': apiKey,
  };

  let response = await fetch(
    `${endpoint}/databases/${databaseId}/collections/${usersTableId}/documents/${encodeURIComponent(userId)}`,
    { headers },
  );
  if (response.status === 404) {
    const tableResponse = await fetch(
      `${endpoint}/tablesdb/${databaseId}/tables/${usersTableId}/rows/${encodeURIComponent(userId)}`,
      { headers },
    );
    if (tableResponse.ok) response = tableResponse;
  }
  if (!response.ok) throw new Error(`Unable to verify broadcast role (${response.status}).`);
  const profile = await response.json();
  const role = String(profile.role || 'member').trim().toLowerCase();
  const email = String(profile.email || '').trim().toLowerCase();
  const superAdminEmails = (process.env.APPWRITE_SUPER_ADMIN_EMAILS || '')
    .toLowerCase()
    .split(',')
    .map((e) => e.trim())
    .filter(Boolean);
  if (superAdminEmails.includes(email)) {
    return 'admin';
  }
  return role;
}

export default async ({ req, res, error }) => {
  if (req.method !== 'POST') return res.json({ error: 'Method not allowed. Use POST.' }, 405);

  try {
    const userId = req.headers['x-appwrite-user-id'];
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const { action, meetingType = 'general', egressId } = body;

    if (!userId) return res.json({ error: 'Authentication is required.' }, 401);

    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET || process.env.LIVEKIT_SECRET;
    if (!apiKey || !apiSecret) return res.json({ error: 'Broadcast is not configured.' }, 503);

    const egress = new EgressClient(SERVICE_URL, apiKey, apiSecret);

    if (action === 'stop') {
      if (!egressId) return res.json({ error: 'egressId is required to stop.' }, 400);
      await egress.stopEgress(egressId);
      return res.json({ status: 'stopped', egressId });
    }

    if (action === 'list') {
      const egresses = await egress.listEgress();
      return res.json({ egresses });
    }

    // 'start' (default) path.
    const streamKey = body.streamKey || process.env.YOUTUBE_STREAM_KEY;
    if (!streamKey) return res.json({ error: 'YouTube stream key is not configured.' }, 503);

    // Verify user role
    let role = 'member';
    try {
      role = await getRole(userId, req);
    } catch (err) {
      if (error) error(`Role lookup notice: ${err.message}`);
    }

    if (!BROADCAST_ROLES.includes(role)) {
      return res.json({ error: 'You do not have permission to broadcast.' }, 403);
    }

    const policy = roomPolicies[meetingType];
    const targetRoom = body.roomName || (policy ? policy.room : null) || 'alive-meet-community';

    // If room policy has role restrictions, ensure user has access to that room
    if (policy && policy.roles && !policy.roles.includes(role)) {
      return res.json({ error: 'You do not have permission to broadcast from this room.' }, 403);
    }

    const ingestUrl = (process.env.YOUTUBE_STREAM_URL || YOUTUBE_INGEST).replace(/\/$/, '');
    const urls = [`${ingestUrl}/${streamKey}`];

    if (process.env.YOUTUBE_BACKUP_STREAM_URL) {
      const backupUrl = process.env.YOUTUBE_BACKUP_STREAM_URL.replace(/\/$/, '');
      urls.push(`${backupUrl}/${streamKey}`);
    }

    const egressInfo = await egress.startRoomCompositeEgress(
      targetRoom,
      {
        stream: {
          urls: urls,
        },
      },
      {
        layout: 'speaker-layout',
      },
    );

    const egressIdOut = egressInfo.egressId || (typeof egressInfo === 'string' ? egressInfo : JSON.stringify(egressInfo));
    return res.json({ egressId: egressIdOut, status: 'started', roomName: targetRoom });
  } catch (err) {
    error(`Broadcast failed: ${err.message}`);
    return res.json({ error: `Broadcast failed: ${err.message}` }, 503);
  }
};
