var SERVICE_WORKER_VERSION = 27;
var INDEXED_DB_NAME = "serviceWorkerDb";
var INDEXED_DB_VERSION = 1;
var CACHE_NAME = 'flow-cache';
var CACHE_NAME_DYNAMIC = 'flow-dynamic-cache';
var rangeResourceCache = 'flow-range-cache';

var SHARED_DATA_ENDPOINT = 'share/pwa/data.php';
// The value used to determine that we are offline
var LAST_FAILED_COUNT_LIMIT = 5;
// Just to prevent jumping offline/online when the browser get resources from disk cache
var LAST_SUCCESS_COUNT_BACK = 3;

// We gonna cache all resources except resources extensions below
var dynamicResourcesExtensions = [
  ".php",
  ".serverbc",
  ".html",
  ".js"
];

var cacheMode = {
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
// The structure of `requestsCacheFilterSimple` is
//  [{
//    url: /*string*/,
//    methods: [{
//      method: /*string*/,
//      parameters: [{
//        keyValues: [{ key: /*string*/, value: /*string*/ }],
//        ignoreKeys: [ /*string*/ ]
//      }]
//    }]
//  }]
var requestsCacheFilterSimple = [];

// The `requestsCacheFilterExternal` are the same as `requestsCacheFilterSimple`, but for
//  external components, which provides it own js scripts to process the requests
// The structure of `requestsCacheFilterExternal` is
//  [{
//    name: /*string*/,
//    filters: [{    
//      url /*string*/,
//      methods : [{
//        method: /*string*/,
//        parameters : [{
//          keyValues : [{ key /*string*/, value /*string*/ }],
//          ignoreKeys : [ /*string*/ ]
//        }]
//      }]
//    }]
//  }]
var requestsCacheFilterExternal = [];

// Stats about how SW processed request from the last application start
var requestsCount = {
  fromNetwork: 0,
  fromCache: 0,
  skipped: 0,
  failed: 0,
  lastStatus: "",
  lastFailedCount: 0,
  lastNetworkCount: 0
}

var isOnline = true;

// SW db settings
var swIndexedDb = {
  allStatuses: {
    None: 0,
    Ready: 1,
    Starting: 2,
    Closed: 3
  },
  status: 0,
  db: null,
  showNotifications: true,
  isReady: function() { return this.status == this.allStatuses.Ready && this.db != null; },
  isNeedInit: function() { return this.status == this.allStatuses.None; },
  isStarting: function() { return this.status == this.allStatuses.Starting; },
  isNone: function() { return this.status == this.allStatuses.None; },
  initDb: function(db) {
    if (db != null) {
      this.db = db;
      this.status = this.allStatuses.Ready;

      if (this.showNotifications) console.log("ServiceWorker: IndexedDB started successfully.");

      return true;
    } else {
      this.db = null;
      this.status = this.allStatuses.None;

      if (this.showNotifications) console.log("ServiceWorker: Something went wrong. IndexedDB was not started.");

      return false;
    }
  },
  closeDb: function(db) {
    this.db = null;
    this.status = this.allStatuses.Closed;

    alert("A new version of component installed. Please, reload this page.");
    if (this.showNotifications) console.log("ServiceWorker: IndexedDB was closed to apply new version.");

    return true;
  },
  startingDb: function(db) {
    this.db = null;
    this.status = this.allStatuses.Starting;

    if (this.showNotifications) console.log("ServiceWorker: IndexedDB starting...");

    return true;
  },
  failInitDb: function(error) {
    this.db = null;
    this.status = this.allStatuses.None;

    if (this.showNotifications) console.log("ServiceWorker: IndexedDB was not started:", error);

    return true;
  },
  showSwNotification: function(text) {
    if (this.showNotifications) console.log("ServiceWorker: " + text);
  }
}

var timerId = null;

// Collection of requests and timings of processing steps
var requestsTimings = [];

function swIndexedDbInitialize() {
  if (swIndexedDb.isNeedInit()) {
    return swIndexedDbInitPromise();
  } else if (swIndexedDb.isStarting()) {
    return new Promise(function(resolve, reject) {
      swIndexedDbWhaitWhileStarting(function() {
        if (swIndexedDb.isReady()) {
          resolve(swIndexedDb.db);
        } else {
          reject();
        }
      });
    });
  } else {
    return new Promise(function(resolve, reject) { resolve(swIndexedDb.db); });
  }
}

function swIndexedDbWhaitWhileStarting(onDone) {
  if (swIndexedDb.isStarting()) {
    setTimeout(function() { swIndexedDbWhaitWhileStarting(onDone); }, 100);
  } else {
    onDone();
  }
}

function swIndexedDbInitPromise() {
  return new Promise(function(resolve, reject) {
    var openRequest = indexedDB.open(INDEXED_DB_NAME, INDEXED_DB_VERSION);
    var promiseDone = false;
    swIndexedDb.startingDb();

    openRequest.onupgradeneeded = function(e) {
      swIndexedDb.showSwNotification("New version of IndexedDB detected.");
      var thisDB = e.target.result;

      if (!thisDB.objectStoreNames.contains('serviceWorkerVars')) {
        swIndexedDb.showSwNotification("Creation of new tables.");
        thisDB.createObjectStore('serviceWorkerVars', { keyPath: 'varName' });
        let tx = e.target.transaction;
        let os = tx.objectStore('serviceWorkerVars');

        try {
          swIndexedDb.showSwNotification("Adding data 1...");
          // We gonna cache all resources except resources extensions below
          os.add({
            varName: 'dynamicResourcesExtensions',
            value: [
              ".php",
              ".serverbc",
              ".html",
              ".js"
            ]
          });
          swIndexedDb.showSwNotification("Adding data 2...");
          // ServiceWorker behaviour model
          os.add({
            varName: 'cacheMode',
            value: {
              // Respond with cached resources even when online
              PreferCachedResources: false,
              // Cache all static files requests
              CacheStaticResources: true,
              // In offline use only cached requests
              UseOnlyCacheInOffline: false
            }
          });
          swIndexedDb.showSwNotification("Adding data 3...");
          // Rules to show which requests should be skipped SW
          os.add({
            varName: 'requestsSkipOnFetch',
            value: []
          });
          swIndexedDb.showSwNotification("Adding data 4...");
          // Filters, which contains rules `Which` and `How` to cache dynamic requests
          os.add({
            varName: 'requestsCacheFilterSimple',
            value: []
          });
          swIndexedDb.showSwNotification("Adding data 5...");
          // No needs to read/write for the `requestsCacheFilterExternal` because it's `hardcoded` here

          swIndexedDb.showSwNotification('IndexedDB has been updated.');

          if (!promiseDone) {
            promiseDone = true;
            resolve(thisDB);
          }
        } catch (err) {
          swIndexedDb.failInitDb(err.message);
          if (!promiseDone) {
            promiseDone = true;
            reject(err.message);
          }
        }
      }
    }

    openRequest.onsuccess = function(e) {
      var thisDB = e.target.result;
      swIndexedDb.db = thisDB;

      let tx = openRequest.result.transaction(['serviceWorkerVars']);
      let os = tx.objectStore('serviceWorkerVars');

      try {
        Promise.all([
          swIndexedDbGetVarPromise(os, 'dynamicResourcesExtensions', v => { dynamicResourcesExtensions = v; return 1; }),
          swIndexedDbGetVarPromise(os, 'cacheMode', v => { cacheMode = v; return 1; }),
          swIndexedDbGetVarPromise(os, 'requestsSkipOnFetch', v => { requestsSkipOnFetch = v; return 1; }),
          swIndexedDbGetVarPromise(os, 'requestsCacheFilterSimple', v => { requestsCacheFilterSimple = v; return 1; })
        ]).then(
          arr => { swIndexedDb.initDb(thisDB); },
          err => { swIndexedDb.failInitDb(err); }
        );
      } catch (err) {
        swIndexedDb.failInitDb(err.message);
        if (!promiseDone) {
          promiseDone = true;
          reject(err.message);
        }
      }

      thisDB.onversionchange = function() {
        thisDB.close();
        swIndexedDb.closeDb();
      };

      if (!promiseDone) {
        promiseDone = true;
        resolve(thisDB);
      }
    }

    openRequest.onerror = function(e) {
      swIndexedDb.failInitDb(e.target.error);

      if (!promiseDone) {
        promiseDone = true;
        reject(e.target.error);
      }
    }
  });
}

function swIndexedDbGetVarPromise(os, varName, fnInit) {
  return new Promise(function(resolve, reject) {
    let promiseDone = false;
    let result = os.get(varName);

    result.onsuccess = function(e) {
      if (!promiseDone) {
        promiseDone = true;
        fnInit(e.target.result.value);
        resolve(e.target.result.value);
      }
    }

    result.onerror = function(e) {
      if (!promiseDone) {
        promiseDone = true;
        reject(e.target.error);
      }
    }
  });
}

function swIndexedDbSetVarPromise(varName, swVar) {
  return swIndexedDbInitialize()
    .then(db => {
      let tx = db.transaction(['serviceWorkerVars'], "readwrite");
      let os = tx.objectStore('serviceWorkerVars');

      return new Promise(function(resolve, reject) {
        let promiseDone = false;
        let result = os.put({
          varName: varName,
          value: swVar
        });

        result.onsuccess = function(e) {
          if (!promiseDone) {
            promiseDone = true;
            resolve();
          }
        }

        result.onerror = function(e) {
          if (!promiseDone) {
            promiseDone = true;
            reject(e.target.error);
          }
        }
      });
    });
}

function checkOnlineStatus() {
  var innerOnlineStatus = (cacheMode.UseOnlyCacheInOffline ? (navigator.onLine && requestsCount.lastFailedCount < LAST_FAILED_COUNT_LIMIT) : navigator.onLine);
  if (innerOnlineStatus === false) {
    if (isOnline) console.info("Application switched to OFFLINE mode.");
    isOnline = false;
    // If `navigator.onLine` works not correctly, let check `onLine` status manually
    if (navigator.onLine && timerId == null) timerId = setInterval(ping_inner, 30000 /* every 30 seconds */ );
  } else {
    if (!isOnline) console.info("Application returned back to ONLINE mode.");
    isOnline = true;
    if (timerId != null) clearInterval(timerId);
    timerId = null;
  }
}

function ping_inner() {
  const request = new Request(
    urlAddBaseLocation('./images/splash/splash_innovation_trans.png'), { method: 'POST', body: '{"t": ' + (new Date().getTime()) + ', "r":"ping"}' }
  );

  fetch(request)
    .then(function(response) {
      if (response.status == 200 && response.type == "basic") {
        addRequestStatus("fromNetwork");
        requestsCount.lastFailedCount = 0;
        requestsCount.lastNetworkCount = 1;
        if (timerId != null) clearInterval(timerId);
        timerId = null;
      } else {
        addRequestStatus("failed");
      }
    })
    .catch(function() { addRequestStatus("failed"); });
}

function addRequestStatus(value) {
  var lastFailedCount = requestsCount.lastFailedCount;
  var lastNetworkCount = requestsCount.lastNetworkCount;

  switch (value) {
    case 'fromNetwork':
      requestsCount.fromNetwork++;
      lastFailedCount = 0;
      if (requestsCount.lastStatus == value)
        lastNetworkCount++;
      if (lastNetworkCount >= LAST_SUCCESS_COUNT_BACK) lastFailedCount = 0;
      break;
    case 'fromCache':
      requestsCount.fromCache++;
      break;
    case 'skipped':
      requestsCount.skipped++;
      break;
    case 'failed':
      requestsCount.failed++;
      if (requestsCount.lastStatus == value || (requestsCount.lastStatus == 'fromCache' && !cacheMode.PreferCachedResources))
        lastFailedCount++;
      if (lastFailedCount >= LAST_FAILED_COUNT_LIMIT) lastNetworkCount = 0;
      break;
  }

  requestsCount.lastStatus = value;
  requestsCount.lastFailedCount = lastFailedCount;
  requestsCount.lastNetworkCount = lastNetworkCount;
}

function resetRequestsCount() {
  requestsCount.fromNetwork = 0;
  requestsCount.fromCache = 0;
  requestsCount.skipped = 0;
  requestsCount.failed = 0;
  requestsCount.lastStatus = "";
  requestsCount.lastFailedCount = 0;
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
    //  and `single_parameter_key`
    if (parameters2.length == 1 && !parameters2[0].includes("=")) {
      parameters2[0] = "single_parameter_key=" + parameters2[0];
      parameters2.push("special_case_key=special_case_value");
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
      p = p.toLowerCase();
      var index = p.indexOf('=');
      if (index !== -1) p = p.substr(0, index);
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
      if (!isEmpty(client)) client.postMessage(data);
      //console.log(data);
    });
  }, 5);
};

var cleanServiceWorkerCache = function() {
  caches.delete(rangeResourceCache);
  console.log("cache cleared", rangeResourceCache);

  return caches.keys().then(function(keyList) {
    return Promise.all(keyList.map(function(key) {
      // We should reset whole cache on update #22 (excluding SHARED_DATA_ENDPOINT)
      if (!((SHARED_DATA_ENDPOINT == key) || (CACHE_NAME == key && SERVICE_WORKER_VERSION != 22))) {
        console.log("cache cleared", key);
        return caches.delete(key);
      }
    }));
  });
};

var moveJwtToHeaders = function(request) {
  if (isEmpty(request.url)) return Promise.resolve(request);
  
  var requestCloned = request.clone();

  var extractJWTFromUrl = function(url) {
    var urlParameters = extractUrlParameters(url);
    var jwt = "";

    urlParameters.parameters = urlParameters.parameters.filter(function(parameter) {
      var p = parameter.split("=");
      if (p.length == 2 && p[0] == "jwt") {
        jwt = p[1];
        return false;
      } else {
        return true;
      }
    });

    return {
      parameters: urlParameters.parameters,
      baseUrl: urlParameters.baseUrl,
      jwt: jwt
    };
  };

  var addJwtToHeaders = function(jwt) {
    var headers = new Headers();
    requestCloned.headers.forEach(function(val, key) {
      headers.set(key, val);
    });
    headers.append("Authorization", "Bearer " + jwt);

    return headers;
  };

  if (requestCloned.method == "POST") {
    return requestCloned.text()
      .then(function(data) {
        if (isEmpty(data)) {
          return Promise.resolve(request);
        } else {
          if (data.includes("jwt=")) {
            // we use only parameters
            var urlParameters = extractJWTFromUrl("anyhost.com?" + data);
            if (urlParameters.jwt == "") {
              return Promise.resolve(request);
            } else {
              return Promise.resolve(
                (new Request(requestCloned.url, {
                  method: requestCloned.method,
                  headers: addJwtToHeaders(urlParameters.jwt),
                  body: urlParameters.parameters.join("&"),
                  mode: 'same-origin',
                  credentials: requestCloned.credentials,
                  cache: requestCloned.cache,
                  redirect: requestCloned.redirect,
                  referrer: requestCloned.referrer,
                  integrity: requestCloned.integrity
                }))
              );
            }
          } else {
            return Promise.resolve(request);
          }
        }
      })
      .catch(function() { return Promise.resolve(request); });
  } else /* GET */ {
    var urlParameters = extractJWTFromUrl(requestCloned.url);

    if (urlParameters.jwt == "") {
      return Promise.resolve(request);
    } else {
      return Promise.resolve(
        (new Request(urlParameters.baseUrl + "?" + urlParameters.parameters.join("&"), {
          method: requestCloned.method,
          headers: addJwtToHeaders(urlParameters.jwt),
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
};

var createRequestTimingsVar = function() {
  var tm = Date.now();
  return {
    startTimestamp: tm,
    lastTime: tm,
    duration: -1,
    steps: []
  };
}

self.addEventListener('install', function(event) {
  self.skipWaiting();

  // Perform install steps
  event.waitUntil(
    initializeCacheStorage()
  );
});

self.addEventListener('activate', function(event) {
  cleanServiceWorkerCache();

  // this cache is only for session
  event.waitUntil(Promise.all([
    clients.claim(),
    swIndexedDbInitialize()
  ]));
});

self.addEventListener('fetch', function(event) {
  swIndexedDbInitialize();

  var requestTimings = createRequestTimingsVar();

  function addTimingsStep(name) {
    var tm = Date.now() - requestTimings.lastTime;
    requestTimings.steps.push({
      name: name,
      time: tm
    });

    requestTimings.lastTime = Date.now();
  }

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
    var requestUrl = (new URL(url)).pathname,
      parts,
      ext = (parts = requestUrl.split("/").pop().split(".")).length > 1 ? parts.pop() : "";

    return (cacheMode.CacheStaticResources && !isEmpty(ext) && !dynamicResourcesExtensions.includes("." + ext));
  }

  var isAppMainRequestFn = function(url) {
    var requestUrl = (new URL(request.url)).pathname,
      parts,
      ext = (parts = requestUrl.split("/").pop().split(".")).length > 1 ? parts.pop() : "";
    var name = (parts.length > 0 ? parts.pop() : "");

    var res = (!isEmpty(ext) && !isEmpty(name) && (
      "stamp.php" == name + "." + ext ||
      "flowjs.html" == name + "." + ext));

    if (res) {
      resetRequestsCount();
      requestsTimings = [];
    }

    return res;
  }

  var extractRequestStepInfo = function(baseUrl, parameters) {
    requestTimings.name = baseUrl.split('\\').pop().split('/').pop();
    requestTimings.operation = parameters.map(function(p) {
      p2 = p.toLowerCase();
      var index = p2.indexOf('=');

      if ((index !== -1) && (p2.substr(0, index) == "operation")) return p.substr(index + 1);
      else return "";
    }).filter(function(op) { return op != ""});
  }

  // Creation a requestData for GET requests
  var createRequestDataGET = function(request) {
    var fixedUrl = urlAddBaseLocation(request.url);
    var urlSplitted = extractUrlParameters(fixedUrl);
    var usedCacheName = CACHE_NAME;
    var isStaticCaching = isStaticCachingFn(request.url);

    extractRequestStepInfo(urlSplitted.baseUrl, urlSplitted.parameters);

    if (request.method == "GET") {
      var cacheFilter = findCacheFilter(fixedUrl, request.method, false);
      var fixedUrlToCache = urlSplitted.baseUrl + (urlSplitted.parameters.length > 0 ? ("?" + urlSplitted.parameters.join("&")) : "");

      if (!isEmpty(cacheFilter)) {
        if (cacheFilter.isSimple) {
          fixedUrlToCache = filterUrlParameters(fixedUrl, cacheFilter.ignoreKeys);
          usedCacheName = CACHE_NAME_DYNAMIC;
        } else {
          if (!isEmpty(cacheFilter.onNewUrlString))
            fixedUrl = cacheFilter.onNewUrlString(request, fixedUrl);
          fixedUrlToCache = filterUrlParameters(fixedUrl, cacheFilter.ignoreKeys);
          usedCacheName = "flow-" + cacheFilter.name + "-cache";
        }
      } else {
        // Skipping the "special_case_key" parameter for the static resources
        if (isStaticCaching) fixedUrlToCache = filterUrlParameters(fixedUrlToCache, ["special_case_key", "single_parameter_key"]);
      }

      return {
        urlNewFull: fixedUrl,
        urlNewToCache: fixedUrlToCache,
        isCustomCaching: (!isEmpty(cacheFilter)),
        isStaticCaching: isStaticCaching,
        isAppMainRequest: isAppMainRequestFn(request.url),
        customCacheFilter: cacheFilter,
        originalRequest: request,
        isFileUploading: isFileUploadingRequestFn(request),
        usedCacheName: usedCacheName,
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

          extractRequestStepInfo(urlSplitted.baseUrl, extractUrlParameters(requestUrl).parameters);

          return { urlNewFull: requestUrl, isFileUploading: isFileUploadingRequest };
        }).catch(function() {
          return { urlNewFull: fixedUrl, isFileUploading: isFileUploadingRequest };
        });
      } else {
        return Promise.resolve({ urlNewFull: fixedUrl, isFileUploading: isFileUploadingRequest });
      }
    } else {
      extractRequestStepInfo(urlSplitted.baseUrl, urlSplitted.parameters);
      return Promise.resolve({ urlNewFull: fixedUrl, isFileUploading: isFileUploadingRequest });
    }
  }

  // Searching the filter to which the request is match
  var findCacheFilter = function(fixedUrl, method, checkWithoutParameters) {
    fixedUrl = fixedUrl.toLowerCase();
    method = method.toLowerCase();
    var urlParams = extractUrlParameters(fixedUrl).parameters;

    var cFilters = findCacheFilterExternal(fixedUrl, method, urlParams, checkWithoutParameters);
    if (!isEmpty(cFilters) && cFilters.length > 0 && !isEmpty(cFilters[0])) {
      return cFilters[0];
    } else {
      cFilters = findCacheFilterSimple(fixedUrl, method, urlParams, checkWithoutParameters);
      if (!isEmpty(cFilters) && cFilters.length > 0 && !isEmpty(cFilters[0])) {
        return cFilters[0];
      } else {
        return undefined;
      }
    }
  }

  var findCacheFilterExternal = function(fixedUrl, method, urlParams, checkWithoutParameters) {
    return requestsCacheFilterExternal.map(function(elComp) {
        return elComp.filters.map(function(elFilter) {
            // Does url matched
            if (elFilter.url == "" || fixedUrl.startsWith(elFilter.url.toLowerCase())) {
              methods = elFilter.methods.map(function(elMethod) {
                  // Does method matched
                  if (elMethod.method == "" || elMethod.method.toLowerCase() == method) {
                    if (elMethod.parameters.length == 0 || checkWithoutParameters) {
                      return [{
                        method: elMethod.method,
                        parameters: [],
                        ignoreKeys: [],
                        isSimple: false,
                        name: elComp.name,
                        onNewUrlString: elMethod.onNewUrlStringDefault
                      }];
                    } else {
                      var checkRequestParameters = function(parameter) {
                        return parameter.keyValues.every(function(keyValue) {
                          var pair = (keyValue.key + "=" + keyValue.value).toLowerCase();
                          return (urlParams.findIndex(function(up) {
                            return (pair == up);
                          }) != -1);
                        });
                      };

                      return elMethod.parameters.filter(function(parameter) {
                          return parameter.keyValues.length == 0 || checkRequestParameters(parameter);
                        })
                        .map(function(parameter) {
                          return {
                            method: elMethod.method,
                            parameters: parameter.keyValues,
                            ignoreKeys: parameter.ignoreKeys,
                            isSimple: false,
                            name: elComp.name,
                            onNewUrlString: parameter.onNewUrlString
                          };
                        });
                    }
                  }
                })
                .filter(function(elMethod) { return elMethod != undefined; })
                .flat();

              if (methods.length > 0) {
                return methods.map(function(elMethod) {
                  return {
                    url: elFilter.url,
                    method: elMethod.method,
                    parameters: elMethod.parameters,
                    ignoreKeys: elMethod.ignoreKeys,
                    isSimple: false,
                    name: elMethod.name,
                    onNewUrlString: elMethod.onNewUrlString
                  };
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
      })
      .filter(function(el1) { return el1 != undefined; })
      .flat();
  }

  var findCacheFilterSimple = function(fixedUrl, method, urlParams, checkWithoutParameters) {
    return requestsCacheFilterSimple.map(function(elUrl) {
        // Does url matched
        if (elUrl.url == "" || fixedUrl.startsWith(elUrl.url)) {
          methods = elUrl.methods.map(function(elMethod) {
              // Does method matched
              if (elMethod.method == "" || elMethod.method == method) {
                if (elMethod.parameters.length == 0 || checkWithoutParameters) {
                  return [{
                    method: elMethod.method,
                    parameters: [],
                    ignoreKeys: [],
                    isSimple: true,
                    name: ""
                  }];
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
                      return {
                        method: elMethod.method,
                        parameters: parameter.keyValues,
                        ignoreKeys: parameter.ignoreKeys,
                        isSimple: true,
                        name: ""
                      };
                    });
                }
              }
            })
            .filter(function(elMethod) { return elMethod != undefined; })
            .flat();

          if (methods.length > 0) {
            return methods.map(function(elMethod) {
              return {
                url: elUrl.url,
                method: elMethod.method,
                parameters: elMethod.parameters,
                ignoreKeys: elMethod.ignoreKeys,
                isSimple: true,
                name: ""
              };
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
  }

  // Searching the filter to which the request is match (without parameters)
  var findCacheFilterWithoutParameters = function(request) {
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
    // For standard cache logic
    headers.set('If-None-Match', etag);
    // And special case, for header forwarding through CDN
    headers.set('X-If-None-Match', etag);

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

  var updateHeadersInResponse = function(response, newHeaders) {
    var clResponse = response.clone();
    return clResponse.blob().then(blob => {
      var headers = new Headers();
      /* Copying exists headers */
      clResponse.headers.forEach(function(val, key) {
        headers.set(key, val);
      });
      /* Adding/rewriting by new headers */
      newHeaders.forEach(function(val, key) {
        headers.set(key, val);
      });

      return new Response(blob, {
        ok: clResponse.ok,
        redirected: clResponse.redirected,
        status: clResponse.status,
        statusText: clResponse.statusText,
        headers: headers,
        type: clResponse.type,
        url: clResponse.url,
      });
    });
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

      if (isStampForApplicationJsRequestInner(client.url)) {
        addTimingsStep("isStampForApplicationJsRequest");
        return Promise.resolve();
      } else {
        addTimingsStep("isStampForApplicationJsRequest");
        return Promise.reject();
      }
    });
  }

  // Should we skip this request?
  var checkRequestForSkipping = function(request, requestData) {
    // Should be skipped by special filter?
    return isMatchSkipFilter(request) ||
      // Do not process files uploading requests
      isFileUploadingRequestFn(request) ||
      // We disable caching of Range requests for a while
      (!isEmpty(request.headers.get('range')) && isOnline === true) ||
      (
        // Skip if is not a web resource
        !isStaticCachingFn(request.url) &&
        // Skip if is not the main app loader
        !isAppMainRequestFn(request.url) &&
        // Skip GET request which do not match any custom filter
        (isEmpty(requestData) || !requestData.isCustomCaching)
      ) &&
      // Skip POST request which url is not match any filter (without parameters)
      isEmpty(findCacheFilterWithoutParameters(request)) &&
      // Skip if it is not app loader
      !isStampForApplicationJsRequestInner(request.url);
  }

  function getResourceFromCache(requestData, ignoreSearch) {
    if (requestData.isFileUploading) {
      addTimingsStep("getResourceFromCache skip");
      // We don't cache file uploading request, so we skip the step of request searching in cache
      return Promise.reject();
    } else {
      return caches.match(prepareRequestToCache(requestData), { ignoreSearch: (ignoreSearch && !requestData.isCustomCaching) })
        .then(function(response) {
          addTimingsStep("getResourceFromCache match");

          if (!response) {
            return Promise.reject();
          }

          addRequestStatus("fromCache");

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

      // Cache the request if it's match any customized filter or
      // automatically cache uncached static resources
      if (requestData.isCustomCaching || requestData.isStaticCaching || requestData.isAppMainRequest) {
        caches.open(requestData.usedCacheName).then(function(cache) {
          cache.put(fixedRequest, response.clone());

          sendMessageToClient(event, {
            msg: "Cached resource:",
            url: requestData.originalRequest.url,
            urlCached: fixedRequest.url
          });

          addTimingsStep("cache put");
        });
      }
    };

    var doFetchFn = function() {
      return moveJwtToHeaders(requestData.cloneRequest())
      .then(function(request) { addTimingsStep("moveJwtToHeaders"); return fetch(request); })
      .then(function(response) {
          addTimingsStep("fetch" + (response.redirected?"+redirection":""));
          if (response.status == 200 && response.type == "basic") {
            if (isStampForApplicationJsRequestInner(requestData.originalRequest.url))
              cleanTimestampSensitiveRequests(requestData.originalRequest.url);
            doCacheFn(response);
          }

          addRequestStatus("fromNetwork");
          return response.clone();
        })
        .catch(function() {
          addRequestStatus("failed");
          checkOnlineStatus();
          return Promise.reject();
        });
    };

    var doIfNoneMatchFn = function(responseCache) {
      var etag = responseCache.headers.get('etag');
      if (isEmpty(etag)) {
        return doFetchFn();
      } else {
        if (etag.endsWith("-gzip")) etag = etag.substring(0, etag.length - 5);
        else if (etag.endsWith("-gzip\"")) etag = etag.substring(0, etag.length - 6) + "\"";

        addTimingsStep("checked cache-control");

        return createIfNoneMatchRequest(requestData, etag).then(function(cRequest) {
            addTimingsStep("createIfNoneMatchRequest");
            return moveJwtToHeaders(cRequest)
            .then(function(request) { addTimingsStep("moveJwtToHeaders"); return fetch(request); })
            .then(function(response) {
              addTimingsStep("fetch" + (response.redirected?"+redirection":""));

              if (response.status == 200 && response.type == "basic") {
                doCacheFn(response);
                return response.clone();
              } else if (response.status == 304 && response.type == "basic") {
                return updateHeadersInResponse(responseCache, response.headers)
                  .then(responseNew => {
                    addTimingsStep("updateHeadersInResponse");
                    doCacheFn(responseNew);
                    return responseNew.clone();
                  })
                  .catch(function() {
                    return responseCache.clone();
                  });
              } else {
                return response.clone();
              }
            });
          })
          .catch(doFetchFn);
      }
    };

    if (requestData.isFileUploading) {
      // We can't to clone file uploading request, so we processing it as is, without caching
      return fetch(requestData.cloneRequest())
        .then(function(response) { addTimingsStep("fetch" + (response.redirected?"+redirection":"")); addRequestStatus("fromNetwork"); return response.clone(); });
    } else {
      if (checkIfNotModified) {
        return getCachedResource(requestData)
          .then(function(responseCache) {
            var cacheControl = responseCache.headers.get('cache-control');

            if (isEmpty(cacheControl)) {
              return doIfNoneMatchFn(responseCache);
            } else {
              var ccParams = cacheControl.split(", ");
              var ccNC = ccParams.find(function(p) { return p == 'no-cache'; });
              var ccMR = ccParams.find(function(p) { return p == 'must-revalidate'; });
              var ccMA = ccParams.find(function(p) { return p.startsWith('max-age='); });
              var ccDate = responseCache.headers.get('date');

              /* If 'cache-control: no-cache' header presented in the answer from server - we send `If None Match` request */
              if (!isEmpty(ccNC)) {
                return doIfNoneMatchFn(responseCache);
                /* If 'cache-control: max-age' header presented in the answer */
              } else if (!isEmpty(ccMA)) {
                /* and there is not `Date` header - we send `If None Match` request */
                if (isEmpty(ccDate)) {
                  return doIfNoneMatchFn(responseCache);
                  /* and `Date` header exists */
                } else {
                  ccMA = ccMA.split("=");
                  if (ccMA.length == 2 && !isNaN(parseInt(ccMA[1]))) {
                    ccDate = new Date(ccDate);
                    ccDate.setSeconds(ccDate.getSeconds() + parseInt(ccMA[1]));

                    /* We check does the answer still valid and we can reuse it */
                    if (ccDate >= (new Date())) {
                      return responseCache.clone();
                      /* If 'cache-control: must-revalidate' header presented we revalidate exists cache with `If None Match` request */
                    } else if (!isEmpty(ccMR)) {
                      return doIfNoneMatchFn(responseCache);
                      /* If not - we do new request */
                    } else {
                      return doFetchFn();
                    }
                  } else {
                    return doIfNoneMatchFn(responseCache);
                  }
                }
              } else {
                return doIfNoneMatchFn(responseCache);
              }
            }
          })
          .catch(doFetchFn);
      } else {
        return doFetchFn();
      }
    }
  }

  function buildResponse(requestData) {
    if (cacheMode.UseOnlyCacheInOffline && !isOnline) {
      return getCachedResource(requestData).catch(function() { addRequestStatus("failed"); return Promise.reject(); });;
    } else if (cacheMode.PreferCachedResources) {
      return getCachedResource(requestData).catch(function() {
        return fetchResource(requestData, false);
      });
    } else {
      return fetchResource(requestData, true).catch(function() {
        return getCachedResource(requestData).catch(function() { addRequestStatus("failed"); return Promise.reject(); });;
      });
    }
  };

  function buildRangeResponse(requestData) {
    return caches.match(requestData.urlNewToCache)
      .then(function(res) {
        if (!res && (!cacheMode.UseOnlyCacheInOffline || isOnline === true)) {
          return moveJwtToHeaders(requestData.originalRequest).then(function(request) { return fetch(request); })
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
            var usedCacheName = CACHE_NAME;

            if (!isEmpty(cacheFilter)) {
              if (cacheFilter.isSimple) {
                fixedUrlToCache = filterUrlParameters(fixedUrlToCache, cacheFilter.ignoreKeys);
                usedCacheName = CACHE_NAME_DYNAMIC;
              } else {
                if (!isEmpty(cacheFilter.onNewUrlString))
                  fixedUrlToCache = cacheFilter.onNewUrlString(request, fixedUrlToCache);
                fixedUrlToCache = filterUrlParameters(fixedUrlToCache, cacheFilter.ignoreKeys);
                usedCacheName = "flow-" + cacheFilter.name + "-cache";
              }
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
              usedCacheName: usedCacheName,
              cloneRequest: function() { return request.clone(); }
            };
          });
      }
    };

    return fn().then(function(requestData2) {
      addTimingsStep("makeResponse fn");
      if (requestData2.originalRequest.headers.get('range')) {
        return buildRangeResponse(requestData2);
      } else {
        return buildResponse(requestData2).then(function(result) {
          addTimingsStep("some last step");
          requestTimings.duration = (Date.now() - requestTimings.startTimestamp);
          requestsTimings.push(requestTimings);

          return result;
        });
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

  // do nothing for non http requests (like `chrome-extension` requests and others)
  if(!event.request.url.startsWith('http')) {
    addTimingsStep("skipped (http)");
    requestTimings.duration = (Date.now() - requestTimings.startTimestamp);
    requestsTimings.push(requestTimings);
    
    return;
  } else if (url.match(SHARED_DATA_ENDPOINT)) {
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
    requestTimings.lastTime = Date.now();
    var requestData = createRequestDataGET(event.request);
    addTimingsStep("createRequestDataGET");

    if (checkRequestForSkipping(event.request, requestData)) {
      addTimingsStep("checkRequestForSkipping");
      addRequestStatus("skipped (rule)");
      requestTimings.duration = (Date.now() - requestTimings.startTimestamp);
      requestsTimings.push(requestTimings);

      return;
    } else {
      addTimingsStep("checkRequestForSkipping");
      event.respondWith(makeResponse(event.request, requestData));
    }
  }
});

self.addEventListener('message', function(event) {
  swIndexedDbInitialize();

  var respond = function(data) {
    if (event.ports.length > 0 /*&& !isEmpty(event.ports[0])*/ ) {
      event.ports[0].postMessage(data);
    } else {
      console.error("ServiceWorker: Failed to respond!");
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
    return moveJwtToHeaders(request).then(function(request) { return fetch(request); }).then(function(response) {
      // Automatically cache uncached resources
      if (response.status == 200 && response.type == "basic") {
        var requestToCache = new Request(filterUrlParameters(request.url, ignoreParameters.map(function(p) { return p.toLowerCase(); })));
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
    event.data.data.value = (event.data.data.value.startsWith(".") ? event.data.data.value.substr(1) : event.data.data.value).toLowerCase();

    if (!dynamicResourcesExtensions.includes("." + event.data.data.value)) {
      dynamicResourcesExtensions.push("." + event.data.data.value);
    }

    swIndexedDbSetVarPromise('dynamicResourcesExtensions', dynamicResourcesExtensions);
    respond({ status: "OK" });
  } else if (event.data.action == "remove_dynamic_resource_extension") {
    event.data.data.value = (event.data.data.value.startsWith(".") ? event.data.data.value.substr(1) : event.data.data.value).toLowerCase();

    if (dynamicResourcesExtensions.includes("." + event.data.data.value)) {
      dynamicResourcesExtensions = dynamicResourcesExtensions.filter(v => v != ("." + event.data.data.value));
    }

    swIndexedDbSetVarPromise('dynamicResourcesExtensions', dynamicResourcesExtensions);
    respond({ status: "OK" });
  } else if (event.data.action == "set_prefer_cached_resources") {
    cacheMode.PreferCachedResources = event.data.data.value;
    swIndexedDbSetVarPromise('cacheMode', cacheMode);
    respond({ status: "OK" });
  } else if (event.data.action == "set_cache_static_resources") {
    cacheMode.CacheStaticResources = event.data.data.value;
    swIndexedDbSetVarPromise('cacheMode', cacheMode);
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

    var idx1 = requestsCacheFilterSimple.findIndex(function(el) { return isEqualStrings(event.data.data.cacheIfUrlMatch, el.url); });
    if (idx1 == -1) {
      requestsCacheFilterSimple.push({ url: getNotEmptyString(event.data.data.cacheIfUrlMatch), methods: [] });
      idx1 = requestsCacheFilterSimple.length - 1;
    }

    var idx2 = requestsCacheFilterSimple[idx1].methods.findIndex(function(el) {
      return isEqualStrings(event.data.data.method, el.method);
    });
    if (idx2 == -1) {
      requestsCacheFilterSimple[idx1].methods.push({ method: getNotEmptyString(event.data.data.method), parameters: [] });
      idx2 = requestsCacheFilterSimple[idx1].methods.length - 1;
    }

    var idx3 = requestsCacheFilterSimple[idx1].methods[idx2].parameters.findIndex(function(els) {
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
      requestsCacheFilterSimple[idx1].methods[idx2].parameters.push({
        keyValues: event.data.data.cacheIfParametersMatch.map(function(pair) { return { key: pair[0], value: pair[1] }; }),
        ignoreKeys: event.data.data.ignoreParameterKeysOnCache
      });
    } else {
      requestsCacheFilterSimple[idx1].methods[idx2].parameters[idx3] = {
        keyValues: event.data.data.cacheIfParametersMatch.map(function(pair) { return { key: pair[0], value: pair[1] }; }),
        ignoreKeys: event.data.data.ignoreParameterKeysOnCache
      };
    }

    swIndexedDbSetVarPromise('requestsCacheFilterSimple', requestsCacheFilterSimple);
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

    swIndexedDbSetVarPromise('requestsSkipOnFetch', requestsSkipOnFetch);
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
    cacheMode.UseOnlyCacheInOffline = event.data.enabled;
    swIndexedDbSetVarPromise('cacheMode', cacheMode);
    respond({ status: "OK" });
  } else if (event.data.action == "get_requests_stats") {
    respond({ data: requestsCount });
  } else if (event.data.action == "reset_timings") {
    requestsTimings = [];
    respond({ status: "OK" });
  } else if (event.data.action == "get_timings") {
    respond({ data: requestsTimings });
  } else {
    respond({ status: "Failed", error: "Unknown operation: " + event.data.action });
  }
});

swIndexedDbInitialize();