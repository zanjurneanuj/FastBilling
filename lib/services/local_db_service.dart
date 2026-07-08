import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/BusinessProfile.dart';
import '../models/UserModel.dart';

class LocalDbService {
  LocalDbService._();
  static final LocalDbService instance = LocalDbService._();

  static const _dbName       = 'fast_billing.db';
  static const _dbVersion    = 2;          // ← bumped from 1 → 2
  static const _userTable    = 'users';
  static const _profileTable = 'profiles';
  static const _settingsTable = 'settings'; // ← new

  Database? _db;

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
  }

  // ── Table helpers ─────────────────────────────────────────────────────────

  Future<void> _createProfileTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_profileTable (
        uid TEXT PRIMARY KEY,
        name TEXT, address TEXT, gst_number TEXT, currency TEXT,
        logo_path TEXT, logo_url TEXT, updated_at INTEGER
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
    final db = await database;
    await db.insert(
      _settingsTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Remove a setting (e.g. on logout / reset).
  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete(_settingsTable, where: 'key = ?', whereArgs: [key]);
  }

  // ── Profile CRUD ──────────────────────────────────────────────────────────

  Future<void> saveProfile(BusinessProfile p) async {
    final db = await database;
    await db.insert(_profileTable, p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<BusinessProfile?> getProfile(String uid) async {
    final db = await database;
    final rows = await db.query(_profileTable,
        where: 'uid = ?', whereArgs: [uid], limit: 1);
    return rows.isEmpty ? null : BusinessProfile.fromMap(rows.first);
  }

  // ── User CRUD ─────────────────────────────────────────────────────────────

  Future<void> saveUser(UserModel user) async {
    final db = await database;
    await db.insert(_userTable, user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UserModel?> getUser(String uid) async {
    final db = await database;
    final rows = await db.query(_userTable,
        where: 'uid = ?', whereArgs: [uid], limit: 1);
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  Future<UserModel?> getCurrentUser() async {
    final db = await database;
    final rows =
    await db.query(_userTable, orderBy: 'last_login_at DESC', limit: 1);
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  Future<void> deleteUser(String uid) async {
    final db = await database;
    await db.delete(_userTable, where: 'uid = ?', whereArgs: [uid]);
  }

  Future<void> clearUsers() async {
    final db = await database;
    await db.delete(_userTable);
  }
}