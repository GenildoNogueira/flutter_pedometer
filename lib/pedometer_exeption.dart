part of flutter_pedometer;

@immutable
class PedometerException implements Exception {
  PedometerException({
    this.message,
    String? code,
    this.stackTrace,
    // ignore: unnecessary_this
  }) : this.code = code ?? 'unknown';

  /// The long form message of the exception.
  final String? message;

  /// The optional code to accommodate the message.
  final String code;

  /// The stack trace which provides information to the user about the call
  /// sequence that triggered an exception
  final StackTrace? stackTrace;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PedometerException) return false;
    return other.hashCode == hashCode;
  }

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() {
    String output = '[$code] $message';

    if (stackTrace != null) {
      output += '\n\n$stackTrace';
    }

    return output;
  }
}
