import PodPointerCore
import SwiftUI

/// The shared layout for each page of setup.
struct SetupPage<Content: View>: View {
    var progress: String?
    let symbol: String
    let title: String
    var detail: String?
    var onStartOver: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let progress {
                    Text(progress)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .frame(height: 72)
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
