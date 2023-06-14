

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

proc $F_0(httpCustomRequestNative)*(url0 : RtString, method_x0 : RtString, headers0 : seq[seq[RtString]], 
    parameters0 : seq[seq[RtString]], data0 : RtString, responseEncoding0 : RtString, 
    onResponse0 : proc (responseStatus : int32, responseData : RtString, responseHeaders : seq[seq[RtString]]) : void, async : bool): void =
  let url = rt_string_to_utf8(url0)
  let method_x = rt_string_to_utf8(method_x0)
  let headers = map(headers0, proc(header: seq[RtString]): seq[string] =
    map(header, proc(x: RtString): string = rt_string_to_utf8(x))
  )
  let parameters = map(parameters0, proc(param: seq[RtString]): seq[string] =
    map(param, proc(x: RtString): string = rt_string_to_utf8(x))
  )
  let data = rt_string_to_utf8(data0)
  let responseEncoding = rt_string_to_utf8(responseEncoding0)
  #let onData = proc(x: string): void = onData0(rt_utf8_to_string(x))
  #let onError = proc(x: string): void = onError0(rt_utf8_to_string(x))
  let onResponse = proc(esponseStatus : int32, responseData0 : string, responseHeaders0 : seq[seq[string]]): void =
    let responseData = rt_utf8_to_string(responseData0)
    let responseHeaders = map(responseHeaders0, proc(param: seq[string]): seq[RtString] =
      map(param, proc(x: string): RtString = rt_utf8_to_string(x))
    )
    onResponse0(esponseStatus, responseData, responseHeaders)
  spawn execHttpCustomRequest(url, method_x, headers, parameters, data, responseEncoding, onResponse, async, defaultResponseEncoding)