# Password recovery — Appwrite template

The recovery email is the **only** place the recovery secret exists.

Appwrite 1.8.1 `createRecovery` returns `userId` with an **empty** `secret`
(confirmed by `scripts/test_password_reset.mjs`), so the branded Resend reset
link can never be built. That is why the app deliberately does not send one when
the secret comes back empty, and why this template is the whole mechanism.

## Before customising, the two bugs that made the link useless

Both were in our code, not the template. Both are now fixed:

1. **The recovery URL used the path style** while the app routes with a hash.
   `https://app.alivenigeria.org/reset-password` served index.html, Flutter
   booted with an empty fragment, and the reset screen never rendered. It is now
   `https://app.alivenigeria.org/#/reset-password`.
2. **The reset route redirected signed-out users to `/auth`** — so the screen was
   unreachable for exactly the members who had forgotten their password.

If you customise the template before those are deployed, the email will look
right and still land on a blank page.

## Applying it

Console → your project → **Settings → Templates → Recovery** (email type).

**Subject**

```
Reset your ALIVE Nigeria password
```

**Body** — the contents of `recovery.html` in this folder.

`{{link}}` is the only placeholder that matters: Appwrite expands it to the
recovery URL with `userId` and `secret` already attached. Do not edit it.

## Verify

1. Deploy the web build containing the two routing fixes.
2. Request a reset from the sign-in screen.
3. Confirm the link opens the reset form **with the fields enabled** (a blank
   page, or a redirect back to sign-in, means a routing fix is still missing
   from the deployed build).
4. Set a new password and sign in with it.

The project API key cannot read or write templates (`/v1/templates/email`
returns 404, which Appwrite uses to mask a missing scope), so this step is
Console-only and cannot be scripted from here.
