import std / [strutils, tables]
import pkg / [godot]
import pkg / compiler / [lineinfos]
import godotapi / [text_edit, scene_tree, node, input_event, global_constants,
                   input_event_key, style_box_flat, gd_os]
import core, globals
import models except Color

gdobj Editor of TextEdit:
  var
    comment_color* {.gdExport.} = init_color(0.5, 0.5, 0.5)
    og_bg_color: Color
    dirty = false
    open_script_ctx: ScriptCtx

  proc set_open_script_ctx() =
    # TODO: yuck
    var current = self.open_script_ctx
    if ?state.open_unit.value and ?state.open_unit.value.script_ctx:
      current = state.open_unit.value.script_ctx
    if self.open_script_ctx != current:
      if ?self.open_script_ctx:
        self.open_script_ctx.line_changed = nil

    if not state.open_unit.value.is_nil and not state.open_unit.value.script_ctx.is_nil:
      self.open_script_ctx = state.open_unit.value.script_ctx
      if ?self.open_script_ctx:
        self.executing_line = int self.open_script_ctx.current_line.line - 1
        self.open_script_ctx.line_changed = proc(current: TLineInfo, previous: TLineInfo) =
          self.executing_line = int current.line - 1

  proc indent_new_line() =
    let column = int self.cursor_get_column - 1
    if column > 0:
      let
        line = self.get_line(self.cursor_get_line)[0..column]
        stripped = line.strip()

      if stripped.high > 0:
        let last = $stripped[stripped.high]

        if (stripped in ["var", "let", "const", "type"]) or last in [":", "="]:
          let spaces = " ".repeat(line.indentation + 2)
          self.insert_text_at_cursor("\n" & spaces)
          self.get_tree.set_input_as_handled()

  method input*(event: InputEvent) =
    var event = event.as(InputEventKey)
    if not event.is_nil and event.pressed:
      if event.scancode == KEY_ENTER:
        self.indent_new_line()
      if event.scancode == KEY_SEMICOLON and state.config.semicolon_as_colon:
        self.insert_text_at_cursor(":")
        self.get_tree.set_input_as_handled()
      elif event.scancode == KEY_HOME:
        self.cursor_set_column(0)
        self.get_tree.set_input_as_handled()
      elif event.scancode == KEY_END:
        self.cursor_set_column self.get_line(self.cursor_get_line).len
        self.get_tree.set_input_as_handled()

  method unhandled_input*(event: InputEvent) =
    if EditorFocused in state.flags and event.is_action_pressed("ui_cancel"):
      if not (event of InputEventJoypadButton) or CommandMode notin state.flags:
        state.open_unit.value.code.value = Code.init(self.text)
        state.open_unit.value = nil
        self.get_tree().set_input_as_handled()

  proc configure_highlighting =
    # strings
    self.add_color_region("\"\"\"", "\"\"\"", ir_black[normal], false)
    self.add_color_region("\"", "\"", ir_black[text], false)
    # block comments
    self.add_color_region("#[", "]#", self.comment_color, false)
    # line comments
    self.add_color_region("#", "\n", self.comment_color, true)

  proc clear_errors =
    for i in 0..<self.get_line_count():
      self.set_line_as_marked(i, false)

  proc highlight_errors =
    self.clear_executing_line()
    self.set_open_script_ctx()
    if not self.open_script_ctx.is_nil:
      for err in self.open_script_ctx.errors:
        self.set_line_as_marked(int64(err.info.line - 1), true)

  proc `executing_line=`*(line: int) =
    if self.get_line_count >= line:
      self.set_executing_line(line)

  method on_text_changed() =
    self.dirty = true

  method ready* =
    self.bind_signals(self, "text_changed")
    var stylebox = self.get_stylebox("normal").as(StyleBoxFlat)
    self.og_bg_color = stylebox.bg_color

    state.flags.changes:
      if ConsoleVisible.added:
        self.highlight_errors()
      elif ConsoleVisible.removed:
        self.clear_errors()
      elif EditorFocused.added:
        self.grab_focus

    state.open_unit.changes:
      if added:
        let unit = change.item
        if unit.is_nil:
          self.release_focus()
          self.visible = false
          if ?self.open_script_ctx:
            self.open_script_ctx.line_changed = nil
            self.open_script_ctx = nil
        else:
          self.visible = true
          self.set_open_script_ctx()
          self.text = state.open_unit.value.code.value.nim
          if CommandMode in state.flags:
            self.modulate = dimmed_alpha
          else:
            self.modulate = solid_alpha
            self.grab_focus()
          self.clear_errors()
          self.highlight_errors()

    state.flags.changes:
      if EditorFocused.added:
        self.grab_focus
      if CommandMode.added:
        if EditorVisible in state.flags:
          state.open_unit.value.code.value = Code.init(self.text)

          self.modulate = dimmed_alpha
          self.release_focus

      elif CommandMode.removed:
        if EditorVisible in state.flags:
          self.modulate = solid_alpha
          self.grab_focus

    self.configure_highlighting()
