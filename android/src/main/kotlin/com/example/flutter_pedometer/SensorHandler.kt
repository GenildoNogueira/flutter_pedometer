package com.example.flutter_pedometer

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel

class SensorHandler(private val context: Context) : EventChannel.StreamHandler {

    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    private lateinit var eventSink: EventChannel.EventSink

    init {
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        if (stepSensor == null) {
            events.error(SENSOR_UNAVAILABLE_ERROR_CODE, "Step detector sensor not available", null)
        } else {
            sensorManager?.registerListener(
                    sensorEventListener,
                    stepSensor,
                    SensorManager.SENSOR_DELAY_FASTEST
            )
        }
    }

    override fun onCancel(arguments: Any?) {
        sensorManager?.unregisterListener(sensorEventListener)
    }

    private val sensorEventListener =
            object : SensorEventListener {
                override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}

                override fun onSensorChanged(event: SensorEvent) {
                    if (event.sensor == stepSensor) {
                        val steps = event.values[0].toInt()
                        eventSink.success(steps)
                    }
                }
            }

    companion object {
        private const val SENSOR_UNAVAILABLE_ERROR_CODE = "SENSOR_UNAVAILABLE"
    }
}
