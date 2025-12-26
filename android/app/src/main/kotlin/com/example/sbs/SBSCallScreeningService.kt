package com.example.sbs

import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import androidx.annotation.RequiresApi
import android.content.Intent

/**
 * CallScreeningService - HIGHEST PRIORITY CALLER ID API
 * 
 * This service is triggered BEFORE the phone rings, giving SBS
 * the earliest possible opportunity to show caller information.
 * 
 * Priority order:
 * 1. CallScreeningService (THIS) - Runs BEFORE ring
 * 2. PHONE_STATE broadcast - Runs when ringing
 * 3. TelephonyCallback - Runs after broadcast
 */
@RequiresApi(Build.VERSION_CODES.N)
class SBSCallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "SBSCallScreening"
    }

    override fun onScreenCall(callDetails: Call.Details) {
        Log.d(TAG, "⚡ CALL SCREENING - EARLIEST DETECTION!")
        
        // Extract phone number
        val phoneNumber = callDetails.handle?.schemeSpecificPart
        Log.d(TAG, "📞 Screening call from: $phoneNumber")
        
        if (phoneNumber != null) {
            // Trigger overlay service INSTANTLY
            val intent = Intent(this, CallOverlayService::class.java).apply {
                action = if (callDetails.callDirection == Call.Details.DIRECTION_INCOMING) {
                    "com.example.sbs.INCOMING_CALL"
                } else {
                    "com.example.sbs.OUTGOING_CALL"
                }
                putExtra("phone_number", phoneNumber)
                putExtra("from_screening", true) // Flag to indicate early detection
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            
            Log.d(TAG, "✅ Overlay service triggered from screening")
        }
        
        // CRITICAL: Respond to allow the call through
        // Don't block or silence - just observe and trigger our overlay
        val response = CallScreeningService.CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build()
        
        respondToCall(callDetails, response)
        Log.d(TAG, "✅ Call allowed through to system")
    }
}
