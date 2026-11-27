extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_test")

func _check(condition: bool, description: String) -> void:
	if not condition:
		printerr("FAIL: ", description)
		_failures += 1

func _test() -> void:
	var market = (load("res://scenes/world/market_root.tscn") as PackedScene).instantiate()
	root.add_child(market)
	await process_frame
	var cooler: Node3D = market.cooler
	var static_parts := cooler.find_children("*", "MeshInstance3D", true, false)
	var batches := cooler.find_children("*", "MultiMeshInstance3D", true, false)
	var materials := {}
	var meshes := {}
	var placements := 0
	var static_triangles := 0
	var drawn_triangles := 0
	for part in static_parts:
		meshes[part.mesh] = true
		materials[part.get_active_material(0)] = true
		static_triangles += part.mesh.get_faces().size() / 3
		_check(part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "static case has no shadow pass")
	for batch in batches:
		var mesh: Mesh = batch.multimesh.mesh
		meshes[mesh] = true
		var finish: Material = batch.material_override if batch.material_override != null else mesh.surface_get_material(0)
		materials[finish] = true
		placements += batch.multimesh.instance_count
		drawn_triangles += mesh.get_faces().size() / 3 * batch.multimesh.instance_count
		_check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "stock has no shadow pass")
	var unique_triangles := 0
	for mesh in meshes:
		unique_triangles += mesh.get_faces().size() / 3
	var atlas := preload("res://assets/models/cooler_atlas.png")
	_check(atlas.get_size() == Vector2(512, 512), "single 512-square atlas")
	for material in materials:
		_check(material.albedo_texture == atlas and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
			"all cooler surfaces share the nearest-filter atlas")
	_check(materials.size() == 3 and static_parts.size() == 5, "three materials on five static parts")
	_check(batches.size() == 10 and placements == 194, "194 stock facings in ten display batches")
	var surround: MeshInstance3D = cooler.find_child("AisleSurround", true, false)
	var fixture_triangles := static_triangles - surround.mesh.get_faces().size() / 3
	var bottles: Mesh = cooler.bottle_mesh
	var bottle_triangles := bottles.get_faces().size() / 3
	_check(bottle_triangles == 150, "shared Birch Spring counted bottle remains 150 triangles")
	_check(fixture_triangles + unique_triangles - static_triangles + bottle_triangles <= 3000,
		"fixture and unique product meshes fit the 3,000-triangle budget")
	var glass: StandardMaterial3D = cooler.find_child("SafetyGlass", true, false).get_active_material(0)
	_check(glass.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "glass uses the atlas alpha channel")
	var lamps: Array[Light3D] = []
	for light in market.gameplay.security.power.store_lights:
		if light.position.z < -4.7:
			lamps.append(light)
	_check(lamps.size() == 2, "only two cooler lights")
	for light in lamps:
		_check(not light.shadow_enabled, "cooler lights are shadowless")
	var tube: StandardMaterial3D = cooler.find_child("Fluorescents", true, false).get_active_material(0)
	var warm_mesh := market.get_node("Powered warm front window tubes") as MeshInstance3D
	var warm := warm_mesh.get_active_material(0) as StandardMaterial3D
	var pool := market.find_child("Three standing-water depressions",true,false) as MeshInstance3D
	var water := pool.get_active_material(0) as ShaderMaterial
	_check(warm.emission.r > warm.emission.b and warm.emission_energy_multiplier > 1.0
		and bool(water.get_shader_parameter("windows_lit")), "window fixture and its local reflected tint are warm and on")
	var level := tube.emission_energy_multiplier
	market.gameplay.security.power.flip("lights", false)
	_check(level > 0.0 and tube.emission_energy_multiplier == 0.0, "the breaker turns the cooler tubes off")
	_check(warm.emission_energy_multiplier == 0.0 and not bool(water.get_shader_parameter("windows_lit")),
		"the breaker extinguishes the warm window tubes and the windows' reflected tint")
	for light in lamps:
		_check(light.light_energy == 0.0, "the breaker turns the cooler light off")
	market.gameplay.security.power.flip("lights", true)
	_check(tube.emission_energy_multiplier == level, "the breaker restores the cooler tubes")
	_check(warm.emission_energy_multiplier > 1.0 and bool(water.get_shader_parameter("windows_lit")),
		"the breaker restores the warm tubes and their window reflections")
	var flow: FlowUI = market.gameplay.flow
	# This exercises all four runtime modes and deliberately finishes on Quality.
	# Do not write those temporary test choices back to the player's preferences.
	flow.persist_settings = false
	var stock: MultiMeshInstance3D = batches[0]
	var stock_source: BaseMaterial3D = stock.multimesh.mesh.surface_get_material(0)
	for mode in FlowUI.GRAPHICS_MODES:
		flow.settings.graphics_mode = mode
		flow.apply_settings()
		var expected := BaseMaterial3D.SHADING_MODE_PER_VERTEX if mode in ["safe", "performance"] else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_check(stock.material_override.shading_mode == expected, mode + " switches the lighting on cooler stock")
		_check(stock_source.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, mode + " keeps the shared imported material intact")
		market.gameplay.security.power.flip("lights", false)
		_check(tube.emission_energy_multiplier == 0.0, mode + " keeps the cooler tube dark when power is off")
		market.gameplay.security.power.flip("lights", true)
		_check(tube.emission_energy_multiplier == level, mode + " restores the cooler tube")
	print("COOLER ASSET METRICS fixture_triangles=", fixture_triangles, " surround_triangles=", static_triangles-fixture_triangles,
		" unique_stock_triangles=", unique_triangles-static_triangles+bottle_triangles,
		" decorative_triangles=", drawn_triangles, " decorative_instances=", placements,
		" static_surfaces=", static_parts.size(), " decorative_batches=", batches.size(), " materials=", materials.size())
	print("COOLER ASSET TESTS COMPLETE failures=", _failures)
	await market.finish_run(0 if _failures == 0 else 1)
