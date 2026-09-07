class_name TemporaryStatsStop
extends NullEffect


func apply(player_index: int) -> void:
    var effect = RunData.get_player_effect(custom_key_hash ,player_index)
    if not effect is int:
        effect = 0

    effect += value
    RunData.get_player_effects(player_index)[custom_key_hash] = effect


func get_args(player_index: int) -> Array:
    var count = RunData.get_player_effect(custom_key_hash ,player_index)
    if not count is int:
        count = 0

    return [
        "[color=lime]%s[/color]" % value,
        "[color=lime]+%s[/color]" % count
    ]