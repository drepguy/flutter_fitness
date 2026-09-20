package com.example.flutter_fitness.flutter_fitness

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.example.flutter_fitness/rest_timer"
    private var methodChannel: MethodChannel? = null

    private val timerCompletedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == RestTimerService.BROADCAST_TIMER_COMPLETED) {
                methodChannel?.invokeMethod("onTimerCompleted", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> {
                    result.success(Build.VERSION.SDK_INT >= 36)
                }
                "startTimer" -> {
                    val duration = call.argument<Int>("duration") ?: 60
                    val endTime = System.currentTimeMillis() + duration * 1000L
                    val intent = Intent(this, RestTimerService::class.java).apply {
                        action = RestTimerService.ACTION_START
                        putExtra(RestTimerService.EXTRA_DURATION_SECONDS, duration)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(endTime)
                }
                "stopTimer" -> {
                    val intent = Intent(this, RestTimerService::class.java).apply {
                        action = RestTimerService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(null)
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(null)
                }
                "checkLiveInfoStatus" -> {
                    val sdk = Build.VERSION.SDK_INT
                    val manufacturer = Build.MANUFACTURER.lowercase()
                    val isOppoLike = manufacturer.contains("oppo") ||
                            manufacturer.contains("oneplus") ||
                            manufacturer.contains("realme")
                    if (sdk >= 36 && isOppoLike) {
                        val granted = ContextCompat.checkSelfPermission(
                            this, "android.permission.POST_PROMOTED_NOTIFICATIONS"
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(mapOf(
                            "needsHint" to true,
                            "permissionGranted" to granted
                        ))
                    } else if (sdk >= 36) {
                        val granted = ContextCompat.checkSelfPermission(
                            this, "android.permission.POST_PROMOTED_NOTIFICATIONS"
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(mapOf(
                            "needsHint" to !granted,
                            "permissionGranted" to granted
                        ))
                    } else {
                        result.success(mapOf("needsHint" to false, "permissionGranted" to true))
                    }
                }
                else -> result.notImplemented()
            }
        }

        val filter = IntentFilter(RestTimerService.BROADCAST_TIMER_COMPLETED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(timerCompletedReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(timerCompletedReceiver, filter)
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permissions = mutableListOf(Manifest.permission.POST_NOTIFICATIONS)
            if (Build.VERSION.SDK_INT >= 36) {
                permissions.add("android.permission.POST_PROMOTED_NOTIFICATIONS")
            }
            val needed = permissions.filter {
                ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
            }
            if (needed.isNotEmpty()) {
                ActivityCompat.requestPermissions(this, needed.toTypedArray(), 1001)
            }
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(timerCompletedReceiver)
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val display = windowManager.defaultDisplay
        val modes = display.supportedModes
        val highestRate = modes.maxByOrNull { it.refreshRate }
        if (highestRate != null) {
            val attrs = window.attributes
            attrs.preferredDisplayModeId = highestRate.modeId
            window.attributes = attrs
        }

        requestNotificationPermission()
    }
}
