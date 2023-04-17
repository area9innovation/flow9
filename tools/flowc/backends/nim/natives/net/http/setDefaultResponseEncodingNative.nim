# native setDefaultResponseEncodingNative : (encoding : string) -> void = HttpSupport.setDefaultResponseEncoding

import http_utils

proc setDefaultResponseEncodingNative*(encoding : string) =
    defaultResponseEncoding = encoding

    var encodingName = ""
    if (encoding == "auto"):
      encodingName = "auto"
    elif (encoding == "utf8_js"):
      encodingName = "utf8 with surrogate pairs"
    elif (encoding == "utf8"):
      encodingName = "utf8 without surrogate pairs"
    elif (encoding == "byte"):
      encodingName = "raw byte"
    else:
      encodingName = "auto"

    echo("Default response encoding switched to '" & encodingName & "'")