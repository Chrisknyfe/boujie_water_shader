// Water shader to simulate an open ocean based on Gerstner waves

shader_type spatial;

render_mode blend_mix,depth_draw_always,cull_disabled,diffuse_burley,specular_schlick_ggx,world_vertex_coords;

#define WORLD_TRIPLANAR

#define ALBEDO_WAVE
#define VERTEX_WAVE
#define FOAM
#define REFRACTION
#define SHORE_FOAM
#define FRESNEL
#define SNELLS_WINDOW
#define DEPTH_FOG

// Fade out features with distance from camera
#define DISTANCE_FADE // fade ALPHA, then drop at 0
#define FOAM_FADE
#define SHORE_FADE
#define VERTEX_WAVE_FADE
#define DEPTH_FOG_FADE // control depth fade because the depth buffer is imprecise at far distances
#define REFRACTION_SCALING // refraction refracts distant objects way too much; scale it down with distance.

uniform bool freeze_time = false; // Toki wo tomare.
uniform vec4 albedo: source_color;
uniform vec4 albedo_fresnel: source_color;
uniform sampler2D texture_albedo: source_color;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

/* When ON - vertex waves rise along the mesh's normal
 * When OFF - vertex waves rise in the global up direction (+y)
 */
uniform bool vertex_displace_from_mesh_normal;

group_uniforms Refraction;
uniform sampler2D texture_refraction;
uniform float refraction : hint_range(-2,2);
uniform vec4 refraction_texture_channel;
uniform float refraction_opacity : hint_range(0.0, 1.0);
group_uniforms;

group_uniforms Foam;
uniform sampler2D texture_foam: source_color;
uniform float shore_start_blend;
uniform float shore_end_blend;
group_uniforms;

group_uniforms DistanceFade;
uniform float distance_fade_min;
uniform float distance_fade_max;
group_uniforms;

group_uniforms FeatureFade;
uniform float near_fade_min;
uniform float near_fade_max;
uniform float foam_fade_min;
uniform float foam_fade_max;
uniform float shore_fade_min;
uniform float shore_fade_max;
uniform float vertex_wave_fade_min;
uniform float vertex_wave_fade_max; 
uniform float depth_fog_fade_min;
uniform float depth_fog_fade_max; 
uniform float refraction_scaling_distance_min; // no max - refraction falls off proportionally starting from this distance
group_uniforms;

group_uniforms WorldTriplanarUvs;
uniform float uv_blend_sharpness;
uniform vec3 uv_tri_scale;
uniform vec3 uv_tri_offset;
group_uniforms;

group_uniforms DepthFog;
uniform vec4 color_deep : source_color;
uniform vec4 color_shallow : source_color;
uniform float beers_law = 2.0;
uniform float depth_offset = -0.75;
group_uniforms;

group_uniforms SnellWindow;
uniform vec4 albedo_snell: source_color;
uniform vec3 snell_direction = vec3(0.0, 1.0, 0.0);
uniform float snell_tightness : hint_range(0.0, 1.0) = 0.7;
group_uniforms;

group_uniforms WaveParameters;
uniform int WaveCount : hint_range(0,8) = 0;
uniform float WaveSteepnesses[8];
uniform float WaveAmplitudes[8];
uniform float WaveDirectionsDegrees[8];
uniform float WaveFrequencies[8];
uniform float WaveSpeeds[8];
uniform float WavePhases[8];
group_uniforms;

group_uniforms FoamWaveParameters;
uniform int FoamWaveCount : hint_range(0,8) = 0;
uniform float FoamWaveSteepnesses[8];
uniform float FoamWaveAmplitudes[8];
uniform float FoamWaveDirectionsDegrees[8];
uniform float FoamWaveFrequencies[8];
uniform float FoamWaveSpeeds[8];
uniform float FoamWavePhases[8];
group_uniforms;

group_uniforms UVWaveParameters;
uniform int UVWaveCount : hint_range(0,8) = 0;
uniform float UVWaveSteepnesses[8];
uniform float UVWaveAmplitudes[8];
uniform float UVWaveDirectionsDegrees[8];
uniform float UVWaveFrequencies[8];
uniform float UVWaveSpeeds[8];
uniform float UVWavePhases[8];
group_uniforms;


uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying vec3	uv_tri;
varying vec2	refraction_uv;
varying vec3	refraction_uv_tri;
varying vec3	uv_power_normal;
varying float	foam_alpha;

varying vec3	world_coordinates;

float fresnel(float amount, vec3 normal, vec3 view)
{
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}

float snell(float amount, vec3 normal, vec3 view)
{
	return step(amount, clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 ));
}

// An offset at a point on a Gerstner Wave
/*
 * x & z: wave position
 * t: time
 * Steepness: physical height of the wave. Up and down particle motion.
 * Amplitude: also height, but affects the normal more. Fore and aft particle motion.
 * Direction, Frequency, Speed: self explanatory
 */
vec3 P_DEG(float x, float z, float t, float Steepness, float Amplitude, float DirectionDegrees, float Frequency, float Speed, float PhaseDegrees) {
	vec2 Direction = vec2( sin(DirectionDegrees * TAU / 360.0), cos(DirectionDegrees * TAU / 360.0 ));
	float p = PhaseDegrees * TAU / 360.0;
	vec3 result;
	result.x = ((Steepness * Amplitude) * Direction.x * cos(TAU * dot(Frequency * Direction, vec2(x, z)) + (Speed * (t+p))));
	result.y = Steepness * sin(TAU * dot(Frequency * Direction, vec2(x, z)) + (Speed * (t+p)));
	result.z = ((Steepness * Amplitude) * Direction.y * cos(TAU * dot(Frequency * Direction, vec2(x, z)) + (Speed * (t+p))));
	
	return result;
}

vec3 N_DEG(float x, float z, float t, float Steepness, float Amplitude, float DirectionDegrees, float Frequency, float Speed, float PhaseDegrees) {
	vec2 Direction = vec2( sin(DirectionDegrees * TAU / 360.0), cos(DirectionDegrees * TAU / 360.0 ));
	float p = PhaseDegrees * TAU / 360.0;
	vec3 result;
	result.x = (-1.0) * (Direction.x * Frequency * Amplitude * (cos((Frequency * TAU * dot(Direction, vec2(x, z))) + Speed * (t+p))));
	result.y = 1.0 - (Steepness * Frequency * Amplitude * sin((Frequency * TAU * dot(Direction, vec2(x, z))) + Speed * (t+p)));
	result.z = (-1.0) * (Direction.y * Frequency * Amplitude * (cos((Frequency * TAU * dot(Direction, vec2(x, z))) + Speed * (t+p))));
	
	return result;
}

// Rotate a vector from vec3(0,1,0) to the normal, rotation about the z and y axes.
vec3 rotate_to_normal(vec3 point, vec3 normal)
{
	float theta = atan(normal.z, normal.x);
	if (abs(normal.z) < 0.0001 && abs(normal.x) < 0.0001) {
		theta = 0.0;
	}
	float phi = acos(normal.y);
	float ct = cos(theta);
	float st = sin(theta);
	float cp = cos(phi);
	float sp = sin(phi);
	// column major. okay, deep breaths. I got this.
//	mat3 rot = mat3( vec3(cp*ct, sp*ct,-st), vec3(-sp,cp,0), vec3(cp*st,sp*st,ct));
	// huh. let's try row major instead. okay I guess that works?
	mat3 rot = mat3( vec3(cp*ct, -sp, cp*st), vec3(sp*ct, cp, sp*st), vec3(-st, 0, ct));
	vec3 newpoint = rot*point;
	return newpoint;
}

void vertex() {
	float time = TIME; //TIME;
	
	time = time * float(!freeze_time);
	
	
	// UV will be assigned based on xz world coords
	// Zach, VERTEX is in world coords now! world_vertex_coords render mode!
	world_coordinates = VERTEX;
	// Keep UV based on world XZ around as inputs to various wave functions
	vec2 wave_coords = world_coordinates.xz;
	// Need camera pos for distance testing
 	vec3 world_camera_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float distance_from_camera = distance(world_coordinates, world_camera_pos);
	
	
#ifdef WORLD_TRIPLANAR
	// Define triplanar UV
	uv_power_normal=pow(abs(NORMAL),vec3(uv_blend_sharpness));
	uv_power_normal/=dot(uv_power_normal,vec3(1.0));
	uv_tri = (world_coordinates).xyz / uv_tri_scale + uv_tri_offset;
	uv_tri *= vec3(1.0,-1.0, 1.0);
	UV = uv_tri.xz;
#endif

	// Apply some wavey movement to the general UV coords
#ifdef ALBEDO_WAVE
	vec3 uvwave = vec3(0,0,0);
	for (int i = 0; i < UVWaveCount; i++) {
		uvwave += P_DEG(UV.x, UV.y, time, UVWaveSteepnesses[i], UVWaveAmplitudes[i], UVWaveDirectionsDegrees[i], UVWaveFrequencies[i], UVWaveSpeeds[i], UVWavePhases[i]);
	}
	uv_tri += uvwave;

	UV += uvwave.xz;
#endif
	
	
	// Apply some constant movement 
#ifdef WORLD_TRIPLANAR
	refraction_uv_tri = uv_tri;
	refraction_uv_tri += vec3(0.1, -0.2, -0.15) * time;
	uv_tri += vec3(0.1) * time;
#else
	refraction_uv = UV;
	refraction_uv += vec2(0.1, 0.2) * time;
#endif
	UV += vec2(0.1)* time;
	
	// Calcualte foam alpha in vertex where it's cheaper
	
	// Throw in a bunch of constants to make these VERTEX waves look good in UV space
#ifdef FOAM
	vec3 foamVertexWave = vec3(0,0,0);
	for (int i = 0; i < FoamWaveCount; i++) {
		foamVertexWave += P_DEG(wave_coords.x, wave_coords.y, time, FoamWaveSteepnesses[i], FoamWaveAmplitudes[i], FoamWaveDirectionsDegrees[i], FoamWaveFrequencies[i], FoamWaveSpeeds[i], FoamWavePhases[i]);
	}
	foamVertexWave = foamVertexWave / float(FoamWaveCount);
	foam_alpha = foamVertexWave.y;
#else
	foam_alpha = 0.0;
#endif
	
	float vertex_fade_alpha = 1.0;
#ifdef VERTEX_WAVE_FADE
	vertex_fade_alpha = smoothstep(vertex_wave_fade_max, vertex_wave_fade_min, distance_from_camera);
#endif
	
	// Calculate offset for every wave, take average
#ifdef VERTEX_WAVE
	vec3 vertexWave = vec3(0,0,0);
	for (int i = 0; i < WaveCount; i++) {
		vertexWave += P_DEG(wave_coords.x, wave_coords.y, time, WaveSteepnesses[i], WaveAmplitudes[i], WaveDirectionsDegrees[i], WaveFrequencies[i], WaveSpeeds[i], WavePhases[i]);
	}
	vertexWave = vertexWave / float(WaveCount);
	if (vertex_displace_from_mesh_normal) {
		vertexWave = rotate_to_normal(vertexWave, NORMAL);
	}
	vertexWave *= vertex_fade_alpha;
	if (WaveCount > 0) {
		VERTEX += vertexWave;
	}
	
	// Calculate normal for each wave, take average
	vec3 normalWave = vec3(0,0,0);
	for (int i = 0; i < WaveCount; i++) {
		normalWave += N_DEG(wave_coords.x, wave_coords.y, time, WaveSteepnesses[i], WaveAmplitudes[i], WaveDirectionsDegrees[i], WaveFrequencies[i], WaveSpeeds[i], WavePhases[i]);
	}
	normalWave = normalize(normalWave / float(WaveCount));
	if (vertex_displace_from_mesh_normal) {
		normalWave = rotate_to_normal(normalWave, NORMAL);
	}
	normalWave = normalWave * vertex_fade_alpha + NORMAL * (1.0 - vertex_fade_alpha);
	if (WaveCount > 0) {
		NORMAL = normalize(normalWave);
	}
#endif

	// DEBUG: increase vertex height based on distance from center
	//VERTEX.y += 0.1 * (wave_coords.x + wave_coords.y);
	
	// refresh world_coordinates with updated position
	world_coordinates = VERTEX;
}

vec4 triplanar_texture(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos) {
	vec4 samp=vec4(0.0);
	samp+= texture(p_sampler,p_triplanar_pos.xy) * p_weights.z;
	samp+= texture(p_sampler,p_triplanar_pos.xz) * p_weights.y;
	samp+= texture(p_sampler,p_triplanar_pos.zy * vec2(-1.0,1.0)) * p_weights.x;
	return samp;
}

// Calculate depth of solid object beneath the water by reading the depth texture
float depth_from_water_to_object(vec2 screen_uv, mat4 inv_projection_matrix, vec3 vertex) {
	float depth_raw = textureLod(depth_texture, screen_uv, 0.0).r;
	// https://www.reddit.com/r/godot/comments/wb0jw7/godot_4_alpha_12_depth_texture_not_working/ii4awtb/
	// In Godot 4 Vulcan, depth_raw goes from 0 to 1 and doesn't need to be normalzied anymore!!! Holy smokes.
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth_raw); 
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float z_depth = -view.z;
	float z_pos = -vertex.z;
	return z_depth - z_pos;
}


	/* Refraction
	 * How this works: we get the normal and multiply it by the refraction value & texture. More refraction means light is bent more away from normal's direction.
	 * we then grab the part of the screen texture (via it's UV coords) by shifting the regular Screen UV by our "enhanced" refraction normal.
	 * Refraction amount is how much light we are emitting from the other side. This is proportional to albedo opacity, and gated by refraction_opacity.
	 * Finally we do a lookup for the light value from the screen, taking surface roughness into account (lower roughness means higher detail)
	 * The light we get from the screen gets multiplied by the refraction amount, and then we emit it in EMISSION. It's a nice way to fake opacity.
	 * Albedo is darkened to compensate for the extra light coming from the screen behind this material.
	 */

void fragment() {
	ALPHA = 1.0;

	// Calculate distance from the camera to the water
#if defined(DISTANCE_FADE) || defined(FOAM_FADE) || defined (SHORE_FADE) || defined(DEPTH_FOG_FADE)
	float distance_from_camera = distance(CAMERA_POSITION_WORLD, world_coordinates);
#endif

	vec2 screen_uv = SCREEN_UV;

	// Calculate new screen_uv from refraction texture and amount, which will be used by any screen reading code.
#ifdef REFRACTION
	vec4 ref_tex;
#ifdef WORLD_TRIPLANAR
	ref_tex = triplanar_texture(texture_refraction, uv_power_normal, refraction_uv_tri);
#else
	ref_tex = texture(texture_refraction,refraction_uv);
#endif
	float r_final = refraction;
#ifdef REFRACTION_SCALING
	r_final *= clamp(refraction_scaling_distance_min / distance_from_camera, 0.0, 1.0);
#endif
	float ref_sample = dot(ref_tex, refraction_texture_channel);
	vec2 ref_uv_offset = (NORMAL.xy * ref_sample + ref_sample - 0.5) * r_final;
	screen_uv = SCREEN_UV - ref_uv_offset;
#endif

	// Distance fade and foam distance fade
#ifdef DISTANCE_FADE
	ALPHA *= smoothstep(distance_fade_max, distance_fade_min, distance_from_camera);
	// Near fade
	ALPHA *= smoothstep(near_fade_min, near_fade_max, distance_from_camera);
#endif
#ifdef FOAM_FADE
	float foam_fade_alpha = smoothstep(foam_fade_max, foam_fade_min, distance_from_camera);
#else
	float foam_fade_alpha = 1.0;
#endif
#ifdef SHORE_FADE
	float shore_fade_alpha = smoothstep(shore_fade_max, shore_fade_min, distance_from_camera);
#else
	float shore_fade_alpha = 1.0;
#endif
	
	if (ALPHA <= 0.0) {
		discard;
	}
	METALLIC = metallic;
	SPECULAR = specular;
	ROUGHNESS = roughness;
	
	vec4 albedo_tex;
#ifdef WORLD_TRIPLANAR
	albedo_tex = triplanar_texture(texture_albedo, uv_power_normal, uv_tri);
#else
	albedo_tex = texture(texture_albedo, UV);
#endif

	float final_refraction_opacity = refraction_opacity;
#ifdef FRESNEL
	float fresnel_factor = fresnel(3.0, NORMAL, VIEW);
	vec4 surface_color = mix(albedo, albedo_fresnel, fresnel_factor);
#else
	vec4 surface_color = albedo;
#endif

#ifdef SNELLS_WINDOW
	vec2 snell_offset = ref_uv_offset * 2.0;
	vec3 snell_normal = vec3(NORMAL.x - snell_offset.x, NORMAL.y - snell_offset.y, NORMAL.z);
	float snell_factor = snell(snell_tightness, snell_normal, VIEW);
	if (FRONT_FACING) {
		snell_factor = 1.0;
	}
	final_refraction_opacity *= snell_factor;
	final_refraction_opacity = clamp(final_refraction_opacity, 0.0, 1.0);
	surface_color = mix(albedo_snell, surface_color, snell_factor);
#endif

	// Screen-reading shader features
	float screen_lod = 0.0;
	float screen_read_blend_amount = (1.0 - surface_color.a * albedo_tex.a);
#ifdef DEPTH_FOG
	float z_diff_refracted = depth_from_water_to_object(screen_uv, INV_PROJECTION_MATRIX, VERTEX);
	float depth_blend = exp((z_diff_refracted + depth_offset) * -beers_law);
	depth_blend = clamp(1.0 - depth_blend, 0.0, 1.0);
	float depth_blend_power = clamp(pow(depth_blend, 2.5), 0.0, 1.0);
#ifdef DEPTH_FOG_FADE
	depth_blend_power += smoothstep(depth_fog_fade_min, depth_fog_fade_max, distance_from_camera);
	depth_blend_power = clamp(depth_blend_power, 0.0, 1.0);
#endif	
	screen_lod += depth_blend_power * 2.5;
#endif

#ifdef REFRACTION
	screen_read_blend_amount *= final_refraction_opacity;
	screen_lod += ROUGHNESS * 8.0;
#endif

	// Read the screen for screen-reading shader features
#if defined(REFRACTION) || defined(DEPTH_FOG)
	vec3 screen_color = textureLod(screen_texture, screen_uv, screen_lod).rgb;
#endif

	// Blend the screen color with depth fade
#ifdef DEPTH_FOG
	vec3 shallow_screen_color = mix(screen_color, color_shallow.rgb, color_shallow.a);
	vec3 deep_screen_color = mix(screen_color, color_deep.rgb, color_deep.a);
	if (FRONT_FACING) {
		screen_color = mix(shallow_screen_color, deep_screen_color, depth_blend_power);
	}
#endif

	// Finally write color to the screen. Screen-reading shaders use EMISSION to simulate ALPHA.
#if defined(REFRACTION) || defined(DEPTH_FOG)
	ALBEDO = surface_color.rgb * albedo_tex.rgb;
	EMISSION += screen_color * screen_read_blend_amount;
	ALBEDO *= 1.0 - screen_read_blend_amount;
	// don't set ALPHA here
#else
	ALBEDO = surface_color.rgb * albedo_tex.rgb;
	ALPHA *= surface_color.a * albedo_tex.a;
#endif

	/* Sea Foam
	 * override refraction and add to albedo
	 * scale foam opacity based on a given set of waves. 
	 */

#if defined(FOAM) || defined(SHORE_FOAM)
	vec4 foam_tex;
#ifdef WORLD_TRIPLANAR
	foam_tex = triplanar_texture(texture_foam, uv_power_normal, uv_tri);
#else
	foam_tex = texture(texture_foam, UV);
#endif
#endif

#ifdef FOAM
	float final_foam_alpha = foam_alpha * foam_tex.a * foam_fade_alpha;
	float foam_alpha_threshold = 0.0;
	final_foam_alpha = smoothstep(foam_alpha_threshold, foam_alpha_threshold + 1.0, final_foam_alpha);
	EMISSION *= (1.0-final_foam_alpha); // block emission
	ALBEDO = mix(ALBEDO, foam_tex.rgb, final_foam_alpha);
#endif
	
#ifdef SHORE_FOAM
	float z_diff = depth_from_water_to_object(SCREEN_UV, INV_PROJECTION_MATRIX, VERTEX);
	float shore_alpha = 0.0;
	shore_alpha = 1.0 - smoothstep(shore_start_blend, shore_end_blend, z_diff); // TODO: thresholds should be a parameter, something like shore_foam_depth_cutoff
	shore_alpha = clamp(shore_alpha, 0.0, 1.0);
	shore_alpha = foam_tex.a * shore_alpha; // disable this line when you have an all-white foam texture
	shore_alpha = shore_fade_alpha * shore_alpha;
	
	EMISSION *= (1.0-shore_alpha); // block emission
	ALBEDO = mix(ALBEDO, foam_tex.rgb, shore_alpha);
#endif

}