class_name AdaptorSmgWeapon
extends RangedWeapon


func init_stats(at_wave_begin: bool = true) -> void :
    if RunData.fengliu_is_high_wave_intensity() or RunData.is_elite_wave(EliteType.ELITE) or RunData.is_elite_wave(EliteType.HORDE):
        stats.nb_projectiles = 3
        stats.projectile_spread = 0.32
    else:
        stats.nb_projectiles = 1
        stats.projectile_spread = 0.0
    .init_stats(at_wave_begin)