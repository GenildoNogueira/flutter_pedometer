package com.example.flutter_pedometer

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.annotation.Keep

@Keep
class PedometerManager(context: Context) {

    private val appContext = context.applicationContext
    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    private var isListening = false
    private var activeListener: SensorEventListener? = null

    init {
        sensorManager = appContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
    }

    fun isSensorAvailable(): Boolean = stepSensor != null

    fun getSensorName(): String = stepSensor?.name ?: "Not available"

    /**
     * Inicia a escuta do sensor com o listener implementado no Dart via JNI.
     * Também inicia o [PedometerService] para manter o sensor vivo em segundo plano.
     */
    fun startListening(listener: SensorEventListener): Boolean {
        if (stepSensor == null) return false
        if (isListening) stopListening()

        activeListener = listener

        isListening = sensorManager?.registerListener(
            listener,
            stepSensor,
            SensorManager.SENSOR_DELAY_FASTEST,
        ) ?: false

        if (isListening) {
            PedometerService.startService(appContext)
        }

        return isListening
    }

    /**
     * Retorna os passos acumulados pelo serviço em segundo plano
     * e reseta o contador interno do serviço.
     * Deve ser chamado ao retomar o app (onResume) para sincronizar a contagem.
     */
    fun flushBackgroundSteps(): Int {
        return PedometerService.resetBackgroundSteps()
    }

    fun stopListening() {
        if (isListening && activeListener != null) {
            sensorManager?.unregisterListener(activeListener)
            activeListener = null
            isListening = false
        }
        PedometerService.stopService(appContext)
    }

    fun isCurrentlyListening(): Boolean = isListening

    fun dispose() {
        stopListening()
        sensorManager = null
        stepSensor = null
    }
}
