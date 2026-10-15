extends Node
## 全局信号总线。
##
## 系统之间不要互相直接引用（那会变成一团解不开的线），
## 需要通信时一律通过这里发信号，谁关心谁自己连。

signal run_started(run_index: int)
signal run_ended(final_wave: int, coins: int)

signal wave_started(wave: int, total_enemies: int)
signal wave_cleared(wave: int)
## Stable story checkpoint ID; room/Boss progression decides when it fires.
signal story_checkpoint(wave: int)
## 酒馆：打开雇佣界面 / 雇佣名单变化
signal tavern_opened(offers: Array)
signal tavern_closed
signal hired_changed()
## Boss 战：进入/结束（BGM 和界面都挂在这两个信号上）
signal boss_started(boss_id: StringName)
signal boss_defeated(boss_id: StringName)
signal rest_started(duration: float)
signal rest_ended()

signal enemy_spawned(enemy: Node)
signal enemy_died(kind: StringName, where: Vector2, coins: int)
signal enemies_enraged()

signal player_damaged(amount: float, hp: float, max_hp: float)
signal player_healed(amount: float, hp: float, max_hp: float)
signal player_died()
signal player_stats_changed()

signal level_changed(level: int, gained: int)
signal talents_changed()
signal mp_changed(mp: float, max_mp: float)
signal hotbar_changed()
signal skill_cast(skill_id: StringName)
signal skills_changed()

signal coins_changed(coins: int)
signal keys_changed(keys: int)
signal item_acquired(item: Dictionary)
signal item_received(item: Dictionary)
signal equipment_changed()
signal chest_opened(loot: Dictionary)
signal chest_spawned()

signal shop_opened(offers: Array)
signal shop_closed()
signal interact_prompt_show(text: String)
signal interact_prompt_hide()
signal interaction_failed(message: String)

signal request_screen_shake(strength: float)



