import HaxeRuntime;
import NativeTime;
import haxe.ds.Vector;
import haxe.CallStack;

#if js
import js.Browser;
import js.BinaryParser;
import JSBinflowBuffer;
import JsMd5;
#end

#if (flow_nodejs || nwjs)
import js.Node.process;
import js.node.Fs;
import js.node.ChildProcess;
import js.node.Buffer;

#if flow_webmodule
import node.express.Request;
import node.express.Response;
#end
#end

#if flash
import flash.utils.ByteArray;
#end

class Native {
	public static var isNew : Bool = Util.getParameter("new") == "1";
#if (js && flow_nodejs && flow_webmodule)
	static var webModuleResponseText = "";
#end
	public static function println(arg : Dynamic) : Dynamic {
		var s = toString(arg, true);
		#if flash
			try {
				var qoute = StringTools.replace(s, '\\', '');
				flash.external.ExternalInterface.call("console.log", qoute);
			} catch (e : Dynamic) {
				trace(s);
			}
		#elseif neko
			Sys.println(s);
		#elseif (js && ((flow_nodejs && !flow_webmodule) || nwjs))
			Util.println(arg);
		#elseif (js && flow_nodejs && flow_webmodule)
			webModuleResponseText += arg + "\n";
		#elseif js
			untyped console.log(s);
		#else
			Errors.report(s);
		#end
		return null;
	}

	public static inline function debugStopExecution() : Void {
		#if js
			//If dev tools are available stops execution at this line
			js.Lib.debug();
		#end
	}

	public static function genericCompare(a : Dynamic, b : Dynamic) : Int {
		return HaxeRuntime.compareByValue(a, b);
	}

	public static function hostCall(name : String, args: Array<Dynamic>) : Dynamic {
		var result = null;

		#if flash
			if (flash.external.ExternalInterface.available) {
				try {
					result = flash.external.ExternalInterface.call(name,
						args[0],
						args[1],
						args[2],
						args[3],
						args[4]
					);
				} catch (e: Dynamic) {
					trace(e);
				}
			} else {
				if (!complainedMissingExternal) {
					complainedMissingExternal = true;
					trace("No external interface available");
				}
				// Not much to do, dude
			}
		#elseif (js && !flow_nodejs)
			try {
				// Handle namespaces
				var name_parts = name.split(".");
				var fun : Dynamic = untyped Browser.window;
				var fun_nested_object : Dynamic = fun;
				for (i in 0...name_parts.length) {
					fun_nested_object = fun;
					fun = untyped fun[name_parts[i]];
				}
				result = fun.call(fun_nested_object, args[0], args[1], args[2], args[3], args[4]);
			} catch( e : Dynamic) {
				Errors.report(e);
			}
		#end

		return result;
	}

	public static function importJSModule(arg : Dynamic, cb : Dynamic -> Void) : Void {
		#if (js && !flow_nodejs)
			try {
				var module = untyped __js__("arg + encodeURI('\\nconst importJSModuleVersion =' + Math.random())");
				untyped __js__("eval(\"import(module).then((v) => { return v && v.default ? v.default : v; }).then((v) => { cb(v); }).catch((e) => { Errors.report(e); cb(null); })\")");
				//untyped __js__("(new Function(\"import(module).then((v) => { return v && v.default ? v.default : v; }).then((v) => { cb(v); }).catch((e) => { Errors.report(e); cb(null); })\"))()");
			} catch( e : Dynamic) {
				Errors.report(e);
				cb(null);
			}
		#else
			cb(null);
		#end
	}

	static var complainedMissingExternal : Bool = false;

	public static function hostAddCallback(name : String, cb : Void -> Dynamic) : Dynamic {
		#if flash
			try {
				flash.external.ExternalInterface.addCallback(name, cb);
			} catch (e: Dynamic) {
				trace(e);
			}
		#elseif (js && !flow_nodejs)
			untyped Browser.window[name] = cb;
		#end

		return null;
	}

#if (js && !flow_nodejs)
	private static function createInvisibleTextArea() {
		var textArea = Browser.document.createElement("textarea");
		// Place in top-left corner of screen regardless of scroll position.
		// Ensure it has a small width and height. Setting to 1px / 1em
		// doesn't work as this gives a negative w/h on some browsers.
		// We don't need padding, reducing the size if it does flash render.
		// Clean up any borders.
		// Avoid flash of white box if rendered for any reason.
		textArea.style.cssText = "position:fixed;top:0px;left:0px;width:2em;height:2em;padding:0px;border:none;outline:none;boxShadow:none;background:transparent;";
		Browser.document.body.appendChild(textArea);
		return textArea;
	}

	public static function evaluateObjectSize(object : Dynamic) : Int {
		var bytes = 0;
		untyped __js__("
			var objectList = [];
			var stack = [object];

			while (stack.length) {
				var value = stack.pop();

				if (typeof value === 'boolean') {
					bytes += 4;
				}
				else if ( typeof value === 'string' ) {
					bytes += value.length * 2;
				}
				else if ( typeof value === 'number' ) {
					bytes += 8;
				}
				else if
				(
					typeof value === 'object'
					&& objectList.indexOf( value ) === -1
				)
				{
					objectList.push( value );

					if (Object.prototype.toString.call(value) != '[object Array]'){
					   for(var key in value) bytes += 2 * key.length;
					}

					for( var i in value ) {
						stack.push( value[ i ] );
					}
				}
			}
		");
		return bytes;
	}

	public static function usedJSHeapSize() : Int {
		try {
			return untyped Browser.window.performance.memory.usedJSHeapSize;
		} catch (e : Dynamic) {
			untyped console.log("Warning! performance.memory.usedJSHeapSize is not implemented in this target");
			return 0;
		}
	}

	public static function totalJSHeapSize() : Int {
		try {
			return untyped Browser.window.performance.memory.totalJSHeapSize;
		} catch (e : Dynamic) {
			untyped console.log("Warning! performance.memory.totalJSHeapSize is not implemented in this target");
			return 0;
		}
	}

	// TODO : Implement native for performance.measureUserAgentSpecificMemory() as well, when it will be supported by browsers.

	public static function createWindowSnapshot() : Dynamic {
		var snapshot = untyped __js__("{
			timestamp: Date.now(),
			properties: new Map(),
			objectCounts: {},
			totalSize: 0
		}");

		untyped __js__("
			// Capture all window properties
			for (var key in window) {
				try {
					var value = window[key];
					var type = typeof value;
					var size = Native.estimateObjectSize(value, new WeakSet(), 0, 2); // Limit depth to avoid infinite recursion

					snapshot.properties.set(key, {
						type: type,
						size: size,
						constructor: value && value.constructor ? value.constructor.name : 'unknown',
						isArray: Array.isArray(value),
						length: value && value.length !== undefined ? value.length : -1
					});

					snapshot.totalSize += size;
					snapshot.objectCounts[type] = (snapshot.objectCounts[type] || 0) + 1;
				} catch (e) {
					// Some properties might not be accessible
					snapshot.properties.set(key, { error: e.message });
				}
			}
		");

		return snapshot;
	}

	public static function estimateObjectSize(obj : Dynamic, visited : Dynamic, currentDepth : Int, maxDepth : Int) : Int {
		var size = 0;
		untyped __js__("
			if (currentDepth > maxDepth || visited.has(obj)) return 0;

			var type = typeof obj;

			if (type === 'boolean') return 4;
			if (type === 'number') return 8;
			if (type === 'string') return obj.length * 2;
			if (obj === null || obj === undefined) return 0;

			if (type === 'object') {
				visited.add(obj);

				// Count property names
				for (var key in obj) {
					size += key.length * 2; // Property name size
					try {
						size += Native.estimateObjectSize(obj[key], visited, currentDepth + 1, maxDepth);
					} catch (e) {
						// Skip inaccessible properties
					}
				}
			}
		");
		return size;
	}

	public static function compareWindowSnapshots(beforeSnapshot : Dynamic, afterSnapshot : Dynamic) : Dynamic {
		var diff = untyped __js__("{
			newProperties: [],
			changedProperties: [],
			sizeDifferences: [],
			totalSizeChange: afterSnapshot.totalSize - beforeSnapshot.totalSize
		}");

		untyped __js__("
			// Find new properties and changed properties
			for (var entry of afterSnapshot.properties) {
				var key = entry[0];
				var afterValue = entry[1];

				if (!beforeSnapshot.properties.has(key)) {
					diff.newProperties.push(Object.assign({ key: key }, afterValue));
				} else {
					var beforeValue = beforeSnapshot.properties.get(key);
					var sizeChange = afterValue.size - beforeValue.size;

					if (sizeChange !== 0) {
						diff.changedProperties.push({
							key: key,
							sizeBefore: beforeValue.size,
							sizeAfter: afterValue.size,
							sizeChange: sizeChange,
							typeBefore: beforeValue.type,
							typeAfter: afterValue.type
						});
					}
				}
			}

			// Sort by size change (largest first)
			diff.changedProperties.sort(function(a, b) { return Math.abs(b.sizeChange) - Math.abs(a.sizeChange); });
			diff.newProperties.sort(function(a, b) { return b.size - a.size; });

			// Add summary information needed by printMemoryLeakReport
			diff.summary = {
				totalSizeChange: diff.totalSizeChange,
				newPropertiesCount: diff.newProperties.length,
				changedPropertiesCount: diff.changedProperties.length,
				significantChanges: diff.changedProperties.filter(function(p) {
					return Math.abs(p.sizeChange) > 1000; // Changes > 1KB
				}),
				topNewProperties: diff.newProperties.slice(0, 10),
				topChangedProperties: diff.changedProperties.slice(0, 10)
			};
		");

		return diff;
	}

	public static function detectWindowMemoryLeaks() : Dynamic {
		return untyped __js__("
			var snapshot1 = Native.createWindowSnapshot();

			return {
				takeInitialSnapshot: function() {
					snapshot1 = Native.createWindowSnapshot();
					return snapshot1;
				},

				compareCurrent: function() {
					var snapshot2 = Native.createWindowSnapshot();
					var diff = Native.compareWindowSnapshots(snapshot1, snapshot2);

					// Add summary information
					diff.summary = {
						totalSizeChange: diff.totalSizeChange,
						newPropertiesCount: diff.newProperties.length,
						changedPropertiesCount: diff.changedProperties.length,
						significantChanges: diff.changedProperties.filter(function(p) {
							return Math.abs(p.sizeChange) > 1000; // Changes > 1KB
						}),
						topNewProperties: diff.newProperties.slice(0, 10),
						topChangedProperties: diff.changedProperties.slice(0, 10)
					};

					return diff;
				},

				getFlowSpecificChanges: function() {
					var snapshot2 = Native.createWindowSnapshot();
					var flowChanges = [];
					var flowPatterns = [
						/^(Flow|Haxe|Material|RenderSupport|Native)/,
						/Manager$/,
						/Behaviour$/,
						/Transform$/,
						/^M[A-Z]/, // Material components
						/_struct/,
						/_id$/
					];

					for (var entry of snapshot2.properties) {
						var key = entry[0];
						var afterValue = entry[1];
						var isFlowRelated = flowPatterns.some(function(pattern) { return pattern.test(key); });

						if (isFlowRelated) {
							var beforeValue = snapshot1.properties.get(key);
							if (!beforeValue) {
								flowChanges.push(Object.assign({
									type: 'NEW',
									key: key
								}, afterValue));
							} else if (beforeValue.size !== afterValue.size) {
								flowChanges.push({
									type: 'CHANGED',
									key: key,
									sizeBefore: beforeValue.size,
									sizeAfter: afterValue.size,
									sizeChange: afterValue.size - beforeValue.size
								});
							}
						}
					}

					return flowChanges.sort(function(a, b) {
						var aSize = a.sizeChange || a.size || 0;
						var bSize = b.sizeChange || b.size || 0;
						return Math.abs(bSize) - Math.abs(aSize);
					});
				},

				categorizeWindowObjects: function() {
					var snapshot = Native.createWindowSnapshot();
					var categories = {
						functions: [],
						objects: [],
						arrays: [],
						domElements: [],
						eventListeners: [],
						timers: [],
						flowObjects: [],
						other: []
					};

					for (var entry of snapshot.properties) {
						var key = entry[0];
						var value = entry[1];
						var item = { key: key, size: value.size, type: value.type };

						try {
							var actualValue = window[key];
							if (typeof actualValue === 'function') {
								categories.functions.push(item);
							} else if (actualValue && actualValue.nodeType) {
								categories.domElements.push(item);
							} else if (Array.isArray(actualValue)) {
								categories.arrays.push(Object.assign(item, { length: actualValue.length }));
							} else if (key.match(/^(Flow|Haxe|RenderSupport|MaterialManager)/)) {
								categories.flowObjects.push(item);
							} else if (key.includes('event') || key.includes('listener')) {
								categories.eventListeners.push(item);
							} else if (key.includes('timer') || key.includes('interval')) {
								categories.timers.push(item);
							} else if (typeof actualValue === 'object' && actualValue !== null) {
								categories.objects.push(item);
							} else {
								categories.other.push(item);
							}
						} catch (e) {
							categories.other.push(item);
						}
					}

					// Sort each category by size
					for (var cat in categories) {
						categories[cat].sort(function(a, b) { return b.size - a.size; });
					}

					return categories;
				}
			};
		");
	}

	public static function printMemoryLeakReport(diff : Dynamic) : Void {
		untyped __js__("
			if (!diff || !diff.summary) {
				console.log('No memory leak data available');
				return;
			}

			console.group('🔍 Memory Leak Analysis Report');

			console.log('📊 Summary:');
			console.log('  Total size change:', Math.round(diff.summary.totalSizeChange / 1024) + 'KB');
			console.log('  New properties:', diff.summary.newPropertiesCount);
			console.log('  Changed properties:', diff.summary.changedPropertiesCount);
			console.log('  Significant changes (>1KB):', diff.summary.significantChanges.length);

			if (diff.summary.topNewProperties.length > 0) {
				console.group('🆕 Top New Properties:');
				diff.summary.topNewProperties.forEach(function(prop) {
					console.log('  ' + prop.key + ':', {
						type: prop.type,
						size: Math.round(prop.size / 1024) + 'KB',
						constructor: prop.constructor
					});
				});
				console.groupEnd();
			}

			if (diff.summary.topChangedProperties.length > 0) {
				console.group('📈 Top Changed Properties:');
				diff.summary.topChangedProperties.forEach(function(prop) {
					console.log('  ' + prop.key + ':', {
						change: (prop.sizeChange > 0 ? '+' : '') + Math.round(prop.sizeChange / 1024) + 'KB',
						before: Math.round(prop.sizeBefore / 1024) + 'KB',
						after: Math.round(prop.sizeAfter / 1024) + 'KB'
					});
				});
				console.groupEnd();
			}

			console.groupEnd();
		");
	}

	public static function createDeepPathSnapshot(rootObject : Dynamic, maxDepth : Int) : Dynamic {
		var snapshot = untyped __js__("{
			timestamp: Date.now(),
			paths: new Map(), // path -> size
			totalSize: 0
		}");

		untyped __js__("
			function traverseObject(obj, currentPath, depth, visited, globalVisited) {
				if (!obj) return 0;

				var objType = typeof obj;
				var currentSize = 0;

				// Base size for primitive types
				if (objType === 'boolean') return 4;
				if (objType === 'number') return 8;
				if (objType === 'string') return obj.length * 2;
				if (objType !== 'object' || obj === null) return 0;

				// For objects, check if we've seen this exact object before (circular reference)
				if (globalVisited.has(obj)) {
					return 0; // Don't double-count, but this object's size was already counted
				}

				globalVisited.add(obj);

				// Count property names for this object
				for (var key in obj) {
					currentSize += key.length * 2; // Property name overhead
				}

				// If we haven't hit max depth, recurse into properties and track paths
				if (depth < maxDepth) {
					for (var key in obj) {
						try {
							var childObj = obj[key];
							var childPath = currentPath ? currentPath + '.' + key : key;
							var childSize = traverseObject(childObj, childPath, depth + 1, visited, globalVisited);
							currentSize += childSize;

							// Store significant paths for comparison
							if (childSize > 1000) {
								snapshot.paths.set(childPath, childSize);
							}
						} catch (e) {
							// Skip inaccessible properties
						}
					}
				} else {
					// At max depth - estimate remaining size without recursion (like original evaluateObjectSize)
					for (var key in obj) {
						try {
							var childObj = obj[key];
							var childType = typeof childObj;

							if (childType === 'boolean') currentSize += 4;
							else if (childType === 'number') currentSize += 8;
							else if (childType === 'string') currentSize += childObj.length * 2;
							else if (childType === 'object' && childObj !== null && !globalVisited.has(childObj)) {
								// Rough estimate for unexplored objects
								currentSize += 100; // Base object overhead estimate
							}
						} catch (e) {
							// Skip inaccessible properties
						}
					}
				}

				// Store this path's total size if significant
				if (currentSize > 1000 && currentPath) {
					snapshot.paths.set(currentPath, currentSize);
				}

				return currentSize;
			}

			// Start traversal - use the same approach as original evaluateObjectSize
			snapshot.totalSize = traverseObject(rootObject, '', 0, new WeakSet(), new WeakSet());
		");

		return snapshot;
	}

	// Alternative: Use original evaluateObjectSize with path tracking
	public static function createAccuratePathSnapshot(rootObject : Dynamic, maxDepth : Int) : Dynamic {
		var snapshot = untyped __js__("{
			timestamp: Date.now(),
			paths: new Map(),
			totalSize: 0
		}");

		untyped __js__("
			// First get accurate total using the original method
			snapshot.totalSize = Native.evaluateObjectSize(rootObject);

			// Then do path tracking with limited depth for comparison purposes
			function trackPaths(obj, currentPath, depth, visited) {
				if (depth > maxDepth || !obj || typeof obj !== 'object' || obj === null || visited.has(obj)) {
					return;
				}

				visited.add(obj);

				// Calculate size of this specific object path using limited recursion
				var pathSize = Native.estimateObjectSize(obj, new WeakSet(), 0, 2);

				if (pathSize > 1000) {
					snapshot.paths.set(currentPath || 'root', pathSize);
				}

				// Recurse into properties
				for (var key in obj) {
					try {
						var childPath = currentPath ? currentPath + '.' + key : key;
						trackPaths(obj[key], childPath, depth + 1, visited);
					} catch (e) {
						// Skip inaccessible properties
					}
				}
			}

			// Track paths for comparison
			trackPaths(rootObject, '', 0, new WeakSet());
		");

		return snapshot;
	}

	public static function compareDeepPathSnapshots(beforeSnapshot : Dynamic, afterSnapshot : Dynamic) : Dynamic {
		var comparison = untyped __js__("{
			timestamp: Date.now(),
			totalSizeChange: afterSnapshot.totalSize - beforeSnapshot.totalSize,
			pathChanges: [],
			newPaths: [],
			removedPaths: []
		}");

		untyped __js__("
			// Find all unique paths from both snapshots
			var allPaths = new Set();
			beforeSnapshot.paths.forEach((size, path) => allPaths.add(path));
			afterSnapshot.paths.forEach((size, path) => allPaths.add(path));

			// Compare each path
			allPaths.forEach(path => {
				var beforeSize = beforeSnapshot.paths.get(path) || 0;
				var afterSize = afterSnapshot.paths.get(path) || 0;
				var sizeChange = afterSize - beforeSize;

				if (beforeSize === 0 && afterSize > 0) {
					// New path
					comparison.newPaths.push({
						path: path,
						size: afterSize,
						sizeKB: Math.round(afterSize / 1024)
					});
				} else if (afterSize === 0 && beforeSize > 0) {
					// Removed path
					comparison.removedPaths.push({
						path: path,
						size: beforeSize,
						sizeKB: Math.round(beforeSize / 1024)
					});
				} else if (sizeChange !== 0) {
					// Changed path
					comparison.pathChanges.push({
						path: path,
						beforeSize: beforeSize,
						afterSize: afterSize,
						sizeChange: sizeChange,
						sizeChangeKB: Math.round(sizeChange / 1024),
						percentChange: beforeSize > 0 ? Math.round((sizeChange / beforeSize) * 100) : 0
					});
				}
			});

			// Sort by absolute change
			comparison.pathChanges.sort((a, b) => Math.abs(b.sizeChange) - Math.abs(a.sizeChange));
			comparison.newPaths.sort((a, b) => b.size - a.size);
			comparison.removedPaths.sort((a, b) => b.size - a.size);
		");

		return comparison;
	}

	public static function printDeepPathComparison(comparison : Dynamic) : Void {
		untyped __js__("
			console.group('🔍 Deep Path Memory Analysis');

			console.log('📊 Summary:');
			console.log('  Total size change: ' + Math.round(comparison.totalSizeChange / 1024) + 'KB');
			console.log('  Paths with changes: ' + comparison.pathChanges.length);
			console.log('  New paths: ' + comparison.newPaths.length);
			console.log('  Removed paths: ' + comparison.removedPaths.length);

			if (comparison.pathChanges.length > 0) {
				console.group('📈 Top 15 Growing Paths:');
				comparison.pathChanges.slice(0, 15).forEach((change, i) => {
					var changeStr = (change.sizeChange > 0 ? '+' : '') + change.sizeChangeKB + 'KB';
					var percentStr = change.percentChange !== 0 ? ' (' + (change.percentChange > 0 ? '+' : '') + change.percentChange + '%)' : '';
					console.log((i + 1) + '. ' + change.path);
					console.log('    ' + changeStr + percentStr + ' [' + Math.round(change.beforeSize/1024) + 'KB → ' + Math.round(change.afterSize/1024) + 'KB]');
				});
				console.groupEnd();
			}

			if (comparison.newPaths.length > 0) {
				console.group('🆕 Top 10 New Paths:');
				comparison.newPaths.slice(0, 10).forEach((newPath, i) => {
					console.log((i + 1) + '. ' + newPath.path + ': ' + newPath.sizeKB + 'KB');
				});
				console.groupEnd();
			}

			if (comparison.removedPaths.length > 0) {
				console.group('🗑️ Top 10 Removed Paths:');
				comparison.removedPaths.slice(0, 10).forEach((removedPath, i) => {
					console.log((i + 1) + '. ' + removedPath.path + ': ' + removedPath.sizeKB + 'KB');
				});
				console.groupEnd();
			}

			console.groupEnd();
		");
	}

	public static function analyzeFlowMemoryLeaks(beforeSnapshot : Dynamic, afterSnapshot : Dynamic) : Dynamic {
		var flowChanges = untyped __js__("[]");

		untyped __js__("
			var flowPatterns = [
				/^(Flow|Haxe|Material|RenderSupport|Native)/,
				/Manager$/,
				/Behaviour$/,
				/Transform$/,
				/^M[A-Z]/, // Material components
				/_struct/,
				/_id$/
			];

			// Check new properties
			for (var entry of afterSnapshot.properties) {
				var key = entry[0];
				var afterValue = entry[1];
				var isFlowRelated = flowPatterns.some(function(pattern) {
					return pattern.test(key);
				});

				if (isFlowRelated) {
					var beforeValue = beforeSnapshot.properties.get(key);
					if (!beforeValue) {
						flowChanges.push({
							type: 'NEW',
							key: key,
							size: afterValue.size,
							constructor: afterValue.constructor
						});
					} else if (beforeValue.size !== afterValue.size) {
						flowChanges.push({
							type: 'CHANGED',
							key: key,
							sizeChange: afterValue.size - beforeValue.size,
							sizeBefore: beforeValue.size,
							sizeAfter: afterValue.size
						});
					}
				}
			}

			// Sort by impact
			flowChanges.sort(function(a, b) {
				var aSize = a.sizeChange || a.size || 0;
				var bSize = b.sizeChange || b.size || 0;
				return Math.abs(bSize) - Math.abs(aSize);
			});
		");

		return flowChanges;
	}

	public static function createDeepWindowSnapshot() : Dynamic {
		var snapshot = untyped __js__("{
			timestamp: Date.now(),
			properties: new Map(),
			objectCounts: {},
			totalSize: 0
		}");

		untyped __js__("
			// Capture all window properties with NO depth limit (like original evaluateObjectSize)
			for (var key in window) {
				try {
					var value = window[key];
					var type = typeof value;
					var size = Native.estimateObjectSize(value, new WeakSet(), 0, 20); // Much deeper traversal

					snapshot.properties.set(key, {
						type: type,
						size: size,
						constructor: value && value.constructor ? value.constructor.name : 'unknown',
						isArray: Array.isArray(value),
						length: value && value.length !== undefined ? value.length : -1
					});

					snapshot.totalSize += size;
					snapshot.objectCounts[type] = (snapshot.objectCounts[type] || 0) + 1;
				} catch (e) {
					// Some properties might not be accessible
					snapshot.properties.set(key, { error: e.message });
				}
			}
		");

		return snapshot;
	}

	public static function analyzeWindowPropertyGrowth(propertyName : String, beforeSnapshot : Dynamic, afterSnapshot : Dynamic) : Dynamic {
		var result = untyped __js__("{
			propertyName: propertyName,
			beforeSize: 0,
			afterSize: 0,
			sizeChange: 0,
			subProperties: []
		}");

		untyped __js__("
			// Get the property size from snapshots
			var beforeProp = beforeSnapshot.properties.get(propertyName);
			var afterProp = afterSnapshot.properties.get(propertyName);

			if (!beforeProp || !afterProp) {
				console.log('❌ Property ' + propertyName + ' not found in snapshots');
				return result;
			}

			result.beforeSize = beforeProp.size;
			result.afterSize = afterProp.size;
			result.sizeChange = afterProp.size - beforeProp.size;

			// Now analyze the actual object to see what's inside it
			try {
				var obj = window[propertyName];
				if (!obj || typeof obj !== 'object') {
					console.log('⚠️ Property ' + propertyName + ' is not an object, cannot drill down');
					return result;
				}

				console.log('🔍 Analyzing sub-properties of ' + propertyName + ':');
				console.log('   Total change: ' + Math.round(result.sizeChange / 1024) + 'KB');
				console.log('');

				// Get top-level properties of this object
				var subProps = [];
				for (var key in obj) {
					try {
						var subObj = obj[key];
						var subSize = Native.estimateObjectSize(subObj, new WeakSet(), 0, 3);
						subProps.push({
							key: key,
							size: subSize,
							type: typeof subObj,
							constructor: subObj && subObj.constructor ? subObj.constructor.name : 'unknown'
						});
					} catch (e) {
						// Skip inaccessible properties
					}
				}

				// Sort by size (largest first)
				subProps.sort(function(a, b) { return b.size - a.size; });

				// Show top 20 largest sub-properties
				console.log('📊 Top sub-properties by size:');
				subProps.slice(0, 20).forEach(function(prop, i) {
					console.log('  ' + (i+1) + '. ' + prop.key + ': ' +
							   Math.round(prop.size / 1024) + 'KB (' + prop.type + ', ' + prop.constructor + ')');
				});

				result.subProperties = subProps;

			} catch (e) {
				console.error('❌ Error analyzing sub-properties:', e);
			}
		");

		return result;
	}

	public static function findSpecificLeaks() : Dynamic {
		return untyped __js__("{
			// Take before and after snapshots and analyze specific known leak sources
			before: null,
			after: null,

			takeBeforeSnapshot: function() {
				this.before = Native.createDeepWindowSnapshot();
				console.log('📸 Before snapshot taken');
				return this.before;
			},

			takeAfterSnapshot: function() {
				this.after = Native.createDeepWindowSnapshot();
				console.log('📸 After snapshot taken');
				return this.after;
			},

			analyzeLeaks: function() {
				if (!this.before || !this.after) {
					console.log('❌ Need both before and after snapshots. Call takeBeforeSnapshot() first, then takeAfterSnapshot()');
					return;
				}

				console.log('🔍 Analyzing specific leak sources...');
				console.log('');

				// Analyze major properties that commonly leak
				var suspiciousProps = [
					'RenderSupport', 'PIXI', 'MaterialManager', 'FlowFontsManager',
					'Native', 'HaxeRuntime', 'Platform', 'Errors', 'document'
				];

				suspiciousProps.forEach(function(propName) {
					try {
						var analysis = Native.analyzeWindowPropertyGrowth(propName, this.before, this.after);
						if (Math.abs(analysis.sizeChange) > 1000) { // Only show changes > 1KB
							console.log('');
							console.log('🎯 ' + propName + ' grew by ' + Math.round(analysis.sizeChange / 1024) + 'KB');
						}
					} catch (e) {
						// Skip properties that don't exist
					}
				}.bind(this));
			},

			// Analyze DOM-specific leaks
			analyzeDOMLeaks: function() {
				console.log('🔍 Analyzing DOM-specific leaks...');

				try {
					var beforeNodes = this.before ? this.before.properties.get('document') : null;
					var afterNodes = this.after ? this.after.properties.get('document') : null;

					if (beforeNodes && afterNodes) {
						var domGrowth = afterNodes.size - beforeNodes.size;
						console.log('📄 DOM size change: ' + Math.round(domGrowth / 1024) + 'KB');

						// Count actual DOM elements
						var elementCount = document.getElementsByTagName('*').length;
						console.log('🔢 Current DOM elements: ' + elementCount.toLocaleString());

						// Look for common DOM leak patterns
						this.analyzeDOMElements();
					}
				} catch (e) {
					console.error('❌ Error analyzing DOM leaks:', e);
				}
			},

			analyzeDOMElements: function() {
				var tagCounts = {};
				var elements = document.getElementsByTagName('*');

				for (var i = 0; i < elements.length; i++) {
					var tag = elements[i].tagName.toLowerCase();
					tagCounts[tag] = (tagCounts[tag] || 0) + 1;
				}

				// Sort by count
				var sortedTags = Object.keys(tagCounts)
					.map(function(tag) { return {tag: tag, count: tagCounts[tag]}; })
					.sort(function(a, b) { return b.count - a.count; });

				console.log('🏷️ DOM elements by type:');
				sortedTags.slice(0, 10).forEach(function(item) {
					console.log('  ' + item.tag + ': ' + item.count.toLocaleString());
				});
			},

			// Quick workflow: take both snapshots and analyze
			quickAnalysis: function() {
				if (!this.before) {
					console.log('❌ No before snapshot. Taking one now...');
					this.takeBeforeSnapshot();
					console.log('💡 Now perform your operations that cause leaks, then call quickAnalysis() again');
					return;
				}

				this.takeAfterSnapshot();
				this.analyzeLeaks();
				this.analyzeDOMLeaks();
			},

			// Drill deeper into specific objects that showed leaks
			drillDown: function(objectPath) {
				try {
					var obj = window;
					var pathParts = objectPath.split('.');

					for (var i = 0; i < pathParts.length; i++) {
						obj = obj[pathParts[i]];
						if (!obj) {
							console.log('❌ Path not found:', objectPath);
							return;
						}
					}

					console.log('🔍 Drilling down into: ' + objectPath);
					this.analyzeObjectContents(obj, objectPath, 2);

				} catch (e) {
					console.error('❌ Error drilling down into', objectPath + ':', e);
				}
			},

			analyzeObjectContents: function(obj, path, maxDepth) {
				if (maxDepth <= 0 || !obj || typeof obj !== 'object') return;

				var props = [];
				for (var key in obj) {
					try {
						var subObj = obj[key];
						var size = Native.estimateObjectSize(subObj, new WeakSet(), 0, 2);
						props.push({
							key: key,
							size: size,
							type: typeof subObj,
							constructor: subObj && subObj.constructor ? subObj.constructor.name : 'unknown',
							isArray: Array.isArray(subObj),
							length: Array.isArray(subObj) ? subObj.length : -1
						});
					} catch (e) {
						// Skip inaccessible properties
					}
				}

				// Sort by size
				props.sort(function(a, b) { return b.size - a.size; });

				console.log('📊 Contents of ' + path + ':');
				props.slice(0, 15).forEach(function(prop, i) {
					var info = Math.round(prop.size / 1024) + 'KB (' + prop.type;
					if (prop.isArray) info += ', length: ' + prop.length;
					info += ')';
					console.log('  ' + (i+1) + '. ' + prop.key + ': ' + info);
				});
			}
		}");
	}

	/*
Sampe session:

// Get help anytime
Native.memoryLeakHelp();

// Start analysis
Native.memoryLeakStart();
// Output: "📸 Initial snapshot completed! Total memory: 150MB"

// [Navigate your app, create UI elements, trigger suspected leaks]

// Analyze growth
Native.memoryLeakAnalyze();
// Output: "🚨 MEMORY GROWTH DETECTED: +25MB"
//         "📈 Top Changed Properties:"
//         "  1. PIXI.utils.TextureCache: +15MB"
//         "  2. document.head.children: +8MB"

// Get detailed breakdown
Native.memoryLeakDetails();
// Output: "🔥 TOP 10 MEMORY GROWTH LOCATIONS:"
//         "1. 📍 PATH: PIXI.utils.TextureCache"
//         "   📈 GROWTH: +15MB (300%)"
//         "   📝 ARRAY LENGTH: 2,847"
//         "   🔬 SAMPLE TYPES: object, object, object"

// Optional: Monitor ongoing growth
Native.memoryLeakMonitor();
// Output: Monitors top growth paths for 2 minutes

// Reset when done
Native.memoryLeakReset();
	*/
	// ============================================================================
	// CONSOLE MEMORY LEAK ANALYSIS - Easy-to-use functions for browser console
	// ============================================================================
	//
	// USAGE:
	// 1. Native.memoryLeakStart()        - Take initial snapshot
	// 2. [Perform operations that cause leaks in your app]
	// 3. Native.memoryLeakAnalyze()      - Analyze growth and show results
	// 4. Native.memoryLeakMonitor()      - Optional: Monitor ongoing growth
	// 5. Native.memoryLeakHelp()         - Show help and usage instructions
	//
	// EXAMPLE:
	//   Native.memoryLeakStart();
	//   // ... use your app, navigate, create UI elements ...
	//   Native.memoryLeakAnalyze();
	//
	public static function memoryLeakStart() : Void {
		untyped __js__("
			console.log('🔍 MEMORY LEAK ANALYSIS - STARTING');
			console.log('=' + '='.repeat(35));
			console.log('📸 Taking initial snapshot...');
			console.log('⏳ Please wait (this may take 10-20 seconds)...');

			try {
				// Take accurate snapshot
				window._memoryLeakBefore = Native.createAccuratePathSnapshot(window, 5);

				console.log('✅ Initial snapshot completed!');
				console.log('📊 Paths captured:', window._memoryLeakBefore.paths.size);
				console.log('📏 Total memory size:', Math.round(window._memoryLeakBefore.totalSize / 1024 / 1024) + 'MB');
				console.log('🕐 Time:', new Date(window._memoryLeakBefore.timestamp).toLocaleTimeString());
				console.log('');
				console.log('🎯 NOW PERFORM OPERATIONS THAT CAUSE MEMORY LEAKS');
				console.log('   Then call: Native.memoryLeakAnalyze()');

			} catch (e) {
				console.error('❌ Error taking snapshot:', e);
			}
		");
	}

	public static function memoryLeakAnalyze() : Void {
		untyped __js__("
			console.log('📈 MEMORY LEAK ANALYSIS - ANALYZING');
			console.log('=' + '='.repeat(35));

			if (!window._memoryLeakBefore) {
				console.log('❌ No initial snapshot found!');
				console.log('💡 First run: Native.memoryLeakStart()');
				return;
			}

			console.log('📸 Taking final snapshot and comparing...');
			console.log('⏳ Please wait...');

			try {
				// Take after snapshot
				window._memoryLeakAfter = Native.createAccuratePathSnapshot(window, 5);

				console.log('✅ Final snapshot completed!');
				console.log('📊 Paths captured:', window._memoryLeakAfter.paths.size);
				console.log('📏 Total memory size:', Math.round(window._memoryLeakAfter.totalSize / 1024 / 1024) + 'MB');

				// Calculate accurate growth
				var actualGrowth = window._memoryLeakAfter.totalSize - window._memoryLeakBefore.totalSize;
				console.log('');

				if (actualGrowth < 0) {
					console.log('✅ MEMORY DECREASED: ' + Math.round(Math.abs(actualGrowth) / 1024 / 1024) + 'MB');
					console.log('🎉 Memory was freed - this is GOOD news, not a leak!');
					console.log('📊 Freed bytes: ' + Math.abs(actualGrowth).toLocaleString());
					console.log('');
					console.log('💡 No analysis needed - memory is being cleaned up properly.');
					console.log('🔄 Call Native.memoryLeakReset() to start a new analysis.');
					return;
				} else if (actualGrowth < 1000000) { // Less than 1MB growth
					console.log('ℹ️  SMALL GROWTH DETECTED: ' + Math.round(actualGrowth / 1024 / 1024 * 100) / 100 + 'MB');
					console.log('📊 Growth in bytes: ' + actualGrowth.toLocaleString());
					console.log('');
					if (actualGrowth < 100000) { // Less than 100KB
						console.log('✅ This is very small and likely normal app usage.');
						console.log('💡 No detailed analysis needed - this is not a significant leak.');
						console.log('🔄 Call Native.memoryLeakReset() to start fresh if needed.');
						return;
					} else {
						console.log('ℹ️  Growth is small but measurable. Proceeding with light analysis...');
					}
				} else {
					console.log('🚨 SIGNIFICANT MEMORY GROWTH DETECTED: ' + Math.round(actualGrowth / 1024 / 1024) + 'MB');
					console.log('📊 Growth in bytes: ' + actualGrowth.toLocaleString());
					console.log('⚠️  This indicates a potential memory leak!');
				}

				// Compare paths
				var comparison = Native.compareDeepPathSnapshots(window._memoryLeakBefore, window._memoryLeakAfter);
				comparison.totalSizeChange = actualGrowth;
				window._memoryLeakComparison = comparison;

				// Print results
				Native.printDeepPathComparison(comparison);

				console.log('');
				console.log('🎯 DETAILED PATH ANALYSIS:');
				console.log('💡 Call Native.memoryLeakDetails() for detailed investigation');
				console.log('📊 Call Native.memoryLeakMonitor() to monitor ongoing growth');

			} catch (e) {
				console.error('❌ Error during analysis:', e);
			}
		");
	}

	public static function memoryLeakDetails() : Void {
		untyped __js__("
			console.log('🕵️ MEMORY LEAK - DETAILED PATH ANALYSIS');
			console.log('=' + '='.repeat(40));

			if (!window._memoryLeakComparison) {
				console.log('❌ No analysis data found!');
				console.log('💡 Run Native.memoryLeakStart() then Native.memoryLeakAnalyze() first');
				return;
			}

			var comparison = window._memoryLeakComparison;

			if (comparison.pathChanges.length > 0) {
				console.log('🔥 TOP 10 MEMORY GROWTH LOCATIONS:');

				comparison.pathChanges.slice(0, 10).forEach(function(change, i) {
					console.log('\\n' + (i + 1) + '. 📍 PATH: ' + change.path);
					console.log('    📈 GROWTH: ' + (change.sizeChangeKB > 0 ? '+' : '') + change.sizeChangeKB + 'KB (' + change.percentChange + '%)');
					console.log('    📏 SIZE: ' + Math.round(change.beforeSize/1024) + 'KB → ' + Math.round(change.afterSize/1024) + 'KB');

					// Try to inspect the actual object
					try {
						var pathParts = change.path.split('.');
						var obj = window;

						for (var j = 0; j < pathParts.length; j++) {
							var part = pathParts[j];
							if (obj && typeof obj === 'object' && part in obj) {
								obj = obj[part];
							} else {
								obj = null;
								break;
							}
						}

						if (obj !== null) {
							console.log('    🔍 TYPE: ' + typeof obj);
							if (obj.constructor) console.log('    🏗️  CONSTRUCTOR: ' + obj.constructor.name);

							if (Array.isArray(obj)) {
								console.log('    📝 ARRAY LENGTH: ' + obj.length.toLocaleString());
								if (obj.length > 0) {
									var sampleTypes = obj.slice(0, 3).map(function(x) { return typeof x; });
									console.log('    🔬 SAMPLE TYPES: ' + sampleTypes.join(', '));

									// Show sample content for small arrays
									if (obj.length <= 10) {
										console.log('    📄 CONTENT: ' + obj.slice(0, 5).map(function(x) {
											return typeof x === 'string' ? '\"' + x.substring(0, 20) + '\"' : String(x).substring(0, 20);
										}).join(', '));
									}
								}
							} else if (typeof obj === 'object' && obj !== null) {
								var keys = Object.keys(obj);
								console.log('    🔑 PROPERTIES: ' + keys.length.toLocaleString());
								if (keys.length > 0 && keys.length <= 10) {
									console.log('    🏷️  KEYS: ' + keys.join(', '));
								} else if (keys.length > 10) {
									console.log('    🏷️  SAMPLE KEYS: ' + keys.slice(0, 5).join(', ') + ', ...');
								}
							} else if (typeof obj === 'string') {
								console.log('    📄 STRING LENGTH: ' + obj.length.toLocaleString());
								console.log('    👀 PREVIEW: \"' + obj.substring(0, 100) + (obj.length > 100 ? '...' : '') + '\"');
							}
						}
					} catch (e) {
						console.log('    ❌ Cannot analyze: ' + e.message);
					}
				});
			}

			if (comparison.newPaths.length > 0) {
				console.log('\\n🆕 TOP 5 NEW OBJECTS:');
				comparison.newPaths.slice(0, 5).forEach(function(newPath, i) {
					console.log((i + 1) + '. ' + newPath.path + ': ' + newPath.sizeKB + 'KB');
				});
			}

			console.log('\\n💡 TIPS:');
			console.log('• Look for arrays that keep growing (length increasing)');
			console.log('• Check for objects with more properties over time');
			console.log('• Watch for caches that never get cleared');
			console.log('• Strings that keep getting longer indicate text accumulation');
		");
	}

	public static function memoryLeakMonitor() : Void {
		untyped __js__("
			console.log('⏱️ MEMORY LEAK - CONTINUOUS MONITORING');
			console.log('=' + '='.repeat(40));

			if (!window._memoryLeakComparison || !window._memoryLeakComparison.pathChanges.length) {
				console.log('❌ No growth paths to monitor!');
				console.log('💡 Run Native.memoryLeakStart() and Native.memoryLeakAnalyze() first');
				return;
			}

			// Get top growing paths to monitor
			var topPaths = window._memoryLeakComparison.pathChanges.slice(0, 5).map(function(c) { return c.path; });

			console.log('🎯 Monitoring these paths for continued growth:');
			topPaths.forEach(function(path, i) {
				console.log((i + 1) + '. ' + path);
			});

			// Store initial sizes for monitoring
			var initialSizes = new Map();

			topPaths.forEach(function(path) {
				try {
					var pathParts = path.split('.');
					var obj = window;

					for (var i = 0; i < pathParts.length; i++) {
						var part = pathParts[i];
						if (obj && typeof obj === 'object' && part in obj) {
							obj = obj[part];
						} else {
							obj = null;
							break;
						}
					}

					if (obj !== null) {
						var size = Native.estimateObjectSize(obj, new WeakSet(), 0, 2);
						initialSizes.set(path, size);
					}
				} catch (e) {
					console.log('Cannot monitor ' + path + ': ' + e.message);
				}
			});

			console.log('✅ Monitoring started - checking every 10 seconds');
			console.log('⏹️  Will stop automatically after 2 minutes');
			console.log('🛑 Or stop manually with: clearInterval(' + 'window._memoryMonitorId' + ')');

			var checkCount = 0;
			var maxChecks = 12; // 2 minutes

			window._memoryMonitorId = setInterval(function() {
				checkCount++;
				var anyChanges = false;

				console.log('\\n📊 Monitor Check #' + checkCount + ':');

				initialSizes.forEach(function(initialSize, path) {
					try {
						var pathParts = path.split('.');
						var obj = window;

						for (var i = 0; i < pathParts.length; i++) {
							var part = pathParts[i];
							if (obj && typeof obj === 'object' && part in obj) {
								obj = obj[part];
							} else {
								obj = null;
								break;
							}
						}

						if (obj !== null) {
							var currentSize = Native.estimateObjectSize(obj, new WeakSet(), 0, 2);
							var growth = currentSize - initialSize;

							if (Math.abs(growth) > 10000) { // Report changes > 10KB
								console.log('  📈 ' + path + ': ' + (growth > 0 ? '+' : '') + Math.round(growth/1024) + 'KB');
								anyChanges = true;

								// Update initial size for next comparison
								initialSizes.set(path, currentSize);
							}
						}
					} catch (e) {
						// Skip errors
					}
				});

				if (!anyChanges) {
					console.log('  ✅ No significant changes detected');
				}

				if (checkCount >= maxChecks) {
					clearInterval(window._memoryMonitorId);
					console.log('\\n⏹️ Monitoring stopped after 2 minutes');
					delete window._memoryMonitorId;
				}
			}, 10000);
		");
	}

	public static function memoryLeakReset() : Void {
		untyped __js__("
			console.log('🗑️ MEMORY LEAK ANALYSIS - RESET');
			console.log('=' + '='.repeat(30));

			// Clear stored data
			delete window._memoryLeakBefore;
			delete window._memoryLeakAfter;
			delete window._memoryLeakComparison;

			// Stop monitoring if running
			if (window._memoryMonitorId) {
				clearInterval(window._memoryMonitorId);
				delete window._memoryMonitorId;
				console.log('⏹️ Stopped monitoring');
			}

			console.log('✅ Analysis data cleared');
			console.log('💡 Ready for new analysis - call Native.memoryLeakStart()');
		");
	}

	public static function memoryLeakHelp() : Void {
		untyped __js__("
			console.log('❓ MEMORY LEAK ANALYSIS - HELP & USAGE');
			console.log('=' + '='.repeat(40));
			console.log('');
			console.log('🎯 BASIC USAGE (4 simple steps):');
			console.log('  1. Native.memoryLeakStart()     - Take initial snapshot');
			console.log('  2. [Use your app - navigate, create UI, etc.]');
			console.log('  3. Native.memoryLeakAnalyze()   - Find what grew');
			console.log('  4. Native.memoryLeakDetails()   - See detailed analysis');
			console.log('');
			console.log('📊 AVAILABLE FUNCTIONS:');
			console.log('  Native.memoryLeakStart()        - Begin analysis (takes snapshot)');
			console.log('  Native.memoryLeakAnalyze()      - Compare & find memory growth');
			console.log('  Native.memoryLeakDetails()      - Detailed breakdown of growth');
			console.log('  Native.memoryLeakMonitor()      - Monitor ongoing growth (2 min)');
			console.log('  Native.memoryLeakReset()        - Clear data & start fresh');
			console.log('  Native.memoryLeakHelp()         - Show this help');
			console.log('');
			console.log('💡 EXAMPLE WORKFLOW:');
			console.log('  > Native.memoryLeakStart()');
			console.log('  📸 Initial snapshot taken...');
			console.log('  [Navigate your app, trigger suspected leak]');
			console.log('  > Native.memoryLeakAnalyze()');
			console.log('  📈 Shows: \"PIXI.utils.TextureCache grew +45MB\"');
			console.log('  > Native.memoryLeakDetails()');
			console.log('  🔍 Shows: \"Array length: 1,234 textures\"');
			console.log('');
			console.log('🎯 WHAT TO LOOK FOR:');
			console.log('  • Arrays that keep getting longer');
			console.log('  • Objects with more properties over time');
			console.log('  • Caches that never get cleared');
			console.log('  • Strings that keep growing');
			console.log('  • Texture/image data accumulating');
			console.log('');
			console.log('⚡ QUICK CHECK - Current memory:');
			console.log('  Total: ' + Math.round(Native.evaluateObjectSize(window) / 1024 / 1024) + 'MB');
			console.log('  PIXI textures: ' + Object.keys(PIXI.utils.TextureCache).length);
			console.log('  DOM elements: ' + document.querySelectorAll('*').length.toLocaleString());
		");
	}

	public static function analyzeStyleElementsLeak() : Void {
		untyped __js__("
			console.log('🎨 Analyzing Style Elements Leak:');
			console.log('');

			var styleElements = document.querySelectorAll('style');
			console.log('📊 Total <style> elements: ' + styleElements.length);

			if (styleElements.length > 20) {
				console.log('⚠️  WARNING: ' + styleElements.length + ' style elements is excessive!');
				console.log('   This suggests CSS is being added without cleanup.');
				console.log('');
			}

			// Analyze style content
			var totalStyleContent = 0;
			var styleSources = {};
			var duplicateStyles = 0;
			var seenContent = new Set();

			for (var i = 0; i < Math.min(styleElements.length, 50); i++) {
				var style = styleElements[i];
				var content = style.textContent || style.innerHTML || '';
				var contentLength = content.length;
				totalStyleContent += contentLength;

				// Check for duplicates
				if (seenContent.has(content) && content.length > 10) {
					duplicateStyles++;
				}
				seenContent.add(content);

				// Try to identify source
				var source = 'unknown';
				if (content.includes('pixi')) source = 'PIXI';
				else if (content.includes('material') || content.includes('Material')) source = 'Material';
				else if (content.includes('flow') || content.includes('Flow')) source = 'Flow';
				else if (content.includes('font')) source = 'Font';
				else if (content.length < 100) source = 'small';
				else source = 'large';

				styleSources[source] = (styleSources[source] || 0) + 1;

				// Show first few for inspection
				if (i < 5) {
					console.log('Style ' + (i+1) + ': ' + contentLength + ' chars, source: ' + source);
					if (contentLength < 200) {
						console.log('   Content: ' + content.substring(0, 100) + (content.length > 100 ? '...' : ''));
					}
				}
			}

			console.log('');
			console.log('📈 Style Statistics:');
			console.log('   Total style content: ' + Math.round(totalStyleContent / 1024) + 'KB');
			console.log('   Duplicate styles: ' + duplicateStyles);
			console.log('   Average size per style: ' + Math.round(totalStyleContent / styleElements.length) + ' chars');

			console.log('');
			console.log('🏷️  Style sources:');
			Object.keys(styleSources).forEach(function(source) {
				console.log('   ' + source + ': ' + styleSources[source] + ' elements');
			});

			// Recommendations
			console.log('');
			console.log('💡 Recommendations:');
			if (styleElements.length > 50) {
				console.log('   🔴 CRITICAL: ' + styleElements.length + ' style elements indicates a severe CSS leak');
				console.log('   🔧 Check for: CSS being added on every render/update cycle');
			}
			if (duplicateStyles > 5) {
				console.log('   🟡 ' + duplicateStyles + ' duplicate styles - check for redundant CSS insertion');
			}
			if (styleSources.PIXI > 10) {
				console.log('   🎯 PIXI styles: ' + styleSources.PIXI + ' - check PIXI CSS generation');
			}
		");
	}

#end

	private static function copyAction(textArea : Dynamic) {
		#if (js && !flow_nodejs)
			try {
				untyped textArea.select();
				var successful = Browser.document.execCommand('copy');
				if (!successful) Errors.warning('Browser "copy" command execution was unsuccessful');
			} catch (err : Dynamic) {
				Errors.report('Oops, unable to copy');
			}
		#end
	}

	public static function setClipboard(text: String) : Void {
		#if flash
			flash.system.System.setClipboard(text);
		#elseif (js && !flow_nodejs)
			// save current focus
			var focusedElement = Browser.document.activeElement;

			if (untyped Browser.window.clipboardData && untyped Browser.window.clipboardData.setData) { // IE
				untyped Browser.window.clipboardData.setData('Text', text);
			} else if (untyped Browser.navigator.clipboard && untyped Browser.navigator.clipboard.writeText) { // Chrome Async Clipboard API
				untyped Browser.navigator.clipboard.writeText(text);
			} else {
				var textArea = createInvisibleTextArea();
				untyped textArea.value = text;

				// see https://trello.com/c/rBuXiyWM/194-text-form-content-copypaste-doesnt-work-in-some-cases
				if (text.length < 10000 ) {
					copyAction(textArea);
					Browser.document.body.removeChild(textArea);
				} else {
					untyped setTimeout(function () {
						copyAction(textArea);
						Browser.document.body.removeChild(textArea);
					}, 0);
				}
			}

			// restore focus to the previous state
			focusedElement.focus();

			// If paste command fails in getClipboard()
			// we still have consistent value from here
			clipboardData = text;
		#end
	}

	public static var clipboardData = "";
	public static var clipboardDataHtml = "";

	public static function getClipboard() : String {
		#if (js && !flow_nodejs)
			if (untyped Browser.window.clipboardData && untyped Browser.window.clipboardData.getData) { // IE
				return untyped Browser.window.clipboardData.getData("Text");
			}

			if (isNew) {
				return clipboardData;
			}

			// save current focus
			var focusedElement = Browser.document.activeElement;

			var result = clipboardData;

			var textArea = createInvisibleTextArea();
			untyped textArea.value = '';
			untyped textArea.select();

			try {
				#if js
				untyped __js__("
					if (typeof RenderSupport !== 'undefined') {
						RenderSupport.disablePasteEventListener();
					}
				");
				#end

				var successful = Browser.document.execCommand('paste');

				if (successful) {
					result = untyped textArea.value;
				} else {
					Errors.warning('Browser "paste" command execution was unsuccessful');
				}
			} catch (err : Dynamic) {
				Errors.report('Oops, unable to paste');
			}

			#if js
			untyped __js__("
				if (typeof RenderSupport !== 'undefined') {
					RenderSupport.enablePasteEventListener();
				}
			");
			#end

			Browser.document.body.removeChild(textArea);

			// restore focus to the previous state
			untyped __js__("
				if (typeof RenderSupport !== 'undefined') {
					RenderSupport.deferUntilRender(function() {
						focusedElement.focus();
					});
				} else {
					focusedElement.focus();
				}
			");
			return result;
		#else
			return "";
		#end
	}

	public static function getClipboardToCB(callback : String->Void) : Void {
		#if (js && !flow_nodejs)
			if (untyped Browser.window.clipboardData && untyped Browser.window.clipboardData.getData) { // IE
				callback(untyped Browser.window.clipboardData.getData("Text"));
			} else if (untyped navigator.clipboard && untyped navigator.clipboard.readText) {
				untyped navigator.clipboard.readText().then(callback, function(e){
					Errors.print(e);
				});
			} else {
				callback(clipboardData);
			}
		#else
			callback("");
		#end
	}

	public static function setCurrentDirectory(path : String) : Void {
		// do nothing
	}

	public static function getCurrentDirectory() : String {
		return "";
	}

	public static function getClipboardFormat(mimetype: String) : String {
		if (mimetype == "html" || mimetype == "text/html") return clipboardDataHtml;
		else return "";
	}

	public static function getApplicationPath() : String {
		return "";
	}

	public static function getApplicationArguments() : Array<String> {
		return new Array();
	}

	public static inline function toString(value : Dynamic, ?keepStringEscapes : Bool = false) : String {
		return HaxeRuntime.toString(value, keepStringEscapes);
	}

	public static function toStringForJson(value : String) : String {
		return HaxeRuntime.toStringForJson(value);
	}

	public static inline function gc() : Void {
		#if flash
			// unsupported technique that seems to force garbage collection
			// try {
			//	new flash.net.LocalConnection().connect('foo');
			//	new flash.net.LocalConnection().connect('foo');
			// } catch (e:Dynamic) {}
			flash.system.System.pauseForGCIfCollectionImminent(0.1);
		#end
		// NOP
	}

	public static inline function addHttpHeader(data: String) : Void {
		#if (flow_nodejs && flow_webmodule)
		var headerParts  = data.split(": ");
		if (headerParts.length == 2) {
			untyped response.set(headerParts[0], headerParts[1]);
		}
		#end
	}

	public static inline function getCgiParameter(name: String) : String {
		// NOP
		return "";
	}

	public static inline function subrange<T>(arr : Array<T>, start : Int, len : Int) : Array<T> {
		if (start < 0 || len < 1)
			return [];
		else
			return arr.slice(start, start + len);
	}

	public static inline function removeIndex<T>(src : Vector<T>, index : Int) : Vector<T> {
		if (index >= 0 && index < src.length) {
			var dst = new Vector(src.length - 1);
			var i = 0;

			while (i < index) {
				dst[i] = src[i];
				i++;
			}
			while (i < dst.length) {
				dst[i] = src[i + 1];
				i++;
			}

			return dst;
		} else {
			return src;
		}
	}

	public static function isArray(a : Dynamic) : Bool {
		return HaxeRuntime.isArray(a);
	}

	public static function isSameStructType(a : Dynamic, b : Dynamic) : Bool {
		return HaxeRuntime.isSameStructType(a,b);
	}

	public static function isSameObj(a : Dynamic, b : Dynamic) : Bool {
	#if js
		if (a == b)
			return true;
		// TODO: fix js generator so that fieldless structs have only one instance
		#if (readable)
		if (a != null && b != null &&
			Reflect.hasField(a, "_name") && a._name == b._name &&
			HaxeRuntime._structargs_.get(HaxeRuntime._structids_.get(a._name)).length == 0)
			return true;
		#elseif (namespace)
		if (a != null && b != null &&
			Reflect.hasField(a, "kind") && a.kind == b.kind &&
			HaxeRuntime._structargs_.get(a.kind).length == 0)
			return true;
		#else
		if (a != null && b != null &&
			Reflect.hasField(a, "_id") && a._id == b._id &&
			HaxeRuntime._structargs_.get(a._id).length == 0)
			return true;
		#end
		return false;
	#else
		return a == b;
	#end
	}

	#if !js
	public static inline function length<T>(arr : Array<T>) : Int {
		return arr.length;
	}
	#else
	// Notice: We have to rename because .length is a reserved property on functions! This is a haXe bug
	public static inline function length__<T>(arr : Array<T>) : Int {
		return arr.length;
	}
	#end

	public static function strSplit(str : String, separator : String) : Array<String> {
		return str.split(separator);
	}

	public static inline function strlen(s : String) : Int {
		return s.length;
	}

	public static inline function strIndexOf(str : String, substr : String) : Int {
		return str.indexOf(substr, 0);
	}

	public static inline function strRangeIndexOf(str : String, substr : String, start : Int, end : Int) : Int {
		/*
		  Searching within a range suggest that we can stop searching inside long string after end position.
		  This makes searching a bit faster. But JavaScript has no means for this.
		  We have only way to do this - make a copy of string within the range and search there.
		  It is significantly faster for a long string comparing to simple `indexOf()` for whole string.
		  But copying is not free. Since copy is linear in general and search is linear in general too,
		  we can select method depending on source string length and range width.
		*/

		if (str == "" || start < 0)
			return -1;

		var s = start;
		var e = (end > str.length || end < 0) ? str.length : end;

		if (substr.length == 0) {
			return 0;
		} else if (substr.length > e - s) {
			return -1;
		}
		if (2*(e-s) < str.length - s) {
			if (end >= str.length) return str.indexOf(substr, start);
			var rv = str.substr(start, end-start).indexOf(substr, 0);
			return (rv < 0) ? rv : start+rv;
		} else {
			var pos = str.indexOf(substr, s);
			var finish = pos + substr.length - 1;
			return (pos < 0) ? -1 : (finish < e ? pos : -1);
		}
	}

	public static inline function substring(str : String, start : Int, end : Int) : String {
		var s = str.substr((start), (end));
		#if js
		// It turns out that Chrome does NOT copy strings out when doing substring,
		// and thus we never free the original string
		if (2 * s.length < str.length) {
			// So if our slice is "small", we explicitly force a copy like this
			return untyped (' ' + s).slice(1);
		} else {
			return s;
		}
		#else
		return s;
		#end
	}

	public static inline function cloneString(str : String) : String {
		#if js
		return untyped (' ' + str).slice(1);
		#else
		return str;
		#end
	}

	public static inline function toLowerCase(str : String) : String {
		return str.toLowerCase();
	}

	public static inline function toUpperCase(str : String) : String {
		return str.toUpperCase();
	}

	#if js
	public static inline function strReplace(str : String, find : String, replace : String) : String {
		return StringTools.replace(str, find, replace);
	}
	#end

	public static function string2utf8(str : String) : Array<Int> {
		var bytes = haxe.io.Bytes.ofString(str);
		var a : Array<Int> = [for (i in 0...bytes.length) bytes.get(i)];
		return a;
	}

	public static function s2a(str : String) : Array<Int> {
		var arr : Array<Int> = new Array();
		for (i in 0...str.length)
			arr.push((str.charCodeAt(i)));

		return arr;
	}

	public static function list2string(h : Dynamic) : String {
		var res : String = "";
		while (Reflect.hasField(h, "head")) {
			var s : String = Std.string(h.head);
			res = s + res;
			h = h.tail;
		}
		return res;
	}

	public static function list2arrayMapi(h : Dynamic, clos : Int -> Dynamic -> Dynamic) : Array<Dynamic> {
		var cnt = 0;
		var p: Dynamic = h;
		while (Reflect.hasField(p, "head")) {
			cnt += 1;
			p = p.tail;
		}
		if (cnt == 0) {
		  return untyped Array(0);
		}
		var result = untyped Array(cnt);

		p = h;
		cnt -= 1;
		while (cnt >= 0) {
			result[cnt] = clos(cnt, p.head);
			cnt -= 1;
			p = p.tail;
		}
		return result;
	}

	public static function list2array(h : Dynamic) : Array<Dynamic> {
		return list2arrayMapi(
			h,
			function(i, li) {
				return li;
			}
		);
	}

	// WARNING: This function does NOT validate that the list has exactly 'count' elements!
	// It assumes the list length matches 'count' and will crash or produce undefined
	// behavior if the list is shorter. The function creates an array of size 'count'
	// and iterates exactly 'count' times, accessing .head/.tail without checking
	// for null/EmptyList. ALWAYS ensure your list length equals 'count' parameter!
	// This is an optimization function - use list2array() for safe conversion when
	// the exact count is unknown.
	public static function list2arrayByCount(h : Dynamic, count : Int) : Array<Dynamic> {
		if (count <= 0) {
		  return untyped Array(0);
		}
		var result = untyped Array(count);
		var cnt = count - 1;
		var p: Dynamic = h;
		while (cnt >= 0) {
			result[cnt] = p.head;
			cnt -= 1;
			p = p.tail;
		}
		return result;
	}

	public static inline function bitXor(a : Int, b : Int) : Int {
		return a ^ b;
	}

	public static inline function bitAnd(a : Int, b : Int) : Int {
		return a & b;
	}

	public static inline function bitOr(a : Int, b : Int) : Int {
		return a | b;
	}

	public static inline function bitUshr(a : Int, b : Int) : Int {
		return a >>> b;
	}

	public static inline function bitShl(a : Int, b : Int) : Int {
		return a << b;
	}


	public static inline function bitNot(a : Int) : Int {
		return ~a;
	}

	public static inline function concat<T>(arr1 : Array<T>, arr2 : Array<T>) : Array<T> {
		return arr1.concat(arr2);
	}

	// Some browsers want concat for arrayPush. Testing shows that IE, Edge & Firefox prefer the slice,
	public static var useConcatForPush : Bool = #if js Platform.isChrome || Platform.isSafari; #else false; #end

	public static function replace<T>(arr : Array<T>, i : Int, v : T) : Array<T> {
		if (arr == null) {
			return new Array();
		} else if (i < 0 || i > arr.length) {
			println("replace: array index is out of bounds: " + toString(i) + " of " + toString(arr.length));
			println(CallStack.toString(CallStack.callStack()));
			return arr;
		} else if (i == arr.length && useConcatForPush) {
			return arr.concat([v]);
		} else {
			var new_arr = arr.slice(0, arr.length);
			new_arr[i] = v;
			return new_arr;
		}
	}

	public static function map<T, U>(values : Array<T>, clos : T -> U) : Array<U> {
		var n = values.length;
		var result = untyped Array(n);
		for (i in 0...n) {
			result[i] = clos(values[i]);
		}
		return result;
	}

	public static function iter<T>(values : Array<T>, clos : T -> Void) : Void {
		for (v in values) {
			clos(v);
		}
	}

	public static function mapi<T, U>(values : Array<T>, clos : Int -> T -> U) : Array<U> {
		var n = values.length;
		var result = untyped Array(n);
		for (i in 0...n) {
			result[i] = clos(i, values[i]);
		}
		return result;
	}

	public static function iteri<T>(values : Array<T>, clos : Int -> T -> Void) : Void {
		var i : Int = 0;
		for (v in values) {
			clos(i, v);
			i++;
		}
	}

	public static function iteriUntil<T>(values : Array<T>, clos : Int -> T -> Bool) : Int {
		var i : Int = 0;
		for (v in values) {
			if (clos(i, v)) {
				return i;
			}
			i++;
		}
		return i;
	}

	public static function fold<T, U>(values : Array<T>, init : U, fn : U -> T -> U) : U {
		for (v in values) {
			init = fn(init, v);
		}
		return init;
	}

	public static function foldi<T, U>(values : Array<T>, init : U, fn : Int -> U -> T -> U) : U {
		var i = 0;
		for (v in values) {
			init = fn(i, init, v);
			i++;
		}
		return init;
	}

	public static function filter<T>(values : Array<T>, clos : T -> Bool) : Array<T> {
		var result = new Array();
		for (v in values) {
			if (clos(v))
				result.push(v);
		}
		return result;
	}

	public static function filtermapi<T>(values : Array<T>, clos : Int -> T -> Dynamic) : Array<T> {
		var result = new Array();
		var n = values.length;
		for (i in 0...n) {
			var v = values[i];
			var maybe = clos(i, v);
			var fields = Reflect.fields(maybe);
			// Check if there is both an _id and a value field of some kind: Then it is some
			if (fields.length == 2) {
				for (f in fields) {
					#if namespace
					// The ID field of a struct is named _id, so skip that one
					if (f != "kind") {
						var val = Reflect.field(maybe, f);
						result.push(val);
					}
					#else
					// The ID field of a struct is named _id, so skip that one
					if (f != "_id") {
						var val = Reflect.field(maybe, f);
						result.push(val);
					}
					#end
				}
			}
		}
		return result;
	}

	public static function mapiM<T>(values : Array<T>, clos : Int -> T -> Dynamic) : Dynamic {
		var result = new Array();
		var n = values.length;
		for (i in 0...n) {
			var v = values[i];
			var maybe = clos(i, v);
			var fields = Reflect.fields(maybe);
			// Check if there is both an _id and a value field of some kind: Then it is Some
			if (fields.length == 2) {
				for (f in fields) {
					// The ID field of a struct is named _id, so skip that one
					if (f != "_id") {
						var val = Reflect.field(maybe, f);
						result.push(val);
					}
				}
			} else {
				return maybe;
			}
		}
		return makeStructValue("Some", [ result ], makeStructValue("IllegalStruct", [], null));
	}

	public static inline function random() : Float {
		return Math.random();
	}

	public static inline function deleteNative(clip : Dynamic) : Void {
		if (untyped clip != null && !clip.destroyed) {
			if (clip.destroy != null) {
				untyped clip.destroy({children: true, texture: true, baseTexture: true});
			}

			if (clip.parent != null && clip.parent.removeChild != null) {
				clip.parent.removeChild(clip);
			}

			if (!Platform.isIE && untyped clip.nativeWidget != null) {
				untyped clip.nativeWidget.style.display = 'none';
			}

			#if js
			untyped __js__("
				if (typeof RenderSupport !== 'undefined' && (clip.nativeWidget != null || clip.accessWidget != null)) {
					RenderSupport.once('drawframe', function() {
						DisplayObjectHelper.deleteNativeWidget(clip);
					});
				}
			");
			#end

			untyped clip.destroyed = true;
		}
	}

	public static function timestamp() : Float {
		return NativeTime.timestamp();
	}

	#if js
	public static function getLocalTimezoneId() : String {
		return new js.lib.intl.DateTimeFormat().resolvedOptions().timeZone;
	}

	public static function getTimezoneTimeString(utcStamp : Float, timezoneId : String, language : String) : String {
		var date = new js.lib.Date(utcStamp);
		var tzName : Dynamic = "short";

		if (timezoneId == "") {
			timezoneId = "UTC";
		}

		var tz : Dynamic = timezoneId;

		return date.toLocaleString(language, { timeZone: tz, timeZoneName: tzName });
	}

	public static function getTimezoneOffset(utcStamp : Float, timezoneId : String) : Float {
		if (timezoneId == "") {
			return 0;
		}
		var tz : Dynamic = timezoneId;

		var stamp;
		try {
			var timeString = new js.lib.Date(utcStamp).toLocaleString("en-us", { timeZone: tz });
			stamp = new js.lib.Date(timeString).getTime();
		} catch (e : Dynamic) {
			return 0;
		}

		var localOffset = new js.lib.Date(utcStamp).getTimezoneOffset();
		return Math.round(Math.round((stamp - utcStamp) / 600) / 100 - localOffset) * 60 * 1000;
	}
	#end

	// native getCurrentDate : () -> [Date] = Native.getCurrentDate;
	public static function getCurrentDate() : Dynamic {
		var date = Date.now();
		return makeStructValue("Date", [ date.getFullYear(), date.getMonth() + 1, date.getDate() ], makeStructValue("IllegalStruct", [], null));
	}

	#if js
	private static var DeferQueue : Array< Void -> Void > = new Array();
	private static var deferTolerance : Int = 250;
	private static var deferActive : Bool = false;
	public static function defer(cb : Void -> Void) : Void {
		var fn = function() {
			var t0 = NativeTime.timestamp();

			// we shouldn't block the thread in JS for long time because it freeze UI
			while (NativeTime.timestamp() - t0 < Native.deferTolerance && DeferQueue.length > 0) {
				var f = DeferQueue.shift();
				f();
			}
			if (DeferQueue.length > 0) {
				untyped __js__("setTimeout(fn, 42);");
			} else {
				Native.deferActive = false;
			}
		}

		if (Native.deferActive) {
			DeferQueue.push(cb);
		} else {
			Native.deferActive = true;
			DeferQueue.push(cb);
			untyped __js__("setTimeout(fn, 0);");
		}
	}
	#end

	public static function setInterval(ms : Int, cb : Void -> Void) : Void -> Void {
		#if !neko
		#if flash
		var cs = haxe.CallStack.callStack();
		#end
		var fn = function() {
			try {
				cb();
			} catch (e : Dynamic) {
				var stackAsString = "n/a";
				#if flash
					stackAsString = Assert.callStackToString(cs);
				#end
				var actualStack = Assert.callStackToString(haxe.CallStack.callStack());
				var crashInfo = e + "\nStack at timer creation:\n" + stackAsString + "\nStack:\n" + actualStack;
				println("FATAL ERROR: timer callback: " + crashInfo);
				Assert.printStack(e);
				Native.callFlowCrashHandlers("[Timer Handler]: " + crashInfo);
			}
		};

		var t = untyped __js__("setInterval(fn, ms);");
		return function() { untyped __js__("clearInterval(t);"); };
		#else
		cb();
		return function() {};
		#end
	}

	public static function interruptibleTimer(ms : Int, cb : Void -> Void) : Void -> Void {
		#if !neko
		#if flash
		var cs = haxe.CallStack.callStack();
		#end
		var fn = function() {
			try {
				cb();
			} catch (e : Dynamic) {
				var stackAsString = "n/a";
				#if flash
					stackAsString = Assert.callStackToString(cs);
				#end
				var actualStack = Assert.callStackToString(haxe.CallStack.callStack());
				var crashInfo = e + "\nStack at timer creation:\n" + stackAsString + "\nStack:\n" + actualStack;
				println("FATAL ERROR: timer callback: " + crashInfo);
				Assert.printStack(e);
				Native.callFlowCrashHandlers("[Timer Handler]: " + crashInfo);
			}
		};

		#if js
		// TO DO : may be the same for all short timers
		if (ms == 0) {
			var alive = true;
			defer(function () {if (alive) fn(); });
			return function() { alive = false; };
		}
		#end

		var t = untyped __js__("setTimeout(fn, ms);");
		return function() { untyped __js__("clearTimeout(t);"); };
		#else
		cb();
		return function() {};
		#end
	}

	public static function timer(ms : Int, cb : Void -> Void) : Void {
		interruptibleTimer(ms, cb);
	}

	public static inline function sin(a : Float) : Float {
		return Math.sin(a);
	}

	public static inline function asin(a : Float) : Float {
		return Math.asin(a);
	}

	public static inline function acos(a : Float) : Float {
		return Math.acos(a);
	}

	public static inline function atan(a : Float) : Float {
		return Math.atan(a);
	}

	public static inline function atan2(a : Float, b : Float) : Float {
		return Math.atan2(a, b);
	}

	public static inline function exp(a : Float) : Float {
		return Math.exp(a);
	}

	public static inline function log(a : Float) : Float {
		return Math.log(a);
	}

	public static function generate<T>(from : Int, to : Int, fn : Int -> T) : Array<T> {
		var n = to - from;
		if (n <= 0) {
			return untyped Array(0);
		}
		var result = untyped Array(n);
		for (i in 0...n) {
			result[i] = fn(i + from);
		}
		return result;
	}

	public static function enumFromTo(from : Int, to : Int) : Array<Int> {
		var n = to - from + 1;
		if (n <= 0) {
			return untyped Array(0);
		}
		var result = untyped Array(n);
		for (i in 0...n) {
			result[i] = i + from;
		}
		return result;
	}

	public static function getAllUrlParameters() : Array<Array<String>> {
		var parameters : Map<String, String> = new Map();

		#if flash
		var raw = flash.Lib.current.loaderInfo.parameters;
		var keys = Reflect.fields(raw);
		for (key in keys) {
			parameters.set(key, Reflect.field(raw, key));
		}
		#elseif js
			#if (flow_nodejs && flow_webmodule)
			var params : Array<String> = [];
			var parametersMap = {};
			if (untyped request.method == "GET") {
				parametersMap = untyped request.query;
			} else {
				parametersMap = untyped request.body;
			}
			untyped Object.keys(untyped parametersMap).map(function(key, index) {
				params.push(key + "=" + untyped parametersMap[key]);
			});
			#elseif (flow_nodejs)
			var params = process.argv.slice(2);
			#elseif (nwjs)

			// Command line parameters
			var params1 = nw.Gui.app.argv;

			// Query string parameters from url query string (e.g., from the app manifest file - package.json)
			// (first character in search string is "?", so we skip it)
			var paramString2 = js.Browser.window.location.search.substring(1);
			var params2 : Array<String> = paramString2.split("#")[0].split("&");

			var params = params1.concat(params2);

			#else
			var paramString = js.Browser.window.location.search.substring(1);
			var params : Array<String> = paramString.split("&");
			#end
			for (keyvalue in params) {
				var pair = keyvalue.split("=");
				parameters.set(pair[0], (pair.length > 1)? StringTools.urlDecode(pair[1]) : "");
			}
		#end

		var i = 0;
		var result : Array<Array<String>> = new Array<Array<String>>();
		for (key in parameters.keys()) {
			var keyvalue = new Array<String>();
			keyvalue[0] = key;
			keyvalue[1] = parameters.get(key);

			result[i] = keyvalue;
			i++;
		}
		#if (js)
		untyped __js__("if (typeof predefinedBundleParams != 'undefined') {result = mergePredefinedParams(result, predefinedBundleParams);}");
		#end
		  return result;
	}

	public static function getUrlParameter(name : String) : String {
		var value = "";

	#if (js && flow_nodejs && flow_webmodule)
		if (untyped request.method == "GET") {
			value = untyped request.query[name];
		} else if (untyped request.method == "POST") {
			value = untyped request.body[name];
		}
	#else
		value = Util.getParameter(name);
	#end

		return value != null ? value : "";
	}

	#if js
	public static function isTouchScreen() : Bool {
		#if (flow_nodejs || nwjs)
		return false;
		#else
		return Platform.isMobile || untyped __js__("(('ontouchstart' in window) || (window.DocumentTouch && document instanceof DocumentTouch) || window.matchMedia('(pointer: coarse)').matches)");
		#end
	}
	#end

	public static inline function getTargetName() : String {
		#if flash
			return "flash";
		#elseif neko
			return "neko";
		#elseif js
			#if (flow_nodejs && flow_webmodule)
			return "js,nodejs,webmodule";
			#elseif (flow_nodejs && jslibrary)
			return "js,nodejs,jslibrary";
			#elseif flow_nodejs
			return "js,nodejs";
			#elseif nwjs
			return "js,nwjs";
			#elseif jslibrary
			return "js,jslibrary";
			#else
			var testdiv = Browser.document.createElement("div");
			testdiv.style.height = "1in";
			testdiv.style.width = "1in";
			testdiv.style.left = "-100%";
			testdiv.style.top = "-100%";
			testdiv.style.position = "absolute";
			Browser.document.body.appendChild(testdiv);
			var dpi = testdiv.offsetHeight * js.Browser.window.devicePixelRatio;
			Browser.document.body.removeChild(testdiv);
			if (!Platform.isMobile) {
				return "js,pixi,dpi=" + dpi;
			} else {
				return "js,pixi,mobile,dpi=" + dpi;
			}
			#end
		#else
			return "unknown";
		#end
	}

	#if js
	private static function isIE() : Bool {
	#if (flow_nodejs || nwjs)
		return false;
		#else
		return js.Browser.window.navigator.userAgent.indexOf("MSIE") >= 0;
		#end
	}
	#end

	// Save a key/value pair. Persistent on the client.
	public static function setKeyValue(k : String, v : String) : Bool {
		#if js
		return setKeyValueJS(k, v, false);
		#elseif flash
		return setValue(k, v);
		#else
		return false;
		#end
	}

	// Get a stored key/value pair. Persistent on the client
	public static function getKeyValue(key : String, def : String) : String {
		#if js
		return getKeyValueJS(key, def, false);
		#elseif flash
		var value = getValue(key);
		if (value == null) {
			value = def;
		}
		return value;
		#else
		return def;
		#end
	}

	// Removes a stored key/value pair.
	public static function removeKeyValue(key : String) : Void {
		var useMask = StringTools.endsWith(key, "*");
		var mask = "";
		if (useMask) mask = key.substr(0, key.length-1);

		#if js
		removeKeyValueJS(key, false);
		#elseif flash
		try {
			var cookie = getState();
			if (cookie == null) return;
			if (useMask) {
				var arr = Reflect.fields(cookie.data);
				for (i in 0...arr.length)
					if (StringTools.startsWith(arr[i], mask))
						Reflect.deleteField(cookie.data, arr[i]);
			} else {
				Reflect.deleteField(cookie.data, key);
			}
			cookie.flush();
		} catch (e : Dynamic) {}

		#else
		#end
	}

	// Remove all stored key/value pairs.
	public static function removeAllKeyValues() : Void {
		#if js
		removeAllKeyValuesJS(false);
		#else
		return;
		#end
	}

	// Get list of stored keys.
	public static function getKeysList() : Array<String> {
		#if js
		return getKeysListJS(false);
		#else
		return [];
		#end
	}

	// Save a session key/value pair. Persistent on the client for the duration of the session
	public static function setSessionKeyValue(k : String, v : String) : Bool {
		#if js
		return setKeyValueJS(k, v, true);
		#else
		return false;
		#end
	}

	// Save a session key/value pair.
	public static function getSessionKeyValue(key : String, def : String) : String {
		#if js
		return getKeyValueJS(key, def, true);
		#else
		return def;
		#end
	}

	// Removes a session key/value pair.
	public static function removeSessionKeyValue(key : String) : Void {
		#if js
		removeKeyValueJS(key, true);
		#end
	}

	#if flash
	static function getValue(n : String) : String {
		var v : String = null;
		var cookie = getState();
		if (cookie != null) {
			v = Reflect.field(cookie.data, n);
		}
		return v;
	}

	static function setValue(n : String, v : String) : Bool {
		try {
			var cookie = getState();
			if (cookie == null) {
				return false;
			}
			if (!HaxeRuntime.wideStringSafe(v)) {
				// OK, we can not encode this! So better to fail early
				Errors.print("Unsafe string, can not save key: " + n);
				Reflect.deleteField(cookie.data, n);
				return false;
			}
			// Errors.print("Saving " + v.length + " characters");
			Reflect.setField(cookie.data, n, v);
			if (cookie.flush() != flash.net.SharedObjectFlushStatus.PENDING) {
				return true;
			}
			return false;
		} catch (e : Dynamic) {
			return false;
		}
	}

	static function getState() : flash.net.SharedObject {
		if (state != null) {
			return state;
		}
		try {
			state = flash.net.SharedObject.getLocal("flow", "/");
			return state;
		} catch (e : Dynamic) {
			return null;
		}
	}

	static var state : flash.net.SharedObject;
	#end

	#if js
	public static function setKeyValueJS(k : String, v : String, session : Bool) : Bool {
		#if flow_nodejs
//			Errors.report("Cannot set value for key \"" + k + "\"");
			return false;
		#else
		try {
			var storage = session? untyped sessionStorage : untyped localStorage;
			if (isIE())
				untyped storage.setItem(k, StringTools.urlEncode(v));
			else
				untyped storage.setItem(k, v);
			return true;
		} catch (e : Dynamic) {
			Errors.report("Cannot set value for key \"" + k + "\": " + e);
			return false;
		}
		#end
	}

	public static function getKeyValueJS(key : String, def : String, session : Bool) : String {
		#if flow_nodejs
			// Errors.report("Cannot get value for key \"" + key + "\"");
			return def;
		#else
		try {
			var storage = session? untyped sessionStorage : untyped localStorage;
			var value = untyped storage.getItem(key);

			if (null == value) return def;

			if (isIE())
				return StringTools.urlDecode(value);
			else
				return value;
		} catch (e : Dynamic) {
			Errors.report("Cannot get value for key \"" + key + "\": " + e);
			return def;
		}
		#end
	}

	public static function removeKeyValueJS(key : String, session : Bool) : Void {
		#if flow_nodejs
//			Errors.report("Cannot get remove key \"" + key + "\"");
		#else
		var useMask = StringTools.endsWith(key, "*");
		var mask = "";
		if (useMask) mask = key.substr(0, key.length-1);
		try {
			var storage = session? untyped sessionStorage : untyped localStorage;
			if (storage.length == 0) return;
			if (useMask) {
				var nextKey : String;
				for (i in 0...storage.length) {
					nextKey = storage.key(i);
					if (StringTools.startsWith(nextKey, mask))
						storage.removeItem(nextKey);
				}
			} else storage.removeItem(key);
		} catch (e : Dynamic) {
			Errors.report("Cannot remove key \"" + key + "\": " + e);
		}
		#end
	}

	public static function removeAllKeyValuesJS(session : Bool) : Void {
		try {
			var storage = session? untyped sessionStorage : untyped localStorage;
			storage.clear();
		} catch (e : Dynamic) {
			Errors.report("Cannot clear storage: " + e);
		}
	}

	public static function getKeysListJS(session : Bool) : Array<String> {
		try {
			var storage = session? untyped sessionStorage : untyped localStorage;
			return untyped Object.keys(storage);
		} catch (e : Dynamic) {
			Errors.report("Cannot get keys list: " + e);
			return [];
		}
	}
	#end

	public static function clearTrace() : Void {
		// haxe.Log.clear();
	}

	public static function printCallstack() : Void {
		#if js
		untyped __js__("console.trace()");
		#else
		println(Assert.callStackToString(haxe.CallStack.callStack()));
		#end
	}
	public static function captureCallstack() : Dynamic {
		// This is expensive use captureStringCallstack if you really need it
		// return haxe.CallStack.callStack();
		return null;
	}
	public static function callstack2string(c : Dynamic) : String {
		// return Assert.callStackToString(c);
		return "";
	}
	public static function captureStringCallstack() : Dynamic {
		#if js
		return StringTools.replace(StringTools.replace(untyped __js__("new Error().stack"), "    at ", ""), "Error\n", "");
		#else
		return Assert.callStackToString(haxe.CallStack.callStack());
		#end
	}
	public static function captureCallstackItem(index : Int) : Dynamic {
		return null;
	}
	public static function impersonateCallstackItem(item : Dynamic, index : Int) : Void {
		// stub
	}
	public static function impersonateCallstackFn(fn : Dynamic, index : Int) : Void {
		// stub
	}
	public static function impersonateCallstackNone(index : Int) : Void {
		// stub
	}

	public static function failWithError(e : String) : Void {
		throw ("Runtime failure: " + e);
	}

	public static inline function makeStructValue(name : String, args : Array<Dynamic>, default_value : Dynamic) : Dynamic {
		return HaxeRuntime.makeStructValue(name, args, default_value);
	}

	public static function extractStructArguments(value : Dynamic) :  Array<Dynamic> {
		return HaxeRuntime.extractStructArguments(value);
	}

	public static function quit(c : Int) : Void {
#if js
#if ((flow_nodejs && !flow_webmodule) || nwjs)
		process.exit(c);
#elseif (flow_nodejs && flow_webmodule)
		if (untyped response.headersSent == false)
			untyped response.send(webModuleResponseText);
#else
		Browser.window.open("", "_top").close();
#end
#elseif (neko || cpp)
		Sys.exit(c);
#else
		Errors.print("quit called: " + c);
#end
	}

	public static function getFileContent(file : String) : String {
		#if (flash)
		return "";
		#elseif (js && (flow_nodejs || nwjs))
		try {
			var stat = Fs.statSync(file);
			return stat.isFile() ? Fs.readFileSync(file, 'utf8') : "";
		} catch (error : Dynamic) {
			return "";
		}
		#elseif (js)
		return "";
		#else
		return sys.FileSystem.exists(file) ? sys.io.File.getContent(file) : "";
		#end
	}

	public static function getFileContentBinary(file : String) : String {
		throw "Not implemented for this target: getFileContentBinary";
		return "";
	}

	public static function setFileContent(file : String, content : String) : Bool {
		#if (flash || neko)
			Errors.print("setFileContent '" + file + "' does not work in this target. Use the C++ runner");
			return false;
		#elseif (js && (flow_nodejs || nwjs))
			try {
				Fs.writeFileSync(file, content, 'utf8');
			} catch (error : Dynamic) {
				return false;
			}
			return true;
		#elseif js
			Errors.print("setFileContent '" + file + "' does not work in this target. Use the C++ runner");
			return false;
		#else
			try {
				sys.io.File.saveContent(file, content);
			} catch (error : Dynamic) {
				return false;
			}
			return true;
		#end
	}

	public static function setFileContentUTF16(file : String, content : String) : Bool {
		// throw "Not implemented for this target: setFileContentUTF16";
		return false;
	}

	public static function setFileContentBinaryConvertToUTF8(file : String, content : String) : Bool {
		return setFileContentBinaryCommon(file, content, true);
	}

	public static function setFileContentBinary(file : String, content : Dynamic) : Bool {
		return setFileContentBinaryCommon(file, content, false);
	}

	public static function setFileContentBinaryCommon(file : String, content : Dynamic, convertToUTF8 : Bool) : Bool {
		#if (js && (flow_nodejs || nwjs))
			try {
				Fs.writeFileSync(file, new Buffer(content), 'binary');
			} catch (error : Dynamic) {
				return false;
			}
			return true;
		#elseif (js)
			try {
				var a : Dynamic = js.Browser.document.createElement("a");
				a.download = file;
				js.Browser.document.body.appendChild(a);

				if (convertToUTF8 || Util.getParameter("save_file_utf8") == "1") { // Old implementation, Blob converts to UTF-8
					var fileBlob = new js.html.Blob([content], {type : 'application/octet-stream'});
					var url = js.html.URL.createObjectURL(fileBlob);
					a.href = url;
					a.click();

					Native.defer(function() {
						js.html.URL.revokeObjectURL(url);
					});
				} else {
					if (content.startsWith(Util.fromCharCode(0xFEFF))) {
						content = content.substr(1);
					}
					var base64data = Browser.window.btoa(content);
					a.href = 'data:application/octet-stream;base64,' + base64data;
					a.click();
				}
				Native.defer(function() {
					js.Browser.document.body.removeChild(a);
				});

				return true;
			} catch (error : Dynamic) {
				if (convertToUTF8) {
					return false;
				} else {
					return setFileContentBinaryCommon(file, content, true);
				}
			}

		#else
			// throw "Not implemented for this target: setFileContentBinary";
			return false;
		#end
	}

	public static function setFileContentBytes(file : String, content : Dynamic) : Bool {
		return setFileContentBinary(file, content);
	}

	public static function startProcess(command : String, args : Array<String>, cwd : String, stdIn : String, onExit : Int -> String -> String -> Void) : Bool {
		#if (js && (flow_nodejs || nwjs))
			// TODO: Handle stdIn
			ChildProcess.exec(command + " " + args.join(" "), {cwd:cwd}, function(error, stdout:Dynamic, stderr:Dynamic) {
				onExit(error.code, stdout, stderr);
			});
		#else
		// throw "Not implemented for this target: startProcess";
		#end
		return false;
	}

	public static function runProcess(command : String, args : Array<String>, cwd : String, onstdout : String -> Void, onstderr : String -> Void, onExit : Int -> Void) : Bool {
		return false;
	}

	public static function startDetachedProcess(command : String, args : Array<String>, cwd : String) : Bool {
		return false;
	}

	public static function writeProcessStdin(process : Dynamic, arg : String) : Bool {
		return false;
	}

	public static function killProcess(process : Dynamic) : Bool {
		return false;
	}

	// Convert a UTF-32/UCS-4 unicode character code to a string
	//native fromCharCode : (int) -> string = Native.fromCharCode;
	public static inline function fromCharCode(c : Int) : String {
		return Util.fromCharCode((c));
	}

	public static function utc2local(stamp : Float) : Float {
		return NativeTime.utc2local(stamp);
	}

	public static function local2utc(stamp : Float) : Float {
		return NativeTime.local2utc(stamp);
	}

	// Converts string local time representation to time in milliseconds since epoch 1970 in UTC
	public static function string2time(date : String) : Float {
		return NativeTime.string2time(date);
	}

	public static function dayOfWeek(year: Int, month: Int, day: Int) : Int {
		return NativeTime.dayOfWeek(year, month, day);
	}

	// Returns a string representation for the time (time is given in milliseconds since epoch 1970)
	public static function time2string(date : Float) : String {
		return NativeTime.time2string(date);
	}

	public static function getUrl(u : String, t : String) : Void {
		getUrlBasic(u, t);
	}

	public static function getUrlAutoclose(u : String, t : String, delay : Int) : Void {
		getUrlBasic(u, t, delay);
	}

	public static function getUrlBasic(u : String, t : String, ?autoCloseDelay : Int = -1) : Void {
		#if (js && !flow_nodejs)
		try {
			var openedWindow = Browser.window.open(u, t);
			if (autoCloseDelay >= 0) {
				openedWindow.addEventListener('pageshow', function() {
					timer(autoCloseDelay, function() { openedWindow.close(); });
				});
			}
		} catch (e:Dynamic) {
			// Catch exception that tells that window wasn't opened after user chose to stay on page
			if (e != null && e.number != -2147467259) throw e;
		}
		#end
	}

	public static function getUrl2(u : String, t : String) : Bool {
		#if (js && !flow_nodejs)
		try {
			return Browser.window.open(u, t) != null;
		} catch (e:Dynamic) {
			// Catch exception that tells that window wasn't opened after user chose to stay on page
			if (e != null && e.number != -2147467259) throw e;
			else Errors.report(e);
			return false;
		}
		#elseif flash
		flash.Lib.getURL(new flash.net.URLRequest(u), t);
		return true;
		#else
		return false;
		#end
	}

	public static inline function getCharCodeAt(s : String, i : Int) : Int {
		return (s.charCodeAt((i)));
	}

	public static function loaderUrl() : String {
		#if js
		#if (flow_nodejs && flow_webmodule)
		return untyped request.protocol + "://" + untyped request.hostname + untyped request.originalUrl;
		#elseif flow_nodejs
		return "";
		#else
		return Browser.window.location.href;
		#end
		#elseif flash
		return flash.Lib.current.loaderInfo.loaderURL;
		#else
		return "";
		#end
	}

	public static inline function number2double(n : Dynamic) : Float {
		// NOP for this target
		return n;
	}

	// Binary serialization
	#if flash
	private static var doubleBytes : ByteArray;
	#end

	#if js
	private static var doubleToString : Dynamic;
	private static var stringToDouble : Dynamic;
	#end

	public static function stringbytes2double(s : String) : Float {
		#if flash
		doubleBytes.writeShort(s.charCodeAt(0)); doubleBytes.writeShort(s.charCodeAt(1));
		doubleBytes.writeShort(s.charCodeAt(2)); doubleBytes.writeShort(s.charCodeAt(3));
		doubleBytes.position = 0;
		var ret = doubleBytes.readDouble();
		doubleBytes.position = 0;
		return ret;
		#elseif js
		return stringToDouble(s);
		#else
		return 0.0;
		#end
	}

	public static function stringbytes2int(s : String) : Int {
		return s.charCodeAt(0) | (s.charCodeAt(1) << 16);
	}

	private static function initBinarySerialization() : Void {
		#if flash
		// Buffer for serialization of doubles
		doubleBytes = new ByteArray();
		doubleBytes.endian = flash.utils.Endian.LITTLE_ENDIAN;
		#elseif js
		if (untyped __js__("typeof")(ArrayBuffer) == "undefined" ||
				untyped __js__("typeof")(Float64Array) == "undefined") {
			var binaryParser = new BinaryParser(false, false);
			doubleToString = function(value : Float) : String {
				return packDoubleBytes(binaryParser.fromDouble(value));
			}
			stringToDouble = function(str : String) : Float {
				return binaryParser.toDouble(unpackDoubleBytes(str));
			}
		} else {
			var arrayBuffer = untyped __js__ ("new ArrayBuffer(16)");
			var uint16Array = untyped __js__ ("new Uint16Array(arrayBuffer)");
			var float64Array = untyped __js__ ("new Float64Array(arrayBuffer)");
			doubleToString = function(value : Float) : String {
				float64Array[0] = value;
				var ret : StringBuf = new StringBuf();
				ret.addChar(uint16Array[0]); ret.addChar(uint16Array[1]);
				ret.addChar(uint16Array[2]); ret.addChar(uint16Array[3]);
				return ret.toString();
			}
			stringToDouble = function(str : String) : Float {
				uint16Array[0] = str.charCodeAt(0); uint16Array[1] = str.charCodeAt(1);
				uint16Array[2] = str.charCodeAt(2); uint16Array[3] = str.charCodeAt(3);
				return float64Array[0];
			}
		}
		#end
	}

	#if js
	private static function packDoubleBytes(s : String) : String {
		var ret : StringBuf = new StringBuf();
		for ( i in 0...cast( s.length / 2 ) ) {
			ret.addChar(s.charCodeAt(i * 2) | (s.charCodeAt(i * 2 + 1) << 8));
		}
		return ret.toString();
	}

	private static function unpackDoubleBytes(s : String) : String {
		var ret : StringBuf = new StringBuf();
		for (i in 0...s.length) {
			ret.addChar(s.charCodeAt(i) & 0xFF);
			ret.addChar(s.charCodeAt(i) >> 8);
		}
		return ret.toString();
	}
	#end

	public static function __init__() : Void {
		initBinarySerialization();
	}

	private static inline function writeBinaryInt32( value : Int, buf : StringBuf) : Void {
		buf.addChar(value & 0xFFFF);
		buf.addChar(value >> 16);
	}

	public static inline function writeInt(value : Int, buf : StringBuf) : Void {
		if (value & 0xFFFF8000 != 0) {
			buf.addChar(0xFFF5);
			writeBinaryInt32(value, buf);
		} else {
			buf.addChar(value);
		}
	}

	static var structIdxs : Map<Int,Int>; // struct id -> idx in the struct def table in the footer
	static var structDefs : Array< Array<Dynamic> >; // [ [fields count, structname] ]

	private static function writeStructDefs(buf : StringBuf) : Void {
		writeArrayLength(structDefs.length, buf);
		for (struct_def in structDefs) {
			buf.addChar(0xFFF8); buf.addChar(0x0002);
			buf.addChar(struct_def[0]);
			buf.addChar(0xFFFA);
			buf.addChar(struct_def[1].length);
			buf.addSub(struct_def[1], 0);
		}
	}

	private static function writeArrayLength(arr_len: Int, buf: StringBuf) : Void {
		if (arr_len == 0) {
			buf.addChar(0xFFF7);
		} else {
			if ( arr_len > 65535 ) {
				buf.addChar(0xFFF9);
				writeBinaryInt32(arr_len, buf);
			} else {
				buf.addChar(0xFFF8);
				buf.addChar(arr_len);
			}
		}
	}
	private static function writeBinaryValue(value : Dynamic, buf : StringBuf) : Void {
		switch ( HaxeRuntime.typeOf(value) ) {
			case RTVoid:
				buf.addChar(0xFFFF);
			case RTBool:
				buf.addChar( value ? 0xFFFE : 0xFFFD );
			case RTDouble:
				buf.addChar(0xFFFC);
				#if flash
				doubleBytes.writeDouble(value);
				doubleBytes.position = 0;
				buf.addChar(doubleBytes.readShort()); buf.addChar(doubleBytes.readShort());
				buf.addChar(doubleBytes.readShort()); buf.addChar(doubleBytes.readShort());
				doubleBytes.position = 0;
				#elseif js
				buf.addSub(doubleToString(value), 0);
				#end
			case RTString:
				var str_len : Int = value.length;
				if (value.length > 65535) {
					buf.addChar(0xFFFB);
					writeBinaryInt32(str_len, buf);
				} else {
					buf.addChar(0xFFFA);
					buf.addChar(str_len);
				}
				buf.addSub(value, 0);
			case RTArray(t):
				var arr_len = value.length;
				writeArrayLength(arr_len, buf);
				for (i in 0...arr_len ) {
					writeBinaryValue(value[i], buf);
				}
			case RTStruct(n):
			#if (js && readable)
				var struct_id = HaxeRuntime._structids_.get(value._name);
			#elseif namespace
				var struct_id = value.kind;
			#else
				var struct_id = value._id;
			#end
				var struct_fields = HaxeRuntime._structargs_.get(struct_id);
				var field_types = HaxeRuntime._structargtypes_.get(struct_id);
				var fields_count = struct_fields.length;

				var struct_idx = 0;
				if ( structIdxs.exists(struct_id) ) {
					struct_idx = structIdxs.get(struct_id);
				} else {
					struct_idx = structDefs.length;
					structIdxs.set(struct_id, struct_idx);
					structDefs.push([fields_count, HaxeRuntime._structnames_.get(struct_id)]);
				}

				buf.addChar(0xFFF4);
				buf.addChar(struct_idx);

				for (i in 0...fields_count) {
					var field : Dynamic = Reflect.field(value, struct_fields[i]);
					if (field_types[i] == RTInt) {
						writeInt(field, buf);
					} else {
						writeBinaryValue(field, buf);
					}
				}
			case RTRefTo(t):
				buf.addChar(0xFFF6);
				writeBinaryValue( value.__v, buf );
			default:
				throw "Cannot serialize " + value;
		}
	}

	public static function toBinary(value : Dynamic) : String {
		var buf : StringBuf = new StringBuf();
		// Init struct def table
		structIdxs = new Map<Int,Int>();
		structDefs = new Array< Array<Dynamic> >();

		writeBinaryValue(value, buf);
		var str = buf.toString();

		var struct_defs_buf = new StringBuf();
		writeStructDefs(struct_defs_buf);

		var ret = String.fromCharCode((str.length + 2) & 0xFFFF) + String.fromCharCode((str.length + 2) >> 16) + // Offset of structdefs
			str + struct_defs_buf.toString();

		return ret;
	}

	public static function fromBinary(string : Dynamic, defvalue : Dynamic, fixups : Dynamic) : Dynamic {
		#if js
		if (Type.getClass(string) == JSBinflowBuffer) {
			return string.deserialise(defvalue, fixups);
		} else
		#end
		{
			return string;
		}
	}

	public static function getTotalMemoryUsed() : Float {
		#if flash
		return flash.system.System.totalMemory;
		#elseif (js && (flow_nodejs || nwjs))
		return process.memoryUsage().heapUsed;
		#else
		return 0.0;
		#end
	}

	public static function detectDedicatedGPU() : Bool {
		try {
			var canvas = Browser.document.createElement('canvas');
			var gl = untyped __js__("canvas.getContext('webgl') || canvas.getContext('experimental-webgl')");

			if (gl == null) {
				return false;
			}

			var debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
			var vendor = gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL);
			var renderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);

			return renderer.toLowerCase().indexOf("nvidia") >= 0 || renderer.toLowerCase().indexOf("ati") >= 0 || renderer.toLowerCase().indexOf("radeon") >= 0;
		} catch (e : Dynamic) {
			return false;
		}
	}

	public static function domCompleteTiming() : Float {
		try {
			return untyped __js__("window.performance.timing.domComplete - window.performance.timing.domLoading");
		} catch (e : Dynamic) {
			return -1;
		}
	}

	public static function estimateCPUSpeed() : Float {
		#if js
		untyped __js__("
			var _speedconstant = 1.15600e-8;
			var d = new Date();
			var amount = 150000000;
			var estprocessor = 1.7;
			for (var i = amount; i > 0; i--) {}
			var newd = new Date();
			di = (newd.getTime() - d.getTime()) / 1000;
			spd = ((_speedconstant * amount) / di);
			return Math.round(spd * 1000) / 1000;
		");
		#end

		return -1;
	}

	public static function getDeviceMemory() : Float {
		try {
			return untyped __js__("window.navigator.deviceMemory || -1");
		} catch (e : Dynamic) {
			return -1;
		}
	}

	public static function getDevicePlatform() : Float {
		try {
			return untyped __js__("window.navigator.platform || ''");
		} catch (e : Dynamic) {
			return -1;
		}
	}

	private static var FlowCrashHandlers : Array< String -> Void > = new Array< String -> Void>();

	public static function addCrashHandler(cb : String -> Void) : Void -> Void {
		FlowCrashHandlers.push(cb);
		return function() { FlowCrashHandlers.remove(cb); };
	}

	public static function callFlowCrashHandlers(msg : String) : Void {
		msg += "Call stack: " + Assert.callStackToString(haxe.CallStack.exceptionStack());
		for ( hdlr in FlowCrashHandlers.slice(0, FlowCrashHandlers.length) ) hdlr(msg);
	}

	private static var PlatformEventListeners : Map< String, Array<Void -> Bool> > = new Map();
	private static var LastUserAction : Float = -1;
	private static var IdleLimit : Float = 1000.0 * 60.0; // 1 min
	public static function addPlatformEventListener(event : String, cb : Void -> Bool) : Void -> Void {
		#if (js && !flow_nodejs)
			if (event == "online" || event == "offline") {
				var w = Browser.window;
				if (w.addEventListener != null) {
					w.addEventListener(event, cb, false);
					return function() {
						var w = Browser.window;
						if (w.removeEventListener != null) {
							w.removeEventListener(event, cb);
						}
					}
				}
			} else if (event == "suspend") {
				Browser.window.addEventListener("blur", cb);
				Browser.window.addEventListener("pagehide", cb);
				return function() {
					Browser.window.removeEventListener("blur", cb);
					Browser.window.removeEventListener("pagehide", cb);
				};
			} else if (event == "resume") {
				Browser.window.addEventListener("focus", cb);
				Browser.window.addEventListener("pageshow", cb);
				return function() {
					Browser.window.removeEventListener("focus", cb);
					Browser.window.removeEventListener("pageshow", cb);
				};
			} else if (event == "active") {
				var timeoutActiveId = -1;
				var setTimeoutActiveFn = function () {};
				var activeCalled = false;

				setTimeoutActiveFn = function () {
					var timePassedActive = Date.now().getTime() - LastUserAction;

					if (timePassedActive >= IdleLimit) {
						timeoutActiveId = -1;
						activeCalled = false;
					} else {
						timeoutActiveId = untyped __js__("setTimeout(setTimeoutActiveFn, Native.IdleLimit - timePassedActive)");
						if (!activeCalled) {
							activeCalled = true;
							cb();
						}
					}
				};

				var mouseMoveActiveFn = function () {
					LastUserAction = Date.now().getTime();

					if (timeoutActiveId == -1) {
						setTimeoutActiveFn();
					}
				};

				Browser.window.addEventListener("pointermove", mouseMoveActiveFn);
				Browser.window.addEventListener("videoplaying", mouseMoveActiveFn);
				Browser.window.addEventListener("focus", mouseMoveActiveFn);
				Browser.window.addEventListener("blur", mouseMoveActiveFn);

				mouseMoveActiveFn();

				return function() {
					untyped __js__("clearTimeout(timeoutActiveId)");
					Browser.window.removeEventListener("pointermove", mouseMoveActiveFn);
					Browser.window.removeEventListener("videoplaying", mouseMoveActiveFn);
					Browser.window.removeEventListener("focus", mouseMoveActiveFn);
					Browser.window.removeEventListener("blur", mouseMoveActiveFn);
				};
			} else if (event == "idle") {
				var timeoutIdleId = -1;
				var setTimeoutIdleFn = function () {};
				var idleCalled = false;

				setTimeoutIdleFn = function () {
					var timePassedIdle = Date.now().getTime() - LastUserAction;

					if (timePassedIdle >= IdleLimit) {
						timeoutIdleId = -1;
						if (!idleCalled) {
							idleCalled = true;
							cb();
						}
					} else {
						timeoutIdleId = untyped __js__("setTimeout(setTimeoutIdleFn, Native.IdleLimit - timePassedIdle)");
						idleCalled = false;
					}
				};

				var mouseMoveIdleFn = function () {
					LastUserAction = Date.now().getTime();

					if (timeoutIdleId == -1) {
						setTimeoutIdleFn();
					}
				};

				mouseMoveIdleFn();
				Browser.window.addEventListener("pointermove", mouseMoveIdleFn);
				Browser.window.addEventListener("videoplaying", mouseMoveIdleFn);
				Browser.window.addEventListener("focus", mouseMoveIdleFn);
				Browser.window.addEventListener("blur", mouseMoveIdleFn);

				return function() {
					untyped __js__("clearTimeout(timeoutIdleId)");
					Browser.window.removeEventListener("pointermove", mouseMoveIdleFn);
					Browser.window.removeEventListener("videoplaying", mouseMoveIdleFn);
					Browser.window.removeEventListener("focus", mouseMoveIdleFn);
					Browser.window.removeEventListener("blur", mouseMoveIdleFn);
				};
			}
		#end

		if (!PlatformEventListeners.exists(event)) PlatformEventListeners.set(event, new Array());
		PlatformEventListeners[event].push(cb);
		return function() { PlatformEventListeners[event].remove(cb); };
	}

	public static function setUserIdleLimit(ms : Int) : Void {
		IdleLimit = ms;
	}

	public static function notifyPlatformEvent(event : String) : Bool {
		var cancelled = false;
		if (PlatformEventListeners.exists(event))
			for (cb in PlatformEventListeners[event])
				cancelled = cb() || cancelled;
		return cancelled;
	}

	public static function addCameraPhotoEventListener(cb : Int -> String -> String -> Int -> Int -> Void) : Void -> Void {
		// not implemented yet for js/flash
		return function() { };
	}
	public static function addCameraVideoEventListener(cb : Int -> String -> String -> Int -> Int -> Int -> Int -> Void) : Void -> Void {
		// not implemented yet for js/flash
		return function() { };
	}

	public static function md5(content : String) : String {
		return JsMd5.encode(content);
	}

	public static function getCharAt(s : String, i : Int) : String {
		return s.charAt(i);
	}

	#if js
	// we will create flow objects using several "sid"
	// they obtained from HaxeRuntime._structids_ / HaxeRuntime._structargs_
	// so we cache them in order to not make local vars (they would increase load on GC)
	static var sidJsonArray : Int;
	static var sidJsonArrayVal : String;
	static var sidJsonString : Int;
	static var sidJsonStringVal : String;
	static var sidJsonDouble : Int;
	static var sidJsonDoubleVal : String;

	static var jsonBoolTrue : Dynamic;
	static var jsonBoolFalse : Dynamic;
	static var jsonNull : Dynamic;

	static var sidPair : Int;
	static var sidPairFirst : String;
	static var sidPairSecond : String;
	static var sidJsonObject : Int;
	static var sidJsonObjectFields : String;

	static var jsonDoubleZero : Dynamic;
	static var jsonStringEmpty : Dynamic;

	// Chrome and maybe other browsers faster with for(var f in o) that with Object.getOwnPropertyNames
	private static function object2JsonStructsCompacting(o : Dynamic, sDict : Dynamic, jsDict : Dynamic, nDict : Dynamic) : Dynamic {
		untyped __js__("
		if (Array.isArray(o)) {
			var n = o.length;
			var a1 = Array(n);
			for (var i=0; i<n; i++) {
				a1[i] = Native.object2JsonStructs(o[i], sDict, jsDict, nDict);
			}
			var obj = { _id : Native.sidJsonArray };
			obj[Native.sidJsonArrayVal] = a1;
			return obj;
		} else {
			var t = typeof o;
			switch (t) {
				case 'string':
					if (o === '') return Native.jsonStringEmpty;
					var obj = jsDict[o];
					if (obj == undefined) {
						var s = sDict[o];
						if (s === undefined) {
							s = o;
							sDict[o] = s;
						}
						obj = { _id : Native.sidJsonString };
						obj[Native.sidJsonStringVal] = s;
						jsDict[o] = obj;
					}
					return obj;
				case 'number':
					if (o === 0.0) return Native.jsonDoubleZero;
					var obj = nDict[o];
					if (obj === undefined) {
						obj = { _id : Native.sidJsonDouble };
						obj[Native.sidJsonDoubleVal] = o;
						nDict[o] = obj;
					}
					return obj;
				case 'boolean': return o ? Native.jsonBoolTrue : Native.jsonBoolFalse;
				default:
					if(o == null) {
						return Native.jsonNull;
					} else {
						var mappedFields = [];
						for(var f in o) {
							var a2 = Native.object2JsonStructs(o[f], sDict, jsDict, nDict);
							var obj = { _id : Native.sidPair };
							var cf = sDict[f];
							if (cf === undefined) {
								cf = f;
								sDict[f] = cf;
							}
							obj[Native.sidPairFirst] = cf;
							obj[Native.sidPairSecond] = a2;
							mappedFields.push(obj);
						}
						var obj = { _id : Native.sidJsonObject};
						obj[Native.sidJsonObjectFields] = mappedFields;
						return obj;
					}
			}
		}");

		return "";
	}

	// Firefox and maybe other browsers faster with Object.getOwnPropertyNames that with for(var f in o)
	private static function object2JsonStructsCompacting_FF(o : Dynamic, sDict : Dynamic, jsDict : Dynamic, nDict : Dynamic) : Dynamic {
		untyped __js__("
		if (Array.isArray(o)) {
			var n = o.length;
			var a1 = Array(n);
			for (var i=0; i<n; i++) {
				a1[i] = Native.object2JsonStructs_FF(o[i], sDict, jsDict, nDict);
			}
			var obj = { _id : Native.sidJsonArray };
			obj[Native.sidJsonArrayVal] = a1;
			return obj;
		} else {
			var t = typeof o;
			switch (t) {
				case 'string':
					if (o === '') return Native.jsonStringEmpty;
					var obj = jsDict[o];
					if (obj == undefined) {
						var s = sDict[o];
						if (s === undefined) {
							s = o;
							sDict[o] = s;
						}
						obj = { _id : Native.sidJsonString };
						obj[Native.sidJsonStringVal] = s;
						jsDict[o] = obj;
					}
					return obj;
				case 'number':
					if (o === 0.0) return Native.jsonDoubleZero;
					var obj = nDict[o];
					if (obj === undefined) {
						obj = { _id : Native.sidJsonDouble };
						obj[Native.sidJsonDoubleVal] = o;
						nDict[o] = obj;
					}
					return obj;
				case 'boolean': return o ? Native.jsonBoolTrue : Native.jsonBoolFalse;
				default:
					if(o == null) {
						return Native.jsonNull;
					} else {
						var mappedFields = Object.getOwnPropertyNames(o);
						for(var i=0; i< mappedFields.length; i++) {
							var f = mappedFields[i];
							var cf = sDict[f];
							if (cf === undefined) {
								cf = f;
								sDict[f] = cf;
							}

							var a2 = Native.object2JsonStructs_FF(o[f], sDict, jsDict, nDict);
							var obj = { _id : Native.sidPair };
							obj[Native.sidPairFirst] = cf;
							obj[Native.sidPairSecond] = a2;
							mappedFields[i] = obj;
						}
						var obj = { _id : Native.sidJsonObject};
						obj[Native.sidJsonObjectFields] = mappedFields;
						return obj;
					}
			}
		}");

		return "";
	}

	private static function object2JsonStructs(o : Dynamic) : Dynamic {
		untyped __js__("
		if (Array.isArray(o)) {
			var a1 = Native.map(o,Native.object2JsonStructs);
			var obj = { _id : Native.sidJsonArray };
			obj[Native.sidJsonArrayVal] = a1;
			return obj;
		} else {
			var t = typeof o;
			switch (t) {
				case 'string':
					var obj = { _id : Native.sidJsonString };
					obj[Native.sidJsonStringVal] = o;
					return obj;
				case 'number':
					var obj = { _id : Native.sidJsonDouble };
					obj[Native.sidJsonDoubleVal] = o;
					return obj;
				case 'boolean': return o ? Native.jsonBoolTrue : Native.jsonBoolFalse;
				default:
					if(o == null) {
						return Native.jsonNull;
					} else {
						var mappedFields = [];
						for(var f in o) {
							var a2 = Native.object2JsonStructs(o[f]);
							var obj = { _id : Native.sidPair };
							obj[Native.sidPairFirst] = f;
							obj[Native.sidPairSecond] = a2;
							mappedFields.push(obj);
						}
						var obj = { _id : Native.sidJsonObject};
						obj[Native.sidJsonObjectFields] = mappedFields;
						return obj;
					}
			}
		}");

		return "";
	}

	// Firefox and maybe other browsers faster with Object.getOwnPropertyNames that with for(var f in o)
	private static function object2JsonStructs_FF(o : Dynamic) : Dynamic {
		untyped __js__("
		if (Array.isArray(o)) {
			var a1 = Native.map(o,Native.object2JsonStructs_FF);
			var obj = { _id : Native.sidJsonArray};
			obj[Native.sidJsonArrayVal] = a1;
			return obj;
		} else {
			var t = typeof o;
			switch (t) {
				case 'string':
					var obj = { _id : Native.sidJsonString };
					obj[Native.sidJsonStringVal] = o;
					return obj;
				case 'number':
					var obj = { _id : Native.sidJsonDouble };
					obj[Native.sidJsonDoubleVal] = o;
					return obj;
				case 'boolean': return o ? Native.jsonBoolTrue : Native.jsonBoolFalse;
				default:
					if(o == null) {
						return Native.jsonNull;
					} else {
						var mappedFields = Object.getOwnPropertyNames(o);
						for(var i=0; i< mappedFields.length; i++) {
							var f = mappedFields[i];
							var a2 = Native.object2JsonStructs_FF(o[f]);
							var obj = { _id : Native.sidPair };
							obj[Native.sidPairFirst] = f;
							obj[Native.sidPairSecond] = a2;
							mappedFields[i] = obj;
						}
						var obj = { _id : Native.sidJsonObject};
						obj[Native.sidJsonObjectFields] = mappedFields;
						return obj;
					}
			}
		}");

		return "";
	}

	private static var parseJsonFirstCall = true;
	public static function parseJson(json : String) : Dynamic {
		if (parseJsonFirstCall) {
			Native.sidJsonArray = HaxeRuntime._structids_.get("JsonArray");
			Native.sidJsonArrayVal = HaxeRuntime._structargs_.get(Native.sidJsonArray)[0];

			Native.sidJsonString = HaxeRuntime._structids_.get("JsonString");
			Native.sidJsonStringVal = HaxeRuntime._structargs_.get(Native.sidJsonString)[0];

			Native.sidJsonDouble = HaxeRuntime._structids_.get("JsonDouble");
			Native.sidJsonDoubleVal = HaxeRuntime._structargs_.get(Native.sidJsonDouble)[0];

			Native.jsonBoolTrue = HaxeRuntime.fastMakeStructValue("JsonBool", true);
			Native.jsonBoolFalse = HaxeRuntime.fastMakeStructValue("JsonBool", false);

			Native.sidPair = HaxeRuntime._structids_.get("Pair");
			Native.sidPairFirst = HaxeRuntime._structargs_.get(Native.sidPair)[0];
			Native.sidPairSecond = HaxeRuntime._structargs_.get(Native.sidPair)[1];

			Native.sidJsonObject = HaxeRuntime._structids_.get("JsonObject");
			Native.sidJsonObjectFields = HaxeRuntime._structargs_.get(Native.sidJsonObject)[0];

			Native.jsonNull = HaxeRuntime.makeStructValue("JsonNull",[],null);

			Native.jsonDoubleZero =  HaxeRuntime.makeStructValue("JsonDouble", [0.0], null);
			Native.jsonStringEmpty = HaxeRuntime.makeStructValue("JsonString", [""], null);
			parseJsonFirstCall = false;
		}
		if (json == "") return Native.jsonDoubleZero;

		untyped __js__("
			try {
				if (Platform.isIOS && json.length > 1024) {
					// on IOS memory restriction is very tight so we try to not create duplicate strings if possible
					// it might have advantages for quite long parsed string only
					return Platform.isFirefox ?
					Native.object2JsonStructsCompacting_FF(JSON.parse(json), {}, {}, {}) :
					Native.object2JsonStructsCompacting(JSON.parse(json), {}, {}, {});
				} else {
					return Platform.isFirefox ?
					Native.object2JsonStructs_FF(JSON.parse(json)) :
					Native.object2JsonStructs(JSON.parse(json));
				}
			} catch (e) {
				return Native.jsonDoubleZero;
			}
		");
		return Native.jsonDoubleZero;
	}
	#end

	public static function concurrentAsync(fine : Bool, tasks : Array < Void -> Dynamic >, cb : Array < Dynamic >) : Void {
		#if js
		untyped __js__("
var fns = tasks.map(function(c, i, a) {
	var v = function v (callback) {
		var r = c.call();
		callback(null, r);
	}
	return v;
});

async.parallel(fns, function(err, results) { cb(results) });");
		#end
	}

	public static function preloadStaticResource(href : String, as : String) : Void {
		#if (js && !flow_nodejs)
			var tag : Dynamic = js.Browser.document.createElement("link");
			tag.rel = "preload";
			tag.href = href;
			tag.as = as;
			js.Browser.document.head.appendChild(tag);
		#end
	}

	// Days in month lookup table (index 0 unused, 1-12 for Jan-Dec)
	// Optimized: Use static array instead of calculations
	static var daysInMonth: Array<Int> = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

	static inline function isLeapYear(year: Int): Bool {
		return (year & 3) == 0 && (year % 100 != 0 || year % 400 == 0);
	}

	// Get days in month with leap year handling - inlined for performance
	static inline function getDaysInMonth(month: Int, year: Int): Int {
		if (month == 2 && isLeapYear(year)) return 29;
		return daysInMonth[month];
	}

	/**
	 * Parses datetime strings in formats:
	 * - "YYYY-MM-DD HH:MM:SS"
	 * - "YYYY-MM-DDTHH:MM:SS"
	 * - "YYYY-MM-DD" (defaults to 00:00:00)
	 *
	 * Returns nullTime for invalid inputs
	 */
	private static var nullTime = null;
	private static var makeTime = null;
	public static function db2time(s: String): Dynamic {
		if (nullTime == null) {
			var timeSId = HaxeRuntime._structids_.get("Time");
#if (js)
			makeTime = HaxeRuntime._structconstruct_.get(timeSId);
#else
			var timeArgs = HaxeRuntime._structargs_.get(timeSId);
			makeTime = function(year: Int, month: Int, day: Int, hour: Int, min: Int, sec: Int): Dynamic {
				var t = makeEmptyStruct(timeSId);
				t[timeArgs[0]] = year;
				t[timeArgs[1]] = month;
				t[timeArgs[2]] = day;
				t[timeArgs[3]] = hour;
				t[timeArgs[4]] = min;
				t[timeArgs[5]] = sec;
				return t;
			}
#end
			nullTime = makeTime(0, 0, 0, 0, 0, 0);
		}
		if (s == null) return nullTime;

		var len = s.length;
		var pos = 0;
		var nextCode = null;

		inline function isDigit(c:Int):Bool return c >= 48 && c <= 57;
		function readNum():Dynamic {
			var v = 0;
			var any = false;
			var c = null;
			nextCode = null;
			while (pos < len) {
				c = s.charCodeAt(pos); // charCodeAt is faster then charAt
				pos++;
				if (!isDigit(c)) {
					nextCode = c;
					break;
				}
				any = true;
				v = v * 10 + (c - 48);
			}
			return any ? v : null;
		}

		// Year
		var year = readNum();
		if (year == null || year < 1000 || year > 9999) return nullTime;
		if (pos >= len || nextCode != 45) return nullTime; // '-'

		// Month
		var month:Int = readNum();
		if (month == null || month < 1 || month > 12) return nullTime;
		if (nextCode != 45) return nullTime; // '-'

		// Day
		var day:Int = readNum();
		if (day == null || day < 1) return nullTime;
		var maxDays = getDaysInMonth(month, year);
		if (day > maxDays) return nullTime;

		// Date only
		if (pos >= len && nextCode == null) {
			return makeTime(year, month, day, 0, 0, 0);
		}

		if (nextCode != 32 && nextCode != 84) return nullTime; // ' ' or 'T'

		// Hour
		var hour:Int = readNum();
		if (hour == null) return nullTime;
		if (pos >= len || nextCode != 58) return nullTime; // ":"

		// Minute
		var min:Int = readNum();
		if (min == null) return nullTime;
		if (pos >= len || nextCode != 58) return nullTime; // ":"

		// Second (greedy: read all digits; ignore any non-digit tail)
		var sec:Int = readNum();
		if (sec == null) return nullTime;

		if (hour < 0 || hour >= 24) return nullTime;
		if (min  < 0 || min  >= 60) return nullTime;
		if (sec  < 0 || sec  >= 60) return nullTime;
		if (nextCode == 45 || nextCode == 58) return nullTime;

		return makeTime(year, month, day, hour, min, sec);
	}
}
