class_name RarityWordmark
extends TextureRect
## One shared, untinted wordmark per quality. Controls never intercept clicks.
const ROOT:="res://assets/ui_art/rarity_v01/"
const FILES:=["common","fine","rare","legendary"]
static var _textures:Dictionary={}
static var _compact:Dictionary={}
var quality:=0
static func texture_for(rarity:int)->Texture2D:
	var rank:=clampi(rarity,0,3)
	if not _textures.has(rank):_textures[rank]=load(ROOT+FILES[rank]+".png") as Texture2D
	return _textures[rank]
static func make(rarity:int,height:=32.0)->RarityWordmark:
	var mark:=RarityWordmark.new();mark.name="QualityWordmark"
	mark.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;mark.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;mark.mouse_filter=Control.MOUSE_FILTER_IGNORE
	mark.custom_minimum_size=Vector2(height*2.4,height);mark.size=mark.custom_minimum_size
	mark.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;mark.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	mark.set_quality(rarity);return mark
func set_quality(rarity:int)->void:
	quality=clampi(rarity,0,3);texture=texture_for(quality)
	tooltip_text=ItemDB.rarity_name(quality);set_meta("quality",quality);set_meta("quality_name",tooltip_text)
static func line(rarity:int,category:String,height:=32.0,font_size:=18,color:=Color.WHITE)->HBoxContainer:
	var row:=HBoxContainer.new();row.name="QualityLine";row.add_theme_constant_override("separation",8);row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_child(make(rarity,height))
	if not category.is_empty():
		var label:=PixelUi.label(category,font_size,color);label.name="ItemCategory";label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(label)
	row.tooltip_text=ItemDB.rarity_name(clampi(rarity,0,3))+" · "+category
	return row
static func compact_texture(rarity:int)->Texture2D:
	var rank:=clampi(rarity,0,3)
	if not _compact.has(rank):
		var image:=texture_for(rank).get_image();image.resize(84,35,Image.INTERPOLATE_LANCZOS);_compact[rank]=ImageTexture.create_from_image(image)
	return _compact[rank]
