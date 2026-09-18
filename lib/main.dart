import 'package:flutter/material.dart';

import 'screens/notes_home_page.dart';

void main() {
  runApp(const StudyVaultApp());
}

class StudyVaultApp extends StatelessWidget {
  const StudyVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff735a7b)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff6f3f7),
        fontFamily: 'Segoe UI',
      ),
      home: const NotesHomePage(),
    );
  }
}
