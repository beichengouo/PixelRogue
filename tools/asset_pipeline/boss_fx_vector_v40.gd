extends SceneTree
## Produces editable layered SVG masters and 1024px four-frame geometric FX atlases.
## Geometry is decorative; the existing strike shader remains the hit mask.
const SOURCE_DIR:="res://art_src/boss_fx_v40/"
const RUNTIME_DIR:="res://assets/boss_fx_v40/"
const SIZE:=1024
const IDS:=["king","mage","tide","sephra","verena","nameless"]
const STAGES:=["area","slash","radial","flight"]
const COLORS:={
	"king":["#f4d49c","#ae6c5a","#7c3649"],
	"mage":["#b5edff","#5ea9e2","#8b4ed2"],
	"tide":["#a6eacb","#55bda9","#286384"],
	"sephra":["#fff0b7","#dca64e","#516bba"],
	"verena":["#f7dda6","#ba87ce","#8061b0"],
	"nameless":["#e3dbff","#9e8df4","#e2b972"],
}

func _initialize()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOURCE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RUNTIME_DIR))
	var receipt:Dictionary={"resolution":SIZE,"families":{},"status":"source_and_runtime_atlas"}
	for id:String in IDS:
		receipt.families[id]={}
		for stage:String in STAGES:
			var stem:=id+"_"+stage
			var file:=FileAccess.open(SOURCE_DIR+stem+".svg",FileAccess.WRITE)
			if file==null:push_error("Cannot write SVG "+stem);quit(1);return
			file.store_string(_svg(id,stage,0));file.close()
			var atlas:=Image.create(SIZE*4,SIZE,false,Image.FORMAT_RGBA8);atlas.fill(Color.TRANSPARENT)
			for phase in 4:
				var frame:=Image.new()
				var result:=frame.load_svg_from_string(_svg(id,stage,phase))
				if result!=OK:push_error("SVG render failed "+stem+" "+str(result));quit(1);return
				atlas.blit_rect(frame,Rect2i(Vector2i.ZERO,Vector2i(SIZE,SIZE)),Vector2i(phase*SIZE,0))
				if phase==0:frame.save_png(SOURCE_DIR+stem+"_preview_1024.png")
			atlas.save_png(RUNTIME_DIR+stem+".png")
			receipt.families[id][stage]={"svg":SOURCE_DIR+stem+".svg","preview":SOURCE_DIR+stem+"_preview_1024.png","atlas":RUNTIME_DIR+stem+".png","frames":4}
	var manifest:=FileAccess.open(SOURCE_DIR+"manifest.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify(receipt,"  "));manifest.close()
	print("BOSS_FX_VECTOR_V40 families=",IDS.size()," stages=",STAGES.size()," frames=",IDS.size()*STAGES.size()*4)
	quit()

func _ring(radius:float)->String:
	return "M 0 -%0.1f A %0.1f %0.1f 0 1 1 -0.1 -%0.1f Z"%[radius,radius,radius,radius]

func _svg(id:String,stage:String,phase:int)->String:
	if stage!="area":return _directional_svg(id,stage,phase)
	var colors:Array=COLORS[id]
	var pulse:=1.0+float(phase)*.045
	var rotation:=float(phase)*6.0
	var xml:="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1024\" height=\"1024\" viewBox=\"0 0 1024 1024\">"
	xml+="<defs><radialGradient id=\"core\"><stop offset=\"0\" stop-color=\"%s\" stop-opacity=\".60\"/><stop offset=\".55\" stop-color=\"%s\" stop-opacity=\".22\"/><stop offset=\"1\" stop-color=\"%s\" stop-opacity=\"0\"/></radialGradient>"%[colors[0],colors[1],colors[2]]
	xml+="<linearGradient id=\"metal\" x2=\"1\" y2=\"1\"><stop stop-color=\"%s\"/><stop offset=\".52\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient></defs>"%[colors[0],colors[1],colors[2]]
	xml+="<g id=\"pulse_core\" transform=\"translate(512 512) scale(%0.3f)\"><path d=\"%s\" fill=\"url(#core)\"/></g>"%[pulse,_ring(400)]
	xml+="<g id=\"outer_container\" transform=\"translate(512 512) rotate(%0.1f)\" fill=\"none\" stroke=\"url(#metal)\" stroke-linecap=\"round\">"%rotation
	xml+="<path id=\"outer_rim\" d=\"%s\" stroke-width=\"18\" opacity=\".88\"/>"%_ring(397)
	xml+="<path id=\"inner_rim\" d=\"%s\" stroke-width=\"8\" opacity=\".90\"/>"%_ring(297)
	xml+="<path id=\"thin_rim\" d=\"%s\" stroke-width=\"3\" opacity=\".75\"/>"%_ring(350)
	for index in 12:
		var angle:=float(index)*30.0
		xml+="<path d=\"M 0 -384 L 0 -354 M -12 -340 L 0 -325 L 12 -340\" stroke-width=\"5\" transform=\"rotate(%0.1f)\" opacity=\".8\"/>"%angle
	xml+="</g>"
	xml+="<g id=\"boss_glyphs\" transform=\"translate(512 512) rotate(%0.1f)\" fill=\"none\" stroke=\"%s\" stroke-linejoin=\"round\" stroke-linecap=\"round\">"%[-rotation*.5,colors[0]]
	match id:
		"king":
			for index in 8:xml+="<path d=\"M -31 -271 L -19 -314 L 0 -296 L 19 -314 L 31 -271 Z M -12 -266 L 0 -248 L 12 -266\" stroke-width=\"7\" transform=\"rotate(%d)\"/>"%(index*45)
			xml+="<path d=\"M -160 90 Q 0 -160 160 90 M -135 100 L -135 180 L 135 180 L 135 100\" stroke-width=\"12\"/>"
		"mage":
			for index in 10:xml+="<path d=\"M 0 -306 L 24 -274 L 0 -231 L -24 -274 Z M 0 -231 L 0 -211\" stroke-width=\"7\" transform=\"rotate(%d)\"/>"%(index*36)
			xml+="<path d=\"M -120 115 L 0 -130 L 120 115 Z M -75 115 L 0 -42 L 75 115\" stroke-width=\"9\"/>"
		"tide":
			for index in 8:xml+="<path d=\"M 0 -310 C -50 -266 50 -220 0 -180 C -35 -153 -45 -115 -15 -90 M 0 -310 C 40 -282 42 -248 13 -224\" stroke-width=\"8\" transform=\"rotate(%d)\"/>"%(index*45)
			xml+="<path d=\"M -145 80 Q -75 -105 0 65 Q 78 -110 145 80 M -95 128 Q 0 35 95 128\" stroke-width=\"10\"/>"
		"sephra":
			for index in 4:xml+="<path d=\"M -65 -220 L -65 -90 Q 0 -175 65 -90 L 65 -220 Q 0 -285 -65 -220 Z M 0 -250 L 0 -65\" stroke-width=\"9\" transform=\"rotate(%d)\"/>"%(index*90)
			xml+="<path d=\"M -214 183 L 210 -182 M -210 -182 L 214 183\" stroke-width=\"10\"/>"
		"verena":
			for index in 8:xml+="<path d=\"M -33 -276 Q -12 -296 0 -266 Q 12 -296 33 -276 L 33 -220 Q 8 -237 0 -219 Q -8 -237 -33 -220 Z M 0 -266 L 0 -219\" stroke-width=\"6\" transform=\"rotate(%d)\"/>"%(index*45)
			xml+="<path d=\"M -155 114 Q -70 38 0 105 Q 70 38 155 114 L 155 -37 Q 80 -85 0 -18 Q -80 -85 -155 -37 Z M 0 -18 L 0 105\" stroke-width=\"10\"/>"
		"nameless":
			for index in 12:xml+="<path d=\"M 0 -310 L 10 -282 L 39 -274 L 10 -266 L 0 -238 L -10 -266 L -39 -274 L -10 -282 Z\" stroke-width=\"5\" transform=\"rotate(%d)\"/>"%(index*30)
			xml+="<path d=\"M 0 -151 L 37 -43 L 151 -43 L 59 23 L 94 132 L 0 66 L -94 132 L -59 23 L -151 -43 L -37 -43 Z\" stroke-width=\"9\"/>"
	xml+="</g>"
	xml+="<g id=\"release_feedback\" transform=\"translate(512 512) scale(%0.3f)\" fill=\"none\" stroke=\"%s\" stroke-width=\"5\" opacity=\"%0.2f\"><path d=\"%s\"/></g>"%[.76+phase*.09,colors[0],.3+phase*.14,_ring(470)]
	xml+="</svg>"
	return xml

func _directional_svg(id:String,stage:String,phase:int)->String:
	var colors:Array=COLORS[id]
	var shift:=float(phase)*15.0
	var glow:=.34+float(phase)*.11
	var xml:="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1024\" height=\"1024\" viewBox=\"0 0 1024 1024\">"
	xml+="<defs><linearGradient id=\"blade\" x1=\"0\" x2=\"1\"><stop stop-color=\"%s\" stop-opacity=\"0\"/><stop offset=\".52\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\" stop-opacity=\".2\"/></linearGradient>"%[colors[2],colors[0],colors[1]]
	xml+="<radialGradient id=\"aura\"><stop stop-color=\"%s\" stop-opacity=\".46\"/><stop offset=\"1\" stop-color=\"%s\" stop-opacity=\"0\"/></radialGradient></defs>"%[colors[0],colors[1]]
	xml+="<g id=\"energy_body\" fill=\"url(#blade)\" stroke=\"none\">"
	match stage:
		"slash":
			xml+="<path d=\"M 96 666 Q 430 140 930 268 Q 613 225 282 755 Q 541 644 881 628 Q 500 844 96 666 Z\" opacity=\"%0.2f\"/>"%glow
			xml+="<path d=\"M 107 675 Q 441 150 933 278 Q 584 218 268 766 Q 510 654 866 638 Q 505 856 107 675 Z\" opacity=\".42\"/>"
		"radial":
			xml+="<path d=\"%s\" transform=\"translate(512 512)\" fill=\"url(#aura)\" opacity=\"%0.2f\"/>"%[_ring(454),glow]
		"flight":
			xml+="<path d=\"M 72 512 Q 305 416 702 453 L 946 512 L 702 571 Q 305 608 72 512 Z\" opacity=\"%0.2f\"/>"%glow
			xml+="<path d=\"M 180 512 Q 418 478 760 493 L 946 512 L 760 531 Q 418 546 180 512 Z\" opacity=\".56\"/>"
	xml+="</g>"
	xml+="<g id=\"edge_contours\" fill=\"none\" stroke=\"%s\" stroke-linecap=\"round\" stroke-linejoin=\"round\">"%colors[0]
	match stage:
		"slash":
			xml+="<path d=\"M 91 663 Q 433 135 934 267\" stroke-width=\"12\" opacity=\".92\"/>"
			xml+="<path d=\"M 260 769 Q 549 634 884 625\" stroke-width=\"6\" opacity=\".78\"/>"
		"radial":
			xml+="<path d=\"%s\" transform=\"translate(512 512)\" stroke-width=\"15\" opacity=\".86\"/>"%_ring(392+shift)
			xml+="<path d=\"%s\" transform=\"translate(512 512)\" stroke-width=\"5\" opacity=\".68\"/>"%_ring(307+shift*.5)
		"flight":
			xml+="<path d=\"M 76 512 Q 310 404 716 449 L 949 512 L 716 575 Q 310 620 76 512 Z\" stroke-width=\"8\" opacity=\".86\"/>"
			xml+="<path d=\"M 205 512 L 905 512\" stroke-width=\"5\" opacity=\".9\"/>"
	xml+="</g>"
	xml+="<g id=\"boss_signature\" fill=\"none\" stroke=\"%s\" stroke-linecap=\"round\" stroke-width=\"7\" opacity=\".9\">"%colors[1]
	var glyph:=_signature(id)
	if stage=="radial":
		for index in 8:xml+="<path d=\"%s\" transform=\"translate(512 512) rotate(%d) translate(0 -350)\"/>"%[glyph,index*45]
	elif stage=="slash":
		for index in 5:xml+="<path d=\"%s\" transform=\"translate(%d %d) rotate(-24) scale(.75)\"/>"%[glyph,275+index*128,632-index*71]
	else:
		for index in 5:xml+="<path d=\"%s\" transform=\"translate(%d 512) scale(.8)\"/>"%[glyph,210+index*131]
	xml+="</g>"
	xml+="<g id=\"release_feedback\" fill=\"none\" stroke=\"%s\" stroke-width=\"4\" opacity=\"%0.2f\">"%[colors[0],.38+phase*.15]
	if stage=="radial":xml+="<path d=\"%s\" transform=\"translate(512 512)\"/>"%_ring(445+shift)
	elif stage=="slash":xml+="<path d=\"M 68 709 Q 408 81 957 231\"/>"
	else:xml+="<path d=\"M 80 463 L 948 510 L 80 561\"/>"
	xml+="</g></svg>"
	return xml

func _signature(id:String)->String:
	match id:
		"king":return "M -17 13 L -17 -9 L -8 -1 L 0 -13 L 8 -1 L 17 -9 L 17 13 Z"
		"mage":return "M 0 -18 L 15 0 L 0 18 L -15 0 Z M 0 -18 L 0 18"
		"tide":return "M -18 12 Q -7 -15 0 0 Q 8 -15 18 12 Q 0 21 -18 12 Z"
		"sephra":return "M -15 14 L -15 -12 Q 0 -20 15 -12 L 15 14 M -18 3 L 18 3"
		"verena":return "M -18 13 L -18 -10 Q 0 -18 0 -2 Q 0 -18 18 -10 L 18 13 Q 0 2 -18 13 Z"
		_:return "M 0 -18 L 5 -5 L 18 0 L 5 5 L 0 18 L -5 5 L -18 0 L -5 -5 Z"
