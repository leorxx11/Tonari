import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedTabIndex extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

final selectedTabIndexProvider =
    NotifierProvider<SelectedTabIndex, int>(SelectedTabIndex.new);
