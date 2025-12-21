package com.example.sbs
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
        private const val PERMISSION_REQUEST_CODE = 100
        private const val OVERLAY_PERMISSION_REQUEST_CODE = 101
    }
    
    private var methodChannelHandler: MethodChannelHandler? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity created")
        
        try {
            // Request necessary permissions
            requestPermissions()
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting permissions", e)
        }
    }
    
    override fun onResume() {
        super.onResume()
        
        try {
            // Check and start service when returning to app (e.g., after granting overlay permission)
            checkOverlayPermissionAndStartService()
        } catch (e: Exception) {
            Log.e(TAG, "Error in onResume", e)
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup MethodChannel
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MethodChannelHandler.CHANNEL_NAME
        )
        
        // Initialize MethodChannelHandler
        methodChannelHandler = MethodChannelHandler(this, methodChannel)
        methodChannel.setMethodCallHandler(methodChannelHandler)
        
        Log.d(TAG, "MethodChannel configured: ${MethodChannelHandler.CHANNEL_NAME}")
    }
    
    override fun onDestroy() {
        methodChannelHandler = null
        super.onDestroy()
    }
    
    /**
     * Request necessary runtime permissions
     * Only required for Android 6.0 (API 23) and above
     */
    private fun requestPermissions() {
        // Runtime permissions only needed for Android 6.0+
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            Log.d(TAG, "Pre-Marshmallow device - permissions granted at install time")
            checkOverlayPermissionAndStartService()
            return
        }
        
        val permissionsToRequest = mutableListOf<String>()
        
        // Phone permissions
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE)
            != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.READ_PHONE_STATE)
        }
        
        // READ_CALL_LOG might not be available on all devices
        try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG)
                != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.READ_CALL_LOG)
            }
        } catch (e: Exception) {
            Log.w(TAG, "READ_CALL_LOG permission not available on this device")
        }
        
        // Notification permission (Android 13+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        
        // Request all needed permissions
        if (permissionsToRequest.isNotEmpty()) {
            Log.d(TAG, "Requesting permissions: $permissionsToRequest")
            try {
                ActivityCompat.requestPermissions(
                    this,
                    permissionsToRequest.toTypedArray(),
                    PERMISSION_REQUEST_CODE
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting permissions", e)
                // Continue anyway - app can work with limited functionality
                checkOverlayPermissionAndStartService()
            }
        } else {
            Log.d(TAG, "All permissions already granted")
            checkOverlayPermissionAndStartService()
        }
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            
            if (allGranted) {
                Log.d(TAG, "All permissions granted")
            } else {
                Log.w(TAG, "Some permissions denied - app will work with limited functionality")
            }
            
            // Try to start overlay service anyway (it will check permissions internally)
            try {
                checkOverlayPermissionAndStartService()
            } catch (e: Exception) {
                Log.e(TAG, "Error after permission result", e)
            }
        }
    }
    
    /**
     * Check overlay permission and start CallOverlayService
     * This is now completely optional - app works without it
     */
    private fun checkOverlayPermissionAndStartService() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.canDrawOverlays(this)) {
                    Log.d(TAG, "✅ Overlay permission granted - starting service")
                    startCallOverlayService()
                } else {
                    Log.w(TAG, "⚠️ Overlay permission not granted - app will work without overlay")
                    // Don't request permission automatically - let user enable from settings if needed
                }
            } else {
                // Pre-Marshmallow: Try to start service but don't fail if it doesn't work
                Log.d(TAG, "Pre-Marshmallow device - attempting service start")
                startCallOverlayService()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking overlay permission - app will continue without overlay", e)
        }
    }
    
    /**
     * Request overlay permission
     */
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.canDrawOverlays(this)) {
                    Log.d(TAG, "✅ Overlay permission granted after request")
                    startCallOverlayService()
                } else {
                    Log.e(TAG, "❌ Overlay permission still denied")
                }
            }
        }
    }
    
    /**
     * Start CallOverlayService
     */
    private fun startCallOverlayService() {
        try {
            // Only start if we have all necessary permissions
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!Settings.canDrawOverlays(this)) {
                    Log.w(TAG, "Cannot start overlay service - no overlay permission")
                    return
                }
            }
            
            CallOverlayService.start(this)
            Log.d(TAG, "🚀 CallOverlayService started successfully")
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ SecurityException starting CallOverlayService", e)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting CallOverlayService", e)
        }
    }
}
