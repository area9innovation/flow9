FlowVoid fcPrintln(FlowObject str) {
  if (!isOWASPLevel1().value) {
    return fcPrintln2(str);
  } else {
    return new FlowVoid();
 }
}
