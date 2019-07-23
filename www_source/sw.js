var CACHE_NAME = 'flow-cache';
var CACHE_NAME_DYNAMIC = 'flow-dynamic-cache';
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

// Here we store filters, which contains rules `Which` and `How` to cache dynamic requests
var requestsCacheFilter = [];

function initializeCacheStorage() {
  return caches.open(CACHE_NAME)
    .then(function(cache) {
      console.log('Opened cache');
      return Promise.resolve();
    });
}

// Adding base url if the given url is relative (starts with ./)
// As base url we use location of serverworker file itself (www folder of the app)
var urlAddBaseLocation = function(url) {
  var baseUrl = self.location.href;
  var i = baseUrl.lastIndexOf('/');
  if (i != -1) baseUrl = baseUrl.substr(0, i + 1);

  if (url.startsWith("./")) {
    url = baseUrl + url.substr(1, url.length - 1);
  }

  return url.replace(/(^|[^:])[/]{2,}/, '$1/', url);
}

var extractUrlParameters = function(url) {
  var urlSplitted = url.split("?");
  if (urlSplitted.length > 1) {
    return { baseUrl : urlSplitted[0], parameters : urlSplitted.slice(1).join("?").split("&") };
  } else {
    return { baseUrl : url, parameters : [] };
  }
}

// Removing ignoreParameters from the request url
var filterUrlParameters = function(url, ignoreParameters) {
  var urlParameters = extractUrlParameters(url);
  if (urlParameters.length == 0) {
    return url;
  } else {
    return urlParameters.baseUrl + "?" + urlParameters.parameters.filter(function(p) {
      var index = p.indexOf('=');
      if (index !== -1) p = p.substr(0, index).toLowerCase();
      return !ignoreParameters.includes(p);
    }).join("&");
  }
};

var sendMessageToClient = function(event, data) {
  if (!event.clientId) return;

  // Post message with delay
  // Otherwise makes problem for caching
  setTimeout(function() {
    clients.get(event.clientId).then(function(client) {
      client.postMessage(data);
      //console.log(data);
    });
  }, 5);
};

self.addEventListener('install', function(event) {
  // Perform install steps
  event.waitUntil(
    initializeCacheStorage()
  );
});

self.addEventListener('fetch', function(event) {
  // Creation Promise, which `converts` POST request into GET request
  var getFixedRequestUrl = function(request) {
    var urlSplitted = extractUrlParameters(urlAddBaseLocation(request.url));
    var requestUrl = urlSplitted.baseUrl;
    var glueSymb = "?";

    if (request.method == "POST") {
      if (urlSplitted.parameters.length != 0) {
        requestUrl += glueSymb + urlSplitted.parameters.join("&");
        glueSymb = "&";
      }

      return request.clone().text().then(function(reqParamsText) {
        var formDataText = undefined;
        // We add form data (POST parameters) into GET request url string
        if (reqParamsText !== null && reqParamsText !== undefined && reqParamsText != "") {
          formDataText = reqParamsText;
          requestUrl += glueSymb + reqParamsText;
        }

        return { urlNewFull : requestUrl, formDataText : formDataText };
      }).catch(function() {
        return { urlNewFull : requestUrl, formDataText : undefined };
      });
    } else {
      return Promise.resolve({ urlNewFull : requestUrl, formDataText : undefined });
    }
  }

  // Searching the filter to which the request is match
  var findCacheFilter = function(fixedUrl, method) {
    return requestsCacheFilter.find(function(el) {
      var resUrl = true;
      var resMethod = true;
      var resParameters = true;

      if (el.cacheIfUrlMatch != "") {
        el.cacheIfUrlMatch = urlAddBaseLocation(el.cacheIfUrlMatch);
        resUrl = fixedUrl.startsWith(el.cacheIfUrlMatch);
      }
      if (el.method != "") resMethod = (method == el.method);
      if (el.cacheIfParametersMatch.length > 0) {
        var urlParams = extractUrlParameters(fixedUrl).parameters.map(function(v) { return v.toLowerCase(); });
        
        resParameters = el.cacheIfParametersMatch.every(function(pair) {
          return urlParams.includes(pair[0] + "=" + pair[1]);
        });
      }

      return resUrl && resMethod && resParameters;
    });
  }

  // SW does not allow to cache POST requests, so we create GET from the POST
  var prepareRequestToCache = function(requestData) {
   if (requestData.isCustomCaching) {
      var requestCloned = requestData.cloneRequest();
      return (new Request(requestData.urlNewToCache, {
        method: "GET",
        headers: requestCloned.headers,
        body: requestCloned.body,
        mode: 'same-origin',
        credentials: requestCloned.credentials,
        cache: requestCloned.cache,
        redirect: requestCloned.redirect,
        referrer: requestCloned.referrer,
        integrity: requestCloned.integrity
      }));
    } else {
      return requestData.cloneRequest();
    }
  }

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

  var getResourceFromCache = function(requestData, ignoreSearch) {
    return caches.match(prepareRequestToCache(requestData), { ignoreSearch: (ignoreSearch && !requestData.isCustomCaching) })
      .then(function(response) {
        if (!response) {
          return Promise.reject();
        }

        sendMessageToClient(event, {
          msg: "Responded with cache:",
          url: requestData.originalRequest.url,
          urlCached: requestData.urlNewToCache
        });
        
        return response;
      });
  }

  var getCachedResource = function(requestData) {
    // Ignore search string if that is request to stamp.php for application.js file
    return isStampForApplicationJsRequest()
      .then(function() {
        return getResourceFromCache(requestData, true);
      }).catch(function() {
        return getResourceFromCache(requestData, false); 
      });
  };
  
  var fetchResource = function(requestData) {
    return fetch(requestData.cloneRequest()).then(function(response) {
      if (response.status == 200 && response.type == "basic") {
        // Cache the request if it's match any customized filter
        if (requestData.isCustomCaching) {
          caches.open(CACHE_NAME_DYNAMIC).then(function(cache) {
            cache.put(prepareRequestToCache(requestData), response.clone());

            sendMessageToClient(event, {
              msg: "Cached resource:",
              url: requestData.originalRequest.url,
              urlCached: requestData.urlNewToCache
            });
          });
        // Automatically cache uncached static resources
        } else if (CacheMode.CacheStaticContent) {
          var url = new URL(requestData.originalRequest.url);

          Promise.all(dynamicResourcesExtensions.map(function(resourceName) {
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
              cache.put(requestData.cloneRequest(), response.clone());

              sendMessageToClient(event, {
                msg: "Cached resource:",
                url: requestData.originalRequest.url,
                urlCached: requestData.originalRequest.url
              });
            });
          }).catch(function() { return null; })
        }
      }

      return response.clone();
    });
  }

  function buildResponse(requestData) {
    if (CacheMode.PreferCachedResources) {
      return getCachedResource(requestData).catch(function() {
        return fetchResource(requestData);
      });
    } else {
      return fetchResource(requestData).catch(function() {
        return getCachedResource(requestData);
      });
    }
  };

  function buildRangeResponse(requestData) {
    return caches
      .open(rangeResourceCache)
      .then(function(cache) {
        return cache.match(requestData.fixedUrlToCache);
      })
      .then(function(res) {
        if (!res) {
          return fetch(requestData.originalRequest)
            .then(function(res) {
              if (res.status == 200) {
                var resCloned = res.clone();
                return caches
                  .open(rangeResourceCache)
                  .then(function(cache) {
                    return cache.put(prepareRequestToCache(requestData), resCloned);
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
              var bytes = /^bytes\=(\d+)\-(\d+)?$/g.exec(requestData.originalRequest.headers.get('range'));
              if (bytes) {
                var start = Number(bytes[1]);
                var end = Number(bytes[2]) || arrayBuffer.byteLength - 1;

                return new Response(arrayBuffer.slice(start, end + 1), {
                  status: 206,
                  statusText: 'Partial Content',
                  headers: [
                    ['Content-Type', response.headers.get('Content-Type')],
                    ['Content-Range', 'bytes ' + start + '-' + end + '/' + arrayBuffer.byteLength]
                  ]
                });
              } else {
                return new Response(null, {
                  status: 416,
                  statusText: 'Range Not Satisfiable',
                  headers: [['Content-Range', '*/' + arrayBuffer.byteLength]]
                });
              }
            });
        } else {
          return response;
        }
      });
  }

  function makeResponse(request) {
    return getFixedRequestUrl(request)
    .then(function(urlAndBody) {
      var cacheFilter = findCacheFilter(urlAndBody.urlNewFull, request.method);
      var fixedUrlToCache = urlAndBody.urlNewFull;
      if (cacheFilter !== undefined) {
        fixedUrlToCache = filterUrlParameters(urlAndBody.urlNewFull, cacheFilter.ignoreParameterKeysOnCache);
      }

      return {
        urlNewFull : urlAndBody.urlNewFull,
        urlNewToCache : fixedUrlToCache,
        isCustomCaching : (cacheFilter !== undefined),
        customCacheFilter : cacheFilter,
        formDataText : urlAndBody.formDataText,
        originalRequest : request,
        cloneRequest : function() { return request.clone(); }
      };
    })
    .then(function(requestData) {
      if (requestData.originalRequest.headers.get('range')) {
        return buildRangeResponse(requestData);
      } else {
        return buildResponse(requestData);
      }
    });
  }

  event.respondWith(makeResponse(event.request));
});

var cleanServiceWorkerCache = function() {
  caches.delete(rangeResourceCache);
  console.log("cache cleared", rangeResourceCache);

  return caches.keys().then(function(keyList) {
    return Promise.all(keyList.map(function(key) {
      if (CACHE_NAME != key) {
        console.log("cache cleared", key);
        return caches.delete(key);
      }
    }));
  });
};

self.addEventListener('activate', function(event) {
  // this cache is only for session
  cleanServiceWorkerCache();
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

  var fetchAndCacheByUrl = function(url, ignoreParameters) {
    var request = new Request(url);
    return fetch(request).then(function(response) {
      // Automatically cache uncached resources
      if (response.status == 200 && response.type == "basic") {
        var requestToCache = new Request(filterUrlParameters(url, ignoreParameters));
        caches.open(CACHE_NAME_DYNAMIC).then(function(cache) {
          cache.put(requestToCache, response.clone());

          sendMessageToClient(event, {
            msg: "Cached resource:",
            url: url,
            urlCached: requestToCache.url
          });
        });
      }

      return true;
    }).catch(function() {
      return false;
    });
  };

  var checkUrlsInCache = function(urls) {
    return Promise.all(urls.map(function(url) {
      return caches.match(urlAddBaseLocation(url), { ignoreSearch: false })
      .then(function(response) {
        if (response) {
          return url;
        } else return "";
      }).catch(function() { return ""; })
    })).then(function(urls2) { return urls2.filter(function(url) { return url != ""; }); })
    .then(function(urls2) { return { "urls" : urls2, status: "OK" }; })
    .catch(function() { return { "urls" : [], status: "Failed" }; });
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
  } else if (event.data.action == "clean_cache_storage") {
    respondWithStatus(cleanServiceWorkerCache());
  } else if (event.data.action == "requests_cache_filter") {
    if (!requestsCacheFilter.includes(event.data.data))
      requestsCacheFilter.push(event.data.data);
    respond({status: "OK"});
  } else if (event.data.action == "load_and_cache_urls") {
    respondWithStatus(
      Promise.all(event.data.data.urls.map(function(url) {
        return fetchAndCacheByUrl(url, event.data.data.ignoreParameterKeysOnCache);
      }))
    );
  } else if (event.data.action == "check_urls_in_cache") {
    checkUrlsInCache(event.data.data.urls).then(respond);
  }
});
