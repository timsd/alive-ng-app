// Firebase Messaging Service Worker
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Firebase configuration - configured via configure_web.dart
const firebaseConfig = {
  apiKey: "AIzaSyDmpl9Idp9Q0ult4BfWPg5J7A1URQOpDoU",
  authDomain: "alive-ng-flutter-app.firebaseapp.com",
  projectId: "alive-ng-flutter-app",
  storageBucket: "alive-ng-flutter-app.firebasestorage.app",
  messagingSenderId: "234909240985",
  appId: "1:234909240985:web:9d703098e9fcce3e8e3208",
  measurementId: "G-CC6JE7224Q"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Initialize Firebase Cloud Messaging and get a reference to the service
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  // Customize notification here
  const notificationTitle = payload.notification?.title || 'ALIVE NG';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new message',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'alive-ng-notification',
    requireInteraction: false,
    actions: [
      {
        action: 'open',
        title: 'Open App'
      },
      {
        action: 'close',
        title: 'Close'
      }
    ]
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click events
self.addEventListener('notificationclick', function(event) {
  console.log('[firebase-messaging-sw.js] Notification click received.');

  event.notification.close();

  if (event.action === 'open' || !event.action) {
    // Open the app when notification is clicked
    event.waitUntil(
      clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
        // Check if there is already a window/tab open with the target URL
        for (var i = 0; i < clientList.length; i++) {
          var client = clientList[i];
          // If so, just focus it.
          if (client.url === '/' && 'focus' in client) {
            return client.focus();
          }
        }
        // If not, then open the target URL in a new window/tab.
        if (clients.openWindow) {
          return clients.openWindow('/');
        }
      })
    );
  }
});

// Handle push events
self.addEventListener('push', function(event) {
  console.log('[firebase-messaging-sw.js] Push received.');
  
  if (event.data) {
    const payload = event.data.json();
    console.log('[firebase-messaging-sw.js] Push data: ', payload);
    
    const notificationTitle = payload.notification?.title || 'ALIVE NG';
    const notificationOptions = {
      body: payload.notification?.body || 'You have a new message',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      tag: 'alive-ng-push',
      data: payload.data || {}
    };

    event.waitUntil(
      self.registration.showNotification(notificationTitle, notificationOptions)
    );
  }
});