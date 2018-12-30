FlowString strsubsmart(FlowString s, FlowInteger start, FlowInteger len) {
  if (start.value  >= 0 && len.value > 0) {
    return substring(s, start, len);
  } else {
    int slen = strlen(s).value;
    int trueStart = start.value >= 0 ? start.value : ( slen + start.value >= 0 ? slen + start.value : 0);
    int trueLength = len.value > 0 ? len.value : slen + len.value - trueStart;
    return substring(s, new FlowInteger(trueStart), new FlowInteger(trueLength));
  }
}
