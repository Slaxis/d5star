// Card texture shader — deliberately minimal. Each card outputs at
// most TWO colours: `tint_a` (the dark neutral base) and `tint_b`
// (the casta accent). The chosen pattern decides where each lives.
// No gradient, no vignette, no posterize pass — those were what
// caused the horizontal bands at top/middle/bottom; without them
// the result reads as clean pixel-art on the project's NEAREST
// canvas filter.
//
// Patterns:
//   0  hatch  \\          (generic)
//   1  hatch  //          (generic)
//   2  cross-hatch        (generic)
//   3  Bayer-dot dither   (generic)
//   4  horizontal stripes (generic)
//   5  vertical stripes   (generic)
//   6  HONEYCOMB          (DOMINI gold)
//   7  FLEUR-DE-LIS       (CLERUS cloth)
//   8  CAMO 3-tone        (MILITES — outputs 0.0/0.5/1.0 so the
//                          mid zone reads as a 3rd visual tone)
//   9  CARTEIRA grain     (SUBDITI — leather/canvas weave)
//  10  BLOOD drops        (CAPTIVI — scattered thin blood)
//  11  MIST low-contrast  (EXSULES — almost invisible)
//  12  STAR shimmer       (ARCANO — Mario invincibility star;
//                          ignores tints, animates via TIME,
//                          rainbow diagonal sweep + bright spark band)
shader_type canvas_item;

uniform vec4 tint_a : source_color = vec4(0.10, 0.09, 0.11, 1.0);
uniform vec4 tint_b : source_color = vec4(1.0, 0.85, 0.0, 1.0);
// Optional third tone for camo (mode 8). Other patterns ignore
// tint_c — the linear mix(a, b, p) only fires the c-channel inside
// the camo branch's "mid-zone" remap.
uniform vec4 tint_c : source_color = vec4(0.24, 0.16, 0.08, 1.0);

uniform vec2 card_size = vec2(220.0, 340.0);
uniform float pixel_size : hint_range(1.0, 16.0) = 3.0;
uniform int pattern_mode : hint_range(0, 12) = 0;

// Bayer 4×4 ordered dither matrix.
const float BAYER_4[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

float bayer4(vec2 grid) {
	int xi = int(mod(grid.x, 4.0));
	int yi = int(mod(grid.y, 4.0));
	return BAYER_4[yi * 4 + xi] / 16.0;
}

// Deterministic 2D hash. Same input → same output every frame.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// ─── Generic linear patterns (0..5) ──────────────────────────────

float pattern_linear(vec2 uv) {
	vec2 px = floor(uv * card_size / pixel_size);
	if (pattern_mode == 0) {
		return step(2.0, mod(px.y - px.x, 4.0));
	} else if (pattern_mode == 1) {
		return step(2.0, mod(px.y + px.x, 4.0));
	} else if (pattern_mode == 2) {
		float a = step(2.0, mod(px.y - px.x, 4.0));
		float b = step(2.0, mod(px.y + px.x, 4.0));
		return max(a, b);
	} else if (pattern_mode == 3) {
		return bayer4(px);
	} else if (pattern_mode == 4) {
		return step(2.0, mod(px.y, 4.0));
	} else {
		return step(2.0, mod(px.x, 4.0));
	}
}

// ─── DOMINI honeycomb (mode 6) ───────────────────────────────────

float pattern_honeycomb(vec2 uv) {
	vec2 p = uv * card_size / pixel_size / 6.0;
	p.x += mod(floor(p.y), 2.0) * 0.5;
	vec2 f = fract(p) - 0.5;
	vec2 d = abs(f);
	return step(0.42, max(d.x, d.y * 0.95));
}

// ─── CLERUS fleur-de-lis (mode 7) ────────────────────────────────

float pattern_fleur(vec2 uv) {
	vec2 p = uv * card_size / pixel_size / 12.0;
	vec2 cell = mod(p, 1.0) - 0.5;
	float stem = step(abs(cell.x), 0.05) * step(cell.y, 0.32) * step(-0.32, cell.y);
	float top = step(abs(cell.x) + abs(cell.y + 0.30), 0.13);
	float pl = step(abs(cell.x + 0.18) + abs(cell.y + 0.10), 0.13);
	float pr = step(abs(cell.x - 0.18) + abs(cell.y + 0.10), 0.13);
	float band = step(abs(cell.x), 0.26) * step(abs(cell.y - 0.20), 0.04);
	return max(max(max(stem, top), max(pl, pr)), band);
}

// ─── MILITES 3-tone forest camo (mode 8) — ORGANIC BLOBS ─────────
// "Manchas de onça" — two-octave smoothed value noise quantised
// to a chunky pixel grid, then thresholded into three zones
// (tint_a primary green / tint_b dark green / tint_c earth-brown).
// The smoothed interpolation makes the blob outlines flow instead
// of looking like a tiled noise grid.

// Smoothed value noise — bilerp across hash() values with a
// smoothstep so adjacent cells blend into blobs.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float pattern_camo(vec2 uv) {
	// Sample noise at a coarse grid for organic blobs.
	vec2 px = floor(uv * card_size / pixel_size);
	vec2 p = px / 7.0;
	float n1 = value_noise(p);
	float n2 = value_noise(p * 2.3 + vec2(13.0, 7.0));
	float n = n1 * 0.65 + n2 * 0.35;
	// Three zones — encoded with sentinel values the fragment
	// branch reads to pick tint_b (dark green) or tint_c (brown).
	if (n < 0.40) return 1.5;    // sentinel → tint_b
	if (n > 0.65) return -1.5;   // sentinel → tint_c
	return 0.0;                  // mid → tint_a (primary green)
}

// ─── SUBDITI carteira de trabalho weave (mode 9) ────────────────

float pattern_carteira(vec2 uv) {
	vec2 px = floor(uv * card_size / pixel_size);
	float horiz = step(1.0, mod(px.y, 2.0));
	float stitch = step(2.0, mod(px.x + px.y * 0.5, 5.0));
	return max(horiz * 0.65, stitch * 0.35);
}

// ─── CAPTIVI blood drops (mode 10) ───────────────────────────────

float pattern_blood(vec2 uv) {
	vec2 p = uv * card_size / pixel_size;
	vec2 cell = floor(p / 4.0);
	vec2 in_cell = mod(p, 4.0) - 2.0;
	float r = hash(cell);
	if (r < 0.55) return 0.0;
	vec2 center = (vec2(hash(cell + vec2(7.0)), hash(cell + vec2(13.0))) - 0.5) * 2.0;
	float d = length(in_cell - center);
	return step(d, 1.3);
}

// ─── EXSULES mist (mode 11) ──────────────────────────────────────

float pattern_mist(vec2 uv) {
	vec2 px = floor(uv * card_size / pixel_size);
	return bayer4(px) * 0.55 + hash(px) * 0.45;
}

// ─── ARCANO pearl / crystal iridescence (mode 12) ────────────────
// Static pearly-quartz texture — pale base with subtle hue shifts
// across the surface, like light passing through a diamond cut.
// No animation: the arcano stands out by COLOUR (light against the
// dark casta cards), not by motion (which made the eye dizzy).
// Three pale stops (pink / aqua / gold) blended via two noise
// fields at different scales, plus a Bayer-dither highlight for
// the pixel-art register. Reuses value_noise() from the camo block
// above; ignores tint_a/b/c entirely.

// ─── Dispatch ────────────────────────────────────────────────────

float pixel_pattern(vec2 uv) {
	if (pattern_mode <= 5) {
		return pattern_linear(uv);
	} else if (pattern_mode == 6) {
		return pattern_honeycomb(uv);
	} else if (pattern_mode == 7) {
		return pattern_fleur(uv);
	} else if (pattern_mode == 8) {
		return pattern_camo(uv);
	} else if (pattern_mode == 9) {
		return pattern_carteira(uv);
	} else if (pattern_mode == 10) {
		return pattern_blood(uv);
	} else {
		return pattern_mist(uv);
	}
}

void fragment() {
	// Arcano shimmer (mode 12) produces its own RGB inline and
	// bypasses the tint-mix path — the virus visual is rainbow, not
	// a casta tone. RGB channels are 120°-offset sin waves over the
	// diagonal (Newton-prism style); a sparkle band on top sweeps
	// across as a sharp smoothstep.
	//
	// Godot's canvas_item fragment doesn't allow early `return` —
	// the two branches are mutually exclusive but both have to flow
	// through the single COLOR write at the end.
	vec3 color;
	if (pattern_mode == 12) {
		vec2 px = floor(UV * card_size / pixel_size);
		// Two noise fields at different scales — the coarse one shapes
		// big colour zones (the diamond facets), the finer one breaks
		// them up so adjacent facets don't read as flat patches.
		float n1 = value_noise(px / 10.0);
		float n2 = value_noise(px / 6.5 + vec2(31.0, 53.0));
		// Pearl palette — three pale tones that read together as
		// iridescent rather than as separate stripes.
		vec3 pale_pink = vec3(0.95, 0.82, 0.92);
		vec3 pale_aqua = vec3(0.78, 0.94, 0.92);
		vec3 pale_gold = vec3(0.95, 0.92, 0.76);
		// First mix shapes the major facets, second one veils a gold
		// overlay across part of the surface for the "light passing
		// through" quality.
		vec3 base = mix(pale_pink, pale_aqua, smoothstep(0.30, 0.70, n1));
		color = mix(base, pale_gold, n2 * 0.45);
		// Bayer-dither sparkle at the pixel level — gives the surface
		// a faint shimmer without animating it. Matches the pixel-art
		// register of the other patterns.
		color += vec3(bayer4(px) * 0.06);
	} else {
		float p = pixel_pattern(UV);
		// Camo sentinels: 1.5 → tint_b (dark green), -1.5 → tint_c
		// (earth-brown), 0.0 → tint_a (primary green). Everything else
		// falls through to the standard 2-tone mix.
		if (p > 1.2) {
			color = tint_b.rgb;
		} else if (p < -1.0) {
			color = tint_c.rgb;
		} else if (pattern_mode == 8) {
			color = tint_a.rgb;
		} else {
			color = mix(tint_a.rgb, tint_b.rgb, p);
		}
	}
	COLOR = vec4(color, 1.0);
}
