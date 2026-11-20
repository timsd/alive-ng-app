import { createHash } from 'node:crypto';
import { Client, Databases, ID, Messaging, Query, Users } from 'node-appwrite';

const DEFAULT_ENDPOINT = 'https://api.alivenigeria.org/v1';
const DEFAULT_DATABASE_ID = '6a089307002e54291a32';
const DEFAULT_FCM_PROVIDER_ID = '6a0cbd1600215f960c03';
const USERS_COLLECTION_ID = '6a08943100226f5b4963';
const ORG_OFFICE_HOLDERS_COLLECTION_ID = 'org_office_holders';
const PUSH_TOKENS_COLLECTION_ID = 'push_tokens';
const PRAYER_REQUESTS_COLLECTION_ID = 'prayer_requests';
const NOTIFICATION_SETTINGS_COLLECTION_ID = 'notification_settings';
const GUEST_PUSH_USER_ID = 'guest_push_devices';

const ALLOWED_ROLES = new Set([
  'admin',
  'super_admin',
  'coordinator',
  'director',
  'board',
  'editor',
]);

function sha1Hex(input) {
  return createHash('sha1').update(String(input)).digest('hex');
}

function guestTargetIdFor(token) {
  return `guest_${sha1Hex(token).slice(0, 26)}`;
}

function subscriberIdFor(topicId, targetId) {
  return `sub_${sha1Hex(`${topicId}:${targetId}`).slice(0, 28)}`;
}

/**
 * Low-level Appwrite REST helper so target/subscriber operations never break
 * across node-appwrite minor parameter signature changes.
 */
async function appwriteRest({ endpoint, projectId, apiKey, method, path, body }) {
  const base = endpoint.replace(/\/+$/, '');
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      'X-Appwrite-Project': projectId,
      'X-Appwrite-Key': apiKey,
      'Content-Type': 'application/json',
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const text = await res.text();
  let json = {};
  try {
    json = text ? JSON.parse(text) : {};
  } catch (_) {}
  return { status: res.status, ok: res.ok, json, text };
}

/**
 * Ensures the shared server-managed Appwrite user for guest / pre-login mobile
 * installs exists so freshly installed mobile devices can subscribe to `all_users`.
 */
async function ensureGuestPushUser({ endpoint, projectId, apiKey, log }) {
  const existing = await appwriteRest({
    endpoint,
    projectId,
    apiKey,
    method: 'GET',
    path: `/users/${GUEST_PUSH_USER_ID}`,
  });
  if (existing.ok) return true;

  const created = await appwriteRest({
    endpoint,
    projectId,
    apiKey,
    method: 'POST',
    path: '/users',
    body: {
      userId: GUEST_PUSH_USER_ID,
      name: 'ALIVE Mobile Guest Devices',
    },
  });
  if (!created.ok && created.status !== 409) {
    throw new Error(`Could not create guest push user (${created.status}): ${created.text}`);
  }
  log(`Initialized guest push bucket user: ${GUEST_PUSH_USER_ID}`);
  return true;
}

/**
 * Registers an unauthenticated / newly installed mobile device's FCM token
 * under `guest_push_devices` and subscribes it to the `all_users` topic.
 */
async function handleRegisterGuestDevice({
  endpoint,
  projectId,
  apiKey,
  databaseId,
  fcmProviderId,
  body,
  log,
  res,
}) {
  const token = String(body.token || '').trim();
  const platform = String(body.platform || 'android').trim().toLowerCase().slice(0, 32);

  if (token.length < 40 || token.length > 4096 || /\s/.test(token)) {
    return res.json({ error: 'Invalid FCM device token.' }, 400);
  }

  await ensureGuestPushUser({ endpoint, projectId, apiKey, log });

  const targetId = guestTargetIdFor(token);
  const createTarget = await appwriteRest({
    endpoint,
    projectId,
    apiKey,
    method: 'POST',
    path: `/users/${GUEST_PUSH_USER_ID}/targets`,
    body: {
      targetId,
      providerType: 'push',
      identifier: token,
      providerId: fcmProviderId,
      name: `guest_${platform}`,
    },
  });

  if (!createTarget.ok && createTarget.status === 409) {
    await appwriteRest({
      endpoint,
      projectId,
      apiKey,
      method: 'PUT',
      path: `/users/${GUEST_PUSH_USER_ID}/targets/${targetId}`,
      body: {
        identifier: token,
        providerId: fcmProviderId,
        name: `guest_${platform}`,
      },
    });
  } else if (!createTarget.ok) {
    throw new Error(
      `Failed to create guest push target (${createTarget.status}): ${createTarget.text}`,
    );
  }

  const subscriberId = subscriberIdFor('all_users', targetId);
  const subscribeRes = await appwriteRest({
    endpoint,
    projectId,
    apiKey,
    method: 'POST',
    path: '/messaging/topics/all_users/subscribers',
    body: {
      subscriberId,
      targetId,
    },
  });

  if (!subscribeRes.ok && subscribeRes.status !== 409) {
    throw new Error(
      `Failed to subscribe guest device to all_users (${subscribeRes.status}): ${subscribeRes.text}`,
    );
  }

  // Record in push_tokens for observability (best-effort)
  try {
    const now = new Date().toISOString();
    const docData = {
      user_id: GUEST_PUSH_USER_ID,
      token,
      provider: 'fcm',
      platform,
      updated_at: now,
    };
    const upd = await appwriteRest({
      endpoint,
      projectId,
      apiKey,
      method: 'PATCH',
      path: `/databases/${databaseId}/collections/${PUSH_TOKENS_COLLECTION_ID}/documents/${targetId}`,
      body: { data: docData },
    });
    if (upd.status === 404) {
      await appwriteRest({
        endpoint,
        projectId,
        apiKey,
        method: 'POST',
        path: `/databases/${databaseId}/collections/${PUSH_TOKENS_COLLECTION_ID}/documents`,
        body: {
          documentId: targetId,
          data: { ...docData, created_at: now },
        },
      });
    }
  } catch (e) {
    log(`Guest push_tokens log skipped: ${e.message}`);
  }

  log(`Registered guest mobile device: targetId=${targetId}, platform=${platform}`);
  return res.json({
    success: true,
    targetId,
    topic: 'all_users',
  });
}

/**
 * Removes a guest push target once the device signs into a real member account
 * so the device does not receive duplicate push notifications.
 */
async function handleUnregisterGuestDevice({
  endpoint,
  projectId,
  apiKey,
  databaseId,
  body,
  log,
  res,
}) {
  const token = String(body.token || '').trim();
  const rawTargetId = String(body.targetId || '').trim();
  const targetId = rawTargetId.startsWith('guest_')
    ? rawTargetId
    : (token.length >= 40 ? guestTargetIdFor(token) : '');

  if (!targetId || !targetId.startsWith('guest_')) {
    return res.json({ success: true, removed: false });
  }

  await appwriteRest({
    endpoint,
    projectId,
    apiKey,
    method: 'DELETE',
    path: `/users/${GUEST_PUSH_USER_ID}/targets/${targetId}`,
  });

  await appwriteRest({
    endpoint,
    projectId,
    apiKey,
    method: 'DELETE',
    path: `/databases/${databaseId}/collections/${PUSH_TOKENS_COLLECTION_ID}/documents/${targetId}`,
  });

  log(`Removed prior guest push target after login: ${targetId}`);
  return res.json({ success: true, removed: true, targetId });
}

/**
 * Verifies that the invoking Appwrite user is an admin, coordinator, director,
 * board member, or active office holder.
 */
async function isAuthorizedSender({ databases, usersApi, databaseId, callerUserId, log }) {
  if (!callerUserId) return false;

  try {
    const authUser = await usersApi.get(callerUserId);
    const labels = Array.isArray(authUser.labels) ? authUser.labels : [];
    if (labels.some((l) => ALLOWED_ROLES.has(String(l).toLowerCase()))) {
      return true;
    }
  } catch (e) {
    log(`usersApi.get failed for ${callerUserId}: ${e.message}`);
  }

  try {
    const userDoc = await databases.getDocument(databaseId, USERS_COLLECTION_ID, callerUserId);
    const role = String(userDoc.role || '').toLowerCase();
    if (userDoc.is_admin === true || ALLOWED_ROLES.has(role)) {
      return true;
    }
  } catch (e) {
    log(`userDoc lookup failed for ${callerUserId}: ${e.message}`);
  }

  try {
    const officeRes = await databases.listDocuments(
      databaseId,
      ORG_OFFICE_HOLDERS_COLLECTION_ID,
      [
        Query.equal('user_id', callerUserId),
        Query.equal('is_active', true),
        Query.limit(5),
      ],
    );
    if (officeRes.total > 0) {
      return true;
    }
  } catch (e) {
    log(`office lookup failed for ${callerUserId}: ${e.message}`);
  }

  return false;
}

export default async ({ req, res, log, error }) => {
  try {
    const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT || DEFAULT_ENDPOINT;
    const projectId = process.env.APPWRITE_FUNCTION_PROJECT_ID;
    const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || req.headers['x-appwrite-key'];
    const databaseId = process.env.APPWRITE_DATABASE_ID || DEFAULT_DATABASE_ID;
    const fcmProviderId = process.env.APPWRITE_FCM_PROVIDER_ID || DEFAULT_FCM_PROVIDER_ID;

    if (!projectId || !apiKey) {
      error('Missing APPWRITE_FUNCTION_PROJECT_ID or APPWRITE_FUNCTION_API_KEY.');
      return res.json({ error: 'Push service is not configured.' }, 500);
    }

    let body = {};
    if (req.body !== null && typeof req.body === 'object') {
      body = req.body;
    } else {
      const raw = typeof req.bodyRaw === 'string'
        ? req.bodyRaw
        : (typeof req.body === 'string' ? req.body : '{}');
      body = JSON.parse(raw || '{}');
    }

    const action = String(body.action || '').trim().toLowerCase();

    // Device auto-registration endpoints for fresh mobile installs / guest mode.
    // Strictly limited to adding/removing a single device FCM token on `all_users`;
    // cannot read data or send any push messages.
    if (action === 'register_guest_device') {
      return await handleRegisterGuestDevice({
        endpoint,
        projectId,
        apiKey,
        databaseId,
        fcmProviderId,
        body,
        log,
        res,
      });
    }

    if (action === 'unregister_guest_device') {
      return await handleUnregisterGuestDevice({
        endpoint,
        projectId,
        apiKey,
        databaseId,
        body,
        log,
        res,
      });
    }

    const client = new Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey);

    const databases = new Databases(client);
    const usersApi = new Users(client);
    const messaging = new Messaging(client);

    const callerUserId = String(req.headers['x-appwrite-user-id'] || '').trim();
    const triggerType = String(req.headers['x-appwrite-trigger'] || '').trim().toLowerCase();

    // Dedicated action for any authenticated member praying for another member's prayer request.
    // Looks up the prayer request owner server-side and sends a targeted push notification only to that owner.
    if (action === 'notify_prayer_support') {
      if (!callerUserId) {
        return res.json({ error: 'Authentication required.' }, 401);
      }
      const requestId = String(body.requestId || '').trim();
      if (!requestId) {
        return res.json({ error: 'requestId is required.' }, 400);
      }

      let prayerDoc;
      try {
        prayerDoc = await databases.getDocument(
          databaseId,
          PRAYER_REQUESTS_COLLECTION_ID,
          requestId,
        );
      } catch (e) {
        return res.json({ error: 'Prayer request not found.' }, 404);
      }

      const ownerId = String(
        prayerDoc.user_id || prayerDoc.userId || prayerDoc.requestedById || '',
      ).trim();
      if (!ownerId || ownerId === callerUserId) {
        return res.json({
          success: true,
          skipped: true,
          reason: 'Self-prayer or missing owner.',
        });
      }

      // Check recipient notification preferences if configured
      try {
        const settingsDoc = await databases.getDocument(
          databaseId,
          NOTIFICATION_SETTINGS_COLLECTION_ID,
          ownerId,
        );
        if (
          settingsDoc.push_notifications_enabled === false ||
          settingsDoc.prayer_requests === false
        ) {
          return res.json({
            success: true,
            skipped: true,
            reason: 'Recipient disabled prayer notifications.',
          });
        }
      } catch (_) {
        // Default is enabled if no settings document exists
      }

      const requestTitle = String(prayerDoc.title || 'your prayer request').trim();
      const intercessorName = String(body.intercessorName || '').trim() || 'A fellow believer';
      const prayerCount = Number(prayerDoc.prayer_count || 1);
      const route = `/prayer-wall?prayerId=${encodeURIComponent(requestId)}`;
      const pushTitle = '🙏 Someone Prayed for Your Request';
      const pushBody =
        prayerCount > 1
          ? `${intercessorName} just prayed for "${requestTitle}" (${prayerCount} prayers lifted).`
          : `${intercessorName} just prayed for your request: "${requestTitle}".`;

      const message = await messaging.createPush({
        messageId: ID.unique(),
        title: pushTitle,
        body: pushBody,
        topics: [],
        users: [ownerId],
        targets: [],
        data: {
          type: 'prayer_request',
          id: requestId,
          route,
        },
        icon: 'ic_notification',
        color: '#0F9A07',
        sound: 'default',
        priority: 'high',
        draft: false,
      });

      log(`Prayer support push dispatched: msg=${message.$id}, owner=${ownerId}, request=${requestId}`);
      return res.json({
        success: true,
        messageId: message.$id,
        ownerId,
        requestId,
        route,
      });
    }

    // Require an authenticated admin/office-holder caller for general push broadcasts.
    // Note: Appwrite always injects its dynamic `x-appwrite-key` header into
    // function executions, so we must NOT treat `x-appwrite-key` as proof of
    // caller authentication. Only an authenticated admin `x-appwrite-user-id`
    // (or internal `schedule`/`event` trigger) may dispatch push broadcasts.
    if (callerUserId) {
      const allowed = await isAuthorizedSender({
        databases,
        usersApi,
        databaseId,
        callerUserId,
        log,
      });
      if (!allowed) {
        return res.json({ error: 'Unauthorized: admin or office-holder access required.' }, 403);
      }
    } else if (triggerType !== 'schedule' && triggerType !== 'event') {
      return res.json({ error: 'Authentication required.' }, 401);
    }

    const title = String(body.title || '').trim();
    const messageBody = String(body.body || body.message || '').trim();
    if (!title || !messageBody) {
      return res.json({ error: 'Both title and body are required.' }, 400);
    }

    const topics = Array.isArray(body.topics)
      ? body.topics.map((t) => String(t).trim()).filter(Boolean)
      : [];
    const users = Array.isArray(body.users)
      ? body.users.map((u) => String(u).trim()).filter(Boolean)
      : [];
    const targets = Array.isArray(body.targets)
      ? body.targets.map((t) => String(t).trim()).filter(Boolean)
      : [];

    if (topics.length === 0 && users.length === 0 && targets.length === 0) {
      topics.push('all_users');
    }

    const route = typeof body.route === 'string' ? body.route.trim() : '';
    const type = typeof body.type === 'string' && body.type.trim()
      ? body.type.trim()
      : 'announcement';

    const rawData = body.data && typeof body.data === 'object' ? body.data : {};
    const data = {};
    for (const [k, v] of Object.entries({ ...rawData, type, ...(route ? { route } : {}) })) {
      if (v !== undefined && v !== null && String(v).trim() !== '') {
        data[k] = String(v);
      }
    }

    const sound = typeof body.sound === 'string' && body.sound.trim()
      ? body.sound.trim()
      : 'default';
    const priority = body.priority === 'normal' ? 'normal' : 'high';

    const message = await messaging.createPush({
      messageId: ID.unique(),
      title,
      body: messageBody,
      topics,
      users,
      targets,
      data,
      icon: 'ic_notification',
      color: '#0F9A07',
      sound,
      priority,
      draft: false,
    });

    log(`Push dispatched: id=${message.$id}, topics=${topics.join(',')}, users=${users.length}, targets=${targets.length}, route=${route || '(none)'}`);

    return res.json({
      success: true,
      messageId: message.$id,
      status: message.status,
      topics,
      route: route || null,
      type,
    });
  } catch (err) {
    error(`sendPush failed: ${err.message}`);
    return res.json({ error: err.message || 'Failed to send push notification.' }, 500);
  }
};
