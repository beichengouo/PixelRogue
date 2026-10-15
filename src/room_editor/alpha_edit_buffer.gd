class_name AlphaEditBuffer
extends RefCounted
var image:Image
var original:Image
var path:=""
var locked:=false
var undo:Array[Dictionary]=[]
var redo:Array[Dictionary]=[]
var _before:Dictionary={}
const BASELINES:="E:/CodexWorkspace/PixelRogue/work/art-editor/originals/"
func open(source:String,protected:=false)->Error:
	path=source;locked=protected;undo.clear();redo.clear();_before.clear()
	image=Image.load_from_file(ProjectSettings.globalize_path(source))
	if image==null or image.is_empty():return ERR_FILE_CORRUPT
	image.convert(Image.FORMAT_RGBA8)
	var baseline:=BASELINES+source.sha256_text()+".png"
	if FileAccess.file_exists(baseline):original=Image.load_from_file(baseline)
	else:
		DirAccess.make_dir_recursive_absolute(BASELINES);original=image.duplicate();var error:=original.save_png(baseline)
		if error!=OK:return error
	original.convert(Image.FORMAT_RGBA8)
	if original.get_size()!=image.get_size():original=image.duplicate()
	return OK
func begin_stroke()->void:_before.clear()
func paint(at:Vector2,radius:float,restore:=false)->void:
	if locked or image==null:return
	var center:=Vector2i(at.floor());var extent:=ceili(radius)
	for y in range(maxi(0,center.y-extent),mini(image.get_height(),center.y+extent+1)):
		for x in range(maxi(0,center.x-extent),mini(image.get_width(),center.x+extent+1)):
			if Vector2(x,y).distance_squared_to(at)>radius*radius:continue
			var prior:=image.get_pixel(x,y);var alpha:=original.get_pixel(x,y).a if restore else 0.0
			if is_equal_approx(prior.a,alpha):continue
			var id:=y*image.get_width()+x
			if not _before.has(id):_before[id]=roundi(prior.a*255)
			prior.a=alpha;image.set_pixel(x,y,prior)
func end_stroke()->void:
	if _before.is_empty():return
	var indices:=PackedInt32Array();var before:=PackedByteArray();var after:=PackedByteArray()
	for id:int in _before:
		indices.append(id);before.append(_before[id]);after.append(roundi(image.get_pixel(id%image.get_width(),int(id/image.get_width())).a*255))
	undo.append({"indices":indices,"before":before,"after":after});redo.clear();_before.clear()
	if undo.size()>50:undo.pop_front()
func _apply(stroke:Dictionary,key:String)->void:
	for i in stroke.indices.size():
		var id:int=stroke.indices[i];var x:=id%image.get_width();var y:=int(id/image.get_width());var pixel:=image.get_pixel(x,y);pixel.a=stroke[key][i]/255.0;image.set_pixel(x,y,pixel)
func undo_stroke()->void:
	if undo.is_empty():return
	var stroke:Dictionary=undo.pop_back();_apply(stroke,"before");redo.append(stroke)
func redo_stroke()->void:
	if redo.is_empty():return
	var stroke:Dictionary=redo.pop_back();_apply(stroke,"after");undo.append(stroke)
func save()->Error:
	if locked or image==null:return ERR_UNAUTHORIZED
	var absolute:=ProjectSettings.globalize_path(path)
	if not absolute.replace("\\","/").begins_with("E:/"):return ERR_UNAUTHORIZED
	var temporary:="E:/CodexWorkspace/PixelRogue/temp/alpha_"+path.sha256_text()+".png"
	var error:=image.save_png(temporary)
	if error!=OK:return error
	return DirAccess.rename_absolute(temporary,absolute)
