import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'social_oauth.dart';
import 'ui_kit.dart';

/// Вкладка Supabase: своя авторизация и своя база данных (таблица Users).
class SupabaseTab extends StatefulWidget {
  const SupabaseTab({super.key});

  @override
  State<SupabaseTab> createState() => _SupabaseTabState();
}

class _SupabaseTabState extends State<SupabaseTab> {
  final _db = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSub;

  /// Вход через Supabase: email и пароль, Google, GitHub.
  Session? _session;

  /// Вход через ВК или Яндекс — Supabase о нём не знает.
  SocialUser? _social;

  List<Map<String, dynamic>> _users = [];

  /// Роль из таблицы profiles: 'user' или 'admin'.
  String _role = 'user';

  /// Этот вход — первый для аккаунта.
  bool _firstVisit = false;

  bool get _signedIn => _session != null || _social != null;

  @override
  void initState() {
    super.initState();

    // Если вход уже был выполнен раньше — например, вернулись со страницы Google.
    _session = _db.auth.currentSession;
    if (_session != null) _afterSignIn(_session!);

    _authSub = _db.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      setState(() => _session = state.session);
      if (state.session != null) {
        _afterSignIn(state.session!);
      } else {
        setState(() {
          _role = 'user';
          _firstVisit = false;
        });
      }
    });
  }

  void _afterSignIn(Session session) {
    setState(() => _firstVisit = _isFirstVisit(session.user));
    _load();
    _loadRole();
  }

  /// Первый ли это вход. Supabase хранит у пользователя две отметки:
  /// когда аккаунт создан и когда он входил в последний раз. Если они
  /// совпадают, значит пользователь только что зарегистрировался.
  bool _isFirstVisit(User user) {
    final created = DateTime.tryParse(user.createdAt);
    final lastSignIn = DateTime.tryParse(user.lastSignInAt ?? '');
    if (created == null || lastSignIn == null) return false;
    return lastSignIn.difference(created).inSeconds.abs() < 5;
  }

  /// Роль лежит в таблице profiles. Её строки создаёт триггер базы данных
  /// при регистрации, а менять роль может только администратор проекта —
  /// у приложения прав на запись в profiles нет.
  Future<void> _loadRole() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _role = 'user');
      return;
    }
    try {
      final rows =
          await _db.from('profiles').select('role').eq('id', userId).limit(1);
      final role = rows.isEmpty ? 'user' : '${rows.first['role'] ?? 'user'}';
      if (mounted) setState(() => _role = role);
    } catch (e) {
      // Таблицы profiles может не быть — тогда считаем роль обычной.
      if (mounted) setState(() => _role = 'user');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // ───────── База данных ─────────

  /// SELECT — прочитать таблицу Users.
  Future<void> _load() async {
    try {
      final rows = await _db.from('Users').select();
      if (mounted) {
        setState(() => _users = List<Map<String, dynamic>>.from(rows));
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Ошибка загрузки: $e');
    }
  }

  /// INSERT — добавить строку по нажатию кнопки.
  Future<void> _add(String username, String password) async {
    await _db.from('Users').insert({'username': username, 'password': password});
    await _load();
  }

  /// DELETE — удалить строку. Разрешено только администратору: это
  /// проверяется и здесь (кнопки просто нет), и в самой базе правилом RLS.
  Future<void> _delete(Map<String, dynamic> row) async {
    await _db.from('Users').delete().eq('id', row['id'] as Object);
    await _load();
  }

  // ───────── Вход и выход ─────────

  Future<void> _signUp(String email, String password) async {
    final result = await _db.auth.signUp(email: email, password: password);
    // Если в настройках Supabase включено подтверждение почты,
    // сессии сразу не будет — нужно перейти по ссылке из письма.
    if (result.session == null && mounted) {
      showMessage(
        context,
        'Аккаунт создан. Подтвердите адрес по ссылке из письма и нажмите «Войти».',
      );
    }
  }

  /// Вход через провайдера Supabase (Google, GitHub).
  /// В браузере пользователь уходит на страницу сервиса и возвращается
  /// на наш же адрес, который разрешён в настройках Supabase.
  Future<void> _oauth(OAuthProvider provider) async {
    await _db.auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb
          ? Uri.base.origin
          : 'io.supabase.myfirstflutterapp://login-callback/',
    );
  }

  /// Вход через ВК или Яндекс: Supabase в нём не участвует,
  /// имя пользователя храним у себя, а список читаем как обычно.
  Future<void> _socialSignIn(Future<SocialUser> Function() flow) async {
    final user = await flow();
    if (!mounted) return;
    setState(() => _social = user);
    await _load();
  }

  Future<void> _signOut() async {
    if (_social != null) {
      setState(() => _social = null);
    } else {
      await _db.auth.signOut();
    }
    if (mounted) setState(() => _users = []);
  }

  /// Имя, которое показываем после входа.
  String get _name {
    if (_social != null) return '${_social!.name} · ${_social!.provider}';

    final user = _session!.user;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final name = meta['full_name'] ?? meta['user_name'] ?? meta['name'];
    return '${name ?? user.email ?? 'Вы вошли'}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_signedIn) {
      return LoginScreen(
        title: 'Вход через Supabase',
        onSignIn: (email, password) =>
            _db.auth.signInWithPassword(email: email, password: password),
        onSignUp: _signUp,
        social: [
          SocialButton(
            label: 'Войти через Google',
            icon: Icons.g_mobiledata,
            color: Colors.red,
            onTap: () => _oauth(OAuthProvider.google),
          ),
          SocialButton(
            label: 'Войти через GitHub',
            icon: Icons.code,
            color: Colors.black87,
            onTap: () => _oauth(OAuthProvider.github),
          ),
          SocialButton(
            label: 'Войти через Яндекс',
            icon: Icons.alternate_email,
            color: Colors.red,
            onTap: () => _socialSignIn(SocialAuth.signInWithYandex),
          ),
          SocialButton(
            label: 'Войти через ВКонтакте',
            icon: Icons.people,
            color: Colors.blue,
            onTap: () => _socialSignIn(SocialAuth.signInWithVk),
          ),
        ],
      );
    }

    return HomeScreen(
      name: _name,
      role: _role,
      firstVisit: _firstVisit,
      onSignOut: _signOut,
      onAdd: _add,
      onRefresh: _load,
      list: UsersTable(
        users: _users,
        onDelete: _role == 'admin' ? _delete : null,
      ),
    );
  }
}
