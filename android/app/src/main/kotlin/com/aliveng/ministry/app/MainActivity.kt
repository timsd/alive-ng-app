package com.aliveng.ministry.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.annotation.NonNull

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.aliveng.ministry.app/native"

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
            startActivity(intent)
        } catch (e: Exception) {
            // Handle error
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
            startActivity(Intent.createChooser(intent, "Share via"))
        } catch (e: Exception) {
            // Handle error
        }
    }

    private fun makePhoneCall(phoneNumber: String) {
        try {
            val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$phoneNumber"))
            startActivity(intent)
        } catch (e: Exception) {
            // Handle error - fallback to dial
            val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phoneNumber"))
            startActivity(dialIntent)
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
            startActivity(intent)
        } catch (e: Exception) {
            // Handle error
        }
    }
}