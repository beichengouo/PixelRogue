extends SceneTree
## 把素材「对话框背景.png」切成一条**不变形**的宽对话框底图。
##
## 原图是 2048x1152（16:9）的整幅云雾面板，直接塞进 1240x276 的横向对话框会被
## 压扁成条状。这里改成：从中间裁一条和对话框同宽高比的横带，再等比缩放到目标
## 尺寸 —— 等比缩放，所以花纹不会被拉变形，只是省掉了上下那圈柔光。
##
## 用法：godot --headless --path . --script tools/build_dialogue_box.gd

const SRC := "E:/素材/对话框背景.png"
const DST := "res://assets/backgrounds/dialogue_box.png"
## 目标对话框的宽高比（和 dialogue_ui.gd 里的 BOX_RECT 保持一致）
const TARGET_W := 900.0
const TARGET_H := 268.0
## 输出分辨率倍数（2 倍，UI 放大时也不糊）
const SCALE := 2


func _initialize() -> void:
	var img := Image.load_from_file(SRC)
	if img == null:
		printerr("读不到素材：%s" % SRC)
		quit(1)
		return
	var w := img.get_width()
	var h := img.get_height()
	var aspect := TARGET_W / TARGET_H
	# 按目标宽高比裁一条横带（保持原图宽度，只裁高度）
	var band := int(round(float(w) / aspect))
	band = mini(band, h)
	var y0 := (h - band) / 2
	var cropped := img.get_region(Rect2i(0, y0, w, band))
	cropped.resize(int(TARGET_W) * SCALE, int(TARGET_H) * SCALE, Image.INTERPOLATE_LANCZOS)
	var err := cropped.save_png(DST)
	if err != OK:
		printerr("保存失败：%d" % err)
		quit(1)
		return
	print("已生成 %s：从 %dx%d 裁 y=%d..%d 的横带，输出 %dx%d" % [
		DST, w, h, y0, y0 + band, cropped.get_width(), cropped.get_height()])
	quit(0)
