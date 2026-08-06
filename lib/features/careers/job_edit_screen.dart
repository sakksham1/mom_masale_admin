import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'careers_api.dart';
import 'careers_provider.dart';
import 'careers_screen.dart' show jobStatusLabel;
import '../../core/network/api_exception.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';

class JobEditScreen extends ConsumerStatefulWidget {
  final CareerJob? job; // null = creating a new job
  const JobEditScreen({super.key, this.job});

  @override
  ConsumerState<JobEditScreen> createState() => _JobEditScreenState();
}

class _JobEditScreenState extends ConsumerState<JobEditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _departmentCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _experienceCtrl;
  late final TextEditingController _summaryCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _responsibilitiesCtrl;
  late final TextEditingController _qualificationsCtrl;
  late final TextEditingController _skillsCtrl;
  late final TextEditingController _salaryMinCtrl;
  late final TextEditingController _salaryMaxCtrl;
  late final TextEditingController _salaryCurrencyCtrl;
  late final TextEditingController _salaryPeriodCtrl;
  late final TextEditingController _deadlineCtrl;
  late final TextEditingController _closesAtCtrl;

  late String _workplaceType;
  late String _employmentType;
  late String _status;
  bool _submitting = false;

  bool get _isNew => widget.job == null;

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    _titleCtrl = TextEditingController(text: j?.title ?? '');
    _departmentCtrl = TextEditingController(text: j?.department ?? '');
    _locationCtrl = TextEditingController(text: j?.location ?? '');
    _experienceCtrl = TextEditingController(text: j?.experienceLevel ?? '');
    _summaryCtrl = TextEditingController(text: j?.summary ?? '');
    _descriptionCtrl = TextEditingController(text: j?.description ?? '');
    _responsibilitiesCtrl = TextEditingController(
      text: (j?.responsibilities ?? []).join('\n'),
    );
    _qualificationsCtrl = TextEditingController(
      text: (j?.qualifications ?? []).join('\n'),
    );
    _skillsCtrl = TextEditingController(text: (j?.skills ?? []).join(', '));
    _salaryMinCtrl = TextEditingController(
      text: j?.salary.min?.toString() ?? '',
    );
    _salaryMaxCtrl = TextEditingController(
      text: j?.salary.max?.toString() ?? '',
    );
    _salaryCurrencyCtrl = TextEditingController(
      text: j?.salary.currency ?? 'INR',
    );
    _salaryPeriodCtrl = TextEditingController(text: j?.salary.period ?? '');
    _deadlineCtrl = TextEditingController(text: j?.applicationDeadline ?? '');
    _closesAtCtrl = TextEditingController(text: j?.closesAt ?? '');
    _workplaceType = j?.workplaceType ?? 'on_site';
    _employmentType = j?.employmentType ?? 'full_time';
    _status = j?.status ?? 'draft';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _departmentCtrl.dispose();
    _locationCtrl.dispose();
    _experienceCtrl.dispose();
    _summaryCtrl.dispose();
    _descriptionCtrl.dispose();
    _responsibilitiesCtrl.dispose();
    _qualificationsCtrl.dispose();
    _skillsCtrl.dispose();
    _salaryMinCtrl.dispose();
    _salaryMaxCtrl.dispose();
    _salaryCurrencyCtrl.dispose();
    _salaryPeriodCtrl.dispose();
    _deadlineCtrl.dispose();
    _closesAtCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final initial = DateTime.tryParse(ctrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      ctrl.text = picked.toIso8601String().substring(0, 10);
      setState(() {});
    }
  }

  List<String> _lines(String text) =>
      text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  List<String> _csv(String text) =>
      text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Map<String, dynamic> _buildBody() {
    final salaryMin = int.tryParse(_salaryMinCtrl.text.trim());
    final salaryMax = int.tryParse(_salaryMaxCtrl.text.trim());
    return {
      'title': _titleCtrl.text.trim(),
      'department': _departmentCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'workplaceType': _workplaceType,
      'employmentType': _employmentType,
      'experienceLevel': _experienceCtrl.text.trim(),
      'summary': _summaryCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'responsibilities': _lines(_responsibilitiesCtrl.text),
      'qualifications': _lines(_qualificationsCtrl.text),
      'skills': _csv(_skillsCtrl.text),
      'salaryMin': salaryMin,
      'salaryMax': salaryMax,
      'salaryCurrency': _salaryCurrencyCtrl.text.trim().isEmpty
          ? 'INR'
          : _salaryCurrencyCtrl.text.trim(),
      'salaryPeriod': _salaryPeriodCtrl.text.trim(),
      'applicationDeadline': _deadlineCtrl.text.trim(),
      'closesAt': _closesAtCtrl.text.trim(),
      'status': _status,
    };
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _locationCtrl.text.trim().isEmpty ||
        _summaryCtrl.text.trim().isEmpty ||
        _descriptionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Title, location, summary, and description are required',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final body = _buildBody();
      if (_isNew) {
        await ref.read(careersApiProvider).createJob(body);
      } else {
        await ref.read(careersApiProvider).updateJob(widget.job!.id, body);
      }
      ref.invalidate(careerJobsProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          _isNew ? 'Job created' : 'Job updated',
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New Job' : 'Edit Job')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _SectionCard(
            title: 'Basics',
            children: [
              _Field(controller: _titleCtrl, label: 'Job title'),
              const SizedBox(height: 12),
              _Field(
                controller: _departmentCtrl,
                label: 'Department (optional)',
              ),
              const SizedBox(height: 12),
              _Field(controller: _locationCtrl, label: 'Location'),
              const SizedBox(height: 12),
              _Field(
                controller: _experienceCtrl,
                label: 'Experience level (optional)',
              ),
              const SizedBox(height: 14),
              Text(
                'Workplace type',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: careerWorkplaceTypes
                    .map(
                      (t) => ChoiceChip(
                        label: Text(t.replaceAll('_', ' ')),
                        selected: _workplaceType == t,
                        onSelected: (_) => setState(() => _workplaceType = t),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              Text(
                'Employment type',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: careerEmploymentTypes
                    .map(
                      (t) => ChoiceChip(
                        label: Text(t.replaceAll('_', ' ')),
                        selected: _employmentType == t,
                        onSelected: (_) => setState(() => _employmentType = t),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Description',
            children: [
              _Field(
                controller: _summaryCtrl,
                label: 'Short summary',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _descriptionCtrl,
                label: 'Full description',
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _responsibilitiesCtrl,
                label: 'Responsibilities (one per line)',
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _qualificationsCtrl,
                label: 'Qualifications (one per line)',
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _skillsCtrl,
                label: 'Skills (comma-separated)',
                maxLines: 2,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Compensation & Dates',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _salaryMinCtrl,
                      label: 'Salary min',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      controller: _salaryMaxCtrl,
                      label: 'Salary max',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _salaryCurrencyCtrl,
                      label: 'Currency',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      controller: _salaryPeriodCtrl,
                      label: 'Period (e.g. yearly)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DateField(
                controller: _deadlineCtrl,
                label: 'Application deadline',
                onTap: () => _pickDate(_deadlineCtrl),
              ),
              const SizedBox(height: 12),
              _DateField(
                controller: _closesAtCtrl,
                label: 'Closes at',
                onTap: () => _pickDate(_closesAtCtrl),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Status',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: careerJobStatuses
                    .map(
                      (s) => ChoiceChip(
                        label: Text(jobStatusLabel(s)),
                        selected: _status == s,
                        onSelected: (_) => setState(() => _status = s),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Published jobs show up on the public careers page immediately — '
                'this writes straight to the database, no publish step needed.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isNew ? 'Create Job' : 'Save Changes'),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

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
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _DateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onTap;
  const _DateField({
    required this.controller,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: '$label (optional)',
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
    );
  }
}
