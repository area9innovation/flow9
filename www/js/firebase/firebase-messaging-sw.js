importScripts('firebase-app.js');
importScripts('firebase-config.js');
importScripts('firebase-messaging.js');

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();
var sendMessageToClient = {
  fn: function(data) { /* Do nothing */ }
}

messaging.setBackgroundMessageHandler(function(payload) {
  var title = (payload.data.notification && payload.data.notification.title) ? payload.data.notification.title : (payload.data.title ? payload.data.title : "undefined");
  var body = (payload.data.notification && payload.data.notification.body) ? payload.data.notification.body : (payload.data.body ? payload.data.body : "undefined");
  var tag = (payload.data.notification && payload.data.notification.tag) ? payload.data.notification.tag : (payload.data.tag ? payload.data.tag : "");
  var action = (payload.data.notification && payload.data.notification.click_action) ? payload.data.notification.click_action : (payload.data.click_action ? payload.data.click_action : null);
  var icon = (payload.data.notification && payload.data.notification.icon) ? payload.data.notification.icon : (payload.data.icon ? payload.data.icon : null);

  sendMessageToClient.fn({
    action: "notification",
    title: title,
    body: body,
    data: JSON.stringify(payload.data),
    id: payload.data["google.c.a.c_id"],
    from: payload.from,
    stamp: payload.data["google.c.a.ts"]
  });

  self.registration.showNotification(title, {
    body: body,
    icon: icon,
    tag: tag,
    data: action
  });
});

self.addEventListener('notificationclick', function(event) {
    const target = event.notification.data || '/';
    event.notification.close();

    // Let's see if we already have an application window open:
    event.waitUntil(clients.matchAll({
      type: "window",
      includeUncontrolled: true
    }).then(function (clientList) {
      for (const client of clientList) {
        const urlClient = new URL(client.url);
        const urlNotif = new URL(target);
        if (urlClient.host == urlNotif.host && urlClient.pathname == urlNotif.pathname && 'focus' in client) {
            return client.focus();
        }
      }

      // If we didn't find an existing application window, open a new one:
      return clients.openWindow(target);
    }));
});

self.addEventListener('message', function(event) {
  var respond = function(data) {
    if (event.ports.length > 0) {
      event.ports[0].postMessage(data);
    } else {
      console.error("ServiceWorker: Failed to respond!");
    }
  };

  if (event.data.action == "subscribe_on_messages" && typeof event.data.delay !== "undefined" && event.data.delay !== null) {
    var delay = event.data.delay;
    if (delay < 10) delay = 10;

    var clientId = event.clientId;
    if (!clientId && event.ports.length == 0) {
      sendMessageToClient.fn = function(data) { /* Do nothing */ };
      respond({ action: "subscribe_on_messages", status: "Failed", error: "clientId is empty" });
    } else if (clientId) {
      sendMessageToClient.fn = function(data) {
        // Post message with delay
        // Otherwise makes problem for caching
        setTimeout(function() {
          clients.get(clientId).then(function(client) {
            if (!isEmpty(client)) client.postMessage(data);
          });
        }, delay);
      };

      respond({ action: "subscribe_on_messages", status: "OK" });
    } else {
      var port = event.ports[0];
      sendMessageToClient.fn = function(data) {
        // Post message with delay
        // Otherwise makes problem for caching
        setTimeout(function() {
          port.postMessage(data);
        }, delay);
      };

      respond({ action: "subscribe_on_messages", status: "OK" });
    }
  } else if (event.data.action == "unsubscribe_from_messages") {
    sendMessageToClient.fn = function(data) { /* Do nothing */ };
    respond({ action: "unsubscribe_from_messages", status: "OK" });
  } else {
    respond({ status: "Failed", error: "Unknown operation: " + event.data.action });
  }
});