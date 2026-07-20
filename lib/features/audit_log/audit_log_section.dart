import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audit_log_api.dart';
import 'audit_log_provider.dart';

/// Self-contained "Recent Activity" card. Shows the latest few audit log
/// entries by default; tapping "View more" expands into a paginated list
/// loaded straight from the same endpoint. Drop this anywhere — it manages
/// its own expand/collapse and pagination state internally.
class AuditLogSection extends ConsumerStatefulWidget {
  const AuditLogSection({super.key});
  @override
  ConsumerState<AuditLogSection> createState() => _AuditLogSectionState();
}

class _AuditLogSectionState extends ConsumerState<AuditLogSection> {
  final List<AuditLogEntry> _expanded = [];
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _isExpanded = false;

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    final lastId = _expanded.isNotEmpty ? _expanded.last.id : null;
    final page = await ref
        .read(auditLogApiProvider)
        .fetchLogs(limit: 15, beforeId: lastId);
    setState(() {
      _expanded.addAll(page.logs);
      _hasMore = page.hasMore;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstPageAsync = ref.watch(auditLogFirstPageProvider);
    return firstPageAsync.when(
      data: (page) {
        final entries = _isExpanded ? _expanded : page.logs;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No recent changes.')),
                  )
                else
                  ...entries.map(
                    (e) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.history, size: 18),
                      title: Text(
                        e.summary,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: e.createdAt != null
                          ? Text(
                              e.createdAt!,
                              style: const TextStyle(fontSize: 11),
                            )
                          : null,
                    ),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    if (!_isExpanded) {
                      setState(() {
                        _isExpanded = true;
                        _expanded
                          ..clear()
                          ..addAll(page.logs);
                        _hasMore = page.hasMore;
                      });
                    } else if (_hasMore) {
                      await _loadMore();
                    } else {
                      setState(() => _isExpanded = false);
                    }
                  },
                  icon: Icon(
                    _isExpanded && !_hasMore
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(
                    !_isExpanded
                        ? 'View more'
                        : (_hasMore
                              ? (_loadingMore ? 'Loading…' : 'Load more')
                              : 'Show less'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Could not load audit log: $e'),
    );
  }
}
