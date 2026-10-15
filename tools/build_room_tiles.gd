extends SceneTree
func _initialize()->void:
	var tileset:=TileSet.new();tileset.tile_size=Vector2i(36,36)
	tileset.add_physics_layer();tileset.set_physics_layer_collision_layer(0,Layers.WORLD)
	tileset.add_terrain_set();tileset.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_SIDES)
	for i in 3:
		tileset.add_terrain(0);tileset.set_terrain_name(0,i,["森林苔土","湿地软土","遗迹石地"][i]);tileset.set_terrain_color(0,i,[Color("66a375"),Color("509fa5"),Color("9a9c92")][i])
	var entries:=["floor_forest","floor_wetland","floor_ruin","wall","crate","stone","door_north","door_south","door_west","door_east"]
	for i in entries.size():
		var source:=TileSetAtlasSource.new();source.texture=load("res://assets/room_mode/structure/wall_north.png" if i==3 else ("res://assets/room_mode/refinement/"+entries[i]+".png" if i in [4,5] else "res://assets/room_mode/"+entries[i]+".png"))
		source.texture_region_size=Vector2i(36,36) if i<3 else Vector2i(source.texture.get_size())
		source.create_tile(Vector2i.ZERO);tileset.add_source(source,i)
		var data:=source.get_tile_data(Vector2i.ZERO,0)
		if i<3:
			for at in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				if at!=Vector2i.ZERO:source.create_tile(at)
				data=source.get_tile_data(at,0);data.terrain_set=0;data.terrain=i
				for bit in [TileSet.CELL_NEIGHBOR_TOP_SIDE,TileSet.CELL_NEIGHBOR_RIGHT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,TileSet.CELL_NEIGHBOR_LEFT_SIDE]:data.set_terrain_peering_bit(bit,i)
		elif i>=6:data.texture_origin=Vector2i(0,14)
	for i in 4:
		var source:=TileSetAtlasSource.new();source.texture=load("res://assets/room_mode/services/floor_"+["wood","cobble","garden","carpet"][i]+".png");source.texture_region_size=Vector2i(36,36)
		tileset.add_source(source,10+i)
		tileset.add_terrain(0);tileset.set_terrain_name(0,3+i,["酒馆木地板","商铺石路","商铺花圃","酒馆地毯"][i]);tileset.set_terrain_color(0,3+i,[Color("987047"),Color("84938c"),Color("68a75c"),Color("ae4956")][i])
		for at in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
			source.create_tile(at)
			var data:=source.get_tile_data(at,0);data.terrain_set=0;data.terrain=3+i
			for bit in [TileSet.CELL_NEIGHBOR_TOP_SIDE,TileSet.CELL_NEIGHBOR_RIGHT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,TileSet.CELL_NEIGHBOR_LEFT_SIDE]:data.set_terrain_peering_bit(bit,3+i)
	for i in 8:
		var source:=TileSetAtlasSource.new();source.texture=load("res://assets/room_mode/structure/"+["goods","lantern","planter","notice","barrels","table","shrub","brazier"][i]+".png");source.texture_region_size=Vector2i(source.texture.get_size());source.create_tile(Vector2i.ZERO);tileset.add_source(source,14+i)
		source.get_tile_data(Vector2i.ZERO,0).texture_origin=Vector2i(0,source.texture.get_height()/2)
		var data:=source.get_tile_data(Vector2i.ZERO,0);data.add_collision_polygon(0)
		var w:=source.texture.get_width()*0.39;var d:float=[24,10,20,14,22,32,18,16][i]
		data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-w,-d),Vector2(w,-d),Vector2(w,0),Vector2(-w,0)]))
	for i in 4:
		var row:=2 if i==3 else i
		var tile:=Vector2i(0,row)
		var texture:=load("res://assets/room_mode/structure/doors.png") as Texture2D
		var animated:=TileSetAtlasSource.new();animated.texture=texture;animated.texture_region_size=Vector2i(128,96);animated.create_tile(tile);tileset.add_source(animated,22+i)
		animated.set_tile_animation_columns(tile,4);animated.set_tile_animation_frames_count(tile,4);animated.set_tile_animation_speed(tile,12)
		animated.get_tile_data(tile,0).texture_origin=Vector2i(0,14)
		if i==3:
			animated.create_alternative_tile(tile,1);animated.get_tile_data(tile,1).texture_origin=Vector2i(0,14);animated.get_tile_data(tile,1).flip_h=true
		var closed:=TileSetAtlasSource.new();var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2(0,row*96,128,96);closed.texture=atlas;closed.texture_region_size=Vector2i(128,96);closed.create_tile(Vector2i.ZERO);tileset.add_source(closed,26+i)
		closed.get_tile_data(Vector2i.ZERO,0).texture_origin=Vector2i(0,14)
		if i==3:
			closed.create_alternative_tile(Vector2i.ZERO,1);closed.get_tile_data(Vector2i.ZERO,1).texture_origin=Vector2i(0,14);closed.get_tile_data(Vector2i.ZERO,1).flip_h=true
		# Existing door source IDs stay stable; only their open-state art is replaced.
		var open_texture:=AtlasTexture.new();open_texture.atlas=texture;open_texture.region=Rect2(384,row*96,128,96)
		var open_source:=tileset.get_source(6+i) as TileSetAtlasSource
		open_source.texture=open_texture
		if i==3:
			open_source.create_alternative_tile(Vector2i.ZERO,1);open_source.get_tile_data(Vector2i.ZERO,1).texture_origin=Vector2i(0,14);open_source.get_tile_data(Vector2i.ZERO,1).flip_h=true
	for i in 10:
		var name_value:String=["wall_north","wall_south","wall_west","wall_east","wall_nw","wall_ne","wall_sw","wall_se","building_shop","building_tavern"][i]
		var source:=TileSetAtlasSource.new();source.texture=load("res://assets/room_mode/structure/"+name_value+".png")
		source.texture_region_size=Vector2i(source.texture.get_size());source.create_tile(Vector2i.ZERO);tileset.add_source(source,30+i)
		if i>=8:
			var data:=source.get_tile_data(Vector2i.ZERO,0);data.texture_origin=Vector2i(0,source.texture.get_height()/2)
			data.add_collision_polygon(0)
			var w:=source.texture.get_width()*0.39;var d:=66.0 if i==8 else 76.0
			data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-w,-d),Vector2(w,-d),Vector2(w,0),Vector2(-w,0)]))
	for i in 12:
		var source:=TileSetAtlasSource.new()
		if i<4:
			source.texture=load("res://assets/room_mode/refinement/chest_"+["closed","unlock","open","empty"][i]+".png")
		else:
			var icon:=AtlasTexture.new();icon.atlas=load("res://assets/room_mode/refinement/mushroom_icons.png");icon.region=Rect2((i-4)*64,0,64,64);icon.filter_clip=true;source.texture=icon
		source.texture_region_size=Vector2i(64,64);source.create_tile(Vector2i.ZERO);tileset.add_source(source,40+i)
		source.get_tile_data(Vector2i.ZERO,0).texture_origin=Vector2i(0,28 if i<4 else 19)
	var wall_stamp:=TileMapPattern.new()
	for x in range(1,18):
		wall_stamp.set_cell(Vector2i(x+1,0),30,Vector2i.ZERO,0);wall_stamp.set_cell(Vector2i(x+1,12),31,Vector2i.ZERO,0)
	for y in range(1,10):
		wall_stamp.set_cell(Vector2i(0,y+1),32,Vector2i.ZERO,0);wall_stamp.set_cell(Vector2i(20,y+1),33,Vector2i.ZERO,0)
	for entry in [[Vector2i(0,0),34],[Vector2i(20,0),35],[Vector2i(0,12),36],[Vector2i(20,12),37]]:
		wall_stamp.set_cell(entry[0],entry[1],Vector2i.ZERO,0)
	tileset.add_pattern(wall_stamp)
	for kind in ["shop","tavern"]:
		var floor_stamp:=TileMapPattern.new()
		for y in 11:
			for x in 19:
				var source_id:=11 if x in [8,9,10] or y in [4,5,6] else 12
				if kind=="tavern":source_id=13 if x in [8,9,10] and y in [3,4,5,6,7,8] else 10
				floor_stamp.set_cell(Vector2i(x,y),source_id,Vector2i(x%2,y%2),0)
		tileset.add_pattern(floor_stamp)
		var decor:=TileMapPattern.new()
		var decor_layout:Array=[[Vector2i(4,4),14],[Vector2i(14,4),14],[Vector2i(4,8),16],[Vector2i(14,8),16],[Vector2i(6,2),17],[Vector2i(12,2),15]] if kind=="shop" else [[Vector2i(4,4),18],[Vector2i(14,4),21],[Vector2i(4,8),19],[Vector2i(14,8),19],[Vector2i(3,2),15],[Vector2i(15,2),15]]
		for row in decor_layout:decor.set_cell(row[0],row[1],Vector2i.ZERO,0)
		tileset.add_pattern(decor)
	for kind in ["normal","boss","spawn"]:
		var pattern:=TileMapPattern.new()
		var layout:=RoomLayout.generate(512,kind)
		for y in 11:
			for x in 19:pattern.set_cell(Vector2i(x,y),0,Vector2i(x%2,y%2),0)
		# Floor stamps and obstacle stamps are separate to avoid hiding the ground.
		tileset.add_pattern(pattern)
		var props:=TileMapPattern.new()
		for pair in layout.crates:props.set_cell(Vector2i(pair[0],pair[1]),4,Vector2i.ZERO,0)
		for pair in layout.stones:props.set_cell(Vector2i(pair[0],pair[1]),5,Vector2i.ZERO,0)
		if props.get_used_cells().size()>0:tileset.add_pattern(props)
	var door_stamp:=TileMapPattern.new()
	for entry in [[Vector2i(9,0),6],[Vector2i(9,10),7],[Vector2i(0,5),8],[Vector2i(18,5),9]]:
		door_stamp.set_cell(entry[0],entry[1],Vector2i.ZERO,1 if entry[1]==9 else 0)
	tileset.add_pattern(door_stamp)
	ResourceSaver.save(tileset,"res://assets/room_mode/room_tileset.tres",ResourceSaver.FLAG_CHANGE_PATH)
	var scene:Node=load("res://src/room_mode/room_level.tscn").instantiate()
	var painted:Dictionary={}
	for name_value in ["FloorTiles","ObstacleTiles","DoorTiles"]:
		var previous:=scene.get_node_or_null(name_value) as TileMapLayer
		painted[name_value]=[]
		if previous!=null:
			for at in previous.get_used_cells():painted[name_value].append([at,previous.get_cell_source_id(at),previous.get_cell_atlas_coords(at),previous.get_cell_alternative_tile(at)])
			previous.free()
	var palette:=TileMapLayer.new();palette.name="FloorTiles";palette.tile_set=tileset;palette.z_index=0
	palette.modulate=Color(0.48,0.56,0.52)
	scene.add_child(palette);palette.owner=scene
	var obstacles:=TileMapLayer.new();obstacles.name="ObstacleTiles";obstacles.tile_set=tileset;obstacles.y_sort_enabled=true
	scene.add_child(obstacles);obstacles.owner=scene
	var patterns:=TileMapLayer.new();patterns.name="DoorTiles";patterns.tile_set=tileset;patterns.z_index=1
	scene.add_child(patterns);patterns.owner=scene
	for layer in [palette,obstacles,patterns]:
		for row in painted[str(layer.name)]:
			if row[1] in [9,25,29] and row[3]==0:row[3]=1
			if row[1]==25:row[2]=Vector2i(0,2)
			layer.set_cell(row[0],row[1],row[2],row[3])
	var packed:=PackedScene.new();packed.pack(scene);ResourceSaver.save(packed,"res://src/room_mode/room_level.tscn")
	scene.free()
	print("ROOM_TILESET_OK 52 sources + service floor/decor and directional door patterns + 7 terrains")
	quit()
