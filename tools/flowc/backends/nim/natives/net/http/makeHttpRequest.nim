# native makeHttpRequest : io (url : string, postMethod : bool, headers : [[string]], params : [[string]], onData : (string) -> void, onError : (string) -> void, onStatus : (int) -> void,) -> void = HttpSupport.httpRequest;

import threadpool
import httpclient
import uri
import strutils

# we can't use openArray here
proc execHttpRequest(
                     url : string,
                     postMethod : bool,
                     headers : seq[seq[string]],
                     params : seq[seq[string]],
                     onData : proc(r : string): void,
                     onError : proc(e : string): void,
                     onStatus : proc(c : int32): void,
) =
  let client = newHttpClient()
  client.headers = newHttpHeaders()
  for pair in headers:
    if pair.len == 2:
      client.headers.add(pair[0], pair[1])
  var requestUrl = url
  var data = newMultipartData()
  if (postMethod):
    for pair in params:
      if pair.len == 2:
        data[pair[0]] = pair[1]
        # byte[] postData = urlParams.getBytes(StandardCharsets.UTF_8);
    client.headers.add("Content-Type", "application/x-www-form-urlencoded")
    client.headers.add("charset", "utf-8")
    # client.headers.add("Content-Length", Integer.toString(postData.length))
    # client.headers.add("cache-control", "no-cache")
  else:
    var urlParams = ""
    for pair in params:
      if pair.len == 2:
        if urlParams.len > 0: urlParams.add('&')
        urlParams.add(encodeUrl(pair[0], false) & "=" & encodeUrl(pair[1], false)) #encodeUrlParameter
    if (urlParams != ""):
      requestUrl = requestUrl & (if (requestUrl.contains("?")): "&" else: "?") & urlParams

  try:
    let response = client.request(requestUrl, httpMethod = if (postMethod): HttpPost else: HttpGet, multipart = data)
    onStatus(code(response).int32)
    onData(response.body) # ==  onData(response.bodyStream.readAll())
  except CatchableError as e:
    onError(e.msg)
  finally:
    client.close()


proc $F_0(makeHttpRequest)*(url0 : String, postMethod : bool, headers0 : seq[seq[String]], params0 : seq[seq[String]], onData0 : proc(r : String): void, onError0 : proc(e : String): void, onStatus : proc(c : int32): void) =
  let url = rt_string_to_utf8(url0)
  let headers = map(headers0, proc(header: seq[String]): seq[string] =
    map(header, proc(x: String) = rt_string_to_utf8(x))
  )
  let params = map(params0, proc(param: seq[String]): seq[string] =
    map(param, proc(x: String) = rt_string_to_utf8(x))
  )
  let onData = proc(x: string): void = onData0(rt_utf8_to_string(x))
  let onError = proc(x: string): void = onError0(rt_utf8_to_string(x))
  spawn execHttpRequest(url, postMethod, headers, params, onData, onError, onStatus)
