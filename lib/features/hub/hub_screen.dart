import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/rainbow_title.dart';
import '../../services/sound_service.dart';
import 'game_catalog.dart';

/// The PlayPals home: a swipeable shelf of game cards. The middle card is
/// the chosen one, and the details and Play button below follow it.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  static const _games = GameCatalog.games;

  /// How much of the screen width the middle card takes. The rest shows
  /// the edges of its neighbours, which hints that the shelf swipes.
  static const _cardShare = 0.66;

  final _pages = PageController(viewportFraction: _cardShare);
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  GameInfo get _game => _games[_index];

  void _showGame(int index) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: AppDurations.slow,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _play(GameInfo game) {
    final route = game.route;
    if (route != null) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Cards are 3:4. They shrink on short screens so the Play button
          // stays in view, but never below a readable size.
          final fullHeight =
              constraints.maxWidth * _cardShare * 4 / 3 + _ShelfCard._crownRoom;
          final tallest = math.max(180.0, constraints.maxHeight * 0.52);
          final shelfHeight = math.min(fullHeight, tallest);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - AppSpacing.md * 2,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Entrance(child: _Header(onSettings: _openSettings)),
                  const SizedBox(height: AppSpacing.md),
                  Entrance(
                    index: 1,
                    fromScale: 0.85,
                    child: SizedBox(
                      height: shelfHeight,
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: _games.length,
                        onPageChanged: (index) {
                          // A flick for every game that reaches the middle.
                          playSoundFrom(context, GameSound.swipe);
                          setState(() => _index = index);
                        },
                        itemBuilder: (context, index) => _ShelfCard(
                          game: _games[index],
                          index: index,
                          pages: _pages,
                          onTap: () => index == _index
                              ? _play(_games[index])
                              : _showGame(index),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Dots(count: _games.length, index: _index),
                  const SizedBox(height: AppSpacing.sm),
                  Entrance(
                    index: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: _GameDetails(
                        game: _game,
                        onPlay: () => _play(_game),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSettings() {
    playSoundFrom(context, GameSound.tap);
    context.push(AppRoutes.settings);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RainbowTitle(
                    AppStrings.appName,
                    style: AppText.display,
                    outlineWidth: 3,
                  ),
                ),
                Text(AppStrings.tagline, style: AppText.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            elevation: 1,
            child: IconButton(
              tooltip: 'Settings',
              iconSize: 28,
              constraints: const BoxConstraints(
                minWidth: AppSizes.minTapTarget,
                minHeight: AppSizes.minTapTarget,
              ),
              color: AppColors.navy,
              onPressed: onSettings,
              icon: const Icon(Icons.settings_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

/// One card on the shelf. The middle card wears a bouncing crown and has
/// sparkles around it. Side cards shrink, fade and turn inward like a
/// fan, all following the swipe.
class _ShelfCard extends StatelessWidget {
  const _ShelfCard({
    required this.game,
    required this.index,
    required this.pages,
    required this.onTap,
  });

  /// Room above the card for the crown to sit on its top edge.
  static const _crownRoom = 30.0;

  /// How far, in radians, a side card turns. About 17 degrees.
  static const _tilt = 0.3;

  final GameInfo game;
  final int index;
  final PageController pages;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Each card repaints alone while the shelf moves.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: pages,
        builder: (context, _) {
          final page = pages.hasClients && pages.position.haveDimensions
              ? pages.page ?? pages.initialPage.toDouble()
              : pages.initialPage.toDouble();
          // Negative for cards left of the middle, positive for the right.
          final offset = (index - page).clamp(-1.0, 1.0);
          final distance = offset.abs();
          // 1 for the middle card, falling to 0 one card away.
          final focus = 1 - distance;

          return Opacity(
            opacity: 1 - distance * 0.35,
            child: Transform(
              alignment: Alignment.center,
              // A little perspective makes the turn look three-dimensional.
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(-offset * _tilt)
                ..scaleByDouble(1 - distance * 0.14, 1 - distance * 0.14, 1, 1),
              child: _card(focus),
            ),
          );
        },
      ),
    );
  }

  Widget _card(double focus) {
    return Semantics(
      button: true,
      label: game.isPlayable ? game.name : '${game.name}, coming soon',
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            _crownRoom,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Center(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x401B2A5B),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card - 4),
                      child: Image.asset(
                        game.picture,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  if (!game.isPlayable)
                    const Positioned(
                      bottom: AppSpacing.sm,
                      left: 0,
                      right: 0,
                      child: Center(child: _SoonBadge()),
                    ),
                  // Sparkles and the crown fade in as the card reaches the
                  // middle.
                  if (focus > 0) ...[
                    Positioned(
                      top: -14,
                      left: -12,
                      child: _Sparkle(size: 26, opacity: focus),
                    ),
                    Positioned(
                      bottom: 28,
                      right: -14,
                      child: _Sparkle(size: 20, opacity: focus),
                    ),
                    Positioned(
                      top: -_crownRoom,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Opacity(
                          opacity: focus,
                          child: const _BouncingCrown(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: SvgPicture.asset(AppAssets.star, width: size),
      ),
    );
  }
}

/// A crown that bobs gently on top of the chosen card. It stays still when
/// the phone asks for reduced motion.
class _BouncingCrown extends StatefulWidget {
  const _BouncingCrown();

  @override
  State<_BouncingCrown> createState() => _BouncingCrownState();
}

class _BouncingCrownState extends State<_BouncingCrown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _bob,
    curve: Curves.easeInOut,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _bob
        ..stop()
        ..value = 0.5;
    } else if (!_bob.isAnimating) {
      _bob.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Bobbing redraws only the crown.
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _curve,
          child: SvgPicture.asset(AppAssets.crown, height: 40),
          builder: (context, crown) {
            final lift = (_curve.value - 0.5) * 8;
            return Transform.translate(
              offset: Offset(0, lift),
              child: Transform.rotate(
                angle: (_curve.value - 0.5) * 0.12,
                child: crown,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.sunshine,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.navy, width: 2),
      ),
      child: Text(
        'Coming soon',
        style: AppText.bodySmall,
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}

/// A row of dots, with the current game's dot stretched wide.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Game ${index + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var dot = 0; dot < count; dot++)
            AnimatedContainer(
              duration: reduceMotion ? Duration.zero : AppDurations.medium,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: dot == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: dot == index ? AppColors.navy : AppColors.navySoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
        ],
      ),
    );
  }
}

/// The chosen game's name, what it's like and how to start it.
class _GameDetails extends StatelessWidget {
  const _GameDetails({required this.game, required this.onPlay});

  final GameInfo game;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: reduceMotion ? Duration.zero : AppDurations.medium,
          child: Column(
            key: ValueKey(game.id),
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  game.name,
                  textAlign: TextAlign.center,
                  style: AppText.title,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                game.tagline,
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    game.devices == GameDevices.onePhone
                        ? Icons.smartphone_rounded
                        : Icons.groups_rounded,
                    color: AppColors.navy,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    child: Text(game.devices.label, style: AppText.bodySmall),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GameButton(
          label: game.isPlayable ? 'Play' : 'Coming soon',
          icon: game.isPlayable
              ? Icons.play_arrow_rounded
              : Icons.hourglass_top_rounded,
          onPressed: game.isPlayable ? onPlay : null,
        ),
      ],
    );
  }
}
