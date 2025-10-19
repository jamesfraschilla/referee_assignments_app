package com.example.referee_assignments_app

import dev.fluttercommunity.workmanager.WorkmanagerPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WorkmanagerPlugin.setPluginRegistrantCallback { registry ->
            GeneratedPluginRegistrant.registerWith(registry)
        }
    }
}
