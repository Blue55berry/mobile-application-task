package com.example.sbs

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log

/**
 * IncomingCallReceiver
 * 
 * Static BroadcastReceiver that captures incoming call phone numbers.
 * This is the most reliable way to get phone numbers across all Android versions.
 */
class IncomingCallReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "IncomingCallReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
        
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
        val phoneNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        
        Log.d(TAG, "📞 Phone state: $state, Number: $phoneNumber")
        
        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                // IMMEDIATELY start service to show popup - DON'T WAIT for phone number!
                Log.d(TAG, "📞 PHONE RINGING - showing popup IMMEDIATELY!")
                
                val serviceIntent = Intent(context, CallOverlayService::class.java).apply {
                    action = "com.example.sbs.INCOMING_CALL"
                    // Pass phone number if available, otherwise "Unknown"
                    putExtra("phone_number", phoneNumber ?: "Unknown")
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
            
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                Log.d(TAG, "📞 Call answered/started")
                val serviceIntent = Intent(context, CallOverlayService::class.java).apply {
                    action = "com.example.sbs.CALL_STARTED"
                    if (phoneNumber != null) putExtra("phone_number", phoneNumber)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
            
            TelephonyManager.EXTRA_STATE_IDLE -> {
                Log.d(TAG, "📞 Call ended")
                val serviceIntent = Intent(context, CallOverlayService::class.java).apply {
                    action = "com.example.sbs.CALL_ENDED"
                }
                context.startService(serviceIntent)
            }
        }
    }
}
