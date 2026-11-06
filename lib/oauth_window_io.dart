import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// То же самое на телефоне: открывается браузер, а возврат в приложение
/// происходит по ссылке вида myapp://callback (прописана в AndroidManifest).
Future<String> openAuthWindow(String url, String callbackScheme) =>
    FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: callbackScheme);
