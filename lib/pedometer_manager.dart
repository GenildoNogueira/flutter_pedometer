part of flutter_pedometer;

abstract class AbstractPedometerManager {
  bool isSensorAvailable();
  dynamic getSensorName();
  bool startListening(void Function(int steps) onStep);
  void stopListening();
  bool isCurrentlyListening();
  int flushBackgroundSteps();
  void dispose();
  void release();
}

class JniPedometerManagerAdapter implements AbstractPedometerManager {
  final PedometerManager _delegate;
  SensorEventListener? _jniListener;

  JniPedometerManagerAdapter(this._delegate);

  @override
  bool isSensorAvailable() => _delegate.isSensorAvailable();

  @override
  dynamic getSensorName() => _delegate.getSensorName();

  @override
  bool startListening(void Function(int steps) onStep) {
    _jniListener = SensorEventListener.implement(
      $SensorEventListener(
        onAccuracyChanged: (_, __) {},
        onAccuracyChanged$async: true,
        onSensorChanged: (SensorEvent? event) {
          if (event == null) return;
          final floatArray = event.values;
          if (floatArray != null && floatArray.length > 0) {
            onStep(floatArray[0].toInt());
            floatArray.release();
          }
        },
        onSensorChanged$async: false,
      ),
    );

    final success = _delegate.startListening(_jniListener!);
    if (!success) {
      _jniListener?.release();
      _jniListener = null;
    }
    return success;
  }

  @override
  void stopListening() {
    _delegate.stopListening();
    _jniListener?.release();
    _jniListener = null;
  }

  @override
  bool isCurrentlyListening() => _delegate.isCurrentlyListening();

  @override
  int flushBackgroundSteps() => _delegate.flushBackgroundSteps();

  @override
  void dispose() => _delegate.dispose();

  @override
  void release() => _delegate.release();
}
