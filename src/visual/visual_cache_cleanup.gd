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
	RedrawnHeroArt._cache.clear()
	RedrawnHeroArt._material=null
	IlyuaFX._cache.clear()
	RoomCreatureArt.cache.clear()
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
	DialogueButtonArt._textures.clear()
	ShopArtButton._sheets.clear()
	SpectralCompanionArt._cache.clear()
	SmallSpiritArt._frames=null
	CurrencyArt._frames.clear()
	FrostedGlass._shader=null
	InteractionSkin._textures.clear()
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
	GlowMushroom._frames.clear()
	WorldPropArt._frames.clear()
	EnvironmentAudio.streams.clear()
	ItemChoiceUI._glow_shader = null
	RewardCardFX._shader=null
	Effects._rng = null

