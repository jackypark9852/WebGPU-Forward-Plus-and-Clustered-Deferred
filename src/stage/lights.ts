import { vec3 } from "wgpu-matrix";
import { device } from "../renderer";

import * as shaders from '../shaders/shaders';
import { Camera } from "./camera";

// h in [0, 1]
function hueToRgb(h: number) {
    let f = (n: number, k = (n + h * 6) % 6) => 1 - Math.max(Math.min(k, 4 - k, 1), 0);
    return vec3.lerp(vec3.create(1, 1, 1), vec3.create(f(5), f(3), f(1)), 0.8);
}

export class Lights {
    private camera: Camera;

    numLights = 500;
    static readonly maxNumLights = 5000;
    static readonly numFloatsPerLight = 8; // vec3f is aligned at 16 byte boundaries

    static readonly lightIntensity = 0.1;

    // lights storage
    lightsArray = new Float32Array(Lights.maxNumLights * Lights.numFloatsPerLight);
    lightSetStorageBuffer: GPUBuffer;

    // clusters storage 
    static readonly clusterCount = shaders.constants.clusterDimX * shaders.constants.clusterDimY * shaders.constants.clusterDimZ;
    clustersArray = new Uint32Array(Lights.clusterCount * (shaders.constants.maxNumLightPerCluster + 1)); // + 1 for numLights in each Cluster, +1 for numClusters
    clusterSetStorageBuffer: GPUBuffer;

    timeUniformBuffer: GPUBuffer;

    moveLightsComputeBindGroupLayout: GPUBindGroupLayout;
    moveLightsComputeBindGroup: GPUBindGroup;
    moveLightsComputePipeline: GPUComputePipeline;
    
    clusterComputeBindGroupLayout: GPUBindGroupLayout; 
    clusterComputeBindGroup: GPUBindGroup; 
    clusterComputePipeline: GPUComputePipeline; 

    // TODO-2: add layouts, pipelines, textures, etc. needed for light clustering here
    constructor(camera: Camera) {
        this.camera = camera;

        this.lightSetStorageBuffer = device.createBuffer({
            label: "lights",
            size: 16 + this.lightsArray.byteLength, // 16 for numLights + padding
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });
        this.populateLightsBuffer();
        this.updateLightSetUniformNumLights();

        this.clusterSetStorageBuffer = device.createBuffer({
            label: "clusters", 
            size: this.clustersArray.byteLength,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        }); 

        this.timeUniformBuffer = device.createBuffer({
            label: "time uniform",
            size: 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });

        this.moveLightsComputeBindGroupLayout = device.createBindGroupLayout({
            label: "move lights compute bind group layout",
            entries: [
                { // lightSet
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" }
                },
                { // time
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" }
                }
            ]
        });

        this.moveLightsComputeBindGroup = device.createBindGroup({
            label: "move lights compute bind group",
            layout: this.moveLightsComputeBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.lightSetStorageBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.timeUniformBuffer }
                }
            ]
        });

        this.moveLightsComputePipeline = device.createComputePipeline({
            label: "move lights compute pipeline",
            layout: device.createPipelineLayout({
                label: "move lights compute pipeline layout",
                bindGroupLayouts: [ this.moveLightsComputeBindGroupLayout ]
            }),
            compute: {
                module: device.createShaderModule({
                    label: "move lights compute shader",
                    code: shaders.moveLightsComputeSrc
                }),
                entryPoint: "main"
            }
        });
        
        this.clusterComputeBindGroupLayout = device.createBindGroupLayout({
            label: "cluster compute bind group layout",
            entries: [
                { // clusters
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" }
                },
                { // lights
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "read-only-storage" }
                },
                { // camera
                    binding: 2, 
                    visibility: GPUShaderStage.COMPUTE, 
                    buffer: {type: "uniform"}
                }
            ]
        });

        this.clusterComputeBindGroup = device.createBindGroup({
            label: "cluster compute bind group",
            layout: this.clusterComputeBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.clusterSetStorageBuffer }
                },
                {
                    binding: 1, 
                    resource: { buffer: this.lightSetStorageBuffer}
                },
                {
                    binding: 2, 
                    resource: { buffer: this.camera.uniformsBuffer}
                }
            ]
        });

        this.clusterComputePipeline = device.createComputePipeline({
            label: "cluster compute pipeline",
            layout: device.createPipelineLayout({
                label: "cluster compute compute pipeline layout",
                bindGroupLayouts: [ this.clusterComputeBindGroupLayout ]
            }),
            compute: {
                module: device.createShaderModule({
                    label: "cluster compute shader",
                    code: shaders.clusteringComputeSrc
                }),
                entryPoint: "main"
            }
        });

    }

    private populateLightsBuffer() {
        for (let lightIdx = 0; lightIdx < Lights.maxNumLights; ++lightIdx) {
            // light pos is set by compute shader so no need to set it here
            const lightColor = vec3.scale(hueToRgb(Math.random()), Lights.lightIntensity);
            this.lightsArray.set(lightColor, (lightIdx * Lights.numFloatsPerLight) + 4);
        }

        device.queue.writeBuffer(this.lightSetStorageBuffer, 16, this.lightsArray);
    }

    updateLightSetUniformNumLights() {
        device.queue.writeBuffer(this.lightSetStorageBuffer, 0, new Uint32Array([this.numLights]));
    }

    doLightClustering(encoder: GPUCommandEncoder) {
        // TODO-2: run the light clustering compute pass(es) here
        // implementing clustering here allows for reusing the code in both Forward+ and Clustered Deferred
    }

    // CHECKITOUT: this is where the light movement compute shader is dispatched from the host
    onFrame(time: number) {
        device.queue.writeBuffer(this.timeUniformBuffer, 0, new Float32Array([time]));

        // not using same encoder as render pass so this doesn't interfere with measuring actual rendering performance
        const encoder = device.createCommandEncoder();

        const computePass = encoder.beginComputePass();

        computePass.setPipeline(this.moveLightsComputePipeline);
        computePass.setBindGroup(shaders.constants.bindGroup_moveLights, this.moveLightsComputeBindGroup);
        const moveLightsWorkgroupCount = Math.ceil(this.numLights / shaders.constants.moveLightsWorkgroupSize);
        computePass.dispatchWorkgroups(moveLightsWorkgroupCount);

        computePass.setPipeline(this.clusterComputePipeline);
        computePass.setBindGroup(shaders.constants.bindGroup_cluster, this.clusterComputeBindGroup); 
        const clusterWorkgroupCount = Math.ceil(
            Lights.clusterCount / shaders.constants.clusterWorkgroupSize
        ); 
        computePass.dispatchWorkgroups(clusterWorkgroupCount);

        computePass.end();
        device.queue.submit([encoder.finish()]);
    }
}
