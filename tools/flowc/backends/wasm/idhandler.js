	var IDHandler = {

		ids: [1,2,3], // non-empty for testing purpose. 
		free_ids: [],

		// get an integer ID for a JS object. this keeps a reference to it, preventing GC'ing
		createObjectId: function (obj) {
			var id = IDHandler.ids.length;

			if (IDHandler.free_ids.length > 0) {
				// reuse id from free_ids array
				id = IDHandler.free_ids.shift();
			}

			IDHandler.ids[id] = obj;
			return id;
		},

		// get a JS object from an integer ID
		getObjectFromID: function (id) {
			return IDHandler.ids[id];
		},

		// releases an object that has an ID. this allows it to be GD'd
		revokeObjectId: function (id) {
			IDHandler.ids[id] = null;
			IDHandler.free_ids.unshift(id);
		},
	};
