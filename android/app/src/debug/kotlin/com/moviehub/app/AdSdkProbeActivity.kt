package com.moviehub.app

import android.app.Activity
import android.os.Bundle
import android.util.Log
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.RequestConfiguration
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback

/** Debug-only, Google demo inventory; no Flutter, Film365 or publisher ad units. */
class AdSdkProbeActivity : Activity() {
    private lateinit var status: TextView
    private lateinit var banner: AdView
    private var interstitial: InterstitialAd? = null

    private fun record(message: String) {
        Log.i("AdSdkProbe", message)
        status.append("\n$message\n")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        status = TextView(this).apply { text = "Native SDK demo-ad diagnostic" }
        layout.addView(status)
        banner = AdView(this).apply {
            adUnitId = "ca-app-pub-3940256099942544/6300978111"
            setAdSize(AdSize.BANNER)
            adListener = object : AdListener() {
                override fun onAdLoaded() { record("banner loaded") }
                override fun onAdFailedToLoad(error: LoadAdError) {
                    record("banner failed: $error")
                }
            }
        }
        layout.addView(banner)
        setContentView(layout)
        val restricted = intent.getBooleanExtra("restricted", false)
        val config = RequestConfiguration.Builder()
        intent.getStringExtra("testDeviceId")?.let {
            config.setTestDeviceIds(listOf(it))
        }
        if (restricted) {
            config.setMaxAdContentRating(RequestConfiguration.MAX_AD_CONTENT_RATING_T)
            config.setTagForChildDirectedTreatment(RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_FALSE)
        }
        MobileAds.setRequestConfiguration(config.build())
        record("sdk=${MobileAds.getVersion()} restricted=$restricted package=$packageName")
        // No interstitial presentation: this diagnostic only tests loading.
        Thread {
            MobileAds.initialize(this) { initialization ->
                runOnUiThread {
                    if (isFinishing || isDestroyed) return@runOnUiThread
                    record("initialized adapters=${initialization.adapterStatusMap.keys}")
                    banner.loadAd(AdRequest.Builder().build())
                    InterstitialAd.load(this,
                        "ca-app-pub-3940256099942544/1033173712",
                        AdRequest.Builder().build(),
                        object : InterstitialAdLoadCallback() {
                            override fun onAdLoaded(ad: InterstitialAd) {
                                interstitial = ad
                                record("interstitial loaded: ${ad.responseInfo}")
                            }
                            override fun onAdFailedToLoad(error: LoadAdError) {
                                record("interstitial failed: $error")
                            }
                        })
                }
            }
        }.start()
    }

    override fun onDestroy() {
        banner.destroy()
        interstitial = null
        super.onDestroy()
    }
}
