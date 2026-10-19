extends Resource

export (String) var id = ""
export (PackedScene) var scene = null

export (float) var chance_per_wave = 0.2
# 每个 10 波区块至少排期次数；0 = 不保底
export (int) var min_per_block = 0

# 空数组 = 所有区域；否则按 ZoneData.name 匹配
export (Array, String) var zone_names = []

export (int) var min_wave = 1
export (int) var max_wave = 9999
export (int) var min_difficulty = 0
export (int) var max_difficulty = 9999

export (bool) var show_in_timeline = true
export (Texture) var icon = null
export (String) var icon_path = ""

export (bool) var once_per_run = false
export (int) var max_per_run = 0
export (int) var priority = 0
export (bool) var enabled = true
