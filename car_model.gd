extends Node3D

# Reusable, original low-poly supercar builder. Geometry is generated at runtime.
# Box parts are batched by material and the four wheels use MultiMesh instances
# to keep draw-call counts low on entry-level Android devices.

var _batch_tools: Dictionary = {}
var _batch_materials: Dictionary = {}

func configure(body_color: Color, body_style: int, spoiler_enabled: bool, wheel_style: int) -> void:
	_build_vehicle(body_color, clampi(body_style, 0, 3), spoiler_enabled, clampi(wheel_style, 0, 2))

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.55) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _get_batch(material: StandardMaterial3D) -> SurfaceTool:
	var key := material.get_instance_id()
	if not _batch_tools.has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batch_tools[key] = surface
		_batch_materials[key] = material
	return _batch_tools[key]

func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)

func _add_box(label: String, position_3d: Vector3, dimensions: Vector3, material: StandardMaterial3D, rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	var half := dimensions * 0.5
	var corners: Array[Vector3] = [
		Vector3(-half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, half.y, -half.z),
		Vector3(-half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z),
		Vector3(half.x, -half.y, half.z),
		Vector3(half.x, half.y, half.z),
		Vector3(-half.x, half.y, half.z)
	]
	var basis := Basis.from_euler(Vector3(deg_to_rad(rotation_degrees.x), deg_to_rad(rotation_degrees.y), deg_to_rad(rotation_degrees.z)))
	var transformed: Array[Vector3] = []
	for corner in corners:
		transformed.append(basis * corner + position_3d)
	var surface := _get_batch(material)
	_add_quad(surface, transformed[0], transformed[3], transformed[2], transformed[1])
	_add_quad(surface, transformed[4], transformed[5], transformed[6], transformed[7])
	_add_quad(surface, transformed[0], transformed[1], transformed[5], transformed[4])
	_add_quad(surface, transformed[3], transformed[7], transformed[6], transformed[2])
	_add_quad(surface, transformed[0], transformed[4], transformed[7], transformed[3])
	_add_quad(surface, transformed[1], transformed[2], transformed[6], transformed[5])

func _add_hull(width: float, length: float, material: StandardMaterial3D) -> void:
	# Eight-vertex chamfered hull: narrower shoulders and sloped nose/tail edges.
	var half_width := width * 0.5
	var top_half_width := width * 0.445
	var half_length := length * 0.5
	var vertices: Array[Vector3] = [
		Vector3(-half_width, 0.34, -half_length),
		Vector3(half_width, 0.34, -half_length),
		Vector3(half_width, 0.34, half_length),
		Vector3(-half_width, 0.34, half_length),
		Vector3(-top_half_width, 0.86, -half_length + 0.16),
		Vector3(top_half_width, 0.86, -half_length + 0.16),
		Vector3(top_half_width, 0.86, half_length - 0.14),
		Vector3(-top_half_width, 0.86, half_length - 0.14)
	]
	var surface := _get_batch(material)
	_add_quad(surface, vertices[0], vertices[1], vertices[2], vertices[3])
	_add_quad(surface, vertices[4], vertices[7], vertices[6], vertices[5])
	_add_quad(surface, vertices[0], vertices[4], vertices[5], vertices[1])
	_add_quad(surface, vertices[3], vertices[2], vertices[6], vertices[7])
	_add_quad(surface, vertices[0], vertices[3], vertices[7], vertices[4])
	_add_quad(surface, vertices[1], vertices[5], vertices[6], vertices[2])

func _add_multi_cylinder(label: String, radius: float, height: float, radial_segments: int, material: StandardMaterial3D, positions: Array[Vector3]) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = radial_segments
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = cylinder
	instances.instance_count = positions.size()
	var wheel_basis := Basis.from_euler(Vector3(0, 0, deg_to_rad(90.0)))
	for index in range(positions.size()):
		instances.set_instance_transform(index, Transform3D(wheel_basis, positions[index]))
	var instance_node := MultiMeshInstance3D.new()
	instance_node.name = label
	instance_node.multimesh = instances
	instance_node.material_override = material
	add_child(instance_node)

func _add_wheels(body_width: float, body_length: float, rim_material: StandardMaterial3D, tyre_material: StandardMaterial3D, brake_material: StandardMaterial3D) -> void:
	var wheel_x := body_width * 0.515
	var wheel_z := body_length * 0.325
	var tyre_positions: Array[Vector3] = []
	var rim_positions: Array[Vector3] = []
	var hub_positions: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		for z_position in [-wheel_z, wheel_z]:
			tyre_positions.append(Vector3(side * wheel_x, 0.43, z_position))
			rim_positions.append(Vector3(side * (wheel_x + 0.025), 0.43, z_position))
			hub_positions.append(Vector3(side * (wheel_x + 0.052), 0.43, z_position))
			for spoke_index in range(3):
				var spoke_angle := float(spoke_index) * 120.0
				_add_box("RimSpoke", Vector3(side * (wheel_x + 0.045), 0.43, z_position), Vector3(0.045, 0.29, 0.055), rim_material, Vector3(spoke_angle, 0, 0))
	_add_multi_cylinder("TyreSet", 0.405, 0.30, 20, tyre_material, tyre_positions)
	_add_multi_cylinder("AlloyRimSet", 0.225, 0.325, 24, rim_material, rim_positions)
	_add_multi_cylinder("WheelHubSet", 0.085, 0.34, 12, brake_material, hub_positions)

func _flush_batches() -> void:
	for key in _batch_tools.keys():
		var surface: SurfaceTool = _batch_tools[key]
		surface.generate_normals()
		var instance := MeshInstance3D.new()
		instance.name = "BatchedCarParts"
		instance.mesh = surface.commit()
		instance.material_override = _batch_materials[key]
		add_child(instance)
	_batch_tools.clear()
	_batch_materials.clear()

func _build_vehicle(body_color: Color, body_style: int, spoiler_enabled: bool, wheel_style: int) -> void:
	var widths: Array[float] = [2.00, 2.06, 1.94, 2.12]
	var lengths: Array[float] = [4.00, 4.34, 3.84, 4.48]
	var cabin_lengths: Array[float] = [1.52, 1.72, 1.42, 1.62]
	var cabin_widths: Array[float] = [1.34, 1.38, 1.30, 1.42]
	var body_width: float = widths[body_style]
	var body_length: float = lengths[body_style]
	var cabin_length: float = cabin_lengths[body_style]
	var cabin_width: float = cabin_widths[body_style]

	var paint := _material(body_color, 0.62, 0.24)
	var dark_trim := _material(Color(0.018, 0.025, 0.035), 0.28, 0.34)
	var glass := _material(Color(0.025, 0.075, 0.115), 0.42, 0.13)
	var light_material := _material(Color(0.72, 0.90, 1.0), 0.15, 0.18)
	light_material.emission_enabled = true
	light_material.emission = Color(0.28, 0.55, 0.82)
	var tail_material := _material(Color(0.9, 0.025, 0.018), 0.1, 0.22)
	tail_material.emission_enabled = true
	tail_material.emission = Color(0.7, 0.012, 0.008)
	var tyre_material := _material(Color(0.012, 0.014, 0.018), 0.0, 0.96)
	var brake_material := _material(Color(0.18, 0.20, 0.23), 0.72, 0.38)
	var rim_colors: Array[Color] = [Color(0.70, 0.75, 0.82), Color(0.95, 0.55, 0.10), Color(0.09, 0.11, 0.14)]
	var rim_material := _material(rim_colors[wheel_style], 0.82, 0.27)

	_add_hull(body_width, body_length, paint)
	_add_box("LowerChassis", Vector3(0, 0.43, 0), Vector3(body_width * 0.96, 0.22, body_length * 0.90), dark_trim)
	_add_box("FrontHood", Vector3(0, 0.91, -body_length * 0.285), Vector3(body_width * 0.82, 0.11, body_length * 0.30), paint, Vector3(-5.0, 0, 0))
	_add_box("RearDeck", Vector3(0, 0.91, body_length * 0.315), Vector3(body_width * 0.82, 0.10, body_length * 0.22), paint, Vector3(4.0, 0, 0))
	_add_box("FrontSplitter", Vector3(0, 0.30, -body_length * 0.51), Vector3(body_width * 1.04, 0.09, 0.25), dark_trim)
	_add_box("RearDiffuser", Vector3(0, 0.30, body_length * 0.49), Vector3(body_width * 0.84, 0.13, 0.28), dark_trim)

	var cabin_z := -0.08
	_add_box("CabinShell", Vector3(0, 1.22, cabin_z), Vector3(cabin_width, 0.56, cabin_length), dark_trim, Vector3(-2.0, 0, 0))
	_add_box("RoofPanel", Vector3(0, 1.54, cabin_z + 0.03), Vector3(cabin_width * 0.90, 0.10, cabin_length * 0.56), paint)
	_add_box("FrontWindshield", Vector3(0, 1.34, cabin_z - cabin_length * 0.39), Vector3(cabin_width * 0.84, 0.34, 0.07), glass, Vector3(-31.0, 0, 0))
	_add_box("RearWindow", Vector3(0, 1.34, cabin_z + cabin_length * 0.40), Vector3(cabin_width * 0.82, 0.32, 0.07), glass, Vector3(31.0, 0, 0))
	for side in [-1.0, 1.0]:
		_add_box("SideWindow", Vector3(side * (cabin_width * 0.505), 1.30, cabin_z), Vector3(0.055, 0.29, cabin_length * 0.56), glass)
		_add_box("SideSkirt", Vector3(side * body_width * 0.47, 0.40, 0), Vector3(0.12, 0.16, body_length * 0.62), dark_trim)
		_add_box("SideMirror", Vector3(side * (cabin_width * 0.58), 1.17, -cabin_length * 0.30), Vector3(0.20, 0.10, 0.24), paint)

	for side in [-1.0, 1.0]:
		_add_box("LEDHeadlight", Vector3(side * body_width * 0.31, 0.76, -body_length * 0.505), Vector3(0.42, 0.105, 0.055), light_material)
		_add_box("TailLamp", Vector3(side * body_width * 0.32, 0.75, body_length * 0.505), Vector3(0.43, 0.11, 0.055), tail_material)
		_add_box("HoodVent", Vector3(side * 0.42, 0.975, -body_length * 0.22), Vector3(0.18, 0.025, 0.42), dark_trim)
		_add_box("ExhaustTrim", Vector3(side * 0.48, 0.34, body_length * 0.515), Vector3(0.18, 0.13, 0.07), brake_material)

	_add_box("FrontBadge", Vector3(0, 0.92, -body_length * 0.43), Vector3(0.22, 0.035, 0.18), dark_trim)
	_add_box("RearAccent", Vector3(0, 0.88, body_length * 0.43), Vector3(body_width * 0.46, 0.045, 0.08), dark_trim)
	_add_wheels(body_width, body_length, rim_material, tyre_material, brake_material)

	if spoiler_enabled:
		var spoiler_width := body_width * (0.90 if body_style == 2 else 0.84)
		for side in [-1.0, 1.0]:
			_add_box("SpoilerSupport", Vector3(side * spoiler_width * 0.30, 1.12, body_length * 0.40), Vector3(0.085, 0.38, 0.11), dark_trim)
		_add_box("RearWing", Vector3(0, 1.33, body_length * 0.405), Vector3(spoiler_width, 0.11, 0.42), dark_trim, Vector3(-3.0, 0, 0))

	if body_style == 2:
		for side in [-1.0, 1.0]:
			_add_box("RacingStripe", Vector3(side * 0.30, 0.974, -body_length * 0.28), Vector3(0.10, 0.025, body_length * 0.30), dark_trim)
		_add_box("TrackAeroLip", Vector3(0, 0.25, -body_length * 0.53), Vector3(body_width * 1.08, 0.08, 0.34), dark_trim)

	_flush_batches()
