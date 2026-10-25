extends Node
class OpenRoom extends RoomLevel:
	var clear := true
	func projectile_clear(_from:Vector2,_to:Vector2)->bool:return clear
class WorldProbe extends RefCounted:
	var level:RoomLevel
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("run")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	AchievementTracker.set_process(false);ErrorReporter.interactive=false
	var room:=OpenRoom.new();room.room_rect=Rect2(0,0,900,900)
	var world:=WorldProbe.new();world.level=room
	var pilot:=GMPilot.new();pilot.main=world
	var enemy:=RoomEnemy.new();enemy.room=room;enemy.position=Vector2(400,400);enemy.hp=100;enemy.kind=&"walker"
	var affix:=AffixRuntime.new();affix.enemy=enemy;enemy.affix_runtime=affix
	var hazard:=AffixHazard.new();hazard.position=enemy.position;hazard.direction=Vector2.RIGHT
	# Exact membership agrees with the real detached hazard release shapes.
	affix.active_id=EnemyAffixes.SHOCK_RING;affix.stage_left=.5;hazard.mode=&"ring"
	for radius:float in [0.0,60.0,71.9,72.0,90.0,108.0,144.0,144.1,170.0]:
		var point:=enemy.position+Vector2.RIGHT*radius
		check((pilot._affix_warning_risk(point,enemy)>0)==hazard._inside(point),"ring geometry "+str(radius))
	check(pilot._affix_warning_risk(enemy.position+Vector2(108,0),enemy)>pilot._affix_warning_risk(enemy.position+Vector2(160,0),enemy),"ring danger outranks outer safe ground")
	check(pilot._affix_warning_risk(enemy.position+Vector2(108,0),enemy)>pilot._affix_warning_risk(enemy.position+Vector2(60,0),enemy),"ring hole is safe")
	check(pilot._affix_warning_risk(enemy.position+Vector2(108,0),enemy)>pilot._affix_warning_risk(enemy.position+Vector2(140,0),enemy),"ring risk has escape gradient")
	affix.active_id=EnemyAffixes.VINE_SNARE;affix.locked_aim=Vector2.RIGHT;hazard.mode=&"line"
	for offset:Vector2 in [Vector2(-1,0),Vector2(0,0),Vector2(90,0),Vector2(180,0),Vector2(181,0),Vector2(90,18),Vector2(90,18.1),Vector2(90,-18)]:
		var point:=enemy.position+offset
		check((pilot._affix_warning_risk(point,enemy)>0)==hazard._inside(point),"line geometry "+str(offset))
	affix.locked_aim=Vector2.DOWN;hazard.direction=Vector2.DOWN
	check(pilot._affix_warning_risk(enemy.position+Vector2(0,100),enemy)>0 and pilot._affix_warning_risk(enemy.position+Vector2(100,0),enemy)==0,"vine respects locked direction")
	# Release origin is current enemy position, not its old warning position.
	affix.locked_origin=Vector2(100,100)
	check(pilot._affix_warning_risk(Vector2(400,500),enemy)>0 and pilot._affix_warning_risk(Vector2(100,200),enemy)==0,"knockback origin follows actual release")
	room.clear=false
	check(pilot._affix_warning_risk(Vector2(400,500),enemy)==0,"wall blocks the same hazard as production")
	room.clear=true;affix.stage_left=0
	check(pilot._affix_warning_risk(Vector2(400,500),enemy)==0,"expired stage never creates phantom danger")
	affix.active_id=EnemyAffixes.MEND_CHANT;affix.stage_left=.5
	check(pilot._affix_warning_risk(Vector2(400,500),enemy)==0,"healing chant is not damaging danger")
	affix.active_id=&"";affix.echo_left=.8;affix.echo_origin=Vector2(400,400);affix.echo_aim=Vector2.RIGHT;affix.echo_kind=&"walker"
	check(pilot._affix_warning_risk(Vector2(460,400),enemy)>0,"visible melee echo fan recognized")
	check(pilot._affix_warning_risk(Vector2(340,400),enemy)==0,"echo fan does not threaten its back")
	check(pilot._affix_warning_risk(Vector2(481,400),enemy)==0,"melee echo actual 80px radius")
	check(pilot._affix_warning_risk(Vector2(400,460),enemy)==0,"melee echo actual facing cone")
	affix.echo_kind=&"bomber"
	check(pilot._affix_warning_risk(Vector2(400,495),enemy)>0 and pilot._affix_warning_risk(Vector2(400,501),enemy)==0,"bomber echo circle uses actual 100px")
	affix.echo_kind=&"flyer"
	check(pilot._affix_warning_risk(Vector2(490,400),enemy)>0 and pilot._affix_warning_risk(Vector2(510,400),enemy)==0,"ranged echo reads visible line only")
	var frozen:=pilot._affix_warning_risk(Vector2(490,400),enemy)
	get_tree().paused=true
	await get_tree().process_frame
	await get_tree().process_frame
	check(pilot._affix_warning_risk(Vector2(490,400),enemy)==frozen and is_equal_approx(affix.echo_left,.8),"pause preserves frozen visible warning without wall-clock expiry")
	get_tree().paused=false
	affix.echo_left=0
	check(pilot._affix_warning_risk(Vector2(490,400),enemy)==0,"expired echo not counted")
	affix.active_id=EnemyAffixes.SHOCK_RING;affix.stage_left=.5;enemy._dead=true
	check(pilot._affix_warning_risk(Vector2(508,400),enemy)==0,"dead source warning excluded")
	enemy._dead=false;enemy.hp=0
	check(pilot._affix_warning_risk(Vector2(508,400),enemy)==0,"zero-health source warning excluded")
	enemy.hp=100
	var other:=OpenRoom.new();enemy.room=other
	check(pilot._affix_warning_risk(Vector2(508,400),enemy)==0,"different-room warning excluded")
	enemy.room=room
	# Integration adds only affix risk; old boss and projectile responses remain.
	var threats:Dictionary={"enemies":[enemy],"warnings":[],"bullets":[],"hazards":[]}
	check(pilot._danger_at(Vector2(508,400),threats)>1000,"visible affix incorporated in real danger scoring")
	check(pilot._danger_at(Vector2(570,400),threats)==0,"safe real candidate scores zero")
	threats.enemies=[]
	var warning:=BossPatternWarning.new();warning.position=Vector2(400,400);warning.room=room;warning.spec={"shape":"circle","radius":70}
	threats.warnings=[warning]
	check(pilot._danger_at(Vector2(400,400),threats)>1000,"old boss warning danger retained")
	threats.warnings=[]
	var bullet:=RoomProjectile.new();bullet.position=Vector2(300,400);bullet.direction=Vector2.RIGHT;bullet.speed=200;bullet.hit_radius=9
	threats.bullets=[bullet]
	check(pilot._danger_at(Vector2(400,400),threats)>0 and pilot._danger_at(Vector2(400,500),threats)==0,"old hostile projectile prediction retained")
	warning.free();bullet.free();hazard.free();affix.free();enemy.free();pilot.free();room.free();other.free()
	AudioManager.shutdown()
	await get_tree().process_frame
	print("V22_GM_AFFIX_AWARENESS checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
