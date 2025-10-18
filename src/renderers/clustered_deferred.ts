import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    gBufferPassBindGroupLayout: GPUBindGroupLayout; 
    gBufferPassBindGroup: GPUBindGroup;

    fullscreenPassBindGroupLayout: GPUBindGroupLayout;
    fullscreenPassBindGroup: GPUBindGroup;

    albedoTexture: GPUTexture; 
    albedoTextureView: GPUTextureView; 
    normalTexture: GPUTexture; 
    normalTextureView: GPUTextureView;
    worldPosTexture: GPUTexture;
    worldPosTextureView: GPUTextureView;
    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    gBufferPassPipeline: GPURenderPipeline;
    fullscreenPassPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        // texture allocations 
        this.albedoTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba8unorm",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.albedoTextureView = this.albedoTexture.createView();

        this.normalTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.normalTextureView = this.normalTexture.createView();

        this.worldPosTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.worldPosTextureView = this.worldPosTexture.createView();

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();
        
        // g buffer pass layout 
        this.gBufferPassBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "g-buffer pass bind group layout",
            entries: [
                {   // camera uniforms
                    binding: 0, 
                    visibility: GPUShaderStage.VERTEX, 
                    buffer: {type: 'uniform'} 
                }
            ]
        });

        this.gBufferPassBindGroup = renderer.device.createBindGroup({
            label: "g-buffer bind group",
            layout: this.gBufferPassBindGroupLayout,
            entries: [
                {   // camera uniforms
                    binding: 0, 
                    resource: { buffer: this.camera.uniformsBuffer }
                }
            ]
        });

        // fullscreen pass bind group layout
        this.fullscreenPassBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "fullscreen pass bind group layout", 
            entries: [
                {   // camera uniforms
                    binding: 0, 
                    visibility: GPUShaderStage.FRAGMENT, 
                    buffer: {type: 'uniform'} 
                },
                {   // lightset 
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: 'read-only-storage' }
                }, 
                {   // clusterset
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: 'read-only-storage' }
                },
                {   // albedo
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'float'
                    }
                },
                {   // normal
                    binding: 4,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'float'
                    }
                },
                {   // position
                    binding: 5,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'float'
                    }
                }
            ]
        });

        this.fullscreenPassBindGroup = renderer.device.createBindGroup({
            label: "fullscreen pass bind group",
            layout: this.fullscreenPassBindGroupLayout,
            entries: [
                {   // camera uniforms
                    binding: 0, 
                    resource: { buffer: this.camera.uniformsBuffer }
                },
                {   // lightset
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {   // clusterset
                    binding: 2,
                    resource: { buffer: this.lights.clusterSetStorageBuffer }
                },
                {   // albedo
                    binding: 3,
                    resource: this.albedoTextureView
                },
                {   // normal
                    binding: 4,
                    resource: this.normalTextureView
                },
                {   // position
                    binding: 5,
                    resource: this.worldPosTextureView
                }
            ]
        })
        
        // g-buffer pass pipeline
        this.gBufferPassPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "g-buffer pass layout",
                bindGroupLayouts: [
                    this.gBufferPassBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "stadard vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "g-buffer pass frag shader",
                    code: shaders.clusteredDeferredFragSrc,
                }),
                targets: [
                    // albedo: 0 
                    { format: "rgba8unorm" },
                    // normal: 1 
                    { format: "rgba16float" },
                    // world position: 2
                    { format: "rgba16float" }
                ]
            }
        });

        // fullscreen pass pipeline
        this.fullscreenPassPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "fullscreen pass layout",
                bindGroupLayouts : [
                    this.fullscreenPassBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "cluster deffered fullscreen vert shader",
                    code: shaders.clusteredDeferredFullscreenVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "cluster deffered fullscreen frag shader",
                    code: shaders.clusteredDeferredFullscreenFragSrc,
                }),
                targets: [
                    { format: renderer.canvasFormat }
                ]
            }
        })
    }

    doGBufferPass() {
        const encoder = renderer.device.createCommandEncoder();
        const renderPass = encoder.beginRenderPass({
            label: "g-buffer pass",
             colorAttachments: [
                {
                    view: this.albedoTextureView,
                    clearValue: {r:0, g:0, b:0, a:0},
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.normalTextureView,
                    clearValue: {r:0, g:0, b:0, a:0},
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.worldPosTextureView,
                    clearValue: {r:0, g:0, b:0, a:0},
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });
        
        renderPass.setPipeline(this.gBufferPassPipeline);
        renderPass.setBindGroup(shaders.constants.bindGroup_gBuffer, this.gBufferPassBindGroup);

        this.scene.iterate(node => {
            renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            renderPass.setVertexBuffer(0, primitive.vertexBuffer);
            renderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            renderPass.drawIndexed(primitive.numIndices);
        });

        renderPass.end();
        renderer.device.queue.submit([encoder.finish()]);
    }

    doFullScreenPass() {
        const encoder = renderer.device.createCommandEncoder();
        const canvasTextureView = renderer.context.getCurrentTexture().createView();
        const renderPass = encoder.beginRenderPass({
            label: "fullscreen pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });
        
        renderPass.setPipeline(this.fullscreenPassPipeline);
        renderPass.setBindGroup(shaders.constants.bindGroup_fullScreen, this.fullscreenPassBindGroup);

        this.scene.iterate(node => {
            renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            renderPass.setVertexBuffer(0, primitive.vertexBuffer);
            renderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            renderPass.drawIndexed(primitive.numIndices);
        });

        renderPass.end();
        renderer.device.queue.submit([encoder.finish()]);
    }
     
    override draw() {
        // run clustering compute shader pass
        const encoder = renderer.device.createCommandEncoder();
        this.lights.doLightClustering(encoder);
        renderer.device.queue.submit([encoder.finish()]);

        // run g-buffer pass
        this.doGBufferPass();
        
        // fun fullscreen pass
        this.doFullScreenPass(); 
    }
}
