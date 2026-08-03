import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/service_category.dart';
import '../../../l10n/app_localizations.dart';
import '../craftsman_jobs_controller.dart';
import '../craftsman_jobs_state.dart';

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}

(Color, Color, String) _statusStyle(
  JobHistoryStatus status,
  AppLocalizations l10n,
) => switch (status) {
  JobHistoryStatus.assigned => (
    const Color(0xFFE3F2FD),
    const Color(0xFF1565C0),
    l10n.statusAssigned,
  ),
  JobHistoryStatus.inProgress => (
    const Color(0xFFFFF3CD),
    const Color(0xFF7A5B00),
    l10n.statusInProgress,
  ),
  JobHistoryStatus.completed => (
    const Color(0xFFE0F2E9),
    const Color(0xFF1B8A3B),
    l10n.statusCompleted,
  ),
  JobHistoryStatus.cancelled => (
    const Color(0xFFFDE8E8),
    const Color(0xFFC62828),
    l10n.statusCancelled,
  ),
  JobHistoryStatus.expired => (
    const Color(0xFFF0F0F0),
    const Color(0xFF757575),
    l10n.statusExpired,
  ),
};

class CraftsmanJobsScreen extends ConsumerStatefulWidget {
  const CraftsmanJobsScreen({super.key});

  @override
  ConsumerState<CraftsmanJobsScreen> createState() =>
      _CraftsmanJobsScreenState();
}

class _CraftsmanJobsScreenState extends ConsumerState<CraftsmanJobsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(craftsmanJobsControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(craftsmanJobsControllerProvider);
    final controller = ref.read(craftsmanJobsControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTab)),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.entries.isEmpty
            ? Center(
                child: Text(
                  state.errorMessage ?? l10n.noJobsYetMessage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: state.entries.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.entries.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _JobHistoryTile(entry: state.entries[index]);
                  },
                ),
              ),
      ),
    );
  }
}

class _JobHistoryTile extends StatelessWidget {
  const _JobHistoryTile({required this.entry});

  final JobHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final (chipBg, chipFg, chipLabel) = _statusStyle(entry.status, l10n);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              entry.serviceCategory.icon,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.clientFullName ??
                      entry.serviceCategory.localizedLabel(l10n),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(entry.createdAt),
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (entry.ratingStars != null) ...[
            Icon(Icons.star_rounded, size: 14, color: const Color(0xFFFFC107)),
            const SizedBox(width: 2),
            Text('${entry.ratingStars}', style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              chipLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: chipFg),
            ),
          ),
        ],
      ),
    );
  }
}
