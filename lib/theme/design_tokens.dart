import 'package:flutter/material.dart';

/// Apple Liquid Glass 设计规范 — Design Tokens
///
/// 统一控制全局玻璃效果、阴影、圆角与间距，避免硬编码样式。
class AppShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  /// 普通卡片：黑 4% / 12px / y3
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
  ];

  /// 重点卡片：黑 5% / 16px / y4
  static const List<BoxShadow> cardProminent = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// 顶部导航：黑 5% / 18px / y5
  static const List<BoxShadow> topBar = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 18,
      offset: Offset(0, 5),
    ),
  ];

  /// 底部悬浮导航：黑 7% / 24px / y8
  static const List<BoxShadow> bottomBar = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// AI 输入面板：黑 6% / 20px / y5
  static const List<BoxShadow> inputPanel = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 20,
      offset: Offset(0, 5),
    ),
  ];

  /// 弹出菜单：黑 8% / 22px / y8
  static const List<BoxShadow> popover = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
  ];
}

/// 液态玻璃参数规范。
///
/// 所有玻璃组件统一使用这些数值：真实背景模糊 + 白色半透明 + 细边框。
class AppGlass {
  /// 玻璃面板白色透明度
  static const double whiteOpacity = 0.85;

  /// 背景模糊半径（px）
  static const double blur = 30;

  /// 边框白色透明度
  static const double borderOpacity = 0.65;

  /// 边框宽度（px）
  static const double borderWidth = 0.5;

  /// 输入面板圆角
  static const double panelRadius = 26;

  /// 底部导航圆角
  static const double navRadius = 28;

  /// 弹出面板圆角
  static const double sheetRadius = 24;

  /// 把当前配色转成玻璃背景色（light=白 85%，dark=深灰玻璃）
  static Color background(ColorScheme cs, {double opacity = whiteOpacity}) {
    return cs.brightness == Brightness.dark
        ? const Color(0xFF1C1C1E).withValues(alpha: opacity.clamp(0, 1))
        : Colors.white.withValues(alpha: opacity);
  }

  /// 玻璃细边框色（light=白 65%，dark=白 12%）
  static Color border(ColorScheme cs) {
    return cs.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: borderOpacity);
  }
}

/// 共享桌面弹层 wash。Alpha 与旧每弹层字面量保持一致。
class AppOverlayColors {
  static const double desktopPopoverAlphaDark = 0.28;
  static const double desktopPopoverAlphaLight = 0.56;

  static Color desktopPopoverSurface(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    return cs.surface.withValues(
      alpha: isDark ? desktopPopoverAlphaDark : desktopPopoverAlphaLight,
    );
  }
}

/// 统一圆角规范（8pt 间距体系）
class AppRadii {
  /// 普通按钮
  static const double button = 14;

  /// 输入框
  static const double input = 26;

  /// 普通卡片
  static const double card = 20;

  /// 重点卡片
  static const double cardProminent = 24;

  /// 玻璃导航栏
  static const double capsule = 28;

  /// 弹出面板
  static const double sheet = 24;

  /// 悬浮操作按钮 = 圆形（直径见具体使用处）
}

/// 统一间距规范（8pt 体系）
class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double page = 20; // 页面左右边距
  static const double message = 12; // 消息段落间距
  static const double section = 24; // 大区块间距
}