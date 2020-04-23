var SERVICE_WORKER_VERSION = 11;
var CACHE_NAME = 'flow-cache';
var CACHE_NAME_DYNAMIC = 'flow-dynamic-cache';
var rangeResourceCache = 'flow-range-cache';

var SHARED_DATA_ENDPOINT = 'share/pwa/data.php';

// We gonna cache all resources except resources extensions below
var dynamicResourcesExtensions = [
  ".php",
  ".serverbc",
  ".html",
  ".js"
];

var CacheMode = {
  // Respond with cached resources even when online
  PreferCachedResources: false,
  // Cache all static files requests
  CacheStaticResources: true,
  // In offline use only cached requests
  UseOnlyCacheInOffline: false
}

// Here we store filters, which contains rules `Which` and `How` to cache dynamic requests
// The structure of `requestsSkipOnFetch` is
//  [{
//    url /*string*/,
//    methods : [{
//      method /*string*/,
//      headers : [{ key /*string*/, value /*string*/ }]
//    }]
//  }]
var requestsSkipOnFetch = [];

// Here we store filters, which contains rules `Which` and `How` to cache dynamic requests
// The structure of `requestsCacheFilter` is
//  [{
//    url /*string*/,
//    methods : [{
//      method /*string*/,
//      parameters : [{
//        keyValues : [{ key /*string*/, value /*string*/ }],
//        ignoreKeys : [ /*string*/ ]
//      }]
//    }]
//  }]
var requestsCacheFilter = [];

var isOnline = true;

function checkOnlineStatus() {
  if (navigator.onLine === false) {
    if (isOnline) console.info("Application switched to OFFLINE mode.");
    isOnline = false;
  } else {
    if (!isOnline) console.info("Application returned back to ONLINE mode.");
    isOnline = true;
  }
}

function initializeCacheStorage() {
  return caches.open(CACHE_NAME)
    .then(function(cache) {
      console.log('Opened cache');
      return Promise.resolve();
    });
}

function isEmpty(v) {
  return (
    (typeof v === "undefined") ||
    (v === null) ||
    ((typeof v === "string") && (v == "")) ||
    (Array.isArray(v) && (v.length == 0)) ||
    ((typeof v === "object") && (Object.keys(v).length == 0))
  );
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
    // let's fix the url parameters (if url has multiply `?` - change all `?` -> `&`)
    //  and then split it by `&`
    var parameters2 = urlSplitted.slice(1).join("&").split("&");
    // Then, if the url has only one value after the `?`, without `=`, let's add a default key-value like `special_case_key=special_case_value`
    if (parameters2.length == 1 && !parameters2[0].includes("=")) {
      parameters2.unshift("special_case_key=special_case_value");
    }
    return { baseUrl: urlSplitted[0], parameters: parameters2 };
  } else {
    return { baseUrl: url, parameters: [] };
  }
}

// Removing ignoreParameters from the request url
var filterUrlParameters = function(url, ignoreParameters) {
  var urlParameters = extractUrlParameters(url);
  if (urlParameters.parameters.length == 0) {
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
  var isMatchSkipFilter = function(request) {
    var fixedUrl = urlAddBaseLocation(request.url).toLowerCase();
    var method = request.method.toLowerCase();

    return !isEmpty(requestsSkipOnFetch.find(function(elUrl) {
      // Does url matched
      if (isEmpty(elUrl.url) || fixedUrl.startsWith(elUrl.url)) {
        return !isEmpty(elUrl.methods.find(function(elMethod) {
          // Does method matched
          if (isEmpty(elMethod.method) || elMethod.method == method) {
            return !isEmpty(elMethod.headers.find(function(elHeader) {
              // Does any header matched
              return (
                isEmpty(elHeader.key) ||
                (request.headers.has(elHeader.key) && request.headers.get(elHeader.key) == elHeader.value)
              );
            }));
          } else {
            return false;
          }
        }));
      } else {
        return false;
      }
    }));
  }

  // Here we trying to recognize file uploading request to skip it in cache operations then
  var isFileUploadingRequestFn = function(request) {
    if (request.method == "POST" && request.headers.has("Content-Type")) {
      var ctValue = request.headers.get("Content-Type").toLowerCase();
      var clValue = request.headers.get("Content-Length");
      return (ctValue.includes("multipart/form-data") && ctValue.includes("boundary=")) || clValue > 10000;
    } else {
      return false;
    }
  }

  // Is it a static request?
  var isStaticCachingFn = function(url) {
    var requestUrl = (new URL(request.url)).pathname,
      parts,
      ext = (parts = requestUrl.split("/").pop().split(".")).length > 1 ? parts.pop() : "";

    return (CacheMode.CacheStaticResources && !isEmpty(ext) && !dynamicResourcesExtensions.includes("." + ext));
  }

  var isAppMainRequestFn = function(url) {
    var requestUrl = (new URL(request.url)).pathname,
      parts,
      ext = (parts = requestUrl.split("/").pop().split(".")).length > 1 ? parts.pop() : "";
    var name = (parts.length > 0 ? parts.pop() : "");

    return (!isEmpty(ext) && !isEmpty(name) && (
      "stamp.php" == name + "." + ext ||
      "flowjs.html" == name + "." + ext));
  }

  // Creation a requestData for GET requests
  var createRequestDataGET = function(request) {
    var fixedUrl = urlAddBaseLocation(request.url);
    var urlSplitted = extractUrlParameters(fixedUrl);
    var requestUrl = urlSplitted.baseUrl;
    var glueSymb = "?";

    if (request.method == "GET") {
      var cacheFilter = findCacheFilter(fixedUrl, request.method, false);
      var fixedUrlToCache = fixedUrl;
      if (!isEmpty(cacheFilter)) {
        fixedUrlToCache = filterUrlParameters(fixedUrl, cacheFilter.ignoreKeys);
      }

      return requestData = {
        urlNewFull: fixedUrl,
        urlNewToCache: fixedUrlToCache,
        isCustomCaching: (!isEmpty(cacheFilter)),
        isStaticCaching: isStaticCachingFn(request.url),
        isAppMainRequest: isAppMainRequestFn(request.url),
        customCacheFilter: cacheFilter,
        originalRequest: request,
        isFileUploading: isFileUploadingRequestFn(request),
        cloneRequest: function() { return request.clone(); }
      };
    } else {
      return null;
    }
  }

  // Creation Promise, which `converts` POST request into GET request
  var getFixedRequestUrl = function(request) {
    var fixedUrl = urlAddBaseLocation(request.url);
    var urlSplitted = extractUrlParameters(fixedUrl);
    var requestUrl = urlSplitted.baseUrl;
    var glueSymb = "?";
    var isFileUploadingRequest = isFileUploadingRequestFn(request);

    if (request.method == "POST") {
      if (!isFileUploadingRequest) {
        if (urlSplitted.parameters.length != 0) {
          requestUrl += glueSymb + urlSplitted.parameters.join("&");
          glueSymb = "&";
        }

        return request.clone().text().then(function(reqParamsText) {
          // We add form data (POST parameters) into GET request url string
          if (!isEmpty(reqParamsText)) {
            requestUrl += glueSymb + reqParamsText;
          }

          return { urlNewFull: requestUrl, isFileUploading: isFileUploadingRequest };
        }).catch(function() {
          return { urlNewFull: fixedUrl, isFileUploading: isFileUploadingRequest };
        });
      } else {
        return Promise.resolve({ urlNewFull: fixedUrl, isFileUploading: isFileUploadingRequest });
      }
    } else {
      return Promise.resolve({ urlNewFull: fixedUrl, isFileUploading: isFileUploadingRequest });
    }
  }

  // Searching the filter to which the request is match
  var findCacheFilter = function(fixedUrl, method, checkWithoutParameters) {
    fixedUrl = fixedUrl.toLowerCase();
    method = method.toLowerCase();
    var urlParams = extractUrlParameters(fixedUrl).parameters;

    var cFilters = requestsCacheFilter.map(function(elUrl) {
        // Does url matched
        if (elUrl.url == "" || fixedUrl.startsWith(elUrl.url)) {
          methods = elUrl.methods.map(function(elMethod) {
              // Does method matched
              if (elMethod.method == "" || elMethod.method == method) {
                if (elMethod.parameters.length == 0 || checkWithoutParameters) {
                  return [{ method: elMethod.method, parameters: [], ignoreKeys: [] }];
                } else {
                  var checkRequestParameters = function(parameter) {
                    return parameter.keyValues.every(function(keyValue) {
                      var pair = (keyValue.key + "=" + keyValue.value);
                      return (urlParams.findIndex(function(up) {
                        return (pair == up);
                      }) != -1);
                    });
                  };

                  return elMethod.parameters.filter(function(parameter) {
                      return parameter.keyValues.length == 0 || checkRequestParameters(parameter);
                    })
                    .map(function(parameter) {
                      return { method: elMethod.method, parameters: parameter.keyValues, ignoreKeys: parameter.ignoreKeys };
                    });
                }
              }
            })
            .filter(function(elMethod) { return elMethod != undefined; })
            .flat();

          if (methods.length > 0) {
            return methods.map(function(elMethod) {
              return { url: elUrl.url, method: elMethod.method, parameters: elMethod.parameters, ignoreKeys: elMethod.ignoreKeys };
            });
          } else {
            return undefined;
          }
        } else {
          return undefined;
        }
      })
      .filter(function(el1) { return el1 != undefined; })
      .flat();

    if (cFilters.length > 0) return cFilters[0];
    else return undefined;
  }

  // Searching the filter to which the request is match (without parameters)
  var findCacheFilterSimple = function(request) {
    var fixedUrl = urlAddBaseLocation(request.url);
    return findCacheFilter(fixedUrl, request.method, true);
  }

  // SW does not allow to cache POST requests, so we create GET from the POST
  var prepareRequestToCache = function(requestData) {
    if (requestData.isCustomCaching || (requestData.urlNewToCache != requestData.originalRequest.url)) {
      var requestCloned = requestData.cloneRequest();
      return (new Request(requestData.urlNewToCache, {
        method: "GET",
        headers: requestCloned.headers,
        mode: 'same-origin',
        credentials: requestCloned.credentials,
        cache: requestCloned.cache,
        redirect: requestCloned.redirect,
        referrer: requestCloned.referrer,
        integrity: requestCloned.integrity
      }));
    } else if (requestData.isAppMainRequest) {
      var requestCloned = requestData.cloneRequest();
      return (new Request(extractUrlParameters(requestData.urlNewToCache)['baseUrl'], {
        method: "GET",
        headers: requestCloned.headers,
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

  // SW does not allow to cache POST requests, so we create GET from the POST
  var createIfNoneMatchRequest = function(requestData, etag) {
    var requestCloned = requestData.cloneRequest();
    var headers = new Headers();
    requestCloned.headers.forEach(function(val, key) {
      headers.set(key, val);
    });
    headers.set('If-None-Match', etag);

    if (requestCloned.method == "POST") {
      return requestCloned.blob().then(function(reqBlob) {
        return (new Request(requestCloned.url, {
          method: requestCloned.method,
          headers: headers,
          body: reqBlob,
          mode: 'same-origin',
          credentials: requestCloned.credentials,
          cache: requestCloned.cache,
          redirect: requestCloned.redirect,
          referrer: requestCloned.referrer,
          integrity: requestCloned.integrity
        }));
      }).catch(function() {
        return (new Request(requestCloned.url, {
          method: requestCloned.method,
          headers: headers,
          mode: 'same-origin',
          credentials: requestCloned.credentials,
          cache: requestCloned.cache,
          redirect: requestCloned.redirect,
          referrer: requestCloned.referrer,
          integrity: requestCloned.integrity
        }));
      });
    } else {
      return Promise.resolve(
        (new Request(requestCloned.url, {
          method: requestCloned.method,
          headers: headers,
          mode: 'same-origin',
          credentials: requestCloned.credentials,
          cache: requestCloned.cache,
          redirect: requestCloned.redirect,
          referrer: requestCloned.referrer,
          integrity: requestCloned.integrity
        }))
      );
    }
  }

  // Clean all previous caches for sensitive to timestamp requests
  var cleanTimestampSensitiveRequests = function(originalUrl) {
    var url = new URL(originalUrl);
    // Cache /php/stamp.php?file=<APP_NAME>.js for offline loading
    return isStampForApplicationJsRequest().then(function() {
      return caches.open(CACHE_NAME).then(function(cache) {
        // Clean all previous stamp.php caches (sensitive to timestamp)
        return cache.delete(self.registration.scope + "php/stamp.php", { ignoreSearch: true }).then(function() {
          // Clean all previous application.js caches (sensitive to timestamp)
          return cache.delete(self.registration.scope + url.searchParams.get("file"), { ignoreSearch: true });
        });
      });
    }).catch(function() { return null; });
  }

  var isStampForApplicationJsRequestInner = function(clientUrl) {
    if (!event.clientId) return false;
    var url = new URL(clientUrl);
    return (url.pathname.endsWith("/php/stamp.php") && !isEmpty(url.searchParams.get("file")));
  }

  var isStampForApplicationJsRequest = function() {
    if (!event.clientId) return Promise.reject();
    var url = new URL(event.request.url);

    return clients.get(event.clientId).then(function(client) {
      var clientUrl = new URL(client.url);

      if (isStampForApplicationJsRequestInner(client.url))
        return Promise.resolve();
      else
        return Promise.reject();
    });
  }

  // Should we skip this request?
  var checkRequestForSkipping = function(request, requestData) {
    // Should be skipped by special filter?
    return isMatchSkipFilter(request) ||
      // Do not process files uploading requests
      isFileUploadingRequestFn(request) ||
      // We disable Range requests for a while
      !isEmpty(request.headers.get('range')) ||
      (
        // Skip if is not a web resource
        !isStaticCachingFn(request.url) &&
        // Skip if is not the main app loader
        !isAppMainRequestFn(request.url) &&
        // Skip GET request which do not match any custom filter
        (isEmpty(requestData) || !requestData.isCustomCaching)
      ) &&
      // Skip POST request which url is not match any filter (without parameters)
      isEmpty(findCacheFilterSimple(request)) &&
      // Skip if it is not app loader
      !isStampForApplicationJsRequestInner(request.url);
  }

  function getResourceFromCache(requestData, ignoreSearch) {
    if (requestData.isFileUploading) {
      // We don't cache file uploading request, so we skip the step of request searching in cache
      return Promise.reject();
    } else {
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

          return response.clone();
        });
    }
  }

  function getCachedResource(requestData) {
    // Ignore search string if that is request to stamp.php for application.js file
    return isStampForApplicationJsRequest()
      .then(function() {
        return getResourceFromCache(requestData, true);
      }).catch(function() {
        return getResourceFromCache(requestData, false);
      });
  }

  function fetchResource(requestData, checkIfNotModified) {

    var doCacheFn = function(response) {
      var fixedRequest = prepareRequestToCache(requestData);
      var usedCacheName = CACHE_NAME;
      if (requestData.isCustomCaching) usedCacheName = CACHE_NAME_DYNAMIC;

      // Cache the request if it's match any customized filter or
      // automatically cache uncached static resources
      if (requestData.isCustomCaching || requestData.isStaticCaching || requestData.isAppMainRequest) {
        caches.open(usedCacheName).then(function(cache) {
          cache.put(fixedRequest, response.clone());

          sendMessageToClient(event, {
            msg: "Cached resource:",
            url: requestData.originalRequest.url,
            urlCached: fixedRequest.url
          });
        });
      }
    };

    var doFetchFn = function() {
      return fetch(requestData.cloneRequest()).then(function(response) {
        if (response.status == 200 && response.type == "basic") {
          if (isStampForApplicationJsRequestInner(requestData.originalRequest.url))
            cleanTimestampSensitiveRequests(requestData.originalRequest.url);
          doCacheFn(response);
        }

        return response.clone();
      });
    };

    if (requestData.isFileUploading) {
      // We can't to clone file uploading request, so we processing it as is, without caching
      return fetch(requestData.cloneRequest())
        .then(function(response) { return response.clone(); });
    } else {
      if (checkIfNotModified) {
        return getCachedResource(requestData)
          .then(function(responseCache) {
            var etag = responseCache.headers.get('etag');
            if (isEmpty(etag)) {
              return doFetchFn();
            } else {
              return createIfNoneMatchRequest(requestData, etag).then(function(cRequest) {
                  return fetch(cRequest).then(function(response) {
                    if (response.status == 200 && response.type == "basic") {
                      doCacheFn(response);
                      return response.clone();
                    } else if (response.status == 304 && response.type == "basic") {
                      return responseCache.clone();
                    } else {
                      return response.clone();
                    }
                  });
                })
                .catch(doFetchFn);
            }
          })
          .catch(doFetchFn);
      } else {
        return doFetchFn();
      }
    }
  }

  function buildResponse(requestData) {
    if (CacheMode.UseOnlyCacheInOffline && !isOnline) {
      return getCachedResource(requestData);
    } else if (CacheMode.PreferCachedResources) {
      return getCachedResource(requestData).catch(function() {
        return fetchResource(requestData, false);
      });
    } else {
      return fetchResource(requestData, true).catch(function() {
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
                  headers: [
                    ['Content-Range', '*/' + arrayBuffer.byteLength]
                  ]
                });
              }
            });
        } else {
          return response;
        }
      });
  }

  function makeResponse(request, requestData) {
    var fn = function() {
      if (requestData != null) {
        return Promise.resolve(requestData);
      } else {
        return getFixedRequestUrl(request)
          .then(function(urlAndBody) {
            var cacheFilter = findCacheFilter(urlAndBody.urlNewFull, request.method, false);
            var fixedUrlToCache = urlAndBody.urlNewFull;
            if (!isEmpty(cacheFilter)) {
              fixedUrlToCache = filterUrlParameters(urlAndBody.urlNewFull, cacheFilter.ignoreKeys);
            }

            return {
              urlNewFull: urlAndBody.urlNewFull,
              urlNewToCache: fixedUrlToCache,
              isCustomCaching: !isEmpty(cacheFilter),
              isStaticCaching: isStaticCachingFn(event.request.url),
              isAppMainRequest: isAppMainRequestFn(request.url),
              customCacheFilter: cacheFilter,
              originalRequest: request,
              isFileUploading: urlAndBody.isFileUploading,
              cloneRequest: function() { return request.clone(); }
            };
          });
      }
    };

    return fn().then(function(requestData2) {
      if (requestData2.originalRequest.headers.get('range')) {
        return buildRangeResponse(requestData2);
      } else {
        return buildResponse(requestData2);
      }
    });
  }

  const {
    request,
    request: {
      url,
      method,
    },
  } = event;

  checkOnlineStatus();

  if (url.match(SHARED_DATA_ENDPOINT)) {
    event.respondWith(
      caches.open(SHARED_DATA_ENDPOINT).then(cache => {
        if (method == "POST") {
          return request.json().then(data => {
            cache.put(SHARED_DATA_ENDPOINT + '/' + data.key, new Response(data.value));
            return new Response("OK");
          });
        } else {
          return cache.match(SHARED_DATA_ENDPOINT + '/' + new URL(request.url).searchParams.get('key')).then(response => {
            return response || new Response("");
          }) || new Response("");
        }
      })
    );
  } else {
    var requestData = createRequestDataGET(event.request);

    if (checkRequestForSkipping(event.request, requestData)) {
      return;
    } else {
      event.respondWith(makeResponse(event.request, requestData));
    }
  }
});

var cleanServiceWorkerCache = function() {
  caches.delete(rangeResourceCache);
  console.log("cache cleared", rangeResourceCache);

  return caches.keys().then(function(keyList) {
    return Promise.all(keyList.map(function(key) {
      if (CACHE_NAME != key && SHARED_DATA_ENDPOINT != key) {
        console.log("cache cleared", key);
        return caches.delete(key);
      }
    }));
  });
};

self.addEventListener('install', event => {
  self.skipWaiting();

  event.waitUntil(Promise.resolve());
});

self.addEventListener('activate', function(event) {
  // this cache is only for session
  cleanServiceWorkerCache();

  event.waitUntil(clients.claim());
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
    var request = new Request(urlAddBaseLocation(url));
    return fetch(request).then(function(response) {
      // Automatically cache uncached resources
      if (response.status == 200 && response.type == "basic") {
        var requestToCache = new Request(filterUrlParameters(request.url, ignoreParameters));
        caches.open(CACHE_NAME_DYNAMIC).then(function(cache) {
          cache.put(requestToCache, response.clone());

          sendMessageToClient(event, {
            msg: "Cached resource:",
            url: url,
            urlCached: requestToCache.url
          });

          return true;
        }).catch(function() {
          return false;
        });
      } else {
        return false;
      }
    }).catch(function() {
      return false;
    });
  };

  var isEqualStrings = function(str1, str2) {
    return ((isEmpty(str1) && isEmpty(str2)) || (str1 === str2));
  };

  var getNotEmptyString = function(str) {
    if (isEmpty(str)) return "";
    else return str;
  };

  var checkUrlsInCache = function(urls) {
    return Promise.all(urls.map(function(url) {
        return caches.match(urlAddBaseLocation(url), { ignoreSearch: false })
          .then(function(response) {
            if (response) return url;
            else return "";
          }).catch(function() { return ""; })
      })).then(function(urls2) { return urls2.filter(function(url) { return url != ""; }); })
      .then(function(urls2) { return { "urls": urls2, status: "OK" }; })
      .catch(function() { return { "urls": [], status: "Failed" }; });
  };

  if (event.data.action == "add_dynamic_resource_extension") {
    event.data.data.value = (event.data.data.value.startsWith(".")?event.data.data.value.substr(1):event.data.data.value).toLowerCase();

    if (!dynamicResourcesExtensions.includes("." + event.data.data.value)) {
      dynamicResourcesExtensions.push("." + event.data.data.value);
    }

    respond({ status: "OK" });
  } else if (event.data.action == "remove_dynamic_resource_extension") {
    event.data.data.value = (event.data.data.value.startsWith(".")?event.data.data.value.substr(1):event.data.data.value).toLowerCase();

    if (dynamicResourcesExtensions.includes("." + event.data.data.value)) {
      dynamicResourcesExtensions = dynamicResourcesExtensions.filter(v => v != ("." + event.data.data.value));
    }

    respond({ status: "OK" });
  } else if (event.data.action == "set_prefer_cached_resources") {
    CacheMode.PreferCachedResources = event.data.data.value;
    respond({ status: "OK" });
  } else if (event.data.action == "set_cache_static_resources") {
    CacheMode.CacheStaticResources = event.data.data.value;

    respond({ status: "OK" });
  } else if (event.data.action == "get_cache_version") {
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
    event.data.data.cacheIfUrlMatch = urlAddBaseLocation(event.data.data.cacheIfUrlMatch).toLowerCase();
    event.data.data.method = event.data.data.method.toLowerCase();
    //event.data.data.cacheIfParametersMatch = event.data.data.cacheIfParametersMatch.map(function(el) { return el .toLowerCase();; });
    event.data.data.ignoreParameterKeysOnCache = event.data.data.ignoreParameterKeysOnCache.map(function(el) { return el.toLowerCase(); });

    var idx1 = requestsCacheFilter.findIndex(function(el) { return isEqualStrings(event.data.data.cacheIfUrlMatch, el.url); });
    if (idx1 == -1) {
      requestsCacheFilter.push({ url: getNotEmptyString(event.data.data.cacheIfUrlMatch), methods: [] });
      idx1 = requestsCacheFilter.length - 1;
    }

    var idx2 = requestsCacheFilter[idx1].methods.findIndex(function(el) {
      return isEqualStrings(event.data.data.method, el.method);
    });
    if (idx2 == -1) {
      requestsCacheFilter[idx1].methods.push({ method: getNotEmptyString(event.data.data.method), parameters: [] });
      idx2 = requestsCacheFilter[idx1].methods.length - 1;
    }

    var idx3 = requestsCacheFilter[idx1].methods[idx2].parameters.findIndex(function(els) {
      if (els.keyValues.length == event.data.data.cacheIfParametersMatch.length) {
        return event.data.data.cacheIfParametersMatch.every(function(pair) {
          return (pair.length == 2 && els.keyValues.findIndex(function(kv) {
            return (isEqualStrings(kv.key, pair[0]) && isEqualStrings(kv.value, pair[1]));
          }) != -1);
        });
      } else {
        return false;
      }
    });

    if (idx3 == -1) {
      requestsCacheFilter[idx1].methods[idx2].parameters.push({
        keyValues: event.data.data.cacheIfParametersMatch.map(function(pair) { return { key: pair[0], value: pair[1] }; }),
        ignoreKeys: event.data.data.ignoreParameterKeysOnCache
      });
    } else {
      requestsCacheFilter[idx1].methods[idx2].parameters[idx3] = {
        keyValues: event.data.data.cacheIfParametersMatch.map(function(pair) { return { key: pair[0], value: pair[1] }; }),
        ignoreKeys: event.data.data.ignoreParameterKeysOnCache
      };
    }

    respond({ status: "OK" });
  } else if (event.data.action == "requests_skip_filter") {
    event.data.data.url = urlAddBaseLocation(event.data.data.url).toLowerCase();
    event.data.data.method = event.data.data.method.toLowerCase();
    event.data.data.header = event.data.data.header.map(function(el) { return el.toLowerCase(); });
    if (event.data.data.header.length == 2) {
      event.data.data.header = { key: event.data.data.header[0], value: event.data.data.header[1] };
    } else {
      event.data.data.header = { key: "", value: "" };
    }

    var idx1 = requestsSkipOnFetch.findIndex(function(el) { return isEqualStrings(event.data.data.url, el.url); });
    if (idx1 == -1) {
      requestsSkipOnFetch.push({ url: getNotEmptyString(event.data.data.url), methods: [] });
      idx1 = requestsSkipOnFetch.length - 1;
    }

    var idx2 = requestsSkipOnFetch[idx1].methods.findIndex(function(el) {
      return isEqualStrings(event.data.data.method, el.method);
    });
    if (idx2 == -1) {
      requestsSkipOnFetch[idx1].methods.push({ method: getNotEmptyString(event.data.data.method), headers: [] });
      idx2 = requestsSkipOnFetch[idx1].methods.length - 1;
    }

    var idx3 = requestsSkipOnFetch[idx1].methods[idx2].headers.findIndex(function(h) {
      return (isEqualStrings(h.key, event.data.data.header.key) && isEqualStrings(h.value, event.data.data.header.value));
    });

    if (idx3 == -1) {
      requestsSkipOnFetch[idx1].methods[idx2].headers.push(event.data.data.header);
    }

    respond({ status: "OK" });
  } else if (event.data.action == "load_and_cache_urls") {
    respondWithStatus(
      Promise.all(event.data.data.urls.map(function(url) {
        return fetchAndCacheByUrl(url, event.data.data.ignoreParameterKeysOnCache);
      }))
    );
  } else if (event.data.action == "check_urls_in_cache") {
    checkUrlsInCache(event.data.data.urls).then(respond);
  } else if (event.data.action == "get_service_worker_version") {
    respond({ data: SERVICE_WORKER_VERSION });
  } else if (event.data.action == "set_use_cache_only_in_offline") {
    CacheMode.UseOnlyCacheInOffline = event.data.enabled;
    respond({ status: "OK" });
  } else {
    respond({ status: "Failed", error: "Unknown operation: " + event.data.action });
  }
});