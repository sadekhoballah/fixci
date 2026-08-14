package com.fixci.mobile

import android.app.Activity
import android.content.Intent
import android.content.IntentSender
import com.google.android.gms.auth.api.identity.GetPhoneNumberHintIntentRequest
import com.google.android.gms.auth.api.identity.Identity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result as FlutterResult

// Wraps Google Play services' Phone Number Hint API (part of Identity, not
// Firebase) for core/auth/phone_hint_service.dart. This is a thin,
// app-specific platform channel rather than a pub.dev plugin — the API
// surface is exactly one call, and writing it by hand keeps us in full
// control of the one thing that matters here: this never touches
// READ_PHONE_STATE/READ_PHONE_NUMBERS, and never can, because
// getPhoneNumberHintIntent() only ever launches a system-owned picker UI —
// the app never gets programmatic access to the device's phone numbers any
// other way.
class MainActivity : FlutterActivity() {
    private val channelName = "com.fixci.mobile/phone_hint"
    private val requestHintCode = 6_412

    // The picker's result comes back to onActivityResult, not as a return
    // value of the method call that launched it — so the Dart-side Future
    // has to stay pending until then. Only one request can be in flight at
    // a time (the Dart service enforces this too), so a single field is
    // enough rather than a code->Result map.
    private var pendingResult: FlutterResult? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "requestHint") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingResult != null) {
                    result.error("ALREADY_PENDING", "A hint request is already in flight", null)
                    return@setMethodCallHandler
                }
                requestHint(result)
            }
    }

    private fun requestHint(result: FlutterResult) {
        pendingResult = result
        val request = GetPhoneNumberHintIntentRequest.builder().build()
        Identity.getSignInClient(this)
            .getPhoneNumberHintIntent(request)
            .addOnSuccessListener { pendingIntent ->
                try {
                    startIntentSenderForResult(
                        pendingIntent.intentSender,
                        requestHintCode,
                        null,
                        0,
                        0,
                        0,
                    )
                } catch (e: IntentSender.SendIntentException) {
                    // Couldn't even launch the picker — treat exactly like
                    // "no hint available" (see onActivityResult below), the
                    // Dart side can't tell the difference and shouldn't need
                    // to: either way there's nothing to offer the user.
                    finishHint(null)
                }
            }
            // The device/account genuinely has nothing to offer (no
            // telephony, no Play services account, etc.) — this is the
            // "empty result" case OnboardingController's fallback expects,
            // most commonly a SIM whose carrier never wrote a number to it.
            .addOnFailureListener { finishHint(null) }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != requestHintCode) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        if (resultCode != Activity.RESULT_OK || data == null) {
            // Covers both a genuinely empty picker and the user dismissing
            // it — Android's Hint API doesn't expose which one happened
            // (see phone_hint_service.dart), so both fall back the same way.
            finishHint(null)
            return
        }
        val phoneNumber = try {
            Identity.getSignInClient(this).getPhoneNumberFromIntent(data)
        } catch (e: Exception) {
            null
        }
        finishHint(phoneNumber)
    }

    private fun finishHint(phoneNumber: String?) {
        pendingResult?.success(phoneNumber)
        pendingResult = null
    }
}
