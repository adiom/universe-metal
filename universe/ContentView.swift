import SwiftUI
import Metal
import MetalKit

struct ContentView: View {
    @StateObject var metalRenderer = MetalRenderer()

    var body: some View {
        MetalView(renderer: metalRenderer)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
    }
}

struct MetalView: NSViewRepresentable {
    var renderer: MetalRenderer

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero)
        mtkView.device = renderer.device
        mtkView.delegate = context.coordinator
        mtkView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(renderer: renderer)
    }
}

class Coordinator: NSObject, MTKViewDelegate {
    var renderer: MetalRenderer

    init(renderer: MetalRenderer) {
        self.renderer = renderer
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        renderer.render(in: view)
    }
}

class MetalRenderer: ObservableObject {
    var device: MTLDevice?
    var commandQueue: MTLCommandQueue?
    var renderPipelineState: MTLRenderPipelineState?
    var vertexBuffer: MTLBuffer?
    var vertexDescriptor: MTLVertexDescriptor?

    init() {
        device = MTLCreateSystemDefaultDevice()
        if device == nil {
            fatalError("Metal is not supported on this device")
        }

        commandQueue = device?.makeCommandQueue()
        if commandQueue == nil {
            fatalError("Failed to create command queue")
        }

        // Настройка vertex descriptor
        vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor?.attributes[0].format = .float3
        vertexDescriptor?.attributes[0].offset = 0
        vertexDescriptor?.attributes[0].bufferIndex = 0
        vertexDescriptor?.layouts[0].stride = MemoryLayout<Float>.size * 3

        let library = device?.makeDefaultLibrary()
        if library == nil {
            fatalError("Failed to load Metal library")
        }

        let vertexFunction = library?.makeFunction(name: "vertex_main")
        if vertexFunction == nil {
            fatalError("Failed to load vertex function 'vertex_main'")
        }

        let fragmentFunction = library?.makeFunction(name: "fragment_main")
        if fragmentFunction == nil {
            fatalError("Failed to load fragment function 'fragment_main'")
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Устанавливаем vertexDescriptor
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            renderPipelineState = try device?.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("Render pipeline state created successfully.")
        } catch {
            fatalError("Failed to create render pipeline state: \(error)")
        }

        let vertices: [Float] = [
            0.0,  1.0, 0.0,
           -1.0, -1.0, 0.0,
            1.0, -1.0, 0.0
        ]

        vertexBuffer = device?.makeBuffer(bytes: vertices, length: MemoryLayout<Float>.size * vertices.count, options: [])
        if vertexBuffer == nil {
            fatalError("Failed to create vertex buffer")
        }
    }

    func render(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        guard let renderPipelineState = renderPipelineState else { return }
        guard let vertexBuffer = vertexBuffer else { return }

        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("Error: Failed to create command encoder.")
            return
        }

        commandEncoder.setRenderPipelineState(renderPipelineState)
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        commandEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
