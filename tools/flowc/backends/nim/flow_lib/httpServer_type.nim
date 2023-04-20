

type
  FlowHttpServer* = ref object
   port: int32
#    server : HttpServer
#    closeServer: Future[void]

proc makeFlowHttpServer*(port : int32) : FlowHttpServer =
  FlowHttpServer(port : port)