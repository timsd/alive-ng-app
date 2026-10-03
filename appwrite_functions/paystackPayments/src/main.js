import { Client, Databases, ID, Query } from 'node-appwrite';

const databaseId = process.env.APPWRITE_DATABASE_ID || '6a089307002e54291a32';
const paymentLogsCollectionId = process.env.APPWRITE_PAYMENT_LOGS_COLLECTION_ID || 'payment_logs';
const appSettingsCollectionId =
  process.env.APPWRITE_APP_SETTINGS_COLLECTION_ID || 'app_settings';
// LAST-RESORT value, used only when every live FX provider AND the Appwrite
// `app_settings` rate row are unreachable, so checkout never blocks.
//
// It is NOT the rate a donor is normally billed at: the live market rate is
// always preferred (see getConfiguredUsdToNgnRate). Keep this number in sync
// with the two other copies of the same fallback:
//   lib/services/exchange_rate_service.dart  -> ExchangeRateService.fallbackRate
//   web/donation.html                        -> FALLBACK_RATE
const FALLBACK_USD_TO_NGN = Number(process.env.USD_TO_NGN_RATE || 1380);

const MIN_VALID_RATE = 500;   // outer sanity floor (USD->NGN)
const MAX_VALID_RATE = 5000;  // outer sanity ceiling (USD->NGN)
const MAX_DEVIATION = 0.30;   // ±30% of the trusted reference rate

// Branding asset embedded at the top of outbound receipts. Matches the asset
// the `send_email` function already uses so every ALIVE email is branded the
// same way.
const ALIVE_LOGO_URL =
  process.env.ALIVE_LOGO_URL ||
  'https://app.alivenigeria.org/assets/assets/images/alive_logo.svg';

// Display names for the client's `DonationType` enum values. Used as the
// receipt/report fallback when a donor gives without picking a project.
// Keep in sync with `DonationType.typeDisplayName` in
// lib/models/donation_models.dart.
//
// 'ministrySupport' is intentionally absent: it was retired because a gift
// aimed at a specific project is identified by project_id/project_title, not
// by a separate donation type. Historic rows still carrying that value fall
// through to 'General Support'.
const DONATION_TYPE_LABELS = {
  tractProduction: 'Tract Production',
  generalSupport: 'General Support',
  appMaintenance: 'App Maintenance',
};

/**
 * Escapes text destined for an HTML email body.
 *
 * The purpose string can contain a donor- or admin-supplied project title, so
 * it must never be interpolated raw -- an unescaped "&" or "<" would break the
 * receipt markup.
 */
function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Two-stage guard against API errors over-charging donors:
//   1. Hard bounds reject obviously broken values (inverted
//      rates like 50, or spikes like 50 000).
//   2. A ±30% deviation band around the trusted fallback rejects
//      anything further afield than ~₦966 / ₦1 794 today.
// The deviation band is intentionally wider than 20% because the
// Naira is volatile — the 2023 float crisis still stayed under
// ₦2 000. If a legitimate rate is ever rejected, widen this
// band or refresh USD_TO_NGN_RATE rather than removing the check.
function isValidRate(value, referenceRate = FALLBACK_USD_TO_NGN) {
  const n = Number(value);
  if (!Number.isFinite(n) || n < MIN_VALID_RATE || n > MAX_VALID_RATE) {
    return false;
  }
  const min = referenceRate * (1 - MAX_DEVIATION);
  const max = referenceRate * (1 + MAX_DEVIATION);
  return n >= min && n <= max;
}

async function fetchJsonWithTimeout(url, { timeoutMs = 7000, headers } = {}) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, { headers, signal: ctrl.signal });
    if (!res.ok) return null;
    return await res.json();
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

// Free, key-less USD -> NGN providers, tried in order. No API key and no quota
// to maintain, so the rate a donor is quoted is the live market rate at
// checkout time rather than a number somebody has to remember to update.
//
// NOTE: `api.frankfurter.app` was removed deliberately — it serves the ECB
// reference set, which does not include the Naira, so it always answered 404
// and just delayed the next provider.
const FX_PROVIDERS = [
  {
    name: 'open.er-api.com',
    url: 'https://open.er-api.com/v6/latest/USD',
    pick: (json) => json?.rates?.NGN,
  },
  {
    name: 'exchangerate-api.com',
    url: 'https://api.exchangerate-api.com/v4/latest/USD',
    pick: (json) => json?.rates?.NGN,
  },
  {
    name: 'currency-api',
    url: 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json',
    pick: (json) => json?.usd?.ngn,
  },
];

async function getLiveUsdToNgnRate() {
  for (const provider of FX_PROVIDERS) {
    const json = await fetchJsonWithTimeout(provider.url);
    const rate = provider.pick(json);
    if (isValidRate(rate, FALLBACK_USD_TO_NGN)) {
      return { rate: Number(rate), source: provider.name };
    }
  }
  return null;
}

// Negotiable rate shown to donors AND used to convert USD donations that
// Paystack cannot charge in dollars.
//
// Priority is deliberately "live first": the quoted rate is the market rate at
// checkout time, so nobody has to keep a constant up to date.
//   1. Admin pin  — only when USD_TO_NGN_PIN_RATE=true is set explicitly.
//   2. Live market rate (free key-less providers, see FX_PROVIDERS).
//   3. Appwrite `app_settings` row — last known good rate the admin owns,
//      updatable without redeploying the function.
//   4. USD_TO_NGN_RATE env value, if configured.
//   5. FALLBACK_USD_TO_NGN — last resort only, so checkout never blocks.
async function getConfiguredUsdToNgnRate(log) {
  const envRate = Number(process.env.USD_TO_NGN_RATE);
  const pinned =
    String(process.env.USD_TO_NGN_PIN_RATE || '').toLowerCase() === 'true';

  // 1. Deliberate admin pin (opt-in, so live rates stay the default).
  if (pinned && isValidRate(envRate)) {
    return { rate: envRate, source: 'env USD_TO_NGN_RATE (pinned)' };
  }
  // 2. Live market rate.
  const live = await getLiveUsdToNgnRate();
  if (live) return live;
  // 3. Admin-published Appwrite setting (app_settings key `usd_to_ngn`).
  try {
    if (process.env.APPWRITE_API_KEY && process.env.APPWRITE_ENDPOINT) {
      const client = new Client()
        .setEndpoint(process.env.APPWRITE_ENDPOINT)
        .setProject(process.env.APPWRITE_PROJECT_ID || '')
        .setKey(process.env.APPWRITE_API_KEY);
      const databases = new Databases(client);
      const tryKeys = ['usd_to_ngn', 'usd_to_ngn_rate', 'exchange_rate_usd_ngn'];
      for (const key of tryKeys) {
        try {
          const res = await databases.listDocuments(databaseId, appSettingsCollectionId, [
            Query.equal('key', key),
            Query.limit(1),
          ]);
          const match = res?.documents?.[0];
          const raw = match?.value ?? match?.setting_value;
          if (isValidRate(raw)) {
            return { rate: Number(raw), source: `app_settings:${key}` };
          }
        } catch (_) {
          continue;
        }
      }
    }
  } catch (e) {
    if (log) log(`Appwrite rate setting lookup failed: ${e.message}`);
  }
  // 4. Previously configured rate.
  if (isValidRate(envRate)) {
    return { rate: envRate, source: 'env USD_TO_NGN_RATE' };
  }
  // 5. Safe fallback so checkout never blocks on FX downtime.
  return { rate: FALLBACK_USD_TO_NGN, source: 'fallback' };
}

async function getPaystackPublicKey(log) {
  if (process.env.PAYSTACK_PUBLIC_KEY && process.env.PAYSTACK_PUBLIC_KEY.trim()) {
    return process.env.PAYSTACK_PUBLIC_KEY.trim();
  }
  try {
    const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
    const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT || process.env.APPWRITE_ENDPOINT;
    const projId = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID || '';
    if (apiKey && endpoint) {
      const client = new Client()
        .setEndpoint(endpoint)
        .setProject(projId)
        .setKey(apiKey);
      const databases = new Databases(client);
      const res = await databases.listDocuments(databaseId, appSettingsCollectionId, [
        Query.equal('key', 'paystack_public_key'),
        Query.limit(1),
      ]);
      const match = res?.documents?.[0];
      const val = match?.value ?? match?.setting_value;
      if (typeof val === 'string' && val.trim().startsWith('pk_')) {
        return val.trim();
      }
    }
  } catch (e) {
    if (log) log(`Paystack public key lookup failed: ${e.message}`);
  }
  return '';
}

async function getPaystackSecretKey(log) {
  if (process.env.PAYSTACK_SECRET_KEY && process.env.PAYSTACK_SECRET_KEY.trim()) {
    return process.env.PAYSTACK_SECRET_KEY.trim();
  }
  try {
    const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
    const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT || process.env.APPWRITE_ENDPOINT;
    const projId = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID || '';
    if (apiKey && endpoint) {
      const client = new Client()
        .setEndpoint(endpoint)
        .setProject(projId)
        .setKey(apiKey);
      const databases = new Databases(client);
      const res = await databases.listDocuments(databaseId, appSettingsCollectionId, [
        Query.equal('key', 'paystack_secret_key'),
        Query.limit(1),
      ]);
      const match = res?.documents?.[0];
      const val = match?.value ?? match?.setting_value;
      if (typeof val === 'string' && val.trim().startsWith('sk_')) {
        return val.trim();
      }
    }
  } catch (e) {
    if (log) log(`Paystack secret key lookup failed: ${e.message}`);
  }
  return '';
}

export default async ({ req, res, log, error }) => {
  if (req.method !== 'POST') {
    return res.json({ error: 'Method not allowed. Use POST.' }, 405);
  }

  try {
    const secret = await getPaystackSecretKey(log);
    if (!secret) {
      error('Missing PAYSTACK_SECRET_KEY in function environment or app_settings.');
      return res.json({ error: 'Paystack is not configured.' }, 500);
    }

    let parsedBody = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    if (parsedBody && typeof parsedBody.body === 'string') {
      try { parsedBody = JSON.parse(parsedBody.body); } catch (_) { }
    } else if (parsedBody && parsedBody.body && typeof parsedBody.body === 'object') {
      parsedBody = parsedBody.body;
    }
    const body = parsedBody || {};
    if (containsRawCardData(body)) {
      return res.json({ error: 'Raw card data must be submitted only to Paystack checkout.' }, 400);
    }

    const action = body.action || 'initialize_transaction';

    // ── Public rate lookup (no Paystack call). Lets web + Flutter show a
    // ── live "$1 ≈ ₦X" label from the market rate instead of a constant. ──
    if (action === 'get_exchange_rate' || action === 'get_payment_config') {
      const { rate, source } = await getConfiguredUsdToNgnRate(log);
      const publicKey = await getPaystackPublicKey(log);
      return res.json({
        rate,
        source,
        pair: 'USD_NGN',
        live: source !== 'fallback',
        paystack_public_key: publicKey,
        updated_at: new Date().toISOString(),
      });
    }

    // ── Direct verification flow (from client return or webhook fallback) ──
    if (action === 'verify_transaction') {
      const ref = body.reference || body.trxref;
      if (!ref) {
        return res.json({ error: 'Missing reference to verify.' }, 400);
      }
      const verifyRes = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(ref)}`, {
        headers: {
          Authorization: `Bearer ${secret}`,
          'Content-Type': 'application/json',
        },
      });
      const verifyData = await verifyRes.json();
      if (!verifyData.status) {
        return res.json({ error: verifyData.message || 'Verification failed.' }, 400);
      }
      const pData = verifyData.data;
      if (pData.status === 'success') {
        await handleVerifiedPayment(pData, log);
      }
      return res.json({
        success: pData.status === 'success',
        status: pData.status,
        reference: pData.reference,
        amount: pData.amount / 100,
        currency: pData.currency,
        paid_at: pData.paid_at,
        customer: pData.customer,
        metadata: pData.metadata,
      });
    }

    // ── Manage a recurring subscription (list / cancel) ──
    if (action === 'list_subscriptions' || action === 'cancel_subscription') {
      const fnError = (message, status = 400) => res.json({ error: message }, status);
      const paystack = async (path, { method = 'GET', payload = null } = {}) => {
        const resp = await fetch(`https://api.paystack.co${path}`, {
          method,
          headers: {
            Authorization: `Bearer ${secret}`,
            'Content-Type': 'application/json',
          },
          ...(payload ? { body: JSON.stringify(payload) } : {}),
        });
        const json = await resp.json().catch(() => ({}));
        if (!json?.status) {
          throw new Error(json?.message || 'Paystack request failed.');
        }
        return json.data;
      };

      // The donor's email is the only reliable key: find their live
      // (non-cancelled) subscriptions and filter by match below.
      const donorEmail =
        typeof body.email === 'string' && body.email.trim()
          ? body.email.trim().toLowerCase()
          : (typeof body.metadata?.donor_email === 'string'
              ? body.metadata.donor_email.trim().toLowerCase()
              : '');
      if (!donorEmail) {
        return fnError('Missing donor email.');
      }

      let subscriptions;
      try {
        subscriptions = await paystack('/subscription?perPage=100');
      } catch (listErr) {
        return fnError(`Could not list subscriptions: ${listErr.message}`, 502);
      }

      const owned = (Array.isArray(subscriptions) ? subscriptions : []).filter(
        (sub) =>
          typeof sub?.customer?.email === 'string' &&
          sub.customer.email.trim().toLowerCase() === donorEmail &&
          String(sub?.status || '').toLowerCase() !== 'cancelled',
      );

      if (action === 'list_subscriptions') {
        return res.json({
          ok: true,
          email: donorEmail,
          count: owned.length,
          subscriptions: owned.map((sub) => ({
            subscription_code: sub.subscription_code,
            email_token: sub.email_token,
            status: sub.status,
            amount: sub.amount,
            currency: sub.plan?.currency || null,
            plan: sub.plan?.name || null,
            plan_code: sub.plan?.plan_code || null,
            next_payment_date: sub.next_payment_date || null,
          })),
        });
      }

      // cancel_subscription: pin down exactly ONE subscription.
      const code =
        typeof body.subscription_code === 'string' && body.subscription_code.trim()
          ? body.subscription_code.trim()
          : typeof body.email_token === 'string' && body.email_token.trim()
            ? body.email_token.trim()
            : '';
      let target = owned.find(
        (sub) => sub.subscription_code === code || sub.email_token === code,
      );
      if (!target && owned.length === 1 && !code) {
        target = owned[0];
      }
      if (!target) {
        if (owned.length === 0) {
          return res.json({ ok: true, cancelled: false, count: 0, message: 'No active subscriptions found.' });
        }
        return fnError('Multiple active subscriptions found. Please choose which one to cancel.', 409);
      }

      try {
        await paystack('/subscription/disable', {
          method: 'POST',
          payload: { code: target.subscription_code, token: target.email_token },
        });
      } catch (cancelErr) {
        return fnError(`Cancellation failed: ${cancelErr.message}`, 502);
      }

      return res.json({
        ok: true,
        cancelled: true,
        subscription_code: target.subscription_code,
        plan: target.plan?.name || null,
        message: 'Your monthly donation has been cancelled.',
      });
    }

    const reference = validateReference(body.reference);
    const email = validateEmail(body.email);
    const appwriteUserId =
      typeof req.headers['x-appwrite-user-id'] === 'string'
        ? req.headers['x-appwrite-user-id']
        : '';
    const bodyUserId =
      typeof body.appwrite_user_id === 'string'
        ? body.appwrite_user_id.trim()
        : '';
    const userId = appwriteUserId || bodyUserId || 'guest';
    const isGuest = !appwriteUserId;
    const callbackUrl = body.callback_url;
    const channels = Array.isArray(body.channels) ? body.channels : undefined;
    const currency = typeof body.currency === 'string' && body.currency.trim() ? body.currency : 'NGN';
    const metadata = {
      ...(body.metadata || {}),
      appwrite_user_id: userId,
      guest_donation: isGuest,
      reference,
    };

    const payload = {
      email,
      reference,
      callback_url: callbackUrl,
      channels,
      currency,
      metadata,
    };

    const amount = Number(body.amount);
    if (Number.isFinite(amount) && amount > 0) {
      payload.amount = Math.round(amount);
    } else if (action !== 'initialize_subscription') {
      return res.json({ error: 'Invalid amount.' }, 400);
    }

    // Paystack plan facts, verified live against the API (see
    // scripts/probe_plan_api.mjs):
    //   * `amount` is in the SMALLEST unit (kobo), e.g. 10000 = N100.
    //   * It must be a JSON number (a stringified "1000" is rejected) and
    //     Paystack enforces a hard floor of N100 => 10000 kobo.
    //   * `currency: "USD"` is rejected outright: "USD not a supported currency".
    //     There is no USD plan, so a USD monthly gift must be converted to its
    //     NGN equivalent BEFORE the plan is created -- waiting for the
    //     transaction call to fail first meant the plan was already dead.
    const MIN_PLAN_KOBO = 10000;

    if (action === 'initialize_subscription') {
      // Dynamic plans only: the donor's own amount becomes a fresh Paystack
      // plan every time. There is intentionally NO static/env plan fallback
      // (the plans those env vars pointed at were deleted).
      if (!payload.amount || !(payload.amount > 0)) {
        return res.json({ error: 'Invalid amount.' }, 400);
      }

      // USD monthly gifts: first attempt direct USD plan creation so donors
      // are billed in USD directly and settled into the merchant's USD account.
      // If the account does not support USD plans, fallback seamlessly to NGN.
      let planCurrency = (payload.currency || 'NGN').toUpperCase();
      let planAmountMinor = payload.amount;
      let conversion = null;
      let planCode = null;
      let planName = '';

      if (planCurrency === 'USD') {
        if (planAmountMinor < 100) {
          return res.json({
            error: 'Recurring USD donations must be at least $1.00 per month.',
          }, 400);
        }

        // 1. Attempt direct USD plan creation on merchant account
        planName = makeDynamicPlanName('USD', planAmountMinor, false);
        planCode = await createDynamicPlan({
          secret,
          log,
          name: planName,
          amount: planAmountMinor,
          currency: 'USD',
        });

        // 2. If Paystack rejects direct USD plan creation, fallback to NGN conversion
        if (!planCode) {
          log('Paystack direct USD plan creation not available. Falling back to NGN conversion for recurring plan.');
          const clientRate = Number(
            body?.metadata?.exchange_rate_usd_ngn ?? body?.metadata?.exchange_rate,
          );
          let exchangeRate = clientRate;
          let rateSource = 'client';
          if (!Number.isFinite(exchangeRate) || exchangeRate <= 100) {
            const resolved = await getConfiguredUsdToNgnRate(log);
            exchangeRate = resolved.rate;
            rateSource = resolved.source;
          }
          const usdAmount = planAmountMinor / 100;
          planAmountMinor = Math.round(usdAmount * exchangeRate * 100);
          planCurrency = 'NGN';
          conversion = {
            original_currency: 'USD',
            original_amount: usdAmount,
            exchange_rate: exchangeRate,
            exchange_rate_source: rateSource,
            converted_to_ngn: true,
          };
          log(
            `Converting monthly $${usdAmount} USD to N${planAmountMinor / 100} NGN ` +
              `at rate ${exchangeRate} (${rateSource}) before creating the plan.`,
          );

          if (planAmountMinor < MIN_PLAN_KOBO) {
            return res.json({
              error: `Recurring donations must be at least N${MIN_PLAN_KOBO / 100} per month. Increase the amount or choose a one-time donation.`,
            }, 400);
          }

          planName = makeDynamicPlanName(planCurrency, planAmountMinor, true);
          planCode = await createDynamicPlan({
            secret,
            log,
            name: planName,
            amount: planAmountMinor,
            currency: planCurrency,
          });
        }
      } else {
        if (planAmountMinor < MIN_PLAN_KOBO) {
          return res.json({
            error: `Recurring donations must be at least N${MIN_PLAN_KOBO / 100} per month.`,
          }, 400);
        }
        planName = makeDynamicPlanName(planCurrency, planAmountMinor, false);
        planCode = await createDynamicPlan({
          secret,
          log,
          name: planName,
          amount: planAmountMinor,
          currency: planCurrency,
        });
      }

      if (!planCode) {
        return res.json({ error: 'Could not create a recurring plan. Please try a one-time donation.' }, 400);
      }

      payload.plan = planCode;
      // When using a plan, Paystack ignores the `amount` field and uses
      // the plan's amount instead, so we remove it to avoid confusion.
      delete payload.amount;
      payload.currency = planCurrency;
      payload.metadata = {
        ...payload.metadata,
        ...(conversion || {}),
        recurring: true,
        plan_code: planCode,
        requested_amount: body.amount,
        plan_amount_minor: planAmountMinor,
        plan_name: planName,
      };
    }

    let paystackResponse = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secret}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });
    let json = await paystackResponse.json();

    // ── Channel rejection recovery ──────────────────────────────────────────
    // Paystack fails the WHOLE initialization when `channels` contains one it
    // cannot use for this account/currency (e.g. "mobile_money is not a valid
    // channel" / "channel_not_supported"). The web donation page never sends
    // channels, which is why the APK-only failure happened for BOTH NGN and USD
    // while the web page worked. Already-installed APK builds still send the old
    // hardcoded list, so retry once exactly like the web page: omit the field.
    if (!json?.status && Array.isArray(payload.channels) && payload.channels.length > 0) {
      log(
        `Paystack init failed with channels [${payload.channels.join(', ')}]: ` +
          `${json?.message}. Retrying without the channels field (web parity).`,
      );
      const firstErrorMessage = json?.message;
      delete payload.channels;
      paystackResponse = await fetch('https://api.paystack.co/transaction/initialize', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${secret}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });
      json = await paystackResponse.json();
      if (!json?.status) {
        // Keep the original channel-specific reason when the retry also fails.
        json.message =
          json.message ||
          firstErrorMessage ||
          'Paystack initialization failed.';
      }
    }

    // If Paystack rejects USD (unsupported_currency), fallback seamlessly to NGN conversion
    // One-time USD gifts only. Recurring gifts are already converted to NGN and
    // carry a plan by this point, so there is no amount left to re-convert here.
    if (!json?.status && action !== 'initialize_subscription' && (payload.currency === 'USD' || (json?.message && json.message.toLowerCase().includes('currency')))) {
      // Prefer a client-supplied fresh rate, else resolve live on the server
      // so the donor is billed at the current market rate — never stale.
      // Web sends `exchange_rate`, the Flutter app sends
      // `exchange_rate_usd_ngn`; accept either.
      const clientRate = Number(
        body?.metadata?.exchange_rate_usd_ngn ?? body?.metadata?.exchange_rate,
      );
      let exchangeRate = clientRate;
      let rateSource = 'client';
      if (!Number.isFinite(exchangeRate) || exchangeRate <= 100) {
        const resolved = await getConfiguredUsdToNgnRate(log);
        exchangeRate = resolved.rate;
        rateSource = resolved.source;
      }
      const usdAmount = (payload.amount || 0) / 100;
      const ngnAmountMinor = Math.round(usdAmount * exchangeRate * 100);
      log(`Paystack rejected USD currency. Converting $${usdAmount} USD to ₦${ngnAmountMinor / 100} NGN at rate ${exchangeRate} (${rateSource})`);
      payload.currency = 'NGN';
      payload.amount = ngnAmountMinor;
      payload.metadata = {
        ...payload.metadata,
        original_currency: 'USD',
        original_amount: usdAmount,
        exchange_rate: exchangeRate,
        exchange_rate_source: rateSource,
        converted_to_ngn: true,
      };
      // Keep the retry channel-rejection-proof as well.
      if (Array.isArray(payload.channels) && payload.channels.length > 1) {
        payload.channels = ['card'];
      }

      paystackResponse = await fetch('https://api.paystack.co/transaction/initialize', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${secret}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });
      json = await paystackResponse.json();
    }

    await writePaymentLog({
      event: action,
      reference,
      status: json?.status ? 'initialized' : 'failed',
      payload: json,
      log,
    });

    if (!json?.status) {
      return res.json({
        error: json?.message || 'Paystack initialization failed.',
        data: json,
      }, 502);
    }

    const publicKey = await getPaystackPublicKey(log);
    return res.json({
      ...(json.data || {}),
      public_key: publicKey,
    });
  } catch (err) {
    error(`Paystack initialization failed: ${err.message}`);
    return res.json({ error: err.message || 'Internal Server Error' }, 500);
  }
};

function validateEmail(value) {
  if (typeof value !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
    throw new Error('Invalid email.');
  }
  return value;
}

function validateReference(value) {
  if (typeof value !== 'string' || value.length < 8 || value.length > 128) {
    throw new Error('Invalid reference.');
  }
  return value;
}

function containsRawCardData(value) {
  const blockedKeys = new Set([
    'card',
    'card_number',
    'cardnumber',
    'number',
    'pan',
    'cvv',
    'cvc',
    'security_code',
    'expiry',
    'expiry_month',
    'expiry_year',
    'exp_month',
    'exp_year',
  ]);

  const visit = (item) => {
    if (!item || typeof item !== 'object') return false;
    if (Array.isArray(item)) return item.some(visit);

    return Object.entries(item).some(([key, child]) => {
      const normalized = key.toLowerCase().replace(/[\s-]/g, '_');
      if (blockedKeys.has(normalized)) return true;
      return visit(child);
    });
  };

  return visit(value);
}

async function writePaymentLog({ event, reference, status, payload, log }) {
  try {
    const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
    const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT || process.env.APPWRITE_ENDPOINT;
    const projectId = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
    if (!apiKey || !endpoint || !projectId) return;

    const client = new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey);
    const databases = new Databases(client);
    await databases.createDocument(
      databaseId,
      paymentLogsCollectionId,
      ID.unique(),
      {
        provider: 'paystack',
        reference,
        event,
        status,
        payload: JSON.stringify(payload),
        created_at: new Date().toISOString(),
      },
    );
  } catch (err) {
    if (log) log(`Skipping payment log write: ${err.message}`);
  }
}

// ── Dynamic subscription plans ───────────────────────────────────────────
// There is intentionally NO static/pre-configured plan fallback: every monthly
// donation creates its own plan for the donor's exact amount (NGN or the NGN
// equivalent of a USD amount), because the plans the env vars used to point
// at have been deleted from the Paystack dashboard.
function makeDynamicPlanName(currency, amountMinor, fromUsd = false) {
  const major = amountMinor / 100;
  const money = Number.isInteger(major) ? String(major) : major.toFixed(2);
  const stamp = Date.now().toString(36).toUpperCase();
  const suffix = fromUsd ? ' (from USD)' : '';
  return `ALIVE Monthly ${currency} ${money}${suffix} ${stamp}`;
}

async function createDynamicPlan({ secret, log, name, amount, currency }) {
  try {
    const createPlanRes = await fetch('https://api.paystack.co/plan', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secret}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name,
        interval: 'monthly',
        amount,
        currency,
      }),
    });
    const planJson = await createPlanRes.json();
    if (planJson?.status && planJson?.data?.plan_code) {
      if (log) log(`Created dynamic plan: ${planJson.data.plan_code} (${name})`);
      return planJson.data.plan_code;
    }
    if (log) log(`Dynamic plan creation failed: ${planJson?.message || 'unknown'}`);
    return null;
  } catch (planErr) {
    if (log) log(`Dynamic plan creation error: ${planErr.message}`);
    return null;
  }
}

/**
 * Works out what a completed gift was FOR, as a short human-readable phrase.
 *
 * The receipt is the donor's proof of what they gave toward, and the finance
 * team needs the same string on the stored record, so both use this. The
 * precedence intentionally mirrors `appwrite_admin_export_service.dart`
 * (`_resolvePurpose`) so the email, the CSV export and the in-app reports never
 * disagree about the same donation.
 */
async function resolveDonationPurpose({ databases, projectsCollectionId, metadata, donationType }) {
  const meta = metadata || {};

  const text = (v) => (typeof v === 'string' ? v.trim() : '');

  // 1. A split across several designations is the most specific answer, so it
  //    wins over everything else the donor picked.
  const split = Array.isArray(meta.fund_designations)
    ? meta.fund_designations.map(text).filter(Boolean)
    : [];
  if (split.length > 1) {
    return `Split donation: ${split.join(', ')}`;
  }
  if (split.length === 1) {
    return split[0];
  }

  const designation = text(meta.fund_designation);
  if (designation && !/^split:/i.test(designation)) {
    return designation;
  }

  // 2. Title of the project the donor selected on screen.
  const projectTitle = text(meta.project_title);
  if (projectTitle) return projectTitle;

  // 3. Same thing, but resolved from the projects collection so receipts stay
  //    correct even if the client did not send a title.
  const projectId = text(meta.project_id);
  if (projectId && databases && projectsCollectionId) {
    try {
      const project = await databases.getDocument(databaseId, projectsCollectionId, projectId);
      const name =
        text(project.title) ||
        text(project.name) ||
        text(project.project_name) ||
        text(project.purpose) ||
        text(project.description);
      if (name) return name;
    } catch (_) {
      // A missing project must never block the receipt.
    }
  }

  // 4. Otherwise fall back to the donation category the donor chose.
  const typeLabel = DONATION_TYPE_LABELS[text(donationType)];
  if (typeLabel) return typeLabel;

  return 'General Support';
}

/**
 * The credit marker lives on the donation row rather than in memory, so it
 * survives across the two independent executions that can see one payment:
 * the donor's `verify_transaction` call and Paystack's webhook.
 */
const PROJECT_CREDIT_FIELD = 'project_credited_at';

/**
 * True when this reference has already been added to a project target.
 * A missing donation row is treated as "not yet credited" so the payment is
 * never silently dropped just because the record write lost a race.
 */
async function hasProjectCredit(databases, collectionId, reference) {
  if (!databases || !collectionId || !reference) return false;
  try {
    const donation = await databases.getDocument(databaseId, collectionId, reference);
    return Boolean(donation && donation[PROJECT_CREDIT_FIELD]);
  } catch (_) {
    return false;
  }
}

/** Records that this reference has been added to a project target. */
async function markProjectCredited(databases, collectionId, reference) {
  if (!databases || !collectionId || !reference) return;
  try {
    await databases.updateDocument(databaseId, collectionId, reference, {
      [PROJECT_CREDIT_FIELD]: new Date().toISOString(),
    });
  } catch (_) {
    // The counter is already correct; failing to stamp the marker is not
    // worth failing the whole payment over.
  }
}

// The donor's `verify_transaction` call also sends a receipt, so this used to
// deliver two identical "Official Donation Receipt" emails for one gift. The
// marker lives on the donation row and is shared with `paystackPayments`.
const RECEIPT_SENT_FIELD = 'receipt_sent_at';

async function hasReceiptBeenSent(databases, reference) {
  if (!databases || !donationsCollectionId || !reference) return false;
  try {
    const donation = await databases.getDocument(databaseId, donationsCollectionId, reference);
    return Boolean(donation && donation[RECEIPT_SENT_FIELD]);
  } catch (_) {
    return false;
  }
}

async function markReceiptSent(databases, reference) {
  if (!databases || !donationsCollectionId || !reference) return;
  try {
    await databases.updateDocument(databaseId, donationsCollectionId, reference, {
      [RECEIPT_SENT_FIELD]: new Date().toISOString(),
    });
  } catch (_) {
    // The mail is already out; a missing stamp only risks a duplicate.
  }
}

/**
 * Adds to a project's raised total.
 *
 * `??` rather than `||` matters here: a brand-new project has `raised === 0`,
 * and `||` would read that as "unset" and fall through to `amount_raised`.
 */
async function addToProjectRaised({ databases, projectsCollectionId, projectId, amount }) {
  const project = await databases.getDocument(databaseId, projectsCollectionId, projectId);
  const current = Number(project.raised ?? project.amount_raised ?? 0);
  const next = current + amount;
  await databases.updateDocument(databaseId, projectsCollectionId, projectId, {
    raised: next,
    amount_raised: next,
    updated_at: new Date().toISOString(),
  });
  return next;
}

async function handleVerifiedPayment(paystackData, log) {
  try {
    const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
    const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT || process.env.APPWRITE_ENDPOINT;
    const projectId = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
    const donationsCollectionId = process.env.APPWRITE_DONATION_RECORDS_COLLECTION_ID || 'donation_records';
    const projectsCollectionId = process.env.APPWRITE_PROJECTS_COLLECTION_ID || 'projects';

    if (!apiKey || !endpoint || !projectId) return;
    const client = new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey);
    const databases = new Databases(client);

    const reference = paystackData.reference;
    const amountKobo = Number(paystackData.amount || 0);
    const amount = amountKobo / 100;
    const customerEmail = paystackData.customer?.email || paystackData.metadata?.donor_email || paystackData.metadata?.email || '';
    const donorName = paystackData.metadata?.donor_name || paystackData.customer?.first_name || 'Donor';
    const metadata = {
      ...(paystackData.metadata || {}),
      processor: 'paystack',
      channel: paystackData.channel,
      fees: paystackData.fees,
      gateway_response: paystackData.gateway_response,
      paid_at: paystackData.paid_at,
    };

    // Resolve what this gift was FOR, so the receipt and the stored record are
    // both traceable. Priority mirrors the admin export service
    // (`_resolvePurpose`) so the receipt, the CSV export and the in-app
    // reports all agree on the wording:
    //   1. an explicit purpose/designation chosen by the donor
    //   2. the selected project's title
    //   3. the project's human-readable name looked up in the DB
    //   4. the donation type (e.g. "Tract Production")
    //   5. "General Support"
    const purpose = await resolveDonationPurpose({
      databases,
      projectsCollectionId,
      metadata,
      donationType: paystackData.metadata?.donation_type || '',
    });

    // 1. Update or create donation record
    try {
      await databases.updateDocument(databaseId, donationsCollectionId, reference, {
        status: 'completed',
        transaction_id: String(paystackData.id || ''),
        purpose,
        project_title: purpose,
        completed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        metadata: JSON.stringify(metadata),
      });
    } catch (_) {
      try {
        await databases.createDocument(databaseId, donationsCollectionId, reference, {
          reference,
          status: 'completed',
          processor: 'paystack',
          purpose,
          project_title: purpose,
          amount_kobo: Math.round(amountKobo),
          amount,
          currency: paystackData.currency || 'NGN',
          user_id: paystackData.metadata?.user_id || paystackData.metadata?.appwrite_user_id || 'guest',
          // donorName is resolved above (metadata.donor_name, then the Paystack
          // customer's first name, then 'Donor'). It was computed but never
          // written, so every donation made through this function had a NULL
          // user_name and the admin list fell back to deriving a name from the
          // email address or showing 'Anonymous Donor'. Guest donors on the web
          // page are the worst affected, since they have no account to fall back
          // to.
          user_name: donorName,
          user_email: customerEmail,
          email: customerEmail,
          type: paystackData.metadata?.donation_type || 'generalSupport',
          payment_method: 'paystack',
          transaction_id: String(paystackData.id || ''),
          completed_at: new Date().toISOString(),
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          metadata: JSON.stringify(metadata),
        });
      } catch (e) {
        if (log) log(`Donation record save note: ${e.message}`);
      }
    }

    // 2. Increment project raised counter.
    //
    // This used to be a plain read-modify-write with two defects:
    //   a) it ran on BOTH the verify_transaction call and the Paystack webhook
    //      for the same donation, so one gift could be counted twice;
    //   b) `project.raised || project.amount_raised` treated a legitimate 0 as
    //      "missing" and fell through to the other field.
    // A per-reference credit marker on the donation row makes it idempotent,
    // and `??` keeps a real 0 intact.
    const projId = String(paystackData.metadata?.project_id || '').trim();
    const NON_PROJECT_IDS = new Set(['general_mission_fund', 'general_support', '']);
    if (projId && !NON_PROJECT_IDS.has(projId)) {
      try {
        const alreadyCredited = await hasProjectCredit(
          databases,
          donationsCollectionId,
          reference,
        );
        if (alreadyCredited) {
          if (log) {
            log(`Project ${projId} already credited for ${reference}; not double counting`);
          }
        } else {
          // Only NGN may raise an NGN-denominated target. A charge that
          // settled in another currency would otherwise be added as naira.
          const settled = String(paystackData.currency || 'NGN').toUpperCase();
          if (settled !== 'NGN') {
            if (log) {
              log(`Not crediting project ${projId}: settled in ${settled}, target is NGN`);
            }
          } else {
            await addToProjectRaised({
              databases,
              projectsCollectionId,
              projectId: projId,
              amount,
            });
            if (log) log(`Credited project ${projId} by ${amount}`);
            await markProjectCredited(databases, donationsCollectionId, reference);
          }
        }
      } catch (projErr) {
        if (log) log(`Skipping project raised update: ${projErr.message}`);
      }
    }

    // 3. Send donation receipt email.
    //
    // Paystack's webhook sends the same receipt, so a single gift produced two
    // identical "Official Donation Receipt" emails. The marker on the donation
    // row keeps it to one.
    const receiptAlreadySent = await hasReceiptBeenSent(databases, reference);
    if (receiptAlreadySent) {
      if (log) log(`Receipt already sent for ${reference}; not resending`);
    } else if (process.env.RESEND_API_KEY && customerEmail) {
      try {
        const dateStr = new Date().toLocaleDateString('en-NG', { year: 'numeric', month: 'long', day: 'numeric' });
        const currency = paystackData.currency || 'NGN';
        const formattedAmount = amount.toLocaleString();
        // Purpose and donor name can originate from metadata, so both are
        // escaped before going into the HTML body.
        const safePurpose = escapeHtml(purpose);
        const safeDonorName = escapeHtml(donorName);
        const safeReference = escapeHtml(reference);
        const isRecurring = Boolean(metadata?.recurring);
        const purposeRow = `<tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Purpose</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${safePurpose}</td></tr>`;
        const typeRow = `<tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Type</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${isRecurring ? 'Monthly recurring gift' : 'One-time gift'}</td></tr>`;
        const receiptHtml = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>Donation Receipt - ALIVE Nigeria</title></head><body style="font-family:Georgia,serif;max-width:600px;margin:0 auto;padding:20px;color:#1a202c;"><div style="text-align:center;border-bottom:3px solid #1a365d;padding-bottom:20px;margin-bottom:20px;"><img src="${ALIVE_LOGO_URL}" alt="ALIVE Nigeria" width="88" height="88" style="display:block;margin:0 auto 12px;border:0;outline:none;" /><h1 style="color:#1a365d;margin:0;">ALIVE Nigeria</h1><p style="color:#666;margin:4px 0;">Official Donation Receipt</p></div><div style="padding:10px 0;"><p>Dear ${safeDonorName},</p><p>Thank you for your generous donation to ALIVE Nigeria. Your support empowers our work across Nigeria.</p><p style="color:#4a5568;">Your gift of <strong>${escapeHtml(currency)} ${escapeHtml(formattedAmount)}</strong> was designated to <strong>${safePurpose}</strong>.</p><table style="width:100%;border-collapse:collapse;margin:20px 0;"><tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Donor Name</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${safeDonorName}</td></tr>${typeRow}${purposeRow}<tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Amount</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${escapeHtml(currency)} ${escapeHtml(formattedAmount)}</td></tr><tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Reference</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${safeReference}</td></tr><tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Date</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${escapeHtml(dateStr)}</td></tr></table><p style="color:#4a5568;font-size:14px;">Please retain this receipt for your records. Contact us at <a href="mailto:app@alivenigeria.org">app@alivenigeria.org</a> for any inquiries.</p></div><div style="text-align:center;border-top:1px solid #e2e8f0;padding-top:20px;color:#999;font-size:12px;"><p>ALIVE Nigeria &mdash; Thank you for your generosity.</p></div></body></html>`;

        // Receipts always come from the dedicated receipts@ identity so a
        // donor can distinguish a financial document from ministry mail.
        const sender =
          process.env.RECEIPT_SENDER_EMAIL || 'ALIVE Nigeria App <receipts@app.alivenigeria.org>';
        const replyTo = process.env.REPLY_TO_EMAIL || 'app@alivenigeria.org';
        const emailRes = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from: sender,
            to: [customerEmail],
            cc: [replyTo],
            reply_to: replyTo,
            subject: `Your ALIVE Nigeria Donation Receipt - ${reference}`,
            html: receiptHtml,
          }),
        });
        const resText = await emailRes.text();
        if (emailRes.ok) {
          if (log) log(`Receipt email dispatched to ${customerEmail}: status ${emailRes.status}`);
          // Stamp only after Resend accepted it, so a failure can be retried
          // by the other handler rather than silently swallowed.
          await markReceiptSent(databases, reference);
        } else if (log) {
          log(`Receipt email FAILED for ${customerEmail} (${emailRes.status}): ${resText}`);
        }
      } catch (mailErr) {
        if (log) log(`Receipt email error: ${mailErr.message}`);
      }
    }
  } catch (err) {
    if (log) log(`handleVerifiedPayment error: ${err.message}`);
  }
}



