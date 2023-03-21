import httpbeast

proc closeHttpServerNative*(server: HttpServer, closeFuture: Future[void]) =
  echo("Untested closeHttpServerNative")
  complete(closeFuture)
  server.close()
