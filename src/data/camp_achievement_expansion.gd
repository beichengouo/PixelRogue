class_name CampAchievementExpansion
extends RefCounted
## Reuse existing achievement symbols; IDs and statistics are additive.
const DATA:={
"contract_first":{"name":"说到做到","description":"首次成功交付一份营地委托。","metric":"contracts_delivered","goal":1,"category":"探索","icon":"contracts_five"},
"contracts_ten":{"name":"有事就找你","description":"累计成功交付十次营地委托，重复委托也计入。","metric":"contracts_delivered","goal":10,"category":"探索","icon":"contracts_five"},
"contracts_twenty":{"name":"大家的老熟人","description":"累计成功交付二十次营地委托，重复委托也计入。","metric":"contracts_delivered","goal":20,"category":"探索","icon":"contracts_five"},
"contracts_variety_four":{"name":"顺手帮个忙","description":"完成四种不同的营地委托。旧档已完成的委托也计入。","metric":"contract_seen","goal":4,"category":"探索","icon":"contracts_five"},
"contracts_variety_eight":{"name":"回廊百事通","description":"完成八种不同的营地委托。","metric":"contract_seen","goal":8,"category":"探索","icon":"contracts_five"},
"commission_first":{"name":"今天的小事","description":"完成一段居民生活委托。","metric":"story_commissions","goal":1,"category":"探索","icon":"event_three"},
"commission_six":{"name":"住得越来越熟","description":"完成六段不同的居民生活委托。","metric":"story_commissions","goal":6,"category":"探索","icon":"event_three"},
"commission_all":{"name":"这儿也是家","description":"完成四位营地居民的全部十二段生活委托。","metric":"story_commissions","goal":12,"category":"探索","icon":"two_chapters"},
"commission_surveyor":{"name":"这次说明白了","description":"完成希尔薇娅的「谁都能看懂的手册」。","metric":"story_commissions","contains":"camp_surveyor_handbook","goal":1,"category":"探索","icon":"research_three"},
"commission_carpenter":{"name":"一起坐下吃饭","description":"完成布琳娜的「今晚把桌子拼起来」。","metric":"story_commissions","contains":"camp_carpenter_table","goal":1,"category":"探索","icon":"contracts_five"},
"commission_herbalist":{"name":"休息也算正事","description":"完成艾莉娅的「好好休息也算正事」。","metric":"story_commissions","contains":"camp_herbalist_rest","goal":1,"category":"探索","icon":"holy_healing"},
"commission_minstrel":{"name":"记在今天这页","description":"完成闻铃的「没有观众席的晚会」。","metric":"story_commissions","contains":"camp_minstrel_evening","goal":1,"category":"探索","icon":"event_three"},
"low_gear_ready":{"name":"朴素也齐整","description":"正式出征中同时穿戴普通或精良的武器、衣服和饰品。训练不计入。","metric":"low_gear_ready","goal":1,"category":"收集","icon":"legendary_set"},
"low_gear_six":{"name":"好用就留下","description":"正式出征中取得六种普通或精良装备；穿戴的装备也计入。","metric":"low_gear_seen","goal":6,"category":"收集","icon":"bound_return"},
"low_relic_six":{"name":"口袋里的小帮手","description":"正式出征中取得六种普通或精良遗物。","metric":"low_relic_seen","goal":6,"category":"收集","icon":"chests"},
"alchemy_first":{"name":"配方真管用","description":"正式出征中成功制作一份炼金产物。","metric":"field_alchemy","goal":1,"category":"收集","icon":"alchemy_ten"},
"enchant_first":{"name":"亲手补强","description":"正式出征中成功刻印一件装备。","metric":"field_enchants","goal":1,"category":"收集","icon":"enchant_three"},
"research_first":{"name":"带回来的用处","description":"在营地完成一项工坊研究。","metric":"research_seen","goal":1,"category":"收集","icon":"research_three"},
"bound_first":{"name":"这件要带回去","description":"成功撤离并把一件绑定装备存进仓库。","metric":"bound_returned","goal":1,"category":"收集","icon":"bound_return"},
"event_first":{"name":"听完这段故事","description":"处理一次正式出征中的异闻房事件。","metric":"event_resolutions","goal":1,"category":"探索","icon":"event_three"},
"elite_first":{"name":"硬仗的第一回","description":"清理一间精英房。","metric":"elite_clears","goal":1,"category":"挑战","icon":"elite_five"},
"trial_first":{"name":"别急，一轮轮来","description":"完成一间试炼房的全部轮次。","metric":"trial_clears","goal":1,"category":"挑战","icon":"trial_three"},
"extractions_five":{"name":"又平安回来了","description":"累计成功撤离五次。","metric":"extractions","goal":5,"category":"探索","icon":"extraction"},
"rooms_thirty":{"name":"路越走越熟","description":"累计清理三十间战斗房。","metric":"rooms","goal":30,"category":"探索","icon":"rooms_ten"}
}
