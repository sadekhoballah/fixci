import '../../core/models/service_category.dart';

enum VerificationRole { craftsman, client }

/// Google Vision auto-check verdict attached to an uploaded document, as
/// returned in each `/admin/verifications` entry (`idAutoCheck` /
/// `licenseAutoCheck`). Advisory only — it pre-scores the queue, the admin
/// still decides. Null on the entry when Vision wasn't consulted.
enum IdAutoCheckVerdict { pass, uncertain, reject }

class IdAutoCheck {
  const IdAutoCheck({
    required this.verdict,
    required this.score,
    required this.reasons,
    required this.degraded,
    this.at,
  });

  final IdAutoCheckVerdict verdict;
  final int score;
  final List<String> reasons;
  // True when Vision itself couldn't run (unconfigured / error / timeout) —
  // the verdict is then always `uncertain` and means nothing on its own.
  final bool degraded;
  final DateTime? at;

  static IdAutoCheck? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final verdict = switch (json['verdict']) {
      'pass' => IdAutoCheckVerdict.pass,
      'reject' => IdAutoCheckVerdict.reject,
      _ => IdAutoCheckVerdict.uncertain,
    };
    return IdAutoCheck(
      verdict: verdict,
      score: (json['score'] as num?)?.toInt() ?? 0,
      reasons:
          (json['reasons'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      degraded: json['degraded'] as bool? ?? false,
      at: json['at'] == null ? null : DateTime.tryParse(json['at'] as String),
    );
  }
}

class PendingVerification {
  const PendingVerification({
    required this.userId,
    required this.role,
    required this.fullName,
    required this.phone,
    required this.serviceCategory,
    required this.experienceDetails,
    required this.licenseVerified,
    required this.createdAt,
    this.idAutoCheck,
    this.licenseAutoCheck,
  });

  final String userId;
  final VerificationRole role;
  final String phone;
  final String? fullName;
  // Craftsman-only — null for a client entry.
  final ServiceCategory? serviceCategory;
  final String? experienceDetails;
  // Craftsman-only, meaningful only when serviceCategory.requiresDriverLicense
  // is true (taxi/camion) — whether the license half of KYC is done, so the
  // card can show its own preview/status independent of the ID card's.
  final bool licenseVerified;
  final DateTime createdAt;
  // Google Vision pre-check on the uploaded ID photo (and, taxi/camion only,
  // the license). Null when Vision wasn't consulted for this submission.
  final IdAutoCheck? idAutoCheck;
  final IdAutoCheck? licenseAutoCheck;
}

class AdminKycState {
  const AdminKycState({
    this.entries = const [],
    this.isLoading = true,
    this.errorMessage,
    this.processingUserIds = const {},
  });

  final List<PendingVerification> entries;
  final bool isLoading;
  final String? errorMessage;
  // Which cards currently have an Approve/Reject request in flight — keyed
  // by userId, so each card's buttons disable independently.
  final Set<String> processingUserIds;

  AdminKycState copyWith({
    List<PendingVerification>? entries,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    Set<String>? processingUserIds,
  }) {
    return AdminKycState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      processingUserIds: processingUserIds ?? this.processingUserIds,
    );
  }
}
