// 会话列表页（iMessage 风格：头像/名称/最后消息/时间）
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:Kelivo/theme/app_font_weights.dart';

import '../im_store.dart';
import 'im_chat_page.dart';

class ImSessionListPage extends StatefulWidget {
  const ImSessionListPage({super.key});

  @override
  State<ImSessionListPage> createState() => _ImSessionListPageState();
}

class _ImSessionListPageState extends State<ImSessionListPage> {
  List<ImSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _initCore();
  }

  Future<void> _initCore() async {
    // 初始化 Rust Core（KelivoStore）：数据落在 App 沙盒 im/ 目录
    try {
      final dir = await getApplicationSupportDirectory();
      KelivoStore.init(dir.path);
      _refresh();
    } catch (e) {
      debugPrint('KelivoCore init failed: $e');
      setState(() => _sessions = []);
    }
  }

  void _seedIfEmpty() {
    if (_sessions.isEmpty && !_seeded) {
      _seeded = true;
      final n = KelivoStore.seedDemo();
      if (n > 0) _refresh();
    }
  }

  bool _seeded = false;

  void _refresh() {
    _sessions = KelivoStore.sessions();
    _seedIfEmpty();
    if (mounted) setState(() {});
  }

  String _timeText(double ts) {
    if (ts <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch((ts * 1000).round());
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month && d.year == now.year) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('信息', style: TextStyle(fontWeight: AppFontWeights.semibold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square),
            tooltip: '新消息',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('新消息：在 Rust Core 中创建一个会话后出现')));
            },
          ),
        ],
      ),
      body: _sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 56,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  const Text('还没有会话'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      final n = KelivoStore.seedDemo();
                      _refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已生成 $n 个模拟会话')));
                    },
                    child: const Text('生成模拟会话'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _sessions.length,
              separatorBuilder: (_, __) => Divider(
                  height: 1, indent: 72, color: Theme.of(context).dividerColor),
              itemBuilder: (_, i) {
                final s = _sessions[i];
                return ListTile(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ImChatPage(session: s),
                    ));
                  },
                  leading: _avatar(s),
                  title: Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: AppFontWeights.medium)),
                  subtitle: Text(
                    s.last.isEmpty ? ' ' : s.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  trailing: Text(_timeText(s.ts),
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                );
              },
            ),
    );
  }

  Widget _avatar(ImSession s) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: s.kind == 'group'
            ? const Color(0xFF6E8B5E)
            : const Color(0xFF5FA8D3),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(s.avatar.isEmpty ? s.name.characters.first : s.avatar,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
    );
  }
}