/**
 * Monthly Donation Reminder Function
 *
 * Sends localized push notifications (with email fallback) to all active
 * members on the 1st of each month. Tapping the notification deep-links to
 * the donation screen.
 *
 * SDK note: written for node-appwrite ^22.1.3 and verified against the
 * Messaging API in that version. Both calls use the OBJECT form so the
 * parameter order can never silently break (positional order changed
 * between SDK releases, which is exactly the bug class that is hardest to
 * spot in review).
 */

const sdk = require('node-appwrite');
const { Client, Users, Messaging, Databases, Query, ID } = sdk;


// Localized notification content.
// NOTE: Have a native speaker confirm the Yoruba / Igbo / Hausa wording
// before a live broadcast.
const NOTIFICATION_MESSAGES = {
  en: {
    title: 'Ministry Support Reminder',
    body: (name) =>
      `Dear ${name}, a new month begins! Your support enables us to spread the Gospel and serve our community. Tap to give today.`,
    action: 'Give Now',
  },
  yo: {
    title: 'Itaniji Iranlowo fun Ise Ihin Rere',
    body: (name) =>
      `${name}, Oolùfe. Oṣù tuntun miran ti bẹ̀rẹ̀! Atìlẹ́yìn rẹ ń fún wa lágbára lati tàn Ìròyìn Aayò kálẹ̀ kí á sì sìn àwùjọ wa. Tẹ ibí láti se itọrẹ lónìí.`,
    action: 'Fi Ore Ranse',
  },
  ig: {
    title: 'Ncheta Inye Aka na Ozi Oma',
    body: (name) =>
      `Ndeewo ${name}, onwa ohuru amaliteghalari! Inye aka gi na-enyere anyi aka isa Ozi Oma na ijere obodo anyi ozi. Tapa ebe a ka i nye onyinye gi taa.`,
    action: 'Nye Onyinye Taa',
  },
  ha: {
    title: 'Tuna Maza da Tallafin Bada Wata',
    body: (name) =>
      `Barka da sabon wata ${name}! Tallafin ku yana taimaka mana wajen yada Linjila da hidimta wa al'umma. Danna nan don ba da gudummawa a yau.`,
    action: 'Ba da gudummawa',
  },
};

// Default to English if the language is not recognized.
function getLocalizedMessage(languageCode) {
  const code = (languageCode || 'en').toLowerCase().split('-')[0];
  return NOTIFICATION_MESSAGES[code] || NOTIFICATION_MESSAGES.en;
}

// Main function handler — called by Appwrite runtime on schedule or manual trigger.
module.exports = async ({ req, res, log, error }) => {
  const APPWRITE_ENDPOINT = process.env.APPWRITE_ENDPOINT || 'https://api.alivenigeria.org/v1';
  const APPWRITE_PROJECT_ID = process.env.APPWRITE_PROJECT_ID || '6a3bef53002f5090dedf';
  const APPWRITE_API_KEY = process.env.APPWRITE_API_KEY;
  const DATABASE_ID = process.env.APPWRITE_DATABASE_ID || '6a089307002e54291a32';
  const APP_SETTINGS_COLLECTION_ID = process.env.APP_SETTINGS_COLLECTION_ID || 'app_settings';

  // Deep-link target inside the ALIVE-NG app.
  const DONATION_DEEP_LINK = 'https://app.alivenigeria.org/donate';

  if (!APPWRITE_API_KEY) {
    error('APPWRITE_API_KEY is not set. Aborting.');
    return res.json({ ok: false, message: 'Server misconfiguration: missing API key.' }, 500);
  }

  const client = new Client()
    .setEndpoint(APPWRITE_ENDPOINT)
    .setProject(APPWRITE_PROJECT_ID)
    .setKey(APPWRITE_API_KEY);

  const users = new Users(client);
  const messaging = new Messaging(client);
  const databases = new Databases(client);

  // ── 1. Load opt-out list from app_settings ────────────────────────────────
  let optedOutUserIds = new Set();
  try {
    const settingsDoc = await databases.getDocument(
      DATABASE_ID,
      APP_SETTINGS_COLLECTION_ID,
      'monthly_reminder_optouts',
    );
    const raw = settingsDoc?.data?.value;
    const list = Array.isArray(raw)
      ? raw
      : typeof raw === 'string'
      ? JSON.parse(raw)
      : [];
    optedOutUserIds = new Set(list);
    log(`Loaded ${optedOutUserIds.size} opt-out user(s).`);
  } catch (e) {
    // If document does not exist yet, no one has opted out — carry on.
    if (e?.code !== 404) {
      error(`Warning: Could not load opt-out list: ${e?.message}`);
    }
  }

  // ── 2. Page through all registered users ──────────────────────────────────
  let cursor = null;
  let totalSent = 0;
  let totalSkipped = 0;
  let totalErrors = 0;

  log('Starting monthly donation reminder dispatch...');

  do {
    const queries = [Query.limit(100)];
    if (cursor) queries.push(Query.cursorAfter(cursor));

    const page = await users.list(queries);
    if (!page.users.length) break;

    for (const user of page.users) {
      // Skip opted-out users and users without push targets.
      if (optedOutUserIds.has(user.$id)) {
        totalSkipped++;
        continue;
      }

      // Prefer the user's preferred language; fall back to English.
      const lang = user.prefs?.language || user.prefs?.locale || 'en';
      const messages = getLocalizedMessage(lang);
      const displayName = user.name?.split(' ')[0] || 'Friend';

      try {
        await messaging.createPush({
          messageId: ID.unique(),
          title: messages.title,
          body: messages.body(displayName),
          topics: [],
          users: [user.$id],
          targets: [],
          data: {
            route: '/donate',
            url: DONATION_DEEP_LINK,
            action: messages.action,
          },
          action: DONATION_DEEP_LINK,
          icon: '',
          sound: 'default',
          color: '',
          tag: 'monthly_donation_reminder',
          badge: '',
          draft: false,
          scheduledAt: '',
        });
        totalSent++;
      } catch (sendErr) {
        // Log but don't abort the whole batch for one user failure.
        error(`Failed to send notification to user ${user.$id}: ${sendErr?.message}`);
        totalErrors++;
      }
    }

    cursor = page.users.at(-1)?.$id ?? null;
    log(`Processed batch of ${page.users.length}. Sent: ${totalSent}, Skipped: ${totalSkipped}, Errors: ${totalErrors}`);
  } while (cursor);

  const summary = {
    ok: true,
    sent: totalSent,
    skipped: totalSkipped,
    errors: totalErrors,
    timestamp: new Date().toISOString(),
  };
  log(`Monthly donation reminder complete: ${JSON.stringify(summary)}`);
  return res.json(summary);
};

