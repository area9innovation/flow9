var CMP = HaxeRuntime.compareByValue;
function OTC(fn, fn_name) {
  var top_args;
  global[fn_name] = function() {
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
  global['sc_' + fn_name] = function() {
    top_args = arguments;
  };
}
