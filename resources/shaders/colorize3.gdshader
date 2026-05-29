// colorize3 — three-chroma-key colour swap for indexed tile sprites.
//
// The tile PNGs ship with exactly three RGB values inside the hex
// (black / mid-grey / white, plus alpha=0 outside). At render time
// this shader detects each chroma key and replaces it with whatever
// colour the caller has set for that role. So one B/W/Grey asset
// becomes any palette the engine asks for — terrain, faction, mood.
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
// alpha. Used by climate / temperature / damage overlays without
// having to touch the per-key colours.
uniform vec4  tint_color : source_color = vec4(1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate    : hint_range(0.0, 1.0) = 0.0;
uniform float alpha         : hint_range(0.0, 1.0) = 1.0;

// Squared-distance tolerance for chroma matching. The indexed PNG
// holds the keys pixel-exact, so a tiny tolerance is enough; bumping
// it lets the shader work on slightly noisy hand-painted sources.
uniform float tolerance : hint_range(0.0, 0.1) = 0.01;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
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

	float desat_amount = clamp(desaturate, 0.0, 1.0);
	float tint_amount  = clamp(tint_strength, 0.0, 1.0);
	float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat_rgb  = mix(base.rgb, vec3(gray), desat_amount);
	vec3 tinted_rgb = mix(desat_rgb, tint_color.rgb, tint_amount);
	COLOR = vec4(tinted_rgb, base.a * alpha);
}
