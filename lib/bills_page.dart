import 'dart:math';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:flutter/material.dart';
import 'package:myapp/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:myapp/services/appwrite_service.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';

// ── PALETTE (1:1 from CSS :root) ────────────────────────────────────
Color kBg = Color(0xFF08111F);
Color kBg2 = Color(0xFF0F1A2D);
Color kShell = Color(0xFF192131);
Color kShell2 = Color(0xFF111723);
Color kText = Color(0xFFF5F7FF);
Color kMuted = Color(0xB8E6EBFF);
Color kAccent = Color(0xFF6B91FF);
Color kAccent2 = Color(0xFF8D7DFF);
Color kAccent3 = Color(0xFF04D7C8);
Color kAccent4 = Color(0xFFFF8EC7);
Color kAccent5 = Color(0xFFFFD86E);
Color kRed = Color(0xFFFF6B7A);
Color kPanel = Color(0x14FFFFFF);
Color kPanel2 = Color(0x1FFFFFFF);
Color kBorder = Color(0x1FFFFFFF);

// ════════════════════════════════════════════════════════════════════
//  TRANSLATION HELPERS  (top-level so all widgets can use them)
// ════════════════════════════════════════════════════════════════════
String _translateCategory(BuildContext context, String key) {
  switch (key.toLowerCase()) {
    case 'shopping': return AppLocalizations.t(context, 'bills_cat_shopping');
    case 'food':     return AppLocalizations.t(context, 'bills_cat_food');
    case 'utility':  return AppLocalizations.t(context, 'bills_cat_utility');
    case 'medical':  return AppLocalizations.t(context, 'bills_cat_medical');
    default:         return AppLocalizations.t(context, 'bills_cat_other');
  }
}

String _translatePayment(BuildContext context, String key) {
  switch (key) {
    case 'UPI':         return AppLocalizations.t(context, 'bills_pay_upi');
    case 'Credit Card': return AppLocalizations.t(context, 'bills_pay_credit');
    case 'Debit Card':  return AppLocalizations.t(context, 'bills_pay_debit');
    case 'Cash':        return AppLocalizations.t(context, 'bills_pay_cash');
    case 'Net Banking': return AppLocalizations.t(context, 'bills_pay_netbanking');
    default:            return key;
  }
}

String _categoryDbKey(BuildContext context, String localizedCat) {
  if (localizedCat == AppLocalizations.t(context, 'bills_cat_shopping')) return 'shopping';
  if (localizedCat == AppLocalizations.t(context, 'bills_cat_food'))     return 'food';
  if (localizedCat == AppLocalizations.t(context, 'bills_cat_utility'))  return 'utility';
  if (localizedCat == AppLocalizations.t(context, 'bills_cat_medical'))  return 'medical';
  return 'other';
}

String _couponTypeDbKey(BuildContext context, String localizedType) {
  if (localizedType == AppLocalizations.t(context, 'bills_coupon_type_percent')) return 'percent';
  if (localizedType == AppLocalizations.t(context, 'bills_coupon_type_flat'))    return 'flat';
  if (localizedType == AppLocalizations.t(context, 'bills_coupon_type_free'))    return 'free';
  return localizedType.toLowerCase();
}

String _paymentDbKey(BuildContext context, String localizedPay) {
  if (localizedPay == AppLocalizations.t(context, 'bills_pay_upi'))        return 'UPI';
  if (localizedPay == AppLocalizations.t(context, 'bills_pay_credit'))     return 'Credit Card';
  if (localizedPay == AppLocalizations.t(context, 'bills_pay_debit'))      return 'Debit Card';
  if (localizedPay == AppLocalizations.t(context, 'bills_pay_cash'))       return 'Cash';
  if (localizedPay == AppLocalizations.t(context, 'bills_pay_netbanking')) return 'Net Banking';
  return localizedPay;
}

// ════════════════════════════════════════════════════════════════════
//  ROOT WIDGET
// ════════════════════════════════════════════════════════════════════
class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});
  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen>
    with TickerProviderStateMixin {
  AppThemeTokens get _t => context.themeTokens;
  Color get _accent => _t.accent.primary;
  Color get _accent2 => _t.accent.secondary;
  Color get _accent3 => _t.accent.tertiary;
  Color get _accent4 => Color.lerp(_accent2, _accent, 0.45)!;
  Color get _accent5 => Color.lerp(_accent, _accent3, 0.45)!;

  // ── STATE ──────────────────────────────────────────────────────────
  bool _isLoading = true;
  String _activeFilter = 'all';
  bool _chatOpen = false;

  String _addMode = 'ai';
  // These are initialized lazily in didChangeDependencies so they always
  // match the first item in the localized dropdown lists.
  String? _selCategory;
  String? _selPayment;
  String? _couponTypeVal; // Initialized in didChangeDependencies from localized list
  DateTime _selectedDate = DateTime.now();

  String _toastMsg = '';
  bool _toastVisible = false;
  late AnimationController _toastAnim;

  late AnimationController _pulseCtrl;

  late AnimationController _chatCtrl;
  late Animation<double> _chatSlide;

  late AnimationController _sheetCtrl;

  bool _isSavingBill = false;
  bool _isSavingCoupon = false;

  // Holds the StatefulBuilder's setState so the sheet rebuilds on toggle
  StateSetter? _sheetSetState;

  final List<Map<String, String>> _chatMessages = [
    {
      'from': 'ahvi',
      'text':
          'Hi! ✦ I\'m AHVI. Upload a bill photo for AI autofill, or enter details manually — I\'ve got you covered!',
    },
  ];
  final TextEditingController _chatInputCtrl = TextEditingController();
  OverlayEntry? _overlay;

  // ── DB DATA LISTS ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _coupons = [];

  // ── COMPUTED ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredBills {
    if (_activeFilter == 'all') return _bills;
    return _bills.where((b) => b['category'] == _activeFilter).toList();
  }

  double get _totalAmount =>
      _filteredBills.fold(0.0, (sum, b) => sum + (b['amount'] as double));

  String get _avgBill {
    final list = _filteredBills;
    if (list.isEmpty) return '–';
    final avg = _totalAmount / list.length;
    return '₹${avg.toStringAsFixed(0)}';
  }

  String get _topCategory {
    if (_bills.isEmpty) return '–';
    final Map<String, double> totals = {};
    for (final b in _bills) {
      final cat = b['category'] as String;
      totals[cat] = (totals[cat] ?? 0) + (b['amount'] as double);
    }
    final top = totals.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final icons = {
      'food': '🍔',
      'shopping': '🛍️',
      'medical': '💊',
      'utility': '⚡',
      'other': '📄',
    };
    return icons[top.toLowerCase()] ?? '–';
  }

  String _formatAmount(double v) {
    if (v >= 1000) {
      final s = v.toStringAsFixed(0);
      final parts = <String>[];
      var rem = s;
      while (rem.length > 3) {
        parts.insert(0, rem.substring(rem.length - 3));
        rem = rem.substring(0, rem.length - 3);
      }
      parts.insert(0, rem);
      return parts.join(',');
    }
    return v.toStringAsFixed(0);
  }

  Map<String, dynamic> _getCategoryMeta(String cat) {
    final meta = {
      'shopping': {'icon': '🛍️', 'color': kAccent2, 'bg': Color(0x268D7DFF)},
      'food': {'icon': '🍔', 'color': kAccent5, 'bg': Color(0x26FFD86E)},
      'utility': {'icon': '⚡', 'color': kAccent3, 'bg': Color(0x2604D7C8)},
      'medical': {'icon': '💊', 'color': kAccent4, 'bg': Color(0x26FF8EC7)},
      'other': {'icon': '📄', 'color': _t.textPrimary, 'bg': Color(0x1AFFFFFF)},
    };
    return meta[cat.toLowerCase()] ?? meta['other']!;
  }

  // ── LIFECYCLE ─────────────────────────────────────────────────────

  /// Called once after first build (when context has Localizations).
  /// Re-initializes dropdown values whenever the locale changes so that
  /// the selected value always matches one of the localized items.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final firstCat = AppLocalizations.t(context, 'bills_cat_shopping');
    final firstPay = AppLocalizations.t(context, 'bills_pay_upi');
    // Only reset when unset or when the locale-generated value has changed
    // (i.e. the user switched language mid-session).
    final catItems = [
      AppLocalizations.t(context, 'bills_cat_shopping'),
      AppLocalizations.t(context, 'bills_cat_food'),
      AppLocalizations.t(context, 'bills_cat_utility'),
      AppLocalizations.t(context, 'bills_cat_medical'),
      AppLocalizations.t(context, 'bills_cat_other'),
    ];
    final payItems = [
      AppLocalizations.t(context, 'bills_pay_upi'),
      AppLocalizations.t(context, 'bills_pay_credit'),
      AppLocalizations.t(context, 'bills_pay_debit'),
      AppLocalizations.t(context, 'bills_pay_cash'),
      AppLocalizations.t(context, 'bills_pay_netbanking'),
    ];
    if (_selCategory == null || !catItems.contains(_selCategory)) {
      _selCategory = firstCat;
    }
    if (_selPayment == null || !payItems.contains(_selPayment)) {
      _selPayment = firstPay;
    }

    final couponItems = [
      AppLocalizations.t(context, 'bills_coupon_type_percent'),
      AppLocalizations.t(context, 'bills_coupon_type_flat'),
      AppLocalizations.t(context, 'bills_coupon_type_free'),
    ];
    if (_couponTypeVal == null || !couponItems.contains(_couponTypeVal)) {
      _couponTypeVal = couponItems[0];
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchData();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);


    _chatCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350),
    );
    _chatSlide = CurvedAnimation(parent: _chatCtrl, curve: Curves.easeOutBack);

    _sheetCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 450),
    );

    _toastAnim = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }


  // ── APPWRITE ACTIONS ──────────────────────────────────────────────

  // Converts Appwrite ISO Datetime back to a friendly UI string
  String _formatFriendlyDate(String isoString) {
    try {
      final d = DateTime.parse(isoString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (e) {
      return isoString;
    }
  }

  Future<void> _fetchData() async {
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      final billsDocs = await appwrite.getBills();
      final couponsDocs = await appwrite.getCoupons();

      if (mounted) {
        setState(() {
          _bills = billsDocs
              .map(
                (d) => {
                  'id': d.$id,
                  'store': d.data['store'],
                  'amount': (d.data['amount'] as num)
                      .toDouble(), // Safe cast int to double for UI
                  'date': _formatFriendlyDate(
                    d.data['date'],
                  ), // Convert datetime to nice string
                  'category': d.data['category'],
                  'payment': d.data['payment'],
                  'items': d.data['items'] ?? '',
                  'note': d.data['note'] ?? '',
                },
              )
              .toList();

          _coupons = couponsDocs
              .map(
                (d) => {
                  'id': d.$id,
                  'code': d.data['code'],
                  'type': d.data['type'],
                  'value': (d.data['value'] as num)
                      .toDouble(), // Safe cast int to double for UI
                  'note': d.data['note'] ?? '',
                },
              )
              .toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showToast(AppLocalizations.t(context, 'bills_load_error'));
    }
  }

  void _deleteBill(String id) async {
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      await appwrite.deleteBill(id);
      if (!mounted) return;
      setState(() => _bills.removeWhere((b) => b['id'] == id));
      _showToast(AppLocalizations.t(context, 'bills_removed'));
    } catch (e) {
      if (!mounted) return;
      _showToast(AppLocalizations.t(context, 'bills_remove_error'));
    }
  }

  void _deleteCoupon(String id) async {
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      await appwrite.deleteCoupon(id);
      if (!mounted) return;
      setState(() => _coupons.removeWhere((c) => c['id'] == id));
      _showToast(AppLocalizations.t(context, 'bills_coupon_removed'));
    } catch (e) {
      if (!mounted) return;
      _showToast(AppLocalizations.t(context, 'bills_coupon_remove_error'));
    }
  }

  void _addBill({
    required String store,
    required String amount,
    required String category,
    required String payment,
    required String items,
    required String note,
  }) async {
    final amt = double.tryParse(amount) ?? 0;
    if (store.trim().isEmpty || amt <= 0) {
      _showToast(AppLocalizations.t(context, 'bills_fill_required'));
      return;
    }

    _setOverlayState(() => _isSavingBill = true);
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      await appwrite.createBill({
        'store': store.trim(),
        'amount': amt.toInt(), // ✅ FIXED: Appwrite expects Integer!
        'date': _selectedDate.toIso8601String(),
        'category': _categoryDbKey(context, category),
        'payment': _paymentDbKey(context, payment),
        'items': items.trim(),
        'note': note.trim().isEmpty ? null : note.trim(), // Send null if empty
      });

      if (mounted) {
        _fetchData();
        _closeOverlay();
        _showToast('✦ Bill saved!');
      }
    } catch (e) {
      if (mounted) _showToast(AppLocalizations.t(context, 'bills_save_error'));
      debugPrint("Bill Error: $e");
    } finally {
      if (mounted) _setOverlayState(() => _isSavingBill = false);
    }
  }

  void _saveNewCoupon() async {
    final code = _newCodeCtrl.text.trim().toUpperCase();
    final value = double.tryParse(_newValueCtrl.text) ?? 0;
    final note = _newNoteCtrl.text.trim();

    if (code.isEmpty) {
      _showToast(AppLocalizations.t(context, 'bills_enter_coupon'));
      return;
    }
    final couponFreeKey = AppLocalizations.t(context, 'bills_coupon_type_free');
    if (_couponTypeVal != couponFreeKey && value <= 0) {
      _showToast(AppLocalizations.t(context, 'bills_enter_valid'));
      return;
    }
    if (_coupons.any((c) => c['code'] == code)) {
      _showToast(AppLocalizations.t(context, 'bills_coupon_saved'));
      return;
    }

    _setOverlayState(() => _isSavingCoupon = true);
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);

      await appwrite.createCoupon({
        'code': code,
        'type': _couponTypeDbKey(context, _couponTypeVal ?? ''),
        'value': value.toInt(), // ✅ FIXED: Appwrite expects Integer!
        'note': note.isEmpty ? null : note,
      });

      if (mounted) {
        _newCodeCtrl.clear();
        _newValueCtrl.clear();
        _newNoteCtrl.clear();
        _fetchData(); // Refresh coupons
        _showToast('✦ Coupon "$code" saved!');
      }
    } catch (e) {
      if (mounted) _showToast(AppLocalizations.t(context, 'bills_coupon_save_error'));
      debugPrint("Coupon Error: $e");
    } finally {
      if (mounted) _setOverlayState(() => _isSavingCoupon = false);
    }
  }

  // ── UI ACTIONS ────────────────────────────────────────────────────

  void _toggleChat() {
    setState(() => _chatOpen = !_chatOpen);
    if (_chatOpen) {
      _chatCtrl.forward();
    } else {
      _chatCtrl.reverse();
    }
  }

  /// Calls setState on both the parent and the sheet's StatefulBuilder
  /// so that mode toggles and loading flags both rebuild the sheet UI.
  void _setOverlayState(VoidCallback fn) {
    setState(fn);
    _sheetSetState?.call(fn);
  }

  void _openOverlay(String type) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Color(0xB808111F),
      useRootNavigator: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Store so _setOverlayState can trigger sheet rebuilds (e.g. mode toggle)
            _sheetSetState = setSheetState;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: type == 'add'
                  ? _buildAddSheet()
                  : _buildCouponMgrSheet(),
            );
          },
        );
      },
    ).then((_) {
      _sheetSetState = null; // Clear stale reference after sheet closes
      if (mounted) {
        setState(() {
          _selectedDate = DateTime.now();
          _storeCtrl.clear();
          _amountCtrl.clear();
          _itemsCtrl.clear();
          _notesCtrl.clear();
        });
      }
    });
  }

  void _closeOverlay() {
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  void _showToast(String msg) async {
    setState(() {
      _toastMsg = msg;
      _toastVisible = true;
    });
    await _toastAnim.forward(from: 0);
    await Future.delayed(Duration(milliseconds: 2200));
    await _toastAnim.reverse();
    if (mounted) setState(() => _toastVisible = false);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _chatCtrl.dispose();
    _sheetCtrl.dispose();
    _toastAnim.dispose();
    _chatInputCtrl.dispose();
    _removeOverlay();
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _t.backgroundPrimary,
        body: Center(child: CircularProgressIndicator(color: _accent2)),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: _t.backgroundPrimary,
        body: Stack(
          children: [
            _MeshBackground(
              base: _t.backgroundPrimary,
              glowA: _accent.withValues(alpha: 0.22),
              glowB: _accent2.withValues(alpha: 0.15),
            ),
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildScrollArea()),
                _buildBottomActions(),
              ],
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildChatFab(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _chatSlide,
              builder: (_, _) {
                return Positioned(
                  bottom: 170,
                  right: 24,
                  child: Opacity(
                    opacity: _chatSlide.value,
                    child: Transform(
                      alignment: Alignment.bottomRight,
                      transform: Matrix4.identity()
                        ..translateByVector3(
                            Vector3(0.0, 16.0 * (1 - _chatSlide.value), 0.0))
                        ..scaleByVector3(Vector3(
                            0.95 + 0.05 * _chatSlide.value,
                            0.95 + 0.05 * _chatSlide.value,
                            1.0)),
                      child: IgnorePointer(
                        ignoring: !_chatOpen,
                        child: _buildChatPanel(),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_toastVisible)
              AnimatedBuilder(
                animation: _toastAnim,
                builder: (_, _) => Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: _toastAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - _toastAnim.value)),
                        child: _buildToast(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      color: _t.backgroundPrimary,
      padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Icon ──
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _accent2.withValues(alpha: 0.22),
                  _accent.withValues(alpha: 0.22),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withValues(alpha: 0.25)),
            ),
            child: Icon(Icons.receipt_long_rounded, color: _accent, size: 22),
          ),
          SizedBox(width: 12),
          // ── Title ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      color: _accent,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      AppLocalizations.t(context, 'bills_title'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _t.textPrimary,
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  AppLocalizations.t(context, 'bills_by_ahvi'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.2,
                    color: _t.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sticky top section (spending card + filter tabs) ──
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSpendingCard(),
              SizedBox(height: 14),
              _buildFilterTabs(),
              SizedBox(height: 12),
              Text(
                _activeFilter == 'all'
                    ? AppLocalizations.t(context, 'bills_recent')
                    : _translateCategory(context, _activeFilter),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _t.textPrimary,
                ),
              ),
              SizedBox(height: 10),
            ],
          ),
        ),
        // ── Scrollable bills list only ──
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBillsList(),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildSpendingCard() {
    final bills = _filteredBills;
    final total = _totalAmount;
    final count = bills.length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accent2, _accent, _accent4.withValues(alpha: 0.85)],
          stops: [0.0, 0.4, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Color(0x1FFFFFFF),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Color(0x12FFFFFF),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t(context, 'bills_total_spending'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.88,
                    color: Color(0xBFFFFFFF),
                  ),
                ),
                SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: Align(
                    key: ValueKey(total),
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '₹',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xD9FFFFFF),
                            ),
                          ),
                          TextSpan(
                            text: _formatAmount(total),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildStatPill('$count', AppLocalizations.t(context, 'bills_stat_bills'))),
                    SizedBox(width: 8),
                    Expanded(child: _buildStatPill(_avgBill, AppLocalizations.t(context, 'bills_stat_avg'))),
                    SizedBox(width: 8),
                    Expanded(child: _buildStatPill(_topCategory, AppLocalizations.t(context, 'bills_stat_top'))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String value, String label) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: Color(0x38FFFFFF),
        border: Border.all(color: Color(0x4DFFFFFF), width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xB3FFFFFF),
              letterSpacing: 1.28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final tabs = [
      {'key': 'all', 'label': AppLocalizations.t(context, 'bills_filter_all'), 'color': Colors.white, 'bg': kBg2},
      {
        'key': 'shopping',
        'label': AppLocalizations.t(context, 'bills_filter_shopping'),
        'color': _accent2,
        'bg': _accent2.withValues(alpha: 0.18),
      },
      {
        'key': 'food',
        'label': AppLocalizations.t(context, 'bills_filter_food'),
        'color': _accent5,
        'bg': _accent5.withValues(alpha: 0.18),
      },
      {
        'key': 'utility',
        'label': AppLocalizations.t(context, 'bills_filter_utility'),
        'color': _accent3,
        'bg': _accent3.withValues(alpha: 0.18),
      },
      {
        'key': 'medical',
        'label': AppLocalizations.t(context, 'bills_filter_medical'),
        'color': _accent4,
        'bg': _accent4.withValues(alpha: 0.18),
      },
      {
        'key': 'other',
        'label': AppLocalizations.t(context, 'bills_filter_other'),
        'color': _t.textPrimary,
        'bg': _t.backgroundSecondary,
      },
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final key = tab['key'] as String;
          final isActive = _activeFilter == key;
          final color = tab['color'] as Color;
          final bg = tab['bg'] as Color;
          return Padding(
            padding: EdgeInsets.only(right: 7),
            child: GestureDetector(
              onTap: () => setState(() => _activeFilter = key),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive ? bg : _t.panel,
                  border: Border.all(
                    color: isActive
                        ? color.withValues(alpha: 0.6)
                        : _t.cardBorder,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isActive
                          ? color.withValues(alpha: 0.14)
                          : _accent.withValues(alpha: 0.08),
                      blurRadius: isActive ? 14 : 8,
                      offset: Offset(0, isActive ? 4 : 2),
                    ),
                  ],
                ),
                child: AnimatedDefaultTextStyle(
                  duration: Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: isActive ? color : _t.textPrimary,
                    letterSpacing: 0.2,
                  ),
                  child: Text(tab['label'] as String),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBillsList() {
    final bills = _filteredBills;
    if (bills.isEmpty) return _buildEmptyState();

    return Column(
      children: bills.asMap().entries.map((entry) {
        final i = entry.key;
        final bill = entry.value;
        final meta = _getCategoryMeta(bill['category'] as String);

        return _AnimatedBillCard(
          key: ValueKey(bill['id']),
          bill: bill,
          meta: meta,
          delay: Duration(milliseconds: i * 60),
          onTap: () => _showDetailSheet(bill, meta),
          onDelete: () => _deleteBill(bill['id'] as String),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _t.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _t.cardBorder, width: 1.5),
      ),
      child: Column(
        children: [
          Text('🧾', style: TextStyle(fontSize: 56)),
          SizedBox(height: 16),
          Text(
            AppLocalizations.t(context, 'bills_empty_title'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _t.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            AppLocalizations.t(context, 'bills_empty_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _t.mutedText,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 28),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: _PressScaleButton(
              onTap: () => _openOverlay('add'),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accent2, _accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: _accent2.withValues(alpha: 0.40),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      AppLocalizations.t(context, 'bills_btn_add_bill'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _PressScaleButton(
              onTap: () => _openOverlay('coupon'),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accent, _accent2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.35),
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          AppLocalizations.t(context, 'bills_btn_my_coupons'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: 14,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      height: 18,
                      constraints: BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: _accent4,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: _t.backgroundPrimary,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${_coupons.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatFab() {
    return AhviStylistFab(onTap: () => showAhviStylistChatSheet(context, moduleContext: 'bills'));
  }

  Widget _buildChatPanel() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: _t.backgroundSecondary,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _t.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 60,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x1A8D7DFF), Color(0x0FFF8EC7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(bottom: BorderSide(color: _t.cardBorder, width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_accent2, _accent4]),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AHVI',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _t.textPrimary,
                          ),
                        ),
                        Text(
                          'Online · Bills Assistant',
                          style: TextStyle(
                            fontSize: 9,
                            color: _t.mutedText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleChat,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _t.panel,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: _t.textPrimary,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _chatMessages.length,
                itemBuilder: (_, i) {
                  final msg = _chatMessages[i];
                  final isAhvi = msg['from'] == 'ahvi';
                  return Align(
                    alignment: isAhvi
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      constraints: const BoxConstraints(maxWidth: 220),
                      decoration: BoxDecoration(
                        color: isAhvi
                            ? _t.panel
                            : _accent2.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isAhvi ? 4 : 16),
                          bottomRight: Radius.circular(isAhvi ? 16 : 4),
                        ),
                        border: Border.all(color: _t.cardBorder, width: 1),
                      ),
                      child: Text(
                        msg['text']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _t.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _t.cardBorder, width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Attachment chip (shown above input row when file/search picked) ──
                  Padding(
                    padding: EdgeInsets.fromLTRB(10, 8, 10, 12),
                    child: Row(
                children: [
                  SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _t.panel,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      color: _t.mutedText,
                      size: 14,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _chatInputCtrl,
                      style: TextStyle(fontSize: 12, color: _t.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ask about your bills…',
                        hintStyle: TextStyle(color: _t.mutedText, fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                      ),
                      onSubmitted: (v) => _sendChatMsg(v),
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendChatMsg(_chatInputCtrl.text),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_accent2, _accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _accent2.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
                  ),   // Padding
                ],
              ),   // Column
            ),
          ],
        ),
      ),
    );
  }

  void _sendChatMsg(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _chatMessages.add({'from': 'user', 'text': text.trim()});
      _chatMessages.add({
        'from': 'ahvi',
        'text': 'Got it! I\'m reviewing your bills now… ✦',
      });
    });
    _chatInputCtrl.clear();
  }



  // ════════════════════════════════════════════════════════════════════
  //  ADD BILL SHEET
  // ════════════════════════════════════════════════════════════════════
  final _storeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _itemsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _couponCtrl = TextEditingController();

  Widget _buildAddSheet() {
    return Container(
      decoration: BoxDecoration(
        color: _t.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        border: Border(top: BorderSide(color: _t.cardBorder, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Color(0x266B91FF),
            blurRadius: 60,
            offset: Offset(0, -20),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(22, 0, 22, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            Text(
              AppLocalizations.t(context, 'bills_sheet_add_title'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _t.textPrimary,
              ),
            ),
            SizedBox(height: 3),
            Text(
              AppLocalizations.t(context, 'bills_sheet_add_sub'),
              style: TextStyle(
                fontSize: 11,
                color: _t.mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 14),

            _buildModeToggle(),
            SizedBox(height: 16),

            if (_addMode == 'ai') ...[
              _buildUploadSection(),
              SizedBox(height: 12),
            ],

            if (_addMode == 'manual') ...[
              _buildManualBanner(),
              SizedBox(height: 12),
            ],

            _buildFormGroup(
              AppLocalizations.t(context, 'bills_field_store'),
              child: _glassInput(
                controller: _storeCtrl,
                placeholder: AppLocalizations.t(context, 'bills_field_store_hint'),
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildFormGroup(
                    AppLocalizations.t(context, 'bills_field_amount'),
                    child: _glassInput(
                      controller: _amountCtrl,
                      placeholder: '0.00',
                      inputType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildFormGroup(AppLocalizations.t(context, 'bills_field_date'), child: _datePickerTrigger()),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildFormGroup(
                    AppLocalizations.t(context, 'bills_field_category'),
                    child: _buildSelectField(
                      value: _selCategory!,
                      items: [
                        AppLocalizations.t(context, 'bills_cat_shopping'),
                        AppLocalizations.t(context, 'bills_cat_food'),
                        AppLocalizations.t(context, 'bills_cat_utility'),
                        AppLocalizations.t(context, 'bills_cat_medical'),
                        AppLocalizations.t(context, 'bills_cat_other'),
                      ],
                      onChanged: (v) => _setOverlayState(() => _selCategory = v!),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildFormGroup(
                    AppLocalizations.t(context, 'bills_field_payment'),
                    child: _buildSelectField(
                      value: _selPayment!,
                      items: [
                        AppLocalizations.t(context, 'bills_pay_upi'),
                        AppLocalizations.t(context, 'bills_pay_credit'),
                        AppLocalizations.t(context, 'bills_pay_debit'),
                        AppLocalizations.t(context, 'bills_pay_cash'),
                        AppLocalizations.t(context, 'bills_pay_netbanking'),
                      ],
                      onChanged: (v) => _setOverlayState(() => _selPayment = v!),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            _buildFormGroup(
              AppLocalizations.t(context, 'bills_field_items'),
              child: _glassInput(
                controller: _itemsCtrl,
                placeholder: AppLocalizations.t(context, 'bills_field_items_hint'),
              ),
            ),
            SizedBox(height: 10),
            _buildFormGroup(
              AppLocalizations.t(context, 'bills_field_notes'),
              child: _glassInput(
                controller: _notesCtrl,
                placeholder: AppLocalizations.t(context, 'bills_field_notes_hint'),
                maxLines: 3,
              ),
            ),
            SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _PressScaleButton(
                    onTap: _closeOverlay,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: _t.panel,
                        border: Border.all(color: _t.cardBorder, width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          AppLocalizations.t(context, 'bills_btn_cancel'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _t.mutedText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _PressScaleButton(
                    onTap: () {
                      if (_isSavingBill) return;
                      _addBill(
                        store: _storeCtrl.text,
                        amount: _amountCtrl.text,
                        category: _selCategory ?? '',
                        payment: _selPayment ?? '',
                        items: _itemsCtrl.text,
                        note: _notesCtrl.text,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_accent2, _accent]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.30),
                            blurRadius: 20,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isSavingBill
                            ? SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                AppLocalizations.t(context, 'bills_btn_save'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: kPanel,
        border: Border.all(color: kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: ['ai', 'manual'].map((mode) {
          final isActive = _addMode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => _setOverlayState(() => _addMode = mode),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 280),
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? (mode == 'ai' ? Color(0x268D7DFF) : Color(0x2604D7C8))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      mode == 'ai' ? Icons.auto_awesome : Icons.edit_outlined,
                      size: 14,
                      color: isActive
                          ? (mode == 'ai' ? kAccent2 : kAccent3)
                          : _t.mutedText,
                    ),
                    SizedBox(width: 5),
                    Text(
                      mode == 'ai'
                          ? AppLocalizations.t(context, 'bills_mode_ai')
                          : AppLocalizations.t(context, 'bills_mode_manual'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? (mode == 'ai' ? kAccent2 : kAccent3)
                            : _t.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUploadSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.t(context, 'bills_upload_photo'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _t.mutedText,
            letterSpacing: 1.6,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _uploadOptBtn(
                icon: Icons.camera_alt_outlined,
                iconColor: Color(0xFFD4756E),
                bg: isDark ? Color(0x1FD4756E) : Color(0xFFD4756E).withValues(alpha: 0.08),
                border: isDark ? Color(0x33D4756E) : Color(0xFFD4756E).withValues(alpha: 0.30),
                label: AppLocalizations.t(context, 'bills_camera_label'),
                sub: AppLocalizations.t(context, 'bills_camera_sub'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _uploadOptBtn(
                icon: Icons.upload_file_outlined,
                iconColor: Color(0xFF5A8FD8),
                bg: isDark ? Color(0x1F5A8FD8) : Color(0xFF5A8FD8).withValues(alpha: 0.08),
                border: isDark ? Color(0x335A8FD8) : Color(0xFF5A8FD8).withValues(alpha: 0.30),
                label: AppLocalizations.t(context, 'bills_upload_label'),
                sub: AppLocalizations.t(context, 'bills_upload_sub'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _uploadOptBtn({
    required IconData icon,
    required Color iconColor,
    required Color bg,
    required Color border,
    required String label,
    required String sub,
  }) {
    return _PressScaleButton(
      onTap: () => _showToast('Camera/Upload coming soon'),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 22),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
            SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                fontSize: 10,
                color: _t.mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualBanner() {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(0x1204D7C8),
        border: Border.all(color: Color(0x2904D7C8), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_rounded, color: kAccent3, size: 16),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.t(context, 'bills_manual_mode'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kAccent3,
                ),
              ),
              Text(
                AppLocalizations.t(context, 'bills_manual_sub'),
                style: TextStyle(
                  fontSize: 10,
                  color: _t.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormGroup(String label, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _t.mutedText,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 5),
        child,
      ],
    );
  }

  Widget _glassInput({
    required TextEditingController controller,
    required String placeholder,
    TextInputType? inputType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _t.panel,
        border: Border.all(color: _t.cardBorder, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0x146B91FF),
            blurRadius: 14,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _t.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: _t.mutedText, fontSize: 13),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _datePickerTrigger() {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final d = _selectedDate;
    final label = '${months[d.month - 1]} ${d.day}, ${d.year}';

    return GestureDetector(
      onTap: () => _showThemedCalendar(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _t.panel,
          border: Border.all(color: _t.cardBorder, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 14, color: _accent2),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _t.textPrimary,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _accent2),
          ],
        ),
      ),
    );
  }

  /// Custom themed calendar dialog — matches app's dark glass style
  void _showThemedCalendar() {
    DateTime _viewMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    DateTime _tempSelected = _selectedDate;
    final now = DateTime.now();

    showDialog(
      context: context,
      barrierColor: Color(0xB808111F),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlgState) {
          final daysInMonth = DateUtils.getDaysInMonth(_viewMonth.year, _viewMonth.month);
          final firstWeekday = DateTime(_viewMonth.year, _viewMonth.month, 1).weekday % 7; // 0=Sun
          final monthLabel = [
            'January','February','March','April','May','June',
            'July','August','September','October','November','December'
          ][_viewMonth.month - 1];

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              decoration: BoxDecoration(
                color: _t.backgroundSecondary,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _t.cardBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _accent2.withValues(alpha: 0.18),
                    blurRadius: 40,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Month nav ─────────────────────────────────────
                  Row(
                    children: [
                      _calNavBtn(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => setDlgState(() {
                          _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
                        }),
                      ),
                      Expanded(
                        child: Text(
                          '$monthLabel ${_viewMonth.year}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _t.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _calNavBtn(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => setDlgState(() {
                          final next = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
                          if (!next.isAfter(DateTime(now.year, now.month + 1, 1))) {
                            _viewMonth = next;
                          }
                        }),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),

                  // ── Weekday headers ───────────────────────────────
                  Row(
                    children: ['Su','Mo','Tu','We','Th','Fr','Sa'].map((w) =>
                      Expanded(
                        child: Center(
                          child: Text(
                            w,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _t.mutedText,
                            ),
                          ),
                        ),
                      ),
                    ).toList(),
                  ),
                  SizedBox(height: 8),

                  // ── Day grid ──────────────────────────────────────
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 1,
                    ),
                    itemCount: firstWeekday + daysInMonth,
                    itemBuilder: (_, i) {
                      if (i < firstWeekday) return SizedBox.shrink();
                      final day = i - firstWeekday + 1;
                      final date = DateTime(_viewMonth.year, _viewMonth.month, day);
                      final isSelected = date.year == _tempSelected.year &&
                          date.month == _tempSelected.month &&
                          date.day == _tempSelected.day;
                      final isToday = date.year == now.year &&
                          date.month == now.month &&
                          date.day == now.day;
                      final isFuture = date.isAfter(now);

                      return GestureDetector(
                        onTap: isFuture ? null : () => setDlgState(() => _tempSelected = date),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [_accent2, _accent],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isSelected
                                ? null
                                : isToday
                                    ? _accent.withValues(alpha: 0.15)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isToday && !isSelected
                                ? Border.all(color: _accent.withValues(alpha: 0.50), width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected || isToday
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : isFuture
                                        ? _t.mutedText.withValues(alpha: 0.35)
                                        : _t.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 16),
                  Divider(color: _t.cardBorder, height: 1),
                  SizedBox(height: 12),

                  // ── Actions ───────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: _t.panel,
                              border: Border.all(color: _t.cardBorder, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _t.mutedText,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _setOverlayState(() => _selectedDate = _tempSelected);
                            Navigator.of(ctx).pop();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [_accent2, _accent]),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withValues(alpha: 0.30),
                                  blurRadius: 14,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'OK',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _calNavBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _t.panel,
          border: Border.all(color: _t.cardBorder, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _accent2, size: 18),
      ),
    );
  }

  Widget _buildSelectField({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _t.panel,
        border: Border.all(color: _t.cardBorder, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: _t.backgroundSecondary,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFFC4A0C8),
            size: 16,
          ),
          isExpanded: true,
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _t.textPrimary,
          ),
          items: items
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  //  COUPON MANAGER SHEET
  // ════════════════════════════════════════════════════════════════════
  final _newCodeCtrl = TextEditingController();
  final _newValueCtrl = TextEditingController();
  final _newNoteCtrl = TextEditingController();

  Widget _buildCouponMgrSheet() {
    return Container(
      decoration: BoxDecoration(
        color: _t.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        border: Border(top: BorderSide(color: _t.cardBorder, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2E8D7DFF),
            blurRadius: 60,
            offset: Offset(0, -20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 0),
            child: Column(
              children: [
                _sheetHandle(),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.t(context, 'bills_my_coupons_title'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _t.textPrimary,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            AppLocalizations.t(context, 'bills_saved_coupons_count').replaceFirst('{count}', '${_coupons.length}'),
                            style: TextStyle(
                              fontSize: 12,
                              color: _t.mutedText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PressScaleButton(
                      onTap: _closeOverlay,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _t.panel,
                          border: Border.all(color: _t.cardBorder),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: _t.textPrimary,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 40),
              child: Column(
                children: [
                  _buildAddCouponForm(),
                  SizedBox(height: 16),
                  if (_coupons.isEmpty) _buildCouponEmptyState(),
                  ..._coupons.asMap().entries.map(
                    (e) => _buildStoredCouponCard(e.value, e.key),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCouponForm() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _t.panel,
        border: Border.all(color: _t.cardBorder, width: 1.5),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _accent2.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _couponFieldLabel(AppLocalizations.t(context, 'bills_coupon_code_label')),
          SizedBox(height: 5),
          _couponInput(
            controller: _newCodeCtrl,
            placeholder: AppLocalizations.t(context, 'bills_coupon_code_placeholder'),
            isBold: true,
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _couponFieldLabel(AppLocalizations.t(context, 'bills_coupon_type_label')),
                    SizedBox(height: 5),
                    Container(
                      decoration: BoxDecoration(
                        color: _t.panel,
                        border: Border.all(color: _t.cardBorder, width: 1.5),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _couponTypeVal ?? AppLocalizations.t(context, 'bills_coupon_type_percent'),
                          dropdownColor: _t.backgroundSecondary,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFFC4A0C8),
                            size: 16,
                          ),
                          isExpanded: true,
                          padding: EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 2,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _t.textPrimary,
                          ),
                          items: [
                                AppLocalizations.t(context, 'bills_coupon_type_percent'),
                                AppLocalizations.t(context, 'bills_coupon_type_flat'),
                                AppLocalizations.t(context, 'bills_coupon_type_free'),
                              ].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                          onChanged: (v) => _setOverlayState(() => _couponTypeVal = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _couponFieldLabel(AppLocalizations.t(context, 'bills_coupon_value_label')),
                    SizedBox(height: 5),
                    _couponInput(
                      controller: _newValueCtrl,
                      placeholder: '0',
                      inputType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          _couponFieldLabel(AppLocalizations.t(context, 'bills_coupon_note_label')),
          SizedBox(height: 5),
          _couponInput(
            controller: _newNoteCtrl,
            placeholder: AppLocalizations.t(context, 'bills_coupon_note_placeholder'),
          ),
          SizedBox(height: 12),
          _PressScaleButton(
            onTap: () {
              if (!_isSavingCoupon) _saveNewCoupon();
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_accent2, _accent]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: _accent2.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSavingCoupon)
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  else ...[
                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      AppLocalizations.t(context, 'bills_coupon_save'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _couponFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: _t.mutedText,
      ),
    );
  }

  Widget _couponInput({
    required TextEditingController controller,
    required String placeholder,
    bool isBold = false,
    TextInputType? inputType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _t.panel,
        border: Border.all(color: _t.cardBorder, width: 1.5),
        borderRadius: BorderRadius.circular(13),
      ),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        textCapitalization: isBold
            ? TextCapitalization.characters
            : TextCapitalization.none,
        style: TextStyle(
          fontSize: isBold ? 14 : 13,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: _t.textPrimary,
          letterSpacing: isBold ? 1.0 : 0,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: _t.mutedText, fontSize: 13),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        ),
      ),
    );
  }

  Widget _buildCouponEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: _t.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _t.cardBorder,
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Text('🏷️', style: TextStyle(fontSize: 40)),
          SizedBox(height: 10),
          Text(
            AppLocalizations.t(context, 'bills_coupon_empty'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _t.textPrimary,
            ),
          ),
          SizedBox(height: 5),
          Text(
            AppLocalizations.t(context, 'bills_coupon_empty_sub'),
            style: TextStyle(
              fontSize: 11,
              color: _t.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoredCouponCard(Map<String, dynamic> coupon, int index) {
    final palettes = [
      [Color(0xFF8D7DFF), Color(0xFF6B91FF)],
      [Color(0xFFFF8EC7), Color(0xFFFFD86E)],
      [Color(0xFF04D7C8), Color(0xFF6B91FF)],
      [Color(0xFF6B91FF), Color(0xFF04D7C8)],
    ];
    final gradientColors = palettes[index % palettes.length];

    final bigNum = coupon['type'] == 'free'
        ? '🎁'
        : (coupon['type'] == 'flat'
              ? '₹${coupon['value'].toInt()}'
              : '${coupon['value'].toInt()}%');
    final unitTxt = coupon['type'] == 'free'
        ? AppLocalizations.t(context, 'bills_coupon_type_special')
        : (coupon['type'] == 'flat'
            ? AppLocalizations.t(context, 'bills_coupon_type_flat')
            : AppLocalizations.t(context, 'bills_coupon_type_off'));

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0x218050C8),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
            child: Container(
              width: 82,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -18,
                    right: -18,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Color(0x1FFFFFFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -22,
                    left: -10,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Color(0x14FFFFFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          bigNum,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 2),
                        Text(
                          unitTxt,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xD9FFFFFF),
                            letterSpacing: 0.64,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 14,
            child: CustomPaint(painter: _PerforationPainter(notchColor: _t.backgroundSecondary)),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(
                color: _t.backgroundSecondary,
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(20),
                ),
                border: Border.all(color: _t.cardBorder, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          coupon['code'] as String,
                          style: TextStyle(
                            fontFamily: 'Courier New',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _t.textPrimary,
                            letterSpacing: 1.28,
                          ),
                        ),
                        if ((coupon['note'] as String).isNotEmpty) ...[
                          SizedBox(height: 3),
                          Text(
                            coupon['note'] as String,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: _t.mutedText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: gradientColors.first.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_offer,
                                size: 8,
                                color: gradientColors.first,
                              ),
                              SizedBox(width: 3),
                              Text(
                                '${coupon['value'].toInt()}${coupon['type'] == 'percent' ? '%' : '₹'} Off',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.96,
                                  color: gradientColors.first,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PressScaleButton(
                    onTap: () => _deleteCoupon(coupon['id'] as String),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(0x14FF6B7A),
                        border: Border.all(color: Color(0x33FF6B7A), width: 1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 13,
                        color: Color(0x99FF6B7A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _showDetailSheet(Map<String, dynamic> bill, Map<String, dynamic> meta) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetailSheet(
        bill: bill,
        meta: meta,
        onDelete: (id) {
          Navigator.pop(context);
          _deleteBill(id);
        },
      ),
    );
  }

  Widget _buildToast() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xF20F1A2D),
        border: Border.all(color: kBorder, width: 1),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 20)],
      ),
      child: Text(
        _toastMsg,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _t.textPrimary,
        ),
      ),
    );
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: EdgeInsets.only(top: 8, bottom: 20),
        decoration: BoxDecoration(
          color: kPanel2,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ANIMATED BILL CARD
// ════════════════════════════════════════════════════════════════════
class _AnimatedBillCard extends StatefulWidget {
  final Map<String, dynamic> bill;
  final Map<String, dynamic> meta;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Duration delay;

  const _AnimatedBillCard({
    super.key,
    required this.bill,
    required this.meta,
    required this.onTap,
    required this.onDelete,
    required this.delay,
  });

  @override
  State<_AnimatedBillCard> createState() => _AnimatedBillCardState();
}

class _AnimatedBillCardState extends State<_AnimatedBillCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Cubic(0.34, 1.2, 0.64, 1)));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final meta = widget.meta;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1.0,
            duration: Duration(milliseconds: 120),
            child: Builder(builder: (context) {
              final t = context.themeTokens;
              return Container(
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: t.cardBorder, width: 1.5),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _pressed
                        ? t.accent.primary.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.10),
                    blurRadius: _pressed ? 24 : 12,
                    offset: Offset(0, _pressed ? 8 : 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 62,
                    decoration: BoxDecoration(
                      color: meta['bg'] as Color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.cardBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: (meta['color'] as Color).withValues(alpha: 0.12),
                          blurRadius: 9,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        meta['icon'] as String,
                        style: TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill['store'] as String,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                bill['date'] as String,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: t.mutedText,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: meta['bg'] as Color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _translateCategory(context, bill['category'] as String).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.96,
                                  color: meta['color'] as Color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          bill['note'] as String,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            color: t.mutedText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 10),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${_fmtAmount(bill['amount'] as double)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _translatePayment(context, bill['payment'] as String),
                        style: TextStyle(
                          fontSize: 9,
                          color: t.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Color(0x26FF6B7A),
                            border: Border.all(
                              color: Color(0x4DFF6B7A),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 11,
                            color: kRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            }),
          ),
        ),
      ),
    );
  }

  String _fmtAmount(double v) {
    if (v >= 1000) {
      final s = v.toStringAsFixed(0);
      final parts = <String>[];
      var rem = s;
      while (rem.length > 3) {
        parts.insert(0, rem.substring(rem.length - 3));
        rem = rem.substring(0, rem.length - 3);
      }
      parts.insert(0, rem);
      return parts.join(',');
    }
    return v.toStringAsFixed(0);
  }
}

// ════════════════════════════════════════════════════════════════════
//  DETAIL SHEET
// ════════════════════════════════════════════════════════════════════
class _DetailSheet extends StatelessWidget {
  final Map<String, dynamic> bill;
  final Map<String, dynamic> meta;
  final void Function(String id) onDelete;

  const _DetailSheet({
    required this.bill,
    required this.meta,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        border: Border(top: BorderSide(color: kBorder, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2E6B91FF),
            blurRadius: 60,
            offset: Offset(0, -20),
          ),
        ],
      ),
      constraints: BoxConstraints(maxHeight: 700),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(22, 16, 22, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: kPanel2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 68,
                  height: 80,
                  decoration: BoxDecoration(
                    color: meta['bg'] as Color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0x4DC4A0C8), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x247850B4),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      meta['icon'] as String,
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill['store'] as String,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: kText,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        bill['date'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: kMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${_fmtAmount(bill['amount'] as double)}',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: kText,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Color(0x1F8D7DFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0x388D7DFF), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✦', style: TextStyle(fontSize: 8, color: kAccent2)),
                  SizedBox(width: 4),
                  Text(
                    AppLocalizations.t(context, 'bills_ai_scanned'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: kAccent2,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 18, bottom: 10),
              child: Text(
                AppLocalizations.t(context, 'bills_detail_title'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.4,
                  color: kMuted,
                ),
              ),
            ),
            _detailRow(AppLocalizations.t(context, 'bills_detail_category'), _translateCategory(context, bill['category'] as String).toUpperCase()),
            _detailRow(AppLocalizations.t(context, 'bills_detail_payment'), _translatePayment(context, bill['payment'] as String)),
            _detailRow(AppLocalizations.t(context, 'bills_detail_amount'), '₹${_fmtAmount(bill['amount'] as double)}'),
            _detailRow(AppLocalizations.t(context, 'bills_detail_date'), bill['date'] as String),
            if ((bill['items'] as String).isNotEmpty) ...[
              _detailRow(AppLocalizations.t(context, 'bills_detail_items'), bill['items'] as String),
            ],
            if ((bill['note'] as String).isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.only(top: 18, bottom: 10),
                child: Text(
                  AppLocalizations.t(context, 'bills_detail_notes'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.4,
                    color: kMuted,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x148D7DFF), Color(0x0DFF8EC7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Color(0x238D7DFF), width: 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  bill['note'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: kText,
                    height: 1.6,
                  ),
                ),
              ),
            ],
            SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _detailBtn(context, AppLocalizations.t(context, 'bills_detail_share'), false)),
                SizedBox(width: 9),
                Expanded(
                  child: _detailBtn(
                    context,
                    AppLocalizations.t(context, 'bills_detail_delete'),
                    true,
                    onTap: () => onDelete(bill['id'] as String),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String key, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 7),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: kPanel,
        border: Border.all(color: kBorder, width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            key,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailBtn(
    BuildContext ctx,
    String label,
    bool isPrimary, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.pop(ctx),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  colors: [Color(0xCCFF6B7A), Color(0xCCFF8EC7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary ? null : kPanel,
          border: Border.all(color: kBorder, width: 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: Color(0x47FF6B7A),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Colors.white : kText,
            ),
          ),
        ),
      ),
    );
  }

  String _fmtAmount(double v) {
    if (v >= 1000) {
      final s = v.toStringAsFixed(0);
      final parts = <String>[];
      var rem = s;
      while (rem.length > 3) {
        parts.insert(0, rem.substring(rem.length - 3));
        rem = rem.substring(0, rem.length - 3);
      }
      parts.insert(0, rem);
      return parts.join(',');
    }
    return v.toStringAsFixed(0);
  }
}

// ════════════════════════════════════════════════════════════════════
//  MESH BACKGROUND
// ════════════════════════════════════════════════════════════════════
class _MeshBackground extends StatelessWidget {
  final Color base;
  final Color glowA;
  final Color glowB;
  const _MeshBackground({
    required this.base,
    required this.glowA,
    required this.glowB,
  });
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _MeshPainter(base: base, glowA: glowA, glowB: glowB),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  final Color base;
  final Color glowA;
  final Color glowB;
  _MeshPainter({required this.base, required this.glowA, required this.glowB});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = base,
    );
    final paint1 = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.6, -0.8),
        radius: 1.0,
        colors: [glowA, Colors.transparent],
        stops: [0.0, 0.6],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.6, 0.6),
        radius: 0.9,
        colors: [glowB, Colors.transparent],
        stops: [0.0, 0.55],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ════════════════════════════════════════════════════════════════════
//  PRESS SCALE BUTTON
// ════════════════════════════════════════════════════════════════════
class _PressScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressScaleButton({required this.child, required this.onTap});

  @override
  State<_PressScaleButton> createState() => _PressScaleButtonState();
}

class _PressScaleButtonState extends State<_PressScaleButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PERFORATED DIVIDER
// ════════════════════════════════════════════════════════════════════
class _PerforationPainter extends CustomPainter {
  final Color notchColor;
  const _PerforationPainter({required this.notchColor});

  @override
  void paint(Canvas canvas, Size size) {
    final notchPaint = Paint()
      ..color = notchColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, 0), 8, notchPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height), 8, notchPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 8, notchPaint);

    final dashPaint = Paint()
      ..color = kBorder
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final dashH = 5.0;
    final dashGap = 5.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, min(y + dashH, size.height)),
        dashPaint,
      );
      y += dashH + dashGap;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
// ─────────────────────────────────────────────────────────────────────────────
//  Bills Chat Plus Button — Ahvi-style bottom sheet (same as ahvi_stylist_chat)
// ─────────────────────────────────────────────────────────────────────────────
class _BillsPlusButton extends StatefulWidget {
  final Color panel, cardBorder, accent, accentSecondary, text, background;
  final VoidCallback? onCameraSelected;
  final VoidCallback? onMenuOpen;
  final VoidCallback? onMenuClose;

  const _BillsPlusButton({
    required this.panel,
    required this.cardBorder,
    required this.accent,
    required this.accentSecondary,
    required this.text,
    required this.background,
    this.onCameraSelected,
    this.onMenuOpen,
    this.onMenuClose,
  });

  @override
  State<_BillsPlusButton> createState() => _BillsPlusButtonState();
}

class _BillsPlusButtonState extends State<_BillsPlusButton> {
  bool _menuOpen = false;

  void _openSheet() {
    setState(() => _menuOpen = true);
    widget.onMenuOpen?.call();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: widget.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: widget.cardBorder),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: widget.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Menu rows
                Container(
                  decoration: BoxDecoration(
                    color: widget.panel,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: widget.cardBorder),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BillsMenuRow(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        subtitle: 'Take a photo',
                        accent: widget.accent,
                        accentSecondary: widget.accentSecondary,
                        cardBorder: widget.cardBorder,
                        textPrimary: widget.text,
                        isFirst: true,
                        isLast: false,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          widget.onCameraSelected?.call();
                        },
                      ),
                      _BillsMenuRow(
                        icon: Icons.photo_library_rounded,
                        label: 'Photo Library',
                        subtitle: 'Choose from gallery',
                        accent: widget.accent,
                        accentSecondary: widget.accentSecondary,
                        cardBorder: widget.cardBorder,
                        textPrimary: widget.text,
                        isFirst: false,
                        isLast: false,
                        onTap: () => Navigator.of(ctx).pop(),
                      ),
                      _BillsMenuRow(
                        icon: Icons.insert_drive_file_rounded,
                        label: 'Files',
                        subtitle: 'Upload a document',
                        accent: widget.accent,
                        accentSecondary: widget.accentSecondary,
                        cardBorder: widget.cardBorder,
                        textPrimary: widget.text,
                        isFirst: false,
                        isLast: false,
                        onTap: () => Navigator.of(ctx).pop(),
                      ),
                      _BillsMenuRow(
                        icon: Icons.travel_explore_rounded,
                        label: 'Browse',
                        subtitle: 'Search the web',
                        accent: widget.accent,
                        accentSecondary: widget.accentSecondary,
                        cardBorder: widget.cardBorder,
                        textPrimary: widget.text,
                        isFirst: false,
                        isLast: true,
                        onTap: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _menuOpen = false);
      widget.onMenuClose?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openSheet,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _menuOpen
              ? widget.accent.withValues(alpha: 0.15)
              : widget.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _menuOpen
                ? widget.accent.withValues(alpha: 0.5)
                : widget.cardBorder,
            width: 1.5,
          ),
        ),
        child: Icon(
          _menuOpen ? Icons.close_rounded : Icons.add_rounded,
          color: widget.accent,
          size: 18,
        ),
      ),
    );
  }
}

// ── Ahvi-style menu row for Bills plus sheet ──────────────────────────────────
class _BillsMenuRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent, accentSecondary, cardBorder, textPrimary;
  final bool isFirst, isLast;
  final VoidCallback onTap;

  const _BillsMenuRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.accentSecondary,
    required this.cardBorder,
    required this.textPrimary,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_BillsMenuRow> createState() => _BillsMenuRowState();
}

class _BillsMenuRowState extends State<_BillsMenuRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.accent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.vertical(
            top: widget.isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: widget.isLast ? const Radius.circular(20) : Radius.zero,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.accent.withValues(alpha: 0.18),
                          widget.accentSecondary.withValues(alpha: 0.18),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Icon(widget.icon, color: widget.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.textPrimary.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.isLast)
              Divider(
                height: 1,
                thickness: 1,
                color: widget.cardBorder,
                indent: 74,
                endIndent: 0,
              ),
          ],
        ),
      ),
    );
  }
}