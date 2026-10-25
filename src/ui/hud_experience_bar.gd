extends PlayerStatBar
## XP shares the new meter renderer while retaining its capped-value wording.
var capped:=false

func configure(_type: String) -> void:
	super.configure("xp")
	kind = "xp"
	_amount_label.add_theme_font_size_override("font_size",14)
	_amount_label.add_theme_constant_override("outline_size",2)

func set_capped(value:bool)->void:
	capped=value;_update_amount()

func _update_amount()->void:
	if _amount_label!=null:_amount_label.text="已满级" if capped else "经验 %d / %d"%[floori(_value),ceili(_max_value)]
