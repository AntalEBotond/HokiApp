part of menu_screen;

const List<String> _kReactionOrder = ['like', 'love', 'care', 'wow', 'haha', 'sad', 'angry'];

const Map<String, _ReactionVisual> _kReactionVisuals = {
  'like': _ReactionVisual(Icons.thumb_up_alt_rounded, Color(0xFF4C8BF5), 'reaction_like'),
  'love': _ReactionVisual(Icons.favorite_rounded, Color(0xFFFF5C8A), 'reaction_love'),
  'care': _ReactionVisual(Icons.emoji_emotions_rounded, Color(0xFFFFB74D), 'reaction_care'),
  'wow': _ReactionVisual(Icons.auto_awesome_rounded, Color(0xFF7E57C2), 'reaction_wow'),
  'haha': _ReactionVisual(Icons.mood_rounded, Color(0xFFFFD54F), 'reaction_haha'),
  'sad': _ReactionVisual(Icons.sentiment_dissatisfied_rounded, Color(0xFF4FC3F7), 'reaction_sad'),
  'angry': _ReactionVisual(Icons.sentiment_very_dissatisfied_rounded, Color(0xFFF06292), 'reaction_angry'),
};

const List<List<Color>> _kVibePalettes = [
  [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
  [Color(0xFF00B4DB), Color(0xFF0083B0)],
  [Color(0xFFFF512F), Color(0xFFF09819)],
  [Color(0xFF11998E), Color(0xFF38EF7D)],
  [Color(0xFF4568DC), Color(0xFFB06AB3)],
];

const String _kCommentAttachmentPrefix = '::attachment::';

_ReactionVisual _visualForReaction(String type) =>
    _kReactionVisuals[type] ?? _kReactionVisuals['like']!;

String _reactionLabel(BuildContext context, String type) =>
    I18n.t(context, _visualForReaction(type).labelKey);

int _totalReactions(Map<String, int>? counts) {
  if (counts == null || counts.isEmpty) return 0;
  return counts.values.fold<int>(0, (sum, value) => sum + value);
}

List<MapEntry<String, int>> _topReactions(Map<String, int> counts) {
  final filtered = counts.entries.where((e) => e.value > 0).toList();
  filtered.sort((a, b) {
    final orderA = _kReactionOrder.contains(a.key) ? _kReactionOrder.indexOf(a.key) : _kReactionOrder.length;
    final orderB = _kReactionOrder.contains(b.key) ? _kReactionOrder.indexOf(b.key) : _kReactionOrder.length;
    final orderCompare = orderA.compareTo(orderB);
    if (a.value == b.value) {
      return orderCompare;
    }
    return b.value.compareTo(a.value);
  });
  return filtered;
}

Map<String, int> _countsFromDynamic(dynamic raw) {
  final result = <String, int>{};
  if (raw is Map) {
    for (final entry in raw.entries) {
      final key = entry.key?.toString();
      final value = entry.value;
      if (key == null) continue;
      if (value is num) {
        result[key] = value.toInt();
      }
    }
  }
  return result;
}

class _ReactionVisual {
  const _ReactionVisual(this.icon, this.color, this.labelKey);

  final IconData icon;
  final Color color;
  final String labelKey;
}

enum ComposerIntent { mood, tagFriends, checkIn, goLive, image }

class _PostContentParts {
  const _PostContentParts({
    required this.text,
    this.mood,
    this.activity,
    this.checkIn,
    this.vibe,
  });

  final String text;
  final String? mood;
  final String? activity;
  final String? checkIn;
  final String? vibe;

  bool get hasMeta =>
      (mood != null && mood!.isNotEmpty) ||
      (activity != null && activity!.isNotEmpty) ||
      (checkIn != null && checkIn!.isNotEmpty);
}

mixin _FeedSection on State<MenuScreen> {
  /// Feed state with PHP-backed reactions, comments, and glass UI.
  final List<Map<String, dynamic>> _posts = [];
  bool _loadingPosts = false;
  final Map<int, Map<String, int>> _reactionCounts = {};
  final Map<int, String?> _userReactions = {};
  final Map<int, int> _commentCounts = {};
  final ScrollController _feedCtrl = ScrollController();
  int? _currentUserId;
  Future<_ComposerAvatar>? _composerAvatarFuture;

  void initFeed() {
    _fetchPosts();
    _hydrateCurrentUser();
    _composerAvatarFuture = _loadAvatarForComposer(refresh: true);
  }

  void disposeFeed() {
    _feedCtrl.dispose();
  }

  Future<void> _hydrateCurrentUser() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentUserId = sp.getInt('auth_user_id');
    });
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  List<Widget> buildHomeActions(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurface;
    Widget circle(IconData icon, {VoidCallback? onTap}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.white.withOpacity(0.08),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                ),
              ),
            ),
          ),
        );
    return [
      circle(Icons.add_box_outlined, onTap: () => _toast(context, I18n.t(context, 'create'))),
      circle(Icons.search, onTap: () => _toast(context, I18n.t(context, 'search'))),
      circle(Icons.message_outlined, onTap: () => _toast(context, I18n.t(context, 'messages'))),
      const SizedBox(width: 6),
    ];
  }

  Widget _buildFeed(BuildContext context, ThemeData theme) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 700;

    final children = <Widget>[
      if (!isCompact) _homeTopBar(context),
      const SizedBox(height: 8),
      _homeComposer(context),
      const Divider(height: 24),
      if (_loadingPosts)
        ...List.generate(4, (_) => const SkeletonPostCard()).expand((w) => [w, const SizedBox(height: 12)]),
      if (!_loadingPosts && _posts.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('Nu exista', style: theme.textTheme.bodyMedium)),
        ),
      if (!_loadingPosts && _posts.isNotEmpty)
        ..._posts.map((p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _postCard(context, p),
            )),
    ];

    return RefreshIndicator(
      onRefresh: _fetchPosts,
      child: ListView(
        controller: _feedCtrl,
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }

  Widget _homeTopBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('Aplicatie', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          ...buildHomeActions(context),
        ],
      ),
    );
  }

  Widget _homeComposer(BuildContext context) {
    final theme = Theme.of(context);

    Widget composerChip(String label, IconData icon, {ComposerIntent? intent}) {
      return GestureDetector(
        onTap: () => _openCreatePost(context, intent: intent),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: FutureBuilder<_ComposerAvatar>(
        future: _composerAvatarFuture ??= _loadAvatarForComposer(),
        builder: (context, snap) {
          final data = snap.data;
          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.surface.withOpacity(0.88),
                      theme.colorScheme.surface.withOpacity(0.62),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FramedAvatar(
                          image: data?.img,
                          name: data?.initials ?? '🙂',
                          radius: 18,
                          frameStyle: data?.frame ?? 'none',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openCreatePost(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                              ),
                              child: Text(
                                I18n.t(context, 'whats_on_your_mind'),
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withOpacity(0.75),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IconButton(
                            onPressed: () => _openCreatePost(context, intent: ComposerIntent.image),
                            icon: const Icon(Icons.image_outlined, color: Colors.white),
                            splashRadius: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        composerChip(
                          I18n.t(context, 'feeling_activity'),
                          Icons.auto_awesome,
                          intent: ComposerIntent.mood,
                        ),
                        composerChip(
                          I18n.t(context, 'tag_friends'),
                          Icons.people_alt_outlined,
                          intent: ComposerIntent.tagFriends,
                        ),
                        composerChip(
                          I18n.t(context, 'check_in'),
                          Icons.place_outlined,
                          intent: ComposerIntent.checkIn,
                        ),
                        composerChip(
                          I18n.t(context, 'go_live'),
                          Icons.videocam_outlined,
                          intent: ComposerIntent.goLive,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _fetchPosts() async {
    if (!mounted) return;
    setState(() => _loadingPosts = true);
    try {
      final api = ApiService();
      final list = await api.getPosts(limit: 20, offset: 0);
      final normalized = <Map<String, dynamic>>[];
      for (final item in list) {
        normalized.add(_normalizePostRecord(item));
      }
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(normalized);
        _loadingPosts = false;
      });
      for (final p in list) {
        final pid = (p['id'] as num?)?.toInt();
        if (pid != null) {
          unawaited(_refreshReactionsFor(pid));
          unawaited(_ensureCommentsCount(pid));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPosts = false);
      _toast(context, 'Nu s-au putut încărca postările');
    }
  }

  Map<String, dynamic> _normalizePostRecord(dynamic raw) {
    final map = <String, dynamic>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (key == null) return;
        map[key.toString()] = value;
      });
    }

    Map<String, dynamic> ensureMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return Map<String, dynamic>.from(value);
      }
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    }

    String? clean(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final user = ensureMap(map['user']);
    final id = _asInt(user['id']) ?? _asInt(map['user_id']);
    if (id != null) {
      user['id'] = id;
    }

    final nameCandidates = <String?>[
      clean(user['full_name']),
      clean(user['name']),
      clean(map['user_name']),
      clean(map['full_name']),
      clean(map['username']),
    ];
    final resolvedName = nameCandidates.firstWhere(
      (element) => element != null && element.isNotEmpty,
      orElse: () => null,
    );
    if (resolvedName != null) {
      user.putIfAbsent('full_name', () => resolvedName);
      user.putIfAbsent('name', () => resolvedName);
      user.putIfAbsent('username', () => resolvedName);
    }

    final avatarCandidates = <String?>[
      clean(user['avatar']),
      clean(map['user_avatar']),
      clean(map['avatar']),
      clean(map['avatar_url']),
    ];
    final resolvedAvatar = avatarCandidates.firstWhere(
      (element) => element != null && element.isNotEmpty,
      orElse: () => null,
    );
    if (resolvedAvatar != null) {
      user['avatar'] = resolvedAvatar;
    }

    final frameCandidates = <String?>[
      clean(user['frame']),
      clean(map['user_frame']),
      clean(map['avatar_frame']),
    ];
    final resolvedFrame = frameCandidates.firstWhere(
      (element) => element != null && element.isNotEmpty,
      orElse: () => null,
    );
    if (resolvedFrame != null) {
      user['frame'] = resolvedFrame;
    }

    final stickerCandidates = <String?>[
      clean(user['sticker']),
      clean(map['user_sticker']),
      clean(map['avatar_sticker']),
    ];
    final resolvedSticker = stickerCandidates.firstWhere(
      (element) => element != null && element.isNotEmpty,
      orElse: () => null,
    );
    if (resolvedSticker != null) {
      user['sticker'] = resolvedSticker;
    }

    if (clean(user['name']) == null && id != null) {
      user['name'] = 'User #$id';
      user.putIfAbsent('full_name', () => 'User #$id');
      user.putIfAbsent('username', () => 'user$id');
    }

    map['user'] = user;
    return map;
  }

  Future<void> _openCreatePost(BuildContext context,
      {Map<String, dynamic>? existing, ComposerIntent? intent}) async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('auth_token');
    if (token == null) {
      _toast(context, I18n.t(context, 'not_authenticated'));
      return;
    }
    final isEdit = existing != null;
    final parsedContent = _parsePostContent(existing?['content'] as String?);
    final controller = TextEditingController(text: parsedContent.text);
    final theme = Theme.of(context);
    XFile? pickedMedia;
    String? pickedGifUrl;
    final existingImageUrl = existing?['image_url'] as String?;
    bool checkInLoading = false;
    bool autoCheckInHandled = intent != ComposerIntent.checkIn;

    final gradients = _kVibePalettes;
    final feelings = <String>['Inspired', 'Celebrating', 'Chill', 'Focused'];
    final activities = <String>['Working remotely', 'Traveling', 'Gaming session', 'Coffee break'];
    int? selectedGradient = _vibeIndexFromMeta(parsedContent.vibe, gradients.length);
    String? selectedFeeling = parsedContent.mood;
    String? selectedActivity = parsedContent.activity;
    String? selectedCheckIn = parsedContent.checkIn;

    if (intent == ComposerIntent.goLive && controller.text.trim().isEmpty) {
      controller.text = 'Going live soon! 🔴';
    }
    if (intent == ComposerIntent.tagFriends && controller.text.trim().isEmpty) {
      controller.text = '@';
      controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
    }
    if (intent == ComposerIntent.mood && selectedFeeling == null && feelings.isNotEmpty) {
      selectedFeeling = feelings.first;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: StatefulBuilder(builder: (ctx2, setSheetState) {
            if (!autoCheckInHandled) {
              autoCheckInHandled = true;
              Future.microtask(() async {
                setSheetState(() => checkInLoading = true);
                final location = await _resolveCurrentLocationName();
                if (!mounted) return;
                setSheetState(() {
                  checkInLoading = false;
                  if (location != null) {
                    selectedCheckIn = location;
                  } else {
                    _toast(context, I18n.t(context, 'location_fetch_failed'));
                  }
                });
              });
            }
            final canPublish = controller.text.trim().isNotEmpty;
            final hasNewAttachment = pickedMedia != null || pickedGifUrl != null;
            final showExistingAttachment =
                !hasNewAttachment && isEdit && (existingImageUrl != null && existingImageUrl.isNotEmpty);
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.surface.withOpacity(0.95),
                        theme.colorScheme.surface.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.08)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 46,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.24),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    isEdit ? I18n.t(context, 'edit_post') : I18n.t(context, 'create_post'),
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: I18n.t(context, 'close'),
                                onPressed: () => Navigator.pop(ctx, false),
                                icon: const Icon(Icons.close),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: selectedGradient != null
                                  ? LinearGradient(
                                      colors: gradients[selectedGradient!],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: selectedGradient == null
                                  ? theme.colorScheme.surfaceVariant.withOpacity(0.35)
                                  : null,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: TextField(
                              controller: controller,
                              onChanged: (_) => setSheetState(() {}),
                              maxLines: 6,
                              minLines: 3,
                              style: (selectedGradient != null)
                                  ? theme.textTheme.bodyLarge?.copyWith(color: Colors.white)
                                  : theme.textTheme.bodyLarge,
                              decoration: InputDecoration(
                                hintText: I18n.t(context, 'share_something'),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Background vibe', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            children: List.generate(gradients.length, (index) {
                              final colors = gradients[index];
                              final selected = selectedGradient == index;
                              return GestureDetector(
                                onTap: () => setSheetState(() {
                                  selectedGradient = selected ? null : index;
                                }),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected ? theme.colorScheme.primary : Colors.white54,
                                      width: selected ? 2.4 : 1.2,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: theme.colorScheme.primary.withOpacity(0.4),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: selected
                                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                                      : null,
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 18),
                          Text('Mood highlight', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: feelings.map((feeling) {
                              final selected = selectedFeeling == feeling;
                              return ChoiceChip(
                                label: Text(feeling),
                                selected: selected,
                                onSelected: (value) => setSheetState(() => selectedFeeling = value ? feeling : null),
                                selectedColor: theme.colorScheme.primary.withOpacity(0.25),
                                backgroundColor: Colors.white.withOpacity(0.08),
                                labelStyle: theme.textTheme.labelMedium?.copyWith(
                                  color: selected ? theme.colorScheme.primary : theme.hintColor,
                                ),
                                side: BorderSide(color: selected ? theme.colorScheme.primary : Colors.white24),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                          Text('Activity', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: activities.map((activity) {
                              final selected = selectedActivity == activity;
                              return ChoiceChip(
                                label: Text(activity),
                                selected: selected,
                                onSelected: (value) => setSheetState(() => selectedActivity = value ? activity : null),
                                selectedColor: theme.colorScheme.secondary.withOpacity(0.25),
                                backgroundColor: Colors.white.withOpacity(0.08),
                                labelStyle: theme.textTheme.labelMedium?.copyWith(
                                  color: selected ? theme.colorScheme.secondary : theme.hintColor,
                                ),
                                side: BorderSide(color: selected ? theme.colorScheme.secondary : Colors.white24),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            I18n.t(context, 'check_in'),
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: checkInLoading
                                    ? null
                                    : () async {
                                        setSheetState(() => checkInLoading = true);
                                        final location = await _resolveCurrentLocationName();
                                        if (!mounted) return;
                                        setSheetState(() {
                                          checkInLoading = false;
                                          if (location != null) {
                                            selectedCheckIn = location;
                                          } else {
                                            _toast(context, I18n.t(context, 'location_fetch_failed'));
                                          }
                                        });
                                      },
                                icon: checkInLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.my_location),
                                label: Text(I18n.t(context, 'use_current_location')),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final value = await _promptManualLocation(ctx2, selectedCheckIn);
                                  if (value != null) {
                                    setSheetState(() => selectedCheckIn = value);
                                  }
                                },
                                icon: const Icon(Icons.edit_location_alt),
                                label: Text(I18n.t(context, 'set_location')),
                              ),
                            ],
                          ),
                          if (selectedCheckIn != null && selectedCheckIn!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: InputChip(
                                avatar: const Icon(Icons.place_outlined),
                                label: Text(selectedCheckIn!),
                                onDeleted: () => setSheetState(() => selectedCheckIn = null),
                              ),
                            ),
                         
                          if (hasNewAttachment || showExistingAttachment) ...[
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  if (pickedMedia != null)
                                    FutureBuilder<Uint8List>(
                                      future: pickedMedia!.readAsBytes(),
                                      builder: (context, snap) {
                                        if (!snap.hasData) {
                                          return const SizedBox(
                                            height: 160,
                                            child: Center(child: CircularProgressIndicator()),
                                          );
                                        }
                                        return Image.memory(snap.data!, height: 200, fit: BoxFit.cover);
                                      },
                                    )
                                  else if (pickedGifUrl != null)
                                    Image.network(
                                      pickedGifUrl!,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return SizedBox(
                                          height: 200,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: progress.expectedTotalBytes != null
                                                  ? progress.cumulativeBytesLoaded /
                                                      progress.expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 200,
                                        color: Colors.black26,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.broken_image, size: 32),
                                      ),
                                    )
                                  else if (showExistingAttachment)
                                    Image.network(
                                      _normalizeUploadUrl(existingImageUrl!),
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  if (hasNewAttachment)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Material(
                                        color: Colors.black54,
                                        shape: const CircleBorder(),
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                          onPressed: () => setSheetState(() {
                                            pickedMedia = null;
                                            pickedGifUrl = null;
                                          }),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: () async {
                                  final file = await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 85,
                                  );
                                  if (file != null) {
                                    setSheetState(() {
                                      pickedMedia = file;
                                      pickedGifUrl = null;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.image),
                                label: Text(I18n.t(context, 'add_image')),
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  final source = await _chooseGifSource(ctx2);
                                  if (source == 'device') {
                                    final file = await ImagePicker().pickImage(
                                      source: ImageSource.gallery,
                                      imageQuality: 100,
                                    );
                                    if (file != null) {
                                      if (!_isGifFile(file)) {
                                        _toast(context, I18n.t(context, 'invalid_gif'));
                                      } else {
                                        setSheetState(() {
                                          pickedMedia = file;
                                          pickedGifUrl = null;
                                        });
                                      }
                                    }
                                  } else if (source == 'url') {
                                    final url = await _promptGifUrl(ctx2, initialValue: pickedGifUrl);
                                    if (url != null) {
                                      setSheetState(() {
                                        pickedGifUrl = url;
                                        pickedMedia = null;
                                      });
                                    }
                                  }
                                },
                                icon: const Icon(Icons.gif_box),
                                label: Text(I18n.t(context, 'attach_gif')),
                              ),
                              OutlinedButton.icon(
                                onPressed: selectedGradient != null
                                    ? () => setSheetState(() => selectedGradient = null)
                                    : null,
                                icon: const Icon(Icons.layers_clear),
                                label: const Text('Reset vibe'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: canPublish ? () => Navigator.pop(ctx, true) : null,
                              child: Text(isEdit ? I18n.t(context, 'save') : I18n.t(context, 'publish')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );

    if (result != true) {
      controller.dispose();
      return;
    }

    try {
      var content = controller.text.trim();
      if (content.isEmpty) return;
      final meta = <String>[];
      if (selectedFeeling != null && selectedFeeling!.isNotEmpty) {
        meta.add('Mood: $selectedFeeling');
      }
      if (selectedActivity != null && selectedActivity!.isNotEmpty) {
        meta.add('Activity: $selectedActivity');
      }
      if (selectedCheckIn != null && selectedCheckIn!.isNotEmpty) {
        meta.add('Check-in: $selectedCheckIn');
      }
      if (selectedGradient != null) {
        meta.add('Vibe: Palette #${selectedGradient! + 1}');
      }
      if (meta.isNotEmpty) {
        content = [
          content,
          meta.map((m) => '• $m').join('\n'),
        ].where((section) => section.trim().isNotEmpty).join('\n\n');
      }

      if (isEdit) {
        final postId = (existing?['id'] as num?)?.toInt();
        if (postId == null) return;
        if (pickedMedia != null || pickedGifUrl != null) {
          _toast(context, I18n.t(context, 'edit_attachment_not_supported'));
        }
        await ApiService().updatePost(token, postId, content: content);
        await _fetchPosts();
        _toast(context, I18n.t(context, 'post_updated'));
        HapticFeedback.selectionClick();
      } else {
        if (pickedGifUrl != null) {
          try {
            final uri = Uri.parse(pickedGifUrl!);
            final response = await http.get(uri);
            if (response.statusCode >= 200 && response.statusCode < 300) {
              await ApiService().createPostWithImageBytes(
                token,
                content,
                response.bodyBytes,
                filename: 'gif_${DateTime.now().millisecondsSinceEpoch}.gif',
                contentType: 'image/gif',
              );
            } else {
              throw Exception('GIF status ${response.statusCode}');
            }
          } catch (e) {
            _toast(context, I18n.t(context, 'gif_fetch_failed'));
            return;
          }
        } else if (pickedMedia != null) {
          final isGif = _isGifFile(pickedMedia!);
          if (kIsWeb) {
            final bytes = await pickedMedia!.readAsBytes();
            await ApiService().createPostWithImageBytes(
              token,
              content,
              bytes,
              filename: pickedMedia!.name.isNotEmpty ? pickedMedia!.name : 'upload.jpg',
              contentType: isGif ? 'image/gif' : null,
            );
          } else {
            await ApiService().createPostWithImage(
              token,
              content,
              pickedMedia!.path,
              filename: pickedMedia!.name,
              contentType: isGif ? 'image/gif' : null,
            );
          }
        } else {
          await ApiService().createPost(token, content);
        }
        await _fetchPosts();
        _toast(context, I18n.t(context, 'post_published'));
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      _toast(context, '${I18n.t(context, 'save_failed')}: $e');
    } finally {
      controller.dispose();
    }
  }

  String _normalizeUploadUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    final base = ApiService.uploadBaseUrl;
    final needsSlash = !url.startsWith('/');
    return needsSlash ? '$base/$url' : '$base$url';
  }

  _PostContentParts _parsePostContent(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const _PostContentParts(text: '');
    }
    final lines = raw.split('\\n');
    final bodyLines = <String>[];
    String? mood;
    String? activity;
    String? checkIn;
    String? vibe;
    final metaPattern = RegExp(r'^(?:[\\u2022\\-*]\\s*)?(.+?):\\s*(.+)\$', caseSensitive: false);
    for (final line in lines) {
      final trimmed = line.trim();
      final sanitized = trimmed.replaceFirst(RegExp(r'^[\\u2022\\-*]\\s*'), '');
      final match = metaPattern.firstMatch(trimmed) ?? metaPattern.firstMatch(sanitized);
      if (match != null) {
        final key = match.group(1)!.toLowerCase();
        final value = match.group(2)!.trim();
        if (key.startsWith('mood')) {
          mood = value;
        } else if (key.startsWith('activity')) {
          activity = value;
        } else if (key.startsWith('check')) {
          checkIn = value;
        } else if (key.startsWith('vibe')) {
          vibe = value;
        }
        continue;
      }
      final lower = sanitized.toLowerCase();
      if (lower.startsWith('vibe palette') || lower.startsWith('vibe:')) {
        vibe = sanitized;
        continue;
      }
      bodyLines.add(line);
    }
    final textOnly = bodyLines.join('\\n').trim();
    return _PostContentParts(
      text: textOnly,
      mood: mood,
      activity: activity,
      checkIn: checkIn,
      vibe: vibe,
    );
  }

  int? _vibeIndexFromMeta(String? vibe, int paletteCount) {
    if (vibe == null || vibe.isEmpty) return null;
    final match = RegExp(r'#(\\d+)').firstMatch(vibe);
    if (match == null) return null;
    final parsed = int.tryParse(match.group(1) ?? '');
    if (parsed == null) return null;
    final index = parsed - 1;
    if (index < 0 || index >= paletteCount) return null;
    return index;
  }

  Future<String?> _resolveCurrentLocationName() async {
    try {
      final response = await http.get(Uri.parse('https://ipapi.co/json/'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final city = data['city']?.toString();
        final country = data['country_name']?.toString();
        if ((city == null || city.isEmpty) && (country == null || country.isEmpty)) {
          return null;
        }
        if (city == null || city.isEmpty) return country;
        if (country == null || country.isEmpty) return city;
        return '$city, $country';
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _promptManualLocation(BuildContext context, String? initial) async {
    final controller = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t(context, 'set_location')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: I18n.t(context, 'location_hint')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(I18n.t(context, 'cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(I18n.t(context, 'save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return null;
    final trimmed = result.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<String?> _chooseGifSource(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(I18n.t(context, 'gif_from_device')),
              onTap: () => Navigator.pop(ctx, 'device'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(I18n.t(context, 'gif_from_url')),
              onTap: () => Navigator.pop(ctx, 'url'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptGifUrl(BuildContext context, {String? initialValue}) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t(context, 'attach_gif')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(hintText: I18n.t(context, 'gif_url_hint')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(I18n.t(context, 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(I18n.t(context, 'save'))),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return null;
    final trimmed = result.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (!uri.hasScheme || !(uri.isScheme('http') || uri.isScheme('https')))) {
      _toast(context, I18n.t(context, 'invalid_gif_url'));
      return null;
    }
    return trimmed;
  }

  bool _isGifFile(XFile file) {
    final reference = (file.name.isNotEmpty ? file.name : file.path).toLowerCase();
    return reference.endsWith('.gif');
  }

  ImageProvider? _stickerProviderFor(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString();
    if (value.isEmpty) return null;
    if (value.startsWith('http')) {
      return NetworkImage(_normalizeUploadUrl(value));
    }
    if (value.startsWith('assets/')) {
      return AssetImage(value);
    }
    return AssetImage('assets/stickers/$value');
  }

  Widget _postCard(BuildContext context, Map<String, dynamic> post) {
    final theme = Theme.of(context);
    final postId = (post['id'] as num?)?.toInt() ?? 0;
    final storedCounts = _reactionCounts[postId];
    final counts = storedCounts != null
        ? Map<String, int>.from(storedCounts)
        : _countsFromDynamic(post['reactions']);
    counts.putIfAbsent('like', () => post['likes'] is num ? (post['likes'] as num).toInt() : 0);
    final totalReactions = _totalReactions(counts);
    final userReaction = _userReactions[postId];
    final commentCount = _commentCounts[postId] ?? (post['comments_count'] as int? ?? 0);

    final parts = _parsePostContent(post['content'] as String?);
    final bodyText = parts.text;
    final vibeIndex = _vibeIndexFromMeta(parts.vibe, _kVibePalettes.length);
    final vibePalette = vibeIndex != null ? _kVibePalettes[vibeIndex] : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface.withOpacity(0.92),
                theme.colorScheme.surfaceVariant.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 26, offset: const Offset(0, 14)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _postHeader(context, post, parts),
              if (bodyText.isNotEmpty || vibePalette != null) ...[
                const SizedBox(height: 12),
                _PostBodyBlock(text: bodyText, palette: vibePalette),
              ],
              if ((post['image_url'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 14),
                _postMedia(context, post['image_url'] as String),
              ],
              if (totalReactions > 0) ...[
                const SizedBox(height: 16),
                _ReactionSummary(
                  counts: counts,
                  total: totalReactions,
                  onTap: () => _openReactionDetails(context, postId),
                ),
              ],
              const SizedBox(height: 16),
              _postFooter(
                context,
                postId: postId,
                userReaction: userReaction,
                totalReactions: totalReactions,
                commentCount: commentCount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postHeader(BuildContext context, Map<String, dynamic> post, _PostContentParts parts) {
    final theme = Theme.of(context);
    final user = post['user'] as Map<String, dynamic>?;
    final displayName = [
      user?['full_name'],
      user?['name'],
      user?['username'],
    ].map((value) => value?.toString().trim()).firstWhere((value) => value != null && value!.isNotEmpty, orElse: () => 'User')!;
    final avatar = (user?['avatar'] as String?) ?? '';
    final frame = (user?['frame'] as String?) ?? 'none';
    final sticker = _stickerProviderFor(user?['sticker'] ?? user?['avatar_sticker']);
    final createdAt = post['created_at'] as String?;
    final visibility = post['visibility'] as String? ?? 'public';
    final timeAgo = _timeAgo(createdAt);
    final metaPills = <Widget>[];
    if (parts.mood != null && parts.mood!.isNotEmpty) {
      metaPills.add(_PostMetaPill(icon: Icons.emoji_emotions_outlined, label: parts.mood!, color: theme.colorScheme.primary));
    }
    if (parts.activity != null && parts.activity!.isNotEmpty) {
      metaPills.add(_PostMetaPill(icon: Icons.flash_on, label: parts.activity!, color: theme.colorScheme.secondary));
    }
    if (parts.checkIn != null && parts.checkIn!.isNotEmpty) {
      metaPills.add(_PostMetaPill(icon: Icons.place_outlined, label: parts.checkIn!, color: theme.colorScheme.tertiary));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FramedAvatar(
          image: avatar.isNotEmpty ? NetworkImage(_normalizeUploadUrl(avatar)) : null,
          name: displayName,
          radius: 20,
          frameStyle: frame,
          stickerImage: sticker,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (timeAgo.isNotEmpty) ...[
                const SizedBox(height: 6),
                _PostMetaInfoChip(
                  icon: Icons.access_time,
                  label: timeAgo,
                  trailing: Icon(_visibilityIcon(visibility), size: 14, color: theme.hintColor),
                ),
              ],
              if (metaPills.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: metaPills,
                ),
              ],
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: () => _showPostActions(context, post),
        )
      ],
    );
  }

  Widget _postMedia(BuildContext context, String url) {
    final normalized = _normalizeUploadUrl(url);
    return GestureDetector(
      onTap: () => _openImageViewer(context, normalized),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          normalized,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            height: 200,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image, size: 32),
          ),
        ),
      ),
    );
  }

  Widget _postFooter(
    BuildContext context, {
    required int postId,
    required String? userReaction,
    required int totalReactions,
    required int commentCount,
  }) {
    final theme = Theme.of(context);
    final visual = _visualForReaction(userReaction ?? 'like');
    final isActive = userReaction != null;
    return Row(
      children: [
        _ReactionPill(
          leading: Icon(visual.icon, size: 18, color: isActive ? visual.color : theme.hintColor),
          label: isActive ? _reactionLabel(context, userReaction!) : I18n.t(context, 'like'),
          count: totalReactions,
          color: isActive ? visual.color : null,
          active: isActive,
          onTap: () => _toggleReaction(context, postId, userReaction ?? 'like'),
          onLongPress: () => _openReactionPicker(context, postId),
          onCountTap: totalReactions > 0 ? () => _openReactionDetails(context, postId) : null,
        ),
        const SizedBox(width: 12),
        _ReactionPill(
          leading: Icon(Icons.mode_comment_outlined, size: 18, color: theme.hintColor),
          label: I18n.t(context, 'comment'),
          count: commentCount,
          color: null,
          onTap: () => _openComments(context, postId),
        ),
        const Spacer(),
        _GlassIconButton(
          icon: Icons.ios_share,
          label: I18n.t(context, 'share'),
          onTap: () => _toast(context, I18n.t(context, 'coming_soon')),
        ),
      ],
    );
  }

  bool _isPostOwner(Map<String, dynamic> post) {
    if (post['is_owner'] == true) return true;
    final user = post['user'] as Map<String, dynamic>?;
    final postOwner = _asInt(user?['id']) ?? _asInt(post['user_id']);
    return _currentUserId != null && postOwner == _currentUserId;
  }

  Future<void> _showPostActions(BuildContext context, Map<String, dynamic> post) async {
    final isOwner = _isPostOwner(post);
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.surface.withOpacity(0.96),
                      theme.colorScheme.surfaceVariant.withOpacity(0.82),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOwner)
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: Text(I18n.t(context, 'edit_post')),
                          onTap: () => Navigator.pop(ctx, 'edit'),
                        ),
                      if (isOwner)
                        ListTile(
                          leading: const Icon(Icons.delete_forever),
                          title: Text(I18n.t(context, 'delete')),
                          onTap: () => Navigator.pop(ctx, 'delete'),
                        ),
                      ListTile(
                        leading: const Icon(Icons.copy),
                        title: Text(I18n.t(context, 'share')),
                        onTap: () => Navigator.pop(ctx, 'copy'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    switch (result) {
      case 'edit':
        _openCreatePost(context, existing: post);
        break;
      case 'delete':
        await _deletePost(context, post);
        break;
      case 'copy':
        final content = (post['content'] as String?) ?? '';
        await Clipboard.setData(ClipboardData(text: content));
        _toast(context, I18n.t(context, 'copied'));
        break;
    }
  }

  Future<void> _deletePost(BuildContext context, Map<String, dynamic> post) async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('auth_token');
    if (token == null) {
      _toast(context, I18n.t(context, 'not_authenticated'));
      return;
    }
    final id = _asInt(post['id']);
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t(context, 'delete')),
        content: Text(I18n.t(context, 'delete_post_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(I18n.t(context, 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(I18n.t(context, 'delete'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().deletePost(token, id);
      if (!mounted) return;
      setState(() {
        _posts.removeWhere((element) => _asInt(element['id']) == id);
        _reactionCounts.remove(id);
        _userReactions.remove(id);
        _commentCounts.remove(id);
      });
      _toast(context, I18n.t(context, 'post_deleted'));
    } catch (e) {
      _toast(context, '${I18n.t(context, 'save_failed')}: $e');
    }
  }

  Future<void> _openComments(BuildContext context, int postId) async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('auth_token');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: _CommentsSheet(
            postId: postId,
            token: token,
            onCountChanged: (count) {
              if (!mounted) return;
              setState(() => _commentCounts[postId] = count);
            },
            normalizeUrl: _normalizeUploadUrl,
            timeAgo: _timeAgo,
            currentUserId: _currentUserId,
          ),
        );
      },
    );
  }

  Future<void> _toggleReaction(BuildContext context, int postId, String reactionType) async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('auth_token');
    if (token == null) {
      _toast(context, I18n.t(context, 'not_authenticated'));
      return;
    }
    try {
      await ApiService().reactToPost(token, postId, type: reactionType);
      await _refreshReactionsFor(postId);
    } catch (e) {
      _toast(context, 'Eroare: $e');
    }
  }

  Future<void> _openReactionDetails(BuildContext context, int postId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('auth_token');
      final data = await ApiService().getReactions(postId, token: token);
      if (!mounted) return;
      final rawList = data['reactions'];
      final reactions = <Map<String, dynamic>>[];
      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map) {
            reactions.add(item.map((key, value) => MapEntry(key.toString(), value)));
          }
        }
      }
      if (!context.mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ReactionDetailsSheet(
          reactions: reactions,
          normalizeUrl: _normalizeUploadUrl,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast(context, '${I18n.t(context, 'error')}: $e');
    }
  }

  Future<void> _openReactionPicker(BuildContext context, int postId) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.surface.withOpacity(0.95),
                      theme.colorScheme.surfaceVariant.withOpacity(0.78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        I18n.t(ctx, 'choose_reaction'),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final type in _kReactionOrder)
                            _ReactionChoice(
                              visual: _visualForReaction(type),
                              label: _reactionLabel(ctx, type),
                              onTap: () => Navigator.of(ctx).pop(type),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (selected != null) {
      await _toggleReaction(context, postId, selected);
    }
  }

  Future<void> _ensureCommentsCount(int postId) async {
    if (_commentCounts.containsKey(postId)) return;
    try {
      final list = await ApiService().getComments(postId);
      if (!mounted) return;
      setState(() => _commentCounts[postId] = list.length);
    } catch (_) {}
  }

  Future<void> _refreshReactionsFor(int postId) async {
    try {
      final data = await ApiService().getReactions(postId);
      final parsed = _countsFromDynamic(data['counts']);
      if (!mounted) return;
      setState(() {
        _reactionCounts[postId] = parsed;
        _userReactions[postId] = data['user_reaction'] as String?;
      });
    } catch (_) {}
  }

  IconData _visibilityIcon(String value) {
    switch (value) {
      case 'friends':
        return Icons.group;
      case 'private':
        return Icons.lock;
      default:
        return Icons.public;
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) return '';
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'acum câteva sec.';
      if (diff.inMinutes < 60) return 'acum ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'acum ${diff.inHours} h';
      if (diff.inDays < 7) return 'acum ${diff.inDays} z';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Future<_ComposerAvatar> _loadAvatarForComposer({bool refresh = false}) async {
    final sp = await SharedPreferences.getInstance();
    String? name = sp.getString('profile_name');
    String frame = sp.getString('profile_avatar_frame') ?? 'none';
    String? avatarUrl = sp.getString('profile_avatar_url');
    final token = sp.getString('auth_token');

    final needsFetch = refresh ||
        avatarUrl == null ||
        avatarUrl.isEmpty ||
        name == null ||
        name.isEmpty;
    if (needsFetch && token != null && token.isNotEmpty) {
      try {
        final profile = await ApiService().getProfile(token);
        final remoteName = (profile['full_name'] as String?)?.trim();
        final remoteFrame = (profile['avatar_frame'] as String?)?.trim();
        final remoteAvatar = (profile['avatar_url'] as String?)?.trim();
        if (remoteName != null && remoteName.isNotEmpty) {
          name = remoteName;
          await sp.setString('profile_name', remoteName);
        }
        if (remoteFrame != null && remoteFrame.isNotEmpty) {
          frame = remoteFrame;
          await sp.setString('profile_avatar_frame', remoteFrame);
        }
        if (remoteAvatar != null && remoteAvatar.isNotEmpty) {
          avatarUrl = remoteAvatar;
          await sp.setString('profile_avatar_url', remoteAvatar);
        }
      } catch (_) {}
    }

    name ??= sp.getString('auth_username') ?? 'U';
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    ImageProvider? image;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      image = NetworkImage(_normalizeUploadUrl(avatarUrl));
    }
    return _ComposerAvatar(image, initials, frame);
  }

  void _openImageViewer(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
  
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.leading,
    required this.label,
    required this.count,
    required this.onTap,
    this.onLongPress,
    this.active = false,
    this.color,
    this.dense = false,
    this.onCountTap,
  });

  final Widget leading;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final bool dense;
  final VoidCallback? onCountTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? (active ? theme.colorScheme.primary : theme.hintColor);
    final horizontal = dense ? 12.0 : 14.0;
    final vertical = dense ? 8.0 : 10.0;
    final gradient = color != null
        ? [
            color!.withOpacity(active ? 0.25 : 0.16),
            color!.withOpacity(active ? 0.12 : 0.06),
          ]
        : active
            ? [
                theme.colorScheme.primary.withOpacity(0.2),
                theme.colorScheme.primary.withOpacity(0.08),
              ]
            : [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ];
    final borderColor = color != null
        ? color!.withOpacity(active ? 0.4 : 0.2)
        : (active
            ? theme.colorScheme.primary.withOpacity(0.4)
            : Colors.white.withOpacity(0.12));
    final countChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(active || color != null ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$count', style: theme.textTheme.labelSmall?.copyWith(color: effectiveColor)),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    leading,
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(color: effectiveColor),
                    ),
                  ],
                ),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onCountTap ?? onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: dense ? 4 : 6,
                    vertical: dense ? 3 : 4,
                  ),
                  child: countChip,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withOpacity(0.08),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: theme.hintColor),
                  const SizedBox(width: 6),
                  Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionSummary extends StatelessWidget {
  const _ReactionSummary({required this.counts, required this.total, this.onTap});

  final Map<String, int> counts;
  final int total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final top = _topReactions(counts);
    if (top.isEmpty || total == 0) return const SizedBox.shrink();
    final items = top.take(3).toList();
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 32,
                width: 32 + (items.length - 1) * 18,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Positioned(
                        left: i * 18,
                        child: _ReactionBadge(visual: _visualForReaction(items[i].key)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${I18n.t(context, 'reactions')}: $total',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionBadge extends StatelessWidget {
  const _ReactionBadge({required this.visual});

  final _ReactionVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: visual.color.withOpacity(0.15),
        border: Border.all(color: visual.color.withOpacity(0.4), width: 1.5),
      ),
      child: Icon(visual.icon, size: 18, color: visual.color),
    );
  }
}

class _ReactionDetailsSheet extends StatelessWidget {
  const _ReactionDetailsSheet({required this.reactions, required this.normalizeUrl});

  final List<Map<String, dynamic>> reactions;
  final String Function(String?) normalizeUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.65;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.surface.withOpacity(0.96),
                  theme.colorScheme.surfaceVariant.withOpacity(0.82),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.emoji_emotions, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              I18n.t(context, 'people_reacted'),
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                    if (reactions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          I18n.t(context, 'no_reactions_yet'),
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemBuilder: (ctx, index) {
                            final entry = reactions[index];
                            final type = entry['type']?.toString() ?? 'like';
                            final visual = _visualForReaction(type);
                            final rawName = entry['name']?.toString().trim();
                            final name = (rawName == null || rawName.isEmpty) ? 'User' : rawName;
                            final username = entry['username']?.toString().trim();
                            final avatarUrl = entry['avatar_url']?.toString().trim();
                            ImageProvider? avatar;
                            if (avatarUrl != null && avatarUrl.isNotEmpty) {
                              avatar = NetworkImage(normalizeUrl(avatarUrl));
                            }
                            final subtitle = (username != null && username.isNotEmpty) ? '@$username' : null;
                            final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatar,
                                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                child: avatar == null
                                    ? Text(initials)
                                    : null,
                              ),
                              title: Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              subtitle: subtitle != null ? Text(subtitle, style: theme.textTheme.bodySmall) : null,
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Icon(visual.icon, color: visual.color, size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    I18n.t(ctx, visual.labelKey),
                                    style: theme.textTheme.labelSmall?.copyWith(color: visual.color),
                                  ),
                                ],
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                          itemCount: reactions.length,
                        ),
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

class _CommentAttachmentGallery extends StatelessWidget {
  const _CommentAttachmentGallery({
    required this.attachments,
    required this.normalizeUrl,
    required this.onPreview,
  });

  final List<_CommentAttachment> attachments;
  final String Function(String?) normalizeUrl;
  final void Function(String url) onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: attachments.map((attachment) {
        final url = normalizeUrl(attachment.url);
        final overlayColor = attachment.type == _CommentAttachmentType.gif
            ? theme.colorScheme.primary
            : theme.colorScheme.secondary;
        return GestureDetector(
          onTap: () => onPreview(url),
          child: SizedBox(
            width: 120,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black12),
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                    ),
                    if (attachment.type == _CommentAttachmentType.gif)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: overlayColor.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('GIF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ComposerAttachmentPreview extends StatelessWidget {
  const _ComposerAttachmentPreview({
    required this.attachments,
    required this.normalizeUrl,
    required this.onRemove,
    required this.onPreview,
  });

  final List<_CommentAttachment> attachments;
  final String Function(String?) normalizeUrl;
  final void Function(int index) onRemove;
  final void Function(String url) onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: attachments.asMap().entries.map((entry) {
        final index = entry.key;
        final attachment = entry.value;
        final url = normalizeUrl(attachment.url);
        return GestureDetector(
          onTap: () => onPreview(url),
          child: SizedBox(
            width: 110,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black12),
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => onRemove(index),
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    if (attachment.type == _CommentAttachmentType.gif)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('GIF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReactionChoice extends StatelessWidget {
  const _ReactionChoice({required this.visual, required this.label, required this.onTap});

  final _ReactionVisual visual;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                visual.color.withOpacity(0.22),
                visual.color.withOpacity(0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: visual.color.withOpacity(0.42)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(visual.icon, color: visual.color),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.postId,
    required this.token,
    required this.onCountChanged,
    required this.normalizeUrl,
    required this.timeAgo,
    required this.currentUserId,
  });

  final int postId;
  final String? token;
  final ValueChanged<int> onCountChanged;
  final String Function(String?) normalizeUrl;
  final String Function(String?) timeAgo;
  final int? currentUserId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<_CommentNode> _roots = [];
  final Map<int, _CommentNode> _nodeById = {};
  final Map<int, Map<String, int>> _commentReactions = {};
  final Map<int, String?> _userCommentReactions = {};
  final Set<int> _loadingReactions = <int>{};
  final Set<int> _expandedComments = <int>{};
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  _CommentNode? _replyTarget;
  int? _editingCommentId;
  final List<_CommentAttachment> _pendingAttachments = [];
  bool _uploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService().getComments(widget.postId);
      final normalized = <Map<String, dynamic>>[];
      for (final item in list) {
        normalized.add(_normalizeCommentRecord(item));
      }
      if (!mounted) return;
      setState(() {
        _roots
          ..clear()
          ..addAll(_buildCommentTree(normalized));
        _nodeById
          ..clear();
        _indexNodes(_roots);
        _expandedComments.clear();
        _loading = false;
      });
      _prefetchCommentReactions();
      widget.onCountChanged(_nodeById.length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<_CommentNode> _buildCommentTree(List<Map<String, dynamic>> raw) {
    final nodeMap = <int, _CommentNode>{};
    final nodes = <_CommentNode>[];
    for (final data in raw) {
      final node = _CommentNode(data);
      final id = node.id;
      if (id != null) {
        nodeMap[id] = node;
      }
      nodes.add(node);
    }
    final roots = <_CommentNode>[];
    for (final node in nodes) {
      final parentId = node.parentId;
      if (parentId != null && nodeMap.containsKey(parentId)) {
        nodeMap[parentId]!.children.add(node);
      } else {
        roots.add(node);
      }
    }
    return roots;
  }

  void _indexNodes(List<_CommentNode> nodes) {
    for (final node in nodes) {
      final id = node.id;
      if (id != null) {
        _nodeById[id] = node;
      }
      if (node.children.isNotEmpty) {
        _indexNodes(node.children);
      }
    }
  }

  void _insertComment(Map<String, dynamic> comment) {
    final node = _CommentNode(_normalizeCommentRecord(comment));
    final id = node.id;
    if (id != null) {
      _nodeById[id] = node;
    }
    final parentId = node.parentId;
    if (parentId != null && _nodeById.containsKey(parentId)) {
      final parent = _nodeById[parentId]!;
      parent.children.insert(0, node);
      _expandedComments.add(parentId);
    } else {
      _roots.insert(0, node);
    }
    if (id != null) {
      unawaited(_fetchCommentReactions(id));
    }
  }

  void _applyUpdatedComment(Map<String, dynamic> updated) {
    final id = _asInt(updated['id']);
    if (id == null) return;
    final node = _nodeById[id];
    if (node == null) return;
    node.data = _normalizeCommentRecord(updated);
  }

  Map<String, dynamic> _normalizeCommentRecord(dynamic raw) {
    final map = <String, dynamic>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (key == null) return;
        map[key.toString()] = value;
      });
    }

    Map<String, dynamic> ensureMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return Map<String, dynamic>.from(value);
      }
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    }

    String? clean(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final user = ensureMap(map['user']);
    final id = _asInt(user['id']) ?? _asInt(map['user_id']);
    if (id != null) {
      user['id'] = id;
    }

    final resolvedName = clean(user['name']) ?? clean(user['full_name']) ?? clean(map['user_name']);
    if (resolvedName != null) {
      user.putIfAbsent('name', () => resolvedName);
      user.putIfAbsent('full_name', () => resolvedName);
      user.putIfAbsent('username', () => resolvedName);
    } else if (id != null && clean(user['name']) == null) {
      user['name'] = 'User #$id';
      user.putIfAbsent('full_name', () => 'User #$id');
      user.putIfAbsent('username', () => 'user$id');
    }

    final resolvedAvatar = clean(user['avatar']) ?? clean(map['user_avatar']);
    if (resolvedAvatar != null) {
      user['avatar'] = resolvedAvatar;
    }

    map['user'] = user;

    final rawContent = map['content']?.toString() ?? '';
    final parsedContent = _splitCommentContent(rawContent);
    map['raw_content'] = rawContent;
    map['content'] = parsedContent.text;
    map['attachments'] = parsedContent.attachments.map((e) => e.toMap()).toList();
    return map;
  }

  Future<void> _deleteComment(int id) async {
    final token = widget.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'not_authenticated'))),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t(context, 'delete')),
        content: Text(I18n.t(context, 'delete_comment_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(I18n.t(context, 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(I18n.t(context, 'delete'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().deleteComment(token, id);
      if (!mounted) return;
      setState(() {
        _removeNode(id);
        if (_replyTarget?.id == id) _replyTarget = null;
        if (_editingCommentId == id) {
          _editingCommentId = null;
          _controller.clear();
        }
      });
      widget.onCountChanged(_nodeById.length);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'comment_deleted'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t(context, 'save_failed')}: $e')),
      );
    }
  }

  void _removeNode(int id) {
    _nodeById.remove(id);
    _commentReactions.remove(id);
    _userCommentReactions.remove(id);
    _expandedComments.remove(id);
    _removeNodeFromList(_roots, id);
  }

  bool _removeNodeFromList(List<_CommentNode> list, int id) {
    for (var i = 0; i < list.length; i++) {
      final node = list[i];
      if (node.id == id) {
        list.removeAt(i);
        return true;
      }
      if (_removeNodeFromList(node.children, id)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _submit() async {
    final token = widget.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'not_authenticated'))),
      );
      return;
    }
    final text = _controller.text.trim();
    if ((text.isEmpty && _pendingAttachments.isEmpty) || _submitting) return;
    setState(() => _submitting = true);
    try {
      final sections = <String>[];
      if (text.isNotEmpty) {
        sections.add(text);
      }
      for (final attachment in _pendingAttachments) {
        sections.add('$_kCommentAttachmentPrefix${attachment.type.name}|${attachment.url}');
      }
      final payload = sections.join('\n');
      if (_editingCommentId != null) {
        final updated = await ApiService().updateComment(token, _editingCommentId!, payload);
        if (!mounted) return;
        setState(() {
          _applyUpdatedComment(updated);
          _submitting = false;
          _controller.clear();
          _editingCommentId = null;
          _pendingAttachments.clear();
        });
        HapticFeedback.selectionClick();
      } else {
        final comment = await ApiService().addComment(token, widget.postId, payload, parentId: _replyTarget?.id);
        if (!mounted) return;
        setState(() {
          _insertComment(comment);
          _submitting = false;
          _controller.clear();
          _replyTarget = null;
          _pendingAttachments.clear();
        });
        widget.onCountChanged(_nodeById.length);
        HapticFeedback.lightImpact();
      }
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t(context, 'save_failed')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text(_error!, style: theme.textTheme.bodyMedium));
    } else if (_roots.isEmpty) {
      body = Center(child: Text(I18n.t(context, 'no_comments_yet'), style: theme.textTheme.bodyMedium));
    } else {
      final items = _roots
          .map((node) => _buildCommentWidget(theme, node, 0))
          .toList(growable: false);
      body = ListView.separated(
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) => items[index],
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: items.length,
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface.withOpacity(0.96),
                theme.colorScheme.surfaceVariant.withOpacity(0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.24),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(I18n.t(context, 'comment'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: I18n.t(context, 'reload'),
                        onPressed: _load,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: body),
                  const SizedBox(height: 12),
                  _composer(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentWidget(ThemeData theme, _CommentNode node, int depth) {
    final commentId = node.id;
    final tile = _commentTile(theme, node, depth);
    if (commentId == null || node.children.isEmpty) {
      return tile;
    }
    final expanded = _expandedComments.contains(commentId);
    final count = node.children.length;
    final label = expanded
        ? I18n.t(context, 'hide_replies')
        : I18n.t(context, 'view_replies').replaceFirst('%d', '$count');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tile,
        Padding(
          padding: EdgeInsets.only(left: (depth + 1) * 20.0, top: 4),
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                if (expanded) {
                  _expandedComments.remove(commentId);
                } else {
                  _expandedComments.add(commentId);
                }
              });
            },
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 16),
            label: Text(label),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              const SizedBox(height: 8),
              for (final child in node.children)
                Padding(
                  padding: EdgeInsets.only(left: (depth + 1) * 20.0, top: 8),
                  child: _buildCommentWidget(theme, child, depth + 1),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _commentTile(ThemeData theme, _CommentNode node, int depth) {
    final comment = node.data;
    final user = (comment['user'] as Map<String, dynamic>?) ?? const {};
    final name = (user['name'] as String?) ?? 'User';
    final avatarUrl = widget.normalizeUrl(user['avatar'] as String?);
    final frame = (user['frame'] as String?) ?? 'none';
    final content = (comment['content'] as String?) ?? '';
    final rawContent = comment['raw_content']?.toString() ?? content;
    final attachmentsList = (comment['attachments'] as List?) ?? const [];
    final attachments = attachmentsList
        .whereType<Map>()
        .map((map) => _CommentAttachment.fromMap(map.map((k, v) => MapEntry(k.toString(), v))))
        .where((attachment) => attachment.url.isNotEmpty)
        .toList();
    final createdAt = widget.timeAgo(comment['created_at'] as String?);
    final commentId = node.id;
    final reactions = commentId != null ? _commentReactions[commentId] ?? _countsFromDynamic(comment['reactions']) : null;
    final total = _totalReactions(reactions);
    final userReaction = commentId != null ? _userCommentReactions[commentId] : null;
    final visual = _visualForReaction(userReaction ?? 'like');
    final isLoading = commentId != null && _loadingReactions.contains(commentId);
    final ownerId = _asInt(user['id']) ?? _asInt(comment['user_id']);
    final canManage = ownerId != null && ownerId == widget.currentUserId;

    return Padding(
      padding: EdgeInsets.only(left: depth * 20.0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FramedAvatar(
              image: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              name: name,
              radius: 16,
              frameStyle: frame,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text(createdAt, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                      if (canManage && commentId != null)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              setState(() {
                                _editingCommentId = commentId;
                                _controller.text = content;
                                _pendingAttachments
                                  ..clear()
                                  ..addAll(attachments);
                              });
                              _focusNode.requestFocus();
                            } else if (value == 'delete') {
                              _deleteComment(commentId);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'edit', child: Text(I18n.t(context, 'edit'))),
                            PopupMenuItem(value: 'delete', child: Text(I18n.t(context, 'delete'))),
                          ],
                        ),
                    ],
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(content, style: theme.textTheme.bodyMedium),
                  ],
                  if (attachments.isNotEmpty) ...[
                    SizedBox(height: content.isNotEmpty ? 10 : 6),
                    _CommentAttachmentGallery(
                      attachments: attachments,
                      normalizeUrl: widget.normalizeUrl,
                      onPreview: _openAttachmentViewer,
                    ),
                  ],
                  if (commentId != null)
                    Row(
                      children: [
                        _ReactionPill(
                          leading: isLoading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(visual.color),
                                  ),
                                )
                              : Icon(
                                  visual.icon,
                                  size: 16,
                                  color: userReaction != null ? visual.color : theme.hintColor,
                                ),
                          label: userReaction != null ? _reactionLabel(context, userReaction) : I18n.t(context, 'like'),
                          count: total,
                          color: userReaction != null ? visual.color : null,
                          active: userReaction != null,
                          dense: true,
                          onTap: () => _toggleCommentReaction(commentId, userReaction ?? 'like'),
                          onLongPress: () => _openCommentReactionPicker(commentId),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () {
                            setState(() => _replyTarget = node);
                            _focusNode.requestFocus();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            textStyle: theme.textTheme.labelMedium,
                          ),
                          child: Text(I18n.t(context, 'reply')),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(ThemeData theme) {
    final contextNode = _editingCommentId != null
        ? _nodeById[_editingCommentId!]
        : _replyTarget;
    final contextLabel = _editingCommentId != null
        ? I18n.t(context, 'editing_comment')
        : contextNode != null
            ? I18n.t(context, 'replying_to').replaceFirst('%s', (contextNode.data['user'] as Map?)?['name']?.toString() ?? 'User')
            : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (contextLabel != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Icon(_editingCommentId != null ? Icons.edit : Icons.reply, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(contextLabel, style: theme.textTheme.labelMedium)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _replyTarget = null;
                      _editingCommentId = null;
                      _controller.clear();
                      _pendingAttachments.clear();
                    });
                  },
                  child: Text(I18n.t(context, 'cancel')),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        tooltip: I18n.t(context, 'add_emoji'),
                        onPressed: _showEmojiKeyboard,
                      ),
                      IconButton(
                        icon: const Icon(Icons.gif_box),
                        tooltip: I18n.t(context, 'attach_gif'),
                        onPressed: _uploadingAttachment ? null : _pickGifAttachment,
                      ),
                      IconButton(
                        icon: const Icon(Icons.image_outlined),
                        tooltip: I18n.t(context, 'attach_photo'),
                        onPressed: _uploadingAttachment ? null : _pickImageAttachment,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: I18n.t(context, 'write_comment'),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _submitting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton(
                              icon: const Icon(Icons.send_rounded),
                              color: theme.colorScheme.primary,
                              onPressed: _uploadingAttachment ? null : _submit,
                            ),
                    ],
                  ),
                  if (_pendingAttachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ComposerAttachmentPreview(
                      attachments: _pendingAttachments,
                      normalizeUrl: widget.normalizeUrl,
                      onRemove: _removePendingAttachment,
                      onPreview: _openAttachmentViewer,
                    ),
                  ],
                  if (_uploadingAttachment) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      minHeight: 3,
                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _prefetchCommentReactions() {
    for (final id in _nodeById.keys) {
      unawaited(_fetchCommentReactions(id));
    }
  }

  void _openAttachmentViewer(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _removePendingAttachment(int index) {
    if (index < 0 || index >= _pendingAttachments.length) return;
    setState(() {
      _pendingAttachments.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.t(context, 'attachment_removed'))),
    );
  }

  Future<void> _fetchCommentReactions(int commentId) async {
    if (_loadingReactions.contains(commentId)) return;
    if (!mounted) return;
    setState(() => _loadingReactions.add(commentId));
    try {
      final data = await ApiService().getCommentReactions(commentId, token: widget.token);
      final counts = _countsFromDynamic(data['counts']);
      if (!mounted) return;
      setState(() {
        _commentReactions[commentId] = counts;
        _userCommentReactions[commentId] = data['user_reaction'] as String?;
        _loadingReactions.remove(commentId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReactions.remove(commentId));
    }
  }

  Future<void> _toggleCommentReaction(int commentId, String reactionType) async {
    final token = widget.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'not_authenticated'))),
      );
      return;
    }
    try {
      await ApiService().reactToComment(token, commentId, type: reactionType);
      await _fetchCommentReactions(commentId);
      HapticFeedback.selectionClick();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t(context, 'save_failed')}: $e')),
      );
    }
  }

  Future<void> _openCommentReactionPicker(int commentId) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.surface.withOpacity(0.95),
                      theme.colorScheme.surfaceVariant.withOpacity(0.78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        I18n.t(ctx, 'choose_reaction'),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final type in _kReactionOrder)
                            _ReactionChoice(
                              visual: _visualForReaction(type),
                              label: _reactionLabel(ctx, type),
                              onTap: () => Navigator.of(ctx).pop(type),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (selected != null) {
      await _toggleCommentReaction(commentId, selected);
    }
  }

  Future<void> _pickImageAttachment() async {
    final token = widget.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'not_authenticated'))),
      );
      return;
    }
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      await _uploadAttachment(token, file, _CommentAttachmentType.image);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t(context, 'save_failed')}: $e')),
      );
    }
  }

  Future<void> _pickGifAttachment() async {
    final token = widget.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'not_authenticated'))),
      );
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(I18n.t(context, 'gif_from_device')),
              onTap: () => Navigator.pop(ctx, 'device'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(I18n.t(context, 'gif_from_url')),
              onTap: () => Navigator.pop(ctx, 'url'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'device') {
      try {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 100);
        if (file == null) return;
        final name = file.name.isNotEmpty ? file.name.toLowerCase() : file.path.toLowerCase();
        if (!name.endsWith('.gif')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(I18n.t(context, 'invalid_gif'))),
          );
          return;
        }
        await _uploadAttachment(token, file, _CommentAttachmentType.gif);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${I18n.t(context, 'save_failed')}: $e')),
        );
      }
    } else if (choice == 'url') {
      final url = await _promptGifUrl();
      if (url == null) return;
      setState(() {
        _pendingAttachments.add(_CommentAttachment(_CommentAttachmentType.gif, url));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'attachment_added'))),
      );
    }
  }

  Future<String?> _promptGifUrl() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t(context, 'attach_gif')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(hintText: I18n.t(context, 'gif_url_hint')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(I18n.t(context, 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(I18n.t(context, 'save'))),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return null;
    final uri = Uri.tryParse(result.trim());
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'invalid_gif_url'))),
      );
      return null;
    }
    return result.trim();
  }

  Future<void> _uploadAttachment(String token, XFile file, _CommentAttachmentType type) async {
    setState(() => _uploadingAttachment = true);
    try {
      String url;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        url = await ApiService().uploadCommentMediaBytes(token, bytes, filename: file.name.isNotEmpty ? file.name : 'attachment');
      } else {
        url = await ApiService().uploadCommentMedia(token, file.path, filename: file.name.isNotEmpty ? file.name : null);
      }
      if (!mounted) return;
      setState(() {
        _pendingAttachments.add(_CommentAttachment(type, url));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'attachment_added'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t(context, 'attachment_upload_failed')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingAttachment = false);
      }
    }
  }

  Future<void> _showEmojiKeyboard() async {
    FocusScope.of(context).requestFocus(_focusNode);
    await SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  void _toastUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.t(context, 'coming_soon'))),
    );
  }
  
}

class _ComposerAvatar {
  const _ComposerAvatar(this.img, this.initials, this.frame);
  final ImageProvider? img;
  final String initials;
  final String frame;
}

class _CommentNode {
  _CommentNode(Map<String, dynamic> data) : data = Map<String, dynamic>.from(data);

  Map<String, dynamic> data;
  final List<_CommentNode> children = [];

  int? get id => (data['id'] as num?)?.toInt();
  int? get parentId => (data['parent_id'] as num?)?.toInt();
}

enum _CommentAttachmentType { image, gif }

class _CommentAttachment {
  const _CommentAttachment(this.type, this.url);

  final _CommentAttachmentType type;
  final String url;

  Map<String, dynamic> toMap() => {'type': type.name, 'url': url};

  static _CommentAttachment fromMap(Map<String, dynamic> map) {
    final typeName = map['type']?.toString() ?? 'image';
    final url = map['url']?.toString() ?? '';
    final type = _CommentAttachmentType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => _CommentAttachmentType.image,
    );
    return _CommentAttachment(type, url);
  }
}

class _ParsedCommentContent {
  const _ParsedCommentContent({required this.text, required this.attachments});

  final String text;
  final List<_CommentAttachment> attachments;
}

_ParsedCommentContent _splitCommentContent(String raw) {
  if (raw.isEmpty) {
    return const _ParsedCommentContent(text: '', attachments: []);
  }
  final attachments = <_CommentAttachment>[];
  final buffer = <String>[];
  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith(_kCommentAttachmentPrefix)) {
      final payload = trimmed.substring(_kCommentAttachmentPrefix.length);
      final separatorIndex = payload.indexOf('|');
      if (separatorIndex >= 0) {
        final typeName = payload.substring(0, separatorIndex);
        final url = payload.substring(separatorIndex + 1).trim();
        if (url.isNotEmpty) {
          final type = _CommentAttachmentType.values.firstWhere(
            (t) => t.name == typeName,
            orElse: () => _CommentAttachmentType.image,
          );
          attachments.add(_CommentAttachment(type, url));
          continue;
        }
      }
    }
    buffer.add(line);
  }
  final text = buffer.join('\n').trim();
  return _ParsedCommentContent(text: text, attachments: attachments);
}

class AnimatedLikeIcon extends StatefulWidget {
  const AnimatedLikeIcon({super.key, required this.active});

  final bool active;

  @override
  State<AnimatedLikeIcon> createState() => _AnimatedLikeIconState();
}

class _AnimatedLikeIconState extends State<AnimatedLikeIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedLikeIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _controller.forward(from: 0).then((_) {
        if (mounted) {
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color;
    return ScaleTransition(
      scale: _scale,
      child: Icon(widget.active ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined, size: 18, color: color),
    );
  }
}
class _PostMetaPill extends StatelessWidget {
  const _PostMetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.20),
            color.withOpacity(0.10),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PostMetaInfoChip extends StatelessWidget {
  const _PostMetaInfoChip({
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveLabel = label.isEmpty ? '—' : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.hintColor),
          const SizedBox(width: 6),
          Text(
            effectiveLabel,
            style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _PostBodyBlock extends StatelessWidget {
  const _PostBodyBlock({required this.text, this.palette});

  final String text;
  final List<Color>? palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPalette = palette != null && palette!.isNotEmpty;
    final colors = hasPalette
        ? palette!
            .map((color) =>
                theme.brightness == Brightness.light ? Color.alphaBlend(Colors.white.withOpacity(0.42), color) : color)
            .toList(growable: false)
        : null;
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: hasPalette
          ? LinearGradient(colors: colors!, begin: Alignment.topLeft, end: Alignment.bottomRight)
          : null,
      color: hasPalette ? null : theme.colorScheme.surfaceVariant.withOpacity(0.18),
      border: Border.all(
        color: hasPalette
            ? (theme.brightness == Brightness.light
                ? Colors.black.withOpacity(0.04)
                : Colors.white.withOpacity(0.18))
            : Colors.white.withOpacity(0.08),
      ),
      boxShadow: hasPalette
          ? [
              BoxShadow(
                color: (theme.brightness == Brightness.light ? colors!.last : colors!.last).withOpacity(0.22),
                blurRadius: 24,
                offset: const Offset(0, 16),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
    );

    final textStyle = hasPalette
        ? theme.textTheme.bodyMedium?.copyWith(
              color: theme.brightness == Brightness.light ? Colors.black.withOpacity(0.85) : Colors.white,
              height: 1.5,
              fontWeight: FontWeight.w600,
            )
        : theme.textTheme.bodyMedium?.copyWith(height: 1.5);

    final trimmed = text.trim();
    final child = trimmed.isEmpty
        ? const SizedBox(height: 72)
        : Text(
            text,
            style: textStyle,
          );

    final padding = trimmed.isEmpty
        ? const EdgeInsets.symmetric(horizontal: 18, vertical: 24)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 16);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: decoration,
      child: child,
    );
  }
}
