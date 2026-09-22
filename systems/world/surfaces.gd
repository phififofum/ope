class_name Surfaces
extends RefCounted

## Every surface in the shop, generated rather than imported.
##
## The documents were always drawn at runtime, and they are the part of this game that
## looks finished. This is the same trick applied to the room: wood grain, tile, plaster
## and glass come out of a hash function, so the shop has materials without anybody
## shipping a texture.
##
## Images are filled pixel by pixel rather than through [NoiseTexture2D], which generates
## on a worker thread and is therefore not ready when a headless screenshot is taken. A
## 128-pixel square costs a fraction of a frame and is identical on every machine, which
## is what the visual regression baseline needs.

const SIZE: int = 128

static var _cache: Dictionary = {}


## Value noise in [0, 1], deterministic for a given [param seed_value].
static func noise(x: float, y: float, seed_value: int) -> float:
	var x0: int = int(floor(x))
	var y0: int = int(floor(y))
	var fx: float = x - float(x0)
	var fy: float = y - float(y0)
	# Smoothstep the interpolation, or the grid shows through as a lattice of creases.
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var top: float = lerpf(_at(x0, y0, seed_value), _at(x0 + 1, y0, seed_value), fx)
	var bottom: float = lerpf(_at(x0, y0 + 1, seed_value), _at(x0 + 1, y0 + 1, seed_value), fx)
	return lerpf(top, bottom, fy)


## Several octaves of the above. Fewer than four and it reads as blur rather than grain.
static func fractal(x: float, y: float, seed_value: int, octaves: int = 4) -> float:
	var total: float = 0.0
	var amplitude: float = 1.0
	var scale: float = 1.0
	var sum: float = 0.0
	for octave: int in range(octaves):
		total += noise(x * scale, y * scale, seed_value + octave * 977) * amplitude
		sum += amplitude
		amplitude *= 0.5
		scale *= 2.0
	return total / maxf(0.0001, sum)


## Sawn timber: long grain along one axis, knots left out on purpose because a knot in a
## repeating texture is a knot you see four times in a row.
static func wood(tint: Color, seed_value: int = 11) -> Texture2D:
	return _build(
		"wood_%s_%d" % [tint.to_html(false), seed_value],
		func(u: float, v: float) -> Color:
			var grain: float = fractal(u * 3.0, v * 26.0, seed_value, 4)
			var rings: float = sin((v * 18.0 + grain * 3.4) * PI) * 0.5 + 0.5
			var shade: float = 0.82 + 0.18 * grain + 0.09 * rings
			return Color(tint.r * shade, tint.g * shade, tint.b * shade, 1.0)
	)


## Chequered vinyl, the floor of every corner shop. The grout line is drawn rather than
## noised so it stays crisp when the texture is tiled across a room.
static func tile(light: Color, dark: Color, seed_value: int = 23) -> Texture2D:
	return _build(
		"tile_%s_%s" % [light.to_html(false), dark.to_html(false)],
		func(u: float, v: float) -> Color:
			var cell_u: float = fmod(u * 4.0, 1.0)
			var cell_v: float = fmod(v * 4.0, 1.0)
			var checker: bool = (int(u * 4.0) + int(v * 4.0)) % 2 == 0
			var base: Color = light if checker else dark
			var wear: float = 0.9 + 0.12 * fractal(u * 9.0, v * 9.0, seed_value, 3)
			var grout: float = minf(minf(cell_u, 1.0 - cell_u), minf(cell_v, 1.0 - cell_v))
			if grout < 0.02:
				base = base.darkened(0.45)
			return Color(base.r * wear, base.g * wear, base.b * wear, 1.0)
	)


## Painted plaster: almost flat, with just enough variation that a large wall does not
## read as a solid fill.
static func plaster(tint: Color, seed_value: int = 41) -> Texture2D:
	return _build(
		"plaster_%s_%d" % [tint.to_html(false), seed_value],
		func(u: float, v: float) -> Color:
			var speckle: float = fractal(u * 16.0, v * 16.0, seed_value, 3)
			var shade: float = 0.94 + 0.08 * speckle
			return Color(tint.r * shade, tint.g * shade, tint.b * shade, 1.0)
	)


## Coarse weave for chairs and the notice board.
static func fabric(tint: Color, seed_value: int = 67) -> Texture2D:
	return _build(
		"fabric_%s_%d" % [tint.to_html(false), seed_value],
		func(u: float, v: float) -> Color:
			var warp: float = sin(u * SIZE * PI * 0.5) * 0.5 + 0.5
			var weft: float = sin(v * SIZE * PI * 0.5) * 0.5 + 0.5
			var shade: float = (
				0.86 + 0.16 * maxf(warp, weft) * fractal(u * 8.0, v * 8.0, seed_value, 2)
			)
			return Color(tint.r * shade, tint.g * shade, tint.b * shade, 1.0)
	)


## A lit, rough surface: the material a shelf's own strip light makes of the board above.
static func matte(tint: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	material.metallic = 0.0
	return material


static func textured(
	texture: Texture2D, scale: Vector3 = Vector3.ONE, roughness: float = 0.85
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.uv1_scale = scale
	material.roughness = roughness
	material.metallic = 0.0
	return material


## Shop glass: you can see the cards through it, and it catches the light.
static func glass(tint: Color = Color(0.72, 0.84, 0.86, 0.22)) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.05
	material.metallic = 0.1
	material.metallic_specular = 0.6
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Anything that is its own light source: a strip light, a sign, the glow inside the case.
static func glowing(tint: Color, strength: float = 1.6) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = strength
	material.roughness = 0.6
	return material


static func metal(tint: Color, roughness: float = 0.35) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.45
	material.roughness = roughness
	return material


static func _at(x: int, y: int, seed_value: int) -> float:
	var hashed: int = (x * 374761393 + y * 668265263 + seed_value * 1274126177) & 0x7FFFFFFF
	hashed = (hashed ^ (hashed >> 13)) * 1274126177
	return float((hashed ^ (hashed >> 16)) & 0xFFFF) / 65535.0


static func _build(key: String, shade: Callable) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			image.set_pixel(x, y, shade.call(float(x) / float(SIZE), float(y) / float(SIZE)))
	var texture: Texture2D = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture
