import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class GPSLocalDB {
  static final GPSLocalDB instance = GPSLocalDB._();

  static Database? _database;

  GPSLocalDB._();

  //----------------------------------------
  // INIT DATABASE
  //----------------------------------------

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB();

    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, "gps_tracking.db");

    return await openDatabase(path, version: 1, onCreate: _createTables);
  }

  //----------------------------------------
  // CREATE TABLE
  //----------------------------------------

  Future<void> _createTables(Database db, int version) async {
    await db.execute("""

    CREATE TABLE gps_points (

      id INTEGER PRIMARY KEY AUTOINCREMENT,

      latitude REAL NOT NULL,

      longitude REAL NOT NULL,

      accuracy REAL,

      speed REAL,

      heading REAL,

      timestamp TEXT NOT NULL,

      is_synced INTEGER DEFAULT 0

    )

    """);

    //------------------------------------
    // Index for fast queries
    //------------------------------------

    await db.execute("""
    CREATE INDEX idx_synced
    ON gps_points (is_synced)
    """);

    await db.execute("""
    CREATE INDEX idx_timestamp
    ON gps_points (timestamp)
    """);
  }

  //----------------------------------------
  // INSERT GPS POINT
  //----------------------------------------

  Future<int> insertPoint({
    required double latitude,
    required double longitude,
    required double accuracy,
    required double speed,
    required double heading,
  }) async {
    final db = await database;

    return await db.insert("gps_points", {
      "latitude": latitude,
      "longitude": longitude,
      "accuracy": accuracy,
      "speed": speed,
      "heading": heading,
      "timestamp": DateTime.now().toIso8601String(),
      "is_synced": 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  //----------------------------------------
  // GET UNSYNCED POINTS
  //----------------------------------------

  Future<List<Map<String, dynamic>>> getUnsyncedPoints({
    int limit = 100,
  }) async {
    final db = await database;

    return await db.query(
      "gps_points",

      where: "is_synced = 0",

      limit: limit,

      orderBy: "id ASC",
    );
  }

  //----------------------------------------
  // MARK POINTS AS SYNCED
  //----------------------------------------

  Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;

    final db = await database;

    final idsString = ids.join(",");

    await db.rawUpdate("""

      UPDATE gps_points

      SET is_synced = 1

      WHERE id IN ($idsString)

    """);
  }

  //----------------------------------------
  // GET ALL POINTS FOR TRIP
  //----------------------------------------

  Future<List<Map<String, dynamic>>> getAllPoints() async {
    final db = await database;

    return await db.query("gps_points", orderBy: "id ASC");
  }

  //----------------------------------------
  // CLEAR SYNCED POINTS (cleanup)
  //----------------------------------------

  Future<void> clearSynced() async {
    final db = await database;

    await db.delete("gps_points", where: "is_synced = 1");
  }

  //----------------------------------------
  // DELETE ALL (trip reset)
  //----------------------------------------

  Future<void> clearAll() async {
    final db = await database;

    await db.delete("gps_points");
  }
}
