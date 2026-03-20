library flutter_pedometer;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jni/jni.dart';

import 'generated/pedometer_bindings.dart';

part 'pedometer_exception.dart';
part 'pedometer_manager.dart';

class FlutterPedometer {
  AbstractPedometerManager? _pedometerManager;
  StreamController<StepCount>? _stepEventController;
  //SensorEventListener? _jniListener;

  int _totalSteps = 0;
  bool _isInitialized = false;

  @visibleForTesting
  set pedometerManager(AbstractPedometerManager manager) {
    _pedometerManager = manager;
  }

  void initialize() {
    if (_isInitialized) return;

    try {
      _pedometerManager ??= JniPedometerManagerAdapter(
        PedometerManager(Jni.androidApplicationContext),
      );

      if (!_pedometerManager!.isSensorAvailable()) {
        throw PedometerException(
          message: 'Sensor de passos não disponível neste dispositivo',
        );
      }

      final sensorName = _pedometerManager!.getSensorName();
      debugPrint('Pedometer initialized: ${sensorName.toDartString()}');
      sensorName.release();

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      throw PedometerException(message: 'Erro ao inicializar pedômetro: $e');
    }
  }

  Stream<StepCount> get stepStream {
    if (!_isInitialized || _pedometerManager == null) {
      throw PedometerException(
        message: 'Pedômetro não inicializado. Chame initialize() primeiro.',
      );
    }

    if (_stepEventController == null || _stepEventController!.isClosed) {
      _stepEventController = StreamController<StepCount>.broadcast(
        onListen: _startListening,
        onCancel: _stopListening,
      );
    }

    return _stepEventController!.stream;
  }

  void _startListening() {
    if (_pedometerManager == null) return;

    final success = _pedometerManager!.startListening((int steps) {
      _totalSteps += steps;
      if (!(_stepEventController?.isClosed ?? true)) {
        _stepEventController?.add(StepCount._(_totalSteps));
      }
    });

    if (!success) {
      _stepEventController?.addError(
        PedometerException(message: 'Falha ao iniciar escuta do sensor'),
      );
    } else {
      debugPrint('Pedometer listening started');
    }
  }

  void _stopListening() {
    if (_pedometerManager != null && isListening) {
      _pedometerManager!.stopListening();
    }
    //_jniListener?.release();
    //_jniListener = null;
  }

  /// Chame no [onResume] do app para absorver os passos contados
  /// pelo [PedometerService] enquanto o app estava em segundo plano.
  /// O stream emite um novo evento com o total atualizado automaticamente.
  int flushBackgroundSteps() {
    if (_pedometerManager == null || !_isInitialized) return 0;

    final bgSteps = _pedometerManager!.flushBackgroundSteps();
    if (bgSteps > 0) {
      _totalSteps += bgSteps;
      if (!(_stepEventController?.isClosed ?? true)) {
        _stepEventController?.add(StepCount._(_totalSteps));
      }
      debugPrint('Flushed $bgSteps background steps. Total: $_totalSteps');
    }

    return bgSteps;
  }

  bool get isListening => _pedometerManager?.isCurrentlyListening() ?? false;
  bool get isInitialized => _isInitialized;
  int get totalSteps => _totalSteps;

  String get sensorName {
    if (_pedometerManager == null || !_isInitialized) return 'N/A';
    final name = _pedometerManager!.getSensorName();
    final result = name.toDartString();
    name.release();
    return result;
  }

  Future<void> dispose() async {
    _stopListening();
    await _stepEventController?.close();
    _stepEventController = null;

    try {
      _pedometerManager?.dispose();
      _pedometerManager?.release();
    } catch (_) {}

    _pedometerManager = null;
    _totalSteps = 0;
    _isInitialized = false;
  }
}

class StepCount {
  final int steps;
  StepCount(this.steps);
  StepCount._(this.steps);

  @override
  String toString() => 'Steps taken: $steps';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepCount &&
          runtimeType == other.runtimeType &&
          steps == other.steps;

  @override
  int get hashCode => steps.hashCode;
}
