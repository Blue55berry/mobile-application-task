package com.example.sbs

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat

/**
 * PhoneCallDetector - Universal call detection for Android 5.0 - 15
 * 
 * Uses:
 * - TelephonyCallback for Android 12+ (API 31+)
 * - PhoneStateListener for Android 8-11 (API 26-30)
 * 
 * Sends broadcasts to CallOverlayService with call state and phone number.
 */
class PhoneCallDetector(private val context: Context) {
    
    companion object {
        private const val TAG = "PhoneCallDetector"
    }
    
    interface CallStateCallback {
        fun onIncomingCall(phoneNumber: String?)
        fun onOutgoingCall(phoneNumber: String?)
        fun onCallAnswered()
        fun onCallEnded()
    }
    
    private val telephonyManager: TelephonyManager = 
        context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
    
    private var callback: CallStateCallback? = null
    private var lastState = TelephonyManager.CALL_STATE_IDLE
    private var lastPhoneNumber: String? = null
    private var isIncoming = false
    
    // For Android 12+
    @RequiresApi(Build.VERSION_CODES.S)
    private var telephonyCallback: TelephonyCallback? = null
    
    // For Android 8-11
    @Suppress("DEPRECATION")
    private var phoneStateListener: PhoneStateListener? = null
    
    fun setCallback(cb: CallStateCallback) {
        callback = cb
    }
    
    fun startListening() {
        if (!hasPhonePermission()) {
            Log.e(TAG, "Missing READ_PHONE_STATE permission")
            return
        }
        
        Log.d(TAG, "Starting phone call detection (API ${Build.VERSION.SDK_INT})")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            startTelephonyCallback()
        } else {
            startPhoneStateListener()
        }
    }
    
    fun stopListening() {
        Log.d(TAG, "Stopping phone call detection")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyCallback?.let {
                telephonyManager.unregisterTelephonyCallback(it)
                telephonyCallback = null
            }
        } else {
            @Suppress("DEPRECATION")
            phoneStateListener?.let {
                telephonyManager.listen(it, PhoneStateListener.LISTEN_NONE)
                phoneStateListener = null
            }
        }
    }
    
    fun setOutgoingNumber(number: String?) {
        Log.d(TAG, "📞 Outgoing number set: $number")
        lastPhoneNumber = number
        isIncoming = false
    }
    
    private fun hasPhonePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, 
            Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    @RequiresApi(Build.VERSION_CODES.S)
    private fun startTelephonyCallback() {
        telephonyCallback = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
            override fun onCallStateChanged(state: Int) {
                handleCallState(state, null) // Phone number not provided on Android 12+
            }
        }
        
        try {
            telephonyManager.registerTelephonyCallback(
                context.mainExecutor,
                telephonyCallback!!
            )
            Log.d(TAG, "✅ TelephonyCallback registered (Android 12+)")
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Permission denied for TelephonyCallback", e)
        }
    }
    
    @Suppress("DEPRECATION")
    private fun startPhoneStateListener() {
        phoneStateListener = object : PhoneStateListener() {
            override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                handleCallState(state, phoneNumber)
            }
        }
        
        try {
            telephonyManager.listen(
                phoneStateListener,
                PhoneStateListener.LISTEN_CALL_STATE
            )
            Log.d(TAG, "✅ PhoneStateListener registered (Android 8-11)")
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Permission denied for PhoneStateListener", e)
        }
    }
    
    private fun handleCallState(state: Int, phoneNumber: String?) {
        // Update phone number if provided (only on Android 8-11)
        if (phoneNumber != null && phoneNumber.isNotEmpty()) {
            lastPhoneNumber = phoneNumber
            if (state == TelephonyManager.CALL_STATE_RINGING) {
                isIncoming = true
            }
        }
        
        Log.d(TAG, "📞 Call state: $lastState -> $state (Phone: $lastPhoneNumber, Incoming: $isIncoming)")
        
        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                // Incoming call ringing
                if (lastState == TelephonyManager.CALL_STATE_IDLE) {
                    isIncoming = true
                    Log.d(TAG, "📞 INCOMING CALL: $lastPhoneNumber")
                    callback?.onIncomingCall(lastPhoneNumber)
                }
            }
            
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                when {
                    lastState == TelephonyManager.CALL_STATE_RINGING -> {
                        // Incoming call answered
                        Log.d(TAG, "📞 CALL ANSWERED")
                        callback?.onCallAnswered()
                    }
                    lastState == TelephonyManager.CALL_STATE_IDLE -> {
                        // Outgoing call started
                        isIncoming = false
                        Log.d(TAG, "📞 OUTGOING CALL: $lastPhoneNumber")
                        callback?.onOutgoingCall(lastPhoneNumber)
                    }
                }
            }
            
            TelephonyManager.CALL_STATE_IDLE -> {
                // Call ended
                if (lastState != TelephonyManager.CALL_STATE_IDLE) {
                    Log.d(TAG, "📞 CALL ENDED")
                    callback?.onCallEnded()
                    lastPhoneNumber = null
                    isIncoming = false
                }
            }
        }
        
        lastState = state
    }
}
