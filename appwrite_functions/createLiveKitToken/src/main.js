import { AccessToken } from 'livekit-server-sdk';

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

async function getRole(userId) {
  const endpoint = process.env.APPWRITE_ENDPOINT?.replace(/\/$/, '');
  const projectId = process.env.APPWRITE_PROJECT_ID;
  const databaseId = process.env.APPWRITE_DATABASE_ID;
  const apiKey = process.env.APPWRITE_FUNCTION_API_KEY;
  const usersTableId = process.env.APPWRITE_USERS_TABLE_ID;
  if (!endpoint || !projectId || !databaseId || !apiKey || !usersTableId) {
    throw new Error('Private ALIVE Meet rooms are not configured for role verification.');
  }

  const response = await fetch(
    `${endpoint}/tablesdb/${databaseId}/tables/${usersTableId}/rows/${encodeURIComponent(userId)}`,
    { headers: { 'X-Appwrite-Project': projectId, 'X-Appwrite-Key': apiKey } },
  );
  if (!response.ok) {
    throw new Error(`Unable to verify ALIVE Meet role (${response.status}).`);
  }
  const profile = await response.json();
  return String(profile.role || 'member').trim().toLowerCase();
}

export default async ({ req, res, error }) => {
  if (req.method !== 'POST') return res.json({ error: 'Method not allowed. Use POST.' }, 405);

  try {
    const authenticatedUserId = req.headers['x-appwrite-user-id'];
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const { roomName, participantName, identity, meetingType = 'general' } = body;
    const policy = roomPolicies[meetingType];

    if (!authenticatedUserId) return res.json({ error: 'Authentication is required.' }, 401);
    if (!roomName || !identity || !policy) return res.json({ error: 'Invalid ALIVE Meet request.' }, 400);
    if (identity !== authenticatedUserId) return res.json({ error: 'Cannot create a token for another user.' }, 403);
    if (roomName !== policy.room) return res.json({ error: 'Invalid room for the requested ALIVE Meet type.' }, 403);

    let role = 'member';
    if (policy.roles) {
      role = await getRole(authenticatedUserId);
      if (!policy.roles.includes(role)) return res.json({ error: 'You do not have access to this ALIVE Meet room.' }, 403);
    }

    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET || process.env.LIVEKIT_SECRET;
    if (!apiKey || !apiSecret) return res.json({ error: 'ALIVE Meet is not configured.' }, 503);

    const token = new AccessToken(apiKey, apiSecret, { identity, name: participantName || identity });
    token.addGrant({
      roomJoin: true,
      room: policy.room,
      canPublish: true,
      canSubscribe: true,
      roomAdmin: ['admin', 'bod', 'trustee'].includes(role),
    });
    return res.json({ token: await token.toJwt() });
  } catch (err) {
    error(`ALIVE Meet token generation failed: ${err.message}`);
    return res.json({ error: 'ALIVE Meet is temporarily unavailable.' }, 503);
  }
};