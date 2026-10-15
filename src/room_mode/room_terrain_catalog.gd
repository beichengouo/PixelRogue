class_name RoomTerrainCatalog
extends RefCounted
const ROOT:="res://assets/room_mode/terrain_v3/"
const MODELS:=["pillar","ruined_pillar","boulder","rubble","stump","log","crate_iron","barricade","fern","flowers","bones","jar","arch","altar","shrub","planks"]
const NAMES:=["林地细树","林地圆树","林间岩块","碎岩堆","树根桩","倒木","木制储物箱","木栅栏","青草丛","淡金花丛","遗骨","盆栽","花果树","岩石基座","灌木","旧木板"]
# Every new model supplies all four physical footprints and matching editor art.
const SIZES:=[Vector2i.ONE,Vector2i(2,2),Vector2i(1,2),Vector2i(2,1)]
