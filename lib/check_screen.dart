import 'package:flutter/material.dart';

/// Имя именованного пути («маршрута») к этому экрану.
///
/// Вынесено в константу, чтобы одна и та же строка не писалась руками
/// в двух местах — там, где путь объявляется (routes в main.dart),
/// и там, где по нему переходят (Navigator.pushNamed). Опечатка в одном
/// из двух мест дала бы ошибку только во время работы приложения,
/// а с константой её поймает компилятор.
const String checkRoute = '/check';

/// Функция, результат которой готов не сразу: её тип — `Future<String>`.
///
/// Настоящего обращения к серверу здесь нет. Вместо него Future.delayed:
/// «подожди три секунды и только потом верни строку». Это учебная
/// заглушка — зато хорошо видно, что FutureBuilder сначала показывает
/// ожидание и лишь затем готовый результат.
///
/// async + await означают: функция не блокирует приложение на эти три
/// секунды. Интерфейс продолжает отвечать, кнопки нажимаются,
/// а выполнение самой функции приостанавливается на строке с await
/// и продолжается, когда ожидание закончилось.
Future<String> checkConnection({bool breakIt = false}) async {
  await Future.delayed(const Duration(seconds: 3));

  // Второй случай нужен, чтобы показать ветку ошибки в FutureBuilder:
  // если Future завершился исключением, в snapshot будет не data, а error.
  if (breakIt) {
    throw Exception('сервер не ответил');
  }

  return 'Связь есть: ответ пришёл через 3 секунды';
}

/// Второй экран приложения. Открывается по именованному пути [checkRoute].
///
/// Экран сделан StatefulWidget не ради красоты: Future нужно создать
/// один раз и запомнить в состоянии. Если написать
/// `future: checkConnection()` прямо внутри build, то при каждой
/// перерисовке создавался бы новый Future и ожидание начиналось заново —
/// частая ошибка новичков. Поэтому Future создаётся в initState,
/// а заново — только когда мы сами этого захотим, в _restart.
class CheckScreen extends StatefulWidget {
  const CheckScreen({super.key});

  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  /// Тот самый `Future<String>`, который ждёт FutureBuilder.
  late Future<String> _answer;

  /// Переключатель «сломать ответ»: с ним функция завершится ошибкой.
  bool _breakIt = false;

  @override
  void initState() {
    super.initState();
    _answer = checkConnection();
  }

  /// Запустить проверку заново: новый Future + setState, чтобы
  /// FutureBuilder увидел, что ждать теперь нужно другой результат.
  void _restart() {
    setState(() {
      _answer = checkConnection(breakIt: _breakIt);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Кнопку «назад» AppBar добавляет сам: экран открыт через
      // pushNamed, то есть положен поверх предыдущего, и Navigator
      // знает, куда возвращаться.
      appBar: AppBar(
        title: const Text('Проверка связи'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // FutureBuilder сам перерисовывает себя три раза:
                // пока ждёт, и когда результат (или ошибка) готов.
                FutureBuilder<String>(
                  future: _answer,
                  builder: (context, snapshot) {
                    // 1. Ещё ждём — показываем кружок.
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Проверяем связь...'),
                        ],
                      );
                    }

                    // 2. Future завершился исключением.
                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Ошибка: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      );
                    }

                    // 3. Готово: snapshot.data — та самая String,
                    // которую вернула функция.
                    return Column(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 48, color: Colors.green),
                        const SizedBox(height: 16),
                        Text(
                          snapshot.data ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                const Divider(),
                SwitchListTile(
                  value: _breakIt,
                  onChanged: (value) => setState(() => _breakIt = value),
                  title: const Text('Сломать ответ'),
                  subtitle: const Text('чтобы увидеть ветку ошибки'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Проверить снова'),
                ),
                const SizedBox(height: 8),
                // Возврат на предыдущий экран: снимаем верхний экран
                // со стека. То же самое делает кнопка «назад» в AppBar.
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Назад'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
