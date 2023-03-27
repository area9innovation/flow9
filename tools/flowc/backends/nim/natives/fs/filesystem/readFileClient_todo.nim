#[ 
	native readFileClient : (
		file : native,
		as : string, // Acceptable values: text, uri, data. Default value: text.
		onData : (string) -> void,
		onError : (string) -> void
	) -> void = FlowFileSystem.readFile;
 ]#

#[ import os

proc readFileClient*(file : Native, asType : string, onData : proc(string) : void, onError : proc(string) : void) =
    case file.tp:
      of ntFile:
        if (file.f != nil):
          try:
            onData(readFile(file.f.path))
          except IOError as msg:
            onError(msg)
      else :
        onError("Invalid file type") ]#