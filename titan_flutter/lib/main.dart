import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/monitor_screen.dart';
import 'screens/settings_screen.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF05070F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(
    ChangeNotifierProvider(create: (_) => AppState(), child: const TitanApp()),
  );
}

// ── App State ──────────────────────────────────────────────────────────────
class AppState extends ChangeNotifier {
  String _lang = 'ar';
  String get lang => _lang;
  bool get isAr => _lang == 'ar';

  String _apiBase = 'https://web-production-7631ff.up.railway.app';
  String get apiBase => _apiBase;

  void setLang(String l) {
    _lang = l;
    notifyListeners();
  }

  void setApiBase(String url) {
    _apiBase = url;
    ApiService.baseUrl = url;
    notifyListeners();
  }
}

// ── Theme ──────────────────────────────────────────────────────────────────
class TitanTheme {
  // Backgrounds — ultra dark
  static const bgPrimary   = Color(0xFF05070F);
  static const bgSecondary = Color(0xFF080B18);
  static const bgCard      = Color(0x0AFFFFFF);
  static const bgCardHover = Color(0x14FFFFFF);
  static const borderColor = Color(0x12FFFFFF);
  static const borderGlow  = Color(0x30FFFFFF);

  // Brand
  static const indigo      = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const violet      = Color(0xFF8B5CF6);
  static const violetLight = Color(0xFFA78BFA);
  static const cyan        = Color(0xFF22D3EE);
  static const cyanDark    = Color(0xFF0E9BB5);
  static const green       = Color(0xFF10B981);
  static const greenDark   = Color(0xFF059669);
  static const amber       = Color(0xFFF59E0B);
  static const red         = Color(0xFFEF4444);
  static const orange      = Color(0xFFF97316);
  static const pink        = Color(0xFFEC4899);

  // Text
  static const textPrimary   = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted     = Color(0xFF475569);

  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [indigo, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cyanGradient = LinearGradient(
    colors: [cyan, Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const emeraldGradient = LinearGradient(
    colors: [green, Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const deepGradient = LinearGradient(
    colors: [Color(0xFF0D1025), Color(0xFF05070F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgPrimary,
        colorScheme: const ColorScheme.dark(
          primary: indigo,
          secondary: cyan,
          tertiary: violet,
          surface: bgSecondary,
          error: red,
        ),
        textTheme:
            GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          displayLarge: GoogleFonts.spaceGrotesk(
              color: textPrimary, fontWeight: FontWeight.w800),
          headlineMedium: GoogleFonts.spaceGrotesk(
              color: textPrimary, fontWeight: FontWeight.w700),
          titleMedium: GoogleFonts.inter(
              color: textPrimary, fontWeight: FontWeight.w600),
          bodyMedium: GoogleFonts.inter(color: textSecondary),
          labelSmall: GoogleFonts.inter(
              color: textMuted, letterSpacing: 0.08, fontSize: 11),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bgPrimary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.spaceGrotesk(
              color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          iconTheme: const IconThemeData(color: textSecondary),
        ),
        cardTheme: CardThemeData(
          color: bgCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: borderColor),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0x08FFFFFF),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: indigo, width: 1.5),
          ),
          hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: indigo,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            textStyle: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700, fontSize: 15),
            elevation: 0,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0x1A6366F1),
          labelStyle:
              GoogleFonts.inter(color: indigoLight, fontSize: 12),
          side: const BorderSide(color: Color(0x406366F1)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        dividerTheme: const DividerThemeData(color: borderColor, thickness: 1),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: bgSecondary,
          contentTextStyle: GoogleFonts.inter(color: textPrimary),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          behavior: SnackBarBehavior.floating,
        ),
      );
}

// ── Root App ───────────────────────────────────────────────────────────────
class TitanApp extends StatelessWidget {
  const TitanApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Titan OSINT',
        theme: TitanTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const RootNavigation(),
      );
}

// ── Nav Item Data ──────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}

// ── Root Navigation ────────────────────────────────────────────────────────
class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation>
    with TickerProviderStateMixin {
  int _index = 0;

  late AnimationController _pageCtrl;
  late AnimationController _indicatorCtrl;
  late Animation<double> _indicatorAnim;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;

  static const _navItems = [
    _NavItem(Icons.radar_outlined,       Icons.radar,       'Scan'),
    _NavItem(Icons.dashboard_outlined,   Icons.dashboard,   'Dashboard'),
    _NavItem(Icons.history_outlined,     Icons.history,     'History'),
    _NavItem(Icons.visibility_outlined,  Icons.visibility,  'Monitor'),
    _NavItem(Icons.settings_outlined,    Icons.settings,    'Settings'),
  ];

  final _pages = const [
    HomeScreen(),
    DashboardScreen(),
    HistoryScreen(),
    MonitorScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();

    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _indicatorAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeInOutCubic),
    );

    _pageFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pageCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic),
    );

    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _indicatorCtrl.dispose();
    super.dispose();
  }

  void _onTap(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();

    final double from = _index.toDouble();
    final double to   = i.toDouble();

    setState(() => _index = i);

    _indicatorAnim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeInOutCubic),
    );
    _indicatorCtrl.forward(from: 0);

    _pageCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TitanTheme.bgPrimary,
      extendBody: true,
      body: AnimatedBuilder(
        animation: _pageCtrl,
        builder: (context, _) {
          return FadeTransition(
            opacity: _pageFade,
            child: SlideTransition(
              position: _pageSlide,
              child: IndexedStack(index: _index, children: _pages),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildFloatingNav(),
    );
  }

  Widget _buildFloatingNav() {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 8,
      ),
      child: _FloatingPillNav(
        items: _navItems,
        selectedIndex: _index,
        indicatorAnimation: _indicatorAnim,
        onTap: _onTap,
      ),
    );
  }
}

// ── Floating Pill Nav ──────────────────────────────────────────────────────
class _FloatingPillNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final Animation<double> indicatorAnimation;
  final ValueChanged<int> onTap;

  const _FloatingPillNav({
    required this.items,
    required this.selectedIndex,
    required this.indicatorAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(52),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFF0C0F1E).withOpacity(0.88),
            borderRadius: BorderRadius.circular(52),
            border: Border.all(
              color: const Color(0xFF6366F1).withOpacity(0.28),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.18),
                blurRadius: 40,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  // Sliding indicator pill
                  AnimatedBuilder(
                    animation: indicatorAnimation,
                    builder: (context, _) {
                      return Positioned(
                        left: indicatorAnimation.value * itemWidth + 6,
                        top: 6,
                        bottom: 6,
                        width: itemWidth - 12,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(42),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.55),
                                blurRadius: 18,
                                spreadRadius: -2,
                              ),
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withOpacity(0.25),
                                blurRadius: 32,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Nav items row
                  Row(
                    children: List.generate(items.length, (i) {
                      return _NavPillItem(
                        item: items[i],
                        isSelected: selectedIndex == i,
                        onTap: () => onTap(i),
                        width: itemWidth,
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Nav Pill Item ──────────────────────────────────────────────────────────
class _NavPillItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final double width;

  const _NavPillItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                key: ValueKey('${item.label}_$isSelected'),
                size: 20,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
                letterSpacing: 0.04,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
