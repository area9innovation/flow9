
// Important to initialize notificationclick listener before Firebase Initialization
self.addEventListener('notificationclick', function(event) {
  logMessage('Notification click received', event);
  
  event.notification.close();

  // Get the URL to open
  var targetUrl = '/';
  const message = event.notification.data.FCM_MSG;
  // message.notification.click_action not supported on V1 API
  // Known issue for iOS 26 and previous version: when the app is in foreground notification click doesn't work correctly
  if (message && message.data && message.data.click_action) {
    targetUrl = message.data.click_action;
  }

  // Handle action clicks
  if (event.action === 'open' || !event.action) {
    logMessage('Opening URL', targetUrl);

    // Enhanced client handling specifically
    event.waitUntil(
      clients.matchAll({
        type: "window",
        includeUncontrolled: true
      }).then(function (clientList) {
        logMessage('Found clients', clientList.length);
        
        // Try to find an existing client with the same origin
        for (const client of clientList) {
          try {
            const clientUrl = new URL(client.url);
            let targetUrlObj = new URL(targetUrl);
            
            if (clientUrl.origin === targetUrlObj.origin && 'focus' in client) {
              logMessage('Focusing existing client');

              // For macOS Safari, try navigation if needed
              if (clientUrl.pathname === targetUrlObj.pathname) {
                let newUrl = new URL(clientUrl.href);
                targetUrlObj.searchParams.forEach((value, key) => {
                  newUrl.searchParams.set(key, value);
                });

                if (targetUrlObj.hash) {
                    newUrl.hash = targetUrlObj.hash;
                }

                targetUrlObj = newUrl;
              }

              if (targetUrlObj.href !== clientUrl.href) {
                if ('navigate' in client) {
                  return client.navigate(targetUrlObj.href).then(() => client.focus());
                }
                client.postMessage({
                  action: 'navigate',
                  url: targetUrlObj.href
                });
              }

              return client.focus();
            }
          } catch (e) {
            logMessage('Error processing client URL', e);
          }
        }

        // If we didn't find an existing client, open a new one
        logMessage('Opening new window');
        return clients.openWindow(targetUrl);
      }).catch(function(error) {
        logMessage('Error handling notification click', error);
      })
    );
  }
});

// Import Firebase scripts using the new modular SDK
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging-compat.js');
importScripts('firebase-config.js');
importScripts('../db-helper.js');

// Initialize Firebase using the compat version for service workers
firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

var sendMessageToClient = {
  fn: function(data) { /* Do nothing */ }
}

// Helper function to check if object is empty or null
function isEmpty(obj) {
  return obj == null || obj == undefined;
}

// Enhanced logging specifically debugging
function logMessage(message, data) {
  const logMessage = '[firebase-messaging-sw.js] ' + message;
  console.log(logMessage, data || '');
}

// Critical: Handle background messages - This is the main FCM handler
messaging.onBackgroundMessage(function(payload) {
  logMessage('FCM Background message received', payload);

  // Send message to client for internal handling
  sendMessageToClient.fn({ action: "notification", payload });

  // Handle badge from payload using IndexedDB
  if (payload.data && payload.data.badge) {
    var badgeValue = payload.data.badge;

    if (badgeValue === 'inc') {
      return incrementBadgeCount()
        .then(function() {
          return getBadgeCount();
        })
        .catch(function(err) {
          logMessage('Failed to increment badge', err);
        });
    } else {
      var badgeNum = parseInt(badgeValue, 10);
      if (!isNaN(badgeNum)) {
        return setBadgeCount(badgeNum)
          .catch(function(err) {
            logMessage('Failed to set badge', err);
          });
      }
    }
  }
});

// Enhanced message handling specifically
self.addEventListener('message', function(event) {
  logMessage('Received message', event);
  
  var respond = function(data) {
    try {
      if (event.ports && event.ports.length > 0) {
        event.ports[0].postMessage(data);
      } else if (event.source) {
        event.source.postMessage(data);
      } else {
        logMessage("No way to respond to message!");
      }
    } catch (e) {
      logMessage("Failed to respond", e);
    }
  };

  if (event.data && event.data.action == "subscribe_on_messages" && typeof event.data.delay !== "undefined" && event.data.delay !== null) {
    var delay = event.data.delay;
    if (delay < 10) delay = 10;
    
    if (event.ports && event.ports.length > 0) {
      var port = event.ports[0];
      sendMessageToClient.fn = function(data) {
        // Post message with delay - important
        setTimeout(function() {
          try {
            logMessage('Posting message', data);
            port.postMessage(data);
          } catch (e) {
            logMessage('Failed to send message via port', e);
          }
        }, delay);
      };

      respond({ action: "subscribe_on_messages", status: "OK" });
    } else if (event.source && event.source.id) {
        var clientId = event.source ? event.source.id : null;
      sendMessageToClient.fn = function(data) {
        // Post message with delay - important
        setTimeout(function() {
          clients.get(clientId).then(function(client) {
            if (!isEmpty(client)) {
              try {
                logMessage('Posting message', data);
                client.postMessage(data);
              } catch (e) {
                logMessage('Failed to send message to client', e);
              }
            }
          }).catch(function(e) {
            logMessage('Failed to get client', e);
          });
        }, delay);
      };

      respond({ action: "subscribe_on_messages", status: "OK" });
    } else {
      sendMessageToClient.fn = function(data) { /* Do nothing */ };
      respond({ action: "subscribe_on_messages", status: "Failed", error: "No client connection available" });
    }
  } else if (event.data && event.data.action == "unsubscribe_from_messages") {
    sendMessageToClient.fn = function(data) { /* Do nothing */ };
    respond({ action: "unsubscribe_from_messages", status: "OK" });
  } else {
    respond({ status: "Failed", error: "Unknown operation: " + (event.data ? event.data.action : 'undefined') });
  }
});

self.addEventListener('notificationclose', function(event) {
  logMessage('Notification closed', event.notification.tag);
});
