#import httpbeast

proc $F_0(closeHttpServerNative)*(server: Native): void =
  if server.ntp == ntHttpServer:
    echo("Untested closeHttpServerNative")
    #complete(server.s.closeServer)
    #server.s.server.close()
  else:
    discard
