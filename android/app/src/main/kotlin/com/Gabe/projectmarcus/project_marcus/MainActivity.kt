package com.Gabe.projectmarcus.project_marcus

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var hidHandler: BluetoothHidHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            hidHandler = BluetoothHidHandler(flutterEngine.dartExecutor)
            hidHandler?.start(this)
        }
    }

    override fun onDestroy() {
        hidHandler?.destroy()
        hidHandler = null
        super.onDestroy()
    }
}
