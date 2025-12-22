package com.example.sbs

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.telephony.PhoneStateListener
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * CallStateReceiver
 * 
 * Detects incoming and outgoing call states using:
 * - TelephonyCallback (Android 12+ / API 31+)
 * - PhoneStateListener (Android 8-11 / API 26-30)
 * 
 * Sends broadcasts to CallOverlayService with phone number and call state.
 */
class CallStateReceiver(private val context: Context) {
    
    companion object {
        private const val TAG = "CallStateReceiver"
        
        // Broadcast actions
        const val ACTION_INCOMING_CALL = "com.example.sbs.INCOMING_CALL"
        const val ACTION_OUTGOING_CALL = "com.example.sbs.OUTGOING_CALL"
        const val ACTION_CALL_STARTED = "com.example.sbs.CALL_STARTED"
        const val ACTION_CALL_ENDED = "com.example.sbs.CALL_ENDED"
        
        // Intent extras
        const val EXTRA_PHONE_NUMBER = "phone_number"
    }
    
    private val telephonyManager: TelephonyManager =
        context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
    
    private var currentPhoneNumber: String? = null
    private var lastCallState = TelephonyManager.CALL_STATE_IDLE
    private var isOutgoingCall = false
    
    // For Android 12+
    @RequiresApi(Build.VERSION_CODES.S)
    private var telephonyCallback: TelephonyCallback? = null
    
    // For Android 8-11
    @Suppress("DEPRECATION")
    private var phoneStateListener: PhoneStateListener? = null
    
    /**
     * Start listening to call state changes
     */
    fun startListening() {
        Log.d(TAG, "Starting call state listener (API ${Build.VERSION.SDK_INT})")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+ (API 31+)
            startTelephonyCallback()
        } else {
            // Android 8-11 (API 26-30)
            startPhoneStateListener()
        }
    }
    
    /**
     * Stop listening to call state changes
     */
    fun stopListening() {
        Log.d(TAG, "Stopping call state listener")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyCallback?.let {
                telephonyManager.unregisterTelephonyCallback(it)
            }
            telephonyCallback = null
        } else {
            @Suppress("DEPRECATION")
            phoneStateListener?.let {
                telephonyManager.listen(it, PhoneStateListener.LISTEN_NONE)
            }
            phoneStateListener = null
        }
        
        currentPhoneNumber = null
        lastCallState = TelephonyManager.CALL_STATE_IDLE
    }
    
    /**
     * Set phone number for outgoing calls (called from MainActivity)
     */
    fun setOutgoingNumber(phoneNumber: String?) {
        Log.d(TAG, "Outgoing call detected: $phoneNumber")
        currentPhoneNumber = phoneNumber
        isOutgoingCall = true
    }
    
    /**
     * Android 12+ implementation using TelephonyCallback
     * Note: On Android 12+, the phone number is NOT provided in the callback.
     * We need to get it from the CallLog for incoming calls.
     */
    @RequiresApi(Build.VERSION_CODES.S)
    private fun startTelephonyCallback() {
        telephonyCallback = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
            override fun onCallStateChanged(state: Int) {
                // For incoming calls on Android 12+, get phone number from CallLog
                if (state == TelephonyManager.CALL_STATE_RINGING && currentPhoneNumber == null) {
                    getLastIncomingNumber()?.let { number ->
                        currentPhoneNumber = number
                        isOutgoingCall = false
                        Log.d(TAG, "📞 Got incoming number from CallLog: $number")
                    }
                }
                handleCallStateChange(state)
            }
        }
        
        try {
            telephonyManager.registerTelephonyCallback(
                context.mainExecutor,
                telephonyCallback!!
            )
            Log.d(TAG, "TelephonyCallback registered successfully")
        } catch (e: SecurityException) {
            Log.e(TAG, "Permission denied for phone state monitoring", e)
        }
    }
    
    /**
     * Get the last incoming call number from CallLog
     * Used for Android 12+ where TelephonyCallback doesn't provide the number
     */
    private fun getLastIncomingNumber(): String? {
        try {
            val cursor = context.contentResolver.query(
                android.provider.CallLog.Calls.CONTENT_URI,
                arrayOf(android.provider.CallLog.Calls.NUMBER, android.provider.CallLog.Calls.TYPE),
                "${android.provider.CallLog.Calls.TYPE} = ?",
                arrayOf(android.provider.CallLog.Calls.INCOMING_TYPE.toString()),
                "${android.provider.CallLog.Calls.DATE} DESC"
            )
            
            cursor?.use {
                if (it.moveToFirst()) {
                    return it.getString(0)
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Permission denied to read CallLog", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error reading CallLog", e)
        }
        return null
    }
    
    /**
     * Android 8-11 implementation using PhoneStateListener
     */
    @Suppress("DEPRECATION")
    private fun startPhoneStateListener() {
        phoneStateListener = object : PhoneStateListener() {
            override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                // For incoming calls, phone number is provided here
                if (state == TelephonyManager.CALL_STATE_RINGING && phoneNumber != null) {
                    currentPhoneNumber = phoneNumber
                    isOutgoingCall = false
                }
                handleCallStateChange(state)
            }
        }
        
        try {
            telephonyManager.listen(
                phoneStateListener,
                PhoneStateListener.LISTEN_CALL_STATE
            )
            Log.d(TAG, "PhoneStateListener registered successfully")
        } catch (e: SecurityException) {
            Log.e(TAG, "Permission denied for phone state monitoring", e)
        }
    }
    
    /**
     * Handle call state changes (common logic for both implementations)
     */
    private fun handleCallStateChange(state: Int) {
        Log.d(TAG, "Call state changed: $lastCallState -> $state (Phone: $currentPhoneNumber)")
        
        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                // Incoming call
                if (lastCallState == TelephonyManager.CALL_STATE_IDLE) {
                    onIncomingCall(currentPhoneNumber)
                }
            }
            
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                // Call started (either answered incoming or outgoing connected)
                if (lastCallState == TelephonyManager.CALL_STATE_RINGING) {
                    // Answered incoming call
                    onCallStarted()
                } else if (lastCallState == TelephonyManager.CALL_STATE_IDLE && isOutgoingCall) {
                    // Outgoing call connected
                    onCallStarted()
                } else if (lastCallState == TelephonyManager.CALL_STATE_IDLE) {
                    // Outgoing call initiated (broadcast outgoing call event)
                    onOutgoingCall(currentPhoneNumber)
                }
            }
            
            TelephonyManager.CALL_STATE_IDLE -> {
                // Call ended
                if (lastCallState != TelephonyManager.CALL_STATE_IDLE) {
                    onCallEnded()
                    // Reset state
                    currentPhoneNumber = null
                    isOutgoingCall = false
                }
            }
        }
        
        lastCallState = state
    }
    
    /**
     * Broadcast incoming call event
     */
    private fun onIncomingCall(phoneNumber: String?) {
        Log.d(TAG, "📞 INCOMING CALL: $phoneNumber")
        val intent = Intent(ACTION_INCOMING_CALL).apply {
            putExtra(EXTRA_PHONE_NUMBER, phoneNumber ?: "Unknown")
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)
    }
    
    /**
     * Broadcast outgoing call event
     */
    private fun onOutgoingCall(phoneNumber: String?) {
        Log.d(TAG, "📞 OUTGOING CALL: $phoneNumber")
        val intent = Intent(ACTION_OUTGOING_CALL).apply {
            putExtra(EXTRA_PHONE_NUMBER, phoneNumber ?: "Unknown")
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)
    }
    
    /**
     * Broadcast call started event
     */
    private fun onCallStarted() {
        Log.d(TAG, "📞 CALL STARTED")
        val intent = Intent(ACTION_CALL_STARTED).apply {
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)
    }
    
    /**
     * Broadcast call ended event
     */
    private fun onCallEnded() {
        Log.d(TAG, "📞 CALL ENDED")
        val intent = Intent(ACTION_CALL_ENDED).apply {
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)
    }
}
