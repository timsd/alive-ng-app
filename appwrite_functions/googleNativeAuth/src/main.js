import { Client, ID, Query, Users } from 'node-appwrite';

const DEFAULT_ENDPOINT = 'https://api.alivenigeria.org/v1';
const DEFAULT_ALLOWED_CLIENT_IDS = [
  '234909240985-1dernhsf9qmkau7idp4hn1nudegpd5ju.apps.googleusercontent.com', // Web / Server OAuth Client
  '234909240985-jr2767d4lmp9plt62fk6j3colff51gue.apps.googleusercontent.com', // iOS OAuth Client
];

function getAllowedClientIds() {
  const extra = (process.env.GOOGLE_ALLOWED_CLIENT_IDS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return new Set([...DEFAULT_ALLOWED_CLIENT_IDS, ...extra]);
}

async function verifyGoogleIdToken(idToken) {
  const res = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
    { method: 'GET' },
  );
  const text = await res.text();
  let payload = {};
  try {
    payload = text ? JSON.parse(text) : {};
  } catch (_) {}

  if (!res.ok) {
    throw new Error(payload.error_description || payload.error || 'Invalid Google ID token.');
  }

  const allowedAudiences = getAllowedClientIds();
  const aud = String(payload.aud || '').trim();
  const azp = String(payload.azp || '').trim();
  if (!allowedAudiences.has(aud) && !allowedAudiences.has(azp)) {
    throw new Error('Google token audience mismatch.');
  }

  const emailVerified =
    payload.email_verified === true || String(payload.email_verified).toLowerCase() === 'true';
  const email = String(payload.email || '').trim().toLowerCase();
  if (!email || !emailVerified) {
    throw new Error('Google account email is not verified.');
  }

  const expSec = Number(payload.exp || 0);
  if (expSec > 0 && expSec * 1000 < Date.now() - 30_000) {
    throw new Error('Google ID token has expired.');
  }

  return {
    email,
    name: String(payload.name || email.split('@')[0] || 'ALIVE Member').trim().slice(0, 128),
    sub: String(payload.sub || '').trim(),
    picture: String(payload.picture || '').trim(),
  };
}

export default async ({ req, res, log, error }) => {
  try {
    const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT || DEFAULT_ENDPOINT;
    const projectId = process.env.APPWRITE_FUNCTION_PROJECT_ID;
    const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || req.headers['x-appwrite-key'];

    if (!projectId || !apiKey) {
      error('Missing APPWRITE_FUNCTION_PROJECT_ID or APPWRITE_FUNCTION_API_KEY.');
      return res.json({ error: 'Authentication service is not configured.' }, 500);
    }

    let body = {};
    if (req.body !== null && typeof req.body === 'object') {
      body = req.body;
    } else {
      const raw =
        typeof req.bodyRaw === 'string'
          ? req.bodyRaw
          : typeof req.body === 'string'
            ? req.body
            : '{}';
      body = JSON.parse(raw || '{}');
    }

    const idToken = String(body.idToken || body.id_token || '').trim();
    if (!idToken || idToken.length < 50) {
      return res.json({ error: 'A valid Google idToken is required.' }, 400);
    }

    const profile = await verifyGoogleIdToken(idToken);

    const client = new Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey);
    const users = new Users(client);

    // 1. Find existing Appwrite Auth user by verified Google email
    let user = null;
    const existing = await users.list([Query.equal('email', [profile.email]), Query.limit(1)]);
    if (existing.users && existing.users.length > 0) {
      user = existing.users[0];
      if (!user.emailVerification) {
        await users.updateEmailVerification(user.$id, true).catch(() => {});
      }
      if ((!user.name || user.name.trim() === '') && profile.name) {
        await users.updateName(user.$id, profile.name).catch(() => {});
      }
    } else {
      // 2. Create new Appwrite Auth user for first-time Google sign-in
      user = await users.create(
        ID.unique(),
        profile.email,
        undefined,
        undefined,
        profile.name,
      );
      await users.updateEmailVerification(user.$id, true).catch(() => {});
      log(`Created new Appwrite user via native Google Sign-In: ${user.$id}`);
    }

    // 3. Mint a single-use Appwrite session token (expires in 5 minutes)
    const token = await users.createToken(user.$id, 64, 300);

    log(`Native Google Sign-In succeeded for user ${user.$id}`);
    return res.json({
      success: true,
      userId: user.$id,
      secret: token.secret,
      email: profile.email,
      name: user.name || profile.name,
    });
  } catch (err) {
    error(`googleNativeAuth failed: ${err.message}`);
    const isClientErr =
      err.message?.includes('Invalid Google') ||
      err.message?.includes('audience') ||
      err.message?.includes('expired') ||
      err.message?.includes('verified');
    return res.json(
      { error: err.message || 'Google sign-in verification failed.' },
      isClientErr ? 401 : 500,
    );
  }
};
