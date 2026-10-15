class_name CurrencyArt
extends RefCounted
static var _frames:Array[Texture2D]=[]
static func frame(index:int)->Texture2D:
	if _frames.is_empty():
		var sheet:Texture2D=load("res://assets/currency_v01/coin.png")
		for column in 4:
			var cell:=AtlasTexture.new();cell.atlas=sheet;cell.region=Rect2(column*96,0,96,96);cell.filter_clip=true;_frames.append(cell)
	return _frames[posmod(index,4)]
