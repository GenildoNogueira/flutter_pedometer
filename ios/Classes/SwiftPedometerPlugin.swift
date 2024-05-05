import Flutter
import UIKit

import CoreMotion

public class SwiftPedometerPlugin: NSObject, FlutterPlugin {

    // Register Plugin
    public static func register(with registrar: FlutterPluginRegistrar) {
        let stepCountHandler = StepCounter()
        let stepCountChannel = FlutterEventChannel.init(name: "step_count", binaryMessenger: registrar.messenger())
        stepCountChannel.setStreamHandler(stepCountHandler)
    }
}

/// StepCounter, handles step count streaming
public class StepCounter: NSObject, FlutterStreamHandler {
    private let pedometer = CMPedometer()
    private var running = false
    private var eventSink: FlutterEventSink?

    private func handleEvent(count: Int) {
        // If no eventSink to emit events to, do nothing (wait)
        if (eventSink == nil) {
            return
        }
        // Emit step count event to Flutter
        eventSink!(count)
    }

    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        if #available(iOS 10.0, *) {
            if (!CMPedometer.isStepCountingAvailable()) {
                eventSink(FlutterError(code: "3", message: "Step Count is not available", details: nil))
            }
            else if (!running) {
                let systemUptime = ProcessInfo.processInfo.systemUptime;
                let timeNow = Date().timeIntervalSince1970
                let dateOfLastReboot = Date(timeIntervalSince1970: timeNow - systemUptime)
                running = true
                pedometer.startUpdates(from: dateOfLastReboot) {
                    pedometerData, error in
                    guard let pedometerData = pedometerData, error == nil else { return }

                    DispatchQueue.main.async {
                        self.handleEvent(count: pedometerData.numberOfSteps.intValue)
                    }
                }
            }
        } else {
            eventSink(FlutterError(code: "1", message: "Requires iOS 10.0 minimum", details: nil))
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(self)
        eventSink = nil

        if (running) {
            pedometer.stopUpdates()
            running = false
        }
        return nil
    }
}
