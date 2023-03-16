proc httpCustomRequestNative*(url : string, method_0 : string, headers : seq[seq[string]], 
    parameters : seq[seq[string]], data : string, responseEncoding : string, 
    onResponse : proc (responseStatus : int, responseData : string, responseHeaders : seq[seq[string]]) : void, async : bool): void =
  echo "TODO: Implement httpCustomRequestNative"