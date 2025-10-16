@group(${bindGroup_cluster}) @binding(0) var<storage, read_write> clusterSet : ClusterSet;
@group(${bindGroup_cluster}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_cluster}) @binding(2) var<uniform> cameraUniforms: CameraUniforms;

// ------------------------------------ 
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

// CHECKITOUT: this is an example of a compute shader entry point function

fn projectPointToZ(p: vec3f, zPlane: f32) -> vec3f {
  // t = zPlane / p.z
  let t = zPlane / p.z;
  return p * t;
}

// exponential slicing
fn sliceNearFarExp(zNear: f32, zFar: f32, sliceIdx: u32, sliceCount: u32) -> vec2<f32> {
  // guard against 0
  let count = max(sliceCount, 1u);

  let k = zFar / zNear;
  let a = f32(sliceIdx)       / f32(count);
  let b = f32(sliceIdx + 1u)  / f32(count);

  // View-space z (negative forward)
  let zNearSlice = -zNear * pow(k, a);
  let zFarSlice  = -zNear * pow(k, b);
  return vec2<f32>(zNearSlice, zFarSlice);
}

fn sqDistPointAABB(p: vec3f, bmin: vec3f, bmax: vec3f) -> f32 {
  // Clamp point to the box, then measure the vector from the clamped point
  let q  = clamp(p, bmin, bmax);
  let v  = p - q;
  return dot(v, v);
}

fn testSphereAABB(center: vec3f, radius: f32, aabbMin: vec3f, aabbMax: vec3f) -> bool {
  let d2 = sqDistPointAABB(center, aabbMin, aabbMax);
  return d2 <= (radius * radius);
}

@compute
@workgroup_size(${clusterWorkgroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    let dims = CLUSTER_DIMS;
    let N    = clusterCount();

    // 1D assignment: one thread per cluster
    let linear = globalIdx.x;
    if (linear >= N) { return; }

    let cid = unflatten1D(linear);
    let cx_f  = f32(cid.x);
    let cy_f  = f32(cid.y);
    let cz    = cid.z;

    // screen / tiling
    let screenWH   = vec2f(cameraUniforms.width, cameraUniforms.height);
    let tileSizePx = screenWH / vec2f(f32(dims.x), f32(dims.y));
    let zNear  = cameraUniforms.zNear;
    let zFar   = cameraUniforms.zFar;

    let eyePos = vec3f(0, 0, 0);

    // find cluster min and max in screen space
    let maxPoint_sS = vec4f(vec2f(cx_f + 1, cy_f + 1) * tileSizePx, -1.0, 1.0); // Top Right
    let minPoint_sS = vec4f(vec2f(cx_f, cy_f) * tileSizePx, -1.0, 1.0); // Bottom left

    // find min and max in view space
    let maxPoint_vS = screenToView(maxPoint_sS.xy, -1, cameraUniforms.invProjMat, screenWH).xyz;
    let minPoint_vS = screenToView(minPoint_sS.xy, -1, cameraUniforms.invProjMat, screenWH).xyz;

    // tile z-near and z-far
    let tileNearFar = sliceNearFarExp(zNear, zFar, cz, dims.z);

    // find min/max points on tile near/far
    let minPointNear = projectPointToZ(minPoint_vS, tileNearFar.x);
    let minPointFar  = projectPointToZ(minPoint_vS, tileNearFar.y);
    let maxPointNear = projectPointToZ(maxPoint_vS, tileNearFar.x);
    let maxPointFar  = projectPointToZ(maxPoint_vS, tileNearFar.y);

    // find clusterAABB
    let minPointAABB = min(min(minPointNear, minPointFar),min(maxPointNear, maxPointFar));
    let maxPointAABB = max(max(minPointNear, minPointFar),max(maxPointNear, maxPointFar));

    let r = f32(${lightRadius});
    var numLights = 0u;
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        let light = lightSet.lights[lightIdx];

        // AABB - Sphere intersection test
        if(testSphereAABB(light.pos, r, minPointAABB, maxPointAABB)) {
            if (numLights < ${maxNumLightPerCluster}u) {
                clusterSet.clusters[linear].lights[numLights] = lightIdx;
                numLights = numLights + 1u;
            }
        }
    }

    clusterSet.clusters[linear].numLights = numLights;
}
