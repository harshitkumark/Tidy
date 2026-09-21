import SwiftUI

#if DEBUG
struct TestModeView: View {
    @Environment(AppState.self) private var appState
    
    @State private var seeder = LibrarySeeder()
    @State private var seedCount: Double = 200
    @State private var isSeeding = false
    @State private var progressText = ""
    
    var body: some View {
        @Bindable var appState = appState
        
        List {
            Section {
                Toggle("Enable Test Mode", isOn: $appState.isTestMode)
                if appState.isTestMode {
                    Toggle("Dry Run (No real deletions)", isOn: $appState.isDryRun)
                        .tint(Theme.Colors.mint)
                    Toggle("Use Mock Data Providers", isOn: $appState.useMockData)
                        .tint(Theme.Colors.mint)
                    Toggle("Show Debug Overlay", isOn: $appState.showDebugOverlay)
                        .tint(Theme.Colors.mint)
                }
            } header: {
                Text("Global Toggles")
            } footer: {
                Text("Dry Run logs deletion intents to the console without calling PhotoKit/Contacts API. Mock Providers bypass the system library entirely.")
            }
            
            if appState.isTestMode {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Seed synthetic photos and videos into your real photo library to test scanning without private data.")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                        
                        HStack {
                            Text("Count:")
                            Slider(value: $seedCount, in: 50...5000, step: 50)
                            Text("\(Int(seedCount))")
                                .monospacedDigit()
                        }
                        
                        if isSeeding {
                            ProgressView(progressText)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            Button("Seed \(Int(seedCount)) Items") {
                                runSeeder()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.Colors.mint)
                            .frame(maxWidth: .infinity)
                        }
                        
                        Button("Remove Seeded Items", role: .destructive) {
                            removeSeededItems()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .disabled(isSeeding)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Photo Library Seeder")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Seed fake contacts with obvious duplicates. Tagged with 'TIDY_TEST'.")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                        
                        Button("Seed Contacts") {
                            seedContacts()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Colors.mint)
                        .frame(maxWidth: .infinity)
                        
                        Button("Remove Test Contacts", role: .destructive) {
                            removeContacts()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Contact Seeder")
                }
                
                Section {
                    Picker("Simulate Photo Permission", selection: $appState.simulatedPermissionState) {
                        ForEach(SimulatedPermission.allCases, id: \.self) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }
                    
                    Button("Reset Onboarding State") {
                        appState.hasCompletedOnboarding = false
                    }
                    .foregroundStyle(Theme.Colors.coral)
                    
                } header: {
                    Text("State Overrides")
                }
            }
        }
        .navigationTitle("Test Mode")
    }
    
    // MARK: - Actions
    
    private func runSeeder() {
        isSeeding = true
        progressText = "Starting..."
        
        Task {
            do {
                try await seeder.seedItems(count: Int(seedCount)) { progress in
                    Task { @MainActor in
                        self.progressText = progress
                    }
                }
                progressText = "Done!"
            } catch {
                progressText = "Error: \(error.localizedDescription)"
            }
            try? await Task.sleep(for: .seconds(2))
            isSeeding = false
        }
    }
    
    private func removeSeededItems() {
        // TODO: Wire this to DeletionService in Step 10
        Logger.info("Hook placeholder: Remove seeded items via DeletionService", category: .deletion)
    }
    
    private func seedContacts() {
        let contactSeeder = ContactSeeder()
        Task {
            do {
                try await contactSeeder.seed()
                Logger.info("Contacts seeded successfully", category: .general)
            } catch {
                Logger.error("Failed to seed contacts: \(error)", category: .general)
            }
        }
    }
    
    private func removeContacts() {
        // TODO: Wire this to DeletionService in Step 10
        Logger.info("Hook placeholder: Remove seeded contacts via DeletionService", category: .deletion)
    }
}

#Preview {
    NavigationStack {
        TestModeView()
            .environment(AppState())
    }
}
#endif
