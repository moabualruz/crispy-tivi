package com.crispytivi.crispy_tivi.hdr

import android.content.Context
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.os.Build
import android.view.Display

/// Runtime HDR support detection.
///
/// Checks both display-level HDR capability and codec-level
/// HDR format support (HDR10, HDR10+, Dolby Vision, HLG).
object HdrCapabilityDetector {

    /// Check if the current display supports HDR output.
    fun isHdrSupported(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val display = getDisplay(context) ?: return false
        return display.isHdr
    }

    /// Get list of supported HDR format names from MediaCodec.
    fun getSupportedFormats(context: Context): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return emptyList()

        val formats = mutableSetOf<String>()
        val codecList = MediaCodecList(MediaCodecList.ALL_CODECS)

        for (info in codecList.codecInfos) {
            if (info.isEncoder) continue
            for (type in info.supportedTypes) {
                if (!type.startsWith("video/")) continue
                try {
                    val caps = info.getCapabilitiesForType(type)
                    for (profile in caps.profileLevels) {
                        classifyProfile(type, profile.profile)?.let { formats.add(it) }
                    }
                } catch (_: Exception) {
                    // Some codecs throw on getCapabilitiesForType
                }
            }
        }
        return formats.toList()
    }

    private fun classifyProfile(mimeType: String, profile: Int): String? {
        // HEVC HDR profiles
        if (mimeType == "video/hevc") {
            return when (profile) {
                MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10 -> "hdr10"
                MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10 -> "hdr10"
                MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10Plus -> "hdr10_plus"
                else -> null
            }
        }
        // AV1 HDR profiles
        if (mimeType == "video/av01") {
            return when (profile) {
                MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10 -> "hdr10"
                MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10HDR10 -> "hdr10"
                MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10HDR10Plus -> "hdr10_plus"
                else -> null
            }
        }
        // Dolby Vision
        if (mimeType == "video/dolby-vision") {
            return "dolby_vision"
        }
        return null
    }

    @Suppress("DEPRECATION")
    private fun getDisplay(context: Context): Display? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            context.display
        } else {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as? android.view.WindowManager
            wm?.defaultDisplay
        }
    }
}
