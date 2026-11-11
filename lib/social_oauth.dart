import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'oauth_window_io.dart'
    if (dart.library.js_interop) 'oauth_window_web.dart';
import 'ui_kit.dart';

/// Пользователь, вошедший через ВКонтакте или Яндекс.
///
/// Эти два сервиса не входят в список провайдеров Supabase и Firebase,
/// поэтому с ними приложение работает напрямую по протоколу OAuth:
/// открывает страницу входа сервиса, получает оттуда токен
/// и по токену узнаёт имя пользователя.
class SocialUser {
  const SocialUser(this.name, this.provider);

  final String name;
  final String provider;
}

class SocialAuth {
  // ───────── Идентификаторы приложений ─────────
  // Яндекс:  https://oauth.yandex.ru/client/new
  // ВК:      https://id.vk.ru/about/business/go
  static const String yandexClientId = '2f9d7f1bbaed439cb13930b9403fab06';
  static const String vkClientId = '54889826';

  /// Адрес, на который сервис возвращает пользователя после входа.
  /// В браузере это страница web/auth.html нашего же сайта,
  /// на телефоне — ссылка вида myapp://callback.
  static String get redirectUri =>
      kIsWeb ? '${Uri.base.origin}/auth.html' : 'myapp://callback';

  static String get _scheme => kIsWeb ? 'http' : 'myapp';

  // ───────── Яндекс ─────────

  /// Яндекс работает по простой схеме: сразу возвращает токен
  /// в адресе после решётки.
  static Future<SocialUser> signInWithYandex() async {
    _requireId(yandexClientId, 'Яндекс', 'yandexClientId');

    final url = Uri.https('oauth.yandex.ru', '/authorize', {
      'response_type': 'token',
      'client_id': yandexClientId,
      'redirect_uri': redirectUri,
    }).toString();

    final returned = await _open(url);
    final token = _fragment(returned)['access_token'];
    if (token == null || token.isEmpty) {
      throw AuthMessage('Яндекс не вернул токен — вход отменён');
    }

    final response = await http.get(
      Uri.parse('https://login.yandex.ru/info?format=json&oauth_token=$token'),
    );
    if (response.statusCode != 200) {
      return const SocialUser('Пользователь Яндекса', 'Яндекс');
    }
    final profile = jsonDecode(response.body) as Map<String, dynamic>;
    final name = profile['display_name'] ??
        profile['real_name'] ??
        profile['login'] ??
        'Пользователь Яндекса';
    return SocialUser('$name', 'Яндекс');
  }

  // ───────── ВКонтакте ─────────

  /// Вход через VK ID.
  ///
  /// ВК требует протокол OAuth 2.1 с PKCE: старый способ, когда токен
  /// возвращался сразу, у приложений VK ID отключён и отвечает
  /// «Security Error». Поэтому путь длиннее:
  ///
  /// 1. Приложение придумывает случайную строку (verifier) и отправляет
  ///    ВК только её отпечаток — SHA-256 (challenge).
  /// 2. ВК возвращает временный код.
  /// 3. Приложение меняет код на токен, предъявляя исходную строку.
  ///    Совпадение отпечатка доказывает, что код пришёл именно к тому,
  ///    кто начинал вход. Это и заменяет секретный ключ, которого
  ///    у приложения в браузере быть не может.
  static Future<SocialUser> signInWithVk() async {
    _requireId(vkClientId, 'ВКонтакте', 'vkClientId');
    if (kIsWeb && Uri.base.scheme != 'https') {
      throw AuthMessage(
        'ВКонтакте пускает только с адреса по https. '
        'Сейчас приложение открыто по ${Uri.base.scheme}, поэтому вход '
        'через ВК доступен только на выложенной версии сайта.',
      );
    }

    final verifier = _randomString(64);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = _randomString(40);

    final url = Uri.https('id.vk.ru', '/authorize', {
      'response_type': 'code',
      'client_id': vkClientId,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'redirect_uri': redirectUri,
      'state': state,
      'scope': 'vkid.personal_info email',
    }).toString();

    // ВК возвращает код в обычных параметрах адреса, а не после решётки.
    final returned = Uri.parse(await _open(url)).queryParameters;

    if (returned['error'] != null) {
      throw AuthMessage(
        'ВКонтакте отказал: ${returned['error_description'] ?? returned['error']}',
      );
    }
    if (returned['state'] != state) {
      throw AuthMessage('ВКонтакте вернул чужой ответ — вход прерван');
    }

    final code = returned['code'];
    final deviceId = returned['device_id'];
    if (code == null || deviceId == null) {
      throw AuthMessage('ВКонтакте не вернул код — вход отменён');
    }

    final tokenResponse = await http.post(
      Uri.parse('https://id.vk.ru/oauth2/auth'),
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': verifier,
        'client_id': vkClientId,
        'device_id': deviceId,
        'redirect_uri': redirectUri,
        'state': state,
      },
    );
    final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final token = tokenData['access_token'] as String?;
    if (token == null) {
      throw AuthMessage(
        'ВКонтакте не выдал токен: '
        '${tokenData['error_description'] ?? tokenData['error'] ?? tokenResponse.body}',
      );
    }

    // Имя спрашиваем отдельным запросом.
    final infoResponse = await http.post(
      Uri.parse('https://id.vk.ru/oauth2/user_info'),
      body: {'access_token': token, 'client_id': vkClientId},
    );
    final info = jsonDecode(infoResponse.body) as Map<String, dynamic>;
    final user = info['user'];
    if (user is Map) {
      final name = [user['first_name'], user['last_name']]
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .join(' ');
      if (name.isNotEmpty) return SocialUser(name, 'ВКонтакте');
      final email = user['email'];
      if (email is String && email.isNotEmpty) {
        return SocialUser(email, 'ВКонтакте');
      }
    }
    return const SocialUser('Пользователь ВК', 'ВКонтакте');
  }

  // ───────── Общее ─────────

  /// Открывает окно входа сервиса и ждёт возврата.
  static Future<String> _open(String url) => openAuthWindow(url, _scheme);

  /// Яндекс возвращает данные после решётки: #access_token=...
  static Map<String, String> _fragment(String url) =>
      Uri.splitQueryString(Uri.parse(url).fragment);

  /// Случайная строка из букв, цифр, дефиса и подчёркивания —
  /// именно такие символы разрешает ВК.
  static String _randomString(int length) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  static void _requireId(String id, String service, String field) {
    if (id.isEmpty) {
      throw AuthMessage(
        'Вход через $service не настроен: впишите $field в lib/social_oauth.dart',
      );
    }
  }
}
