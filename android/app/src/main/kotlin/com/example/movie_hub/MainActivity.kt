package com.example.movie_hub

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "moviehub/store")
            .setMethodCallHandler { call, result ->
                if (call.method != "openListing") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                // Follow the installed app's final release identity.
                val listing = Uri.parse("https://play.google.com/store/apps/details?id=$packageName")
                try {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, listing).setPackage("com.android.vending"))
                    } catch (_: ActivityNotFoundException) {
                        startActivity(Intent(Intent.ACTION_VIEW, listing))
                    }
                    result.success(null)
                } catch (_: Exception) {
                    result.error("STORE_UNAVAILABLE", "Could not open Google Play.", null)
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Protect the entire Flutter window before any screen is rendered,
        // including debug builds. This stays enabled across route changes.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }
}

