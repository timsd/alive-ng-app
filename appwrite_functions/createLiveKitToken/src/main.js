import { AccessToken, RoomServiceClient } from 'livekit-server-sdk';
import { Client, Databases, ID, Messaging, Query } from 'node-appwrite';

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
  const endpoint = (
    process.env.APPWRITE_FUNCTION_API_ENDPOINT ||
    process.env.APPWRITE_ENDPOINT ||
    'https://api.alivenigeria.org/v1'
  ).replace(/\/$/, '');
  const projectId =
    process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
  const databaseId = process.env.APPWRITE_DATABASE_ID || '6a089307002e54291a32';
  const apiKey =
    process.env.APPWRITE_FUNCTION_API_KEY ||
    process.env.APPWRITE_API_KEY ||
    req.headers['x-appwrite-key'];
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
    { headers, signal: AbortSignal.timeout(8000) },
  );

  // Fallback to TablesDB route if standard collections route returns 404
  if (response.status === 404) {
    const tableResponse = await fetch(
      `${endpoint}/tablesdb/${databaseId}/tables/${usersTableId}/rows/${encodeURIComponent(userId)}`,
      { headers, signal: AbortSignal.timeout(8000) },
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

const VALID_TOPICS = new Set([
  'all_users',
  'admins',
  'bod',
  'directors',
  'chapter_leaders',
  'approvals',
  'prayer',
  'chat',
  'donations',
  'events',
  'study',
  'kids',
  'health',
  'content',
]);

async function getTargetUsers(databases, databaseId, usersTableId, targetAudience, targetChapter) {
  if (targetAudience === 'general' || targetAudience === 'all') {
    return { users: [], topics: ['all_users'] };
  }

  const rows = [];
  let offset = 0;
  try {
    while (true) {
      const res = await databases.listDocuments(databaseId, usersTableId, [
        Query.limit(100),
        Query.offset(offset),
      ]);
      const docs = res?.documents || [];
      rows.push(...docs);
      if (docs.length < 100 || rows.length >= (res?.total ?? rows.length) || rows.length >= 1000) {
        break;
      }
      offset += 100;
    }
  } catch (e) {
    // If user listing fails, fall back to valid topics
  }

  const norm = (s) => String(s || '').trim().toLowerCase();
  let matchedIds = [];
  let topics = [];

  switch (targetAudience) {
    case 'chapter': {
      const chapterQuery = norm(targetChapter);
      matchedIds = rows
        .filter((r) => {
          const chId = norm(r.chapter_id || r.chapterId);
          const localCh = norm(r.local_chapter || r.localChapter);
          return (
            chapterQuery &&
            (chId === chapterQuery ||
              localCh === chapterQuery ||
              chId.includes(chapterQuery) ||
              localCh.includes(chapterQuery))
          );
        })
        .map((r) => r.$id || r.id)
        .filter(Boolean);
      break;
    }
    case 'singles': {
      matchedIds = rows
        .filter((r) => norm(r.marital_status || r.maritalStatus) === 'single')
        .map((r) => r.$id || r.id)
        .filter(Boolean);
      break;
    }
    case 'married':
    case 'couples':
    case 'channel_married': {
      matchedIds = rows
        .filter((r) => ['married', 'couple'].includes(norm(r.marital_status || r.maritalStatus)))
        .map((r) => r.$id || r.id)
        .filter(Boolean);
      break;
    }
    case 'directors': {
      topics = ['directors'];
      matchedIds = rows
        .filter((r) => ['director', 'admin', 'super_admin'].includes(norm(r.role)))
        .map((r) => r.$id || r.id)
        .filter(Boolean);
      break;
    }
    case 'bod_only': {
      topics = ['bod'];
      matchedIds = rows
        .filter(
          (r) =>
            ['bod', 'admin', 'super_admin'].includes(norm(r.role)) ||
            (Array.isArray(r.roles) && r.roles.map(norm).includes('bod')),
        )
        .map((r) => r.$id || r.id)
        .filter(Boolean);
      break;
    }
    case 'board':
    case 'bod': {
      topics = ['bod'];
      matchedIds = rows
        .filter(
          (r) =>
            ['bod', 'trustee', 'admin', 'super_admin'].includes(norm(r.role)) ||
            (Array.isArray(r.roles) &&
              (r.roles.map(norm).includes('bod') || r.roles.map(norm).includes('trustee'))),
        )
        .map((r) => r.$id || r.id)
        .filter(Boolean);
      break;
    }
    case 'leadership': {
      topics = ['admins', 'bod', 'directors', 'chapter_leaders'];
      matchedIds = rows
        .filter((r) =>
          ['coordinator', 'leader', 'director', 'bod', 'trustee', 'admin', 'super_admin'].includes(
            norm(r.role),
          ),
        )
        .map((r) => r.$id || r.id)
        .filter(Boolean);
      break;
    }
    default: {
      if (targetAudience && (targetAudience.startsWith('channel_') || targetAudience.length === 20)) {
        const channelId = targetAudience;
        try {
          const chatChannelsTableId = '6a08f1c70032affbc00d';
          const chData = await databases.getDocument(databaseId, chatChannelsTableId, channelId);
          const members = Array.isArray(chData?.members) ? chData.members : [];
          matchedIds = members.filter(Boolean);
        } catch (chErr) {
          // Fall back if channel lookup fails
        }
      } else {
        topics = ['all_users'];
      }
      break;
    }
  }

  return {
    users: Array.from(new Set(matchedIds)),
    topics: topics.filter((t) => VALID_TOPICS.has(t)),
  };
}

export default async ({ req, res, log, error }) => {
  if (req.method !== 'POST') return res.json({ error: 'Method not allowed. Use POST.' }, 405);

  try {
    const triggerType = String(req.headers['x-appwrite-trigger'] || '').trim().toLowerCase();
    const isInternal = triggerType === 'event' || triggerType === 'schedule';
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const authenticatedUserId = String(req.headers['x-appwrite-user-id'] || '').trim() || (isInternal ? String(body.identity || '').trim() : '');
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
              return ['director', 'bod', 'trustee', 'president', 'admin', 'super_admin'].includes(role);
            }
            if (name === 'alive-meet-leadership') {
              return ['coordinator', 'leader', 'director', 'bod', 'trustee', 'president', 'admin', 'super_admin'].includes(role);
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
      const normalizedRole = String(role || '').trim().toLowerCase();
      const canEnd = [
        'coordinator',
        'leader',
        'director',
        'bod',
        'trustee',
        'president',
        'admin',
        'super_admin',
      ].includes(normalizedRole);
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

    const targetRoom = String(roomName).trim();
    const isLeader = ['admin', 'super_admin', 'president', 'bod', 'director', 'trustee', 'leader', 'coordinator'].includes(role);
    const isAdmin = ['admin', 'super_admin', 'president', 'bod', 'director', 'trustee'].includes(role);

    const isSelf = identity === authenticatedUserId;
    const isAuthorizedRelay =
      (isLeader || isInternal) &&
      String(identity).startsWith(`${authenticatedUserId}_relay_`);
    if (!isSelf && !isAuthorizedRelay && !isInternal) {
      return res.json({ error: 'Cannot create a token for another user or unauthorized relay.' }, 403);
    }

    // Derive room access policy strictly from the actual targetRoom (including
    // breakout rooms `--br-`) so a client cannot bypass Board/Leadership room
    // restrictions by passing `meetingType: "custom"`.
    const baseRoom = targetRoom.split('--br-')[0];
    const effectiveType = inferMeetingType(baseRoom);
    const policy = roomPolicies[effectiveType] || roomPolicies[meetingType] || roomPolicies.custom;

    // 1. Role-restricted rooms (board, leadership) ALWAYS require matching roles
    if (policy.roles && !policy.roles.includes(role) && !['super_admin', 'president'].includes(role)) {
      return res.json({ error: 'You do not have access to this ALIVE Meet room.' }, 403);
    }

    // 2. Non-leaders may join standard public rooms (community, prayer, quick)
    // and their breakout rooms, or any currently active non-restricted custom
    // room via invite link, but cannot spin up brand-new arbitrary rooms.
    const PUBLIC_ROOMS = new Set(['alive-meet-community', 'alive-meet-prayer', 'alive-meet-quick']);
    if (!isLeader && !PUBLIC_ROOMS.has(baseRoom) && !isInternal) {
      let roomExists = false;
      try {
        const roomService = new RoomServiceClient(rawServiceUrl, apiKey, apiSecret);
        const existing = await roomService.listRooms([targetRoom]);
        roomExists = Array.isArray(existing) && existing.some((r) => r.name === targetRoom && Number(r.numParticipants || 0) > 0);
      } catch (_) {}
      if (!roomExists) {
        return res.json({ error: 'Only ALIVE leaders and administrators can start new meeting rooms.' }, 403);
      }
    }

    // Trigger targeted push notification when a leader/admin starts a meeting
    if (notifyMembers && isLeader) {
      try {
        const endpoint = (
          process.env.APPWRITE_FUNCTION_API_ENDPOINT ||
          process.env.APPWRITE_ENDPOINT ||
          'https://api.alivenigeria.org/v1'
        ).replace(/\/$/, '');
        const projectId =
          process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
        const databaseId = process.env.APPWRITE_DATABASE_ID || '6a089307002e54291a32';
        const serverApiKey =
          process.env.APPWRITE_FUNCTION_API_KEY ||
          process.env.APPWRITE_API_KEY ||
          req.headers['x-appwrite-key'];
        const usersTableId = process.env.APPWRITE_USERS_TABLE_ID || '6a08943100226f5b4963';

        if (endpoint && projectId && databaseId && serverApiKey) {
          const client = new Client()
            .setEndpoint(endpoint)
            .setProject(projectId)
            .setKey(serverApiKey);
          const databases = new Databases(client);
          const messaging = new Messaging(client);
          const meetingTitle = body.meetingTitle || targetRoom;
          const host = participantName || (isAdmin ? 'An Admin' : 'A Leader');

          const targetAudience = body.targetAudience || 'general';
          const targetChapter = body.targetChapter || '';
          const { users: targetUsers, topics: targetTopics } = await getTargetUsers(
            databases,
            databaseId,
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

          const basePushPayload = {
            title: notificationTitle,
            body: notificationBody,
            data: {
              type: 'meeting_started',
              route: `/meet/${targetRoom}`,
              roomName: targetRoom,
              meetingType: meetingType,
              targetAudience: targetAudience,
              targetChapter: targetChapter,
            },
            icon: 'ic_notification',
            color: '#0F9A07',
            sound: 'default',
            priority: 'high',
            draft: false,
          };

          const dispatchPush = async () => {
            if (targetUsers && targetUsers.length > 0) {
              for (let i = 0; i < targetUsers.length; i += 100) {
                await messaging.createPush({
                  ...basePushPayload,
                  messageId: ID.unique(),
                  users: targetUsers.slice(i, i + 100),
                });
              }
            } else if (targetTopics && targetTopics.length > 0) {
              await messaging.createPush({
                ...basePushPayload,
                messageId: ID.unique(),
                topics: targetTopics,
              });
            } else {
              await messaging.createPush({
                ...basePushPayload,
                messageId: ID.unique(),
                topics: ['all_users'],
              });
            }
          };
          // Cap push dispatch wait to 8s so token generation can never hit Appwrite's 30s sync timeout
          await Promise.race([
            dispatchPush(),
            new Promise((resolve) => setTimeout(resolve, 8000)),
          ]);
          if (log) log(`Targeted meeting notification dispatched for ${targetAudience} (${targetChapter}) -> users=${targetUsers.length}, topics=${targetTopics.join(',')}`);
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
