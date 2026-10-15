道具表使用说明（items.json）
=====================================

这个文件是**你自己维护的道具表**。游戏启动时会优先读它，
读不到才会退回代码里的内置定义。改完保存、重开游戏即可生效。

想加/删道具、换图标、改效果和产出概率，都只需要编辑这个文件。


一件道具长这样
--------------
{
  "id": "staff_fire",              // 唯一标识，随便起英文名，不能重复
  "name": "火焰法杖",               // 显示名
  "desc": "均衡输出 · 八方向魔法攻击",   // 数值/功能说明（详情面板里显示）
  "flavor": "杖身温热，靠近能闻到淡淡的硫磺味。",  // 简介（风味文本，可留空）
  "kind": "weapon",                // 见下面「种类」
  "weapon_class": "mage",          // 职业类别：mage / warrior / archer；召唤师沿用法杖
  "rarity": 2,                     // 0普通 1精良 2稀有 3传说（影响配色和默认概率）
  "cost": 34,                      // 商店售价
  "icon": "icons:01_Weapons/0004_staff_fire.png",   // 见下面「图标」
  "flat": { "max_hp": 10.0 },      // 加法加成：最大生命 +10
  "mult": { "attack": 0.15 },      // 乘法加成：攻击力 +15%

  // 只有 kind = weapon 才需要：
  "weapon": {
    "sprite": "same",              // "same" = 保留的素材参考；手持模型由角色动画绘制
    "cd": 0.75,                    // 每发间隔（秒），越小射速越快
    "dmg": 0.85,                   // 单发伤害 = 玩家攻击力 × 这个值
    "reach": 560,                  // 攻击射程（像素）
    "shots": 1,                    // 一轮几发（霰弹类可以写 3）
    "spread_deg": 0,               // 多发时的散射角（度）
    "speed": 430,                  // 弹速
    "color": "#ff9a3d"             // 弹丸颜色
  },

  // 只有 kind = potion 才需要：
  "effect": { "kind": "heal", "amount": 45 }
  // 或者限时增益：
  // "effect": { "kind": "buff", "stat": "attack", "value": 0.35, "duration": 20 }

  // 可选：产出概率与渠道
  "weight": 3.0,                   // 越大越常出；不写就按稀有度自动算；0 = 不自然产出
  "sources": ["shop", "chest", "reward"]   // 只在哪些渠道出现，不写 = 三个渠道都会出
}


种类 kind
---------
  buff       遗物：拿到就立即生效，不能装备
  weapon     武器：装到武器槽，改变普攻属性与特效，受职业限制（同时只能带一把）
  armor      护甲：装到护甲槽
  accessory  饰品：装到饰品槽
  potion     药剂：在背包里点「使用」立即生效，用完消失


图标 icon
---------
三种写法：
  "icons:01_Weapons/0004_staff_fire.png"   ← 用 assets/icons/ 里的图（推荐，共 100 张）
  "sheet:118"                              ← 用 Kenney 图集第 118 号（血条/金币那套）
  "tex:res://assets/next_revision/loot/key.png"       ← 直接指定一张贴图

assets/icons/ 下的分类（每个文件都是「编号_名字.png」）：
  01_Weapons 武器 / 02_Armor 护甲 / 03_Potions 药剂 / 04_Gems_Jewelry 宝石饰品
  05_Food_Drink 食物 / 06_Materials 材料 / 07_Plants_Nature 植物 / 08_Magic 魔法
  09_Tools 工具 / 10_Loot_Currency 金币箱钥 / 11_Monster_Drops 怪物掉落
  12_Status_UI 状态图标 / 13_Clothing 服装 / 14_Misc 杂项


属性名（flat / mult 的键）
--------------------------
  attack 攻击力 / max_hp 最大生命 / move_speed 移动速度
  dash_cooldown 冲刺冷却 / lifesteal 普攻命中回复（固定生命值；仅血纹护符、不死鸟之心、已装备生命药囊各 1 点，同名不叠加，总计最多 3 点）/ thorns 反伤
  crit_chance 暴击率（0.15 = 15%）/ crit_mult 暴击伤害 / coin_gain 金币收益


产出渠道
---------
  shop    商人货架
  chest   补给箱
  reward  首次挑战战斗房清场后的三选一


检查是否改对了
--------------
进游戏 → 主菜单「星遗录」页面，能看到当前实际加载的所有道具
（图标、种类、稀有度、产出渠道、权重）。数量不对或报错的话，
启动日志里会有一行 [道具表] 提示具体哪一条写错了。

注意：tools/export_item_table.gd 会用代码里的内置定义覆盖这个文件，
它已经做了保护 —— 重新导出时会保留你写的 flavor / weight / sources。
真要保险的话，改之前先复制一份备份。
