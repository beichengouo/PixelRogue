@tool
class_name EnvironmentSprites
extends RefCounted
## Generated textures share one batch drawer; no node per blade, drop or splash.
const GRASS: Texture2D = preload("res://assets/environment/animated/grass_sprites.png")
const WATER: Texture2D = preload("res://assets/environment/animated/water_azure_side_v2.png")
const WATER_FRAMES: SpriteFrames = preload("res://assets/environment/animated/water_azure.tres")
const SPLASH_FRAMES: SpriteFrames = preload("res://assets/environment/animated/water_splash.tres")

static func draw_grass(canvas: CanvasItem, base: Vector2, height: float, angle: float, variant: int, wet: float = 0.0, snow: float = 0.0) -> void:
	variant = clampi(variant,0,7)
	var full_height := height*48.0/(27.0 if variant<4 else 44.0)
	var half_width := full_height/3.0
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var shade := Color.WHITE.darkened(wet*0.22)
	# Four vertical sections keep the roots fixed and distribute curvature upward.
	for side in [-1,1]:
		for j in 4:
			var f := (j if side==-1 else 3-j)/3.0
			points.append(base+Vector2(side*half_width+sin(angle)*height*f*f,-full_height*f))
			uv.append(Vector2((variant%4*32+(0.5 if side==-1 else 31.5))/128.0,(variant/4*48+47.5-f*47.0)/96.0))
			colors.append(shade.lerp(Color(0.9,0.96,0.98),snow*clampf((f-0.35)*2,0,1)))
	canvas.draw_polygon(points,colors,uv,GRASS)

static func water_phase(clock:float,flow:float) -> float:
	return fposmod(clock*8.0*flow/6.0,12.0)

static func _water_height(heights:PackedFloat32Array,x:float,width:float) -> float:
	if heights.is_empty():return 0.0
	var sample=clampf(x/width,0.0,1.0)*(heights.size()-1)
	var index=int(sample)
	return lerpf(heights[index],heights[mini(index+1,heights.size()-1)],sample-index)

static func draw_water(canvas:CanvasItem,rect:Rect2,heights:PackedFloat32Array,clock:float,flow:float=6.0,tint:Color=Color.WHITE) -> void:
	if rect.size.x<=0 or rect.size.y<=0:return
	# Atlas regions are sampled explicitly so UV wrapping cannot leak into other frames.
	# Two blended consecutive frames soften generated animation without new nodes.
	var phase=water_phase(clock,flow)
	var frames=[int(phase),(int(phase)+1)%12]
	var blend=phase-int(phase)
	var scroll=fposmod(clock*flow,256.0)
	for pass_index in 2:
		var alpha=1.0 if pass_index==0 else blend
		if alpha<=0.001:continue
		var frame:int=frames[pass_index]
		var origin=Vector2(frame%3*512+1.5,frame/3*256+72.5)
		var left=-scroll
		while left<rect.size.x:
			var begin=maxf(0,left)
			var end=minf(rect.size.x,left+256.0)
			var count=maxi(2,ceili((end-begin)/24.0)+1)
			var points=PackedVector2Array()
			var uv=PackedVector2Array()
			var colors=PackedColorArray()
			for side in 2:
				for step in count:
					var index=step if side==0 else count-1-step
					var x=lerpf(begin,end,float(index)/(count-1))
					var y=_water_height(heights,x,rect.size.x) if side==0 else rect.size.y
					points.append(rect.position+Vector2(x,y))
					uv.append((origin+Vector2((x-left)/256.0*509.0,side*179.0))/WATER.get_size())
					var color=tint
					color.a*=alpha*(0.93 if side==0 else 0.82)
					colors.append(color)
			canvas.draw_polygon(points,colors,uv,WATER)
			left+=256.0

static func draw_splash(canvas: CanvasItem, position: Vector2, fraction: float, strength: float, rain: bool) -> void:
	var frame := clampi(int(fraction*8),0,7)
	var scale := clampf(strength,0.3,1.4)*(0.45 if rain else 0.9)
	var size := Vector2(48,32)*scale
	canvas.draw_texture_rect(SPLASH_FRAMES.get_frame_texture(&"splash",frame),Rect2(position-Vector2(size.x*0.5,size.y*29/32),size),false,Color(0.8,0.95,1,1.0-fraction*0.65))
