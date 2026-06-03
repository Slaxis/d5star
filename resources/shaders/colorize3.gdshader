// colorize3 — three-chroma-key colour swap + per-cell climate modulation
// for indexed tile sprites.
//
// The tile PNGs ship with exactly three RGB values inside the hex
// (black / mid-grey / white, plus alpha=0 outside). At render time
// this shader detects each chroma key and replaces it with whatever
// colour the caller has set for that role. So one B/W/Grey asset
// becomes any palette the engine asks for — terrain, faction, mood.
//
// On top of the swap, an optional climate pass tints the body per
// hex: each pixel of the `climate_map` texture encodes one cell's
// climate (R=temperature, G=humidity, B=elevation, all 0..1). The
// fragment looks up its cell from world coords and modulates the
// colour — cold/wet/high tiles look different from hot/dry/low ones
// without baking the climate into the PNGs.
//
// Adapted from the-scrap-warriors' colorize.gdshader (which adapted
// it from Caves of Qud's two-key variant) with a third chroma added
// for the maker's 3-tone indexed output.
shader_type canvas_item;

// Chroma keys to detect. Defaults match the maker's chroma palette
// (#000000 / #808080 / #ffffff). Override if you author tiles with
// a different convention.
uniform vec4 main_key : source_color = vec4(0.0,         0.0,         0.0,         1.0);
uniform vec4 mid_key  : source_color = vec4(0.50196078,  0.50196078,  0.50196078,  1.0);
uniform vec4 hi_key   : source_color = vec4(1.0,         1.0,         1.0,         1.0);

// Replacement colours injected by the caller — typically resolved
// from a TerrainDef's palette entry (main / mid / hi).
uniform vec4 main_color : source_color = vec4(1.0);
uniform vec4 mid_color  : source_color = vec4(1.0);
uniform vec4 hi_color   : source_color = vec4(1.0);

// Post-pass modifiers: a flat tint, optional desaturation, global
// alpha. Used by damage / mood overlays without having to touch the
// per-key colours.
uniform vec4  tint_color : source_color = vec4(1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate    : hint_range(0.0, 1.0) = 0.0;
uniform float alpha         : hint_range(0.0, 1.0) = 1.0;

// Squared-distance tolerance for chroma matching. The indexed PNG
// holds the keys pixel-exact, so a tiny tolerance is enough; bumping
// it lets the shader work on slightly noisy hand-painted sources.
uniform float tolerance : hint_range(0.0, 0.1) = 0.01;

// --- climate modulation ---------------------------------------------
//
// `climate_map` is a W×H texture, 1 pixel per hex cell, indexed in
// offset coords (offset_col, offset_row). Channels: R=temperature,
// G=humidity, B=elevation, all normalised 0..1. NEAREST filter so
// each cell's pixels read its exact value — no inter-cell blending.
//
// The fragment derives its cell from world coords using the same
// grid maths Godot's hex tilemap uses: column step = cell_step.x,
// row step = cell_step.y, odd columns shifted down by cell_stagger.
// `layout_origin` is the world coord of cell (0,0)'s centre — for
// the Sugar Loaf board, (52, 45) (= half a 104×90 tile).
//
// When `climate_strength = 0` the entire pass is skipped, so a layer
// rendered without climate hooked up looks exactly like it did
// before this shader grew the modulation.
uniform sampler2D climate_map : filter_nearest, repeat_disable;
uniform vec2  grid_size      = vec2(1.0, 1.0);
uniform vec2  cell_step      = vec2(78.0, 90.0);
uniform float cell_stagger   = 45.0;
uniform vec2  layout_origin  = vec2(52.0, 45.0);
uniform float climate_strength : hint_range(0.0, 1.0) = 0.0;
// Atlas layout — the `UV` Godot hands the fragment shader is the
// UV across the *whole* atlas texture (e.g. UV.x ∈ [0, 0.25] for
// variant 0 of a 1×4 strip), not [0, 1] per tile. We need the
// per-tile UV to recover the tile's centre from world coords, so
// expose the atlas grid dimensions and reverse the multiplication.
uniform float atlas_columns = 1.0;
uniform float atlas_rows    = 1.0;

// Temperature controls SATURATION, not hue: hottest cells get the
// terrain's full saturated colour; coldest cells fade toward grey
// keeping just a hint of chroma. `cold_desat` is the desaturation
// applied at the cold pole (1.0 = pure grey, 0.0 = no fade). The
// hot pole always lands at 0 desat, so a desert is the most
// vivid the palette gets to be.
uniform float cold_desat : hint_range(0.0, 1.0) = 0.67;

// Per-cell value (brightness) jitter — every hex picks a tiny,
// deterministic scalar multiplier off its (col, row) hash so a
// grass field becomes a mottle of slightly-different green
// *shades* (lighter / darker greens) instead of a flat block.
// Multiplying RGB by a scalar preserves hue *and* saturation, so
// the jitter never drifts a blue water hex toward green or a red
// lava hex toward magenta — it stays strictly in family. Kept
// very low (±2 %) so each biome reads as its own clear chroma
// rather than blending visually with similar neighbours.
uniform float value_jitter_max : hint_range(0.0, 0.5) = 0.02;

// Body jitter — a heavier per-cell variation applied OUTSIDE the
// climate path so the layer works without `climate_map` wired up
// (today only `solid_air` uses it: each cloud-hex picks its own
// brightness AND its own alpha, so adjacent bubbles read as
// slightly different puffs of vapour with subtle outlines where
// they touch).  Two independent hashes on the cell index drive
// brightness and alpha so they're decorrelated — a darker cloud
// isn't always also a more-transparent one. With
// `body_jitter_speed > 0` the per-cell hashes become phase offsets
// of a `sin(TIME * speed + phase)` oscillation — every cloud
// breathes on its own schedule, the apparent motion masks the
// static seam noise per-cell translucent tiles otherwise show.
uniform float body_jitter_amount : hint_range(0.0, 0.5) = 0.0;
uniform float body_jitter_speed  : hint_range(0.0, 5.0) = 0.0;

// Radial falloff — alpha multiplier that's 1.0 inside `inner` and
// linearly fades to 0 between `inner` and `outer` (measured from the
// tile centre in world units). Solid_air uses inscribed → circum-
// scribed so each cloud reads as a circle inscribed in its hex with
// a halo extending to the hex vertices — adjacent halos overlap and
// blend the hard hex grid into a continuous mass instead of a tiled
// pattern. Both 0 disables the gradient.
uniform float body_falloff_inner : hint_range(0.0, 256.0) = 0.0;
uniform float body_falloff_outer : hint_range(0.0, 256.0) = 0.0;

// --- water shimmer --------------------------------------------------
//
// Animated brightness ripple, ported from the-scrap-warriors'
// `colorize_water_legacy.gdshader`. Two sinusoids of world position
// + TIME interleave into a 0..1 sweep, which is then added to the
// body colour at `wave_strength`. Defaults to 0 so dry-land layers
// render flat — water layers (deep_water, ocean, shallow_water)
// crank it via the material to get the "ondinhas do mar" feel.
uniform float wave_strength    : hint_range(0.0, 0.5)  = 0.0;
uniform float wave_uv_strength : hint_range(0.0, 8.0)  = 0.0;
uniform float wave_speed       : hint_range(0.0, 5.0)  = 1.0;
uniform float wave_scale       : hint_range(4.0, 256.0) = 48.0;

// --- heat haze ------------------------------------------------------
//
// Ported from the-scrap-warriors' `colorize_heat.gdshader`. A
// multi-octave value-noise field scrolls in opposite directions on
// each axis, displacing the texture sample by up to `haze_max_shift`
// texels. Reads as wobbly air above hot ground without animating the
// chroma keys themselves. Gate is `haze_strength` — 0 turns the whole
// pass off so cool tiles render flat.
uniform float haze_strength  : hint_range(0.0, 1.0) = 0.0;
uniform float haze_speed     : hint_range(0.0, 5.0) = 0.45;
uniform float haze_scale     : hint_range(1.0, 32.0) = 8.0;
uniform float haze_max_shift : hint_range(0.0, 4.0) = 0.6;

varying vec2 v_world_pos;

// Cheap value noise (lifted from `colorize_heat.gdshader`). Bilinear
// interpolation of a per-cell white-noise hash, smoothed with the
// classic 3t² − 2t³ ease.
float _hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
float _value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float v00 = _hash21(i);
	float v10 = _hash21(i + vec2(1.0, 0.0));
	float v01 = _hash21(i + vec2(0.0, 1.0));
	float v11 = _hash21(i + vec2(1.0, 1.0));
	return mix(mix(v00, v10, u.x), mix(v01, v11, u.x), u.y);
}

void vertex() {
	// Default canvas-item transform still applies (we don't touch
	// VERTEX). We just publish the post-MODEL world position so the
	// fragment can map it back to a cell for the climate lookup.
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Per-tile UV (0..1 across the current variant's region in the
	// atlas). Computed up front because both the UV-warp water pass
	// below AND the climate cell lookup further down need it.
	vec2 tile_uv = vec2(
		fract(UV.x * atlas_columns),
		fract(UV.y * atlas_rows)
	);

	// UV warp — shifts the texture sample point with two sinusoids of
	// world position + TIME, making the body's chroma pattern *flow*
	// instead of just flashing brighter / darker. Stays in tile-UV
	// space and clamps to the variant's region so it never bleeds
	// into a neighbouring atlas slice.
	vec2 sample_uv = UV;
	vec2 texel_in_tile = TEXTURE_PIXEL_SIZE * vec2(atlas_columns, atlas_rows);
	vec2 uv_shift = vec2(0.0);
	if (wave_uv_strength > 0.0) {
		float t = TIME * wave_speed;
		vec2 warp = vec2(
			sin(v_world_pos.y / wave_scale + t),
			cos(v_world_pos.x / wave_scale + t * 0.9)
		);
		uv_shift += warp * texel_in_tile * wave_uv_strength;
	}
	if (haze_strength > 0.0) {
		// Two scrolling noise samples (one per axis) — the opposite
		// scroll directions are what gives the haze its shimmering,
		// bidirectional drift.
		vec2 uv_r = tile_uv + vec2( TIME * haze_speed, 0.0);
		vec2 uv_g = tile_uv + vec2(0.0, -TIME * haze_speed);
		float wave_x = sin(
			_value_noise(uv_r * haze_scale *  1.0) * 0.2 +
			_value_noise(uv_r * haze_scale *  2.0) * 0.2 +
			_value_noise(uv_r * haze_scale *  4.0) * 0.2 +
			_value_noise(uv_r * haze_scale *  8.0) * 0.2 +
			_value_noise(uv_r * haze_scale * 16.0) * 0.2
		) - 0.5;
		float wave_y = sin(
			_value_noise(uv_g * haze_scale *  1.0) * 0.2 +
			_value_noise(uv_g * haze_scale *  2.0) * 0.2 +
			_value_noise(uv_g * haze_scale *  4.0) * 0.2 +
			_value_noise(uv_g * haze_scale *  8.0) * 0.2 +
			_value_noise(uv_g * haze_scale * 16.0) * 0.2
		) - 0.5;
		uv_shift += vec2(wave_x, wave_y) * texel_in_tile * haze_max_shift * haze_strength;
	}
	if (uv_shift != vec2(0.0)) {
		vec2 warped_tile_uv = clamp(tile_uv + uv_shift, texel_in_tile * 0.5, vec2(1.0) - texel_in_tile * 0.5);
		float v_idx_x = floor(UV.x * atlas_columns);
		float v_idx_y = floor(UV.y * atlas_rows);
		sample_uv = vec2(
			(v_idx_x + warped_tile_uv.x) / atlas_columns,
			(v_idx_y + warped_tile_uv.y) / atlas_rows
		);
	}

	vec4 c = texture(TEXTURE, sample_uv);
	// Bail out for pixels outside the hex shape. Even though the
	// chroma swap + climate pass leave `base.a` untouched in the
	// transparent branch (so COLOR.a ends up 0), a clamp / overflow
	// inside `clamp(base.rgb * value_scale, 0, 1)` on the magenta
	// sentinel RGB the indexed PNG carries for its transparent index
	// was producing a visible rectangle behind every hex. `discard`
	// skips the fragment entirely — no maths, no output, no halo.
	if (c.a < 0.01) {
		discard;
	}
	vec4 base = c;
	float tol2 = tolerance * tolerance;

	// Three sequential key tests — main first because tiles tend to
	// have more body pixels than detail pixels (early-out wins).
	vec3 d1 = c.rgb - main_key.rgb;
	if (dot(d1, d1) <= tol2) {
		base = vec4(main_color.rgb, c.a);
	} else {
		vec3 d2 = c.rgb - mid_key.rgb;
		if (dot(d2, d2) <= tol2) {
			base = vec4(mid_color.rgb, c.a);
		} else {
			vec3 d3 = c.rgb - hi_key.rgb;
			if (dot(d3, d3) <= tol2) {
				base = vec4(hi_color.rgb, c.a);
			}
			// No key match: pass through (lets a hand-edited tile mix
			// chroma keys with literal pixels).
		}
	}

	// Climate modulation. Gated on `climate_strength` so layers
	// without a climate map hooked up render exactly as before.
	if (climate_strength > 0.0) {
		// Anchor the cell lookup on the *tile's* world centre, not on
		// the fragment's own world position. The fragment's world_x
		// crosses cell boundaries mid-tile (the left ~25 px round to
		// col-1, the right ~13 px round to col+1) — sampling those as
		// distinct cells gives every hex three vertical bands of
		// different modulation and the rectangular tile boundary
		// shows through as a visible grid. Reversing the per-tile UV
		// (computed at the top of fragment()) gets us back to the
		// tile centre, which uniquely identifies the cell.
		vec2 tile_size  = vec2(cell_step.x * 4.0 / 3.0, cell_step.y);
		vec2 tile_centre = v_world_pos - (tile_uv - 0.5) * tile_size;
		float col = floor((tile_centre.x - layout_origin.x) / cell_step.x + 0.5);
		float col_parity = mod(col, 2.0);    // GLSL mod handles negative col cleanly
		float stagger_y = col_parity * cell_stagger;
		float row = floor((tile_centre.y - layout_origin.y - stagger_y) / cell_step.y + 0.5);

		vec2 cell_uv = (vec2(col, row) + 0.5) / grid_size;
		vec4 cli = texture(climate_map, cell_uv);
		float temp = cli.r;

		// Per-cell value jitter — multiply by a deterministic scalar
		// near 1.0. Stays strictly within the source colour's hue
		// family: a blue water hex never drifts toward green, a green
		// grass hex never toward yellow — only lighter / darker
		// shades of the same chroma. Applied BEFORE the desat so the
		// shade variety fades along with the colour as the cell cools.
		float h = fract(sin(dot(vec2(col, row), vec2(127.1, 311.7))) * 43758.5453);
		float value_scale = 1.0 + (h - 0.5) * 2.0 * value_jitter_max;
		vec3 jittered = clamp(base.rgb * value_scale, 0.0, 1.0);

		// Temperature → saturation: hottest cells keep full chroma,
		// coldest cells lerp toward grey by `cold_desat`.
		float desat_amount = mix(cold_desat, 0.0, temp);
		float lum = dot(jittered, vec3(0.299, 0.587, 0.114));
		vec3 climated = mix(jittered, vec3(lum), desat_amount);

		base.rgb = mix(base.rgb, climated, climate_strength);
	}

	// Water shimmer — two phase-shifted sinusoids of world position
	// produce a slow sparkling ripple over the body. Adapted from
	// `colorize_water_legacy.gdshader` in the-scrap-warriors. Gated
	// on `wave_strength` so land terrains are untouched.
	if (wave_strength > 0.0) {
		float wave_a = sin((v_world_pos.x + v_world_pos.y) / wave_scale + TIME * wave_speed);
		float wave_b = cos((v_world_pos.x - v_world_pos.y) / (wave_scale * 1.7) + TIME * wave_speed * 1.3);
		float wave01 = (wave_a + wave_b) * 0.25 + 0.5;
		base.rgb = clamp(base.rgb + vec3(wave01 * wave_strength), 0.0, 1.0);
	}

	float desat_amount = clamp(desaturate, 0.0, 1.0);
	float tint_amount  = clamp(tint_strength, 0.0, 1.0);
	float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat_rgb  = mix(base.rgb, vec3(gray), desat_amount);
	vec3 tinted_rgb = mix(desat_rgb, tint_color.rgb, tint_amount);
	float final_alpha = base.a * alpha;

	// Body jitter + radial falloff — both rely on the per-cell
	// `tile_centre` so they share a single recovery pass. Falloff
	// fades the alpha from 1 at `inner` to 0 at `outer` measured
	// from the cell centre; jitter modulates brightness and alpha
	// per cell with two independent hashes; `body_jitter_speed > 0`
	// turns the hashes into phase offsets of a TIME-driven sin().
	if (body_jitter_amount > 0.0 || body_falloff_outer > 0.0) {
		vec2 tile_size  = vec2(cell_step.x * 4.0 / 3.0, cell_step.y);
		vec2 tile_centre = v_world_pos - (tile_uv - 0.5) * tile_size;

		if (body_jitter_amount > 0.0) {
			float bj_col = floor((tile_centre.x - layout_origin.x) / cell_step.x + 0.5);
			float bj_col_parity = mod(bj_col, 2.0);
			float bj_stagger_y = bj_col_parity * cell_stagger;
			float bj_row = floor((tile_centre.y - layout_origin.y - bj_stagger_y) / cell_step.y + 0.5);
			float bh = fract(sin(dot(vec2(bj_col, bj_row), vec2(127.1, 311.7))) * 43758.5453);
			float ah = fract(sin(dot(vec2(bj_col, bj_row), vec2(311.7, 269.5))) * 43758.5453);
			float bright_jitter;
			float alpha_jitter;
			if (body_jitter_speed > 0.0) {
				float t = TIME * body_jitter_speed;
				bright_jitter = sin(t + bh * 6.2831853) * body_jitter_amount;
				alpha_jitter  = sin(t + ah * 6.2831853) * body_jitter_amount;
			} else {
				bright_jitter = (bh - 0.5) * 2.0 * body_jitter_amount;
				alpha_jitter  = (ah - 0.5) * 2.0 * body_jitter_amount;
			}
			tinted_rgb = clamp(tinted_rgb * (1.0 + bright_jitter), 0.0, 1.0);
			final_alpha = clamp(final_alpha * (1.0 + alpha_jitter), 0.0, 1.0);
		}

		if (body_falloff_outer > body_falloff_inner) {
			float dist = length(v_world_pos - tile_centre);
			float falloff = clamp(
				(body_falloff_outer - dist) / (body_falloff_outer - body_falloff_inner),
				0.0, 1.0
			);
			final_alpha *= falloff;
		}
	}

	COLOR = vec4(tinted_rgb, final_alpha);
}
