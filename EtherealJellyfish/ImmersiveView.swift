//
//  ImmersiveView.swift
//  EtherealJellyfish
//
//  Created by kagi on 2025/07/20.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @State private var arkitSession = ARKitSession()
    @State private var sceneReconstructionProvider = SceneReconstructionProvider()
    @State private var meshEntities: [UUID: ModelEntity] = [:]
    @State private var jellyfishEntity = Entity()
    private let audioData = AudioDataActor()
    private var audioAnalysisEngine: AudioAnalysisEngine?

    init() {
        audioAnalysisEngine = AudioAnalysisEngine(audioData: audioData)
    }

    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
            }

            // Create jellyfish entity
            let bellEntity = ModelEntity()
            bellEntity.name = "Bell"
            var bellParticles = ParticleEmitterComponent()
            bellParticles.emitterShape = .sphere
            bellParticles.birthLocation = .surface
            bellParticles.particleLifeSpan = 1.5
            bellEntity.components.set(bellParticles)

            let tentacleCount = 8
            let tentacleEntities = (0..<tentacleCount).map { i -> ModelEntity in
                let tentacleEntity = ModelEntity()
                var tentacleParticles = ParticleEmitterComponent()
                tentacleParticles.emitterShape = .point
                tentacleParticles.particleLifeSpan = 5.0
                tentacleParticles.speed = 0.2
                tentacleEntity.components.set(tentacleParticles)

                let angle = (2.0 * .pi / Float(tentacleCount)) * Float(i)
                tentacleEntity.position = [cos(angle) * 0.1, -0.2, sin(angle) * 0.1]
                return tentacleEntity
            }

            do {
                let library = try await MTLCreateSystemDefaultDevice()!.makeDefaultLibrary(bundle: realityKitContentBundle!)
                let surfaceShader = CustomMaterial.SurfaceShader(named: "jellyfishShader", in: library)
                var material = try CustomMaterial(surfaceShader: surfaceShader, lightingModel: .unlit)
                bellEntity.model = ModelComponent(mesh: .generateSphere(radius: 0.2), materials: [material])

                for tentacle in tentacleEntities {
                    tentacle.model = ModelComponent(mesh: .generateBox(size: 0.01), materials: [material])
                    jellyfishEntity.addChild(tentacle)
                }
            } catch {
                print("Failed to create custom material: \(error)")
            }

            jellyfishEntity.addChild(bellEntity)

            content.add(jellyfishEntity)

        } update: { content in
            for (id, entity) in meshEntities {
                if entity.parent == nil {
                    content.add(entity)
                }
            }

            Task {
                let magnitudes = await audioData.getMagnitudes()
                if var model = jellyfishEntity.findEntity(named: "Bell")?.components[ModelComponent.self] {
                    if var material = model.materials.first as? CustomMaterial {
                        material.setParameter(name: "fftMagnitudes", value: .array(magnitudes))
                        model.materials[0] = material
                    }
                }
            }
        }
        .task {
            do {
                try audioAnalysisEngine?.start()
            } catch {
                print("Failed to start audio engine: \(error)")
            }

            Task {
                let providers: [any DataProvider] = [
                    sceneReconstructionProvider
                ]
                do {
                    try await arkitSession.run(providers)
                    for await update in sceneReconstructionProvider.anchorUpdates {
                        let meshAnchor = update.anchor

                        guard let shape = try? await ShapeResource.generateStaticMesh(from: meshAnchor) else { continue }

                        switch update.event {
                        case .added, .updated:
                            let entity = ModelEntity()
                            entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                            entity.components.set(CollisionComponent(shapes: [shape], isStatic: true))
                            entity.components.set(InputTargetComponent())
                            entity.components.set(OcclusionMaterial())

                            meshEntities[meshAnchor.id] = entity
                        case .removed:
                            meshEntities[meshAnchor.id]?.removeFromParent()
                            meshEntities.removeValue(forKey: meshAnchor.id)
                        }
                    }
                } catch {
                    print("ARKit session error: \(error)")
                }
            }
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
