import { AccessToken } from 'livekit-server-sdk';
import { Client, Messaging, ID } from 'node-appwrite';

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
  custom: { room: null, roles: null },
};

async function getRole(userId, req) {
  const endpoint = process.env.APPWRITE_ENDPOINT?.replace(/\/$/, '');
  const projectId = process.env.APPWRITE_PROJECT_ID;
  const databaseId = process.env.APPWRITE_DATABASE_ID;
  const apiKey =
    req.headers['x-appwrite-key'] ||
    process.env.APPWRITE_FUNCTION_API_KEY;
  const usersTableId = process.env.APPWRITE_USERS_TABLE_ID || '6a08943100226f5b4963';
  if (!endpoint || !projectId || !databaseId || !apiKey || !usersTableId) {
    throw new Error('Private ALIVE Meet rooms are not configured for role verification.');
  }

  const headers = {
    'X-Appwrite-Project': projectId,
    'X-Appwrite-Key': apiKey,
  };

  // Try standard Appwrite Databases endpoint (collections/documents) first
  let response = await fetch(
    `${endpoint}/databases/${databaseId}/collections/${usersTableId}/documents/${encodeURIComponent(userId)}`,
    { headers },
  );

  // Fallback to TablesDB route if standard collections route returns 404
  if (response.status === 404) {
    const tableResponse = await fetch(
      `${endpoint}/tablesdb/${databaseId}/tables/${usersTableId}/rows/${encodeURIComponent(userId)}`,
      { headers },
    );
    if (tableResponse.ok) {
      response = tableResponse;
    }
  }

  if (!response.ok) {
    throw new Error(`Unable to verify ALIVE Meet role (${response.status}).`);
  }
  const profile = await response.json();
  return String(profile.role || 'member').trim().toLowerCase();
}

export default async ({ req, res, log, error }) => {
  if (req.method !== 'POST') return res.json({ error: 'Method not allowed. Use POST.' }, 405);

  try {
    const authenticatedUserId = req.headers['x-appwrite-user-id'];
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const { roomName, participantName, identity, meetingType = 'general', notifyMembers = false } = body;

    if (!authenticatedUserId) return res.json({ error: 'Authentication is required.' }, 401);
    if (!roomName || !identity) return res.json({ error: 'Invalid ALIVE Meet request.' }, 400);
    if (identity !== authenticatedUserId) return res.json({ error: 'Cannot create a token for another user.' }, 403);

    const targetRoom = String(roomName).trim();
    const policy = roomPolicies[meetingType] || roomPolicies.custom;

    let role = 'member';
    try {
      role = await getRole(authenticatedUserId, req);
    } catch (roleErr) {
      if (log) log(`Role lookup notice: ${roleErr.message}`);
    }

    const isAdmin = ['admin', 'bod', 'director', 'trustee'].includes(role);

    // Permission enforcement:
    // 1. Role-restricted rooms (e.g. board, leadership) require matching roles
    if (policy.roles && !policy.roles.includes(role)) {
      return res.json({ error: 'You do not have access to this ALIVE Meet room.' }, 403);
    }

    // 2. Fixed-room policy validation for non-admins
    if (policy.room && targetRoom !== policy.room && !isAdmin) {
      return res.json({ error: 'Invalid room for the requested ALIVE Meet type.' }, 403);
    }

    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET || process.env.LIVEKIT_SECRET;
    if (!apiKey || !apiSecret) return res.json({ error: 'ALIVE Meet is not configured.' }, 503);

    // Trigger push notification to members when an admin starts a meeting and requests member notification
    if (notifyMembers && isAdmin) {
      try {
        const endpoint = process.env.APPWRITE_ENDPOINT?.replace(/\/$/, '');
        const projectId = process.env.APPWRITE_PROJECT_ID;
        const serverApiKey = req.headers['x-appwrite-key'] || process.env.APPWRITE_FUNCTION_API_KEY;

        if (endpoint && projectId && serverApiKey) {
          const client = new Client()
            .setEndpoint(endpoint)
            .setProject(projectId)
            .setKey(serverApiKey);
          const messaging = new Messaging(client);
          const meetingTitle = body.meetingTitle || targetRoom;
          const host = participantName || 'An Admin';

          await messaging.createPush({
            messageId: ID.unique(),
            title: 'ALIVE Meet: Meeting Started',
            body: `${host} has started "${meetingTitle}". Tap to join now!`,
            topics: ['all_users'],
            data: {
              type: 'meeting_started',
              roomName: targetRoom,
              meetingType: meetingType,
            },
            draft: false,
          });
          if (log) log(`Meeting notification dispatched for room ${targetRoom}`);
        }
      } catch (pushErr) {
        if (error) error(`Failed to dispatch meeting start push notification: ${pushErr.message}`);
      }
    }

    const token = new AccessToken(apiKey, apiSecret, { identity, name: participantName || identity });
    token.addGrant({
      roomJoin: true,
      room: targetRoom,
      canPublish: true,
      canSubscribe: true,
      roomAdmin: ['admin', 'bod', 'trustee'].includes(role),
    });

    return res.json({
      token: await token.toJwt(),
      roomName: targetRoom,
    });
  } catch (err) {
    if (error) error(`ALIVE Meet token generation failed: ${err.message}`);
    return res.json({ error: 'ALIVE Meet is temporarily unavailable.' }, 503);
  }
};
