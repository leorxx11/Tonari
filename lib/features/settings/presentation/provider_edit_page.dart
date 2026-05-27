import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../translation/data/llm_provider_repository.dart';
import '../../translation/data/translation_service.dart';

enum _Template {
  deepseek(
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    model: 'deepseek-v4-flash',
  ),
  gemini(
    name: 'Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    model: 'gemini-2.5-flash',
  ),
  custom(name: '自定义', baseUrl: '', model: '');

  const _Template({
    required this.name,
    required this.baseUrl,
    required this.model,
  });

  final String name;
  final String baseUrl;
  final String model;
}

class ProviderEditPage extends ConsumerStatefulWidget {
  const ProviderEditPage({super.key, this.provider});

  final LlmProvider? provider;

  @override
  ConsumerState<ProviderEditPage> createState() => _ProviderEditPageState();
}

class _ProviderEditPageState extends ConsumerState<ProviderEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _apiKey;
  late final TextEditingController _systemPrompt;
  bool _obscureKey = true;
  bool _testing = false;
  bool _saving = false;
  String? _existingKeyHint;

  bool get _isEdit => widget.provider != null;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _name = TextEditingController(text: p?.name ?? '');
    _baseUrl = TextEditingController(text: p?.baseUrl ?? '');
    _model = TextEditingController(text: p?.model ?? '');
    _apiKey = TextEditingController();
    _systemPrompt = TextEditingController(text: p?.systemPrompt ?? '');
    if (p != null) {
      _loadExistingKeyHint(p.id);
    }
  }

  Future<void> _loadExistingKeyHint(String providerId) async {
    final repo = ref.read(llmProviderRepositoryProvider);
    final key = await repo.readKey(providerId);
    if (!mounted) return;
    if (key != null && key.isNotEmpty) {
      setState(() {
        _existingKeyHint = _maskKey(key);
      });
    }
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    _systemPrompt.dispose();
    super.dispose();
  }

  void _applyTemplate(_Template t) {
    setState(() {
      if (_name.text.isEmpty) _name.text = t.name;
      _baseUrl.text = t.baseUrl;
      _model.text = t.model;
    });
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      _baseUrl.text.trim().isNotEmpty &&
      _model.text.trim().isNotEmpty &&
      (_isEdit || _apiKey.text.trim().isNotEmpty);

  Future<void> _testConnection() async {
    if (_baseUrl.text.trim().isEmpty || _model.text.trim().isEmpty) {
      _snack('请先填写 Base URL 和 Model');
      return;
    }
    String apiKey = _apiKey.text.trim();
    if (apiKey.isEmpty && _isEdit) {
      final saved = await ref
          .read(llmProviderRepositoryProvider)
          .readKey(widget.provider!.id);
      if (saved != null && saved.isNotEmpty) apiKey = saved;
    }
    if (apiKey.isEmpty) {
      _snack('请填写 API Key');
      return;
    }

    setState(() => _testing = true);
    try {
      await ref
          .read(translationServiceProvider)
          .testConnection(
            LlmProviderConfig(
              baseUrl: _baseUrl.text.trim(),
              model: _model.text.trim(),
              apiKey: apiKey,
              systemPrompt: _systemPrompt.text.trim().isEmpty
                  ? null
                  : _systemPrompt.text.trim(),
            ),
          );
      if (!mounted) return;
      _snack('连接成功');
    } catch (e) {
      if (!mounted) return;
      _snack('连接失败：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(llmProviderRepositoryProvider);
      final systemPrompt = _systemPrompt.text.trim().isEmpty
          ? null
          : _systemPrompt.text.trim();
      if (_isEdit) {
        await repo.update(
          id: widget.provider!.id,
          name: _name.text.trim(),
          baseUrl: _baseUrl.text.trim(),
          model: _model.text.trim(),
          apiKey: _apiKey.text.trim().isEmpty ? null : _apiKey.text.trim(),
          systemPrompt: systemPrompt,
        );
      } else {
        await repo.create(
          name: _name.text.trim(),
          baseUrl: _baseUrl.text.trim(),
          model: _model.text.trim(),
          apiKey: _apiKey.text.trim(),
          systemPrompt: systemPrompt,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _snack('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑 Provider' : '添加 Provider'),
        actions: [
          TextButton(
            onPressed: _canSave && !_saving ? _save : null,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          if (!_isEdit) ...[
            Text(
              '快速模板',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in _Template.values)
                  ActionChip(
                    label: Text(t.name),
                    onPressed: () => _applyTemplate(t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '例如 DeepSeek 主力',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.example.com/v1',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: 'Model',
              hintText: 'deepseek-chat',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: _isEdit ? 'API Key（留空保留原值）' : 'API Key',
              hintText: _existingKeyHint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _systemPrompt,
            decoration: const InputDecoration(
              labelText: 'System Prompt 附加内容（可选）',
              hintText: '术语字典、风格偏好等',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: const Text('测试连接'),
            onPressed: _testing ? null : _testConnection,
          ),
        ],
      ),
    );
  }
}
