@group(${bindGroup_gBuffer}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_gBuffer}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_gBuffer}) @binding(2) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_gBuffer}) @binding(3) var albedoTex: texture_2d<f32>;
@group(${bindGroup_gBuffer}) @binding(4) var norTex: texture_2d<f32>;
@group(${bindGroup_gBuffer}) @binding(5) var posTex: texture_2d<f32>;

struct FragmentInput
{
    @builtin(position) fragPos: vec4f
}

fn getDepthSlice(zView: f32) -> u32 {
    let s = floor(cameraUniforms.sliceA * log(-zView) - cameraUniforms.sliceB);

    // clamp to valid slice range
    let sClamped = clamp(s, 0.0, f32(dimZ - 1u));
    return u32(sClamped);
}

fn depthToClipZ(d: f32) -> f32 {
    return d * 2.0 - 1.0;
}


fn getClusterIndex(
  pixelCoord : vec3f, 
  dims       : vec3u
) -> u32 {
    let screenWH  = vec2f(cameraUniforms.width, cameraUniforms.height);
    let tileSizePx = screenWH / vec2f(f32(dims.x), f32(dims.y));
    let invProj   = cameraUniforms.invProjMat;
    let clipZ     = depthToClipZ(pixelCoord.z);
    let posVS     = screenToView(pixelCoord.xy, clipZ, invProj, screenWH);

    let cz: u32 = clamp(getDepthSlice(posVS.z), 0u, dimZ - 1u);
    let cx: u32 = clamp(u32(pixelCoord.x / tileSizePx.x), 0u, 16 - 1u);
    let cy: u32 = clamp(u32(pixelCoord.y / tileSizePx.y), 0u, dimY - 1u);

    return flatten3D(cx, cy, cz);
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    let dims = CLUSTER_DIMS;

    let normal = (textureLoad(norTex, vec2<u32>(in.fragPos.xy), 0)).xyz * 2 - 1;
    let worldPos = (textureLoad(posTex, vec2<u32>(in.fragPos.xy), 0)).xyz;
    let albedo = textureLoad(albedoTex, vec2<u32>(in.fragPos.xy), 0);

    let cidLinear = getClusterIndex(in.fragPos.xyz, dims);
    let numLights = clusterSet.clusters[cidLinear].numLights;
    var totalLightContrib = vec3f(0, 0, 0);
    for (var i = 0u; i < numLights; i++) {
        let lightIdx = clusterSet.clusters[cidLinear].lights[i];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, worldPos, normalize(normal));
    }

    var finalColor = albedo.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}