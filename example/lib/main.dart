import 'package:flutter/material.dart';
import 'package:flutter_pedometer/flutter_pedometer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Stream<StepCount> _stepCountStream;
  int stepsCounter = 0;
  String? stepsException;

  Future<void> initPlatformState() async {
    _stepCountStream = FlutterPedometer.stepCountStream;
    _stepCountStream.listen(onStepCount).onError(onStepCountError);
  }

  void onStepCount(StepCount event) async {
    setState(() {
      stepsCounter = event.steps;
    });
  }

  void onStepCountError(exception) {
    setState(() {
      stepsException = exception.message;
    });
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Pedometer Plugin'),
        ),
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Center(
                  child: Text('Steps Counter: $stepsCounter'),
                ),
              ),
              if (stepsException != null)
                Expanded(
                  child: Text(stepsException!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
