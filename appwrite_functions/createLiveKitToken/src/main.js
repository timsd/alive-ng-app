import { AccessToken } from 'livekit-server-sdk';

export default async ({ req, res, log, error }) => {
  if (req.method !== 'POST') {
    return res.json({ error: 'Method not allowed. Use POST.' }, 405);
  }

  try {
    const authenticatedUserId = req.headers['x-appwrite-user-id'];
    if (!authenticatedUserId) {
      return res.json({ error: 'Authentication required.' }, 401);
    }

    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const { roomName, participantName, identity } = body;

    if (!roomName || !identity) {
      return res.json({ error: 'Missing roomName or identity parameters.' }, 400);
    }

    if (identity !== authenticatedUserId) {
      return res.json({ error: 'Cannot create a token for another user.' }, 403);
    }

    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET || process.env.LIVEKIT_SECRET;

    if (!apiKey || !apiSecret) {
      error('Missing LIVEKIT_API_KEY and LIVEKIT_API_SECRET/LIVEKIT_SECRET environment variables.');
      return res.json({ error: 'LiveKit server credentials are not configured.' }, 500);
    }

    const token = new AccessToken(apiKey, apiSecret, {
      identity,
      name: participantName || identity,
    });

    token.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,
      canSubscribe: true,
    });

    return res.json({ token: await token.toJwt() });
  } catch (err) {
    error(`LiveKit Token Generation Failed: ${err.message}`);
    return res.json({ error: 'Internal Server Error', details: err.message }, 500);
  }
};
