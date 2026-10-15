class_name ReleaseNotes
extends RefCounted
## New releases are prepended; keep prior entries for the settings history.
const RELEASES:Array[Dictionary]=[
	{
		"version":"0.4","title":"失名星城","date":"2026年10月15日",
		"intro":"星灯越过苏醒的林地，照见一座不肯迎来明天的城市。新的章节、新的构筑与旅途修整，现已随 V0.4 到来。",
		"sections":[
			{"title":"第二关 · 失名星城","text":"通关苏醒林地后，所有角色均可在营地选择第二关，重新准备并独立出征。新增六张普通场景与三张首领场景；苔石四角庭、古庭木台迁入星城，原有地图编辑数据保留。\n执印巡卫·塞芙菈、千页司书·维蕾娜、无名录仪带来三场独立首领战。首领按本章进度出现，第二关的 BossRush 挑战本章三位首领。"},
			{"title":"被保存的名字","text":"新增十个章节剧情节点，三名角色各有专属回应。记录官维蕾娜拥有五种表情立绘。已读剧情可以跳过或简短重访，旅途回响支持按章节、角色回看。\n本章胜利由击败三位首领判定。终幕之后可呼唤女神返回营地，或选择继续无尽探索。"},
			{"title":"装备、遗物与构筑","text":"新增十二件装备与遗物，补充连击、技能与闪避等构筑联动。品质文字采用独立艺术字，雇佣介绍与单位的实际攻击方式保持一致。\n战斗掉落及宝箱的珍贵物品更倾向产出遗物：装备与遗物均可产出时，分别按 35% 与 65% 选择。遗物仍遵守原有产出上限；清房三选一的相对概率保持原样。套装说明统一使用“套装效果”，尚未成型时以灰色显示。"},
			{"title":"战斗节奏与敌人生态","text":"普通战斗房及精英变体按章节和地图生态组合敌人，增加不同兵种搭配。增援按时间逐个登场，同时在场的普通增援设有上限，死亡腾出位置后继续生成；原有驻守单位与召唤单位不占该增援额度。\n第一关以森林、湿地生物为主，第二关以旧城骸骨与星术守卫为主；特殊房间保留各自的场景生态。修复冲刺进入新房间后仍继续滑行的问题。"},
			{"title":"角色表现与战斗信息","text":"修正希露媞雅动作帧裁切及部分技能表现，调整地面光阵与瞬移特效的脚底位置；祈光充盈光圈改为围绕角色显示。修复天赋树图标重叠及重做前文案残留。\n玩家血条与蓝条显示当前数值和上限；未完成的成就图标以灰色呈现。修整部分装备图标边缘残留，并保留现有技能、天赋与装备联动。"},
			{"title":"宝箱、界面与旅途记录","text":"普通宝箱与特殊宝箱进一步缩小，降落阴影、落点法阵与实际落点统一。宝箱金币采用与异闻相同的模型，并调整为异闻原显示大小的三分之二。\n更新公告首次进入新版本主菜单时显示，设置中可随时回看。公告采用半透明毛玻璃与流光边缘，减少动效设置可停用流光运动。兼容已有存档，营地地图继续使用开发者保存的最新碰撞配置。"}
		]
	}
]
static func current()->Dictionary:return RELEASES[0]
static func needs_prompt()->bool:return str(SaveService.data.get("release_notes_seen",""))!=str(current().version)
static func acknowledge()->bool:
	var previous:String=str(SaveService.data.get("release_notes_seen",""))
	SaveService.data.release_notes_seen=str(current().version)
	if SaveService.save_data():return true
	SaveService.data.release_notes_seen=previous
	return false
