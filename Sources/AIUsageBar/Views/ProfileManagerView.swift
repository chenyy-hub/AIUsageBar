import SwiftUI

// MARK: - Profile Manager

struct ProfileManagerView: View {
    @ObservedObject var service: UsageService
    @State private var profiles: [ModelProfile] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if profiles.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "cpu").font(.title2).foregroundColor(.secondary)
                        Text("暂无模型配置").font(.subheadline).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity).padding(30)
                } else {
                    ForEach(profiles) { profile in
                        ProfileRow(profile: profile, service: service, onChanged: { loadProfiles() })
                    }
                }

                Button(action: { service.windowManager?.openProfileEdit(); loadProfiles() }) {
                    Label("添加配置", systemImage: "plus.circle").font(.subheadline)
                }
                .buttonStyle(.plain).foregroundColor(.accentColor).padding(.top, 4)
            }
            .padding(12)
        }
        .frame(width: 340, height: 520)
        .onAppear { loadProfiles() }
    }

    private func loadProfiles() { profiles = service.profileService?.profiles ?? [] }
}

// MARK: - Profile Row

struct ProfileRow: View {
    let profile: ModelProfile
    @ObservedObject var service: UsageService
    let onChanged: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: profile.isActive ? "checkmark.circle.fill" : "circle")
                .foregroundColor(profile.isActive ? .green : .secondary.opacity(0.3))
                .font(.title3)
                .onTapGesture {
                    service.profileService?.activateProfile(id: profile.id)
                    service.windowManager?.onDataChanged?()
                    onChanged()
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.subheadline).fontWeight(.medium)
                Text("\(profile.provider) · \(profile.model) · \(profile.client)")
                    .font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            Button("Edit") { service.windowManager?.openProfileEdit(existing: profile) }
                .buttonStyle(.plain).font(.caption).foregroundColor(.accentColor)

            Button(action: { service.profileService?.deleteProfile(id: profile.id); onChanged() }) {
                Image(systemName: "trash").font(.caption).foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(profile.isActive ? Color.accentColor.opacity(0.08) : Color(nsColor: .windowBackgroundColor)))
    }
}
