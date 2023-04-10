
import threadpool, os
import std/asynchttpserver
import std/asyncdispatch
import atomics
import httpclient
import tables
import net, asyncnet

type
  HttpServerMessage = proc (
        requestUrl: string,
        requestBody: string,
        requestMethod: string,
        requestHeaders: seq[seq[string]],#seq[tuple[key, value: string]],
        endResponse: proc (body: string): void,
        setResponseHeader: proc (key: string, values: seq[string]): void,
        setResponseStatus: proc (code: int32): void
  ): void
# TODO: correct synchronization primitive
var stopSrvPortId : Atomic[int]
var createdSrvPortId : Atomic[int]

proc onMessageFuture(req: Request, onMessage : HttpServerMessage): Future[void] =
  var headers : seq[seq[string]] = newSeq[seq[string]](len(req.headers.table))
  for k, v in req.headers.table.pairs:
    var s = v
    s.insert(k, 0)
    headers.add(s)
  var respStatus = Http500
  var respHeaders : seq[tuple[key: string, val: string]] = @[]
  var respBody = ""
  var ready = false
  onMessage(
    $req.url,
    req.body,
    $req.reqMethod,
    headers,
    proc(body: string): void =
      respBody = body
      ready = true,
    proc(key: string, values: seq[string]): void =
      for v in values : respHeaders.add((key, v)),
    proc(code: int32): void = respStatus = HttpCode(int(code))
  )
  while not ready:
    #echo "waiting for response future"
    sleep(100)
  req.respond(respStatus, respBody, newHttpHeaders(respHeaders))


# the server will not stop immediately, but only when the next request is received
proc runServer(portId : int, mask : int, onMessage : HttpServerMessage) {.async.} =
  var server = newAsyncHttpServer()
#   wrapSocket(newContext(), server.socket)
  var stopped = false
  var requestFuture: Future[void]
  let isStopped = proc(): bool =
    let existsServer = (createdSrvPortId.load() and mask) > 0
    let stopSignal = (stopSrvPortId.load() and mask) > 0
    result = not existsServer or stopSignal
  proc cb(req: Request) {.async, closure, gcsafe.} =
   {.cast(gcsafe).}: # <- MAGIC !
    echo "Received request [" & $portId & "]"
    # let headers = {"Content-type": "text/plain; charset=utf-8"}
    if (not isStopped()):
      await onMessageFuture(req, onMessage)
    else : 
      echo "  Request REJECTED [" & $portId & "]"
      discard fetchAnd(createdSrvPortId, not mask)
      discard fetchAnd(stopSrvPortId, not mask)
      stopped = true
      if (not requestFuture.isNil): requestFuture.complete()
      discard
  try:
    server.listen(Port(portId))
  except CatchableError as e:
    echo "error listen port=" & $portId & " " & $e.msg
    stopped = true
  echo "started thread server [" & $portId & "]. thread=" & $(getThreadId())
  # loop to wait for the next request
  while not stopped:
    echo "while REQUEST " & $portId
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      echo "while Requset PAUSE" & $portId
      # too many concurrent connections, `maxFDs` exceeded
      # wait 500ms for FDs to be closed
      await sleepAsync(500)
  server.close()
  echo "stopped server with port=" & $portId


proc startServerThread(port : int, mask : int, onMessage : HttpServerMessage) {.thread.} =
  waitFor runServer(port, mask, onMessage)
  echo "stopped thread server [" & $port & "]. thread=" & $(getThreadId())

proc notifyServer(port : int): void =
  let client = newHttpClient()
  try:
    echo "    NOTIFY SERVER [" & $port & "]"
    discard client.request("http://localhost:" & $port, HttpGet)
  except CatchableError:
   discard
  finally:
    client.close()

proc makeStopServerFn(port : int, mask : int): proc(): void {.gcsafe.} =
  result = proc():void =
    echo "stop server [" & $port & "]"
    discard fetchOr(stopSrvPortId, mask)
    notifyServer(port)

proc startServer*(port : int, onMessage : HttpServerMessage): proc(): void {.gcsafe.} =
  let mask = (createdSrvPortId.load() shl 1) or 1 # nextBinVal. but we have to search for first 0
  discard createdSrvPortId.fetchOr(mask)
  result = makeStopServerFn(port, mask)
  spawn startServerThread(port, mask, onMessage)

proc timerBody(delay : int32, fn : proc (): void {.gcsafe.}) : void =
  sleep(int(delay))
  fn()
proc timer*(delay : int32, fn : proc (): void {.gcsafe.}) : void =
  spawn timerBody(delay, fn)

import marshal
echo "main thread=" & $(getThreadId())
stopSrvPortId.store(0)
createdSrvPortId.store(0)
let onMessage : HttpServerMessage = proc (
        requestUrl: string,
        requestBody: string,
        requestMethod: string,
        requestHeaders: seq[seq[string]],#seq[tuple[key, value: string]],
        endResponse: proc (body: string): void,
        setResponseHeader: proc (key: string, values: seq[string]): void,
        setResponseStatus: proc (code: int32): void
  ): void =
    echo "requestUrl=" & requestUrl
    echo "requestBody=" & requestBody
    echo "requestMethod=" & requestMethod
    echo "requestHeaders=" & $$requestHeaders
    setResponseHeader("customH", @["customV"])
    setResponseStatus(201)
    timer(1000, proc() = 
      {.cast(gcsafe).}: # <- MAGIC !
        endResponse("OK to request")
    )

let stop2 = startServer(8082, onMessage) # 0b0000_0001
let stop5 = startServer(8085, onMessage) # 0b0000_0010
# let stop3 = startServer(8085, onMessage) # 0b0000_0100
timer(5000, stop2)
timer(6000, stop2)
timer(6000, stop5)

timer(15000, proc(): void =
  {.cast(gcsafe).}: # <- MAGIC !
    echo " REUSE PORT"
    let stop5_1 = startServer(8085, onMessage))


# runForever()
while true: waitFor(sleepAsync(2000000000))