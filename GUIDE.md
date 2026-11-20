# Руководство по проекту: как это сделано и как сделать такое самой

Этот файл — учебный разбор. Здесь по порядку: что за технологии мы
использовали, как с нуля настроить все сервисы, что делает каждая строчка
кода и как всё это работает вместе.

Читать можно подряд, а можно прыгать по разделам.

**Содержание**

1. [Что это за приложение](#1-что-это-за-приложение)
2. [Технологии: что есть что](#2-технологии-что-есть-что)
3. [Пошаговая настройка всех сервисов](#3-пошаговая-настройка-всех-сервисов)
4. [Разбор кода по файлам](#4-разбор-кода-по-файлам)
5. [Механика: где что хранится и что происходит при входе](#5-механика-где-что-хранится)
6. [Ошибки, на которые мы напоролись](#6-ошибки-на-которые-мы-напоролись)
7. [Чеклист: как сделать такой проект заново](#7-чеклист-как-сделать-такой-проект-заново)

---

## 1. Что это за приложение

Одно приложение на Flutter с нижним меню из двух вкладок.

**Вкладка Supabase** и **вкладка Firebase** — это два независимых мира.
У каждого своя авторизация, своя база данных, свой список пользователей.
Можно войти на одной вкладке и не входить на другой: они друг про друга
ничего не знают. Так и задумано — это лабораторная работа, где надо
сравнить два облачных сервиса.

На каждой вкладке можно войти пятью способами:

- логин или почта + пароль (с регистрацией),
- Google,
- GitHub,
- Яндекс,
- ВКонтакте.

После входа видно: **имя, роль, список пользователей из базы и кнопку
«Выйти»**. Список можно сортировать по столбцу, а удалять записи может
только администратор.

---

## 2. Технологии: что есть что

### 2.1 Flutter и Dart

**Dart** — язык программирования. **Flutter** — фреймворк, который из
одного кода на Dart собирает приложение под Android, iOS, Windows и для
браузера.

Мы собираем **под браузер** (Flutter Web). Flutter компилирует Dart
в JavaScript и рисует интерфейс на `<canvas>` — то есть страница почти
не состоит из обычных HTML-элементов, это как бы картинка, которую
рисует программа. Поэтому, кстати, кнопки на сайте нельзя найти
«поиском по странице» — их в HTML нет.

Ключевое понятие Flutter — **виджет**. Любая кнопка, текст, отступ,
весь экран — это виджет. Виджеты вкладываются друг в друга деревом.

Есть два вида:

- **StatelessWidget** — без состояния. Нарисовал и забыл. Пример:
  `MyApp` в `main.dart`.
- **StatefulWidget** — с состоянием. Умеет перерисовываться, когда
  данные меняются. Пример: `SupabaseTab` — у него меняется то, вошёл
  пользователь или нет.

Перерисовка запускается вызовом **`setState()`**. Это главное, что надо
понять про Flutter: ты не «обновляешь экран вручную», ты меняешь данные
внутри `setState`, а Flutter сам перерисовывает то, что от них зависит.

### 2.2 Supabase

Это облачный сервис, построенный вокруг обычной базы **PostgreSQL**.
Даёт сразу:

- саму базу (таблицы, SQL),
- **Auth** — готовую систему входа (почта+пароль, Google, GitHub и др.),
- **REST API** поверх таблиц: можно читать и писать из приложения
  обычными HTTP-запросами, свой сервер писать не нужно,
- **RLS** (Row Level Security) — правила доступа на уровне строк базы.

**RLS — самое важное для понимания.** Это правила, записанные в самой
базе: кто какие строки может читать, добавлять, удалять. Они работают
независимо от приложения. Если в приложении спрятать кнопку «Удалить»,
её можно вернуть через инструменты разработчика за полминуты. А правило
RLS обойти нельзя — оно проверяется на сервере.

### 2.3 Firebase

Сервис Google. Из него мы используем три части:

- **Authentication** — вход (почта+пароль, Google, GitHub, анонимный),
- **Realtime Database** — база данных в виде одного большого JSON-дерева,
  которая умеет **сама присылать изменения** в приложение,
- **Hosting** — бесплатный хостинг для сайта с https.

Главное отличие Realtime Database от Supabase: это **не таблицы, а дерево**.
Нет строк и колонок, есть вложенные узлы (ветки). Наш список лежит в ветке
`Users`, внутри неё — записи со случайными ключами.

Второе отличие: **realtime**. Supabase мы спрашиваем «дай список» и
получаем ответ один раз. Firebase мы говорим «следи за этой веткой» —
и он сам присылает новые данные, когда кто-то что-то изменил, хоть
из консоли, хоть с другого компьютера. Поэтому на вкладке Firebase
написано «обновляется сам», а на вкладке Supabase есть кнопка «Обновить».

Правила доступа в Firebase называются **Security Rules** и пишутся
в JSON — это аналог RLS.

### 2.4 OAuth — вход «через Google» и подобные

Это протокол, по которому чужой сервис подтверждает, кто ты, не показывая
нашему приложению твой пароль. Участников трое: ты, сервис (Google) и наше
приложение.

Базовые понятия:

| Что | Это что такое |
|---|---|
| **client_id** | Публичный номер нашего приложения в чужом сервисе. Его не прячут. |
| **client_secret** | Секретный ключ того же приложения. Его прячут: он доказывает, что запрос от нас. |
| **redirect_uri** | Адрес, куда сервис вернёт человека после входа. Заранее прописывается в настройках сервиса — иначе любой смог бы увести токен себе. |
| **access_token** | «Пропуск». С ним можно спросить у сервиса данные пользователя. |
| **scope** | Что именно мы просим: почту, имя, аватар. |

Как это выглядит по шагам (упрощённо):

1. Приложение открывает страницу Google с нашим `client_id` и `redirect_uri`.
2. Человек вводит пароль **на странице Google** — приложение его не видит.
3. Google возвращает человека на `redirect_uri` и отдаёт токен или код.
4. Приложение по токену спрашивает имя и почту.

### 2.5 PKCE — почему вход в ВК устроен сложнее

Обычный OAuth предполагает, что у приложения есть `client_secret`.
Но у приложения **в браузере** секрета быть не может: весь код скачивается
к пользователю, секрет оттуда вытащит кто угодно.

Решение — **PKCE** (произносится «пикси»):

1. Приложение придумывает длинную случайную строку — **verifier**.
2. Считает от неё отпечаток SHA-256 — **challenge** — и отправляет
   сервису **только отпечаток**.
3. Сервис возвращает временный **код**.
4. Приложение меняет код на токен, предъявляя **исходную строку**.
5. Сервис считает от неё отпечаток и сверяет с тем, что получил вначале.

Смысл: если кто-то перехватит код, он не сможет обменять его на токен —
исходной строки у него нет. Отпечаток назад не раскручивается.

Этим PKCE и заменяет секретный ключ. ВК требует именно такую схему,
старую у приложений VK ID он отключил.

### 2.6 Почему Яндекс и ВК сделаны отдельно

В списке готовых провайдеров Supabase и Firebase есть Google, GitHub,
Apple, Facebook и ещё десяток — но **нет Яндекса и ВК**. Поэтому с ними
приложение работает напрямую: само открывает окно входа, само получает
токен, само спрашивает имя. Это и есть файл `social_oauth.dart`.

Преподаватель это и имел в виду, когда написал «делаем через supabase
и firebase, кроме вк и yandex».

---

## 3. Пошаговая настройка всех сервисов

Здесь всё с нуля. Если будешь делать новый проект — иди по порядку.

### 3.1 Создать проект Flutter

```bash
flutter create my_app
cd my_app
```

Проверить, что всё установлено:

```bash
flutter doctor
```

### 3.2 Supabase: проект и таблица

1. Зайти на **supabase.com**, войти (можно через GitHub).
2. **New project** → придумать имя, пароль базы, выбрать регион
   (бери ближайший — от этого зависит скорость).
3. Дождаться, пока проект поднимется (пара минут).
4. Слева **Table Editor** → **New table**:
   - имя таблицы: `Users`,
   - колонки: `id` (создаётся сам, тип int8, первичный ключ),
     `username` (text), `password` (text).
5. Слева **Settings → API**. Оттуда нужны две вещи:
   - **Project URL** — вида `https://xxxxx.supabase.co`,
   - **publishable key** (он же anon key) — длинная строка.

Эти два значения вставляются в код, в `main.dart`. **Их не прячут** —
они публичные по задумке, защита держится на RLS.

### 3.3 Подключить Supabase к приложению

```bash
flutter pub add supabase_flutter
```

В `main.dart`:

```dart
await Supabase.initialize(
  url: 'https://xxxxx.supabase.co',
  publishableKey: 'sb_publishable_...',
);
```

### 3.4 Вход через Google (в Supabase)

Это самая длинная настройка, потому что участвуют два сервиса.

**Сначала в Google Cloud:**

1. Открыть **console.cloud.google.com**, создать проект (или взять тот,
   что создался вместе с Firebase).
2. Слева **APIs & Services → OAuth consent screen** (сейчас называется
   «Платформа аутентификации Google» → «Брендинг»). Заполнить название
   приложения и почту поддержки.
3. Раздел **Аудитория**: тип **External**. Пока приложение
   в режиме **Testing**, войти смогут только те, кто добавлен
   в **Test users** — обязательно добавь туда свою почту, иначе Google
   откажет.
4. Раздел **Клиенты** → **Create client** → тип **Web application**:
   - **Authorized JavaScript origins**: `http://localhost:3000`,
   - **Authorized redirect URIs**:
     `https://xxxxx.supabase.co/auth/v1/callback`
     (этот адрес Supabase показывает сам, см. следующий шаг).
5. Скопировать **Client ID** и **Client secret**.

**Потом в Supabase:**

1. **Authentication → Sign In / Providers → Google** → включить.
2. Вставить Client ID и Client Secret.
3. Там же Supabase показывает свой **Callback URL** — именно его надо
   было вписать в Google на шаге 4.
4. **Authentication → URL Configuration**:
   - **Site URL** — адрес, куда возвращать по умолчанию,
   - **Redirect URLs** — список всех разрешённых адресов возврата.
     Добавить сюда `http://localhost:3000` и адреса выложенных версий.

> **Это место ломается чаще всего.** Если адрес, на который приложение
> просит вернуть, не совпадает со списком — Supabase молча отправит
> на Site URL. Выглядит как «вход не работает», хотя всё настроено.

**И ещё одна настройка:** Authentication → Sign In / Providers →
выключить **«Подтвердите адрес электронной почты»**. Иначе после
регистрации по почте человека не пустят, пока он не перейдёт по ссылке
из письма, а встроенная почта Supabase шлёт всего 2 письма в час.

### 3.5 Вход через GitHub (в Supabase)

1. На GitHub: **Settings → Developer settings → OAuth Apps →
   New OAuth App**.
2. Заполнить:
   - **Application name** — любое,
   - **Homepage URL** — адрес проекта,
   - **Authorization callback URL** —
     `https://xxxxx.supabase.co/auth/v1/callback`.
3. Создать, затем **Generate a new client secret**. Секрет показывается
   **один раз** — скопировать сразу.
4. В Supabase: **Sign In / Providers → GitHub** → включить, вставить
   Client ID и Client Secret.

> Если тот же проект подключается и к Firebase — нужно **два разных
> приложения GitHub**, у них разные адреса возврата. Мы на этом
> споткнулись: секрет от одного вставили в другое и получили
> `incorrect_client_credentials`.

### 3.6 Firebase: проект и подключение

1. **console.firebase.google.com** → **Создать проект**.
2. Добавить приложения: кнопка **Добавить приложение** → **Web** (`</>`).
   Для Android — отдельное приложение, там указывается **имя пакета**
   (оно должно совпадать с `applicationId` в
   `android/app/build.gradle.kts`, иначе сборка APK упадёт).
3. Поставить инструмент и подключить проект:

```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

`flutterfire configure` сам создаст файл `lib/firebase_options.dart`
со всеми ключами и `firebase.json`.

4. Добавить пакеты:

```bash
flutter pub add firebase_core firebase_auth firebase_database
```

### 3.7 Firebase: способы входа

**Authentication → Sign-in method → Add new provider.** Включить:

- **Email/Password** — просто включить,
- **Google** — включить, выбрать почту поддержки, больше ничего не нужно
  (Firebase сам создаёт OAuth-клиент в Google Cloud),
- **GitHub** — нужны Client ID и Secret **второго** приложения GitHub,
  с адресом возврата `https://ПРОЕКТ.firebaseapp.com/__/auth/handler`
  (Firebase показывает его прямо в окне настройки),
- **Anonymous** — нужен для входа через ВК и Яндекс, объясню в разделе 5.

Есть ещё одна настройка, из-за которой у нас вход через GitHub падал:
**Authentication → Настройки → Привязка учётных записей пользователей**.
По умолчанию стоит «объединять по адресу почты», и если на одну почту
приходят Google и GitHub — второй отвергается с ошибкой
`account-exists-with-different-credential`. Мы переключили на
**«Создайте несколько учётных записей для каждого поставщика»**.

### 3.8 Firebase: база данных и правила

1. Слева **Realtime Database** → **Создать базу данных** → выбрать регион
   (это важно для скорости — у нас база в США и отвечает ~1 секунду,
   тогда как Supabase ~120 мс).
2. Вкладка **Правила** — туда вставляется JSON из `db/firebase_rules.json`.

Правила можно выкладывать и командой, не открывая консоль:

```bash
firebase deploy --only database
```

Для этого в `firebase.json` есть раздел:

```json
"database": { "rules": "db/firebase_rules.json" }
```

### 3.9 Яндекс ID

1. Открыть **oauth.yandex.ru/client/new**.
2. Тип: **«Для авторизации пользователей»**.
3. Название, **иконка обязательна** (без неё не даст сохранить),
   почта для связи.
4. Платформа **«Веб-сервисы»** → **Redirect URI**. Можно добавить
   несколько — у нас три: localhost, Firebase Hosting и GitHub Pages.
5. Права доступа: **«Доступ к адресу электронной почты»** (`login:email`)
   и **«Доступ к логину, имени и фамилии, полу»** (`login:info`).
6. Создать. На странице приложения взять **ClientID** — он публичный,
   вставляется прямо в код.

Верификацию через Госуслуги можно пропустить, приложение работает
и без неё (просто будет надпись «Сервис не верифицирован»).

### 3.10 VK ID

1. Открыть **id.vk.ru/about/business/go** → **Добавить приложения**.
2. Название, платформа **Web**.
3. Второй шаг — **самое важное**:
   - **Базовый домен** — домен сайта, например `flutter-app-982b4.web.app`,
   - **Доверенный Redirect URL** — `https://ДОМЕН/auth.html`.
4. Подтвердить по SMS.
5. Взять **ID приложения** — это и есть client_id.

**Две ловушки, на которых мы потеряли много времени:**

- **ВК требует https.** Адрес возврата по `http://localhost` он не
  принимает вообще: «Обязателен протокол https». Значит, вход через ВК
  проверяется только на выложенном сайте.
- **Менять настройки готового приложения ВК не даёт** без верификации
  бизнес-профиля через Госуслуги. Создавать новые — даёт. Поэтому, если
  ошибся с доменом, проще завести новое приложение, чем исправить старое.
  И поэтому базовый домен надо указать правильно **сразу**.

### 3.11 Роли пользователей

Идея одна для обоих сервисов: **у каждого пользователя есть строка
с ролью, и правило доступа в базе смотрит именно туда.**

**Supabase** — файл [`db/supabase_roles.sql`](db/supabase_roles.sql),
выполняется в **SQL Editor**. Он делает четыре вещи:

1. Создаёт таблицу `profiles` (`id`, `email`, `role`).
2. Вешает на `auth.users` триггер: при регистрации нового пользователя
   автоматически появляется строка в `profiles` с ролью `user`.
3. Включает RLS на `Users`: читать и добавлять может кто угодно,
   **удалять — только тот, у кого в `profiles` роль `admin`**.
4. Выдаёт роль `admin` твоей почте.

У приложения **нет прав на запись в `profiles`** — политик insert/update
там нет намеренно. Поэтому выдать себе админа из браузера невозможно,
только через SQL Editor.

**Firebase** — файл [`db/firebase_rules.json`](db/firebase_rules.json).
Роль лежит в ветке `profiles/{uid}/role`. Правило на записи списка:

```json
".write": "auth != null && (newData.exists() || root.child('profiles').child(auth.uid).child('role').val() === 'admin')"
```

Читается так: писать может любой вошедший, **но если данные исчезают**
(`newData.exists()` ложно — а это и есть удаление), то только админ.

Роль `admin` проставляется вручную в консоли или командой:

```bash
firebase database:set /profiles/ТВОЙ_UID файл.json
```

### 3.12 Публикация сайта

Нужна, потому что ВК требует https. Есть два способа, оба бесплатные.

**Firebase Hosting:**

```bash
flutter build web
firebase deploy --only hosting
```

В `firebase.json` должен быть раздел:

```json
"hosting": { "public": "build/web", "rewrites": [{"source": "**", "destination": "/index.html"}] }
```

**GitHub Pages** — собирается сам при каждом `git push`, настраивается
файлом `.github/workflows/htmlpush.yaml`. Два момента:

- в команде сборки нужен правильный базовый адрес:
  `flutter build web --base-href /ИМЯ_РЕПОЗИТОРИЯ/`,
- в **Settings → Pages → Source** должно стоять **GitHub Actions**,
  иначе встроенный Jekyll будет затирать твою сборку.

---

## 4. Разбор кода по файлам

### 4.1 Карта проекта

```
lib/
  main.dart              запуск, подключение сервисов, нижнее меню
  ui_kit.dart            общие виджеты обеих вкладок
  supabase_tab.dart      всё про Supabase
  firebase_tab.dart      всё про Firebase
  social_oauth.dart      вход через ВК и Яндекс
  oauth_window_web.dart  окно входа — версия для браузера
  oauth_window_io.dart   окно входа — версия для телефона
  firebase_options.dart  ключи Firebase (создан автоматически)
web/
  auth.html              страница, куда возвращаются ВК и Яндекс
db/
  supabase_roles.sql     роли и права для Supabase
  firebase_rules.json    правила доступа для Firebase
```

Кто кого использует:

```
main.dart
 ├── supabase_tab.dart ──┬── ui_kit.dart
 └── firebase_tab.dart ──┤
                         └── social_oauth.dart ── oauth_window_web/io.dart
                                                   └── web/auth.html
```

`ui_kit.dart` не знает ни про Supabase, ни про Firebase — это чистый
интерфейс. В этом весь смысл: экран входа написан **один раз**, а вкладки
передают в него свои функции.

### 4.2 pubspec.yaml — зачем каждый пакет

| Пакет | Зачем |
|---|---|
| `supabase_flutter` | клиент Supabase: вход и запросы к базе |
| `firebase_core` | базовое подключение к Firebase, нужно всем остальным |
| `firebase_auth` | вход в Firebase |
| `firebase_database` | Realtime Database |
| `http` | обычные HTTP-запросы — ими мы говорим с ВК и Яндексом |
| `crypto` | SHA-256 для PKCE (вход в ВК) |
| `web` | доступ к функциям браузера из Dart (окно, BroadcastChannel) |
| `flutter_web_auth_2` | окно входа на телефоне |

### 4.3 main.dart — точка входа

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
```

`main()` — первая функция, которая запускается. `ensureInitialized()`
обязателен, когда до `runApp` делается что-то асинхронное: он готовит
связь Flutter с платформой. Без него подключение к Supabase упадёт.

```dart
  await Supabase.initialize(url: ..., publishableKey: ...);
```

Подключение к Supabase. После этого в любом месте программы доступен
`Supabase.instance.client`. Это **синглтон** — один объект на всё
приложение.

```dart
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase не запустился: $e');
  }
```

Подключение к Firebase обёрнуто в `try`. Смысл: если ключи Firebase
не настроены, приложение всё равно запустится и вкладка Supabase будет
работать — вкладка Firebase просто покажет подсказку. Без `try` падало бы
всё целиком.

`DefaultFirebaseOptions.currentPlatform` сам выбирает нужные ключи:
для браузера одни, для Android другие.

```dart
  runApp(MyApp(firebaseReady: firebaseReady));
```

Запуск интерфейса. Дальше всё управляется деревом виджетов.

```dart
class MyApp extends StatelessWidget {
  ...
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
    home: HomeShell(firebaseReady: firebaseReady),
  );
```

`MaterialApp` — обёртка, которая даёт тему, навигацию и локализацию.
`colorSchemeSeed` — Flutter сам строит всю палитру от одного цвета.
`debugShowCheckedModeBanner: false` убирает красную плашку DEBUG в углу.

```dart
class _HomeShellState extends State<HomeShell> {
  int _index = 0;
```

`_index` — какая вкладка открыта. Подчёркивание в начале имени в Dart
означает «приватное», видно только внутри файла.

```dart
      body: IndexedStack(
        index: _index,
        children: [const SupabaseTab(), FirebaseTab(ready: widget.firebaseReady)],
      ),
```

**`IndexedStack` вместо обычного переключения — осознанный выбор.**
Он держит в памяти обе вкладки сразу и показывает одну. Если бы мы
создавали вкладку заново при каждом переключении, вход бы сбрасывался,
а список перезагружался. А так ты вошла в Supabase, переключилась
на Firebase, вернулась — всё на месте.

```dart
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
```

Вот здесь видно, как работает Flutter: нажатие меняет `_index` внутри
`setState`, Flutter перерисовывает `HomeShell`, и `IndexedStack`
показывает другую вкладку.

### 4.4 ui_kit.dart — общие виджеты

Файл не знает ни про какие сервисы. Он описывает **как выглядит**
экран, а **что делают кнопки** передаёт вкладка.

#### showMessage

```dart
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
```

Всплывающая плашка внизу экрана. `..` — это каскад: оба вызова идут
одному объекту. Сначала прячем предыдущее сообщение, потом показываем
новое, чтобы они не накапливались очередью.

#### loginToEmail и emailToLogin

```dart
const String loginDomain = 'example.com';

String loginToEmail(String input) {
  final value = input.trim();
  return value.contains('@') ? value : '$value@$loginDomain';
}
```

Трюк, который позволяет входить **по логину, а не только по почте**.
И Supabase, и Firebase принимают только адрес почты: на `vera` они
отвечают `invalid format`. Поэтому если собаки нет — дописываем
технический домен и отправляем в базу `vera@example.com`.

Домен `example.com` выбран не наугад: он зарезервирован стандартом
под примеры, и Supabase его принимает. Выдуманный `users.local`
он отвергает — проверено запросом.

```dart
String emailToLogin(String? email) {
  if (email == null || email.isEmpty) return '';
  return email.endsWith('@$loginDomain') ? email.split('@').first : email;
}
```

Обратное преобразование — чтобы на экране снова было видно просто `vera`.

#### AuthMessage

```dart
class AuthMessage implements Exception {
  AuthMessage(this.message);
  final String message;
  @override
  String toString() => message;
}
```

Своё исключение с человеческим текстом. Обычное `Exception('текст')`
при выводе даёт `Exception: текст`. Здесь `toString` переопределён,
поэтому на экран попадает только сам текст.

#### SocialButton

```dart
class SocialButton {
  const SocialButton({required this.label, required this.icon,
                      required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;
}
```

Это **не виджет**, а описание кнопки: подпись, иконка, цвет и функция.
`Future<void> Function()` — тип «функция без аргументов, возвращающая
Future». В Dart функции можно хранить в переменных, и это основа всего
нашего разделения: вкладка кладёт сюда свою функцию входа.

#### LoginScreen

```dart
class LoginScreen extends StatefulWidget {
  final String title;
  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function(String email, String password) onSignUp;
  final List<SocialButton> social;
```

Экран входа один на обе вкладки. Он не знает, Supabase это или Firebase —
просто вызывает те функции, которые ему дали.

```dart
  final _email = TextEditingController();
  final _password = TextEditingController();
```

`TextEditingController` — объект, через который читают и меняют текст
в поле ввода.

```dart
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
```

`dispose()` вызывается, когда виджет убирают с экрана. Контроллеры надо
освобождать вручную, иначе получится утечка памяти. Это обязательный
ритуал Flutter.

```dart
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
```

Одна обёртка на все кнопки сразу. Что делает:

- ставит `_busy = true` → все кнопки гаснут, на «Войти» появляется
  «Подождите...», случайный двойной клик невозможен,
- ловит любую ошибку и показывает её текст,
- в `finally` снимает блокировку — это выполнится и при успехе,
  и при ошибке.

`if (mounted)` — проверка, что виджет ещё на экране. Без неё, если
пользователь успел уйти с экрана, `setState` выбросит ошибку.

```dart
              for (final button in widget.social) ...[
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(button.onTap),
                  ...
```

Кнопки соцсетей строятся циклом прямо в списке виджетов. `...[` — это
**spread-оператор**: он «разворачивает» вложенный список в общий.
`onPressed: null` — стандартный способ в Flutter сделать кнопку
неактивной.

#### HomeScreen

Экран после входа. Принимает `name`, `role`, `firstVisit`, функции
`onSignOut`, `onAdd`, `onRefresh` и — главное — **готовый виджет `list`**.

```dart
  final Widget list;
```

Вот это важный приём. Список у вкладок разный: Supabase отдаёт обычную
таблицу, Firebase — таблицу внутри `StreamBuilder`, которая обновляется
сама. Вместо того чтобы городить условия внутри `HomeScreen`, мы просим
вкладку передать уже собранный виджет.

```dart
  bool get isAdmin => role == 'admin';
```

Геттер — вычисляемое свойство. Пишется без скобок при обращении.

#### AddUserForm

Форма «логин + пароль + кнопка». Сама запись в базу происходит
не здесь: форма вызывает переданную функцию `onAdd`.

```dart
    setState(() => _busy = true);
    try {
      await widget.onAdd(login, password);
      _login.clear();
      _password.clear();
      if (mounted) showMessage(context, 'Пользователь добавлен');
```

После успешного добавления поля очищаются — иначе легко случайно
добавить одно и то же дважды.

#### UsersTable

```dart
class _UsersTableState extends State<UsersTable> {
  static const _keys = ['username', 'password'];
  int _column = 0;
  bool _ascending = true;
```

Состояние сортировки: какой столбец и в какую сторону. `_keys`
связывает номер столбца с именем поля в данных.

```dart
  List<Map<String, dynamic>> get _sorted {
    final key = _keys[_column];
    final rows = [...widget.users];
    rows.sort((a, b) {
      final left = '${a[key] ?? ''}'.toLowerCase();
      final right = '${b[key] ?? ''}'.toLowerCase();
      return _ascending ? left.compareTo(right) : right.compareTo(left);
    });
    return rows;
  }
```

Сортировка происходит **в приложении, а не в базе**. `[...widget.users]`
создаёт копию списка: сортировать исходный нельзя, он принадлежит
вкладке. `?? ''` подставляет пустую строку, если значения нет.
`toLowerCase()` — чтобы «Аня» и «аня» сортировались рядом.

```dart
            columns: [
              DataColumn(label: const Text('Логин'), onSort: _sort),
              DataColumn(label: const Text('Пароль'), onSort: _sort),
              if (widget.onDelete != null) const DataColumn(label: Text('')),
            ],
```

`if` прямо внутри списка — это нормальный Dart. Третий столбец
(с корзиной) появляется, **только если передали функцию удаления**.
А вкладка передаёт её только администратору. Получается: нет прав —
нет и столбца.

```dart
  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(...);
    if (yes != true) return;
```

Диалог подтверждения. `showDialog` возвращает то, что передали
в `Navigator.pop(context, true/false)`. Проверка `!= true`, а не `== false`,
потому что если диалог закрыли мимо кнопок, вернётся `null`.

### 4.5 supabase_tab.dart — вкладка Supabase

```dart
  final _db = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSub;
  Session? _session;
  SocialUser? _social;
  List<Map<String, dynamic>> _users = [];
  String _role = 'user';
  bool _firstVisit = false;
```

Всё состояние вкладки. Два разных вида входа:

- `_session` — настоящая сессия Supabase (почта, Google, GitHub),
- `_social` — вход через ВК или Яндекс, про который Supabase не знает.

```dart
  bool get _signedIn => _session != null || _social != null;
```

Вошли, если есть хоть что-то из двух.

```dart
  @override
  void initState() {
    super.initState();
    _session = _db.auth.currentSession;
    if (_session != null) _afterSignIn(_session!);

    _authSub = _db.auth.onAuthStateChange.listen((state) { ... });
  }
```

`initState` вызывается один раз при создании виджета. Здесь:

1. Проверяем, нет ли уже сессии. Она бывает: Supabase хранит её
   в `localStorage` браузера, и после перезагрузки страницы или
   возврата со страницы Google сессия уже есть.
2. Подписываемся на изменения входа. `onAuthStateChange` — **поток**
   (Stream): он присылает событие каждый раз, когда человек вошёл
   или вышел.

```dart
  bool _isFirstVisit(User user) {
    final created = DateTime.tryParse(user.createdAt);
    final lastSignIn = DateTime.tryParse(user.lastSignInAt ?? '');
    if (created == null || lastSignIn == null) return false;
    return lastSignIn.difference(created).inSeconds.abs() < 5;
  }
```

Определение первого входа **без единого запроса к базе**. Supabase хранит
у пользователя две отметки: когда аккаунт создан и когда был последний
вход. При регистрации они совпадают, дальше вторая уходит вперёд.
Пять секунд — запас на задержку сети.

```dart
  Future<void> _loadRole() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) { ... return; }
    try {
      final rows = await _db.from('profiles').select('role').eq('id', userId).limit(1);
      final role = rows.isEmpty ? 'user' : '${rows.first['role'] ?? 'user'}';
      if (mounted) setState(() => _role = role);
    } catch (e) {
      if (mounted) setState(() => _role = 'user');
    }
  }
```

Чтение роли. `.from('profiles').select('role').eq('id', userId)` —
это конструктор запроса, он превращается в SQL
`select role from profiles where id = ...`.

`catch` важен: если таблицы `profiles` ещё нет (например, SQL не выполнен),
приложение не падает, а считает роль обычной.

```dart
  Future<void> _load() async {
    final rows = await _db.from('Users').select();
    setState(() => _users = List<Map<String, dynamic>>.from(rows));
  }

  Future<void> _add(String username, String password) async {
    await _db.from('Users').insert({'username': username, 'password': password});
    await _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    await _db.from('Users').delete().eq('id', row['id'] as Object);
    await _load();
  }
```

Три операции с базой: **SELECT, INSERT, DELETE**. После добавления
и удаления список перечитывается — у Supabase нет автообновления,
в отличие от Firebase.

```dart
  Future<void> _oauth(OAuthProvider provider) async {
    await _db.auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? SocialAuth.appBaseUrl : 'io.supabase...://login-callback/',
    );
  }
```

Вход через Google и GitHub. Всю работу делает Supabase: уводит на страницу
сервиса и возвращает обратно. `redirectTo` — куда вернуть; этот адрес
обязан быть в списке Redirect URLs, иначе вернёт на Site URL.

`kIsWeb` — константа, известная на этапе компиляции: в браузере или нет.

```dart
  Future<void> _socialSignIn(Future<SocialUser> Function() flow) async {
    final user = await flow();
    if (!mounted) return;
    setState(() => _social = user);
    await _load();
  }
```

Вход через ВК или Яндекс. Здесь Supabase не участвует вообще: имя
кладётся в поле `_social`, список читается как обычно (RLS разрешает
чтение всем).

```dart
  String get _name {
    if (_social != null) return '${_social!.name} · ${_social!.provider}';
    final user = _session!.user;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final name = meta['full_name'] ?? meta['user_name'] ?? meta['name'];
    if (name != null) return '$name';
    final login = emailToLogin(user.email);
    return login.isEmpty ? 'Вы вошли' : login;
  }
```

Имя ищется по цепочке. `userMetadata` — то, что прислал провайдер:
у Google там `full_name`, у GitHub — `user_name`. Если ничего нет,
показываем логин из почты. `??` — «если слева null, бери справа».

```dart
      list: UsersTable(
        users: _users,
        onDelete: _role == 'admin' ? _delete : null,
      ),
```

Вот где роль превращается в интерфейс: не админ → `null` → столбца
с корзиной нет.

### 4.6 firebase_tab.dart — вкладка Firebase

Устроена похоже, но есть три существенных отличия.

#### Отличие 1: данные приходят потоком

```dart
  Stream<DatabaseEvent>? _usersStream;
  DatabaseReference get _ref => FirebaseDatabase.instance.ref('Users');
  Stream<DatabaseEvent> get _usersChanges => _usersStream ??= _ref.onValue;
```

`onValue` — поток, который присылает содержимое ветки `Users` сразу
и потом при **каждом** изменении. Не нужно ничего перечитывать руками.

`??=` означает «присвоить, только если сейчас null» — поток создаётся
один раз и запоминается.

```dart
          list: StreamBuilder<DatabaseEvent>(
            stream: _usersChanges,
            builder: (context, event) {
              if (event.hasError) { ... }
              if (!event.hasData) { ... индикатор ... }
              return UsersTable(users: _parse(event.data!.snapshot.value), ...);
            },
          ),
```

`StreamBuilder` — виджет, который сам перестраивается, когда в потоке
появляются новые данные. Три состояния: ошибка, ещё нет данных, данные
есть.

```dart
            // Слушатель списка умирает вместе с сессией
            _usersStream = null;
```

Эта строчка — исправление настоящего бага. Firebase при выходе
из аккаунта отзывает подписку, поток становится мёртвым. Если оставить
его в поле, следующий вход подпишется на мертвеца: данные не придут
никогда, и на экране навсегда останется «Подключаемся к базе...».
Ошибки при этом нет, поэтому индикатор крутится вечно. Обнуляем —
и следующий вход создаёт новый поток.

#### Отличие 2: дерево вместо таблицы

```dart
  Future<void> _add(String username, String password) =>
      _ref.push().set({'username': username, 'password': password});
```

`push()` создаёт узел со случайным уникальным ключом вроде
`-P56dEjlt2TSz_OeSxgr`. Автоинкрементного `id`, как в SQL, здесь нет.

```dart
  List<Map<String, dynamic>> _parse(Object? value) {
    void add(Object? key, Object? item) {
      if (item is Map) {
        rows.add({'key': '$key', 'username': item['username'], 'password': item['password']});
      }
    }
    if (value is Map) { value.forEach(add); }
    else if (value is List) { ... }
```

Firebase отдаёт ветку как `Map` «ключ → запись». Но если ключи
оказались числами 0, 1, 2 — он отдаёт `List`. Поэтому обрабатываем
оба случая. Ключ запоминаем в поле `key` — по нему потом удаляем:

```dart
  Future<void> _delete(Map<String, dynamic> row) =>
      _ref.child('${row['key']}').remove();
```

#### Отличие 3: анонимный вход для ВК и Яндекса

```dart
  Future<void> _socialSignIn(Future<SocialUser> Function() flow) async {
    final user = await flow();
    await _auth.signInAnonymously();
    if (mounted) setState(() => _social = user);
  }
```

Правила базы Firebase требуют `auth != null`, а вход через Яндекс
для Firebase чужой. Поэтому после Яндекса мы дополнительно входим
**анонимно**: доступ к данным появляется, а имя показываем настоящее.

#### Прочее

```dart
    FirebaseDatabase.instance.ref('.info/connected').once().ignore();
```

«Разогрев» соединения. База Firebase в США, установка связи по веб-сокету
занимает несколько секунд. Узел `.info/connected` служебный и читается
без входа — трогаем его заранее, пока человек вводит логин, чтобы потом
не смотреть на индикатор.

```dart
  Future<T> _friendly<T>(Future<T> Function() action) async {
    try { return await action(); }
    on FirebaseAuthException catch (e) { throw AuthMessage(_errorText(e)); }
  }
```

Обёртка-переводчик. `<T>` — **дженерик**: функция работает с любым типом
результата. `_errorText` переводит коды ошибок Firebase на русский.

### 4.7 social_oauth.dart — ВК и Яндекс вручную

#### Условный импорт

```dart
import 'oauth_window_io.dart'
    if (dart.library.js_interop) 'oauth_window_web.dart';
```

Читается так: «подключи `oauth_window_io.dart`, но если сборка идёт
под браузер — подключи `oauth_window_web.dart`». Оба файла объявляют
функцию `openAuthWindow` с одинаковой сигнатурой, поэтому остальной
код не замечает разницы. Так в Flutter делают платформенные различия.

#### Яндекс — простая схема

```dart
    final url = Uri.https('oauth.yandex.ru', '/authorize', {
      'response_type': 'token',
      'client_id': yandexClientId,
      'redirect_uri': redirectUri,
    }).toString();

    final returned = await _open(url);
    final token = _fragment(returned)['access_token'];
```

`response_type=token` — Яндекс возвращает токен **сразу**, в адресе
после решётки: `.../auth.html#access_token=...`.

```dart
  static Map<String, String> _fragment(String url) =>
      Uri.splitQueryString(Uri.parse(url).fragment);
```

`fragment` — это часть адреса после `#`. Она устроена как обычная строка
параметров, поэтому разбирается тем же `splitQueryString`.

```dart
    final response = await http.get(
      Uri.parse('https://login.yandex.ru/info?format=json&oauth_token=$token'),
    );
    final profile = jsonDecode(response.body) as Map<String, dynamic>;
    final name = profile['display_name'] ?? profile['real_name'] ?? profile['login'] ?? ...;
```

По токену спрашиваем имя. `jsonDecode` превращает JSON-текст в Map.

#### ВКонтакте — схема с PKCE

```dart
    final verifier = _randomString(64);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = _randomString(40);
```

Здесь рождается PKCE:

- `verifier` — случайная строка, её хранит только приложение,
- `challenge` — её отпечаток SHA-256 в кодировке base64url,
  `=` в конце убирается по требованию стандарта,
- `state` — ещё одна случайная строка, защита от подмены ответа.

```dart
    final url = Uri.https('id.vk.ru', '/authorize', {
      'response_type': 'code',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      ...
```

`response_type=code` — ВК вернёт не токен, а **временный код**.

```dart
    final returned = Uri.parse(await _open(url)).queryParameters;
```

Обрати внимание: у ВК параметры в **обычной** части адреса
(`?code=...`), а не после решётки, как у Яндекса.

```dart
    if (returned['state'] != state) {
      throw AuthMessage('ВКонтакте вернул чужой ответ — вход прерван');
    }
```

Проверка `state`: вернулась ли та же строка, что мы отправили. Если нет —
ответ подменили, вход прерываем.

```dart
    final tokenResponse = await http.post(
      Uri.parse('https://id.vk.ru/oauth2/auth'),
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': verifier,
        ...
```

Второй шаг: меняем код на токен, предъявляя **исходную строку**.
ВК считает от неё отпечаток и сверяет с первым запросом.

```dart
    final infoResponse = await http.post(
      Uri.parse('https://id.vk.ru/oauth2/user_info'),
      body: {'access_token': token, 'client_id': vkClientId},
    );
```

Третий шаг: спрашиваем имя.

#### appBaseUrl — важное замечание

В репозитории эта функция вычисляет адрес сама:

```dart
  static String get appBaseUrl {
    final uri = Uri.base;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && segments.last.contains('.')) segments.removeLast();
    final path = segments.isEmpty ? '/' : '/${segments.join('/')}/';
    return '${uri.origin}$path';
  }
```

`Uri.base` — адрес текущей страницы. Берём домен **вместе с папкой**,
отбрасывая имя файла. Получается:

| Где открыто | Что вернёт |
|---|---|
| `http://localhost:3000/` | `http://localhost:3000/` |
| `https://flutter-app-982b4.web.app/` | `https://flutter-app-982b4.web.app/` |
| `https://vera104102007.github.io/flutter/` | `https://vera104102007.github.io/flutter/` |

Одного домена мало: на GitHub Pages приложение лежит в папке `/flutter/`,
и возврат на голый домен уводит на главную страницу GitHub.

> **В твоей рабочей копии сейчас эта функция переписана** — адрес
> прописан жёстко строкой `return 'https://vera104102007.github.io/flutter/';`.
> На Pages это работает, но на localhost и на Firebase Hosting вход
> через Google будет выбрасывать на Pages. Если захочешь, чтобы работали
> все три адреса, верни вычисляемый вариант — он лежит в коммите
> `9f525ff` и проверен на Pages.

### 4.8 oauth_window_web.dart и oauth_window_io.dart

Два файла с одной и той же функцией для разных платформ.

**Для браузера:**

```dart
Future<String> openAuthWindow(String url, String callbackScheme) {
  final result = Completer<String>();
  final channel = web.BroadcastChannel('flutter-oauth');

  channel.onmessage = ((web.MessageEvent event) {
    if (result.isCompleted) return;
    final href = event.data.dartify();
    if (href is String) result.complete(href);
  }).toJS;

  web.window.open(url, '_blank', 'width=600,height=700');

  return result.future.timeout(const Duration(minutes: 3), ...)
      .whenComplete(() => channel.close());
}
```

`Completer` — «обещание, которое я выполню сам позже». Мы возвращаем
`result.future` сразу, а заполняем его, когда придёт сообщение.

**`BroadcastChannel` — тут самое интересное.** Обычно всплывающее окно
отдаёт результат через `window.opener` — ссылку на открывшее его окно.
С Яндексом и ВК это не работает: они присылают заголовок
`Cross-Origin-Opener-Policy`, и браузер намеренно рвёт эту связь.

BroadcastChannel — общий канал для всех вкладок одного сайта, и связь
между окнами ему не нужна. Поэтому работает.

`.toJS` и `.dartify()` — перевод между типами Dart и JavaScript.

**Для телефона:**

```dart
Future<String> openAuthWindow(String url, String callbackScheme) =>
    FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: callbackScheme);
```

Там всё проще: пакет сам открывает браузер и ловит возврат по ссылке
`myapp://callback` (она прописана в `AndroidManifest.xml`).

### 4.9 web/auth.html — страница возврата

```html
<script>
  try {
    new BroadcastChannel('flutter-oauth').postMessage(window.location.href);
  } catch (e) {}
  try {
    if (window.opener) { window.opener.postMessage(...); }
  } catch (e) {}
  window.close();
</script>
```

Эта страница живёт полсекунды. Сюда ВК и Яндекс возвращают человека,
дописав к адресу токен или код. Скрипт берёт **весь адрес** и отправляет
его в канал, после чего окно закрывается. Второй `try` — запасной путь,
на случай если связь с открывшим окном всё-таки сохранилась.

Файл лежит в папке `web/`, поэтому Flutter копирует его в сборку как есть.

### 4.10 firebase_options.dart

Создаётся автоматически командой `flutterfire configure`. Руками его
не пишут. Внутри — ключи для каждой платформы:

```dart
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      ...
```

Эти ключи **публичные**. Защита Firebase держится не на них, а на
правилах базы и на списке разрешённых доменов.

### 4.11 db/supabase_roles.sql

Разбор самого важного куска:

```sql
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
```

**Триггер** — функция, которую база вызывает сама при событии. Здесь:
«после того как в таблице пользователей появилась строка, создай строку
в profiles».

`security definer` означает, что функция выполняется с правами
её создателя, а не вызывающего. Без этого она не смогла бы писать
в защищённую таблицу.

`on conflict (id) do nothing` — если строка уже есть, молча пропустить.

```sql
create policy users_delete_admin on public."Users"
  for delete using (
    exists (select 1 from public.profiles p
            where p.id = auth.uid() and p.role = 'admin')
  );
```

Политика удаления. `auth.uid()` — функция Supabase, возвращает id
того, кто сейчас делает запрос. Читается: «удалять можно те строки,
для которых нашлась запись в profiles с ролью admin у текущего
пользователя». Если такой записи нет — под условие не подходит
ни одна строка, и удалять оказывается нечего.

> Важная тонкость: Supabase в этом случае **не выдаёт ошибку**.
> Он отвечает `HTTP 204`, как будто всё прошло, но удаляет ноль строк.
> Проверять надо не код ответа, а то, что данные на месте.

### 4.12 db/firebase_rules.json

```json
"Users": {
  ".read": "auth != null",
  "$row": {
    ".write": "auth != null && (newData.exists() || root.child('profiles').child(auth.uid).child('role').val() === 'admin')"
  }
}
```

`$row` — переменная, означающая «любая запись внутри Users».

`newData.exists()` — будут ли данные после операции. При добавлении
и изменении — да. При удалении — **нет**. Поэтому условие читается:
писать может любой вошедший, а удалять только админ.

```json
"profiles": {
  "$uid": {
    ".read": "auth != null && auth.uid === $uid",
    ".write": "auth != null && auth.uid === $uid && (!data.exists() ? newData.child('role').val() === 'user' : newData.child('role').val() === data.child('role').val())"
  }
}
```

Профиль: человек видит только свой, может создать его **только с ролью
`user`** и не может потом её изменить (`newData` должно совпадать
с `data`). Админа выдаёт владелец проекта.

В отличие от Supabase, Firebase при отказе честно отвечает
`Permission denied`.

---

## 5. Механика: где что хранится

### 5.1 Вход через Яндекс — по шагам

Ты спрашивала именно про это, разберу подробно.

**Что происходит:**

1. Нажимаешь «Войти через Яндекс» на вкладке Supabase.
2. Открывается окно `oauth.yandex.ru/authorize` с нашим `client_id`.
3. Ты (или уже сохранённая сессия Яндекса) подтверждаешь вход.
4. Яндекс возвращает окно на `https://.../auth.html#access_token=...`.
5. `auth.html` отправляет этот адрес в BroadcastChannel и закрывается.
6. Приложение достаёт токен, запрашивает `login.yandex.ru/info`
   и получает имя.
7. Имя кладётся в поле `_social`, экран перерисовывается.

**Где теперь эта учётка:**

| Где | Что там появилось |
|---|---|
| **Supabase Authentication** | **Ничего.** Supabase про этот вход не знает вообще. |
| **Таблица `profiles`** | Ничего. |
| **В приложении** | Имя лежит в поле `_social` — то есть **в оперативной памяти вкладки**. |
| **В твоём Яндекс ID** | Приложение «Flutter Lab» появляется в списке подключённых — на `id.yandex.ru`, раздел «Доступ к данным». |

**Главное следствие:** этот вход **не сохраняется**. Обновишь страницу —
и снова увидишь экран входа. Никакой записи в базе не создаётся. Строки,
которые ты добавила в список, конечно, остаются — они лежат в таблице
`Users` и не привязаны к тому, кто их добавил.

**На вкладке Firebase немного иначе.** Там после Яндекса приложение
дополнительно делает анонимный вход в Firebase, поэтому появляется:

| Где | Что появилось |
|---|---|
| **Firebase Authentication** | Пользователь с пометкой `(anonymous)` и своим UID |
| **Realtime Database → `profiles/{uid}`** | Запись с `role: user` и временем создания |
| **В приложении** | Имя от Яндекса в поле `_social` |

То есть **имя от Яндекса не хранится нигде**, а в Firebase появляется
безымянный анонимный аккаунт. Это компромисс: правила базы требуют
входа, а настоящего аккаунта у Яндекса в Firebase быть не может.

Если обновить страницу, Firebase восстановит анонимную сессию, но имя
Яндекса уже потеряно — покажется «Гость».

### 5.2 Вход через Google или GitHub в Supabase

Здесь всё по-настоящему.

1. При **первом** входе в разделе **Authentication → Users** появляется
   новый пользователь с UID.
2. Появляется запись в `auth.identities` — связка «аккаунт ↔ провайдер».
3. Срабатывает триггер → строка в таблице `profiles` с ролью `user`.
4. Сессия сохраняется в `localStorage` браузера, поэтому после
   перезагрузки страницы вход сохраняется.

При **повторных** входах новый пользователь не создаётся, меняется
только отметка `last_sign_in_at`.

### 5.3 Вход через Google или GitHub в Firebase

То же самое, но в **Firebase Authentication**. Плюс при первом входе
приложение само создаёт `profiles/{uid}` в Realtime Database.

Отдельная особенность: у нас включена настройка «несколько аккаунтов
на один адрес почты». Поэтому вход через Google и вход через GitHub
с **одной и той же почтой** создают **два разных аккаунта с разными
UID**. Мы это видели своими глазами.

### 5.4 Вход по логину и паролю

Вводишь `vera` → приложение превращает это в `vera@example.com` →
отправляет в Supabase или Firebase. В консоли ты увидишь именно
`vera@example.com`. На экране приложения домен срезается обратно.

### 5.5 Где физически лежат данные

| Данные | Где лежат | Видно в |
|---|---|---|
| Список пользователей (Supabase) | таблица `Users` в PostgreSQL | Supabase → Table Editor |
| Список пользователей (Firebase) | ветка `Users` | Firebase → Realtime Database → Данные |
| Аккаунты Supabase | `auth.users` | Supabase → Authentication → Users |
| Аккаунты Firebase | внутренняя база Firebase | Firebase → Authentication → Users |
| Роли Supabase | таблица `profiles` | Supabase → Table Editor |
| Роли Firebase | ветка `profiles` | Firebase → Realtime Database |
| Сессия (вошёл или нет) | `localStorage` браузера | DevTools → Application |
| Имя от ВК и Яндекса | оперативная память приложения | нигде не сохраняется |

### 5.6 Почему Firebase медленнее

Замеры из браузера, по четыре запроса:

| База | Время ответа |
|---|---|
| Supabase | 107, 126, 119, 266 мс |
| Firebase | 1036, 1101, 1329, 919 мс |

Причина — регион: база Firebase в США (`us-central1`). Плюс Supabase
делает **один** обычный HTTP-запрос, а Firebase до первых данных
успевает несколько раз сходить по веб-сокету: соединение, токен,
подписка. Каждый обмен — около секунды.

Зато за эту цену список обновляется сам. Это честный размен,
и его стоит упомянуть в отчёте.

---

## 6. Ошибки, на которые мы напоролись

Полезнее всего именно это: что ломалось и как выглядело.

| Симптом | Настоящая причина |
|---|---|
| Кнопка Google «не грузится» | Приложение запускалось не на `localhost:3000`. Сервер слушал только IPv6 из-за `--web-hostname localhost` |
| `errno = 10048` при запуске | Порт 3000 занят предыдущим `flutter run` |
| Окно входа ВК/Яндекса возвращается, но ничего не происходит | `Cross-Origin-Opener-Policy` рвёт связь с открывшим окном. Решилось через BroadcastChannel |
| `permission-denied at /Users` | Правила Firebase требуют входа, а Яндекс для Firebase чужой. Решилось анонимным входом |
| Список Firebase виснет на «Подключаемся к базе...» навсегда | Поток `onValue` пережил выход из аккаунта и стал мёртвым |
| `incorrect_client_credentials` у GitHub | Секрет от приложения для Supabase вставили в Firebase |
| `account-exists-with-different-credential` | Firebase по умолчанию не даёт два аккаунта на одну почту |
| `Unable to validate email address: invalid format` | Ввели логин без собаки, а сервис принимает только адрес почты |
| ВК: `Security Error` | Приложения VK ID не поддерживают старый протокол, нужен OAuth 2.1 с PKCE |
| ВК: «не указан базовый домен» | Базовый домен приложения не совпадал с адресом сайта |
| На GitHub Pages пустая страница | В workflow стоял `--base-href /RMP-Flutter/`, а репозиторий называется `flutter` |
| На Pages то приложение, то README | Две публикации дерутся: workflow и встроенный Jekyll |
| Вход на Pages выбрасывает на localhost | Адрес возврата собирался без папки `/flutter/` |
| Сборка APK падает | `applicationId` не совпадает с пакетом в `google-services.json` |

Общая мораль: **сообщения об ошибках почти всегда врут о причине**.
`Security Error` у ВК на самом деле значил «не тот протокол», а
«кнопка не грузится» — «приложение запущено не по тому адресу».
Поэтому полезно не гадать, а проверять: открыть адрес авторизации
руками, посмотреть консоль браузера, сделать запрос через `curl`.

---

## 7. Чеклист: как сделать такой проект заново

Коротко, по порядку. Детали — в разделе 3.

**Подготовка**

1. `flutter create имя` → `flutter doctor`.
2. Решить сразу, по какому адресу приложение будет жить в интернете.
   Этот адрес понадобится во всех настройках, а менять его потом
   больно (особенно в ВК).

**Supabase**

3. Создать проект, таблицу `Users`, взять URL и ключ.
4. `flutter pub add supabase_flutter`, вызвать `Supabase.initialize`.
5. Выключить подтверждение почты.
6. В URL Configuration добавить **все** адреса: localhost и выложенные.
7. Google: создать клиент в Google Cloud, вписать в Supabase,
   добавить себя в Test users.
8. GitHub: создать OAuth App с адресом возврата Supabase.
9. Выполнить SQL с ролями, выдать себе `admin`.

**Firebase**

10. Создать проект, `flutterfire configure`.
11. Включить Email/Password, Google, GitHub (**второе** приложение
    GitHub!), Anonymous.
12. Переключить привязку аккаунтов на «несколько на одну почту».
13. Создать Realtime Database, выложить правила.

**Яндекс и ВК**

14. Яндекс: приложение, иконка, redirect URI, права, взять ClientID.
15. ВК: приложение **сразу с правильным базовым доменом**, взять ID.
    Помнить, что ВК работает только по https.

**Код**

16. `ui_kit.dart` — общие виджеты, без знания о сервисах.
17. По файлу на каждый сервис, общий экран входа получает функции
    параметрами.
18. `social_oauth.dart` + `auth.html` для ВК и Яндекса.

**Публикация**

19. Firebase Hosting или GitHub Pages, адрес возврата считать
    от текущей страницы **вместе с папкой**.
20. Проверить каждую кнопку на выложенной версии — на localhost
    часть из них в принципе работать не может.

---

## Что почитать дальше

- Документация Flutter: `docs.flutter.dev`
- Supabase: `supabase.com/docs`
- Firebase: `firebase.google.com/docs`
- VK ID: `id.vk.ru/about/business/go/docs`
- Яндекс ID: `yandex.ru/dev/id/doc`

Остальные файлы проекта:

- [`INSTRUCTIONS.md`](INSTRUCTIONS.md) — как запускать и что где настроено
- [`ANSWERS.md`](ANSWERS.md) — ответы на вопросы преподавателя
