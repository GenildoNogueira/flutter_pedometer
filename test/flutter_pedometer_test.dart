import 'dart:async';

import 'package:flutter_pedometer/flutter_pedometer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simula o JString retornado pelo código nativo.
class _MockJString {
  final String _value;
  _MockJString([this._value = 'Mock Sensor']);
  String toDartString() => _value;
  void release() {}
}

/// Implementação fake de [AbstractPedometerManager] sem nenhuma dependência JNI.
class MockPedometerManager implements AbstractPedometerManager {
  bool sensorAvailable = true;
  bool currentlyListening = false;
  bool shouldFailToStart = false;
  int pendingBackgroundSteps = 0;
  String sensorLabel = 'Mock Sensor';

  // Armazena o callback para simular eventos nativos nos testes
  void Function(int steps)? _onStep;

  /// Simula um evento de passo vindo do sensor nativo
  void simulateStep(int steps) => _onStep?.call(steps);

  @override bool isSensorAvailable() => sensorAvailable;
  @override dynamic getSensorName() => _MockJString(sensorLabel);

  @override
  bool startListening(void Function(int steps) onStep) {
    if (shouldFailToStart) return false;
    _onStep = onStep;
    currentlyListening = true;
    return true;
  }

  @override void stopListening() { currentlyListening = false; _onStep = null; }
  @override bool isCurrentlyListening() => currentlyListening;
  @override int flushBackgroundSteps() {
    final s = pendingBackgroundSteps; pendingBackgroundSteps = 0; return s;
  }
  @override void dispose() => stopListening();
  @override void release() {}
}

void main() {
  late FlutterPedometer pedometer;
  late MockPedometerManager mock;

  setUp(() {
    pedometer = FlutterPedometer();
    mock = MockPedometerManager();
    pedometer.pedometerManager = mock;
  });

  tearDown(() async => pedometer.dispose());

  group('initialize()', () {
    test('marca como inicializado quando o sensor está disponível', () {
      pedometer.initialize();

      expect(pedometer.isInitialized, isTrue);
    });

    test('expõe o nome do sensor após inicialização', () {
      mock.sensorLabel = 'Fake Step Counter';
      pedometer.initialize();

      expect(pedometer.sensorName, 'Fake Step Counter');
    });

    test('é idempotente — chamar duas vezes não lança exceção', () {
      pedometer.initialize();

      expect(() => pedometer.initialize(), returnsNormally);
      expect(pedometer.isInitialized, isTrue);
    });

    test('lança PedometerException quando o sensor não está disponível', () {
      mock.sensorAvailable = false;

      expect(() => pedometer.initialize(), throwsA(isA<PedometerException>()));
      expect(pedometer.isInitialized, isFalse);
    });
  });

  group('sensorName (antes de inicializar)', () {
    test('retorna "N/A" antes de initialize()', () {
      expect(pedometer.sensorName, 'N/A');
    });
  });

  group('stepStream', () {
    test('lança PedometerException se acessado sem initialize()', () {
      expect(() => pedometer.stepStream, throwsA(isA<PedometerException>()));
    });

    test('inicia escuta do sensor ao receber o primeiro subscriber', () {
      pedometer.initialize();
      pedometer.stepStream.listen((_) {});

      expect(mock.isCurrentlyListening(), isTrue);
    });

    test('para a escuta quando o último subscriber cancela', () async {
      pedometer.initialize();
      final sub = pedometer.stepStream.listen((_) {});

      await sub.cancel();

      expect(mock.isCurrentlyListening(), isFalse);
    });

    test('é um broadcast stream — aceita múltiplos subscribers', () {
      pedometer.initialize();
      final stream = pedometer.stepStream;

      expect(() {
        stream.listen((_) {});
        stream.listen((_) {});
      }, returnsNormally);
    });

    test(
      'adiciona PedometerException ao stream quando startListening falha',
      () async {
        pedometer.initialize();
        mock.shouldFailToStart = true;

        final errorCompleter = Completer<Object>();
        pedometer.stepStream.listen((_) {}, onError: errorCompleter.complete);

        final error = await errorCompleter.future;
        expect(error, isA<PedometerException>());
        expect(mock.isCurrentlyListening(), isFalse);
      },
    );
  });

  group('isListening', () {
    test('é false antes de qualquer subscriber', () {
      pedometer.initialize();

      expect(pedometer.isListening, isFalse);
    });

    test('é true enquanto há subscribers ativos', () {
      pedometer.initialize();
      pedometer.stepStream.listen((_) {});

      expect(pedometer.isListening, isTrue);
    });

    test('volta para false após cancelamento', () async {
      pedometer.initialize();
      final sub = pedometer.stepStream.listen((_) {});
      await sub.cancel();

      expect(pedometer.isListening, isFalse);
    });
  });

  group('totalSteps', () {
    test('começa em zero', () {
      expect(pedometer.totalSteps, 0);
    });

    test('permanece zero após initialize() sem eventos', () {
      pedometer.initialize();

      expect(pedometer.totalSteps, 0);
    });
  });

  group('flushBackgroundSteps()', () {
    test('retorna 0 antes de initialize()', () {
      expect(pedometer.flushBackgroundSteps(), 0);
    });

    test('retorna 0 quando não há passos pendentes', () {
      pedometer.initialize();

      expect(pedometer.flushBackgroundSteps(), 0);
    });

    test(
      'retorna o número de passos em background e os incorpora ao total',
      () {
        pedometer.initialize();
        mock.pendingBackgroundSteps = 50;

        final flushed = pedometer.flushBackgroundSteps();

        expect(flushed, 50);
        expect(pedometer.totalSteps, 50);
      },
    );

    test('zera os passos pendentes no manager após o flush', () {
      pedometer.initialize();
      mock.pendingBackgroundSteps = 30;

      pedometer.flushBackgroundSteps();

      expect(mock.pendingBackgroundSteps, 0);
    });

    test('emite evento no stream com o total atualizado', () async {
      pedometer.initialize();
      mock.pendingBackgroundSteps = 20;

      final received = <StepCount>[];
      pedometer.stepStream.listen(received.add);

      pedometer.flushBackgroundSteps();

      await Future<void>.microtask(() {});

      expect(received, [StepCount(20)]);
    });

    test('acumula corretamente em múltiplos flushes', () {
      pedometer.initialize();

      mock.pendingBackgroundSteps = 10;
      pedometer.flushBackgroundSteps();
      expect(pedometer.totalSteps, 10);

      mock.pendingBackgroundSteps = 25;
      pedometer.flushBackgroundSteps();
      expect(pedometer.totalSteps, 35);
    });

    test('não emite evento no stream quando não há passos pendentes', () async {
      pedometer.initialize();

      final received = <StepCount>[];
      pedometer.stepStream.listen(received.add);

      pedometer.flushBackgroundSteps();

      await Future<void>.microtask(() {});

      expect(received, isEmpty);
    });
  });

  group('dispose()', () {
    test('pode ser chamado sem initialize() sem lançar exceção', () async {
      await expectLater(pedometer.dispose(), completes);
    });

    test('para a escuta do sensor', () async {
      pedometer.initialize();
      pedometer.stepStream.listen((_) {});

      await pedometer.dispose();

      expect(mock.isCurrentlyListening(), isFalse);
    });

    test('reseta isInitialized para false', () async {
      pedometer.initialize();
      await pedometer.dispose();

      expect(pedometer.isInitialized, isFalse);
    });

    test('reseta totalSteps para zero', () async {
      pedometer.initialize();
      mock.pendingBackgroundSteps = 100;
      pedometer.flushBackgroundSteps();
      expect(pedometer.totalSteps, 100);

      await pedometer.dispose();

      expect(pedometer.totalSteps, 0);
    });

    test('stepStream lança PedometerException após dispose', () async {
      pedometer.initialize();
      await pedometer.dispose();

      expect(() => pedometer.stepStream, throwsA(isA<PedometerException>()));
    });

    test('pode ser chamado múltiplas vezes sem exceção', () async {
      pedometer.initialize();
      await pedometer.dispose();

      await expectLater(pedometer.dispose(), completes);
    });
  });

  group('StepCount', () {
    test('igualdade por valor', () {
      expect(StepCount(100), equals(StepCount(100)));
      expect(StepCount(100), isNot(equals(StepCount(101))));
    });

    test('hashCode consistente com igualdade', () {
      expect(StepCount(100).hashCode, equals(StepCount(100).hashCode));
    });

    test('hashCode diferente para valores diferentes', () {
      expect(StepCount(1).hashCode, isNot(equals(StepCount(2).hashCode)));
    });

    test('toString retorna formato esperado', () {
      expect(StepCount(42).toString(), 'Steps taken: 42');
    });

    test('não é igual a outro tipo', () {
      // ignore: unrelated_type_equality_checks
      expect(StepCount(10) == 10, isFalse);
    });
  });
}
