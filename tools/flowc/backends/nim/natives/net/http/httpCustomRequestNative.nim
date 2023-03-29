

#[ // responseEncoding parameter allows to set which encoding should be the response:
//  'auto' - defined by target (js - 'utf8_js', cpp - 'utf8', but cropped by two bytes (it is bug));
//  'utf8_js' -  UTF-8 encoding with surrogate pairs;
//  'utf8' - original UTF-8 encoding with 1, 2, 3 bytes length;
//  'byte' - 1 byte encoding (raw response).
native httpCustomRequestNative : io (
	url : string, method : string, headers : [[string]], parameters : [[string]], data : string,
	responseEncoding : string, // ['auto', 'utf8_js', 'utf8', 'byte']
	onResponse : (responseStatus : int, responseData : string, responseHeaders : [[string]]) -> void, async : bool
) -> void = HttpSupport.httpCustomRequestNative; ]#
import http_utils
import threadpool

proc httpCustomRequestNative*(url : string, method_0 : string, headers : seq[seq[string]], 
    parameters : seq[seq[string]], data : string, responseEncoding : string, 
    onResponse : proc (responseStatus : int, responseData : string, responseHeaders : seq[seq[string]]) : void, async : bool): void =
  spawn execHttpCustomRequest(url, method_0, headers, parameters, data, responseEncoding, onResponse, async)