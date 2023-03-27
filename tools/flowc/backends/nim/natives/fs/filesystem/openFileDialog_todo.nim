#[ 
	native openFileDialog : (
		maxFiles : int,
		fileTypes: [string], // array of "*.jpg" like strings or "image/*" mime-type filter strings
		callback : (files : [native]) -> void
	) -> void = FlowFileSystem.openFileDialog;
 ]#