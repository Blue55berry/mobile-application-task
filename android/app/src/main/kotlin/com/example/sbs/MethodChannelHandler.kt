package com.example.sbs

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannelHandler
 * 
 * Handles bidirectional communication between Flutter and Android native:
 * 
 * Flutter → Android:
 * - startCallMonitoring()
 * - stopCallMonitoring()
 * - queryLeadByPhone(phoneNumber)
 * - saveCallLog(callData)
 * - hasOverlayPermission()
 * - requestOverlayPermission()
 * 
 * Android → Flutter:
 * - onIncomingCall(phoneNumber, leadData)
 * - onOutgoingCall(phoneNumber, leadData)
 * - onCallStarted()
 * - onCallEnded(duration)
 */
class MethodChannelHandler(
    private val context: Context,
    private val methodChannel: MethodChannel
) : MethodChannel.MethodCallHandler {
    
    companion object {
        const val CHANNEL_NAME = "com.example.sbs/call_methods"
        private const val TAG = "MethodChannelHandler"
        
        // Static reference for access from CallOverlayService
        private var instance: MethodChannelHandler? = null
        
        fun getInstance(): MethodChannelHandler? = instance
    }
    
    init {
        instance = this
    }
    
    private var callStateReceiver: CallStateReceiver? = null
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "Method called: ${call.method}")
        
        when (call.method) {
            "startCallMonitoring" -> {
                startCallMonitoring(result)
            }
            
            "stopCallMonitoring" -> {
                stopCallMonitoring(result)
            }
            
            "queryLeadByPhone" -> {
                val phoneNumber = call.argument<String>("phoneNumber")
                queryLeadByPhone(phoneNumber, result)
            }
            
            "saveCallLog" -> {
                val callData = call.arguments as? Map<String, Any>
                saveCallLog(callData, result)
            }
            
            "hasOverlayPermission" -> {
                hasOverlayPermission(result)
            }
            
            "requestOverlayPermission" -> {
                requestOverlayPermission(result)
            }
            
            "setOutgoingNumber" -> {
                val phoneNumber = call.argument<String>("phoneNumber")
                setOutgoingNumber(phoneNumber, result)
            }
            
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * Start call monitoring service
     */
    private fun startCallMonitoring(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Starting call monitoring service...")
            
            // Initialize CallStateReceiver
            if (callStateReceiver == null) {
                callStateReceiver = CallStateReceiver(context)
            }
            
            // Start CallOverlayService
            CallOverlayService.start(context)
            
            // Start listening to call states
            callStateReceiver?.startListening()
            
            Log.d(TAG, "Call monitoring started successfully")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting call monitoring", e)
            result.error("START_ERROR", e.message, null)
        }
    }
    
    /**
     * Stop call monitoring service
     */
    private fun stopCallMonitoring(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Stopping call monitoring service...")
            
            // Stop listening
            callStateReceiver?.stopListening()
            callStateReceiver = null
            
            // Stop service
            CallOverlayService.stop(context)
            
            Log.d(TAG, "Call monitoring stopped successfully")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping call monitoring", e)
            result.error("STOP_ERROR", e.message, null)
        }
    }
    
    /**
     * Query lead data by phone number (delegated to Flutter's database)
     * This is called FROM Flutter, not TO Flutter
     */
    private fun queryLeadByPhone(phoneNumber: String?, result: MethodChannel.Result) {
        if (phoneNumber == null) {
            result.error("INVALID_ARGUMENT", "Phone number is null", null)
            return
        }
        
        // This method is actually called BY Android TO query Flutter's database
        // The implementation will be in Flutter side (DatabaseService)
        // For now, we acknowledge the call
        Log.d(TAG, "Query lead by phone: $phoneNumber (handled by Flutter)")
        result.notImplemented()
    }
    
    /**
     * Save call log (delegated to Flutter's database)
     */
    private fun saveCallLog(callData: Map<String, Any>?, result: MethodChannel.Result) {
        if (callData == null) {
            result.error("INVALID_ARGUMENT", "Call data is null", null)
            return
        }
        
        Log.d(TAG, "Save call log: $callData (handled by Flutter)")
        result.notImplemented()
    }
    
    /**
     * Check if overlay permission is granted
     */
    private fun hasOverlayPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val hasPermission = Settings.canDrawOverlays(context)
            Log.d(TAG, "Overlay permission: $hasPermission")
            result.success(hasPermission)
        } else {
            // Pre-Marshmallow doesn't need this permission
            result.success(true)
        }
    }
    
    /**
     * Request overlay permission (opens system settings)
     */
    private fun requestOverlayPermission(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${context.packageName}")
                ).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                Log.d(TAG, "Overlay permission request sent")
                result.success(true)
            } else {
                result.success(true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting overlay permission", e)
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }
    
    /**
     * Set outgoing phone number (for outgoing call detection)
     */
    private fun setOutgoingNumber(phoneNumber: String?, result: MethodChannel.Result) {
        callStateReceiver?.setOutgoingNumber(phoneNumber)
        Log.d(TAG, "Set outgoing number: $phoneNumber")
        result.success(true)
    }
    
    /**
     * Send incoming call event to Flutter
     */
    fun notifyIncomingCall(phoneNumber: String, leadData: Map<String, Any>?) {
        val data = mutableMapOf<String, Any>(
            "phoneNumber" to phoneNumber,
            "timestamp" to System.currentTimeMillis()
        )
        
        leadData?.let { data.putAll(it) }
        
        methodChannel.invokeMethod("onIncomingCall", data)
        Log.d(TAG, "Notified Flutter: onIncomingCall")
    }
    
    /**
     * Send outgoing call event to Flutter
     */
    fun notifyOutgoingCall(phoneNumber: String, leadData: Map<String, Any>?) {
        val data = mutableMapOf<String, Any>(
            "phoneNumber" to phoneNumber,
            "timestamp" to System.currentTimeMillis()
        )
        
        leadData?.let { data.putAll(it) }
        
        methodChannel.invokeMethod("onOutgoingCall", data)
        Log.d(TAG, "Notified Flutter: onOutgoingCall")
    }
    
    /**
     * Send call started event to Flutter
     */
    fun notifyCallStarted() {
        methodChannel.invokeMethod("onCallStarted", mapOf(
            "timestamp" to System.currentTimeMillis()
        ))
        Log.d(TAG, "Notified Flutter: onCallStarted")
    }
    
    /**
     * Request Flutter to save a contact to the database
     */
    fun notifySaveContact(name: String, phone: String, category: String) {
        methodChannel.invokeMethod("saveContact", mapOf(
            "name" to name,
            "phone" to phone,
            "category" to category,
            "timestamp" to System.currentTimeMillis()
        ))
        Log.d(TAG, "Notified Flutter: saveContact ($name, $phone)")
    }
    
    /**
     * Send call ended event to Flutter
     */
    fun notifyCallEnded(duration: Long) {
        methodChannel.invokeMethod("onCallEnded", mapOf(
            "duration" to duration,
            "timestamp" to System.currentTimeMillis()
        ))
        Log.d(TAG, "Notified Flutter: onCallEnded")
    }
    
    /**
     * Send new lead saved event to Flutter
     */
    fun notifyNewLeadSaved(leadId: Int, name: String, phoneNumber: String?, category: String) {
        val data = mapOf(
            "leadId" to leadId,
            "name" to name,
            "phone" to phoneNumber,
            "category" to category,
            "timestamp" to System.currentTimeMillis()
        )
        
        methodChannel.invokeMethod("onNewLeadSaved", data)
        Log.d(TAG, "Notified Flutter: onNewLeadSaved - $name (ID: $leadId)")
    }
    
    /**
     * Send lead updated event to Flutter
     */
    fun notifyLeadUpdated(leadId: Int, name: String, phoneNumber: String?, category: String) {
        val data = mapOf(
            "leadId" to leadId,
            "name" to name,
            "phone" to phoneNumber,
            "category" to category,
            "timestamp" to System.currentTimeMillis()
        )
        
        methodChannel.invokeMethod("onLeadUpdated", data)
        Log.d(TAG, "Notified Flutter: onLeadUpdated - $name (ID: $leadId)")
    }
}
