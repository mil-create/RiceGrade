import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'api_service.dart';

/// One saved analysis. Image files live in the app documents directory.
class HistoryEntry {
  final int id;
  final DateTime createdAt;
  final String imagePath;
  final String annotatedPath;
  final int wholeCount;
  final int brokenCount;
  final double brokenPercent;
  final double avgLengthBreadthRatio;
  final String grade;
  final String? label;

  const HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.imagePath,
    required this.annotatedPath,
    required this.wholeCount,
    required this.brokenCount,
    required this.brokenPercent,
    required this.avgLengthBreadthRatio,
    required this.grade,
    this.label,
  });

  factory HistoryEntry.fromRow(Map<String, Object?> row) => HistoryEntry(
        id: row['id'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        imagePath: row['image_path'] as String,
        annotatedPath: row['annotated_path'] as String,
        wholeCount: row['whole_count'] as int,
        brokenCount: row['broken_count'] as int,
        brokenPercent: (row['broken_percent'] as num).toDouble(),
        avgLengthBreadthRatio:
            (row['avg_length_breadth_ratio'] as num).toDouble(),
        grade: row['grade'] as String,
        label: row['label'] as String?,
      );

  HistoryEntry withLabel(String? label) => HistoryEntry(
        id: id,
        createdAt: createdAt,
        imagePath: imagePath,
        annotatedPath: annotatedPath,
        wholeCount: wholeCount,
        brokenCount: brokenCount,
        brokenPercent: brokenPercent,
        avgLengthBreadthRatio: avgLengthBreadthRatio,
        grade: grade,
        label: label,
      );

  /// Same shape as [AnalysisResult.toJson] minus the image.
  Map<String, dynamic> toResultsJson() => {
        'whole_count': wholeCount,
        'broken_count': brokenCount,
        'broken_percent': brokenPercent,
        'avg_length_breadth_ratio': avgLengthBreadthRatio,
        'grade': grade,
      };
}

/// Stores every analysis locally (SQLite + image files), so history works offline.
class HistoryRepository {
  static const _table = 'history';

  Database? _db;
  Directory? _imagesDir;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    _imagesDir = await Directory(p.join(dir.path, 'history')).create();
    _db = await openDatabase(
      p.join(dir.path, 'ricegrade.db'),
      version: 2,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          image_path TEXT NOT NULL,
          annotated_path TEXT NOT NULL,
          whole_count INTEGER NOT NULL,
          broken_count INTEGER NOT NULL,
          broken_percent REAL NOT NULL,
          avg_length_breadth_ratio REAL NOT NULL,
          grade TEXT NOT NULL,
          label TEXT
        )
      '''),
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_table ADD COLUMN label TEXT');
        }
      },
    );
    return _db!;
  }

  Future<List<HistoryEntry>> list() async {
    final db = await _open();
    final rows = await db.query(_table, orderBy: 'created_at DESC');
    return rows.map(HistoryEntry.fromRow).toList();
  }

  Future<HistoryEntry?> get(int id) async {
    final db = await _open();
    final rows =
        await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : HistoryEntry.fromRow(rows.first);
  }

  /// Copies the source photo (picker files can be temporary) and writes the annotated PNG.
  Future<HistoryEntry> add(
      String sourceImagePath, AnalysisResult result) async {
    final db = await _open();
    final now = DateTime.now();
    final stem = now.millisecondsSinceEpoch.toString();
    final ext = p.extension(sourceImagePath).isEmpty
        ? '.jpg'
        : p.extension(sourceImagePath);

    final imagePath = p.join(_imagesDir!.path, '${stem}_original$ext');
    final annotatedPath = p.join(_imagesDir!.path, '${stem}_annotated.png');
    await File(sourceImagePath).copy(imagePath);
    await File(annotatedPath)
        .writeAsBytes(base64Decode(result.annotatedImageBase64));

    final row = <String, Object?>{
      'created_at': now.millisecondsSinceEpoch,
      'image_path': imagePath,
      'annotated_path': annotatedPath,
      'whole_count': result.wholeCount,
      'broken_count': result.brokenCount,
      'broken_percent': result.brokenPercent,
      'avg_length_breadth_ratio': result.avgLengthBreadthRatio,
      'grade': result.grade,
    };
    final id = await db.insert(_table, row);
    return HistoryEntry.fromRow({...row, 'id': id});
  }

  Future<HistoryEntry> setLabel(HistoryEntry entry, String? label) async {
    final db = await _open();
    await db.update(_table, {'label': label},
        where: 'id = ?', whereArgs: [entry.id]);
    return entry.withLabel(label);
  }

  Future<void> delete(HistoryEntry entry) async {
    final db = await _open();
    await db.delete(_table, where: 'id = ?', whereArgs: [entry.id]);
    await _deleteFiles(entry);
  }

  Future<void> clear() async {
    final entries = await list();
    final db = await _open();
    await db.delete(_table);
    for (final entry in entries) {
      await _deleteFiles(entry);
    }
  }

  Future<void> _deleteFiles(HistoryEntry entry) async {
    for (final path in [entry.imagePath, entry.annotatedPath]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> close() async => _db?.close();
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final repo = HistoryRepository();
  ref.onDispose(repo.close);
  return repo;
});
