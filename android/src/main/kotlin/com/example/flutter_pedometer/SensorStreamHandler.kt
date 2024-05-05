package com.example.flutter_pedometer

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import android.util.Log
import java.util.Calendar
import java.util.Date

class SensorStreamHandler(private val context: Context) : EventChannel.StreamHandler {

    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    private lateinit var eventSink: EventChannel.EventSink
    private var stepsCount: Int = 0

    init {
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        if (stepSensor == null) {
            events.error(SENSOR_UNAVAILABLE_ERROR_CODE, "Step detector sensor not available", null)
        } else if (!hasPermission()) {
            events.error(PERMISSION_DENIED_ERROR_CODE, "Permission denied to access step counter sensor", null)
        } else {
            loadData()
            sensorManager?.registerListener(sensorEventListener, stepSensor, SensorManager.SENSOR_DELAY_FASTEST)
        }
    }

    override fun onCancel(arguments: Any?) {
        sensorManager?.unregisterListener(sensorEventListener)
        saveData()
    }

    private fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED
    }

    private val sensorEventListener = object : SensorEventListener {
        override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}

        override fun onSensorChanged(event: SensorEvent) {
            if (event.sensor == stepSensor) {
                val totalSteps = event.values[0].toInt()
                stepsCount += totalSteps
                eventSink.success(stepsCount)
                saveData()
            }
        }
    }

    private fun saveData() {
        val sharedPreferences = context.getSharedPreferences("mySteps", Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            putInt("stepsCount", stepsCount)
            putLong("lastStepCountTimestamp", Calendar.getInstance().timeInMillis)
            apply()
        }
    }

    private fun loadData() {
        val sharedPreferences = context.getSharedPreferences("mySteps", Context.MODE_PRIVATE)
        val stepsAsInt = sharedPreferences.getInt("stepsCount", 0)
        val lastSavedTimestamp = sharedPreferences.getLong("lastStepCountTimestamp", 0)
        val lastSavedDate = Calendar.getInstance().apply { timeInMillis = lastSavedTimestamp }

        val currentDay = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)

        if (lastSavedDate.get(Calendar.DAY_OF_YEAR) != currentDay) {
            stepsCount = 0
            eventSink.success(stepsCount)
        } else if (stepsAsInt > 0) {
            stepsCount = stepsAsInt
            eventSink.success(stepsCount)
        }
    }

    companion object {
        private const val SENSOR_UNAVAILABLE_ERROR_CODE = "SENSOR_UNAVAILABLE"
        private const val PERMISSION_DENIED_ERROR_CODE = "PERMISSION_DENIED"
    }
}
