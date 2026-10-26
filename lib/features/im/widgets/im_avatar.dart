// 统一 IM 头像组件：本地照片优先，否则昵称首字符/群标
// 会话列表、创建群聊选好友、聊天页 AppBar 共用，保证头像一致
import 'dart:io';

import 'package:flutter/material.dart';

class ImAvatar extends StatelessWidget {
  const ImAvatar({
    super.key,
    required this.name,
    this.avatar = '',
    this.isGroup = false,
    this.size = 48,
  });

  /// 昵称（无头像时取首字符）
  final String name;

  /// 照片本地路径（以 / 开头）或空
  final String avatar;

  final bool isGroup;
  final double size;

  /// 是否为本地照片路径
  static bool isPhotoPath(String v) =>
      v.startsWith('/') || v.startsWith('file://');

  @override
  Widget build(BuildContext context) {
    final color = isGroup ? const Color(0xFF6E8B5E) : const Color(0xFF5FA8D3);
    final photo = !isGroup && isPhotoPath(avatar) ? avatar : '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: ClipOval(
        child: photo.isNotEmpty
            ? Image.file(
                File(photo),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _text(color),
              )
            : _text(color),
      ),
    );
  }

  Widget _text(Color color) => Center(
        child: Text(
          isGroup
              ? '群'
              : (name.isEmpty ? '?' : String.fromCharCode(name.runes.first)),
          style: TextStyle(
            color: Colors.white,
            fontSize: isGroup ? size * 0.29 : size * 0.38,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
