import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart' show Options, ResponseType;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import '../../core/network/api_client.dart';

const careerJobStatuses = [
  'draft',
  'published',
  'paused',
  'closed',
  'archived',
];
const careerApplicationStatuses = [
  'new',
  'screening',
  'shortlisted',
  'interview',
  'offered',
  'hired',
  'rejected',
  'withdrawn',
];
const careerEmploymentTypes = [
  'full_time',
  'part_time',
  'contract',
  'internship',
];
const careerWorkplaceTypes = ['on_site', 'hybrid', 'remote'];

class CareerSalary {
  final num? min, max;
  final String? currency, period;
  CareerSalary({this.min, this.max, this.currency, this.period});

  factory CareerSalary.fromJson(Map<String, dynamic>? j) => CareerSalary(
    min: j?['min'],
    max: j?['max'],
    currency: j?['currency'],
    period: j?['period'],
  );
}

class CareerJob {
  final int id;
  final String slug, title, location, workplaceType, employmentType, status;
  final String? department, experienceLevel;
  final String summary, description;
  final List<String> responsibilities, qualifications, skills;
  final CareerSalary salary;
  final String? applicationDeadline,
      publishedAt,
      closesAt,
      createdAt,
      updatedAt;

  CareerJob({
    required this.id,
    required this.slug,
    required this.title,
    this.department,
    required this.location,
    required this.workplaceType,
    required this.employmentType,
    this.experienceLevel,
    required this.summary,
    required this.description,
    required this.responsibilities,
    required this.qualifications,
    required this.skills,
    required this.salary,
    this.applicationDeadline,
    this.publishedAt,
    this.closesAt,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory CareerJob.fromJson(Map<String, dynamic> j) => CareerJob(
    id: j['id'],
    slug: j['slug'] ?? '',
    title: j['title'] ?? '',
    department: j['department'],
    location: j['location'] ?? '',
    workplaceType: j['workplaceType'] ?? 'on_site',
    employmentType: j['employmentType'] ?? 'full_time',
    experienceLevel: j['experienceLevel'],
    summary: j['summary'] ?? '',
    description: j['description'] ?? '',
    responsibilities: List<String>.from(j['responsibilities'] ?? const []),
    qualifications: List<String>.from(j['qualifications'] ?? const []),
    skills: List<String>.from(j['skills'] ?? const []),
    salary: CareerSalary.fromJson(j['salary'] as Map<String, dynamic>?),
    applicationDeadline: j['applicationDeadline'],
    publishedAt: j['publishedAt'],
    closesAt: j['closesAt'],
    status: j['status'] ?? 'draft',
    createdAt: j['createdAt'],
    updatedAt: j['updatedAt'],
  );
}

class ResumeInfo {
  final String? filename, mime;
  final int? bytes;
  ResumeInfo({this.filename, this.mime, this.bytes});
  factory ResumeInfo.fromJson(Map<String, dynamic>? j) => ResumeInfo(
    filename: j?['filename'],
    mime: j?['mime'],
    bytes: j?['bytes'],
  );
}

class CareerApplication {
  final int id, jobId;
  final String? jobSlug, jobTitle;
  final String name, email, phone, status;
  final String? location,
      education,
      experience,
      portfolioUrl,
      expectedSalary,
      coverLetter,
      source,
      createdAt,
      updatedAt;
  final ResumeInfo resume;

  CareerApplication({
    required this.id,
    required this.jobId,
    this.jobSlug,
    this.jobTitle,
    required this.name,
    required this.email,
    required this.phone,
    this.location,
    this.education,
    this.experience,
    this.portfolioUrl,
    this.expectedSalary,
    this.coverLetter,
    required this.resume,
    required this.status,
    this.source,
    this.createdAt,
    this.updatedAt,
  });

  factory CareerApplication.fromJson(Map<String, dynamic> j) =>
      CareerApplication(
        id: j['id'],
        jobId: j['jobId'],
        jobSlug: j['jobSlug'],
        jobTitle: j['jobTitle'],
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'] ?? '',
        location: j['location'],
        education: j['education'],
        experience: j['experience'],
        portfolioUrl: j['portfolioUrl'],
        expectedSalary: j['expectedSalary'],
        coverLetter: j['coverLetter'],
        resume: ResumeInfo.fromJson(j['resume'] as Map<String, dynamic>?),
        status: j['status'] ?? 'new',
        source: j['source'],
        createdAt: j['createdAt'],
        updatedAt: j['updatedAt'],
      );
}

class CareerApplicationEvent {
  final int id;
  final String eventType;
  final String? fromStatus, toStatus, note, createdAt, createdByName;
  CareerApplicationEvent({
    required this.id,
    required this.eventType,
    this.fromStatus,
    this.toStatus,
    this.note,
    this.createdAt,
    this.createdByName,
  });

  factory CareerApplicationEvent.fromJson(Map<String, dynamic> j) =>
      CareerApplicationEvent(
        id: j['id'],
        eventType: j['event_type'] ?? '',
        fromStatus: j['from_status'],
        toStatus: j['to_status'],
        note: j['note'],
        createdAt: j['created_at'],
        createdByName: j['created_by_name'],
      );
}

class CareerApplicationDetail {
  final CareerApplication application;
  final List<CareerApplicationEvent> events;
  CareerApplicationDetail({required this.application, required this.events});
}

class CareersApi {
  final ApiClient client;
  CareersApi(this.client);

  Future<List<CareerJob>> fetchJobs({String? status}) async {
    final res = await client.get(
      '/api/careers/manage/jobs',
      query: {'status': ?status},
    );
    return (res.data['jobs'] as List)
        .map((j) => CareerJob.fromJson(j))
        .toList();
  }

  Future<CareerJob> createJob(Map<String, dynamic> body) async {
    final res = await client.post('/api/careers/manage/jobs', body);
    return CareerJob.fromJson(res.data['job']);
  }

  Future<CareerJob> updateJob(int id, Map<String, dynamic> body) async {
    final res = await client.patch('/api/careers/manage/jobs', {
      'id': id,
      ...body,
    });
    return CareerJob.fromJson(res.data['job']);
  }

  Future<List<CareerApplication>> fetchApplications({
    String? status,
    int? jobId,
    int limit = 100,
    int offset = 0,
  }) async {
    final res = await client.get(
      '/api/careers/manage/applications',
      query: {
        'status': ?status,
        if (jobId != null) 'jobId': '$jobId',
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    return (res.data['applications'] as List)
        .map((a) => CareerApplication.fromJson(a))
        .toList();
  }

  Future<CareerApplicationDetail> fetchApplicationDetail(int id) async {
    final res = await client.get(
      '/api/careers/manage/applications',
      query: {'id': '$id'},
    );
    return CareerApplicationDetail(
      application: CareerApplication.fromJson(res.data['application']),
      events: (res.data['events'] as List)
          .map((e) => CareerApplicationEvent.fromJson(e))
          .toList(),
    );
  }

  Future<void> updateApplicationStatus({
    required int id,
    required String status,
    String? note,
  }) {
    return client.patch('/api/careers/manage/applications', {
      'id': id,
      'status': status,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Downloads the CV through the authenticated session and hands it to the
  /// person to save wherever they like.
  ///
  /// On Android/iOS, [getApplicationDocumentsDirectory] is app-private
  /// internal storage — invisible in any file manager without root — so
  /// instead this writes to a temp file and opens the native "Save As"
  /// dialog (Storage Access Framework) so the person can pick Downloads (or
  /// anywhere else) themselves, no storage permission required. Desktop
  /// platforms keep the old direct-write path since their documents folder
  /// is already a normal, browsable directory.
  ///
  /// Returns the saved file path, or `null` if the person cancelled the
  /// save dialog (Android/iOS only — desktop always returns a path).
  Future<String?> downloadResume({
    required int applicationId,
    required String filename,
  }) async {
    final response = await client.dio.get(
      '/api/careers/manage/resume',
      queryParameters: {'applicationId': applicationId},
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data as List<int>;
    final safeName = filename.isEmpty ? 'resume-$applicationId' : filename;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$safeName');
      await tempFile.writeAsBytes(bytes);
      try {
        final savedPath = await FlutterFileDialog.saveFile(
          params: SaveFileDialogParams(sourceFilePath: tempFile.path),
        );
        return savedPath;
      } finally {
        // Clean up the temp copy regardless of what the person chose.
        if (await tempFile.exists()) await tempFile.delete();
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
