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

import httpclient
import uri
import strutils

# TODO: async ?
proc execHttpCustomRequest*(url : string, method_0 : string, headers : seq[seq[string]], 
    parameters : seq[seq[string]], data : string, responseEncoding : string, 
    onResponse : proc (responseStatus : int, responseData : string, responseHeaders : seq[seq[string]]) : void,
    async : bool
): void =
  var requestMethod = HttpGet
  try:
    requestMethod = parseEnum[HttpMethod](method_0)
  except ValueError as e:
    onResponse(500, e.msg, @[]) # TODO : diff errors

  let client = newHttpClient()
  client.headers = newHttpHeaders()
  for pair in headers:
    if pair.len == 2:
      client.headers.add(pair[0], pair[1])
  var requestUrl = url
  var postData = newMultipartData()
  var requestBody = ""
  if (requestMethod == HttpPost):
    if (data != ""):
      requestBody = data #   postData = data.getBytes(StandardCharsets.UTF_8);
      client.headers.add("Content-Type", "application/raw");
    else:
      for pair in parameters:
        if pair.len == 2:
          postData[pair[0]] = pair[1]
      client.headers.add("Content-Type", "application/x-www-form-urlencoded")
    
    client.headers.add("charset", "utf-8")
    # int postDataLength = postData.length;
    # addHeaders(con, headers);
    # con.setRequestProperty("charset", "utf-8");
    # con.setRequestMethod(method);
    # con.setDoOutput(true);
    # con.setRequestProperty("Content-Length", Integer.toString(postDataLength));
    # con.setUseCaches(false);
    # try(DataOutputStream wr = new DataOutputStream(con.getOutputStream())) {
    #   wr.write(postData);
    # }

    # byte[] postData = urlParams.getBytes(StandardCharsets.UTF_8);
    # client.headers.add("Content-Length", Integer.toString(postData.length))
    # client.headers.add("cache-control", "no-cache")
  else:
    var urlParams = ""
    for pair in parameters:
      if pair.len == 2:
        if urlParams.len > 0: urlParams.add('&')
        urlParams.add(encodeUrl(pair[0], false) & "=" & encodeUrl(pair[1], false)) #encodeUrlParameter
    if (urlParams != ""):
      requestUrl = requestUrl & (if (requestUrl.contains("?")): "&" else: "?") & urlParams

  try:
    let response = client.request(requestUrl, httpMethod = requestMethod, multipart = postData, body = requestBody)
    var responseHeaders : seq[seq[string]] = @[]
    for k, v in response.headers.pairs:
      responseHeaders.add(@[k, v])
    onResponse(code(response).int32, response.body, responseHeaders)
  except CatchableError as e:
    onResponse(500, e.msg, @[]) # TODO : diff errors
  finally:
    client.close()