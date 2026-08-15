class DirectoryEntry {
  const DirectoryEntry({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.districtName,
    required this.isOnline,
    this.serviceCategory,
  });

  final String userId;
  final String? fullName;
  final String phone;
  final String districtName;
  final bool isOnline;
  // Craftsmen only — null for clients.
  final String? serviceCategory;
}

enum DirectoryTab { clients, craftsmen }

class AdminDirectoryState {
  const AdminDirectoryState({
    this.tab = DirectoryTab.clients,
    this.entries = const [],
    this.isLoading = true,
    this.errorMessage,
    this.search = '',
    this.category,
    this.processingIds = const {},
  });

  final DirectoryTab tab;
  final List<DirectoryEntry> entries;
  final bool isLoading;
  final String? errorMessage;
  final String search;
  // Craftsmen tab only — the ServiceCategory wire value, or null for all.
  final String? category;
  // Which rows currently have a cancel-mission/delete request in flight.
  final Set<String> processingIds;

  AdminDirectoryState copyWith({
    DirectoryTab? tab,
    List<DirectoryEntry>? entries,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? search,
    String? category,
    bool clearCategory = false,
    Set<String>? processingIds,
  }) {
    return AdminDirectoryState(
      tab: tab ?? this.tab,
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      search: search ?? this.search,
      category: clearCategory ? null : (category ?? this.category),
      processingIds: processingIds ?? this.processingIds,
    );
  }
}
