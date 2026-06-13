import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiagnosticLog {
  DiagnosticLog._();

  static const _enabledKey = 'diagnostic.log.enabled';
  static const _sessionKey = 'diagnostic.log.session';
  static SharedPreferences? _prefs;
  static File? _file;
  static bool _enabled = false;
  static String _session = '';
  static Future<void> _pending = Future.value();

  static bool get enabled => _enabled;
  static String get session => _session;

  static Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _session = prefs.getString(_sessionKey) ?? '';
    if (_enabled && _session.isEmpty) {
      _session = _newSessionId();
      await prefs.setString(_sessionKey, _session);
    }
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/tonari-diagnostic.jsonl');
  }

  static Future<void> startSession() async {
    _session = _newSessionId();
    _enabled = true;
    await _prefs!.setString(_sessionKey, _session);
    await _prefs!.setBool(_enabledKey, true);
    await clear();
    write('diagnostic', 'session_start', {'sessionId': _session});
  }

  static Future<void> stopSession() async {
    write('diagnostic', 'session_stop', {'sessionId': _session});
    await _pending;
    _enabled = false;
    await _prefs!.setBool(_enabledKey, false);
  }

  static void write(
    String source,
    String event, [
    Map<String, Object?> fields = const {},
  ]) {
    if (!_enabled) return;
    final file = _file!;
    final record = <String, Object?>{
      'ts': DateTime.now().toIso8601String(),
      'session': _session,
      'source': source,
      'event': event,
      ...fields,
    };
    final line = '${jsonEncode(record)}\n';
    _pending = _pending
        .then<void>((_) async {
          await file.writeAsString(line, mode: FileMode.append);
        })
        .catchError((Object _) {});
  }

  static Future<String> read() async {
    await _pending;
    final file = _file!;
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  static Future<void> clear() async {
    await _pending;
    final file = _file!;
    await file.writeAsString('');
  }

  /// Writes the current log to a `.txt` in the temp dir for sharing, returning
  /// its path (or null when empty). Sharing via the system sheet needs no
  /// entitlement, so it works on any signing.
  static Future<String?> exportTxt() async {
    await _pending;
    final content = await read();
    if (content.isEmpty) return null;
    final dir = await getTemporaryDirectory();
    final name = _session.isEmpty ? 'tonari-diagnostic' : 'tonari-$_session';
    final out = File('${dir.path}/$name.txt');
    await out.writeAsString(content);
    return out.path;
  }

  static String _newSessionId() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  }
}
