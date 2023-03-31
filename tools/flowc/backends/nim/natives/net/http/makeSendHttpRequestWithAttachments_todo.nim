
# not implemented in Java

#[ 
	native makeSendHttpRequestWithAttachments : (
	url : string,
	headers : [[string]],
	params : [[string]],
	attachments : [[string]], // path to files in file system.
	onData : (string) -> void,
	onError : (string) -> void
) -> void = HttpSupport.sendHttpRequestWithAttachments;

 ]#