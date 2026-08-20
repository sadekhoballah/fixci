import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import 'report_reason.dart';

class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.fullName,
    required this.phone,
  });

  final String userId;
  final String? fullName;
  final String? phone;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
    userId: json['userId'] as String,
    fullName: json['fullName'] as String?,
    phone: json['phone'] as String?,
  );
}

// Backs both the report/block action (ReportBlockMenu, wherever the other
// party's contact info is shown) and the "Utilisateurs bloqués" management
// list (BlockedUsersScreen) — see backend/src/safety/safety.controller.ts.
class SafetyRepository {
  SafetyRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> reportUser(
    String userId, {
    required ReportReason reason,
    String? message,
    String? contextType,
    String? contextId,
  }) => _apiClient.post('/users/$userId/report', {
    'reason': reportReasonWireValue(reason),
    if (message != null && message.isNotEmpty) 'message': message,
    if (contextType != null) 'contextType': contextType,
    if (contextId != null) 'contextId': contextId,
  });

  Future<void> blockUser(String userId) =>
      _apiClient.post('/users/$userId/block', const {});

  Future<void> unblockUser(String userId) =>
      _apiClient.delete('/users/$userId/block');

  Future<List<BlockedUser>> getBlockedUsers() async {
    final response = await _apiClient.get('/users/blocked');
    return (response['items'] as List)
        .map((raw) => BlockedUser.fromJson(raw as Map<String, dynamic>))
        .toList();
  }
}

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepository(ref.watch(apiClientProvider)),
);
