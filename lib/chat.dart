import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/bills_page.dart' as bills_page;
import 'package:myapp/calendar.dart' as calendar_page;
import 'package:myapp/daily_wear.dart' as daily_wear_page;
import 'package:myapp/life_goals.dart' as life_goals_page;
import 'package:myapp/medi_tracker.dart' as medi_tracker_page;
import 'package:myapp/app_localizations.dart';
import 'package:myapp/widgets/ahvi_chat_prompt_bar.dart';
import 'package:myapp/widgets/ahvi_home_text.dart';
import 'package:myapp/services/appwrite_service.dart';
import 'package:myapp/services/backend_service.dart';
import 'package:myapp/skincare.dart' as skincare_page;
import 'package:myapp/theme/theme_tokens.dart';
import 'package:provider/provider.dart';

Map<String, List<String>> _getChipsByModule(BuildContext context) => {
  'style': [
    AppLocalizations.t(context, 'intent_style_s1'),
    AppLocalizations.t(context, 'intent_style_s2'),
    AppLocalizations.t(context, 'intent_style_s3'),
  ],
  'organize': [
    AppLocalizations.t(context, 'intent_organize_s1'),
    AppLocalizations.t(context, 'intent_organize_s2'),
    AppLocalizations.t(context, 'intent_organize_s3'),
    AppLocalizations.t(context, 'intent_organize_s4'),
    AppLocalizations.t(context, 'intent_organize_s5'),
    AppLocalizations.t(context, 'intent_organize_s6'),
    AppLocalizations.t(context, 'intent_organize_s7'),
    AppLocalizations.t(context, 'intent_organize_s8'),
  ],
  'plan': [
    AppLocalizations.t(context, 'intent_prepare_s1'),
    AppLocalizations.t(context, 'intent_prepare_s2'),
    AppLocalizations.t(context, 'intent_prepare_s3'),
  ],
};

class _ChatMessage {
  final String text;
  final bool isMe;
  final bool isGreeting;
  final List<dynamic> chips;
  final String? boardId;
  final String? packId;
  final List<dynamic> styleBoards;
  final _LocalResponse? local;
  _ChatMessage({
    required this.text,
    required this.isMe,
    this.isGreeting = false,
    this.chips = const [],
    this.boardId,
    this.packId,
    this.styleBoards = const [],
    this.local,
  });
}

enum _RespType { outfits, plan, card, checklist }

class _LocalResponse {
  final _RespType type;
  final String intro;
  final List<_Outfit> outfits;
  final List<_Plan> plans;
  final _CardData? card;
  const _LocalResponse({
    required this.type,
    required this.intro,
    this.outfits = const [],
    this.plans = const [],
    this.card,
  });
}

class _Outfit {
  final String name;
  final List<String> tags;
  final String image;
  final String description;
  bool saved;
  _Outfit(
    this.name,
    this.tags,
    this.image, {
    this.description = '',
    this.saved = false,
  });
}

class _Plan {
  final String title;
  final List<String> items;
  const _Plan(this.title, this.items);
}

class _CardData {
  final String title;
  final IconData icon;
  final List<_CardRow> rows;
  final String footer;
  final String pageKey;
  const _CardData(this.title, this.icon, this.rows, this.footer, this.pageKey);
}

class _CardRow {
  final bool done;
  final String main;
  final String sub;
  final String tag;
  const _CardRow(this.done, this.main, this.sub, this.tag);
}

final _local = <String, _LocalResponse>{
  'What should I wear today?': _LocalResponse(
    type: _RespType.outfits,
    intro:
        "Based on today's 14Â°C partly cloudy weather, here are 3 looks curated for you:",
    outfits: [
      _Outfit(
        'Layered Minimal',
        ['Casual', 'Today'],
        'https://images.unsplash.com/photo-1594938298603-c8148c4b9c2b?w=220&h=260&fit=crop&crop=top&auto=format',
        description:
            'A light knit layered over a crisp tee with slim trousers. Comfortable yet polished for a cool day.',
      ),
      _Outfit(
        'Smart Casual',
        ['Office', 'Versatile'],
        'https://images.unsplash.com/photo-1591369822096-ffd140ec948f?w=220&h=260&fit=crop&crop=top&auto=format',
        description:
            'Tailored chinos paired with a structured shirt. Effortless transition from desk to dinner.',
      ),
      _Outfit(
        'Street Edit',
        ['Urban', 'Fresh'],
        'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=220&h=260&fit=crop&crop=top&auto=format',
        description:
            'Wide-leg joggers with an oversized graphic tee and clean sneakers. Relaxed city energy.',
      ),
    ],
  ),
  'Build a rooftop party outfit': _LocalResponse(
    type: _RespType.outfits,
    intro:
        "Rooftop energy calls for elevated looks. Here's what works perfectly:",
    outfits: [
      _Outfit(
        'Evening Glow',
        ['Party', 'Night'],
        'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=220&h=260&fit=crop&crop=top&auto=format',
        description:
            'A sleek satin slip dress with strappy heels. Warm-toned accessories complete the golden-hour vibe.',
      ),
      _Outfit(
        'Rooftop Chic',
        ['Elevated', 'Cool'],
        'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=220&h=260&fit=crop&crop=top&auto=format',
        description:
            'Tailored wide-leg trousers with a cropped blazer. Sharp, confident and built for the skyline.',
      ),
      _Outfit(
        'Bold Statement',
        ['Trendy', 'Standout'],
        'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=220&h=260&fit=crop&crop=top&auto=format',
        description:
            'A vibrant co-ord set that commands attention. Minimal jewellery lets the colour do the talking.',
      ),
    ],
  ),
  'Show trending casual looks': _LocalResponse(
    type: _RespType.outfits,
    intro:
        'Quiet luxury and clean lines are having a moment. Top trending now:',
    outfits: [
      _Outfit(
        'Quiet Luxury',
        ['Trending', 'Minimal'],
        'https://images.unsplash.com/photo-1538805060514-97d9cc17730c?w=220&h=260&fit=crop&crop=top&auto=format',
        description:
            'Cream wide-leg trousers with a fine-knit cardigan. Understated elegance that speaks volumes.',
      ),
      _Outfit(
        'Soft Tones',
        ['Casual', 'Neutral'],
        'https://images.unsplash.com/photo-1594938298603-c8148c4b9c2b?w=220&h=260&fit=crop&crop=top&auto=format',
        description:
            'Dusty beige linen set with white sneakers. Easy, breathable and endlessly wearable.',
      ),
      _Outfit(
        'Classic Ease',
        ['Everyday', 'Fresh'],
        'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=220&h=260&fit=crop&crop=top&auto=format',
        description:
            'A white oversized button-down tucked into straight jeans. The perfect no-fuss uniform.',
      ),
    ],
  ),
  'Plan a 3-day Goa trip': _LocalResponse(
    type: _RespType.checklist,
    intro: "Here's your expert-curated 3-day Goa itinerary:",
    plans: [
      _Plan('Day 1 â€” Arrival & North Goa', [
        'â˜€ï¸ Arrive & check in',
        'ðŸ–ï¸ Baga Beach',
        'ðŸ½ï¸ Dinner at Thalassa',
      ]),
      _Plan('Day 2 â€” Culture & South Goa', [
        'ðŸ›ï¸ Old Goa churches',
        'ðŸš— Drive to Palolem',
        'ðŸŒ… Sunset at Cabo de Rama',
      ]),
      _Plan('Day 3 â€” Relax & Depart', [
        'ðŸ§˜ Morning yoga',
        'ðŸ›ï¸ Anjuna flea market',
        'âœˆï¸ Airport by 4pm',
      ]),
    ],
  ),
  'Pack for business travel': _LocalResponse(
    type: _RespType.checklist,
    intro: 'Smart packing list â€” nothing missing, nothing extra:',
    plans: [
      _Plan('ðŸ‘” Clothing', [
        '2Ã— formal shirts',
        '1Ã— blazer',
        '2Ã— trousers',
      ]),
      _Plan('ðŸ’¼ Work Essentials', [
        'Laptop + charger',
        'Notebook + pens',
        'Portable battery',
      ]),
      _Plan('ðŸ§´ Toiletries', [
        'Moisturiser, deodorant',
        'Toothbrush + paste',
        'Face wash + razor',
      ]),
    ],
  ),
  'Create a wedding checklist': _LocalResponse(
    type: _RespType.checklist,
    intro: 'Complete wedding checklist â€” 24 items across 4 categories:',
    plans: [
      _Plan('ðŸ“† 6â€“12 Months Before', [
        'Set budget & guest list',
        'Book venue & caterer',
        'Book photographer',
      ]),
      _Plan('ðŸŽ¨ 3â€“6 Months Before', [
        'Send invitations',
        'Finalise menu',
        'Book hair & makeup',
      ]),
      _Plan('âœ… Week Of', [
        'Final dress fitting',
        'Prepare wedding day kit',
        'Rest & enjoy ðŸŽ‰',
      ]),
    ],
  ),
  'Today\'s meals': _LocalResponse(
    type: _RespType.card,
    intro: 'You have 4 meals planned today.',
    card: _CardData(
      'Meals',
      Icons.restaurant_menu_rounded,
      [
        _CardRow(
          true,
          'Oats with banana & honey',
          'Breakfast Â· 380 kcal',
          'Breakfast',
        ),
        _CardRow(true, 'Dal rice with salad', 'Lunch Â· 620 kcal', 'Lunch'),
        _CardRow(
          false,
          'Grilled paneer with roti',
          'Dinner Â· 540 kcal',
          'Dinner',
        ),
      ],
      'Open Meals',
      'meal',
    ),
  ),
  'My medicines': _LocalResponse(
    type: _RespType.card,
    intro: 'You have 3 medicines tracked.',
    card: _CardData(
      'Medicines',
      Icons.medication_rounded,
      [
        _CardRow(true, 'Vitamin D3 â€” 1 tablet', 'Daily Â· 08:00', 'Taken'),
        _CardRow(
          true,
          'Iron Supplement â€” 1 tablet',
          'Daily Â· 13:00',
          'Taken',
        ),
        _CardRow(false, 'Omega-3 â€” 2 capsules', 'Daily Â· 20:00', 'Pending'),
      ],
      'Open Medicines',
      'medi',
    ),
  ),
  'Pending bills': _LocalResponse(
    type: _RespType.card,
    intro: 'You have 3 unpaid bills.',
    card: _CardData(
      'Bills',
      Icons.receipt_long_rounded,
      [
        _CardRow(false, 'Rent', 'Due: Mar 28 Â· Rent', 'â‚¹12,000'),
        _CardRow(
          false,
          'Netflix + Hotstar',
          'Due: Apr 03 Â· Subscription',
          'â‚¹649',
        ),
        _CardRow(false, 'Phone Recharge', 'Due: Apr 05 Â· Utilities', 'â‚¹299'),
      ],
      'Open Bills',
      'bill',
    ),
  ),
  'Today\'s workout': _LocalResponse(
    type: _RespType.card,
    intro: 'Today\'s workout has 5 exercises.',
    card: _CardData(
      'Workout',
      Icons.fitness_center_rounded,
      [
        _CardRow(true, 'Warm-up cardio', 'Cardio Â· 1 set Â· 10 min', 'Cardio'),
        _CardRow(false, 'Squats', 'Strength Â· 4 sets Â· 12 reps', 'Strength'),
        _CardRow(false, 'Lunges', 'Strength Â· 3 sets Â· 15 reps', 'Strength'),
      ],
      'Open Workout',
      'workout',
    ),
  ),
  'Upcoming events': _LocalResponse(
    type: _RespType.card,
    intro: 'Here are your upcoming events.',
    card: _CardData(
      'Events',
      Icons.event_note_rounded,
      [
        _CardRow(
          false,
          'Doctor Appointment',
          '24 Mar Â· 11:00 AM Â· Apollo Clinic',
          'Health',
        ),
        _CardRow(false, 'Dinner with family', '24 Mar Â· 07:30 PM', 'Personal'),
        _CardRow(
          false,
          'Spanish Class',
          '28 Mar Â· 06:00 PM Â· Online',
          'Learning',
        ),
      ],
      'Open Calendar',
      'calendar',
    ),
  ),
  'Today\'s events': _LocalResponse(
    type: _RespType.card,
    intro: 'No events scheduled for today.',
    card: _CardData(
      'Events',
      Icons.today_rounded,
      [
        _CardRow(
          false,
          'Doctor Appointment',
          '24 Mar Â· 11:00 AM Â· Apollo Clinic',
          'Health',
        ),
        _CardRow(false, 'Dinner with family', '24 Mar Â· 07:30 PM', 'Personal'),
      ],
      'Open Calendar',
      'calendar',
    ),
  ),
  'Morning skincare': _LocalResponse(
    type: _RespType.card,
    intro: 'Your morning routine has 4 steps.',
    card: _CardData(
      'Skincare',
      Icons.spa_rounded,
      [
        _CardRow(
          true,
          'Gentle Cleanser',
          'CeraVe Â· Morning Â· Step 1',
          'Step 1',
        ),
        _CardRow(
          true,
          'Vitamin C Serum',
          'Minimalist Â· Morning Â· Step 2',
          'Step 2',
        ),
        _CardRow(
          true,
          'SPF 50 Sunscreen',
          'Biore Â· Morning Â· Step 4',
          'Step 4',
        ),
      ],
      'Open Skincare',
      'skincare',
    ),
  ),
};

// â”€â”€ Persistent chat session model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ChatSession {
  String id;
  String title;
  final DateTime createdAt;
  final List<Map<String, String>> history; // [{role, content}]

  _ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.history,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'history': history,
  };

  factory _ChatSession.fromJson(Map<String, dynamic> j) => _ChatSession(
    id: j['id'] as String,
    title: j['title'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    history: (j['history'] as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList(),
  );
}

const _kSessionsKey = 'ahvi_chat_sessions';

class ChatScreen extends StatefulWidget {
  final String moduleContext;
  final String? initialPrompt;
  final bool showBackButton;
  const ChatScreen({
    super.key,
    this.moduleContext = 'style',
    this.initialPrompt,
    this.showBackButton = true,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<_ChatMessage> _messages = [];
  final List<Map<String, String>> _chatHistory = [];
  String _runningMemory = '';
  String _persistentMemory = '';
  bool _isTyping = false;
  String _userName = 'User';
  String _userId = 'anonymous';
  final Map<String, List<List<bool>>> _checklistChecksByTitle = {};
  final Map<String, List<List<String>>> _checklistItemsByTitle = {};
  final Map<String, List<TextEditingController>> _checklistAddCtrlsByTitle = {};
  final Map<String, bool> _checklistSavedByTitle = {};
  final Map<String, String> _boardOccasionByLabel = const {
    'Party Looks': 'Party',
    'Occasion': 'Occasion',
    'Office Fit': 'Office',
    'Vacation': 'Vacation',
  };
  final Map<String, String> _boardImageByLabel = const {
    'Party Looks':
        'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=1200&h=900&fit=crop&auto=format',
    'Occasion':
        'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=1200&h=900&fit=crop&auto=format',
    'Office Fit':
        'https://images.unsplash.com/photo-1487222477894-8943e31ef7b2?w=1200&h=900&fit=crop&auto=format',
    'Vacation':
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1200&h=900&fit=crop&auto=format',
  };

  // â”€â”€ Voice â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  // â”€â”€ History â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<_ChatSession> _sessions = [];
  late String _currentSessionId;
  bool _greetingAdded = false;
  String get _module => widget.moduleContext.toLowerCase().trim() == 'prepare'
      ? 'plan'
      : widget.moduleContext.toLowerCase().trim();

  @override
  void initState() {
    super.initState();
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _loadSessions();
    _initSpeech();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_greetingAdded) {
      _greetingAdded = true;
      _fetchUser();
      _messages.add(_ChatMessage(text: '', isMe: false, isGreeting: true));
      final pendingPrompt = widget.initialPrompt?.trim();
      if (pendingPrompt != null && pendingPrompt.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _sendMessage(pendingPrompt);
        });
      }
    }
  }

  Future<void> _fetchUser() async {
    final appwrite = Provider.of<AppwriteService>(context, listen: false);
    final user = await appwrite.getCurrentUser();
    if (user != null && mounted) {
      final latestMemory = await appwrite.getLatestMemory();
      final memoryText = (latestMemory?.data['memory'] ?? '').toString().trim();
      setState(() {
        _userName = user.name.isNotEmpty
            ? user.name.split(' ').first
            : 'Stylist';
        _userId = user.$id;
        _persistentMemory = memoryText;
        _runningMemory = memoryText;
      });
    }
  }

  Future<void> _syncMemoryToCloud(String updatedMemory) async {
    final cleanMemory = updatedMemory.trim();
    if (cleanMemory.isEmpty) return;
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      await appwrite.upsertUserMemory(cleanMemory);
    } catch (e) {
      debugPrint('Memory sync failed: $e');
    }
  }

  Future<bool> _saveChecklistToBoard({
    required String boardLabel,
    required List<List<String>> itemsState,
  }) async {
    final appwrite = Provider.of<AppwriteService>(context, listen: false);
    final occasion = _boardOccasionByLabel[boardLabel] ?? 'Occasion';
    final imageUrl =
        _boardImageByLabel[boardLabel] ??
        'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=1200&h=900&fit=crop&auto=format';

    final itemLabels = itemsState
        .expand((sectionItems) => sectionItems)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(100)
        .toList();

    final itemIds = await appwrite.resolveWardrobeItemIds(itemLabels);
    if (itemIds.isEmpty) {
      debugPrint(
        'Board save skipped: no real wardrobe item ids matched from checklist labels.',
      );
      return false;
    }

    final saved = await appwrite.createSavedBoard(
      occasion: occasion,
      imageUrl: imageUrl,
      itemIds: itemIds,
    );
    return saved != null;
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (e) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _chatController.text = result.recognizedWords;
            _chatController.selection = TextSelection.fromPosition(
              TextPosition(offset: _chatController.text.length),
            );
          });
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            _speech.stop();
            setState(() => _isListening = false);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        localeId: 'en_IN',
        cancelOnError: true,
        partialResults: true,
      );
    }
  }

  // â”€â”€ Session persistence â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSessionsKey);
    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw) as List;
        if (mounted) {
          setState(() {
            _sessions =
                decoded
                    .map(
                      (e) => _ChatSession.fromJson(e as Map<String, dynamic>),
                    )
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          });
        }
      } catch (_) {}
    }
    if (mounted) {
      await _syncSessionTitlesFromCloud();
    }
  }

  Future<void> _syncSessionTitlesFromCloud() async {
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      final docs = await appwrite.getChatThreads(module: _module);
      if (!mounted || docs.isEmpty) return;

      final titleById = <String, String>{
        for (final d in docs) d.$id: (d.data['title']?.toString().trim() ?? ''),
      };

      final existingById = <String, _ChatSession>{
        for (final s in _sessions) s.id: s,
      };
      var changed = false;
      for (final s in _sessions) {
        final cloudTitle = titleById[s.id] ?? '';
        if (cloudTitle.isNotEmpty && cloudTitle != s.title) {
          s.title = cloudTitle;
          changed = true;
        }
      }

      for (final d in docs) {
        if (existingById.containsKey(d.$id)) continue;
        final cloudTitle = (d.data['title']?.toString().trim() ?? '');
        final createdAtRaw = d.$createdAt.toString();
        final createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
        _sessions.add(
          _ChatSession(
            id: d.$id,
            title: cloudTitle.isNotEmpty ? cloudTitle : 'Chat',
            createdAt: createdAt,
            history: [],
          ),
        );
        changed = true;
      }

      if (changed && mounted) {
        setState(() {
          _sessions = List<_ChatSession>.from(_sessions)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _kSessionsKey,
          jsonEncode(_sessions.map((s) => s.toJson()).toList()),
        );
      }
    } catch (e) {
      debugPrint('Chat thread title sync failed: $e');
    }
  }

  Future<void> _saveCurrentSession() async {
    if (_chatHistory.isEmpty) return; // nothing to persist yet
    final prefs = await SharedPreferences.getInstance();

    // Build a readable title from the first user message
    final firstUser = _chatHistory.firstWhere(
      (m) => m['role'] == 'user',
      orElse: () => {'content': 'Chat'},
    );
    final title = (firstUser['content'] ?? 'Chat').length > 40
        ? '${firstUser['content']!.substring(0, 40)}...'
        : firstUser['content']!;

    final existing = _sessions.indexWhere((s) => s.id == _currentSessionId);
    if (existing >= 0) {
      _sessions[existing].history
        ..clear()
        ..addAll(_chatHistory);
      _sessions[existing].title = title;
    } else {
      _sessions.insert(
        0,
        _ChatSession(
          id: _currentSessionId,
          title: title,
          createdAt: DateTime.now(),
          history: List.from(_chatHistory),
        ),
      );
    }

    await prefs.setString(
      _kSessionsKey,
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );

    // Sync thread metadata to Appwrite chat_threads
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      final lastMessage =
          (_chatHistory.isNotEmpty ? _chatHistory.last['content'] : null) ?? '';
      final synced = await appwrite.upsertChatThread(
        threadId: _currentSessionId,
        title: title,
        module: _module,
        lastMessage: lastMessage,
      );
      if (synced != null && synced.$id != _currentSessionId) {
        final oldId = _currentSessionId;
        _currentSessionId = synced.$id;
        final idx = _sessions.indexWhere((s) => s.id == oldId);
        if (idx >= 0) {
          _sessions[idx].id = _currentSessionId;
        }
        await prefs.setString(
          _kSessionsKey,
          jsonEncode(_sessions.map((s) => s.toJson()).toList()),
        );
      }
    } catch (e) {
      debugPrint('Chat thread sync failed: $e');
    }
  }

  Future<void> _deleteSession(String id) async {
    setState(() => _sessions.removeWhere((s) => s.id == id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSessionsKey,
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      await appwrite.deleteChatMessagesByThread(id);
      await appwrite.deleteChatThread(id);
    } catch (e) {
      debugPrint('Chat thread delete sync failed: $e');
    }
  }

  void _startNewChat() {
    Navigator.of(context).pop(); // close drawer
    setState(() {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages
        ..clear()
        ..add(_ChatMessage(text: '', isMe: false, isGreeting: true));
      _chatHistory.clear();
      _runningMemory = _persistentMemory;
    });
    _scrollToBottom();
  }

  void _loadSession(_ChatSession session) {
    Navigator.of(context).pop(); // close drawer
    setState(() {
      _currentSessionId = session.id;
      _chatHistory
        ..clear()
        ..addAll(session.history);
      _messages.clear();
      // Rebuild _messages from history for display
      _messages.add(_ChatMessage(text: '', isMe: false, isGreeting: true));
      for (final h in session.history) {
        _messages.add(
          _ChatMessage(text: h['content'] ?? '', isMe: h['role'] == 'user'),
        );
      }
      _runningMemory = _persistentMemory;
    });
    _scrollToBottom();
    _loadSessionMessagesFromCloud(session.id);
  }

  Future<void> _persistMessageToCloud({
    required String role,
    required String content,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      await appwrite.createChatMessage(
        threadId: _currentSessionId,
        role: role,
        content: content,
        meta: meta,
      );
    } catch (e) {
      debugPrint('Chat message sync failed: $e');
    }
  }

  Future<void> _loadSessionMessagesFromCloud(String threadId) async {
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      final docs = await appwrite.getChatMessages(
        threadId: threadId,
        limit: 500,
      );
      if (!mounted || docs.isEmpty) return;

      final cloudHistory = <Map<String, String>>[];
      for (final d in docs) {
        final role = (d.data['role']?.toString() ?? '').trim().toLowerCase();
        final content = (d.data['content']?.toString() ?? '').trim();
        if (content.isEmpty) continue;
        if (role != 'user' && role != 'assistant' && role != 'system') continue;
        cloudHistory.add({'role': role, 'content': content});
      }
      if (cloudHistory.isEmpty) return;

      setState(() {
        _chatHistory
          ..clear()
          ..addAll(cloudHistory);
        _messages
          ..clear()
          ..add(_ChatMessage(text: '', isMe: false, isGreeting: true));
        for (final h in cloudHistory) {
          _messages.add(
            _ChatMessage(text: h['content'] ?? '', isMe: h['role'] == 'user'),
          );
        }
      });

      final idx = _sessions.indexWhere((s) => s.id == threadId);
      if (idx >= 0) {
        _sessions[idx].history
          ..clear()
          ..addAll(cloudHistory);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _kSessionsKey,
          jsonEncode(_sessions.map((s) => s.toJson()).toList()),
        );
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint('Chat messages load sync failed: $e');
    }
  }

  Future<void> _handleChipTap(String chip) async {
    final local = _local[chip];
    if (local == null) {
      _sendMessage(chip);
      return;
    }
    setState(() {
      _messages.add(_ChatMessage(text: chip, isMe: true));
      _messages.add(_ChatMessage(text: local.intro, isMe: false, local: local));
      _chatHistory.add({'role': 'user', 'content': chip});
      _chatHistory.add({'role': 'assistant', 'content': local.intro});
    });
    _scrollToBottom();
    await _saveCurrentSession();
    await _persistMessageToCloud(
      role: 'user',
      content: chip,
      meta: {'source': 'local_chip'},
    );
    await _persistMessageToCloud(
      role: 'assistant',
      content: local.intro,
      meta: {'source': 'local_chip'},
    );
  }

  void _sendMessage([String? chipText]) async {
    final text = chipText ?? _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isMe: true));
      _chatHistory.add({'role': 'user', 'content': text});
      _isTyping = true;
    });
    _scrollToBottom();
    await _saveCurrentSession();
    await _persistMessageToCloud(
      role: 'user',
      content: text,
      meta: {'source': 'chat_input'},
    );
    try {
      final backend = Provider.of<BackendService>(context, listen: false);
      final response = await backend.sendChatQuery(
        text,
        _userId,
        List<Map<String, String>>.from(_chatHistory),
        _runningMemory,
        threadId: _currentSessionId,
      );
      if (!mounted) return;
      if (response['updated_memory'] != null) {
        final updated = response['updated_memory'].toString();
        _runningMemory = updated;
        _persistentMemory = updated;
        await _syncMemoryToCloud(updated);
      }
      final backendError = response['error']?.toString().trim();
      final aiText =
          (backendError != null && backendError.isNotEmpty)
          ? backendError
          : (response['message']?['content']?.toString() ??
                AppLocalizations.t(context, 'chat_connection_error'));
      _chatHistory.add({'role': 'assistant', 'content': aiText});
      setState(
        () => _messages.add(
          _ChatMessage(
            text: aiText,
            isMe: false,
            chips: response['chips'] ?? [],
            boardId: response['board_ids'],
            packId: response['pack_ids'],
            styleBoards: response['style_boards'] is List
                ? List<dynamic>.from(response['style_boards'] as List)
                : const [],
          ),
        ),
      );
      await _saveCurrentSession();
      await _persistMessageToCloud(
        role: 'assistant',
        content: aiText,
        meta: {
          'source': 'backend_reply',
          'chips_count': response['chips'] is List
              ? (response['chips'] as List).length
              : 0,
          'has_board_ids': response['board_ids'] != null,
          'has_pack_ids': response['pack_ids'] != null,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(
            text: '${AppLocalizations.t(context, 'chat_error_prefix')}: $e',
            isMe: false,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 180,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });

  void _openOrganizePage(String pageKey) {
    Widget? page;
    switch (pageKey) {
      case 'meal':
        page = daily_wear_page.DailyWearScreen();
        page = medi_tracker_page.MediTrackScreen();
        break;
      case 'bill':
        page = const bills_page.BillsScreen();
        break;
      case 'workout':
        page = daily_wear_page.DailyWearScreen();
        break;
      case 'calendar':
        page = const calendar_page.CalendarShell();
        break;
      case 'skincare':
        page = const skincare_page.SkincareScreen();
        break;
      case 'life_goals':
      case 'life-goals':
      case 'goal':
      case 'goals':
        page = const life_goals_page.LifeGoalsScreen();
        break;
    }
    if (page == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page!));
  }

  @override
  void dispose() {
    _speech.stop();
    _chatController.dispose();
    _chatFocusNode.dispose();
    _scrollController.dispose();
    for (final ctrls in _checklistAddCtrlsByTitle.values) {
      for (final c in ctrls) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: t.backgroundPrimary,
      drawer: _historyDrawer(t),
      appBar: AppBar(
        backgroundColor: t.backgroundPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                tooltip: AppLocalizations.t(context, 'chat_back'),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: AhviHomeText(
            color: t.textPrimary,
            fontSize: 30.0,
            letterSpacing: 3.2,
            fontWeight: FontWeight.w400,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: AppLocalizations.t(context, 'chat_history_btn'),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _msg(_messages[i], t),
              ),
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.t(context, 'chat_typing'),
                  style: TextStyle(color: t.mutedText, fontSize: 12),
                ),
              ),
            ),
          _input(t),
          SizedBox(
            height:
                MediaQuery.of(context).viewPadding.bottom +
                (widget.showBackButton ? 0 : 80),
          ),
        ],
      ),
    );
  }

  Widget _historyDrawer(AppThemeTokens t) {
    return Drawer(
      backgroundColor: t.backgroundSecondary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.t(context, 'chat_history_title'),
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _startNewChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [t.accent.primary, t.accent.secondary],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            AppLocalizations.t(context, 'chat_new'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: t.cardBorder, height: 1),
            // Session list
            Expanded(
              child: _sessions.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.t(context, 'chat_no_history'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.mutedText, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _sessions.length,
                      itemBuilder: (ctx, i) {
                        final s = _sessions[i];
                        final isActive = s.id == _currentSessionId;
                        final date = _formatDate(s.createdAt);
                        return Dismissible(
                          key: ValueKey(s.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.withValues(alpha: 0.15),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                          ),
                          onDismissed: (_) => _deleteSession(s.id),
                          child: ListTile(
                            selected: isActive,
                            selectedTileColor: t.accent.primary.withValues(
                              alpha: 0.1,
                            ),
                            onTap: () => _loadSession(s),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 2,
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? t.accent.primary.withValues(alpha: 0.2)
                                    : t.panel,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: t.cardBorder),
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 16,
                                color: isActive
                                    ? t.accent.primary
                                    : t.mutedText,
                              ),
                            ),
                            title: Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 13,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              date,
                              style: TextStyle(
                                color: t.mutedText,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return AppLocalizations.t(context, 'chat_today');
    if (diff.inDays == 1) return AppLocalizations.t(context, 'chat_yesterday');
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _msg(_ChatMessage m, AppThemeTokens t) => Column(
    crossAxisAlignment: m.isMe
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Align(
        alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: m.isMe ? t.accent.primary : t.panel,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(m.isMe ? 18 : 4),
              bottomRight: Radius.circular(m.isMe ? 4 : 18),
            ),
            border: m.isMe ? null : Border.all(color: t.cardBorder),
          ),
          child: Text(
            m.isGreeting
                ? AppLocalizations.t(context, 'chat_greeting')
                : m.text,
            style: TextStyle(
              color: m.isMe ? Colors.white : t.textPrimary,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ),
      ),
      if (!m.isMe && m.local != null) _localView(m.local!, t),
      if (!m.isMe && m.styleBoards.isNotEmpty) _styleBoardsView(m.styleBoards, t),
      if (!m.isMe && m.chips.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: m.chips
                .map(
                  (c) => GestureDetector(
                    onTap: () => _sendMessage(c.toString()),
                    child: _chip(c.toString(), t),
                  ),
                )
                .toList(),
          ),
        ),
    ],
  );

  String? _boardItemImage(dynamic item) {
    if (item is! Map) return null;
    final masked = item['masked_url']?.toString().trim() ?? '';
    if (masked.isNotEmpty) return masked;
    final raw = item['image_url']?.toString().trim() ?? '';
    if (raw.isNotEmpty) return raw;
    return null;
  }

  String _boardItemToken(Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString().trim();
    if (id.isNotEmpty) return id;
    final name = (item['name'] ?? '').toString().trim().toLowerCase();
    final masked = (item['masked_url'] ?? '').toString().trim();
    final raw = (item['image_url'] ?? '').toString().trim();
    return '$name|$masked|$raw';
  }

  Map<String, dynamic>? _boardItemByKey(Map<String, dynamic> board, String key) {
    final value = board[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  List<Map<String, dynamic>> _boardItems(dynamic board) {
    if (board is! Map) return const [];
    final picked = <Map<String, dynamic>>[];
    final keys = ['masterpiece', 'top', 'dress', 'bottom', 'footwear'];
    for (final key in keys) {
      final value = board[key];
      if (value is Map) picked.add(Map<String, dynamic>.from(value));
    }
    final acc = board['accessories'];
    if (acc is List) {
      for (final item in acc.take(3)) {
        if (item is Map) picked.add(Map<String, dynamic>.from(item));
      }
    }
    final deduped = <String>{};
    final ordered = <Map<String, dynamic>>[];
    for (final item in picked) {
      final token = _boardItemToken(item);
      if (token.isEmpty || deduped.contains(token)) continue;
      deduped.add(token);
      ordered.add(item);
    }
    return ordered;
  }

  Widget _boardCutoutImage({
    required String? imageUrl,
    required AppThemeTokens t,
    BoxFit fit = BoxFit.contain,
    EdgeInsetsGeometry padding = const EdgeInsets.all(2),
    double borderRadius = 0,
    IconData fallbackIcon = Icons.checkroom_outlined,
    bool showFallbackIcon = true,
  }) {
    final child = Container(
      padding: padding,
      color: Colors.transparent,
      child: imageUrl == null || imageUrl.isEmpty
          ? (showFallbackIcon
                ? Center(
                    child: Icon(
                      fallbackIcon,
                      color: t.mutedText.withValues(alpha: 0.55),
                      size: 18,
                    ),
                  )
                : const SizedBox.shrink())
          : Image.network(
              imageUrl,
              fit: fit,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: t.mutedText.withValues(alpha: 0.55),
                  size: 18,
                ),
              ),
            ),
    );
    if (borderRadius <= 0) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }

  List<Map<String, dynamic>> _pickAccessoryRailItems({
    required List<Map<String, dynamic>> accessories,
    Map<String, dynamic>? footwear,
  }) {
    final picked = <Map<String, dynamic>>[];
    for (final a in accessories) {
      if (picked.length >= 5) break;
      picked.add(a);
    }
    if (footwear != null) {
      final shoeToken = _boardItemToken(footwear);
      final exists = picked.any((x) => _boardItemToken(x) == shoeToken);
      if (!exists) picked.add(footwear);
    }
    while (picked.length < 5) {
      picked.add(const <String, dynamic>{});
    }
    return picked.take(5).toList();
  }

  Widget _styleBoardCollage(Map<String, dynamic> board, AppThemeTokens t) {
    final dress = _boardItemByKey(board, 'dress');
    final top = _boardItemByKey(board, 'top') ?? _boardItemByKey(board, 'masterpiece');
    final bottom = _boardItemByKey(board, 'bottom');
    final footwear = _boardItemByKey(board, 'footwear');
    final accRaw = board['accessories'];
    final accessories = <Map<String, dynamic>>[];
    if (accRaw is List) {
      for (final item in accRaw) {
        if (item is Map) accessories.add(Map<String, dynamic>.from(item));
      }
    }

    final railItems = _pickAccessoryRailItems(
      accessories: accessories,
      footwear: footwear,
    );

    final hero = dress ?? top;
    final heroUrl = _boardItemImage(hero);
    final bottomUrl = _boardItemImage(bottom);
    final footwearUrl = _boardItemImage(footwear);
    final hasHero = heroUrl != null && heroUrl.isNotEmpty;
    final hasBottom = bottomUrl != null && bottomUrl.isNotEmpty;
    final useBalancedTwoPiece = dress == null && hasHero && hasBottom;

    return Container(
      color: const Color(0xFFEAEAEA),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Column(
              children: [
                for (int i = 0; i < railItems.length; i++) ...[
                  Expanded(
                    child: _boardCutoutImage(
                      imageUrl: _boardItemImage(railItems[i]),
                      t: t,
                      fit: BoxFit.contain,
                      fallbackIcon: i == railItems.length - 1
                          ? Icons.hiking_outlined
                          : Icons.diamond_outlined,
                      showFallbackIcon: false,
                    ),
                  ),
                  if (i != railItems.length - 1) const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: useBalancedTwoPiece
                ? Column(
                    children: [
                      Expanded(
                        child: _boardCutoutImage(
                          imageUrl: heroUrl,
                          t: t,
                          fit: BoxFit.contain,
                          fallbackIcon: Icons.checkroom_outlined,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: _boardCutoutImage(
                          imageUrl: bottomUrl,
                          t: t,
                          fit: BoxFit.contain,
                          fallbackIcon: Icons.dry_cleaning_outlined,
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _boardCutoutImage(
                            imageUrl: bottomUrl,
                            t: t,
                            fit: BoxFit.contain,
                            fallbackIcon: Icons.dry_cleaning_outlined,
                          ),
                        ),
                      ),
                      if (hasHero)
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: FractionallySizedBox(
                              heightFactor:
                                  bottomUrl == null || bottomUrl.isEmpty || dress != null
                                  ? 1.0
                                  : 0.64,
                              child: _boardCutoutImage(
                                imageUrl: heroUrl,
                                t: t,
                                fit: BoxFit.contain,
                                fallbackIcon: Icons.checkroom_outlined,
                              ),
                            ),
                          ),
                        ),
                      if ((footwearUrl != null && footwearUrl.isNotEmpty) && dress != null)
                        Positioned(
                          bottom: 2,
                          left: 4,
                          right: 4,
                          height: 48,
                          child: _boardCutoutImage(
                            imageUrl: footwearUrl,
                            t: t,
                            fit: BoxFit.contain,
                            fallbackIcon: Icons.hiking_outlined,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _styleBoardCard(
    Map<String, dynamic> board,
    List<Map<String, dynamic>> boardItems,
    AppThemeTokens t,
  ) {
    final occ = (board['occasion'] ?? 'Style Board').toString();
    final note = (board['style_note'] ?? '').toString();
    return Container(
      width: 272,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 258,
            width: double.infinity,
            child: _styleBoardCollage(board, t),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              occ,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              note.isNotEmpty ? note : 'Curated from your wardrobe',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.mutedText, fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: boardItems.take(5).map((item) {
                final name = (item['name'] ?? 'Item').toString();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.accent.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _openStyleBoardPreview(
    Map<String, dynamic> board,
    List<Map<String, dynamic>> boardItems,
    AppThemeTokens t,
  ) {
    final occ = (board['occasion'] ?? 'Style Board').toString();
    final note = (board['style_note'] ?? '').toString();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        final w = MediaQuery.of(ctx).size.width;
        final h = MediaQuery.of(ctx).size.height;
        final cardW = (w * 0.90).clamp(280.0, 430.0);
        final artH = (h * 0.68).clamp(360.0, 640.0);
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: cardW,
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.cardBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: artH,
                    width: double.infinity,
                    child: _styleBoardCollage(board, t),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            occ,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: Icon(Icons.close_rounded, color: t.textPrimary),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        note.isNotEmpty ? note : 'Curated from your wardrobe',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.mutedText, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: boardItems.take(6).map((item) {
                        final name = (item['name'] ?? 'Item').toString();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: t.accent.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _styleBoardsView(List<dynamic> boards, AppThemeTokens t) {
    final cleanBoards = boards.whereType<Map>().toList();
    if (cleanBoards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 2, bottom: 14),
      child: SizedBox(
        height: 392,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cleanBoards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final board = Map<String, dynamic>.from(cleanBoards[index]);
            final boardItems = _boardItems(board);
            return GestureDetector(
              onTap: () => _openStyleBoardPreview(board, boardItems, t),
              child: _styleBoardCard(board, boardItems, t),
            );
          },
        ),
      ),
    );
  }

  Widget _localView(_LocalResponse r, AppThemeTokens t) {
    if (r.type == _RespType.outfits) {
      final screenW = MediaQuery.of(context).size.width;
      final screenH = MediaQuery.of(context).size.height;
      final outfitCardW = (screenW * 0.30).clamp(100.0, 140.0);
      final outfitStripH = (screenH * 0.22).clamp(155.0, 195.0);
      final outfitImgH = outfitStripH * 0.62;
      return SizedBox(
        height: outfitStripH,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: r.outfits.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final o = r.outfits[i];
            final heroTag = 'outfit_hero_${o.name}_$i';
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  PageRouteBuilder<void>(
                    opaque: false,
                    barrierColor: Colors.transparent,
                    transitionDuration: const Duration(milliseconds: 420),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 320,
                    ),
                    pageBuilder: (ctx, animation, _) => FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                      ),
                      child: _OutfitDetailPage(
                        outfit: o,
                        heroTag: heroTag,
                        t: t,
                        onSaveChanged: (saved) =>
                            setState(() => o.saved = saved),
                      ),
                    ),
                  ),
                );
              },
              child: Hero(
                tag: heroTag,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: outfitCardW,
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: t.backgroundPrimary.withValues(alpha: 0.20),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                o.image,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                cacheWidth: 280,
                                errorBuilder: (_, __, ___) => Container(
                                  color: t.accent.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: t.mutedText,
                                    size: 28,
                                  ),
                                ),
                              ),
                              // Saved badge
                              if (o.saved)
                                Positioned(
                                  top: 7,
                                  right: 7,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: t.accent.primary.withValues(
                                        alpha: 0.88,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.bookmark_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      size: 10,
                                    ),
                                  ),
                                ),
                              // Bottom gradient
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 32,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        t.backgroundPrimary.withValues(
                                          alpha: 0.40,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Label
                        Padding(
                          padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.name,
                                style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 3,
                                children: o.tags
                                    .take(2)
                                    .map(
                                      (tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: t.accent.primary.withValues(
                                            alpha: 0.10,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                        ),
                                        child: Text(
                                          tag,
                                          style: TextStyle(
                                            color: t.mutedText,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    if (r.type == _RespType.plan) {
      final colors = [t.accent.primary, t.accent.secondary, t.accent.tertiary];
      return Column(
        children: r.plans
            .asMap()
            .entries
            .map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: colors[e.key % 3], width: 2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.value.title,
                      style: TextStyle(
                        color: colors[e.key % 3],
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...e.value.items.map(
                      (it) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          it,
                          style: TextStyle(
                            color: t.mutedText,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    }
    if (r.type == _RespType.checklist) {
      return _buildChecklistCard(r, t);
    }
    final d = r.card!;
    final accent = t.accent.primary;
    final done = d.rows.where((x) => x.done).length;
    return Container(
      margin: EdgeInsets.only(
        left: 4,
        right: (MediaQuery.of(context).size.width * 0.07).clamp(16.0, 28.0),
        bottom: 16,
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Icon(d.icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  d.title,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.30)),
                ),
                child: Text(
                  '$done/${d.rows.length}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...d.rows.map(
            (x) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: t.panel.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.cardBorder.withValues(alpha: 0.9)),
              ),
              child: Row(
                children: [
                  Icon(
                    x.done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: x.done ? accent : t.mutedText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          x.main,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          x.sub,
                          style: TextStyle(color: t.mutedText, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withValues(alpha: 0.20)),
                    ),
                    child: Text(
                      x.tag,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _openOrganizePage(d.pageKey),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.cardBorder)),
              ),
              child: Text(
                d.footer,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(_LocalResponse r, AppThemeTokens t) {
    final title = r.intro.isNotEmpty ? r.intro : 'Checklist';
    const sections = [
      (
        name: 'Documents',
        emoji: 'ðŸ“„',
        color: Color(0xFF04D7C8), // teal - keep as semantic category color
        items: [
          'Passport / ID',
          'Boarding pass',
          'Travel insurance',
          'Hotel confirmation',
          'Visa (if required)',
        ],
      ),
      (
        name: 'Tech & Power',
        emoji: 'ðŸ”Œ',
        color: Color(0xFF8D7DFF),
        items: [
          'Phone + charger',
          'Power bank',
          'Headphones',
          'Laptop or tablet',
          'Universal adapter',
        ],
      ),
      (
        name: 'Comfort',
        emoji: 'ðŸ˜´',
        color: Color(0xFF6B91FF),
        items: [
          'Neck pillow',
          'Eye mask',
          'Earplugs',
          'Light jacket',
          'Compression socks',
        ],
      ),
    ];
    const sectionImages = [
      [
        'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1450101499163-c8848c66ca85?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1522199755839-a2bacb67c546?w=400&h=260&fit=crop&auto=format',
      ],
      [
        'https://images.unsplash.com/photo-1517336714739-489689fd1ca8?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1525547719571-a2d4ac8945e2?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1593344484962-796055d4a3a4?w=400&h=260&fit=crop&auto=format',
      ],
      [
        'https://images.unsplash.com/photo-1520006403909-838d6b92c22e?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1506485338023-6ce5f36692df?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=400&h=260&fit=crop&auto=format',
      ],
    ];

    final itemsState = _checklistItemsByTitle.putIfAbsent(
      title,
      () => sections.map((s) => List<String>.from(s.items)).toList(),
    );
    final addCtrls = _checklistAddCtrlsByTitle.putIfAbsent(
      title,
      () => List.generate(sections.length, (_) => TextEditingController()),
    );
    final checksState = _checklistChecksByTitle.putIfAbsent(
      title,
      () => itemsState
          .map(
            (items) => List<bool>.filled(items.length, false, growable: true),
          )
          .toList(),
    );
    final isSaved = _checklistSavedByTitle[title] ?? false;

    for (var i = 0; i < itemsState.length; i++) {
      final targetLen = itemsState[i].length;
      if (checksState[i].length < targetLen) {
        checksState[i].addAll(
          List<bool>.filled(
            targetLen - checksState[i].length,
            false,
            growable: true,
          ),
        );
      } else if (checksState[i].length > targetLen) {
        checksState[i] = checksState[i].sublist(0, targetLen);
      }
    }

    return StatefulBuilder(
      builder: (context, checklistSetState) {
        final totalItems = itemsState.fold<int>(
          0,
          (sum, items) => sum + items.length,
        );
        final totalChecked = checksState.fold<int>(
          0,
          (sum, items) => sum + items.where((v) => v).length,
        );
        final progress = totalItems == 0 ? 0.0 : totalChecked / totalItems;

        return Container(
          margin: EdgeInsets.only(
            left: 4,
            right: (MediaQuery.of(context).size.width * 0.07).clamp(16.0, 28.0),
            bottom: 16,
          ),
          decoration: BoxDecoration(
            color: t.backgroundSecondary,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: t.phoneShell,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.intro,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalChecked of $totalItems items',
                      style: TextStyle(
                        color: t.mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      height: 7,
                      decoration: BoxDecoration(
                        color: t.cardBorder.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 300),
                          widthFactor: progress,
                          alignment: Alignment.centerLeft,
                          child: Container(color: t.accent.tertiary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...List.generate(sections.length, (sIdx) {
                final s = sections[sIdx];
                return Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border(
                      top: BorderSide(
                        color: t.cardBorder.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(s.emoji),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.name,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 64,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: sectionImages[sIdx].length,
                          itemExtent: 88,
                          itemBuilder: (_, imgIdx) {
                            final img = sectionImages[sIdx][imgIdx];
                            return Padding(
                              padding: EdgeInsets.only(
                                right: imgIdx == sectionImages[sIdx].length - 1
                                    ? 0
                                    : 8,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: t.cardBorder.withValues(alpha: 0.85),
                                  ),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: Image.network(
                                  img,
                                  fit: BoxFit.cover,
                                  cacheWidth: 264,
                                  cacheHeight: 192,
                                  errorBuilder: (_, _, _) => Container(
                                    color: t.panel.withValues(alpha: 0.75),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 16,
                                      color: t.mutedText,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(itemsState[sIdx].length, (i) {
                        final done = checksState[sIdx][i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: t.panel.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: t.cardBorder.withValues(alpha: 0.8),
                            ),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => checklistSetState(
                                  () => checksState[sIdx][i] = !done,
                                ),
                                child: Icon(
                                  done
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 18,
                                  color: done ? s.color : t.mutedText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  itemsState[sIdx][i],
                                  style: TextStyle(
                                    color: done ? t.mutedText : t.textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  checklistSetState(() {
                                    itemsState[sIdx].removeAt(i);
                                    checksState[sIdx].removeAt(i);
                                  });
                                },
                                child: Text(
                                  'Ã—',
                                  style: TextStyle(
                                    color: t.mutedText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: t.phoneShellInner.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: addCtrls[sIdx],
                                style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 12,
                                ),
                                decoration: InputDecoration(
                                  hintText: AppLocalizations.t(
                                    context,
                                    'chat_add_item',
                                  ),
                                  hintStyle: TextStyle(
                                    color: t.mutedText,
                                    fontSize: 12,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (_) {
                                  final v = addCtrls[sIdx].text.trim();
                                  if (v.isEmpty) return;
                                  checklistSetState(() {
                                    itemsState[sIdx].add(v);
                                    checksState[sIdx].add(false);
                                    addCtrls[sIdx].clear();
                                  });
                                },
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                final v = addCtrls[sIdx].text.trim();
                                if (v.isEmpty) return;
                                checklistSetState(() {
                                  itemsState[sIdx].add(v);
                                  checksState[sIdx].add(false);
                                  addCtrls[sIdx].clear();
                                });
                              },
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: s.color,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  '+',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: GestureDetector(
                  onTap: isSaved
                      ? null
                      : () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: t.backgroundSecondary,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (_) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),
                                  Text(
                                    AppLocalizations.t(
                                      context,
                                      'save_to_board_title',
                                    ),
                                    style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...[
                                    'Party Looks',
                                    'Occasion',
                                    'Office Fit',
                                    'Vacation',
                                  ].map(
                                    (b) => ListTile(
                                      title: Text(
                                        b,
                                        style: TextStyle(color: t.textPrimary),
                                      ),
                                      trailing: Icon(
                                        Icons.chevron_right_rounded,
                                        color: t.mutedText,
                                      ),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        final didSave =
                                            await _saveChecklistToBoard(
                                              boardLabel: b,
                                              itemsState: itemsState,
                                            );
                                        if (!mounted) return;
                                        if (didSave) {
                                          checklistSetState(
                                            () =>
                                                _checklistSavedByTitle[title] =
                                                    true,
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'No matching wardrobe items found for this board.',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          );
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSaved
                          ? LinearGradient(
                              colors: [t.accent.tertiary, t.accent.tertiary],
                            )
                          : LinearGradient(
                              colors: [t.accent.tertiary, t.accent.primary],
                            ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isSaved
                          ? AppLocalizations.t(context, 'list_saved')
                          : AppLocalizations.t(context, 'save_to_board'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chips(AppThemeTokens t) {
    final chips = _getChipsByModule(context)[_module] ?? const <String>[];
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _handleChipTap(chips[i]),
          child: _chip(chips[i], t),
        ),
      ),
    );
  }

  Widget _chip(String label, AppThemeTokens t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: t.panel,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: t.cardBorder, width: 1.2),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: t.mutedText,
      ),
    ),
  );

  Widget _input(AppThemeTokens t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chips(t),
        AhviChatPromptBar(
          controller: _chatController,
          focusNode: _chatFocusNode,
          hintText: AppLocalizations.t(context, 'chat_hint'),
          hasTextListenable: _chatController,
          surface: t.phoneShellInner,
          border: t.cardBorder,
          accent: t.accent.primary,
          accentSecondary: t.accent.secondary,
          textHeading: t.textPrimary,
          textMuted: t.mutedText,
          shadowMedium: t.backgroundPrimary.withValues(alpha: 0.20),
          onAccent: Colors.white,
          themeTokens: t,
          onVoiceTap: _toggleListening,
          isListening: _isListening,
          onSendMessage: (v) => _sendMessage(v),
          // â”€â”€ Lens sheet actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          // TODO: implement Visual Search (image picker â†’ AI search)
          onVisualSearch: () {},
          // TODO: implement Find Similar (wardrobe â†’ similar items screen)
          onFindSimilar: () {},
          // TODO: implement Add to Wardrobe (image picker â†’ wardrobe save)
          onAddToWardrobe: () {},
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// â”€â”€ Outfit Detail Page (Hero expand destination) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _OutfitDetailPage extends StatefulWidget {
  final _Outfit outfit;
  final String heroTag;
  final AppThemeTokens t;
  final ValueChanged<bool> onSaveChanged;

  const _OutfitDetailPage({
    required this.outfit,
    required this.heroTag,
    required this.t,
    required this.onSaveChanged,
  });

  @override
  State<_OutfitDetailPage> createState() => _OutfitDetailPageState();
}

class _OutfitDetailPageState extends State<_OutfitDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _contentCtrl;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late bool _saved;

  @override
  void initState() {
    super.initState();
    _saved = widget.outfit.saved;
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _contentFade = CurvedAnimation(
      parent: _contentCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentCtrl,
            curve: const Interval(0.2, 1.0, curve: Cubic(0.16, 1.0, 0.3, 1.0)),
          ),
        );
    Future.delayed(const Duration(milliseconds: 170), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final accent = t.accent.primary;
    final accentTertiary = t.accent.tertiary;
    final bg = t.backgroundPrimary;
    final surface = t.phoneShellInner;
    final onAccent = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: bg.withValues(alpha: 0.82),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // prevent tap-through
              child: Hero(
                tag: widget.heroTag,
                flightShuttleBuilder: (_, animation, __, ___, toCtx) =>
                    AnimatedBuilder(
                      animation: animation,
                      builder: (_, __) => toCtx.widget,
                    ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: screenW * 0.88,
                    constraints: BoxConstraints(maxHeight: screenH * 0.82),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.22),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: bg.withValues(alpha: 0.50),
                          blurRadius: 60,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color: accent.withValues(alpha: 0.10),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // â”€â”€ Large image â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        SizedBox(
                          height: screenH * 0.42,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                widget.outfit.image,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorBuilder: (_, __, ___) => Container(
                                  color: accent.withValues(alpha: 0.10),
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: t.mutedText,
                                    size: 48,
                                  ),
                                ),
                              ),
                              // Bottom fade
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 80,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, surface],
                                    ),
                                  ),
                                ),
                              ),
                              // Top shimmer line
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        accent.withValues(alpha: 0.55),
                                        accentTertiary.withValues(alpha: 0.45),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.35, 0.65, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Close button
                              Positioned(
                                top: 14,
                                right: 14,
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: bg.withValues(alpha: 0.55),
                                      border: Border.all(
                                        color: t.cardBorder,
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: t.textPrimary,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        FadeTransition(
                          opacity: _contentFade,
                          child: SlideTransition(
                            position: _contentSlide,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(22, 6, 22, 26),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tags
                                  Wrap(
                                    spacing: 6,
                                    children: widget.outfit.tags
                                        .map(
                                          (tag) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: accent.withValues(
                                                alpha: 0.10,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              border: Border.all(
                                                color: accent.withValues(
                                                  alpha: 0.20,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              tag,
                                              style: TextStyle(
                                                color: accent,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                  const SizedBox(height: 10),

                                  // Name
                                  Text(
                                    widget.outfit.name,
                                    style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // 2-line description
                                  Text(
                                    widget.outfit.description.isNotEmpty
                                        ? widget.outfit.description
                                        : 'A curated look styled just for you.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: t.mutedText,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w400,
                                      height: 1.55,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Save button
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _saved = !_saved);
                                      widget.onSaveChanged(_saved);
                                      if (_saved) HapticFeedback.lightImpact();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 260,
                                      ),
                                      curve: const Cubic(0.34, 1.56, 0.64, 1.0),
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: _saved
                                            ? null
                                            : LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  accent,
                                                  accentTertiary,
                                                ],
                                              ),
                                        color: _saved ? t.panel : null,
                                        borderRadius: BorderRadius.circular(16),
                                        border: _saved
                                            ? Border.all(
                                                color: accent.withValues(
                                                  alpha: 0.30,
                                                ),
                                                width: 1,
                                              )
                                            : null,
                                        boxShadow: _saved
                                            ? []
                                            : [
                                                BoxShadow(
                                                  color: accent.withValues(
                                                    alpha: 0.30,
                                                  ),
                                                  blurRadius: 18,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _saved
                                                ? Icons.bookmark_rounded
                                                : Icons.bookmark_border_rounded,
                                            color: _saved ? accent : onAccent,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _saved
                                                ? 'Saved to Wardrobe'
                                                : 'Save Outfit',
                                            style: TextStyle(
                                              color: _saved ? accent : onAccent,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ],
                                      ),
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
            ),
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Pulsing mic animation when listening â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon();

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return ScaleTransition(
      scale: _scale,
      child: const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
    );
  }
}
