import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pedometer/flutter_pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final FlutterPedometer _pedometer;
  StreamSubscription<StepCount>? _stepSubscription;

  int _baseSteps = 0;
  int _sessionSteps = 0;

  int get stepsCounter => _baseSteps + _sessionSteps;

  String? stepsException;
  String sensorName = 'N/A';
  String permissionStatus = 'N/A';
  bool isListening = false;

  static const String _stepsKey = 'my_app_total_steps';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initPlatformState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepSubscription?.cancel();
    _pedometer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App voltou ao primeiro plano — absorve passos do background
        _syncBackgroundSteps();
      case AppLifecycleState.paused:
        // App indo para background — o PedometerService assume o controle.
        // Não precisamos fazer nada aqui; o service já está rodando.
        debugPrint('App pausado — PedometerService mantém a contagem');
      default:
        break;
    }
  }

  /// Absorve os passos acumulados pelo [PedometerService] em background
  /// e os adiciona à contagem total, persistindo no SharedPreferences.
  void _syncBackgroundSteps() {
    final bgSteps = _pedometer.flushBackgroundSteps();
    if (bgSteps > 0) {
      // _sessionSteps já foi atualizado pelo flushBackgroundSteps via stream,
      // mas salvamos o total para garantir persistência.
      _saveSteps(stepsCounter);
      debugPrint('Sincronizados $bgSteps passos do background');
    }
  }

  Future<void> initPlatformState() async {
    await _loadBaseSteps();

    try {
      await _requestPermission();

      if (permissionStatus != 'Permissão Concedida') {
        setState(() {
          stepsException = 'Permissão de Atividade Física é necessária.';
        });
        return;
      }

      _pedometer = FlutterPedometer();
      _pedometer.initialize();

      sensorName = _pedometer.sensorName;

      _stepSubscription = _pedometer.stepStream.listen(
        _onStepEvent,
        onError: _onStepError,
      );

      if (mounted) {
        setState(() => isListening = _pedometer.isListening);
      }
    } catch (e) {
      if (mounted) {
        setState(() => stepsException = e.toString());
      }
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.activityRecognition.request();
    setState(() {
      permissionStatus = switch (status) {
        _ when status.isGranted => 'Permissão Concedida',
        _ when status.isPermanentlyDenied => 'Permissão Negada Permanentemente',
        _ => 'Permissão Negada',
      };
    });
  }

  /// Chamado a cada passo detectado (foreground) ou ao fazer flush do background.
  /// [event.steps] = total acumulado nesta sessão pelo FlutterPedometer.
  void _onStepEvent(StepCount event) {
    setState(() {
      _sessionSteps = event.steps;
      isListening = _pedometer.isListening;
    });
    _saveSteps(stepsCounter);
  }

  void _onStepError(Object error) {
    setState(() {
      stepsException = error is PedometerException
          ? error.message
          : 'Erro inesperado: $error';
      isListening = _pedometer.isListening;
    });
  }

  Future<void> _saveSteps(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepsKey, steps);
  }

  Future<void> _loadBaseSteps() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _baseSteps = prefs.getInt(_stepsKey) ?? 0);
  }

  Future<void> _resetSteps() async {
    setState(() {
      _baseSteps = 0;
      _sessionSteps = 0;
      stepsException = null;
    });
    await _saveSteps(0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Pedometer Plugin')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Steps Counter: $stepsCounter',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sessão atual: $_sessionSteps  |  Histórico: $_baseSteps',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text('Sensor: $sensorName'),
              Text('Permissão: $permissionStatus'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isListening ? Icons.sensors : Icons.sensors_off,
                    color: isListening ? Colors.green : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isListening
                        ? 'Sensor ativo (inclui background)'
                        : 'Sensor inativo',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (stepsException != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Erro: $stepsException',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _resetSteps,
                child: const Text('Reset steps'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
