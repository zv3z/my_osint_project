import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _keyCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(
      text: context.read<AppState>().apiBase,
    );
    _keyCtrl = TextEditingController(text: ApiService.apiKey);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App header
          Center(
            child: Column(
              children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [TitanTheme.indigo, TitanTheme.cyan]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: TitanTheme.indigo.withAlpha(102),
                          blurRadius: 24),
                    ],
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 12),
                Text('TITAN OSINT',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: TitanTheme.textPrimary)),
                const Text('Version 3.1.0',
                    style: TextStyle(fontSize: 13, color: TitanTheme.textMuted)),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Language
          _SectionHeader(title: 'LANGUAGE'),
          GlassCard(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _LangButton(
                  label: '🇸🇦  العربية',
                  selected: state.isAr,
                  onTap: () => state.setLang('ar'),
                ),
                _LangButton(
                  label: '🇺🇸  English',
                  selected: !state.isAr,
                  onTap: () => state.setLang('en'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // API Server
          _SectionHeader(title: 'API SERVER'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Backend URL',
                    style: TextStyle(
                        fontSize: 13, color: TitanTheme.textSecondary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                const Text(
                    'Point this to your Titan OSINT API server '
                    '(run: uvicorn api:app)',
                    style: TextStyle(fontSize: 11, color: TitanTheme.textMuted)),
                const SizedBox(height: 10),
                TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13,
                      color: TitanTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'http://192.168.1.x:8000',
                    prefixIcon: Icon(Icons.link_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    state.setApiBase(_urlCtrl.text.trim());
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ API URL saved!')));
                  },
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // API Key
          _SectionHeader(title: 'API KEY'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('API Key (optional)',
                    style: TextStyle(
                        fontSize: 13, color: TitanTheme.textSecondary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                const Text(
                    'Set TITAN_API_KEY on the server to enable',
                    style: TextStyle(fontSize: 11, color: TitanTheme.textMuted)),
                const SizedBox(height: 10),
                TextField(
                  controller: _keyCtrl,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13,
                      color: TitanTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'your-api-key',
                    prefixIcon: Icon(Icons.key_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    ApiService.apiKey = _keyCtrl.text.trim();
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ API Key saved!')));
                  },
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // How to run
          _SectionHeader(title: 'SETUP GUIDE'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Step(n: '1', text: 'Install Python backend dependencies',
                    cmd: 'pip install -r requirements.txt'),
                _Step(n: '2', text: 'Start the API server',
                    cmd: 'uvicorn api:app --host 0.0.0.0 --port 8000'),
                _Step(n: '3', text: 'Set the server IP above (use your local IP)'),
                _Step(n: '4', text: 'Tap Scan and enter a target!'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // About
          _SectionHeader(title: 'ABOUT'),
          GlassCard(
            child: Column(
              children: [
                _InfoRow(label: 'App',     value: 'Titan OSINT'),
                _InfoRow(label: 'Version', value: '3.2.0'),
                _InfoRow(label: 'Engines', value: '50+ threat intelligence APIs'),
                _InfoRow(label: 'AI',      value: 'Gemini 2.5 Flash + GPT-4o'),
                _InfoRow(label: 'Platform', value: 'iOS & Android'),
              ],
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: GoogleFonts.spaceGrotesk(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: TitanTheme.textMuted, letterSpacing: 0.12)),
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? TitanTheme.indigo.withAlpha(51) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? TitanTheme.indigo.withAlpha(127)
                  : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: selected
                        ? TitanTheme.indigoLight
                        : TitanTheme.textMuted)),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  final String? cmd;

  const _Step({required this.n, required this.text, this.cmd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: TitanTheme.indigo.withAlpha(38),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TitanTheme.indigo.withAlpha(102)),
            ),
            child: Center(
              child: Text(n,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: TitanTheme.indigoLight)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: const TextStyle(
                        fontSize: 13, color: TitanTheme.textPrimary)),
                if (cmd != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => Clipboard.setData(ClipboardData(text: cmd!)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(76),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(cmd!,
                          style: const TextStyle(
                              fontSize: 11, color: TitanTheme.cyan,
                              fontFamily: 'monospace')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: TitanTheme.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: TitanTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}
