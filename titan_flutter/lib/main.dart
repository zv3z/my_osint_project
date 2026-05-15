import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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

  String _apiBase = 'http://localhost:8000';
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
  static const bgPrimary = Color(0xFF05070F);
  static const bgSecondary = Color(0xFF090C18);
  static const bgCard = Color(0x08FFFFFF);
  static const bgCardHover = Color(0x12FFFFFF);
  static const borderColor = Color(0x12FFFFFF);
  static const borderGlow = Color(0x30FFFFFF);

  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const violet = Color(0xFF8B5CF6);
  static const violetLight = Color(0xFFA78BFA);
  static const cyan = Color(0xFF22D3EE);
  static const cyanDark = Color(0xFF0E9BB5);
  static const green = Color(0xFF10B981);
  static const greenDark = Color(0xFF059669);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF97316);

  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);

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
    colors: [green, Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgPrimary,
        colorScheme: const ColorScheme.dark(
          primary: indigo,
          secondary: cyan,
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
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: borderColor),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgCard,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: indigo, width: 1.5),
          ),
          hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: indigo,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700, fontSize: 15),
            elevation: 0,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0x1A6366F1),
          labelStyle: GoogleFonts.inter(color: indigoLight, fontSize: 12),
          side: const BorderSide(color: Color(0x406366F1)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        dividerTheme: const DividerThemeData(color: borderColor, thickness: 1),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: bgSecondary,
          contentTextStyle: GoogleFonts.inter(color: textPrimary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// ── Floating Pill Navigation ───────────────────────────────────────────────
class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation>
    with TickerProviderStateMixin {
  int _index = 0;
  int _prevIndex = 0;

  late AnimationController _slideCtrl;
  late AnimationController _indicatorCtrl;
  late Animation<double> _indicatorAnim;

  static const _navItems = [
    _NavItem(Icons.radar_outlined, Icons.radar, 'Scan'),
    _NavItem(Icons.history_outlined, Icons.history, 'History'),
    _NavItem(Icons.visibility_outlined, Icons.visibility, 'Monitor'),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  final _pages = const [
    HomeScreen(),
    HistoryScreen(),
    MonitorScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _indicatorAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _indicatorCtrl.dispose();
    super.dispose();
  }

  void _onTap(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();

    final double from = _index.toDouble();
    final double to = i.toDouble();

    setState(() {
      _prevIndex = _index;
      _index = i;
    });

    _indicatorAnim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeInOutCubic),
    );
    _indicatorCtrl.forward(from: 0);
    _slideCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TitanTheme.bgPrimary,
      extendBody: true,
      body: AnimatedBuilder(
        animation: _slideCtrl,
        builder: (context, child) {
          return IndexedStack(index: _index, children: _pages);
        },
      ),
      bottomNavigationBar: _buildFloatingNav(),
    );
  }

  Widget _buildFloatingNav() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1025).withOpacity(0.85),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / _navItems.length;
                  return Stack(
                    children: [
                      // Sliding indicator
                      AnimatedBuilder(
                        animation: _indicatorAnim,
                        builder: (context, _) {
                          return Positioned(
                            left: _indicatorAnim.value * itemWidth + 6,
                            top: 6,
                            bottom: 6,
                            width: itemWidth - 12,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF8B5CF6),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        const Color(0xFF6366F1).withOpacity(0.5),
                                    blurRadius: 16,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Nav items
                      Row(
                        children: List.generate(_navItems.length, (i) {
                          return _NavPillItem(
                            item: _navItems[i],
                            isSelected: _index == i,
                            onTap: () => _onTap(i),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav Item Data ──────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}

// ── Nav Pill Item Widget ───────────────────────────────────────────────────
class _NavPillItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavPillItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  key: ValueKey(isSelected),
                  size: 20,
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF475569),
                  letterSpacing: 0.05,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
