import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'oauth_window_io.dart'
    if (dart.library.js_interop) 'oauth_window_web.dart';
import 'ui_kit.dart';

/// Пользователь, вошедший через ВКонтакте или Яндекс.
///
/// Эти два сервиса не входят в список провайдеров Supabase и Firebase,
/// поэтому с ними приложение работает напрямую по протоколу OAuth 2.0:
/// открывает страницу входа сервиса, получает оттуда access_token
/// и по токену узнаёт имя пользователя.
class SocialUser {
  const SocialUser(this.name, this.provider);

  final String name;
  final String provider;
}

class SocialAuth {
  // ───────── Сюда вписываются идентификаторы приложений ─────────
  // Яндекс:  https://oauth.yandex.ru/client/new
  // ВК:      https://id.vk.com/about/business/go
  // Как их получить — написано в INSTRUCTIONS.md.
  static const String yandexClientId = '2f9d7f1bbaed439cb13930b9403fab06';
  static const String vkClientId = '54880062';

  /// Адрес, на который сервис возвращает пользователя после входа.
  /// В браузере это страница web/auth.html нашего же сайта,
  /// на телефоне — ссылка вида myapp://callback.
  static String get redirectUri =>
      kIsWeb ? '${Uri.base.origin}/auth.html' : 'myapp://callback';

  static String get _scheme => kIsWeb ? 'http' : 'myapp';

  /// Вход через Яндекс ID.
  static Future<SocialUser> signInWithYandex() async {
    _requireId(yandexClientId, 'Яндекс', 'yandexClientId');

    final url = Uri.https('oauth.yandex.ru', '/authorize', {
      'response_type': 'token',
      'client_id': yandexClientId,
      'redirect_uri': redirectUri,
    }).toString();

    final token = _tokenFrom(await _open(url), 'Яндекс');

    // Имя берём из профиля Яндекса.
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

  /// Вход через ВКонтакте.
  ///
  /// ВК принимает адрес возврата только по https, поэтому на
  /// http://localhost этот вход работать не будет — нужен сайт,
  /// выложенный на HTTPS (например, Firebase Hosting).
  static Future<SocialUser> signInWithVk() async {
    _requireId(vkClientId, 'ВКонтакте', 'vkClientId');
    if (kIsWeb && Uri.base.scheme != 'https') {
      throw AuthMessage(
        'ВКонтакте пускает только с адреса по https. '
        'Сейчас приложение открыто по ${Uri.base.scheme}, поэтому вход '
        'через ВК доступен только на выложенной версии сайта.',
      );
    }

    final url = Uri.https('oauth.vk.com', '/authorize', {
      'client_id': vkClientId,
      'redirect_uri': redirectUri,
      'response_type': 'token',
      'scope': 'email',
      'display': 'page',
      'v': '5.131',
    }).toString();

    final result = await _open(url);
    final params = _params(result);
    _tokenFrom(result, 'ВКонтакте');

    // ВК возвращает почту и номер пользователя прямо в адресе,
    // поэтому дополнительный запрос к API не нужен.
    final name = params['email'] ?? 'Пользователь ВК id${params['user_id']}';
    return SocialUser(name, 'ВКонтакте');
  }

  /// Открывает окно входа сервиса и ждёт возврата.
  static Future<String> _open(String url) => openAuthWindow(url, _scheme);

  /// Сервис возвращает данные после решётки: #access_token=...&user_id=...
  static Map<String, String> _params(String url) =>
      Uri.splitQueryString(Uri.parse(url).fragment);

  static String _tokenFrom(String url, String service) {
    final token = _params(url)['access_token'];
    if (token == null || token.isEmpty) {
      throw AuthMessage('$service не вернул токен — вход отменён');
    }
    return token;
  }

  static void _requireId(String id, String service, String field) {
    if (id.isEmpty) {
      throw AuthMessage(
        'Вход через $service не настроен: впишите $field в lib/social_oauth.dart',
      );
    }
  }
}
