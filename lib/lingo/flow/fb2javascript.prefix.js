var CMP = HaxeRuntime.compareByValue;
var CME = HaxeRuntime.compareEqual;
function OTC(fn, fn_name) {
  var top_args;
  window[fn_name] = function() {
    var result, old_top_args = top_args;
    top_args = arguments;
    while (top_args !== null) {
      var cur_args = top_args;
      top_args = null;
      result = fn.apply(null, cur_args);
    }
    top_args = old_top_args;
    return result;
  };
  window['sc_' + fn_name] = function() { top_args = arguments; };
}
