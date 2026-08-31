import PodPointerCore
import SwiftUI

/// The everyday screen after setup.
struct HomeView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            controlSection
            if !model.hasAccessibility {
                accessSection
            }
            if !model.isReceivingMotion {
                connectionSection
            }
            calibrationSection
            advancedSection
        }
        .formStyle(.grouped)
    }

    private var controlSection: some View {
        Section {
            Picker("Mode", selection: Binding(
