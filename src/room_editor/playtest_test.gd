extends Node
func _ready() -> void:
    call_deferred("run")
func run() -> void:
    var args := OS.get_cmdline_user_args()
    var wanted: bool = args[args.size() - 1] == "1"
    var scene: Variant = load("res://src/room_editor/playtest.tscn").instantiate()
    add_child(scene)
    var template: Dictionary = RoomTemplateCodec.read_file(args[args.size() - 2])
    var marker_positions: Array[Vector2] = []
    for marker in template.layers.markers:
        if str(marker.get("asset_id", "")) == "spawn": marker_positions.append(RoomLayout.center(Vector2i(int(marker.at[0]), int(marker.at[1]))))
    var marked_enemy_count := 0
    for enemy_node in scene.enemies_root.get_children():
        for marked in marker_positions:
            if enemy_node.position.distance_to(marked) < 1.0: marked_enemy_count += 1
    await get_tree().process_frame
    await get_tree().physics_frame
    var failures: Array[String] = []
    var player: Variant = scene.player
    if not player is RoomPlayer: failures.append("not a RoomPlayer")
    if not player.get_node("BodyCollider") is CollisionShape2D: failures.append("missing real body collider")
    if scene.enemies_root.get_child_count() == 0 and wanted: failures.append("no spawned enemies")
    if scene.enemies_root.get_child_count() != 0 and not wanted: failures.append("enemies spawned while disabled")
    if scene.room.record.terrain_layout.get("template_id", "") != template.id: failures.append("wrong template")
    if wanted and not marker_positions.is_empty() and marked_enemy_count == 0: failures.append("marker position ignored")
    var hp: float = player.hp
    player.take_damage(9999.0, player.position + Vector2.RIGHT)
    if player.hp != hp: failures.append("player took damage")
    if player._invuln > 0.0: failures.append("invulnerability timer used")
    var start: Vector2 = player.global_position
    Input.action_press("room_right")
    for i in 8: await get_tree().physics_frame
    Input.action_release("room_right")
    if player.global_position.distance_to(start) < 1.0: failures.append("player did not move")
    Input.action_press("room_right")
    Input.action_press("dash")
    await get_tree().physics_frame
    await get_tree().physics_frame
    if player._dash_timer <= 0.0: failures.append("player did not dash")
    Input.action_release("dash")
    Input.action_release("room_right")
    Input.action_press("room_aim_right")
    for i in 30: await get_tree().physics_frame
    Input.action_release("room_aim_right")
    if scene.fx_root.get_child_count() == 0: failures.append("player did not fire")
    if wanted:
        var enemy: Variant = scene.enemies_root.get_child(0)
        player.global_position = enemy.global_position + Vector2(34, 0)
        var saw_attack := false
        for i in 120:
            await get_tree().physics_frame
            if enemy._windup > 0.0 or enemy._rush > 0.0 or enemy._visual_release_left > 0.0: saw_attack = true
        if player.hp != hp: failures.append("enemy damaged player")
        if not saw_attack: failures.append("enemy did not enter attack behavior")
    var userdata := ProjectSettings.globalize_path("user://")
    var isolated_appdata := OS.get_environment("APPDATA").replace("\\", "/")
    if not isolated_appdata.begins_with("E:/CodexWorkspace/PixelRogue/temp/") or not userdata.begins_with(isolated_appdata + "/"):
        failures.append("userdata not isolated: " + userdata)
    print("PLAYTEST_CHECK mode=", wanted, " failures=", failures)
    if GameState.player == player: GameState.player = null
    scene.room.scene_navigation.clear()
    scene.room.scene_occlusion.clear()
    scene.free()
    await get_tree().process_frame
    await get_tree().physics_frame
    await get_tree().create_timer(0.1).timeout
    AudioManager.shutdown()
    get_tree().call_deferred("quit", 0 if failures.is_empty() else 1)

