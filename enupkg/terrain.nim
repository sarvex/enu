import ../godotapi / [mesh, voxel_terrain, voxel_tool, voxel_library,
                      voxel_buffer, voxel_map, voxel],
       godot,
       globals, core, pen

gdobj Terrain of VoxelTerrain:
  var
    targeted_voxel: Vector3
    current_normal: Vector3
    current_point: Vector3
    pens: Table[string, Pen]
    selected_voxes: VoxSet
    pending_locations: seq[Vector3]
    duration: Duration
    last_duration: Duration
    dirty = false
    voxels_to_clear: seq[Vector3]
    game_ready = false

  method ready*() =
    self.bind_signals(self, ["target_in", "target_out", "target_move",
                             "block_loaded", "target_fire", "target_remove"])
    self.bind_signals("game_ready")

  method on_game_ready() =
    self.game_ready = true

  proc rebuild(voxes: VoxSet) =
    let tool = self.get_voxel_tool()
    for vox in voxes.blocks:
      tool.set_voxel(vox.vec3, vox.index + 1)

  proc find_targeted_voxel(point, normal: Vector3): Vector3 =
    let diffed = (vec3(1, 1, 1) + normal) * 0.5
    result = point - diffed

  proc find_pen(targeted_voxel: Vector3): Option[Pen] =
    for pen in self.pens.values:
      if targeted_voxel.to_vox in pen.voxes.blocks:
        return some(pen)

  proc highlight(targeted_voxel: Vector3) =
    let pen = self.find_pen(targeted_voxel)
    assert pen.is_some
    let
      voxes = pen.get.voxes
      blocks = voxes.blocks
      tool = self.get_voxel_tool()
    if voxes != self.selected_voxes:
      self.selected_voxes = voxes
      for vox in blocks:
        tool.set_voxel(vox.vec3, 1)

  method process*(delta: float) =
    if self.game_ready:
      if self.dirty:
        self.save_modified_blocks()
        self.dirty = false
      elif self.voxels_to_clear.len > 0:
        echo &"clearing {self.voxels_to_clear.len} voxels"
        let tool = self.get_voxel_tool()
        for loc in self.voxels_to_clear:
          tool.set_voxel_metadata(loc, new_variant())
          tool.set_voxel(loc, 0)
        self.voxels_to_clear = @[]
        self.dirty = true

  method on_block_loaded(location: Vector3, buffer: VoxelBuffer) =
    let uniform = buffer.is_uniform(0)
    if not uniform or (uniform and buffer.get_voxel(0, 0, 0) != 0):
      let
        size_x = buffer.get_size_x
        size_y = buffer.get_size_y
        size_z = buffer.get_size_z

      for x in 0..<size_x:
        for y in 0..<size_y:
          for z in 0..<size_z:
            let v = buffer.get_voxel(x, y, z)
            if v > 0:
              let m = buffer.get_voxel_metadata(vec3(float x, float y, float z))
              assert m.get_type == VariantType.String
              let
                metadata = m.as_string
                parts = metadata.split(":")
                id = parts[0]
                index = parts[1].parse_int

                offset = self.block_to_voxel(location)
                voxel_location = offset + vec3(float x, float y, float z)
              if id in self.pens:
                let p = self.pens[id]
                p.voxes.blocks.incl voxel_location.to_vox(index)
              else:
                self.voxels_to_clear.add(voxel_location)

  method on_target_move(point, normal: Vector3) =
    self.current_point = point
    self.current_normal = normal
    let targeted_voxel = self.find_targeted_voxel(point, normal)
    if targeted_voxel != self.targeted_voxel:
      self.targeted_voxel = targeted_voxel
      if tool_mode == CodeMode:
        self.highlight(targeted_voxel)

  method on_target_out() =
    self.targeted_voxel = vec3()
    if self.selected_voxes != nil:
      self.rebuild(self.selected_voxes)
      self.selected_voxes = nil

  method on_target_in() =
    # we don't need this right now. Thanks for the memories.
    discard

  method on_target_fire() =
    if tool_mode == BlockMode:
      let pen = self.find_pen(self.targeted_voxel)
      assert pen.is_some
      pen.get.draw(self.targeted_voxel + self.current_normal, 1)

    if tool_mode == CodeMode:
      let pen = self.find_pen(self.targeted_voxel)
      assert pen.is_some
      pen.get.builder.trigger("selected")

  method on_target_remove() =
    if tool_mode == BlockMode:
      let pen = self.find_pen(self.targeted_voxel)
      assert pen.is_some
      pen.get.draw(self.targeted_voxel, -1)

type
  VoxelPen* = ref object of Pen
    voxel_tool: VoxelTool
    terrain: Terrain

proc init*(typ:typedesc[VoxelPen], builder: Node, id: string, voxes: VoxSet): VoxelPen =
  let terrain = game_node.find_node("Terrain") as Terrain
  assert terrain != nil
  let tool = terrain.get_voxel_tool()
  assert tool != nil
  result = VoxelPen(builder: builder, terrain: terrain, voxel_tool: tool,
                    id: id, voxes: voxes)
  terrain.pens[id] = result

method draw*(self: VoxelPen, location: Vector3, index: int, save = true) =
  self.terrain.dirty = true
  let metadata = self.id & ":" & $index
  let variant = if index == -1:
    new_variant()
  else:
    metadata.to_variant

  self.voxel_tool.set_voxel_metadata(location, variant)
  self.voxel_tool.set_voxel(location, index + 1)
  if save:
    self.voxes.blocks.incl location.to_vox(index)
