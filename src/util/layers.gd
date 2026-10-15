class_name Layers
extends RefCounted
## 物理层定义。
##
## 用命名常量代替魔法数字，改碰撞关系时只动这一处。
## 注意 Godot 的层是「位」：层 1 = 1<<0，层 2 = 1<<1。

const WORLD := 1 << 0         # 地形平台
const PLAYER := 1 << 1        # 玩家本体
const ENEMY := 1 << 2         # 敌人本体
const PLAYER_ATTACK := 1 << 3 # 玩家攻击判定
const PICKUP := 1 << 4        # 掉落物
const ENEMY_ATTACK := 1 << 5  # 敌人接触伤害
const INTERACT := 1 << 6      # 交互范围（商店 NPC）
const ONE_WAY := 1 << 7       # 单向平台（单独一层，才能只关掉它做「下穿」）
const HAZARD := 1 << 8        # 伤害物块（尖刺等）
const DEEP_WATER := 1 << 9    # 深水仅阻挡地面单位，弹道与飞行单位可越过
const UNIT_BODY := 1 << 10   # 地面脚底体积；与攻击、接触伤害判定分离

## set_collision_mask_value() 用的是 1 起算的层号，这里换算好，免得每次心算
const ONE_WAY_LAYER := 8
const HAZARD_LAYER := 9

const BOSS_OBJECT := 1 << 11 # Breakable emitters block projectiles, never actors.
