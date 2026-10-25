# Four-stage room refactor — inline implementation ledger

Authority: C:/Users/Administrator/Desktop/房间重构.md and confirmed follow-ups.

Decisions: every stage permits existing extraction; stages 1–3 reserve an altar while readings <3 (within the special quota, no replacement); experience is awarded for individual natural enemy kills, never summoned enemies. Bosses award more. Legacy map schemas retain the legacy generator. No packaging, version change, player-save edits or Git publishing.

Dependency audit: RoomGraph owns dynamic expansion, wave redirects and topology pruning; RoomDirector owns waves, reinforcement queues and BossRush; RoomMain owns story/reward/transfer; RoomRuntime snapshots room entities; LootDirector owns kill receipts and XP; Outpost owns the atomic settlement transaction. Minimap currently reveals every generated node. These are the integration points, not replacement global managers.

- [x] Data-only deterministic stage generator, bounded retry/fallback, 1000 seeds per stage.
- [x] Schema 3 graph, fixed bosses, stable stage identities, legacy compatibility, retained snapshots.
- [x] Active stage portals, stage 3 risk confirmation, reward-before-transition and restore.
- [x] Stage/depth strength and per-kill XP with origin/receipt guards.
- [x] Extreme reward material, atomic settlement, achievement and result display.
- [x] Map fog, existing GM/UI compatibility and end-to-end regression.

Ruling: retain the existing dirty formal checkout and separate QA project; copying it into a new worktree would omit the user's and earlier session's uncommitted content. Verification uses isolated E: userdata. No subagents as requested.


Completed: schema 3 staged maps and old v1/v2 isolated restoration; stage/depth strength retains old boss 10/20/30 equivalents and stage4 rush50. Actual kill XP replaces room-clear top-up only on new staged runs. Counts, pressure, service stocks and snapshots retained. All stages use existing 3+30+2 combat /3+5+2 safe extraction. Stage1/2 deliberate gate, stage3 reversible exploration / withdraw / confirmed stage4, stage4 final rush + one legal rare-or-better item bonus. Starbound sigils (2–4) and extreme-return statistics are added only inside successful existing settlement transaction; no additional elite economy multiplier was enabled.

Review rulings: solo review honors the user's no-subagent request. Two distinct RNG salts prevent identical stage layouts. Trial/event generation uses actual prior clears; the explicitly approved reserved altar is the exception. The stage marker uses the actor ground sorting plane (RED invisible-under-ground test → GREEN), caches its anchor and chooses the player's reachable component. Loading/rollback guards tolerate no live player. A held complete checkpoint protects background/OS-close saves during stage replacement; only the destination commit bypasses it (RED partial-stage save → GREEN). Both pre-load and post-load disk failures preserve prior state. No overwrite of user collision edits.

Verification details are in verification.json and the existing polish-v045 logs. Core flow/transactions cover 3 heroes,2 chapters,4 difficulties; actual six-boss setup/scaling/CRUEL checks864. All four stages have 1000-seed topology tests, size extremes, explicit fallback, unlocked specials and JSON restore. Backtracking and full reload preserve real unpicked loot above the old ten-room cap. PC/mobile layout variants100 each. Existing item/talent/workshop/GM/camp/input suites listed in the JSON passed.

Combat probes (real attacks/loot/GM decisions, accelerated headless, not an FPS claim): empty-start Ilyua4501 reached stage2/lv18 and died at307.24 gameplay seconds; full-set Xixifu4502 defeated all three chapter bosses at522.37 gameplay seconds/lv34 (146.94 wall seconds). The latter predates the final special-unlock guard/save-only fixes; final flow/scaling/transaction suites cover those changes. Neither probe claims fourth-stage combat completion. Android device performance remains user-side. An older scene_nav_service_regression was not counted: it assumes hard validation blocks saving and removes existing user-authored collision overrides in its fixture. No production validation behavior or authored map data was changed to satisfy it.

No version, player save, package, Git commit/push or user editor process changes. Formal and QA sources are byte-identical; only the new PNG import/cache and three script UID sidecars were copied into formal, without opening another editor.
