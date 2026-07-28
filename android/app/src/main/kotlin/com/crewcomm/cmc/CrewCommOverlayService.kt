package com.crewcomm.cmc

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.min

class CrewCommOverlayService : Service() {
    companion object {
        const val ACTION_SHOW = "com.crewcomm.cmc.overlay.SHOW"
        const val ACTION_UPDATE = "com.crewcomm.cmc.overlay.UPDATE"
        const val ACTION_HIDE = "com.crewcomm.cmc.overlay.HIDE"
        const val ACTION_EVENT = "com.crewcomm.cmc.overlay.EVENT"
        const val EXTRA_ACTION = "action"

        private const val CHANNEL_ID = "crewcomm_overlay"
        private const val NOTIFICATION_ID = 41416
    }

    private lateinit var windowManager: WindowManager
    private lateinit var bubble: RadioBubbleView
    private lateinit var bubbleParams: WindowManager.LayoutParams
    private var menu: View? = null
    private var menuParams: WindowManager.LayoutParams? = null
    private var dismissTarget: TextView? = null
    private var dismissParams: WindowManager.LayoutParams? = null
    private val handler = Handler(Looper.getMainLooper())
    private val touchSlop by lazy { ViewConfiguration.get(this).scaledTouchSlop }
    private var downRawX = 0f
    private var downRawY = 0f
    private var downWindowX = 0
    private var downWindowY = 0
    private var dragging = false
    private var transmittingFromTouch = false
    private var menuVisible = false

    private val pttRunnable = Runnable {
        if (!dragging) {
            transmittingFromTouch = true
            bubble.transmitting = true
            sendEvent("pttDown")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotification()
        createBubble()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_HIDE -> stopSelf()
            ACTION_UPDATE -> updateState(intent)
            ACTION_SHOW -> updateState(intent)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(pttRunnable)
        removeMenu()
        removeDismissTarget()
        if (::bubble.isInitialized && bubble.isAttachedToWindow) {
            windowManager.removeView(bubble)
        }
        super.onDestroy()
    }

    private fun createNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "CrewComm floating controls",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_crewcomm_notification)
            .setContentTitle("CrewComm floating PTT")
            .setContentText("Hold the radio button to transmit")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createBubble() {
        bubble = RadioBubbleView(this)
        val size = dp(82)
        bubbleParams = overlayParams(size, size).apply {
            gravity = Gravity.TOP or Gravity.START
            x = resources.displayMetrics.widthPixels - size - dp(12)
            y = resources.displayMetrics.heightPixels / 3
        }
        bubble.setOnTouchListener(::handleBubbleTouch)
        windowManager.addView(bubble, bubbleParams)
    }

    private fun handleBubbleTouch(view: View, event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downRawX = event.rawX
                downRawY = event.rawY
                downWindowX = bubbleParams.x
                downWindowY = bubbleParams.y
                dragging = false
                transmittingFromTouch = false
                handler.postDelayed(pttRunnable, 140)
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                if (transmittingFromTouch) {
                    return true
                }
                val deltaX = event.rawX - downRawX
                val deltaY = event.rawY - downRawY
                if (!dragging && hypot(deltaX.toDouble(), deltaY.toDouble()) > touchSlop) {
                    dragging = true
                    handler.removeCallbacks(pttRunnable)
                    removeMenu()
                    showDismissTarget()
                }
                if (dragging) {
                    bubbleParams.x = downWindowX + deltaX.toInt()
                    bubbleParams.y = downWindowY + deltaY.toInt()
                    clampBubble()
                    windowManager.updateViewLayout(bubble, bubbleParams)
                    setDismissActive(isOverDismissTarget())
                }
                return true
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                handler.removeCallbacks(pttRunnable)
                if (transmittingFromTouch) {
                    transmittingFromTouch = false
                    bubble.transmitting = false
                    sendEvent("pttUp")
                } else if (dragging) {
                    if (isOverDismissTarget()) {
                        sendEvent("dismiss")
                        stopSelf()
                        return true
                    }
                    snapToEdge()
                    removeDismissTarget()
                } else if (event.actionMasked == MotionEvent.ACTION_UP) {
                    toggleMenu()
                }
                dragging = false
                return true
            }
        }
        return false
    }

    private fun updateState(intent: Intent) {
        bubble.connected = intent.getBooleanExtra("connected", false)
        bubble.transmitting = intent.getBooleanExtra("transmitting", false)
        bubble.receiving = intent.getBooleanExtra("receiving", false)
        bubble.label = intent.getStringExtra("label") ?: "PTT"
        bubble.speaker = intent.getStringExtra("speaker")
        bubble.muted = intent.getBooleanExtra("muted", false)
    }

    private fun toggleMenu() {
        if (menuVisible) {
            removeMenu()
        } else {
            showMenu()
        }
    }

    private fun showMenu() {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(5), dp(5), dp(5), dp(5))
            background = roundedBackground(0xEA181818.toInt(), dp(28).toFloat())
        }
        val broadcast = menuButton("ALL", 0xFFE53935.toInt())
        broadcast.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    sendEvent("broadcastDown")
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    sendEvent("pttUp")
                    true
                }
                else -> true
            }
        }
        layout.addView(broadcast)
        layout.addView(menuButton("MUTE", 0xFFFFC107.toInt()).apply {
            setOnClickListener {
                bubble.muted = !bubble.muted
                sendEvent("mute")
            }
        })
        layout.addView(menuButton("OPEN", 0xFF66BB6A.toInt()).apply {
            setOnClickListener {
                val openIntent = Intent(this@CrewCommOverlayService, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                startActivity(openIntent)
                removeMenu()
            }
        })
        layout.addView(menuButton("×", 0xFF9E9E9E.toInt()).apply {
            textSize = 25f
            setOnClickListener {
                sendEvent("dismiss")
                stopSelf()
            }
        })
        menu = layout
        menuParams = overlayParams(dp(64), dp(224)).apply {
            gravity = Gravity.TOP or Gravity.START
            x = if (bubbleParams.x > resources.displayMetrics.widthPixels / 2) {
                bubbleParams.x - dp(68)
            } else {
                bubbleParams.x + dp(86)
            }
            y = (bubbleParams.y - dp(70)).coerceAtLeast(dp(12))
        }
        windowManager.addView(layout, menuParams)
        menuVisible = true
    }

    private fun removeMenu() {
        menu?.let {
            if (it.isAttachedToWindow) {
                windowManager.removeView(it)
            }
        }
        menu = null
        menuParams = null
        menuVisible = false
    }

    private fun showDismissTarget() {
        if (dismissTarget != null) {
            return
        }
        val target = TextView(this).apply {
            text = "×"
            textSize = 42f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = roundedBackground(0xDD2B2B2B.toInt(), dp(42).toFloat())
        }
        dismissTarget = target
        dismissParams = overlayParams(dp(84), dp(84)).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = dp(34)
        }
        windowManager.addView(target, dismissParams)
    }

    private fun removeDismissTarget() {
        dismissTarget?.let {
            if (it.isAttachedToWindow) {
                windowManager.removeView(it)
            }
        }
        dismissTarget = null
        dismissParams = null
    }

    private fun setDismissActive(active: Boolean) {
        dismissTarget?.background = roundedBackground(
            if (active) 0xFFF44336.toInt() else 0xDD2B2B2B.toInt(),
            dp(42).toFloat(),
        )
        dismissTarget?.scaleX = if (active) 1.18f else 1f
        dismissTarget?.scaleY = if (active) 1.18f else 1f
    }

    private fun isOverDismissTarget(): Boolean {
        val screenHeight = resources.displayMetrics.heightPixels
        val bubbleCenterX = bubbleParams.x + bubble.width / 2
        val bubbleCenterY = bubbleParams.y + bubble.height / 2
        val targetCenterX = resources.displayMetrics.widthPixels / 2
        val targetCenterY = screenHeight - dp(76)
        return hypot(
            (bubbleCenterX - targetCenterX).toDouble(),
            (bubbleCenterY - targetCenterY).toDouble(),
        ) < dp(76)
    }

    private fun snapToEdge() {
        val width = resources.displayMetrics.widthPixels
        bubbleParams.x = if (bubbleParams.x + bubble.width / 2 < width / 2) {
            dp(8)
        } else {
            width - bubble.width - dp(8)
        }
        windowManager.updateViewLayout(bubble, bubbleParams)
    }

    private fun clampBubble() {
        val width = resources.displayMetrics.widthPixels
        val height = resources.displayMetrics.heightPixels
        bubbleParams.x = bubbleParams.x.coerceIn(0, width - bubble.width)
        bubbleParams.y = bubbleParams.y.coerceIn(dp(24), height - bubble.height - dp(24))
    }

    private fun menuButton(label: String, color: Int): TextView =
        TextView(this).apply {
            text = label
            textSize = if (label.length > 3) 8f else 11f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            background = roundedBackground(color, dp(23).toFloat())
            layoutParams = LinearLayout.LayoutParams(dp(46), dp(46)).apply {
                bottomMargin = dp(6)
            }
        }

    private fun roundedBackground(color: Int, radius: Float) =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius
            setColor(color)
        }

    private fun overlayParams(width: Int, height: Int) = WindowManager.LayoutParams(
        width,
        height,
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        },
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        android.graphics.PixelFormat.TRANSLUCENT,
    )

    private fun sendEvent(action: String) {
        sendBroadcast(
            Intent(ACTION_EVENT)
                .setPackage(packageName)
                .putExtra(EXTRA_ACTION, action),
        )
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private class RadioBubbleView(context: Context) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val icon = BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)
        var connected = false
            set(value) {
                field = value
                invalidate()
            }
        var transmitting = false
            set(value) {
                field = value
                invalidate()
            }
        var receiving = false
            set(value) {
                field = value
                invalidate()
            }
        var muted = false
            set(value) {
                field = value
                invalidate()
            }
        var label = "PTT"
            set(value) {
                field = value
                invalidate()
            }
        var speaker: String? = null
            set(value) {
                field = value
                invalidate()
            }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val centerX = width / 2f
            val centerY = height / 2f
            val radius = min(width, height) * 0.42f
            val activeColor = when {
                transmitting -> 0xFFE53935.toInt()
                receiving -> 0xFFFFC107.toInt()
                connected -> 0xFF66BB6A.toInt()
                else -> 0xFF666666.toInt()
            }
            paint.style = Paint.Style.FILL
            paint.color = 0xD9121212.toInt()
            canvas.drawCircle(centerX, centerY, radius + dp(5), paint)
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = dp(if (transmitting || receiving) 5 else 3).toFloat()
            paint.color = activeColor
            canvas.drawCircle(centerX, centerY, radius, paint)
            paint.style = Paint.Style.FILL
            val inset = dp(13).toFloat()
            canvas.drawBitmap(
                icon,
                null,
                RectF(inset, inset, width - inset, height - inset),
                paint,
            )
            if (muted) {
                paint.color = 0xEE121212.toInt()
                canvas.drawCircle(width - dp(16).toFloat(), dp(16).toFloat(), dp(11).toFloat(), paint)
                paint.color = Color.WHITE
                paint.textAlign = Paint.Align.CENTER
                paint.textSize = dp(12).toFloat()
                paint.typeface = android.graphics.Typeface.DEFAULT_BOLD
                canvas.drawText("×", width - dp(16).toFloat(), dp(20).toFloat(), paint)
            }
        }

        private fun dp(value: Int): Int =
            (value * resources.displayMetrics.density).toInt()
    }
}
