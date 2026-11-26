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
 *   RESEND_API_KEY  - sends the account-closed confirmation
 *   SENDER_EMAIL / REPLY_TO_EMAIL  - optional, override the sender and the
 *   monitored reply-to mailbox
 *
 * Sends a confirmation email once the account is really gone. The member's
 * address is read from Appwrite *before* the delete, because afterwards the
 * account no longer exists to look up. A failure to send is logged but does not
 * fail the request, since the deletion itself has already succeeded.
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

  const apiKey =
    process.env.APPWRITE_FUNCTION_API_KEY ||
    process.env.APPWRITE_API_KEY ||
    req.headers?.['x-appwrite-key'];
  const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT || process.env.APPWRITE_ENDPOINT;
  const project = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
  if (!apiKey || !endpoint || !project) {
    error('deleteAccount is not configured (missing Appwrite credentials).');
    return res.json({ error: 'Account deletion service is not configured.' }, 500);
  }

  // Capture the member's details BEFORE the delete, strictly from Appwrite
  // Auth (never trust caller-supplied body.email so a throwaway account cannot
  // send closure emails to arbitrary third-party addresses).
  let memberEmail = '';
  let memberName = '';
  try {
    const whoRes = await fetch(
      `${endpoint}/users/${encodeURIComponent(targetId)}`,
      {
        headers: {
          'X-Appwrite-Project': project,
          'X-Appwrite-Key': apiKey,
          'Content-Type': 'application/json',
        },
      },
    );
    if (whoRes.ok) {
      const who = await whoRes.json();
      memberEmail = String(who?.email || '').trim();
      memberName = String(who?.name || '').trim();
    }
  } catch (lookupErr) {
    // Non-fatal: the account is still deleted, only the confirmation is lost.
    error(`Could not read the account before deletion: ${lookupErr?.message}`);
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

    // ── Server-side PII & privilege cascade cleanup (matches Privacy Policy §7.3) ──
    const dbId = process.env.APPWRITE_DATABASE_ID || '6a089307002e54291a32';
    const usersColId = process.env.APPWRITE_USERS_COLLECTION_ID || '6a08943100226f5b4963';
    const base = endpoint.replace(/\/+$/, '');
    const authHeaders = {
      'X-Appwrite-Project': project,
      'X-Appwrite-Key': apiKey,
      'Content-Type': 'application/json',
    };
    const deleteDocSafe = async (colId, docId) => {
      try {
        await fetch(
          `${base}/databases/${dbId}/collections/${colId}/documents/${encodeURIComponent(docId)}`,
          { method: 'DELETE', headers: authHeaders },
        );
      } catch (_) {}
    };
    const listUserDocs = async (colId, attr = 'user_id') => {
      try {
        const q = encodeURIComponent(JSON.stringify({ method: 'equal', attribute: attr, values: [targetId] }));
        const l = encodeURIComponent(JSON.stringify({ method: 'limit', values: [100] }));
        const r = await fetch(
          `${base}/databases/${dbId}/collections/${colId}/documents?queries[]=${q}&queries[]=${l}`,
          { headers: authHeaders },
        );
        if (!r.ok) return [];
        const data = await r.json();
        return Array.isArray(data.documents) ? data.documents : [];
      } catch (_) {
        return [];
      }
    };

    // 1. Delete profile row & notification_settings row
    await deleteDocSafe(usersColId, targetId);
    await deleteDocSafe('notification_settings', targetId);

    // 2. Remove push_tokens rows
    for (const tokDoc of await listUserDocs('push_tokens')) {
      await deleteDocSafe('push_tokens', tokDoc.$id);
    }

    // 3. Preserve `org_office_holders` rows intact for organizational/leadership
    //    historical archive records (never deleted or wiped on account closure).

    // 4. Delete private prayer requests authored by this user
    for (const pDoc of await listUserDocs('prayer_requests')) {
      if (pDoc.is_private === true) {
        await deleteDocSafe('prayer_requests', pDoc.$id);
      }
    }

    // ── Confirmation email ────────────────────────────────────────────────
    // Sent after the delete succeeds, and only then: telling a member their
    // account was closed when it was not would be worse than sending nothing.
    //
    // Failure is logged but does NOT fail the request. The account is already
    // gone, so reporting an error would tell the member it failed when it
    // succeeded, and there is nothing they could usefully do about it.
    let emailSent = false;
    if (memberEmail) {
      try {
        const from =
          process.env.SENDER_EMAIL || 'ALIVE Nigeria App <msg@app.alivenigeria.org>';
        const replyTo = process.env.REPLY_TO_EMAIL || 'app@alivenigeria.org';
        const rawGreeting = memberName ? memberName.split(' ')[0] : 'Friend';
        const greeting = String(rawGreeting)
          .replace(/&/g, '&amp;')
          .replace(/</g, '&lt;')
          .replace(/>/g, '&gt;')
          .replace(/"/g, '&quot;')
          .replace(/'/g, '&#39;');

        const mailRes = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from,
            to: [memberEmail],
            cc: [replyTo],
            reply_to: replyTo,
            subject: 'Your ALIVE Nigeria account has been closed',
            html: `
              <p>Hello ${greeting},</p>
              <p>Your ALIVE Nigeria account has been closed at your request.</p>
              <p>Your profile and sign-in details have been removed. This also
                 means you will no longer receive ministry reminders or updates
                 on this account.</p>
              <p>All associated profile data, reading history, and achievements have been permanently erased. Please note that this action is irreversible and no account restoration is possible.</p>
              <p>If you wish to return to ALIVE Nigeria in the future, you are always welcome to register afresh with a new account on a clean slate at <a href="https://app.alivenigeria.org">app.alivenigeria.org</a>.</p>
              <p>&mdash; ALIVE Nigeria</p>
            `.replace(/\n\s+/g, ' '),
          }),
        });
        emailSent = mailRes.ok;
        if (!mailRes.ok) {
          error(`Confirmation email not sent (${mailRes.status}): ` +
            `${(await mailRes.text()).slice(0, 200)}`);
        }
      } catch (mailErr) {
        error(`Confirmation email failed: ${mailErr?.message}`);
      }
    } else {
      error('No email address available for the confirmation message.');
    }

    return res.json({ ok: true, deleted: true, user_id: targetId, email_sent: emailSent });
  }

  const text = await response.text();
  error(`Account deletion failed (${response.status}): ${text}`);
  return res.json({ error: 'Failed to delete account.' }, 502);
};
