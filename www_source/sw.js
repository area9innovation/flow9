var CACHE_NAME = 'flow-cache';
var rangeResourceCache = 'flow-range-cache';

// We gonna cache all resources except resources extensions below
var dynamicResourcesExtensions = [
  ".php",
  ".serverbc"
];

var CacheMode = {
  // Respond with cached resources even when online
  PreferCachedResources: false,
  // Cache all static files requests
  CacheStaticContent: true
}

function initializeCacheStorage() {
  return caches.open(CACHE_NAME)
    .then(function(cache) {
      console.log('Opened cache');
      return Promise.resolve();
    });
}

self.addEventListener('install', function(event) {
  // Perform install steps
  event.waitUntil(
    initializeCacheStorage()
  );
});

self.addEventListener('fetch', function(event) {
  var sendMessageToClient = function(data) {
    if (!event.clientId) return;

    // Post message with delay
    // Otherwise makes problem for caching
    setTimeout(function() {
      clients.get(event.clientId).then(function(client) {
        client.postMessage(data);
      });
    }, 5);
  };

  var isStampForApplicationJsRequest = function() {
    if (!event.clientId) return Promise.reject();

    var url = new URL(event.request.url);

    return clients.get(event.clientId).then(function(client) {
      var clientUrl = new URL(client.url);

      if (url.pathname.endsWith("/php/stamp.php") && url.searchParams.get("file") == (clientUrl.searchParams.get("name") + ".js"))
        return Promise.resolve();
      else
        return Promise.reject();
    });
  }

  var getResourceFromCache = function(ignoreSearch) {
    return caches.match(event.request, { ignoreSearch: ignoreSearch })
      .then(function(response) {
        if (!response) return Promise.reject();

        sendMessageToClient({
          msg: "Responded with cache:",
          url: event.request.url
        });
        
        return response;
      });
  }

  var getCachedResource = function() {
    // Ignore search string if that is request to stamp.php for application.js file
    return isStampForApplicationJsRequest()
      .then(function() {
        return getResourceFromCache(true);
      }).catch(function() { 
        return getResourceFromCache(false); 
      });
  };

  var fetchResource = function() {
    return fetch(event.request).then(function(response) {
      // Automatically cache uncached resources
      if (CacheMode.CacheStaticContent && response.status == 200 && response.type == "basic") {
        var url = new URL(event.request.url);

        // Let's cache all static resources here
        return Promise.all(dynamicResourcesExtensions.map(function(resourceName) {
          if (!url.pathname.endsWith(resourceName)) {
            return Promise.resolve();
          } else {
            // Cache /php/stamp.php?file=<APP_NAME>.js for offline loading
            return isStampForApplicationJsRequest().then(function() {
              return caches.open(CACHE_NAME).then(function(cache) {
                // Clean all previous stamp.php caches (sensitive to timestamp)
                return cache.delete(self.registration.scope + "php/stamp.php", { ignoreSearch: true }).then(function() {
                  // Clean all previous application.js caches (sensitive to timestamp)
                  return cache.delete(self.registration.scope + url.searchParams.get("file"), { ignoreSearch: true });
                });
              });
            });
          }
        })).then(function() {
          caches.open(CACHE_NAME).then(function(cache) {
            cache.put(event.request, response);

            sendMessageToClient({
              msg: "Cached resource:",
              url: event.request.url
            });
          });

          return response.clone();
        }).catch(function() {
          return response;
        });
      } else {
        return response;
      }
    });
  }

  function buildResponse() {
    if (CacheMode.PreferCachedResources) {
      return getCachedResource().catch(function() {
        return fetchResource();
      });
    } else {
      return fetchResource().catch(function() {
        return getCachedResource();
      })
    }
  };

  function buildRangeResponse() {
    return caches
      .open(rangeResourceCache)
      .then(function(cache) {
        return cache.match(event.request.url);
      })
      .then(function(res) {
        if (!res) {
          return fetch(event.request)
            .then(function(res) {
              if (res.status == 200) {
                var clonedRes = res.clone();
                return caches
                  .open(rangeResourceCache)
                  .then(function(cache) {
                    return cache.put(event.request, clonedRes);
                  })
                  .then(function() {
                    return res;
                  });
              } else {
                return res;
              }
            });
        }
        return res;
      })
      .then(function(response) {
        if (response.status == 200) {
          return response
            .arrayBuffer()
            .then(function(arrayBuffer) {
              var bytes = /^bytes\=(\d+)\-(\d+)?$/g.exec(event.request.headers.get('range'));
              if (bytes) {
                var start = Number(bytes[1]);
                var end = Number(bytes[2]) || arrayBuffer.byteLength - 1;

                return new Response(arrayBuffer.slice(start, end + 1), {
                  status: 206,
                  statusText: 'Partial Content',
                  headers: [
                  ['Content-Type', response.headers.get('Content-Type')],
                  ['Content-Range', `bytes ${start}-${end}/${arrayBuffer.byteLength}`]
                  ]
                });
              } else {
                return new Response(null, {
                  status: 416,
                  statusText: 'Range Not Satisfiable',
                  headers: [['Content-Range', `*/${arrayBuffer.byteLength}`]]
                });
              }
            });
        } else {
          return response;
        }
      });
  }

  if (event.request.headers.get('range')) {
    event.respondWith(buildRangeResponse());
  } else {
    event.respondWith(buildResponse());
  }
});

self.addEventListener('activate', function(event) {
  // this cache is only for session
  caches.delete(rangeResourceCache);
  console.log("cache cleared", rangeResourceCache);

  caches.keys().then(function(keyList) {
    return Promise.all(keyList.map(function(key) {
      if (CACHE_NAME != key) {
        return caches.delete(key);
      }
    }));
  });
});

// Currently not used
self.addEventListener('message', function(event) {
  var respond = function(data) {
    if (event.ports.length > 0) {
      event.ports[0].postMessage(data);
    } else {
      console.error("Failed to respond!");
    }
  };

  var respondWithStatus = function(promise) {
    promise.then(function() {
      respond({
        status: "OK"
      });
    }).catch(function() {
      respond({
        status: "Failed"
      });
    });
  };

  if (event.data.action == "get_cache_version") {
    respond({
      cache_version: SW_CACHE_VERSION
    });
  } else if (event.data.action.indexOf("_cache_resources") > 0) {
    respondWithStatus(caches.open(CACHE_NAME).then(function(cache) {
      return Promise.all(event.data.urls.map(function(url) {
        if (event.data.action == "add_cache_resources") {
          return cache.add(url);
        } else if (event.data.action == "remove_cache_resources") {
          return cache.delete(url);
        }
      }));
    }));
  } else if (event.data.action == "get_cache_storage_names") {
    caches.keys().then(function(keyList) {
      respond({
        names: keyList
      });
    });
  } else if (event.data.action == "remove_cache_storage") {
    respondWithStatus(caches.delete(event.data.action.name));
  }
});
