extends Node
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;printerr("FAIL ",message)
func frames(count:=4)->void:
	for index in count:await get_tree().process_frame
func _ready()->void:call_deferred("run")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):
		push_error("Isolated E drive profile required");get_tree().quit(1);return
	AchievementTracker.set_process(false);GameState.set_process(false)
	SaveService.data.reduced_motion=true
	check(str(ProjectSettings.get_setting("application/config/version"))=="0.56","runtime version")
	check(str(ReleaseNotes.current().version)=="0.56","current announcement")
	check(ReleaseNotes.current().sections.size()==6,"all announcement sections")
	check(str(ReleaseNotes.RELEASES[1].version)=="0.55","prior announcement preserved")
	var versions:Dictionary={}
	for release:Dictionary in ReleaseNotes.RELEASES:
		check(not versions.has(release.version),"unique historical version");versions[release.version]=true
		check(not str(release.title).is_empty() and not str(release.intro).is_empty(),"nonempty announcement")
		for section:Dictionary in release.sections:check(not str(section.title).is_empty() and not str(section.text).is_empty(),"nonempty section")
	SaveService.data.release_notes_seen="0.5"
	check(ReleaseNotes.needs_prompt(),"old seen version prompts current")
	check(SaveService.save_data(),"isolated prior acknowledgement saved")
	var before:PackedByteArray=FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)
	var blocker:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp"
	check(DirAccess.make_dir_absolute(blocker)==OK,"isolated atomic save fault created")
	check(not ReleaseNotes.acknowledge(),"acknowledgement rejects failed save")
	check(str(SaveService.data.release_notes_seen)=="0.5" and ReleaseNotes.needs_prompt(),"failure restores prior acknowledgement")
	check(FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)==before,"failure leaves prior disk bytes")
	check(DirAccess.remove_absolute(blocker)==OK,"isolated blocker removed")
	check(ReleaseNotes.acknowledge() and not ReleaseNotes.needs_prompt(),"retry acknowledges exactly current release")
	var disk:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SaveService.SAVE_PATH))
	check(str(disk.release_notes_seen)=="0.56","current acknowledgement persisted")
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames()
		var ui:=ReleaseNotesUI.new();add_child(ui);await frames()
		check(ui._heading.text.begins_with("V0.56"),"current title at "+str(extent))
		check(ui._selector.item_count==ReleaseNotes.RELEASES.size(),"history menu complete")
		check(ui._body.get_child_count()==2+ReleaseNotes.current().sections.size()*2,"all current paragraphs rendered")
		check(ui._scroll.size.y>0 and ui._body.size.y>ui._scroll.size.y,"long announcement scrolls")
		var close:Button=ui.find_child("CloseReleaseNotes",true,false)
		check(close!=null and get_viewport().get_visible_rect().has_point(close.get_global_rect().get_center()),"close button remains onscreen")
		ui._show_release(1);await frames()
		check(ui._heading.text.begins_with("V0.55 ·"),"historical announcement accessible")
		ui._show_release(0);await frames()
		check(ui._scroll.scroll_vertical==0,"returning current resets scroll")
		ui.dismiss();await frames()
	AudioManager.shutdown();await frames()
	print("RELEASE_V056 checks=%d failures=%d"%[checks,failures]);get_tree().quit(1 if failures else 0)
