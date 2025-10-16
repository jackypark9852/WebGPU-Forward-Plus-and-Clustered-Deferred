// CHECKITOUT: code that you add here will be prepended to all shaders

struct Light {
    pos: vec3f,
    color: vec3f
}

struct LightSet {
    numLights: u32,
    lights: array<Light>
}

struct Cluster {
    numLights: u32, 
    lights: array<u32, ${maxNumLightPerCluster}>
}

// TODO-2: you may want to create a ClusterSet struct similar to LightSet
struct ClusterSet {
    numClusters: u32, 
    clusters: array<Cluster> 
}

struct CameraUniforms {
    // TODO-1.3: add an entry for the view proj mat (of type mat4x4f)
    viewProjMat: mat4x4f,
    invProjMat: mat4x4f,
    zNear: f32,
    zFar: f32,
    width: f32, 
    height: f32,
    sliceA: f32,
    sliceB: f32
}

// CHECKITOUT: this special attenuation function ensures lights don't affect geometry outside the maximum light radius
fn rangeAttenuation(distance: f32) -> f32 {
    return clamp(1.f - pow(distance / ${lightRadius}, 4.f), 0.f, 1.f) / (distance * distance);
}

fn calculateLightContrib(light: Light, posWorld: vec3f, nor: vec3f) -> vec3f {
    let vecToLight = light.pos - posWorld;
    let distToLight = length(vecToLight);

    let lambert = max(dot(nor, normalize(vecToLight)), 0.f);
    return light.color * lambert * rangeAttenuation(distToLight);
}

fn divRem(n: u32, d: u32) -> vec2<u32> {
  let q = n / d;
  let r = n - q * d;
  return vec2<u32>(q, r);
}

fn flatten3D(ix: u32, iy: u32, iz: u32) -> u32 {
  return ix + ${clusterDimX} * (iy + ${clusterDimY} * iz);
}

const CLUSTER_DIMS : vec3<u32> = vec3u(${clusterDimX}u, ${clusterDimY}u, ${clusterDimZ}u);

fn clusterCount() -> u32 {
  return ${clusterDimX} * ${clusterDimY} * ${clusterDimZ}; 
}

fn unflatten1D(i: u32) -> vec3<u32> {
  // i = x + X*(y + Y*z)
  let qx_rx = divRem(i, ${clusterDimX});
  let qx = qx_rx.x;    // y + Y*z
  let x  = qx_rx.y;

  let qy_ry = divRem(qx, ${clusterDimY});
  let z  = qy_ry.x;
  let y  = qy_ry.y;

  return vec3<u32>(x, y, z);
}

fn screenToView(
  screenXY : vec2f,      // pixel coords (x,y)
  clipZ    : f32,        // NDC z in [-1,1] (e.g., -1 for near-plane corner)
  invProj  : mat4x4f,
  screenWH : vec2f
) -> vec3f {
  let tex  = screenXY / screenWH;
  let ndc  = vec2f(tex.x * 2.0 - 1.0, (1.0 - tex.y) * 2.0 - 1.0);
  let clip = vec4f(ndc, clipZ, 1.0);
  let vH   = invProj * clip;
  return vH.xyz / vH.w;
}
