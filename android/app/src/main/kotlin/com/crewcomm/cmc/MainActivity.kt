package com.crewcomm.cmc

import android.view.KeyEvent
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var headsetChannel: MethodChannel? = null
    private var deepLinkChannel: MethodChannel? = null
    private var initialLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initialLink = intent?.dataString
        headsetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "crewcomm/headset")
        headsetChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "registerMediaButtons" -> result.success(null)
                else -> result.notImplemented()
            }
        }
        deepLinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "crewcomm/deeplink")
        deepLinkChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> result.success(initialLink)
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { link ->
            deepLinkChannel?.invokeMethod("link", link)
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val method = when (event.keyCode) {
            KeyEvent.KEYCODE_HEADSETHOOK,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_MEDIA_PLAY -> if (event.action == KeyEvent.ACTION_DOWN) {
                "mediaButtonDown"
            } else {
                "mediaButtonUp"
            }
            else -> null
        }
        if (method != null) {
            headsetChannel?.invokeMethod(method, null)
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}
