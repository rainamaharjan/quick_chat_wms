import 'package:flutter/material.dart';

/// Placeholder shown while the chat WebView loads.
///
/// Mirrors the QuickConnect WEB skeleton so the mobile SDK and the web widget
/// look like one product: left-aligned blocks of varying height, no bubble
/// tails, no avatars, no timestamps. Keeping the two in sync matters more than
/// guessing at a prettier shape — the real conversation replaces this, and the
/// closer the two are, the less the swap registers as a change of screen.
class ChatSkeleton extends StatefulWidget {
  const ChatSkeleton({
    super.key,
    required this.backgroundColor,
    required this.accentColor,
  });

  /// Chat background, so the skeleton sits on the same surface as the WebView.
  final Color backgroundColor;

  /// Brand colour — used for the send button in the composer, matching the
  /// real one the page draws once it loads.
  final Color accentColor;

  @override
  State<ChatSkeleton> createState() => _ChatSkeletonState();
}

class _ChatSkeletonState extends State<ChatSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  /// The web skeleton's block run, as (height, width fraction). Proportions are
  /// taken from the web widget: a short banner, a tall card, three equal short
  /// rows, a wider row, then a medium card.
  static const List<_SkeletonBlock> _blocks = [
    _SkeletonBlock(height: 40, widthFactor: 1.00),
    _SkeletonBlock(height: 124, widthFactor: 1.00),
    _SkeletonBlock(height: 20, widthFactor: 0.60),
    _SkeletonBlock(height: 20, widthFactor: 0.60),
    _SkeletonBlock(height: 20, widthFactor: 0.60),
    _SkeletonBlock(height: 19, widthFactor: 0.80),
    _SkeletonBlock(height: 63, widthFactor: 0.90),
  ];

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  /// Whether the chat surface is light, so the placeholders can be a shade off
  /// the background instead of guessing a fixed grey.
  bool get _isLightSurface => widget.backgroundColor.computeLuminance() > 0.5;

  Color get _baseColor => _isLightSurface
      ? const Color(0xFFF0F0F0)
      : Colors.white.withValues(alpha: 0.07);

  Color get _highlightColor => _isLightSurface
      ? const Color(0xFFFAFAFA)
      : Colors.white.withValues(alpha: 0.14);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _shimmer,
              builder: (context, child) {
                // Sweep a highlight band across the whole column, so the blocks
                // shimmer as one surface rather than each animating on its own.
                final double slide = _shimmer.value * 2 - 1;
                return ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      colors: [_baseColor, _highlightColor, _baseColor],
                      stops: const [0.35, 0.5, 0.65],
                      begin: Alignment(slide - 1, -0.3),
                      end: Alignment(slide + 1, 0.3),
                    ).createShader(bounds);
                  },
                  child: child,
                );
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final _SkeletonBlock block in _blocks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: block.widthFactor,
                          child: Container(
                            height: block.height,
                            decoration: BoxDecoration(
                              color: _baseColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  /// The message composer, which the real page also shows straight away — so
  /// the bottom of the screen doesn't sit empty while the conversation loads.
  /// Not shimmered: it's chrome, not content being waited on.
  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        border: Border(
          top: BorderSide(
            color: _isLightSurface
                ? const Color(0xFFEAEAEA)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attach_file,
            size: 20,
            color: _isLightSurface
                ? const Color(0xFFBDBDBD)
                : Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: _baseColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: widget.accentColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock {
  const _SkeletonBlock({required this.height, required this.widthFactor});

  final double height;
  final double widthFactor;
}
