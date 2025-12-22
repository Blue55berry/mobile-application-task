package com.example.sbs

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.*
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import android.content.pm.ServiceInfo
import kotlinx.coroutines.*

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

    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var phoneCallDetector: PhoneCallDetector? = null

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
        removeFloatingIcon()
        removePopup()
        serviceScope.cancel()
        super.onDestroy()
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
        // Remove any existing popup/icon from previous call
        removePopup()
        removeFloatingIcon()
        // Clear previous lead state to ensure fresh lookup
        currentLead = null
        currentPhoneNumber = phoneNumber
        queryLeadAndShowOverlay(phoneNumber, isIncoming = true)
        updateNotification("Incoming call: ${phoneNumber ?: "Unknown"}")
    }

    private fun handleOutgoingCall(phoneNumber: String?) {
        Log.d(TAG, "📞 Outgoing call: $phoneNumber")
        // Remove any existing popup/icon from previous call
        removePopup()
        removeFloatingIcon()
        // Clear previous lead state to ensure fresh lookup
        currentLead = null
        currentPhoneNumber = phoneNumber
        queryLeadAndShowOverlay(phoneNumber, isIncoming = false)
        updateNotification("Outgoing call: ${phoneNumber ?: "Unknown"}")
    }

    private fun handleCallStarted() {
        Log.d(TAG, "📞 Call started")
        updateNotification("Call in progress")
    }

    private fun handleCallEnded() {
        Log.d(TAG, "📞 Call ended")
        removeFloatingIcon()
        removePopup()
        currentPhoneNumber = null
        currentLead = null
        updateNotification("Monitoring calls...")
    }

    private fun queryLeadAndShowOverlay(phoneNumber: String?, isIncoming: Boolean) {
        if (phoneNumber == null) return
        serviceScope.launch {
            currentLead = queryLeadFromDatabase(phoneNumber)
            Log.d(TAG, "🔍 Lead lookup result: ${if (currentLead != null) "FOUND" else "NOT FOUND"}")
            
            // Show floating icon
            showFloatingIcon()
            
            // Auto-show popup if lead is saved
            if (currentLead != null) {
                // Small delay for better UX
                kotlinx.coroutines.delay(500)
                showPopup()
            }
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
                            isVip = cursor.getColumnIndex("isVip").let { if (it >= 0) cursor.getInt(it) == 1 else false }
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

    private fun showFloatingIcon() {
        if (isFloatingIconVisible) return
        try {
            floatingIconView = createFloatingIconView()
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = 20
                y = 100
            }
            windowManager?.addView(floatingIconView, params)
            isFloatingIconVisible = true
            Log.d(TAG, "✅ Floating icon shown")
        } catch (e: Exception) {
            Log.e(TAG, "Error showing floating icon", e)
        }
    }

    private fun createFloatingIconView(): View {
        val density = resources.displayMetrics.density
        val iconSize = (60 * density).toInt()
        
        val frameLayout = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(iconSize, iconSize)
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
                    if (!isDragging) {
                        // It's a click - show popup for saved contacts, otherwise toggle
                        if (currentLead != null) {
                            showPopup()
                        } else {
                            togglePopup()
                        }
                    }
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

    private fun removeFloatingIcon() {
        try {
            floatingIconView?.let { windowManager?.removeView(it) }
            floatingIconView = null
            isFloatingIconVisible = false
            Log.d(TAG, "Floating icon removed")
        } catch (e: Exception) {
            Log.e(TAG, "Error removing floating icon", e)
        }
    }

    private fun showPopup() {
        if (isPopupVisible) return
        try {
            popupView = createPopupView()
            
            // Determine flags: 
            // - Info popup (currentLead != null): No focus needed (FLAG_NOT_FOCUSABLE)
            // - Form popup (currentLead == null): Needs focus for keyboard, remove FLAG_NOT_FOCUSABLE
            var flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
            if (currentLead != null) {
                flags = flags or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
                flags,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.BOTTOM
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
        
        // Main container with semi-transparent background
        val mainContainer = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            setBackgroundColor(Color.parseColor("#80000000"))
            setPadding(0, 0, 0, 0)
        }

        // Card view
        val cardView = LinearLayout(this).apply {
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
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#2A2A3E"))
                cornerRadius = 24 * density
                setStroke((1 * density).toInt(), Color.parseColor("#4D6C5CE7"))
            }
            elevation = 24f
            setPadding(
                (24 * density).toInt(),
                (24 * density).toInt(),
                (24 * density).toInt(),
                (24 * density).toInt()
            )
        }

        // Close button
        val closeButton = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.END
            }
            text = "✕"
            textSize = 24f
            setTextColor(Color.WHITE)
            setPadding((12 * density).toInt(), (8 * density).toInt(), (12 * density).toInt(), (8 * density).toInt())
            setOnClickListener { removePopup() }
        }
        cardView.addView(closeButton)

        // Avatar
        val avatarSize = (80 * density).toInt()
        val avatar = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(avatarSize, avatarSize).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                topMargin = (8 * density).toInt()
            }
            text = (currentLead?.name?.firstOrNull()?.uppercase() ?: "?")
            gravity = Gravity.CENTER
            textSize = 36f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                colors = intArrayOf(Color.parseColor("#6C5CE7"), Color.parseColor("#A855F7"))
                setStroke((3 * density).toInt(), Color.parseColor("#FFFFFF"))
            }
            elevation = 8f
        }
        cardView.addView(avatar)

        // Name
        val name = currentLead?.name ?: "Unknown Caller"
        cardView.addView(TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (16 * density).toInt()
            }
            text = name
            textSize = 28f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        })

        // Category badge
        val category = currentLead?.category ?: "Unknown"
        val categoryColor = when(category.lowercase()) {
            "client" -> "#00C853"
            "partner" -> "#2196F3"
            "vendor" -> "#FF9800"
            "vip" -> "#FFD700"
            else -> "#6C5CE7"
        }

        val categoryBadge = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                topMargin = (12 * density).toInt()
            }
            text = category.uppercase()
            textSize = 14f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding((20 * density).toInt(), (8 * density).toInt(), (20 * density).toInt(), (8 * density).toInt())
            background = GradientDrawable().apply {
                setColor(Color.parseColor(categoryColor))
                cornerRadius = 20 * density
            }
            elevation = 4f
        }
        cardView.addView(categoryBadge)

        // Phone number
        val phoneNumber = currentPhoneNumber ?: ""
        if (phoneNumber.isNotEmpty()) {
            cardView.addView(TextView(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = (16 * density).toInt()
                }
                text = phoneNumber
                textSize = 16f
                setTextColor(Color.parseColor("#AAAAAA"))
                gravity = Gravity.CENTER
            })
        }

        // Email
        currentLead?.email?.let { email ->
            if (email.isNotEmpty()) {
                cardView.addView(TextView(this).apply {
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        topMargin = (8 * density).toInt()
                    }
                    text = "📧 $email"
                    textSize = 14f
                    setTextColor(Color.parseColor("#CCCCCC"))
                    gravity = Gravity.CENTER
                })
            }
        }

        // Status
        currentLead?.status?.let { status ->
            cardView.addView(TextView(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = (12 * density).toInt()
                }
                text = "Status: $status"
                textSize = 13f
                setTextColor(Color.parseColor("#CCCCCC"))
                gravity = Gravity.CENTER
            })
        }

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
            setTextColor(Color.parseColor("#AAAAAA"))
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
                    put("phoneNumber", currentPhoneNumber)
                    put("email", if (email.isNotEmpty()) email else null)
                    put("category", category)
                    put("status", "New")
                    put("createdAt", java.time.Instant.now().toString())
                    put("totalCalls", 0)
                    put("isVip", 0)
                }
                
                val id = db.insert("leads", null, values)
                db.close()
                
                withContext(Dispatchers.Main) {
                    if (id > 0) {
                        Log.d(TAG, "✅ New lead saved: $name (ID: $id)")
                        android.widget.Toast.makeText(
                            this@CallOverlayService,
                            "Contact saved successfully!",
                            android.widget.Toast.LENGTH_SHORT
                        ).show()
                        
                        // Reload lead data
                        currentLead = queryLeadFromDatabase(currentPhoneNumber ?: "")
                        
                        // Notify Flutter app about new lead
                        notifyFlutterNewLeadSaved(id.toInt(), name, currentPhoneNumber ?: "", category)
                    } else {
                        Log.e(TAG, "Failed to save lead")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error saving lead", e)
                withContext(Dispatchers.Main) {
                    android.widget.Toast.makeText(
                        this@CallOverlayService,
                        "Failed to save contact",
                        android.widget.Toast.LENGTH_SHORT
                    ).show()
                }
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
}

data class Lead(
    val id: Int,
    val name: String,
    val phone: String,
    val email: String?,
    val category: String,
    val status: String,
    val isVip: Boolean
)