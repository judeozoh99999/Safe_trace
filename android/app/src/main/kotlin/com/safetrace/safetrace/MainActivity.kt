package com.safetrace.safetrace

import android.os.Bundle
import android.view.WindowManager
import android.os.Build
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.safetrace.safetrace/ringtone").setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    try {
                        if (ringtone == null) {
                            val notification: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                            ringtone = RingtoneManager.getRingtone(applicationContext, notification)
                        }
                        if (ringtone?.isPlaying == false) {
                            ringtone?.play()
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message ?: "Failed to play ringtone", null)
                    }
                }
                "stop" -> {
                    try {
                        if (ringtone?.isPlaying == true) {
                            ringtone?.stop()
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message ?: "Failed to stop ringtone", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.safetrace.safetrace/sms").setMethodCallHandler { call, result ->
            if (call.method == "sendSms") {
                val rawRecipients = call.argument<List<Map<String, String>>>("recipients")
                if (rawRecipients == null) {
                    result.error("INVALID_ARGUMENTS", "Recipients list is null", null)
                    return@setMethodCallHandler
                }

                val sentList = mutableListOf<String>()
                val failedList = mutableListOf<String>()

                val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    applicationContext.getSystemService(SmsManager::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    SmsManager.getDefault()
                }

                for (recipient in rawRecipients) {
                    val phone = recipient["phoneNumber"]?.trim() ?: ""
                    val message = recipient["message"] ?: ""

                    if (phone.isEmpty()) continue

                    try {
                        if (message.length > 160) {
                            val parts = smsManager.divideMessage(message)
                            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                        } else {
                            smsManager.sendTextMessage(phone, null, message, null, null)
                        }
                        sentList.add(phone)
                    } catch (e: Exception) {
                        failedList.add(phone)
                    }
                }

                result.success(mapOf("sent" to sentList, "failed" to failedList))
            } else {
                result.notImplemented()
            }
        }
    }
}
