proc hostCall*(name: string, args: seq[Flow]): Flow =
  echo("hostCall of $name is not implemented")
  return Flow(tp: rtVoid)