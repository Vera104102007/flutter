import 'package:flutter/material.dart';

/// Всплывающее сообщение внизу экрана.
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Ошибка с понятным текстом: в сообщении показывается только текст,
/// без служебного слова Exception.
class AuthMessage implements Exception {
  AuthMessage(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Описание одной кнопки входа через внешний сервис.
class SocialButton {
  const SocialButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;
}

/// Экран входа. Один на обе вкладки: что именно делают кнопки,
/// решает вкладка, которая передаёт сюда свои функции.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.title,
    required this.onSignIn,
    required this.onSignUp,
    required this.social,
  });

  final String title;
  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function(String email, String password) onSignUp;
  final List<SocialButton> social;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Общая обёртка для всех кнопок: блокирует экран на время запроса
  /// и показывает текст ошибки, если что-то пошло не так.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showMessage(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _withEmail(Future<void> Function(String, String) action) {
    final email = _email.text.trim();
    final password = _password.text.trim();
    if (email.isEmpty || password.isEmpty) {
      showMessage(context, 'Заполните email и пароль');
      return;
    }
    _run(() => action(email, password));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 12),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : () => _withEmail(widget.onSignIn),
                child: Text(_busy ? 'Подождите...' : 'Войти'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _withEmail(widget.onSignUp),
                child: const Text('Зарегистрироваться'),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('или войти через'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              for (final button in widget.social) ...[
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(button.onTap),
                  icon: Icon(button.icon, color: button.color),
                  label: Text(button.label),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Экран после успешного входа: имя, список из базы данных и кнопка «Выйти».
/// Сам список передаёт вкладка: у Supabase это обычная таблица,
/// у Firebase — таблица, которая обновляется сама.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.name,
    required this.onSignOut,
    required this.onAdd,
    required this.list,
    this.listTitle = 'Список пользователей',
    this.onRefresh,
  });

  final String name;
  final VoidCallback onSignOut;
  final Future<void> Function(String username, String password) onAdd;
  final Widget list;
  final String listTitle;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Выйти'),
                ),
              ],
            ),
            const Divider(),
            AddUserForm(onAdd: onAdd),
            const SizedBox(height: 16),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    listTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Обновить',
                  ),
              ],
            ),
            list,
          ],
        ),
      ),
    );
  }
}

/// Форма «логин + пароль + кнопка». Саму запись в базу делает вкладка.
class AddUserForm extends StatefulWidget {
  const AddUserForm({super.key, required this.onAdd});

  final Future<void> Function(String username, String password) onAdd;

  @override
  State<AddUserForm> createState() => _AddUserFormState();
}

class _AddUserFormState extends State<AddUserForm> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final login = _login.text.trim();
    final password = _password.text.trim();
    if (login.isEmpty || password.isEmpty) {
      showMessage(context, 'Заполните оба поля');
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.onAdd(login, password);
      _login.clear();
      _password.clear();
      if (mounted) showMessage(context, 'Пользователь добавлен');
    } catch (e) {
      if (mounted) showMessage(context, 'Ошибка добавления: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Добавить пользователя',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _login,
          decoration: const InputDecoration(
            labelText: 'Логин',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Пароль',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Добавляем...' : 'Добавить'),
        ),
      ],
    );
  }
}

/// Таблица пользователей: №, Логин, Пароль.
class UsersTable extends StatelessWidget {
  const UsersTable({super.key, required this.users});

  final List<Map<String, dynamic>> users;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Пока пусто')),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('№')),
              DataColumn(label: Text('Логин')),
              DataColumn(label: Text('Пароль')),
            ],
            rows: [
              for (var i = 0; i < users.length; i++)
                DataRow(
                  cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(Text('${users[i]['username'] ?? ''}')),
                    DataCell(Text('${users[i]['password'] ?? ''}')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
