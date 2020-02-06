importScripts('firebase-app.js');
importScripts('firebase-config.js');
importScripts('firebase-messaging.js');

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.setBackgroundMessageHandler(function(payload) {
    return self.registration.showNotification(payload.data.title, {
        body: payload.data.body,
        icon: payload.data.icon,
        tag: payload.data.tag,
        data: payload.data.link
    });
});
