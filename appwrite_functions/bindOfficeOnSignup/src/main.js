/**
 * Attaches a leadership office to a new account, by email.
 *
 * Triggered on `users.*.create`. When someone signs up, this matches their
 * email against `officer_registry`; on a match it writes their real `user_id`
 * into `org_office_holders` and retires the registry row.
 *
 * Why server-side: `org_office_holders` decides who may see finance. A client
 * that set its own office could claim the Treasurer's role, so the binding has
 * to be decided here, from an email the person cannot choose at runtime. A
 * display name is deliberately NOT a match key -- anyone can set their profile
 * name, which would hand them the Treasurer's office.
 *
 * Everything is best-effort: a failed lookup or write must never block a
 * signup, so every error is logged and swallowed.
 */
import { Client, Databases, Query, ID, ExecutionMethod } from 'node-appwrite';

const REGISTRY = 'officer_registry';
const HOLDERS = 'org_office_holders';

const log = (msg) => console.log(`[bind-office] ${msg}`);

export default async ({ req, res, log: appwriteLog, error, client }) => {
  // Appwrite only surfaces output through the context's `log`. Using
  // console.log instead leaves the function logs empty, which makes a
  // non-binding impossible to diagnose.
  const log = (msg) => {
    try {
      appwriteLog?.(msg);
    } catch {}
    console.log(`[bind-office] ${msg}`);
  };

  // Appwrite 1.8 passes a ready `client` on the context. Fall back to building
  // one from the environment for older runtimes.
  let db = client;
  if (!db) {
    const c = new Client()
      .setEndpoint(req.headers['x-appwrite-endpoint'] || process.env.APPWRITE_ENDPOINT)
      .setProject(req.headers['x-appwrite-project'] || process.env.APPWRITE_PROJECT_ID)
      .setKey(process.env.APPWRITE_API_KEY);
    db = new Databases(c);
  }

  const databaseId = process.env.APPWRITE_DATABASE_ID;

  try {
    // The event payload carries the new user. Fall back to the request body so
    // the function can also be called directly for a retry.
    let user = null;
    const events = req.headers['x-appwrite-events'] || '';
    if (Array.isArray(events) && events.length) {
      const parsed = JSON.parse(events[0]);
      user = parsed.data || parsed;
    } else if (req.bodyJson && req.bodyJson.userId) {
      user = req.bodyJson;
    } else if (req.bodyText) {
      const parsed = JSON.parse(req.bodyText);
      user = parsed.userId ? parsed : null;
    }

    if (!user || !user.$id) {
      log('no user in the event payload; nothing to bind');
      return res.json({ ok: true, bound: false, reason: 'no user in payload' });
    }

    const email = String(user.email || '').trim().toLowerCase();
    if (!email) {
      log(`user ${user.$id} has no email; cannot match an office`);
      return res.json({ ok: true, bound: false, reason: 'no email' });
    }

    // An exact, case-insensitive match on email only.
    const matches = await db.listDocuments(databaseId, REGISTRY, [
      Query.equal('email', email),
      Query.equal('consumed', false),
      Query.limit(1),
    ]);

    if (!matches.documents.length) {
      log(`${email}: no pending office; nothing to do`);
      return res.json({ ok: true, bound: false, reason: 'no pending office' });
    }

    const entry = matches.documents[0];
    const officeId = String(entry.office_id || '').trim();
    if (!officeId) {
      log(`${email}: registry row has no office_id`);
      return res.json({ ok: true, bound: false, reason: 'registry row has no office' });
    }

    const holders = await db.listDocuments(databaseId, HOLDERS, [
      Query.equal('office_id', officeId),
      Query.limit(1),
    ]);
    if (!holders.documents.length) {
      log(`${email}: no org_office_holders row for ${officeId}`);
      return res.json({ ok: true, bound: false, reason: 'no holder row' });
    }

    await db.updateDocument(databaseId, HOLDERS, holders.documents[0].$id, {
      // Appwrite 1.8 reads a PATCH body as empty unless it is wrapped in
      // `data`, and reports that as a permissions error.
      data: {
        user_id: user.$id,
        email: user.email,
        full_name: entry.full_name || user.name || '',
        bound_at: new Date().toISOString(),
        bound_by: 'officer_registry',
      },
    });

    // Retire the registry row so a later account reusing the address cannot
    // silently inherit the office.
    await db.updateDocument(databaseId, REGISTRY, entry.$id, {
      data: {
        consumed: true,
        consumed_by: user.$id,
        consumed_at: new Date().toISOString(),
      },
    });

    log(`${email} bound to ${officeId} as ${user.$id}`);
    return res.json({ ok: true, bound: true, office_id: officeId, user_id: user.$id });
  } catch (e) {
    // A signup must never be blocked by this.
    log(`failed: ${e?.message ?? e}`);
    return res.json({ ok: false, error: e?.message ?? String(e) });
  }
};
