class_name ShopArtButton
extends Button
## Kept as a business API so stock, rest and key-purchase actions remain unchanged.
var art_key:="purchase"
static var _sheets:Dictionary={}
func _ready()->void:
	set_art(art_key);ComicMotion.bind_button(self)
func set_art(key:String)->void:
	art_key=key;text={"purchase":"购买","key":"购买钥匙","refresh":"刷新商品","rest":"休憩","close":"关闭"}.get(key,key)
	add_theme_font_override("font",GameFonts.get_font("button"));update_visual()
func update_visual()->void:InteractionSkin.apply_button(self,"shop")
