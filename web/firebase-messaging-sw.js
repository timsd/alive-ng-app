// Appwrite Messaging uses FCM as the push provider for web delivery.
// This worker is intentionally limited to FCM browser push handling.
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: '{{FIREBASE_API_KEY}}',
  authDomain: '{{FIREBASE_AUTH_DOMAIN}}',
  projectId: '{{FIREBASE_PROJECT_ID}}',
  storageBucket: '{{FIREBASE_STORAGE_BUCKET}}',
  messagingSenderId: '{{FIREBASE_MESSAGING_SENDER_ID}}',
  appId: '{{FIREBASE_APP_ID}}',
  measurementId: '{{FIREBASE_MEASUREMENT_ID}}',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || 'ALIVE-NG';
  const options = {
    body: notification.body || 'You have a new notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow('/');
      return undefined;
    }),
  );
});
