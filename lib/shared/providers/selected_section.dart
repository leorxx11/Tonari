import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppSection {
  audioLibrary,
  videoLibrary,
  collections,
  history,
  browse,
  settings,
}

class SelectedSection extends Notifier<AppSection> {
  @override
  AppSection build() => AppSection.audioLibrary;

  void set(AppSection value) => state = value;
}

final selectedSectionProvider = NotifierProvider<SelectedSection, AppSection>(
  SelectedSection.new,
);
