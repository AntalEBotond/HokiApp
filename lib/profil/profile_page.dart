library profile_page;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/sticker_service.dart';
import '../utils/i18n.dart';
import '../utils/ui_utils.dart';
import 'frame_preview_strip.dart';
import 'framed_avatar.dart';
import 'models/profile_models.dart';
import 'note_editor.dart' show NoteEditResult, showEmojiPickerSheet;
import 'note_editor_page.dart';
import 'note_overlay.dart';
import 'services/profile_repository.dart';

part 'completion_card.dart';
part 'halo_painter.dart';
part 'countdown_ring_painter.dart';
part 'quick_action_button.dart';
part 'frame_picker_sheet.dart';
part 'avatar_viewer.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  late final AnimationController _haloCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  ProfileRepository? _repository;
  ProfileData _data = ProfileData.initial();

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _syncingText = false;

  Timer? _nameDebounce;
  Timer? _descDebounce;
  Timer? _statusTicker;
  Timer? _autoSaveTimer;

  String? _frameTempPreview;
  List<Sticker> _stickers = const [];

  static const List<String> kFrameStyles = [
    'none',
    'glow-00E676',
    'glow-03A9F4',
    'glow-FF5252',
    'glow-AB47BC',
    'neon-00FF9C',
    'neon-FFEA00',
    'neon-FF3D00',
    'neon-00E5FF',
    'neon-7C4DFF',
    'outline-42A5F5',
    'outline-FF7043',
    'outline-66BB6A',
    'outline-EC407A',
    'outline-FFC107',
    'ring-1DE9B6',
    'ring-E040FB',
    'ring-FF6E40',
    'ring-29B6F6',
    'ring-AED581',
    'gradient-sunset',
    'gradient-ocean',
    'gradient-forest',
    'gradient-violet',
    'gradient-fire',
    'gradient-candy',
    'gradient-berry',
    'gradient-sky',
    'gradient-mint',
    'gradient-royal',
    'gradient-rose',
    'gradient-aurora',
    'gradient-citrus',
    'gradient-plasma',
    'gradient-peach',
    'gradient-lava',
    'gradient-aqua',
    'gradient-steel',
    'gradient-gold',
    'gradient-silver',
    'gradient-bronze',
    'rainbow',
    'glow-FF4081',
    'glow-8BC34A',
    'neon-18FFFF',
    'neon-E040FB',
    'outline-90CAF9',
    'outline-FFAB91',
    'ring-80CBC4',
    'ring-CE93D8',
  ];

  static const Map<String, List<String>> _kCategories = {
    'All': [],
    'Gradients': ['gradient-', 'rainbow'],
    'Glow': ['glow-'],
    'Neon': ['neon-'],
    'Outline': ['outline-'],
    'Ring': ['ring-'],
    'Other': ['none'],
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _nameCtrl.addListener(_handleNameChanged);
    _descCtrl.addListener(_handleDescriptionChanged);
    _initialize();
  }

  Future<void> _initialize() async {
    final repository = await ProfileRepository.create();
    final data = await repository.loadProfile();
    if (!mounted) return;
    setState(() {
      _repository = repository;
      _data = data;
      _loading = false;
    });
    _applyTextControllers();
    if (_data.preferences.reduceMotion) {
      _haloCtrl.stop();
    } else if (!_haloCtrl.isAnimating) {
      _haloCtrl.repeat();
    }
    _startStatusTicker();
  }

  void _applyTextControllers() {
    _syncingText = true;
    _nameCtrl.text = _data.name;
    _descCtrl.text = _data.description;
    _syncingText = false;
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _descDebounce?.cancel();
    _statusTicker?.cancel();
    _autoSaveTimer?.cancel();
    _haloCtrl.dispose();
    _nameCtrl.removeListener(_handleNameChanged);
    _descCtrl.removeListener(_handleDescriptionChanged);
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (_syncingText) return;
    final value = _nameCtrl.text;
    _nameDebounce?.cancel();
    setState(() {
      _data = _data.copyWith(name: value);
    });
    _markDirty();
    _nameDebounce = Timer(const Duration(milliseconds: 350), () {
      _repository?.persistName(value);
    });
  }

  void _handleDescriptionChanged() {
    if (_syncingText) return;
    final value = _descCtrl.text;
    _descDebounce?.cancel();
    setState(() {
      _data = _data.copyWith(description: value);
    });
    _markDirty();
    _descDebounce = Timer(const Duration(milliseconds: 500), () {
      _repository?.persistDescription(value);
    });
  }

  void _markDirty() {
    if (!_data.isAuthenticated) return;
    if (!_dirty) {
      setState(() => _dirty = true);
    }
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    if (!_data.isAuthenticated) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_dirty && !_saving) {
        _saveProfileToServer(silent: true);
      }
    });
  }

  Future<void> _persistDraft() async {
    final repo = _repository;
    if (repo == null) return;
    await repo.persistDraft(_data);
    _markDirty();
  }

  void _startStatusTicker() {
    _statusTicker?.cancel();
    if (!_data.status.isActive) return;
    _statusTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_data.status.isActive) {
        _statusTicker?.cancel();
      }
    });
  }

  double get _statusProgress {
    final status = _data.status;
    if (!status.isActive || status.expiresAt == null) return 0;
    final end = status.expiresAt!;
    final start = end.subtract(const Duration(hours: 24));
    final now = DateTime.now();
    final total = end.difference(start).inMilliseconds.toDouble();
    final done = (now.isBefore(start)
            ? 0
            : now.difference(start).inMilliseconds.toDouble())
        .clamp(0, total);
    if (total <= 0) return 0;
    return done / total;
  }

  Future<void> _refreshProfile() async {
    final repo = _repository ?? await ProfileRepository.create();
    final updated = await repo.loadProfile();
    if (!mounted) return;
    setState(() {
      _repository = repo;
      _data = updated;
      _dirty = false;
    });
    _applyTextControllers();
    if (_data.preferences.reduceMotion) {
      _haloCtrl.stop();
    } else if (!_haloCtrl.isAnimating) {
      _haloCtrl.repeat();
    }
    _startStatusTicker();
  }

  Future<void> _revertLocal() async {
    final repo = _repository;
    if (repo == null) return;
    final local = await ProfileData.fromPrefsAsync(repo.prefs);
    if (!mounted) return;
    setState(() {
      _data = local.copyWith(authToken: _data.authToken);
      _dirty = false;
    });
    _applyTextControllers();
    _startStatusTicker();
  }

  Future<void> _saveProfileToServer({bool silent = false}) async {
    final repo = _repository;
    if (repo == null || !_data.isAuthenticated) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t(context, 'not_authenticated'))),
        );
      }
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final snapshot = _data.copyWith(
        name: _nameCtrl.text,
        description: _descCtrl.text,
      );
      final updated = await repo.saveProfile(snapshot);
      if (!mounted) return;
      setState(() {
        _data = updated;
        _dirty = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t(context, 'profile_saved'))),
        );
        HapticFeedback.mediumImpact();
      }
    } on ProfileAuthException {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t(context, 'not_authenticated'))),
        );
      }
    } catch (e) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${I18n.t(context, 'save_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveAvatarFromXFile(XFile file) async {
    final repo = _repository ?? await ProfileRepository.create();
    try {
      final updated = await repo.saveAvatar(
        _data.copyWith(authToken: _data.authToken ?? repo.prefs.getString('auth_token')),
        file,
      );
      if (!mounted) return;
      setState(() => _data = updated);
      _repository = repo;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'avatar_updated'))),
      );
      HapticFeedback.selectionClick();
      if (_data.preferences.reduceMotion) {
        _haloCtrl.stop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t(context, 'upload_error')}: $e')),
      );
    }
  }

  Future<void> _clearAvatar() async {
    final repo = _repository ?? await ProfileRepository.create();
    try {
      final updated = await repo.clearAvatar(_data);
      if (!mounted) return;
      setState(() => _data = updated);
      _repository = repo;
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t(context, 'avatar_delete_failed')}: $e')),
      );
    }
  }

  Future<void> _saveBannerFromXFile(XFile file) async {
    final repo = _repository ?? await ProfileRepository.create();
    try {
      final updated = await repo.saveBanner(
        _data.copyWith(authToken: _data.authToken ?? repo.prefs.getString('auth_token')),
        file,
      );
      if (!mounted) return;
      setState(() => _data = updated);
      _repository = repo;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'banner_updated'))),
      );
      HapticFeedback.selectionClick();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t(context, 'upload_error')}: $e')),
      );
    }
  }

  Future<void> _clearBanner() async {
    final repo = _repository ?? await ProfileRepository.create();
    try {
      final updated = await repo.clearBanner(_data);
      if (!mounted) return;
      setState(() => _data = updated);
      _repository = repo;
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t(context, 'banner_delete_failed')}: $e')),
      );
    }
  }

  void _setFrame(String style) {
    setState(() => _data = _data.copyWith(avatarFrame: style));
    _persistDraft();
    HapticFeedback.selectionClick();
  }

  void _cycleFrame(int dir) {
    final list = kFrameStyles;
    final idx = list.indexOf(_data.avatarFrame);
    final next = (idx < 0 ? 0 : idx + dir) % list.length;
    final selection = list[(next + list.length) % list.length];
    _setFrame(selection);
  }

  void _randomizeFrame() {
    final pool = kFrameStyles.where((e) => e != 'none').toList()..shuffle();
    if (pool.isEmpty) return;
    _setFrame(pool.first);
  }

  Future<void> _openFramePickerSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FramePickerSheet(
        allStyles: kFrameStyles,
        current: _data.avatarFrame,
        favs: _data.preferences.frameFavorites,
        categories: _kCategories,
        colorsFor: _colorsForFrame,
        onPreviewStart: (style) => setState(() => _frameTempPreview = style),
        onPreviewEnd: () => setState(() => _frameTempPreview = null),
        onToggleFav: (style) async {
          final currentFavs = _data.preferences.frameFavorites.toSet();
          if (currentFavs.contains(style)) {
            currentFavs.remove(style);
          } else {
            currentFavs.add(style);
          }
          setState(() {
            _data = _data.copyWith(
              preferences: _data.preferences.copyWith(frameFavorites: currentFavs),
            );
          });
          await _persistDraft();
        },
      ),
    );
    if (selected != null && selected.isNotEmpty) {
      _setFrame(selected);
    }
  }

  Future<void> _showBannerOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(I18n.t(context, 'pick_from_gallery')),
              onTap: () async {
                Navigator.of(context).pop();
                await _pickBannerImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(I18n.t(context, 'take_photo')),
              onTap: () async {
                Navigator.of(context).pop();
                await _pickBannerImage(ImageSource.camera);
              },
            ),
            if (_data.banner.hasImage)
              ListTile(
                leading: const Icon(Icons.delete),
                title: Text(I18n.t(context, 'delete_banner')),
                onTap: () {
                  Navigator.of(context).pop();
                  _clearBanner();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBannerImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (file != null) {
        await _saveBannerFromXFile(file);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la incarcare banner: $e')),
      );
    }
  }

  void _showImageOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(I18n.t(context, 'pick_from_gallery')),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(I18n.t(context, 'take_photo')),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            if (_data.avatar.hasImage)
              ListTile(
                leading: const Icon(Icons.delete),
                title: Text(I18n.t(context, 'delete_avatar')),
                onTap: () {
                  Navigator.of(context).pop();
                  _clearAvatar();
                },
              ),
            if (_currentAvatarImage() != null)
              ListTile(
                leading: const Icon(Icons.zoom_out_map),
                title: Text(I18n.t(context, 'zoom_avatar')),
                onTap: () {
                  Navigator.of(context).pop();
                  _openAvatarViewer();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file != null) {
        await _saveAvatarFromXFile(file);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t(context, 'image_load_error')}: $e')),
      );
    }
  }

  Future<void> _editStatusNote() async {
    final result = await Navigator.of(context).push<NoteEditResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NoteEditorPage(
          initialText: _data.status.text ?? '',
          textColor: _data.status.textColor,
          bgColor: _data.status.backgroundColor,
          emoji: _data.status.emoji,
          avatarImage: _currentAvatarImage(),
          avatarName: _nameCtrl.text.trim().isEmpty ? 'User' : _nameCtrl.text.trim(),
          frameStyle: _data.avatarFrame,
        ),
      ),
    );
    if (result == null) return;
    if (result.deleted || result.text?.trim().isEmpty == true) {
      setState(() {
        _data = _data.copyWith(status: const StatusNote(text: null, expiresAt: null, emoji: null));
      });
      await _persistDraft();
      _statusTicker?.cancel();
      return;
    }
    final exp = DateTime.now().add(const Duration(hours: 24));
    setState(() {
      _data = _data.copyWith(
        status: StatusNote(
          text: result.text?.trim(),
          expiresAt: exp,
          textColor: result.textColor,
          backgroundColor: result.bgColor,
          emoji: _data.status.emoji,
        ),
      );
    });
    await _persistDraft();
    _startStatusTicker();
  }

  Future<void> _pickEmoji() async {
    final emoji = await showEmojiPickerSheet(context);
    if (emoji == null) return;
    setState(() {
      _data = _data.copyWith(
        status: _data.status.copyWith(emoji: emoji.isEmpty ? null : emoji),
      );
    });
    await _persistDraft();
  }

  Future<void> _saveLink(String key, String? value) async {
    SocialLinks updated;
    switch (key) {
      case 'profile_facebook':
        updated = _data.social.copyWith(facebook: value);
        break;
      case 'profile_instagram':
        updated = _data.social.copyWith(instagram: value);
        break;
      case 'profile_tiktok':
        updated = _data.social.copyWith(tiktok: value);
        break;
      case 'profile_youtube':
        updated = _data.social.copyWith(youtube: value);
        break;
      default:
        updated = _data.social;
    }
    setState(() => _data = _data.copyWith(social: updated));
    await _persistDraft();
  }

  Future<void> _editLinkDialog(String title, String prefKey, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${I18n.t(context, 'edit')}: $title'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Link sau @handle (ex. https://..., @user, user)',
            ),
            onSubmitted: (_) => Navigator.of(context).maybePop(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(I18n.t(context, 'cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final raw = controller.text.trim();
                final normalized = _normalizeLinkForBrand(prefKey, raw);
                _saveLink(prefKey, normalized.isEmpty ? null : normalized);
                Navigator.of(context).pop();
                HapticFeedback.selectionClick();
              },
              child: Text(I18n.t(context, 'save')),
            ),
          ],
        );
      },
    );
  }

  String _normalizeLinkForBrand(String prefKey, String input) {
    final value = input.trim();
    if (value.isEmpty) return '';
    final isUrl = value.startsWith('http://') || value.startsWith('https://');
    final username = value.startsWith('@') ? value.substring(1) : value;
    if (isUrl) return value;
    switch (prefKey) {
      case 'profile_facebook':
        return 'https://facebook.com/$username';
      case 'profile_instagram':
        return 'https://instagram.com/$username';
      case 'profile_tiktok':
        if (username.contains('/')) return 'https://tiktok.com/$username';
        return 'https://www.tiktok.com/@$username';
      case 'profile_youtube':
        if (username.startsWith('@')) return 'https://youtube.com/$username';
        if (username.startsWith('UC')) return 'https://youtube.com/channel/$username';
        return 'https://youtube.com/@$username';
      default:
        return value;
    }
  }

  Future<void> _openLink(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu exista link setat pentru acest serviciu.')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL invalid.')),
      );
      return;
    }
    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu s-a putut deschide linkul.')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _socialButton(String brand, IconData icon, String? link, String title, String prefKey) {
    final enabled = link != null && link.isNotEmpty;
    BoxDecoration decoFor(String b) {
      switch (b) {
        case 'facebook':
          const base = Color(0xFF1877F2);
          return BoxDecoration(
            color: enabled ? base : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [BoxShadow(color: base.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]
                : [],
          );
        case 'instagram':
          return BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? const LinearGradient(
                    colors: [
                      Color(0xFFF58529),
                      Color(0xFFDD2A7B),
                      Color(0xFF8134AF),
                      Color(0xFF515BD4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade600]),
            boxShadow: enabled ? [const BoxShadow(color: Color(0x55212121), blurRadius: 10, offset: Offset(0, 4))] : [],
          );
        case 'tiktok':
          return BoxDecoration(
            color: enabled ? Colors.black : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [
                    BoxShadow(color: const Color(0xFF69C9D0).withOpacity(0.4), blurRadius: 10, offset: const Offset(-2, 2)),
                    BoxShadow(color: const Color(0xFFEE1D52).withOpacity(0.4), blurRadius: 10, offset: const Offset(2, 2)),
                  ]
                : [],
          );
        case 'youtube':
          const base = Color(0xFFFF0000);
          return BoxDecoration(
            color: enabled ? base : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: enabled ? [BoxShadow(color: base.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))] : [],
          );
        default:
          return BoxDecoration(color: enabled ? Colors.blueAccent : Colors.grey, shape: BoxShape.circle);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: enabled ? '$title megnyitása' : '$title nincs beállítva',
          child: GestureDetector(
            onTap: enabled
                ? () {
                    _openLink(link);
                    HapticFeedback.selectionClick();
                  }
                : null,
            onLongPress: enabled
                ? () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(I18n.t(context, 'link_copied'))),
                      );
                    }
                    HapticFeedback.lightImpact();
                  }
                : null,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: enabled ? 1.0 : 0.95,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: decoFor(brand),
                alignment: Alignment.center,
                child: FaIcon(icon, color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editLinkDialog(title, prefKey, link),
              tooltip: I18n.t(context, 'edit_link'),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: enabled ? () => _openLink(link) : null,
              tooltip: I18n.t(context, 'open_link'),
            ),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final textScale = MediaQuery.of(context).textScaleFactor.clamp(0.9, 1.2);
    final isSmall = width < 420;
    final avatarRadius = isSmall ? 48.0 : 60.0;
    final bubbleSpace = isSmall ? 44.0 : 52.0;
    final tileWidth = (avatarRadius * 2) + (isSmall ? 160.0 : 220.0);
    final bubbleRightInset = (tileWidth / 2) - avatarRadius - 4;
    final name = _nameCtrl.text.trim();
    final completeness = _data.completeness;

    return WillPopScope(
      onWillPop: _onBackPressed,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(I18n.t(context, 'profile')),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 68,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.surface.withOpacity(0.92),
                    theme.colorScheme.surface.withOpacity(0.78),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.surfaceVariant.withOpacity(0.75),
                  theme.colorScheme.surface.withOpacity(0.92),
                  theme.colorScheme.surface.withOpacity(0.98),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: RefreshIndicator(
              onRefresh: _refreshProfile,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(isSmall ? 12 : 20, 16, isSmall ? 12 : 20, 24),
                child: Column(
                  children: [
                    _buildHeroSection(theme, isSmall, avatarRadius, name),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.center,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _QuickActionButton(
                            icon: Icons.brush_outlined,
                            label: 'Rame',
                            onTap: _openFramePickerSheet,
                          ),
                          _QuickActionButton(
                            icon: Icons.casino_outlined,
                            label: 'Random',
                            onTap: _randomizeFrame,
                          ),
                          _QuickActionButton(
                            icon: Icons.edit_note_outlined,
                            label: I18n.t(context, 'add_status'),
                            onTap: _editStatusNote,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _CompletionCard(percent: completeness),
                    const SizedBox(height: 16),
                    _glassField(
                      child: TextField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nume',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _glassField(
                      child: TextField(
                        controller: _descCtrl,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Descriere',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Rama avatar', style: theme.textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    FramePreviewStrip(
                      styles: kFrameStyles,
                      selected: _data.avatarFrame,
                      image: _currentAvatarImage(),
                      name: name,
                      onSelected: _setFrame,
                    ),
                    const SizedBox(height: 16),
                    _glassField(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_fix_high, size: 18),
                              const SizedBox(width: 8),
                              const Text('Puterea haloului'),
                              const Spacer(),
                              Text('${(_data.preferences.haloStrength * 100).round()}%'),
                            ],
                          ),
                          Slider(
                            value: _data.preferences.haloStrength,
                            onChanged: (v) => setState(() =>
                                _data = _data.copyWith(preferences: _data.preferences.copyWith(haloStrength: v))),
                            onChangeEnd: (_) => _persistDraft(),
                          ),
                          const SizedBox(height: 6),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Reduce motion (efecte minime)'),
                            value: _data.preferences.reduceMotion,
                            onChanged: (value) {
                              setState(() {
                                _data = _data.copyWith(
                                  preferences: _data.preferences.copyWith(reduceMotion: value),
                                );
                              });
                              if (value) {
                                _haloCtrl.stop();
                              } else if (!_haloCtrl.isAnimating) {
                                _haloCtrl.repeat();
                              }
                              _persistDraft();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _glassField(
                      child: FutureBuilder<List<Sticker>>(
                        future: StickerService().loadStickers(),
                        builder: (context, snap) {
                          final list = snap.data ?? const <Sticker>[];
                          _stickers = list;
                          if (list.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Nu există autocolante disponibile. Adăugați PNG-uri în dosarul cu materiale/autocolante.'),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.emoji_emotions_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Sticker'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final sticker in list)
                                    GestureDetector(
                                      onTap: () async {
                                        final asset = sticker.asset ?? sticker.url;
                                        setState(() => _data = _data.copyWith(avatarSticker: asset));
                                        await _persistDraft();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: (_data.avatarSticker == (sticker.asset ?? sticker.url))
                                                ? theme.colorScheme.primary
                                                : Colors.white24,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: SizedBox(
                                          width: 78,
                                          height: 78,
                                          child: sticker.asset != null
                                              ? Image.asset('assets/stickers/${sticker.asset!}', fit: BoxFit.contain)
                                              : Image.network(sticker.url!, fit: BoxFit.contain),
                                        ),
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: () async {
                                      setState(() => _data = _data.copyWith(avatarSticker: null));
                                      await _persistDraft();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white24, width: 1.5),
                                      ),
                                      child: const Icon(Icons.close, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Social media', style: theme.textTheme.titleMedium),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 18,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _socialButton('facebook', FontAwesomeIcons.facebookF, _data.social.facebook, 'Facebook', 'profile_facebook'),
                        _socialButton('instagram', FontAwesomeIcons.instagram, _data.social.instagram, 'Instagram', 'profile_instagram'),
                        _socialButton('tiktok', FontAwesomeIcons.tiktok, _data.social.tiktok, 'TikTok', 'profile_tiktok'),
                        _socialButton('youtube', FontAwesomeIcons.youtube, _data.social.youtube, 'YouTube', 'profile_youtube'),
                      ],
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              offset: (_dirty && _data.isAuthenticated) ? Offset.zero : const Offset(0, 1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: (_dirty && _data.isAuthenticated) ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(16),
                    color: theme.colorScheme.surface,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Ai modificări nesalvate.')),
                          TextButton(
                            onPressed: _revertLocal,
                            child: const Text('Renunta'),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            onPressed: _saving ? null : () => _saveProfileToServer(),
                            icon: const Icon(Icons.save),
                            label: const Text('Salveaza'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _onBackPressed() async {
    if (!_dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modificări nesalvate'),
        content: const Text('Vrei să părăsești pagina fără să salvezi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Rămâi')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Părăsește')),
        ],
      ),
    );
    return result ?? false;
  }

Widget _buildHeroSection(ThemeData theme, bool isSmall, double avatarRadius, String name) {
  const double _ = 32;
  final double heroHeight = isSmall ? 220.0 : 270.0;
  final status = _data.status;
  final bannerImage = _currentBannerImage();
  final accent = _data.preferences.accentColor;
  final double bubbleTouchGap = isSmall ? 6 : 8; 
  final double bubbleR = avatarRadius + bubbleTouchGap;

    return SizedBox(
    height: heroHeight + avatarRadius + (isSmall ? 92 : 104),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.24),
                    blurRadius: 28,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bannerImage != null)
                      Image(image: bannerImage, fit: BoxFit.cover)
                    else
                      _buildBannerPlaceholder(theme, accent, isSmall),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.35),
                              Colors.black.withOpacity(0.18),
                              Colors.black.withOpacity(0.55),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: _floatingGlassButton(
              icon: Icons.wallpaper_outlined,
              label: I18n.t(context, 'edit_banner'),
              onTap: _showBannerOptions,
            ),
          ),
          Positioned(
            left: isSmall ? 28 : 44,
            bottom: avatarRadius + (isSmall ? 70 : 84),
            right: isSmall ? 140 : 220,
            child: _heroTextBlock(theme, name, isSmall),
          ),
           Positioned(
              bottom: isSmall ? 60 : 88,
              left: 0,
              right: 0,
              child: _buildAvatarCluster(avatarRadius, name),
            ),

          
          Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(bubbleR * 1.10, -bubbleR * 0.20),
                  child: status.isActive
                      ? NoteOverlay(
                          text: status.text ?? '',
                          textColor: status.textColor,
                          bgColor: status.backgroundColor,
                          maxWidth: isSmall ? 180 : 240,
                          onEdit: _editStatusNote,
                          emoji: status.emoji,
                          onPickEmoji: _pickEmoji,
                        )
                      : _statusPlaceholderChip(theme),))
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPlaceholder(ThemeData theme, Color accent, bool isSmall) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(0.65),
            theme.colorScheme.primary.withOpacity(0.45),
            theme.colorScheme.surfaceVariant.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.all(isSmall ? 18 : 28),
              child: Text(
                I18n.t(context, 'no_banner'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Icon(
              Icons.wallpaper_outlined,
              size: isSmall ? 88 : 120,
              color: Colors.white.withOpacity(0.28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _floatingGlassButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.white.withOpacity(0.18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroTextBlock(ThemeData theme, String name, bool isSmall) {
    final pronouns = _data.pronouns;
    final location = _data.location;
    final website = _data.websiteUrl;
    final headline = theme.textTheme.headlineSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      shadows: [Shadow(color: Colors.black.withOpacity(0.55), blurRadius: 16)],
    );
    final secondary = theme.textTheme.titleMedium?.copyWith(
      color: Colors.white70,
      fontWeight: FontWeight.w500,
      shadows: [Shadow(color: Colors.black.withOpacity(0.35), blurRadius: 10)],
    );

    final widgets = <Widget>[
      Text(
        name.isEmpty ? I18n.t(context, 'profile') : name,
        style: headline,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ];

    if (pronouns != null && pronouns.isNotEmpty) {
      widgets.add(const SizedBox(height: 4));
      widgets.add(Text(pronouns, style: secondary?.copyWith(fontSize: (secondary?.fontSize ?? 16) - 2)));
    }
    if (location != null && location.isNotEmpty) {
      widgets.add(const SizedBox(height: 4));
      widgets.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, size: 16, color: Colors.white70),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              location,
              style: secondary,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ));
    }
    if (website != null && website.isNotEmpty) {
      widgets.add(const SizedBox(height: 4));
      widgets.add(GestureDetector(
        onTap: () => _openLink(website),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 16, color: Colors.white70),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                website,
                style: secondary?.copyWith(decoration: TextDecoration.underline),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ));
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isSmall ? 220 : 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: widgets,
      ),
    );
  }

  Widget _statusPlaceholderChip(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.white.withOpacity(0.18),
          child: InkWell(
            onTap: _editStatusNote,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    I18n.t(context, 'add_status'),
                    style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCluster(double avatarRadius, String name) {
    final frame = _frameTempPreview ?? _data.avatarFrame;
    final image = _currentAvatarImage();
    final stickerAsset = _data.avatarSticker;
    final stickerImage = (stickerAsset == null || stickerAsset.isEmpty)
        ? null
        : (stickerAsset.startsWith('http')
            ? NetworkImage(stickerAsset)
            : AssetImage('assets/stickers/$stickerAsset') as ImageProvider);
    final reduceMotion = _data.preferences.reduceMotion;
    final size = avatarRadius * 2 + 24;

    return GestureDetector(
      onTap: _showImageOptions,
      onDoubleTap: _randomizeFrame,
      onLongPress: _openAvatarViewer,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 80) return;
        _cycleFrame(velocity < 0 ? 1 : -1);
      },
      child: SizedBox(
  width: (size as num).toDouble(),   // vagy: final double size = ...; feljebb
  height: (size as num).toDouble(),
  child: Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _haloCtrl,
            builder: (context, _) {
              // legyen explicit double
              final double rotation =
                  reduceMotion ? 0.0 : _haloCtrl.value * 2 * math.pi;

              return CustomPaint(
                painter: _HaloPainter(
                  rotation: rotation, // most már double
                  colors: _colorsForFrame(frame),
                  strength: (_data.preferences.haloStrength as num).toDouble(),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_data.status.isActive)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _CountdownRingPainter(
                        progress: _statusProgress,
                        trackColor: Colors.white.withOpacity(0.16),
                        glowColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            Hero(
              tag: 'profile_avatar_hero',
              child: FramedAvatar(
                image: image,
                name: name,
                radius: avatarRadius,
                frameStyle: frame,
                stickerImage: stickerImage,
              ),
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _currentBannerImage() {
    final banner = _data.banner;
    if (banner.url != null && banner.url!.isNotEmpty && banner.bytes == null && (banner.localPath == null || banner.localPath!.isEmpty)) {
      return NetworkImage(UiUtils.normalizeUploadUrl(banner.url!));
    }
    if (kIsWeb) {
      if (banner.bytes != null && banner.bytes!.isNotEmpty) {
        return MemoryImage(banner.bytes!);
      }
    } else {
      if (banner.localPath != null && banner.localPath!.isNotEmpty) {
        final file = File(banner.localPath!);
        if (file.existsSync()) {
          return FileImage(file);
        }
      }
    }
    return null;
  }

  Widget _glassField({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  ImageProvider? _currentAvatarImage() {
    final avatar = _data.avatar;
    if (avatar.url != null && avatar.url!.isNotEmpty && avatar.bytes == null && (avatar.localPath == null || avatar.localPath!.isEmpty)) {
      return NetworkImage(UiUtils.normalizeUploadUrl(avatar.url!));
    }
    if (kIsWeb) {
      if (avatar.bytes != null && avatar.bytes!.isNotEmpty) {
        return MemoryImage(avatar.bytes!);
      }
    } else {
      if (avatar.localPath != null && avatar.localPath!.isNotEmpty && File(avatar.localPath!).existsSync()) {
        return FileImage(File(avatar.localPath!));
      }
    }
    return null;
  }

  List<Color> _colorsForFrame(String style) {
    switch (style) {
      case 'gradient-sunset':
        return const [Color(0xFFFF512F), Color(0xFFF09819)];
      case 'gradient-ocean':
        return const [Color(0xFF36D1DC), Color(0xFF5B86E5)];
      case 'gradient-forest':
        return const [Color(0xFF11998E), Color(0xFF38EF7D)];
      case 'gradient-violet':
        return const [Color(0xFF8E2DE2), Color(0xFF4A00E0)];
      case 'gradient-royal':
        return const [Color(0xFF141E30), Color(0xFF243B55)];
      case 'gradient-aurora':
        return const [Color(0xFF00C9FF), Color(0xFF92FE9D)];
      case 'gradient-plasma':
        return const [Color(0xFF12C2E9), Color(0xFFC471ED), Color(0xFFF64F59)];
      case 'gradient-gold':
        return const [Color(0xFFFFD700), Color(0xFFFFB700)];
      case 'gradient-silver':
        return const [Color(0xFFBCC6CC), Color(0xFFE5E4E2)];
      case 'rainbow':
        return const [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.indigo, Colors.purple];
      default:
        return [
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.primary.withOpacity(0.55),
        ];
    }
  }

  void _openAvatarViewer() {
    final image = _currentAvatarImage();
    if (image == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _AvatarViewer(image: image)),
    );
  }
}
