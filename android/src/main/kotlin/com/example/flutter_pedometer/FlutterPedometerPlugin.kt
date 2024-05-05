package com.example.flutter_pedometer

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

class FlutterPedometerPlugin : FlutterPlugin {
    private lateinit var stepCountChannel: EventChannel

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        /// Create channels
        stepCountChannel = EventChannel(flutterPluginBinding.binaryMessenger, "step_count")
        /// Create handlers
        val stepCountHandler = SensorStreamHandler(flutterPluginBinding.applicationContext)
        /// Set handlers
        stepCountChannel.setStreamHandler(stepCountHandler)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        stepCountChannel.setStreamHandler(null)
    }
}