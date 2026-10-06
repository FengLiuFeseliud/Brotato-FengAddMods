extends "res://zones/backgrounds/background_data.gd"

# 「线条空间」的场地用「整张图」模式：把一整张场地图等比铺满整个场地（超出裁掉、居中），
# 不再像原版那样把贴图切成 3×4 共 12 格随机拼贴。关掉 fengliu_whole_image 即回到原版行为。

export (bool) var fengliu_whole_image = true

