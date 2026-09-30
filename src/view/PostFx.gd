class_name PostFx
extends CanvasLayer
## Постобработка кадра (виньетка, хроматическая аберрация, зерно, цветовой тон, вспышка урона).

var _rect: ColorRect
var _mat: ShaderMaterial
var _flash := 0.0


func _init() -> void:
	layer = 5
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = Assets.shader("res://assets/shaders/postfx.gdshader")
	_rect.material = _mat
	add_child(_rect)


func set_quality(q: int) -> void:
	_rect.visible = q >= 1
	_mat.set_shader_parameter("grain", [0.0, 0.03, 0.045, 0.055][clampi(q, 0, 3)])
	_mat.set_shader_parameter("aberration", [0.0, 0.0008, 0.0016, 0.0022][clampi(q, 0, 3)])


func flash(amount: float) -> void:
	_flash = minf(1.0, _flash + amount)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.5)
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)
