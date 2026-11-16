package com.alive.alivengandroidapp

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServicePlugin
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.util.Log
import android.util.Rational
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.alive.alivengandroidapp/native"
    private val PIP_CHANNEL = "com.alive.alivengandroidapp/pip"
    private val ACTION_PIP_TOGGLE_MIC = "com.alive.alivengandroidapp.PIP_TOGGLE_MIC"
    private val ACTION_PIP_LEAVE_MEETING = "com.alive.alivengandroidapp.PIP_LEAVE_MEETING"

    private var pipChannel: MethodChannel? = null
    private var isInActiveMeeting: Boolean = false
    private var isPlayingVideo: Boolean = false
    private var videoAspectWidth: Int = 16
    private var videoAspectHeight: Int = 9
    private var isAudioMuted: Boolean = false
    private var isRequestingScreenShare: Boolean = false
    private var pipReceiver: BroadcastReceiver? = null

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return AudioServicePlugin.getFlutterEngine(context)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        registerPipActionReceiver()

        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "setMeetingActive" -> {
                        val active = call.argument<Boolean>("active") ?: false
                        val mutedArg = call.argument<Boolean>("isMuted")
                        isInActiveMeeting = active
                        if (mutedArg != null) {
                            isAudioMuted = mutedArg
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isPipSupported()) {
                            try {
                                setPictureInPictureParams(buildPipParams(autoEnter = isInActiveMeeting || isPlayingVideo))
                            } catch (e: Exception) {
                                Log.w("MainActivity", "Failed to update PiP params", e)
                            }
                        }
                        result.success(true)
                    }
                    "setVideoPipState" -> {
                        val active = call.argument<Boolean>("active") ?: false
                        val isVertical = call.argument<Boolean>("isVertical") ?: false
                        isPlayingVideo = active
                        if (isVertical) {
                            videoAspectWidth = 9
                            videoAspectHeight = 16
                        } else {
                            videoAspectWidth = 16
                            videoAspectHeight = 9
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isPipSupported()) {
                            try {
                                setPictureInPictureParams(buildPipParams(autoEnter = isInActiveMeeting || isPlayingVideo))
                            } catch (e: Exception) {
                                Log.w("MainActivity", "Failed to update video PiP params", e)
                            }
                        }
                        result.success(true)
                    }
                    "updatePipState" -> {
                        val mutedArg = call.argument<Boolean>("isMuted")
                        if (mutedArg != null) {
                            isAudioMuted = mutedArg
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isPipSupported() && isInActiveMeeting) {
                            try {
                                setPictureInPictureParams(buildPipParams(autoEnter = isInActiveMeeting))
                            } catch (e: Exception) {
                                Log.w("MainActivity", "Failed to refresh PiP actions", e)
                            }
                        }
                        result.success(true)
                    }
                    "enterPipMode" -> {
                        result.success(tryEnterPipMode())
                    }
                    "isPipSupported" -> {
                        result.success(isPipSupported())
                    }
                    "startScreenShareService" -> {
                        isRequestingScreenShare = true
                        try {
                            MediaProjectionForegroundService.start(this@MainActivity)
                            result.success(true)
                        } catch (e: Exception) {
                            isRequestingScreenShare = false
                            Log.e("MainActivity", "Failed to start screen share service", e)
                            result.error("SCREEN_SHARE_SERVICE_ERROR", e.message, null)
                        }
                    }
                    "stopScreenShareService" -> {
                        isRequestingScreenShare = false
                        MediaProjectionForegroundService.stop(this@MainActivity)
                        result.success(true)
                    }
                    "setRequestingScreenShare" -> {
                        isRequestingScreenShare = call.argument<Boolean>("requesting") ?: false
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        openUrl(url)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "URL is required", null)
                    }
                }
                "shareText" -> {
                    val text = call.argument<String>("text")
                    val subject = call.argument<String>("subject")
                    if (text != null) {
                        shareText(text, subject)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Text is required", null)
                    }
                }
                "makePhoneCall" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    if (phoneNumber != null) {
                        makePhoneCall(phoneNumber)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Phone number is required", null)
                    }
                }
                "sendEmail" -> {
                    val email = call.argument<String>("email")
                    val subject = call.argument<String>("subject")
                    val body = call.argument<String>("body")
                    if (email != null) {
                        sendEmail(email, subject, body)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Email is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openUrl(url: String) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
            } else {
                Log.e("MainActivity", "No activity found to handle URL: $url")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error opening URL: $url", e)
        }
    }

    private fun shareText(text: String, subject: String?) {
        try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
                if (subject != null) {
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                }
            }
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(Intent.createChooser(intent, "Share via"))
            } else {
                Log.e("MainActivity", "No activity found to share text")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error sharing text", e)
        }
    }

    private fun makePhoneCall(phoneNumber: String) {
        try {
            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phoneNumber"))
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
            } else {
                Log.e("MainActivity", "No activity found to handle phone dialer")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error launching dialer for: $phoneNumber", e)
        }
    }

    private fun sendEmail(email: String, subject: String?, body: String?) {
        try {
            val intent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("mailto:$email")
                if (subject != null) {
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                }
                if (body != null) {
                    putExtra(Intent.EXTRA_TEXT, body)
                }
            }
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
            } else {
                Log.e("MainActivity", "No email client found for: $email")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error sending email", e)
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if ((isInActiveMeeting || isPlayingVideo) && !isInPictureInPictureMode && !isRequestingScreenShare) {
            tryEnterPipMode()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    private fun isPipSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun tryEnterPipMode(): Boolean {
        if (!isPipSupported()) return false
        return try {
            enterPictureInPictureMode(buildPipParams(autoEnter = isInActiveMeeting || isPlayingVideo))
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to enter Picture-in-Picture mode", e)
            false
        }
    }

    override fun onDestroy() {
        pipReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
            pipReceiver = null
        }
        super.onDestroy()
    }

    private fun registerPipActionReceiver() {
        if (pipReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    ACTION_PIP_TOGGLE_MIC -> {
                        pipChannel?.invokeMethod("onPipAction", "toggle_mic")
                    }
                    ACTION_PIP_LEAVE_MEETING -> {
                        pipChannel?.invokeMethod("onPipAction", "leave_meeting")
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_PIP_TOGGLE_MIC)
            addAction(ACTION_PIP_LEAVE_MEETING)
        }
        ContextCompat.registerReceiver(
            this,
            receiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        pipReceiver = receiver
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun buildPipParams(autoEnter: Boolean): PictureInPictureParams {
        val micLabel = if (isAudioMuted) "Unmute" else "Mute"
        val micIconRes = if (isAudioMuted) {
            android.R.drawable.ic_lock_silent_mode_off
        } else {
            android.R.drawable.ic_lock_silent_mode
        }
        val micPendingIntent = PendingIntent.getBroadcast(
            this,
            101,
            Intent(ACTION_PIP_TOGGLE_MIC).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val micAction = RemoteAction(
            Icon.createWithResource(this, micIconRes),
            micLabel,
            micLabel,
            micPendingIntent
        )

        val leavePendingIntent = PendingIntent.getBroadcast(
            this,
            102,
            Intent(ACTION_PIP_LEAVE_MEETING).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val leaveAction = RemoteAction(
            Icon.createWithResource(this, android.R.drawable.ic_menu_close_clear_cancel),
            "Leave",
            "Leave meeting",
            leavePendingIntent
        )

        val builder = PictureInPictureParams.Builder()
        if (isPlayingVideo && !isInActiveMeeting) {
            builder
                .setAspectRatio(Rational(videoAspectWidth, videoAspectHeight))
                .setActions(emptyList())
        } else {
            builder
                .setAspectRatio(Rational(9, 16))
                .setActions(listOf(micAction, leaveAction))
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoEnter)
            builder.setSeamlessResizeEnabled(true)
        }
        return builder.build()
    }
}
