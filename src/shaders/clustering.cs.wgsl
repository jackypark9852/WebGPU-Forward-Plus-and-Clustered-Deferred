@group(${bindGroup_cluster}) @binding(0) var<storage, read_write> clusterSet : ClusterSet;
@group(${bindGroup_cluster}) @binding(1) var<uniform> cameraUniforms: CameraUniforms;

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
@compute
@workgroup_size(${clusterWorkgroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {

    // write clusters[idx * 256 + 0] = count; etc…
}
