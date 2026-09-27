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
import { Client, Databases, Users, Query, ExecutionMethod } from 'node-appwrite';

const REGISTRY = 'officer_registry';
const HOLDERS = 'org_office_holders';

// The node SDK appends no version prefix to the endpoint, so normalise here
// too: Appwrite's runtime context supplies a bare host
// (`https://api.alivenigeria.org`) with no `/v1`, which makes every call miss
// the API and surface as the misleading "no available server".
function withApiVersion(endpoint) {
  const base = String(endpoint || '').replace(/\/+$/, '');
  return /\/v\d+$/.test(base) ? base : `${base}/v1`;
}

/**
 * Appwrite delivers `x-appwrite-events` either as an array of JSON strings or,
 * depending on the runtime and proxy, as a single comma-joined string. Parse
 * whichever shape arrives and return every event it describes.
 */
function parseEventHeaders(raw) {
  const parts = Array.isArray(raw) ? raw : String(raw || '').split(',');
  const events = [];
  for (const part of parts) {
    const text = String(part || '').trim();
    if (!text) continue;
    try {
      const parsed = JSON.parse(text);
      events.push(...(Array.isArray(parsed) ? parsed : [parsed]));
    } catch {
      // A header we cannot read is not a reason to drop the others.
    }
  }
  return events;
}

/**
 * Updates a document over REST instead of through the SDK.
 *
 * The installed SDK's updateDocument argument order does not match either
 * published convention in this runtime: with arity 5, passing `data` in the
 * fifth slot lands it in `permissions` and Appwrite rejects it with
 * 'Invalid `permissions` param: Permission "..." is not allowed'. Guessing the
 * right positional is guesswork, so this bypasses it.
 *
 * REST is also the form the rest of this project's scripts already use, and
 * Appwrite 1.8 requires the body wrapped as `{ data: { ... } }` -- a bare
 * payload is read as empty and reported as a permissions error.
 *
 * `apiBase` is passed in rather than read from module scope, because the
 * endpoint is only known once the handler has seen the request.
 */
async function updateDocument(apiBase, databaseId, collectionId, documentId, data) {
  const res = await fetch(
    `${apiBase}/databases/${databaseId}/collections/${collectionId}/documents/${documentId}`,
    {
      method: 'PATCH',
      headers: {
        'X-Appwrite-Project': process.env.APPWRITE_PROJECT_ID,
        'X-Appwrite-Key': process.env.APPWRITE_API_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ data }),
    },
  );
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`update ${collectionId}/${documentId} -> ${res.status}: ${t.slice(0, 200)}`);
  }
  return res.json();
}

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

  // Prefer the context client (its key is already scoped to this function) but
  // point it at the versioned API.
  const apiBase = withApiVersion(
    client?.config?.endpoint || req.headers['x-appwrite-endpoint'] || process.env.APPWRITE_ENDPOINT,
  );
  const sdkClient = (client ?? new Client()
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY))
    .setEndpoint(apiBase);
  const db = new Databases(sdkClient);

  const databaseId = process.env.APPWRITE_DATABASE_ID;

  try {
    // Appwrite 1.8 puts the whole new user in the request body for a
    // users.*.create event, so read the email from there first. The
    // x-appwrite-event / x-appwrite-user-id headers are only the event name and
    // an id, and the first deployed version read only those -- found no user,
    // and quietly bound nothing.
    //
    // Headers are still matched case-insensitively, because Appwrite's context
    // lower-cases them but a proxy in front of the function may not.
    const headerOf = (name) => {
      const wanted = name.toLowerCase();
      for (const [k, v] of Object.entries(req.headers || {})) {
        if (String(k).toLowerCase() === wanted) return v;
      }
      return undefined;
    };

    const rawEvents = headerOf('x-appwrite-events');
    const eventUserId = headerOf('x-appwrite-user-id');

    const events = parseEventHeaders(rawEvents);
    log(`parsed ${events.length} event(s) from x-appwrite-events`);

    // Candidate sources, best first: the body (complete), then the event header
    // (older builds), then a direct call for a manual retry.
    let user = null;
    for (const source of [req.bodyJson, ...events.map((ev) => ev?.data ?? ev)]) {
      const candidate = source && typeof source === 'object' ? source : null;
      if (candidate?.$id && candidate?.email) {
        user = candidate;
        break;
      }
      if (candidate?.userId && !user) user = candidate;
    }
    if (user?.email) log(`user ${user.$id} <${user.email}> from ${req.bodyJson?.email ? 'body' : 'event header'}`);

    // Fallback for a manual retry that sends only a userId, and for a body that
    // somehow lacks the email. The event body normally has it, so this rarely
    // runs -- and the function's own key can report "no available server" for
    // users.get, so a failure here is logged and tolerated rather than fatal.
    const userId = eventUserId || user?.$id || user?.userId;
    if (userId && !user?.email) {
      try {
        const users = new Users(sdkClient);
        user = await users.get(userId);
        log(`resolved ${userId} -> ${user.email} via users.get`);
      } catch (e) {
        log(`users.get failed for ${userId}: ${e?.message ?? e}`);
      }
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
    // A person can hold more than one office -- Timothy is Treasurer *and*
    // Director Logistics. Taking only the first match left the rest of their
    // queue rows pending forever, so the office gate stayed closed for part of
    // their access. Bind every pending row.
    const matches = await db.listDocuments(databaseId, REGISTRY, [
      Query.equal('email', email),
      Query.equal('consumed', false),
      Query.limit(100),
    ]);

    if (!matches.documents.length) {
      log(`${email}: no pending office; nothing to do`);
      return res.json({ ok: true, bound: false, reason: 'no pending office' });
    }
    log(`${email}: ${matches.documents.length} pending office(s) to bind`);

    const bound = [];
    const skipped = [];

    for (const entry of matches.documents) {
      const officeId = String(entry.office_id || '').trim();
      if (!officeId) {
        log(`${email}: registry row ${entry.$id} has no office_id; skipped`);
        skipped.push({ office_id: null, reason: 'registry row has no office' });
        continue;
      }

      try {
        const holders = await db.listDocuments(databaseId, HOLDERS, [
          Query.equal('office_id', officeId),
          Query.limit(1),
        ]);
        if (!holders.documents.length) {
          log(`${email}: no org_office_holders row for ${officeId}; skipped`);
          skipped.push({ office_id: officeId, reason: 'no holder row' });
          continue;
        }

        // Only attributes that exist on org_office_holders. The schema has no
        // bound_at/bound_by, and Appwrite rejects an update naming an unknown
        // attribute outright with 'Unknown attribute', failing the whole write.
        // When the binding happened is already on the document as $updatedAt.
        await updateDocument(apiBase, databaseId, HOLDERS, holders.documents[0].$id, {
          user_id: user.$id,
          email: user.email,
          full_name: entry.full_name || user.name || '',
          is_current: true,
        });

        // Retire the registry row so a later account reusing the address cannot
        // silently inherit the office.
        await updateDocument(apiBase, databaseId, REGISTRY, entry.$id, {
          consumed: true,
          consumed_by: user.$id,
          consumed_at: new Date().toISOString(),
        });

        log(`${email} bound to ${officeId} as ${user.$id}`);
        bound.push(officeId);
      } catch (e) {
        // One office failing must not cost the person the others.
        log(`${email}: binding ${officeId} failed: ${e?.message ?? e}`);
        skipped.push({ office_id: officeId, reason: e?.message ?? String(e) });
      }
    }

    return res.json({
      ok: true,
      bound: bound.length > 0,
      office_ids: bound,
      user_id: user.$id,
      ...(skipped.length ? { skipped } : {}),
    });
  } catch (e) {
    // A signup must never be blocked by this.
    log(`failed: ${e?.message ?? e}`);
    return res.json({ ok: false, error: e?.message ?? String(e) });
  }
};
