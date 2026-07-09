import SwiftUI

// MARK: - Profile Manager

struct ProfileManagerView: View {
    @ObservedObject var service: UsageService
    @State private var showAddSheet = false
    @State private var showPreview = false
    @State private var selectedProfile: ModelProfile?
    @State private var previewContent: String = ""
    @State private var profiles: [ModelProfile] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if profiles.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "cpu")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("暂无模型配置")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(30)
                } else {
                    ForEach(profiles) { profile in
                        ProfileRow(
                            profile: profile,
                            isActive: profile.isActive,
                            onActivate: {
                                service.profileService?.activateProfile(id: profile.id)
                                loadProfiles()
                                service.refresh()
                            },
                            onPreview: {
                                previewContent = service.profileService?.previewEnvConfig(profile) ?? ""
                                selectedProfile = profile
                                showPreview = true
                            },
                            onDelete: {
                                service.profileService?.deleteProfile(id: profile.id)
                                loadProfiles()
                            }
                        )
                    }
                }

                Button {
                    showAddSheet = true
                } label: {
                    Label("添加配置", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.top, 4)
            }
            .padding(12)
        }
        .frame(width: 340, height: 520)
        .onAppear {
            service.setEditing(true)
            loadProfiles()
        }
        .onDisappear {
            service.setEditing(false)
        }
        .onChange(of: service.selectedTab, initial: false) { _, _ in
            if !service.isEditing { loadProfiles() }
        }
        .sheet(isPresented: $showAddSheet) {
            ProfileEditSheet(service: service, onSave: { loadProfiles() })
        }
        .sheet(isPresented: $showPreview) {
            ProfilePreviewSheet(content: previewContent, profile: selectedProfile, service: service)
        }
    }

    private func loadProfiles() {
        profiles = service.profileService?.profiles ?? []
    }
}

// MARK: - Profile Row

struct ProfileRow: View {
    let profile: ModelProfile
    let isActive: Bool
    let onActivate: () -> Void
    let onPreview: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Active indicator
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            } else {
                Circle()
                    .stroke(Color.secondary.opacity(0.3))
                    .frame(width: 18, height: 18)
                    .onTapGesture { onActivate() }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(profile.provider) · \(profile.model) · \(profile.client)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Actions
            Button("预览", action: onPreview)
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.accentColor)
                .help("预览环境变量")

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("删除")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.08) : Color(nsColor: .windowBackgroundColor))
        )
    }
}

// MARK: - Add Profile Sheet

struct ProfileEditSheet: View {
    @ObservedObject var service: UsageService
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var provider = "deepseek"
    @State private var model = ""
    @State private var baseUrl = ""
    @State private var client = "claude-code"

    private let providers = ["deepseek", "openai", "anthropic", "openrouter"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "cpu.fill").foregroundColor(.accentColor)
                Text("新建模型配置").font(.headline)
            }

            Group {
                TextField("配置名称 (如 DeepSeek-Pro)", text: $name)
                    .textFieldStyle(.roundedBorder)

                Picker("Provider", selection: $provider) {
                    ForEach(providers, id: \.self) { p in
                        Text(p).tag(p)
                    }
                }

                TextField("模型名", text: $model)
                    .textFieldStyle(.roundedBorder)

                TextField("Base URL", text: $baseUrl)
                    .textFieldStyle(.roundedBorder)

                TextField("Client", text: $client)
                    .textFieldStyle(.roundedBorder)
            }
            .font(.subheadline)

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                Spacer()
                Button("保存") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || model.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 330)
        .onAppear {
            service.setEditing(true)
        }
        .onDisappear {
            service.setEditing(false)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedModel.isEmpty else { return }

        let newProfile = ModelProfile(
            id: 0,
            name: trimmedName,
            provider: provider,
            model: trimmedModel,
            baseUrl: baseUrl.trimmingCharacters(in: .whitespacesAndNewlines),
            client: client.trimmingCharacters(in: .whitespacesAndNewlines),
            envConfigJSON: "{}",
            isActive: false,
            createdAt: ""
        )
        service.profileService?.saveProfile(newProfile)
        dismiss()
        DispatchQueue.main.async {
            onSave()
            service.refresh()
        }
    }
}

// MARK: - Preview Sheet

struct ProfilePreviewSheet: View {
    let content: String
    let profile: ModelProfile?
    @ObservedObject var service: UsageService
    @Environment(\.dismiss) private var dismiss
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.accentColor)
                Text("Profile Preview: \(profile?.name ?? "")")
                    .font(.headline)
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }

            Divider()

            ScrollView {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Button("📋 复制到剪贴板") {
                    guard let profile, let svc = service.profileService, let prov = service.providerService else { return }
                    svc.copyToClipboard(profile, providerService: prov)
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopied = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if showCopied {
                    Text("✅ 已复制")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Spacer()

                Button("📥 导出 .env") {
                    guard let profile, let svc = service.profileService, let prov = service.providerService else { return }
                    if let url = svc.exportEnvFile(profile, providerService: prov) {
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 380, height: 440)
    }
}
