package com.rethinkandrevive1.golddustgardening

import com.zohosalesiq.plugin.MobilistenPlugin
import io.flutter.app.FlutterApplication

class MyFlutterApplication : FlutterApplication() {

    override fun onCreate() {
        MobilistenPlugin.registerCallbacks(this)
        super.onCreate()
    }
}