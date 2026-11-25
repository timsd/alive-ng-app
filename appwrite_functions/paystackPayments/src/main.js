import { Client, Databases, ID, Query, Users } from 'node-appwrite';

const databaseId = process.env.APPWRITE_DATABASE_ID || '6a089307002e54291a32';
const paymentLogsCollectionId = process.env.APPWRITE_PAYMENT_LOGS_COLLECTION_ID || 'payment_logs';
const donationsCollectionId = process.env.APPWRITE_DONATION_RECORDS_COLLECTION_ID || 'donation_records';
const usersCollectionId = process.env.APPWRITE_USERS_COLLECTION_ID || '6a08943100226f5b4963';
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

async function getPaystackConfigKeys(log, options = {}, req = null) {
  let isTestMode =
    options.forceTestMode !== undefined
      ? options.forceTestMode === true
      : process.env.PAYSTACK_TEST_MODE === 'true';

  let testPublicKey = process.env.PAYSTACK_TEST_PUBLIC_KEY?.trim() || (process.env.PAYSTACK_PUBLIC_KEY?.trim()?.startsWith('pk_test_') ? process.env.PAYSTACK_PUBLIC_KEY.trim() : '');
  let testSecretKey = process.env.PAYSTACK_TEST_SECRET_KEY?.trim() || (process.env.PAYSTACK_SECRET_KEY?.trim()?.startsWith('sk_test_') ? process.env.PAYSTACK_SECRET_KEY.trim() : '');
  let livePublicKey = process.env.PAYSTACK_LIVE_PUBLIC_KEY?.trim() || (process.env.PAYSTACK_PUBLIC_KEY?.trim()?.startsWith('pk_live_') ? process.env.PAYSTACK_PUBLIC_KEY.trim() : '');
  let liveSecretKey = process.env.PAYSTACK_LIVE_SECRET_KEY?.trim() || (process.env.PAYSTACK_SECRET_KEY?.trim()?.startsWith('sk_live_') ? process.env.PAYSTACK_SECRET_KEY.trim() : '');

  let dynamicPublicKey = '';
  let dynamicSecretKey = '';

  try {
    const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY || req?.headers?.['x-appwrite-key'];
    const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT || process.env.APPWRITE_ENDPOINT;
    const projId = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID || '';
    if (apiKey && endpoint) {
      const client = new Client()
        .setEndpoint(endpoint)
        .setProject(projId)
        .setKey(apiKey);
      const databases = new Databases(client);
      const res = await databases.listDocuments(databaseId, appSettingsCollectionId, [
        Query.limit(200),
      ]);
      for (const doc of (res?.documents || [])) {
        const k = doc.key || doc.setting_key;
        const v = (doc.value ?? doc.setting_value ?? '').toString().trim();
        if (k === 'paystack_test_mode') {
          if (options.forceTestMode === undefined) {
            isTestMode = v === 'true';
          }
        } else if (k === 'paystack_test_public_key' && v.startsWith('pk_')) {
          testPublicKey = v;
        } else if (k === 'paystack_test_secret_key' && v.startsWith('sk_')) {
          testSecretKey = v;
        } else if (k === 'paystack_live_public_key' && v.startsWith('pk_')) {
          livePublicKey = v;
        } else if (k === 'paystack_live_secret_key' && v.startsWith('sk_')) {
          liveSecretKey = v;
        } else if (k === 'paystack_public_key' && v.startsWith('pk_')) {
          dynamicPublicKey = v;
        } else if (k === 'paystack_secret_key' && v.startsWith('sk_')) {
          dynamicSecretKey = v;
        }
      }
    }
  } catch (e) {
    if (log) log(`Appwrite settings lookup note: ${e.message}`);
  }

  let secret = isTestMode ? testSecretKey : liveSecretKey;
  let publicKey = isTestMode ? testPublicKey : livePublicKey;

  if (dynamicSecretKey) {
    if (isTestMode && dynamicSecretKey.startsWith('sk_test_')) secret = dynamicSecretKey;
    if (!isTestMode && dynamicSecretKey.startsWith('sk_live_')) secret = dynamicSecretKey;
  }
  if (dynamicPublicKey) {
    if (isTestMode && dynamicPublicKey.startsWith('pk_test_')) publicKey = dynamicPublicKey;
    if (!isTestMode && dynamicPublicKey.startsWith('pk_live_')) publicKey = dynamicPublicKey;
  }

  // Never cross-fallback between test and live keys: if Live mode is enabled
  // and live key is missing, fail loudly instead of silently switching to test.
  if (!secret) {
    const envFallback = process.env.PAYSTACK_SECRET_KEY?.trim() || '';
    if ((isTestMode && envFallback.startsWith('sk_test_')) || (!isTestMode && envFallback.startsWith('sk_live_'))) {
      secret = envFallback;
    }
  }

  // CRITICAL FAIL-SAFE: Paystack test and live keys must NEVER be mismatched.
  // If secret is live, public key MUST be live. If secret is test, public key MUST be test.
  if (secret.startsWith('sk_live_') && !publicKey.startsWith('pk_live_')) {
    publicKey = livePublicKey;
  } else if (secret.startsWith('sk_test_') && !publicKey.startsWith('pk_test_')) {
    publicKey = testPublicKey;
  }

  return { secret, publicKey, isTestMode, liveSecretKey, livePublicKey, testSecretKey, testPublicKey };
}

async function getPaystackPublicKey(log, options = {}) {
  const conf = await getPaystackConfigKeys(log, options);
  return conf.publicKey;
}

async function getPaystackSecretKey(log, options = {}) {
  const conf = await getPaystackConfigKeys(log, options);
  return conf.secret;
}

export default async ({ req, res, log, error }) => {
  if (req.method !== 'POST') {
    return res.json({ error: 'Method not allowed. Use POST.' }, 405);
  }

  try {
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

    // Always resolve test/live mode authoritatively from server app_settings/env
    // (never allow an unauthenticated client to override test_mode).
    const paystackConfig = await getPaystackConfigKeys(log, {}, req);
    let secret = paystackConfig.secret;
    let publicKey = paystackConfig.publicKey;
    const candidateKeys = [
      paystackConfig.liveSecretKey,
      paystackConfig.testSecretKey,
      process.env.PAYSTACK_SECRET_KEY?.trim(),
      process.env.PAYSTACK_LIVE_SECRET_KEY?.trim(),
      process.env.PAYSTACK_TEST_SECRET_KEY?.trim(),
    ].filter((k, idx, arr) => k && arr.indexOf(k) === idx);

    if (!secret) {
      error('Missing PAYSTACK_SECRET_KEY in function environment or app_settings.');
      return res.json({ error: 'Paystack is not configured.' }, 500);
    }

    const action = body.action || 'initialize_transaction';

    // ── Public rate lookup (no Paystack call). Lets web + Flutter show a
    // ── live "$1 ≈ ₦X" label from the market rate instead of a constant. ──
    if (action === 'get_exchange_rate' || action === 'get_payment_config') {
      const { rate, source } = await getConfiguredUsdToNgnRate(log);
      return res.json({
        rate,
        source,
        pair: 'USD_NGN',
        live: source !== 'fallback',
        test_mode: paystackConfig.isTestMode,
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
      let verifyRes = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(ref)}`, {
        headers: {
          Authorization: `Bearer ${secret}`,
          'Content-Type': 'application/json',
        },
      });
      let verifyData = await verifyRes.json();

      // If verification failed with invalid key/auth or not found (e.g. just after mode switch), retry once with alternate keys
      const verifyMsg = String(verifyData.message || '').toLowerCase();
      if (
        !verifyData.status &&
        (verifyMsg.includes('key') ||
          verifyMsg.includes('not found') ||
          verifyRes.status === 401 ||
          verifyRes.status === 404)
      ) {
        for (const altSecret of candidateKeys.filter((k) => k !== secret)) {
          const retryRes = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(ref)}`, {
            headers: {
              Authorization: `Bearer ${altSecret}`,
              'Content-Type': 'application/json',
            },
          });
          const retryData = await retryRes.json();
          if (retryData.status) {
            verifyRes = retryRes;
            verifyData = retryData;
            secret = altSecret;
            break;
          }
        }
      }
      if (!verifyData.status) {
        return res.json({ error: verifyData.message || 'Verification failed.' }, 400);
      }
      const pData = verifyData.data;
      if (pData.status === 'success') {
        await handleVerifiedPayment(pData, log);
      }
      // Return only non-PII verification fields to unauthenticated callers
      const rawMeta = pData.metadata && typeof pData.metadata === 'object' ? pData.metadata : {};
      const safeMeta = {
        ...(rawMeta.project_id ? { project_id: rawMeta.project_id } : {}),
        ...(rawMeta.project_ids ? { project_ids: rawMeta.project_ids } : {}),
        ...(rawMeta.project_title ? { project_title: rawMeta.project_title } : {}),
        ...(rawMeta.fund_designations ? { fund_designations: rawMeta.fund_designations } : {}),
        ...(rawMeta.donation_type ? { donation_type: rawMeta.donation_type } : {}),
        ...(rawMeta.category ? { category: rawMeta.category } : {}),
        ...(rawMeta.material_id ? { material_id: rawMeta.material_id } : {}),
        ...(rawMeta.original_currency ? { original_currency: rawMeta.original_currency } : {}),
        ...(rawMeta.original_amount ? { original_amount: rawMeta.original_amount } : {}),
        ...(rawMeta.exchange_rate ? { exchange_rate: rawMeta.exchange_rate } : {}),
      };
      return res.json({
        success: pData.status === 'success',
        status: pData.status,
        reference: pData.reference,
        amount: pData.amount / 100,
        currency: pData.currency,
        domain: pData.domain,
        is_test: pData.domain === 'test',
        paid_at: pData.paid_at,
        metadata: safeMeta,
      });
    }

    // ── Admin sync: pull live Paystack transactions directly into payment_logs ──
    if (action === 'sync_transactions') {
      const callerId = String(req.headers['x-appwrite-user-id'] || '').trim();
      const triggerType = String(req.headers['x-appwrite-trigger'] || '').trim().toLowerCase();
      if (!callerId && triggerType !== 'schedule') {
        return res.json({ error: 'Authentication required.' }, 401);
      }
      if (callerId) {
        const fnEp = process.env.APPWRITE_FUNCTION_API_ENDPOINT || process.env.APPWRITE_ENDPOINT;
        const fnPr = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
        const fnKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY || req.headers['x-appwrite-key'];
        if (!fnEp || !fnPr || !fnKey) {
          return res.json({ error: 'Admin verification unavailable.' }, 500);
        }
        const authClient = new Client().setEndpoint(fnEp).setProject(fnPr).setKey(fnKey);
        const authDb = new Databases(authClient);
        const authUsers = new Users(authClient);
        let isAuthorizedAdmin = false;
        try {
          const u = await authUsers.get(callerId);
          const labels = Array.isArray(u.labels) ? u.labels.map((l) => String(l).toLowerCase()) : [];
          if (labels.some((l) => ['admin', 'super_admin', 'treasurer', 'president'].includes(l))) {
            isAuthorizedAdmin = true;
          }
        } catch (_) {}
        if (!isAuthorizedAdmin) {
          try {
            const uDoc = await authDb.getDocument(databaseId, usersCollectionId, callerId);
            const r = String(uDoc.role || '').toLowerCase();
            if (uDoc.is_admin === true || ['admin', 'super_admin', 'treasurer'].includes(r)) {
              isAuthorizedAdmin = true;
            }
          } catch (_) {}
        }
        if (!isAuthorizedAdmin) {
          try {
            const holderList = await authDb.listDocuments(databaseId, 'org_office_holders', [
              Query.equal('user_id', callerId),
              Query.equal('is_current', true),
              Query.limit(20),
            ]);
            for (const h of holderList.documents || []) {
              const title = String(h.office_title || h.office_slug || h.title || '').toLowerCase();
              if (
                title.includes('treasurer') ||
                title.includes('president') ||
                title.includes('admin') ||
                title.includes('finance')
              ) {
                isAuthorizedAdmin = true;
                break;
              }
            }
          } catch (_) {}
        }
        if (!isAuthorizedAdmin) {
          return res.json({ error: 'Unauthorized: admin access required.' }, 403);
        }
      }

      const liveConf = await getPaystackConfigKeys(log, { forceTestMode: false });
      const liveSecret = liveConf.liveSecretKey;
      if (!liveSecret || !liveSecret.startsWith('sk_live_')) {
        return res.json(
          { error: 'Live Paystack secret key (sk_live_...) is not configured.' },
          500,
        );
      }

      const perPage = Math.min(Math.max(Number(body.per_page || 100), 1), 100);
      const allRows = [];
      let page = 1;
      while (true) {
        const listRes = await fetch(
          `https://api.paystack.co/transaction?status=success&perPage=${perPage}&page=${page}`,
          {
            headers: {
              Authorization: `Bearer ${liveSecret}`,
              'Content-Type': 'application/json',
            },
          },
        );
        const listData = await listRes.json();
        if (!listRes.ok || !listData.status) {
          return res.json(
            { error: listData.message || 'Could not fetch Paystack transactions' },
            502,
          );
        }
        const rows = Array.isArray(listData.data) ? listData.data : [];
        allRows.push(...rows);
        const total = Number(listData.meta?.total ?? allRows.length);
        if (rows.length < perPage || allRows.length >= total || page >= 10) {
          break;
        }
        page++;
      }

      let syncDb = null;
      const syncApiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY || req.headers['x-appwrite-key'];
      const syncEndpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT || process.env.APPWRITE_ENDPOINT;
      const syncProjId = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID || '';
      if (syncApiKey && syncEndpoint) {
        const syncClient = new Client()
          .setEndpoint(syncEndpoint)
          .setProject(syncProjId)
          .setKey(syncApiKey);
        syncDb = new Databases(syncClient);
      }
      let synced = 0;
      let skippedExternal = 0;
      for (const tx of allRows) {
        if (tx && tx.status === 'success' && tx.reference) {
          if (!(await isAliveAppTransaction(tx, syncDb))) {
            skippedExternal++;
            continue;
          }
          await handleVerifiedPayment(tx, log, { skipReceiptEmail: true });
          synced++;
        }
      }
      return res.json({
        success: true,
        synced,
        skipped_external: skippedExternal,
        total_fetched: allRows.length,
      });
    }

    // ── Manage a recurring subscription (list / cancel) ──
    if (action === 'list_subscriptions' || action === 'cancel_subscription') {
      const fnError = (message, status = 400) => res.json({ error: message }, status);
      const callerId = String(req.headers['x-appwrite-user-id'] || '').trim();
      if (!callerId) {
        return fnError('Authentication is required to manage subscriptions.', 401);
      }

      // Derive donor email authoritatively from the authenticated Appwrite account
      // so no caller can enumerate or cancel another member's subscriptions.
      let verifiedEmail = '';
      try {
        const fnEp = process.env.APPWRITE_FUNCTION_API_ENDPOINT || process.env.APPWRITE_ENDPOINT;
        const fnPr = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
        const fnKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY || req.headers['x-appwrite-key'];
        if (fnEp && fnPr && fnKey) {
          const uClient = new Client().setEndpoint(fnEp).setProject(fnPr).setKey(fnKey);
          const authUser = await new Users(uClient).get(callerId);
          verifiedEmail = String(authUser?.email || '').trim().toLowerCase();
        }
      } catch (lookupErr) {
        log(`Subscription caller lookup failed: ${lookupErr.message}`);
      }
      if (!verifiedEmail) {
        return fnError('Could not verify your account email.', 403);
      }

      const subModePrefix = paystackConfig.isTestMode ? 'sk_test_' : 'sk_live_';
      const paystack = async (path, { method = 'GET', payload = null } = {}) => {
        let resp = await fetch(`https://api.paystack.co${path}`, {
          method,
          headers: {
            Authorization: `Bearer ${secret}`,
            'Content-Type': 'application/json',
          },
          ...(payload ? { body: JSON.stringify(payload) } : {}),
        });
        let json = await resp.json().catch(() => ({}));
        if (!json?.status && (json?.message?.toLowerCase().includes('key') || resp.status === 401)) {
          for (const altKey of candidateKeys.filter((k) => k !== secret && k.startsWith(subModePrefix))) {
            const retryResp = await fetch(`https://api.paystack.co${path}`, {
              method,
              headers: {
                Authorization: `Bearer ${altKey}`,
                'Content-Type': 'application/json',
              },
              ...(payload ? { body: JSON.stringify(payload) } : {}),
            });
            const retryJson = await retryResp.json().catch(() => ({}));
            if (retryJson?.status || !retryJson?.message?.toLowerCase().includes('key')) {
              resp = retryResp;
              json = retryJson;
              secret = altKey;
              break;
            }
          }
        }
        if (!json?.status) {
          throw new Error(json?.message || 'Paystack request failed.');
        }
        return json.data;
      };

      const donorEmail = verifiedEmail;

      let subscriptions = [];
      try {
        // Look up Paystack customer ID first so we filter server-side even past 100 org subscriptions
        let customerId = null;
        try {
          const customer = await paystack(`/customer/${encodeURIComponent(donorEmail)}`);
          customerId = customer?.id || null;
        } catch (_) {}
        const queryPath = customerId
          ? `/subscription?customer=${encodeURIComponent(customerId)}&perPage=100`
          : '/subscription?perPage=100';
        const data = await paystack(queryPath);
        subscriptions = Array.isArray(data) ? data : [];
      } catch (listErr) {
        return fnError(`Could not list subscriptions: ${listErr.message}`, 502);
      }

      const INACTIVE_SUB_STATUSES = new Set(['cancelled', 'non-renewing', 'complete', 'completed']);
      const owned = subscriptions.filter(
        (sub) =>
          typeof sub?.customer?.email === 'string' &&
          sub.customer.email.trim().toLowerCase() === donorEmail &&
          !INACTIVE_SUB_STATUSES.has(String(sub?.status || '').toLowerCase()),
      );

      if (action === 'list_subscriptions') {
        return res.json({
          ok: true,
          email: donorEmail,
          count: owned.length,
          subscriptions: owned.map((sub) => ({
            subscription_code: sub.subscription_code,
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
      app_id: 'alive_nigeria_app',
      source: body.metadata?.source || 'alive_ng_app',
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
        const usdPlanRes = await createDynamicPlan({
          secret,
          candidateKeys,
          log,
          name: planName,
          amount: planAmountMinor,
          currency: 'USD',
        });
        planCode = usdPlanRes?.planCode || null;
        if (usdPlanRes?.activeSecret && usdPlanRes.activeSecret !== secret) {
          secret = usdPlanRes.activeSecret;
          publicKey = secret.startsWith('sk_live_')
            ? (paystackConfig.livePublicKey || publicKey)
            : (paystackConfig.testPublicKey || publicKey);
        }

        // 2. If Paystack rejects direct USD plan creation, fallback to NGN conversion
        if (!planCode) {
          log('Paystack direct USD plan creation not available. Falling back to NGN conversion for recurring plan.');
          const clientRate = Number(
            body?.metadata?.exchange_rate_usd_ngn ?? body?.metadata?.exchange_rate,
          );
          let exchangeRate = clientRate;
          let rateSource = 'client';
          if (!isValidRate(exchangeRate)) {
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
          const ngnPlanRes = await createDynamicPlan({
            secret,
            candidateKeys,
            log,
            name: planName,
            amount: planAmountMinor,
            currency: planCurrency,
          });
          planCode = ngnPlanRes?.planCode || null;
          if (ngnPlanRes?.activeSecret && ngnPlanRes.activeSecret !== secret) {
            secret = ngnPlanRes.activeSecret;
            publicKey = secret.startsWith('sk_live_')
              ? (paystackConfig.livePublicKey || publicKey)
              : (paystackConfig.testPublicKey || publicKey);
          }
        }
      } else {
        if (planAmountMinor < MIN_PLAN_KOBO) {
          return res.json({
            error: `Recurring donations must be at least N${MIN_PLAN_KOBO / 100} per month.`,
          }, 400);
        }
        planName = makeDynamicPlanName(planCurrency, planAmountMinor, false);
        const directPlanRes = await createDynamicPlan({
          secret,
          candidateKeys,
          log,
          name: planName,
          amount: planAmountMinor,
          currency: planCurrency,
        });
        planCode = directPlanRes?.planCode || null;
        if (directPlanRes?.activeSecret && directPlanRes.activeSecret !== secret) {
          secret = directPlanRes.activeSecret;
          publicKey = secret.startsWith('sk_live_')
            ? (paystackConfig.livePublicKey || publicKey)
            : (paystackConfig.testPublicKey || publicKey);
        }
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

    // ── Invalid key recovery (same mode only) ───────────────────────────────
    // Never silently fall back from Live mode to a Test key (or vice versa),
    // so Live mode never disguises an invalid sk_live_ key as a test checkout.
    const sameModePrefix = paystackConfig.isTestMode ? 'sk_test_' : 'sk_live_';
    const sameModeCandidates = candidateKeys.filter((k) => k !== secret && k.startsWith(sameModePrefix));
    if (!json?.status && (json?.message?.toLowerCase().includes('key') || paystackResponse.status === 401)) {
      for (const altKey of sameModeCandidates) {
        log(`Paystack init returned "${json?.message}". Retrying with same-mode fallback key ${altKey.substring(0, 10)}...`);
        const retryRes = await fetch('https://api.paystack.co/transaction/initialize', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${altKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(payload),
        });
        const retryJson = await retryRes.json();
        if (retryJson?.status || !retryJson?.message?.toLowerCase().includes('key')) {
          paystackResponse = retryRes;
          json = retryJson;
          secret = altKey;
          publicKey = altKey.startsWith('sk_live_')
            ? (paystackConfig.livePublicKey || publicKey)
            : (paystackConfig.testPublicKey || publicKey);
          break;
        }
      }
    }

    if (!json?.status && (json?.message?.toLowerCase().includes('key') || paystackResponse.status === 401)) {
      const modeLabel = paystackConfig.isTestMode ? 'Test' : 'Live';
      const settingKey = paystackConfig.isTestMode ? 'paystack_test_secret_key' : 'paystack_live_secret_key';
      error(`Paystack ${modeLabel} secret key rejected: ${json?.message || paystackResponse.status}`);
      return res.json({
        error: `Paystack ${modeLabel} Secret Key was rejected by Paystack ("${json?.message || 'Invalid key'}"). Please update ${settingKey} in App Settings.`,
        test_mode: paystackConfig.isTestMode,
      }, 400);
    }

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

    // ── USD fallback to NGN ─────────────────────────────────────────────────
    // If Paystack rejects the USD transaction for ANY reason — unsupported
    // currency, no active channel, or anything else — convert to NGN and retry.
    // This covers BOTH one-time and recurring (subscription) donations.
    //
    // Known failure modes:
    //   • "Currency not supported by merchant" — USD not enabled at all
    //   • "No active channel to process transaction" — USD enabled but no
    //     payment channel (card/bank) is activated for USD on Paystack dashboard
    // Strictly gate USD->NGN conversion to USD transactions only so an NGN channel
    // error can never multiply an NGN kobo amount by the USD/NGN exchange rate!
    const isUsdFailure = !json?.status && payload.currency === 'USD';
    if (isUsdFailure) {
      // Prefer a client-supplied fresh rate, else resolve live on the server
      // so the donor is billed at the current market rate — never stale.
      // Web sends `exchange_rate`, the Flutter app sends
      // `exchange_rate_usd_ngn`; accept either.
      const clientRate = Number(
        body?.metadata?.exchange_rate_usd_ngn ?? body?.metadata?.exchange_rate,
      );
      let exchangeRate = clientRate;
      let rateSource = 'client';
      if (!isValidRate(exchangeRate)) {
        const resolved = await getConfiguredUsdToNgnRate(log);
        exchangeRate = resolved.rate;
        rateSource = resolved.source;
      }

      // For subscriptions with a USD plan that failed at init, we need to
      // replace the USD plan with an NGN plan. The original USD amount is in
      // body.amount (minor units, e.g. 1000 = $10.00).
      const isSubscription = action === 'initialize_subscription';
      const originalAmountMinor = Number(body.amount) || 0;
      const usdAmount = originalAmountMinor / 100;
      const ngnAmountMinor = Math.round(usdAmount * exchangeRate * 100);

      log(
        `Paystack rejected USD init: "${json?.message}". ` +
        `Converting $${usdAmount} USD to ₦${ngnAmountMinor / 100} NGN ` +
        `at rate ${exchangeRate} (${rateSource})` +
        (isSubscription ? ' [recurring — re-creating plan in NGN]' : ''),
      );

      payload.currency = 'NGN';
      payload.amount = ngnAmountMinor;

      const conversion = {
        original_currency: 'USD',
        original_amount: usdAmount,
        exchange_rate: exchangeRate,
        exchange_rate_source: rateSource,
        converted_to_ngn: true,
      };

      payload.metadata = {
        ...payload.metadata,
        ...conversion,
      };

      // For recurring: replace the USD plan with a new NGN plan
      if (isSubscription && payload.plan) {
        if (ngnAmountMinor < MIN_PLAN_KOBO) {
          return res.json({
            error: `Recurring donations must be at least ₦${MIN_PLAN_KOBO / 100} per month. Increase the amount or choose a one-time donation.`,
          }, 400);
        }
        const ngnPlanName = makeDynamicPlanName('NGN', ngnAmountMinor, true);
        const ngnPlanRes = await createDynamicPlan({
          secret,
          candidateKeys,
          log,
          name: ngnPlanName,
          amount: ngnAmountMinor,
          currency: 'NGN',
        });
        const ngnPlanCode = ngnPlanRes?.planCode || null;
        if (ngnPlanRes?.activeSecret && ngnPlanRes.activeSecret !== secret) {
          secret = ngnPlanRes.activeSecret;
          publicKey = secret.startsWith('sk_live_')
            ? (paystackConfig.livePublicKey || publicKey)
            : (paystackConfig.testPublicKey || publicKey);
        }
        if (!ngnPlanCode) {
          return res.json({ error: 'Could not create a recurring plan. Please try a one-time donation.' }, 400);
        }
        payload.plan = ngnPlanCode;
        // When using a plan, Paystack ignores `amount` and uses the plan's
        delete payload.amount;
        payload.metadata.plan_code = ngnPlanCode;
        payload.metadata.plan_name = ngnPlanName;
        payload.metadata.plan_amount_minor = ngnAmountMinor;
        log(`Replaced USD plan with NGN plan: ${ngnPlanCode} (${ngnPlanName})`);
      }

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

/**
 * Returns true only for Paystack transactions that originated from the ALIVE
 * Nigeria App (or web donation page), so transactions from the shared
 * Membership Portal on the same Paystack account are never imported.
 */
async function isAliveAppTransaction(txData, databases) {
  const meta =
    typeof txData?.metadata === 'string'
      ? (() => { try { return JSON.parse(txData.metadata); } catch (_) { return {}; } })()
      : (txData?.metadata || {});
  const ref = String(txData?.reference || '').trim();
  const planName = String(txData?.plan_object?.name || txData?.plan?.name || '').trim();

  if (
    meta.app_id === 'alive_nigeria_app' ||
    meta.source === 'alive_ng_app' ||
    meta.source === 'web_donation_page' ||
    Boolean(meta.donation_id) ||
    ref.startsWith('ALIVE') ||
    ref.startsWith('don_') ||
    planName.startsWith('ALIVE Monthly')
  ) {
    return true;
  }

  return false;
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

async function createDynamicPlan({ secret, candidateKeys = [], log, name, amount, currency }) {
  try {
    let activeSecret = secret;
    let createPlanRes = await fetch('https://api.paystack.co/plan', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${activeSecret}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name,
        interval: 'monthly',
        amount,
        currency,
      }),
    });
    let planJson = await createPlanRes.json();

    const sameModePrefix = activeSecret.startsWith('sk_test_') ? 'sk_test_' : 'sk_live_';
    if (!planJson?.status && (planJson?.message?.toLowerCase().includes('key') || createPlanRes.status === 401)) {
      for (const altKey of candidateKeys.filter((k) => k && k !== activeSecret && k.startsWith(sameModePrefix))) {
        if (log) log(`Plan creation returned "${planJson?.message}". Retrying with alternate same-mode key...`);
        const retryRes = await fetch('https://api.paystack.co/plan', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${altKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            name,
            interval: 'monthly',
            amount,
            currency,
          }),
        });
        const retryJson = await retryRes.json();
        if (retryJson?.status || !retryJson?.message?.toLowerCase().includes('key')) {
          createPlanRes = retryRes;
          planJson = retryJson;
          activeSecret = altKey;
          break;
        }
      }
    }

    if (planJson?.status && planJson?.data?.plan_code) {
      if (log) log(`Created dynamic plan: ${planJson.data.plan_code} (${name})`);
      return { planCode: planJson.data.plan_code, activeSecret };
    }
    if (log) log(`Dynamic plan creation failed: ${planJson?.message || 'unknown'}`);
    return { planCode: null, activeSecret };
  } catch (planErr) {
    if (log) log(`Dynamic plan creation error: ${planErr.message}`);
    return { planCode: null, activeSecret: secret };
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
    const KNOWN_WEB_PROJECTS = {
      general_mission_fund: 'General Mission Fund',
      impact_hub_center: 'Impact Hub Center',
      vehicle_purchase: 'Mission Vehicle Purchase',
      media_studio_setup: 'Media Studio Setup',
      youth_discipleship: 'Youth Discipleship & Campus Ministry',
      tract_printing: 'Bibles, Books & Tract Printing',
    };
    const knownTitle = KNOWN_WEB_PROJECTS[projectId.toLowerCase()];
    if (knownTitle) return knownTitle;
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

async function handleVerifiedPayment(paystackData, log, options = {}) {
  try {
    const skipReceiptEmail = options.skipReceiptEmail === true;
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
    const customerFullName = [paystackData.customer?.first_name, paystackData.customer?.last_name]
      .filter((v) => typeof v === 'string' && v.trim().length > 0)
      .join(' ')
      .trim();
    const customFieldName = Array.isArray(paystackData.metadata?.custom_fields)
      ? (paystackData.metadata.custom_fields.find((f) =>
          String(f?.display_name || f?.variable_name || '').toLowerCase().includes('name') &&
          String(f?.value || '').trim().length > 0
        )?.value || '').trim()
      : '';
    const donorName =
      paystackData.metadata?.donor_name ||
      paystackData.metadata?.customer_name ||
      paystackData.metadata?.full_name ||
      paystackData.metadata?.name ||
      customFieldName ||
      customerFullName ||
      customerEmail ||
      '';
    const isTestPayment = paystackData.domain
      ? paystackData.domain === 'test'
      : (process.env.PAYSTACK_SECRET_KEY || '').startsWith('sk_test_');
    const metadata = {
      ...(paystackData.metadata || {}),
      processor: 'paystack',
      channel: paystackData.channel,
      fees: paystackData.fees,
      gateway_response: paystackData.gateway_response,
      paid_at: paystackData.paid_at,
      is_test: isTestPayment,
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
    const paidAt = paystackData.paid_at || paystackData.created_at || new Date().toISOString();
    const nowIso = new Date().toISOString();
    const updatePayload = {
      status: 'completed',
      transaction_id: String(paystackData.id || ''),
      purpose,
      project_title: purpose,
      amount_kobo: Math.round(amountKobo),
      amount,
      currency: paystackData.currency || 'NGN',
      user_name: donorName,
      user_email: customerEmail,
      email: customerEmail,
      is_test: isTestPayment,
      completed_at: paidAt,
      created_at: paidAt,
      updated_at: nowIso,
      metadata: JSON.stringify(metadata),
    };
    const createPayload = {
      reference,
      ...updatePayload,
      processor: 'paystack',
      user_id: paystackData.metadata?.user_id || paystackData.metadata?.appwrite_user_id || 'guest',
      type: paystackData.metadata?.donation_type || 'generalSupport',
      payment_method: 'paystack',
    };

    const upsertDonation = async (payloadForUpdate, payloadForCreate) => {
      try {
        await databases.updateDocument(databaseId, donationsCollectionId, reference, payloadForUpdate);
      } catch (updErr) {
        if (updErr?.code === 404) {
          try {
            await databases.createDocument(databaseId, donationsCollectionId, reference, payloadForCreate);
          } catch (crtErr) {
            if (crtErr?.code === 409) {
              await databases.updateDocument(databaseId, donationsCollectionId, reference, payloadForUpdate);
            } else {
              throw crtErr;
            }
          }
        } else {
          throw updErr;
        }
      }
    };

    try {
      await upsertDonation(updatePayload, createPayload);
    } catch (e) {
      if (String(e?.message || '').includes('is_test')) {
        const { is_test: _u, ...fallbackUpdate } = updatePayload;
        const { is_test: _c, ...fallbackCreate } = createPayload;
        try {
          await upsertDonation(fallbackUpdate, fallbackCreate);
        } catch (fallbackErr) {
          if (log) log(`Donation record save note: ${fallbackErr.message}`);
        }
      } else {
        if (log) log(`Donation record save note: ${e.message}`);
      }
    }

    // 2. Increment project raised counter (supports single and multi-project splits).
    //
    // A per-reference credit marker on the donation row makes it idempotent,
    // and `??` keeps a real 0 intact. When a donor splits a gift across
    // multiple areas (including multiple projects), every selected project is
    // credited its proportional equal share (total / splitCount).
    const NON_PROJECT_IDS = new Set(['general_mission_fund', 'general_support', '']);
    const rawProjectIds = [];
    const metaProjectIds = paystackData.metadata?.project_ids;
    if (Array.isArray(metaProjectIds)) {
      for (const id of metaProjectIds) {
        const clean = String(id || '').trim();
        if (clean && !NON_PROJECT_IDS.has(clean)) rawProjectIds.push(clean);
      }
    } else if (typeof metaProjectIds === 'string' && metaProjectIds.trim()) {
      try {
        const parsed = JSON.parse(metaProjectIds);
        if (Array.isArray(parsed)) {
          for (const id of parsed) {
            const clean = String(id || '').trim();
            if (clean && !NON_PROJECT_IDS.has(clean)) rawProjectIds.push(clean);
          }
        }
      } catch {
        for (const id of metaProjectIds.split(',')) {
          const clean = String(id || '').trim();
          if (clean && !NON_PROJECT_IDS.has(clean)) rawProjectIds.push(clean);
        }
      }
    }
    const singleProjId = String(paystackData.metadata?.project_id || '').trim();
    if (singleProjId && !NON_PROJECT_IDS.has(singleProjId)) {
      rawProjectIds.push(singleProjId);
    }
    const targetProjectIds = [...new Set(rawProjectIds)];

    if (targetProjectIds.length > 0) {
      try {
        if (isTestPayment) {
          if (log) {
            log(`[TEST GUARD] Test payment detected (domain=${paystackData.domain}) - skipping real project credit for ${targetProjectIds.join(', ')}`);
          }
        } else {
          const alreadyCredited = await hasProjectCredit(
            databases,
            donationsCollectionId,
            reference,
          );
          if (alreadyCredited) {
            if (log) {
              log(`Project(s) ${targetProjectIds.join(', ')} already credited for ${reference}; not double counting`);
            }
          } else {
            const settled = String(paystackData.currency || 'NGN').toUpperCase();
            let totalNgnCredit = amount;
            if (settled === 'USD') {
              const clientRate = Number(
                paystackData.metadata?.exchange_rate_usd_ngn ?? paystackData.metadata?.exchange_rate,
              );
              let rate = clientRate;
              if (!isValidRate(rate)) {
                const resolved = await getConfiguredUsdToNgnRate(log);
                rate = resolved.rate;
              }
              totalNgnCredit = Math.round(amount * rate);
              if (log) {
                log(`Converting USD donation ($${amount}) to ₦${totalNgnCredit} NGN at rate ${rate} for ${targetProjectIds.join(', ')}`);
              }
            }
            const designationsList = Array.isArray(paystackData.metadata?.fund_designations)
              ? paystackData.metadata.fund_designations.filter(Boolean)
              : [];
            const metaSplitCount = Number(paystackData.metadata?.split_count || 0);
            const effectiveSplitCount = Math.max(
              Number.isFinite(metaSplitCount) ? metaSplitCount : 0,
              designationsList.length,
              targetProjectIds.length,
              1,
            );
            const creditShare = effectiveSplitCount > 1
              ? Math.round(totalNgnCredit / effectiveSplitCount)
              : totalNgnCredit;
            if (effectiveSplitCount > 1 && log) {
              log(`Split donation (${effectiveSplitCount} areas): crediting proportional share ₦${creditShare} to each of [${targetProjectIds.join(', ')}]`);
            }
            let creditedCount = 0;
            for (const projId of targetProjectIds) {
              try {
                await addToProjectRaised({
                  databases,
                  projectsCollectionId,
                  projectId: projId,
                  amount: creditShare,
                });
                creditedCount++;
                if (log) log(`Credited project ${projId} by ${creditShare}`);
              } catch (singleErr) {
                if (log) log(`Skipping project ${projId} raised update: ${singleErr.message}`);
              }
            }
            if (creditedCount > 0) {
              await markProjectCredited(databases, donationsCollectionId, reference);
            }
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
    // row keeps it to one. Historical sync also skips email dispatch.
    const receiptAlreadySent = skipReceiptEmail || (await hasReceiptBeenSent(databases, reference));
    if (receiptAlreadySent) {
      if (log) {
        log(
          skipReceiptEmail
            ? `Skipping receipt email for ${reference} during historical sync`
            : `Receipt already sent for ${reference}; not resending`,
        );
      }
    } else if (process.env.RESEND_API_KEY && customerEmail) {
      try {
        const dateStr = new Date(paystackData.paid_at || Date.now()).toLocaleDateString('en-NG', { year: 'numeric', month: 'long', day: 'numeric' });
        const currency = paystackData.currency || 'NGN';
        const formattedAmount = amount.toLocaleString();
        // Purpose and donor name can originate from metadata, so both are
        // escaped before going into the HTML body.
        const safePurpose = escapeHtml(purpose);
        const displayDonor = donorName || customerEmail;
        const safeDonorName = escapeHtml(displayDonor);
        const safeDonorEmail = escapeHtml(customerEmail);
        const safeReference = escapeHtml(reference);
        const isRecurring = Boolean(metadata?.recurring);
        const emailRow = safeDonorEmail
          ? `<tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Donor Email</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${safeDonorEmail}</td></tr>`
          : '';
        const purposeRow = `<tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Purpose</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${safePurpose}</td></tr>`;
        const typeRow = `<tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Type</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${isRecurring ? 'Monthly recurring gift' : 'One-time gift'}</td></tr>`;
        const modeRow = isTestPayment
          ? `<tr><td style="padding:10px;border:1px solid #e2e8f0;background:#fff5f5;color:#9b2c2c;"><strong>Mode</strong></td><td style="padding:10px;border:1px solid #e2e8f0;background:#fff5f5;color:#9b2c2c;"><strong>TEST / SANDBOX (No real charge)</strong></td></tr>`
          : '';
        const testBanner = isTestPayment
          ? `<div style="background:#fff5f5;border:2px solid #c53030;color:#9b2c2c;padding:12px 16px;border-radius:8px;margin-bottom:20px;text-align:center;font-family:Arial,sans-serif;font-size:13px;"><strong>TEST TRANSACTION &mdash; NOT A REAL PAYMENT</strong><br/>This receipt was generated in Paystack Test Mode. No real money was charged, this gift is excluded from live totals, and it is not valid for tax filing.</div>`
          : '';
        const receiptTitle = isTestPayment ? '[TEST] Donation Receipt - ALIVE Nigeria' : 'Donation Receipt - ALIVE Nigeria';
        const receiptSubtitle = isTestPayment
          ? 'TEST Donation Receipt (Sandbox Mode &mdash; Not Valid for Tax Filing)'
          : 'Official Donation Receipt';
        const footerNote = isTestPayment
          ? 'This is a <strong>TEST</strong> receipt generated in sandbox mode. No real funds were transferred. Contact <a href="mailto:app@alivenigeria.org">app@alivenigeria.org</a> if you have any questions.'
          : 'Please retain this receipt for your records. Contact us at <a href="mailto:app@alivenigeria.org">app@alivenigeria.org</a> for any inquiries.';
        const receiptHtml = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>${receiptTitle}</title></head><body style="font-family:Georgia,serif;max-width:600px;margin:0 auto;padding:20px;color:#1a202c;">${testBanner}<div style="text-align:center;border-bottom:3px solid ${isTestPayment ? '#c53030' : '#1a365d'};padding-bottom:20px;margin-bottom:20px;"><img src="${ALIVE_LOGO_URL}" alt="ALIVE Nigeria" width="88" height="88" style="display:block;margin:0 auto 12px;border:0;outline:none;" /><h1 style="color:#1a365d;margin:0;">ALIVE Nigeria</h1><p style="color:${isTestPayment ? '#c53030' : '#666'};margin:4px 0;font-weight:${isTestPayment ? 'bold' : 'normal'};">${receiptSubtitle}</p></div><div style="padding:10px 0;"><p>Dear ${safeDonorName},</p><p>${isTestPayment ? 'This confirms your <strong>TEST</strong> donation flow with ALIVE Nigeria (sandbox mode — no real charge occurred).' : 'Thank you for your generous donation to ALIVE Nigeria. Your support empowers our work across Nigeria.'}</p><p style="color:#4a5568;">Your ${isTestPayment ? 'test ' : ''}gift of <strong>${escapeHtml(currency)} ${escapeHtml(formattedAmount)}</strong> was designated to <strong>${safePurpose}</strong>.</p><table style="width:100%;border-collapse:collapse;margin:20px 0;">${modeRow}<tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Donor Name</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${safeDonorName}</td></tr>${emailRow}${typeRow}${purposeRow}<tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Amount</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${escapeHtml(currency)} ${escapeHtml(formattedAmount)}</td></tr><tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Reference</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${safeReference}</td></tr><tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Date</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${escapeHtml(dateStr)}</td></tr></table><p style="color:#4a5568;font-size:14px;">${footerNote}</p></div><div style="text-align:center;border-top:1px solid #e2e8f0;padding-top:20px;color:#999;font-size:12px;"><p>ALIVE Nigeria &mdash; ${isTestPayment ? 'Test Mode Receipt' : 'Thank you for your generosity.'}</p></div></body></html>`;

        // Receipts always come from the dedicated receipts@ identity so a
        // donor can distinguish a financial document from ministry mail.
        // Test receipts are NOT cc'd to the live finance inbox to keep test
        // and live records strictly separated.
        const sender =
          process.env.RECEIPT_SENDER_EMAIL || 'ALIVE Nigeria App <receipts@app.alivenigeria.org>';
        const replyTo = process.env.REPLY_TO_EMAIL || 'app@alivenigeria.org';
        const emailPayload = {
          from: sender,
          to: [customerEmail],
          reply_to: replyTo,
          subject: isTestPayment
            ? `[TEST] ALIVE Nigeria Donation Receipt (No Real Charge) - ${reference}`
            : `Your ALIVE Nigeria Donation Receipt - ${reference}`,
          html: receiptHtml,
        };
        if (!isTestPayment) {
          emailPayload.cc = [replyTo];
        }
        const emailRes = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(emailPayload),
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



