class DirectoryEntry {
  const DirectoryEntry({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.districtName,
    required this.countryCode,
    required this.isOnline,
    required this.phoneVerified,
    this.serviceCategory,
    this.idVerified,
    this.isActive,
    this.averageRating,
    this.ratingsCount,
    this.completedCount,
    this.assignedCount,
  });

  final String userId;
  final String? fullName;
  final String phone;
  final String districtName;
  final String countryCode;
  final bool isOnline;
  // False for a client who signed up but hasn't confirmed their number yet
  // (they do it once, at their first request).
  final bool phoneVerified;
  // Everything below is craftsmen-only — null for clients.
  final String? serviceCategory;
  final double? averageRating;
  final int? ratingsCount;
  final int? completedCount;
  final int? assignedCount;
  final bool? idVerified;
  final bool? isActive;
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
