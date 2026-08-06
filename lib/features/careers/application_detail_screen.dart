import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'careers_api.dart';
import 'careers_provider.dart';
import 'careers_screen.dart'
    show appStatusLabel, appStatusColor, appStatusIcon, formatShortDate;
import '../../core/network/api_exception.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/swipe_confirm_sheet.dart';

class ApplicationDetailScreen extends ConsumerStatefulWidget {
  final int applicationId;
  const ApplicationDetailScreen({super.key, required this.applicationId});

  @override
  ConsumerState<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState
    extends ConsumerState<ApplicationDetailScreen> {
  bool _downloading = false;
  bool _deciding = false;

  Future<void> _downloadResume(ResumeInfo resume) async {
    setState(() => _downloading = true);
    try {
      final path = await ref
          .read(careersApiProvider)
          .downloadResume(
            applicationId: widget.applicationId,
            filename: resume.filename ?? 'resume',
          );
      Haptics.success();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved to app storage: $path')));
      }
    } catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not download CV: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _changeStatus(CareerApplication app) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusPickerSheet(current: app.status),
    );
    if (chosen == null || chosen == app.status || !mounted) return;

    String? note;
    if (chosen == 'rejected') {
      note = await _askNote('Reason for rejecting (optional)');
    }

    final color = appStatusColor(chosen);
    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: appStatusIcon(chosen),
      color: color,
      message: Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            const TextSpan(text: 'Move '),
            TextSpan(
              text: app.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: ' to '),
            TextSpan(
              text: appStatusLabel(chosen),
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
            const TextSpan(
              text: '? This notifies the applicant by email where applicable.',
            ),
          ],
        ),
      ),
      swipeLabel: 'Slide to confirm',
    );
    if (!confirmed) return;

    setState(() => _deciding = true);
    try {
      await ref
          .read(careersApiProvider)
          .updateApplicationStatus(
            id: widget.applicationId,
            status: chosen,
            note: note,
          );
      Haptics.success();
      ref.invalidate(careerApplicationDetailProvider(widget.applicationId));
      ref.invalidate(careerApplicationsProvider);
      if (mounted) {
        await SuccessPulse.show(context, 'Moved to ${appStatusLabel(chosen)}');
      }
    } on ApiException catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _deciding = false);
    }
  }

  Future<String?> _askNote(String label) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      careerApplicationDetailProvider(widget.applicationId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Application')),
      body: detailAsync.when(
        data: (detail) => _buildBody(detail),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load application: $e')),
      ),
    );
  }

  Widget _buildBody(CareerApplicationDetail detail) {
    final app = detail.application;
    final scheme = Theme.of(context).colorScheme;
    final color = appStatusColor(app.status);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.16),
                color.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(appStatusIcon(app.status), color: color, size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                app.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                app.jobTitle ?? 'Unknown role',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  appStatusLabel(app.status),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Contact',
          icon: Icons.badge_outlined,
          children: [
            _Row(icon: Icons.mail_outline, label: 'Email', value: app.email),
            _Row(icon: Icons.call_outlined, label: 'Phone', value: app.phone),
            if (app.location != null && app.location!.isNotEmpty)
              _Row(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: app.location!,
              ),
            if (app.portfolioUrl != null && app.portfolioUrl!.isNotEmpty)
              _Row(
                icon: Icons.link,
                label: 'Portfolio / LinkedIn',
                value: app.portfolioUrl!,
              ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Background',
          icon: Icons.school_outlined,
          children: [
            if (app.education != null && app.education!.isNotEmpty)
              _Row(
                icon: Icons.school_outlined,
                label: 'Education',
                value: app.education!,
              ),
            if (app.experience != null && app.experience!.isNotEmpty)
              _Row(
                icon: Icons.work_history_outlined,
                label: 'Experience',
                value: app.experience!,
              ),
            if (app.expectedSalary != null && app.expectedSalary!.isNotEmpty)
              _Row(
                icon: Icons.payments_outlined,
                label: 'Expected salary',
                value: app.expectedSalary!,
              ),
            _Row(
              icon: Icons.event_outlined,
              label: 'Applied',
              value: formatShortDate(app.createdAt),
            ),
          ],
        ),
        if (app.coverLetter != null && app.coverLetter!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Cover Letter',
            icon: Icons.article_outlined,
            children: [
              Text(
                app.coverLetter!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _Section(
          title: 'CV',
          icon: Icons.description_outlined,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    app.resume.filename ?? 'resume',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _downloading
                      ? null
                      : () => _downloadResume(app.resume),
                  icon: _downloading
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 18),
                  label: Text(_downloading ? 'Saving…' : 'Download'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Activity',
          icon: Icons.history,
          children: detail.events.isEmpty
              ? [
                  Text(
                    'No activity recorded yet.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ]
              : detail.events
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.circle, size: 8),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.toStatus != null
                                        ? 'Moved to ${appStatusLabel(e.toStatus!)}'
                                        : e.eventType,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (e.note != null && e.note!.isNotEmpty)
                                    Text(
                                      e.note!,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  Text(
                                    [
                                      if (e.createdByName != null)
                                        e.createdByName!,
                                      formatShortDate(e.createdAt),
                                    ].join(' · '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _deciding ? null : () => _changeStatus(app),
            icon: _deciding
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.swap_horiz),
            label: Text(_deciding ? 'Updating…' : 'Change Status'),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPickerSheet extends StatelessWidget {
  final String current;
  const _StatusPickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text('Move to…', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ...careerApplicationStatuses.map((s) {
                final isCurrent = s == current;
                final color = appStatusColor(s);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isCurrent
                        ? scheme.surfaceContainerLow
                        : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isCurrent ? null : () => Navigator.pop(context, s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              appStatusIcon(s),
                              color: isCurrent
                                  ? scheme.onSurfaceVariant
                                  : color,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                appStatusLabel(s),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isCurrent
                                      ? scheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                            ),
                            if (isCurrent)
                              Text(
                                'Current',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                            else
                              Icon(Icons.chevron_right, color: color, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
