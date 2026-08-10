import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'themes_api.dart';
import 'themes_provider.dart';
import 'theme_edit_screen.dart';
import '../../core/network/api_exception.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/tap_scale.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import '../../shared/widgets/swipe_confirm_sheet.dart';
import '../../shared/widgets/success_pulse.dart';

Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final value = int.tryParse(h, radix: 16);
  if (value == null) return null;
  return Color(value);
}

class ThemesScreen extends ConsumerStatefulWidget {
  const ThemesScreen({super.key});

  @override
  ConsumerState<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends ConsumerState<ThemesScreen> {
  bool _busyDeactivate = false;

  Future<void> _openNew() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const ThemeEditScreen(theme: null)),
    );
    ref.invalidate(themesProvider);
  }

  Future<void> _openEdit(SiteTheme theme) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => ThemeEditScreen(theme: theme)),
    );
    ref.invalidate(themesProvider);
  }

  Future<void> _deactivate() async {
    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: Icons.brightness_low_outlined,
      color: AppColors.cumin,
      message: const Text(
        'Revert to the default site look? Coupons linked to the active '
        'theme will also turn off.',
      ),
      swipeLabel: 'Slide to deactivate',
    );
    if (!confirmed) return;

    setState(() => _busyDeactivate = true);
    try {
      await ref.read(themesApiProvider).deactivate();
      Haptics.success();
      ref.invalidate(themesProvider);
      if (mounted) await SuccessPulse.show(context, 'Reverted to default look');
    } on ApiException catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busyDeactivate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themesAsync = ref.watch(themesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Site Themes')),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: LayoutConstants.fabScaffoldExtraPadding,
        ),
        child: FloatingActionButton.extended(
          onPressed: _openNew,
          icon: const Icon(Icons.add),
          label: const Text('New Theme'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(themesProvider),
        child: themesAsync.when(
          data: (themes) {
            final active = themes.where((t) => t.isActive).firstOrNull;
            final others = themes.where((t) => !t.isActive).toList();

            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                LayoutConstants.navBarClearance +
                    LayoutConstants.fabScaffoldExtraPadding,
              ),
              children: [
                _ActiveThemeHero(
                  active: active,
                  busy: _busyDeactivate,
                  onDeactivate: _deactivate,
                  onTap: active == null ? null : () => _openEdit(active),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'All Themes',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (others.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        active == null
                            ? 'No themes yet — create one to get started.'
                            : 'No other themes yet.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...List.generate(others.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: StaggeredFadeIn(
                        key: ValueKey('theme_fade_${others[i].id}'),
                        index: i,
                        child: _ThemeTile(
                          key: ValueKey('theme_${others[i].id}'),
                          theme: others[i],
                          onTap: () => _openEdit(others[i]),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load themes: $e')),
        ),
      ),
    );
  }
}

class _ActiveThemeHero extends StatelessWidget {
  final SiteTheme? active;
  final bool busy;
  final VoidCallback onDeactivate;
  final VoidCallback? onTap;
  const _ActiveThemeHero({
    required this.active,
    required this.busy,
    required this.onDeactivate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = active;
    final accent = theme == null
        ? const Color(0xFF8A97A3)
        : (parseHexColor(theme.colors['maroon']) ?? AppColors.maroon);

    return TapScale(
      onTap: onTap,
      scaleDown: 0.99,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.16),
              accent.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    theme == null
                        ? Icons.brightness_auto_outlined
                        : Icons.auto_awesome,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme == null ? 'Default site look' : theme.name,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        theme == null
                            ? 'No seasonal theme is active right now.'
                            : 'Live on the storefront now',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (theme != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in themeColorKeys)
                    if (theme.colors[key] != null)
                      _Swatch(hex: theme.colors[key]!, label: key),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (theme.discountPercent != null)
                    _InfoChip(
                      icon: Icons.percent,
                      label: '${theme.discountPercent}% off',
                      color: accent,
                    ),
                  if (theme.bannerEnabled)
                    _InfoChip(
                      icon: Icons.campaign_outlined,
                      label: 'Banner on',
                      color: accent,
                    ),
                  if (theme.couponCode != null)
                    _InfoChip(
                      icon: Icons.sell_outlined,
                      label: theme.couponCode!,
                      color: accent,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onDeactivate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                  ),
                  icon: busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.error,
                          ),
                        )
                      : const Icon(Icons.brightness_low_outlined, size: 18),
                  label: Text(busy ? 'Reverting…' : 'Revert to Default'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final SiteTheme theme;
  final VoidCallback onTap;
  const _ThemeTile({super.key, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = parseHexColor(theme.colors['maroon']) ?? AppColors.cumin;

    return TapScale(
      scaleDown: 0.985,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.palette_outlined, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          theme.key,
                          style: TextStyle(
                            fontFamily: 'IBMPlexMono',
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (theme.discountPercent != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· ${theme.discountPercent}% off',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String hex;
  final String label;
  const _Swatch({required this.hex, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(hex) ?? Colors.grey;
    return Tooltip(
      message: '$label · $hex',
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
