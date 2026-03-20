import SwiftUI

struct DeployScreen: View {
    @State private var accounts: [RailwayAccount] = []
    @State private var agentMap: [[String: Any]] = []

    struct RailwayAccount: Codable, Identifiable {
        let account_id: Int
        let alias: String?
        let daily_creates: Int?
        let active_services: Int?
        let max_concurrent: Int?
        let max_daily_creates: Int?
        let token_status: String?

        var id: Int { account_id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("🚀")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("DEPLOY")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("Railway Cloud Infrastructure")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    ActionButton(icon: "🔄", label: "Redeploy", color: V4Color.golden,
                                 action: "redeploy")
                }
                .padding()

                // Summary
                let totalServices = accounts.reduce(0) { $0 + ($1.active_services ?? 0) }
                let validTokens = accounts.filter { $0.token_status == "valid" }.count

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                    StatCard(label: "Accounts", value: "\(accounts.count)", accent: V4Color.accent)
                    StatCard(label: "Active Services", value: "\(totalServices)", accent: V4Color.golden)
                    StatCard(label: "Valid Tokens", value: "\(validTokens)/\(accounts.count)", accent: validTokens == accounts.count ? V4Color.statusOK : V4Color.statusWarn)
                }
                .padding(.horizontal)

                // Account details
                ForEach(accounts) { acct in
                    HStack(spacing: ParietalSpacing.md) {
                        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                            HStack {
                                Text(acct.alias ?? "account-\(acct.account_id)")
                                    .font(.headline)
                                    .foregroundStyle(V4Color.textPrimary)
                                Text("#\(acct.account_id)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(V4Color.textSecondary)
                            }
                            HStack(spacing: ParietalSpacing.lg) {
                                Label("\(acct.active_services ?? 0) services", systemImage: "server.rack")
                                    .font(.caption)
                                    .foregroundStyle(V4Color.textSecondary)
                                Label("\(acct.daily_creates ?? 0)/\(acct.max_daily_creates ?? 50) creates", systemImage: "plus.circle")
                                    .font(.caption)
                                    .foregroundStyle(V4Color.textSecondary)
                            }
                        }
                        Spacer()
                        StatusBadge(status: acct.token_status == "valid" ? .up : .down)
                    }
                    .padding()
                    .background(V4Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                    .padding(.horizontal)
                }

                if accounts.isEmpty {
                    VStack(spacing: ParietalSpacing.md) {
                        Text("No Railway farm data")
                            .font(.headline)
                            .foregroundStyle(V4Color.textPrimary)
                        Text(".trinity/railway_farm.json not found")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                }
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
        .onAppear { loadDeploy() }
    }

    private func loadDeploy() {
        let path = "\(FileManager.default.currentDirectoryPath)/.trinity/railway_farm.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let acctArray = json["accounts"] as? [[String: Any]] else { return }

        let decoder = JSONDecoder()
        if let acctData = try? JSONSerialization.data(withJSONObject: acctArray) {
            accounts = (try? decoder.decode([RailwayAccount].self, from: acctData)) ?? []
        }
    }
}
