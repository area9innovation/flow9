#[ // responseEncoding parameter allows to set which encoding should be the response:
//  'auto' - defined by target (js - 'utf8_js', cpp - 'utf8', but cropped by two bytes (it is bug))
//  'utf8_js' -  UTF-8 encoding with surrogate pairs
//  'utf8' - original UTF-8 encoding with 1, 2, 3 bytes length
//  'byte' - 1 byte encoding (raw response).
native httpCustomRequestNative : io (
  url : string, method : string, headers : [[string]], parameters : [[string]], data : string,
  responseEncoding : string, // ['auto', 'utf8_js', 'utf8', 'byte']
  onResponse : (responseStatus : int, responseData : string, responseHeaders : [[string]]) -> void, async : bool
) -> void = HttpSupport.httpCustomRequestNative ]#

import httpclient
import uri
import strutils
import streams
import unicode
import ../url_parameter/getUrlParameterNative

var defaultResponseEncoding* = "auto"

proc containsUrlParameter(name: string): bool =
  when declared(commandLineParams):
    for arg in commandLineParams():
      if (arg == name): return true
    result = false
  else:
    result = false

proc isUrlParamTrue(param : string) : bool =
  let paramValue = getUrlParameterNative(param)
  paramValue == "1" or toLowerAscii(paramValue) == "true" or containsUrlParameter(paramValue)

# TODO: i doubt it can work. utf8<->utf16
proc unpackSurrogatePair(response : var string, codeHi : uint16, codeLow : uint16) : int =
  let codeError = 0xFFFD
  var codeResult : int = codeError

  # `code` is the highest part of the surrogate pair
  if (0xD800 <= codeHi and (codeHi <= 0xDBFF)):
    codeResult = (int)(((codeHi and 0x3FF) shl 10) + (codeLow and 0x3FF)) + 0x10000
    # unicode.toUTF8(cast[Rune](code))
    response.add(cast[Rune](codeResult))
    return 2
  elif (0xDC00 <= codeHi and codeHi <= 0xDFFF):
  # `code` is the lowest part of the surrogate pair
  # If we meet it - something went wrong.
    response.add(cast[Rune](codeError))
    return 1
  # Otherwise we do nothing - we have utf8 code.
  # Will process it below.
  else:
    response.add(cast[Rune](codeHi))
    return 1

proc encodeResponse(bodyStream: Stream, encoding : string, defaultEncoding : string) : string =
  if (bodyStream == nil): return ""
  else:
    var responseEncoding = encoding
    if (isUrlParamTrue("use_utf8_js_style")): responseEncoding = "utf8_js"
    elif (isUrlParamTrue("utf8_no_surrogates")): responseEncoding = "utf8"
    elif (isUrlParamTrue("auto")): responseEncoding = defaultEncoding
    const bufferSize = 1024
    if (responseEncoding == "utf8") :
      # uint16 ~= char in Java
      # How much last chars from the previous chain we moved to the beginning of the new one (0 or 1).
      var additionalChars = 0
      # +1 additinal char from the prevoius chain
      var buffer: array[bufferSize + 1, uint16]
      var readSize = 0
      var countSize = 0
      var codesUsed = 0
      var counter = 0
      while (not bodyStream.atEnd()):
        # How much chars we used to decode symbol into utf8 (1 or 2)
        readSize = bodyStream.readData(addr(buffer), bufferSize)
        # readSize = in.read(buffer, additionalChars, bufferSize)
        # We stop, if nothing read
        if (readSize < 0): break
        # On one less of real to use it as index + 1 in `for`
        countSize = readSize + additionalChars - 1
        # Now, how much unprocessed chars we have
        additionalChars = readSize
        counter = 0
        while (counter < countSize):
          codesUsed = unpackSurrogatePair(result, buffer[counter], buffer[counter + 1])
          counter = counter + codesUsed
          additionalChars = additionalChars - codesUsed
        if (additionalChars > 0):
          buffer[0] = buffer[counter]
          additionalChars = 1

      if (additionalChars > 0):
        discard unpackSurrogatePair(result, buffer[0], buffer[0])
    elif (responseEncoding == "utf8_js") :
      # uint16 ~= char in Java
      var buffer: array[bufferSize, uint16]
      var length = 0
      while (not bodyStream.atEnd()):
        length = bodyStream.readData(addr(buffer), bufferSize)
        for i in 0..<length:
          result.add(cast[Rune](buffer[i]))
    elif (responseEncoding == "byte") :
      var buffer: array[bufferSize, byte]
      var length = 0
      while (not bodyStream.atEnd()):
        length = bodyStream.readData(addr(buffer), bufferSize)
        for i in 0..<length:
          result.add(cast[Rune](buffer[i] and 0x00FF))
    else: # auto or other
      for line in bodyStream.lines():
        result.add(line)
        result.add("\n")
    bodyStream.close()

# TODO: async ?
proc execHttpCustomRequest*(url : string, method_0 : string, headers : seq[seq[string]], 
    parameters : seq[seq[string]], data : string, responseEncoding : string, 
    onResponse : proc (responseStatus : int32, responseData : string, responseHeaders : seq[seq[string]]) : void,
    async : bool, defaultEncoding : string
): void =
  var requestMethod = HttpGet
  try:
    requestMethod = parseEnum[HttpMethod](method_0)
  except ValueError as e:
    onResponse(500i32, e.msg, @[]) # TODO : diff errors

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
      requestBody = data #   postData = data.getBytes(StandardCharsets.UTF_8)
      client.headers.add("Content-Type", "application/raw")
    else:
      for pair in parameters:
        if pair.len == 2:
          postData[pair[0]] = pair[1]
      client.headers.add("Content-Type", "application/x-www-form-urlencoded")
    
    client.headers.add("charset", "utf-8")
    # byte[] postData = urlParams.getBytes(StandardCharsets.UTF_8)
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
    onResponse(code(response).int32, encodeResponse(response.bodyStream, responseEncoding, defaultEncoding), responseHeaders)
  except CatchableError as e:
    onResponse(500i32, e.msg, @[]) # TODO : diff errors
  finally:
    client.close()