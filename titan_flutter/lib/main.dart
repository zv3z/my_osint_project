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
    systemNavigationBarColor: Color(0xFF080B14),
  ));
  runApp(
    ChangeNotifierProvider(create: (_) => AppState(), child: const TitanApp()),
  );
}

// ── App State ──────────────────────────────────────────────────────────────
class AppState extends ChangeNotifier {
  String _lang = 'ar';
  String get lang => _lang;
  bool get isAr  => _lang == 'ar';

  String  _apiBase = 'http://localhost:8000';
  String  get apiBase => _apiBase;

  void setLang(String l) { _lang = l; notifyListeners(); }
  void setApiBase(String url) {
    _apiBase = url;
    ApiService.baseUrl = url;
    notifyListeners();
  }
}

// ── Theme ──────────────────────────────────────────────────────────────────
class TitanTheme {
  static const bgPrimary    = Color(0xFF080B14);
  static const bgSecondary  = Color(0xFF0D1121);
  static const bgCard       = Color(0x0AFFFFFF);
  static const borderColor  = Color(0x14FFFFFF);

  static const indigo       = Color(0xFF6366F1);
  static const indigoLight  = Color(0xFF818CF8);
  static const cyan         = Color(0xFF22D3EE);
  static const green        = Color(0xFF10B981);
  static const amber        = Color(0xFFF59E0B);
  static const red          = Color(0xFFEF4444);
  static const orange       = Color(0xFFF97316);

  static const textPrimary   = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted     = Color(0xFF475569);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgPrimary,
    colorScheme: ColorScheme.dark(
      primary:   indigo,
      secondary: cyan,
      surface:   bgSecondary,
      error:     red,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
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
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: bgSecondary,
      selectedItemColor: indigoLight,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15),
        elevation: 0,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0x1A6366F1),
      labelStyle: GoogleFonts.inter(color: indigoLight, fontSize: 12),
      side: const BorderSide(color: Color(0x406366F1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    dividerTheme: const DividerThemeData(color: borderColor, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: bgSecondary,
      contentTextStyle: GoogleFonts.inter(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// ── Bottom Navigation ──────────────────────────────────────────────────────
class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),
    HistoryScreen(),
    MonitorScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.radar_outlined),
              activeIcon: Icon(Icons.radar),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_border_outlined),
              activeIcon: Icon(Icons.bookmark),
              label: 'Monitor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
