package com.netsource.sentinel

import com.netsource.sentinel.ads.SentinelAdsBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SentinelAdsBridge.register(this, flutterEngine)
    }
}
