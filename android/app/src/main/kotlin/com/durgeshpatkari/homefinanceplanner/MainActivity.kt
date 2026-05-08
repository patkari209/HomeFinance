package com.durgeshpatkari.homefinanceplanner

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val methodChannelName = "home_finance/sms_methods"
        private const val eventChannelName = "home_finance/sms_events"
        private var smsEventSink: EventChannel.EventSink? = null

        fun pushSmsEvent(payload: Map<String, Any>) {
            smsEventSink?.success(payload)
        }

        private const val smsPermissionRequestCode = 9401
    }

    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermissions" -> {
                    result.success(hasSmsPermissions())
                }
                "requestSmsPermissions" -> {
                    if (hasSmsPermissions()) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    permissionResult = result
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(
                            Manifest.permission.RECEIVE_SMS,
                            Manifest.permission.READ_SMS,
                        ),
                        smsPermissionRequestCode,
                    )
                }
                "consumePendingSms" -> {
                    result.success(SmsBridgeStore.consumePendingMessages(applicationContext))
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventChannelName
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                smsEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                smsEventSink = null
            }
        })
    }

    private fun hasSmsPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECEIVE_SMS
        ) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_SMS
            ) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != smsPermissionRequestCode) {
            return
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { result -> result == PackageManager.PERMISSION_GRANTED }
        permissionResult?.success(granted)
        permissionResult = null
    }
}
