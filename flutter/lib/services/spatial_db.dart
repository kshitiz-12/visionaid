import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'intent_service.dart';

/// Thrown when the spatial SQLite layer fails.
class SpatialDbException implements Exception {
  const SpatialDbException(this.message, {this.code = 'SPATIAL_DB'});

  final String message;
  final String code;

  @override
  String toString() => 'SpatialDbException($code): $message';
}

class SpatialDbConfigException extends SpatialDbException {
  const SpatialDbConfigException(super.message)
      : super(code: 'SPATIAL_DB_CONFIG');
}

class SpatialDbOpenException extends SpatialDbException {
  const SpatialDbOpenException(super.message)
      : super(code: 'SPATIAL_DB_OPEN');
}

class SpatialDbQueryException extends SpatialDbException {
  const SpatialDbQueryException(super.message)
      : super(code: 'SPATIAL_DB_QUERY');
}

class SpatialDbNotFoundException extends SpatialDbException {
  const SpatialDbNotFoundException(super.message)
      : super(code: 'SPATIAL_DB_NOT_FOUND');
}

/// Row in `nodes`.
class SpatialNode {
  const SpatialNode({
    required this.id,
    required this.label,
    required this.type,
  });

  final String id;
  final String label;
  final String type;

  RoomNodeRef toRoomNodeRef() => RoomNodeRef(id: id, label: label, type: type);

  Map<String, Object?> toMap() => {
        'id': id,
        'label': label,
        'type': type,
      };

  factory SpatialNode.fromMap(Map<String, Object?> map) {
    final id = map['id'];
    final label = map['label'];
    final type = map['type'];
    if (id is! String || id.trim().isEmpty) {
      throw const SpatialDbQueryException(
        'nodes.id must be a non-empty string.',
      );
    }
    if (label is! String || label.trim().isEmpty) {
      throw const SpatialDbQueryException(
        'nodes.label must be a non-empty string.',
      );
    }
    if (type is! String || type.trim().isEmpty) {
      throw const SpatialDbQueryException(
        'nodes.type must be a non-empty string.',
      );
    }
    return SpatialNode(id: id.trim(), label: label.trim(), type: type.trim());
  }
}

/// Row in `edges` (directed walk segment between nodes).
class SpatialEdge {
  const SpatialEdge({
    required this.fromNode,
    required this.toNode,
    required this.distanceMeters,
    required this.headingDegrees,
    required this.stepCount,
  });

  final String fromNode;
  final String toNode;
  final double distanceMeters;
  final double headingDegrees;
  final int stepCount;

  Map<String, Object?> toMap() => {
        'from_node': fromNode,
        'to_node': toNode,
        'distance_meters': distanceMeters,
        'heading_degrees': headingDegrees,
        'step_count': stepCount,
      };

  factory SpatialEdge.fromMap(Map<String, Object?> map) {
    final from = map['from_node'];
    final to = map['to_node'];
    final distance = map['distance_meters'];
    final heading = map['heading_degrees'];
    final steps = map['step_count'];
    if (from is! String || from.trim().isEmpty) {
      throw const SpatialDbQueryException(
        'edges.from_node must be a non-empty string.',
      );
    }
    if (to is! String || to.trim().isEmpty) {
      throw const SpatialDbQueryException(
        'edges.to_node must be a non-empty string.',
      );
    }
    if (distance is! num) {
      throw const SpatialDbQueryException(
        'edges.distance_meters must be numeric.',
      );
    }
    if (heading is! num) {
      throw const SpatialDbQueryException(
        'edges.heading_degrees must be numeric.',
      );
    }
    if (steps is! num) {
      throw const SpatialDbQueryException('edges.step_count must be numeric.');
    }
    return SpatialEdge(
      fromNode: from.trim(),
      toNode: to.trim(),
      distanceMeters: distance.toDouble(),
      headingDegrees: heading.toDouble(),
      stepCount: steps.round(),
    );
  }
}

/// One historical sighting row in `object_memory`.
class ObjectMemoryRecord {
  const ObjectMemoryRecord({
    required this.objectLabel,
    required this.associatedNode,
    required this.timestamp,
    this.id,
    this.relativeVectorX,
    this.relativeVectorY,
    this.depthZ,
  });

  final int? id;
  final String objectLabel;
  final String associatedNode;
  final double? relativeVectorX;
  final double? relativeVectorY;
  final double? depthZ;
  final DateTime timestamp;

  Map<String, Object?> toInsertMap() => {
        'object_label': objectLabel,
        'associated_node': associatedNode,
        'relative_vector_x': relativeVectorX,
        'relative_vector_y': relativeVectorY,
        'depth_z': depthZ,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory ObjectMemoryRecord.fromMap(Map<String, Object?> map) {
    final id = map['id'];
    final label = map['object_label'];
    final node = map['associated_node'];
    final x = map['relative_vector_x'];
    final y = map['relative_vector_y'];
    final z = map['depth_z'];
    final ts = map['timestamp'];
    if (label is! String || label.trim().isEmpty) {
      throw const SpatialDbQueryException(
        'object_memory.object_label must be a non-empty string.',
      );
    }
    if (node is! String || node.trim().isEmpty) {
      throw const SpatialDbQueryException(
        'object_memory.associated_node must be a non-empty string.',
      );
    }
    if (x != null && x is! num) {
      throw const SpatialDbQueryException(
        'object_memory.relative_vector_x must be numeric or null.',
      );
    }
    if (y != null && y is! num) {
      throw const SpatialDbQueryException(
        'object_memory.relative_vector_y must be numeric or null.',
      );
    }
    if (z != null && z is! num) {
      throw const SpatialDbQueryException(
        'object_memory.depth_z must be numeric or null.',
      );
    }
    if (ts is! String || ts.trim().isEmpty) {
      throw const SpatialDbQueryException(
        'object_memory.timestamp must be a non-empty ISO-8601 string.',
      );
    }
    final parsed = DateTime.tryParse(ts);
    if (parsed == null) {
      throw SpatialDbQueryException(
        'object_memory.timestamp is not valid ISO-8601: $ts',
      );
    }
    if (id != null && id is! num) {
      throw const SpatialDbQueryException(
        'object_memory.id must be numeric when present.',
      );
    }
    return ObjectMemoryRecord(
      id: id == null ? null : (id as num).toInt(),
      objectLabel: label.trim(),
      associatedNode: node.trim(),
      relativeVectorX: x == null ? null : (x as num).toDouble(),
      relativeVectorY: y == null ? null : (y as num).toDouble(),
      depthZ: z == null ? null : (z as num).toDouble(),
      timestamp: parsed.toUtc(),
    );
  }
}

/// SQLite spatial graph + object memory store.
///
/// Schema (v2):
/// - `nodes(id, label, type)`
/// - `edges(from_node, to_node, distance_meters, heading_degrees, step_count)`
/// - `object_memory` append-only history (`id` AUTOINCREMENT)
class SpatialDb {
  SpatialDb({
    DatabaseFactory? databaseFactory,
    String? databaseFileName,
  })  : _databaseFactory = databaseFactory ?? databaseFactorySqflitePlugin,
        _databaseFileName = databaseFileName ?? 'visionaid_spatial.db';

  final DatabaseFactory _databaseFactory;
  final String _databaseFileName;
  Database? _db;

  static const schemaVersion = 2;

  bool get isOpen => _db != null && _db!.isOpen;

  /// Opens (or creates) the DB and applies migrations. Idempotent.
  Future<void> open() async {
    if (isOpen) {
      return;
    }
    try {
      final dir = await getDatabasesPath();
      if (dir.trim().isEmpty) {
        throw const SpatialDbOpenException(
          'sqflite getDatabasesPath() returned an empty path.',
        );
      }
      final path = p.join(dir, _databaseFileName);
      _db = await _databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, version) async {
            await _createSchema(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            await _upgradeSchema(db, oldVersion, newVersion);
          },
        ),
      );
    } on SpatialDbException {
      rethrow;
    } catch (error, stack) {
      throw SpatialDbOpenException(
        'Failed to open spatial database "$_databaseFileName": $error\n$stack',
      );
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) {
      return;
    }
    try {
      await db.close();
    } catch (error, stack) {
      throw SpatialDbOpenException(
        'Failed to close spatial database: $error\n$stack',
      );
    } finally {
      _db = null;
    }
  }

  Database _requireDb() {
    final db = _db;
    if (db == null || !db.isOpen) {
      throw const SpatialDbConfigException(
        'SpatialDb is not open. Call SpatialDb.open() before queries.',
      );
    }
    return db;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE nodes (
  id TEXT PRIMARY KEY NOT NULL,
  label TEXT NOT NULL,
  type TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE edges (
  from_node TEXT NOT NULL,
  to_node TEXT NOT NULL,
  distance_meters REAL NOT NULL,
  heading_degrees REAL NOT NULL,
  step_count INTEGER NOT NULL,
  PRIMARY KEY (from_node, to_node),
  FOREIGN KEY (from_node) REFERENCES nodes(id) ON DELETE CASCADE,
  FOREIGN KEY (to_node) REFERENCES nodes(id) ON DELETE CASCADE
)
''');
    await _createObjectMemoryV2(db);
  }

  Future<void> _createObjectMemoryV2(Database db) async {
    await db.execute('''
CREATE TABLE object_memory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  object_label TEXT NOT NULL,
  associated_node TEXT NOT NULL,
  relative_vector_x REAL,
  relative_vector_y REAL,
  depth_z REAL,
  timestamp TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  FOREIGN KEY (associated_node) REFERENCES nodes(id) ON DELETE CASCADE
)
''');
    await db.execute(
      'CREATE INDEX idx_object_memory_label_time '
      'ON object_memory(object_label, timestamp DESC)',
    );
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await db.execute('ALTER TABLE object_memory RENAME TO object_memory_v1');
      await _createObjectMemoryV2(db);
      await db.execute('''
INSERT INTO object_memory (
  object_label, associated_node, relative_vector_x, relative_vector_y,
  depth_z, timestamp
)
SELECT
  object_label, associated_node, relative_vector_x, NULL, depth_z, timestamp
FROM object_memory_v1
''');
      await db.execute('DROP TABLE object_memory_v1');
      return;
    }
    throw SpatialDbConfigException(
      'Unsupported spatial DB upgrade $oldVersion → $newVersion. '
      'Add an explicit migration in SpatialDb._upgradeSchema.',
    );
  }

  /// Inserts or replaces a node.
  Future<void> upsertNode(SpatialNode node) async {
    final id = node.id.trim();
    final label = node.label.trim();
    final type = node.type.trim();
    if (id.isEmpty || label.isEmpty || type.isEmpty) {
      throw const SpatialDbQueryException(
        'upsertNode requires non-empty id, label, and type.',
      );
    }
    final db = _requireDb();
    try {
      await db.insert(
        'nodes',
        SpatialNode(id: id, label: label, type: type).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (error, stack) {
      throw SpatialDbQueryException(
        'Failed to upsert node "$id": $error\n$stack',
      );
    }
  }

  Future<List<SpatialNode>> listNodes() async {
    final db = _requireDb();
    try {
      final rows = await db.query('nodes', orderBy: 'label COLLATE NOCASE ASC');
      return rows.map(SpatialNode.fromMap).toList();
    } catch (error, stack) {
      throw SpatialDbQueryException(
        'Failed to list nodes: $error\n$stack',
      );
    }
  }

  /// Catalog loader compatible with [IntentService].
  Future<List<RoomNodeRef>> loadRoomNodes() async {
    final nodes = await listNodes();
    return nodes.map((n) => n.toRoomNodeRef()).toList();
  }

  Future<SpatialNode?> getNode(String id) async {
    final key = id.trim();
    if (key.isEmpty) {
      throw const SpatialDbQueryException('getNode requires a non-empty id.');
    }
    final db = _requireDb();
    try {
      final rows = await db.query(
        'nodes',
        where: 'id = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return SpatialNode.fromMap(rows.first);
    } catch (error, stack) {
      throw SpatialDbQueryException(
        'Failed to get node "$key": $error\n$stack',
      );
    }
  }

  /// Inserts or replaces a directed edge. Both endpoints must already exist.
  Future<void> upsertEdge(SpatialEdge edge) async {
    final from = edge.fromNode.trim();
    final to = edge.toNode.trim();
    if (from.isEmpty || to.isEmpty) {
      throw const SpatialDbQueryException(
        'upsertEdge requires non-empty from_node and to_node.',
      );
    }
    if (from == to) {
      throw const SpatialDbQueryException(
        'upsertEdge refuses self-loop edges (from_node == to_node).',
      );
    }
    if (edge.stepCount < 0) {
      throw const SpatialDbQueryException(
        'upsertEdge step_count must be >= 0.',
      );
    }
    if (edge.distanceMeters < 0) {
      throw const SpatialDbQueryException(
        'upsertEdge distance_meters must be >= 0.',
      );
    }

    final db = _requireDb();
    final fromNode = await getNode(from);
    final toNode = await getNode(to);
    if (fromNode == null) {
      throw SpatialDbNotFoundException(
        'Cannot upsert edge: from_node "$from" does not exist in nodes.',
      );
    }
    if (toNode == null) {
      throw SpatialDbNotFoundException(
        'Cannot upsert edge: to_node "$to" does not exist in nodes.',
      );
    }

    try {
      await db.insert(
        'edges',
        SpatialEdge(
          fromNode: from,
          toNode: to,
          distanceMeters: edge.distanceMeters,
          headingDegrees: edge.headingDegrees,
          stepCount: edge.stepCount,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (error, stack) {
      throw SpatialDbQueryException(
        'Failed to upsert edge $from → $to: $error\n$stack',
      );
    }
  }

  Future<List<SpatialEdge>> listEdges({String? fromNode}) async {
    final db = _requireDb();
    try {
      final rows = fromNode == null || fromNode.trim().isEmpty
          ? await db.query('edges', orderBy: 'from_node, to_node')
          : await db.query(
              'edges',
              where: 'from_node = ?',
              whereArgs: [fromNode.trim()],
              orderBy: 'to_node',
            );
      return rows.map(SpatialEdge.fromMap).toList();
    } catch (error, stack) {
      throw SpatialDbQueryException(
        'Failed to list edges: $error\n$stack',
      );
    }
  }

  /// Appends a historical sighting (never overwrites prior rows).
  Future<int> insertObjectMemory(ObjectMemoryRecord record) async {
    final label = record.objectLabel.trim().toLowerCase();
    final node = record.associatedNode.trim();
    if (label.isEmpty) {
      throw const SpatialDbQueryException(
        'insertObjectMemory requires a non-empty object_label.',
      );
    }
    if (node.isEmpty) {
      throw const SpatialDbQueryException(
        'insertObjectMemory requires a non-empty associated_node.',
      );
    }
    final existing = await getNode(node);
    if (existing == null) {
      throw SpatialDbNotFoundException(
        'Cannot insert object_memory: associated_node "$node" does not exist.',
      );
    }
    final db = _requireDb();
    try {
      final id = await db.insert(
        'object_memory',
        ObjectMemoryRecord(
          objectLabel: label,
          associatedNode: node,
          relativeVectorX: record.relativeVectorX,
          relativeVectorY: record.relativeVectorY,
          depthZ: record.depthZ,
          timestamp: record.timestamp.toUtc(),
        ).toInsertMap(),
      );
      return id;
    } catch (error, stack) {
      throw SpatialDbQueryException(
        'Failed to insert object_memory "$label": $error\n$stack',
      );
    }
  }

  /// Most recent historical row for [objectLabel] (exact normalized label).
  Future<ObjectMemoryRecord?> locateLastSeen(String objectLabel) async {
    final label = objectLabel.trim().toLowerCase();
    if (label.isEmpty) {
      throw const SpatialDbQueryException(
        'locateLastSeen requires a non-empty object_label.',
      );
    }
    final db = _requireDb();
    try {
      final rows = await db.query(
        'object_memory',
        where: 'object_label = ?',
        whereArgs: [label],
        orderBy: 'timestamp DESC, id DESC',
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return ObjectMemoryRecord.fromMap(rows.first);
    } catch (error, stack) {
      throw SpatialDbQueryException(
        'Failed to locateLastSeen("$label"): $error\n$stack',
      );
    }
  }

  /// Most recent row whose label equals or contains [objectQuery].
  Future<ObjectMemoryRecord?> locateLastSeenByQuery(String objectQuery) async {
    final query = objectQuery.trim().toLowerCase();
    if (query.isEmpty) {
      throw const SpatialDbQueryException(
        'locateLastSeenByQuery requires a non-empty objectQuery.',
      );
    }
    final exact = await locateLastSeen(query);
    if (exact != null) {
      return exact;
    }
    final db = _requireDb();
    try {
      final rows = await db.query(
        'object_memory',
        where: 'object_label LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'timestamp DESC, id DESC',
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return ObjectMemoryRecord.fromMap(rows.first);
    } catch (error, stack) {
      throw SpatialDbQueryException(
        'Failed to locateLastSeenByQuery("$query"): $error\n$stack',
      );
    }
  }

  /// Newest row matching any label in [labels] (synonym-aware recall).
  Future<ObjectMemoryRecord?> locateLastSeenByAnyLabel(List<String> labels) async {
    final normalized = {
      for (final label in labels)
        if (label.trim().isNotEmpty) label.trim().toLowerCase(),
    };
    if (normalized.isEmpty) {
      throw const SpatialDbQueryException(
        'locateLastSeenByAnyLabel requires at least one label.',
      );
    }
    ObjectMemoryRecord? newest;
    for (final label in normalized) {
      final hit = await locateLastSeenByQuery(label);
      if (hit == null) {
        continue;
      }
      if (newest == null || hit.timestamp.isAfter(newest.timestamp)) {
        newest = hit;
      }
    }
    return newest;
  }

  /// Resolves a spoken place phrase to a node id (exact id, then label match).
  Future<SpatialNode?> resolveNode(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      throw const SpatialDbQueryException(
        'resolveNode requires a non-empty query.',
      );
    }
    final byId = await getNode(q);
    if (byId != null) {
      return byId;
    }
    final nodes = await listNodes();
    for (final node in nodes) {
      if (node.id.toLowerCase() == q || node.label.toLowerCase() == q) {
        return node;
      }
    }
    for (final node in nodes) {
      final label = node.label.toLowerCase();
      if (label.contains(q) || q.contains(label)) {
        return node;
      }
    }
    return null;
  }

  /// Dijkstra shortest path by `distance_meters`. Returns null if unreachable.
  Future<List<SpatialEdge>?> findShortestPath({
    required String fromNodeId,
    required String toNodeId,
  }) async {
    final from = fromNodeId.trim();
    final to = toNodeId.trim();
    if (from.isEmpty || to.isEmpty) {
      throw const SpatialDbQueryException(
        'findShortestPath requires non-empty fromNodeId and toNodeId.',
      );
    }
    if (from == to) {
      return const <SpatialEdge>[];
    }
    final fromNode = await getNode(from);
    final toNode = await getNode(to);
    if (fromNode == null) {
      throw SpatialDbNotFoundException(
        'findShortestPath: from node "$from" does not exist.',
      );
    }
    if (toNode == null) {
      throw SpatialDbNotFoundException(
        'findShortestPath: to node "$to" does not exist.',
      );
    }

    final edges = await listEdges();
    final adjacency = <String, List<SpatialEdge>>{};
    for (final edge in edges) {
      adjacency.putIfAbsent(edge.fromNode, () => []).add(edge);
    }

    final dist = <String, double>{from: 0};
    final prev = <String, SpatialEdge>{};
    final visited = <String>{};
    final queue = <String>{from};

    while (queue.isNotEmpty) {
      String? current;
      var best = double.infinity;
      for (final candidate in queue) {
        final d = dist[candidate] ?? double.infinity;
        if (d < best) {
          best = d;
          current = candidate;
        }
      }
      if (current == null) {
        break;
      }
      queue.remove(current);
      if (current == to) {
        break;
      }
      if (!visited.add(current)) {
        continue;
      }
      final outbound = adjacency[current] ?? const <SpatialEdge>[];
      for (final edge in outbound) {
        final next = edge.toNode;
        final tentative = best + edge.distanceMeters;
        final known = dist[next];
        if (known == null || tentative < known) {
          dist[next] = tentative;
          prev[next] = edge;
          queue.add(next);
        }
      }
    }

    if (!prev.containsKey(to) && from != to) {
      return null;
    }

    final path = <SpatialEdge>[];
    var cursor = to;
    while (cursor != from) {
      final edge = prev[cursor];
      if (edge == null) {
        return null;
      }
      path.add(edge);
      cursor = edge.fromNode;
    }
    return path.reversed.toList();
  }
}
