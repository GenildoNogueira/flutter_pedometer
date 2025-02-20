library flutter_pedometer;

import 'dart:async';

import 'package:flutter/services.dart' show EventChannel, PlatformException;
import 'package:flutter/foundation.dart';

part 'exeption.dart';
part 'pedometer_exeption.dart';

class FlutterPedometer {
  static const EventChannel _stepCountChannel = const EventChannel(
    'step_count',
  );

  /// Returns the steps taken since.
  /// Events may come with a delay.
  static Stream<StepCount> get stepCountStream => _stepCountChannel
      .receiveGuardedBroadcastStream(
        onError: convertPlatformExceptionToPedometerException,
      )
      .map((event) => StepCount._(event));
}

class StepCount {
  int _steps = 0;

  StepCount._(dynamic e) {
    _steps = e as int;
  }

  int get steps => _steps;

  @override
  String toString() => 'Steps taken: $_steps';
}
