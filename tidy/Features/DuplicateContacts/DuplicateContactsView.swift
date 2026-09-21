import SwiftUI

struct DuplicateContactsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: DuplicateContactsViewModel
    
    init(contactProvider: ContactsProviding = ContactService()) {
        #if DEBUG
        let useMock = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let provider = useMock ? MockContacts() : contactProvider
        _viewModel = State(initialValue: DuplicateContactsViewModel(contactProvider: provider))
        #else
        _viewModel = State(initialValue: DuplicateContactsViewModel(contactProvider: contactProvider))
        #endif
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView("Scanning Contacts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.groups.isEmpty {
                EmptyStateView(
                    icon: "person.2.slash",
                    title: "No Duplicates",
                    message: "Your contacts are perfectly organized."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(viewModel.groups) { group in
                            ContactGroupCard(
                                group: group,
                                willMerge: viewModel.hasOperation(for: group.id),
                                onToggle: { viewModel.toggleOperation(for: group.id) }
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
            }
            
            // Selection Floating Bar
            VStack {
                Spacer()
                SelectionBar(
                    count: viewModel.selectedCount,
                    totalSize: nil, // Contacts don't really free up meaningful bytes
                    actionTitle: "Review Merges"
                ) {
                    reviewSelection()
                }
            }
        }
        .navigationTitle("Duplicate Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if appState.isTestMode && appState.useMockData {
                viewModel = DuplicateContactsViewModel(contactProvider: MockContacts())
            }
            await viewModel.load()
        }
    }
    
    private func reviewSelection() {
        appState.cleanupSelection.contactMergeGroups = viewModel.operations
        // TODO: Navigate to Review View
        Logger.info("Ready for Review: \(viewModel.operations.count) contact merges", category: .general)
    }
}

// MARK: - Group Card

private struct ContactGroupCard: View {
    let group: ContactGroup
    let willMerge: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(group.contacts.count) Duplicates")
                            .font(Theme.Typography.headline())
                            .foregroundStyle(Theme.Colors.ink)
                        Text("Matched by \(group.matchReason)")
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: onToggle) {
                        HStack {
                            Image(systemName: willMerge ? "checkmark.circle.fill" : "circle")
                            Text(willMerge ? "Merge" : "Skip")
                        }
                        .font(Theme.Typography.caption().bold())
                        .foregroundStyle(willMerge ? .white : Theme.Colors.inkSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(willMerge ? Theme.Colors.mint : Theme.Colors.cloud)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                // Contact Items
                ForEach(group.contacts) { contact in
                    let isBase = contact.id == group.baseContactID
                    
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        // Avatar
                        Circle()
                            .fill(isBase ? Theme.Colors.mint.opacity(0.2) : Theme.Colors.cloud)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(contact.givenName.prefix(1))
                                    .font(.headline)
                                    .foregroundStyle(isBase ? Theme.Colors.mint : Theme.Colors.inkSecondary)
                            )
                        
                        // Details
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(contact.fullName.isEmpty ? "No Name" : contact.fullName)
                                    .font(Theme.Typography.body())
                                    .foregroundStyle(Theme.Colors.ink)
                                
                                if isBase {
                                    Text("BASE")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Theme.Colors.mint)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            
                            if !contact.phoneNumbers.isEmpty {
                                Text(contact.phoneNumbers.joined(separator: ", "))
                                    .font(Theme.Typography.caption())
                                    .foregroundStyle(Theme.Colors.inkSecondary)
                            }
                            
                            if !contact.emailAddresses.isEmpty {
                                Text(contact.emailAddresses.joined(separator: ", "))
                                    .font(Theme.Typography.caption())
                                    .foregroundStyle(Theme.Colors.inkSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        DuplicateContactsView(contactProvider: MockContacts())
            .environment(AppState())
    }
}
