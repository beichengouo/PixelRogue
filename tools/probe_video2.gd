extends SceneTree
func _initialize() -> void:
	var found := []
	for c in ClassDB.get_class_list():
		if str(c).begins_with("VideoStream") or str(c).begins_with("Video"):
			found.append(str(c))
	print("视频相关类: ", found)
	quit()
