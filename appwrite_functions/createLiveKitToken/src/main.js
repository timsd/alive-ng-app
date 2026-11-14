import { AccessToken, RoomServiceClient } from 'livekit-server-sdk';
import { Client, Messaging, ID } from 'node-appwrite';

const rawServiceUrl = (process.env.LIVEKIT_URL || 'https://livekit.alivenigeria.org')
  .replace(/^ws:\/\//, 'http://')
  .replace(/^wss:\/\//, 'https://')
  .replace(/\/$/, '');

function formatRoomDisplayName(roomName, metadataStr) {
  if (metadataStr) {
    try {
      const meta = JSON.parse(metadataStr);
      if (meta && meta.title) return String(meta.title);
    } catch (_) {}
  }
  if (roomName === 'alive-meet-community') return 'General Meeting Room';
  if (roomName === 'alive-meet-prayer') return 'Prayer Room Meeting';
  if (roomName === 'alive-meet-quick') return 'Quick Meeting Room';
  if (roomName === 'alive-meet-leadership') return 'Leadership Meeting';
  if (roomName === 'alive-meet-board' || roomName.startsWith('board-meeting-')) {
    return 'Board of Directors Meeting';
  }
  return roomName
    .replace(/^alive-meet-/, '')
    .replace(/[-_]+/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function inferMeetingType(roomName) {
  if (roomName === 'alive-meet-board' || roomName.startsWith('board-meeting-')) return 'board';
  if (roomName === 'alive-meet-leadership') return 'leadership';
  if (roomName === 'alive-meet-prayer') return 'prayer';
  if (roomName === 'alive-meet-quick') return 'quick';
  return 'general';
}

const roomPolicies = {
  general: { room: 'alive-meet-community', roles: null },
  prayer: { room: 'alive-meet-prayer', roles: null },
  quick: { room: 'alive-meet-quick', roles: null },
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

async function getTargetUsers(endpoint, projectId, databaseId, serverApiKey, usersTableId, targetAudience, targetChapter) {
  if (targetAudience === 'general') return { users: [], topics: ['all_users'] };

  const headers = {
    'X-Appwrite-Project': projectId,
    'X-Appwrite-Key': serverApiKey,
  };

  let rows = [];
  try {
    let res = await fetch(
      `${endpoint}/databases/${databaseId}/collections/${usersTableId}/documents?limit=250`,
      { headers },
    );
    if (res.status === 404) {
      res = await fetch(
        `${endpoint}/tablesdb/${databaseId}/tables/${usersTableId}/rows?limit=250`,
        { headers },
      );
    }
    if (res.ok) {
      const data = await res.json();
      rows = data.documents || data.rows || [];
    }
  } catch (e) {
    // If user listing fails, fall back to topic
  }

  const norm = (s) => String(s || '').trim().toLowerCase();
  let matchedIds = [];
  let topics = [];

  switch (targetAudience) {
    case 'chapter': {
      const chapterQuery = norm(targetChapter);
      const chapterSlug = chapterQuery.replace(/[^a-z0-9]/g, '_');
      topics = chapterSlug ? [`chapter_${chapterSlug}`] : ['all_users'];
      matchedIds = rows
        .filter((r) => {
          const chId = norm(r.chapter_id || r.chapterId);
          const localCh = norm(r.local_chapter || r.localChapter);
          return chId === chapterQuery || localCh === chapterQuery || chId.includes(chapterQuery) || localCh.includes(chapterQuery);
        })
        .map((r) => r.$id || r.id);
      break;
    }
    case 'singles': {
      topics = ['singles', 'fellowship_singles'];
      matchedIds = rows
        .filter((r) => norm(r.marital_status || r.maritalStatus) === 'single')
        .map((r) => r.$id || r.id);
      break;
    }
    case 'married':
    case 'couples':
    case 'channel_married': {
      topics = ['married', 'fellowship_married', 'couples'];
      matchedIds = rows
        .filter((r) => ['married', 'couple'].includes(norm(r.marital_status || r.maritalStatus)))
        .map((r) => r.$id || r.id);
      break;
    }
    case 'directors': {
      topics = ['directors'];
      matchedIds = rows
        .filter((r) => ['director', 'admin'].includes(norm(r.role)))
        .map((r) => r.$id || r.id);
      break;
    }
    case 'bod_only': {
      topics = ['bod', 'board_only'];
      matchedIds = rows
        .filter((r) => ['bod', 'admin'].includes(norm(r.role)) || (Array.isArray(r.roles) && r.roles.map(norm).includes('bod')))
        .map((r) => r.$id || r.id);
      break;
    }
    case 'board':
    case 'bod': {
      topics = ['board', 'bod'];
      matchedIds = rows
        .filter((r) => ['bod', 'trustee', 'admin'].includes(norm(r.role)) || (Array.isArray(r.roles) && (r.roles.map(norm).includes('bod') || r.roles.map(norm).includes('trustee'))))
        .map((r) => r.$id || r.id);
      break;
    }
    case 'leadership': {
      topics = ['leadership'];
      matchedIds = rows
        .filter((r) => ['coordinator', 'leader', 'director', 'bod', 'trustee', 'admin'].includes(norm(r.role)))
        .map((r) => r.$id || r.id);
      break;
    }
    default: {
      if (targetAudience && (targetAudience.startsWith('channel_') || targetAudience.length === 20)) {
        const channelId = targetAudience;
        const channelSlug = channelId.replace(/[^a-z0-9]/g, '_');
        topics = [`channel_${channelSlug}`];
        try {
          const chatChannelsTableId = '6a08f1c70032affbc00d';
          let chRes = await fetch(
            `${endpoint}/databases/${databaseId}/collections/${chatChannelsTableId}/documents/${channelId}`,
            { headers }
          );
          if (chRes.status === 404) {
            chRes = await fetch(
              `${endpoint}/tablesdb/${databaseId}/tables/${chatChannelsTableId}/rows/${channelId}`,
              { headers }
            );
          }
          if (chRes.ok) {
            const chData = await chRes.json();
            const members = Array.isArray(chData.members) ? chData.members : [];
            matchedIds = members;
          }
        } catch (chErr) {
          // Fall back to channel topic
        }
      } else {
        topics = ['all_users'];
      }
      break;
    }
  }

  return { users: matchedIds.slice(0, 100), topics };
}

export default async ({ req, res, log, error }) => {
  if (req.method !== 'POST') return res.json({ error: 'Method not allowed. Use POST.' }, 405);

  try {
    const isInternal = Boolean(req.headers['x-appwrite-key']);
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const authenticatedUserId = req.headers['x-appwrite-user-id'] || (isInternal ? body.identity : null) || body.identity;
    const { action, roomName, participantName, identity, meetingType = 'general', notifyMembers = false } = body;

    if (!authenticatedUserId) return res.json({ error: 'Authentication is required.' }, 401);

    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET || process.env.LIVEKIT_SECRET;
    if (!apiKey || !apiSecret) return res.json({ error: 'ALIVE Meet is not configured.' }, 503);

    let role = 'member';
    try {
      role = await getRole(authenticatedUserId, req);
    } catch (roleErr) {
      if (log) log(`Role lookup notice: ${roleErr.message}`);
    }

    // List active/ongoing LiveKit rooms so users can see ongoing meetings in ALIVE Meet
    if (action === 'listRooms') {
      try {
        const roomService = new RoomServiceClient(rawServiceUrl, apiKey, apiSecret);
        const liveRooms = await roomService.listRooms();
        const visibleRooms = (liveRooms || [])
          .filter((r) => {
            const name = String(r.name || '');
            if (!name || name.includes('--br-')) return false;
            const count = Number(r.numParticipants || 0);
            if (count <= 0) return false;
            if (name === 'alive-meet-board' || name.startsWith('board-meeting-')) {
              return ['director', 'bod', 'trustee', 'admin'].includes(role);
            }
            if (name === 'alive-meet-leadership') {
              return ['coordinator', 'leader', 'director', 'bod', 'trustee', 'admin'].includes(role);
            }
            return true;
          })
          .map((r) => ({
            roomName: r.name,
            displayName: formatRoomDisplayName(r.name, r.metadata),
            meetingType: inferMeetingType(r.name),
            numParticipants: Number(r.numParticipants || 0),
            createdAt: r.creationTime ? Number(r.creationTime) : null,
          }));
        return res.json({ rooms: visibleRooms });
      } catch (listErr) {
        if (log) log(`listRooms notice: ${listErr.message}`);
        return res.json({ rooms: [] });
      }
    }

    // Forcibly end and close a LiveKit room for all participants (any leader/admin)
    if (action === 'endRoom') {
      const target = String(roomName || '').trim();
      if (!target) {
        return res.json({ error: 'Room name is required.' }, 400);
      }
      const canEnd = ['coordinator', 'leader', 'director', 'bod', 'trustee', 'admin'].includes(role);
      if (!canEnd && !isInternal) {
        return res.json({ error: 'Only leaders and administrators can end a meeting for all.' }, 403);
      }
      try {
        const roomService = new RoomServiceClient(rawServiceUrl, apiKey, apiSecret);
        try {
          const liveRooms = await roomService.listRooms();
          const breakoutPrefix = `${target}--br-`;
          for (const r of liveRooms || []) {
            if (r.name && String(r.name).startsWith(breakoutPrefix)) {
              await roomService.deleteRoom(String(r.name)).catch(() => {});
            }
          }
        } catch (_) {}
        await roomService.deleteRoom(target);
        return res.json({ ok: true, endedRoom: target });
      } catch (endErr) {
        const msg = String(endErr?.message || endErr || '');
        if (msg.toLowerCase().includes('not found') || endErr?.status === 404) {
          return res.json({ ok: true, endedRoom: target, alreadyClosed: true });
        }
        if (log) log(`endRoom error: ${msg}`);
        return res.json({ error: 'Failed to close meeting room.' }, 500);
      }
    }

    if (!roomName || !identity) return res.json({ error: 'Invalid ALIVE Meet request.' }, 400);
    if (identity !== authenticatedUserId && !isInternal) return res.json({ error: 'Cannot create a token for another user.' }, 403);

    const targetRoom = String(roomName).trim();
    const policy = roomPolicies[meetingType] || roomPolicies.custom;

    const isLeader = ['admin', 'bod', 'director', 'trustee', 'leader', 'coordinator'].includes(role);
    const isAdmin = ['admin', 'bod', 'director', 'trustee'].includes(role);

    // Permission enforcement:
    // 1. Role-restricted rooms (e.g. board, leadership) require matching roles
    if (policy.roles && !policy.roles.includes(role)) {
      return res.json({ error: 'You do not have access to this ALIVE Meet room.' }, 403);
    }

    // 2. Fixed-room policy validation for non-leaders (only leaders can start arbitrary/custom rooms)
    if (policy.room && targetRoom !== policy.room && !isLeader) {
      return res.json({ error: 'Only ALIVE leaders and administrators can start new meeting rooms.' }, 403);
    }

    // Trigger targeted push notification when a leader/admin starts a meeting
    if (notifyMembers && isLeader) {
      try {
        const endpoint = process.env.APPWRITE_ENDPOINT?.replace(/\/$/, '');
        const projectId = process.env.APPWRITE_PROJECT_ID;
        const databaseId = process.env.APPWRITE_DATABASE_ID;
        const serverApiKey = req.headers['x-appwrite-key'] || process.env.APPWRITE_FUNCTION_API_KEY;
        const usersTableId = process.env.APPWRITE_USERS_TABLE_ID || '6a08943100226f5b4963';

        if (endpoint && projectId && databaseId && serverApiKey) {
          const client = new Client()
            .setEndpoint(endpoint)
            .setProject(projectId)
            .setKey(serverApiKey);
          const messaging = new Messaging(client);
          const meetingTitle = body.meetingTitle || targetRoom;
          const host = participantName || (isAdmin ? 'An Admin' : 'A Leader');

          const targetAudience = body.targetAudience || 'general';
          const targetChapter = body.targetChapter || '';
          const { users: targetUsers, topics: targetTopics } = await getTargetUsers(
            endpoint,
            projectId,
            databaseId,
            serverApiKey,
            usersTableId,
            targetAudience,
            targetChapter,
          );

          let notificationTitle = 'ALIVE Meet: Meeting Started';
          let notificationBody = `${host} has started "${meetingTitle}". Tap to join now!`;

          if (targetAudience === 'chapter' && targetChapter) {
            notificationTitle = `ALIVE Meet: ${targetChapter} Chapter Meeting`;
            notificationBody = `${host} has started the ${targetChapter} chapter fellowship. Tap to join!`;
          } else if (targetAudience === 'singles') {
            notificationTitle = 'ALIVE Meet: Singles Fellowship';
            notificationBody = `${host} has started Singles Fellowship. Tap to join!`;
          } else if (targetAudience === 'married' || targetAudience === 'couples' || targetAudience === 'channel_married') {
            notificationTitle = 'ALIVE Meet: Couples & Married Fellowship';
            notificationBody = `${host} has started Couples & Married Fellowship. Tap to join!`;
          } else if (targetAudience === 'directors') {
            notificationTitle = 'ALIVE Meet: Directors Meeting';
            notificationBody = `${host} has started the Directors Meeting. Tap to join!`;
          } else if (targetAudience === 'bod_only') {
            notificationTitle = 'ALIVE Meet: Board of Directors (BOD) Meeting';
            notificationBody = `${host} has convened the Board of Directors (BOD). Tap to join!`;
          } else if (targetAudience === 'board' || targetAudience === 'bod') {
            notificationTitle = 'ALIVE Meet: Board & Trustees Meeting';
            notificationBody = `${host} has convened the Board of Directors & Trustees. Tap to join!`;
          } else if (targetAudience === 'leadership') {
            notificationTitle = 'ALIVE Meet: Leadership Meeting';
            notificationBody = `${host} has started the Leadership Meeting. Tap to join!`;
          } else if (targetAudience && targetAudience.startsWith('channel_')) {
            notificationTitle = `ALIVE Meet: ${meetingTitle}`;
            notificationBody = `${host} has started a meeting for this channel. Tap to join!`;
          }

          const pushPayload = {
            messageId: ID.unique(),
            title: notificationTitle,
            body: notificationBody,
            topics: targetTopics && targetTopics.length > 0 ? targetTopics : undefined,
            users: targetUsers && targetUsers.length > 0 ? targetUsers : undefined,
            data: {
              type: 'meeting_started',
              roomName: targetRoom,
              meetingType: meetingType,
              targetAudience: targetAudience,
              targetChapter: targetChapter,
            },
            draft: false,
          };

          if (!pushPayload.topics && !pushPayload.users) {
            pushPayload.topics = ['all_users'];
          }

          await messaging.createPush(pushPayload);
          if (log) log(`Targeted meeting notification dispatched for ${targetAudience} (${targetChapter})`);
        }
      } catch (pushErr) {
        if (error) error(`Failed to dispatch meeting start push notification: ${pushErr.message}`);
      }
    }

    const token = new AccessToken(apiKey, apiSecret, {
      identity,
      name: participantName || identity,
      metadata: JSON.stringify({
        isLeader,
        isWaitingRoomEnabled: Boolean(body.isWaitingRoomEnabled),
        targetAudience: body.targetAudience || 'general',
        targetChapter: body.targetChapter || '',
      }),
    });
    token.addGrant({
      roomJoin: true,
      room: targetRoom,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
      roomAdmin: isLeader,
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
