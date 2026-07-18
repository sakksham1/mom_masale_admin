/// Typed exceptions so UI code can react differently to each failure mode,
/// instead of catching a raw Exception and stringifying it.
sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Session expired. Please log in again.']);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'You don\'t have access to do that.']);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Not found.']);
}

class ValidationException extends ApiException {
  final Map<String, List<String>> fieldErrors;
  const ValidationException(this.fieldErrors, [super.message = 'Please check the form and try again.']);
}

class NetworkException extends ApiException {
  const NetworkException([super.message = 'Could not reach the server. Check your connection.']);
}

class ServerException extends ApiException {
  const ServerException([super.message = 'Something went wrong on our end.']);
}

class UnknownApiException extends ApiException {
  const UnknownApiException([super.message = 'Unexpected error.']);
}