class_name NpcArt
extends RefCounted
## One identity map for trading, camp interactions and dialogue expressions.
const ROOT := "res://assets/next_revision/npcs/"
const FALLBACK := {"merchant":"res://assets/ui_art/shop/merchant_portrait.png", "tavern":"res://assets/characters/tavern_npc.png"}
static func portrait_path(npc:String,state:="welcome")->String:
	var revised:=CampResidents.ROOT+npc+"_"+state+".png"
	if ResourceLoader.exists(revised):return revised
	revised=CampResidents.ROOT+npc+"_welcome.png"
	if ResourceLoader.exists(revised):return revised
	var path:=ROOT+npc+"_"+state+".png"
	if ResourceLoader.exists(path):return path
	path=ROOT+npc+"_welcome.png"
	return path if ResourceLoader.exists(path) else str(FALLBACK.get(npc,Story.P_GODDESS))
static func portrait(npc:String,state:="welcome")->Texture2D:
	return load(portrait_path(npc,state)) as Texture2D
static func background(npc:String)->Texture2D:
	var path:=ROOT+npc+"_background.png"
	if not ResourceLoader.exists(path):path="res://assets/ui_art/shop/star_shop_backdrop.png"
	return load(path) as Texture2D
