// 会话列表页（Amore/微信风格：好友+群组联系人管理 + 会话列表）
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  // ---- 添加好友（头像/性别/年龄/人设/语音模型） ----
  static const _avatarEmojis = ['😀','😊','😎','🥰','🤗','😇','🐱','🐶','🌸','🌙','⭐','🎀'];
  static const _avatarColors = [
    Color(0xFF5FA8D3), Color(0xFFF2A65A), Color(0xFF8E8ED8),
    Color(0xFF6E8B5E), Color(0xFFD87373), Color(0xFF4FA8A8),
    Color(0xFFB886C8), Color(0xFF7A8B99),
  ];
  static const _voiceModels = ['默认', '本地朗读', '模型音色', '硅基流动', '豆包'];

  void _addFriendSheet() {
    final nameCtl = TextEditingController();
    final ageCtl = TextEditingController();
    final noteCtl = TextEditingController();
    final personaCtl = TextEditingController();
    final voiceCtl = TextEditingController();
    final memoryCtl = TextEditingController();
    final modelCtl = TextEditingController();
    var gender = 'female';
    var localTools = true;
    var emoji = '😊';
    var color = const Color(0xFF5FA8D3);
    var avatarPath = '';
    var voice = '默认';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('添加好友'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头像选择：本地照片 或 emoji + 底色
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: color,
                      backgroundImage: avatarPath.isNotEmpty
                          ? FileImage(File(avatarPath))
                          : null,
                      child: avatarPath.isEmpty
                          ? Text(emoji, style: const TextStyle(fontSize: 26))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () async {
                        try {
                          final picked = await ImagePicker().pickImage(
                              source: ImageSource.gallery, maxWidth: 512);
                          if (picked != null) {
                            setDlg(() => avatarPath = picked.path);
                          }
                        } catch (e) {
                          debugPrint('选照片失败: $e');
                        }
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      tooltip: '从相册选头像',
                    ),
                    if (avatarPath.isNotEmpty)
                      IconButton(
                        onPressed: () => setDlg(() => avatarPath = ''),
                        icon: const Icon(Icons.close),
                        tooltip: '清除照片头像',
                      ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 4,
                            children: [
                              for (final e in _avatarEmojis)
                                GestureDetector(
                                  onTap: () => setDlg(() => emoji = e),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: emoji == e
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.15)
                                          : null,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(e,
                                        style: const TextStyle(fontSize: 16)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final c in _avatarColors)
                                GestureDetector(
                                  onTap: () => setDlg(() => color = c),
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: color == c
                                          ? Border.all(
                                              width: 2,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary)
                                          : null,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '昵称'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '年龄'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'female', label: Text('女')),
                        ButtonSegment(value: 'male', label: Text('男')),
                      ],
                      selected: {gender},
                      onSelectionChanged: (s) =>
                          setDlg(() => gender = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtl,
                  decoration: const InputDecoration(labelText: '备注（可选）'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: personaCtl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: '人设',
                      hintText: '例如：温柔细心，喜欢咖啡和猫'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: memoryCtl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: '记忆（每行一条）',
                      hintText: '例如：\n喜欢去海边散步\n生日是 6 月 18 日'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: modelCtl,
                  decoration: const InputDecoration(
                      labelText: '专属模型（空=跟随全局）',
                      hintText: '例如：gpt-4o-mini'),
                ),
                SwitchListTile(
                  value: localTools,
                  title: const Text('本地工具（代码/计算/数据）'),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDlg(() => localTools = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: voice,
                        decoration: const InputDecoration(labelText: '语音模型'),
                        items: [
                          for (final v in _voiceModels)
                            DropdownMenuItem(value: v, child: Text(v)),
                        ],
                        onChanged: (v) => setDlg(() => voice = v ?? '默认'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: voiceCtl,
                        decoration:
                            const InputDecoration(labelText: '音色 ID（可空）'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                final name = nameCtl.text.trim();
                if (name.isEmpty) return;
                final id = 'im_${DateTime.now().millisecondsSinceEpoch}';
                // 照片头像复制进沙盒，持久化
                var savedAvatarPath = '';
                if (avatarPath.isNotEmpty) {
                  try {
                    final dir =
                        await getApplicationSupportDirectory();
                    final avDir = Directory('${dir.path}/im/avatars');
                    if (!avDir.existsSync()) {
                      avDir.createSync(recursive: true);
                    }
                    final ext = avatarPath.split('.').last;
                    final dest = '${avDir.path}/$id.$ext';
                    File(avatarPath).copySync(dest);
                    savedAvatarPath = dest;
                  } catch (e) {
                    debugPrint('头像复制失败: $e');
                  }
                }
                try {
                  KelivoContacts.saveFriend(ImFriend(
                      id: id,
                      name: name,
                      gender: gender,
                      age: ageCtl.text.trim(),
                      note: noteCtl.text.trim(),
                      persona: personaCtl.text.trim(),
                      voiceEngine: voice == '默认' ? '' : voice,
                      voiceId: voiceCtl.text.trim(),
                      avatar: emoji,
                      avatarColor: color.toARGB32(),
                      avatarPath: savedAvatarPath,
                      memory: memoryCtl.text
                          .split('\n')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      model: modelCtl.text.trim(),
                      localTools: localTools));
                  // 自动建立会话（Rust append 自动维护会话列表）
                  KelivoStore.append(id, 'assistant', '你好，我是$name，很高兴认识你！');
                } catch (e) {
                  debugPrint('添加好友失败: $e');
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('添加失败：$e')));
                  }
                  return;
                }
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
        title: Text('信息',
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
                          TextStyle(fontWeight: AppFontWeights.medium)),
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
    final color = isGroup ? const Color(0xFF6E8B5E) : const Color(0xFF5FA8D3);
    // 好友照片头像（avatar 字段若为本地路径则显示照片）
    final avatarPath = !isGroup && s.avatar.startsWith('/')
        ? s.avatar
        : '';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: ClipOval(
        child: avatarPath.isNotEmpty
            ? Image.file(File(avatarPath),
                width: 48, height: 48, fit: BoxFit.cover)
            : Center(
                child: Text(
                    isGroup
                        ? '群'
                        : (s.avatar.isEmpty
                            ? s.name.characters.first
                            : s.avatar),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isGroup ? 14 : 18,
                        fontWeight: FontWeight.w600))),
      ),
    );
  }
}