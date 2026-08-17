package com.adigitalid.app

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and exposes a small channel that opens the system
 * biometric-enrolment screen.
 *
 * Android never lets an app enrol a fingerprint itself — enrolment lives in
 * Settings and is guarded by the device credential. The best an app can do is
 * hand the user straight to the right screen, which is what this channel does,
 * so an applicant whose finger is not yet enrolled can add it and come back
 * without hunting through Settings.
 */
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canOpenEnrollment" -> result.success(true)
                    "openEnrollment" -> result.success(openEnrollment())
                    "openBiometricSettings" -> result.success(openBiometricSettings())
                    else -> result.notImplemented()
                }
            }
    }

    /** Launches the most specific *enrolment* screen this API level offers. */
    private fun openEnrollment(): Boolean = startFirstAvailable(
        buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                add(
                    Intent(Settings.ACTION_BIOMETRIC_ENROLL).putExtra(
                        Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                        // BiometricManager.Authenticators.BIOMETRIC_STRONG —
                        // inlined so the app module needs no extra dependency.
                        BIOMETRIC_STRONG,
                    )
                )
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                add(Intent(Settings.ACTION_FINGERPRINT_ENROLL))
            }
            addAll(securityFallbacks())
        }
    )

    /**
     * Opens the screen that lists enrolled fingerprints, so an operator can
     * delete an applicant's print once their card has been issued.
     */
    private fun openBiometricSettings(): Boolean = startFirstAvailable(
        buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                add(Intent(Settings.ACTION_FINGERPRINT_ENROLL))
            }
            addAll(securityFallbacks())
        }
    )

    private fun securityFallbacks(): List<Intent> = listOf(
        Intent(Settings.ACTION_SECURITY_SETTINGS),
        Intent(Settings.ACTION_SETTINGS),
    )

    /** Tries each screen in turn, stopping at the first the device can show. */
    private fun startFirstAvailable(intents: List<Intent>): Boolean {
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // Try the next, less specific, screen.
            }
        }
        return false
    }

    private companion object {
        const val CHANNEL = "com.adigitalid.app/biometric"
        const val BIOMETRIC_STRONG = 0x000000ff
    }
}
