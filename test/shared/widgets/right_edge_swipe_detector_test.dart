import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/shared/widgets/right_edge_swipe_detector.dart';

import '../../support/forward_gesture.dart';

void main() {
  void testIosWidgets(String description, WidgetTesterCallback callback) {
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  var nativeEnabled = false;
  Future<ForwardNavigationObserver> pumpApp(
    WidgetTester tester, {
    VoidCallback? onCommitted,
    VoidCallback? onCreated,
    VoidCallback? onDisposed,
  }) async {
    const channel = MethodChannel('tonari/forward_navigation');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      nativeEnabled = call.arguments as bool;
      return null;
    });
    final observer = ForwardNavigationObserver();
    addTearDown(() {
      observer.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {TargetPlatform.iOS: CupertinoPageTransitionsBuilder()},
          ),
        ),
        navigatorObservers: [observer],
        builder: (_, child) =>
            ForwardNavigationScope(observer: observer, child: child!),
        home: RightEdgeSwipeDetector(
          pageBuilder: (_) =>
              _Destination(onCreated: onCreated, onDisposed: onDisposed),
          onNavigationCommitted: onCommitted,
          child: const Scaffold(body: SizedBox.expand(key: Key('source'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(nativeEnabled, isTrue);
    return observer;
  }

  testIosWidgets(
    'one route follows the drag, commits without remounting and pops',
    (tester) async {
      var commits = 0;
      var creates = 0;
      var disposes = 0;
      final observer = await pumpApp(
        tester,
        onCommitted: () => commits++,
        onCreated: () => creates++,
        onDisposed: () => disposes++,
      );
      final width = tester.getSize(find.byKey(const Key('source'))).width;
      await sendForwardGesture(tester, 'began', progress: .1);
      await sendForwardGesture(tester, 'changed', progress: .4);
      expect(creates, 1);
      expect(disposes, 0);
      expect(observer.navigator!.userGestureInProgress, isTrue);
      expect(
        tester.getTopLeft(find.byKey(const Key('destination'))).dx,
        closeTo(width * .6, 1),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('source'))).dx,
        lessThan(0),
      );
      expect(commits, 0);
      final state = tester.state(find.byType(_Destination));
      await sendForwardGesture(tester, 'ended', progress: .4);
      await tester.pumpAndSettle();
      expect(commits, 1);
      expect(creates, 1);
      expect(disposes, 0);
      expect(tester.state(find.byType(_Destination)), same(state));
      expect(observer.navigator!.userGestureInProgress, isFalse);
      expect(tester.getTopLeft(find.byKey(const Key('destination'))).dx, 0);
      await tester.dragFrom(const Offset(1, 300), Offset(width * .8, 0));
      await tester.pumpAndSettle();
      expect(disposes, 1);
      expect(find.byKey(const Key('source')), findsOneWidget);
      expect(nativeEnabled, isTrue);
    },
  );

  for (final ending in ['ended', 'cancelled']) {
    testIosWidgets('$ending returns to source without committing', (
      tester,
    ) async {
      var commits = 0;
      final observer = await pumpApp(tester, onCommitted: () => commits++);
      final progress = ending == 'ended' ? .04 : .8;
      await sendForwardGesture(tester, 'began', progress: progress);
      await sendForwardGesture(tester, ending, progress: progress);
      await tester.pumpAndSettle();
      expect(commits, 0);
      expect(observer.navigator!.userGestureInProgress, isFalse);
      expect(find.byKey(const Key('destination')), findsNothing);
      expect(find.byKey(const Key('source')), findsOneWidget);
      await sendForwardGesture(tester, 'began', progress: .4);
      await sendForwardGesture(tester, 'ended', progress: .4);
      await tester.pumpAndSettle();
      expect(commits, 1);
    });
  }

  testIosWidgets(
    'zero progress cancellation releases navigator gesture state',
    (tester) async {
      final observer = await pumpApp(tester);
      await sendForwardGesture(tester, 'began', progress: 0);
      await sendForwardGesture(tester, 'cancelled', progress: 0);
      await tester.pumpAndSettle();
      expect(observer.navigator!.userGestureInProgress, isFalse);
      expect(find.byKey(const Key('destination')), findsNothing);
    },
  );

  testIosWidgets('popup and local history block forward navigation', (
    tester,
  ) async {
    final observer = await pumpApp(tester);
    final context = tester.element(find.byKey(const Key('source')));
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(title: Text('dialog')),
    );
    await tester.pumpAndSettle();
    expect(nativeEnabled, isFalse);
    await sendForwardGesture(tester, 'began', progress: .4);
    expect(find.byType(_Destination), findsNothing);
    observer.navigator!.pop();
    await tester.pumpAndSettle();
    ModalRoute.of(context)!.addLocalHistoryEntry(LocalHistoryEntry());
    await tester.pumpAndSettle();
    await sendForwardGesture(tester, 'began', progress: .4);
    expect(find.byType(_Destination), findsNothing);
    observer.navigator!.pop();
    await tester.pumpAndSettle();
    await sendForwardGesture(tester, 'began', progress: .4);
    await sendForwardGesture(tester, 'ended', progress: .4);
    await tester.pumpAndSettle();
    expect(find.byType(_Destination), findsOneWidget);
  });
}

class _Destination extends StatefulWidget {
  const _Destination({this.onCreated, this.onDisposed});
  final VoidCallback? onCreated;
  final VoidCallback? onDisposed;

  @override
  State<_Destination> createState() => _DestinationState();
}

class _DestinationState extends State<_Destination> {
  @override
  void initState() {
    super.initState();
    widget.onCreated?.call();
  }

  @override
  void dispose() {
    widget.onDisposed?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Destination')),
    body: const SizedBox.expand(key: Key('destination')),
  );
}
