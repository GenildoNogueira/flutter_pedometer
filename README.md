# Flutter Pedometer

A Flutter plugin for **continuous step counting** on Android, built on top of the native `TYPE_STEP_DETECTOR` sensor via **JNI direct callbacks** — no polling, no MethodChannel overhead.

Steps are counted in real time while the app is in the foreground, and continue accumulating in the background through a **Foreground Service** that survives app minimization and screen-off.

---

## Platform Support

| Platform | Status | Mechanism |
|----------|--------|-----------|
| Android  | ✅ Supported | JNI + `TYPE_STEP_DETECTOR` + Foreground Service |
| iOS      | 🔜 Planned | `CMPedometer` |

---

## Permissions

### Android

Add the following to your `AndroidManifest.xml`:

```xml
<!-- Required on Android 10+ for step sensor access -->
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />

<!-- Required for the background Foreground Service -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH" />

<!-- Keeps the sensor active while the screen is off -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

Also register the background service inside `<application>`:

```xml
<service
    android:name=".PedometerService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="health" />
```

Request the permission at runtime using [`permission_handler`](https://pub.dev/packages/permission_handler):

```dart
final status = await Permission.activityRecognition.request();
```

---

## How It Works

```
App in foreground
    └── SensorEventListener (Dart, via JNI)
            └── onSensorChanged() fires on every step
                    └── emits StepCount on the stream

App in background / screen off
    └── PedometerService (Kotlin Foreground Service)
            └── independent SensorEventListener
                    └── accumulates steps in backgroundSteps

App returns to foreground
    └── flushBackgroundSteps()
            └── drains backgroundSteps into the stream
            └── emits updated StepCount automatically
```

> The Android system **guarantees** that Foreground Services are not aggressively killed. A persistent notification is shown while the service is active — this is an OS requirement.

---

## Usage

### 1. Initialize

```dart
final pedometer = FlutterPedometer();
pedometer.initialize(); // throws PedometerException if sensor unavailable
```

### 2. Listen to the step stream

```dart
final subscription = pedometer.stepStream.listen(
  (StepCount event) {
    print('Total steps this session: ${event.steps}');
  },
  onError: (error) {
    if (error is PedometerException) {
      print('Error: ${error.message}');
    }
  },
);
```

`StepCount.steps` holds the **cumulative total for the current listening session**. It resets to zero each time `startListening` is called (i.e., each time a new subscriber joins the stream).

### 3. Handle background / foreground transitions

Use `WidgetsBindingObserver` to sync steps accumulated in the background:

```dart
class _MyState extends State<MyWidget> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Absorbs steps counted by PedometerService while in background.
      // Emits an updated StepCount on the stream automatically.
      pedometer.flushBackgroundSteps();
    }
  }
}
```

### 4. Persist across sessions

`StepCount.steps` resets when the app restarts. To persist totals across sessions, save to `SharedPreferences` on each event:

```dart
void _onStepEvent(StepCount event) async {
  final prefs = await SharedPreferences.getInstance();
  final base = prefs.getInt('base_steps') ?? 0;
  await prefs.setInt('total_steps', base + event.steps);
}
```

### 5. Dispose

Always call `dispose()` when done to release the JNI listener and stop the Foreground Service:

```dart
@override
void dispose() {
  subscription.cancel();
  pedometer.dispose(); // stops PedometerService and releases native resources
  super.dispose();
}
```

---

## API Reference

### `FlutterPedometer`

| Member | Type | Description |
|--------|------|-------------|
| `initialize()` | `void` | Initializes the sensor. Throws `PedometerException` if unavailable. |
| `stepStream` | `Stream<StepCount>` | Emits a `StepCount` on every step detected. Starts the sensor on first listen; stops it when all listeners cancel. |
| `flushBackgroundSteps()` | `int` | Drains steps counted by `PedometerService` since last flush. Also emits on `stepStream`. Call on `AppLifecycleState.resumed`. |
| `isInitialized` | `bool` | Whether `initialize()` completed successfully. |
| `isListening` | `bool` | Whether the JNI sensor listener is currently registered. |
| `totalSteps` | `int` | Total steps counted in this session (foreground + flushed background). |
| `sensorName` | `String` | Name of the underlying hardware sensor. `'N/A'` if not initialized. |
| `dispose()` | `Future<void>` | Releases all native resources and stops the background service. |

### `StepCount`

| Member | Type | Description |
|--------|------|-------------|
| `steps` | `int` | Cumulative steps counted since listening started (current session only). |

### `PedometerException`

| Member | Type | Description |
|--------|------|-------------|
| `message` | `String?` | Human-readable error description. |
| `code` | `String` | Error code. Defaults to `'unknown'`. |
| `stackTrace` | `StackTrace?` | Optional stack trace. |

---

## Sensor Availability

The `TYPE_STEP_DETECTOR` sensor is not available on all devices. Known cases:

- Some **Samsung** budget devices do not expose a step sensor.
- Emulators generally do not have a step sensor.

`initialize()` will throw a `PedometerException` with a descriptive message in these cases. Your app should handle this gracefully:

```dart
try {
  pedometer.initialize();
} on PedometerException catch (e) {
  print('Pedometer not available: ${e.message}');
}
```

---

## Background Counting — Important Notes

- The **Foreground Service** starts automatically when `stepStream` gets its first listener and stops when `dispose()` is called.
- Android **requires a visible notification** while the service is active. The notification displays the current background step count and updates in real time.
- `backgroundSteps` is stored in the `PedometerService` companion object. It survives service restarts caused by `START_STICKY`, but is reset to zero on `flushBackgroundSteps()`.
- Steps counted in the background are **not emitted on the stream** until `flushBackgroundSteps()` is explicitly called — this avoids out-of-order events when the app resumes.

---

## Architecture Overview

```
lib/
├── flutter_pedometer.dart          # Public API + JNI stream bridge
├── pedometer_exception.dart        # Exception class
└── generated/
    └── pedometer_bindings.dart     # Auto-generated by jnigen (do not edit)

android/src/main/kotlin/com/example/flutter_pedometer/
├── PedometerManager.kt             # JNI-facing class — sensor registration
└── PedometerService.kt             # Foreground Service — background counting
```
