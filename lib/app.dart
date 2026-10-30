import 'package:flutter/material.dart';

import 'home_page.dart';

class RsReaderApp extends StatelessWidget {
  const RsReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RSReader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomePage(),
    );
  }
}