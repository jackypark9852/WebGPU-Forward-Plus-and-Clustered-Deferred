@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f,
    @builtin(position) fragPos : vec4f,
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let d = in.fragPos.z;
    return vec4(vec3(pow(d, 50.0)), 1.0);
}
