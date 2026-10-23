sealed class CameraException implements Exception {
  const new();
}

class CameraAccessDeniedException extends CameraException {
  const new();

  @override
  String toString() => 'CameraAccessDeniedException: no access to the camera';
}

class CameraUnavailableException extends CameraException {
  const new(this.reason);

  final String reason;

  @override
  String toString() => 'CameraUnavailableException: $reason';
}
