import SwiftUI
import LocalAuthentication

struct PrivateVaultView: View {
    @State private var isUnlocked = false
    @State private var authenticationError: String? = nil
    
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            if isUnlocked {
                unlockedView
            } else {
                lockedView
            }
        }
        .navigationTitle("Private Vault")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            authenticate()
        }
    }
    
    // MARK: - Views
    
    private var lockedView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.Colors.mint)
            
            Text("Vault Locked")
                .font(Theme.Typography.title())
                .foregroundStyle(Theme.Colors.ink)
            
            Text("Use Face ID or Passcode to access your hidden items.")
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            
            if let error = authenticationError {
                Text(error)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.coral)
                    .padding(.top, Theme.Spacing.sm)
            }
            
            Spacer()
            
            PrimaryButton("Unlock Vault", icon: "faceid") {
                authenticate()
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
    
    private var unlockedView: some View {
        VStack {
            EmptyStateView(
                icon: "archivebox",
                title: "Vault is Empty",
                message: "You haven't added any items to your private vault yet. Select items from your library and move them here to keep them safe.",
                actionTitle: "Lock Vault"
            ) {
                isUnlocked = false
            }
        }
    }
    
    // MARK: - Logic
    
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        // Check if device supports biometrics
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Unlock your private vault."
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        withAnimation {
                            self.isUnlocked = true
                            self.authenticationError = nil
                        }
                    } else {
                        if let authError = authError as? LAError {
                            switch authError.code {
                            case .userCancel, .systemCancel:
                                // Don't show error for cancellation
                                break
                            default:
                                self.authenticationError = authError.localizedDescription
                            }
                        }
                    }
                }
            }
        } else {
            // Device does not support biometrics or passcode
            DispatchQueue.main.async {
                self.authenticationError = error?.localizedDescription ?? "Authentication not available."
                
                #if targetEnvironment(simulator)
                // Fallback for simulator if biometrics aren't configured
                withAnimation {
                    self.isUnlocked = true
                }
                #endif
            }
        }
    }
}

#Preview {
    NavigationStack {
        PrivateVaultView()
    }
}
