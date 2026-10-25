class_name UnitVitalBar
extends Control
var style_id:="ally"
var max_value:=1.0:
 set(amount):max_value=maxf(.001,amount);queue_redraw()
var value:=1.0:
 set(amount):value=amount;queue_redraw()
func _ready()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw()->void:UnitHealthArt.draw(self,Rect2(Vector2.ZERO,size),value/max_value,style_id)
