package com.netsource.sentinel

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.netsource.sentinel/ads_diag",
        ).setMethodCallHandler { call, result ->
            if (call.method != "initializeNextGen") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val appId = call.argument<String>("appId")?.trim().orEmpty()
            if (appId.isEmpty()) {
                result.error("missing_app_id", "Missing AdMob app ID.", null)
                return@setMethodCallHandler
            }

            try {
                // Keep every GMA Next-Gen class out of the normal Flutter
                // startup path. The runtime class is resolved only when Dart
                // explicitly asks for the diagnostic initialization.
                val runtime = Class.forName(
                    "com.netsource.sentinel.ads.NextGenAdsRuntime",
                )
                val initialize = runtime.getMethod(
                    "initialize",
                    android.app.Activity::class.java,
                    String::class.java,
                )
                initialize.invoke(null, this, appId)
                result.success(true)
            } catch (error: Throwable) {
                result.error(
                    "next_gen_init_bridge",
                    error.cause?.message ?: error.message ?: error.toString(),
                    null,
                )
            }
        }
    }
}
