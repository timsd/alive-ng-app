"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ingestTractPdfContent = exports.setUserRoleAndClaims = exports.claimAdminRole = exports.generateStreamChatToken = exports.consumeApprovalToken = exports.syncApprovedTestimonyToPrayerFeed = exports.sendReceiptOnCompletion = exports.paystackWebhook = exports.initPaystackSubscription = exports.initPaystackTransaction = exports.sendEmail = void 0;
const functions = __importStar(require("firebase-functions"));
const params_1 = require("firebase-functions/params");
const admin = __importStar(require("firebase-admin"));
const node_fetch_1 = __importDefault(require("node-fetch"));
const node_crypto_1 = __importDefault(require("node:crypto"));
admin.initializeApp();
const db = admin.firestore();
const PAYSTACK_SECRET_KEY = (0, params_1.defineSecret)('PAYSTACK_SECRET_KEY');
const RESEND_API_KEY = (0, params_1.defineSecret)('RESEND_API_KEY');
const STREAM_CHAT_SECRET = (0, params_1.defineSecret)('STREAM_CHAT_SECRET');
const ENFORCE_APPCHECK = (0, params_1.defineString)('ENFORCE_APPCHECK', { default: 'false' });
const RECEIPT_SENDER_EMAIL = (0, params_1.defineString)('RECEIPT_SENDER_EMAIL', { default: 'onboarding@resend.dev' });
const ALIVE_LOGO_URL = (0, params_1.defineString)('ALIVE_LOGO_URL', { default: 'https://alive.ng/logo.png' });
// ── Generic email sending via Resend ──────────────────────────────────────────
async function _sendViaResend(params) {
    const apiKey = RESEND_API_KEY.value();
    const sender = RECEIPT_SENDER_EMAIL.value();
    if (!apiKey) {
        console.warn('_sendViaResend: Missing RESEND_API_KEY, skipping');
        return;
    }
    const msg = {
        to: [params.to],
        from: sender,
        subject: params.subject,
        html: params.html,
    };
    const resp = await (0, node_fetch_1.default)('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(msg),
    });
    if (!resp.ok) {
        const body = await resp.text();
        throw new Error(`Resend API error ${resp.status}: ${body}`);
    }
}
/**
 * Generic callable Cloud Function to send an email via Resend.
 * Called by the Dart `EmailService` to keep the API key server-side.
 */
exports.sendEmail = functions
    .runWith({ secrets: [RESEND_API_KEY] })
    .https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const { to, subject, html } = data || {};
    if (!to || typeof to !== 'string' || !subject || typeof subject !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'Missing to/subject');
    }
    if (!html || typeof html !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'Missing html body');
    }
    try {
        await _sendViaResend({ to, subject, html });
        return { ok: true };
    }
    catch (e) {
        console.error('sendEmail failed', e);
        throw new functions.https.HttpsError('internal', e?.message || 'Email send failed');
    }
});
exports.initPaystackTransaction = functions
    .runWith({ secrets: [PAYSTACK_SECRET_KEY] })
    .https.onCall(async (data, context) => {
    const { amount, email, reference, callback_url, channels, metadata, currency } = data || {};
    const enforceAppCheck = ENFORCE_APPCHECK.value() === 'true';
    if (enforceAppCheck && !context.app) {
        throw new functions.https.HttpsError('failed-precondition', 'App Check token is required');
    }
    if (!amount || typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
    }
    if (!email || typeof email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid email');
    }
    if (!reference || typeof reference !== 'string' || reference.length < 8 || reference.length > 80) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid reference');
    }
    const secret = PAYSTACK_SECRET_KEY.value();
    if (!secret) {
        throw new functions.https.HttpsError('failed-precondition', 'Missing PAYSTACK_SECRET_KEY');
    }
    const body = {
        amount,
        email,
        reference,
        callback_url,
        channels,
        currency: currency || 'NGN',
        metadata,
    };
    const resp = await (0, node_fetch_1.default)('https://api.paystack.co/transaction/initialize', {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${secret}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
    });
    const json = await resp.json();
    if (!json?.status) {
        throw new functions.https.HttpsError('unknown', json?.message || 'Paystack init failed', json);
    }
    return json?.data;
});
exports.initPaystackSubscription = functions
    .runWith({ secrets: [PAYSTACK_SECRET_KEY] })
    .https.onCall(async (data, context) => {
    const { email, reference, callback_url, channels, metadata, currency, planCode } = data || {};
    const enforceAppCheck = ENFORCE_APPCHECK.value() === 'true';
    if (enforceAppCheck && !context.app) {
        throw new functions.https.HttpsError('failed-precondition', 'App Check token is required');
    }
    if (!email || typeof email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid email');
    }
    if (!reference || typeof reference !== 'string' || reference.length < 8 || reference.length > 80) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid reference');
    }
    if (!planCode || typeof planCode !== 'string' || planCode.trim().length == 0) {
        throw new functions.https.HttpsError('failed-precondition', 'Missing Paystack monthly plan code. Configure and retry.');
    }
    const secret = PAYSTACK_SECRET_KEY.value();
    if (!secret) {
        throw new functions.https.HttpsError('failed-precondition', 'Missing PAYSTACK_SECRET_KEY');
    }
    const body = {
        email,
        reference,
        callback_url,
        channels,
        currency: currency || 'NGN',
        metadata: {
            ...(metadata || {}),
            recurring: true,
            plan_code: planCode,
        },
        plan: planCode,
    };
    const resp = await (0, node_fetch_1.default)('https://api.paystack.co/transaction/initialize', {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${secret}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
    });
    const json = await resp.json();
    if (!json?.status) {
        throw new functions.https.HttpsError('unknown', json?.message || 'Paystack subscription init failed', json);
    }
    return json?.data;
});
function verifySignature(req) {
    const secret = PAYSTACK_SECRET_KEY.value();
    const computed = node_crypto_1.default.createHmac('sha512', secret).update(JSON.stringify(req.body)).digest('hex');
    return computed === req.header('x-paystack-signature');
}
exports.paystackWebhook = functions
    .runWith({ secrets: [PAYSTACK_SECRET_KEY] })
    .https.onRequest(async (req, res) => {
    if (req.method !== 'POST') {
        res.status(405).send('Method Not Allowed');
        return;
    }
    if (!verifySignature(req)) {
        res.status(401).send('Invalid signature');
        return;
    }
    const event = req.body;
    const type = event?.event;
    const data = event?.data;
    const reference = data?.reference;
    if (!reference) {
        res.status(400).send('Missing reference');
        return;
    }
    const docRef = db.collection('donation_records').doc(reference);
    const meta = {
        processor: 'paystack',
        channel: data?.channel,
        fees: data?.fees,
        gateway_response: data?.gateway_response,
        paid_at: data?.paid_at,
    };
    if (type === 'charge.success') {
        await docRef.set({
            status: 'completed',
            transaction_id: data?.id?.toString(),
            completed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            metadata: meta,
        }, { merge: true });
    }
    else if (type === 'charge.failed' || type === 'charge.abandoned') {
        await docRef.set({
            status: 'failed',
            updated_at: new Date().toISOString(),
            metadata: meta,
        }, { merge: true });
    }
    else {
        await docRef.set({
            updated_at: new Date().toISOString(),
            metadata: meta,
        }, { merge: true });
    }
    res.status(200).send('OK');
});
exports.sendReceiptOnCompletion = functions
    .runWith({ secrets: [RESEND_API_KEY] })
    .firestore
    .document('donation_records/{reference}')
    .onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    if (!after || !before)
        return;
    if (before.status === 'completed' || after.status !== 'completed')
        return;
    const email = after.user_email;
    if (!email)
        return;
    const reference = context.params.reference;
    const amount = after.amount;
    const currency = after.currency;
    const title = after.material_title;
    await sendReceiptEmail({
        to: email,
        reference,
        amount,
        currency,
        title,
    });
});
exports.syncApprovedTestimonyToPrayerFeed = functions.firestore
    .document('testimonies/{testimonyId}')
    .onWrite(async (change, context) => {
    const after = change.after.data();
    if (!after)
        return;
    const testimonyId = context.params.testimonyId;
    const isApproved = after.is_approved === true;
    const feedRef = db.collection('prayer_strengthening_feed').doc(testimonyId);
    await feedRef.set({
        id: testimonyId,
        testimony_id: testimonyId,
        user_id: after.user_id || null,
        author_name: after.is_anonymous ? 'Anonymous' : (after.user_name || 'Member'),
        content: after.content || '',
        is_anonymous: after.is_anonymous === true,
        is_approved: isApproved,
        is_visible: isApproved,
        source: 'testimony',
        updated_at: new Date().toISOString(),
        created_at: after.created_at || new Date().toISOString(),
    }, { merge: true });
});
exports.consumeApprovalToken = functions.https.onCall(async (data, context) => {
    const userId = data?.userId || '';
    const token = data?.token || '';
    if (!userId || !token) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing userId or token');
    }
    if (token.length < 24 || token.length > 128) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid token format');
    }
    const tokenRef = db.collection('approval_tokens').doc(token);
    const userRef = db.collection('users').doc(userId);
    const approved = await db.runTransaction(async (tx) => {
        const snap = await tx.get(tokenRef);
        if (!snap.exists)
            return false;
        const tokenData = snap.data();
        if (tokenData.used === true)
            return false;
        if (tokenData.userId !== userId)
            return false;
        const expiresAt = tokenData.expiresAt ? new Date(tokenData.expiresAt) : null;
        if (!expiresAt || Number.isNaN(expiresAt.getTime()) || Date.now() > expiresAt.getTime()) {
            return false;
        }
        tx.update(tokenRef, {
            used: true,
            usedAt: new Date().toISOString(),
        });
        tx.set(userRef, {
            isApproved: true,
            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
            approvedBy: 'approval_link_token',
        }, { merge: true });
        return true;
    });
    return { ok: approved };
});
function _base64UrlEncode(value) {
    return Buffer.from(value)
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/g, '');
}
function _createHs256Jwt(payload, secret) {
    const header = { alg: 'HS256', typ: 'JWT' };
    const headerPart = _base64UrlEncode(JSON.stringify(header));
    const payloadPart = _base64UrlEncode(JSON.stringify(payload));
    const unsigned = `${headerPart}.${payloadPart}`;
    const signature = node_crypto_1.default
        .createHmac('sha256', secret)
        .update(unsigned)
        .digest('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/g, '');
    return `${unsigned}.${signature}`;
}
exports.generateStreamChatToken = functions
    .runWith({ secrets: [STREAM_CHAT_SECRET] })
    .https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const requestedUserId = data?.userId || context.auth.uid;
    const isAdmin = (context.auth.token && context.auth.token.admin) === true;
    if (requestedUserId !== context.auth.uid && !isAdmin) {
        throw new functions.https.HttpsError('permission-denied', 'Cannot mint token for another user');
    }
    const secret = STREAM_CHAT_SECRET.value();
    if (!secret) {
        throw new functions.https.HttpsError('failed-precondition', 'Missing STREAM_CHAT_SECRET');
    }
    // Stream user token payload: user_id + issued-at timestamp.
    const token = _createHs256Jwt({
        user_id: requestedUserId,
        iat: Math.floor(Date.now() / 1000),
    }, secret);
    return { token };
});
exports.claimAdminRole = functions.https.onCall(async (_data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const uid = context.auth.uid;
    const email = context.auth.token.email?.toLowerCase();
    if (email !== 'alivenigeria2011@gmail.com') {
        throw new functions.https.HttpsError('permission-denied', 'Only configured owner account can self-claim admin');
    }
    await admin.auth().setCustomUserClaims(uid, {
        ...(context.auth.token || {}),
        admin: true,
    });
    const profileRef = db.collection('profiles').doc(uid);
    await profileRef.set({
        role: 'admin',
        updated_at: new Date().toISOString(),
    }, { merge: true });
    return { ok: true, role: 'admin', claim: 'admin' };
});
exports.setUserRoleAndClaims = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const callerClaims = context.auth.token;
    if (callerClaims.admin !== true) {
        throw new functions.https.HttpsError('permission-denied', 'Admin claim required');
    }
    const targetUid = data?.uid || '';
    const role = (data?.role || '').trim().toLowerCase();
    if (!targetUid || !role) {
        throw new functions.https.HttpsError('invalid-argument', 'uid and role are required');
    }
    const allowedRoles = new Set(['member', 'coordinator', 'leader', 'director', 'bod', 'trustee', 'admin']);
    if (!allowedRoles.has(role)) {
        throw new functions.https.HttpsError('invalid-argument', `Unsupported role: ${role}`);
    }
    const currentRecord = await admin.auth().getUser(targetUid);
    const currentClaims = (currentRecord.customClaims || {});
    const nextClaims = {
        ...currentClaims,
        admin: role === 'admin',
        role,
    };
    await admin.auth().setCustomUserClaims(targetUid, nextClaims);
    await db.collection('profiles').doc(targetUid).set({
        role,
        updated_at: new Date().toISOString(),
    }, { merge: true });
    return { ok: true, uid: targetUid, role };
});
exports.ingestTractPdfContent = functions.firestore
    .document('tracts/{tractId}')
    .onWrite(async (change, context) => {
    const after = change.after.data();
    if (!after)
        return;
    const tractId = context.params.tractId;
    const pdfUrl = (after.downloadUrl || after.pdfUrl || '');
    if (!pdfUrl)
        return;
    const sourceKey = `${pdfUrl}|${(after.updated_at || after.updatedAt || '')}`;
    if (after.pdf_ingest_source === sourceKey && after.content_ready === true) {
        return;
    }
    try {
        const response = await (0, node_fetch_1.default)(pdfUrl);
        if (!response.ok) {
            throw new Error(`Failed to fetch PDF (${response.status})`);
        }
        const arrayBuffer = await response.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);
        const extractedText = extractPdfTextBestEffort(buffer);
        const pages = chunkTextForReader(extractedText, 2200, 24);
        const questions = inferQuestionsFromText(extractedText, 12);
        await db.collection('tract_contents').doc(tractId).set({
            tract_id: tractId,
            content: extractedText,
            pages,
            questions,
            image_url: (after.coverImage || after.imageUrl || null),
            source: 'pdf_ingest_best_effort',
            updated_at: new Date().toISOString(),
        }, { merge: true });
        await db.collection('tracts').doc(tractId).set({
            content_ready: true,
            extracted_page_count: pages.length,
            extracted_char_count: extractedText.length,
            pdf_ingest_source: sourceKey,
            pdf_ingested_at: new Date().toISOString(),
        }, { merge: true });
    }
    catch (error) {
        console.error('ingestTractPdfContent failed', tractId, error);
        await db.collection('tracts').doc(tractId).set({
            content_ready: false,
            pdf_ingest_source: sourceKey,
            pdf_ingest_error: `${error}`,
            pdf_ingested_at: new Date().toISOString(),
        }, { merge: true });
    }
});
function extractPdfTextBestEffort(buffer) {
    const raw = buffer.toString('latin1');
    const blocks = raw.match(/BT[\s\S]*?ET/g) || [];
    const parts = [];
    for (const block of blocks) {
        const direct = block.match(/\((?:\\.|[^\\)])*\)\s*Tj/g) || [];
        for (const token of direct) {
            const start = token.indexOf('(');
            const end = token.lastIndexOf(')');
            if (start >= 0 && end > start) {
                parts.push(decodePdfString(token.slice(start + 1, end)));
            }
        }
        const arrays = block.match(/\[(?:\\.|[^\]])*]\s*TJ/g) || [];
        for (const arr of arrays) {
            const inner = arr.slice(1, arr.indexOf(']'));
            const segments = inner.match(/\((?:\\.|[^\\)])*\)/g) || [];
            for (const seg of segments) {
                parts.push(decodePdfString(seg.slice(1, -1)));
            }
        }
    }
    const text = parts
        .join('\n')
        .replace(/\s+\n/g, '\n')
        .replace(/\n{3,}/g, '\n\n')
        .replace(/[ \t]{2,}/g, ' ')
        .trim();
    return text;
}
function decodePdfString(value) {
    return value
        .replace(/\\n/g, '\n')
        .replace(/\\r/g, '\r')
        .replace(/\\t/g, '\t')
        .replace(/\\\(/g, '(')
        .replace(/\\\)/g, ')')
        .replace(/\\\\/g, '\\')
        .replace(/\r\n/g, '\n')
        .replace(/\r/g, '\n');
}
function chunkTextForReader(text, chunkSize, maxPages) {
    const normalized = text.replace(/\r\n?/g, '\n').trim();
    if (!normalized)
        return [];
    const chunks = [];
    let cursor = 0;
    while (cursor < normalized.length && chunks.length < maxPages) {
        const target = Math.min(cursor + chunkSize, normalized.length);
        if (target === normalized.length) {
            chunks.push(normalized.slice(cursor).trim());
            break;
        }
        const splitAt = normalized.lastIndexOf('\n', target);
        if (splitAt > cursor + Math.floor(chunkSize / 3)) {
            chunks.push(normalized.slice(cursor, splitAt).trim());
            cursor = splitAt + 1;
        }
        else {
            chunks.push(normalized.slice(cursor, target).trim());
            cursor = target;
        }
    }
    return chunks.filter((c) => c.length > 0);
}
function inferQuestionsFromText(text, max) {
    const lines = text
        .split(/\n+/)
        .map((l) => l.trim())
        .filter(Boolean);
    const result = [];
    for (const line of lines) {
        if (!line.endsWith('?'))
            continue;
        const question = line.replace(/^\d+[\).\s-]*/, '').trim();
        if (question.length < 12)
            continue;
        result.push({
            id: `q_${result.length + 1}`,
            question,
            type: 'text',
            order: result.length + 1,
        });
        if (result.length >= max)
            break;
    }
    return result;
}
async function sendReceiptEmail(params) {
    const logoUrl = ALIVE_LOGO_URL.value();
    const fmtAmount = params.amount != null ? Number(params.amount).toLocaleString() : '';
    const html = `
    <div style="font-family: Arial, sans-serif; color:#111;">
      <div style="text-align:center; padding:16px;">
        <img src="${logoUrl}" alt="ALIVE-NG" height="48" />
      </div>
      <h2 style="text-align:center;">Donation Receipt</h2>
      <p>Dear donor,</p>
      <p>Thank you for your generous support. Below are the details of your donation.</p>
      <table style="width:100%; border-collapse:collapse;">
        <tr><td style="padding:8px;">Reference</td><td style="padding:8px;"><strong>${params.reference}</strong></td></tr>
        <tr><td style="padding:8px;">Amount</td><td style="padding:8px;"><strong>${fmtAmount} ${params.currency || ''}</strong></td></tr>
        <tr><td style="padding:8px;">Item</td><td style="padding:8px;"><strong>${params.title || 'Donation'}</strong></td></tr>
      </table>
      <hr />
      <p style="font-size:12px; color:#555;">ALIVE-NG Finance Department • ALIVE-NG Ministries</p>
    </div>
  `;
    try {
        await _sendViaResend({ to: params.to, subject: 'ALIVE-NG Donation Receipt', html });
    }
    catch (e) {
        console.error('Failed to send receipt email via Resend', e);
    }
}
