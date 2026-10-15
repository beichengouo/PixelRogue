extends SceneTree
## 自检脚本：确认输入映射、自动加载单例、关卡数据都正常。
## 用法：--headless --path . --script res://tools/verify_project.gd

const EXPECTED_ACTIONS := [
	"move_left", "move_right", "jump", "attack", "dash",
	"interact", "start_wave", "restart", "pause_menu",
]


func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var failed := 0

	for action: String in EXPECTED_ACTIONS:
		if not InputMap.has_action(action):
			printerr("缺少输入动作：%s" % action)
			failed += 1
		else:
			var events := InputMap.action_get_events(action)
			if events.is_empty():
				printerr("输入动作没有绑定按键：%s" % action)
				failed += 1

	var rows: Array = LevelData.ROWS
	var width: int = String(rows[0]).length()
	for i in rows.size():
		if String(rows[i]).length() != width:
			printerr("关卡第 %d 行长度不一致" % i)
			failed += 1

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# ItemDB uses autoloads; resolve it after SceneTree has initialized them.
	var database: GDScript = load("res://src/data/item_db.gd")
	var offers: Array = database.roll_offers(3, rng)
	if offers.size() != 3:
		printerr("道具抽取异常，只抽到 %d 件" % offers.size())
		failed += 1

	var wave5 := WaveTable.build(5)
	if int(wave5["total"]) <= 0:
		printerr("第 5 波没有敌人")
		failed += 1

	if failed == 0:
		print("[verify_project] 全部检查通过：%d 个输入动作 / 关卡 %d 行 x %d 列 / 第 5 波 %d 只怪"
			% [EXPECTED_ACTIONS.size(), rows.size(), width, int(wave5["total"])])
	quit(0 if failed == 0 else 1)
