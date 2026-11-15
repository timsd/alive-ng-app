import { Client, Databases, ID, Messaging, Query, Users } from 'node-appwrite';

const DEFAULT_ENDPOINT = 'https://api.alivenigeria.org/v1';
const DEFAULT_DATABASE_ID = '6a089307002e54291a32';
const USERS_COLLECTION_ID = '6a08943100226f5b4963';
const ORG_OFFICE_HOLDERS_COLLECTION_ID = 'org_office_holders';

const ALLOWED_ROLES = new Set([
  'admin',
  'super_admin',
  'coordinator',
  'director',
  'board',
  'editor',
]);

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

    const client = new Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey);

    const databases = new Databases(client);
    const usersApi = new Users(client);
    const messaging = new Messaging(client);

    // Require an authenticated admin/office-holder caller (unless invoked with
    // an explicit server API key header without a user context).
    const callerUserId = req.headers['x-appwrite-user-id'] || '';
    const triggerType = req.headers['x-appwrite-trigger'] || '';
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
    } else if (triggerType === 'http' && !req.headers['x-appwrite-key']) {
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
