package com.crewcomm.cmc

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var headsetChannel: MethodChannel? = null
    private var deepLinkChannel: MethodChannel? = null
    private var overlayChannel: MethodChannel? = null
    private var audioChannel: MethodChannel? = null
    private var pcmPlayer: NativePcmPlayer? = null
    private var initialLink: String? = null
    private var overlayReceiverRegistered = false
    private var showOverlayAfterPermission = false
    private var pendingOverlayState: Map<*, *>? = null

    private val overlayReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.getStringExtra(CrewCommOverlayService.EXTRA_ACTION) ?: return
            overlayChannel?.invokeMethod("action", mapOf("action" to action))
        }
    }

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
        overlayChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "crewcomm/overlay",
        )
        overlayChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    showOverlay()
                    result.success(null)
                }
                "hide" -> {
                    stopOverlay()
                    result.success(null)
                }
                "updateState" -> {
                    updateOverlay(call.arguments as? Map<*, *>)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        pcmPlayer = NativePcmPlayer(applicationContext)
        audioChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "crewcomm/audio",
        )
        audioChannel?.setMethodCallHandler { call, result ->
            val arguments = call.arguments as? Map<*, *>
            when (call.method) {
                "initialize" -> {
                    pcmPlayer?.initialize(
                        (arguments?.get("sampleRate") as? Number)?.toInt() ?: 16000,
                        (arguments?.get("channels") as? Number)?.toInt() ?: 1,
                    )
                    result.success(null)
                }
                "write" -> {
                    val pcm = arguments?.get("pcm") as? ByteArray
                    if (pcm == null) {
                        result.error("invalid_pcm", "PCM payload is missing", null)
                    } else {
                        pcmPlayer?.write(
                            pcm,
                            (arguments["volume"] as? Number)?.toFloat() ?: 1f,
                        )
                        result.success(null)
                    }
                }
                "stop" -> {
                    pcmPlayer?.stop()
                    result.success(null)
                }
                "dispose" -> {
                    pcmPlayer?.dispose()
                    pcmPlayer = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        registerOverlayReceiver()
    }

    override fun onResume() {
        super.onResume()
        if (showOverlayAfterPermission && Settings.canDrawOverlays(this)) {
            showOverlayAfterPermission = false
            window.decorView.postDelayed({ startOverlay() }, 250)
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

    override fun onDestroy() {
        if (overlayReceiverRegistered) {
            unregisterReceiver(overlayReceiver)
            overlayReceiverRegistered = false
        }
        overlayChannel?.setMethodCallHandler(null)
        overlayChannel = null
        audioChannel?.setMethodCallHandler(null)
        audioChannel = null
        pcmPlayer?.dispose()
        pcmPlayer = null
        super.onDestroy()
    }

    private fun registerOverlayReceiver() {
        if (overlayReceiverRegistered) {
            return
        }
        val filter = IntentFilter(CrewCommOverlayService.ACTION_EVENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(overlayReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(overlayReceiver, filter)
        }
        overlayReceiverRegistered = true
    }

    private fun showOverlay() {
        if (!Settings.canDrawOverlays(this)) {
            showOverlayAfterPermission = true
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName"),
                ),
            )
            return
        }
        startOverlay()
    }

    private fun startOverlay() {
        val intent = Intent(this, CrewCommOverlayService::class.java).apply {
            action = CrewCommOverlayService.ACTION_SHOW
            putOverlayState(pendingOverlayState)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopOverlay() {
        stopService(Intent(this, CrewCommOverlayService::class.java))
    }

    private fun updateOverlay(state: Map<*, *>?) {
        if (state == null) {
            return
        }
        pendingOverlayState = state
        if (!Settings.canDrawOverlays(this)) {
            return
        }
        val intent = Intent(this, CrewCommOverlayService::class.java).apply {
            action = CrewCommOverlayService.ACTION_UPDATE
            putOverlayState(state)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun Intent.putOverlayState(state: Map<*, *>?) {
        if (state == null) {
            return
        }
        putExtra("connected", state["connected"] == true)
        putExtra("transmitting", state["transmitting"] == true)
        putExtra("receiving", state["receiving"] == true)
        putExtra("speaker", state["speaker"] as? String)
        putExtra("label", state["label"] as? String)
        putExtra("muted", state["muted"] == true)
    }
}
