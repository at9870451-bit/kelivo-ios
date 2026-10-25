// 聊天页（iMessage 风格：蓝/灰气泡、时间戳、已读状态、输入框、附件菜单）
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import '../im_store.dart';

class ImChatPage extends StatefulWidget {
  final ImSession session;
  const ImChatPage({super.key, required this.session});

  @override
  State<ImChatPage> createState() => _ImChatPageState();
}

class _ImChatPageState extends State<ImChatPage> {
  final _inputCtl = TextEditingController();
  final _scrollCtl = ScrollController();
  List<ImMessage> _msgs = [];
  List<ImMessage> _pendingAtts = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _msgs = KelivoStore.messages(widget.session.id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtl.hasClients) {
        _scrollCtl.jumpTo(_scrollCtl.position.maxScrollExtent);
      }
    });
  }

  String _timeText(double ts) {
    final d = DateTime.fromMillisecondsSinceEpoch((ts * 1000).round());
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _send() async {
    final text = _inputCtl.text.trim();
    final atts = List<ImMessage>.from(_pendingAtts);
    if (text.isEmpty && atts.isEmpty) return;
    _inputCtl.clear();
    setState(() {
      _pendingAtts = [];
      _sending = true;
    });
    // 通过 Rust Core 落库（消息带内容；图片附件以内容标记存储）
    if (text.isNotEmpty) {
      KelivoStore.append(widget.session.id, 'user', text);
    }
    for (final a in atts) {
      final tag = '[图片] ${a.content}';
      KelivoStore.append(widget.session.id, 'user', tag);
    }
    // AI 好友：调用模型生成回复；无模型/失败则模拟回复
    final reply = await _generateReply(text);
    if (mounted) {
      KelivoStore.append(widget.session.id, 'assistant', reply);
      final all = KelivoStore.messages(widget.session.id);
      for (final m in all.reversed) {
        if (m.mine) {
          KelivoStore.replace(widget.session.id,
              [for (final x in all) x.id == m.id ? ImMessage(id: m.id, mine: true, content: m.content, ts: m.ts, read: true) : x]);
          break;
        }
      }
      setState(() => _sending = false);
      _reload();
    }
  }

  /// 查找当前会话对应的好友（用于读取专属模型/人设）
  ImFriend? _findFriend() {
    for (final f in KelivoContacts.friends()) {
      if (f.id == widget.session.id) return f;
    }
    return null;
  }

  /// AI 回复：好友有专属模型（或全局模型）时调用；否则模拟回复
  Future<String> _generateReply(String text) async {
    if (text.isEmpty) return '（已读）收到～';
    final friend = _findFriend();
    if (friend == null) return '（已读）收到～';

    String? model = friend.model.isNotEmpty ? friend.model : null;
    String? baseUrl;
    String? apiKey;
    try {
      final settings = context.read<SettingsProvider>();
      final providerKey = settings.currentModelProvider;
      if (providerKey != null && providerKey.isNotEmpty) {
        final cfg = settings.getProviderConfig(providerKey);
        baseUrl = cfg.baseUrl.trim();
        apiKey = cfg.apiKey.trim();
      }
      model ??= settings.currentModelId;
    } catch (_) {}

    if (baseUrl == null || baseUrl.isEmpty || apiKey == null || apiKey.isEmpty) {
      return '（已读）收到～';
    }
    if (model == null || model.isEmpty) {
      return '（已读）收到～';
    }

    // 组装最近历史（≤10 条）
    final history = KelivoStore.messages(widget.session.id);
    final recent = history.length > 10
        ? history.sublist(history.length - 10)
        : history;
    final msgs = [
      for (final m in recent)
        {
          'role': m.mine ? 'user' : 'assistant',
          'content': m.content,
        },
    ];

    // 人设注入
    String system = '';
    if (friend.persona.isNotEmpty) {
      system = friend.persona;
    }

    try {
      var url = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      if (!url.endsWith('/chat/completions')) {
        url = '${url}chat/completions';
      }
      final resp = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              if (system.isNotEmpty) 'system': system,
              'messages': msgs,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices.first['message']?['content'];
          if (content != null && content.toString().trim().isNotEmpty) {
            return content.toString().trim();
          }
        }
      }
    } catch (e) {
      debugPrint('AI 回复失败: $e');
    }
    return '（已读）收到～';
  }

  Future<void> _attachMenu() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('照片'),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (v == null) return;
    final XFile? img = await ImagePicker().pickImage(
      source: v == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
    if (img == null) return;
    // 真实图片消息：复制到临时文件并作为附件预览（发送后经 Rust 存储为 [图片] 消息）
    final file = File(img.path);
    if (mounted) {
      setState(() {
        _pendingAtts = [
          ..._pendingAtts,
          ImMessage(id: DateTime.now().microsecondsSinceEpoch, mine: true,
              content: file.path, ts: 0, read: false),
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mine = const Color(0xFF007AFF); // iMessage 蓝
    final other = cs.brightness == Brightness.dark
        ? const Color(0xFF26262A)
        : const Color(0xFFE5E5EA); // iMessage 灰
    final mineText = Colors.white;
    final otherText = cs.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.session.name,
                style: TextStyle(fontWeight: AppFontWeights.semibold)),
            Text('Rust Core 会话 · ${widget.session.kind}',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: const Text('清空会话'),
                        onTap: () {
                          KelivoStore.clear(widget.session.id);
                          Navigator.pop(ctx);
                          _reload();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _msgs.isEmpty
                  ? Center(
                      child: Text('还没有消息',
                          style: TextStyle(color: cs.onSurfaceVariant)))
                  : ListView.builder(
                      controller: _scrollCtl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) {
                        final m = _msgs[i];
                        return _bubble(m, mine, other, mineText, otherText);
                      },
                    ),
            ),
            if (_pendingAtts.isNotEmpty)
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: _pendingAtts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final a = _pendingAtts[i];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(a.content),
                          width: 52, height: 52, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_outlined)),
                    );
                  },
                ),
              ),
            _inputBar(cs),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ImMessage m, Color mine, Color other, Color mineText,
      Color otherText) {
    final isMine = m.mine;
    final isImage = m.content.startsWith('[图片] ') &&
        File(m.content.substring(5).trim()).existsSync();
    final Widget content;
    if (isImage) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(File(m.content.substring(5).trim()),
            width: 160, height: 160, fit: BoxFit.cover),
      );
    } else {
      content = Text(m.content,
          style: TextStyle(fontSize: 16, height: 1.4, color: isMine ? mineText : otherText));
    }

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: isMine ? mine : other,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
        ),
      ),
      child: content,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(
                  color: Color(0xFF5FA8D3), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(widget.session.avatar.isEmpty
                  ? widget.session.name.characters.first
                  : widget.session.avatar,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
          if (isMine) ...[
            const SizedBox(width: 5),
            // iMessage 已读状态
            Text(
              m.read ? '已读' : '已送达',
              style: TextStyle(
                  fontSize: 11,
                  color: m.read ? const Color(0xFF34C759) : null),
            ),
          ],
        ],
      ),
    );
  }

  Widget _inputBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: cs.onSurfaceVariant,
            onPressed: _attachMenu,
          ),
          Expanded(
            child: TextField(
              controller: _inputCtl,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'iMessage',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                  color: Color(0xFF34C759), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }
}