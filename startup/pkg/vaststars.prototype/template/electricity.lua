local entities = { {
    dir = "N",
    items = {},
    prototype_name = "指挥中心",
    recipe = "车辆装配",
    x = 126,
    y = 120
  }, {
    dir = "N",
    items = { { "收货车站", 2 }, { "送货车站", 2 }, { "水电站I", 2 }, { "熔炼炉I", 2 }, { "无人机仓库", 5 }, { "铁制电线杆", 10 } },
    prototype_name = "机身残骸",
    x = 107,
    y = 134
  }, {
    dir = "S",
    items = { { "无人机仓库", 4 }, { "采矿机I", 2 }, { "科研中心I", 1 }, { "组装机I", 4 } },
    prototype_name = "机尾残骸",
    x = 110,
    y = 120
  }, {
    dir = "S",
    items = { { "风力发电机I", 1 }, { "蓄电池I", 10 }, { "运输车框架", 4 }, { "太阳能板I", 6 }, { "锅炉I", 4 }, { "蒸汽发电机I", 8 } },
    prototype_name = "机翼残骸",
    x = 133,
    y = 122
  }, {
    dir = "W",
    items = { { "电解厂I", 1 }, { "地下水挖掘机", 4 }, { "化工厂I", 3 }, { "空气过滤器I", 4 } },
    prototype_name = "机头残骸",
    x = 125,
    y = 108
  }, {
    dir = "N",
    prototype_name = "太阳能板I",
    x = 114,
    y = 135
  }, {
    dir = "N",
    prototype_name = "太阳能板I",
    x = 118,
    y = 135
  }, {
    dir = "N",
    prototype_name = "铁制电线杆",
    x = 117,
    y = 136
  }, {
    dir = "N",
    prototype_name = "铁制电线杆",
    x = 117,
    y = 129
  }, {
    dir = "N",
    prototype_name = "采矿机I",
    recipe = "碎石挖掘",
    x = 113,
    y = 127
  }, {
    dir = "N",
    prototype_name = "铁制电线杆",
    x = 129,
    y = 136
  }, {
    dir = "N",
    prototype_name = "太阳能板I",
    x = 126,
    y = 135
  }, {
    dir = "N",
    fluids = {
      input = {},
      output = { "地下卤水" }
    },
    prototype_name = "地下水挖掘机",
    recipe = "离岸抽水",
    x = 130,
    y = 135
  }, {
    dir = "N",
    fluids = {
      input = { "地下卤水" },
      output = { "蒸汽" }
    },
    prototype_name = "锅炉I",
    recipe = "卤水沸腾",
    x = 133,
    y = 136
  }, {
    dir = "N",
    fluids = {
      input = { "蒸汽" },
      output = {}
    },
    prototype_name = "蒸汽发电机I",
    recipe = "蒸汽发电",
    x = 133,
    y = 138
  }, {
    dir = "N",
    fluids = {
      input = { "蒸汽" },
      output = {}
    },
    prototype_name = "蒸汽发电机I",
    recipe = "蒸汽发电",
    x = 133,
    y = 143
  }, {
    dir = "N",
    prototype_name = "铁制电线杆",
    x = 132,
    y = 142
  }, {
    dir = "N",
    prototype_name = "铁制电线杆",
    x = 160,
    y = 128
  }, {
    dir = "N",
    prototype_name = "采矿机I",
    recipe = "铁矿石挖掘",
    x = 162,
    y = 127
  }, {
    dir = "N",
    prototype_name = "铁制电线杆",
    x = 160,
    y = 135
  }, {
    dir = "N",
    prototype_name = "铁制电线杆",
    x = 160,
    y = 142
  }, {
    dir = "N",
    prototype_name = "太阳能板I",
    x = 159,
    y = 139
  }, {
    dir = "N",
    prototype_name = "太阳能板I",
    x = 156,
    y = 139
  }, {
    dir = "N",
    prototype_name = "太阳能板I",
    x = 162,
    y = 139
  }, {
    dir = "N",
    prototype_name = "蓄电池I",
    x = 156,
    y = 142
  }, {
    dir = "N",
    prototype_name = "蓄电池I",
    x = 158,
    y = 142
  }, {
    dir = "N",
    prototype_name = "蓄电池I",
    x = 161,
    y = 142
  }, {
    dir = "N",
    prototype_name = "蓄电池I",
    x = 163,
    y = 142
  }, {
    dir = "N",
    prototype_name = "无人机仓库",
    x = 160,
    y = 126
  }, {
    dir = "N",
    prototype_name = "无人机仓库",
    x = 158,
    y = 126
  }, {
    dir = "N",
    prototype_name = "无人机仓库",
    x = 156,
    y = 126
  }, {
    dir = "N",
    prototype_name = "无人机仓库",
    x = 116,
    y = 127
  }, {
    dir = "N",
    prototype_name = "无人机仓库",
    x = 118,
    y = 127
  }, {
    dir = "N",
    prototype_name = "无人机仓库",
    x = 120,
    y = 127
  }, {
    dir = "N",
    fluids = {
      input = {},
      output = { "地下卤水" }
    },
    prototype_name = "核子挖掘机",
    recipe = "离岸抽水",
    x = 130,
    y = 149
  }, {
    dir = "N",
    fluid = "地下卤水",
    prototype_name = "液罐I",
    x = 133,
    y = 149
  } }
local road = {}

local mineral = {
  ["136,172"] = "铁矿石",
  ["100,60"] = "铁矿石",
  ["162,127"] = "铁矿石",
  ["89,156"] = "铁矿石",
  ["60,183"] = "铁矿石",
  ["59,116"] = "铁矿石",
  ["73,91"] = "铁矿石",
  ["171,74"] = "铁矿石",
  ["194,115"] = "铁矿石",
  ["207,160"] = "铁矿石",
  ["178,191"] = "铁矿石",
  ["148,93"] = "铁矿石",
  ["168,110"] = "碎石",
  ["142,84"] = "碎石",
  ["113,127"] = "碎石",
  ["70,130"] = "碎石",
  ["91,100"] = "碎石",
  ["143,147"] = "碎石",
  ["190,130"] = "碎石",
}

return {
  name = "电网测试",
  entities = entities,
  road = road,
  mineral = mineral,
}
    