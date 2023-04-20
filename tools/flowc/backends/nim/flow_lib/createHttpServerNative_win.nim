import "httpServer_type"

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
  echo "Not implemented for Windows yet"
  nil
