// lib/services/database_service.dart (updated)

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/lead_model.dart';
import '../models/call_history_model.dart';
import '../models/user_model.dart';
import '../models/label_model.dart';
import '../models/quotation_model.dart';
import '../models/quotation_item_model.dart';
import '../models/invoice_model.dart';
import '../models/invoice_item_model.dart';
import '../models/communication_model.dart';

class DatabaseService {
  static Database? _database;
  static const String dbName =
      'sbs_database.db'; // Changed to match native service

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    String path = join(await getDatabasesPath(), dbName);
    return await openDatabase(
      path,
      version: 15, // Incremented for automatic_messages table
      onCreate: (db, version) async {
        // Create leads table
        await db.execute('''CREATE TABLE leads(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            status TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            phoneNumber TEXT UNIQUE,
            email TEXT,
            description TEXT,
            lastCallDate TEXT,
            totalCalls INTEGER DEFAULT 0,
            assignedDate TEXT,
            assignedTime TEXT,
            isVip INTEGER DEFAULT 0,
            source TEXT DEFAULT 'crm',
            photoUrl TEXT
          )''');

        // Create call history table
        await db.execute('''CREATE TABLE call_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            leadId INTEGER NOT NULL,
            callTime TEXT NOT NULL,
            duration INTEGER NOT NULL,
            isIncoming INTEGER NOT NULL,
            notes TEXT,
            FOREIGN KEY (leadId) REFERENCES leads (id) ON DELETE CASCADE
          )''');

        // Create tasks table
        await db.execute('''CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT,
            dueDate TEXT NOT NULL,
            dueTime TEXT,
            category TEXT NOT NULL,
            priority TEXT NOT NULL,
            isCompleted INTEGER DEFAULT 0,
            leadId INTEGER,
            reminder TEXT,
            FOREIGN KEY (leadId) REFERENCES leads (id) ON DELETE CASCADE
          )''');

        // Create notes table
        await db.execute('''CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            leadId INTEGER NOT NULL,
            FOREIGN KEY (leadId) REFERENCES leads (id) ON DELETE CASCADE
          )''');

        // Create tags table
        await db.execute('''CREATE TABLE tags(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            color INTEGER NOT NULL
          )''');

        // Create lead_tags junction table
        await db.execute('''CREATE TABLE lead_tags(
            leadId INTEGER NOT NULL,
            tagId INTEGER NOT NULL,
            PRIMARY KEY (leadId, tagId),
            FOREIGN KEY (leadId) REFERENCES leads (id) ON DELETE CASCADE,
            FOREIGN KEY (tagId) REFERENCES tags (id) ON DELETE CASCADE
          )''');

        // Create users table for authentication
        await db.execute('''CREATE TABLE users(
            id TEXT PRIMARY KEY,
            email TEXT UNIQUE NOT NULL,
            displayName TEXT NOT NULL,
            photoUrl TEXT,
            loginDate TEXT NOT NULL
          )''');

        // Create labels table for custom categories
        await db.execute('''CREATE TABLE labels(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            color TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )''');

        // Insert default labels
        await db.insert('labels', {
          'name': 'Client',
          'color': '#00C853',
          'createdAt': DateTime.now().toIso8601String(),
        });
        await db.insert('labels', {
          'name': 'Partner',
          'color': '#2196F3',
          'createdAt': DateTime.now().toIso8601String(),
        });
        await db.insert('labels', {
          'name': 'Vendor',
          'color': '#FF9800',
          'createdAt': DateTime.now().toIso8601String(),
        });
        await db.insert('labels', {
          'name': 'Other',
          'color': '#6C5CE7',
          'createdAt': DateTime.now().toIso8601String(),
        });

        // Create quotations table
        await db.execute('''CREATE TABLE quotations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            leadId INTEGER NOT NULL,
            quotationNumber TEXT UNIQUE NOT NULL,
            createdAt TEXT NOT NULL,
            validUntil TEXT NOT NULL,
            status TEXT NOT NULL,
            subtotal REAL NOT NULL,
            taxRate REAL NOT NULL,
            taxAmount REAL NOT NULL,
            discountPercent REAL DEFAULT 0,
            discountAmount REAL DEFAULT 0,
            totalAmount REAL NOT NULL,
            notes TEXT,
            termsAndConditions TEXT,
            FOREIGN KEY (leadId) REFERENCES leads (id) ON DELETE CASCADE
          )''');

        // Create quotation_items table
        await db.execute('''CREATE TABLE quotation_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            quotationId INTEGER NOT NULL,
            itemName TEXT NOT NULL,
            description TEXT,
            quantity REAL NOT NULL,
            unit TEXT NOT NULL,
            unitPrice REAL NOT NULL,
            totalPrice REAL NOT NULL,
            position INTEGER NOT NULL,
            FOREIGN KEY (quotationId) REFERENCES quotations (id) ON DELETE CASCADE
          )''');

        // Create invoices table
        await db.execute('''CREATE TABLE invoices(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            leadId INTEGER NOT NULL,
            quotationId INTEGER,
            invoiceNumber TEXT UNIQUE NOT NULL,
            createdAt TEXT NOT NULL,
            dueDate TEXT NOT NULL,
            status TEXT NOT NULL,
            paymentStatus TEXT NOT NULL,
            subtotal REAL NOT NULL,
            taxRate REAL NOT NULL,
            taxAmount REAL NOT NULL,
            discountPercent REAL DEFAULT 0,
            discountAmount REAL DEFAULT 0,
            totalAmount REAL NOT NULL,
            paidAmount REAL DEFAULT 0,
            balanceAmount REAL NOT NULL,
            notes TEXT,
            termsAndConditions TEXT,
            paidDate TEXT,
            FOREIGN KEY (leadId) REFERENCES leads (id) ON DELETE CASCADE,
            FOREIGN KEY (quotationId) REFERENCES quotations (id) ON DELETE SET NULL
          )''');

        // Create invoice_items table
        await db.execute('''CREATE TABLE invoice_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoiceId INTEGER NOT NULL,
            itemName TEXT NOT NULL,
            description TEXT,
            quantity REAL NOT NULL,
            unit TEXT NOT NULL,
            unitPrice REAL NOT NULL,
            totalPrice REAL NOT NULL,
            position INTEGER NOT NULL,
            FOREIGN KEY (invoiceId) REFERENCES invoices (id) ON DELETE CASCADE
          )''');

        // Create payments table for tracking invoice payments
        await db.execute('''CREATE TABLE payments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoiceId INTEGER NOT NULL,
            amount REAL NOT NULL,
            paymentDate TEXT NOT NULL,
            paymentMethod TEXT NOT NULL,
            referenceNumber TEXT,
            notes TEXT,
            FOREIGN KEY (invoiceId) REFERENCES invoices (id) ON DELETE CASCADE
          )''');

        // Create companies table
        await db.execute('''CREATE TABLE companies(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT,
            industry TEXT,
            email TEXT,
            phone TEXT,
            website TEXT,
            address TEXT,
            logo TEXT,
            member_count INTEGER DEFAULT 1,
            team_members TEXT,
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL
          )''');

        // Create automatic_messages table
        await db.execute('''CREATE TABLE automatic_messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            message TEXT NOT NULL,
            trigger TEXT NOT NULL,
            is_enabled INTEGER DEFAULT 1,
            created_at TEXT NOT NULL
          )''');

        // Insert default automatic messages
        await db.insert('automatic_messages', {
          'name': 'Missed Call Reply',
          'message': 'Sorry I missed your call. I will get back to you soon.',
          'trigger': 'missed_call',
          'is_enabled': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
        await db.insert('automatic_messages', {
          'name': 'New Contact Welcome',
          'message': 'Thank you for contacting us! We\'ll be in touch shortly.',
          'trigger': 'new_contact',
          'is_enabled': 1,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Create index on phone number for faster lookups
        await db.execute(
          'CREATE INDEX idx_phone_number ON leads (phoneNumber)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add new columns if upgrading
          await db.execute('ALTER TABLE leads ADD COLUMN description TEXT');
          await db.execute('ALTER TABLE leads ADD COLUMN lastCallDate TEXT');
          await db.execute(
            'ALTER TABLE leads ADD COLUMN totalCalls INTEGER DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          // Add new columns if upgrading from version 2
          await db.execute('ALTER TABLE leads ADD COLUMN assignedDate TEXT');
          await db.execute('ALTER TABLE leads ADD COLUMN assignedTime TEXT');
        }
        if (oldVersion < 4) {
          // Add VIP column if upgrading from version 3
          await db.execute(
            'ALTER TABLE leads ADD COLUMN isVip INTEGER DEFAULT 0',
          );
        }
        if (oldVersion < 5) {
          // Create tasks table
          await db.execute('''CREATE TABLE tasks(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              description TEXT,
              dueDate TEXT NOT NULL,
              dueTime TEXT,
              category TEXT NOT NULL,
              priority TEXT NOT NULL,
              isCompleted INTEGER DEFAULT 0,
              leadId INTEGER,
              reminder TEXT,
              FOREIGN KEY (leadId) REFERENCES leads (id) ON DELETE CASCADE
            )''');

          // Create notes table
          await db.execute('''CREATE TABLE notes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              content TEXT NOT NULL,
              createdAt TEXT NOT NULL,
              leadId INTEGER NOT NULL,
              FOREIGN KEY (leadId) REFERENCES leads (id) ON DELETE CASCADE
            )''');

          // Create tags and junction table
          await db.execute('''CREATE TABLE tags(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              color INTEGER NOT NULL
            )''');

          await db.execute('''CREATE TABLE lead_tags(
              leadId INTEGER NOT NULL,
              tagId INTEGER NOT NULL,
              PRIMARY KEY (leadId, tagId),
              FOREIGN KEY (leadId) REFERENCES leads (id) ON DELETE CASCADE,
              FOREIGN KEY (tagId) REFERENCES tags (id) ON DELETE CASCADE
            )''');
        }
        if (oldVersion < 6) {
          // Create users table for authentication
          await db.execute('''CREATE TABLE users(
              id TEXT PRIMARY KEY,
              email TEXT UNIQUE NOT NULL,
              displayName TEXT NOT NULL,
              photoUrl TEXT,
              loginDate TEXT NOT NULL
            )''');
        }
        if (oldVersion < 7) {
          // Create labels table for custom categories
          await db.execute('''CREATE TABLE labels(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              color TEXT NOT NULL,
              createdAt TEXT NOT NULL
            )''');

          // Insert default labels
          await db.insert('labels', {
            'name': 'Client',
            'color': '#00C853',
            'createdAt': DateTime.now().toIso8601String(),
          });
          await db.insert('labels', {
            'name': 'Partner',
            'color': '#2196F3',
            'createdAt': DateTime.now().toIso8601String(),
          });
          await db.insert('labels', {
            'name': 'Vendor',
            'color': '#FF9800',
            'createdAt': DateTime.now().toIso8601String(),
          });
          await db.insert('labels', {
            'name': 'Other',
            'color': '#6C5CE7',
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
        if (oldVersion < 8) {
          // Create quotations table
          await db.execute('''CREATE TABLE quotations(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              leadId INTEGER NOT NULL,
              quotationNumber TEXT UNIQUE NOT NULL,
              createdAt TEXT NOT NULL,
              validUntil TEXT NOT NULL,
              status TEXT NOT NULL,
              subtotal REAL NOT NULL,
              taxRate REAL NOT NULL,
              taxAmount REAL NOT NULL,
              discountPercent REAL DEFAULT 0,
              discountAmount REAL DEFAULT 0,
              totalAmount REAL NOT NULL,
              notes TEXT,
              termsAndConditions TEXT,
              FOREIGN KEY (leadId) REFERENCES leads (id) ON DELETE CASCADE
            )''');

          // Create quotation_items table
          await db.execute('''CREATE TABLE quotation_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              quotationId INTEGER NOT NULL,
              itemName TEXT NOT NULL,
              description TEXT,
              quantity REAL NOT NULL,
              unit TEXT NOT NULL,
              unitPrice REAL NOT NULL,
              totalPrice REAL NOT NULL,
              position INTEGER NOT NULL,
              FOREIGN KEY (quotationId) REFERENCES quotations (id) ON DELETE CASCADE
            )''');

          // Create invoices table
          await db.execute('''CREATE TABLE invoices(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              leadId INTEGER NOT NULL,
              quotationId INTEGER,
              invoiceNumber TEXT UNIQUE NOT NULL,
              createdAt TEXT NOT NULL,
              dueDate TEXT NOT NULL,
              status TEXT NOT NULL,
              paymentStatus TEXT NOT NULL,
              subtotal REAL NOT NULL,
              taxRate REAL NOT NULL,
              taxAmount REAL NOT NULL,
              discountPercent REAL DEFAULT 0,
              discountAmount REAL DEFAULT 0,
              totalAmount REAL NOT NULL,
              paidAmount REAL DEFAULT 0,
              balanceAmount REAL NOT NULL,
              notes TEXT,
              termsAndConditions TEXT,
              paidDate TEXT,
              FOREIGN KEY (leadId) REFERENCES leads (id) ON DELETE CASCADE,
              FOREIGN KEY (quotationId) REFERENCES quotations (id) ON DELETE SET NULL
            )''');

          // Create invoice_items table
          await db.execute('''CREATE TABLE invoice_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              invoiceId INTEGER NOT NULL,
              itemName TEXT NOT NULL,
              description TEXT,
              quantity REAL NOT NULL,
              unit TEXT NOT NULL,
              unitPrice REAL NOT NULL,
              totalPrice REAL NOT NULL,
              position INTEGER NOT NULL,
              FOREIGN KEY (invoiceId) REFERENCES invoices (id) ON DELETE CASCADE
            )''');
        }
        if (oldVersion < 9) {
          // Create payments table for tracking invoice payments
          await db.execute('''CREATE TABLE payments(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              invoiceId INTEGER NOT NULL,
              amount REAL NOT NULL,
              paymentDate TEXT NOT NULL,
              paymentMethod TEXT NOT NULL,
              referenceNumber TEXT,
              notes TEXT,
              FOREIGN KEY (invoiceId) REFERENCES invoices (id) ON DELETE CASCADE
            )''');
        }
        if (oldVersion < 10) {
          // Add source column to leads table
          await db.execute(
            "ALTER TABLE leads ADD COLUMN source TEXT DEFAULT 'crm'",
          );
        }
        if (oldVersion < 11) {
          // Add communications table
          await db.execute('''CREATE TABLE IF NOT EXISTS communications(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              leadId INTEGER NOT NULL,
              type TEXT NOT NULL,
              direction TEXT NOT NULL,
              subject TEXT,
              body TEXT,
              phoneNumber TEXT,
              emailAddress TEXT,
              timestamp INTEGER NOT NULL,
              status TEXT NOT NULL,
              metadata TEXT,
              FOREIGN KEY (leadId) REFERENCES leads (id) ON DELETE CASCADE
            )''');
        }

        if (oldVersion < 12) {
          // Add photoUrl column to leads table
          await db.execute("ALTER TABLE leads ADD COLUMN photoUrl TEXT");
        }
        if (oldVersion < 13) {
          // Add companies table when upgrading to version 13
          await db.execute('''CREATE TABLE IF NOT EXISTS companies(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              type TEXT,
              industry TEXT,
              email TEXT,
              phone TEXT,
              website TEXT,
              address TEXT,
              logo TEXT,
              member_count INTEGER DEFAULT 1,
              team_members TEXT,
              is_active INTEGER DEFAULT 1,
              created_at TEXT NOT NULL
            )''');
        }

        if (oldVersion < 14) {
          // Add team_members column to companies table
          try {
            await db.execute(
              'ALTER TABLE companies ADD COLUMN team_members TEXT',
            );
            debugPrint('✅ Added team_members column to companies table');
          } catch (e) {
            debugPrint('⚠️ team_members column may already exist: $e');
          }
        }

        if (oldVersion < 15) {
          // Add automatic_messages table when upgrading to version 15
          await db.execute('''CREATE TABLE IF NOT EXISTS automatic_messages(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              message TEXT NOT NULL,
              trigger TEXT NOT NULL,
              is_enabled INTEGER DEFAULT 1,
              created_at TEXT NOT NULL
            )''');

          // Insert default messages
          await db.insert('automatic_messages', {
            'name': 'Missed Call Reply',
            'message': 'Sorry I missed your call. I will get back to you soon.',
            'trigger': 'missed_call',
            'is_enabled': 1,
            'created_at': DateTime.now().toIso8601String(),
          });
          await db.insert('automatic_messages', {
            'name': 'New Contact Welcome',
            'message':
                'Thank you for contacting us! We will be in touch shortly.',
            'trigger': 'new_contact',
            'is_enabled': 1,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      },
    );
  }

  // Lead operations
  Future<int> insertLead(Lead lead) async {
    final db = await database;
    return await db.insert('leads', lead.toMap());
  }

  Future<List<Lead>> getLeads() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'leads',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Lead.fromMap(maps[i]));
  }

  Future<Lead?> getLeadByPhone(String phoneNumber) async {
    final db = await database;

    // Normalize phone number: keep only digits and get last 10
    final normalizedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final last10Digits = normalizedPhone.length >= 10
        ? normalizedPhone.substring(normalizedPhone.length - 10)
        : normalizedPhone;

    // Use LIKE to match phone numbers regardless of country code or formatting
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT * FROM leads 
      WHERE phoneNumber LIKE ? 
         OR phoneNumber LIKE ?
         OR phoneNumber = ?
      LIMIT 1
      ''',
      ['%$last10Digits%', '%$phoneNumber%', phoneNumber],
    );

    if (maps.isEmpty) return null;
    return Lead.fromMap(maps.first);
  }

  Future<int> updateLead(Lead lead) async {
    final db = await database;
    return await db.update(
      'leads',
      lead.toMap(),
      where: 'id = ?',
      whereArgs: [lead.id],
    );
  }

  Future<int> deleteLead(int id) async {
    final db = await database;
    return await db.delete('leads', where: 'id = ?', whereArgs: [id]);
  }

  // Call history operations
  Future<int> insertCallHistory(CallHistory callHistory) async {
    final db = await database;
    return await db.insert('call_history', callHistory.toMap());
  }

  Future<List<CallHistory>> getCallHistoryForLead(int leadId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'call_history',
      where: 'leadId = ?',
      whereArgs: [leadId],
      orderBy: 'callTime DESC',
    );
    return List.generate(maps.length, (i) => CallHistory.fromMap(maps[i]));
  }

  // Task operations
  Future<int> insertTask(Map<String, dynamic> taskMap) async {
    final db = await database;
    return await db.insert('tasks', taskMap);
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    final db = await database;
    return await db.query('tasks', orderBy: 'dueDate ASC');
  }

  Future<int> updateTask(Map<String, dynamic> taskMap) async {
    final db = await database;
    return await db.update(
      'tasks',
      taskMap,
      where: 'id = ?',
      whereArgs: [taskMap['id']],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // Note operations
  Future<int> insertNote(Map<String, dynamic> noteMap) async {
    final db = await database;
    return await db.insert('notes', noteMap);
  }

  Future<List<Map<String, dynamic>>> getNotesForLead(int leadId) async {
    final db = await database;
    return await db.query(
      'notes',
      where: 'leadId = ?',
      whereArgs: [leadId],
      orderBy: 'createdAt DESC',
    );
  }

  // Update lead call statistics
  Future<void> updateLeadCallStats(int leadId, DateTime callTime) async {
    final db = await database;
    await db.rawUpdate(
      '''UPDATE leads 
         SET totalCalls = totalCalls + 1, 
             lastCallDate = ? 
         WHERE id = ?''',
      [callTime.toIso8601String(), leadId],
    );
  }

  // Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;

    final totalLeads =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM leads'),
        ) ??
        0;

    final totalCalls =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT SUM(totalCalls) FROM leads'),
        ) ??
        0;

    final categoryCounts = await db.rawQuery(
      'SELECT category, COUNT(*) as count FROM leads GROUP BY category',
    );

    return {
      'totalLeads': totalLeads,
      'totalCalls': totalCalls,
      'categoryCounts': categoryCounts,
    };
  }

  // Export database data
  Future<List<Map<String, dynamic>>> exportAllData() async {
    final db = await database;

    final leads = await db.query('leads');
    final callHistory = await db.query('call_history');

    return [
      {'leads': leads},
      {'call_history': callHistory},
    ];
  }

  // User operations (for authentication)
  Future<void> saveUser(AppUser user) async {
    final db = await database;

    // Use INSERT OR REPLACE to handle updates
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUser(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<int> deleteUser(String id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // Label operations
  Future<List<Label>> getLabels() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'labels',
      orderBy: 'createdAt ASC', // Show default labels first
    );
    return List.generate(maps.length, (i) => Label.fromMap(maps[i]));
  }

  Future<int> insertLabel(Label label) async {
    final db = await database;
    try {
      return await db.insert('labels', label.toMap());
    } catch (e) {
      // Handle duplicate label name
      throw Exception('Label name already exists');
    }
  }

  Future<void> updateLabel(Label label) async {
    final db = await database;
    await db.update(
      'labels',
      label.toMap(),
      where: 'id = ?',
      whereArgs: [label.id],
    );
  }

  Future<void> deleteLabel(int id) async {
    final db = await database;
    await db.delete('labels', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isLabelInUse(int id) async {
    final db = await database;
    // Get the label name first
    final labelResult = await db.query(
      'labels',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (labelResult.isEmpty) return false;

    final labelName = labelResult.first['name'] as String;

    // Check if any leads use this label
    final result = await db.query(
      'leads',
      where: 'category = ?',
      whereArgs: [labelName],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // ============================================
  // Quotation operations
  // ============================================

  Future<int> insertQuotation(Quotation quotation) async {
    final db = await database;
    return await db.insert('quotations', quotation.toMap());
  }

  Future<List<Quotation>> getQuotations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'quotations',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Quotation.fromMap(maps[i]));
  }

  Future<Quotation?> getQuotationById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'quotations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Quotation.fromMap(maps.first);
  }

  Future<List<Quotation>> getQuotationsForLead(int leadId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'quotations',
      where: 'lead Id = ?',
      whereArgs: [leadId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Quotation.fromMap(maps[i]));
  }

  Future<int> updateQuotation(Quotation quotation) async {
    final db = await database;
    return await db.update(
      'quotations',
      quotation.toMap(),
      where: 'id = ?',
      whereArgs: [quotation.id],
    );
  }

  Future<int> deleteQuotation(int id) async {
    final db = await database;
    return await db.delete('quotations', where: 'id = ?', whereArgs: [id]);
  }

  // Quotation Item operations
  Future<int> insertQuotationItem(QuotationItem item) async {
    final db = await database;
    return await db.insert('quotation_items', item.toMap());
  }

  Future<List<QuotationItem>> getQuotationItems(int quotationId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'quotation_items',
      where: 'quotationId = ?',
      whereArgs: [quotationId],
      orderBy: 'position ASC',
    );
    return List.generate(maps.length, (i) => QuotationItem.fromMap(maps[i]));
  }

  Future<int> updateQuotationItem(QuotationItem item) async {
    final db = await database;
    return await db.update(
      'quotation_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteQuotationItem(int id) async {
    final db = await database;
    return await db.delete('quotation_items', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================
  // Invoice operations
  // ============================================

  Future<int> insertInvoice(Invoice invoice) async {
    final db = await database;
    return await db.insert('invoices', invoice.toMap());
  }

  Future<List<Invoice>> getInvoices() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Invoice.fromMap(maps[i]));
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Invoice.fromMap(maps.first);
  }

  Future<List<Invoice>> getInvoicesForLead(int leadId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'leadId = ?',
      whereArgs: [leadId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Invoice.fromMap(maps[i]));
  }

  Future<int> updateInvoice(Invoice invoice) async {
    final db = await database;
    return await db.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  Future<int> deleteInvoice(int id) async {
    final db = await database;
    return await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  // Invoice Item operations
  Future<int> insertInvoiceItem(InvoiceItem item) async {
    final db = await database;
    return await db.insert('invoice_items', item.toMap());
  }

  Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoice_items',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId],
      orderBy: 'position ASC',
    );
    return List.generate(maps.length, (i) => InvoiceItem.fromMap(maps[i]));
  }

  Future<int> updateInvoiceItem(InvoiceItem item) async {
    final db = await database;
    return await db.update(
      'invoice_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteInvoiceItem(int id) async {
    final db = await database;
    return await db.delete('invoice_items', where: 'id = ?', whereArgs: [id]);
  }

  // Helper method to get next sequence number for quotations
  Future<int> getNextQuotationSequence() async {
    final db = await database;
    final today = DateTime.now();
    final todayString =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM quotations WHERE quotationNumber LIKE ?',
      ['QT-$todayString%'],
    );

    return (Sqflite.firstIntValue(result) ?? 0) + 1;
  }

  // Helper method to get next sequence number for invoices
  Future<int> getNextInvoiceSequence() async {
    final db = await database;
    final today = DateTime.now();
    final todayString =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM invoices WHERE invoiceNumber LIKE ?',
      ['INV-$todayString%'],
    );

    return (Sqflite.firstIntValue(result) ?? 0) + 1;
  }

  // Communication operations
  Future<int> insertCommunication(Communication communication) async {
    final db = await database;
    return await db.insert('communications', communication.toMap());
  }

  Future<List<Communication>> getCommunicationsForLead(int leadId) async {
    final db = await database;
    final maps = await db.query(
      'communications',
      where: 'leadId = ?',
      whereArgs: [leadId],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Communication.fromMap(maps[i]));
  }

  Future<List<Communication>> getAllCommunications({
    String? type,
    DateTime? since,
  }) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (type != null && since != null) {
      whereClause = 'type = ? AND timestamp >= ?';
      whereArgs = [type, since.millisecondsSinceEpoch];
    } else if (type != null) {
      whereClause = 'type = ?';
      whereArgs = [type];
    } else if (since != null) {
      whereClause = 'timestamp >= ?';
      whereArgs = [since.millisecondsSinceEpoch];
    }

    final maps = await db.query(
      'communications',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Communication.fromMap(maps[i]));
  }

  Future<int> updateCommunicationStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      'communications',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCommunication(int id) async {
    final db = await database;
    return await db.delete('communications', where: 'id = ?', whereArgs: [id]);
  }

  // Get recent communications count for dashboard
  Future<int> getRecentCommunicationsCount({Duration? since}) async {
    final db = await database;
    final sinceTime = since ?? const Duration(days: 7);
    final timestamp = DateTime.now().subtract(sinceTime).millisecondsSinceEpoch;

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM communications WHERE timestamp >= ?',
      [timestamp],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
