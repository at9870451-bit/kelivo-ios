// 会话列表页（Amore/微信风格：好友+群组联系人管理 + 会话列表）
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
  List<ImFriend> _friends = [];
  List<ImGroup> _groups = [];
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _initCore();
  }

  Future<void> _initCore() async {
    try {
      final dir = await getApplicationSupportDirectory();
      KelivoStore.init(dir.path);
      _load();
    } catch (e) {
      debugPrint('KelivoCore init failed: $e');
    }
  }

  void _load() {
    _sessions = KelivoStore.sessions();
    if (_sessions.isEmpty && !_seeded) {
      _seeded = true;
      final n = KelivoStore.seedDemo();
      if (n > 0) _sessions = KelivoStore.sessions();
    }
    _friends = KelivoContacts.friends();
    _groups = KelivoContacts.groups();
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

  // ---- 添加好友（微信风格） ----
  void _addFriendSheet() {
    final nameCtl = TextEditingController();
    final noteCtl = TextEditingController();
    var gender = 'female';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('添加好友'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                autofocus: true,
                decoration: const InputDecoration(labelText: '昵称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtl,
                decoration: const InputDecoration(labelText: '备注（可选）'),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'female', label: Text('女')),
                  ButtonSegment(value: 'male', label: Text('男')),
                ],
                selected: {gender},
                onSelectionChanged: (s) => setDlg(() => gender = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final name = nameCtl.text.trim();
                if (name.isEmpty) return;
                final id = 'im_${DateTime.now().millisecondsSinceEpoch}';
                KelivoContacts.saveFriend(ImFriend(
                    id: id, name: name, gender: gender, note: noteCtl.text.trim()));
                // 自动建立空会话（进聊天即出现）
                KelivoStore.append(id, 'assistant', '你好，我是$name，很高兴认识你！');
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 创建群聊（选好友成员） ----
  void _createGroupSheet() {
    final nameCtl = TextEditingController(text: '新群聊');
    final selected = <String>{};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('创建群聊'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: '群名称'),
                ),
                const SizedBox(height: 8),
                if (_friends.isEmpty)
                  const Text('还没有好友，先添加几位好友吧',
                      style: TextStyle(color: Colors.grey))
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final f in _friends)
                          CheckboxListTile(
                            dense: true,
                            value: selected.contains(f.id),
                            title: Text(f.name),
                            secondary: CircleAvatar(
                                backgroundColor: const Color(0xFF5FA8D3),
                                child: Text(f.avatar.isEmpty
                                    ? f.name.characters.first
                                    : f.avatar,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14))),
                            onChanged: (v) => setDlg(() {
                              if (v == true) {
                                selected.add(f.id);
                              } else {
                                selected.remove(f.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (selected.isEmpty) return;
                final name = nameCtl.text.trim();
                final id = 'im_g_${DateTime.now().millisecondsSinceEpoch}';
                KelivoContacts.saveGroup(
                    ImGroup(id: id, name: name, memberIds: selected.toList()));
                final members = _friends
                    .where((f) => selected.contains(f.id))
                    .map((f) => f.name)
                    .join('、');
                KelivoStore.append(id, 'assistant', '欢迎加入「$name」（$members）');
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 长按会话：查看联系人/删除 ----
  void _sessionMenu(ImSession s) {
    final isFriend = _friends.any((f) => f.id == s.id);
    final isGroup = _groups.any((g) => g.id == s.id);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFriend)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('查看好友'),
                subtitle: Text(_friends
                        .firstWhere((f) => f.id == s.id)
                        .note
                        .isEmpty
                    ? _friends.firstWhere((f) => f.id == s.id).name
                    : _friends.firstWhere((f) => f.id == s.id).note),
                onTap: () => Navigator.pop(ctx),
              ),
            if (isGroup)
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('查看成员'),
                subtitle: Text(_groupMembers(s.id)),
                onTap: () => Navigator.pop(ctx),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除会话', style: TextStyle(color: Colors.red)),
              onTap: () {
                KelivoStore.clear(s.id);
                Navigator.pop(ctx);
                _load();
              },
            ),
            if (isFriend)
              ListTile(
                leading: const Icon(Icons.person_remove_outlined,
                    color: Colors.red),
                title:
                    const Text('删除好友', style: TextStyle(color: Colors.red)),
                onTap: () {
                  KelivoStore.clear(s.id);
                  KelivoContacts.deleteFriend(s.id);
                  Navigator.pop(ctx);
                  _load();
                },
              ),
            if (isGroup)
              ListTile(
                leading:
                    const Icon(Icons.group_remove_outlined, color: Colors.red),
                title: const Text('解散群聊', style: TextStyle(color: Colors.red)),
                onTap: () {
                  KelivoStore.clear(s.id);
                  KelivoContacts.deleteGroup(s.id);
                  Navigator.pop(ctx);
                  _load();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _groupMembers(String gid) {
    ImGroup? g;
    for (final x in _groups) {
      if (x.id == gid) g = x;
    }
    if (g == null) return '';
    final names = <String>[];
    for (final id in g.memberIds) {
      String? n;
      for (final f in _friends) {
        if (f.id == id) n = f.name;
      }
      names.add(n ?? '成员');
    }
    return names.join('、');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('信息',
            style: TextStyle(fontWeight: AppFontWeights.semibold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            tooltip: '添加好友',
            onPressed: _addFriendSheet,
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: '创建群聊',
            onPressed: _createGroupSheet,
          ),
        ],
      ),
      body: _sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 56,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  const Text('还没有好友或群聊'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _addFriendSheet,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('添加第一位好友'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _sessions.length,
              separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 72,
                  color: Theme.of(context).dividerColor),
              itemBuilder: (_, i) {
                final s = _sessions[i];
                final isGroup = s.kind == 'group';
                return ListTile(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ImChatPage(session: s),
                    ));
                  },
                  onLongPress: () => _sessionMenu(s),
                  leading: _avatar(s, isGroup),
                  title: Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontWeight: AppFontWeights.medium)),
                  subtitle: Text(
                    s.last.isEmpty ? '打个招呼吧～' : s.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  trailing: Text(_timeText(s.ts),
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                );
              },
            ),
    );
  }

  Widget _avatar(ImSession s, bool isGroup) {
    final cs = Theme.of(context).colorScheme;
    final color = isGroup ? const Color(0xFF6E8B5E) : const Color(0xFF5FA8D3);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
          isGroup
              ? '群'
              : (s.avatar.isEmpty ? s.name.characters.first : s.avatar),
          style: const TextStyle(
              color: Colors.white,
              fontSize: isGroup ? 14 : 18,
              fontWeight: FontWeight.w600)),
    );
  }
}