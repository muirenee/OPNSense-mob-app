package com.netsource.sentinel.ads

import android.app.Activity
import android.util.Log
import com.google.android.libraries.ads.mobile.sdk.MobileAds
import com.google.android.libraries.ads.mobile.sdk.initialization.InitializationConfig

object NextGenAdsRuntime {
    private const val TAG = "SentinelNextGenAds"

    @JvmStatic
    fun initialize(activity: Activity, appId: String) {
        Thread {
            try {
                val config = InitializationConfig.Builder(appId).build()
                MobileAds.initialize(activity.applicationContext, config) {
                    Log.i(TAG, "GMA Next-Gen adapter initialization completed")
                }
                Log.i(TAG, "GMA Next-Gen SDK initialization returned")
            } catch (error: Throwable) {
                Log.e(TAG, "GMA Next-Gen initialization failed", error)
            }
        }.start()
    }
}
