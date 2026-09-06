class_name WeaponHitSlowEffect
extends NullEffect


export (int) var gain_value = 0


func get_args(player_index: int) -> Array:
    var slow_value = value + int(Utils.get_stat(key_hash, player_index) * (gain_value / 100.0))
    return [
        "[color=lime]%s[/color]" % slow_value,
        Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0)
    ]