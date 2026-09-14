import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/BusinessProfile.dart';
import '../models/UserModel.dart';

/// Local persistence for the business profile, cached users, and small app
/// settings (currency/language/printer prefs/etc). Backed by sqflite, which
/// has no implementation on Flutter Web — every public method below
/// short-circuits when `kIsWeb` instead of throwing "databaseFactory not
/// initialized" the moment anything touches `database`. Settings fall back
/// to an in-memory map (works for the session, lost on page reload); profile
/// and user lookups return null/no-op since Firestore is already the source
/// of truth for those via ProfileService's cloud fallback and AuthService's
/// Firestore sync.
class LocalDbService {
  LocalDbService._();
  static final LocalDbService instance = LocalDbService._();

  static const _dbName       = 'fast_billing.db';
  static const _dbVersion    = 3;          // ← bumped 1 → 2 → 3
  static const _userTable    = 'users';
  static const _profileTable = 'profiles';
  static const _settingsTable = 'settings'; // ← new

  Database? _db;
  final Map<String, String> _webSettings = {};

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,   // ← was defined but never wired in before
    );
  }

  // ── Schema creation (fresh install) ──────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_userTable (
        uid TEXT PRIMARY KEY, email TEXT, display_name TEXT,
        photo_url TEXT, provider TEXT, last_login_at INTEGER
      )
    ''');
    await _createProfileTable(db);
    await _createSettingsTable(db);   // ← new
  }

  // ── Migrations (existing installs) ───────────────────────────────────────

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) await _createSettingsTable(db);
    if (oldV < 3) {
      for (final col in ['state', 'bank_name', 'bank_account_no', 'bank_ifsc']) {
        await db.execute('ALTER TABLE $_profileTable ADD COLUMN $col TEXT');
      }
    }
  }

  // ── Table helpers ─────────────────────────────────────────────────────────

  Future<void> _createProfileTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_profileTable (
        uid TEXT PRIMARY KEY,
        name TEXT, address TEXT, gst_number TEXT, state TEXT, currency TEXT,
        logo_path TEXT, logo_url TEXT,
        bank_name TEXT, bank_account_no TEXT, bank_ifsc TEXT,
        updated_at INTEGER
      )
    ''');
  }

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_settingsTable (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ── Settings CRUD ─────────────────────────────────────────────────────────

  /// Read a setting by key. Returns null if the key has never been written.
  Future<String?> getSetting(String key) async {
    if (kIsWeb) return _webSettings[key];
    final db = await database;
    final rows = await db.query(
      _settingsTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  /// Write (insert or overwrite) a setting.
  Future<void> saveSetting(String key, String value) async {
    if (kIsWeb) {
      _webSettings[key] = value;
      return;
    }
    final db = await database;
    await db.insert(
      _settingsTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Remove a setting (e.g. on logout / reset).
  Future<void> deleteSetting(String key) async {
    if (kIsWeb) {
      _webSettings.remove(key);
      return;
    }
    final db = await database;
    await db.delete(_settingsTable, where: 'key = ?', whereArgs: [key]);
  }

  // ── Profile CRUD ──────────────────────────────────────────────────────────

  Future<void> saveProfile(BusinessProfile p) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(_profileTable, p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<BusinessProfile?> getProfile(String uid) async {
    if (kIsWeb) return null;
    final db = await database;
    final rows = await db.query(_profileTable,
        where: 'uid = ?', whereArgs: [uid], limit: 1);
    return rows.isEmpty ? null : BusinessProfile.fromMap(rows.first);
  }

  // ── User CRUD ─────────────────────────────────────────────────────────────

  Future<void> saveUser(UserModel user) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(_userTable, user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UserModel?> getUser(String uid) async {
    if (kIsWeb) return null;
    final db = await database;
    final rows = await db.query(_userTable,
        where: 'uid = ?', whereArgs: [uid], limit: 1);
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  Future<UserModel?> getCurrentUser() async {
    if (kIsWeb) return null;
    final db = await database;
    final rows =
    await db.query(_userTable, orderBy: 'last_login_at DESC', limit: 1);
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  Future<void> deleteUser(String uid) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(_userTable, where: 'uid = ?', whereArgs: [uid]);
  }

  Future<void> clearUsers() async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(_userTable);
  }
}
