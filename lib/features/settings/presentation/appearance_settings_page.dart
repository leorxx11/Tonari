import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/file_entry_prefs.dart';
import '../data/privacy_prefs.dart';
import '../data/theme_prefs.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themePrefsProvider);
    final themeNotifier = ref.read(themePrefsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        children: [
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode != null) themeNotifier.setMode(mode);
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text('跟随系统'),
                  secondary: Icon(Icons.brightness_auto_outlined),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text('浅色'),
                  secondary: Icon(Icons.light_mode_outlined),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text('深色'),
                  secondary: Icon(Icons.dark_mode_outlined),
                ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            value: ref.watch(privacyBlurProvider),
            onChanged: (on) =>
                ref.read(privacyBlurProvider.notifier).setEnabled(on),
            title: const Text('后台模糊'),
            subtitle: const Text('切到后台时模糊画面，多任务切换器中不显示内容'),
            secondary: const Icon(Icons.blur_on),
          ),
          const Divider(),
          ListTile(
            title: const Text('作品文件入口位置'),
            subtitle: const Text('设置封面文件图标显示在左下角或右下角'),
            trailing: CupertinoSlidingSegmentedControl<FileEntryPosition>(
              groupValue: ref.watch(fileEntryPositionProvider),
              children: const {
                FileEntryPosition.bottomLeft: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('左下角'),
                ),
                FileEntryPosition.bottomRight: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('右下角'),
                ),
              },
              onValueChanged: (position) {
                if (position != null) {
                  ref.read(fileEntryPositionProvider.notifier).set(position);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
