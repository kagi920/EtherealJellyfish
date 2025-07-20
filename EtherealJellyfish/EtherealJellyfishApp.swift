//
//  EtherealJellyfishApp.swift
//  EtherealJellyfish
//
//  Created by kagi on 2025/07/20.
//

import SwiftUI

@main
struct EtherealJellyfishApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
                .environment(appModel)
        }
    }
}
