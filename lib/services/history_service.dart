import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

class HistoryService {
  HistoryService._privateConstructor();
  static final HistoryService instance = HistoryService._privateConstructor();

  final ValueNotifier<List<Map<String, dynamic>>> recordsNotifier = ValueNotifier([]);

  void addRecord({
    required String label,
    required double confidence,
    String? imagePath,
    DateTime? timestamp,
    String? id,
    String? trueLabel,
  }) {
    final record = {
      'id': id ?? 'rec_${DateTime.now().millisecondsSinceEpoch}',
      'category': label,
      'confidence': confidence,
      'timestamp': timestamp ?? DateTime.now(),
      'imagePath': imagePath,
      if (trueLabel != null) 'trueLabel': trueLabel,
    };

    final updated = List<Map<String, dynamic>>.from(recordsNotifier.value);
    updated.insert(0, record);
    recordsNotifier.value = updated;

    // Persist to Realtime Database (best-effort)
    try {
      final db = FirebaseDatabase.instance;
      final key = record['id'] as String;
      final ref = db.ref('records/$key');
      final payload = {
        'id': record['id'],
        'category': record['category'],
        'confidence': record['confidence'],
        'timestamp': (record['timestamp'] as DateTime).toIso8601String(),
        'imagePath': record['imagePath'] ?? '',
        if (record.containsKey('trueLabel')) 'trueLabel': record['trueLabel'],
      };
      ref.set(payload).catchError((e) {
        // ignore write errors; keep local history functional
        // ignore: avoid_print
        print('Failed saving record to Firebase: $e');
      });
    } catch (e) {
      // ignore initialization errors
      // ignore: avoid_print
      print('Firebase write skipped: $e');
    }
  }

  /// Load all records from Realtime Database and populate the local history.
  Future<void> loadFromFirebase() async {
    try {
      final db = FirebaseDatabase.instance;
      final ref = db.ref('records');
      final snap = await ref.get();
      if (!snap.exists) return;

      final List<Map<String, dynamic>> loaded = [];
      final data = snap.value as Map<dynamic, dynamic>?;
      if (data != null) {
        data.forEach((key, value) {
          try {
            final map = Map<String, dynamic>.from(value as Map);
            final tsRaw = map['timestamp'] as String? ?? '';
            DateTime ts;
            try {
              ts = DateTime.parse(tsRaw);
            } catch (_) {
              ts = DateTime.now();
            }

            loaded.add({
              'id': map['id'] ?? key,
              'category': map['category'] ?? 'Unknown',
              'confidence': (map['confidence'] is num) ? (map['confidence'] as num).toDouble() : 0.0,
              'timestamp': ts,
              'imagePath': map['imagePath'] ?? '',
              if (map.containsKey('trueLabel')) 'trueLabel': map['trueLabel'],
            });
          } catch (e) {
            // skip malformed entry
          }
        });
      }

      // Sort by timestamp desc
      loaded.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      recordsNotifier.value = loaded;
    } catch (e) {
      // ignore read errors
      // ignore: avoid_print
      print('Failed loading history from Firebase: $e');
    }
  }

  /// Set or update the true/ground-truth label for an existing record by id.
  bool setTrueLabel(String id, String trueLabel) {
    final idx = recordsNotifier.value.indexWhere((r) => r['id'] == id);
    if (idx == -1) return false;
    final updated = List<Map<String, dynamic>>.from(recordsNotifier.value);
    final rec = Map<String, dynamic>.from(updated[idx]);
    rec['trueLabel'] = trueLabel;
    updated[idx] = rec;
    recordsNotifier.value = updated;
    return true;
  }

  List<Map<String, dynamic>> getAll() => List.unmodifiable(recordsNotifier.value);

  List<Map<String, dynamic>> filterBy(String category) {
    if (category == 'All') return getAll();
    return recordsNotifier.value.where((r) => r['category'] == category).toList();
  }

  Map<String, dynamic> getStats() {
    final records = recordsNotifier.value;
    final total = records.length;
    final Map<String, int> counts = {};
    double avgConfidence = 0.0;

    for (final r in records) {
      final cat = r['category'] as String? ?? 'Unknown';
      counts[cat] = (counts[cat] ?? 0) + 1;
      avgConfidence += (r['confidence'] as double? ?? 0.0);
    }

    if (total > 0) avgConfidence = avgConfidence / total;

    return {
      'total': total,
      'counts': counts,
      'avgConfidence': avgConfidence,
    };
  }
}
