package com.auralis.audio

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.auralis.audio/engine"
    }

    private var engineRunning = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        engineRunning = true
                        result.success(null)
                    }
                    "stop" -> {
                        engineRunning = false
                        result.success(null)
                    }
                    "isSupported" -> result.success(true)
                    else -> result.notImplemented()
                }
            }
    }
}
