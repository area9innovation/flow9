# nimble install jester
import jester
import asyncdispatch
import os
import strutils
import threadpool

proc createHttpServerInner(
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
  echo "Not implemented . " & getOS() & " target"


router myrouter:
  get "/":
    resp "It's alive!"

proc startServer(portId : int) =
#   let port = paramStr(1).parseInt().Port
  echo "startServer : " & $(portId)
  let port = Port(portId)
  let settings = newSettings(port=port)
  var jester = initJester(myrouter, settings=settings)
  jester.serve()


startServer(8082)
  nil

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
  makeHttpServerNative(createHttpServerInner(port, isHttps, pfxPath, pfxPassword, onOpen, onMessage))