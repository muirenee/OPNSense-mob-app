package com.netsource.sentinel.ads

import android.content.Context
import android.view.View

interface AdsRuntime {
    fun initialize(callback: (Map<String, Any?>) -> Unit)

    fun showPrivacyOptions(callback: (Map<String, Any?>) -> Unit)

    fun state(): Map<String, Any?>

    fun createBanner(context: Context, adUnitId: String): View

    fun disposeBanner(view: View)
}
