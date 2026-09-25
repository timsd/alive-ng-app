/**
 * Deletes the caller's own Appwrite auth account.
 *
 * Why this exists: the Flutter `appwrite` SDK (26.x) does not expose
 * `Account.delete()`, and the REST `DELETE /account` call requires the
 * caller's session — so the app executes this function (which Appwrite
 * authenticates as the session user via the `x-appwrite-user-id` header) and
 * the function uses its API key to remove the user row server-side.
 *
 * Required env vars:
 *   APPWRITE_FUNCTION_API_KEY  - key with users.write scope
 *   APPWRITE_FUNCTION_API_ENDPOINT / APPWRITE_FUNCTION_PROJECT_ID (or the
 *   Appwrite-injected APPWRITE_FUNCTION_* equivalents)
 *
 * Safety: the function refuses to delete anyone other than the authenticated
 * caller (body `user_id` must equal the `x-appwrite-user-id` header).
 */
export default async ({ req, res, log, error }) => {
  if (req.method !== 'POST') {
    return res.json({ error: 'Method not allowed. Use POST.' }, 405);
  }

  const callerId = req.headers['x-appwrite-user-id'];
  if (!callerId) {
    return res.json({ error: 'Authentication required.' }, 401);
  }

  let body;
  try {
    const raw = typeof req.bodyRaw === 'string'
      ? req.bodyRaw
      : (typeof req.body === 'string' ? req.body : '{}');
    body = req.body !== null && typeof req.body === 'object'
      ? req.body
      : JSON.parse(raw || '{}');
  } catch (_) {
    body = {};
  }

  const targetId = String(body.user_id || body.userId || '').trim();
  if (!targetId) {
    return res.json({ error: 'Missing user_id.' }, 400);
  }
  if (targetId !== callerId) {
    error(`Refusing deletion: caller ${callerId} != target ${targetId}`);
    return res.json({ error: 'You can only delete your own account.' }, 403);
  }

  const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
  const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT || process.env.APPWRITE_ENDPOINT;
  const project = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
  if (!apiKey || !endpoint || !project) {
    error('deleteAccount is not configured (missing Appwrite credentials).');
    return res.json({ error: 'Account deletion service is not configured.' }, 500);
  }

  const response = await fetch(
    `${endpoint}/users/${encodeURIComponent(targetId)}`,
    {
      method: 'DELETE',
      headers: {
        'X-Appwrite-Project': project,
        'X-Appwrite-Key': apiKey,
        'Content-Type': 'application/json',
      },
    },
  );

  if (response.ok || response.status === 404) {
    log(`Deleted auth account ${targetId}`);
    return res.json({ ok: true, deleted: true, user_id: targetId });
  }

  const text = await response.text();
  error(`Account deletion failed (${response.status}): ${text}`);
  return res.json({ error: 'Failed to delete account.' }, 502);
};
