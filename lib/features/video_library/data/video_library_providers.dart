import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../browse/data/remote_models.dart';
import '../../browse/data/remote_resolvers.dart';
import '../../video/data/video_controller.dart';
import 'video_cover_store.dart';

final videoItemsProvider = StreamProvider<List<VideoItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.videoItems,
  )..orderBy([(v) => OrderingTerm.desc(v.addedAt)])).watch();
});

/// Whether this stable id is already in the video library.
final videoInLibraryProvider = StreamProvider.family<bool, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.videoItems)..where((v) => v.id.equals(id)))
      .watch()
      .map((rows) => rows.isNotEmpty);
});

final videoItemByIdProvider = StreamProvider.family<VideoItem?, String>((
  ref,
  id,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.videoItems,
  )..where((v) => v.id.equals(id))).watchSingleOrNull();
});

final videoCollectionIdsProvider = StreamProvider.family<Set<String>, String>((
  ref,
  videoId,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.collectionVideos)
        ..where((cv) => cv.videoId.equals(videoId)))
      .watch()
      .map((rows) => rows.map((r) => r.collectionId).toSet());
});

final collectionVideosProvider = StreamProvider.family<List<VideoItem>, String>(
  (ref, collectionId) {
    final db = ref.watch(databaseProvider);
    final query =
        db.select(db.videoItems).join([
            innerJoin(
              db.collectionVideos,
              db.collectionVideos.videoId.equalsExp(db.videoItems.id),
            ),
          ])
          ..where(db.collectionVideos.collectionId.equals(collectionId))
          ..orderBy([OrderingTerm.desc(db.collectionVideos.addedAt)]);
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(db.videoItems)).toList(),
    );
  },
);

String videoItemTitle(VideoItem row) {
  final custom = row.customTitle;
  if (custom != null && custom.isNotEmpty) return custom;
  return p.basenameWithoutExtension(row.fileName);
}

final videoLibraryRepositoryProvider = Provider<VideoLibraryRepository>((ref) {
  return VideoLibraryRepository(
    ref.watch(databaseProvider),
    ref.watch(videoCoverStoreProvider),
  );
});

class VideoLibraryRepository {
  VideoLibraryRepository(this._db, this._covers);

  final TonariDatabase _db;
  final VideoCoverStore _covers;

  /// Returns false when the video is already in the library.
  Future<bool> add(PlayableItem item) async {
    final id = item.stableId;
    final existing = await _row(id);
    if (existing != null) return false;
    await _db
        .into(_db.videoItems)
        .insert(
          VideoItemsCompanion.insert(
            id: id,
            sourceKind: item.sourceKind.name,
            sourceId: item.sourceId,
            sourceName: item.sourceName,
            path: item.path,
            fileName: item.fileName,
            pickcode: Value(item.pickcode),
            size: Value(item.size),
            addedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return true;
  }

  Future<void> remove(String id) async {
    final row = await _row(id);
    await _db.transaction(() async {
      await (_db.delete(
        _db.collectionVideos,
      )..where((cv) => cv.videoId.equals(id))).go();
      await (_db.delete(_db.videoItems)..where((v) => v.id.equals(id))).go();
    });
    await _covers.delete(row?.coverPath);
  }

  Future<void> setFavorite(String id, bool favorite) async {
    await (_db.update(_db.videoItems)..where((v) => v.id.equals(id))).write(
      VideoItemsCompanion(isFavorite: Value(favorite)),
    );
  }

  Future<void> rename(String id, String? customTitle) async {
    final title = (customTitle == null || customTitle.trim().isEmpty)
        ? null
        : customTitle.trim();
    await (_db.update(_db.videoItems)..where((v) => v.id.equals(id))).write(
      VideoItemsCompanion(customTitle: Value(title)),
    );
  }

  Future<void> setCoverPath(String id, String? coverPath) async {
    final row = await _row(id);
    if (row == null) return;
    await (_db.update(_db.videoItems)..where((v) => v.id.equals(id))).write(
      VideoItemsCompanion(coverPath: Value(coverPath)),
    );
    if (row.coverPath != null && row.coverPath != coverPath) {
      await _covers.delete(row.coverPath);
    }
  }

  Future<void> touchLastPlayed(String id) async {
    await (_db.update(_db.videoItems)..where((v) => v.id.equals(id))).write(
      VideoItemsCompanion(lastPlayedAt: Value(DateTime.now())),
    );
  }

  Future<void> setCollectionMembership(
    String videoId,
    String collectionId, {
    required bool member,
  }) async {
    if (member) {
      await _db
          .into(_db.collectionVideos)
          .insert(
            CollectionVideosCompanion.insert(
              collectionId: collectionId,
              videoId: videoId,
              addedAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_db.delete(_db.collectionVideos)..where(
            (cv) =>
                cv.collectionId.equals(collectionId) &
                cv.videoId.equals(videoId),
          ))
          .go();
    }
  }

  Future<VideoItem?> _row(String id) {
    return (_db.select(
      _db.videoItems,
    )..where((v) => v.id.equals(id))).getSingleOrNull();
  }
}

final videoLibraryPlayerProvider = Provider<VideoLibraryPlayer>((ref) {
  return VideoLibraryPlayer(ref);
});

class VideoLibraryPlayer {
  VideoLibraryPlayer(this._ref);

  final Ref _ref;

  PlayableItem playableFrom(VideoItem row) {
    final kind = RemoteSourceKind.values.byName(row.sourceKind);
    return PlayableItem(
      id: row.id,
      sourceKind: kind,
      sourceId: row.sourceId,
      sourceName: row.sourceName,
      path: row.path,
      fileName: row.fileName,
      kind: RemoteEntryKind.video,
      size: row.size,
      pickcode: row.pickcode,
      resolverSource: 'video_library',
      title: videoItemTitle(row),
      resolve: buildRemoteResolver(
        _ref,
        sourceKind: kind,
        sourceId: row.sourceId,
        path: row.path,
        pickcode: row.pickcode,
        isVideo: true,
      ),
    );
  }

  Future<void> play(VideoItem row) {
    return _ref.read(videoControllerProvider.notifier).open(playableFrom(row));
  }
}
