package com.crispytivi.crispy_tivi

import android.app.AppOpsManager
import android.app.PictureInPictureParams
import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import com.crispytivi.crispy_tivi.hdr.CrispyHdrPlayerPlugin

class MainActivity: FlutterActivity() {
    private val channel = "crispy/pip"

    // Auto PiP state
    private var autoPipReady = false
    private var autoPipWidth: Int = 16
    private var autoPipHeight: Int = 9

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register HDR native player plugin (Media3 ExoPlayer + SurfaceView)
        flutterEngine.plugins.add(CrispyHdrPlayerPlugin())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        result.success(mapOf("success" to false, "errorCode" to "android_version"))
                        return@setMethodCallHandler
                    }

                    if (!isPipPermissionGranted()) {
                        result.success(mapOf("success" to false, "errorCode" to "permission_disabled"))
                        return@setMethodCallHandler
                    }

                    try {
                        val width = call.argument<Int>("width") ?: 16
                        val height = call.argument<Int>("height") ?: 9
                        val clamped = clampAspectRatio(width, height)

                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(Rational(clamped.first, clamped.second))
                            .build()
                        val success = enterPictureInPictureMode(params)
                        if (success) {
                            result.success(mapOf("success" to true))
                        } else {
                            result.success(mapOf("success" to false, "errorCode" to "failed"))
                        }
                    } catch (e: IllegalStateException) {
                        result.success(mapOf("success" to false, "errorCode" to "not_supported"))
                    } catch (e: Exception) {
                        result.success(mapOf("success" to false, "errorCode" to "unknown", "errorMessage" to (e.message ?: "Unknown error")))
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
                "setAutoPipReady" -> {
                    autoPipReady = call.argument<Boolean>("ready") ?: false
                    autoPipWidth = call.argument<Int>("width") ?: 16
                    autoPipHeight = call.argument<Int>("height") ?: 9

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val clamped = clampAspectRatio(autoPipWidth, autoPipHeight)
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(clamped.first, clamped.second))
                                .setAutoEnterEnabled(autoPipReady)
                                .build()
                            setPictureInPictureParams(params)
                        } catch (_: Exception) {}
                    }
                    result.success(true)
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

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Auto PiP for API 26-30 (API 31+ uses setAutoEnterEnabled)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S &&
            autoPipReady && isPipPermissionGranted()) {
            try {
                val clamped = clampAspectRatio(autoPipWidth, autoPipHeight)
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(clamped.first, clamped.second))
                    .build()
                enterPictureInPictureMode(params)
            } catch (_: Exception) {}
        }
    }

    private fun isPipPermissionGranted(): Boolean {
        val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOpsManager.checkOpNoThrow(
            AppOpsManager.OPSTR_PICTURE_IN_PICTURE,
            applicationInfo.uid,
            packageName
        ) == AppOpsManager.MODE_ALLOWED
    }

    private fun clampAspectRatio(width: Int, height: Int): Pair<Int, Int> {
        val ratio = width.toFloat() / height.toFloat()
        return when {
            ratio < 0.42f -> Pair(5, 12)
            ratio > 2.39f -> Pair(12, 5)
            else -> Pair(width, height)
        }
    }
}
