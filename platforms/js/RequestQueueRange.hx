import js.lib.Promise;

/**
 * Represents a queue for managing requests which are loaded by chunks.
 */
class RequestQueueRange {
	// A map of request identifiers to their corresponding promises.
	private var pendingRequests: Map<String, Promise<String>> = new Map();
	// A cache storing blobs identified by a string (url) key.
	private var blobCache: Map<String, String> = new Map<String, String>();
	// Tracks the usage count of each blob by its identifier.
	private var blobUsage: Map<String, Int> = new Map<String, Int>();

	public function new() {
		// Nothing to initialize there
	}

	/**
	* Sends a request to the specified URL, utilizing cached data if available.
	*
	* @param url The URL to send the request to.
	* @param headers An array of header arrays to include in the request.
	* @param updateVideoSource A callback function to update the video source.
	* @return A promise that resolves with the response as a string.
	*
	* If the requested URL is already cached, the cached data is returned.
	* If a request for the URL is already in progress, the existing promise is returned.
	* Otherwise, a new request is initiated and its promise is stored and returned.
	*/
	public function request(url: String, headers: Array<Array<String>>, updateVideoSource: String -> Void): Promise<String> {
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
		var promise = createRequestPromise(url, headers, updateVideoSource);

		// Places request into the download queue
		pendingRequests.set(url, promise);

		return promise;
	}

	/**
	* Creates a promise to handle a request to the specified URL with given headers.
	*
	* @param url The URL to send the request to.
	* @param headers An array of header arrays to include in the request.
	* @param updateVideoSource A callback function to update the video source.
	* @return A promise that resolves with a string result.
	*/
	private function createRequestPromise(url: String, headers: Array<Array<String>>, updateVideoSource: String -> Void): Promise<String> {
		// Creates a new promise and stores it in the pending requests map.
		return new Promise<String>(function(resolve, reject) {
			// Loads the content total length.
			loadContentLengthPromise(url, headers).then(function(contentLength) {
				// Loads the content by chunks.
				loadAllChunks(url, headers, contentLength, updateVideoSource, resolve, reject);
			});
		});
	}

	/**
	* Loads the content length of a resource from a given URL using a HEAD request.
	*
	* @param url The URL of the resource to query.
	* @param headers An array of header key-value pairs to include in the request.
	* @return A promise that resolves with the content length as an integer if successful,
	*         or rejects with an error message if the request fails or the content-length
	*         header is not present or invalid.
	*/
	private function loadContentLengthPromise(url: String, headers: Array<Array<String>>): Promise<Int> {
		return new Promise<Int>(function(resolve, reject) {
			// New request to download file
			var xhrHead = new js.html.XMLHttpRequest();
			xhrHead.open("HEAD", url, true);
			for (header in headers) {
				xhrHead.setRequestHeader(header[0], header[1]);
			}

			// If the request is successful, read the content length header.
			xhrHead.onload = function (oEvent) {
				if (xhrHead.status == 200) {
					var contentLengthHeader: Null<String> = xhrHead.getResponseHeader("content-length");
					if (contentLengthHeader != null && contentLengthHeader.length > 0) {
						var contentLength: Int = Std.parseInt(contentLengthHeader);
						if (contentLength > 0) {
							resolve(contentLength);
						} else {
							reject("content-length header is 0");
						}
					} else {
						reject("content-length header is not presented");
					}
				} else if (xhrHead.status >= 400) {
					// Handle errors
					reject("Request failed: " + xhrHead.status);
				}
			};

			// Handle errors
			xhrHead.onerror = reject;
			xhrHead.send(null);
		});
	}

	/**
	* Loads all chunks of data from a given URL and processes them sequentially.
	*
	* @param url The URL from which to load the data chunks.
	* @param headers An array of headers to include in the request.
	* @param contentLength The total length of the content to be loaded.
	* @param updateVideoSource A callback function to update the video source with each processed chunk.
	* @param resolve A callback function to call upon successful loading and processing of first chunk.
	* @param reject A callback function to call if an error occurs during loading.
	*/
    private function loadAllChunks(
        url: String, 
        headers: Array<Array<String>>, 
        contentLength: Int, 
        updateVideoSource: String -> Void, 
        resolve: String -> Void, 
        reject: String -> Void
    ): Void {
        var sizeChunks = [];
        var oneMb = 1024 * 1024;
        var chunkSize = 2 * oneMb;
        var collectedSize = 0;

        // Calculate chunk sizes
        while (collectedSize < contentLength) {
            var chunk: Int = Std.int(Math.min(chunkSize, contentLength - collectedSize));
            sizeChunks.push(chunk);
            collectedSize += chunk;
            chunkSize *= 3;
        }

        // Attach the rest part of the video to the last chunk if it is less than previous chunk
        if (sizeChunks.length > 1) {
			var lastChunkIndex = sizeChunks.length - 1;
			var lastLastChunkIndex = sizeChunks.length - 2;
        	var lastChunkSize = sizeChunks[lastChunkIndex];
			var lastLastChunkSize = sizeChunks[lastLastChunkIndex];
			if (lastLastChunkSize > lastChunkSize) {
				sizeChunks[lastLastChunkIndex] = lastLastChunkSize + lastChunkSize;
				sizeChunks.pop();
			}
		}

        var start: Int = 0;
        var chunks = [];
        // Load each chunk
        for (i in 0...sizeChunks.length) {
            var size = sizeChunks[i];
            var end: Int = start + size - 1;

            loadChunk(
                url, headers, start, end,
                function(chunk) {
                    processChunk(url, i, chunk, chunks, updateVideoSource, resolve);
                },
                reject
            );

            start += size;
        }
    }

	/**
	* Processes a video chunk by updating the chunk array, creating a blob from all chunks,
	* and updating the video source with the new blob URL.
	*
	* @param url The URL associated with the video content.
	* @param i The index of the current chunk being processed.
	* @param chunk The current video chunk to be processed.
	* @param chunks An array containing all video chunks.
	* @param updateVideoSource A function to update the video source with the new blob URL.
	* @param resolve A function to resolve the first fragment's readiness.
	*/
    private function processChunk(
        url: String, 
        i: Int, 
        chunk: String, 
        chunks: Array<String>, 
        updateVideoSource: String -> Void, 
        resolve: String -> Void
    ): Void {
        // Store the current chunk in the chunks array
        chunks[i] = chunk;

        // Remember the previous chunk if it's not the first one
        var oldChunk = (i != 0) ? blobCache.get(url) : null;

        // Create a new blob from all chunks and cache its URL
        var blob = new js.html.Blob(chunks);
        var blobUrl = js.html.URL.createObjectURL(blob);
        blobCache.set(url, blobUrl);

        // Notify that the first chunk is ready
        if (i == 0) {
            resolve(blobUrl);
        }

        // Update the video source with the new blob URL
        updateVideoSource(blobUrl);

        // Revoke the previous blob URL if not the first chunk
        if (oldChunk != null) {
            haxe.Timer.delay(() -> {
                js.html.URL.revokeObjectURL(oldChunk);
            }, 100);
        }
    }

	/**
	* Loads a chunk of data from a specified URL using an HTTP GET request with range headers.
	*
	* @param url The URL to request the data from.
	* @param headers An array of header key-value pairs to include in the request.
	* @param start The starting byte position of the data to be loaded.
	* @param end The ending byte position of the data to be loaded.
	* @param resolve A callback function to be called with the response data if the request is successful.
	* @param reject A callback function to be called with an error message if the request fails.
	*/
    private function loadChunk(
        url: String, 
        headers: Array<Array<String>>, 
        start: Int, 
        end: Int, 
        resolve: String -> Void, 
        reject: String -> Void
    ): Void {
        var xhrChunk = new js.html.XMLHttpRequest();
        xhrChunk.open("GET", url, true);

        // Set custom headers
        for (header in headers) {
            xhrChunk.setRequestHeader(header[0], header[1]);
        }
        xhrChunk.setRequestHeader("Range", "bytes=" + start + "-" + end);
        xhrChunk.responseType = js.html.XMLHttpRequestResponseType.BLOB;

        // Define onload event handler
        xhrChunk.onload = function(_) {
            if (xhrChunk.status == 206) {
                resolve(xhrChunk.response);
            } else if (xhrChunk.status >= 400) {
                reject("Request failed: " + xhrChunk.status);
            }
        };

        // Define onerror event handler
        xhrChunk.onerror = function(_) {
            reject("Network error occurred");
        };

        xhrChunk.send();
    }

	/**
	* Removes or decrements the usage count of a blob identified by the given URL.
	*
	* @param url The URL of the blob whose usage is to be removed or decremented.
	* @param keepInRequestCache A boolean indicating whether to keep the blob in the request cache.
	* 
	* If the usage count is greater than 1, it decrements the count. If the count is 1 or less,
	* it either sets the count to 0 or removes the blob from the cache based on the keepInRequestCache flag.
	*/
	public function removeBlobUsage(url: String, keepInRequestCache : Bool): Void {
		var cnt = blobUsage.get(url);
		if (cnt > 1) {
			// Count usages of the blob
			blobUsage.set(url, cnt - 1);
		} else {
			if (keepInRequestCache) {
				blobUsage.set(url, 0);
			} else {
				// Removes info about images usage from the caches
				blobCache.remove(url);
				blobUsage.remove(url);
			}
		}
	}

	/**
	* Clears the cache by removing all entries from the blobCache and blobUsage.
	*/
	public function clearCache(): Void {
		blobCache.clear();
		blobUsage.clear();
	}
}
