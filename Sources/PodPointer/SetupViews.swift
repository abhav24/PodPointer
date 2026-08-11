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
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
            .padding(32)
        }
        .safeAreaInset(edge: .bottom) {
            if let onStartOver {
                Button("Start Over", action: onStartOver)
                    .buttonStyle(.link)
                    .padding(.bottom, 14)
            }
        }
    }
}

/// Numbered instructions.
struct InstructionList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1).")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(minWidth: 180)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
    }
}

/// Shows what the app is waiting for, so a still screen doesn't look stuck.
struct WaitingLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

