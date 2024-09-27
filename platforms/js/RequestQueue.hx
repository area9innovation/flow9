import js.lib.Promise;

class RequestQueue {
	private static var pendingRequests: Map<String, Promise<String>> = new Map();
	private static var blobCache: Map<String, String> = new Map<String, String>();
	private static var blobUsage: Map<String, Int> = new Map<String, Int>();

	public function new() {
		// Nothing to initialize there
	}

	public function request(url: String, headers: Array<Array<String>>): Promise<String> {
		if (blobCache.exists(url)) {
			return new Promise<String>(function(resolve, reject) {
				// Use cached blob
				var blob = blobCache.get(url);
				blobUsage.set(url, blobUsage.get(url) + 1);

				resolve(blob);
			});
		} else if (pendingRequests.exists(url)) {
			// Request already in progress, return existing promise
			return pendingRequests.get(url);
		}

		// Create a new promise and store it in the pending requests map
		var promise = new Promise<String>(function(resolve, reject) {
			// New request to download file
			var blobXhr = new js.html.XMLHttpRequest();
			blobXhr.open("GET", url, true);
			for (header in headers) {
				blobXhr.setRequestHeader(header[0], header[1]);
			}
			
			blobXhr.responseType = js.html.XMLHttpRequestResponseType.BLOB;
			blobXhr.onload = function (oEvent) {
				// Removes request from the download queue
				pendingRequests.remove(url);

				if (blobXhr.status == 200) {
					var type = blobXhr.getResponseHeader("content-type");

					// Adds content to blobs cache
		  			blobCache.set(url, js.html.URL.createObjectURL(blobXhr.response));
		  			resolve(blobCache.get(url));
				} else if (blobXhr.status >= 400) {
					// Handle errors
					reject("Request failed: " + blobXhr.status);
				}
			};

			blobXhr.onerror = reject;
			blobXhr.send(null);
		});

		// Places request into the download queue
		pendingRequests.set(url, promise);

		return promise;
	}

	public function removeBlobUsage(url: String) {
		var cnt = blobUsage.get(url);
		if (cnt > 1) {
			// Count usages of the blob
			blobUsage.set(url, cnt - 1);
		} else {
			// Removes info about images usage from the caches
			blobCache.remove(url);
			blobUsage.remove(url);
		}
	}
}
