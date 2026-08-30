package com.example.flutter_fitness.flutter_fitness

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
    }
}
