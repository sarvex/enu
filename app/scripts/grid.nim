import macros, strformat

type
  ColorIndex* = enum
    blue = 1,
    red = 2,
    green = 3,
    black = 4,
    white = 5

  DrawMode* = enum
    GridMode, VoxelMode

var
  speed*: 0.0..250.0 = 30.0
  drawing* = true
  color*: ColorIndex
  mode* = VoxelMode
  overwrite* = false

proc forward*(steps = 1) = discard
proc back*(steps = 1)    = discard
proc left*(degrees = 90.0) = discard
proc right*(degrees = 90.0)= discard
proc up*(steps = 1) = discard
proc down*(steps = 1) = discard
proc fd*(steps = 1)      = forward(steps)
proc bk*(steps = 1)      = back(steps)
proc lt*(degrees = 90.0)   = left(degrees)
proc rt*(degrees = 90.0)   = right(degrees)
proc print*(msg: string)   = discard
proc echo*(msg: string)   = discard
proc sleep*(seconds: float) = discard
proc reset*(clear = false) = discard
proc save*(name = "default") = discard
proc restore*(name = "default") = discard
proc pause*() = discard
proc load_defaults() = discard

proc change_color*(amount: int) =
  var color_index = int color
  color_index += amount
  if color_index > int ColorIndex.high:
    color_index = ColorIndex.low.int
  elif color_index < ColorIndex.low.int:
    color_index = int ColorIndex.high
  color = ColorIndex color_index

proc next_color*() = change_color 1
proc prev_color*() = change_color -1
proc nc*() = next_color()
proc pc*() = prev_color()

proc set_vars*(color_index: int, drw: bool, spd: float, draw_mode: int, ow: bool) =
  color = ColorIndex color_index
  drawing = drw
  speed = spd
  mode = DrawMode draw_mode
  overwrite = ow

proc fill_square*(length = 1) =
  for l in 0..length:
    for i in 0..3:
      forward(length - l)
      right()

template times*(count: int, body: untyped): untyped =
  for x in 0..<count:
    body

macro dump*(x: typed): untyped =
  let s = x.toStrLit
  let r = quote do:
    echo(`s` & " = " & $`x`)
  return r

load_defaults()