package com.example.flutter_pedometer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.annotation.Keep
import androidx.core.app.NotificationCompat

/**
 * Foreground Service responsável por manter o sensor de passos ativo
 * mesmo quando o app está em segundo plano ou com a tela desligada.
 *
 * O Android garante que processos com Foreground Service não sejam
 * mortos agressivamente pelo sistema operacional.
 *
 * Os passos são acumulados aqui e entregues ao Dart via [PedometerManager]
 * quando o app volta ao primeiro plano.
 */
@Keep
class PedometerService : Service() {

    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null

    // Listener interno do serviço — independente do listener JNI do Dart
    private val sensorListener = object : SensorEventListener {
        override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}

        override fun onSensorChanged(event: SensorEvent) {
            if (event.sensor.type == Sensor.TYPE_STEP_DETECTOR) {
                // Acumula os passos detectados em segundo plano
                val steps = event.values[0].toInt()
                backgroundSteps += steps
                updateNotification(backgroundSteps)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> start()
            ACTION_STOP  -> stop()
        }
        return START_STICKY
    }

    private fun start() {
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification(backgroundSteps))
        sensorManager?.registerListener(
            sensorListener,
            stepSensor,
            SensorManager.SENSOR_DELAY_FASTEST,
        )
    }

    private fun stop() {
        sensorManager?.unregisterListener(sensorListener)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun updateNotification(steps: Int) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(steps))
    }

    private fun buildNotification(steps: Int): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Pedômetro ativo")
            .setContentText("$steps passos em segundo plano")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Pedômetro",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Mantém a contagem de passos em segundo plano"
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        sensorManager?.unregisterListener(sensorListener)
        super.onDestroy()
    }

    companion object {
        const val ACTION_START = "START_PEDOMETER"
        const val ACTION_STOP  = "STOP_PEDOMETER"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "pedometer_channel"

        // Passos acumulados enquanto o app está em segundo plano.
        // Usamos companion object para que o valor sobreviva se o service
        // for recriado pelo START_STICKY, e para ser lido pelo PedometerManager.
        @Volatile
        var backgroundSteps: Int = 0
            private set

        /** Reseta a contagem de segundo plano (chamado pelo Dart ao retomar). */
        fun resetBackgroundSteps(): Int {
            val steps = backgroundSteps
            backgroundSteps = 0
            return steps
        }

        fun startService(context: Context) {
            val intent = Intent(context, PedometerService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, PedometerService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
}
