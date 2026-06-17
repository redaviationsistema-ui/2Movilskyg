import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LocalCacheService {
  static const _dbName = 'reservation_cache.db';
  static const _dbVersion = 2;

  static const airportsTable = 'airports';
  static const aircraftTable = 'aircraft_fleet';
  static const reservationsTable = 'reservations_cache';
  static const metadataTable = 'cache_metadata';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, _dbName);

    return openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $airportsTable (
            name TEXT PRIMARY KEY,
            city TEXT,
            state TEXT,
            lat REAL,
            lng REAL,
            iata TEXT,
            country TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE $aircraftTable (
            id TEXT PRIMARY KEY,
            name TEXT,
            aircraft_type TEXT,
            capacity_passengers INTEGER,
            rental_price_usd REAL,
            cruise_speed_knots REAL,
            national_expenses_usd REAL,
            international_expenses_usd REAL,
            home_base TEXT,
            city TEXT,
            crew_overnight_usd REAL,
            minimum_hours REAL,
            image_url TEXT,
            is_active INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE $reservationsTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            aircraft_id TEXT,
            start_datetime TEXT,
            end_datetime TEXT,
            status TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE $metadataTable (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _ensureAircraftImageUrlColumn(db);
        }
      },
      onOpen: (db) async {
        await _ensureAircraftImageUrlColumn(db);
      },
    );
  }

  Future<void> _ensureAircraftImageUrlColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($aircraftTable)');
    final hasImageUrl = columns.any((column) => column['name'] == 'image_url');

    if (!hasImageUrl) {
      await db.execute(
        'ALTER TABLE $aircraftTable ADD COLUMN image_url TEXT',
      );
    }
  }

  Future<void> cacheAirports(List<Map<String, dynamic>> airports) async {
    final db = await database;
    final batch = db.batch();

    batch.delete(airportsTable);

    for (final airport in airports) {
      batch.insert(
        airportsTable,
        airport,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> cacheAircraft(List<Map<String, dynamic>> aircraft) async {
    final db = await database;
    await _ensureAircraftImageUrlColumn(db);

    Future<void> writeBatch() async {
      final batch = db.batch();

      batch.delete(aircraftTable);

      for (final item in aircraft) {
        batch.insert(
          aircraftTable,
          item,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    }

    try {
      await writeBatch();
    } on DatabaseException catch (error) {
      if (error.toString().contains('no column named image_url')) {
        await _ensureAircraftImageUrlColumn(db);
        await writeBatch();
        return;
      }
      rethrow;
    }
  }

  Future<void> cacheReservations(
    List<Map<String, dynamic>> reservations,
  ) async {
    final db = await database;
    final batch = db.batch();

    batch.delete(reservationsTable);

    for (final item in reservations) {
      batch.insert(
        reservationsTable,
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedAirports() async {
    final db = await database;
    return db.query(airportsTable, orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> getCachedAircraft() async {
    final db = await database;
    return db.query(aircraftTable, orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> getCachedReservations() async {
    final db = await database;
    return db.query(reservationsTable, orderBy: 'start_datetime ASC');
  }

  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert(metadataTable, {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getMetadata(String key) async {
    final db = await database;
    final rows = await db.query(
      metadataTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }
}
