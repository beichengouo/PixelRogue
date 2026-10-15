class_name HolySkills
extends RefCounted
const ROOT:="res://assets/characters/sylphiette_holy_v01/"
# Stable legacy IDs migrate the mage's equipped skill slots without losing saves.
const ORDER:Array[StringName]=[&"flame_nova",&"fan_bolts",&"blink",&"meteor",&"flame_shield",&"frost_nova",&"healing_light",&"starfall"]
const DATA:={
&"flame_nova":{"id":&"flame_nova","name":"晨曦圣裁","unlock_level":1,"ultimate":false,"mp":24.0,"cd":7.0,"role":"圣裁","icon":ROOT+"skills/dawn.png","effect":{"kind":"holy_dawn"},"desc":"圣纹追随目标0.25秒，0.55秒后落下光柱：64范围造成1.4倍攻击并附加6秒辉光印记，随后光环造成0.35倍攻击。圣辉强化：附近依次降下三道0.65倍攻击的小光柱。"},
&"fan_bolts":{"id":&"fan_bolts","name":"圣羽巡礼","unlock_level":5,"ultimate":false,"mp":24.0,"cd":10.0,"role":"圣羽","icon":ROOT+"skills/feathers.png","effect":{"kind":"holy_feathers"},"desc":"召出三片圣羽，持续8秒；环绕接触或自动追击造成0.3倍攻击，消耗后2秒重凝，优先攻击普攻近期命中者。命中辉光印记追加一次0.12倍攻击追击。圣辉强化：额外三片圣羽持续3秒，并产生一代细羽。"},
&"blink":{"id":&"blink","name":"圣云庇佑","unlock_level":8,"ultimate":false,"mp":26.0,"cd":14.0,"role":"护佑","icon":ROOT+"skills/cloud_shelter.png","effect":{"kind":"holy_shield"},"desc":"获得20%最大生命护盾，持续6秒；每0.75秒净化一枚近身普通弹幕。实际承伤后反击0.25倍攻击圣羽，护盾耗尽或到期释放72范围、0.6倍攻击冲击。圣辉强化：额外净化三枚普通弹幕并击退普通敌人。"},
&"meteor":{"id":&"meteor","name":"圣辉裁决","unlock_level":12,"ultimate":true,"mp":55.0,"cd":28.0,"role":"圣裁","icon":ROOT+"skills/judgment.png","effect":{"kind":"holy_judgment"},"desc":"持续8秒，每1.2秒在敌群中预告两道0.5倍攻击圣裁。普攻及小技能直击同目标三次（辉光目标两次），降下0.6倍攻击追击，目标冷却1秒。结束分区域施加1.1倍攻击终审。大招不消耗祈光。"},
&"flame_shield":{"id":&"flame_shield","name":"圣钟清鸣","unlock_level":15,"ultimate":false,"mp":22.0,"cd":8.0,"role":"圣钟","icon":ROOT+"skills/bell.png","effect":{"kind":"holy_bell"},"desc":"108范围圣钟造成0.9倍攻击，击退普通敌人54距离并静谧0.55秒；精英、首领分别减速30%、20%持续1.2秒。净化至多三枚普通弹幕。圣辉强化：0.45秒后追加0.55倍攻击回响。"},
&"frost_nova":{"id":&"frost_nova","name":"晨露祷庭","unlock_level":18,"ultimate":false,"mp":28.0,"cd":12.0,"role":"祷庭","icon":ROOT+"skills/dew.png","effect":{"kind":"holy_court"},"desc":"前方合法地面展开90范围、持续6秒的法阵，每秒造成0.22倍攻击；确实命中敌人且自身在阵内时，回复1%最大生命，每阵最多6%。结束0.5倍攻击绽放。圣辉强化：结束追击三名敌人并给予阵内自身8%生命护盾3秒。"},
&"healing_light":{"id":&"healing_light","name":"流光祈步","unlock_level":22,"ultimate":false,"mp":18.0,"cd":12.0,"role":"流光","icon":ROOT+"skills/prayer_step.png","effect":{"kind":"holy_step"},"desc":"沿移动或瞄准方向移动至多108距离，实体地形阻挡；获得0.18秒无敌，起点留下3秒圣影，向附近敌人发射少量0.18倍攻击祷光。路径擦击0.15倍攻击并附加辉光印记，下一次普攻追加光羽。圣辉强化：圣影结束追击三名敌人。"},
&"starfall":{"id":&"starfall","name":"永昼祈愿","unlock_level":25,"ultimate":true,"mp":60.0,"cd":30.0,"role":"圣域","icon":ROOT+"skills/sanctuary.png","effect":{"kind":"holy_sanctuary"},"desc":"展开随身126范围圣域，持续8秒，每0.75秒造成0.35倍攻击，获得12%生命护盾4秒；每秒净化两枚普通弹幕。直击圣域敌人追加0.12倍攻击涟漪，目标冷却0.8秒。结束0.9倍攻击冲击及6%生命护盾3秒。大招不消耗祈光。"}}
