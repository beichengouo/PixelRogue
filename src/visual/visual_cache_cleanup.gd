extends RefCounted
## Release resource caches only at application shutdown, after world/UI nodes exit.
## Never call this when returning to a menu or changing rooms.
static func release() -> void:
	PixelUi._theme = null
	PixelUi._art_shader = null
	StarUi._theme = null
	StarUi._font = null
	UiFactory._font_cache = null
	GameFonts._cache.clear()
	PixelSpellArt._cache.clear()
	PixelSpellArt._material = null
	PixelMeleeFX._frames = null
	WorldMapV2._tileset = null
	RoomHeroArt._frames = null
	HanddrawnHeroArt.clear()
	RedrawnHeroArt._cache.clear()
	RedrawnHeroArt._material=null
	IlyuaFX._cache.clear()
	RoomCreatureArt.cache.clear()
	RevisedMonsterArt._cache.clear()
	ForestUnitArt.clear()
	LargeSkillArt._cache.clear()
	RoomExpansionRules._textures.clear()
	RoomAimCursor._texture=null
	CampResidentArt._frames.clear()
	SpecialRoomArt._chests.clear()
	SpecialRoomArt._icons.clear()
	KeyBindings._defaults.clear()
	RewardCategoryWordmark._textures.clear()
	UltimateCutin.portraits.clear()
	WeaponArt._cache.clear()
	WeaponBuildFX._frames.clear()
	RoomWaterArt.clear_cache()
	WeatherSurfaceArt._particle_frames.clear()
	SuppliedMapAssets.clear_cache()
	LightUtil._radial = null
	MonsterCodex._icons.clear()
	CampArt._cache.clear()
	ExtractionSpriteArt._cache.clear()
	ExtractionSpriteArt._success_profiles.clear()
	DialogueButtonArt._textures.clear()
	DialogueCast.clear_cache()
	ShopArtButton._sheets.clear()
	SpectralCompanionArt._cache.clear()
	SmallSpiritArt._frames=null
	CurrencyArt._frames.clear()
	FrostedGlass._shader=null
	InteractionSkin._textures.clear()
	InteractionSkin._theme=null
	RarityWordmark._textures.clear()
	RarityWordmark._compact.clear()
	XixifuArt._frames = null
	PixelHireArt._frames.clear()
	PixelHeroArt._frames = null
	PixelEnemyArt._frames.clear()
	NewMonsterAtlasArt._cache.clear()
	NewMonsterAtlasArt._metadata.clear()
	PixelEnemyArt._textures.clear()
	PixelEnemyArt._generated_data.clear()
	HireOffers._portraits.clear()
	PixelBossArt._cache.clear()
	BossStageArt.clear()
	UnitHealthArt._profiles.clear();UnitHealthArt._skulls.clear()
	SizedSkillArt._cache.clear();SizedSkillArt._order.clear()
	CombatContactFX._banks.clear();FateSpellFX._textures.clear()
	LightModelArt._cache.clear()
	BossEntranceArt._packs.clear();BossEntranceArt._order.clear()
	GlowMushroom._frames.clear()
	WorldPropArt._frames.clear()
	EnvironmentAudio.streams.clear()
	ItemChoiceUI._glow_shader = null
	RewardCardFX._shader=null
	Effects._rng = null
	CombatArtWarmup.clear()
	HostileAttackFX._frames.clear()
	HostileAttackFX._shader=null
	HostileAttackFX._strike_shader=null
	HolyFX.textures.clear()
	RoomSceneOcclusion._frame_bounds.clear()
	var navigation:Script=load("res://src/room_mode/room_scene_navigation.gd")
	navigation._shared.clear();navigation._lru.clear()
	TexturePixels.clear()
