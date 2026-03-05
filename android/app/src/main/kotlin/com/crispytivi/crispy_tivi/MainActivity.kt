package com.crispytivi.crispy_tivi

import android.app.PictureInPictureParams
import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channel = "crispy/pip"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val aspectRatio = Rational(16, 9)
                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(aspectRatio)
                            .build()
                        enterPictureInPictureMode(params)
                        result.success(null)
                    } else {
                        result.error("UNAVAILABLE", "PiP not supported on this Android version", null)
                    }
                }
                "exitPip" -> {
                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                    if (intent != null) {
                        intent.flags = android.content.Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                        startActivity(intent)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "crispy/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "getFormFactor" -> {
                    val isLeanback = packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_LEANBACK)
                    val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                    val isTvMode = uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                    if (isLeanback || isTvMode) {
                        result.success("tv")
                    } else {
                        result.success("mobile")
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, channel).invokeMethod("onNativePipChanged", mapOf("isInPip" to isInPictureInPictureMode))
        }
    }
}
