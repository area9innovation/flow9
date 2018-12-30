import sequtils
import typetraits
import strutils
import unicode

type
  List*[T] = object of RootObj

  Cons*[T] = object of List[T]
    head*: T
    tail*: List[T]

  EmptyList*[T] = object of List[T]

# Runtime for NIM backend

proc fcPrintln2*[Ty](x: Ty): void =
  debugEcho $x

# Get a subrange of an array from index
# if index < 0 or length < 1 it returns an empty array
proc subrange*[T](s: seq[T], index: int, length : int): seq[T] {.inline.} =
  s[index, index + len]

proc length*[T](s: seq[T]): int {.inline.} =
  len(s)

proc concat*[T](s1, s2: seq[T]): seq[T] {.inline.} =
  sequtils.concat(s1, s2)

proc map*[T, S](s: seq[T], op: proc (x: T): S): seq[S] {.inline.} =
  sequtils.map(s, op)

# Replace a given element in an array with a new value. Makes a copy
#native replace : ([?], int, ?) -> [?] = Native.replace;
proc replace*[T](s: seq[T], i: int, v: T): seq[T] =
  if i<0 or s == nil:
    return @[]
  else:
    var s1 = s & @[] # Copy of s
    if len(s1) > i:
      s1[i] = v
    else:
      add(s1, v) # Append item to the end of array, increasing length
    return s1

# Apply a function which takes an index and each element of an array to give a new array
proc mapi*[T, S](s: seq[T], op: proc (i: int, v: T): S): seq[S] =
  var rv: seq[S] = newSeq(length(s))
  for i in 0 .. s.len-1:
    rv[i] = op(i, s[i])
  return rv

proc enumFromTo*(f: int, t: int): seq[int] =
  var n: int = t - f + 1
  var rv: seq[int]

  if (n < 0):
    rv = @[]
    return rv

  for i in 0 .. n-1:
    rv[i] = f + i

  return rv

# Apply a collecting function.  This is a left fold, i.e., it folds with the start of
# the array first, i.e., fold([x1, x2, x3], x0, o) = ((x0 o x1) o x2) o x3
proc fold*[T, S](arr: seq[T], init: S, op: proc(acc: S, v: T): S): S =
  var ini = init
  for x in arr:
    ini = op(ini, x)
  return ini

# Apply a collecting function which takes an index, initial value and each element
proc foldi*[T, S](xs: seq[T], init: S, fn: proc(idx: int, acc: S, v: T): S): S =
  for i in 0..length(xs)-1:
    init = fn(i, init, xs[i])
  return init

# Creates a new array, whose elements are selected from 'a' with a condition 'test'.
proc filter*[T](a: seq[T]; test: proc (v: T): bool): seq[T] =
  return sequtils.filter(a, test)

# Apply a function which takes an index and each element of an array until it returns true
# Returns index of last element function was applied to.
proc iteriUntil*[T](a: seq[T], op: proc(idx: int, v: T): bool): int =
  for i in 0..length(a)-1:
    if op(i, a[i]):
      return i
  return length(a)

# Apply a function to each element of an array
proc iter*[T](a: seq[T], op: proc (v: T): void): void =
  for x in a:
    op(x)
  return

proc isSameStructType*[T1, T2](a: T1, b: T2): bool =
  return name(a.type) == name(b.type)

proc getUrlParameter*(name: string): string =
  ""

proc toString*[T](a: T): string =
  return $a

proc strlen*(s: string): int =
  return len(s);

proc clipLenToRange(start: int, leng: int, size: int): int =
  var leng1 = leng
  var send = start + leng
  if send > size or send  < 0:
    leng1 = size - start
  return leng1

proc substring*(str: string, start: int, leng: int): string =
  var slen = leng
  var sstart = start
  var strlen = len(str)
  if slen < 0:
    if (sstart < 0) :
      slen = 0
    else:
      var smartLen1 = slen + sstart
      if smartLen1 >= 0:
        slen = 0
      else:
        var smartLen2 = smartLen1 + strlen
        if (smartLen2 <= 0):
          slen = 0
        else:
          slen = smartLen2

  if (sstart < 0):
    var smartStart = sstart + strlen
    if (smartStart > 0):
      sstart = smartStart
    else:
      sstart = 0
  else:
    if (sstart >= strlen):
      slen = 0

    if (slen < 1):
      return "";

  slen = clipLenToRange(start, slen, strlen)
  return substr(str, sstart, sstart + slen)

proc strIndexOf*(s: string, sub: string): int =
  return strutils.find(s, sub, 0)

proc toLowerCase*(s: string): string =
  return unicode.toLower(s)

proc toUpperCase*(s: string): string =
  return unicode.toLower(s)

proc getCharCodeAt*(s: string, i: int): int =
  if i >= 0 and i < len(s):
    return cast[int](unicode.runeAt(s, i))
  else:
    return -1

proc strsubsmart*(s: string, start: int, fl0wlen: int): string =
    if start >= 0 and fl0wlen > 0:
      substring(s, start, fl0wlen)
    else:
      var slen: int =
        strlen(s)
      var trueStart: int = (
        if start >= 0: (
          start
        ) else: (
          var ss: int =
            slen+start;
          if ss >= 0: (
            ss
          ) else:
            0
          )
        )
      var trueLength: int =
        if fl0wlen > 0:
          fl0wlen
        else:
          slen+fl0wlen-trueStart
      substring(s, trueStart, trueLength)

proc list2array*[T](list: RootObj): seq[T] =
  var p = list
  var r = newSeq[T]()

  while true:
    echo name(p.type)
    var n = name(p.type)
    case n:
    of "EmptyList":
      break
    of "Cons":
      var c = cast[Cons[T]](p)
      r = r & @[c.head]
      p = c.tail
    else:
      discard

#[
    if (p of EmptyList):
      break
    else:
      if (p of Cons):
        var c = cast[Cons[T]](p)
        r = r & @[c.head]
        p = c.tail
      else:
        discard
]#
  return r


