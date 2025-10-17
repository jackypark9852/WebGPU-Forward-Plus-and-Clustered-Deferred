@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;
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

fn hashFloat01(n: u32) -> f32 {
  var x = n;
  x ^= x >> 17; x *= 0xED5AD4BBu;
  x ^= x >> 11; x *= 0xAC4C1B51u;
  x ^= x >> 15; x *= 0x31848BABu;
  x ^= x >> 14;
  // 0..1
  return f32(x) / f32(0xFFFFFFFFu);
}

fn hashColor3(n: u32) -> vec3f {
  return vec3f(hashFloat01(n), hashFloat01(n ^ 0x68E31DA4u), hashFloat01(n ^ 0xB5297A4Du));
}

fn saturate(x: f32) -> f32 { return clamp(x, 0.0, 1.0); }

fn heatmap_gyr(t_raw: f32) -> vec3f {
  let t = saturate(t_raw);
  if (t < 0.5) {
    let u = t * 2.0;
    return mix(vec3f(0.0, 1.0, 0.0), vec3f(1.0, 1.0, 0.0), u);
  } else {
    let u = (t - 0.5) * 2.0;
    return mix(vec3f(1.0, 1.0, 0.0), vec3f(1.0, 0.0, 0.0), u);
  }
}


@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    let dims = CLUSTER_DIMS;
    let N    = clusterCount();

    // Reconstruct view-space position at this fragment:
    // in.fragPos.xy = pixel coords; in.fragPos.z = post-projection depth [0,1]
    
    let cidLinear = getClusterIndex(in.fragPos.xyz, dims);
    let numLights = clusterSet.clusters[cidLinear].numLights;

    // let t = saturate(f32(numLights) / 100.0);   // cap at 50
    // let col = heatmap_gyr(t);
    let t = saturate(f32(numLights) / 1.0) ;
    let col = vec3f(t, t, t);
    return vec4f(col, 1.0);
}