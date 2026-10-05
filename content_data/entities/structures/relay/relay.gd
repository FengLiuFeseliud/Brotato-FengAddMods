class_name Relay
extends Structure


# 区域光环配色：青绿色
const AREA_COLOR: = Color(0.35, 1.0, 0.85)
# 区域半透明度
const AREA_ALPHA: = 0.22
# 光环贴图半径（aura_effect.png 为 250x250，半径 125）
const AURA_TEXTURE_RADIUS: = 125.0
# 兜底加成
const ATTACK_SPEED_PERCENT_DEFAULT: = 0

onready var _relay_shape: CollisionShape2D = $RelayArea / CollisionShape2D
onready var _aura: Sprite = $RelayArea / Aura
onready var _center_icon: Sprite = $RelayArea / CenterIcon

# 当前停留在区域内的构筑物
var _structures_in_area: Array = []
# 中继器给出的炮台攻速加成（%）
var _attack_speed_percent: int = ATTACK_SPEED_PERCENT_DEFAULT
# 本座中继器的区域半径
var _area_radius: int = 0


# 生成时刷新区域外观，并把加成规则算好
func set_data(data: Resource) -> void:
	.set_data(data)
	# 攻速加成与半径都从效果资源的 get_args 
	var effect_args: Array = _get_effect_args(data)
	_attack_speed_percent = int(effect_args[0]) if effect_args.size() >= 1 else ATTACK_SPEED_PERCENT_DEFAULT
	_area_radius = int(effect_args[3]) if effect_args.size() >= 4 else int(stats.max_range)
	apply_area_visual()

	# 被诅咒时的光效
	if is_cursed and not is_instance_valid(curse_particle_instance):
		curse_particle_instance = curse_particles.instance()
		add_child(curse_particle_instance)
		_apply_curse_outline()


# 取效果资源的数值
func _get_effect_args(data: Resource) -> Array:
	if data == null or not data.has_method("get_args"):
		return []

	return data.get_args(player_index)


func apply_area_visual() -> void:
	# 半透明区域
	_aura.modulate = Color(AREA_COLOR.r, AREA_COLOR.g, AREA_COLOR.b, AREA_ALPHA)

	var radius: float = float(_area_radius) if stats != null else 0.0
	if radius <= 0.0:
		return

	_relay_shape.shape.radius = radius
	var scale_factor: float = radius / AURA_TEXTURE_RADIUS
	_aura.scale = Vector2(scale_factor, scale_factor)


# 构筑物进入区域
func _on_RelayArea_body_entered(body: Node) -> void:
	if not body.has_method("fengliu_set_relay_attack_speed"):
		return

	if _structures_in_area.has(body):
		return

	_structures_in_area.append(body)
	if body.has_method("fengliu_set_relay_attack_speed"):
		body.fengliu_set_relay_attack_speed(self, _attack_speed_percent)


# 构筑物离开区域
func _on_RelayArea_body_exited(body: Node) -> void:
	if not _structures_in_area.has(body):
		return

	_structures_in_area.erase(body)
	if is_instance_valid(body) and body.has_method("fengliu_clear_relay_attack_speed"):
		body.fengliu_clear_relay_attack_speed(self)


# 持续在区域内
func _physics_process(_delta: float) -> void:
	var alive: = []
	for structure in _structures_in_area:
		if not is_instance_valid(structure) or structure.dead:
			continue
		alive.append(structure)

	_structures_in_area = alive


# 给中心图标套上诅咒紫色描边
func _apply_curse_outline() -> void:
	var mat: = ShaderMaterial.new()
	mat.shader = outline_material.shader
	mat.set_shader_param("texture_size", _center_icon.texture.get_size())
	mat.set_shader_param("width", 3.0)
	mat.set_shader_param("alpha", 1.0)
	mat.set_shader_param("desaturation", 0.0)
	mat.set_shader_param("outline_color_0", Utils.CURSE_COLOR)
	_center_icon.material = mat