import createHttpServerNative_unix

proc $F_0(createHttpServerNative)*(
    port: int32,
    isHttps: bool,
    pfxPath0: RtString,
    pfxPassword0: RtString,
    onOpen: proc (): void,
    onMessage0: proc (
        requestUrl: RtString,
        requestBody: RtString,
        requestMethod: RtString,
        requestHeaders: seq[seq[RtString]],#seq[tuple[key, value: string]],
        endResponse: proc (body: RtString): void,
        setResponseHeader: proc (key: RtString, values: seq[RtString]): void,
        setResponseStatus: proc (code: int32): void): void
): Native =
  let pfxPath = rt_string_to_utf8(pfxPath0)
  let pfxPassword = rt_string_to_utf8(pfxPassword0)
  let onMessage = proc (
        requestUrl0: string,
        requestBody0: string,
        requestMethod0: string,
        requestHeaders0: seq[seq[string]],#seq[tuple[key, value: string]],
        endResponse0: proc (body: string): void,
        setResponseHeader0: proc (key: string, values: seq[string]): void,
        setResponseStatus: proc (code: int32): void): void =
    let requestUrl = rt_utf8_to_string(requestUrl0)
    let requestBody = rt_utf8_to_string(requestBody0)
    let requestMethod = rt_utf8_to_string(requestMethod0)
    let requestHeaders = map(requestHeaders0, proc(header: seq[string]): seq[RtString] =
      map(header, proc(x: string): RtString = rt_utf8_to_string(x))
    )
    let endResponse = proc(body: RtString): void = endResponse0(rt_string_to_utf8(body))
    let setResponseHeader = proc(key0: RtString, values0: seq[RtString]): void =
      let key = rt_string_to_utf8(key0)
      let values = map(values0, proc(x: RtString): string = rt_string_to_utf8(x))
      setResponseHeader0(key, values)
    onMessage0(requestUrl, requestBody, requestMethod, requestHeaders, endResponse, setResponseHeader, setResponseStatus)
  makeHttpServerNative(createHttpServerInner(port, isHttps, pfxPath, pfxPassword, onOpen, onMessage))
