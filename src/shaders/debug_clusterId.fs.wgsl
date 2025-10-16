@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f,
    @builtin(position) fragPos : vec4f
}

fn getDepthSlice(zView: f32) -> u32 {
    let s = floor(cameraUniforms.sliceA * log(-zView) - cameraUniforms.sliceB);

    // clamp to valid slice range
    let sClamped = clamp(s, 0.0, f32(${clusterDimZ} - 1u));
    return u32(sClamped);
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

    let cz: u32 = clamp(getDepthSlice(posVS.z), 0u, ${clusterDimZ} - 1u);
    let cx: u32 = clamp(u32(pixelCoord.x / tileSizePx.x), 0u, ${clusterDimX} - 1u);
    let cy: u32 = clamp(u32(pixelCoord.y / tileSizePx.y), 0u, ${clusterDimY} - 1u);

    return flatten3D(cx, cy, cz);
}

fn depthToClipZ(d: f32) -> f32 {
    return d * 2.0 - 1.0;
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    let dims = CLUSTER_DIMS;
    let N    = clusterCount();

    // Reconstruct view-space position at this fragment:
    // in.fragPos.xy = pixel coords; in.fragPos.z = post-projection depth [0,1]
    
    let cidLinear = getClusterIndex(in.fragPos.xyz, dims);

    let cid = unflatten1D(cidLinear);

    let nx = (f32(cid.x) + 0.5) / max(1.0, f32(dims.x));
    let ny = (f32(cid.y) + 0.5) / max(1.0, f32(dims.y));
    let nz = (f32(cid.z) + 0.5) / max(1.0, f32(dims.z));

    return vec4f(nx, ny, nz, 1.0);
}