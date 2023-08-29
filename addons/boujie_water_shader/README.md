# Boujie Water Shader
This is a fancy water shader for Godot Engine 4.1+, plus tools to build your own
infinite ocean.

Tested with: Godot_v4.1.1-stable_win64

![looping_ocean_2023](https://github.com/Chrisknyfe/boujie_water_shader/assets/652027/0be34247-e32e-48a9-972c-65302e06bbe3)

This is a shader I made many years ago for Godot 3, based on MrMinimal's water
shader, itself based on an NVidia shader book. Recently I ported this shader
to godot 4 when I updated my game, added a bunch of features on stream in the
Godot discord, and now I want to give the results back to the community.

[You can find the 3.x water shader here.](https://github.com/Chrisknyfe/godot-scraps)

# Quick Start with Prefabs

To get started with your ocean, instantiate a child scene with SHIFT+CTRL+A and 
load one of the prefab scenes in res://addons/boujie_water_shader/prefabs .
If you want to make more complex changes to your ocean, either use "Make Local"
or "Editable Children".

You can also apply prefab materials, such as ice and obsidian, to your existing
objects.

# How it works

Take a look at `example/boujie_water_shader/water_shader_examples.tscn` for an
example of how to set up an ocean scene.

## Ocean node
![Godot_v4 1 1-stable_win64_Jk7ohpm06o](https://github.com/Chrisknyfe/boujie_water_shader/assets/652027/15b06332-129f-4876-883e-3ab736cabe92)

The plane on which water is simulated is generated during runtime.
Several meshes are generated using the SurfaceTool class, giving you multiple
levels of detail (LODs) which use fewer polygons the further they are
from the center. Finally a "far plane" is generated around the meshes,
stretching to the horizon.

## The Water Shader (water.gdshader)
![Godot_v4 1 1-stable_win64_LllDCC6j79](https://github.com/Chrisknyfe/boujie_water_shader/assets/652027/bca1b36b-f00a-4c4a-a1c8-f0208b70d12b)

A vertex shader is applied to the mesh which moves the vertices up and down
every frame. The movement consists of the average of multiple Gerstner Waves 
each with slightly different values.

The water shader has many adjustable features:
 * Specular, Roughness, and Metallic 
 * Wavy albedo texture
 * Refraction
 * Fresnel
 * [Snell's window](https://en.wikipedia.org/wiki/Snell%27s_window)
 * Sea foam texture modulated by Gerstner Waves
 * Shore foam around solid objects in the water
 * Depth fog
 * Distance fade
 * Fade out features with distance, such as vertex waves and foam

You can optimize shader performance by copying the shader code and
commenting-out any of the #define lines to disable features you don't need.

## CameraFollower3D node
![Godot_v4 1 1-stable_win64_GsdC29ku4M](https://github.com/Chrisknyfe/boujie_water_shader/assets/652027/4d67e644-c86f-4a5f-b84a-80cba8ef4310)

The water plane now follows the camera around, giving the illusion of an
infinite body of water. This works with the water shader, which calculates
wave heights based on global position, not local position.

This node can independently copy the X, Y and Z coordinate from the camera to
the target. It can also snap the target's position to multiples of a given unit
size, which is useful for preventing unpleasant moire patterns and vertex
swimming as vertices move along the waves of the water shader.

## GerstnerWave resource
![Godot_v4 1 1-stable_win64_vZL1lY4QkH](https://github.com/Chrisknyfe/boujie_water_shader/assets/652027/16a431fd-501f-4962-8de2-abe3b75c250a)

A gerstener wave simulates a water wave, with an optionally sharp peak. 

Parameters:
 * Steepness: sharpness of the wave peak
 * Amplitude: increases height of the wave, and fore and aft motion.
 * Direction: direction of the linear waves in degrees
 * Frequency: frequency of the wave
 * Speed: speed of the wave
 * Phase: phase of the wave in degrees. I use this to set foam waves to slightly
	trail matching height waves.

## WaterMaterialDesigner node
![Godot_v4 1 1-stable_win64_bHsp2uFJBY](https://github.com/Chrisknyfe/boujie_water_shader/assets/652027/158878a0-9816-4755-af94-10cd1f0bfe82)

A helper node which can automatically set the water shader's parameters based on
nodes and resources in the scene. Arrays of GerstnerWave resources get converted
into shader parameter arrays for height, foam, and albedo UV waves.

You can optionally choose an Ocean node and a CameraFollower3D node to sync
with the water shader. 

This designer node synchronizes the following:
 * The distance from the center to the edge of the mesh grids of the Ocean node
	is considered the "middle distance". Many "feature fade" shader params are
	set to fade out completely at this "middle distance".
 * The Ocean node's largest quad size is copied to the CameraFollower3D's
	"snap unit".
 * The current Camera's far parameter is considered the "far distance". 
	The Ocean's farplane is regenerated to stretch out into the "far distance".

# Credits
 * Original water shader was made by Tom Langwaldt (MrMinimal).
 * This shader has modifications by Zach Bernal (Chrisknyfe).
 * The refraction feature was modified from code generated by the Godot Engine
 * The fresnel and depth fog features were inspired by the Single Plane Water Shader tutorial by StayAtHomeDev
 * The Ocean class's mesh generation was inspired by the Making An Infinite Ocean tutorial by StayAtHomeDev

# Resources and References
 * [GPU Gems](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models)
 * [Tom's Original GodotWater](https://gitlab.com/MrMinimal/GodotWater)
 * [Wind Waker Ocean Graphics Analysis](https://medium.com/@gordonnl/the-ocean-170fdfd659f1)
 * [Single Plane Water Shader in Godot 4](https://stayathomedev.com/tutorials/single-plane-water-shader/)
 * [Making An Infinite Ocean in Godot 4](https://stayathomedev.com/tutorials/making-an-infinite-ocean-in-godot-4/)
