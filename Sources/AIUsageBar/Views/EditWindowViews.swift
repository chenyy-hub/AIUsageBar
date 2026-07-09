import SwiftUI

// MARK: - Profile Edit Window

struct ProfileEditView: View {
    @State var draft: ProfileEditDraft
    let onSave: (ProfileEditDraft) -> Void
    @State private var showCancelAlert = false

    private let providers = ["deepseek", "openai", "anthropic", "openrouter"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Profile Configuration").font(.headline)
            Divider()

            Group {
                TextField("Name (e.g. DeepSeek-Pro)", text: $draft.name)
                Picker("Provider", selection: $draft.provider) {
                    ForEach(providers, id: \.self) { Text($0).tag($0) }
                }
                TextField("Model", text: $draft.model)
                TextField("Base URL", text: $draft.baseUrl)
                TextField("Client", text: $draft.client)
            }
            .textFieldStyle(.roundedBorder)
            .font(.subheadline)

            Spacer()
            Divider()
            HStack {
                Button("Cancel") { showCancelAlert = true }
                    .buttonStyle(.plain).foregroundColor(.secondary)
                Spacer()
                Button("Save") {
                    NSApp.keyWindow?.close()
                    onSave(draft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.name.isEmpty || draft.model.isEmpty)
            }
        }
        .padding(20)
        .alert("Discard changes?", isPresented: $showCancelAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) { NSApp.keyWindow?.close() }
        }
    }
}

// MARK: - Provider Edit Window

struct ProviderEditView: View {
    @State var draft: ProviderEditDraft
    let onSave: (ProviderEditDraft) -> Void
    @State private var showCancelAlert = false

    private let typeOptions = ProviderAdapterType.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provider Configuration").font(.headline)
            Divider()

            Group {
                TextField("Provider name (e.g. deepseek)", text: $draft.provider)
                Picker("Type", selection: $draft.providerType) {
                    ForEach(typeOptions) { Text($0.displayName).tag($0.rawValue) }
                }
                TextField("Display name (optional)", text: $draft.displayName)
                TextField("Base URL", text: $draft.baseUrl)
                TextField("Models (comma-separated)", text: .init(
                    get: { draft.modelsJSON },
                    set: { draft.modelsJSON = $0 }
                ))
                SecureField("API Key (stored in Keychain)", text: $draft.apiKey)
            }
            .textFieldStyle(.roundedBorder)
            .font(.subheadline)

            Spacer()
            Divider()
            HStack {
                Button("Cancel") { showCancelAlert = true }
                    .buttonStyle(.plain).foregroundColor(.secondary)
                Spacer()
                Button("Save") {
                    NSApp.keyWindow?.close()
                    onSave(draft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.provider.isEmpty)
            }
        }
        .padding(20)
        .alert("Discard changes?", isPresented: $showCancelAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) { NSApp.keyWindow?.close() }
        }
    }
}

// MARK: - Pricing Edit Window

struct PricingEditView: View {
    @State var draft: PricingEditDraft
    let onSave: (PricingEditDraft) -> Void
    @State private var showCancelAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pricing Configuration").font(.headline)
            Divider()

            Group {
                TextField("Provider", text: $draft.provider)
                TextField("Model", text: $draft.model)
                labeledField("Cache Hit Price (/1M)") {
                    TextField("0.025", value: $draft.inputCacheHitPrice, format: .number)
                }
                labeledField("Cache Miss Price (/1M)") {
                    TextField("3.0", value: $draft.inputCacheMissPrice, format: .number)
                }
                labeledField("Output Price (/1M)") {
                    TextField("6.0", value: $draft.outputPrice, format: .number)
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.subheadline)

            Spacer()
            Divider()
            HStack {
                Button("Cancel") { showCancelAlert = true }
                    .buttonStyle(.plain).foregroundColor(.secondary)
                Spacer()
                Button("Save") {
                    NSApp.keyWindow?.close()
                    onSave(draft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.provider.isEmpty || draft.model.isEmpty)
            }
        }
        .padding(20)
        .alert("Discard changes?", isPresented: $showCancelAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) { NSApp.keyWindow?.close() }
        }
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).frame(width: 160, alignment: .leading)
            content()
        }
    }
}

// MARK: - Budget Edit Window

struct BudgetEditView: View {
    @State var draft: BudgetEditDraft
    let onSave: (BudgetEditDraft) -> Void
    @State private var showCancelAlert = false

    private let periodOptions = [("total", "Total"), ("daily", "Daily"), ("weekly", "Weekly"), ("monthly", "Monthly")]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Configuration").font(.headline)
            Divider()

            Group {
                TextField("Name (optional)", text: $draft.name)
                TextField("Provider (empty = global)", text: $draft.provider)
                labeledField("Initial Balance") {
                    TextField("1000", value: $draft.initialBalance, format: .number)
                }
                Picker("Period", selection: $draft.periodType) {
                    ForEach(periodOptions, id: \.0) { Text($0.1).tag($0.0) }
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.subheadline)

            Spacer()
            Divider()
            HStack {
                Button("Cancel") { showCancelAlert = true }
                    .buttonStyle(.plain).foregroundColor(.secondary)
                Spacer()
                Button("Save") {
                    NSApp.keyWindow?.close()
                    onSave(draft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.initialBalance <= 0)
            }
        }
        .padding(20)
        .alert("Discard changes?", isPresented: $showCancelAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) { NSApp.keyWindow?.close() }
        }
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).frame(width: 140, alignment: .leading)
            content()
        }
    }
}
