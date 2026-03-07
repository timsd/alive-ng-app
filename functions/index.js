/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

/**
 * Bible verse search function
 * Allows users to search for Bible verses by reference or keyword
 */

const functions = require("firebase-functions");
const { setGlobalOptions } = require("firebase-functions");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const axios = require("axios");
const cors = require("cors")({ origin: true });
const { StreamChat } = require("stream-chat");
// Gen2 scheduler and params migration are deferred to avoid deploy-time analysis issues

admin.initializeApp();
setGlobalOptions({ maxInstances: 10 });

/**
 * Callable function: Send notification to a specific user.
 * Expects: { userId: string, title: string, body: string, data?: object }
 */
exports.sendNotificationToUser = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }

    const userId = data.userId;
    const title = data.title;
    const body = data.body;
    const payloadData = data.data || {};

    if (!userId || !title || !body) {
      throw new functions.https.HttpsError("invalid-argument", "Missing required fields: userId, title, body");
    }

    // Get user's active push token from Firestore (doc keyed by userId)
    const tokenDoc = await admin.firestore().collection("push_tokens").doc(userId).get();
    if (!tokenDoc.exists) {
      logger.warn(`No push token found for user ${userId}`);
      return { success: false, message: "No push token" };
    }
    const tokenData = tokenDoc.data();
    if (!tokenData || tokenData.is_active !== true || !tokenData.token) {
      logger.warn(`Inactive or missing token for user ${userId}`);
      return { success: false, message: "Inactive or missing token" };
    }

    const token = tokenData.token;

    const message = {
      token,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(payloadData).map(([k, v]) => [k, String(v)])),
    };

    const response = await admin.messaging().send(message);

    // Log to notification_history
    await admin.firestore().collection("notification_history").add({
      user_id: userId,
      title,
      body,
      data: payloadData,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, messageId: response };
  } catch (error) {
    logger.error("Error in sendNotificationToUser", error);
    throw new functions.https.HttpsError("internal", error.message || "Unknown error");
  }
});

if (functions.pubsub && typeof functions.pubsub.schedule === "function") {
  exports.processRecurringDonations = functions.pubsub
    .schedule("0 0 * * *")
    .timeZone("Africa/Lagos")
    .onRun(async (context) => {
      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();
      try {
        const due = await db
          .collection("recurring_donations")
          .where("status", "==", "active")
          .where("next_payment_date", "<=", now)
          .get();
        if (due.empty) return null;
        const tasks = due.docs.map(async (doc) => {
          const d = doc.data();
          const { amount, email, authorization_code, user_id, frequency } = d;
          if (!authorization_code) return;
          const key = functions.config().paystack?.secret_key || process.env.PAYSTACK_SECRET_KEY;
          if (!key) return;
          try {
            const resp = await axios.post(
              "https://api.paystack.co/transaction/charge_authorization",
              {
                amount: Math.round(amount * 100),
                email,
                authorization_code,
                currency: "NGN",
                metadata: { user_id, recurring_donation_id: doc.id },
              },
              { headers: { Authorization: `Bearer ${key}` } }
            );
            if (resp.data.status) {
              const next = new Date();
              if (frequency === "weekly") next.setDate(next.getDate() + 7);
              else if (frequency === "monthly") next.setMonth(next.getMonth() + 1);
              else if (frequency === "yearly") next.setFullYear(next.getFullYear() + 1);
              await doc.ref.update({
                last_payment_date: now,
                next_payment_date: admin.firestore.Timestamp.fromDate(next),
                failure_count: 0,
              });
              await db.collection("donation_records").add({
                user_id,
                amount,
                status: "completed",
                transaction_id: resp.data.data.reference,
                created_at: now,
                type: "recurring",
                recurring_donation_id: doc.id,
                payment_data: { processor: "paystack", channel: "recurring_charge" },
              });
            }
          } catch (e) {
            const failures = (d.failure_count || 0) + 1;
            const updates = { failure_count: failures };
            if (failures >= 3) updates.status = "failed";
            await doc.ref.update(updates);
          }
        });
        await Promise.all(tasks);
        return null;
      } catch (e) {
        logger.error("Error in processRecurringDonations", e);
        return null;
      }
    });
}
/**
 * Callable function: Send notification to a topic.
 * Expects: { topic: string, title: string, body: string, data?: object }
 */
exports.sendTopicNotification = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }

    const topic = data.topic;
    const title = data.title;
    const body = data.body;
    const payloadData = data.data || {};

    if (!topic || !title || !body) {
      throw new functions.https.HttpsError("invalid-argument", "Missing required fields: topic, title, body");
    }

    const message = {
      topic,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(payloadData).map(([k, v]) => [k, String(v)])),
    };

    const response = await admin.messaging().send(message);

    // Optionally log topic notification
    await admin.firestore().collection("notification_history").add({
      topic,
      title,
      body,
      data: payloadData,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, messageId: response };
  } catch (error) {
    logger.error("Error in sendTopicNotification", error);
    throw new functions.https.HttpsError("internal", error.message || "Unknown error");
  }
});

/**
 * Callable function: Search Bible verses by text or reference.
 * Expects: { query: string, version: string, language: string, limit: number }
 * Returns: Array of verse objects matching the search criteria
 */
exports.searchBibleVerses = functions.https.onCall(async (data, context) => {
  try {
    const { query, version, language, limit = 20 } = data;
    
    if (!query || !version || !language) {
      throw new functions.https.HttpsError(
        "invalid-argument", 
        "Missing required fields: query, version, language",
      );
    }
    
    const db = admin.firestore();
    const results = [];
    
    // Check if query looks like a Bible reference (e.g., "John 3:16" or "Genesis 1:1-10")
    const referenceRegex = /^([1-3]?\s?[A-Za-z]+)\s+(\d+)(?::(\d+)(?:-(\d+))?)?$/;
    const referenceMatch = query.match(referenceRegex);
    
    if (referenceMatch) {
      // Handle Bible reference search
      const [, book, chapter, verseStart, verseEnd] = referenceMatch;
      
      let verseQuery = db.collection("bible_verses")
        .where("language", "==", language)
        .where("version", "==", version)
        .where("book", "==", book)
        .where("chapter", "==", parseInt(chapter));
      
      if (verseStart) {
        if (verseEnd) {
          // Range of verses
          const startVerse = parseInt(verseStart);
          const endVerse = parseInt(verseEnd);
          verseQuery = verseQuery
            .where("verse", ">=", startVerse)
            .where("verse", "<=", endVerse)
            .orderBy("verse");
        } else {
          // Single verse
          verseQuery = verseQuery.where("verse", "==", parseInt(verseStart));
        }
      }
      
      const snapshot = await verseQuery.limit(limit).get();
      
      snapshot.forEach(doc => {
        const data = doc.data();
        results.push({
          book: data.book,
          chapter: data.chapter,
          verse: data.verse,
          text: data.text,
          reference: `${data.book} ${data.chapter}:${data.verse}`,
        });
      });
    } else {
      // Handle keyword search
      // First try exact match on searchableText array
      const exactMatchSnapshot = await db.collection("bible_verses")
        .where("language", "==", language)
        .where("version", "==", version)
        .where("searchableText", "array-contains", query.toLowerCase())
        .limit(limit)
        .get();
      
      exactMatchSnapshot.forEach(doc => {
        const data = doc.data();
        results.push({
          book: data.book,
          chapter: data.chapter,
          verse: data.verse,
          text: data.text,
          reference: `${data.book} ${data.chapter}:${data.verse}`,
        });
      });
      
      // If we don't have enough results, try a more flexible search
      if (results.length < limit) {
        // Split query into words for more flexible matching
        const queryWords = query.toLowerCase().split(/\s+/);
        
        // Get verses that contain any of the words
        const flexibleMatchPromises = queryWords.map(word => {
          return db.collection("bible_verses")
            .where("language", "==", language)
            .where("version", "==", version)
            .where("searchableText", "array-contains", word)
            .limit(limit)
            .get();
        });
        
        const flexibleSnapshots = await Promise.all(flexibleMatchPromises);
        
        // Track verses we've already added to avoid duplicates
        const addedVerseIds = new Set(results.map(r => `${r.book}-${r.chapter}-${r.verse}`));
        
        flexibleSnapshots.forEach(snapshot => {
          snapshot.forEach(doc => {
            const data = doc.data();
            const verseId = `${data.book}-${data.chapter}-${data.verse}`;
            
            if (!addedVerseIds.has(verseId) && results.length < limit) {
              results.push({
                book: data.book,
                chapter: data.chapter,
                verse: data.verse,
                text: data.text,
                reference: `${data.book} ${data.chapter}:${data.verse}`,
              });
              addedVerseIds.add(verseId);
            }
          });
        });
      }
    }
    
    return results;
  } catch (error) {
    logger.error("Error in searchBibleVerses", error);
    throw new functions.https.HttpsError("internal", error.message || "Unknown error");
  }
});

/**
 * Callable function: Initialize Paystack payment transaction
 * Expects: { amount: number, email: string, reference: string, metadata?: object }
 * Returns: { success: boolean, access_code?: string, authorization_url?: string, message?: string }
 */
exports.initializePaystackPayment = functions.https.onCall(async (data, context) => {
  return cors(data, context, async () => {
    try {
      // Verify authentication
      if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
      }

      const { amount, email, reference, metadata = {} } = data;

      // Validate required fields
      if (!amount || !email || !reference) {
        throw new functions.https.HttpsError(
          "invalid-argument", 
          "Missing required fields: amount, email, reference",
        );
      }

      // Validate amount (must be positive and in kobo for Paystack)
      const amountInKobo = Math.round(amount * 100);
      if (amountInKobo <= 0) {
        throw new functions.https.HttpsError(
          "invalid-argument", 
          "Amount must be greater than 0",
        );
      }

      // Get Paystack secret key from environment variables
      const paystackSecretKey = safeParamValue(PAYSTACK_SECRET_KEY) || functions.config().paystack?.secret_key || process.env.PAYSTACK_SECRET_KEY;
      if (!paystackSecretKey) {
        logger.error("Paystack secret key not configured");
        throw new functions.https.HttpsError(
          "failed-precondition", 
          "Payment service not configured",
        );
      }

      // Prepare Paystack initialization payload
      const paystackPayload = {
        amount: amountInKobo,
        email: email,
        reference: reference,
        currency: "NGN",
        callback_url: "https://app.alivenigeria.org/payment/callback",
        metadata: {
          ...metadata,
          user_id: context.auth.uid,
          initiated_at: new Date().toISOString(),
        },
        channels: ["card", "bank", "ussd", "qr", "mobile_money", "bank_transfer"],
      };

      // Initialize transaction with Paystack
      const paystackResponse = await axios.post(
        "https://api.paystack.co/transaction/initialize",
        paystackPayload,
        {
          headers: {
            Authorization: `Bearer ${paystackSecretKey}`,
            "Content-Type": "application/json",
          },
        },
      );

      if (paystackResponse.data.status === true) {
        const { access_code, authorization_url } = paystackResponse.data.data;

        // Log the transaction initialization
        await admin.firestore().collection("payment_logs").add({
          user_id: context.auth.uid,
          reference: reference,
          amount: amount,
          email: email,
          status: "initialized",
          access_code: access_code,
          authorization_url: authorization_url,
          metadata: metadata,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        logger.info(`Payment initialized for user ${context.auth.uid}, reference: ${reference}`);

        return {
          success: true,
          access_code: access_code,
          authorization_url: authorization_url,
          message: "Payment initialized successfully",
        };
      } else {
        logger.error("Paystack initialization failed", paystackResponse.data);
        throw new functions.https.HttpsError(
          "internal", 
          paystackResponse.data.message || "Payment initialization failed",
        );
      }
    } catch (error) {
      logger.error("Error in initializePaystackPayment", error);
      
      if (error.response?.data) {
        logger.error("Paystack API error", error.response.data);
        throw new functions.https.HttpsError(
          "internal", 
          error.response.data.message || "Payment service error",
        );
      }
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError("internal", "Payment initialization failed");
    }
  });
});

/**
 * Callable: Export selected Firestore collections to Firebase Storage as CSV/JSON.
 * Expects: { collections?: string[], format?: 'csv'|'json' }
 * Returns: { ok: boolean, files: { [collection]: { path: string, url?: string } }, prefix: string }
 */
exports.exportFirestoreCollections = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    const isAdmin = (context.auth.token && context.auth.token.admin) || false;
    if (!isAdmin) {
      throw new functions.https.HttpsError("permission-denied", "Admin privilege required");
    }

    const collections = Array.isArray(data?.collections) && data.collections.length
      ? data.collections
      : [
          "profiles",
          "prayer_requests",
          "chapters",
          "user_roles",
          "user_groups",
          "notification_history",
          "bible_verses"
        ];
    const format = (data?.format === "json" || data?.format === "csv") ? data.format : "csv";

    const bucket = admin.storage().bucket();
    const prefix = `backups/${new Date().toISOString().replace(/[:.]/g, "-")}`;
    const files = {};

    function flattenDoc(obj) {
      const out = {};
      for (const [k, v] of Object.entries(obj || {})) {
        if (v === null || v === undefined) {
          out[k] = "";
        } else if (typeof v === "object" && !Array.isArray(v)) {
          out[k] = JSON.stringify(v);
        } else {
          out[k] = Array.isArray(v) ? JSON.stringify(v) : v;
        }
      }
      return out;
    }

    function toCsv(rows) {
      if (!rows.length) return "";
      const headers = Array.from(
        rows.reduce((set, r) => {
          Object.keys(r).forEach((k) => set.add(k));
          return set;
        }, new Set())
      );
      const escape = (val) => {
        const s = String(val ?? "");
        if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
        return s;
      };
      const lines = [];
      lines.push(headers.join(","));
      for (const r of rows) {
        lines.push(headers.map((h) => escape(r[h])).join(","));
      }
      return lines.join("\n");
    }

    for (const col of collections) {
      const snap = await admin.firestore().collection(col).get();
      const rows = [];
      snap.forEach((doc) => {
        const data = doc.data();
        rows.push({ id: doc.id, ...flattenDoc(data) });
      });

      const content =
        format === "json" ? JSON.stringify(rows, null, 2) : toCsv(rows);
      const contentType =
        format === "json" ? "application/json" : "text/csv";
      const path = `${prefix}/${col}.${format}`;
      const file = bucket.file(path);
      await file.save(content, { contentType, resumable: false });

      let url;
      try {
        const [signedUrl] = await file.getSignedUrl({
          action: "read",
          expires: Date.now() + 60 * 60 * 1000, // 1 hour
        });
        url = signedUrl;
      } catch (e) {
        logger.warn(`Failed to create signed URL for ${path}: ${e?.message || e}`);
      }

      files[col] = { path, url };
    }

    return { ok: true, files, prefix };
  } catch (error) {
    logger.error("Error in exportFirestoreCollections", error);
    throw new functions.https.HttpsError("internal", error.message || "Unknown error");
  }
});

exports.exportStreamChatMetadata = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    const isAdmin = (context.auth.token && context.auth.token.admin) || false;
    if (!isAdmin) {
      throw new functions.https.HttpsError("permission-denied", "Admin privilege required");
    }

    const apiKey = functions.config().stream?.api_key || process.env.STREAM_CHAT_API_KEY;
    const apiSecret = functions.config().stream?.api_secret || process.env.STREAM_CHAT_SECRET;
    if (!apiKey || !apiSecret) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Stream Chat credentials not configured",
      );
    }

    const client = new StreamChat(apiKey, apiSecret);
    const type = data?.type || "messaging";
    const filter = data?.filter || {};
    const sort = [{ field: "created_at", direction: -1 }];

    const channels = await client.queryChannels(
      { type, ...filter },
      sort,
      { limit: 100 },
    );

    const rows = channels.map((ch) => ({
      id: ch.id,
      type: ch.type,
      name: ch.data?.name || "",
      created_at: ch.created_at?.toISOString?.() || ch.created_at,
      created_by_id: ch.created_by?.id || "",
      member_count: Array.isArray(ch.state?.members) ? ch.state.members.length : (ch.members?.length || 0),
      members: (Array.isArray(ch.state?.members) ? ch.state.members : ch.members || [])
        .map((m) => m.user?.id || m.user_id || m.id)
        .filter(Boolean),
      extraData: ch.data || {},
    }));

    const bucket = admin.storage().bucket();
    const prefix = `backups/${new Date().toISOString().replace(/[:.]/g, "-")}`;
    const path = `${prefix}/stream_chat_channels.json`;
    const file = bucket.file(path);
    await file.save(JSON.stringify(rows, null, 2), {
      contentType: "application/json",
      resumable: false,
    });

    let url;
    try {
      const [signedUrl] = await file.getSignedUrl({
        action: "read",
        expires: Date.now() + 60 * 60 * 1000,
      });
      url = signedUrl;
    } catch (e) {
      logger.warn(`Failed to create signed URL for ${path}: ${e?.message || e}`);
    }

    return { ok: true, file: { path, url }, prefix, count: rows.length };
  } catch (error) {
    logger.error("Error in exportStreamChatMetadata", error);
    throw new functions.https.HttpsError("internal", error.message || "Unknown error");
  }
});

/**
 * Callable: Export Stream Chat messages per channel to Firebase Storage.
 * Input: { type?: string, filter?: object, limitPerChannel?: number }
 * Output: { ok: boolean, prefix: string, files: Array<{ cid: string, path: string, url?: string, count: number }> }
 */
exports.exportStreamChatMessages = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    const isAdmin = (context.auth.token && context.auth.token.admin) || false;
    if (!isAdmin) {
      throw new functions.https.HttpsError("permission-denied", "Admin privilege required");
    }

    const apiKey = functions.config().stream?.api_key || process.env.STREAM_CHAT_API_KEY;
    const apiSecret = functions.config().stream?.api_secret || process.env.STREAM_CHAT_SECRET;
    if (!apiKey || !apiSecret) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Stream Chat credentials not configured",
      );
    }

    const client = new StreamChat(apiKey, apiSecret);
    const type = data?.type || "messaging";
    const filter = data?.filter || {};
    const limitPerChannel = Number.isInteger(data?.limitPerChannel) ? data.limitPerChannel : 500;
    const sort = [{ field: "created_at", direction: -1 }];

    const channels = await client.queryChannels(
      { type, ...filter },
      sort,
      { limit: 100 },
    );

    const bucket = admin.storage().bucket();
    const prefix = `backups/${new Date().toISOString().replace(/[:.]/g, "-")}/stream_chat_messages`;
    const files = [];

    for (const ch of channels) {
      try {
        const cid = ch.cid || `${ch.type}:${ch.id}`;
        // Query messages from the channel
        const res = await ch.query({
          messages: { limit: limitPerChannel },
          state: true,
        });
        const messages = Array.isArray(res.messages) ? res.messages : (ch.state?.messages || []);

        const rows = messages.map((m) => ({
          id: m.id,
          text: m.text || "",
          user_id: m.user?.id || "",
          created_at: m.created_at?.toISOString?.() || m.created_at,
          updated_at: m.updated_at?.toISOString?.() || m.updated_at,
          mentioned_users: (m.mentioned_users || []).map((u) => u?.id).filter(Boolean),
          attachments: (m.attachments || []).map((a) => ({
            type: a.type,
            title: a.title,
            image_url: a.image_url,
            asset_url: a.asset_url,
            file_size: a.file_size,
          })),
          extraData: m.extraData || {},
        }));

        const path = `${prefix}/${cid.replace(/[:/]/g, "_")}.json`;
        const file = bucket.file(path);
        await file.save(JSON.stringify(rows, null, 2), {
          contentType: "application/json",
          resumable: false,
        });

        let url;
        try {
          const [signedUrl] = await file.getSignedUrl({
            action: "read",
            expires: Date.now() + 60 * 60 * 1000,
          });
          url = signedUrl;
        } catch (e) {
          logger.warn(`Failed to create signed URL for ${path}: ${e?.message || e}`);
        }

        files.push({ cid, path, url, count: rows.length });
      } catch (e) {
        logger.error(`Error exporting messages for channel ${ch.id}`, e);
      }
    }

    return { ok: true, prefix, files };
  } catch (error) {
    logger.error("Error in exportStreamChatMessages", error);
    throw new functions.https.HttpsError("internal", error.message || "Unknown error");
  }
});

/**
 * HTTP function: Verify Paystack payment transaction
 * This endpoint is called by Paystack webhook to verify payments
 */
exports.verifyPaystackPayment = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      // Only allow POST requests
      if (req.method !== "POST") {
        res.status(405).send("Method not allowed");
        return;
      }

      const { reference } = req.body;

      if (!reference) {
        res.status(400).json({ success: false, message: "Reference is required" });
        return;
      }

      // Get Paystack secret key
      const paystackSecretKey = functions.config().paystack?.secret_key || process.env.PAYSTACK_SECRET_KEY;
      if (!paystackSecretKey) {
        logger.error("Paystack secret key not configured");
        res.status(500).json({ success: false, message: "Payment service not configured" });
        return;
      }

      // Verify transaction with Paystack
      const verificationResponse = await axios.get(
        `https://api.paystack.co/transaction/verify/${reference}`,
        {
          headers: {
            Authorization: `Bearer ${paystackSecretKey}`,
          },
        },
      );

      if (verificationResponse.data.status === true) {
        const transactionData = verificationResponse.data.data;

        // Update payment log with verification result
        const paymentLogQuery = await admin
          .firestore()
          .collection("payment_logs")
          .where("reference", "==", reference)
          .limit(1)
          .get();

        if (!paymentLogQuery.empty) {
          const paymentLogDoc = paymentLogQuery.docs[0];
          await paymentLogDoc.ref.update({
            status: transactionData.status,
            verified_at: admin.firestore.FieldValue.serverTimestamp(),
            transaction_data: transactionData,
          });
        }

        // Update donation record if this is a donation
        if (transactionData.metadata?.donation_id) {
          const donationRef = admin
            .firestore()
            .collection("donation_records")
            .doc(transactionData.metadata.donation_id);

          await donationRef.update({
            status: transactionData.status === "success" ? "completed" : "failed",
            transaction_id: reference,
            verified_at: admin.firestore.FieldValue.serverTimestamp(),
            payment_data: {
              processor: "paystack",
              amount: transactionData.amount / 100, // Convert from kobo to naira
              currency: transactionData.currency,
              channel: transactionData.channel,
              fees: transactionData.fees / 100,
            },
          });
        }

        logger.info(`Payment verified for reference: ${reference}, status: ${transactionData.status}`);

        res.status(200).json({
          success: true,
          status: transactionData.status,
          message: "Payment verified successfully",
        });
      } else {
        logger.error("Payment verification failed", verificationResponse.data);
        res.status(400).json({
          success: false,
          message: verificationResponse.data.message || "Payment verification failed",
        });
      }
    } catch (error) {
      logger.error("Error in verifyPaystackPayment", error);
      
      if (error.response?.data) {
        logger.error("Paystack verification error", error.response.data);
      }
      
      res.status(500).json({
        success: false,
        message: "Payment verification error",
      });
    }
  });
});

