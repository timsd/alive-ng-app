// Firebase Cloud Messaging service worker for the deployed web app.
//
// A browser cannot receive a push notification without one of these: FCM's Web
// SDK runs here, in the background, and hands the token to the page. Without
// this file `getToken` fails with "Service worker registration failed", so no
// device token could ever be created and push was impossible on web.
//
// The config below is a *placeholder*. It is overwritten at build time by
// scripts/configure_web.dart from the FIREBASE_WEB_* dart-defines, so no
// credentials are committed here. A real Firebase Web app must be registered in
// the project first -- see web/README-push.md.
//
// Only the notification data Appwrite sends is handled: a title, a body and an
// optional URL to open when the member taps it.

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: '__FIREBASE_WEB_API_KEY__',
  authDomain: '__FIREBASE_WEB_AUTH_DOMAIN__',
  projectId: '__FIREBASE_WEB_PROJECT_ID__',
  storageBucket: '__FIREBASE_WEB_STORAGE_BUCKET__',
  messagingSenderId: '__FIREBASE_WEB_MESSAGING_SENDER_ID__',
  appId: '__FIREBASE_WEB_APP_ID__',
});

const messaging = firebase.messaging();

// Appwrite sends data-only messages, so the payload is read from data rather
// than from `notification`, which is empty for those.
messaging.onMessage((payload) => {
  const data = payload.data || {};
  const title = data.title || 'ALIVE Nigeria';
  const body = data.body || '';

  self.registration.showNotification(title, {
    body,
    icon: 'icons/Icon-192.png',
    badge: 'icons/badge.png',
    // Collapse duplicates per conversation, and keep the tag consistent with
    // the tap handler below so tapping the newest one opens the right screen.
    tag: data.tag || 'alive-notification',
    renotify: false,
    data: { url: data.url || '/' },
  });
});

messaging.onBackgroundMessage((payload) => {
  // Notifications are displayed by the onMessage handler above via
  // showNotification; nothing further is required here.
});

// Tapping a notification opens the URL the message carried, in an existing tab
// when possible so the member does not accumulate tabs.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = (event.notification.data && event.notification.data.url) || '/';
  const absolute = new URL(target, self.location.origin).href;

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          client.navigate(absolute);
          return client.focus();
        }
      }
      return self.clients.openWindow(absolute);
    }),
  );
});
