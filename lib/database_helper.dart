import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _databaseName = "grammar.sqlite3";

  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_databaseName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Check if the database exists in the device's file system
    final exists = await databaseExists(path);

    if (!exists) {
      // Make sure the parent directory exists
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      ByteData data = await rootBundle.load(join("assets", filePath));
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      // Write and flush the bytes written
      await File(path).writeAsBytes(bytes, flush: true);
    }

    // Open the database and create Favorites table if not exists
    final db = await openDatabase(path);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Favorites (
        id TEXT PRIMARY KEY
      )
    ''');
    return db;
  }

  // Example query method
  Future<List<Map<String, dynamic>>> searchGrammar(
    String keyword, {
    List<String>? levels,
  }) async {
    final db = await instance.database;
    String whereClause = '(showkey LIKE ? OR tag LIKE ?)';
    List<dynamic> whereArgs = ['%$keyword%', '%$keyword%'];

    if (levels != null && levels.isNotEmpty) {
      whereClause +=
          ' AND level IN (${List.filled(levels.length, '?').join(', ')})';
      whereArgs.addAll(levels);
    }

    return await db.query(
      'GrammarTable',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'level DESC',
    );
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    final db = await instance.database;
    if (isFavorite) {
      await db.insert('Favorites', {'id': id}, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('Favorites', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<bool> isFavorite(String id) async {
    final db = await instance.database;
    final results = await db.query('Favorites', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty;
  }

  Future<List<String>> getAllFavoriteIds() async {
    final db = await instance.database;
    final results = await db.query('Favorites', columns: ['id']);
    return results.map((e) => e['id'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT g.* 
      FROM GrammarTable g
      INNER JOIN Favorites f ON g.id = f.id
      ORDER BY g.level DESC
    ''');
  }
}
