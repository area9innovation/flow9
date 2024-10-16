import httpbeast, asyncdispatch, strtabs

import "httpServer_type"

# nimble install httpbeast

# Untested
proc createHttpServerInner*(
    port: int32,
    isHttps: bool,
    pfxPath: string,
    pfxPassword: string,
    onOpen: proc (): void,
    onMessage: proc (
        requestUrl: string,
        requestBody: string,
        requestMethod: string,
        requestHeaders: seq[seq[string]],
        endResponse: proc (body: string): void,
        setResponseHeader: proc (key: string, values: seq[string]): void,
        setResponseStatus: proc (code: int32): void): void
): FlowHttpServer =
  echo("Untested createHttpServerNative")
#[   var closeFuture = newFuture[void]()
  
  proc onRequest(req: Request) {.async.} =
    if closeFuture.finished:
      return
    var headers: seq[tuple[key, value: string]] = @[]
    for key, value in req.headers:
      headers.add((key: key, value: value))

    proc endResponse(body: string) =
      req.send(Http200, body)

    proc setResponseHeader(key: string, values: seq[string]) =
      for value in values:
        req.setHeader(key, value)

    proc setResponseStatus(code: int) =
      req.status = HttpCode(code)

    onMessage(req.url, $req.body, $req.method, headers, endResponse, setResponseHeader, setResponseStatus)

  var server = newHttpServer(port)
  if isHttps:
    server.sslContext = newContext(certFile = pfxPath, keyFile = pfxPath, password = pfxPassword)
  server.listen()

  onOpen()

  while true:
    if closeFuture.finished:
      break
    await server.processClient(onRequest)
   ]#
  return makeFlowHttpServer(port)#, closeServer: closeFuture)

