package com.netsource.sentinel.ads

import android.app.Activity
import android.content.Context
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.work.WorkManager
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform

class GoogleAdsRuntime(
    private val activity: Activity,
) : AdsRuntime {
    private val consentInformation: ConsentInformation by lazy {
        UserMessagingPlatform.getConsentInformation(activity)
    }

    private var initializing = false
    private var initialized = false
    private var workManagerReady = false
    private var mobileAdsInitialized = false
    private var canRequestAds = false
    private var privacyOptionsRequired = false
    private var lastError: String? = null

    override fun initialize(callback: (Map<String, Any?>) -> Unit) {
        activity.runOnUiThread {
            if (initialized || initializing) {
                callback(state())
                return@runOnUiThread
            }

            initializing = true
            lastError = null

            // Real-device logs showed AndroidX Startup crashing the process while
            // creating WorkManager's WorkDatabase before MainActivity. Startup
            // initialization is disabled in the manifest. Force the same work
            // database creation here, after Sentinel is visible, on a background
            // thread and under Throwable protection. If it still fails, ads are
            // simply unavailable for this session.
            preflightWorkManager(callback)
        }
    }

    private fun preflightWorkManager(callback: (Map<String, Any?>) -> Unit) {
        Thread {
            try {
                WorkManager.getInstance(activity.applicationContext)
                workManagerReady = true
                activity.runOnUiThread {
                    beginConsentInitialization(callback)
                }
            } catch (error: Throwable) {
                activity.runOnUiThread {
                    workManagerReady = false
                    canRequestAds = false
                    lastError = "Advertising disabled: ${error.safeAdsMessage()}"
                    initialized = true
                    initializing = false
                    callback(state())
                }
            }
        }.apply {
            name = "SentinelAdsWorkManagerPreflight"
            isDaemon = true
        }.start()
    }

    private fun beginConsentInitialization(callback: (Map<String, Any?>) -> Unit) {
        if (!workManagerReady) {
            initialized = true
            initializing = false
            canRequestAds = false
            callback(state())
            return
        }

        try {
            val params = ConsentRequestParameters.Builder().build()
            consentInformation.requestConsentInfoUpdate(
                activity,
                params,
                {
                    try {
                        UserMessagingPlatform.loadAndShowConsentFormIfRequired(
                            activity,
                        ) { formError ->
                            if (formError != null) {
                                lastError = formError.message
                            }
                            finishInitialization(callback)
                        }
                    } catch (error: Throwable) {
                        lastError = error.safeAdsMessage()
                        finishInitialization(callback)
                    }
                },
                { requestError ->
                    // UMP can still have usable consent from a previous app
                    // session, so refresh canRequestAds even when the update
                    // request itself fails.
                    lastError = requestError.message
                    finishInitialization(callback)
                },
            )
        } catch (error: Throwable) {
            lastError = error.safeAdsMessage()
            finishInitialization(callback)
        }
    }

    override fun showPrivacyOptions(callback: (Map<String, Any?>) -> Unit) {
        activity.runOnUiThread {
            if (!workManagerReady) {
                callback(state())
                return@runOnUiThread
            }
            try {
                UserMessagingPlatform.showPrivacyOptionsForm(activity) { formError ->
                    if (formError != null) {
                        lastError = formError.message
                    } else {
                        lastError = null
                    }
                    refreshConsentState()
                    initializeMobileAdsIfAllowed(callback)
                }
            } catch (error: Throwable) {
                lastError = error.safeAdsMessage()
                refreshConsentState()
                callback(state())
            }
        }
    }

    override fun state(): Map<String, Any?> = mapOf(
        "initialized" to initialized,
        "canRequestAds" to canRequestAds,
        "privacyOptionsRequired" to privacyOptionsRequired,
        "lastError" to lastError,
    )

    override fun createBanner(context: Context, adUnitId: String): View {
        val container = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(context, 50),
            )
        }

        if (!workManagerReady ||
            !canRequestAds ||
            !mobileAdsInitialized ||
            adUnitId.isBlank()
        ) {
            return container
        }

        try {
            val adView = AdView(context).apply {
                setAdSize(AdSize.BANNER)
                this.adUnitId = adUnitId
            }

            adView.adListener = object : AdListener() {
                override fun onAdFailedToLoad(loadAdError: LoadAdError) {
                    lastError = loadAdError.message
                    try {
                        adView.destroy()
                        container.removeAllViews()
                    } catch (_: Throwable) {
                        // A failed ad is not allowed to affect Sentinel.
                    }
                }
            }

            container.addView(
                adView,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER,
                ),
            )
            container.tag = adView
            adView.loadAd(AdRequest.Builder().build())
        } catch (error: Throwable) {
            lastError = error.safeAdsMessage()
            try {
                container.removeAllViews()
            } catch (_: Throwable) {
                // Keep the platform view alive but empty.
            }
        }

        return container
    }

    override fun disposeBanner(view: View) {
        val container = view as? FrameLayout ?: return
        val adView = container.tag as? AdView
        try {
            adView?.destroy()
            container.removeAllViews()
            container.tag = null
        } catch (_: Throwable) {
            // Advertising teardown must never affect firewall management.
        }
    }

    private fun finishInitialization(callback: (Map<String, Any?>) -> Unit) {
        refreshConsentState()
        initializeMobileAdsIfAllowed(callback)
    }

    private fun refreshConsentState() {
        try {
            canRequestAds = workManagerReady && consentInformation.canRequestAds()
            privacyOptionsRequired =
                consentInformation.privacyOptionsRequirementStatus ==
                ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
        } catch (error: Throwable) {
            lastError = lastError ?: error.safeAdsMessage()
            canRequestAds = false
            privacyOptionsRequired = false
        }
    }

    private fun initializeMobileAdsIfAllowed(
        callback: (Map<String, Any?>) -> Unit,
    ) {
        if (!workManagerReady || !canRequestAds || mobileAdsInitialized) {
            initialized = true
            initializing = false
            callback(state())
            return
        }

        try {
            MobileAds.initialize(activity) {
                activity.runOnUiThread {
                    mobileAdsInitialized = true
                    initialized = true
                    initializing = false
                    callback(state())
                }
            }
        } catch (error: Throwable) {
            lastError = error.safeAdsMessage()
            canRequestAds = false
            initialized = true
            initializing = false
            callback(state())
        }
    }

    private fun dp(context: Context, value: Int): Int {
        return (value * context.resources.displayMetrics.density).toInt()
    }
}

private fun Throwable.safeAdsMessage(): String {
    return message?.takeIf { it.isNotBlank() }
        ?: this::class.java.simpleName
        ?: "Google advertising error"
}
