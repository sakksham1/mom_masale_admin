import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'careers_api.dart';
import 'careers_provider.dart';
import 'job_edit_screen.dart';
import 'application_detail_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/tap_scale.dart';
import '../../shared/widgets/staggered_fade_in.dart';

// ── Status visuals ──────────────────────────────────────────────────────

String jobStatusLabel(String s) {
  switch (s) {
    case 'draft':
      return 'Draft';
    case 'published':
      return 'Published';
    case 'paused':
      return 'Paused';
    case 'closed':
      return 'Closed';
    case 'archived':
      return 'Archived';
    default:
      return s;
  }
}

Color jobStatusColor(String s) {
  switch (s) {
    case 'draft':
      return const Color(0xFF8A97A3);
    case 'published':
      return const Color(0xFF2E7D32);
    case 'paused':
      return AppColors.turmeric;
    case 'closed':
      return AppColors.paprika;
    case 'archived':
      return const Color(0xFF5A6B7A);
    default:
      return Colors.grey;
  }
}

IconData jobStatusIcon(String s) {
  switch (s) {
    case 'draft':
      return Icons.edit_note;
    case 'published':
      return Icons.public;
    case 'paused':
      return Icons.pause_circle_outline;
    case 'closed':
      return Icons.block;
    case 'archived':
      return Icons.archive_outlined;
    default:
      return Icons.help_outline;
  }
}

String appStatusLabel(String s) {
  switch (s) {
    case 'new':
      return 'New';
    case 'screening':
      return 'Screening';
    case 'shortlisted':
      return 'Shortlisted';
    case 'interview':
      return 'Interview';
    case 'offered':
      return 'Offered';
    case 'hired':
      return 'Hired';
    case 'rejected':
      return 'Rejected';
    case 'withdrawn':
      return 'Withdrawn';
    default:
      return s;
  }
}

Color appStatusColor(String s) {
  switch (s) {
    case 'new':
      return const Color(0xFF8A97A3);
    case 'screening':
      return AppColors.turmeric;
    case 'shortlisted':
      return AppColors.paprika;
    case 'interview':
      return AppColors.maroon;
    case 'offered':
      return const Color(0xFF3D8B5F);
    case 'hired':
      return const Color(0xFF2E7D32);
    case 'rejected':
      return const Color(0xFFC62828);
    case 'withdrawn':
      return const Color(0xFF8A97A3);
    default:
      return Colors.grey;
  }
}

IconData appStatusIcon(String s) {
  switch (s) {
    case 'new':
      return Icons.fiber_new_outlined;
    case 'screening':
      return Icons.search;
    case 'shortlisted':
      return Icons.star_outline;
    case 'interview':
      return Icons.groups_outlined;
    case 'offered':
      return Icons.local_offer_outlined;
    case 'hired':
      return Icons.check_circle_outline;
    case 'rejected':
      return Icons.cancel_outlined;
    case 'withdrawn':
      return Icons.undo;
    default:
      return Icons.help_outline;
  }
}

String formatShortDate(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  var iso = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
  if (!iso.endsWith('Z') && !iso.contains('+')) iso += 'Z';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

class _StatusChipBar extends StatelessWidget {
  final String? selected;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String Function(String) label;
  const _StatusChipBar({
    required this.selected,
    required this.options,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label(o)),
                selected: selected == o,
                onSelected: (_) => onChanged(o),
              ),
            ),
        ],
      ),
    );
  }
}

class CareersScreen extends StatefulWidget {
  const CareersScreen({super.key});
  @override
  State<CareersScreen> createState() => _CareersScreenState();
}

class _CareersScreenState extends State<CareersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Careers'),
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(text: 'Jobs'),
            Tab(text: 'Applications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [_JobsTab(), _ApplicationsTab()],
      ),
    );
  }
}

// ── Jobs tab ─────────────────────────────────────────────────────────────

class _JobsTab extends ConsumerStatefulWidget {
  const _JobsTab();
  @override
  ConsumerState<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends ConsumerState<_JobsTab> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(careerJobsProvider(_status));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: LayoutConstants.fabScaffoldExtraPadding,
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            Haptics.tap();
            final created = await Navigator.of(context, rootNavigator: true)
                .push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const JobEditScreen(job: null),
                  ),
                );
            if (created == true) ref.invalidate(careerJobsProvider);
          },
          icon: const Icon(Icons.add),
          label: const Text('New Job'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _StatusChipBar(
              selected: _status,
              options: careerJobStatuses,
              label: jobStatusLabel,
              onChanged: (s) => setState(() => _status = s),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(careerJobsProvider),
              child: jobsAsync.when(
                data: (jobs) {
                  if (jobs.isEmpty) {
                    return ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 64),
                          child: Center(
                            child: Text('No jobs in this status yet.'),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      LayoutConstants.navBarClearance +
                          LayoutConstants.fabScaffoldExtraPadding,
                    ),
                    itemCount: jobs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => StaggeredFadeIn(
                      key: ValueKey('job_fade_${jobs[i].id}'),
                      index: i,
                      child: _JobCard(
                        key: ValueKey('job_${jobs[i].id}'),
                        job: jobs[i],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load jobs: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  final CareerJob job;
  const _JobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final color = jobStatusColor(job.status);

    return TapScale(
      scaleDown: 0.985,
      onTap: () async {
        final changed = await Navigator.of(context, rootNavigator: true)
            .push<bool>(
              MaterialPageRoute(builder: (_) => JobEditScreen(job: job)),
            );
        if (changed == true) ref.invalidate(careerJobsProvider);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(jobStatusIcon(job.status), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      job.department,
                      job.location,
                    ].where((s) => s != null && s.isNotEmpty).join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          jobStatusLabel(job.status),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      _MiniTag(job.workplaceType.replaceAll('_', ' ')),
                      _MiniTag(job.employmentType.replaceAll('_', ' ')),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag(this.label);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── Applications tab ─────────────────────────────────────────────────────

class _ApplicationsTab extends ConsumerStatefulWidget {
  const _ApplicationsTab();
  @override
  ConsumerState<_ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends ConsumerState<_ApplicationsTab> {
  String? _status;
  int? _jobId;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(careerJobsProvider(null));
    final appsAsync = ref.watch(
      careerApplicationsProvider((status: _status, jobId: _jobId)),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search applicant name or email…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _StatusChipBar(
            selected: _status,
            options: careerApplicationStatuses,
            label: appStatusLabel,
            onChanged: (s) => setState(() => _status = s),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: jobsAsync.maybeWhen(
            data: (jobs) => Align(
              alignment: Alignment.centerLeft,
              child: DropdownButton<int?>(
                value: _jobId,
                underline: const SizedBox(),
                hint: const Text('Filter by role'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All roles'),
                  ),
                  for (final j in jobs)
                    DropdownMenuItem<int?>(value: j.id, child: Text(j.title)),
                ],
                onChanged: (v) => setState(() => _jobId = v),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(careerApplicationsProvider),
            child: appsAsync.when(
              data: (apps) {
                final filtered = _query.isEmpty
                    ? apps
                    : apps.where((a) {
                        final q = _query.toLowerCase();
                        return a.name.toLowerCase().contains(q) ||
                            a.email.toLowerCase().contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 64),
                        child: Center(
                          child: Text(
                            apps.isEmpty
                                ? 'No applications yet.'
                                : 'No matches for "$_query".',
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    LayoutConstants.navBarClearance,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => StaggeredFadeIn(
                    key: ValueKey('app_fade_${filtered[i].id}'),
                    index: i,
                    child: _ApplicationCard(
                      key: ValueKey('app_${filtered[i].id}'),
                      application: filtered[i],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Could not load applications: $e')),
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final CareerApplication application;
  const _ApplicationCard({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = appStatusColor(application.status);

    return TapScale(
      scaleDown: 0.985,
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) =>
              ApplicationDetailScreen(applicationId: application.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                appStatusIcon(application.status),
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    application.jobTitle ?? 'Unknown role',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Applied ${formatShortDate(application.createdAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                appStatusLabel(application.status),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
