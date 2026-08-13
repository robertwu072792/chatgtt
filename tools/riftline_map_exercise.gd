extends SceneTree

func _initialize() -> void:
	var root := Node3D.new()
	root.name = "NuclearRushMapExercise"
	get_root().add_child(root)

	var layout: Dictionary = RiftlineMapLayout.build()
	_assert_layout_contract(layout)

	var concourse := RiftlineMap.new()
	root.add_child(concourse)
	concourse.configure(RiftlineMap.Id.CONCOURSE, false)
	await process_frame
	assert(not _contains_mesh(concourse))
	assert(concourse.ambient_motion_count() == 0)
	assert(concourse.solid_count() == (layout.solids as Array).size())
	_assert_team_symmetry(concourse)
	_assert_spawn_clearance(concourse)
	await _assert_central_bridge_access(concourse)
	await _assert_central_bridge_crossing(concourse)
	await _assert_overlook_access_and_passage(concourse)
	_assert_routes(concourse)
	_assert_tactical_facts(concourse)
	_assert_sightlines(concourse)

	var rendered := RiftlineMap.new()
	root.add_child(rendered)
	rendered.configure(RiftlineMap.Id.CONCOURSE, true)
	assert(_contains_mesh(rendered))
	var visual_root := _find_named_node(rendered, "ConcourseV2Visual")
	assert(visual_root != null)
	assert(visual_root.get_child_count() == 1)
	assert(_find_named_node(visual_root, "ImportedEnvironment") != null)
	_assert_shadowless_meshes(rendered)
	assert(rendered.ambient_motion_count() == 0)
	assert(rendered.is_spawn_clear(rendered.core_spawn_position()))
	assert(rendered.is_spawn_clear(rendered.launch_pad_positions()[Duelist.Team.RED]))
	assert(rendered.is_spawn_clear(rendered.launch_pad_positions()[Duelist.Team.BLUE]))
	assert(rendered.solid_count() == concourse.solid_count())

	# The visual shell has no animated map nodes; objective presentation is
	# owned by RiftlineArena's match presentation layer.
	rendered.pulse_objective()
	assert(not rendered.is_processing())

	print("Nuclear Rush Concourse V2 map exercise: PASS")
	quit()

func _assert_layout_contract(layout: Dictionary) -> void:
	for key in ["solids", "route_graphs", "spawns", "launch_pads", "gates", "core_spawn", "tactical_facts"]:
		assert(layout.has(key), "layout is missing key: %s" % key)
	var solids: Array = layout.solids
	assert(solids.size() > 80)
	for solid_variant in solids:
		var solid: Dictionary = solid_variant
		assert(solid.keys().size() == 9)
		for key in ["name", "shape", "position", "dimensions", "rotation_y", "rise", "material_role", "route_blocker", "casts_shadow"]:
			assert(solid.has(key), "solid is missing key: %s" % key)
		assert(solid.position is Vector3)
		assert(solid.dimensions is Vector3)
	_assert_bridge_ramp_record(solids, "CentralBridgeRamp_W", Vector3(-16.5, 0.0, 0.0), 0.0)
	_assert_bridge_ramp_record(solids, "CentralBridgeRamp_E", Vector3(16.5, 0.0, 0.0), PI)
	_assert_bridge_support_record(solids, "CoreColumn_W", Vector3(-5.0, 1.3, 0.0))
	_assert_bridge_support_record(solids, "CoreColumn_E", Vector3(5.0, 1.3, 0.0))
	_assert_overlook_reference_platform_records(solids)
	for solid_variant in solids:
		var solid: Dictionary = solid_variant
		var solid_name := str(solid.name)
		assert(solid_name != "CentralBridgeSightlineBreak",
			"the old full-width bridge blocker must be removed")
		assert(not solid_name.contains("UpperConnector"),
			"the deleted diagonal upper connector must not have collision: %s" % solid_name)
		assert(not solid_name.contains("UpperSightlineBreak"),
			"the deleted diagonal upper connector blocker must not survive: %s" % solid_name)

	var graphs: Dictionary = layout.route_graphs
	for lane in ["auto", "center", "maintenance", "overlook"]:
		assert(graphs.has(lane), "route graph is missing lane: %s" % lane)
		var graph: Dictionary = graphs[lane]
		var target_range: Vector2 = graph.target_range
		var nominal_distance: float = graph.gate_core_distance
		assert(nominal_distance >= target_range.x and nominal_distance <= target_range.y)
		assert(is_equal_approx(nominal_distance, float(graph.rotated_gate_core_distance)))
		assert(absf(float(graph.authored_path_length) - nominal_distance) < 8.0)

func _assert_bridge_ramp_record(solids: Array, wanted_name: String, wanted_position: Vector3, wanted_rotation: float) -> void:
	for solid_variant in solids:
		var solid: Dictionary = solid_variant
		if str(solid.name) != wanted_name:
			continue
		assert(str(solid.shape) == "ramp")
		assert((solid.position as Vector3).is_equal_approx(wanted_position))
		assert((solid.dimensions as Vector3).is_equal_approx(Vector3(9.0, 0.2, 4.5)))
		assert(is_equal_approx(float(solid.rotation_y), wanted_rotation))
		assert(is_equal_approx(float(solid.rise), 3.2))
		assert(not bool(solid.route_blocker))
		return
	assert(false, "missing central bridge access ramp: %s" % wanted_name)

func _assert_bridge_support_record(solids: Array, wanted_name: String, wanted_position: Vector3) -> void:
	for solid_variant in solids:
		var solid: Dictionary = solid_variant
		if str(solid.name) != wanted_name:
			continue
		assert((solid.position as Vector3).is_equal_approx(wanted_position))
		assert((solid.dimensions as Vector3).is_equal_approx(Vector3(1.4, 2.6, 1.4)))
		var top: float = (solid.position as Vector3).y + (solid.dimensions as Vector3).y * 0.5
		assert(top <= 2.6, "bridge support protrudes through the deck: %s" % wanted_name)
		return
	assert(false, "missing bridge support: %s" % wanted_name)

func _assert_overlook_reference_platform_records(solids: Array) -> void:
	var expected: Array[Dictionary] = [
		{"name": "OverlookFloorEntrance", "shape": "box", "position": Vector3(25.4, 2.9, 14.8), "dimensions": Vector3(6.8, 0.6, 7.2), "rotation": 0.0},
		{"name": "OverlookFloorCombat", "shape": "box", "position": Vector3(26.7, 2.9, 25.4), "dimensions": Vector3(9.4, 0.6, 14.0), "rotation": 0.0},
		{"name": "OverlookFloorRear", "shape": "box", "position": Vector3(25.6, 2.9, 35.6), "dimensions": Vector3(7.2, 0.6, 6.4), "rotation": 0.0},
		{"name": "OverlookOuterRailEntryEnd", "shape": "box", "position": Vector3(25.4, 3.85, 11.2), "dimensions": Vector3(6.8, 1.3, 0.34), "rotation": 0.0},
		{"name": "OverlookOuterRailEntry", "shape": "box", "position": Vector3(28.8, 3.85, 14.8), "dimensions": Vector3(0.34, 1.3, 7.2), "rotation": 0.0},
		{"name": "OverlookOuterRailWiden", "shape": "box", "position": Vector3(30.1, 3.85, 18.4), "dimensions": Vector3(2.6, 1.3, 0.34), "rotation": 0.0},
		{"name": "OverlookOuterRailCombat", "shape": "box", "position": Vector3(31.4, 3.85, 25.4), "dimensions": Vector3(0.34, 1.3, 14.0), "rotation": 0.0},
		{"name": "OverlookOuterRailNarrow", "shape": "box", "position": Vector3(30.3, 3.85, 32.4), "dimensions": Vector3(2.2, 1.3, 0.34), "rotation": 0.0},
		{"name": "OverlookOuterRailRear", "shape": "box", "position": Vector3(29.2, 3.85, 35.6), "dimensions": Vector3(0.34, 1.3, 6.4), "rotation": 0.0},
		{"name": "OverlookOuterRailRearEnd", "shape": "box", "position": Vector3(25.6, 3.85, 38.8), "dimensions": Vector3(7.2, 1.3, 0.34), "rotation": 0.0},
		{"name": "OverlookInnerGlass", "shape": "box", "position": Vector3(22.05, 4.12, 30.25), "dimensions": Vector3(0.30, 1.84, 15.5), "rotation": 0.0},
		{"name": "OverlookBlastWall", "shape": "box", "position": Vector3(25.5, 5.0, 19.55), "dimensions": Vector3(1.16, 3.6, 5.42), "rotation": deg_to_rad(25.0)},
		{"name": "OverlookEquipmentBox", "shape": "box", "position": Vector3(24.1, 3.95, 27.35), "dimensions": Vector3(3.25, 1.5, 2.1), "rotation": 0.0},
		{"name": "OverlookMainStair", "shape": "ramp", "position": Vector3(17.5, 0.0, 14.8), "dimensions": Vector3(9.0, 0.2, 5.4), "rotation": 0.0},
	]
	var stair_count := 0
	for team_sign_variant in [-1.0, 1.0]:
		var team_sign: float = float(team_sign_variant)
		var team_name := "Blue" if team_sign < 0.0 else "Red"
		for record_variant in expected:
			var record: Dictionary = record_variant
			var wanted_name := team_name + str(record.name)
			var found := false
			for solid_variant in solids:
				var solid: Dictionary = solid_variant
				if str(solid.name) != wanted_name:
					continue
				found = true
				var local_position: Vector3 = record.position
				assert((solid.position as Vector3).is_equal_approx(Vector3(team_sign * local_position.x, local_position.y, team_sign * local_position.z)))
				assert((solid.dimensions as Vector3).is_equal_approx(record.dimensions as Vector3))
				var expected_rotation: float = float(record.rotation) + (PI if team_sign < 0.0 else 0.0)
				assert(is_equal_approx(float(solid.rotation_y), expected_rotation))
				assert(str(solid.shape) == str(record.shape))
				if str(record.name) == "OverlookMainStair":
					stair_count += 1
					assert(is_equal_approx(float(solid.rise), 3.2))
					assert(not bool(solid.route_blocker))
				break
			assert(found, "missing reference-style overlook piece: %s" % wanted_name)
	assert(stair_count == 2, "each mirrored platform must have exactly one main stair")

	# Every corner of the rotated wall stays at least 0.5 m inside the local deck.
	var wall_center := Vector2(25.5, 19.55)
	var wall_half := Vector2(1.16, 5.42) * 0.5
	var wall_angle := deg_to_rad(25.0)
	for local_x_variant in [-wall_half.x, wall_half.x]:
		var local_x: float = float(local_x_variant)
		for local_z_variant in [-wall_half.y, wall_half.y]:
			var local_z: float = float(local_z_variant)
			var corner := wall_center + Vector2(
				local_x * cos(wall_angle) + local_z * sin(wall_angle),
				-local_x * sin(wall_angle) + local_z * cos(wall_angle))
			var outer_edge := 28.8 if corner.y <= 18.4 else 31.4
			assert(corner.x >= 22.5 and corner.x <= outer_edge - 0.5,
				"blast-wall corner violates 0.5 m deck clearance: %s" % corner)
			assert(corner.y >= 11.7 and corner.y <= 38.3,
				"blast-wall corner leaves the deck: %s" % corner)
	for solid_variant in solids:
		var solid: Dictionary = solid_variant
		var solid_name := str(solid.name)
		assert(not solid_name.contains("OverlookBaffle"), "old boxed-corridor baffle survived: %s" % solid_name)
		assert(not solid_name.ends_with("OverlookOuterWall"), "old full-height outer wall survived: %s" % solid_name)
		assert(not solid_name.contains("OverlookCoverSouth") and not solid_name.contains("OverlookCoverNorth"),
			"duplicate overlook cover survived: %s" % solid_name)
		assert(not solid_name.contains("OverlookDivider"),
			"rejected diagonal overlook divider survived: %s" % solid_name)
		assert(not solid_name.contains("OverlookGateHeader"),
			"rejected overhead gate wall survived: %s" % solid_name)
		assert(not solid_name.contains("OverlookGateInner") and not solid_name.contains("OverlookGateOuter"),
			"rejected repeated gate pylon survived: %s" % solid_name)
		assert(not solid_name.contains("OverlookFloorMain") and not solid_name.contains("OverlookFloorTurnExtension"),
			"rejected straight-bridge floor survived: %s" % solid_name)
		assert(not solid_name.contains("OverlookRamp"),
			"a second legacy overlook stair survived: %s" % solid_name)

func _assert_central_bridge_access(map: RiftlineMap) -> void:
	for side_variant in [-1.0, 1.0]:
		var side: float = float(side_variant)
		var body := CharacterBody3D.new()
		body.name = "BridgeAccessProbe_%s" % ("W" if side < 0.0 else "E")
		body.floor_snap_length = 0.45
		body.floor_max_angle = deg_to_rad(46.0)
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.45
		capsule.height = 1.8
		collision.shape = capsule
		body.add_child(collision)
		map.add_child(body)
		body.global_position = Vector3(side * 21.5, 1.05, 0.0)
		await physics_frame
		var direction: float = -side
		for _step in 180:
			body.velocity.x = direction * 5.0
			body.velocity.z = 0.0
			if not body.is_on_floor():
				body.velocity.y -= 18.0 / 60.0
			else:
				body.velocity.y = 0.0
			body.move_and_slide()
			await physics_frame
			if body.global_position.x * side < 12.0 and body.global_position.y > 3.8:
				break
		assert(body.global_position.x * side < 12.5,
			"central bridge ramp did not reach the deck from side %s: %s" % [side, body.global_position])
		assert(body.global_position.y > 3.8,
			"central bridge ramp left the player below the deck from side %s: %s" % [side, body.global_position])
		body.queue_free()
		await physics_frame

func _assert_central_bridge_crossing(map: RiftlineMap) -> void:
	var body := CharacterBody3D.new()
	body.name = "BridgeThroughRouteProbe"
	body.floor_snap_length = 0.45
	body.floor_max_angle = deg_to_rad(46.0)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	collision.shape = capsule
	body.add_child(collision)
	map.add_child(body)
	body.global_position = Vector3(-5.0, 4.1, 0.0)
	await physics_frame
	for _step in 300:
		body.velocity.x = 5.0
		body.velocity.z = 0.0
		if not body.is_on_floor():
			body.velocity.y -= 18.0 / 60.0
		else:
			body.velocity.y = 0.0
		body.move_and_slide()
		await physics_frame
		if body.global_position.x > 4.5:
			break
	assert(body.global_position.x > 4.5,
		"central bridge still blocks the open through route: %s" % body.global_position)
	assert(body.global_position.y > 3.8,
		"central bridge crossing dropped the player below the deck: %s" % body.global_position)
	body.queue_free()
	await physics_frame

func _assert_overlook_access_and_passage(map: RiftlineMap) -> void:
	for team_sign_variant in [-1.0, 1.0]:
		var team_sign: float = float(team_sign_variant)
		var ramp_probe := _make_player_probe("OverlookMainStairProbe_%s" % team_sign)
		map.add_child(ramp_probe)
		ramp_probe.global_position = Vector3(team_sign * 12.5, 1.05, team_sign * 14.8)
		await physics_frame
		for _step in 240:
			ramp_probe.velocity.x = team_sign * 5.0
			ramp_probe.velocity.z = 0.0
			_apply_probe_gravity(ramp_probe)
			ramp_probe.move_and_slide()
			await physics_frame
			if ramp_probe.global_position.x * team_sign > 22.5 and ramp_probe.global_position.y > 3.8:
				break
		assert(ramp_probe.global_position.x * team_sign > 22.4,
			"main overlook stair did not reach its flat landing: %s" % ramp_probe.global_position)
		assert(ramp_probe.global_position.y > 3.8,
			"main overlook stair left the player below its landing: %s" % ramp_probe.global_position)
		ramp_probe.queue_free()
		await physics_frame

		var passage_probe := _make_player_probe("OverlookPassageProbe_%s" % team_sign)
		map.add_child(passage_probe)
		# Start on the arena floor and physically climb the sole stair, then use the
		# broad outer lane around the angled wall and offset equipment cover.
		passage_probe.global_position = Vector3(team_sign * 12.5, 1.05, team_sign * 14.8)
		await physics_frame
		var local_waypoints: Array[Vector2] = [
			Vector2(22.8, 14.8), Vector2(27.8, 15.2), Vector2(29.0, 18.9),
			Vector2(29.2, 23.5), Vector2(28.8, 29.8), Vector2(27.4, 35.5),
		]
		for waypoint in local_waypoints:
			var world_target := Vector3(team_sign * waypoint.x, 4.1, team_sign * waypoint.y)
			for _step in 240:
				var offset := world_target - passage_probe.global_position
				offset.y = 0.0
				if offset.length() < 0.35:
					break
				var direction := offset.normalized()
				passage_probe.velocity.x = direction.x * 5.0
				passage_probe.velocity.z = direction.z * 5.0
				_apply_probe_gravity(passage_probe)
				passage_probe.move_and_slide()
				await physics_frame
			assert(Vector2(passage_probe.global_position.x, passage_probe.global_position.z).distance_to(Vector2(world_target.x, world_target.z)) < 0.8,
				"overlook slalom waypoint is blocked: %s -> %s" % [passage_probe.global_position, world_target])
		assert(passage_probe.global_position.z * team_sign > 34.5,
			"asymmetric overlook main route is blocked: %s" % passage_probe.global_position)
		assert(passage_probe.global_position.y > 3.8,
			"overlook passage dropped the player below the deck: %s" % passage_probe.global_position)
		passage_probe.queue_free()
		await physics_frame

		# The inner-left opening is intentionally unguarded.  It must drop straight
		# onto the unchanged, flat concourse floor rather than a ramp or structure.
		var jump_probe := _make_player_probe("OverlookJumpOpeningProbe_%s" % team_sign)
		map.add_child(jump_probe)
		jump_probe.global_position = Vector3(team_sign * 23.0, 4.1, team_sign * 20.8)
		await physics_frame
		for _step in 240:
			jump_probe.velocity.x = -team_sign * 3.5
			jump_probe.velocity.z = 0.0
			_apply_probe_gravity(jump_probe)
			jump_probe.move_and_slide()
			await physics_frame
			if jump_probe.is_on_floor() and jump_probe.global_position.y < 1.3:
				break
		assert(jump_probe.global_position.x * team_sign < 21.5,
			"glass or geometry blocks the jump opening: %s" % jump_probe.global_position)
		assert(jump_probe.is_on_floor() and jump_probe.global_position.y < 1.3,
			"jump opening does not land on the normal floor: %s" % jump_probe.global_position)
		assert(jump_probe.get_floor_normal().y > 0.95,
			"jump opening landed on a slope or extra structure: %s" % jump_probe.get_floor_normal())
		jump_probe.queue_free()
		await physics_frame

func _make_player_probe(probe_name: String) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = probe_name
	body.floor_snap_length = 0.45
	body.floor_max_angle = deg_to_rad(46.0)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	collision.shape = capsule
	body.add_child(collision)
	return body

func _apply_probe_gravity(body: CharacterBody3D) -> void:
	if not body.is_on_floor():
		body.velocity.y -= 18.0 / 60.0
	else:
		body.velocity.y = 0.0

func _assert_team_symmetry(map: RiftlineMap) -> void:
	var gates := map.gate_positions()
	var pads := map.launch_pad_positions()
	var red_gate: Vector3 = gates[Duelist.Team.RED]
	var blue_gate: Vector3 = gates[Duelist.Team.BLUE]
	var red_pad: Vector3 = pads[Duelist.Team.RED]
	var blue_pad: Vector3 = pads[Duelist.Team.BLUE]
	assert(blue_gate.is_equal_approx(Vector3(-red_gate.x, red_gate.y, -red_gate.z)))
	assert(blue_pad.is_equal_approx(Vector3(-red_pad.x, red_pad.y, -red_pad.z)))
	var red_spawns := map.spawn_points(Duelist.Team.RED)
	var blue_spawns := map.spawn_points(Duelist.Team.BLUE)
	assert(red_spawns.size() == 4 and blue_spawns.size() == 4)
	for index in red_spawns.size():
		assert(blue_spawns[index].is_equal_approx(Vector3(-red_spawns[index].x, red_spawns[index].y, -red_spawns[index].z)))
	assert(red_gate.distance_to(map.core_spawn_position()) > 40.0)

func _assert_spawn_clearance(map: RiftlineMap) -> void:
	assert(map.is_spawn_clear(map.core_spawn_position()))
	for team in [Duelist.Team.RED, Duelist.Team.BLUE]:
		var pad: Vector3 = map.launch_pad_positions()[team]
		assert(map.is_spawn_clear(pad))
		var spawns := map.spawn_points(team)
		for index in spawns.size():
			assert(map.is_spawn_clear(spawns[index]))
			for other_index in range(index + 1, spawns.size()):
				assert(spawns[index].distance_to(spawns[other_index]) >= 3.0)

func _assert_routes(map: RiftlineMap) -> void:
	var core := map.core_spawn_position()
	for lane in [&"center", &"maintenance", &"overlook"]:
		for team in [Duelist.Team.RED, Duelist.Team.BLUE]:
			var spawns := map.spawn_points(team)
			for spawn in spawns:
				var spawn_route_ok := _has_authored_route(map, spawn, core, lane)
				assert(spawn_route_ok, "spawn %s cannot route to core in %s" % [spawn, lane])
			var pad: Vector3 = map.launch_pad_positions()[team]
			assert(_has_authored_route(map, core, pad, lane), "core cannot route to pad in %s" % lane)
			assert(_has_authored_route(map, pad, core, lane), "pad cannot route to core in %s" % lane)
	assert(_has_authored_route(map, map.gate_positions()[Duelist.Team.RED], map.gate_positions()[Duelist.Team.BLUE], &"center"))

func _assert_tactical_facts(map: RiftlineMap) -> void:
	var facts := map.tactical_facts()
	assert(int(facts.version) == RiftlineMapLayout.VERSION)
	assert(facts.has("anchors"))
	assert(facts.lane_posts.keys().size() == 3)
	for anchor_variant in facts.anchors.values():
		if anchor_variant is Vector3:
			assert(map.is_spawn_clear(anchor_variant))
		elif anchor_variant is Dictionary:
			for point_variant in anchor_variant.values():
				var point: Vector3 = point_variant
				assert(map.is_spawn_clear(point), "tactical anchor is inside a solid: %s" % point)
	for lane in facts.lane_posts.keys():
		for post_variant in facts.lane_posts[lane]:
			var post: Vector3 = post_variant
			assert(map.is_spawn_clear(post), "lane post is inside a solid: %s %s" % [lane, post])
			assert(_has_authored_route(map, post, map.core_spawn_position(), StringName(lane)))
	assert(facts.base_entrances.keys().size() == 2)
	assert(facts.bridge_sides.size() == 2)
	for bridge_side_variant in facts.bridge_sides:
		var bridge_side: Vector3 = bridge_side_variant
		assert(map.is_spawn_clear(bridge_side), "bridge side is inside a solid: %s" % bridge_side)
		assert(_has_authored_route(map, bridge_side, map.core_spawn_position(), &"overlook"))
	assert(facts.bridge_access.keys().size() == 4)
	assert((facts.bridge_access.west_bottom as Vector3).is_equal_approx(Vector3(-21.0, 0.1, 0.0)))
	assert((facts.bridge_access.west_top as Vector3).is_equal_approx(Vector3(-12.0, 3.35, 0.0)))
	assert((facts.bridge_access.east_bottom as Vector3).is_equal_approx(Vector3(21.0, 0.1, 0.0)))
	assert((facts.bridge_access.east_top as Vector3).is_equal_approx(Vector3(12.0, 3.35, 0.0)))

func _assert_sightlines(map: RiftlineMap) -> void:
	var world := map.get_world_3d()
	assert(world != null)
	var space := world.direct_space_state
	for team in [Duelist.Team.RED, Duelist.Team.BLUE]:
		var origin: Vector3 = map.gate_positions()[team] + Vector3.UP * 1.0
		var target := map.core_spawn_position() + Vector3.UP * 1.0
		var query := PhysicsRayQueryParameters3D.create(origin, target)
		var hit: Dictionary = space.intersect_ray(query)
		assert(not hit.is_empty(), "base gate has no authored sightline blocker")
	# Upper-level route exits must remain clear enough to descend toward the core.
	for post_variant in map.tactical_facts().lane_posts.overlook:
		var post: Vector3 = post_variant
		assert(_has_authored_route(map, post, map.core_spawn_position(), &"overlook"))

func _has_authored_route(map: RiftlineMap, origin: Vector3, goal: Vector3, lane: StringName) -> bool:
	var current := origin
	var previous := origin + Vector3(999.0, 0.0, 999.0)
	for _step in 96:
		var next := map.route_toward(current, goal, lane)
		assert(next.x >= -RiftlineMap.CONCOURSE_RADIUS - 2.0 and next.x <= RiftlineMap.CONCOURSE_RADIUS + 2.0)
		assert(next.z >= -RiftlineMap.CONCOURSE_RADIUS - 2.0 and next.z <= RiftlineMap.CONCOURSE_RADIUS + 2.0)
		if next.distance_to(goal) < 1.0:
			return true
		if next.distance_to(current) < 0.5 or next.distance_to(previous) < 0.5:
			return false
		previous = current
		current = next
	return false

func _contains_mesh(node: Node) -> bool:
	for child in node.get_children():
		if child is MeshInstance3D:
			return true
		if _contains_mesh(child):
			return true
	return false

func _find_named_node(node: Node, wanted_name: String) -> Node:
	for child in node.get_children():
		if child.name == wanted_name:
			return child
		var nested := _find_named_node(child, wanted_name)
		if nested != null:
			return nested
	return null

func _assert_shadowless_meshes(node: Node) -> void:
	for child_variant in node.get_children():
		var child: Node = child_variant
		if child is MeshInstance3D:
			var mesh_instance: MeshInstance3D = child as MeshInstance3D
			assert(mesh_instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		_assert_shadowless_meshes(child)
