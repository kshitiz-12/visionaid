package com.visionaid.visionaid

import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Session
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val walkingChannel = "visionaid/walking"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, walkingChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "capabilities") {
                    result.success(probeCapabilities())
                } else {
                    result.notImplemented()
                }
            }
    }

    /// ARCore Depth cannot share the Flutter CameraX session, so walking still
    /// uses the box-size fallback for metres. This probe is for capability UI.
    private fun probeCapabilities(): Map<String, Any> {
        var arcore = false
        var depth = false
        try {
            val availability = ArCoreApk.getInstance().checkAvailability(this)
            arcore = availability.isSupported
            if (arcore) {
                val session = Session(this)
                try {
                    depth = session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)
                } finally {
                    session.close()
                }
            }
        } catch (_: Throwable) {
            arcore = false
            depth = false
        }
        return mapOf(
            "arcore" to arcore,
            "depth" to depth,
        )
    }
}
