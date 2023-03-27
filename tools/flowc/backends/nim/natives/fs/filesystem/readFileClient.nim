#[ 
	native readFileClient : (
		file : native,
		as : string, // Acceptable values: text, uri, data. Default value: text.
		onData : (string) -> void,
		onError : (string) -> void
	) -> void = FlowFileSystem.readFile;
 ]#