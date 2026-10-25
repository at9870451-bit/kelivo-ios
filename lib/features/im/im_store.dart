// KelivoStore — Rust Core 数据层封装（会话/消息/数据处理/安全模块）
import 'im_bridge.dart';

class ImMessage {
  final int id;
  final bool mine; // true=自己发送（蓝色气泡）
  final String content;
  final double ts;
  final bool read; // 已读状态

  const ImMessage({
    required this.id,
    required this.mine,
    required this.content,
    required this.ts,
    required this.read,
  });

  factory ImMessage.fromJson(Map<String, dynamic> j) => ImMessage(
        id: (j['id'] as num?)?.toInt() ?? 0,
        mine: (j['role']?.toString() ?? 'user') == 'user',
        content: j['content']?.toString() ?? '',
        ts: (j['ts'] as num?)?.toDouble() ?? 0,
        read: j['read'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': mine ? 'user' : 'assistant',
        'content': content,
        'ts': ts,
        'read': read,
      };
}

class ImSession {
  final String id;
  final String name;
  final String kind; // friend / group
  final String avatar;
  final String last;
  final double ts;

  const ImSession({
    required this.id,
    required this.name,
    required this.kind,
    required this.avatar,
    required this.last,
    required this.ts,
  });

  factory ImSession.fromJson(Map<String, dynamic> j) => ImSession(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        kind: j['kind']?.toString() ?? 'friend',
        avatar: j['avatar']?.toString() ?? '',
        last: j['last']?.toString() ?? '',
        ts: (j['ts'] as num?)?.toDouble() ?? 0,
      );
}

class KelivoStore {
  KelivoStore._();

  static bool _inited = false;

  static void init(String dataDir) {
    if (_inited) return;
    KelivoBridge.call('core.init', {'data_dir': dataDir});
    _inited = true;
  }

  // ---- 会话 ----
  static List<ImSession> sessions() {
    final r = KelivoBridge.call('store.sessions', {});
    return (r['sessions'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ImSession.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<ImMessage> messages(String key) {
    final r = KelivoBridge.call('store.messages', {'key': key});
    return (r['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ImMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static int seedDemo() {
    final r = KelivoBridge.call('store.seed_demo', {});
    return (r['seeded'] as num?)?.toInt() ?? 0;
  }

  static int append(String key, String role, String content) {
    final r = KelivoBridge.call('store.append', {
      'key': key,
      'role': role,
      'content': content,
    });
    return (r['count'] as num?)?.toInt() ?? 0;
  }

  static int replace(String key, List<ImMessage> msgs) {
    final r = KelivoBridge.call('store.replace', {
      'key': key,
      'messages': msgs.map((m) => m.toJson()).toList(),
    });
    return (r['count'] as num?)?.toInt() ?? 0;
  }

  static int remove(String key, int id) {
    final r = KelivoBridge.call('store.remove', {'key': key, 'id': id});
    return (r['count'] as num?)?.toInt() ?? 0;
  }

  static int clear(String key) {
    final r = KelivoBridge.call('store.clear', {'key': key});
    return (r['count'] as num?)?.toInt() ?? 0;
  }

  // ---- 数据处理（Rust）----
  static Map<String, dynamic> textStats(String text) =>
      KelivoBridge.call('util.text_stats', {'text': text});

  static String eval(String expr) {
    final r = KelivoBridge.call('util.eval', {'expr': expr});
    return (r['value'] ?? r['error'] ?? '').toString();
  }

  // ---- 安全模块（Rust）----
  static String sha256(String data) =>
      KelivoBridge.call('crypto.sha256', {'data': data})['sha256'] as String;

  static String blake2s(String data) =>
      KelivoBridge.call('crypto.blake2s', {'data': data})['blake2s'] as String;

  static String crc32(String data) =>
      KelivoBridge.call('crypto.crc32', {'data': data})['crc32'] as String;
}

/// 好友（微信风格联系人：头像 emoji+颜色 / 性别 / 年龄 / 人设 / 语音模型）
class ImFriend {
  final String id;
  final String name;
  final String gender;
  final String age;
  final String note;
  final String persona;
  final String voiceEngine;
  final String voiceId;
  final String avatar;
  final int avatarColor;
  final String avatarPath; // 本地照片头像路径（空=用 emoji/文字）
  final List<String> memory; // 长期记忆
  final String model; // 专属模型（空=全局）
  final bool localTools; // 本地工具开关

  const ImFriend({
    required this.id,
    required this.name,
    this.gender = '',
    this.age = '',
    this.note = '',
    this.persona = '',
    this.voiceEngine = '',
    this.voiceId = '',
    this.avatar = '',
    this.avatarColor = 0xFF5FA8D3,
    this.avatarPath = '',
    List<String>? memory,
    this.model = '',
    this.localTools = true,
  }) : memory = memory ?? const [];

  factory ImFriend.fromJson(Map<String, dynamic> j) => ImFriend(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        gender: j['gender']?.toString() ?? '',
        age: j['age']?.toString() ?? '',
        note: j['note']?.toString() ?? '',
        persona: j['persona']?.toString() ?? '',
        voiceEngine: j['voiceEngine']?.toString() ?? '',
        voiceId: j['voiceId']?.toString() ?? '',
        avatar: j['avatar']?.toString() ?? '',
        avatarColor: (j['avatarColor'] as num?)?.toInt() ?? 0xFF5FA8D3,
        avatarPath: j['avatarPath']?.toString() ?? '',
        memory: (j['memory'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        model: j['model']?.toString() ?? '',
        localTools: j['localTools'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gender': gender,
        'age': age,
        'note': note,
        'persona': persona,
        'voiceEngine': voiceEngine,
        'voiceId': voiceId,
        'avatar': avatar.isEmpty && name.isNotEmpty
            ? String.fromCharCode(name.runes.first)
            : avatar,
        'avatarColor': avatarColor,
        'avatarPath': avatarPath,
        'memory': memory,
        'model': model,
        'localTools': localTools,
      };
}

/// 群组
class ImGroup {
  final String id;
  final String name;
  final List<String> memberIds;

  const ImGroup({required this.id, required this.name, this.memberIds = const []});

  factory ImGroup.fromJson(Map<String, dynamic> j) => ImGroup(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        memberIds: (j['memberIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'memberIds': memberIds,
      };
}

// ---- 联系人 API（Rust 存储）----
extension KelivoContacts on KelivoStore {
  static List<ImFriend> friends() {
    final r = KelivoBridge.call('contacts.friends', {});
    return (r['friends'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ImFriend.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static int saveFriend(ImFriend f) {
    final r = KelivoBridge.call('contacts.save_friend', {'friend': f.toJson()});
    return (r['count'] as num?)?.toInt() ?? 0;
  }

  static int deleteFriend(String id) {
    final r = KelivoBridge.call('contacts.delete_friend', {'id': id});
    return (r['count'] as num?)?.toInt() ?? 0;
  }

  static List<ImGroup> groups() {
    final r = KelivoBridge.call('contacts.groups', {});
    return (r['groups'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ImGroup.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static int saveGroup(ImGroup g) {
    final r = KelivoBridge.call('contacts.save_group', {'group': g.toJson()});
    return (r['count'] as num?)?.toInt() ?? 0;
  }

  static int deleteGroup(String id) {
    final r = KelivoBridge.call('contacts.delete_group', {'id': id});
    return (r['count'] as num?)?.toInt() ?? 0;
  }
}
