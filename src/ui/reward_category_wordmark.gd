class_name RewardCategoryWordmark
extends TextureRect
## Reward-only category lettering; does not replace quality or altar labels.
const ROOT:="res://assets/fate_v01/reward_wordmarks/"
static var _textures:Dictionary={}

static func make(item:Dictionary,height:=34.0)->RewardCategoryWordmark:
	var category:="relic" if ItemDB.is_relic(item) else "equipment"
	if not _textures.has(category):
		var source:=load(ROOT+category+".png") as Texture2D
		var atlas:=AtlasTexture.new();atlas.atlas=source
		atlas.region=source.get_image().get_used_rect();atlas.filter_clip=true
		_textures[category]=atlas
	var mark:=RewardCategoryWordmark.new();mark.name="RewardCategoryWordmark"
	mark.texture=_textures[category];mark.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;mark.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	mark.custom_minimum_size=Vector2(height*2.05,height);mark.size=mark.custom_minimum_size
	mark.size_flags_vertical=Control.SIZE_SHRINK_CENTER;mark.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;mark.tooltip_text="遗物" if category=="relic" else "装备 · "+ItemDB.kind_label(item)
	mark.set_meta("reward_category",category);return mark
