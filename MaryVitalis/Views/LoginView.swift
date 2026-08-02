import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var profile: ProfileStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Theme.defaultAccent)
                        .frame(width: 64, height: 64)
                        .background(Theme.defaultAccent.opacity(0.13),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("MARY VITALIS")
                        .font(.caption.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(Theme.textFaint)
                    Text("Accedi una sola volta")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("Il profilo scelto determina schede, recupero, widget e recap. La sessione resta memorizzata in modo sicuro su questo iPhone.")
                        .font(.body)
                        .foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Scegli account")
                        .font(.headline)
                        .foregroundStyle(Theme.text)

                    ForEach(AccountData.all) { account in
                        accountButton(account)
                    }
                }

                Label("Modalità locale TestFlight: è una selezione profilo, non ancora un login con password e server.",
                      systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background { Theme.background }
    }

    private func accountButton(_ account: AppAccount) -> some View {
        Button {
            profile.signIn(accountID: account.id)
            Feedback.success()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: account.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(roleColor(account.role))
                    .frame(width: 46, height: 46)
                    .background(roleColor(account.role).opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(account.displayName)
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        Text(account.role.title.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .tracking(0.7)
                            .foregroundStyle(roleColor(account.role))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(roleColor(account.role).opacity(0.12), in: Capsule())
                    }
                    Text(account.role.detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textDim)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(roleColor(account.role))
            }
            .frame(minHeight: 64)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
                .stroke(Theme.border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Accedi come \(account.displayName), ruolo \(account.role.title)")
    }

    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .member: Theme.defaultAccent
        case .trainer: Color(hex: "#f59e0b")
        case .admin: Color(hex: "#a78bfa")
        }
    }
}
