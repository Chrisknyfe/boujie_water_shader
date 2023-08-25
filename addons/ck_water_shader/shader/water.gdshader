// Shader to simulate an open ocean based on Gerstner waves
// Reference: https://developer.nvidia.com/gpugems/GPUGems/gpugems_ch01.html

// Water / Ocean Shader

shader_type spatial;

render_mode blend_mix,depth_draw_always,cull_disabled,diffuse_burley,specular_schlick_ggx,world_vertex_coords;

#define WORLD_TRIPLANAR

#define ALBEDO_WAVE
#define VERTEX_WAVE
#define FOAM
#define REFRACTION
#define SHORE_FOAM

// Fade out features with distance from camera
#define DISTANCE_FADE // fade alpha
#define FOAM_FADE
#define SHORE_FADE
#define VERTEX_WAVE_FADE

uniform bool freeze; // Toki wo tomare.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

uniform vec4 albedo: source_color;
uniform sampler2D texture_albedo: source_color;

uniform sampler2D texture_foam: source_color;

uniform sampler2D texture_refraction;
uniform float refraction : hint_range(-16,16);
uniform vec4 refraction_texture_channel;
uniform float refraction_opacity : hint_range(0.0, 1.0);

uniform float shore_start_blend;
uniform float shore_end_blend;

uniform float distance_fade_min;
uniform float distance_fade_max;
uniform float near_fade_min;
uniform float near_fade_max;
uniform float foam_fade_min;
uniform float foam_fade_max;
uniform float shore_fade_min;
uniform float shore_fade_max;
uniform float vertex_wave_fade_min;
uniform float vertex_wave_fade_max; 

uniform float specular : hint_range(0.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0);
uniform float metallic : hint_range(0.0, 1.0);

uniform float uv_blend_sharpness;
uniform vec3 uv_tri_scale;
uniform vec3 uv_tri_offset;

uniform bool vertex_displace_from_mesh_normal;

// TODO: inject these from the camera near/far
uniform float near = 0.1;
uniform float far = 400.0;

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

varying vec3	uv_tri;
varying vec2	refraction_uv;
varying vec3	refraction_uv_tri;
varying vec3	uv_power_normal;
varying float	foam_alpha;

varying vec3	world_coordinates;

float linearize_depth(float depth) {
    depth = 2.0 * depth - 1.0;
    return near * far / (far + depth * (near - far));
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
	float twopi = 6.283185307179586;
	vec2 Direction = vec2( sin(DirectionDegrees * twopi / 360.0), cos(DirectionDegrees * twopi / 360.0 ));
	float p = PhaseDegrees * twopi / 360.0;
	vec3 result;
	result.x = ((Steepness * Amplitude) * Direction.x * cos(twopi * dot(Frequency * Direction, vec2(x, z)) + (Speed * (t+p))));
	result.y = Steepness * sin(twopi * dot(Frequency * Direction, vec2(x, z)) + (Speed * (t+p)));
	result.z = ((Steepness * Amplitude) * Direction.y * cos(twopi * dot(Frequency * Direction, vec2(x, z)) + (Speed * (t+p))));
	
	return result;
}

vec3 N_DEG(float x, float z, float t, float Steepness, float Amplitude, float DirectionDegrees, float Frequency, float Speed, float PhaseDegrees) {
	float twopi = 6.283185307179586;
	vec2 Direction = vec2( sin(DirectionDegrees * twopi / 360.0), cos(DirectionDegrees * twopi / 360.0 ));
	float p = PhaseDegrees * twopi / 360.0;
	vec3 result;
	result.x = (-1.0) * (Direction.x * Frequency * Amplitude * (cos((Frequency * twopi * dot(Direction, vec2(x, z))) + Speed * (t+p))));
	result.y = 1.0 - (Steepness * Frequency * Amplitude * sin((Frequency * twopi * dot(Direction, vec2(x, z))) + Speed * (t+p)));
	result.z = (-1.0) * (Direction.y * Frequency * Amplitude * (cos((Frequency * twopi * dot(Direction, vec2(x, z))) + Speed * (t+p))));
	
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
	
	time = time * float(!freeze);
	
	
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
	VERTEX += vertexWave;
	
	// Calculate normal for each wave, take average
	vec3 normalWave = vec3(0,0,0);
	for (int i = 0; i < WaveCount; i++) {
		normalWave += N_DEG(wave_coords.x, wave_coords.y, time, WaveSteepnesses[i], WaveAmplitudes[i], WaveDirectionsDegrees[i], WaveFrequencies[i], WaveSpeeds[i], WavePhases[i]);
	}
	normalWave = normalWave / float(WaveCount);
	normalWave = rotate_to_normal(normalWave, NORMAL);
	normalWave = normalWave * vertex_fade_alpha + NORMAL * (1.0 - vertex_fade_alpha);
	NORMAL = normalize(normalWave);
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

void fragment() {
	ALPHA = 1.0;
#if defined(DISTANCE_FADE) || defined(FOAM_FADE) || defined (SHORE_FADE)
	float distance_from_camera = distance(CAMERA_POSITION_WORLD, world_coordinates);
#endif
	// Distance fade and foam distance fade
#ifdef DISTANCE_FADE
	ALPHA *= smoothstep(distance_fade_max, distance_fade_min, distance_from_camera);
	// Near fade
	ALPHA *= smoothstep(near_fade_min, near_fade_max, distance_from_camera);
#endif
#ifdef FOAM_FADE
	float foam_fade_alpha = smoothstep(foam_fade_max, foam_fade_min, distance_from_camera);
#endif
#ifdef SHORE_FADE
	float shore_fade_alpha = smoothstep(shore_fade_max, shore_fade_min, distance_from_camera);
#endif
	
	if (ALPHA <= 0.0) {
		discard;
	}
	
	SPECULAR = specular;
	ROUGHNESS = roughness;
	
	vec4 albedo_tex;
#ifdef WORLD_TRIPLANAR
	albedo_tex = triplanar_texture(texture_albedo, uv_power_normal, uv_tri);
#else
	albedo_tex = texture(texture_albedo, UV);
#endif
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	
	/* Refraction
	 * How this works: we get the normal and multiply it by the refraction value & texture. More refraction means light is bent more away from normal's direction.
	 * we then grab the part of the screen texture (via it's UV coords) by taking shifting the regular Screen UV by our "enhanced" refraction normal.
	 * Refraction amount is how much light we are emitting from the other side. This is proportional to albedo opacity, and gated by refraction_opacity.
	 * Finally we do a lookup for the light value from the screen, taking surface roughness into account (lower roughness means higher detail)
	 * The light we get from the screen gets multiplied by the refraction amount, and then we emit it in EMISSION. It's a nice way to fake opacity.
	 * Albedo is darkened to compensate for the extra light coming from the screen behind this material.
	 */
#ifdef REFRACTION
	vec4 ref_tex;
#ifdef WORLD_TRIPLANAR
	ref_tex = triplanar_texture(texture_refraction, uv_power_normal, refraction_uv_tri);
#else
	ref_tex = texture(texture_refraction,refraction_uv);
#endif
	vec3 ref_normal = NORMAL;
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * dot(ref_tex, refraction_texture_channel) * refraction;
	float ref_amount = (1.0 - albedo.a * albedo_tex.a) * refraction_opacity;
	EMISSION += textureLod(screen_texture,ref_ofs,ROUGHNESS * 8.0).rgb * ref_amount;
	ALBEDO *= 1.0 - ref_amount;
#else
	ALPHA *= albedo.a * albedo_tex.a;
#endif
	
	/* Sea Foam
	 * override refraction and add to albedo
	 * scale foam opacity by height of a few of the vertex waves. 
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
	float z_depth = linearize_depth(texture(depth_texture, SCREEN_UV).x);
	float z_pos = linearize_depth(FRAGCOORD.z);
	float z_diff = z_depth - z_pos;
	float shore_alpha = 0.0;
	shore_alpha = 1.0 - smoothstep(shore_start_blend, shore_end_blend, z_diff); // TODO: thresholds should be a parameter, something like shore_foam_depth_cutoff
	shore_alpha = clamp(shore_alpha, 0.0, 1.0);
	shore_alpha = foam_tex.a * shore_alpha; // disable this line when you have an all-white foam texture
	shore_alpha = shore_fade_alpha * shore_alpha;
	
	EMISSION *= (1.0-shore_alpha); // block emission
	ALBEDO = mix(ALBEDO, foam_tex.rgb, shore_alpha);
#endif

}