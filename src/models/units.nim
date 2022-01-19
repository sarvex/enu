import std / os
import pkg / model_citizen
import godotapi / node
import core, models / [types, states], engine / engine

proc init*(_: type Model, node: Node): Model =
  result = Model(flags: ZenSet[ModelFlags].init, node: node)

proc data_dir*(self: Unit): string =
  if self.parent.is_nil:
    GameState.active.config.data_dir / self.id
  else:
    self.parent.data_dir / self.id

proc script_file*(self: Unit): string =
  GameState.active.config.script_dir / self.id & ".nim"

proc data_file*(self: Unit): string =
  self.data_dir / self.id & ".json"

method on_begin_move*(self: Unit, direction: Vector3, steps: float): Callback {.base.} =
  quit "override me"

method on_begin_turn*(self: Unit, direction: Vector3, degrees: float): Callback {.base.} =
  quit "override me"

method clone*(self: Unit, clone_to: Unit, ctx: ScriptCtx): Unit {.base.} =
  quit "override me"

method code_template*(self: Unit, imports: string): string {.base.} =
  quit "override me"

method on_script_loaded*(self: Unit) {.base.} =
  quit "override me"

method load_vars*(self: Unit) {.base.} =
  quit "override me"

method reset*(self: Unit) {.base.} =
  quit "override me"
