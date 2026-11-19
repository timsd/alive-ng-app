package com.alive.alivengandroidapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicBoolean

class MediaProjectionForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "alive_screen_share"
        const val NOTIFICATION_ID = 4401
        const val ACTION_START = "com.alive.alivengandroidapp.ACTION_START_SCREEN_SHARE"
        const val ACTION_STOP = "com.alive.alivengandroidapp.ACTION_STOP_SCREEN_SHARE"

        private val isForegroundReady = AtomicBoolean(false)
        private val pendingCallbacks = CopyOnWriteArrayList<(Boolean) -> Unit>()
        private val mainHandler = Handler(Looper.getMainLooper())

        fun start(context: Context, onReady: ((Boolean) -> Unit)? = null) {
            if (isForegroundReady.get()) {
                onReady?.let { cb -> mainHandler.post { cb(true) } }
                return
            }

            if (onReady != null) {
                val invoked = AtomicBoolean(false)
                val wrapped: (Boolean) -> Unit = { success ->
                    if (invoked.compareAndSet(false, true)) {
                        mainHandler.post { onReady(success) }
                    }
                }
                pendingCallbacks.add(wrapped)
                // Safety timeout so the Flutter MethodChannel can never hang
                mainHandler.postDelayed({
                    pendingCallbacks.remove(wrapped)
                    wrapped(isForegroundReady.get())
                }, 2500L)
            }

            val intent = Intent(context, MediaProjectionForegroundService::class.java).apply {
                action = ACTION_START
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e("MediaProjectionSvc", "Failed to start foreground service", e)
                notifyCallbacks(false)
            }
        }

        fun stop(context: Context) {
            isForegroundReady.set(false)
            notifyCallbacks(false)
            val intent = Intent(context, MediaProjectionForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.stopService(intent)
            } catch (_: Exception) {
            }
        }

        private fun notifyCallbacks(success: Boolean) {
            val snapshot = ArrayList(pendingCallbacks)
            pendingCallbacks.clear()
            for (cb in snapshot) {
                cb(success)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            isForegroundReady.set(false)
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        try {
            ensureChannel()
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            isForegroundReady.set(true)
            notifyCallbacks(true)
        } catch (e: Exception) {
            Log.e("MediaProjectionSvc", "startForeground failed", e)
            isForegroundReady.set(false)
            notifyCallbacks(false)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        isForegroundReady.set(false)
        stopForegroundCompat()
        super.onDestroy()
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "ALIVE Meet Screen Sharing",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Active while sharing your screen in ALIVE Meet"
                    setShowBadge(false)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    private fun buildNotification(): Notification {
        val resumeIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra("resume_meeting", true)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            resumeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ALIVE Meet")
            .setContentText("Sharing your screen in the meeting")
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFF0F9A07.toInt())
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .build()
    }
}
