extends SceneTree
## 一次性检查脚本：确认导入后的立绘纹理到底有没有 mipmap。
func _initialize() -> void:
	for p in ["res://assets/characters/witch_portrait_calm.png",
			"res://assets/characters/goddess_portrait.png"]:
		var t: Texture2D = load(p)
		if t == null:
			print("加载失败 ", p)
			continue
		var img := t.get_image()
		print("%s  %dx%d  format=%d  mipmap=%s" % [
			p.get_file(), t.get_width(), t.get_height(),
			img.get_format(), str(img.has_mipmaps())])
	quit()
