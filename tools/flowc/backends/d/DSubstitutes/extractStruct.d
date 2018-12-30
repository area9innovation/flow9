/*
T2 extractStruct(T1, T2)(T1[] a, T2 e) {
  return fold(a, e, delegate (T2 acc, T1 el) {
      if(isSameStructType(acc, el)){
        T2 t = cast(T2)el;
        return t;
      }else{
        return acc;
      }
    });
}
*/

FlowObject extractStruct(FlowArray a, FlowObject e) {
  return fold(a, e, new FlowFunction2(cast(FlowObject delegate(FlowObject p1, FlowObject p2))delegate (FlowObject acc, FlowObject el) {
	if(isSameStructType(acc, el).value){
	  auto t = el;
	  return t;
	}else{
	  return acc;
	}
      }));
}
