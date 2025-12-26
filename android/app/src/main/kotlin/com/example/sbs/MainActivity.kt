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
        
        // Request necessary permissions
        requestPermissions()
        
        // Start the call overlay service
        startCallOverlayService()
        
        // Request to be default Caller ID app on app start
        requestDefaultCallerIdOnStart()
    }
    
    /**
     * Request default Caller ID role when app starts (Android 10+)
     */
    private fun requestDefaultCallerIdOnStart() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val roleManager = getSystemService(android.app.role.RoleManager::class.java)
                val hasRole = roleManager.isRoleHeld(android.app.role.RoleManager.ROLE_CALL_SCREENING)
                
                if (!hasRole) {
                    Log.d(TAG, "Requesting default Caller ID role on app start...")
                    val intent = roleManager.createRequestRoleIntent(android.app.role.RoleManager.ROLE_CALL_SCREENING)
                    startActivityForResult(intent, 1001)
                } else {
                    Log.d(TAG, "Already set as default Caller ID app")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting default role on start", e)
            }
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
        
        // Setup MethodChannel for call methods
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MethodChannelHandler.CHANNEL_NAME
        )
        
        // Initialize MethodChannelHandler
        methodChannelHandler = MethodChannelHandler(this, methodChannel)
        methodChannel.setMethodCallHandler(methodChannelHandler)
        
        Log.d(TAG, "MethodChannel configured: ${MethodChannelHandler.CHANNEL_NAME}")
        
        // Setup separate channel for call screening role request
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.sbs/call_screening")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestDefaultRole" -> {
                        Log.d(TAG, "Requesting default caller ID role...")
                        Log.d(TAG, "Android version: ${Build.VERSION.SDK_INT}")
                        
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            try {
                                val roleManager = getSystemService(android.app.role.RoleManager::class.java)
                                Log.d(TAG, "RoleManager obtained: $roleManager")
                                
                                // Check if already holding the role
                                val hasRole = roleManager.isRoleHeld(android.app.role.RoleManager.ROLE_CALL_SCREENING)
                                Log.d(TAG, "Already has CALL_SCREENING role: $hasRole")
                                
                                if (hasRole) {
                                    Log.d(TAG, "Already set as default caller ID")
                                    result.success(true)
                                } else {
                                    val intent = roleManager.createRequestRoleIntent(android.app.role.RoleManager.ROLE_CALL_SCREENING)
                                    Log.d(TAG, "Role request intent created, starting activity...")
                                    startActivityForResult(intent, 1001)
                                    result.success(true)
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Error requesting role", e)
                                result.error("ERROR", e.message, null)
                            }
                        } else {
                            Log.w(TAG, "RoleManager API not available (Android ${Build.VERSION.SDK_INT})")
                            result.error("UNAVAILABLE", "Android 10+ required, current: ${Build.VERSION.SDK_INT}", null)
                        }
                    }
                    "isDefaultCallerID" -> {
                        // Check if SBS is currently the default caller ID app
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            try {
                                val roleManager = getSystemService(android.app.role.RoleManager::class.java)
                                val hasRole = roleManager.isRoleHeld(android.app.role.RoleManager.ROLE_CALL_SCREENING)
                                result.success(hasRole)
                            } catch (e: Exception) {
                                result.error("ERROR", e.message, null)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        
        // Setup channel for battery optimization
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.sbs/battery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestBatteryOptimizationExemption" -> {
                        Log.d(TAG, "Requesting battery optimization exemption...")
                        requestBatteryOptimizationExemption(result)
                    }
                    "isBatteryOptimizationExempt" -> {
                        result.success(isBatteryOptimized())
                    }
                    "openBatterySettings" -> {
                        openBatterySettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    /**
     * Check if battery optimization is disabled for this app
     */
    private fun isBatteryOptimized(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(android.os.PowerManager::class.java)
            return pm.isIgnoringBatteryOptimizations(packageName)
        }
        return true // Pre-M doesn't have Doze mode
    }
    
    /**
     * Request exemption from battery optimization
     */
    private fun requestBatteryOptimizationExemption(result: io.flutter.plugin.common.MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val pm = getSystemService(android.os.PowerManager::class.java)
                if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                    Log.d(TAG, "Requesting battery optimization exemption...")
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(true)
                } else {
                    Log.d(TAG, "Already exempt from battery optimization")
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting battery exemption", e)
                // Fallback: open battery settings
                openBatterySettings()
                result.success(false)
            }
        } else {
            result.success(true)
        }
    }
    
    /**
     * Open battery settings for the app
     */
    private fun openBatterySettings() {
        try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening battery settings", e)
            // Fallback to app settings
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            } catch (e2: Exception) {
                Log.e(TAG, "Error opening app settings", e2)
            }
        }
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
     * Does NOT automatically request permission to avoid disrupting user experience
     */
    private fun checkOverlayPermissionAndStartService() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.canDrawOverlays(this)) {
                    Log.d(TAG, "✅ Overlay permission granted - starting service")
                    startCallOverlayService()
                } else {
                    Log.w(TAG, "⚠️ Overlay permission not granted - service not started")
                    // Don't auto-request to avoid app appearing to crash
                    // User can enable from app settings
                }
            } else {
                // Pre-Marshmallow: overlay permission granted by default
                Log.d(TAG, "Pre-Marshmallow device - starting service")
                startCallOverlayService()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking overlay permission", e)
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
