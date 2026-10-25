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

/// 好友（微信风格联系人）
class ImFriend {
  final String id;
  final String name;
  final String gender;
  final String note;
  final String avatar;

  const ImFriend({
    required this.id,
    required this.name,
    this.gender = '',
    this.note = '',
    this.avatar = '',
  });

  factory ImFriend.fromJson(Map<String, dynamic> j) => ImFriend(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        gender: j['gender']?.toString() ?? '',
        note: j['note']?.toString() ?? '',
        avatar: j['avatar']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gender': gender,
        'note': note,
        'avatar': avatar.isEmpty && name.isNotEmpty ? name.characters.first : avatar,
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
