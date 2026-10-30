package com.alive.alivengandroidapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.annotation.NonNull

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.alive.alivengandroidapp/native"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
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
}
