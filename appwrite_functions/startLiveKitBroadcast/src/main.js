import { EgressClient } from 'livekit-server-sdk';

const rawServiceUrl = (process.env.LIVEKIT_URL || 'https://livekit.alivenigeria.org')
  .replace(/^ws:\/\//, 'http://')
  .replace(/^wss:\/\//, 'https://')
  .replace(/\/$/, '');
const SERVICE_URL = rawServiceUrl;
const YOUTUBE_INGEST = 'rtmp://a.rtmp.youtube.com/live2';
const FACEBOOK_INGEST = 'rtmps://live-api-s.facebook.com:443/rtmp';

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

async function getStreamingSettings(req) {
  const endpoint = process.env.APPWRITE_ENDPOINT?.replace(/\/$/, '');
  const projectId = process.env.APPWRITE_PROJECT_ID;
  const databaseId = process.env.APPWRITE_DATABASE_ID;
  const apiKey =
    req?.headers?.['x-appwrite-key'] ||
    process.env.APPWRITE_FUNCTION_API_KEY;
  const settingsTableId = process.env.APPWRITE_APP_SETTINGS_TABLE_ID || 'app_settings';
  if (!endpoint || !projectId || !databaseId || !apiKey) {
    return {};
  }
  const headers = {
    'X-Appwrite-Project': projectId,
    'X-Appwrite-Key': apiKey,
  };
  let response = await fetch(
    `${endpoint}/tablesdb/${databaseId}/tables/${settingsTableId}/rows?queries[0]=${encodeURIComponent('{"method":"limit","values":[200]}')}`,
    { headers },
  );
  if (!response.ok) {
    response = await fetch(
      `${endpoint}/databases/${databaseId}/collections/${settingsTableId}/documents`,
      { headers },
    );
  }
  if (!response.ok) {
    return {};
  }
  const payload = await response.json();
  const rows = payload.rows || payload.documents || [];
  const map = {};
  for (const row of rows) {
    const key = String(row.setting_key || row.key || '').trim();
    if (!key) continue;
    map[key] = String(row.setting_value ?? row.value ?? '').trim();
  }
  return map;
}

export default async ({ req, res, error }) => {
  if (req.method !== 'POST') return res.json({ error: 'Method not allowed. Use POST.' }, 405);

  try {
    const userId = req.headers['x-appwrite-user-id'];
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const { action, meetingType = 'general', egressId } = body;

    if (!userId) return res.json({ error: 'Authentication is required.' }, 401);

    const apiKey = (process.env.LIVEKIT_API_KEY || '').trim();
    const apiSecret = (process.env.LIVEKIT_API_SECRET || process.env.LIVEKIT_SECRET || '').trim();
    if (!apiKey || !apiSecret) {
      return res.json({
        error: 'Live broadcast is not configured: LIVEKIT_API_KEY or LIVEKIT_API_SECRET is missing.'
      }, 503);
    }

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
    const settings = await getStreamingSettings(req);
    const rawPlatformMode = String(
      body.platforms || settings.streaming_platforms || 'youtube',
    )
      .trim()
      .toLowerCase();
    const platformMode = ['youtube', 'facebook', 'both'].includes(rawPlatformMode)
      ? rawPlatformMode
      : 'youtube';

    const youtubeKey = String(
      body.youtubeStreamKey ||
        body.streamKey ||
        settings.youtube_stream_key ||
        process.env.YOUTUBE_STREAM_KEY ||
        '',
    ).trim();
    const youtubeUrl = String(
      settings.youtube_stream_url ||
        process.env.YOUTUBE_STREAM_URL ||
        YOUTUBE_INGEST,
    )
      .trim()
      .replace(/\/$/, '');

    const facebookKey = String(
      body.facebookStreamKey ||
        settings.facebook_stream_key ||
        process.env.FACEBOOK_STREAM_KEY ||
        '',
    ).trim();
    const facebookUrl = String(
      settings.facebook_stream_url ||
        process.env.FACEBOOK_STREAM_URL ||
        FACEBOOK_INGEST,
    )
      .trim()
      .replace(/\/$/, '');

    const wantsYouTube = platformMode === 'youtube' || platformMode === 'both';
    const wantsFacebook = platformMode === 'facebook' || platformMode === 'both';

    if (platformMode === 'youtube' && !youtubeKey) {
      return res.json(
        { error: 'YouTube stream key is not configured in Admin App Settings.' },
        503,
      );
    }
    if (platformMode === 'facebook' && !facebookKey) {
      return res.json(
        { error: 'Facebook stream key is not configured in Admin App Settings.' },
        503,
      );
    }

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

    const urls = [];
    const activePlatforms = [];

    if (wantsYouTube && youtubeKey) {
      urls.push(`${youtubeUrl}/${youtubeKey}`);
      if (process.env.YOUTUBE_BACKUP_STREAM_URL) {
        const backupUrl = process.env.YOUTUBE_BACKUP_STREAM_URL.replace(/\/$/, '');
        urls.push(`${backupUrl}/${youtubeKey}`);
      }
      activePlatforms.push('youtube');
    }

    if (wantsFacebook && facebookKey) {
      urls.push(`${facebookUrl}/${facebookKey}`);
      activePlatforms.push('facebook');
    }

    if (urls.length === 0) {
      return res.json(
        { error: 'No streaming keys are configured in Admin App Settings.' },
        503,
      );
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
    return res.json({
      egressId: egressIdOut,
      status: 'started',
      roomName: targetRoom,
      platforms: activePlatforms,
    });
  } catch (err) {
    error(`Broadcast failed: ${err.message}`);
    const errMsg = err.message || 'unknown error';
    if (errMsg.toLowerCase().includes('invalid api key') || errMsg.toLowerCase().includes('unauthorized')) {
      return res.json({
        error: 'Broadcast failed: LiveKit streaming API key or secret is invalid on the server. Please verify LIVEKIT_API_KEY and LIVEKIT_API_SECRET in Appwrite and LiveKit server settings.'
      }, 503);
    }
    return res.json({ error: `Broadcast failed: ${errMsg}` }, 503);
  }
};
