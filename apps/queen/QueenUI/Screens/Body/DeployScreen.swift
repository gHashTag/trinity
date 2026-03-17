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
            VStack(spacing: TrinityTheme.spacing) {
                HStack {
                    Text("🚀")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("DEPLOY")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text("Railway Cloud Infrastructure")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                    ActionButton(icon: "🔄", label: "Redeploy", color: TrinityTheme.golden,
                                 action: "redeploy")
                }
                .padding()

                // Summary
                let totalServices = accounts.reduce(0) { $0 + ($1.active_services ?? 0) }
                let validTokens = accounts.filter { $0.token_status == "valid" }.count

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(label: "Accounts", value: "\(accounts.count)", accent: TrinityTheme.accent)
                    StatCard(label: "Active Services", value: "\(totalServices)", accent: TrinityTheme.golden)
                    StatCard(label: "Valid Tokens", value: "\(validTokens)/\(accounts.count)", accent: validTokens == accounts.count ? TrinityTheme.statusOK : TrinityTheme.statusWarn)
                }
                .padding(.horizontal)

                // Account details
                ForEach(accounts) { acct in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(acct.alias ?? "account-\(acct.account_id)")
                                    .font(.headline)
                                    .foregroundStyle(TrinityTheme.textPrimary)
                                Text("#\(acct.account_id)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(TrinityTheme.textMuted)
                            }
                            HStack(spacing: 16) {
                                Label("\(acct.active_services ?? 0) services", systemImage: "server.rack")
                                    .font(.caption)
                                    .foregroundStyle(TrinityTheme.textMuted)
                                Label("\(acct.daily_creates ?? 0)/\(acct.max_daily_creates ?? 50) creates", systemImage: "plus.circle")
                                    .font(.caption)
                                    .foregroundStyle(TrinityTheme.textMuted)
                            }
                        }
                        Spacer()
                        StatusBadge(status: acct.token_status == "valid" ? .up : .down)
                    }
                    .padding()
                    .background(TrinityTheme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                    .padding(.horizontal)
                }

                if accounts.isEmpty {
                    VStack(spacing: 12) {
                        Text("No Railway farm data")
                            .font(.headline)
                            .foregroundStyle(TrinityTheme.textPrimary)
                        Text(".trinity/railway_farm.json not found")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                }
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
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
