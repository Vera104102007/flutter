import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'social_oauth.dart';
import 'ui_kit.dart';

/// Вкладка Firebase: своя авторизация и своя база данных
/// (ветка Users в Realtime Database, которая обновляется сама).
class FirebaseTab extends StatefulWidget {
  const FirebaseTab({super.key, required this.ready});

  final bool ready;

  @override
  State<FirebaseTab> createState() => _FirebaseTabState();
}

class _FirebaseTabState extends State<FirebaseTab> {
  /// Вход через ВК или Яндекс — Firebase о нём не знает.
  SocialUser? _social;

  /// Роль из ветки profiles: 'user' или 'admin'.
  String _role = 'user';

  /// Этот вход — первый для аккаунта.
  bool _firstVisit = false;

  StreamSubscription<User?>? _roleSub;

  @override
  void initState() {
    super.initState();
    if (!widget.ready) return;

    // Заранее открываем соединение с базой, пока человек только вводит
    // логин. Firebase держит связь по веб-сокету с сервером в США, и его
    // установка занимает несколько секунд. Узел .info/connected читается
    // без входа, поэтому годится, чтобы «разогреть» соединение заранее —
    // иначе эти секунды пришлось бы ждать уже после входа, глядя
    // на крутящийся индикатор вместо таблицы.
    FirebaseDatabase.instance.ref('.info/connected').once().ignore();

    _roleSub = _auth.authStateChanges().listen((user) {
      if (user == null) {
        if (mounted) {
          setState(() {
            _role = 'user';
            _firstVisit = false;
          });
        }
      } else {
        _loadProfile(user);
      }
    });
  }

  @override
  void dispose() {
    _roleSub?.cancel();
    super.dispose();
  }

  /// Читает профиль пользователя, а при первом входе создаёт его.
  ///
  /// Первый ли это вход, Firebase сообщает сам: у пользователя есть
  /// отметки о создании аккаунта и о последнем входе. Если они совпадают,
  /// пользователь только что зарегистрировался.
  Future<void> _loadProfile(User user) async {
    final created = user.metadata.creationTime;
    final lastSignIn = user.metadata.lastSignInTime;
    final first = created != null &&
        lastSignIn != null &&
        lastSignIn.difference(created).inSeconds.abs() < 5;

    var role = 'user';
    try {
      final ref = FirebaseDatabase.instance.ref('profiles/${user.uid}');
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        // Первый вход — заводим профиль. Роль здесь всегда обычная:
        // правила базы не дают приложению записать сюда 'admin',
        // эту роль выдаёт владелец проекта вручную в консоли.
        await ref.set({
          'email': user.email,
          'role': 'user',
          'createdAt': ServerValue.timestamp,
        });
      } else {
        final value = snapshot.value;
        if (value is Map) role = '${value['role'] ?? 'user'}';
      }
    } catch (e) {
      debugPrint('Не удалось прочитать профиль: $e');
    }

    if (mounted) {
      setState(() {
        _role = role;
        _firstVisit = first;
      });
    }
  }

  // Потоки создаём один раз и только когда Firebase уже подключился.
  Stream<User?>? _authStream;
  Stream<DatabaseEvent>? _usersStream;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  DatabaseReference get _ref => FirebaseDatabase.instance.ref('Users');

  Stream<User?> get _authChanges => _authStream ??= _auth.authStateChanges();

  /// onValue срабатывает при загрузке и при любом изменении данных.
  Stream<DatabaseEvent> get _usersChanges => _usersStream ??= _ref.onValue;

  /// INSERT — push() создаёт запись с уникальным ключом.
  Future<void> _add(String username, String password) =>
      _ref.push().set({'username': username, 'password': password});

  /// DELETE — удалить запись по её ключу. Разрешено только администратору:
  /// это проверяется и здесь (кнопки просто нет), и в правилах базы.
  Future<void> _delete(Map<String, dynamic> row) =>
      _ref.child('${row['key']}').remove();

  /// Вход через провайдера Firebase (Google, GitHub).
  Future<void> _oauth(AuthProvider provider) => _friendly(() async {
        if (kIsWeb) {
          await _auth.signInWithPopup(provider);
        } else {
          await _auth.signInWithProvider(provider);
        }
      });

  /// Переводит ошибки Firebase на человеческий язык.
  /// Без этого на экран попадает английский текст на несколько строк.
  Future<T> _friendly<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthMessage(_errorText(e));
    }
  }

  String _errorText(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Некорректный email';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Неверный email или пароль';
      case 'email-already-in-use':
        return 'Такой пользователь уже зарегистрирован';
      case 'weak-password':
        return 'Слишком простой пароль, нужно минимум 6 символов';
      case 'operation-not-allowed':
        return 'Этот способ входа не включён в настройках Firebase';
      case 'network-request-failed':
        return 'Нет соединения с интернетом';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Окно входа закрыто';
      case 'account-exists-with-different-credential':
        return 'На этот адрес почты уже есть аккаунт, созданный другим '
            'способом входа. Войдите тем же способом, что и в первый раз, '
            'или разрешите в Firebase несколько аккаунтов на один адрес '
            '(Authentication → Settings → User account linking).';
      default:
        return e.message ?? e.code;
    }
  }

  /// Вход через ВК или Яндекс. Firebase о них не знает, а правила его базы
  /// требуют входа («auth != null»), иначе список не прочитать. Поэтому
  /// дополнительно входим в Firebase анонимно: доступ к данным появляется,
  /// а имя показываем настоящее — то, что прислал ВК или Яндекс.
  Future<void> _socialSignIn(Future<SocialUser> Function() flow) async {
    final user = await flow();
    try {
      await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'admin-restricted-operation' ||
          e.code == 'operation-not-allowed') {
        throw AuthMessage(
          'Чтобы показать список, включите в Firebase способ входа '
          '«Анонимно» (Authentication → Sign-in method → Anonymous).',
        );
      }
      rethrow;
    }
    if (mounted) setState(() => _social = user);
  }

  Future<void> _signOut() async {
    setState(() => _social = null);
    await _auth.signOut();
  }

  /// Имя, которое показываем после входа.
  /// У входа через GitHub имя иногда лежит не в самом пользователе,
  /// а в данных провайдера, поэтому проверяем оба места.
  String _nameOf(User? user) {
    if (_social != null) return '${_social!.name} · ${_social!.provider}';
    if (user == null) return 'Вы вошли';

    final candidates = <String?>[
      user.displayName,
      user.email,
      for (final p in user.providerData) p.displayName,
      for (final p in user.providerData) p.email,
    ];
    for (final name in candidates) {
      if (name != null && name.isNotEmpty) return name;
    }
    return user.isAnonymous ? 'Гость' : 'Вы вошли';
  }

  /// Превращает данные Firebase в список для таблицы.
  /// Firebase отдаёт Map «ключ → запись» или List, если ключи 0, 1, 2...
  /// Ключ запоминаем: по нему потом удаляется строка.
  List<Map<String, dynamic>> _parse(Object? value) {
    final rows = <Map<String, dynamic>>[];

    void add(Object? key, Object? item) {
      if (item is Map) {
        rows.add({
          'key': '$key',
          'username': item['username'],
          'password': item['password'],
        });
      }
    }

    if (value is Map) {
      value.forEach(add);
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        add(i, value[i]);
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ready) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Firebase не подключился.\n\n'
            'Проверьте значения в файле lib/firebase_options.dart '
            'и перезапустите приложение.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: _authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;
        if (user == null && _social == null) return _loginScreen();

        return HomeScreen(
          name: _nameOf(user),
          role: _role,
          firstVisit: _firstVisit,
          onSignOut: _signOut,
          onAdd: _add,
          listTitle: 'Список пользователей (обновляется сам)',
          list: StreamBuilder<DatabaseEvent>(
            stream: _usersChanges,
            builder: (context, event) {
              if (event.hasError) {
                return Text(
                  'Ошибка чтения: ${event.error}',
                  style: const TextStyle(color: Colors.red),
                );
              }
              if (!event.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Подключаемся к базе Firebase...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              return UsersTable(
                users: _parse(event.data!.snapshot.value),
                onDelete: _role == 'admin' ? _delete : null,
              );
            },
          ),
        );
      },
    );
  }

  Widget _loginScreen() {
    return LoginScreen(
      title: 'Вход через Firebase',
      onSignIn: (email, password) => _friendly(
        () => _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
      ),
      onSignUp: (email, password) => _friendly(
        () => _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      ),
      social: [
        SocialButton(
          label: 'Войти через Google',
          icon: Icons.g_mobiledata,
          color: Colors.red,
          onTap: () => _oauth(GoogleAuthProvider()),
        ),
        SocialButton(
          label: 'Войти через GitHub',
          icon: Icons.code,
          color: Colors.black87,
          onTap: () => _oauth(GithubAuthProvider()),
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
}
