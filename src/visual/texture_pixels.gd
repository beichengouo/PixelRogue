class_name TexturePixels
extends RefCounted
## Imported textures are immutable. Cache decompression, not mutable caller images.
static var _sources:Dictionary={}
static var _bytes:=0
static var _clock:=0
static func _source(texture:Texture2D)->Image:
	if texture==null:return null
	if texture is AtlasTexture:return image(texture)
	if not texture is CompressedTexture2D:return texture.get_image()
	_clock+=1;var key:=texture.get_instance_id()
	if _sources.has(key) and _sources[key].texture.get_ref()==texture:
		_sources[key].used=_clock;return _sources[key].image
	var result:=texture.get_image()
	if result!=null and result.is_compressed() and result.decompress()!=OK:return null
	if result==null:return null
	var size:=result.get_data_size();var limit:=24*1024*1024 if MobileControls.enabled() else 64*1024*1024
	if size>limit:return result
	while _bytes+size>limit and not _sources.is_empty():
		var oldest:Variant=null;var age:=2147483647
		for id in _sources:
			if int(_sources[id].used)<age:age=int(_sources[id].used);oldest=id
		_bytes-=int(_sources[oldest].bytes);_sources.erase(oldest)
	_sources[key]={"texture":weakref(texture),"image":result,"bytes":size,"used":_clock};_bytes+=size
	return result
static func image(texture:Texture2D)->Image:
	if texture==null:return null
	if texture is AtlasTexture:
		var atlas:=texture as AtlasTexture;var source:=_source(atlas.atlas)
		if source==null:return null
		var region:=Rect2i(atlas.region)
		if not region.has_area():region=Rect2i(Vector2i.ZERO,source.get_size())
		return source.get_region(region)
	var result:=_source(texture)
	# Palette conversion and alpha analysis callers may mutate their own result.
	return result.duplicate() if result!=null else null
