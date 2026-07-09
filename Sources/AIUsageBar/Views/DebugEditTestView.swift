import SwiftUI

// MARK: - Debug Edit Test View

/// Test view for sheet lifecycle verification (superseded by WindowManager).
/// Retained as reference. Use service.windowManager for all editing.
struct DebugEditTestView: View {
    var body: some View {
        Text("WindowManager handles all editing. See service.windowManager.")
            .font(.caption).foregroundColor(.secondary)
            .padding(20)
    }
}
