import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'firebase_tab.dart';
import 'supabase_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Подключение к Supabase.
  await Supabase.initialize(
    url: 'https://cgqhvdqaveelzszcfgtj.supabase.co',
    publishableKey: 'sb_publishable_vTBGqP1LexerCIaWXZq2ng_3TolOPT6',
  );

  // Подключение к Firebase. Если оно не удалось, приложение всё равно
  // запустится, а вкладка Firebase покажет подсказку.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase не запустился: $e');
  }

  runApp(MyApp(firebaseReady: firebaseReady));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: HomeShell(firebaseReady: firebaseReady),
    );
  }
}

/// Каркас приложения: заголовок и нижнее меню из двух вкладок.
/// Вкладки независимы: у каждой своя авторизация и своя база данных.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.people),
        title: Text(
          _index == 0 ? 'Пользователи Supabase' : 'Пользователи Firebase',
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      // IndexedStack держит обе вкладки живыми:
      // вход не сбрасывается при переключении между ними.
      body: IndexedStack(
        index: _index,
        children: [
          const SupabaseTab(),
          FirebaseTab(ready: widget.firebaseReady),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storage), label: 'Supabase'),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department),
            label: 'Firebase',
          ),
        ],
      ),
    );
  }
}
