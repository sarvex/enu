import ../godotapi / [scene_tree, kinematic_body, material, mesh_instance, spatial, input_event],
       godot,
       math, sugar,
       globals, engine

const
  MOVE_SPEED = 100.0

gdobj NimBot of KinematicBody:
  var
    enu_script* {.gdExport.} = "scripts/scott.nim"
    material* {.gdExport.}, highlight_material* {.gdExport.},
      selected_material* {.gdExport.}: Material

    callback: proc(delta: float): bool
    engine: Engine
    last_error: string
    orig_rotation: Vector3
    orig_translation: Vector3
    skin: Spatial
    mesh: MeshInstance
    paused = false
    selected = false
    running = false

  proc update_material*(value: Material) =
    self.mesh.set_surface_material(0, value)

  proc highlight*() =
    if not self.selected:
      self.update_material(self.highlight_material)

  proc set_default_material*() =
    if not self.selected:
      self.update_material(self.material)

  proc deselect*() =
    self.selected = false
    self.set_default_material()

  proc select*() =
    self.selected = true
    self.update_material self.selected_material
    show_editor self.enu_script
    selected_items.add proc = self.deselect()

  proc print_error(msg: string) =
    if msg != self.last_error:
      self.last_error = msg
      print(msg)

  proc move(speed, steps: float): bool =
    var last_change = vec3(float.high, float.high, float.high)
    let
      facing = BACK.rotated(UP, self.rotation.y)
      finish = self.translation - facing * steps

    self.callback = proc(delta: float): bool =
      let change = abs(finish - self.translation)
      if change > last_change:
        self.translation = finish
        return false
      else:
        discard self.move_and_slide(facing * speed * delta, UP)
        last_change = change
        return true
    true

  proc turn(degrees: float): bool =
    var duration = 0.0
    self.callback = proc(delta: float): bool =
      duration += delta
      self.rotate(UP, deg_to_rad(degrees * delta))
      duration <= 1
    true

  proc forward(steps: float): bool = self.move(-MOVE_SPEED, steps)
  proc back(steps: float): bool = self.move(MOVE_SPEED, steps)
  proc left(degrees: float): bool = self.turn(degrees)
  proc right(degrees: float): bool = self.turn(-degrees)

  proc load_script() =
    debug &"Loading {self.enu_script}"
    self.callback = nil
    if (self.engine = load(self.enu_script); self.engine != nil):
      let e = self.engine
      e.expose("enu", "forward", a => self.forward(get_float(a, 0)))
      e.expose("enu", "back", a => self.back(get_float(a, 0)))
      e.expose("enu", "left", a => self.left(get_float(a, 0)))
      e.expose("enu", "right", a => self.right(get_float(a, 0)))
      e.expose("enu", "print", a => print(get_string(a, 0)))
      self.running = e.call("run")
    else:
      self.running = false
      err &"Unable to load {self.enu_script}"

  method ready*() =
    self.bind_signals("reload", "pause")
    self.skin = self.get_node("Mannequiny").as(Spatial)
    self.mesh = self.skin.get_node("root/Skeleton/body001").as(MeshInstance)
    self.orig_rotation = self.rotation
    self.orig_translation = self.translation
    self.set_default_material()
    self.load_script()

  method physics_process*(delta: float64) =
    if not self.paused:
      try:
        if self.running and (self.callback == nil or not self.callback(delta)):
          self.running = self.engine.resume()
      except:
        self.running = false
        err &"Error resuming {self.enu_script}:\n" &
              get_current_exception_msg()

  method on_reload*() =
    self.translation = self.orig_translation
    self.rotation = self.orig_rotation
    self.paused = false
    self.load_script()

  method on_pause*() =
    self.paused = not self.paused
