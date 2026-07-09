import SwiftUI

// MARK: - Budget Manager

struct BudgetManagerView: View {
    @ObservedObject var service: UsageService
    @State private var showAddSheet = false
    @State private var budgets: [Budget] = []
    @State private var balances: [Int: BudgetService.BalanceResult] = [:]
    @State private var dailySpending: [(String, Double)] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if budgets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "creditcard")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("暂无预算配置")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("添加预算后自动从使用量扣减")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(30)
                } else {
                    ForEach(budgets) { budget in
                        if let balance = balances[budget.id] {
                            BudgetCard(budget: budget, balance: balance)
                        }
                    }

                    // Daily trend (last 14 days)
                    if !dailySpending.isEmpty {
                        CardView(title: "每日花费趋势 (近14天)", icon: "chart.bar.fill") {
                            let maxSpend = dailySpending.map(\.1).max() ?? 1
                            HStack(alignment: .bottom, spacing: 4) {
                                ForEach(dailySpending, id: \.0) { day in
                                    VStack(spacing: 2) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.accentColor.opacity(0.6))
                                            .frame(height: maxSpend > 0 ? max(CGFloat(day.1 / maxSpend) * 40, 2) : 2)
                                        Text(String(day.0.suffix(5).dropFirst(3)))
                                            .font(.system(size: 7))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(height: 50)
                            .padding(.top, 4)
                        }
                    }
                }

                Button {
                    showAddSheet = true
                } label: {
                    Label("添加预算", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.top, 4)
            }
            .padding(12)
        }
        .frame(width: 340, height: 520)
        .onAppear { refresh() }
        .onChange(of: service.selectedTab, initial: false) { _, _ in refresh() }
        .sheet(isPresented: $showAddSheet) {
            BudgetEditSheet(service: service, onSave: { refresh() })
        }
    }

    private func refresh() {
        budgets = service.budgetService?.budgets ?? []
        var newBalances: [Int: BudgetService.BalanceResult] = [:]
        for budget in budgets where budget.isActive {
            newBalances[budget.id] = service.budgetService?.calculateBalance(budget)
        }
        balances = newBalances

        // Aggregate daily spending across all active budgets
        let globalProvider = budgets.first?.provider ?? ""
        dailySpending = service.budgetService?.dailySpending(provider: globalProvider, days: 14) ?? []
    }
}

// MARK: - Budget Card

struct BudgetCard: View {
    let budget: Budget
    let balance: BudgetService.BalanceResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.accentColor)
                    .font(.caption)
                Text(budget.name.isEmpty ? (budget.provider.isEmpty ? "全局预算" : "\(budget.provider) 预算") : budget.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(budget.periodType)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.12)))
            }

            // Balance line
            HStack {
                Text(CostFormatter.formatShort(balance.remaining))
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("/ \(CostFormatter.formatShort(budget.initialBalance))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("已用 \(CostFormatter.formatShort(balance.spent))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Progress bar
            ProgressBarView(value: balance.spentPercent / 100, color: progressColor, height: 6)

            // Stats
            HStack {
                StatItem(label: "日均", value: CostFormatter.formatShort(balance.dailyAverage))
                Spacer()
                if let runway = balance.runwayDays, runway.isFinite {
                    StatItem(label: "预计可用", value: "\(Int(runway)) 天")
                }
                Spacer()
                StatItem(label: "活跃", value: "\(balance.daysActive) 天")
            }
            .font(.caption)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    private var progressColor: Color {
        let pct = balance.spentPercent
        if pct > 85 { return .red }
        if pct > 60 { return .orange }
        return .green
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Add Budget Sheet

struct BudgetEditSheet: View {
    @ObservedObject var service: UsageService
    var existing: Budget? = nil
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var provider = ""
    @State private var initialBalance: Double = 1000
    @State private var currency = "CNY"
    @State private var periodType = "total"

    private let periodOptions = [
        ("total", "累计"),
        ("daily", "每日"),
        ("weekly", "每周"),
        ("monthly", "每月"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill").foregroundColor(.accentColor)
                Text(existing != nil ? "编辑预算" : "添加预算").font(.headline)
            }

            Group {
                TextField("名称 (可选)", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Provider (留空 = 全局)", text: $provider)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("初始余额")
                    Spacer()
                    TextField("", value: $initialBalance, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .monospacedDigit()
                }

                Picker("周期", selection: $periodType) {
                    ForEach(periodOptions, id: \.0) { opt in
                        Text(opt.1).tag(opt.0)
                    }
                }
            }
            .font(.subheadline)

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                Spacer()
                Button("保存") {
                    let budget = Budget(
                        id: existing?.id ?? 0,
                        name: name,
                        provider: provider,
                        initialBalance: initialBalance,
                        currency: currency,
                        periodType: periodType,
                        startDate: existing?.startDate ?? "",
                        isActive: true,
                        createdAt: existing?.createdAt ?? ""
                    )
                    service.budgetService?.saveBudget(budget)
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(initialBalance <= 0)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear {
            if let e = existing {
                name = e.name
                provider = e.provider
                initialBalance = e.initialBalance
                currency = e.currency
                periodType = e.periodType
            }
        }
    }
}
