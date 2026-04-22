package com.kimyuseong.motivating

import android.content.Intent
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kimyuseong.motivating/lifecycle"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            })
    }

    override fun onPause() {
        super.onPause()
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        val isScreenOn = pm.isInteractive
        // 화면이 켜져 있으면서 pause → 앱 전환
        // 화면이 꺼지면서 pause → 화면 꺼짐
        eventSink?.success(if (isScreenOn) "app_switch" else "screen_off")
    }

    override fun onResume() {
        super.onResume()
        eventSink?.success("resumed")
    }
}