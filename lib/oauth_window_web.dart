import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'ui_kit.dart';

/// Открывает окно входа сервиса в браузере и ждёт адрес с токеном.
///
/// Обычный способ (window.opener + postMessage) здесь не работает:
/// Яндекс и ВКонтакте присылают заголовок Cross-Origin-Opener-Policy,
/// и всплывающее окно теряет связь с тем, которое его открыло.
/// Поэтому страница web/auth.html передаёт адрес через BroadcastChannel —
/// это общий канал для всех вкладок одного сайта, и связь ему не нужна.
Future<String> openAuthWindow(String url, String callbackScheme) {
  final result = Completer<String>();
  final channel = web.BroadcastChannel('flutter-oauth');

  channel.onmessage = ((web.MessageEvent event) {
    if (result.isCompleted) return;
    final href = event.data.dartify();
    if (href is String) result.complete(href);
  }).toJS;

  web.window.open(url, '_blank', 'width=600,height=700');

  return result.future
      .timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw AuthMessage('Вход не был завершён'),
      )
      .whenComplete(() => channel.close());
}
