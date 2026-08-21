extends "res://entities/units/enemies/enemy.gd"


var effect_fengliu_wave_intensity_damage = Keys.generate_hash("fengliu_wave_intensity_damage")


func get_damage_value(dmg_value: int, from_player_index: int, armor_applied: = true, dodgeable: = true, is_crit: = false, hitbox: Hitbox = null, is_burning: = false) -> GetDamageValueResult:
    var damage_value = .get_damage_value(dmg_value, from_player_index, armor_applied, dodgeable, is_crit, hitbox, is_burning)

    for effect in RunData.get_player_effect(effect_fengliu_wave_intensity_damage, from_player_index):
        damage_value.value += int(RunData.fengliu_get_wave_total_hp_to_duration() * (effect[0] / 100.0))
    return damage_value