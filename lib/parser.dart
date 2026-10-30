class ParsedText {
  const ParsedText(this.words, this.starts);

  final List<String> words;
  final List<int> starts;
}

ParsedText parseText(String text) {
  final hasBlank = RegExp(r'\n\s*\n').hasMatch(text);
  final parts = hasBlank ? text.split(RegExp(r'\n\s*\n')) : text.split('\n');
  final words = <String>[];
  final starts = <int>[];
  for (final part in parts) {
    final w = part.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (w.isEmpty) continue;
    starts.add(words.length);
    words.addAll(w);
  }
  return ParsedText(words, starts);
}