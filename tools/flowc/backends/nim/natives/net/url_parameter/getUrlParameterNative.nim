proc $F_0(getUrlParameterNative)*(name: string): string =
  # getUrlParameterNative  is implemented in flow_lib/url_parameters
  return rt_utf8_to_string(getUrlParameterNative(rt_string_to_utf8(name)))
