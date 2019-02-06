// this function extracts memory representation of type from passed value
// for example for 'int' it will return [2], for '[string]' -> [9, 4] etc.
function extractTagsFromValue(value) {
	var isInt = function(n) {
		var ret = (n % 1 === 0);
		return ret;
	};

	var forTag = function(t, f) {
		switch (typeof(t)) {
			case "boolean": return f([1]);
			case "number": 
				if (isInt(t))
					return f([2]);
				else 
					return f([3]);
			case "string": return f([4]);
			case "object": 
				if (Array.isArray(t))
					return f(mergeArrayTag(t));
				else 
					return -1;
			default: return -1;
		}
	}

	// this function selects the most suitable type tag from the all in the arrayTags (this is an array)
	// the most suitable tag is the 'most complex'. i.e.:
	// if array contain ints and doubles then double will be selected
	// ints, doubles & strings -> string etc.
	var mergeArrayTag = function(arrayTags) {
		var t = [];
		arrayTags.forEach(function(entry) {
			t.push(forTag(entry, function(tt) { return tt; }));
		});

		// for zero-length arrays we'll select type of array of ints
		if (t.length <= 0)
			return [9, 2];

		// ensure all elements are the same length
		var baseLen = t[0].length;
		if (t.some(elem => elem.length != baseLen))
			return -1; // all lengths should be equal

		// select the most suitable
		var ret = t[0];
		for (var i = 1; i < t.length; ++i) {
			for (var j = 0; j < baseLen; ++j) {
				// we use simple 'max' since our types fortunately arranged in proper way that allows to use it
				ret[j] = Math.max(ret[j], t[i][j]);
			};
		}

		return [9].concat(ret);
	};

	var mergeTag = function(t) {
		var ret = t[0];
		var itemlength = ret.length;
		for (var i = 1; i < t.length; ++i) {
			for (var j = 0; j < itemlength; ++j) {
				ret[j] = Math.max(ret[j], t[i][j]);
			};
		}

		return ret;
	};

	var ret = forTag(value, function(t) {
		return t;
	});

	if (ret == -1) {
		console.error('Something wrong with value of type: ' + typeof(value));
	}

	// console.log('data: ' + JSON.stringify(value) + '; result type: ' + ret);
	return ret;
}

// function test1() {
// 	extractTagsFromValue(5);
// 	extractTagsFromValue(6.7);
// 	extractTagsFromValue("8");
// 	extractTagsFromValue([]);
// 	extractTagsFromValue([1, 2, 3]);
// 	extractTagsFromValue([1, 2.2, 1]);
// 	extractTagsFromValue([1, 1, 2.2]);
// 	extractTagsFromValue([1, 2.2, "3.3"]);
// 	extractTagsFromValue([[1, 2], [3, 4]]);
// 	extractTagsFromValue([[1, 2], [3.1, 4]]);
// 	extractTagsFromValue([[1, 2], [3.1, "4"]]);
// 	extractTagsFromValue([[[1, 2], [1, 2]], [[1, 2], [1, 2]]]);
// 	extractTagsFromValue([[[1, 2], [1.1, 2]], [[1, 2], [1, 2]]]);
// 	extractTagsFromValue([[[1, 2], [1, 2]], [["1", 2], [1, 2]]]);
// }

// test1();
