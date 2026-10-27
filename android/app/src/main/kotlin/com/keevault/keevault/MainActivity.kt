package com.keevault.keevault

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import android.os.Bundle
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.keevault.keevault/secure_clipboard"

    override fun onCreate(savedInstanceState: Bundle?) {
        System.setProperty("logs.folder", filesDir.absolutePath + "/logs");

        super.onCreate(savedInstanceState)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "copySensitive") {
                val text = call.argument<String>("text")
                if (text != null) {
                    val systemShowedUi = copyToClipboard(text)
                    // Send boolean back to Dart code
                    result.success(systemShowedUi) 
                } else {
                    result.error("INVALID_ARGUMENT", "Text cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun copyToClipboard(text: String): Boolean {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("sensitive_data", text)

        val isAndroid13OrHigher = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU

        if (isAndroid13OrHigher) {
            val bundle = PersistableBundle().apply {
                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
            }
            clip.description.extras = bundle
        } else {
            // Backward compatibility flag if running below API 33
            val bundle = PersistableBundle().apply {
                putBoolean("android.content.extra.IS_SENSITIVE", true)
            }
            clip.description.extras = bundle
        }

        clipboard.setPrimaryClip(clip)
        
        // Android 13+ handles the UI feedback overlay natively
        return isAndroid13OrHigher
    }
}
