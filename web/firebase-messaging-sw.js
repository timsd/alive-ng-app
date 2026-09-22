// Appwrite Messaging uses FCM as the push provider for web delivery.
// This worker is intentionally limited to FCM browser push handling.
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDmpl9Idp9Q0ult4BfWPg5J7A1URQOpDoU',
  authDomain: 'alive-ng-flutter-app.firebaseapp.com',
  projectId: 'alive-ng-flutter-app',
  storageBucket: 'alive-ng-flutter-app.firebasestorage.app',
  messagingSenderId: '234909240985',
  appId: '1:234909240985:web:9d703098e9fcce3e8e3208',
  measurementId: 'G-CC6JE7224Q',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || 'ALIVE Nigeria';
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
