import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'db_explorer_api.dart';
import 'db_explorer_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/constants/layout_constants.dart';

/// Thin standalone wrapper — used by the /db-explorer route (reachable via
/// the quick-link chip on the Account/Me screen). The actual UI lives in
/// [DbExplorerView] so it can also be embedded as a tab inside BusinessScreen
/// without a duplicate/nested AppBar.
class DbExplorerScreen extends StatelessWidget {
  const DbExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DB Explorer')),
      body: const DbExplorerView(),
    );
  }
}

class DbExplorerView extends ConsumerStatefulWidget {
  const DbExplorerView({super.key});

  @override
  ConsumerState<DbExplorerView> createState() => _DbExplorerViewState();
}

class _DbExplorerViewState extends ConsumerState<DbExplorerView> {
  final _sqlCtrl = TextEditingController();
  String? _selectedTable;
  int _limit = 200;
  bool _loading = false;
  String? _error;
  QueryResult? _result;

  @override
  void dispose() {
    _sqlCtrl.dispose();
    super.dispose();
  }

  void _pickTable(DbTable table) {
    setState(() {
      _selectedTable = table.name;
      _sqlCtrl.text = 'SELECT * FROM ${table.name}';
    });
    _run();
  }

  Future<void> _run() async {
    final sql = _sqlCtrl.text.trim();
    if (sql.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(dbExplorerApiProvider)
          .runQuery(sql, limit: _limit);
      setState(() => _result = result);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _result = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(dbTablesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: tablesAsync.when(
            data: (tables) => ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: tables.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final t = tables[i];
                final selected = _selectedTable == t.name;
                return ChoiceChip(
                  label: Text(t.name),
                  selected: selected,
                  onSelected: (_) => _pickTable(t),
                  labelStyle: TextStyle(
                    fontFamily: 'IBMPlexMono',
                    fontSize: 12,
                    color: selected ? AppColors.parchment : null,
                  ),
                  selectedColor: AppColors.maroon,
                  backgroundColor: scheme.surfaceContainerLow,
                );
              },
            ),
            loading: () => const Center(
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Center(
              child: Text(
                'Could not load tables: $e',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _sqlCtrl,
                maxLines: 4,
                minLines: 2,
                style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'SELECT * FROM products WHERE category = ?',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _run,
                      icon: _loading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.parchment,
                              ),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(_loading ? 'Running…' : 'Run Query'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: _limit,
                    underline: const SizedBox(),
                    items: const [50, 100, 200, 500]
                        .map(
                          (n) => DropdownMenuItem(
                            value: n,
                            child: Text('$n rows'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _limit = v);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.paprika.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.paprika.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.paprika,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.paprika,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(child: _buildResults(context)),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_result == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Pick a table above or write a SELECT query, then tap Run.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final result = _result!;
    if (result.rows.isEmpty) {
      return const Center(child: Text('Query ran fine — no rows returned.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            result.truncated
                ? '${result.rowCount} row(s) · showing up to $_limit'
                : '${result.rowCount} row(s)',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: LayoutConstants.navBarClearance,
              ),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    scheme.surfaceContainerLow,
                  ),
                  columns: result.columns
                      .map(
                        (c) => DataColumn(
                          label: Text(
                            c,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  rows: result.rows
                      .map(
                        (row) => DataRow(
                          cells: result.columns
                              .map(
                                (c) => DataCell(
                                  Text(
                                    _cellText(row[c]),
                                    style: AppTypography.ledger(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: row[c] == null
                                          ? scheme.onSurfaceVariant
                                          : scheme.onSurface,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _cellText(dynamic value) => value == null ? '—' : value.toString();
}
