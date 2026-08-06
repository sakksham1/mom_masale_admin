import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'careers_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final careersApiProvider = Provider(
  (ref) => CareersApi(ref.watch(apiClientProvider)),
);

/// null status = every job regardless of status.
final careerJobsProvider = FutureProvider.family<List<CareerJob>, String?>((
  ref,
  status,
) {
  return ref.watch(careersApiProvider).fetchJobs(status: status);
});

typedef ApplicationsFilter = ({String? status, int? jobId});

final careerApplicationsProvider =
    FutureProvider.family<List<CareerApplication>, ApplicationsFilter>((
      ref,
      filter,
    ) {
      return ref
          .watch(careersApiProvider)
          .fetchApplications(status: filter.status, jobId: filter.jobId);
    });

final careerApplicationDetailProvider =
    FutureProvider.family<CareerApplicationDetail, int>((ref, id) {
      return ref.watch(careersApiProvider).fetchApplicationDetail(id);
    });
