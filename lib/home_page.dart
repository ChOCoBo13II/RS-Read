import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parser.dart';
import 'reader_page.dart';

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

  @override
  Widget build(BuildContext context) {
    final canResume = _savedIndex > 0 && _controller.text == _savedText;
    return Scaffold(
      appBar: AppBar(title: const Text('RSReader')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: (_) => setState(() {}),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Incolla qui il testo da leggere',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (canResume) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _start(resume: true),
                  child: Text('Continua da parola ${_savedIndex + 1}'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: canResume
                  ? OutlinedButton(
                      onPressed: () => _start(resume: false),
                      child: const Text("Leggi dall'inizio"),
                    )
                  : FilledButton(
                      onPressed: () => _start(resume: false),
                      child: const Text("Leggi dall'inizio"),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}