# getCurrentDate : io () -> Date = Native.getCurrentDate;
# Date(year : int, month : int, day : int);

proc getCurrentDate*(): Date =
  let dt = now()
  return make_Date(int32(dt.year), int32(ord(month(dt))), int32(ord(monthday(dt))))