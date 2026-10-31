class_name CampStory
extends RefCounted
const INTRO = "你与希露媞雅、希希芙、伊露雅都记得自己的名字和本领，却想不起个人经历与共同过去。你们现在住在星辉回廊：你整理行囊和记录，她们亲自远行调查，回来后一起核对线索。\n\n黑晶会重复保存的声音和动作，内容可能残缺或被拼接。先查苏醒林地的旧路标，再寻找失名星城的记录；熟悉的声音只是线索，不等于已经找回的记忆。关系也由现在的相处决定，不由过去替你们作答。"
const EVENTS = {
	"merchant": [
		{
			"id": "meeting",
			"title": "货架与归路",
			"gain": 2,
			"min": 0,
			"require": "",
			"lines": [
				{
					"who": "",
					"text": "姜糖把一枚星纹扣放到你手心，又笑着收了回去："
				},
				{
					"who": "merchant",
					"text": "‘先看看，不买也没关系。’",
					"expression": "neutral"
				},
				{
					"who": "merchant",
					"text": "‘我卖的东西要经得住旅途，不是只在货架上好看。布琳娜帮我补木架，希尔薇娅帮我辨认材料。你缺什么，就直接告诉我。’",
					"expression": "neutral"
				},
				{
					"who": "",
					"text": "她将行囊摆正："
				},
				{
					"who": "merchant",
					"text": "‘账本我会记清楚，回来的位置也会留好。下一次见面，希望你有新的故事。’",
					"expression": "neutral"
				}
			]
		}
	],
	"tavern": [
		{
			"id": "meeting",
			"title": "杯中的灯火",
			"gain": 2,
			"min": 0,
			"require": "",
			"lines": [
				{
					"who": "",
					"text": "温阮将茶杯推到灯下，没有催你开口。杯沿的热气慢慢散开。"
				},
				{
					"who": "tavern",
					"text": "‘艾莉娅会替我把药草挑好，闻铃会吹一点不那么吵的曲子。你若今天不想谈冒险，也可以只坐一会儿。’",
					"expression": "neutral"
				},
				{
					"who": "",
					"text": "她温柔地笑了笑："
				},
				{
					"who": "tavern",
					"text": "‘这里不只留给勇敢的人。疲惫的时候，也记得回来。’",
					"expression": "neutral"
				}
			]
		}
	],
	"sylphiette": [
		{
			"id": "meeting",
			"title": "先让自己坐下",
			"min": 0,
			"gain": 3,
			"require": "",
			"lines": [
				{
					"who": "",
					"text": "你找到希露媞雅时，她正把桌上的杯子挨个转向同一个方向，方便别人伸手就能拿到。她自己的那杯茶却早已凉了。你搬来另一张椅子，她才意识到自己又忙过了头，指尖还停在杯柄上，神情有一点被当场抓住的不好意思。"
				},
				{
					"who": "sylphiette",
					"text": "你累不累？这里的椅子……啊，你是来找我的。",
					"expression": "neutral"
				},
				{
					"who": "契约者",
					"text": "嗯。先坐下，你已经绕着桌子忙三圈了。",
					"expression": "neutral"
				},
				{
					"who": "sylphiette",
					"text": "三圈？我都没注意。谢谢，我好像一直习惯先问别人。",
					"expression": "happy"
				},
				{
					"who": "",
					"text": "她捧起杯子，又看了一眼你的黑斗篷。"
				},
				{
					"who": "sylphiette",
					"text": "我记得名字，也会祈祷。可以前和谁住在一起，怎么都想不起来。见到你时又觉得……不该这么陌生。",
					"expression": "thoughtful"
				},
				{
					"who": "契约者",
					"text": "我也一样。暂时当作重新认识，好吗？",
					"expression": "neutral"
				},
				{
					"who": "sylphiette",
					"text": "好。那我先记住今天：有人会提醒我坐下喝水。",
					"expression": "happy"
				}
			]
		},
		{
			"id": "promise",
			"title": "半块甜饼",
			"min": 20,
			"gain": 4,
			"require": "extraction",
			"lines": [
				{
					"who": "",
					"text": "她在灯边摊开绷带，想把路上用剩的每一截都整理清楚。你提醒现在可以休息，她先下意识点头，过了一会儿才真的把东西放下。两人一时都没说话，桌面上那点安静没有让她难堪，反而让肩膀慢慢松了下来。"
				},
				{
					"who": "sylphiette",
					"text": "我刚才想说，边上焦一点的留给你。可我怎么知道你爱不爱吃？",
					"expression": "surprised"
				},
				{
					"who": "契约者",
					"text": "我脑子里也闪过一张小木桌。窗子漏雨，你把盘子往里挪。",
					"expression": "thoughtful"
				},
				{
					"who": "sylphiette",
					"text": "我记得有人披着黑斗篷，在桌对面笑。看不见脸……但那个人应该是你。",
					"expression": "thoughtful"
				},
				{
					"who": "",
					"text": "你们把分别记得的细节写在同一页，空白处没有补猜测。"
				},
				{
					"who": "sylphiette",
					"text": "先别急着认定。下次再想起来，我们就多核对一点。现在……要哪一半？",
					"expression": "happy"
				}
			],
			"previous": "meeting"
		},
		{
			"id": "memory",
			"title": "那场没下完的雨",
			"min": 50,
			"gain": 5,
			"require": "",
			"lines": [
				{
					"who": "",
					"text": "那枚旧云纹放在桌子中央，你们各拿一张纸，先写下自己记得的细节。希露媞雅没有抢着把空白填满。她偶尔停下来，看一眼你手里的笔，像终于允许一件重要的事不必今晚就全部做好。茶还热着，今天有足够的时间把话慢慢说完。"
				},
				{
					"who": "sylphiette",
					"text": "那天我们在旧驿站躲雨。希希芙带着小灵，伊露雅嫌屋里闷，坐在门边。我们四个都在。",
					"expression": "thoughtful"
				},
				{
					"who": "契约者",
					"text": "你一边替别人看伤，一边说自己不冷。结果拿杯子时，手都在抖。",
					"expression": "neutral"
				},
				{
					"who": "sylphiette",
					"text": "然后你把干毯子塞给我。还说，先把自己裹好，不然明天就多一个病人。",
					"expression": "happy"
				},
				{
					"who": "",
					"text": "她笑了。你记得递出毯子的动作，她记得接过时的温度；这是能够互相核对的一件往事。"
				},
				{
					"who": "sylphiette",
					"text": "原来你以前就会这样念我。挺好……这次也继续吧。",
					"expression": "happy"
				}
			],
			"previous": "promise"
		},
		{
			"id": "close",
			"title": "这次想留下的时间",
			"min": 100,
			"gain": 5,
			"require": "",
			"lines": [
				{
					"who": "",
					"text": "她提前给自己留了一个座位，这件小事比一番长祷还让你意外。往常她总在别人坐好后才想起自己，今天却先把茶杯摆到你旁边。她开口时仍有些斟酌，但这次问的不是还缺什么物资，而是你愿不愿意把一点时间留给她。"
				},
				{
					"who": "sylphiette",
					"text": "我还想起一点。那次休息后，我又想去照看门外的人，你叫伊露雅替一会儿，自己留着陪我。",
					"expression": "thoughtful"
				},
				{
					"who": "sylphiette",
					"text": "以前我总怕一停下来就误事。现在才知道，别人也能帮忙，我不必一直撑着。",
					"expression": "neutral"
				},
				{
					"who": "契约者",
					"text": "那今天想做什么？",
					"expression": "neutral"
				},
				{
					"who": "sylphiette",
					"text": "想和你待一会儿。不是为了问明天带什么，也不只是因为以前认识。我喜欢现在这样说话。你呢？",
					"expression": "happy"
				},
				{
					"who": "sylphiette",
					"text": "如果不是请你帮忙，只是我想和你更亲近一些，你愿意吗？还是说，你更希望我们一直做朋友？",
					"expression": "happy"
				}
			],
			"previous": "memory",
			"choices": [
				{
					"text": "我愿意与你更靠近一些。",
					"relation": "mutual_interest",
					"reply": [
						{
							"who": "sylphiette",
							"text": "我也想慢慢走近你。那明天的茶，我可以来找你一起喝吗？",
							"expression": "happy"
						}
					]
				},
				{
					"text": "我愿意以朋友的身份陪你。",
					"relation": "friendship",
					"reply": [
						{
							"who": "sylphiette",
							"text": "好，朋友也很重要。那明天照样一起喝茶，别因为说清楚了反而躲我。",
							"expression": "happy"
						}
					]
				}
			]
		},
		{
			"id": "romance",
			"title": "今晚不用守灯",
			"min": 200,
			"gain": 5,
			"require": "",
			"lines": [
				{
					"who": "",
					"text": "酒馆有人接过值守，希露媞雅确认一次便坐下了，没有再找借口起来巡视。你能看见她指尖轻轻挪动杯沿。她不是忘了想说什么，只是在认真挑一个属于自己的开头。今晚桌边没有需要她证明的功劳，也没有必须替过去履行的承诺。"
				},
				{
					"who": "sylphiette",
					"text": "刚才我问了大家，我们以前有没有在交往。她们说，谁也没想起过这种事。",
					"expression": "thoughtful"
				},
				{
					"who": "sylphiette",
					"text": "所以我想把话说清楚。我喜欢你，是因为这段时间和你在一起，我很开心。不需要找一份旧承诺作证明。",
					"expression": "happy"
				},
				{
					"who": "",
					"text": "她把手放在你伸手可及的桌边，等你回答。你可以接受、暂缓，或者认真回应她的友情。"
				},
				{
					"who": "sylphiette",
					"text": "我喜欢现在和你在一起的日子。不用急着回答；如果你也喜欢这样的相处，愿意和我试着交往吗？",
					"expression": "happy"
				}
			],
			"previous": "close",
			"choices": [
				{
					"text": "我愿意，与你一起确认这段关系。",
					"relation": "romance",
					"reply": [
						{
							"who": "sylphiette",
							"text": "嗯，我很愿意。从今天起，我们是在交往了。今晚就坐在这里陪我一会儿吧。",
							"expression": "happy"
						}
					]
				},
				{
					"text": "让我再想一想。",
					"defer": true,
					"reply": [
						{
							"who": "sylphiette",
							"text": "好，不用急着回答。我说清楚心意以后，反而没那么紧张了。",
							"expression": "neutral"
						}
					]
				},
				{
					"text": "我更珍惜我们现在的友情。",
					"relation": "friendship",
					"reply": [
						{
							"who": "sylphiette",
							"text": "好，朋友也很重要。那明天照样一起喝茶，别因为说清楚了反而躲我。",
							"expression": "happy"
						}
					]
				}
			]
		},
		{
			"id": "memory_recap_v12",
			"title": "重新核对：我们记得的过去",
			"min": 50,
			"gain": 0,
			"require": "",
			"previous": "memory",
			"lines": [
				{
					"who": "",
					"text": "你们把已经核对的旧片段另放一页。没有想起的部分依然留白，今天的经历则按日期继续记。"
				},
				{
					"who": "sylphiette",
					"text": "能确定的是，我们以前就一起走过一段路。旧驿站、躲雨和互相照顾的细节，可以慢慢核对。记不起的不用勉强。",
					"expression": "neutral"
				},
				{
					"who": "契约者",
					"text": "旧事帮我们了解彼此。现在是什么关系，还是按我们现在的选择来。",
					"expression": "neutral"
				}
			]
		},
		{
			"id": "memory_flower",
			"title": "花与那张画",
			"gain": 4,
			"min": 50,
			"require": "",
			"previous": "memory",
			"gift": true,
			"lines": [
				{
					"who": "",
					"text": "你把真正带回来的记忆花放在旧驿站的画旁。那些共同往事已经被你们核对过，不需要靠这朵花来证明。"
				},
				{
					"who": "sylphiette",
					"text": "原来它长这样。我很喜欢，也喜欢你那天陪我把画补完。",
					"expression": "happy"
				},
				{
					"who": "",
					"text": "她把花收在祭袍系带内侧，又小心合好画笺。"
				},
				{
					"who": "sylphiette",
					"text": "这次就不转送给别人了。谢谢你专门给我留着。",
					"expression": "happy"
				}
			]
		}
	],
	"iris": [
		{
			"id": "meeting",
			"title": "先把情况说清楚",
			"gain": 3,
			"min": 0,
			"require": "",
			"lines": [
				{
					"who": "iris",
					"text": "这里叫星辉回廊，是现在能休息和回来的据点。我叫伊莉丝，负责照看归航灯。",
					"expression": "neutral"
				},
				{
					"who": "契约者",
					"text": "我们四个为什么都想不起从前？",
					"expression": "thoughtful"
				},
				{
					"who": "iris",
					"text": "我还不知道原因。我找到你们时，你们都记得名字、本领和常识，却说不清以前的生活。我也不能把缺的经历直接还给你们。",
					"expression": "sad"
				},
				{
					"who": "iris",
					"text": "先从苏醒林地的旧路标查起。那里有与你们旧物相似的标记。把见闻带回来，一起核对，比相信一句熟悉的声音可靠。",
					"expression": "thoughtful"
				},
				{
					"who": "iris",
					"text": "你留在这里准备物资和整理记录，三位伙伴亲自调查。我能循归航联系接人，但找不回死亡时掉在外面的物资。",
					"expression": "neutral"
				}
			]
		},
		{
			"id": "return",
			"title": "等人回来也会紧张",
			"gain": 4,
			"min": 20,
			"require": "extraction",
			"lines": [
				{
					"who": "",
					"text": "撤离完成，伊莉丝才松开一直握着的灯柄。"
				},
				{
					"who": "契约者",
					"text": "原来你也会紧张。我还以为女神什么都知道。",
					"expression": "neutral"
				},
				{
					"who": "iris",
					"text": "别人这样叫我，不等于我什么都能做到。归航联系一弱，我也得等。",
					"expression": "neutral"
				},
				{
					"who": "契约者",
					"text": "那这杯茶给你。我给她们留了，差点忘了你。",
					"expression": "neutral"
				},
				{
					"who": "iris",
					"text": "现在还热。谢谢，下次也给我留一杯吧。",
					"expression": "happy"
				}
			]
		},
		{
			"id": "truth",
			"title": "同一种符号不等于答案",
			"gain": 5,
			"min": 50,
			"require": "deep",
			"lines": [
				{
					"who": "",
					"text": "你把林地带回的编号与星城旧信标图放在一起。伊莉丝指出两个相同的接口标记。"
				},
				{
					"who": "iris",
					"text": "信标就是让撤离队认路、传消息的装置。我参与建过其中一些，但没有建过所有装置。",
					"expression": "thoughtful"
				},
				{
					"who": "iris",
					"text": "现在能确认有记录被拼接、停止条件被删掉。是谁改的、改动怎样传到其他地方，还没有足够证据。",
					"expression": "neutral"
				},
				{
					"who": "契约者",
					"text": "那我们失去的记忆，也可能混在这些记录里？",
					"expression": "thoughtful"
				},
				{
					"who": "iris",
					"text": "可能，但同样要核对。记忆里的人亲口说出的细节，比一段重复的回放可靠。别为了赶快想起来就接受它要求的代价。",
					"expression": "neutral"
				}
			]
		},
		{
			"id": "close",
			"title": "也给守灯人留个位置",
			"gain": 4,
			"min": 100,
			"require": "echo",
			"lines": [
				{
					"who": "",
					"text": "夜里没有新归航。你把另一把椅子搬到灯坛边，伊莉丝终于坐了下来。"
				},
				{
					"who": "iris",
					"text": "我有时候也想离开灯边，去看看大家说的地方。现在还做不到，不过不是永远不能。",
					"expression": "neutral"
				},
				{
					"who": "契约者",
					"text": "那等能交班的时候，一起去。先从酒馆开始也行。",
					"expression": "neutral"
				},
				{
					"who": "iris",
					"text": "这个目标倒很具体。好，明天没有归航时，你来叫我。别又只问灯油够不够。",
					"expression": "happy"
				}
			]
		}
	],
	"ilyua": [
		{
			"id": "meeting",
			"title": "窗边没有风",
			"min": 0,
			"gain": 3,
			"require": "",
			"lines": [
				{
					"who": "",
					"text": "伊露雅坐在靠窗的位置，把短弓横放在腿边，给桌面留出足够的地方。你端来水，她先说不用准备太多，又在你放下杯子时接得很稳。窗外没什么风，她仍偶尔向那边看一眼，直到发现你没有急着问故乡在哪里，才肯把兜帽稍稍放松。"
				},
				{
					"who": "ilyua",
					"text": "坐吧。站在那里挡光，我都看不清弦了。",
					"expression": "neutral"
				},
				{
					"who": "契约者",
					"text": "你在看外面的路？",
					"expression": "neutral"
				},
				{
					"who": "ilyua",
					"text": "也在看这扇窗为什么一点风都不进。别笑，我记得怎么认风向，却想不起自己以前住哪片林子。",
					"expression": "thoughtful"
				},
				{
					"who": "",
					"text": "她看向你的黑斗篷，停了半拍。"
				},
				{
					"who": "ilyua",
					"text": "我好像见过你。不是刚才，是很久以前。想不起来就先算了，今天重新认识也行。伊露雅，叫名字就好。",
					"expression": "neutral"
				}
			]
		},
		{
			"id": "promise",
			"title": "树上的两道刻痕",
			"min": 20,
			"gain": 4,
			"require": "extraction",
			"lines": [
				{
					"who": "",
					"text": "那枚种子被伊露雅装在很普通的小纸包里，外面只画了一片叶子。她把它推过来，又补了一句不要天天挖开看有没有长根。你答应以后，她的手仍在纸包旁停了片刻。这不像交给你一件必须守住的任务，更像第一次试着把某件小事放心留在别人这里。"
				},
				{
					"who": "ilyua",
					"text": "你怎么知道这里要刻两道？",
					"expression": "surprised"
				},
				{
					"who": "契约者",
					"text": "等人的记号。我记得站在树下，鞋子灌了水。你回来时还笑了。",
					"expression": "thoughtful"
				},
				{
					"who": "ilyua",
					"text": "因为你没认错树，鞋倒先陷进泥里了。我记得把你拉出来……只有这一小段。",
					"expression": "happy"
				},
				{
					"who": "",
					"text": "你们各自描述树旁的石头和坡度，三处细节吻合。她在纸边写下“待核对：林间旧路”。"
				},
				{
					"who": "ilyua",
					"text": "下次想起多少就说多少，不用替空白编故事。先把鞋烘干，我是说这次的。",
					"expression": "happy"
				}
			],
			"previous": "meeting"
		},
		{
			"id": "memory",
			"title": "岔路口等着的人",
			"min": 50,
			"gain": 5,
			"require": "forest_clue",
			"lines": [
				{
					"who": "",
					"text": "她用手指在桌边画出旧驿站门口的位置，你补上一张她没记住的凳子。两个细节没有一开始就对上，伊露雅也没因此转身走开。她重新比了比距离，问你当时是不是坐得太挤，语气里终于有了一点和熟人谈糗事的轻松。"
				},
				{
					"who": "ilyua",
					"text": "我们四个那时走过同一条林间路。我探路，你们留在岔口。有人把两道短线刻在树上，说会在这里等。",
					"expression": "thoughtful"
				},
				{
					"who": "契约者",
					"text": "是我。你带回一条更安全的小路，后来我们一起去驿站避雨。",
					"expression": "neutral"
				},
				{
					"who": "ilyua",
					"text": "对。不是我一个人逃难，也不是谁命令我回来。我们那时就是约好了一起走。",
					"expression": "neutral"
				},
				{
					"who": "",
					"text": "她在缺口旁绕了一圈新线，没有把旧痕磨掉。"
				},
				{
					"who": "ilyua",
					"text": "总算找回一件完整的事。今晚值得多加一道菜，你请？好吧，我也出一半。",
					"expression": "happy"
				}
			],
			"previous": "promise"
		},
		{
			"id": "close",
			"title": "下次还在窗边",
			"min": 100,
			"gain": 5,
			"require": "forest_clear",
			"lines": [
				{
					"who": "",
					"text": "伊露雅比约好的时间早来一点，却没有站在门口等你发现。她直接走到桌边，把两只杯子放好，才问今晚能不能一起坐会儿。你听得出她仍不习惯为这种愿望找措辞。她没有许诺从此不再远行，只是把今天想待在哪里说得很清楚。"
				},
				{
					"who": "ilyua",
					"text": "我还记起一件小事。探路回来后，我以为你会问为什么这么慢，你先问我吃了没有。",
					"expression": "thoughtful"
				},
				{
					"who": "契约者",
					"text": "现在也会问。你今天吃了吗？",
					"expression": "neutral"
				},
				{
					"who": "ilyua",
					"text": "吃了。所以这次别拿饭岔开话题。",
					"expression": "happy"
				},
				{
					"who": "ilyua",
					"text": "我以后还想去找故乡，也会有自己出门的时候。但回来以后，第一个想找你说话。这已经不只是认得旧路了。你怎么想？",
					"expression": "neutral"
				},
				{
					"who": "ilyua",
					"text": "我想把你当作比朋友更特别的人。你愿意吗？还是维持现在这样，对你更自在？",
					"expression": "happy"
				}
			],
			"previous": "memory",
			"choices": [
				{
					"text": "我愿意与你更靠近一些。",
					"relation": "mutual_interest",
					"reply": [
						{
							"who": "ilyua",
							"text": "好。我也是这个意思。下次别只问吃饭，记得约我散步。",
							"expression": "happy"
						}
					]
				},
				{
					"text": "我愿意以朋友的身份陪你。",
					"relation": "friendship",
					"reply": [
						{
							"who": "ilyua",
							"text": "知道了。那还是老位置，想聊路上的事时我会来找你。朋友也别想逃掉请饭。",
							"expression": "happy"
						}
					]
				}
			]
		},
		{
			"id": "romance",
			"title": "把约会写进地图",
			"min": 200,
			"gain": 5,
			"require": "",
			"lines": [
				{
					"who": "",
					"text": "窗边那盆新芽已经站直，伊露雅看过叶片，便把注意力转回你身上。她把弓放到不妨碍走动的位置，坐下时没有再用行程当开场。今天她要问的事，与什么时候去找下一条路无关，也不需要一段早已遗忘的恋情替她说服你。"
				},
				{
					"who": "ilyua",
					"text": "这一段以后有机会一起走。我想把它当约会，不是调查任务。",
					"expression": "happy"
				},
				{
					"who": "ilyua",
					"text": "以前一起赶过路，不代表我们以前谈过恋爱。我现在想和你交往，是这段日子认真想过的。",
					"expression": "neutral"
				},
				{
					"who": "ilyua",
					"text": "我不会因此不找故乡，也不会要求你放下自己的事。愿意的话，我们就从今天开始。",
					"expression": "happy"
				},
				{
					"who": "ilyua",
					"text": "我想和你交往，也想继续走自己的路。你愿意和现在的我试着在一起吗？",
					"expression": "happy"
				}
			],
			"previous": "close",
			"choices": [
				{
					"text": "我愿意，与你一起确认这段关系。",
					"relation": "romance",
					"reply": [
						{
							"who": "ilyua",
							"text": "那就说好了。先牵手，地图等会儿再看——你不会连这个也要等我提醒吧？",
							"expression": "happy"
						}
					]
				},
				{
					"text": "让我再想一想。",
					"defer": true,
					"reply": [
						{
							"who": "ilyua",
							"text": "行，想清楚再说。今天该浇水还是得浇，别光顾着紧张。",
							"expression": "neutral"
						}
					]
				},
				{
					"text": "我更珍惜我们现在的友情。",
					"relation": "friendship",
					"reply": [
						{
							"who": "ilyua",
							"text": "知道了。那还是老位置，想聊路上的事时我会来找你。朋友也别想逃掉请饭。",
							"expression": "happy"
						}
					]
				}
			]
		},
		{
			"id": "memory_recap_v12",
			"title": "重新核对：我们记得的过去",
			"min": 50,
			"gain": 0,
			"require": "",
			"previous": "memory",
			"lines": [
				{
					"who": "",
					"text": "你们把已经核对的旧片段另放一页。没有想起的部分依然留白，今天的经历则按日期继续记。"
				},
				{
					"who": "ilyua",
					"text": "以前一起走过路，不代表现在要照旧过一遍。先把能核对的地点记清楚，剩下的继续调查。",
					"expression": "neutral"
				},
				{
					"who": "契约者",
					"text": "旧事帮我们了解彼此。现在是什么关系，还是按我们现在的选择来。",
					"expression": "neutral"
				}
			]
		}
	],
	"xixifu": [
		{
			"id": "meeting",
			"title": "三下以后再敲门",
			"min": 0,
			"gain": 3,
			"require": "",
			"lines": [
				{
					"who": "",
					"text": "小灵在桌边敲了三下，最后一下稍重，把杯垫震歪了。希希芙本来想把它藏到身后，看见你搬来一张矮凳，又替它认真摆好。她把杯垫扶正了两次才抬头，显然练过的介绍词被这点小意外打乱了；不过这次，她没有让你一直猜眼前的伙伴是什么。"
				},
				{
					"who": "",
					"text": "小灵是希希芙自愿同行的骸灵伙伴，借魔力维持这副小骷髅身体，用敲击、点头和手势表达意见。它会自己决定靠近谁，不是被她操控的尸体。幽灯则是另一位灵体伙伴，今天没有抢着替它介绍自己。"
				},
				{
					"who": "xixifu",
					"text": "这是小灵，不是坏骷髅。它想自己打招呼，所以……你先别怕？",
					"expression": "neutral"
				},
				{
					"who": "契约者",
					"text": "我在听。三下是它的名字吗？",
					"expression": "neutral"
				},
				{
					"who": "xixifu",
					"text": "是“我来了”。你居然会等它敲完，我还以为要解释很久。",
					"expression": "happy"
				},
				{
					"who": "xixifu",
					"text": "以前的事我记不清。召唤和契约倒还会，小灵也认得我。它刚才看你的样子，好像也认识你。",
					"expression": "thoughtful"
				},
				{
					"who": "",
					"text": "小灵又敲三下。希希芙在纸上记了一个问号。"
				},
				{
					"who": "xixifu",
					"text": "先留着问号吧。现在可以先交朋友，我叫希希芙。",
					"expression": "happy"
				}
			]
		},
		{
			"id": "promise",
			"title": "等伙伴回来吃饭",
			"min": 20,
			"gain": 4,
			"require": "extraction",
			"lines": [
				{
					"who": "",
					"text": "希希芙留了两碗热汤，自己却迟迟没碰。幽灯出去绕回廊，小灵替它守着空椅子，连有人经过也要认真抬头看一眼。你在桌边坐下，听她说起等待时脑子里冒出的各种糟糕猜测。那些想法听起来有点好笑，她讲的时候却真的担心过。"
				},
				{
					"who": "xixifu",
					"text": "它说去看看。我知道它会自己回来，可我还是总想往门口看。",
					"expression": "thoughtful"
				},
				{
					"who": "契约者",
					"text": "我好像也这样等过你。两碗汤，一把空椅子……还有一张写着“我去找小灵”的纸。",
					"expression": "thoughtful"
				},
				{
					"who": "xixifu",
					"text": "纸背画了一只很不像的小灵！那是我画的。你居然还记得。",
					"expression": "surprised"
				},
				{
					"who": "",
					"text": "你们各自画出纸条的样子，连歪掉的两只脚都对得上。"
				},
				{
					"who": "xixifu",
					"text": "那先吃吧。它们回来再添热汤。今天我可以一边等，一边和你说话。",
					"expression": "happy"
				}
			],
			"previous": "meeting"
		},
		{
			"id": "memory",
			"title": "袖口的蓝线",
			"min": 50,
			"gain": 5,
			"require": "forest_clue",
			"lines": [
				{
					"who": "",
					"text": "桌上的纸画着一只很难认出种类的小骷髅。希希芙坚持先说明这是她自己画的，免得你误会当年同行者真的长这样。笑过以后，你们才把旧驿站、雨声和找人的经过一点点拼起来。她记不起全部细节，却终于敢承认那天既着急，也怕给别人添麻烦。"
				},
				{
					"who": "xixifu",
					"text": "我记起来了。小灵那天掉进沟里，我急得忘了撑伞。是你和伊露雅把它拉上来的。",
					"expression": "thoughtful"
				},
				{
					"who": "契约者",
					"text": "你用这根线捆住它松掉的手腕。希露媞雅替你们擦水，你却先问我是不是被吓着了。",
					"expression": "neutral"
				},
				{
					"who": "xixifu",
					"text": "因为以前有人会怕它。可你说，先找齐零件，再吓也来得及。",
					"expression": "happy"
				},
				{
					"who": "",
					"text": "她忍不住笑出声，眼圈却有些发红。那次相遇的细节，你们终于能接起来了。"
				},
				{
					"who": "xixifu",
					"text": "原来我们以前就一起照顾过它。想起这个，比想起自己会多少法术都好。",
					"expression": "happy"
				}
			],
			"previous": "promise"
		},
		{
			"id": "close",
			"title": "明天来找你",
			"min": 100,
			"gain": 5,
			"require": "city_clue",
			"lines": [
				{
					"who": "",
					"text": "希希芙把写到一半的契约收进抽屉，改为在你旁边放了一只干净碗。小灵很识趣地带着幽灯去了另一张桌子，走到一半又回来拿走自己的杯垫。她看得差点笑出来，原本绷得紧紧的肩膀也松了些。接下来这句话，她想用自己的意思说，不靠纸上的条款壮胆。"
				},
				{
					"who": "xixifu",
					"text": "我想起那天为什么出去找小灵了。我怕你觉得它麻烦，想自己赶快解决，连招呼都没打好。",
					"expression": "thoughtful"
				},
				{
					"who": "契约者",
					"text": "你回来以后，我们一起吃了饭。没因为等久一点就吵架。",
					"expression": "neutral"
				},
				{
					"who": "xixifu",
					"text": "嗯。以前的我真会瞎担心……现在偶尔也会。但我想来找你，不只是因为怕被忘掉。",
					"expression": "neutral"
				},
				{
					"who": "xixifu",
					"text": "和你说话很开心。明天也想见你。如果你愿意，我想比朋友再近一点。",
					"expression": "happy"
				},
				{
					"who": "xixifu",
					"text": "我想比朋友再靠近一点。你也是这样想的吗？如果你想保持朋友的距离，也愿意亲口告诉我吗？",
					"expression": "happy"
				}
			],
			"previous": "memory",
			"choices": [
				{
					"text": "我愿意与你更靠近一些。",
					"relation": "mutual_interest",
					"reply": [
						{
							"who": "xixifu",
							"text": "那我记下明天的饭。不是契约，是我很期待见到你。",
							"expression": "happy"
						}
					]
				},
				{
					"text": "我愿意以朋友的身份陪你。",
					"relation": "friendship",
					"reply": [
						{
							"who": "xixifu",
							"text": "好。我会有一点不好意思，不过不会躲你的。明天一起吃饭，朋友也算数。",
							"expression": "happy"
						}
					]
				}
			]
		},
		{
			"id": "romance",
			"title": "不用写进契约",
			"min": 200,
			"gain": 5,
			"require": "",
			"lines": [
				{
					"who": "",
					"text": "小灵和幽灯在另一桌研究怎样把杯垫叠得更高。希希芙确认它们没有挡住过道，才把椅子往你这里挪了一点。她今天没有带契约纸，手指只抓着衣袖。你等她开口，没替她把准备好的话说完；她已经愿意来问，就值得有这么一点从容的时间。"
				},
				{
					"who": "xixifu",
					"text": "我们以前认识，这件事已经核对过了。至于以前是不是恋人……没有那样的记忆，我也不想编一个。",
					"expression": "thoughtful"
				},
				{
					"who": "xixifu",
					"text": "我现在喜欢你。会想约你吃饭，会在想起好笑的事时先找你，也想试着牵你的手。",
					"expression": "happy"
				},
				{
					"who": "xixifu",
					"text": "你愿意和我交往吗？今天认真问一次就好，不用每天重新签字。",
					"expression": "happy"
				},
				{
					"who": "xixifu",
					"text": "不用找回以前的约定，也不用急着答应。我想认真问一次：你愿意和现在的我交往吗？",
					"expression": "happy"
				}
			],
			"previous": "close",
			"choices": [
				{
					"text": "我愿意，与你一起确认这段关系。",
					"relation": "romance",
					"reply": [
						{
							"who": "xixifu",
							"text": "真的？那……我可以牵手了吧？我刚才练习得很镇定，现在好像白练了。",
							"expression": "happy"
						}
					]
				},
				{
					"text": "让我再想一想。",
					"defer": true,
					"reply": [
						{
							"who": "xixifu",
							"text": "好。想清楚再说，我先去救一下那些被小灵叠起来的杯垫。",
							"expression": "neutral"
						}
					]
				},
				{
					"text": "我更珍惜我们现在的友情。",
					"relation": "friendship",
					"reply": [
						{
							"who": "xixifu",
							"text": "好。我会有一点不好意思，不过不会躲你的。明天一起吃饭，朋友也算数。",
							"expression": "happy"
						}
					]
				}
			]
		},
		{
			"id": "memory_recap_v12",
			"title": "重新核对：我们记得的过去",
			"min": 50,
			"gain": 0,
			"require": "",
			"previous": "memory",
			"lines": [
				{
					"who": "",
					"text": "你们把已经核对的旧片段另放一页。没有想起的部分依然留白，今天的经历则按日期继续记。"
				},
				{
					"who": "xixifu",
					"text": "我们以前认识，也一起照顾过伙伴。至于当时还有哪些事，先别拿一小段录音猜完，咱们慢慢找。",
					"expression": "neutral"
				},
				{
					"who": "契约者",
					"text": "旧事帮我们了解彼此。现在是什么关系，还是按我们现在的选择来。",
					"expression": "neutral"
				}
			]
		}
	]
}

## Explicit speakers belong to the authored scene. Legacy prose remains narration.
static func dialogue_lines(value: Variant) -> Array:
	var result: Array = []
	var entries: Array = value if value is Array else [value]
	for entry in entries:
		if entry is Dictionary:
			var line: Dictionary = entry.duplicate(true)
			line["who"] = str(line.get("who", ""))
			line["text"] = str(line.get("text", ""))
			result.append(line)
		else:
			result.append({"who":"", "text":str(entry)})
	return result

static func available(npc: String, scene: Dictionary) -> bool:
	if bool(scene.get("daily",false)):
		if int(Outpost.data.get("conversation_days",{}).get(npc,-1))==BondRules.day_key(BondRules.now()):return false
	elif Outpost.data.events.has(npc+":"+str(scene.id)): return false
	if int(Outpost.data.bonds.get(npc,0)) < int(scene.min): return false
	if bool(scene.get("gift",false)) and int(Outpost.data.inventory.get("memory_gift",0))<=0:return false
	var previous := str(scene.get("previous",""))
	if not previous.is_empty() and not Outpost.data.events.has(npc+":"+previous): return false
	var required := str(scene.get("require",""))
	if required == "extraction" and Outpost.data.best.is_empty(): return false
	if required == "forest_clue" and not (StoryState.seen(&"cp_10",StringName(npc)) or Outpost.data.contracts.has("survey")): return false
	if required == "forest_clear" and not bool(StoryState.get_flag(&"forest_cleared",false)): return false
	if required == "city_clue" and not (StoryState.seen(&"city_clue_2",StringName(npc)) or bool(StoryState.get_flag(&"city_cleared",false))): return false
	if required not in ["","extraction","forest_clue","forest_clear","city_clue"] and not Outpost.data.contracts.has(required): return false
	return true

static func relationship(npc: String) -> String:
	return str(Outpost.data.get("relationships",{}).get(npc,"friendship"))

static func daily_event(npc:String)->Dictionary:
	var talks:Dictionary={
	"sylphiette": [
		{
			"who": "",
			"text": "希露媞雅给自己也倒了一杯茶。"
		},
		{
			"who": "sylphiette",
			"text": "今天我先休息过了，才去帮忙。你看，不用每次都提醒。",
			"expression": "happy"
		},
		{
			"who": "契约者",
			"text": "那我今天只负责把饼干递过去。",
			"expression": "neutral"
		},
		{
			"who": "sylphiette",
			"text": "可以。记得留两块，等她们回来。",
			"expression": "happy"
		}
	],
	"xixifu": [
		{
			"who": "xixifu",
			"text": "小灵学会把杯垫叠起来了。十次里面，有一次不会倒。",
			"expression": "happy"
		},
		{
			"who": "契约者",
			"text": "另外九次呢？",
			"expression": "neutral"
		},
		{
			"who": "xixifu",
			"text": "它说那是重新开始的机会。我觉得它在找借口，但先给它留着面子吧。",
			"expression": "happy"
		}
	],
	"ilyua": [
		{
			"who": "ilyua",
			"text": "新叶长出来了。你昨天浇的水正好，今天不用加。",
			"expression": "happy"
		},
		{
			"who": "契约者",
			"text": "我还怕给多了。",
			"expression": "neutral"
		},
		{
			"who": "ilyua",
			"text": "怕就来问。养花不是考试，错一次也不会不让你看它。走，出去透口气。",
			"expression": "happy"
		}
	]
}
	if not talks.has(npc):return {}
	return {"id":"daily_conversation","title":"灯下闲谈","min":0,"gain":4,"require":"","daily":true,"lines":talks[npc]}

static func invitation_event(npc:String)->Dictionary:
	# Old close events remain seen; never guess that their old affection meant love.
	if not EVENTS.has(npc) or npc not in ["sylphiette","xixifu","ilyua"]:return {}
	if not Outpost.data.events.has(npc+":close") or Outpost.data.get("relationships",{}).has(npc):return {}
	for event:Dictionary in EVENTS[npc]:
		if str(event.id)!="close":continue
		var result:=event.duplicate(true);result.id="invitation";result.title="重新询问的心意";result.previous="close";result.require=""
		result.lines=[{"who":"","text":"你们曾谈过亲近，却没有明确关系。今天她再次来问你的想法；过去是否熟识，都不会替今天的选择作答。"},{"who":npc,"text":"我想认真问问，我们现在是什么关系？不急，你可以把自己的想法说清楚。","expression":"neutral"}]
		return result
	return {}

static func can_romance(npc: String) -> bool:
	if relationship(npc) != "mutual_interest": return false
	for other in Outpost.data.get("relationships",{}):
		if other != npc and str(Outpost.data.relationships[other]) == "romance": return false
	return true

# Cosmetic chapter memories reuse the existing Iris conversation and event record.
const RETURN_MEMORIES:={
	"sylphiette": {
		"awakening_woods": {
			"title": "林尽仍有晨光",
			"lines": [
				{
					"who": "",
					"text": "成功撤离后，你们把晶片编号与林地地图放在同一张桌上。这些实际带回的记录可留在回廊继续核对。"
				},
				{
					"who": "iris",
					"text": "编号指向失名星城。下一步去那里查登记原件，林地的抄录和旧话不能单独算证据。",
					"expression": "neutral"
				},
				{
					"who": "sylphiette",
					"text": "我还记下了岗亭窗形。看见它时想起那场雨，等我休息好，想和你再对一次。",
					"expression": "happy"
				},
				{
					"who": "契约者",
					"text": "好，今天先吃饭。线索明天还在，人已经平安回来了。",
					"expression": "neutral"
				}
			]
		},
		"chapter_2": {
			"title": "昨日之外的祈愿",
			"lines": [
				{
					"who": "",
					"text": "带回的离城许可上留着空白。你们在旁边另写了一页，只记录已经互相核对的记忆。"
				},
				{
					"who": "iris",
					"text": "星城的强制归档停了。以后再去，遇到的是残余记录，不是让居民重新受困。更远的航路还要调查，今天不急着替它起结论。",
					"expression": "neutral"
				},
				{
					"who": "sylphiette",
					"text": "我想找回以前的事，也想把今天记好。先写下我们一起吃晚饭这一条吧。",
					"expression": "happy"
				}
			]
		}
	},
	"xixifu": {
		"awakening_woods": {
			"title": "为告别留一盏灯",
			"lines": [
				{
					"who": "",
					"text": "成功撤离后，你们把晶片编号与林地地图放在同一张桌上。这些实际带回的记录可留在回廊继续核对。"
				},
				{
					"who": "iris",
					"text": "编号指向失名星城。下一步去那里查登记原件，林地的抄录和旧话不能单独算证据。",
					"expression": "neutral"
				},
				{
					"who": "xixifu",
					"text": "小灵看到那件旧披风也敲了三下。我把细节都写了，明天一起看，好不好？",
					"expression": "happy"
				},
				{
					"who": "契约者",
					"text": "好，今天先吃饭。线索明天还在，人已经平安回来了。",
					"expression": "neutral"
				}
			]
		},
		"chapter_2": {
			"title": "声音不再是契约",
			"lines": [
				{
					"who": "",
					"text": "带回的离城许可上留着空白。你们在旁边另写了一页，只记录已经互相核对的记忆。"
				},
				{
					"who": "iris",
					"text": "星城的强制归档停了。以后再去，遇到的是残余记录，不是让居民重新受困。更远的航路还要调查，今天不急着替它起结论。",
					"expression": "neutral"
				},
				{
					"who": "xixifu",
					"text": "记录能留下声音，可现在的约饭得我自己来问。你今晚有空吗？小灵它们也来。",
					"expression": "happy"
				}
			]
		}
	},
	"ilyua": {
		"awakening_woods": {
			"title": "归林之箭",
			"lines": [
				{
					"who": "",
					"text": "成功撤离后，你们把晶片编号与林地地图放在同一张桌上。这些实际带回的记录可留在回廊继续核对。"
				},
				{
					"who": "iris",
					"text": "编号指向失名星城。下一步去那里查登记原件，林地的抄录和旧话不能单独算证据。",
					"expression": "neutral"
				},
				{
					"who": "ilyua",
					"text": "旧路能走了。我画了两道短刻痕的位置，回头你看看，是不是也觉得眼熟。",
					"expression": "happy"
				},
				{
					"who": "契约者",
					"text": "好，今天先吃饭。线索明天还在，人已经平安回来了。",
					"expression": "neutral"
				}
			]
		},
		"chapter_2": {
			"title": "不在名册中的新芽",
			"lines": [
				{
					"who": "",
					"text": "带回的离城许可上留着空白。你们在旁边另写了一页，只记录已经互相核对的记忆。"
				},
				{
					"who": "iris",
					"text": "星城的强制归档停了。以后再去，遇到的是残余记录，不是让居民重新受困。更远的航路还要调查，今天不急着替它起结论。",
					"expression": "neutral"
				},
				{
					"who": "ilyua",
					"text": "旧的路线补上了，新的地方还没去过。等休息好了，我们再一起挑下一段路。",
					"expression": "happy"
				}
			]
		}
	}
}
static func memory_key(hero:String,chapter:String)->String:return "chapter_memory:"+hero+":"+chapter
static func memories()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for hero in RETURN_MEMORIES:
		for chapter in RETURN_MEMORIES[hero]:
			var row:Dictionary=RETURN_MEMORIES[hero][chapter].duplicate(true)
			row["id"]=memory_key(hero,chapter);row["hero"]=hero;row["chapter"]=chapter;row["gain"]=0
			row["unlocked"]=bool(Outpost.data.get("events",{}).get(row.id,false));result.append(row)
	return result
static func remember_clear(hero:String,chapter:String)->String:
	if not RETURN_MEMORIES.has(hero) or not RETURN_MEMORIES[hero].has(chapter):return ""
	var key:=memory_key(hero,chapter)
	if bool(Outpost.data.get("events",{}).get(key,false)):return ""
	if not Outpost.data.has("events"):Outpost.data.events={}
	Outpost.data.events[key]=true
	return str(RETURN_MEMORIES[hero][chapter].title)
static func next_memory(hero:String="")->String:
	var id:=str(Characters.current_id()) if hero.is_empty() else hero
	for chapter in [str(ChapterCatalog.FIRST),str(ChapterCatalog.NEXT)]:
		if RETURN_MEMORIES.has(id) and not bool(Outpost.data.get("events",{}).get(memory_key(id,chapter),false)):
			return "使用当前角色完成「%s」并成功撤离，可在伊莉丝处回看纪念对话「%s」。"%[ChapterCatalog.title(chapter),str(RETURN_MEMORIES[id][chapter].title)]
	return "当前角色两章纪念已收录；可继续尝试其他构筑、高难度通关或极限阶段。"
