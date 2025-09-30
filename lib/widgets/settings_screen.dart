import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/settings_service.dart';
import '../utils/i18n.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<Color> _kAccentChoices = <Color>[
    Color(0xFF6750A4),
    Color(0xFF5E60CE),
    Color(0xFF2F9FF8),
    Color(0xFF0BA5A5),
    Color(0xFF2BC760),
    Color(0xFFFFB74D),
    Color(0xFFFF7043),
    Color(0xFFFF5C93),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = SettingsController.instance;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasSeedColor = controller.seedColor != null;
        final seedColor = controller.seedColor ?? theme.colorScheme.primary;
        final languageItems = <DropdownMenuItem<Locale?>>[
          DropdownMenuItem(value: null, child: Text(I18n.t(context, 'system'))),
          const DropdownMenuItem(value: Locale('hu'), child: Text('Magyar')),
          const DropdownMenuItem(value: Locale('en'), child: Text('English')),
          const DropdownMenuItem(value: Locale('ro'), child: Text('Română')),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
          children: [
            _SettingsHeader(seedColor: seedColor),
            const SizedBox(height: 24),
            _SettingsCard(
              icon: Icons.palette_rounded,
              title: I18n.t(context, 'appearance'),
              description: I18n.t(context, 'appearance_hint'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(I18n.t(context, 'theme_mode'), style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemePreference>(
                    segments: [
                      ButtonSegment(
                        value: ThemePreference.system,
                        label: Text(I18n.t(context, 'system')),
                        icon: const Icon(Icons.settings_suggest_outlined),
                      ),
                      ButtonSegment(
                        value: ThemePreference.light,
                        label: Text(I18n.t(context, 'light')),
                        icon: const Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemePreference.dark,
                        label: Text(I18n.t(context, 'dark')),
                        icon: const Icon(Icons.nightlight_round_outlined),
                      ),
                      ButtonSegment(
                        value: ThemePreference.scheduled,
                        label: Text(I18n.t(context, 'scheduled')),
                        icon: const Icon(Icons.schedule_rounded),
                      ),
                    ],
                    selected: <ThemePreference>{controller.themePreference},
                    onSelectionChanged: (value) {
                      if (value.isEmpty) return;
                      controller.setThemePreference(value.first);
                    },
                  ),
                  if (controller.themePreference == ThemePreference.scheduled) ...[
                    const SizedBox(height: 16),
                    _ScheduleRow(
                      start: controller.scheduledStart,
                      end: controller.scheduledEnd,
                      onStartTap: () => _pickSchedule(context, controller, true),
                      onEndTap: () => _pickSchedule(context, controller, false),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(I18n.t(context, 'dynamic_color')),
                    subtitle: Text(I18n.t(context, 'dynamic_color_hint')),
                    value: controller.useDynamicColor,
                    onChanged: (value) => controller.setUseDynamicColor(value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(I18n.t(context, 'true_black')),
                    value: controller.trueBlack,
                    onChanged: (value) => controller.setTrueBlack(value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(I18n.t(context, 'high_contrast')),
                    value: controller.highContrast,
                    onChanged: (value) => controller.setHighContrast(value),
                  ),
                  const SizedBox(height: 8),
                  Text(I18n.t(context, 'accent_color'), style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _AccentChoiceChip(
                        color: seedColor,
                        label: I18n.t(context, 'accent_default'),
                        selected: !hasSeedColor,
                        onSelected: (_) => controller.setSeedColor(null),
                      ),
                      for (final color in _kAccentChoices)
                        _AccentChoiceChip(
                          color: color,
                          selected: hasSeedColor && controller.seedColor?.value == color.value,
                          onSelected: (_) => controller.setSeedColor(color),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SettingsCard(
              icon: Icons.text_snippet_rounded,
              title: I18n.t(context, 'reading_experience'),
              description: I18n.t(context, 'reading_experience_hint'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(I18n.t(context, 'text_scale'), style: theme.textTheme.titleSmall),
                  Slider(
                    value: controller.textScale,
                    min: 0.85,
                    max: 1.30,
                    divisions: 9,
                    label: controller.textScale.toStringAsFixed(2),
                    onChanged: (value) => controller.setTextScale(value),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(I18n.t(context, 'reduce_motion')),
                      Switch.adaptive(
                        value: controller.reduceMotion,
                        onChanged: (value) => controller.setReduceMotion(value),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(I18n.t(context, 'haptics')),
                      Switch.adaptive(
                        value: controller.haptics,
                        onChanged: (value) => controller.setHaptics(value),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SettingsCard(
              icon: Icons.translate_rounded,
              title: I18n.t(context, 'language'),
              description: I18n.t(context, 'language_hint'),
              child: DropdownButtonFormField<Locale?>(
                value: controller.locale,
                items: languageItems,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  labelText: I18n.t(context, 'language'),
                ),
                onChanged: (locale) => controller.setLocale(locale),
              ),
            ),
            const SizedBox(height: 24),
            _SettingsCard(
              icon: Icons.cloud_sync_rounded,
              title: I18n.t(context, 'advanced'),
              description: I18n.t(context, 'advanced_hint'),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_rounded),
                    title: Text(I18n.t(context, 'export_settings')),
                    subtitle: Text(I18n.t(context, 'export_settings_hint')),
                    onTap: () => _exportSettings(context, controller),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload_rounded),
                    title: Text(I18n.t(context, 'import_settings')),
                    subtitle: Text(I18n.t(context, 'import_settings_hint')),
                    onTap: () => _importSettings(context, controller),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restore_rounded),
                    title: Text(I18n.t(context, 'reset')),
                    subtitle: Text(I18n.t(context, 'reset_hint')),
                    onTap: () => _confirmReset(context, controller),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _pickSchedule(
    BuildContext context,
    SettingsController controller,
    bool pickStart,
  ) async {
    final initial = pickStart ? controller.scheduledStart : controller.scheduledEnd;
    final label = pickStart ? I18n.t(context, 'start_time') : I18n.t(context, 'end_time');
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: label,
    );
    if (picked == null) return;
    final start = pickStart ? picked : controller.scheduledStart;
    final end = pickStart ? controller.scheduledEnd : picked;
    await controller.setThemeSchedule(start: start, end: end);
  }

  static Future<void> _exportSettings(
    BuildContext context,
    SettingsController controller,
  ) async {
    final json = await controller.exportSettingsJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.t(context, 'settings_copied'))),
    );
  }

  static Future<void> _importSettings(
    BuildContext context,
    SettingsController controller,
  ) async {
    final controllerText = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t(context, 'import_settings')),
        content: TextField(
          controller: controllerText,
          minLines: 6,
          maxLines: 12,
          decoration: InputDecoration(hintText: I18n.t(context, 'paste_settings_hint')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(I18n.t(context, 'cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controllerText.text.trim()),
            child: Text(I18n.t(context, 'import_settings')),
          ),
        ],
      ),
    );
    controllerText.dispose();
    if (result == null || result.isEmpty) return;
    try {
      await controller.importSettingsJson(result);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'import_success'))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t(context, 'import_failed')}: $e')),
      );
    }
  }

  static Future<void> _confirmReset(
    BuildContext context,
    SettingsController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t(context, 'reset')),
        content: Text(I18n.t(context, 'reset_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(I18n.t(context, 'cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(I18n.t(context, 'reset')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.resetToDefaults();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.t(context, 'reset_done'))),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.seedColor});

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = LinearGradient(
      colors: [seedColor, seedColor.withOpacity(0.45)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: seedColor.withOpacity(0.35), blurRadius: 30, offset: const Offset(0, 18)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune_rounded, color: Colors.white.withOpacity(0.95), size: 32),
          const SizedBox(height: 18),
          Text(
            I18n.t(context, 'settings'),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            I18n.t(context, 'settings_tagline'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 22, offset: const Offset(0, 14)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _AccentChoiceChip extends StatelessWidget {
  const _AccentChoiceChip({
    required this.color,
    this.label,
    required this.selected,
    required this.onSelected,
  });

  final Color color;
  final String? label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label ?? '#${color.value.toRadixString(16).substring(2).toUpperCase()}'),
      avatar: CircleAvatar(backgroundColor: color),
      selected: selected,
      onSelected: onSelected,
      selectedColor: color.withOpacity(0.25),
      checkmarkColor: theme.colorScheme.onPrimary,
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.start,
    required this.end,
    required this.onStartTap,
    required this.onEndTap,
  });

  final TimeOfDay start;
  final TimeOfDay end;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String format(TimeOfDay tod) => tod.format(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onStartTap,
            icon: const Icon(Icons.nights_stay_outlined),
            label: Text('${I18n.t(context, 'start_time')} • ${format(start)}'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEndTap,
            icon: const Icon(Icons.sunny_snowing),
            label: Text('${I18n.t(context, 'end_time')} • ${format(end)}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
