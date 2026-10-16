class_name RewardCategoryWordmark
extends TextureRect
## Shared category lettering; text/tooltips retain semantics and native focus.
const ROOT:="res://assets/fate_v01/reward_wordmarks/"
static var _textures:Dictionary={}

static func make(item:Dictionary,height:=34.0)->RewardCategoryWordmark:
	var category:="relic" if ItemDB.is_relic(item) else "equipment"
	return for_category(category,height,"遗物" if category=="relic" else "装备 · "+ItemDB.kind_label(item))
static func texture_for(category:String)->Texture2D:
	category="relic" if category in ["relic","遗物"] else "equipment"
	if not _textures.has(category):
		var source:=load(ROOT+category+".png") as Texture2D
		var atlas:=AtlasTexture.new();atlas.atlas=source
		atlas.region=source.get_image().get_used_rect();atlas.filter_clip=true
		_textures[category]=atlas
	return _textures[category]
static func for_category(category:String,height:=34.0,hint:="")->RewardCategoryWordmark:
	category="relic" if category in ["relic","遗物"] else "equipment"
	var mark:=RewardCategoryWordmark.new();mark.name="RewardCategoryWordmark"
	mark.texture=texture_for(category);mark.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;mark.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	mark.custom_minimum_size=Vector2(height*2.05,height);mark.size=mark.custom_minimum_size
	mark.size_flags_vertical=Control.SIZE_SHRINK_CENTER;mark.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;mark.tooltip_text=hint if not hint.is_empty() else ("遗物" if category=="relic" else "装备")
	mark.set_meta("reward_category",category);return mark

func set_category(category:String)->void:
	texture=texture_for(category);tooltip_text="遗物" if category in ["relic","遗物"] else "装备";set_meta("reward_category","relic" if category in ["relic","遗物"] else "equipment")

static func decorate_pair(button:Button,height:=28.0)->void:
	decorate_button(button,"装备",height,"·")
	var row:=button.get_node("CategoryLettering") as HBoxContainer
	if not row.has_node("RelicLettering"):
		var other:=for_category("relic",height);other.name="RelicLettering";row.add_child(other)
	button.tooltip_text="装备与遗物";button.custom_minimum_size.x=maxf(button.custom_minimum_size.x,height*4.1+44)

static func decorate_button(button:Button,category:String,height:=30.0,suffix:="")->void:
	var row:=button.get_node_or_null("CategoryLettering") as HBoxContainer
	if row==null:
		row=HBoxContainer.new();row.name="CategoryLettering";row.alignment=BoxContainer.ALIGNMENT_CENTER;row.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(row);row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.add_theme_constant_override("separation",6)
		row.add_child(for_category(category,height))
		var count:=Label.new();count.name="Count";count.mouse_filter=Control.MOUSE_FILTER_IGNORE;count.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;row.add_child(count)
	var counter:=row.get_node("Count") as Label;counter.text=suffix;counter.visible=not suffix.is_empty();counter.add_theme_font_size_override("font_size",button.get_theme_font_size("font_size"))
	var mark:=row.get_child(0) as RewardCategoryWordmark;mark.set_category(category);mark.custom_minimum_size=Vector2(height*2.05,height)
	button.text="";button.tooltip_text=category+(" "+suffix if not suffix.is_empty() else "");button.set_meta("category_wordmark",category)
	button.custom_minimum_size=button.custom_minimum_size.max(Vector2(height*2.05+(32 if not suffix.is_empty() else 0)+20,height+10))
