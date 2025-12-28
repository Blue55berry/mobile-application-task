package com.example.sbs
import android.accounts.AccountManager
import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.provider.Settings
import android.util.Log
import android.view.*
import android.widget.*
import androidx.core.app.NotificationCompat
import android.content.pm.ServiceInfo
import java.util.Calendar
import kotlinx.coroutines.*


// Simple Lead data class
data class Lead(
    val id: Int,
    val name: String,
    val phone: String,
    val email: String?,
    val category: String,
    val status: String,
    val isVip: Boolean,
    val photoUrl: String? = null
)

class CallOverlayService : Service() {

    companion object {
        private const val TAG = "CallOverlayService"
        private const val NOTIFICATION_ID = 888
        private const val CHANNEL_ID = "sbs_call_monitor"

        fun start(context: Context) {
            val intent = Intent(context, CallOverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, CallOverlayService::class.java)
            context.stopService(intent)
        }
    }

    private var windowManager: WindowManager? = null
    private var floatingIconView: View? = null
    private var popupView: View? = null

    private var currentPhoneNumber: String? = null
    private var currentLead: Lead? = null
    private var isFloatingIconVisible = false
    private var isPopupVisible = false
    private var isQueryComplete = false  // Track if database query is complete

    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var phoneCallDetector: PhoneCallDetector? = null
    
    // Wake lock to keep service alive
    private var wakeLock: PowerManager.WakeLock? = null
    
    // Call tracking for incoming calls
    private var callStartTime: Long = 0
    private var isIncomingCall = false
    private var iconMonitorJob: Job? = null // Monitor icon visibility during calls

    private val callDetectorCallback = object : PhoneCallDetector.CallStateCallback {
        override fun onIncomingCall(phoneNumber: String?) {
            Log.d(TAG, "📞 Callback: Incoming call from $phoneNumber")
            handleIncomingCall(phoneNumber)
        }
        
        override fun onOutgoingCall(phoneNumber: String?) {
            Log.d(TAG, "📞 Callback: Outgoing call to $phoneNumber")
            handleOutgoingCall(phoneNumber)
        }
        
        override fun onCallAnswered() {
            Log.d(TAG, "📞 Callback: Call answered")
            handleCallStarted()
        }
        
        override fun onCallEnded() {
            Log.d(TAG, "📞 Callback: Call ended")
            handleCallEnded()
        }
    }

    private val callStateBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.d(TAG, "Broadcast received: ${intent?.action}")
            when (intent?.action) {
                "com.example.sbs.INCOMING_CALL" -> {
                    val phoneNumber = intent.getStringExtra("phone_number")
                    handleIncomingCall(phoneNumber)
                }
                "com.example.sbs.OUTGOING_CALL" -> {
                    val phoneNumber = intent.getStringExtra("phone_number")
                    handleOutgoingCall(phoneNumber)
                }
                "com.example.sbs.CALL_STARTED" -> {
                    handleCallStarted()
                }
                "com.example.sbs.CALL_ENDED" -> {
                    handleCallEnded()
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        
        // Acquire wake lock to prevent service from sleeping
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "SBS::CallMonitorWakeLock"
            )
            wakeLock?.acquire(10*60*60*1000L) // 10 hours timeout
            Log.d(TAG, "✅ Wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to acquire wake lock", e)
        }
        
        // Use SPECIAL_USE type for Android 14+ (doesn't require DIALER role)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID, 
                createNotification("Monitoring calls..."),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, createNotification("Monitoring calls..."))

        }
        
        registerCallStateReceiver()
        
        // Initialize PhoneCallDetector for direct call monitoring
        phoneCallDetector = PhoneCallDetector(this)
        phoneCallDetector?.setCallback(callDetectorCallback)
        phoneCallDetector?.startListening()
        
        Log.d(TAG, "✅ Service initialized successfully with PhoneCallDetector")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}")
        
        // Handle intents from static BroadcastReceivers
        when (intent?.action) {
            "com.example.sbs.INCOMING_CALL" -> {
                val phoneNumber = intent.getStringExtra("phone_number")
                Log.d(TAG, "📞 Received INCOMING_CALL intent: $phoneNumber")
                handleIncomingCall(phoneNumber)
            }
            "com.example.sbs.OUTGOING_CALL" -> {
                val phoneNumber = intent.getStringExtra("phone_number")
                Log.d(TAG, "📞 Received OUTGOING_CALL intent: $phoneNumber")
                handleOutgoingCall(phoneNumber)
            }
            "com.example.sbs.CALL_STARTED" -> {
                Log.d(TAG, "📞 Received CALL_STARTED intent")
                handleCallStarted()
            }
            "com.example.sbs.CALL_ENDED" -> {
                Log.d(TAG, "📞 Received CALL_ENDED intent")
                handleCallEnded()
            }
        }
        
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "Service destroying")
        try {
            phoneCallDetector?.stopListening()
            phoneCallDetector = null
            unregisterReceiver(callStateBroadcastReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver", e)
        }
        
        // Release wake lock
        try {
            wakeLock?.release()
            wakeLock = null
            Log.d(TAG, "Wake lock released")
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock", e)
        }
        
        stopIconMonitoring() // Stop monitoring when service destroyed
        removeFloatingIcon(force = true)
        removePopup()
        serviceScope.cancel()
        super.onDestroy()
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "⚠️ Task removed - scheduling service restart")
        
        // Schedule service restart using AlarmManager
        try {
            val restartServiceIntent = Intent(applicationContext, CallOverlayService::class.java)
            val restartServicePendingIntent = PendingIntent.getService(
                this, 
                1, 
                restartServiceIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmService = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmService.set(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + 1000,
                restartServicePendingIntent
            )
            Log.d(TAG, "✅ Service restart scheduled")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to schedule restart", e)
        }
    }

    private fun registerCallStateReceiver() {
        val filter = IntentFilter().apply {
            addAction("com.example.sbs.INCOMING_CALL")
            addAction("com.example.sbs.OUTGOING_CALL")
            addAction("com.example.sbs.CALL_STARTED")
            addAction("com.example.sbs.CALL_ENDED")
        }
         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(callStateBroadcastReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(callStateBroadcastReceiver, filter)
        }
    }

    private fun handleIncomingCall(phoneNumber: String?) {
        Log.d(TAG, "📞 Incoming call: $phoneNumber")
        
        // Clean up previous overlays
        removePopup()
        removeFloatingIcon()
        currentPhoneNumber = phoneNumber
        currentLead = null
        
        // Skip if phone number is invalid
        val digits = phoneNumber?.replace(Regex("[^0-9]"), "") ?: ""
        if (digits.length < 6 || phoneNumber == "Unknown") {
            Log.d(TAG, "📞 Skipping invalid incoming call number: $phoneNumber")
            return
        }
        
        // Mark as incoming call for tracking
        isIncomingCall = true
        
        // OPTIMIZED: Show both icon and popup IMMEDIATELY for instant feedback
        try {
            showFloatingIcon()
            showPopup() // Show popup immediately with loading state
            Log.d(TAG, "✅ Floating icon and popup shown immediately for incoming call")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing overlay", e)
        }
        
        // Query in background and update popup content when ready
        queryLeadAndShowOverlay(phoneNumber, isIncoming = true)
        updateNotification("Incoming call: ${phoneNumber ?: "Unknown"}")
    }

    private fun handleOutgoingCall(phoneNumber: String?) {
        Log.d(TAG, "📞 Outgoing call: $phoneNumber")
        
        // Clean up previous overlays
        removePopup()
        removeFloatingIcon()
        currentPhoneNumber = phoneNumber
        currentLead = null
        
        // Skip if phone number is invalid
        val digits = phoneNumber?.replace(Regex("[^0-9]"), "") ?: ""
        if (digits.length < 6 || phoneNumber == "Unknown") {
            Log.d(TAG, "📞 Skipping invalid outgoing call number: $phoneNumber")
            return
        }
        
        // Mark as OUTGOING call for tracking
        isIncomingCall = false
        
        // OPTIMIZED: Show both icon and popup IMMEDIATELY for instant feedback
        try {
            showFloatingIcon()
            showPopup() // Show popup immediately with loading state
            Log.d(TAG, "✅ Floating icon and popup shown immediately for outgoing call")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing overlay", e)
        }
        
        // Query in background and update popup content when ready
        queryLeadAndShowOverlay(phoneNumber, isIncoming = false)
        updateNotification("Outgoing call: ${phoneNumber ?: "Unknown"}")
    }

    private fun handleCallStarted() {
        Log.d(TAG, "📞 Call started")
        // Record call start time for duration calculation
        callStartTime = System.currentTimeMillis()
        startIconMonitoring() // Start monitoring icon visibility
        updateNotification("Call in progress")
    }

    private fun handleCallEnded() {
        Log.d(TAG, "📞 Call ended")
        
        // Stop icon monitoring
        stopIconMonitoring()
        
        // Calculate duration if call was started
        val durationSeconds = if (callStartTime > 0) {
            ((System.currentTimeMillis() - callStartTime) / 1000).toInt()
        } else {
            0
        }
        
        // Log call based on direction
        if (currentPhoneNumber != null && callStartTime > 0) {
            if (isIncomingCall) {
                logIncomingCall(currentPhoneNumber!!, durationSeconds)
            } else {
                logOutgoingCall(currentPhoneNumber!!, durationSeconds)
            }
        }
        
        // Check for missed call auto-reply (incoming only)
        if (isIncomingCall && currentPhoneNumber != null) {
            checkAndSendAutoReply(currentPhoneNumber!!)
        }

        // FIXED: Auto-hide both popup and floating icon when call ends (forced)
        removeFloatingIcon(force = true)
        removePopup()
        
        // Reset call tracking
        isIncomingCall = false
        callStartTime = 0
        currentPhoneNumber = null
        currentLead = null
        updateNotification("Monitoring calls...")
    }

    private fun logIncomingCall(phoneNumber: String, durationSeconds: Int) {
        Log.d(TAG, "📊 Logging incoming call: $phoneNumber, duration: ${durationSeconds}s")
        logCommunication(
            type = "call",
            direction = "inbound",
            recipient = phoneNumber,
            subject = "Incoming Call",
            body = "Duration: ${durationSeconds}s",
            metadata = "duration:$durationSeconds"
        )
    }
    
    private fun logOutgoingCall(phoneNumber: String, durationSeconds: Int) {
        Log.d(TAG, "📊 Logging outgoing call: $phoneNumber, duration: ${durationSeconds}s")
        logCommunication(
            type = "call",
            direction = "outbound",
            recipient = phoneNumber,
            subject = "Outgoing Call",
            body = "Duration: ${durationSeconds}s",
            metadata = "duration:$durationSeconds"
        )
    }

    private fun checkAndSendAutoReply(phoneNumber: String) {
        val prefs = getSharedPreferences("sbs_prefs", Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean("auto_messages_enabled", false)
        val message = prefs.getString("auto_message_text", "Thanks for calling! I'll get back to you soon.") ?: ""
        
        if (isEnabled && message.isNotEmpty()) {
            try {
                val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    this.getSystemService(android.telephony.SmsManager::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    android.telephony.SmsManager.getDefault()
                }
                
                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                Log.d(TAG, "✅ Auto-reply sent to $phoneNumber")
                
                // Log the automatic message with metadata
                logCommunication(
                    type = "sms",
                    direction = "outbound",
                    recipient = phoneNumber,
                    subject = "Automatic Reply",
                    body = message,
                    metadata = "automatic:true"
                )
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to send auto-reply", e)
            }
        }
    }

    private fun queryLeadAndShowOverlay(phoneNumber: String?, isIncoming: Boolean) {
        if (phoneNumber == null) return
        
        Log.d(TAG, "🔍 ===== QUERY START =====")
        Log.d(TAG, "📞 Phone number: '$phoneNumber'")
        
        // ⚡ INSTANT POPUP - Show immediately with loading state
        Handler(Looper.getMainLooper()).post {
            removePopup()
            showPopup() // Shows "Loading..." for new contacts
            Log.d(TAG, "⚡ Instant popup displayed")
        }
        
        // Reset query state
        isQueryComplete = false
        
        serviceScope.launch {
            // Parallel lookup for speed
            val contactNameDeferred = async { queryPhoneContact(phoneNumber) }
            val crmLeadDeferred = async { queryLeadFromDatabase(phoneNumber) }
            
            val contactName = contactNameDeferred.await()
            val crmLead = crmLeadDeferred.await()
            
            Log.d(TAG, "📊 Query Results:")
            Log.d(TAG, "   Contact Name: ${contactName ?: "null"}")
            Log.d(TAG, "   CRM Lead: ${crmLead?.name ?: "null"} (ID: ${crmLead?.id ?: "N/A"})")
            
            // Update current lead state
            currentLead = crmLead
            
            // Auto-create lead for unknown numbers
            if (currentLead == null && phoneNumber != null) {
                val contactName = contactName ?: "Unknown Caller"
                Log.d(TAG, "🆕 Creating new lead for unknown number: $phoneNumber as '$contactName'")
                val newLeadId = createLeadForUnknownNumber(phoneNumber, contactName)
                if (newLeadId != null) {
                    // Re-query to get the full lead object
                    currentLead = queryLeadFromDatabase(phoneNumber)
                    Log.d(TAG, "✅ Auto-created and retrieved lead: ${currentLead?.name} (ID: ${currentLead?.id})")
                }
            }
            
            // Show debug toast
            withContext(Dispatchers.Main) {
                val message = if (crmLead != null) {
                    "✅ Found SBS contact: ${crmLead.name}"
                } else if (contactName != null) {
                    "📱 Phone contact only: $contactName"
                } else {
                    "❌ Unknown number: $phoneNumber"
                }
                Toast.makeText(this@CallOverlayService, message, Toast.LENGTH_SHORT).show()
            }
            
            isQueryComplete = true
            
            // 🔄 UPDATE POPUP - Refresh with actual data
            withContext(Dispatchers.Main) {
                removePopup()
                showPopup() // Now shows saved contact or updated form
                Log.d(TAG, "🎯 Updated popup: ${if (currentLead != null) "SAVED CONTACT" else "NEW CONTACT FORM"}")
            }
        }
    }
    
    private fun queryPhoneContact(phoneNumber: String): String? {
        return try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(phoneNumber)
            )
            
            val projection = arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME)
            val cursor = contentResolver.query(uri, projection, null, null, null)
            
            var contactName: String? = null
            if (cursor != null && cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(ContactsContract.PhoneLookup.DISPLAY_NAME)
                if (nameIndex >= 0) {
                    contactName = cursor.getString(nameIndex)
                    Log.d(TAG, "📱 Found phone contact: $contactName for $phoneNumber")
                }
                cursor.close()
            }
            
            contactName
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error querying phone contacts: ${e.message}", e)
            null
        }
    }
    
    private fun getContactPhotoUri(phoneNumber: String?): Uri? {
        if (phoneNumber == null) {
            Log.d(TAG, "📸 No phone number provided for photo lookup")
            return null
        }
        
        return try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(phoneNumber)
            )
            
            Log.d(TAG, "📸 Looking up photo for: $phoneNumber")
            val projection = arrayOf(ContactsContract.PhoneLookup.PHOTO_URI)
            val cursor = contentResolver.query(uri, projection, null, null, null)
            
            var photoUriString: String? = null
            if (cursor != null && cursor.moveToFirst()) {
                val photoIndex = cursor.getColumnIndex(ContactsContract.PhoneLookup.PHOTO_URI)
                if (photoIndex >= 0) {
                    photoUriString = cursor.getString(photoIndex)
                    if (photoUriString != null) {
                        Log.d(TAG, "✅ Found contact photo URI: $photoUriString")
                    } else {
                        Log.d(TAG, "⚠️ Contact exists but no photo URI available")
                    }
                } else {
                    Log.d(TAG, "⚠️ PHOTO_URI column not found in cursor")
                }
                cursor.close()
            } else {
                Log.d(TAG, "⚠️ No contact found for $phoneNumber")
            }
            
            if (photoUriString != null) Uri.parse(photoUriString) else null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error getting contact photo for $phoneNumber", e)
            null
        }
    }

    private suspend fun queryLeadFromDatabase(phoneNumber: String): Lead? = withContext(Dispatchers.IO) {
        try {
            // Try multiple database paths
            val possiblePaths = listOf(
                getDatabasePath("sbs_database.db"),
                java.io.File(applicationContext.filesDir.parentFile, "databases/sbs_database.db"),
                java.io.File("/data/data/${packageName}/databases/sbs_database.db")
            )
            
            var dbPath: java.io.File? = null
            for (path in possiblePaths) {
                Log.d(TAG, "🔍 Checking DB path: ${path.absolutePath} exists=${path.exists()}")
                if (path.exists()) {
                    dbPath = path
                    break
                }
            }
            
            if (dbPath == null || !dbPath.exists()) {
                Log.e(TAG, "❌ Database file not found at any path!")
                return@withContext null
            }
            
            Log.d(TAG, "✅ Using database at: ${dbPath.absolutePath}")
            
            val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                dbPath.absolutePath,
                null,
                android.database.sqlite.SQLiteDatabase.OPEN_READONLY
            )
            
            // First, let's see all leads in the database
            val allLeadsCursor = db.rawQuery("SELECT id, name, phoneNumber FROM leads LIMIT 10", null)
            Log.d(TAG, "📊 Total leads in DB: ${allLeadsCursor.count}")
            while (allLeadsCursor.moveToNext()) {
                val id = allLeadsCursor.getInt(0)
                val name = allLeadsCursor.getString(1)
                val phone = allLeadsCursor.getString(2)
                Log.d(TAG, "   Lead #$id: $name - $phone")
            }
            allLeadsCursor.close()
            
            // Normalize incoming phone number: remove all non-digits
            val digitsOnly = phoneNumber.replace(Regex("[^0-9]"), "")
            val incomingLast10 = if (digitsOnly.length >= 10) {
                digitsOnly.takeLast(10)
            } else {
                digitsOnly
            }
            
            Log.d(TAG, "🔍 Searching for: '$phoneNumber' -> normalized last10: '$incomingLast10'")
            
            // CRITICAL: If no valid digits, return null immediately
            if (incomingLast10.length < 6) {
                Log.d(TAG, "❌ Phone number too short or invalid, returning null")
                db.close()
                return@withContext null
            }
            
            // Query all leads and compare normalized numbers
            val cursor = db.rawQuery("SELECT * FROM leads", null)
            Log.d(TAG, "📊 Checking ${cursor.count} leads for match")
            
            var lead: Lead? = null

            while (cursor.moveToNext()) {
                val phoneIndex = cursor.getColumnIndex("phoneNumber")
                if (phoneIndex >= 0) {
                    val dbPhone = cursor.getString(phoneIndex) ?: ""
                    // Normalize database phone number
                    val dbDigitsOnly = dbPhone.replace(Regex("[^0-9]"), "")
                    val dbLast10 = if (dbDigitsOnly.length >= 10) {
                        dbDigitsOnly.takeLast(10)
                    } else {
                        dbDigitsOnly
                    }
                    
                    Log.d(TAG, "   Comparing: incoming='$incomingLast10' vs db='$dbLast10' (${cursor.getString(cursor.getColumnIndex("name"))})")
                    
                    // Exact match of last 10 digits
                    if (incomingLast10 == dbLast10 && incomingLast10.isNotEmpty()) {
                        val idIndex = cursor.getColumnIndex("id")
                        val nameIndex = cursor.getColumnIndex("name")
                        val categoryIndex = cursor.getColumnIndex("category")
                        
                        lead = Lead(
                            id = if (idIndex >= 0) cursor.getInt(idIndex) else 0,
                            name = if (nameIndex >= 0) cursor.getString(nameIndex) ?: "Unknown" else "Unknown",
                            phone = phoneNumber,
                            email = cursor.getColumnIndex("email").let { if (it >= 0) cursor.getString(it) else null },
                            category = if (categoryIndex >= 0) cursor.getString(categoryIndex) ?: "General" else "General",
                            status = cursor.getColumnIndex("status").let { if (it >= 0) cursor.getString(it) ?: "New" else "New" },
                            isVip = cursor.getColumnIndex("isVip").let { if (it >= 0) cursor.getInt(it) == 1 else false },
                            photoUrl = cursor.getColumnIndex("photoUrl").let { if (it >= 0) cursor.getString(it) else null }
                        )
                        Log.d(TAG, "✅ FOUND exact match: ${lead.name} (ID: ${lead.id})")
                        break
                    }
                }
            }
            cursor.close()
            db.close()
            
            if (lead == null) {
                Log.d(TAG, "❌ No lead found for: $phoneNumber (normalized: $incomingLast10)")
            }
            
            lead
        } catch (e: Exception) {
            Log.e(TAG, "❌ Database query error: ${e.message}", e)
            null
        }
    }
    
    private suspend fun createLeadForUnknownNumber(phoneNumber: String, name: String = "Unknown"): Int? = withContext(Dispatchers.IO) {
        try {
            val dbPath = getDatabasePath("sbs_database.db")
            if (!dbPath.exists()) {
                Log.e(TAG, "❌ Database not found for lead creation")
                return@withContext null
            }
            
            val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                dbPath.absolutePath,
                null,
                android.database.sqlite.SQLiteDatabase.OPEN_READWRITE
            )
            
            val values = android.content.ContentValues().apply {
                put("name", name)
                put("phoneNumber", phoneNumber)
                put("category", "Incoming Call")
                put("status", "New")
                put("createdAt", java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US).format(java.util.Date()))
                put("isVip", 0)
                put("source", "call")
            }
            
            val newId = db.insert("leads", null, values)
            db.close()
            
            if (newId > 0) {
                Log.d(TAG, "✅ Auto-created lead for $phoneNumber with ID: $newId")
                newId.toInt()
            } else {
                Log.e(TAG, "❌ Failed to create lead for $phoneNumber")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error creating lead: ${e.message}", e)
            null
        }
    }
    
    // === ICON MONITORING DURING CALLS ===
    
    private fun startIconMonitoring() {
        iconMonitorJob?.cancel()
        iconMonitorJob = serviceScope.launch {
            while (callStartTime > 0) {
                delay(2000) // Check every 2 seconds
                ensureIconVisibleDuringCall()
            }
        }
        Log.d(TAG, "✅ Icon monitoring started")
    }
    
    private fun stopIconMonitoring() {
        iconMonitorJob?.cancel()
        iconMonitorJob = null
        Log.d(TAG, "⏹️ Icon monitoring stopped")
    }
    
    private fun ensureIconVisibleDuringCall() {
        if (callStartTime > 0 && !isFloatingIconVisible && currentPhoneNumber != null) {
            Log.w(TAG, "⚠️ Icon disappeared during call - recreating")
            Handler(Looper.getMainLooper()).post {
                showFloatingIcon()
            }
        }
    }

    private fun showFloatingIcon() {
        if (isFloatingIconVisible) return
        
        // Check overlay permission
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                Log.e(TAG, "❌ OVERLAY PERMISSION NOT GRANTED! Icon cannot be shown.")
                return
            } else {
                Log.d(TAG, "✅ Overlay permission granted")
            }
        }
        
        try {
            floatingIconView = createFloatingIconView()
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or 
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or  // Show on lock screen
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,      // Turn screen on if needed
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = 20
                y = 100
            }
            windowManager?.addView(floatingIconView, params)
            isFloatingIconVisible = true
            Log.d(TAG, "✅ Floating icon shown successfully (lock screen enabled)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing floating icon: ${e.message}", e)
        }
    }

    private fun createFloatingIconView(): View {
        val density = resources.displayMetrics.density
        val iconSize = (60 * density).toInt()
        
        val frameLayout = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(iconSize, iconSize)
            alpha = 0.5f // Start in idle state
            scaleX = 0.7f
            scaleY = 0.7f
        }

        // Outer glow/shadow layer
        val glowView = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                (iconSize * 1.3f).toInt(),
                (iconSize * 1.3f).toInt()
            ).apply {
                gravity = Gravity.CENTER
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#4D6C5CE7")) // Semi-transparent purple
            }
            alpha = 0.6f
        }
        frameLayout.addView(glowView)

        // Main icon circle with gradient
        val iconView = TextView(this).apply {
            layoutParams = FrameLayout.LayoutParams(iconSize, iconSize).apply {
                gravity = Gravity.CENTER
            }
            text = "SBS"
            gravity = Gravity.CENTER
            textSize = 18f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(
                    Color.parseColor("#6C5CE7"),  // Purple
                    Color.parseColor("#A855F7")   // Lighter purple
                )
            ).apply {
                shape = GradientDrawable.OVAL
                setStroke((2 * density).toInt(), Color.parseColor("#FFFFFF"))
            }
            elevation = 16f
        }
        frameLayout.addView(iconView)

        // Make icon draggable
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false

        iconView.setOnTouchListener { view, event ->
            val params = floatingIconView?.layoutParams as? WindowManager.LayoutParams

            when (event.action) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    // Update state to active
                    frameLayout.animate().scaleX(1.0f).scaleY(1.0f).alpha(1.0f).setDuration(200).start()
                    
                    initialX = params?.x ?: 0
                    initialY = params?.y ?: 0
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    true
                }
                android.view.MotionEvent.ACTION_MOVE -> {
                    val deltaX = kotlin.math.abs(event.rawX - initialTouchX)
                    val deltaY = kotlin.math.abs(event.rawY - initialTouchY)
                    
                    if (deltaX > 10 || deltaY > 10) {
                        isDragging = true
                        params?.x = initialX + (event.rawX - initialTouchX).toInt()
                        params?.y = initialY + (event.rawY - initialTouchY).toInt()
                        windowManager?.updateViewLayout(floatingIconView, params)
                    }
                    true
                }
                android.view.MotionEvent.ACTION_UP -> {
                    // Update state back to idle
                    frameLayout.animate().scaleX(0.7f).scaleY(0.7f).alpha(0.5f).setDuration(200).start()

                    if (!isDragging) {
                        // Only show popup if query is complete to avoid stale data
                        if (isQueryComplete) {
                            if (currentLead != null) {
                                showPopup()
                            } else {
                                togglePopup()
                            }
                        } else {
                            Log.d(TAG, "📞 Query not complete, waiting...")
                            // Query still in progress, show popup will be triggered when complete
                        }
                    }
                    isDragging = false
                    true
                }
                android.view.MotionEvent.ACTION_CANCEL -> {
                    // Return to idle state if cancelled
                    frameLayout.animate().scaleX(0.7f).scaleY(0.7f).alpha(0.5f).setDuration(200).start()
                    isDragging = false
                    true
                }
                else -> false
            }
        }

        return frameLayout
    }

    private fun togglePopup() {
        if (isPopupVisible) removePopup() else showPopup()
    }

    private fun removePopup() {
        try {
            popupView?.let { windowManager?.removeView(it) }
            popupView = null
            isPopupVisible = false
            Log.d(TAG, "Popup removed")
        } catch (e: Exception) {
            Log.e(TAG, "Error removing popup", e)
        }
    }

    private fun removeFloatingIcon(force: Boolean = false) {
        // Don't remove during active call unless forced
        if (!force && callStartTime > 0) {
            Log.d(TAG, "⚠️ Prevented icon removal during active call")
            return
        }
        
        try {
            floatingIconView?.let { windowManager?.removeView(it) }
            floatingIconView = null
            isFloatingIconVisible = false
            Log.d(TAG, "🗑️ Floating icon removed")
        } catch (e: Exception) {
            Log.e(TAG, "Error removing floating icon", e)
        }
    }

    private fun showPopup() {
        if (isPopupVisible) return
        try {
            popupView = createPopupView()
            
            // MAXIMUM PRIORITY FLAGS - Show before ALL other apps
            var flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                       WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                       WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or  // Show on lockscreen
                       WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or    // Wake screen
                       WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS     // No bounds
            
            if (currentLead != null) {
                flags = flags or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                // Use TYPE_SYSTEM_ALERT for HIGHEST priority (above all apps)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT  // Higher than TYPE_PHONE
                },
                flags,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER  // Center position for compact layout
                // Allow resizing for keyboard and force it to be visible when focused
                softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
            }
            windowManager?.addView(popupView, params)
            isPopupVisible = true
            Log.d(TAG, "✅ Popup shown")
        } catch (e: Exception) {
            Log.e(TAG, "Error showing popup", e)
        }
    }

    private fun createPopupView(): View {
        return if (currentLead != null) {
            createSavedLeadPopup()
        } else {
            createNewLeadFormPopup()
        }
    }

    private fun createSavedLeadPopup(): View {
        val density = resources.displayMetrics.density
        
        // Compact semi-transparent background
        val mainContainer = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            setBackgroundColor(Color.parseColor("#99000000")) // Medium transparent
            setPadding(0, 0, 0, 0)
        }

        // Compact card - notification banner style
        val cardView = LinearLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(
                    (16 * density).toInt(),
                    (8 * density).toInt(),
                    (16 * density).toInt(),
                    (16 * density).toInt()
                )
            }
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                // Clean white background like reference
                setColor(Color.WHITE)
                cornerRadius = 16 * density
                setStroke((1 * density).toInt(), Color.parseColor("#E0E0E0"))
            }
            elevation = 16 * density
            setPadding(
                (16 * density).toInt(),
                (16 * density).toInt(),
                (16 * density).toInt(),
                (16 * density).toInt()
            )
        }

        // ===== COMPACT HEADER (Horizontal Layout) =====
        val headerLayout = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = (12 * density).toInt()
            }
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        // Compact Avatar with Photo or Letter (Left)
        val avatarSize = (48 * density).toInt()
        val avatarView = if (currentLead?.photoUrl != null) {
            ImageView(this).apply {
                layoutParams = LinearLayout.LayoutParams(avatarSize, avatarSize)
                scaleType = ImageView.ScaleType.CENTER_CROP
                try {
                    setImageURI(Uri.parse(currentLead?.photoUrl))
                } catch (e: Exception) {
                    Log.e(TAG, "Error loading contact photo", e)
                }
                // Apply circular clip if possible, or just rounded corners via background
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    colors = intArrayOf(Color.parseColor("#8B5CF6"), Color.parseColor("#EC4899"))
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    clipToOutline = true
                    outlineProvider = object : ViewOutlineProvider() {
                        override fun getOutline(view: View, outline: android.graphics.Outline) {
                            outline.setOval(0, 0, view.width, view.height)
                        }
                    }
                }
            }
        } else {
            TextView(this).apply {
                layoutParams = LinearLayout.LayoutParams(avatarSize, avatarSize)
                text = (currentLead?.name?.firstOrNull()?.uppercase() ?: "?")
                gravity = Gravity.CENTER
                textSize = 20f
                setTextColor(Color.WHITE)
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    colors = intArrayOf(
                        Color.parseColor("#8B5CF6"),
                        Color.parseColor("#EC4899")
                    )
                }
            }
        }
        headerLayout.addView(avatarView)

        // Contact Info (Center)
        val infoLayout = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            ).apply {
                setMargins((12 * density).toInt(), 0, (8 * density).toInt(), 0)
            }
            orientation = LinearLayout.VERTICAL
        }

        val name = currentLead?.name ?: "Unknown"
        infoLayout.addView(TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            text = name
            textSize = 18f
            setTextColor(Color.parseColor("#212121"))
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
        })

        val phoneNumber = currentPhoneNumber ?: ""
        if (phoneNumber.isNotEmpty()) {
            infoLayout.addView(TextView(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = (2 * density).toInt()
                }
                text = phoneNumber
                textSize = 13f
                setTextColor(Color.parseColor("#757575")) // Medium gray for phone number
                typeface = android.graphics.Typeface.MONOSPACE
                maxLines = 1
            })
        }

        headerLayout.addView(infoLayout)

        // Action Icons (Right)
        val actionsLayout = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            orientation = LinearLayout.HORIZONTAL
        }

        // WhatsApp Icon
        val whatsappIcon = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                (40 * density).toInt(),
                (40 * density).toInt()
            ).apply {
                setMargins((4 * density).toInt(), 0, (4 * density).toInt(), 0)
            }
            text = "💬" // WhatsApp icon
            gravity = Gravity.CENTER
            textSize = 20f
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#25D366")) // WhatsApp green
            }
            setOnClickListener {
                val message = "Hello ${name}, contacting you from SBS"
                val intent = Intent(Intent.ACTION_VIEW)
                intent.data = android.net.Uri.parse("https://wa.me/${phoneNumber.replace("+", "")}?text=${android.net.Uri.encode(message)}")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                try {
                    startActivity(intent)
                    // Log communication
                    logCommunication("whatsapp", "outbound", phoneNumber, null, message)
                } catch (e: Exception) {
                    Log.e(TAG, "Error opening WhatsApp", e)
                }
            }
        }
        actionsLayout.addView(whatsappIcon)

        // Email Icon
        val emailIcon = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                (40 * density).toInt(),
                (40 * density).toInt()
            ).apply {
                setMargins((4 * density).toInt(), 0, (4 * density).toInt(), 0)
            }
            text = "✉" // Gmail envelope icon
            gravity = Gravity.CENTER
            textSize = 20f
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#EA4335")) // Gmail red
            }
            setOnClickListener {
                // Open email composer with lead details
                val email = currentLead?.email ?: ""
                val subject = android.net.Uri.encode("Follow up from SBS")
                val body = android.net.Uri.encode("Hi $name,\n\nThank you for your time on the call.\n\nBest regards,\nSBS Team")
                
                val intent = Intent(Intent.ACTION_SENDTO).apply {
                    data = android.net.Uri.parse("mailto:")
                    putExtra(Intent.EXTRA_EMAIL, arrayOf(email))
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                    putExtra(Intent.EXTRA_TEXT, body)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                
                try {
                    startActivity(Intent.createChooser(intent, "Send Email").apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    })
                    // Log communication
                    logCommunication("email", "outbound", email, "Follow up from SBS", body)
                } catch (e: Exception) {
                    Log.e(TAG, "Error opening email", e)
                }
            }
        }
        actionsLayout.addView(emailIcon)

        // Call Icon
        val callIcon = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                (40 * density).toInt(),
                (40 * density).toInt()
            ).apply {
                setMargins((4 * density).toInt(), 0, (4 * density).toInt(), 0)
            }
            text = "📞" // Phone call icon
            gravity = Gravity.CENTER
            textSize = 18f
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#6C5CE7")) // Purple for call button
            }
        }
        actionsLayout.addView(callIcon)

        // Cancel/Close Icon (replaces three-dot menu)
        val closeIcon = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                (40 * density).toInt(),
                (40 * density).toInt()
            ).apply {
                setMargins((4 * density).toInt(), 0, 0, 0)
            }
            text = "⋮"
            gravity = Gravity.CENTER
            textSize = 24f
            setTextColor(Color.parseColor("#757575"))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#F5F5F5"))
            }
            setOnClickListener { removePopup() }
        }
        actionsLayout.addView(closeIcon)

        headerLayout.addView(actionsLayout)
        cardView.addView(headerLayout)

        // Add spacing after header
        cardView.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (1 * density).toInt()
            ).apply {
                topMargin = (16 * density).toInt()
                bottomMargin = (16 * density).toInt()
            }
            setBackgroundColor(Color.parseColor("#333355")) // Subtle divider
        })

        // ===== ADD LABEL SECTION (Button + Current Labels) =====
        val labelContainer = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = (12 * density).toInt()
            }
            orientation = LinearLayout.HORIZONTAL
        }
        
        val addLabelButton = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, (8 * density).toInt(), 0)
            }
            text = "Add Label +"
            textSize = 15f // Slightly larger
            setTextColor(Color.WHITE) // Changed from purple to white for better visibility
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding((20 * density).toInt(), (12 * density).toInt(), (20 * density).toInt(), (12 * density).toInt()) // Larger touch target
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#2D2D4A")) // Darker purple for button bg
                cornerRadius = 20 * density
                setStroke((2 * density).toInt(), Color.parseColor("#6C5CE7"))
            }
            setOnClickListener {
                showLabelSelector(this)
            }
        }
        labelContainer.addView(addLabelButton)
        
        // Show current label/category chip
        val currentCategory = currentLead?.category
        Log.d(TAG, "🏷️ DEBUG: currentCategory = '$currentCategory'")
        Log.d(TAG, "🏷️ DEBUG: currentLead?.name = '${currentLead?.name}'")
        Log.d(TAG, "🏷️ DEBUG: currentLead?.id = ${currentLead?.id}")
        
        if (!currentCategory.isNullOrEmpty()) {
            Log.d(TAG, "🏷️ Creating label chip for category: $currentCategory")
            val labelChip = TextView(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
                text = currentCategory
                textSize = 14f
                setTextColor(Color.WHITE)
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                setPadding((16 * density).toInt(), (10 * density).toInt(), (16 * density).toInt(), (10 * density).toInt())
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#6C5CE7")) // Purple label background
                    cornerRadius = 18 * density
                }
            }
            labelContainer.addView(labelChip)
        } else {
            Log.w(TAG, "⚠️ No category to display - currentCategory is null or empty")
        }
        
        cardView.addView(labelContainer)

        // ===== MOVE TO & ASSIGNED TO DROPDOWNS =====
        val dropdownContainer = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (12 * density).toInt()
                bottomMargin = (12 * density).toInt()
            }
            orientation = LinearLayout.HORIZONTAL
        }

        // Move to... dropdown
        val moveToButton = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            ).apply {
                rightMargin = (8 * density).toInt()
            }
            text = "Move to... ▾"
            textSize = 14f
            setTextColor(Color.parseColor("#666666"))
            gravity = Gravity.START or Gravity.CENTER_VERTICAL
            setPadding((16 * density).toInt(), (14 * density).toInt(), (16 * density).toInt(), (14 * density).toInt())
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F5F5F5"))
                cornerRadius = 8 * density
            }
            setOnClickListener {
                showMoveToDialog()
            }
        }
        dropdownContainer.addView(moveToButton)

        // Assigned to dropdown
        val assignedToButton = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            )
            text = "Assigned to ▾"
            textSize = 14f
            setTextColor(Color.parseColor("#666666"))
            gravity = Gravity.START or Gravity.CENTER_VERTICAL
            setPadding((16 * density).toInt(), (14 * density).toInt(), (16 * density).toInt(), (14 * density).toInt())
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F5F5F5"))
                cornerRadius = 8 * density
            }
            setOnClickListener {
                showAssignedToDialog()
            }
        }
        dropdownContainer.addView(assignedToButton)

        cardView.addView(dropdownContainer)

        // ===== CREATE MEETING BUTTON =====
        val meetingButton = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = (16 * density).toInt()
            }
            text = "📅 Create Meeting"
            textSize = 15f
            setTextColor(Color.parseColor("#333333"))
            gravity = Gravity.START or Gravity.CENTER_VERTICAL
            setPadding((16 * density).toInt(), (14 * density).toInt(), (16 * density).toInt(), (14 * density).toInt())
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F5F5F5"))
                cornerRadius = 8 * density
            }
            setOnClickListener {
                showCreateMeetingDialog()
            }
        }
        cardView.addView(meetingButton)

        // ===== AUTOMATIC MESSAGES SECTION =====
        val autoMessagesContainer = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (16 * density).toInt()
            }
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#252540")) // Slightly lighter purple for contrast
                cornerRadius = 8 * density
            }
            setPadding((16 * density).toInt(), (12 * density).toInt(), (16 * density).toInt(), (12 * density).toInt())
        }

        // Auto messages header
        val autoMessagesHeader = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            orientation = LinearLayout.HORIZONTAL
        }

        autoMessagesHeader.addView(TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            )
            text = "Automatic Messages"
            textSize = 16f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        })

        autoMessagesHeader.addView(TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            text = "⚙"
            textSize = 18f
            setTextColor(Color.WHITE) // Changed from gray to white for better visibility
            setOnClickListener {
                Log.d(TAG, "Auto messages settings clicked")
            }
        })

        autoMessagesContainer.addView(autoMessagesHeader)

        // Auto messages description
        autoMessagesContainer.addView(TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (8 * density).toInt()
            }
            text = "Send an automatic reply to missed calls and greet new customers with your custom message."
            textSize = 13f
            setTextColor(Color.parseColor("#E0E0E0")) // Light gray instead of dark gray for visibility
        })

        // Turn On button
        autoMessagesContainer.addView(TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (12 * density).toInt()
            }
            text = "TURN ON"
            textSize = 14f
            setTextColor(Color.parseColor("#6C5CE7"))
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setOnClickListener {
                toggleAutoMessages()
            }
        })

        cardView.addView(autoMessagesContainer)

        // ===== ORIGINAL ACTION BUTTONS (Preserved) =====
        val actionsRow = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (20 * density).toInt()
            }
            orientation = LinearLayout.HORIZONTAL
        }

        // SAVE button
        val saveButton = Button(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            ).apply {
                rightMargin = (4 * density).toInt()
            }
            text = "💾 SAVE"
            textSize = 14f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#4CAF50"))
                cornerRadius = 12 * density
            }
            setOnClickListener {
                saveContactToDatabase()
                removePopup()
            }
        }
        actionsRow.addView(saveButton)

        // Create Task button
        val taskButton = Button(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            ).apply {
                leftMargin = (4 * density).toInt()
            }
            text = "✓ TASK"
            textSize = 14f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#00BCD4"))
                cornerRadius = 12 * density
            }
            setOnClickListener {
                showCreateTaskDialog()
            }
        }
        actionsRow.addView(taskButton)

        cardView.addView(actionsRow)
        
        mainContainer.setOnClickListener { removePopup() }
        cardView.setOnClickListener { /* Prevent dismissal */ }
        
        mainContainer.addView(cardView)
        return mainContainer
    }

    private fun createNewLeadFormPopup(): View {
        val density = resources.displayMetrics.density
        
        // Main container
        val mainContainer = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            setBackgroundColor(Color.parseColor("#80000000"))
        }

        // Scrollable card
        val scrollView = android.widget.ScrollView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(
                    (16 * density).toInt(),
                    (16 * density).toInt(),
                    (16 * density).toInt(),
                    (16 * density).toInt()
                )
            }
        }

        val cardView = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#2A2A3E"))
                cornerRadius = 24 * density
                setStroke((1 * density).toInt(), Color.parseColor("#4D6C5CE7"))
            }
            elevation = 24f
            setPadding((24 * density).toInt(), (24 * density).toInt(), (24 * density).toInt(), (24 * density).toInt())
        }

        // Header
        cardView.addView(TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            text = "New Contact"
            textSize = 24f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        })

        // Phone number (readonly)
        cardView.addView(TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (16 * density).toInt()
            }
            text = "📞 ${currentPhoneNumber ?: "Unknown"}"
            textSize = 16f
            setTextColor(Color.parseColor("#AAAAAA"))
            gravity = Gravity.CENTER
        })

        // Name input
        val nameInput = android.widget.EditText(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (24 * density).toInt()
            }
            hint = "Name *"
            setHintTextColor(Color.parseColor("#888888"))
            setTextColor(Color.WHITE)
            textSize = 16f
            setPadding((16 * density).toInt(), (12 * density).toInt(), (16 * density).toInt(), (12 * density).toInt())
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1A1A2E"))
                cornerRadius = 12 * density
            }
            isFocusable = true
            isFocusableInTouchMode = true
            setOnClickListener { 
                requestFocus()
                // Ensure keyboard shows up
                val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                imm.showSoftInput(this, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT)
            }
        }
        cardView.addView(nameInput)

        // Email input
        val emailInput = android.widget.EditText(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (12 * density).toInt()
            }
            hint = "Email (optional)"
            setHintTextColor(Color.parseColor("#888888"))
            setTextColor(Color.WHITE)
            textSize = 16f
            inputType = android.text.InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
            setPadding((16 * density).toInt(), (12 * density).toInt(), (16 * density).toInt(), (12 * density).toInt())
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1A1A2E"))
                cornerRadius = 12 * density
            }
        }
        cardView.addView(emailInput)

        // Category label
        cardView.addView(TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (16 * density).toInt()
            }
            text = "Category"
            textSize = 14f
            setTextColor(Color.parseColor("#CCCCCC"))
        })

        // Category buttons - fetch from database
        val categories = fetchLabelsFromDatabase()
        var selectedCategory = if (categories.isNotEmpty()) categories.first() else "Client"

        val categoryContainer = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (8 * density).toInt()
            }
            orientation = LinearLayout.HORIZONTAL
        }

        val categoryButtons = mutableListOf<TextView>()
        categories.forEach { category ->
            val button = TextView(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f
                ).apply {
                    if (category != categories.first()) {
                        leftMargin = (8 * density).toInt()
                    }
                }
                text = category
                textSize = 12f
                setTextColor(if (category == selectedCategory) Color.WHITE else Color.parseColor("#888888"))
                gravity = Gravity.CENTER
                setPadding((8 * density).toInt(), (12 * density).toInt(), (8 * density).toInt(), (12 * density).toInt())
                background = GradientDrawable().apply {
                    setColor(if (category == selectedCategory) Color.parseColor("#6C5CE7") else Color.parseColor("#1A1A2E"))
                    cornerRadius = 12 * density
                }
                setOnClickListener {
                    selectedCategory = category
                    categoryButtons.forEach { btn ->
                        btn.setTextColor(if (btn.text == selectedCategory) Color.WHITE else Color.parseColor("#888888"))
                        btn.background = GradientDrawable().apply {
                            setColor(if (btn.text == selectedCategory) Color.parseColor("#6C5CE7") else Color.parseColor("#1A1A2E"))
                            cornerRadius = 12 * density
                        }
                    }
                }
            }
            categoryButtons.add(button)
            categoryContainer.addView(button)
        }
        cardView.addView(categoryContainer)

        // Buttons
        val buttonContainer = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (24 * density).toInt()
            }
            orientation = LinearLayout.HORIZONTAL
        }

        // Cancel button
        buttonContainer.addView(TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            ).apply {
                rightMargin = (8 * density).toInt()
            }
            text = "Cancel"
            textSize = 16f
            setTextColor(Color.parseColor("#AAAAAA")) // Light gray for secondary text
            gravity = Gravity.CENTER
            setPadding((16 * density).toInt(), (14 * density).toInt(), (16 * density).toInt(), (14 * density).toInt())
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1A1A2E"))
                cornerRadius = 12 * density
            }
            setOnClickListener { removePopup() }
        })

        // Save button
        buttonContainer.addView(TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            )
            text = "Save"
            textSize = 16f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding((16 * density).toInt(), (14 * density).toInt(), (16 * density).toInt(), (14 * density).toInt())
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#6C5CE7"))
                cornerRadius = 12 * density
            }
            setOnClickListener {
                val name = nameInput.text.toString().trim()
                if (name.isNotEmpty()) {
                    saveNewLead(name, emailInput.text.toString().trim(), selectedCategory)
                    removePopup()
                } else {
                    android.widget.Toast.makeText(this@CallOverlayService, "Name is required", android.widget.Toast.LENGTH_SHORT).show()
                }
            }
        })

        cardView.addView(buttonContainer)
        
        scrollView.addView(cardView)
        mainContainer.addView(scrollView)
        mainContainer.setOnClickListener { /* Don't dismiss on background tap for form */ }
        
        return mainContainer
    }
    
    
    // ===== BUTTON HELPER METHODS =====
    
    private fun showLabelSelector(button: TextView?) {
        val labelNames = arrayOf("Hot Lead", "Cold Lead", "Follow Up", "Not Interested", "Customer", "VIP")
        
        val dialog = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
            .setTitle("Select Label")
            .setItems(labelNames) { _, which ->
                val selectedLabel = labelNames[which]
                button?.text = selectedLabel
                button?.setTextColor(Color.WHITE)
                button?.background = GradientDrawable().apply {
                    setColor(Color.parseColor("#6C5CE7"))
                    cornerRadius = 20 * resources.displayMetrics.density
                }
                
                if (currentLead?.id == 0) {
                    saveContactToCRM(selectedLabel)
                } else {
                    Toast.makeText(this, "✅ Label: $selectedLabel", Toast.LENGTH_SHORT).show()
                }
            }
            .create()
            
        dialog.window?.setType(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
            }
        )
        dialog.show()
    }

    private fun saveNewLead(name: String, email: String, category: String) {
        serviceScope.launch(Dispatchers.IO) {
            try {
                val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                    getDatabasePath("sbs_database.db").absolutePath,
                    null,
                    android.database.sqlite.SQLiteDatabase.OPEN_READWRITE
                )
                
                val values = android.content.ContentValues().apply {
                    put("name", name)
                    put("phoneNumber", currentPhoneNumber ?: "")
                    put("email", if (email.isNotEmpty()) email else null)
                    put("category", category)
                    put("status", "New")
                    put("createdAt", java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US).format(java.util.Date()))
                    put("totalCalls", 0)
                    put("isVip", 0)
                }
                
                val id = db.insertWithOnConflict(
                    "leads",
                    null,
                    values,
                    android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE
                )
                db.close()
                
                withContext(Dispatchers.Main) {
                    if (id > 0) {
                        Log.d(TAG, "✅ Contact saved/updated: $name (ID: $id)")
                        android.widget.Toast.makeText(this@CallOverlayService, "✅ Contact saved successfully!", android.widget.Toast.LENGTH_SHORT).show()
                        
                        currentLead = queryLeadFromDatabase(currentPhoneNumber ?: "")
                        
                        val intent = Intent("com.example.sbs.LEAD_CREATED")
                        intent.putExtra("lead_id", id.toInt())
                        intent.putExtra("name", name)
                        intent.putExtra("phone", currentPhoneNumber)
                        intent.putExtra("category", category)
                        sendBroadcast(intent)
                    } else {
                        android.widget.Toast.makeText(this@CallOverlayService, "Failed to save contact", Toast.LENGTH_SHORT).show()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error saving lead: ${e.message}", e)
            }
        }
    }
    
    private fun showCategoryPicker(button: TextView) {
        // Predefined labels
        val labelNames = arrayOf("Hot Lead", "Cold Lead", "Follow Up", "Not Interested", "Customer", "VIP")
        
        val dialog = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
            .setTitle("Select Label")
            .setItems(labelNames) { _, which ->
                val selectedLabel = labelNames[which]
                
                // Update button text and style
                button.text = selectedLabel
                button.setTextColor(Color.WHITE)
                button.background = GradientDrawable().apply {
                    setColor(Color.parseColor("#6C5CE7"))
                    cornerRadius = 20 * resources.displayMetrics.density
                }
                
                // If contact is not in CRM, add them first
                if (currentLead?.id == 0) {
                    saveContactToCRM(selectedLabel)
                } else {
                    Toast.makeText(this, "✅ Label: $selectedLabel", Toast.LENGTH_SHORT).show()
                }
            }
            .create()
        
        // CRITICAL: Set window type to show over phone UI
        dialog.window?.setType(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
            }
        )
        dialog.show()
    }
    
    private fun saveContactToCRM(label: String) {
        serviceScope.launch(Dispatchers.IO) {
            try {
                val dbPath = getDatabasePath("sbs_database.db")
                if (!dbPath.exists()) {
                    withContext(Dispatchers.Main) {
                        Toast.makeText(this@CallOverlayService, "Database not found", Toast.LENGTH_SHORT).show()
                    }
                    return@launch
                }
                
                val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                    dbPath.absolutePath,
                    null,
                    android.database.sqlite.SQLiteDatabase.OPEN_READWRITE
                )
                
                val values = android.content.ContentValues().apply {
                    put("name", currentLead?.name ?: "Unknown")
                    put("phoneNumber", currentPhoneNumber ?: "")
                    put("email", currentLead?.email ?: "")
                    put("category", label)
                    put("status", "New")
                    put("isVip", 0)
                    put("createdAt", System.currentTimeMillis())
                }
                
                val newId = db.insert("leads", null, values)
                db.close()
                
                // Update currentLead with new ID
                currentLead = currentLead?.copy(id = newId.toInt(), category = label)
                
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@CallOverlayService, "Added to CRM with label: $label", Toast.LENGTH_LONG).show()
                }
                
                // Notify Flutter
                val intent = Intent("com.example.sbs.LEAD_CREATED")
                intent.putExtra("lead_id", newId.toInt())
                sendBroadcast(intent)
                
            } catch (e: Exception) {
                Log.e(TAG, "Error saving contact to CRM: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@CallOverlayService, "Error adding to CRM", Toast.LENGTH_SHORT).show()
                }
            }
        }
     }
    
    private fun showStatusDropdown(view: View, button: TextView) {
        val statuses = arrayOf("New", "Contacted", "Qualified", "Won", "Lost")
        val popupMenu = PopupMenu(this, view)
        statuses.forEachIndexed { index, status ->
            popupMenu.menu.add(0, index, index, status)
        }
        popupMenu.setOnMenuItemClickListener { menuItem ->
            val newStatus = statuses[menuItem.itemId]
            
            // Update button text to show selection
            button.text = "$newStatus ▼"
            
            // If contact is not in CRM, add them first
            if (currentLead?.id == 0) {
                saveContactToCRMWithStatus(newStatus)
            } else {
                updateLeadStatus(currentLead?.id ?: 0, newStatus)
                Toast.makeText(this, "✅ Status: $newStatus", Toast.LENGTH_SHORT).show()
            }
            true
        }
        popupMenu.show()
    }
    
    private fun saveContactToCRMWithStatus(status: String) {
        serviceScope.launch(Dispatchers.IO) {
            try {
                val dbPath = getDatabasePath("sbs_database.db")
                if (!dbPath.exists()) {
                    withContext(Dispatchers.Main) {
                        Toast.makeText(this@CallOverlayService, "Database not found", Toast.LENGTH_SHORT).show()
                    }
                    return@launch
                }
                
                val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                    dbPath.absolutePath,
                    null,
                    android.database.sqlite.SQLiteDatabase.OPEN_READWRITE
                )
                
                val values = android.content.ContentValues().apply {
                    put("name", currentLead?.name ?: "Unknown")
                    put("phoneNumber", currentPhoneNumber ?: "")
                    put("email", currentLead?.email ?: "")
                    put("category", "Contact")
                    put("status", status)
                    put("isVip", 0)
                    put("createdAt", System.currentTimeMillis())
                }
                
                val newId = db.insert("leads", null, values)
                db.close()
                
                currentLead = currentLead?.copy(id = newId.toInt(), status = status)
                
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@CallOverlayService, "Added to CRM with status: $status", Toast.LENGTH_LONG).show()
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Error saving contact: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@CallOverlayService, "Error adding to CRM", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
    
    private fun showTeamMemberSelector(button: TextView) {
        val teamMembers = arrayOf("John Doe", "Jane Smith", "Mike Johnson", "Unassigned")
        
        val dialog = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
            .setTitle("Assign To")
            .setItems(teamMembers) { _, which ->
                val selectedMember = teamMembers[which]
                button.text = "$selectedMember ▼"
                Toast.makeText(this, "✅ Assigned to: $selectedMember", Toast.LENGTH_SHORT).show()
            }
            .create()
        
        dialog.window?.setType(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
            }
        )
        dialog.show()
    }
    
    private fun showCreateMeetingDialog() {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(50, 40, 50, 10)
        }
        
        val titleInput = EditText(this).apply {
            hint = "Meeting title"
            setText("Meeting with ${currentLead?.name ?: "Contact"}")
        }
        layout.addView(titleInput)
        
        val dialog = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
            .setTitle("Create Meeting")
            .setView(layout)
            .setPositiveButton("Pick Date") { _, _ ->
                val title = titleInput.text.toString()
                showDateTimePicker(title)
            }
            .setNegativeButton("Cancel", null)
            .create()
        
        // CRITICAL: Set window type to show over phone UI
        dialog.window?.setType(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
            }
        )
        dialog.show()
    }
    
    /**
     * Save current contact to SBS database via Flutter MethodChannel
     */
    private fun saveContactToDatabase() {
        val phone = currentPhoneNumber ?: return
        val name = currentLead?.name ?: "Unknown"
        val category = currentLead?.category ?: "New"
        
        // Show immediate feedback
        Toast.makeText(this, "💾 Saving contact...", Toast.LENGTH_SHORT).show()
        
        // Notify Flutter to save the contact
        MethodChannelHandler.getInstance()?.notifySaveContact(name, phone, category)
        
        Log.d(TAG, "Save contact request sent: $name ($phone)")
    }
    
    private fun showDateTimePicker(title: String) {
        val calendar = Calendar.getInstance()
        val dateDialog = DatePickerDialog(this, { _, year, month, dayOfMonth ->
            val timeDialog = TimePickerDialog(this, { _, hourOfDay, minute ->
                saveMeeting(title, year, month, dayOfMonth, hourOfDay, minute)
            }, calendar.get(Calendar.HOUR_OF_DAY), calendar.get(Calendar.MINUTE), true)
            
            // CRITICAL: Set window type
            timeDialog.window?.setType(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
                }
            )
            timeDialog.show()
        }, calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH), calendar.get(Calendar.DAY_OF_MONTH))
        
        // CRITICAL: Set window type
        dateDialog.window?.setType(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
            }
        )
        dateDialog.show()
    }
    
    private fun saveMeeting(title: String, year: Int, month: Int, day: Int, hour: Int, minute: Int) {
        // Save to SharedPreferences or send to Flutter
        val prefs = getSharedPreferences("sbs_prefs", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("last_meeting", "$title on $day/${month+1}/$year at $hour:$minute")
            .apply()
        
        Toast.makeText(this, "Meeting scheduled: $title", Toast.LENGTH_LONG).show()
        
        // Notify Flutter
        val intent = Intent("com.example.sbs.MEETING_CREATED")
        intent.putExtra("title", title)
        intent.putExtra("lead_id", currentLead?.id ?: 0)
        sendBroadcast(intent)
    }
    
    private fun toggleAutoMessages() {
        val prefs = getSharedPreferences("sbs_prefs", Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean("auto_messages_enabled", false)
        
        if (isEnabled) {
            prefs.edit().putBoolean("auto_messages_enabled", false).apply()
            Toast.makeText(this, "Auto Messages turned OFF", Toast.LENGTH_SHORT).show()
        } else {
            showAutoMessageSetup()
        }
    }
    
    private fun showAutoMessageSetup() {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(50, 40, 50, 10)
        }
        
        val input = EditText(this).apply {
            hint = "Enter your auto-reply message"
            setText("Thanks for calling! I'll get back to you soon.")
            minLines = 3
        }
        layout.addView(input)
        
        val dialog = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
            .setTitle("Setup Auto Messages")
            .setView(layout)
            .setPositiveButton("Enable") { _, _ ->
                val message = input.text.toString()
                val prefs = getSharedPreferences("sbs_prefs", Context.MODE_PRIVATE)
                prefs.edit()
                    .putBoolean("auto_messages_enabled", true)
                    .putString("auto_message_text", message)
                    .apply()
                Toast.makeText(this, "Auto Messages enabled", Toast.LENGTH_SHORT).show()
            }
            .setNegativeButton("Cancel", null)
            .create()
        
        // CRITICAL: Set window type to show over phone UI
        dialog.window?.setType(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
            }
        )
        dialog.show()
    }
    
    private fun notifyFlutterEditLead(leadId: Int) {
        // Show immediate feedback
        Toast.makeText(this, "✏️ Opening edit form...", Toast.LENGTH_SHORT).show()
        
        val intent = Intent("com.example.sbs.EDIT_LEAD")
        intent.putExtra("lead_id", leadId)
        sendBroadcast(intent)
        Log.d(TAG, "Sent edit lead broadcast for ID: $leadId")
    }
    
    private fun showCreateTaskDialog() {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(50, 40, 50, 40)
            setBackgroundColor(Color.parseColor("#2A2A3E"))
        }
        
        
        val titleLabel = TextView(this).apply {
            text = "Task Title"
            textSize = 14f
            setTextColor(Color.parseColor("#B0B0B0"))
            setPadding(0, 0, 0, 10)
        }
        layout.addView(titleLabel)
        
        val titleInput = EditText(this).apply {
            hint = "Task title"
            setText("Follow up with ${currentLead?.name ?: "Contact"}")
            textSize = 16f
            setTextColor(Color.WHITE)
            setHintTextColor(Color.parseColor("#808080"))
            setPadding(40, 30, 40, 30)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1A1A2E"))
                cornerRadius = 24f
            }
        }
        layout.addView(titleInput)
        
        
        val priorityLabel = TextView(this).apply {
            text = "Priority"
            textSize = 14f
            setTextColor(Color.parseColor("#B0B0B0"))
            setPadding(0, 40, 0, 10)
        }
        layout.addView(priorityLabel)
        
        
        val prioritySpinner = Spinner(this).apply {
            setPadding(30, 20, 30, 20)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1A1A2E"))
                cornerRadius = 24f
            }
            adapter = ArrayAdapter(this@CallOverlayService, android.R.layout.simple_spinner_item,
                arrayOf("Low", "Medium", "High"))
        }
        layout.addView(prioritySpinner)
        
        
        val dialog = AlertDialog.Builder(this)
            .setTitle("Create Task")
            .setView(layout)
            .setPositiveButton("CREATE") { _, _ ->
                val title = titleInput.text.toString()
                val priority = prioritySpinner.selectedItem.toString()
                saveTask(title, priority)
            }
            .setNegativeButton("CANCEL", null)
            .create()
        
        // CRITICAL: Set window type to show over phone UI
        dialog.window?.setType(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
            }
        )
        
        // Apply purple theme
        dialog.window?.setBackgroundDrawable(GradientDrawable().apply {
            setColor(Color.parseColor("#2A2A3E"))
            cornerRadius = 48f
        })
        
        dialog.show()
        
        // Style buttons
        dialog.getButton(AlertDialog.BUTTON_POSITIVE)?.apply {
            setTextColor(Color.WHITE)
            setTypeface(null, android.graphics.Typeface.BOLD)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#6C5CE7"))
                cornerRadius = 18f
            }
            setPadding(50, 25, 50, 25)
        }
        dialog.getButton(AlertDialog.BUTTON_NEGATIVE)?.apply {
            setTextColor(Color.parseColor("#B0B0B0"))
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
    }
    
    private fun saveTask(title: String, priority: String) {
        serviceScope.launch(Dispatchers.IO) {
            try {
                val dbPath = getDatabasePath("sbs_database.db")
                if (!dbPath.exists()) {
                    withContext(Dispatchers.Main) {
                        Toast.makeText(this@CallOverlayService, "Database not found", Toast.LENGTH_SHORT).show()
                    }
                    return@launch
                }
                
                val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                    dbPath.absolutePath,
                    null,
                    android.database.sqlite.SQLiteDatabase.OPEN_READWRITE
                )
                
                val values = android.content.ContentValues().apply {
                    put("task", title)
                    put("leadId", currentLead?.id ?: 0)
                    put("priority", priority)
                    put("isDone", 0)
                    put("createdAt", System.currentTimeMillis())
                }
                
                db.insert("tasks", null, values)
                db.close()
                
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@CallOverlayService, "✅ Task created: $title", Toast.LENGTH_LONG).show()
                }
                
                // Notify Flutter
                val intent = Intent("com.example.sbs.TASK_CREATED")
                intent.putExtra("task_title", title)
                sendBroadcast(intent)
                
            } catch (e: Exception) {
                Log.e(TAG, "Error saving task: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@CallOverlayService, "Error creating task", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
    
    private fun updateLeadLabel(leadId: Int, labelId: Int) {
        serviceScope.launch(Dispatchers.IO) {
            try {
                val dbPath = getDatabasePath("sbs_database.db")
                if (!dbPath.exists()) return@launch
                
                val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                    dbPath.absolutePath,
                    null,
                    android.database.sqlite.SQLiteDatabase.OPEN_READWRITE
                )
                
                val values = android.content.ContentValues().apply {
                    put("labelId", labelId)
                }
                
                db.update("leads", values, "id = ?", arrayOf(leadId.toString()))
                db.close()
                
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@CallOverlayService, "Label updated", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error updating label: ${e.message}", e)
            }
        }
    }
    
    private fun updateLeadStatus(leadId: Int, status: String) {
        serviceScope.launch(Dispatchers.IO) {
            try {
                val dbPath = getDatabasePath("sbs_database.db")
                if (!dbPath.exists()) return@launch
                
                val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                    dbPath.absolutePath,
                    null,
                    android.database.sqlite.SQLiteDatabase.OPEN_READWRITE
                )
                
                val values = android.content.ContentValues().apply {
                    put("status", status)
                }
                
                db.update("leads", values, "id = ?", arrayOf(leadId.toString()))
                db.close()
                
                Log.d(TAG, "Lead $leadId status updated to: $status")
            } catch (e: Exception) {
        Log.e(TAG, "Error updating status: ${e.message}", e)
            }
        }
    }

    private fun fetchLabelsFromDatabase(): List<String> {
        return try {
            val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                getDatabasePath("sbs_database.db").absolutePath,
                null,
                android.database.sqlite.SQLiteDatabase.OPEN_READONLY
            )
            
            val cursor = db.rawQuery("SELECT name FROM labels ORDER BY id ASC", null)
            val labels = mutableListOf<String>()
            
            while (cursor.moveToNext()) {
                val nameIndex = cursor.getColumnIndex("name")
                if (nameIndex >= 0) {
                    labels.add(cursor.getString(nameIndex))
                }
            }
            
            cursor.close()
            db.close()
            
            // Fallback to defaults if no labels found
            if (labels.isEmpty()) {
                listOf("Client", "Partner", "Vendor", "Other")
            } else {
                labels
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching labels from database", e)
            listOf("Client", "Partner", "Vendor", "Other")
        }
    }

    private fun notifyFlutterNewLeadSaved(leadId: Int, name: String, phone: String, category: String) {
        try {
            val methodChannelHandler = MethodChannelHandler.getInstance()
            if (methodChannelHandler != null) {
                serviceScope.launch(Dispatchers.Main) {
                    methodChannelHandler.notifyNewLeadSaved(leadId, name, phone, category)
                    Log.d(TAG, "📡 Notified Flutter: New lead saved - $name")
                }
            } else {
                Log.w(TAG, "⚠️ MethodChannelHandler not available, skipping Flutter notification")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error notifying Flutter", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Monitor Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors incoming and outgoing calls"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(contentText: String): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SBS Call Monitor")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(contentText: String) {
        val notification = createNotification(contentText)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    // Log communication to database
    private fun logCommunication(
        type: String,
        direction: String,
        recipient: String?,
        subject: String?,
        body: String?,
        metadata: String? = null
    ) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                val leadId = currentLead?.id
                if (leadId == null || leadId == 0) {
                    Log.w(TAG, "⚠️ Cannot log communication: no valid lead (leadId=$leadId, recipient=$recipient)")
                    return@launch
                }
                
                val dbPath = getDatabasePath("sbs_database.db")
                if (!dbPath.exists()) {
                    Log.e(TAG, "Database not found")
                    return@launch
                }

                val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                    dbPath.absolutePath,
                    null,
                    android.database.sqlite.SQLiteDatabase.OPEN_READWRITE
                )

                val values = android.content.ContentValues().apply {
                    put("leadId", leadId)
                    put("type", type)
                    put("direction", direction)
                    if (subject != null) put("subject", subject)
                    if (body != null) put("body", body)
                    if (type == "email") {
                        put("emailAddress", recipient)
                    } else {
                        put("phoneNumber", recipient)
                    }
                    put("timestamp", System.currentTimeMillis())
                    put("status", "sent")
                    if (metadata != null) put("metadata", metadata)
                }

                val id = db.insert("communications", null, values)
                db.close()

                if (id > 0) {
                    Log.d(TAG, "Communication logged: $type to $recipient (Auto: ${metadata != null})")
                } else {
                    Log.e(TAG, "Failed to log communication")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error logging communication", e)
            }
        }
    }
    
    private fun showMoveToDialog() {
        val statuses = arrayOf("New", "In Progress", "Follow Up", "Contacted", "Qualified", "Converted")
        val dialog = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
            .setTitle("Move to Status")
            .setItems(statuses) { _, which ->
                val selectedStatus = statuses[which]
                currentLead?.id?.let { leadId ->
                    updateLeadStatusInDB(leadId, selectedStatus)
                    Toast.makeText(this, "✅ Moved to: $selectedStatus", Toast.LENGTH_SHORT).show()
                }
            }
            .create()
        dialog.window?.setType(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else { @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_ALERT })
        dialog.show()
    }
    
    private fun showAssignedToDialog() {
        val teamMembers = arrayOf("Unassigned", "Admin", "Sales Team", "Support Team")
        val dialog = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
            .setTitle("Assign to Team Member")
            .setItems(teamMembers) { _, which ->
                val selectedMember = teamMembers[which]
                currentLead?.id?.let { leadId ->
                    updateLeadAssignmentInDB(leadId, selectedMember)
                    Toast.makeText(this, "✅ Assigned to: $selectedMember", Toast.LENGTH_SHORT).show()
                }
            }
            .create()
        dialog.window?.setType(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else { @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_ALERT })
        dialog.show()
    }
    
    private fun updateLeadStatusInDB(leadId: Int, status: String) {
        GlobalScope.launch(Dispatchers.IO) { 
            try {
                val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                    getDatabasePath("sbs_database.db").absolutePath, 
                    null, 
                    android.database.sqlite.SQLiteDatabase.OPEN_READWRITE
                )
                val values = android.content.ContentValues().apply { put("status", status) }
                db.update("leads", values, "id = ?", arrayOf(leadId.toString()))
                db.close()
                withContext(Dispatchers.Main) { 
                    Log.d(TAG, "✅ Lead status updated to: $status") 
                }
            } catch (e: Exception) { 
                Log.e(TAG, "Error updating lead status", e) 
            } 
        }
    }
    
    private fun updateLeadAssignmentInDB(leadId: Int, assignedTo: String) {
        GlobalScope.launch(Dispatchers.IO) { 
            try {
                val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                    getDatabasePath("sbs_database.db").absolutePath, 
                    null, 
                    android.database.sqlite.SQLiteDatabase.OPEN_READWRITE
                )
                val values = android.content.ContentValues().apply { put("assignedTo", assignedTo) }
                db.update("leads", values, "id = ?", arrayOf(leadId.toString()))
                db.close()
                withContext(Dispatchers.Main) { 
                    Log.d(TAG, "✅ Lead assigned to: $assignedTo") 
                }
            } catch (e: Exception) { 
                Log.e(TAG, "Error updating lead assignment", e) 
            } 
        }
    }
}
