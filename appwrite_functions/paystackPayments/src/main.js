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

const MIN_VALID_RATE = 100;
const MAX_VALID_RATE = 100000;

function isValidRate(value) {
  const n = Number(value);
  return Number.isFinite(n) && n > MIN_VALID_RATE && n < MAX_VALID_RATE;
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
    if (isValidRate(rate)) {
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

export default async ({ req, res, log, error }) => {
  if (req.method !== 'POST') {
    return res.json({ error: 'Method not allowed. Use POST.' }, 405);
  }

  try {
    const secret = process.env.PAYSTACK_SECRET_KEY;
    if (!secret) {
      error('Missing PAYSTACK_SECRET_KEY.');
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
    if (action === 'get_exchange_rate') {
      const { rate, source } = await getConfiguredUsdToNgnRate(log);
      return res.json({
        rate,
        source,
        pair: 'USD_NGN',
        live: source !== 'fallback',
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

    if (action === 'initialize_subscription') {
      const planCode = typeof body.planCode === 'string' ? body.planCode.trim() : '';
      if (!planCode) {
        return res.json({ error: 'Missing Paystack monthly plan code.' }, 400);
      }
      payload.plan = planCode;
      payload.metadata = {
        ...payload.metadata,
        recurring: true,
        plan_code: planCode,
      };
    } else {
      const amount = Number(body.amount);
      if (!Number.isFinite(amount) || amount <= 0) {
        return res.json({ error: 'Invalid amount.' }, 400);
      }
      payload.amount = Math.round(amount);
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
    if (!json?.status && (payload.currency === 'USD' || (json?.message && json.message.toLowerCase().includes('currency')))) {
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

    return res.json(json.data);
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

    // 1. Update or create donation record
    try {
      await databases.updateDocument(databaseId, donationsCollectionId, reference, {
        status: 'completed',
        transaction_id: String(paystackData.id || ''),
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
          amount_kobo: Math.round(amountKobo),
          amount,
          currency: paystackData.currency || 'NGN',
          user_id: paystackData.metadata?.user_id || paystackData.metadata?.appwrite_user_id || 'guest',
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

    // 2. Increment project raised counter
    const projId = String(paystackData.metadata?.project_id || '').trim();
    if (projId && projId !== 'general_mission_fund') {
      try {
        const project = await databases.getDocument(databaseId, projectsCollectionId, projId);
        const currentRaised = Number(project.raised || project.amount_raised || 0);
        const newRaised = currentRaised + amount;
        await databases.updateDocument(databaseId, projectsCollectionId, projId, {
          raised: newRaised,
          amount_raised: newRaised,
          updated_at: new Date().toISOString(),
        });
        if (log) log(`Updated project ${projId} raised total to ${newRaised}`);
      } catch (projErr) {
        if (log) log(`Skipping project raised update: ${projErr.message}`);
      }
    }

    // 3. Send donation receipt email
    if (process.env.RESEND_API_KEY && customerEmail) {
      try {
        const dateStr = new Date().toLocaleDateString('en-NG', { year: 'numeric', month: 'long', day: 'numeric' });
        const currency = paystackData.currency || 'NGN';
        const formattedAmount = amount.toLocaleString();
        const receiptHtml = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>Donation Receipt - ALIVE Nigeria</title></head><body style="font-family:Georgia,serif;max-width:600px;margin:0 auto;padding:20px;color:#1a202c;"><div style="text-align:center;border-bottom:3px solid #1a365d;padding-bottom:20px;margin-bottom:20px;"><h1 style="color:#1a365d;margin:0;">ALIVE Nigeria Ministries</h1><p style="color:#666;margin:4px 0;">Official Donation Receipt</p></div><div style="padding:10px 0;"><p>Dear ${donorName},</p><p>Thank you for your generous donation to ALIVE Nigeria Ministries. Your support empowers gospel ministry across Nigeria.</p><table style="width:100%;border-collapse:collapse;margin:20px 0;"><tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Donor Name</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${donorName}</td></tr><tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Amount</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${currency} ${formattedAmount}</td></tr><tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Reference</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${reference}</td></tr><tr><td style="padding:10px;border:1px solid #e2e8f0;background:#f7fafc;"><strong>Date</strong></td><td style="padding:10px;border:1px solid #e2e8f0;">${dateStr}</td></tr></table><p style="color:#4a5568;font-size:14px;">Please retain this receipt for your records. Contact us at <a href="mailto:app@alivenigeria.org">app@alivenigeria.org</a> for any inquiries.</p></div><div style="text-align:center;border-top:1px solid #e2e8f0;padding-top:20px;color:#999;font-size:12px;"><p>ALIVE Nigeria Ministries &mdash; Thank you for your generosity.</p></div></body></html>`;

        const sender = process.env.RECEIPT_SENDER_EMAIL || process.env.SENDER_EMAIL || 'ALIVE Nigeria <app@alivenigeria.org>';
        const emailRes = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from: sender,
            to: [customerEmail],
            subject: `Your ALIVE Nigeria Donation Receipt - ${reference}`,
            html: receiptHtml,
          }),
        });
        const resText = await emailRes.text();
        if (log) log(`Receipt email dispatched to ${customerEmail}: status ${emailRes.status}`);
      } catch (mailErr) {
        if (log) log(`Receipt email error: ${mailErr.message}`);
      }
    }
  } catch (err) {
    if (log) log(`handleVerifiedPayment error: ${err.message}`);
  }
}
