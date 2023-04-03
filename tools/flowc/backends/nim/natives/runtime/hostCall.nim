{.experimental: "dynamicBindSym".}
import macros

# It works only with fnName = const_string
# if we need to use variables, then we need to create a table function_name-expression

macro hostCall2(fnName : string, vargs: varargs[untyped]): untyped =
  if (vargs != nil and vargs.len > 0):
    let args = vargs[0]
    case args.len:
      of 0: result = newCall(bindSym(fnName))
      of 1: 
        if (args[0] != nil): result = newCall(bindSym(fnName), args[0])
        else:
              result = newCall(bindSym("rt_to_flow"))
      of 2: 
        if (args[0] != nil and args[1] != nil):
              result = newCall(bindSym(fnName), args[0], args[1])
        else:
              result = newCall(bindSym("rt_to_flow"))
      of 3: 
        if (args[0] != nil and args[1] != nil):
              result = newCall(bindSym(fnName), args[0], args[1], args[2])
        else:
              result = newCall(bindSym("rt_to_flow"))
      of 4: 
        if (args[0] != nil and args[1] != nil):
              result = newCall(bindSym(fnName), args[0], args[1], args[2], args[3])
        else:
              result = newCall(bindSym("rt_to_flow"))
      of 5: 
        if (args[0] != nil and args[1] != nil):
              result = newCall(bindSym(fnName), args[0], args[1], args[2], args[3], args[4])
        else:
              result = newCall(bindSym("rt_to_flow"))
      of 6: 
        if (args[0] != nil and args[1] != nil):
              result = newCall(bindSym(fnName), args[0], args[1], args[2], args[3], args[4], args[5])
        else:
              result = newCall(bindSym("rt_to_flow"))
      of 7: 
        if (args[0] != nil and args[1] != nil):
              result = newCall(bindSym(fnName), args[0], args[1], args[2], args[3], args[4], args[5], args[6])
        else:
              result = newCall(bindSym("rt_to_flow"))
      of 8: 
        if (args[0] != nil and args[1] != nil):
              result = newCall(bindSym(fnName), args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7])
        else:
              result = newCall(bindSym("rt_to_flow"))
      of 9: 
        if (args[0] != nil and args[1] != nil):
              result = newCall(bindSym(fnName), args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8])
        else:
              result = newCall(bindSym("rt_to_flow"))
      of 10: 
        if (args[0] != nil and args[1] != nil):
              result = newCall(bindSym(fnName), args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9])
        else:
              result = newCall(bindSym("rt_to_flow"))
      else: result = newCall(bindSym("rt_to_flow"))

macro $F_0(hostCall)*(fnName : string, args: varargs[untyped]): untyped =
  if (args != nil):
    result = quote do:
      when type(hostCall2(`fnName`, `args`)) is void:
        hostCall2(`fnName`, `args`)
        rt_to_flow()
      else : rt_to_flow(hostCall2(`fnName`, `args`))
  else: result = newCall(bindSym("rt_to_flow"))
