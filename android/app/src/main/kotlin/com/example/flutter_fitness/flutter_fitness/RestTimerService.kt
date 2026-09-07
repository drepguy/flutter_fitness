package com.example.flutter_fitness.flutter_fitness

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.ServiceCompat
import android.content.pm.ServiceInfo

class RestTimerService : Service() {

    companion object {
        private const val TAG = "RestTimerService"
        const val CHANNEL_ID = "rest_timer_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.example.flutter_fitness.START_REST_TIMER"
        const val ACTION_STOP = "com.example.flutter_fitness.STOP_REST_TIMER"
        const val EXTRA_DURATION_SECONDS = "duration_seconds"
        const val BROADCAST_TIMER_COMPLETED = "com.example.flutter_fitness.TIMER_COMPLETED"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var endTimeMillis = 0L

    private val timerRunnable = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            val remaining = ((endTimeMillis - now) / 1000).toInt()

            if (remaining <= 0) {
                vibrate()
                sendBroadcast(Intent(BROADCAST_TIMER_COMPLETED))
                stopSelf()
                return
            }

            handler.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val duration = intent.getIntExtra(EXTRA_DURATION_SECONDS, 60)
                startTimer(duration)
            }
            ACTION_STOP -> {
                stopTimer()
            }
        }
        return START_STICKY
    }

    private fun startTimer(durationSeconds: Int) {
        handler.removeCallbacks(timerRunnable)
        endTimeMillis = System.currentTimeMillis() + durationSeconds * 1000L

        val notification = buildNotification()
        try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
            Log.d(TAG, "Foreground started, ${durationSeconds}s")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground", e)
        }

        handler.postDelayed(timerRunnable, 1000)
    }

    private fun stopTimer() {
        handler.removeCallbacks(timerRunnable)
        val manager = getSystemService(NotificationManager::class.java)
        manager.cancel(NOTIFICATION_ID)
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildNotification(): Notification {
        val cancelIntent = Intent(this, RestTimerService::class.java).apply {
            action = ACTION_STOP
        }
        val cancelPendingIntent = PendingIntent.getService(
            this, 0, cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val contentIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this, 0, contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val whenTime = endTimeMillis
        val remaining = ((endTimeMillis - System.currentTimeMillis()) / 1000).toInt().coerceAtLeast(0)
        val timeText = "${remaining / 60}:${(remaining % 60).toString().padStart(2, '0')}"

        val builder = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Rest Timer")
            .setContentText(timeText)
            .setColor(0xFF03DAC5.toInt())
            .setOngoing(true)
            .setWhen(whenTime)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setCategory(Notification.CATEGORY_WORKOUT)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(contentPendingIntent)
            .addAction(Notification.Action.Builder(
                null, "Cancel", cancelPendingIntent
            ).build())

        val notification = builder.build()

        if (Build.VERSION.SDK_INT >= 36) {
            try {
                notification.flags = notification.flags or 0x02000000
                Log.d(TAG, "Set FLAG_PROMOTED_ONGOING (0x02000000)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set PROMOTED_ONGOING flag", e)
            }
        }

        if (Build.VERSION.SDK_INT >= 36) {
            try {
                notification.extras.putBoolean("android.requestPromotedOngoing", true)
                Log.d(TAG, "Set promoted ongoing (no shortCriticalText)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set promoted extras", e)
            }
        }

        Log.d(TAG, "Built notification, remaining=${remaining}s, flags=0x${notification.flags.toString(16)}")
        return notification
    }

    private fun createNotificationChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null && existing.importance != NotificationManager.IMPORTANCE_LOW) {
            manager.deleteNotificationChannel(CHANNEL_ID)
            Log.d(TAG, "Deleted old channel (was importance=${existing.importance})")
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Rest Timer",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Rest timer status bar chip"
            setShowBadge(false)
            setSound(null, null)
            enableVibration(false)
            enableLights(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
        Log.d(TAG, "Channel created (IMPORTANCE_LOW, silent)")
    }

    private fun vibrate() {
        val vibrator = getSystemService(Vibrator::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createWaveform(
                longArrayOf(0, 500, 200, 500, 200, 500, 200, 500),
                -1
            )
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(longArrayOf(0, 500, 200, 500, 200, 500, 200, 500), -1)
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(timerRunnable)
        super.onDestroy()
    }
}
