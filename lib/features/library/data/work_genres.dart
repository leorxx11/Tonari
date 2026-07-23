import 'dart:convert';

import '../../../core/db/database.dart';

List<String> genreNamesOf(Work work) {
  final raw = jsonDecode(work.genresJson);
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map && item['name'] is String) item['name'] as String,
  ];
}
