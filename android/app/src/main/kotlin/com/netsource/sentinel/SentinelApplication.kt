package com.netsource.sentinel

import android.app.Application
import android.util.Log
import androidx.work.Configuration

/**
 * Provides WorkManager configuration without creating its database during
 * process startup. AndroidX Startup is disabled in the manifest; the first
 * WorkManager.getInstance(context) call initializes it on demand.
 */
class SentinelApplication : Application(), Configuration.Provider {
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setMinimumLoggingLevel(Log.WARN)
            .build()
}
