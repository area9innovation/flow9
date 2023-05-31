# native doUploadClientFile : ( file : native, url: string, params: [[string]], headers: [[string]], onOpen: () -> void, onData: (string) -> void, onError: (string) -> void, onProgress: (double, double) -> void) -> () -> void = HttpSupport.uploadNativeFile;

# TODO: not tested addFiles part
# TODO: Native is not implemented for FS
import threadpool
import httpclient
import os

proc uploadClientFSFile(
  file : Native,
  url: string,
  params: seq[seq[string]],
  headers: seq[seq[string]],
  onOpen: proc(): void,
  onData: proc(r : string): void,
  onError: proc(e: string): void,
  onProgress: proc(loaded : float, total : float): void{.gcsafe.},
  onSetOnCancel: proc(setter : proc(): void) : void,
) {.thread.} =
  proc onProgressCallback(total, progress, speed: BiggestInt): void {.gcsafe.} =
    let loaded = progress.float / total.float
    onProgress(loaded, total.float)

  let client = newHttpClient()
  let filePath = "" # from file
  let fileName = "" # from file
  onSetOnCancel(proc() = 
    if (client != nil):
      client.onProgressChanged = nil
      client.close()
  )
  client.headers = newHttpHeaders()
  for pair in headers:
    if pair.len == 2:
      client.headers.add(pair[0], pair[1])
  var data = newMultipartData()
  for pair in params:
    if pair.len == 2:
      data[pair[0]] = pair[1]
  # i hope it will work like magic
  data.addFiles({fileName: filePath}) # The MIME types will automatically be determined
  client.headers.add("Content-Type", "application/x-www-form-urlencoded")
  client.headers.add("charset", "utf-8")
  client.onProgressChanged = ProgressChangedProc[void](onProgressCallback)
  var totalSize = 0.0
  try:
    totalSize= getFileSize(filePath).float
  except CatchableError as e:
    onError(e.msg)
  if (totalSize > 0):
    let boundary = "----NimHttpClientFormBoundary"
    client.headers.add("Content-Type", "multipart/form-data; boundary=" & boundary)
    # client.headers.add("Content-Length", Integer.toString(postData.length))
    # client.headers.add("cache-control", "no-cache")
    try:
        onOpen()
        let response = client.request(url, httpMethod = HttpPost, multipart = data)
        onData(response.body)
    except CatchableError as e:
        onError(e.msg)
    finally:
        client.close()
  else:
    client.close()

proc $F_0(doUploadClientFile)*(
  file : Native,
  url0: string,
  params0: seq[seq[String]],
  headers0: seq[seq[String]],
  onOpen: proc(): void,
  onData0: proc(r : String): void,
  onError0: proc(e: String): void,
  onProgress: proc(loaded : float, total : float): void{.gcsafe.}
) : proc(): void =
  let url = rt_string_to_utf8(url0)
  let params = map(params0, proc(param: seq[String]): seq[string] =
    map(param, proc(x: String) = rt_string_to_utf8(x))
  )
  let headers = map(headers0, proc(header: seq[String]): seq[string] =
    map(header, proc(x: String) = rt_string_to_utf8(x))
  )
  let onData = proc(x: string): void = onData0(rt_utf8_to_string(x))
  let onError = proc(x: string): void = onError0(rt_utf8_to_string(x))
  var onCancel : proc(): void = proc() = discard
  spawn uploadClientFSFile(file, url, params, headers, onOpen, onData, onError, onProgress, proc(newProc : proc(): void) = onCancel = newProc)
  onCancel