
import threadpool, os
import std/asynchttpserver
import std/asyncdispatch
import atomics
import httpclient

# TODO: correct synchronization primitive
var stopSrvPortId : Atomic[int]
var createdSrvPortId : Atomic[int]

# the server will not stop immediately, but only when the next request is received
proc runServer(portId : int, mask : int) {.async.} =
  var server = newAsyncHttpServer()
  var stopped = false
  var requestFuture: Future[void]
  let isStopped = proc(): bool =
    let existsServer = (createdSrvPortId.load() and mask) > 0
    let stopSignal = (stopSrvPortId.load() and mask) > 0
    result = not existsServer or stopSignal
  proc cb(req: Request) {.async.} =
    # echo (req.reqMethod, req.url, req.headers)
    # echo "Received request [" & $portId & "]"
    let headers = {"Content-type": "text/plain; charset=utf-8"}
    if (not isStopped()):
      await req.respond(Http200, "Hello World", headers.newHttpHeaders())
    else : 
      # echo "  Request REJECTED [" & $portId & "]"
      discard fetchAnd(createdSrvPortId, not mask)
      discard fetchAnd(stopSrvPortId, not mask)
      stopped = true
      requestFuture.complete()
      discard
  try:
    server.listen(Port(portId))
  except CatchableError as e:
    # echo "error listen port=" & $portId & " " & $e.msg
    stopped = true
  # echo "started thread server [" & $portId & "]. thread=" & $(getThreadId())
  # loop to wait for the next request
  while not stopped:
    echo "while REQUEST " & $portId
    if server.shouldAcceptRequest():
      requestFuture = server.acceptRequest(cb)
      await requestFuture
    else:
      # echo "while Requset PAUSE" & $portId
      # too many concurrent connections, `maxFDs` exceeded
      # wait 500ms for FDs to be closed
      await sleepAsync(500)
  server.close()
  # echo "stopped server with port=" & $portId

proc startServerThread(port : int, mask : int) {.thread.} =
  waitFor runServer(port, mask)
  # echo "stopped thread server [" & $port & "]. thread=" & $(getThreadId())

proc notifyServer(port : int): void =
  let client = newHttpClient()
  try:
    # echo "    NOTIFY SERVER [" & $port & "]"
    discard client.request("http://localhost:" & $port, HttpGet)
  except CatchableError:
   discard
  finally:
    client.close()

proc makeStopServerFn(port : int, mask : int): proc(): void =
  result = proc():void =
    # echo "stop server [" & $port & "]"
    discard fetchOr(stopSrvPortId, mask)
    notifyServer(port)


#[ 
  FlowHttpServer* = ref object
   port: int32
   stopFn : proc(): void
proc makeFlowHttpServer*(port : int32, stopFn : proc(): void) : FlowHttpServer =
  FlowHttpServer(port : port, stopFn = startProcess)
proc makeHttpServerNative*(srv : FlowHttpServer) : Native =
  Native(what : "HttpServer", ntp: ntHttpServer, s : srv)
 ]#
#[ proc createHttpServerInner(
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
  let mask = (createdSrvPortId.load() shl 1) or 1 # nextBinVal. but we have to search for first 0
  discard createdSrvPortId.fetchOr(mask)
  result = makeFlowHttpServer(port, makeStopServerFn(port, mask))
  spawn startServerThread(port, mask)

proc createHttpServerNative*(
    port: int32,
    isHttps: bool,
    pfxPath: string,
    pfxPassword: string,
    onOpen: proc (): void,
    onMessage: proc (
        requestUrl: string,
        requestBody: string,
        requestMethod: string,
        requestHeaders: seq[seq[string]],#seq[tuple[key, value: string]],
        endResponse: proc (body: string): void,
        setResponseHeader: proc (key: string, values: seq[string]): void,
        setResponseStatus: proc (code: int32): void): void
): Native =
  makeHttpServerNative(createHttpServerInner(port, isHttps, pfxPath, pfxPassword, onOpen, onMessage)) ]#

proc startServer(port : int): proc(): void =
  let mask = (createdSrvPortId.load() shl 1) or 1 # nextBinVal. but we have to search for first 0
  discard createdSrvPortId.fetchOr(mask)
  result = makeStopServerFn(port, mask)
  spawn startServerThread(port, mask)

proc timerBody(delay : int32, fn : proc (): void) : void =
  sleep(int(delay))
  fn()
proc timer*(delay : int32, fn : proc (): void) : void =
  spawn timerBody(delay, fn)

echo "main thread=" & $(getThreadId())
stopSrvPortId.store(0)
createdSrvPortId.store(0)
let stop2 = startServer(8082) # 0b0000_0001
let stop5 = startServer(8085) # 0b0000_0010
# let stop3 = startServer(8085) # 0b0000_0100
timer(5000, stop2)
timer(6000, stop2)
timer(6000, stop5)

timer(15000, proc(): void =
  echo " REUSE PORT"
  # if one startServer(), the first request is ignored ....
  let stop5_1 = startServer(8085)
#   let stop6 = startServer(8086)
)

# runForever()
while true: waitFor(sleepAsync(2000000000))