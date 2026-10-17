enum PhotoSource { camera, gallery }

sealed class PhotoPickException implements Exception {
  const new(this.source);

  final PhotoSource source;
}

class PhotoAccessDeniedException extends PhotoPickException {
  const new(super.source);

  @override
  String toString() =>
      'PhotoAccessDeniedException: no access to the ${source.name}';
}

class PhotoUnavailableException extends PhotoPickException {
  const new(super.source, this.reason);

  final String reason;

  @override
  String toString() =>
      'PhotoUnavailableException: ${source.name} failed with $reason';
}
