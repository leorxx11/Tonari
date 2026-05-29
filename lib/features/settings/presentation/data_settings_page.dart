import 'package:flutter/material.dart';

import 'removed_works_page.dart';

class DataSettingsPage extends StatelessWidget {
  const DataSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.restore_from_trash_outlined),
            title: const Text('已移除作品'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RemovedWorksPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
