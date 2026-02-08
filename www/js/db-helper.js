/**
 * IndexedDB Helper for Badge Count
 * Used by: firebase-messaging-sw.js and NotificationsSupport.hx
 * Shared badge database between Service Worker and Client
 */

var BADGE_DB_NAME = "FlowBadgeDB";
var BADGE_DB_VERSION = 1;

var badgeDb = null;
var badgeDbStatus = 'none'; // 'none', 'starting', 'ready', 'error'

function openBadgeDB() {
	if (badgeDbStatus === 'ready' && badgeDb) {
		return Promise.resolve(badgeDb);
	}

	if (badgeDbStatus === 'starting') {
		return new Promise(function(resolve, reject) {
			var checkInterval = setInterval(function() {
				if (badgeDbStatus === 'ready') {
					clearInterval(checkInterval);
					resolve(badgeDb);
				} else if (badgeDbStatus === 'error') {
					clearInterval(checkInterval);
					reject(new Error('Failed to open badge database'));
				}
			}, 100);
		});
	}

	badgeDbStatus = 'starting';

	return new Promise(function(resolve, reject) {
		var request = indexedDB.open(BADGE_DB_NAME, BADGE_DB_VERSION);

		request.onerror = function() {
			badgeDbStatus = 'error';
			reject(request.error);
		};

		request.onsuccess = function() {
			badgeDb = request.result;
			badgeDbStatus = 'ready';
			resolve(badgeDb);
		};

		request.onupgradeneeded = function(e) {
			var db = e.target.result;
			if (!db.objectStoreNames.contains('badge')) {
				db.createObjectStore('badge');
			}
		};
	});
}

function getBadgeCount() {
	return openBadgeDB().then(function(db) {
		return new Promise(function(resolve, reject) {
			var tx = db.transaction('badge', 'readonly');
			var store = tx.objectStore('badge');
			var request = store.get('count');

			request.onsuccess = function() {
				var value = request.result;
				resolve(typeof value === 'number' ? value : 0);
			};

			request.onerror = function() {
				resolve(0);
			};
		});
	}).catch(function() {
		return 0;
	});
}

function setBadgeCount(count) {
	var badgeCount = Math.max(0, count);

	return openBadgeDB().then(function(db) {
		return new Promise(function(resolve, reject) {
			var tx = db.transaction('badge', 'readwrite');
			var store = tx.objectStore('badge');
			var request = store.put(badgeCount, 'count');

			request.onsuccess = function() {
				if (navigator.setAppBadge) {
					navigator.setAppBadge(badgeCount).then(resolve).catch(resolve);
				} else {
					resolve();
				}
			};

			request.onerror = function() {
				reject(request.error);
			};
		});
	});
}

function clearBadgeCount() {
	return setBadgeCount(0).then(function() {
		if (navigator.clearAppBadge) {
			return navigator.clearAppBadge().catch(function() {});
		}
	});
}

function incrementBadgeCount() {
	return getBadgeCount().then(function(current) {
		return setBadgeCount(current + 1);
	});
}

if (typeof self !== 'undefined') {
	self.getBadgeCount = getBadgeCount;
	self.setBadgeCount = setBadgeCount;
	self.clearBadgeCount = clearBadgeCount;
	self.incrementBadgeCount = incrementBadgeCount;
}
