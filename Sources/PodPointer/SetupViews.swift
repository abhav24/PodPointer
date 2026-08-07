import PodPointerCore
import SwiftUI

/// The shared layout for each page of setup.
struct SetupPage<Content: View>: View {
    var progress: String?
    let symbol: String
    let title: String
    var detail: String?
    var onStartOver: (() -> Void)?
