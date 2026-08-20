import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../player/data/playback_controller.dart';
import 'works_providers.dart';

class LastOpenedWorkId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String productId) => state = productId;
}

final lastOpenedWorkIdProvider = NotifierProvider<LastOpenedWorkId, String?>(
  LastOpenedWorkId.new,
);

final libraryForwardWorkProvider = Provider<Work?>((ref) {
  final playingWork = ref.watch(
    playbackControllerProvider.select((state) => state.work),
  );
  if (playingWork != null) return playingWork;

  final lastOpenedId = ref.watch(lastOpenedWorkIdProvider);
  if (lastOpenedId == null) return null;
  final lastOpened = ref.watch(workByIdProvider(lastOpenedId)).value;
  if (lastOpened == null || lastOpened.isRemoved) return null;
  return lastOpened;
});
