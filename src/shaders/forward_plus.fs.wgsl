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
    let sClamped = clamp(s, 0.0, f32(dimX - 1u));
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
    let cx: u32 = clamp(u32(pixelCoord.x / tileSizePx.x), 0u, dimX - 1u);
    let cy: u32 = clamp(u32(pixelCoord.y / tileSizePx.y), 0u, dimY - 1u);

    return flatten3D(cx, cy, cz);
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
  let dims = CLUSTER_DIMS;

  let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
  if (diffuseColor.a < 0.5f) {
      discard;
  }

  let cidLinear = getClusterIndex(in.fragPos.xyz, dims);
  let numLights = clusterSet.clusters[cidLinear].numLights;
  var totalLightContrib = vec3f(0, 0, 0);
  for (var i = 0u; i < numLights; i++) {
      let lightIdx = clusterSet.clusters[cidLinear].lights[i];
      let light = lightSet.lights[lightIdx];
      totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
  }

  var finalColor = diffuseColor.rgb * totalLightContrib;
  return vec4(finalColor, 1);
}