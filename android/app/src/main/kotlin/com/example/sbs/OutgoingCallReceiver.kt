package com.example.sbs

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * OutgoingCallReceiver
 * 
 * Static BroadcastReceiver that captures outgoing call phone numbers.
 */
class OutgoingCallReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "OutgoingCallReceiver"
    }
    
    @Suppress("DEPRECATION")
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_NEW_OUTGOING_CALL) return
        
        val phoneNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
        
        Log.d(TAG, "📞 OUTGOING CALL to: $phoneNumber")
        
        if (phoneNumber != null && phoneNumber.isNotEmpty()) {
            // Start the overlay service with the phone number
            val serviceIntent = Intent(context, CallOverlayService::class.java).apply {
                action = "com.example.sbs.OUTGOING_CALL"
                putExtra("phone_number", phoneNumber)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}
