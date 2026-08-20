import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../blocked_users_controller.dart';
import '../safety_repository.dart';

// Self-service, reversible — see UserBlock's class-level comment on the
// backend. Pushed from account_screen.dart / client_account_screen.dart,
// next to the Privacy Policy / Terms of Service links.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(blockedUsersControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });
    final state = ref.watch(blockedUsersControllerProvider);
    final controller = ref.read(blockedUsersControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockedUsersScreenTitle)),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.items.isEmpty
            ? Center(
                child: Text(
                  l10n.noBlockedUsersMessage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: state.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return _BlockedUserTile(
                      user: item,
                      isProcessing: state.processingUserIds.contains(
                        item.userId,
                      ),
                      onUnblock: () => controller.unblock(item.userId),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.user,
    required this.isProcessing,
    required this.onUnblock,
  });

  final BlockedUser user;
  final bool isProcessing;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              user.fullName ?? user.phone ?? '—',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: isProcessing ? null : onUnblock,
            child: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.unblockButton),
          ),
        ],
      ),
    );
  }
}
