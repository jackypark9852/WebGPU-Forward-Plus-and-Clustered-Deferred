@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct GBufferOutput 
{
    @location(0) albedo: vec4<f32>,
    @location(1) normal: vec4<f32>,
    @location(2) worldPosition: vec4<f32>,
}

@fragment
fn main(in: FragmentInput) -> GBufferOutput
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var output: GBufferOutput;
    output.albedo = diffuseColor;
    output.normal = vec4f((normalize(in.nor.xyz) + 1.0) * 0.5, 1.0);
    output.worldPosition = vec4f(in.pos, 1.0);

    return output;
}
