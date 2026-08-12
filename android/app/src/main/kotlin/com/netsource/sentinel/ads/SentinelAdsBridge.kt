package com.netsource.sentinel.ads

import android.app.Activity
import android.content.Context
import android.view.View
import android.widget.FrameLayout
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

object SentinelAdsBridge {
    private const val CHANNEL_NAME = "com.netsource.sentinel/ads"
    private const val VIEW_TYPE = "com.netsource.sentinel/banner"

    fun register(activity: Activity, flutterEngine: FlutterEngine) {
        val bridge = Bridge(activity)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> bridge.initialize(result)
                "showPrivacyOptions" -> bridge.showPrivacyOptions(result)
                "state" -> result.success(bridge.state())
                else -> result.notImplemented()
            }
        }

        flutterEngine.platformViewsController.registry.registerViewFactory(
            VIEW_TYPE,
            BannerFactory(bridge),
        )
    }

    private class Bridge(private val activity: Activity) {
        private var runtime: AdsRuntime? = null
        private var runtimeLoadAttempted = false
        private var bridgeError: String? = null

        fun initialize(result: MethodChannel.Result) {
            val adsRuntime = ensureRuntime()
            if (adsRuntime == null) {
                result.success(state())
                return
            }

            try {
                adsRuntime.initialize { value -> result.success(value) }
            } catch (error: Throwable) {
                bridgeError = error.safeMessage()
                result.success(state())
            }
        }

        fun showPrivacyOptions(result: MethodChannel.Result) {
            val adsRuntime = ensureRuntime()
            if (adsRuntime == null) {
                result.success(state())
                return
            }

            try {
                adsRuntime.showPrivacyOptions { value -> result.success(value) }
            } catch (error: Throwable) {
                bridgeError = error.safeMessage()
                result.success(state())
            }
        }

        fun state(): Map<String, Any?> {
            val adsRuntime = runtime
            if (adsRuntime != null) {
                return try {
                    adsRuntime.state()
                } catch (error: Throwable) {
                    bridgeError = error.safeMessage()
                    fallbackState()
                }
            }
            return fallbackState()
        }

        fun createBanner(context: Context, args: Any?): View {
            val adsRuntime = runtime ?: return FrameLayout(context)
            val adUnitId = (args as? Map<*, *>)?.get("adUnitId") as? String
            if (adUnitId.isNullOrBlank()) return FrameLayout(context)

            return try {
                adsRuntime.createBanner(context, adUnitId)
            } catch (error: Throwable) {
                bridgeError = error.safeMessage()
                FrameLayout(context)
            }
        }

        fun disposeBanner(view: View) {
            try {
                runtime?.disposeBanner(view)
            } catch (_: Throwable) {
                // Advertising teardown must never affect Sentinel navigation.
            }
        }

        private fun ensureRuntime(): AdsRuntime? {
            runtime?.let { return it }
            if (runtimeLoadAttempted) return null
            runtimeLoadAttempted = true

            return try {
                // Load the Google-dependent implementation only after Dart asks
                // for ads. MainActivity and Flutter engine startup therefore do
                // not initialize or even directly reference Google Ads classes.
                val runtimeClass = Class.forName(
                    "com.netsource.sentinel.ads.GoogleAdsRuntime",
                )
                val constructor = runtimeClass.getConstructor(Activity::class.java)
                (constructor.newInstance(activity) as AdsRuntime).also {
                    runtime = it
                    bridgeError = null
                }
            } catch (error: Throwable) {
                bridgeError = error.safeMessage()
                null
            }
        }

        private fun fallbackState(): Map<String, Any?> = mapOf(
            "initialized" to true,
            "canRequestAds" to false,
            "privacyOptionsRequired" to false,
            "lastError" to bridgeError,
        )
    }

    private class BannerFactory(
        private val bridge: Bridge,
    ) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
            return BannerPlatformView(
                bridge = bridge,
                view = bridge.createBanner(context, args),
            )
        }
    }

    private class BannerPlatformView(
        private val bridge: Bridge,
        private val view: View,
    ) : PlatformView {
        override fun getView(): View = view

        override fun dispose() {
            bridge.disposeBanner(view)
        }
    }
}

private fun Throwable.safeMessage(): String {
    return message?.takeIf { it.isNotBlank() }
        ?: this::class.java.simpleName
        ?: "Native advertising error"
}
