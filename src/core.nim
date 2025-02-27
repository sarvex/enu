import types
export types

import pkg / model_citizen / utils
export utils

### Globals ###
const enu_version* = static_exec("git describe --tags HEAD")
var state* {.threadvar.}: GameState

### Sugar ###
from sugar import dup, dump, collect
import std / [with, times, monotimes]
import pkg / [print, flatty]

export with, sets, tables, print, flatty

### Debug
export dump

import pkg / chronicles
export chronicles

template nim_filename*: string = instantiation_info(full_paths = true).filename

### times ###
export monotimes

proc seconds*(s: float): Duration {.inline.} =
  init_duration(milliseconds = int(s * 1000))

### options ###
import options
export options

proc `||=`*[T](opt: var Option[T], val: T): T {.discardable.} =
  if not opt.is_some:
    opt = some(val)
    result = val
  else:
    result = opt.get()

proc `||`*[T](a, b: T): T =
  if ?a:
    a
  else:
    b

converter from_option*[T](val: Option[T]): T =
  val.get()

proc optional_get*[T](self: var HashSet[T], key: T): Option[T] =
  if key in self:
    result = some(self[key])
  else:
    result = none(T)

### Vector3 ###
import core/godotcoretypes, core/vector3, math

const
  UP* = vec3(0, 1, 0)
  DOWN* = vec3(0, -1, 0)
  BACK* = vec3(0, 0, 1)
  FORWARD* = vec3(0, 0, -1)
  RIGHT* = vec3(1, 0, 0)
  LEFT* = vec3(-1, 0, 0)

proc vec3*(x, y, z: int): Vector3 {.inline.} =
  vec3(x.float, y.float, z.float)

proc vec3*(x: int | float): Vector3 {.inline.} =
  vec3(x, x, x)

proc trunc*(self: Vector3): Vector3 {.inline.} =
  vec3(trunc(self.x), trunc(self.y), trunc(self.z))

proc inverse_normalized*(self: Vector3): Vector3 {.inline.} =
  (self - vec3(self.length, self.length, self.length)) * -1

proc first*[T](arr: open_array[T], test: proc(x: T): bool): Option[T] =
  for item in arr:
    if test(item):
      return some(item)

proc round*(v: Vector3): Vector3 {.inline.} =
  vec3(v.x.round(), v.y.round(), v.z.round())

proc is_axis_aligned*(v: Vector3): bool {.inline.} =
  v in [UP, DOWN, LEFT, RIGHT, FORWARD, BACK]

# Basis

proc `x=`*(self: var Basis, value: Vector3) {.inline.} =
  self.elements[0].x = value.x
  self.elements[1].x = value.y
  self.elements[2].x = value.z

proc `y=`*(self: var Basis, value: Vector3) {.inline.} =
  self.elements[0].y = value.x
  self.elements[1].y = value.y
  self.elements[2].y = value.z

proc `z=`*(self: var Basis, value: Vector3) {.inline.} =
  self.elements[0].z = value.x
  self.elements[1].z = value.y
  self.elements[2].z = value.z

proc surrounding*(point: Vector3): seq[Vector3] =
  collect(new_seq):
    for x in 0..2:
      for y in 0..2:
        for z in 0..2:
          point + vec3(x - 1, y - 1, z - 1)

# math
const CMP_EPSILON = 0.00001
proc roughly_zero[T](s: T): bool =
  abs(s) < CMP_EPSILON

proc lerp*(self, other, t: float): float {.inline.} =
  self + t * (other - self)

proc wrap*[T](value, min, max: T): float =
  let range = max - min
  if range.roughly_zero:
    min
  else:
    value - (range * floor((value - min) / range))

# output

when not defined(no_godot):
  import pkg / godot

  default_chronicles_stream.output.writer =
    proc (logLevel: LogLevel, msg: LogOutputStr) {.gcsafe.} =
      godot.print msg

# misc
import pkg / core / transforms
export transforms

import godotapi / [spatial]
import pkg / godot

proc from_flatty*[N: NimGodotObject](s: string, i: var int, n: N) =
  discard

proc to_flatty*[N: NimGodotObject](s: var string, n: N) =
  discard

proc from_flatty*(s: string, i: var int, n: var ScriptCtx) =
  discard

proc to_flatty*(s: var string, n: ScriptCtx) =
  discard

import pkg / model_citizen
export model_citizen except `%`

Zen.register_type(Player)
Zen.register_type(Build)
Zen.register_type(Sign)
Zen.register_type(Bot)
Zen.register_type(Shared)

proc local_to*(self: Vector3, unit: Unit): Vector3 =
  result = self
  var unit = unit
  while unit != nil:
    result -= unit.node.transform.origin
    unit = unit.parent

proc global_from*(self: Vector3, unit: Unit): Vector3 =
  result = -self.local_to(unit)

proc `+=`*(self: ZenValue[string], str: string) =
  self.value = self.value & str

proc origin*(self: ZenValue[Transform]): Vector3 =
  self.value.origin

proc `origin=`*(self: ZenValue[Transform], value: Vector3) =
  var transform = self.value
  transform.origin = value
  self.value = transform

proc basis*(self: ZenValue[Transform]): Basis =
  self.value.basis

proc `basis=`*(self: ZenValue[Transform], value: Basis) =
  var transform = self.value
  transform.basis = value
  self.value = transform

proc init*(_: type Basis): Basis = init_basis()

proc init*(_: type Transform, origin = vec3()): Transform =
  result = init_transform()
  result.origin = origin

proc init*(_: type Code, nim: string): Code =
  Code(owner: state.worker_ctx_name, nim: nim)

proc update_action_index*(state: GameState, change: int) =
  var index = int(state.tool.value) + change
  if index < 0:
    index = int Tools.high
  elif index > int Tools.high:
    index = int Tools.low

  state.tool.value = Tools(index)

# Workaround for templates not supporting {.discardable.}
proc maybe_discard*[T](self: T): T {.discardable, inline.} = self

template watch*(zen: Zen, unit: untyped, body: untyped) =
  when unit is Unit:
    let zid = zen.changes:
      body
    unit.zids.add(zid)
    maybe_discard(zid)
  else:
    {. error:
      "Watch needs a Unit object to bind its lifetime to. The Unit " &
      "can be passed explicitly, or found implicitly by evaluating " &
      "`self.model`, then `self`." .}

template watch*(zen: Zen, body: untyped) =
  when compiles(self.model):
    watch(zen, self.model, body)
  else:
    watch(zen, self, body)

# from https://forum.nim-lang.org/t/5481#34239
macro enum_fields*(n: typed): untyped =
  let impl = get_type(n)
  expect_kind impl[1], nnk_enum_ty
  result = nnk_bracket.new_tree()
  for f in impl[1]:
    case f.kind
    of nnk_sym, nnk_ident:
      result.add new_lit(f.str_val)
    else: discard
