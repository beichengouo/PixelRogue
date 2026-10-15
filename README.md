# PixelRogue 原型

横版平台跳跃（马里奥式）+ 肉鸽波次 + 波间休整/商店的可玩雏形。
用 Godot 4.7 打开本文件夹即可运行，不需要安装任何插件、不需要任何美术素材。

## 现在能玩到什么

- 跑、跳、二段跳（拿到道具后）、冲刺、挥砍，带土狼时间与跳跃缓冲的手感处理
- 敌人**全部在相机视野外刷新**（屏幕外 + 离玩家有最小距离）
- 波次推进：准备 3 秒 → 战斗 → 全清 → 三选一道具奖励 → 休整 30 秒 → 下一波更难
- 休整期间走到地图上的商人处，可以花金币买道具、免费休整回血
- 15 件可叠加的道具，构成属性构筑（攻击/生命/移速/暴击/吸血/反伤/金币/二段跳……）
- 死亡结算 + 历史最佳波次存档（`user://pixel_rogue_save.json`）

## 运行方式

**方式一（推荐）**：打开 Godot 4.7 → 导入 → 选择本文件夹的 `project.godot` → 按 F5。

**方式二（命令行）**：

```
"E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "<本文件夹路径>"
```

## 操作

| 操作 | 键盘 | 手柄 |
|---|---|---|
| 移动 | A / D 或 ← / → | 左摇杆 / 十字键 |
| 跳跃 | 空格 / W / ↑ | A |
| 挥砍 | J | X |
| 冲刺（有短暂无敌） | K / Shift | B |
| 交互（对商人） | E | Y |
| 提前开始下一波 | Enter | Start |
| 打开/关闭商店 | E / Esc | Y |
| 暂停 | Esc | Back |
| 重开本局 | R（暂停或死亡界面） | — |

## 自动试玩（用来验证没改坏）

改完代码不想手动玩一遍？跑这个命令，机器人会自己打怪、选道具、去商店买东西、
回血、然后死掉重开，全程不需要人盯着：

```
"E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
    --headless --path "<本文件夹路径>" --fixed-fps 60 --quit-after 10800 -- --autoplay
```

`--quit-after 10800` 表示跑 10800 帧（60fps 下 = 3 分钟游戏时间）。
输出里每 10 秒会打印一行状态，如果某波卡住不动还会自动打印「僵持诊断」。

## 画地图（这部分完全交给你）

地形和背景装饰都在**编辑器里直接画**，不需要改代码。

打开 `src/world/level.tscn`，你会看到这样的结构：

```
Level
├── Background                背景（视差滚动）
│   ├── Sky/SkySprite         天空：一块被拉伸的天空瓦片，选中它调 modulate 就能换天色
│   └── Scenery/SceneryTiles  远景装饰层（48px 背景瓦片）
├── Decor                     装饰层     ← 用「透明」瓦片画树/草丛，会被地形遮住
├── Tiles                     地形层     ← 主要在这里画
├── PlayerSpawn               玩家出生点（带文字的方框，直接拖）
└── ShopSpawn                 商人位置（带文字的方框，直接拖）
```

**画地形的步骤**：选中 `Tiles` 节点 → 屏幕底部出现 TileMap 面板 → 选一块瓦片 → 用画笔在场景里涂。

瓦片集分成**三组**，在 TileMap 面板里可以切换。图集里全部 180 块瓦片在三组里都能找到，区别只是碰撞行为：

| 组 | 碰撞行为 | 典型用途 |
|---|---|---|
| 实心 | 四面都挡 | 地面、墙、封闭方块 |
| 单向 | 只能从上面踩住，可以从下面跳穿 | 悬空平台 |
| 透明 | **完全不挡** | 纯装饰：树、草丛、石头、箱子、旗帜…… 画在 `Decor` 层会被地形遮住 |

单向平台不是可有可无的：没有它，敌人站在平台正下方时会被平台底面顶住，那一波就永远打不完。这是开发过程中实测踩到的坑。

三个层各有分工，别画错地方：

| 层 | 用哪组瓦片 | 效果 |
|---|---|---|
| `Background/Scenery/SceneryTiles` | 背景瓦片集（48px） | 最远的一层，跟着相机缓慢移动 |
| `Decor` | 地形瓦片集的「透明」组 | 在背景和地形之间，会被地形挡住 —— 树、草丛放这里 |
| `Tiles` | 「实心」+「单向」 | 真正的地形，也是唯一有碰撞的一层 |

想摆一个"能站在上面的树"？树冠用「透明」画在 `Decor`，再在它顶部用「单向」补一格就能踩上去。三组可以自由搭配。

**装饰物在哪**：识图扫过整张图集给的线索（具体以你在面板里看到的为准）——树冠约在 96-99、树干 116-119、草丛 124-125、仙人掌 127、石块 8-9、木箱木板 47-50、旗帜 111-112、云朵平台 153-155。这些都在「透明」组里能直接画。

**画背景装饰**：选中 `Background/Scenery/SceneryTiles`，同样的画法。

有一个约束要注意：背景瓦片是**按主题分组的，底色必须一致**，否则摆上去会露出一个个方块。当前天空是浅蓝色主题，配套的只有「天空」和「云、树」那两组；黄昏、森林、另一套天空的瓦片混着摆一定会穿帮。

**改了地形不用管的事**：相机边界、摔落线、刷怪点都会自动跟着你画的范围计算。出生点和商人位置是 Marker2D，直接用鼠标拖。

**两个工具脚本，别搞混**：

| 脚本 | 作用 | 会不会动你的地图 |
|---|---|---|
| `tools/build_tilesets.gd` | 重新生成瓦片集（改分组、加瓦片时用） | **不会**，随时可以跑 |
| `tools/reset_level_scene.gd` | 把关卡重置回初始布局 | **会全部覆盖**，想清楚再用 |

## 目录结构

```
src/
  main/main.gd            入口：组装世界 / 界面 / 系统，负责重开一局
  autoload/               全局单例
    event_bus.gd            信号总线（系统之间只通过它通信）
    game_state.gd           一局的运行时状态 + 玩家基础属性
    rng_service.gd          统一随机源（带种子，可复现）
    save_service.gd         跨局存档
  data/
    stats.gd                属性块：基础值 + 道具的加法/乘法
    item_db.gd              15 件道具的数据表
    wave_table.gd           波次表：每波刷什么、难度怎么涨
  systems/
    wave_director.gd        波次状态机 + 僵持时的「暴怒」机制
    combat.gd               伤害结算（纯函数，好测）
  world/
    level.tscn              关卡场景 ★ 你画地图的地方
    level.gd                读取你画的地形，供刷怪系统判断哪里站得住人
    level_data.gd           初始布局的字符模板（只有重置关卡的工具脚本会用到）
    tileset_builder.gd      金币等精灵的图集取用工具
    spawn_finder.gd         视野外刷怪点选择
    camera_rig.gd           相机跟随 + 边界 + 震屏
  actors/
    player.gd               玩家：移动/跳跃/冲刺/挥砍/受伤
    enemy_base.gd           敌人基类：血量/受伤/击退/接触伤害/掉落
    enemy_walker.gd         游荡者（地面，遇墙或玩家在高处会跳）
    enemy_flyer.gd          浮游灵（无视地形直飞）
    enemy_charger.gd        冲锋兵（蓄力预警后猛冲）
    coin.gd / effects.gd / floating_text.gd / shop_npc.gd
  ui/
    hud.gd                  血条/金币/波次/道具列表/提示横幅
    shop_ui.gd              商店
    item_choice_ui.gd       三选一
    game_over_ui.gd / pause_ui.gd
    ui_factory.gd           代码构建 UI 的工具 + 中文字体主题
  tools/
    autopilot.gd            自动试玩机器人
    build_tilesets.gd       生成瓦片集（安全，不影响已画地图）
    reset_level_scene.gd    重置关卡场景（会覆盖你的地图）
    setup_input_map.gd      一次性：生成按键映射写入 project.godot
    verify_project.gd       自检

assets/kenney/
    tiles_36px.png          地形图集（原素材 18px，按 2 倍显示）
    backgrounds_48px.png    背景图集
    terrain_tileset.tres    带碰撞的地形瓦片集（实心 / 单向）
    background_tileset.tres 背景装饰瓦片集
    LICENSE_kenney_CC0.txt  素材授权（CC0，可商用）
```

角色、敌人和界面由代码创建（`main.tscn` 只是入口），关卡则是一个真实场景，可以在编辑器里可视化编辑。

## 想改数值改哪里

## 角色与武器（美术接入）

### 角色素材怎么进来的

主角用的是 DuskBorne-Elf，怪物用的是 2D Pixel Dungeon Asset Pack。处理脚本：

```
tools/build_character_assets.gd
```

跑它就重新生成 `assets/characters/` 下的所有图集。它做了三件事：

1. **缩回原生分辨率**：Elf 的精灵表被放大了 **10 倍**（实测），不缩回来直接用，在游戏里再缩小会毁掉像素
2. **统一裁剪**：按所有动画的公共范围裁，保证动画之间不抖动、脚底对齐
3. **拼成横条**：每个动画一条横图，帧数 = 图宽 / 帧宽

| 图集 | 单帧 | 帧数 |
|---|---|---|
| `elf_idle.png` | 52×54 | 6 |
| `elf_walk.png` | 52×54 | 8 |
| `elf_attack.png` | 52×54 | 7 |
| `elf_hurt.png` | 52×54 | 4 |
| `elf_death.png` | 52×54 | 8 |
| `monster_skeleton / skull / vampire / skeleton2` | 32×32 | 4（放大 2 倍） |
| `weapon_sword.png` | 20×8 | 占位武器 |

### 武器是怎么"拿在手上"的

角色图里**不含武器**（Elf 的动画是空手的）。实现方式是一个挂点：

```
Player
├── Sprite          AnimatedSprite2D，播放 Elf 的动画
└── Hand            Node2D 挂点 ← 武器挂在这里
    └── WeaponSprite  Sprite2D，贴图来自道具数据
```

- `Player._update_hand_pose()` 每帧决定手的位置和角度：待机时垂在身侧，挥砍时带着武器扫出一道弧线
- 道具数据里写 `weapon` 字段，拿到就自动装备：

```gdscript
"weapon": {
    "sprite": "res://assets/characters/weapon_sword.png",
    "grip": Vector2(8.0, 0.0),   # 握点相对手部原点的偏移
    "scale": 1.0,
},
```

**换武器只要换贴图和这两个数字，角色动画完全不用重新导出。**

想调握法，改 `player.gd` 里 `_update_hand_pose()` 的两组数字即可（都是相对角色中心的像素偏移）。

### 要扩展成正式装备栏，还差什么

现在只做了「拿在手上」这一层。完整的装备系统按这个顺序加：

1. **数据**：把武器从道具表里拆出来，做成独立的数据项（或自定义 Resource），带上槽位类型、属性、贴图、握点
2. **槽位**：`GameState` 里加 `equipped = {"main_hand": item_id}`，HUD 加装备格，UI 支持拖放
3. **逐帧手部姿态**（想要"每把武器不同的握法和挥砍轨迹"就做这步）：把现在写死的两组姿态，升级成「每把武器 × 每个动作 × 每一帧」的姿态表：

```gdscript
weapon.hand_poses = {
    "idle":   [{"pos": Vector2(7, -6), "rot": 0.0}, ...],
    "attack": [{"pos": Vector2(5, -9), "rot": -1.2}, ...],
}
```

   另一种更省事的做法：**给武器配自己的挥砍动画图集**，装备后播武器自己的动画，角色的手只做大致跟随。横版像素游戏里两种都很常见。

| 想改什么 | 改哪里 |
|---|---|
| 玩家血量/攻击/移速/跳跃力 | `src/autoload/game_state.gd` 的 `BASE_STATS` |
| 跳跃手感、冲刺、攻速、无敌时间 | `src/actors/player.gd` 顶部的常量 |
| 敌人血量/伤害/速度/掉金币 | 各个 `enemy_*.gd` 的 `_init()` |
| 每波刷多少、难度涨幅 | `src/data/wave_table.gd` |
| 同屏上限、休整时长、刷怪间隔 | `src/systems/wave_director.gd` 顶部常量 |
| 道具效果与售价 | `src/data/item_db.gd` |
| 地形与出生点 | **在编辑器里画**：打开 `src/world/level.tscn`（见上面「画地图」） |
| 配色 | `src/util/palette.gd` |

## 已知限制（原型阶段的取舍）

- 地形和背景已接入 Kenney 像素素材（CC0）；**角色和敌人仍是代码画的色块**，没有帧动画
- 只做了 PC 键鼠 + 手柄；手机触屏的虚拟摇杆还没做（但输入已经走 InputMap 抽象，加触屏不用改逻辑）
- 没有音效音乐
- 没有 Boss、没有层数概念、局外成长只有一个「历史最佳波次」
- 敌人不会寻路，靠「跳跃 + 暴怒加速」保证能追上玩家

## 下一步可以做的

1. 换美术：把 `_build_visual()` 里的色块换成 `Sprite2D` + 帧动画
2. 手机端：虚拟摇杆（用 `Control` + 触摸事件）+ 安全区适配 + Android 导出模板
3. 内容：加 Boss 波、加更多敌人类型和道具、把 15 件扩到 40 件
4. 元进度：用累计金币解锁新角色/新道具进池
5. 关卡：从「一张固定竞技场」扩成「多层房间 + 房间模板拼接」

