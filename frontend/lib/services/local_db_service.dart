import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class LocalDbService {
  static Database? _database;
  static const String _dbName = 'adisyon_offline.db';

  dynamic _pickFirst(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        return json[key];
      }
    }
    return null;
  }

  int _safeInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  double _safeDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return fallback;
    return double.tryParse(raw.replaceAll(',', '.')) ?? fallback;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Ürünleri saklamak için (Offline menü gösterimi)
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY,
            name TEXT,
            price REAL,
            category_id INTEGER,
            category_name TEXT
          )
        ''');

        // Masaları saklamak için
        await db.execute('''
          CREATE TABLE tables (
            id INTEGER PRIMARY KEY,
            display_name TEXT,
            zone TEXT,
            status TEXT
          )
        ''');

        // Senkronize edilmeyi bekleyen istekleri saklamak için (Sync Queue)
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            endpoint TEXT,
            method TEXT,
            body TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  // --- Products ---
  Future<void> saveProducts(List<dynamic> products) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('products');
      for (var p in products) {
        if (p is! Map) continue;
        final row = Map<String, dynamic>.from(p);

        final id = _safeInt(
          _pickFirst(row, const ['id', 'product_id', 'productId']),
        );
        if (id <= 0) continue;

        final name =
            (_pickFirst(row, const ['name', 'product_name', 'productName']) ??
                    '')
                .toString()
                .trim();
        if (name.isEmpty) continue;

        await txn.insert('products', {
          'id': id,
          'name': name,
          'price': _safeDouble(
            _pickFirst(row, const [
              'price',
              'unit_price',
              'unitPrice',
              'fiyat',
            ]),
          ),
          'category_id': _safeInt(
            _pickFirst(row, const ['category_id', 'categoryId']),
          ),
          'category_name':
              (_pickFirst(row, const [
                        'category_name',
                        'category',
                        'categoryName',
                        'kategori',
                      ]) ??
                      '')
                  .toString(),
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query('products');
  }

  // --- Tables ---
  Future<void> saveTables(List<dynamic> tables) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tables');
      for (var t in tables) {
        await txn.insert('tables', {
          'id': t['id'],
          'display_name': t['display_name'],
          'zone': t['zone'],
          'status': t['status'],
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getTables() async {
    final db = await database;
    return await db.query('tables');
  }

  // --- Sync Queue ---
  Future<void> addToQueue(
    String endpoint,
    String method,
    Map<String, dynamic>? body,
  ) async {
    final db = await database;
    await db.insert('sync_queue', {
      'endpoint': endpoint,
      'method': method,
      'body': body != null ? jsonEncode(body) : null,
    });
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'created_at ASC');
  }

  Future<void> removeFromQueue(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }
}
