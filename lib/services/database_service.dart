// lib/services/database_service.dart (updated)

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/lead_model.dart';
import '../models/call_history_model.dart';
import '../models/user_model.dart';
import '../models/label_model.dart';

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
      version: 7, // Incremented for labels table
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
            isVip INTEGER DEFAULT 0
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
}
