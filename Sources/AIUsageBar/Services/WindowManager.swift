import SwiftUI
import AppKit

// MARK: - Window Manager

/// 管理所有编辑窗口的生命周期，替代 MenuBarExtra .sheet()
///
/// 职责：
///   - 创建独立 NSWindow（不绑定到 MenuBarExtra NSPanel）
///   - 防止重复打开同名窗口
///   - 保存后自动关闭 + 触发数据刷新
///
@MainActor
final class WindowManager {
    /// 数据变更通知回调（由 UsageService 设置）
    var onDataChanged: (() -> Void)?

    private var windows: [String: NSWindow] = [:]
    private let db: DatabaseService

    init(db: DatabaseService) {
        self.db = db
    }

    // MARK: - Open Edit Windows

    func openProfileEdit(existing: (any Identifiable & EditableProfile)? = nil) {
        let windowId = "edit-profile"
        guard windows[windowId] == nil else { windows[windowId]?.makeKeyAndOrderFront(nil); return }

        let draft = existing.map { ProfileEditDraft(from: $0) } ?? ProfileEditDraft()
        let view = ProfileEditView(draft: draft) { [weak self] saved in
            guard let self else { return }
            if let existingId = (existing?.id as? Int), existingId > 0 {
                // Update existing
                self.saveProfileDraft(saved, existingId: existingId)
            } else {
                // Create new
                _ = self.db.saveProfile(saved.toModelProfile())
            }
            self.closeWindow(windowId)
            self.onDataChanged?()
        }

        let window = makeWindow(id: windowId, title: existing != nil ? "Edit Profile" : "New Profile",
                                view: view, size: NSSize(width: 500, height: 400))
        windows[windowId] = window
        window.makeKeyAndOrderFront(nil)
    }

    func openProviderEdit(existing: (any Identifiable & EditableProvider)? = nil) {
        let windowId = "edit-provider"
        guard windows[windowId] == nil else { windows[windowId]?.makeKeyAndOrderFront(nil); return }

        let draft = existing.map { ProviderEditDraft(from: $0) } ?? ProviderEditDraft()
        let view = ProviderEditView(draft: draft) { [weak self] saved in
            guard let self else { return }
            let config = saved.toProviderConfig()
            _ = self.db.saveProvider(config)
            if !saved.apiKey.isEmpty {
                ProviderService.saveAPIKey(provider: config.provider, key: saved.apiKey)
            }
            self.closeWindow(windowId)
            self.onDataChanged?()
        }

        let window = makeWindow(id: windowId, title: existing != nil ? "Edit Provider" : "New Provider",
                                view: view, size: NSSize(width: 500, height: 450))
        windows[windowId] = window
        window.makeKeyAndOrderFront(nil)
    }

    func openPricingEdit(existing: (any Identifiable & EditablePricing)? = nil) {
        let windowId = "edit-pricing"
        guard windows[windowId] == nil else { windows[windowId]?.makeKeyAndOrderFront(nil); return }

        let draft = existing.map { PricingEditDraft(from: $0) } ?? PricingEditDraft()
        let view = PricingEditView(draft: draft) { [weak self] saved in
            guard let self else { return }
            self.db.savePricing(saved.toModelPricing())
            self.closeWindow(windowId)
            self.onDataChanged?()
        }

        let window = makeWindow(id: windowId, title: existing != nil ? "Edit Pricing" : "New Pricing",
                                view: view, size: NSSize(width: 500, height: 350))
        windows[windowId] = window
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Internal

    private func makeWindow<Content: View>(
        id: String, title: String, view: Content, size: NSSize
    ) -> NSWindow {
        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = size

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = WindowDelegate(onClose: { [weak self] in
            self?.windows.removeValue(forKey: id)
        })
        return window
    }

    private func closeWindow(_ id: String) {
        windows[id]?.close()
        windows.removeValue(forKey: id)
    }

    private func saveProfileDraft(_ draft: ProfileEditDraft, existingId: Int) {
        let profile = draft.toModelProfile(id: existingId)
        _ = db.saveProfile(profile)
    }
}

// MARK: - Window Delegate

private class WindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}

// MARK: - Editable Protocols

protocol EditableProfile {
    var id: Int { get }
    var name: String { get }
    var provider: String { get }
    var model: String { get }
    var baseUrl: String { get }
    var client: String { get }
    var envConfigJSON: String { get }
    var isActive: Bool { get }
}

extension ModelProfile: EditableProfile {}

protocol EditableProvider {
    var id: Int { get }
    var provider: String { get }
    var providerType: String { get }
    var displayName: String { get }
    var baseUrl: String { get }
    var modelsJSON: String { get }
}

extension ProviderConfig: EditableProvider {}

protocol EditablePricing {
    var id: Int { get }
    var provider: String { get }
    var model: String { get }
    var currency: String { get }
    var inputCacheHitPrice: Double { get }
    var inputCacheMissPrice: Double { get }
    var outputPrice: Double { get }
    var isCustom: Bool { get }
}

extension ModelPricing: EditablePricing {}

// EditableBudget removed in v1.3.2 — Budget feature deleted
