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
const { Client, Users, Messaging, Query } = sdk;

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
