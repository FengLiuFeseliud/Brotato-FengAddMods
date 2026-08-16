class_name WeaponKilledLoot
extends NullEffect


# wave_count

export (float) var gain_value = 0.0
export (float) var cap_value = 0.0


func get_args(_player_index: int) -> Array:

    var value_count = 0
    var text = ""

    if "wave_gain" == key:
        value_count = value + RunData.current_wave * gain_value
        if value_count > cap_value and cap_value > 0:
            value_count = cap_value
        text = "[color=lime]%s[/color]" % int(gain_value)
    else:
        text = Utils.get_scaling_stat_icon_text(key_hash, gain_value)

    return [
        str(value_count),
        text,
        str(cap_value)
    ]