import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../browse/data/remote_models.dart';
import '../../browse/presentation/remote_browser_page.dart';
import '../data/p115_auth_service.dart';
import '../data/p115_client.dart';
import '../data/p115_cookie_store.dart';

class P115BrowserPage extends ConsumerWidget {
  const P115BrowserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const root = RemoteEntry(
      id: '0',
      path: '0',
      name: P115Client.sourceName,
      kind: RemoteEntryKind.folder,
      sourceId: P115Client.sourceId,
    );
    return RemoteBrowserPage(
      sourceKind: RemoteSourceKind.p115,
      sourceId: P115Client.sourceId,
      sourceName: P115Client.sourceName,
      root: root,
      loadFolder: (folder) async {
        try {
          return await ref.read(p115ClientProvider).list(folder.path);
        } on P115AuthExpiredException {
          await ref.read(p115AuthServiceProvider).clearCookie();
          ref.invalidate(p115CookieProvider);
          if (context.mounted) Navigator.of(context).maybePop();
          rethrow;
        }
      },
      resolveFile: (entry) async {
        try {
          return await ref
              .read(p115ClientProvider)
              .resolveDownloadUrl(entry.pickcode!);
        } on P115AuthExpiredException {
          await ref.read(p115AuthServiceProvider).clearCookie();
          ref.invalidate(p115CookieProvider);
          if (context.mounted) Navigator.of(context).maybePop();
          rethrow;
        }
      },
    );
  }
}
