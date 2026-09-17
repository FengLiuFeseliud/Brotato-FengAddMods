class_name AdaptorSmgWeapon
extends RangedWeapon


func init_stats(at_wave_begin: bool = true) -> void :
    # 高质量/敌众/精英波次：三发散射；其余波次：单发直线
    if RunData.fengliu_is_high_wave_intensity() or RunData.is_elite_wave(EliteType.ELITE) or RunData.is_elite_wave(EliteType.HORDE):
        stats.nb_projectiles = 3
        stats.projectile_spread = 0.32
    else:
        stats.nb_projectiles = 1
        stats.projectile_spread = 0.0
    # 交由基类完成其余属性初始化
    .init_stats(at_wave_begin)