class_name UnitHealthArt
extends RefCounted
## Shared layered artwork: no per-hit image reads or per-unit material nodes.
const ROOT:="res://assets/health_bars_v19/"
const STYLES:=["enemy","elite","ally","king","mage","tide","sephra","verena","nameless"]
static var _manifest:Dictionary={}
static var _profiles:Dictionary={}
static var _skulls:Dictionary={}
static func profile(id:String)->Dictionary:
 if _profiles.has(id):return _profiles[id]
 if id not in STYLES:id="enemy"
 if _manifest.is_empty():_manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
 var entry:Dictionary=_manifest[id].duplicate()
 entry.frame_texture=load(ROOT+str(entry.frame));entry.fill_texture=load(ROOT+str(entry.fill));entry.tint=Color(str(entry.color))
 _profiles[id]=entry;return entry
static func skull(level:int)->Texture2D:
 if level<=0:return null
 level=clampi(level,1,RoomDirector.MAX_PRESSURE_LEVEL)
 if not _skulls.has(level):_skulls[level]=load("res://assets/rage_wordmarks_v40/rage_"+str(level)+".png")
 return _skulls[level]
static func slot(rect:Rect2,entry:Dictionary)->Rect2:
 var raw:Array=entry.track
 var left:=float(raw[0])*rect.size.y/256.0
 var right:=(1024.0-float(raw[0])-float(raw[2]))*rect.size.y/256.0
 var trim:=minf(1.0,rect.size.x*.6/maxf(.001,left+right));left*=trim;right*=trim
 return Rect2(rect.position+Vector2(left,float(raw[1])*rect.size.y/256),Vector2(maxf(0,rect.size.x-left-right),float(raw[3])*rect.size.y/256))
static func draw_frame(canvas:CanvasItem,rect:Rect2,entry:Dictionary)->void:
 var channel:=slot(rect,entry);var raw:Array=entry.track;var texture:Texture2D=entry.frame_texture
 var left:=channel.position.x-rect.position.x;var right:=rect.end.x-channel.end.x
 if left>0:canvas.draw_texture_rect_region(texture,Rect2(rect.position,Vector2(left,rect.size.y)),Rect2(0,0,raw[0],256))
 if channel.size.x>0:canvas.draw_texture_rect_region(texture,Rect2(Vector2(channel.position.x,rect.position.y),Vector2(channel.size.x,rect.size.y)),Rect2(raw[0],0,raw[2],256))
 if right>0:canvas.draw_texture_rect_region(texture,Rect2(Vector2(channel.end.x,rect.position.y),Vector2(right,rect.size.y)),Rect2(float(raw[0])+float(raw[2]),0,1024-float(raw[0])-float(raw[2]),256))
static func draw(canvas:CanvasItem,rect:Rect2,ratio:float,id:="enemy",rage:=0)->void:
 if rect.size.x<=0 or rect.size.y<=0:return
 var entry:=profile(id);var channel:=slot(rect,entry);var value:=clampf(ratio,0,1)
 canvas.draw_rect(channel,Color("10131d"))
 if value>0:
  canvas.draw_texture_rect_region(entry.fill_texture,Rect2(channel.position,Vector2(channel.size.x*value,channel.size.y)),Rect2(0,0,1024*value,48))
 draw_frame(canvas,rect,entry)
 if rage>0:
  var height:=maxf(42,rect.size.y*1.5);var width:=height*.72
  canvas.draw_texture_rect(skull(rage),Rect2(Vector2(rect.position.x-width-3,rect.get_center().y-height*.5),Vector2(width,height)),false)
