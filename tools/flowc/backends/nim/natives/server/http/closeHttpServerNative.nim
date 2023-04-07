import httpbeast

proc $F_0(closeHttpServerNative)*(server: HttpServer, closeFuture: Future[void]) =
  echo("Untested closeHttpServerNative")
  complete(closeFuture)
  server.close()
