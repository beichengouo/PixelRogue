extends SceneTree
## 一次性探针：VideoStreamPlayer 到底有哪些属性/常量
func _initialize() -> void:
	var props := []
	for p in ClassDB.class_get_property_list("VideoStreamPlayer"):
		props.append(str(p.name))
	print("VideoStreamPlayer 属性: ", props)
	print("常量: ", ClassDB.class_get_integer_constant_list("VideoStreamPlayer"))
	quit()
