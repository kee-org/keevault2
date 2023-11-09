package com.keevault.keevault

import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import android.os.Bundle

class AutofillActivity(): FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        System.setProperty("logs.folder", filesDir.absolutePath + "/logs");

        super.onCreate(savedInstanceState)
    }
    
}
