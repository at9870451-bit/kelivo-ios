import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' as ui;

import '../../../l10n/app_localizations.dart';
import '../../settings/pages/settings_page.dart';
import '../../im/pages/im_session_list_page.dart';
import '../../../shared/widgets/interactive_drawer.dart';
import '../widgets/side_drawer.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../shared/animations/widgets.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../chat/widgets/frosted/chat_frosted_backdrop.dart';
import '../../chat/widgets/chat_assistant_background.dart';
import '../widgets/assistant_avatar.dart';
import '../widgets/assistant_entry_actions.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

/// Mobile layout scaffold for the home page
/// This widget handles only the structural layout - AppBar, drawer, body structure
/// All message list rendering and input bar logic remain in home_page.dart
class HomeMobileScaffold extends StatefulWidget {
  const HomeMobileScaffold({
    super.key,
    required this.scaffoldKey,
    required this.drawerController,
    required this.assistantPickerCloseTick,
    required this.loadingConversationIds,
    required this.title,
    required this.providerName,
    required this.modelDisplay,
    required this.onToggleDrawer,
    required this.onDismissKeyboard,
    required this.onSelectConversation,
    required this.onNewConversation,
    required this.onOpenMiniMap,
    required this.onCreateNewConversation,
    required this.onToggleTemporaryConversation,
    required this.onSelectModel,
    required this.canToggleTemporaryConversation,
    required this.temporaryConversationEnabled,
    required this.globalSearchMode,
    required this.globalSearchQuery,
    required this.onGlobalSearchQueryChanged,
    required this.onEnterGlobalSearch,
    required this.onExitGlobalSearch,
    required this.onOpenGlobalSearchResult,
    this.appBarOverride,
    required this.body,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final InteractiveDrawerController drawerController;
  final ValueNotifier<int> assistantPickerCloseTick;
  final Set<String> loadingConversationIds;
  final String title;
  final String? providerName;
  final String? modelDisplay;
  final VoidCallback onToggleDrawer;
  final VoidCallback onDismissKeyboard;
  final void Function(String id) onSelectConversation;
  final VoidCallback onNewConversation;
  final VoidCallback onOpenMiniMap;
  final Future<void> Function() onCreateNewConversation;
  final Future<void> Function() onToggleTemporaryConversation;
  final VoidCallback onSelectModel;
  final bool canToggleTemporaryConversation;
  final bool temporaryConversationEnabled;
  final bool globalSearchMode;
  final String globalSearchQuery;
  final ValueChanged<String> onGlobalSearchQueryChanged;
  final VoidCallback onEnterGlobalSearch;
  final VoidCallback onExitGlobalSearch;
  final Future<void> Function(String conversationId, String messageId)
  onOpenGlobalSearchResult;
  final PreferredSizeWidget? appBarOverride;
  final Widget body;

  @override
  State<HomeMobileScaffold> createState() => _HomeMobileScaffoldState();
}

/// 底部导航状态：0 = 聊天主界面，1 = UI 设置
class _HomeMobileScaffoldState extends State<HomeMobileScaffold> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return InteractiveDrawer(
      controller: widget.drawerController,
      side: DrawerSide.left,
      drawerWidth: MediaQuery.sizeOf(context).width * 0.75,
      scrimColor: cs.onSurface,
      maxScrimOpacity: 0.12,
      barrierDismissible: true,
      drawer: SideDrawer(
        userName: context.watch<UserProvider>().name,
        assistantName: _getAssistantName(context),
        closePickerTicker: widget.assistantPickerCloseTick,
        loadingConversationIds: widget.loadingConversationIds,
        globalSearchMode: widget.globalSearchMode,
        globalSearchQuery: widget.globalSearchQuery,
        onGlobalSearchQueryChanged: widget.onGlobalSearchQueryChanged,
        onEnterGlobalSearch: widget.onEnterGlobalSearch,
        onExitGlobalSearch: widget.onExitGlobalSearch,
        onOpenGlobalSearchResult: (conversationId, messageId) async {
          await widget.onOpenGlobalSearchResult(conversationId, messageId);
          widget.drawerController.close();
        },
        onSelectConversation: (id, {closeDrawer = true}) {
          widget.onSelectConversation(id);
          if (closeDrawer) widget.drawerController.close();
        },
        onNewConversation: ({closeDrawer = true}) async {
          await widget.onCreateNewConversation();
          if (closeDrawer) widget.drawerController.close();
        },
      ),
      child: ChatFrostedBackdrop(
        backdrop: const MobileBackgroundLayer(),
        child: Scaffold(
          key: widget.scaffoldKey,
          resizeToAvoidBottomInset: true,
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: widget.appBarOverride ?? _buildAppBar(context, cs),
          // 底部导航栏：消息(IM) / 聊天 / 设置
          body: switch (_tab) {
            0 => const ImSessionListPage(),
            1 => widget.body,
            _ => const SettingsPage(embedded: true),
          },
          bottomNavigationBar: _GlassNavBar(
            selectedIndex: _tab,
            onSelect: (i) => setState(() => _tab = i),
            labels: ['消息', '聊天', l10n.settingsPageTitle],
            icons: const [
              Icons.message_outlined,
              Icons.chat_bubble_outline_rounded,
              Icons.settings_outlined,
            ],
            selectedIcons: const [
              Icons.message_rounded,
              Icons.chat_bubble_rounded,
              Icons.settings_rounded,
            ],
          ),
        ),
      ),
    );
  }

  String _getAssistantName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final a = context.watch<AssistantProvider>().currentAssistant;
    final n = a?.name.trim();
    return (n == null || n.isEmpty) ? l10n.homePageDefaultAssistant : n;
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ColorScheme cs) {
    final isDesktopPlatform =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final useNewAssistantAvatarUx = context
        .watch<SettingsProvider>()
        .useNewAssistantAvatarUx;

    return AppBar(
      systemOverlayStyle: (Theme.of(context).brightness == Brightness.dark)
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Builder(
        builder: (context) {
          return IosIconButton(
            size: 20,
            padding: const EdgeInsets.all(8),
            minSize: 40,
            builder: (color) => SvgPicture.asset(
              'assets/icons/list.svg',
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            onTap: () {
              widget.onDismissKeyboard();
              widget.onToggleDrawer();
            },
          );
        },
      ),
      titleSpacing: 2,
      title: useNewAssistantAvatarUx
          ? Row(
              children: [
                _buildAssistantTitleAvatar(context),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedTextSwap(
                        text: widget.title,
                        style: TextStyle(
                          fontSize: isDesktopPlatform ? 14 : 16,
                          fontWeight: AppFontWeights.medium,
                        ),
                      ),
                      if (widget.providerName != null && widget.modelDisplay != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: widget.onSelectModel,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              child: AnimatedTextSwap(
                                text: '$widget.modelDisplay ($widget.providerName)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                  fontWeight: AppFontWeights.medium,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedTextSwap(
                  text: widget.title,
                  style: TextStyle(
                    fontSize: isDesktopPlatform ? 14 : 16,
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
                if (widget.providerName != null && widget.modelDisplay != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: widget.onSelectModel,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        child: AnimatedTextSwap(
                          text: '$widget.modelDisplay ($widget.providerName)',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.6),
                            fontWeight: AppFontWeights.medium,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      actions: [
        IosIconButton(
          size: 20,
          minSize: 44,
          onTap: widget.onOpenMiniMap,
          semanticLabel: AppLocalizations.of(context)!.miniMapTooltip,
          icon: Lucide.Map,
        ),
        IosIconButton(
          size: 22,
          minSize: 44,
          onTap: () async {
            if (widget.canToggleTemporaryConversation) {
              await widget.onToggleTemporaryConversation();
            } else {
              await widget.onCreateNewConversation();
            }
          },
          semanticLabel: widget.canToggleTemporaryConversation
              ? AppLocalizations.of(context)!.temporaryChatToggleTooltip
              : AppLocalizations.of(context)!.titleForLocale,
          icon: widget.canToggleTemporaryConversation && !widget.temporaryConversationEnabled
              ? Lucide.MessageCircleDashed
              : Lucide.MessageCirclePlus,
          builder:
              widget.canToggleTemporaryConversation && widget.temporaryConversationEnabled
              ? (color) => SvgPicture.asset(
                  'assets/icons/temporary_chat_checked.svg',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                )
              : null,
        ),

        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildAssistantTitleAvatar(BuildContext context) {
    final assistantProvider = context.watch<AssistantProvider>();
    final currentAssistant = assistantProvider.currentAssistant;
    final currentAssistantId = assistantProvider.currentAssistantId;

    return IosCardPress(
      borderRadius: BorderRadius.circular(999),
      baseColor: Colors.transparent,
      padding: const EdgeInsets.all(2),
      longPressTimeout: const Duration(milliseconds: 280),
      onTap: () {
        widget.onDismissKeyboard();
        widget.onToggleDrawer();
      },
      onLongPress: currentAssistantId == null
          ? null
          : () {
              Haptics.light();
              AssistantEntryActions.openAssistantSettings(
                context,
                currentAssistantId,
              );
            },
      child: AssistantAvatar(
        assistant: currentAssistant,
        fallbackName: _getAssistantName(context),
        size: 28,
      ),
    );
  }
}

/// Mobile background widget with assistant-specific image and gradient overlay
class MobileBackgroundLayer extends StatelessWidget {
  const MobileBackgroundLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatAssistantBackground();
  }
}

/// Scroll navigation buttons (scroll to bottom + scroll to previous message)
class ScrollNavigationButtons extends StatelessWidget {
  const ScrollNavigationButtons({
    super.key,
    required this.showJumpToBottom,
    required this.inputBarHeight,
    required this.hasMessages,
    required this.onScrollToBottom,
    required this.onScrollToPreviousQuestion,
  });

  final bool showJumpToBottom;
  final double inputBarHeight;
  final bool hasMessages;
  final VoidCallback onScrollToBottom;
  final VoidCallback onScrollToPreviousQuestion;

  @override
  Widget build(BuildContext context) {
    final showSetting = context.watch<SettingsProvider>().showMessageNavButtons;
    if (!showSetting || !hasMessages) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomOffset = inputBarHeight + 12;

    return Stack(
      children: [
        // Scroll to bottom button
        Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(
            top: false,
            bottom: false,
            child: IgnorePointer(
              ignoring: !showJumpToBottom,
              child: AnimatedScale(
                scale: showJumpToBottom ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  opacity: showJumpToBottom ? 1 : 0,
                  child: Padding(
                    padding: EdgeInsets.only(right: 16, bottom: bottomOffset),
                    child: _ScrollButton(
                      isDark: isDark,
                      icon: Lucide.ChevronDown,
                      onTap: onScrollToBottom,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Scroll to previous message button
        Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(
            top: false,
            bottom: false,
            child: IgnorePointer(
              ignoring: !showJumpToBottom,
              child: AnimatedScale(
                scale: showJumpToBottom ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  opacity: showJumpToBottom ? 1 : 0,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: 16,
                      bottom: bottomOffset + 52,
                    ),
                    child: _ScrollButton(
                      isDark: isDark,
                      icon: Lucide.ChevronUp,
                      onTap: onScrollToPreviousQuestion,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrollButton extends StatelessWidget {
  const _ScrollButton({
    required this.isDark,
    required this.icon,
    required this.onTap,
  });

  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? cs.onSurface.withValues(alpha: 0.06)
                : cs.surface.withValues(alpha: 0.07),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? cs.onSurface.withValues(alpha: 0.10)
                  : cs.outline.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  icon,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: isDark ? 1.0 : 0.87),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selection mode toolbar overlay
class SelectionToolbarOverlay extends StatelessWidget {
  const SelectionToolbarOverlay({
    super.key,
    required this.visible,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool visible;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 122),
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: !visible,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GlassCircleButton(
                      icon: Lucide.X,
                      color: cs.onSurface,
                      onTap: onCancel,
                      semanticLabel: l10n.homePageCancel,
                    ),
                    const SizedBox(width: 14),
                    _GlassCircleButton(
                      icon: Lucide.Check,
                      color: cs.primary,
                      onTap: onConfirm,
                      semanticLabel: l10n.homePageDone,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatefulWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final glassBase = cs.surface.withValues(alpha: 0.06);
    final overlay = cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.05);
    final tileColor = _pressed
        ? Color.alphaBlend(overlay, glassBase)
        : glassBase;
    final borderColor = cs.outlineVariant.withValues(alpha: 0.10);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tileColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.0),
                ),
                child: Center(
                  child: Icon(widget.icon, size: 18, color: widget.color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// 🪟 Liquid Glass 底部导航栏：悬浮毛玻璃——26px 背景模糊 + 半透明白 78% +
/// 白色细边框 + 圆角 26 + 上投轻阴影 + 胶囊形选中态（系统蓝 12% 底）+ SafeArea
class _GlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData> selectedIcons;

  const _GlassNavBar({
    required this.selectedIndex,
    required this.onSelect,
    required this.labels,
    required this.icons,
    required this.selectedIcons,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF101725).withValues(alpha: 0.86)
                  : Colors.white.withValues(alpha: 0.78),
              // 细腻白色边框
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.75),
              ),
              // 上投轻阴影（悬浮感）
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          // 胶囊形选中态：系统蓝 12% 底
                          color: i == selectedIndex
                              ? cs.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              i == selectedIndex
                                  ? selectedIcons[i]
                                  : icons[i],
                              size: 22,
                              color: i == selectedIndex
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: i == selectedIndex
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: i == selectedIndex
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
