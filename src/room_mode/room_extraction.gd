class_name RoomExtraction
extends ExtractionDirector
func _render()->void:
	super._render()
	var view:=get_viewport().get_visible_rect().size
	_label.position=Vector2(view.x-350,view.y-156);_label.size=Vector2(330,48)
	_label.add_theme_font_size_override("font_size",14)
	if state==IDLE and cooldown<=0:_label.text="";_label.hide()
	if UIFlow.gamepad:_label.text=_label.text.replace("右摇杆↑","↓")
func request()->bool:
	if not is_current() or UIFlow.has_screen() or get_tree().paused or TransitionLayer.busy:return false
	if blocks_input():return false
	if state in [PRAYING,WAITING]:cancel(state==WAITING);return true
	if main._navigation_pending or main._room_transfer or not main._reward_offers.is_empty() or not main._story_queue.is_empty() or not main._story_context.is_empty() or not main._reward_pending.is_empty():
		main.hud.show_banner("完成当前剧情、奖励或转场后再呼唤女神",2);return false
	if is_instance_valid(main.expansion) and main.expansion.event_pending():main.hud.show_banner("完成当前异闻选择后再呼唤女神",2);return false
	if cooldown>0:return false
	if main.player.velocity.length()>20 or main.player._dash_timer>0:
		main.hud.show_banner("站稳后合掌呼唤女神",1.5);return false
	wait_duration=5.0 if room_is_safe() else WAIT_SECONDS
	wait_profile="safe" if wait_duration==5.0 else "combat"
	_epoch+=1;state=PRAYING;channel=0;remaining=3;anchor=main.player.global_position+Vector2(0,21)
	stable=wait_profile=="safe";main.player.set_extraction_pose(&"prayer");main.director.extraction_hold=false
	_render();Outpost.request_checkpoint();return true

func room_is_safe()->bool:
	if not main.graph.rooms.has(main.graph.current):return false
	var record:Dictionary=main.graph.rooms[main.graph.current]
	if not bool(record.get("cleared",false)):return false
	if not main.director._queue.is_empty() or not main.director.room_pending.is_empty():return false
	for enemy in main.enemies_root.get_children():
		if enemy is EnemyBase and not enemy._dead and not enemy.is_queued_for_deletion():return false
	return true

func begin_reception()->void:
	state=RECEIVING;reception_elapsed=0
	main.director.extraction_hold=true
	main.clear_hostile_effects()
	for enemy in main.enemies_root.get_children():
		if enemy is EnemyBase:
			enemy.set_physics_process(false)
			if enemy.has_method("cancel_attacks"):enemy.cancel_attacks(true)
	main.player._invuln=maxf(main.player._invuln,RECEPTION_SECONDS+.2)
	main.player.set_extraction_pose(&"receiving")
	Outpost.request_checkpoint()

func cancel(with_cooldown:=true,checkpoint:=true)->void:
	var receiving:=state in [RECEIVING,SETTLING]
	super.cancel(with_cooldown,checkpoint)
	if receiving and is_instance_valid(main) and is_instance_valid(main.enemies_root):
		for enemy in main.enemies_root.get_children():
			if enemy is EnemyBase and not enemy._dead:enemy.set_physics_process(true)

func _process(dt:float)->void:
	if not is_current():
		if state!=IDLE:cancel(false,false)
		return
	if get_tree().paused:return
	cooldown=maxf(0,cooldown-dt)
	if state==PRAYING:
		if main.player.global_position.distance_to(anchor-Vector2(0,21))>5:cancel(false)
		else:
			channel=minf(3,channel+dt);remaining=3-channel
			if remaining<=0:
				state=WAITING;remaining=wait_duration;waiting_elapsed=0;main.player.set_extraction_pose(&"");Outpost.request_checkpoint()
	elif state==WAITING:
		remaining=maxf(0,remaining-dt);waiting_elapsed+=dt
		if remaining<=0:begin_reception()
	elif state==RECEIVING:
		reception_elapsed=minf(2,reception_elapsed+dt)
		if reception_elapsed>=2:state=SETTLING;main.player.set_extraction_pose(&"settling",true);completed.emit()
	_render()
