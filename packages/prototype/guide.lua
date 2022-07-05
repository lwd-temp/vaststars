local guide = {
	{
        name = "guide-1",
		narrative = {
            {"哔哩..哔哗..已迫降在代号P4031的星球。星球未发现生命迹象..(失望)", "textures/guide/guide-1.texture"},
            {"哔哩..哔哗..启动大气分析协议中..缺少氧气..(失望)"},
            {"哔哩..哔哗..启动地质分析协议中..铁铝丰富..(轻松)"},
            {"哔哩..哔哗..启动生存可靠性分析..0.04565%存活概率..(情绪表达跳过中)"},
            {"博士，作为助理AI，我建议你立刻开始工作..哔哩..你的剩余生存时间理论上只有348.26地球小时..(担忧)", "textures/guide/guide-4.texture"},
            {"迫降并不算太糟糕，指挥中心结构完整。我们先清理周边残骸，兴许能找到一些有用的物资..(期待)", "textures/guide/guide-2.texture"},
        },
        narrative_end = {
            pop_chapter = {"序章","迫降P4031"},
            task = {
                "清除废墟",
            },
            visible_value = 5,
        },
        prerequisites = {},
	},

    {
        name = "guide-2",
		narrative = {
            {"看来我们捡到了不少有价值的破烂..哔哩..物资。科技就是第一生产力，让我们建造一所科研中心..(期待)", "textures/guide/guide-2.texture"},
        },
        narrative_end = {
            visible_value = 10,
            task = {
                "放置科研中心",
            }
        },
        prerequisites = {
            "清除废墟",
        },
	},

    {
        name = "guide-3",
		narrative = {
            {"哔哩..我们终于恢复了研究能力..哔哩..目前存活概率提升为0.07672%..(轻松)", "textures/guide/guide-1.texture"},
            {"哔哩..让我们点击“研究中心”按钮，开始研究第一个科技..(兴奋)", "textures/guide/guide-3.texture"},
        },
        narrative_end = {
            visible_value = 15,
            task = {
            }
        },
        prerequisites = {
            "放置科研中心",
        },
	},

    {
        name = "guide-4",
		narrative = {
            {"采集P4031地质样本制造科技包..哔哩..我们就能更好地研究星球地质结构。", "textures/guide/guide-2.texture"},
            {"P4031蕴含丰富的矿藏..哔哩..先用采矿机挖掘铁矿和石矿资源..(期待)", "textures/guide/guide-2.texture"},
        },
        narrative_end = {
            visible_value = 20,
            task = {
                "放置采矿机",
            }
        },
        prerequisites = {
            "地质研究",
        },
	},

    {
        name = "guide-5",
		narrative = {
            {"组装机可使用3D打印技术制造地质科技包..哔哩..哔哗..请求建造组装机..(期待)", "textures/guide/guide-2.texture"},
        },
        narrative_end = {
            visible_value = 20,
            task = {
                "放置组装机",
            }
        },
        prerequisites = {
            "挖掘铁矿石",
            "挖掘碎石矿",
        },
	},

    {
        name = "guide-6",
		narrative = {
            {"科研中心针对“科技包”可开展对应的研究..哔哩..将地质科技包运送科研中心进行下一个科技研究(期待)", "textures/guide/guide-2.texture"},
        },
        narrative_end = {
            visible_value = 20,
            task = {
                "铁矿熔炼",
            }
        },
        prerequisites = {
            "生产地质科技包",
        },
	},

}

return guide