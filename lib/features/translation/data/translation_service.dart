import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'html_segmenter.dart';

class LlmProviderConfig {
  const LlmProviderConfig({
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    this.systemPrompt,
  });

  final String baseUrl;
  final String model;
  final String apiKey;
  final String? systemPrompt;
}

class TranslationException implements Exception {
  TranslationException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => 'TranslationException: $message';
}

class TranslationService {
  TranslationService({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  static const _titlePrompt =
      '你是 DLsite 作品标题翻译助手。请把日文作品标题翻译为简洁自然的中文。'
      '保留作品中的特殊符号、波浪号、标点。不要加任何引号、解释、注释。直接输出译文一行。';

  static const _descPrompt =
      '你是 DLsite 作品简介翻译助手。输入是一个 JSON 字符串数组，每个元素是日文段落或短语。'
      '请把每个元素翻译为自然流畅的中文，保持数组长度与顺序完全一致。'
      '直接输出 JSON 字符串数组，不要包裹 markdown 代码块，不要任何解释。';

  Future<String> translateTitle(
    LlmProviderConfig provider,
    String title, {
    CancelToken? cancelToken,
  }) {
    return _retryOnce(
      () => _chat(
        provider,
        [
          {
            'role': 'system',
            'content': _composeSystemPrompt(_titlePrompt, provider.systemPrompt),
          },
          {'role': 'user', 'content': title},
        ],
        cancelToken: cancelToken,
      ),
    );
  }

  Future<String> translateDescriptionHtml(
    LlmProviderConfig provider,
    String html, {
    CancelToken? cancelToken,
  }) async {
    final segs = HtmlSegmenter.segment(html);
    if (segs.texts.isEmpty) return html;

    final raw = await _retryOnce(
      () => _chat(
        provider,
        [
          {
            'role': 'system',
            'content': _composeSystemPrompt(_descPrompt, provider.systemPrompt),
          },
          {'role': 'user', 'content': jsonEncode(segs.texts)},
        ],
        cancelToken: cancelToken,
      ),
    );

    final arr = _parseJsonArray(raw);
    if (arr.length != segs.texts.length) {
      throw TranslationException(
        'translation count mismatch: ${arr.length} vs ${segs.texts.length}',
      );
    }
    return HtmlSegmenter.fill(segs, arr.map((e) => e.toString()).toList());
  }

  Future<void> testConnection(LlmProviderConfig provider) async {
    await _chat(provider, [
      {'role': 'user', 'content': 'ping'},
    ]);
  }

  Future<String> _chat(
    LlmProviderConfig provider,
    List<Map<String, String>> messages, {
    CancelToken? cancelToken,
  }) async {
    final url = _normalizeBaseUrl(provider.baseUrl);
    final r = await _dio.post<Map<String, dynamic>>(
      '$url/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        },
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
      data: {'model': provider.model, 'messages': messages, 'temperature': 0.3},
      cancelToken: cancelToken,
    );
    final choices = r.data?['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw TranslationException('empty response');
    }
    final content = (choices[0] as Map?)?['message']?['content'];
    if (content is! String || content.trim().isEmpty) {
      throw TranslationException('empty content');
    }
    return content.trim();
  }

  Future<T> _retryOnce<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      return await action();
    }
  }

  List<dynamic> _parseJsonArray(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    final decoded = jsonDecode(cleaned);
    if (decoded is List) return decoded;
    throw TranslationException(
      'expected JSON array, got ${decoded.runtimeType}',
    );
  }

  static String _composeSystemPrompt(String base, String? userExtra) {
    if (userExtra == null || userExtra.trim().isEmpty) return base;
    return '$base\n\n${userExtra.trim()}';
  }

  static String _normalizeBaseUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}

final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService();
});
