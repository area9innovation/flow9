//Simple Least Recent Used class

class LRU {
    private var keyMap : Map<String,Int>;
    private var keyList : List<String>;

    public function new() {
		keyMap = new Map<String,Int>();
		keyList = new List<String>();
    }

    //set: Call to set or update entry position
    public function set(key : String) : Void {
        if (keyMap.exists(key)) {
            //if exists, remove link from list
            keyList.remove(key);
        }else{
            //otherwise create link
            keyMap.set(key, 1);
        }
        //add to end of list
        keyList.add(key);
	}

    //removeLRU: Call to remove & receive LRU
	public function removeLRU() : String {
		//remove from beginning of list
		var key = keyList.pop();
		if (key != null) {
			keyMap.remove(key);
		}
		return key;
	}

    //remove: Call to remove specific entry
    public function remove(key : String) : Void {
        if (key != null) {
            keyList.remove(key);
            keyMap.remove(key);
        }
    }
}
