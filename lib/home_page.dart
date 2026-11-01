import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backdrop.dart';
import 'parser.dart';
import 'reader_page.dart';
import 'settings_page.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  String _savedText = '';
  int _savedIndex = 0;

  @override
  void initState() {
    super.initState();
    _load(withText: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool withText = false}) async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _savedText = p.getString('text') ?? '';
      _savedIndex = p.getInt('index') ?? 0;
      if (withText) _controller.text = _savedText;
    });
  }

  Future<void> _start({required bool resume}) async {
    final text = _controller.text;
    final parsed = parseText(text);
    if (parsed.words.isEmpty) return;
    final start = resume && text == _savedText ? _savedIndex : 0;
    final p = await SharedPreferences.getInstance();
    await p.setString('text', text);
    await p.setInt('index', start);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(
          words: parsed.words,
          starts: parsed.starts,
          startIndex: start,
        ),
      ),
    );
    _load();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canResume = _savedIndex > 0 && _controller.text == _savedText;
    const label = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
    final filledStyle = FilledButton.styleFrom(
      backgroundColor: Ui.ink,
      foregroundColor: Ui.yellow,
      minimumSize: const Size.fromHeight(58),
      shape: Ui.shape,
      textStyle: label,
    );
    final outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: Ui.ink,
      minimumSize: const Size.fromHeight(58),
      shape: Ui.shape,
      side: const BorderSide(color: Ui.ink, width: 2.5),
      textStyle: label,
    );

    return Theme(
      data: Ui.yellowTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: Ui.yellowOverlay,
        child: Stack(
          children: [
            const Positioned.fill(child: AppBackdrop()),
            Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'RSReader',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: Ui.ink,
                            ),
                          ),
                          Glass(
                            radius: 24,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton(
                                tooltip: 'Impostazioni',
                                onPressed: _openSettings,
                                icon: const Icon(Icons.tune, color: Ui.ink),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: const BoxDecoration(
                            color: Ui.ink,
                            borderRadius: Ui.corners,
                          ),
                          child: TextField(
                            controller: _controller,
                            onChanged: (_) => setState(() {}),
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              height: 1.5,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Incolla qui il testo da leggere',
                              hintStyle: TextStyle(
                                color: Ui.muted,
                                fontSize: 18,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (canResume) ...[
                        FilledButton(
                          style: filledStyle,
                          onPressed: () => _start(resume: true),
                          child: Text('Continua da parola ${_savedIndex + 1}'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      canResume
                          ? OutlinedButton(
                              style: outlinedStyle,
                              onPressed: () => _start(resume: false),
                              child: const Text("Leggi dall'inizio"),
                            )
                          : FilledButton(
                              style: filledStyle,
                              onPressed: () => _start(resume: false),
                              child: const Text("Leggi dall'inizio"),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}