import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local vault of issued identity records.
///
/// Every issued card is persisted with its payload so a scanned ID can be
/// resolved against the issuing device and never duplicated.
class IdRecordStore {
  IdRecordStore._(this._database);

  static const String table = 'issued_ids';
  final Database _database;

  static Future<IdRecordStore> open() async {
    final directory = await getDatabasesPath();
    final database = await openDatabase(
      p.join(directory, 'a_digital_id.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            photo_path TEXT,
            issued_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return IdRecordStore._(database);
  }

  Future<void> insert({
    required String id,
    required String payload,
    String? photoPath,
    required DateTime issuedAt,
  }) async {
    await _database.insert(
      table,
      {
        'id': id,
        'payload': payload,
        'photo_path': photoPath,
        'issued_at': issuedAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> findById(String id) async {
    final rows = await _database.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return {
      'id': row['id'],
      'payload': jsonDecode(row['payload'] as String),
      'photo_path': row['photo_path'],
      'issued_at': DateTime.fromMillisecondsSinceEpoch(
        row['issued_at'] as int,
      ),
    };
  }

  Future<void> close() => _database.close();
}
