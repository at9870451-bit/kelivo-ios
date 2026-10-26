import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ChatInputOverlayLayout extends StatelessWidget {
  const ChatInputOverlayLayout({
    super.key,
    required this.topInset,
    required this.content,
    required this.bottomOverlay,
    this.topBackground,
    this.foreground,
    this.backgroundImageActive = false,
  });

  static const double _topOverlayTailHeight = 16;
  static const double _bottomOverlayFadeHeight = 180;
  // Leaves room for badges riding 12px above the composer's top edge.
  static const double _bottomOverlayTopGap = 12;

  final double topInset;
  final Widget content;
  final Widget bottomOverlay;
  final Widget? topBackground;
  final Widget? foreground;
  final bool backgroundImageActive;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(child: content),
              if (backgroundImageActive && topBackground != null)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: ClipRect(
                      clipper: _TopOverlayClipper(
                        topInset + _topOverlayTailHeight,
                      ),
                      child: _TopBackgroundFade(
                        height: topInset + _topOverlayTailHeight,
                        child: IgnorePointer(
                          key: const Key('chat-input-overlay-top-background'),
                          child: _KeyboardStableBackground(
                            child: topBackground!,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (!backgroundImageActive)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: topInset + _topOverlayTailHeight,
                  child: const _TopOverlayFade(),
                ),
              if (backgroundImageActive && topBackground != null)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: ClipRect(
                      clipper: const _BottomOverlayClipper(
                        _bottomOverlayFadeHeight,
                      ),
                      child: _BottomBackgroundFade(
                        height: _bottomOverlayFadeHeight,
                        child: IgnorePointer(
                          key: const Key(
                            'chat-input-overlay-bottom-background',
                          ),
                          child: _KeyboardStableBackground(
                            child: topBackground!,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (!backgroundImageActive)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _bottomOverlayFadeHeight,
                  child: _BottomOverlayFade(),
                ),
              if (foreground != null) Positioned.fill(child: foreground!),
            ],
          ),
        ),
        // The overlay may grow up to the top bar (an expanded composer does)
        // but never behind it.
        Positioned.fill(
          top: topInset + _bottomOverlayTopGap,
          child: Align(alignment: Alignment.bottomCenter, child: bottomOverlay),
        ),
      ],
    );
  }
}

/// Lays the chat artwork out as if the keyboard were closed, letting the extra
/// height overflow behind the IME instead of shrinking with the Scaffold body.
/// A `BoxFit.cover` background re-crops whenever its box changes height, so
/// without this the whole image visibly jumps upwards as the keyboard opens.
///
/// The inset has to come from the [View]: Scaffold strips the bottom view inset
/// off the MediaQuery it hands to its body, so reading it from MediaQuery here
/// would always yield zero. Reading it inside the [LayoutBuilder] also keeps it
/// in sync, because the body's constraints change on the very same frame.
class _KeyboardStableBackground extends StatelessWidget {
  const _KeyboardStableBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight) return child;
          final view = View.of(context);
          final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
          if (bottomInset <= 0) return child;
          final height = constraints.maxHeight + bottomInset;
          return OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: height,
            maxHeight: height,
            child: child,
          );
        },
      ),
    );
  }
}

class _TopOverlayClipper extends CustomClipper<Rect> {
  const _TopOverlayClipper(this.height);

  final double height;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width, height.clamp(0, size.height));
  }

  @override
  bool shouldReclip(_TopOverlayClipper oldClipper) {
    return height != oldClipper.height;
  }
}

class _BottomOverlayClipper extends CustomClipper<Rect> {
  const _BottomOverlayClipper(this.height);

  final double height;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
      0,
      (size.height - height).clamp(0, size.height),
      size.width,
      height.clamp(0, size.height),
    );
  }

  @override
  bool shouldReclip(_BottomOverlayClipper oldClipper) {
    return height != oldClipper.height;
  }
}

class _TopBackgroundFade extends StatelessWidget {
  const _TopBackgroundFade({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return ui.Gradient.linear(Offset.zero, Offset.zero, [const Color(0xFF000000), const Color(0xFF000000)]);
      },
      child: child,
    );
  }
}

class _BottomBackgroundFade extends StatelessWidget {
  const _BottomBackgroundFade({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return ui.Gradient.linear(Offset.zero, Offset.zero, [const Color(0xFF000000), const Color(0xFF000000)]);
      },
      child: child,
    );
  }
}

class _TopOverlayFade extends StatelessWidget {
  const _TopOverlayFade();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;

    return IgnorePointer(
      key: const Key('chat-input-overlay-top-fade'),
      child: const DecoratedBox(
          decoration: BoxDecoration(color: Colors.transparent)),
    );
  }
}

class _BottomOverlayFade extends StatelessWidget {
  const _BottomOverlayFade();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;

    return IgnorePointer(
      key: const Key('chat-input-overlay-bottom-fade'),
      child: const DecoratedBox(
          decoration: BoxDecoration(color: Colors.transparent)),
    );
  }
}
