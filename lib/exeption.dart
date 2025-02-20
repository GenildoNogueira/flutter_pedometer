part of flutter_pedometer;

/// Catches a [PlatformException] and returns an [Exception].
///
/// If the [Exception] is a [PlatformException], a [PedometerException] is returned.
Never convertPlatformExceptionToPedometerException(
  Object exception,
  StackTrace stackTrace,
) {
  if (exception is! PlatformException) {
    Error.throwWithStackTrace(exception, stackTrace);
  }

  Error.throwWithStackTrace(
    platformExceptionToPedometerException(exception),
    stackTrace,
  );
}

/// Converts a [PlatformException] into a [PedometerException].
///
/// A [PlatformException] can only be converted to a [PedometerException] if the
/// `details` of the exception exist. Pedometer returns specific codes and messages
/// which can be converted into user friendly exceptions.
PedometerException platformExceptionToPedometerException(
  PlatformException platformException,
) {
  Map<String, Object>? details =
      platformException.details != null
          ? Map<String, Object>.from(platformException.details)
          : null;

  String? code;
  String message = platformException.message ?? '';

  if (details != null) {
    code = (details['code'] as String?) ?? code;
    message = (details['message'] as String?) ?? message;
  }

  return PedometerException(code: code, message: message);
}

/// A custom [EventChannel] with default error handling logic.
extension EventChannelExtension on EventChannel {
  /// Similar to [receiveBroadcastStream], but with enforced error handling.
  Stream<dynamic> receiveGuardedBroadcastStream({
    dynamic arguments,
    required dynamic Function(Object error, StackTrace stackTrace) onError,
  }) {
    final incomingStackTrace = StackTrace.current;

    return receiveBroadcastStream(arguments).handleError((Object error) {
      return onError(error, incomingStackTrace);
    });
  }
}
