
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


const String kBaseUrl = 'https://valores-friends-app.onrender.com'; 

class C {
  static const canvas      = Color(0xFFFAF7F2);
  static const linen       = Color(0xFFF3EFEA);
  static const edge        = Color(0xFFE8E2D9);
  static const ink         = Color(0xFF24201D);
  static const inkSoft     = Color(0x7324201D);
  static const terracotta  = Color(0xFFC46244);
  static const clay        = Color(0xFFD97757);
  static const sage        = Color(0xFF7C8B7A);
  static const amber       = Color(0xFFDE9E48);
  static const paper       = Colors.white;
  static const sageTint    = Color(0xFFE6EAE3);
  static const amberTint   = Color(0xFFF7E8CF);
  static const clayTint    = Color(0xFFF5E0D8);
  static const lavender    = Color(0xFF9B8EC4);
  static const lavenderTint= Color(0xFFEDE8F5);
  static const sky         = Color(0xFF6BA3BE);
  static const skyTint     = Color(0xFFDCECF3);
  static const rose        = Color(0xFFD4717A);
  static const roseTint    = Color(0xFFF5DEDE);
}

TextStyle serif(double s, {bool italic = false, FontWeight w = FontWeight.w400, Color c = C.ink}) =>
    GoogleFonts.newsreader(
        fontSize: s,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontWeight: w,
        color: c,
        height: 1.25,
        letterSpacing: -0.01 * s);

OutlineInputBorder _ob(Color c) =>
    OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c, width: 1));

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: C.canvas,
      colorScheme: ColorScheme.fromSeed(seedColor: C.terracotta, surface: C.canvas)
          .copyWith(primary: C.terracotta, secondary: C.sage, tertiary: C.amber),
      textTheme: GoogleFonts.dmSansTextTheme().apply(bodyColor: C.ink, displayColor: C.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: C.linen,
        border: _ob(Colors.transparent),
        enabledBorder: _ob(Colors.transparent),
        focusedBorder: _ob(C.terracotta),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: C.inkSoft),
      ),
    );


class Pill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool ghost, busy;
  const Pill(this.label, {super.key, this.onTap, this.ghost = false, this.busy = false});
  @override
  Widget build(BuildContext context) {
    final fg = ghost ? C.terracotta : Colors.white;
    final child = busy
        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.14, color: fg));
    const pad = EdgeInsets.symmetric(horizontal: 28, vertical: 14);
    return ghost
        ? OutlinedButton(
            onPressed: busy ? null : onTap,
            style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(), side: const BorderSide(color: C.terracotta), padding: pad),
            child: child)
        : FilledButton(
            onPressed: busy ? null : onTap,
            style: FilledButton.styleFrom(backgroundColor: C.terracotta, shape: const StadiumBorder(), padding: pad),
            child: child);
  }
}

class PaperCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  const PaperCard({super.key, required this.child, this.color = C.paper, this.padding = const EdgeInsets.all(24)});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xCCE8E2D9)),
          boxShadow: const [
            BoxShadow(color: Color(0x0D24201D), blurRadius: 20, offset: Offset(0, 4), spreadRadius: -2),
            BoxShadow(color: Color(0x0824201D), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: child,
      );
}

class Header extends StatelessWidget {
  final String title, subtitle;
  final Widget? trailing;
  const Header(this.title, this.subtitle, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: serif(32)),
              const SizedBox(height: 4),
              Text(subtitle, style: serif(16, italic: true, c: C.sage)),
            ]),
          ),
          ?trailing,
        ]),
      );
}

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: C.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));

String err(Object e) => e is ApiException ? e.message : 'No connection to the server';


class Block {
  String name, description;
  Block(this.name, this.description);
  factory Block.fromJson(Map<String, dynamic> j) =>
      Block(j['name']?.toString() ?? '', j['description']?.toString() ?? '');
  Map<String, dynamic> toJson() => {'name': name, 'description': description};
}

class BoardCard {
  final String? id;
  final String userId;
  final String? name;
  final int? age;
  final List<Block> blocks;
  BoardCard(this.id, this.userId, this.name, this.age, this.blocks);

  factory BoardCard.fromJson(Map<String, dynamic> j) {
    final inner = j['board'] is Map ? Map<String, dynamic>.from(j['board']) : j;
    final raw = inner['blocks'];
    final blocks = raw is List
        ? raw.whereType<Map>().map((e) => Block.fromJson(Map<String, dynamic>.from(e))).toList()
        : <Block>[];
    final uid = (j['user_id'] ?? j['owner_id'] ?? (j['user'] is Map ? j['user']['id'] : null))?.toString() ?? '';
    return BoardCard(
      j['id']?.toString(),
      uid,
      j['name']?.toString(),
      (j['age'] as num?)?.toInt(),
      blocks,
    );
  }
}

class Conv {
  final String id;
  final String? nickname, lastText;
  final int unread;
  Conv(this.id, this.nickname, this.lastText, this.unread);
  factory Conv.fromJson(Map<String, dynamic> j) {
    final lm = j['last_message'];
    return Conv(
      (j['id'] ?? j['conversation_id']).toString(),
      j['other_user_nickname']?.toString(),
      lm is Map ? lm['content']?.toString() : lm?.toString(),
      (j['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class Message {
  final String id, senderId, content, status;
  final DateTime sentAt;
  Message(this.id, this.senderId, this.content, this.status, this.sentAt);
  factory Message.fromJson(Map<String, dynamic> j) => Message(
        j['id'].toString(),
        j['sender_id'].toString(),
        j['content']?.toString() ?? '',
        j['status']?.toString() ?? 'unread',
        DateTime.tryParse(j['sent_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      );
}

class BlockSuggestion {
  final String name;
  final IconData icon;
  final Color color;
  final Color tint;
  final String hint;
  const BlockSuggestion(this.name, this.icon, this.color, this.tint, this.hint);
}

const kBlockSuggestions = <BlockSuggestion>[
  BlockSuggestion('Values',      Icons.favorite_border,   C.terracotta, C.clayTint,     'What matters most to you in life?'),
  BlockSuggestion('Hobby',         Icons.palette_outlined,  C.amber,      C.amberTint,    'What do you do in your free time?'),
  BlockSuggestion('Music',        Icons.music_note_outlined, C.lavender, C.lavenderTint, 'What genres / bands do you listen to?'),
  BlockSuggestion('Books',       Icons.auto_stories_outlined, C.sage,   C.sageTint,     'The last book that impressed you?'),
  BlockSuggestion('Films & Series', Icons.movie_outlined,  C.sky,        C.skyTint,      'Favourite films, series, anime?'),
  BlockSuggestion('Beliefs',   Icons.lightbulb_outline, C.amber,      C.amberTint,    'What do you believe in? What drives you?'),
  BlockSuggestion('Life goals',  Icons.flag_outlined,     C.sage,       C.sageTint,     'Where are you headed? What do you dream of?'),
  BlockSuggestion('Motto',         Icons.format_quote,      C.rose,       C.roseTint,     'A quote or thought that defines you'),
  BlockSuggestion('Free time',    Icons.wb_sunny_outlined, C.clay,       C.clayTint,     'What does your perfect day look like?'),
  BlockSuggestion('How I feel', Icons.emoji_emotions_outlined, C.lavender, C.lavenderTint, 'Mood, energy – how do you feel right now?'),
  BlockSuggestion('Travel',       Icons.flight_outlined,   C.sky,        C.skyTint,      'Favourite places, travel dreams?'),
  BlockSuggestion('Food',      Icons.restaurant_outlined, C.rose,     C.roseTint,     'Favourite cuisines, dishes, flavours?'),
];

(Color, Color, IconData) blockStyle(String name) {
  final lower = name.toLowerCase();
  for (final s in kBlockSuggestions) {
    if (s.name.toLowerCase() == lower) return (s.tint, s.color, s.icon);
  }
  final fills = [
    (C.paper, C.ink, Icons.auto_awesome),
    (C.linen, C.ink, Icons.auto_awesome),
    (C.sageTint, C.sage, Icons.eco_outlined),
    (C.amberTint, C.amber, Icons.star_border),
    (C.clayTint, C.terracotta, Icons.favorite_border),
    (C.lavenderTint, C.lavender, Icons.nightlight_outlined),
    (C.skyTint, C.sky, Icons.water_drop_outlined),
    (C.roseTint, C.rose, Icons.local_florist_outlined),
  ];
  final idx = name.hashCode.abs() % fills.length;
  return fills[idx];
}

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
}

class Api extends ChangeNotifier {
  static final Api i = Api._();
  Api._();

  late SharedPreferences _p;
  String? token, userId, boardId;
  int? age;
  List<Block> myBlocks = [];
  Set<String> liked = {};

  String _k(String s) => '$userId:$s';

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    token = _p.getString('token');
    userId = _p.getString('userId');
    if (token != null && userId != null) {
      _loadUser();
      fetchMyBoard();
    }
  }

  void _loadUser() {
    age = _p.getInt(_k('age'));
    boardId = _p.getString(_k('boardId'));
    myBlocks = (jsonDecode(_p.getString(_k('blocks')) ?? '[]') as List)
        .map((e) => Block.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    liked = (_p.getStringList(_k('liked')) ?? []).toSet();
  }

  Future<void> _saveUser() async {
    if (userId == null) return;
    if (age != null) await _p.setInt(_k('age'), age!);
    if (boardId != null) await _p.setString(_k('boardId'), boardId!);
    await _p.setString(_k('blocks'), jsonEncode(myBlocks.map((b) => b.toJson()).toList()));
    await _p.setStringList(_k('liked'), liked.toList());
  }

  Future<void> _dropSession() async {
    token = null;
    await _p.remove('token');
    await _p.remove('userId');
    userId = null;
    boardId = null;
    age = null;
    myBlocks = [];
    liked = {};
    notifyListeners();
  }

  Future<dynamic> _req(String method, String path,
      {Map<String, String>? query, Object? body, bool auth = true, bool bearer = false}) async {
    final q = {...?query, if (auth && token != null) 'access_token': token!};
    final uri = Uri.parse('$kBaseUrl$path').replace(queryParameters: q.isEmpty ? null : q);
    final headers = {
      'Content-Type': 'application/json',
      if (bearer && token != null) 'Authorization': 'Bearer $token',
    };
    final enc = body == null ? null : jsonEncode(body);
    final http.Response r;
    switch (method) {
      case 'POST':
        r = await http.post(uri, headers: headers, body: enc);
        break;
      case 'PATCH':
        r = await http.patch(uri, headers: headers, body: enc);
        break;
      case 'DELETE':
        r = await http.delete(uri, headers: headers);
        break;
      default:
        r = await http.get(uri, headers: headers);
    }
    final text = utf8.decode(r.bodyBytes);
    dynamic data;
    try {
      data = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      data = text;
    }
    if (r.statusCode >= 400) {
      if (r.statusCode == 401 && auth) await _dropSession();
      var msg = 'Error ${r.statusCode}';
      if (data is Map && data['detail'] != null) {
        msg = data['detail'] is String ? data['detail'] : jsonEncode(data['detail']);
      }
      throw ApiException(msg, r.statusCode);
    }
    return data;
  }

  // ── auth
  Future<void> _setSession(dynamic d, {int? newAge}) async {
    final t = d['access_token'];
    if (t == null) throw ApiException('Account created – confirm your email address and log in.');
    token = t;
    userId = d['user']['id'].toString();
    await _p.setString('token', token!);
    await _p.setString('userId', userId!);
    _loadUser();
    if (newAge != null) age = newAge;
    await _saveUser();
    await fetchMyBoard();
    notifyListeners();
  }

  Future<void> login(String email, String pw) async =>
      _setSession(await _req('POST', '/auth/login', body: {'email': email, 'password': pw}, auth: false));

  Future<void> register(String email, String pw, int age, String name) async => _setSession(
      await _req('POST', '/auth/register', body: {'email': email, 'password': pw, 'age': age, 'name': name}, auth: false),
      newAge: age);

  Future<void> logout() async {
    try {
      await _req('POST', '/auth/logout', auth: false, bearer: true);
    } catch (_) {}
    await _dropSession();
  }

  Future<void> deleteAccount() async {
    await _req('DELETE', '/auth/account');
    for (final s in ['age', 'boardId', 'blocks', 'liked']) {
      await _p.remove(_k(s));
    }
    await _dropSession();
  }

  // ── boards
  String? _extractId(dynamic res) {
    dynamic b = res is Map ? res['board'] : res;
    if (b is List && b.isNotEmpty) b = b.first;
    return b is Map ? b['id']?.toString() : null;
  }

  /// The backend has no PUT/GET for your own board – "editing" = delete the old one + create a new one.
  Future<void> saveBoard(List<Block> blocks) async {
    if (boardId != null) {
      try {
        await _req('DELETE', '/boards/$boardId');
      } catch (_) {}
    }
    final d = await _req('POST', '/boards', body: {'blocks': blocks.map((b) => b.toJson()).toList()});
    boardId = _extractId(d);
    myBlocks = blocks;
    await _saveUser();
  }

  /// Loads your own board from the database (e.g. after reinstall or on another device).
  Future<void> fetchMyBoard() async {
    try {
      final d = await _req('GET', '/boards/me');
      if (d is! Map) return;
      final row = Map<String, dynamic>.from(d);
      final inner = row['board'] is Map ? Map<String, dynamic>.from(row['board']) : null;
      final raw = inner?['blocks'];
      if (raw is List) {
        myBlocks = raw
            .whereType<Map>()
            .map((e) => Block.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      final id = row['id']?.toString() ?? inner?['id']?.toString();
      if (id != null) boardId = id;
      await _saveUser();
      notifyListeners();
    } catch (_) {}
  }

  Future<List<BoardCard>> discover(int lo, int hi) async {
    final d = await _req('GET', '/discover/boards', query: {'youngest': '$lo', 'oldest': '$hi'}) as List;
    return d
        .whereType<Map>()
        .map((m) => BoardCard.fromJson(Map<String, dynamic>.from(m)))
        .where((c) => c.userId.isNotEmpty && c.blocks.isNotEmpty && !liked.contains(c.userId))
        .toList();
  }

  // ── likes
  Future<Map<String, dynamic>> like(String id) async {
    try {
      final d = await _req('POST', '/likes', body: {'liked_id': id});
      liked.add(id);
      await _saveUser();
      return Map<String, dynamic>.from(d);
    } on ApiException catch (e) {
      if (e.message.contains('Already liked')) {
        liked.add(id);
        await _saveUser();
        return {'is_match': false};
      }
      rethrow;
    }
  }

  /// Saves a swipe (left = skip, right = interested) in the database.
  /// A right swipe also creates a like and checks for a match.
  Future<Map<String, dynamic>> swipe(String id, String direction) async {
    final d = await _req('POST', '/swipes', body: {'swiped_id': id, 'direction': direction});
    if (direction == 'right') {
      liked.add(id);
      await _saveUser();
    }
    return Map<String, dynamic>.from(d);
  }

  Future<void> unlike(String id) async {
    await _req('DELETE', '/likes/$id');
    liked.remove(id);
    await _saveUser();
  }

  Future<List<dynamic>> matches() async => await _req('GET', '/likes/matches') as List;

  // ── conversations / messages
  Future<List<Conv>> conversations() async =>
      (await _req('GET', '/conversations') as List).map((e) => Conv.fromJson(Map<String, dynamic>.from(e))).toList();

  Future<Conv> conversation(String id) async =>
      Conv.fromJson(Map<String, dynamic>.from(await _req('GET', '/conversations/$id')));

  Future<List<Message>> messages(String id, {int limit = 100, String? before}) async {
    final q = <String, String>{'limit': '$limit'};
    if (before != null) q['before'] = before;
    final d = await _req('GET', '/conversations/$id/messages', query: q) as List;
    return d.map((e) => Message.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> send(String id, String content) async =>
      _req('POST', '/conversations/$id/messages', body: {'content': content});

  Future<void> markRead(String id) async => _req('PATCH', '/conversations/$id/messages/read');

  Future<int> unreadCount(String id) async =>
      ((await _req('GET', '/conversations/$id/messages/unread-count'))['unread_count'] as num).toInt();

  /// Total number of unread messages (for the badge and notifications).
  Future<int> totalUnread() async =>
      ((await _req('GET', '/conversations/unread-count'))['unread_count'] as num).toInt();
}

// ───────────────────────────── START ─────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.i.load();
  runApp(const ValoresApp());
}

class ValoresApp extends StatelessWidget {
  const ValoresApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Valores',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: ListenableBuilder(
          listenable: Api.i,
          builder: (_, _) => Api.i.token == null ? const AuthScreen() : const HomeShell(),
        ),
      );
}

// ───────────────────────────── AUTH ─────────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final email = TextEditingController(), pass = TextEditingController(), nameCtrl = TextEditingController(), ageCtrl = TextEditingController();
  bool register = false, busy = false;
  late final AnimationController _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    nameCtrl.dispose();
    ageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      if (register) {
        final n = nameCtrl.text.trim();
        if (n.isEmpty) throw ApiException('Enter your name');
        final a = int.tryParse(ageCtrl.text.trim());
        if (a == null || a < 13 || a > 100) throw ApiException('Enter an age between 13 and 100');
        await Api.i.register(email.text.trim(), pass.text, a, n);
      } else {
        await Api.i.login(email.text.trim(), pass.text);
      }
    } catch (e) {
      if (mounted) toast(context, err(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeCtrl,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Image.asset('assets/logo.png', height: 150, alignment: Alignment.centerLeft),
                    const SizedBox(height: 8),
                    Text('Get to know the person before you see the face.', style: serif(18, italic: true, c: C.sage)),
                    const SizedBox(height: 32),
                    PaperCard(
                      child: Column(children: [
                        TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'E-mail',
                              prefixIcon: Icon(Icons.email_outlined, size: 20, color: C.inkSoft),
                            )),
                        const SizedBox(height: 12),
                        TextField(
                            controller: pass,
                            obscureText: true,
                            textInputAction: register ? TextInputAction.next : TextInputAction.done,
                            onSubmitted: register ? null : (_) => submit(),
                            decoration: const InputDecoration(
                              hintText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline, size: 20, color: C.inkSoft),
                            )),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: register
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(children: [
                                    TextField(
                                        controller: nameCtrl,
                                        textCapitalization: TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          hintText: 'Name',
                                          prefixIcon: Icon(Icons.person_outline, size: 20, color: C.inkSoft),
                                        )),
                                    const SizedBox(height: 12),
                                    TextField(
                                        controller: ageCtrl,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => submit(),
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        decoration: const InputDecoration(
                                          hintText: 'Age',
                                          prefixIcon: Icon(Icons.cake_outlined, size: 20, color: C.inkSoft),
                                        )),
                                  ]),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                            width: double.infinity,
                            child: Pill(register ? 'Create account' : 'Log in', onTap: submit, busy: busy)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => register = !register),
                        child: Text(register ? 'I already have an account' : "I don't have an account – sign up",
                            style: const TextStyle(color: C.terracotta)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0, chatsRev = 0;
  int unread = 0;
  bool _firstPoll = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _pollUnread();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _pollUnread());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _pollUnread() async {
    if (Api.i.token == null) return;
    try {
      final n = await Api.i.totalUnread();
      if (!mounted) return;
      if (!_firstPoll && n > unread) {
        toast(context, 'New message 💬');
      }
      _firstPoll = false;
      if (n != unread) setState(() => unread = n);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.explore_outlined, 'Discover'),
      (Icons.chat_bubble_outline, 'Chats'),
      (Icons.dashboard_outlined, 'Board'),
    ];
    return Scaffold(
      body: Stack(children: [
        SafeArea(
          bottom: false,
          child: IndexedStack(index: tab, children: [
            const DiscoverScreen(),
            ChatsScreen(key: ValueKey('chats$chatsRev')),
            const BoardScreen(),
          ]),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xE0FAF7F2),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: const Color(0xCCE8E2D9)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1424201D), blurRadius: 32, offset: Offset(0, 12), spreadRadius: -4)
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var n = 0; n < items.length; n++)
                        GestureDetector(
                          onTap: () => setState(() {
                            tab = n;
                            if (n == 1) chatsRev++;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(horizontal: tab == n ? 18 : 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: tab == n ? const Color(0x26C46244) : Colors.transparent,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Row(children: [
                              Stack(clipBehavior: Clip.none, children: [
                                Icon(items[n].$1, size: 22, color: tab == n ? C.terracotta : C.inkSoft),
                                if (n == 1 && unread > 0)
                                  Positioned(
                                    right: -6,
                                    top: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      constraints: const BoxConstraints(minWidth: 16),
                                      decoration: BoxDecoration(
                                          color: C.terracotta, borderRadius: BorderRadius.circular(9999)),
                                      child: Text(unread > 9 ? '9+' : '$unread',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                              ]),
                              if (tab == n) ...[
                                const SizedBox(width: 8),
                                Text(items[n].$2,
                                    style: GoogleFonts.dmSans(
                                        fontSize: 13, fontWeight: FontWeight.w600, color: C.terracotta)),
                              ],
                            ]),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}


class BoardTiles extends StatelessWidget {
  final List<Block> blocks;
  final void Function(int)? onTap;
  const BoardTiles(this.blocks, {super.key, this.onTap});

  Widget _tile(int i) {
    final b = blocks[i];
    final (tint, accent, icon) = blockStyle(b.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: tint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.edge)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap == null ? null : () => onTap!(i),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 6),
                Expanded(child: Text(b.name, style: serif(18, italic: true, w: FontWeight.w500))),
              ]),
              if (b.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(b.description, style: const TextStyle(fontSize: 14, height: 1.5)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = <Widget>[], r = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      (i.isEven ? l : r).add(_tile(i));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(children: l)),
      const SizedBox(width: 10),
      Expanded(child: Column(children: r)),
    ]);
  }
}


class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with TickerProviderStateMixin {
  List<BoardCard> cards = [];
  int idx = 0;
  bool loading = true;
  String? error;

  late int youngest;
  late int oldest;

  late AnimationController _swipeCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _rotateAnim;

  Offset _dragPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    final userAge = Api.i.age ?? 20;
    youngest = (userAge - 3).clamp(13, 100);
    oldest   = (userAge + 3).clamp(13, 100);

    _swipeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnim = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
        CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOut));
    _rotateAnim = Tween<double>(begin: 0, end: 0).animate(
        CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOut));

    _load();
  }

  @override
  void dispose() {
    _swipeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final c = await Api.i.discover(youngest, oldest);
      if (mounted) {
        setState(() {
          cards = c;
          idx = 0;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = err(e);
          loading = false;
        });
      }
    }
  }

  void _onPanStart(DragStartDetails d) {
    if (_swipeCtrl.isAnimating) return;
    setState(() => _dragPos = Offset.zero);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_swipeCtrl.isAnimating) return;
    setState(() {
      _dragPos += d.delta;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_swipeCtrl.isAnimating) return;
    final screenW = MediaQuery.of(context).size.width;
    final threshold = screenW * 0.3;
    final vx = d.velocity.pixelsPerSecond.dx;
    final flick = vx.abs() > 700; 

    if (_dragPos.dx > threshold || (flick && _dragPos.dx > 0)) {

      _animateOut(1, () => _like(cards[idx]), velocity: vx);
    } else if (_dragPos.dx < -threshold || (flick && _dragPos.dx < 0)) {

      _animateOut(-1, () => _skip(cards[idx]), velocity: vx);
    } else {
      _animateBack();
    }
  }

  void _animateCardTo(Offset end, double endRotation,
      {Duration duration = const Duration(milliseconds: 320), VoidCallback? onDone}) {
    if (_swipeCtrl.isAnimating) return;
    final screenW = MediaQuery.of(context).size.width;
    _slideAnim = Tween<Offset>(begin: _dragPos, end: end).animate(
        CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOutCubic));
    _rotateAnim = Tween<double>(begin: _dragPos.dx / screenW * 0.3, end: endRotation).animate(
        CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOutCubic));

    _swipeCtrl.duration = duration;
    _swipeCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      _swipeCtrl.reset();
      setState(() => _dragPos = Offset.zero);
      onDone?.call();
    });
  }

  void _animateOut(int direction, VoidCallback onDone, {double velocity = 0}) {
    final screenW = MediaQuery.of(context).size.width;

    final fast = velocity.abs() > 1500;
    _animateCardTo(
      Offset(direction * screenW * 1.5, _dragPos.dy),
      direction * 0.5,
      duration: Duration(milliseconds: fast ? 220 : 340),
      onDone: onDone,
    );
  }

  void _animateBack() {
    _animateCardTo(Offset.zero, 0);
  }

  Future<void> _skip(BoardCard c) async {
    setState(() => idx++);
    try {
      await Api.i.swipe(c.userId, 'left');
    } catch (_) {}
  }

  Future<void> _like(BoardCard c) async {
    setState(() => idx++);
    try {
      final r = await Api.i.swipe(c.userId, 'right');
      if (!mounted) return;
      if (r['is_match'] == true && r['conversation_id'] != null) {
        _showMatchDialog(r['conversation_id'].toString());
      }
    } catch (e) {
      if (mounted) toast(context, err(e));
    }
  }

  void _showMatchDialog(String convId) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.canvas,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          const Icon(Icons.celebration, color: C.amber, size: 28),
          const SizedBox(width: 8),
          Text("It's a match!", style: serif(24)),
        ]),
        content: Text("You both showed interest in each other's boards.\nYou can start chatting!",
            style: serif(16, italic: true)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Later', style: TextStyle(color: C.inkSoft))),
          Pill('Write', onTap: () => Navigator.pop(ctx, true)),
        ],
      ),
    ).then((go) {
      if (go == true && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(convId: convId)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator(color: C.terracotta));
    } else if (error != null) {
      body = Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 48, color: C.inkSoft),
        const SizedBox(height: 12),
        Text(error!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Pill('Try again', onTap: _load),
      ]));
    } else if (idx >= cards.length) {
      body = Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.explore_off_outlined, size: 48, color: C.inkSoft),
        const SizedBox(height: 12),
        Text("That's all for today.", style: serif(24, italic: true)),
        const SizedBox(height: 6),
        Text('Come back later for new boards', style: serif(14, c: C.inkSoft)),
        const SizedBox(height: 20),
        Pill('Refresh', ghost: true, onTap: _load),
      ]));
    } else {
      final c = cards[idx];
      final screenW = MediaQuery.of(context).size.width;
      body = AnimatedBuilder(
        animation: _swipeCtrl,
        builder: (_, child) {
          final offset = _swipeCtrl.isAnimating ? _slideAnim.value : _dragPos;
          final rotation = _swipeCtrl.isAnimating
              ? _rotateAnim.value
              : _dragPos.dx / screenW * 0.3;
          final likeOpacity = (offset.dx / (screenW * 0.3)).clamp(0.0, 1.0);
          final skipOpacity = (-offset.dx / (screenW * 0.3)).clamp(0.0, 1.0);

          return Stack(clipBehavior: Clip.none, children: [

          if (likeOpacity > 0)
            Positioned(
              left: 24,
              top: 24,
              child: Opacity(
                opacity: likeOpacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: C.sage,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.sage, width: 2),
                  ),
                  child: Text('+  Interested',
                      style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          if (skipOpacity > 0)
            Positioned(
              right: 24,
              top: 24,
              child: Opacity(
                opacity: skipOpacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: C.terracotta,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.terracotta, width: 2),
                  ),
                  child: Text('Skip',
                      style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          // Card
          Transform.translate(
            offset: offset,
            child: Transform.rotate(
              angle: rotation,
              child: child,
            ),
          ),
          ]);
        },
        child: GestureDetector(
          onHorizontalDragStart: _onPanStart,
          onHorizontalDragUpdate: _onPanUpdate,
          onHorizontalDragEnd: _onPanEnd,
          onHorizontalDragCancel: () {
            if (!_swipeCtrl.isAnimating) _animateBack();
          },
          child: PaperCard(
            color: C.linen,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (c.name != null || c.age != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (c.name != null)
                      Flexible(child: Text(c.name!, style: serif(26, w: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                    if (c.age != null) ...[
                      const SizedBox(width: 8),
                      Text('${c.age}', style: serif(20, italic: true, c: C.sage)),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Expanded(child: SingleChildScrollView(child: BoardTiles(c.blocks))),
            ]),
          ),
        ),
      );
    }
    final hasCard = !loading && error == null && idx < cards.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Header('Discover', 'boards instead of photos',
              trailing: IconButton(
                icon: const Icon(Icons.settings_outlined, color: C.inkSoft),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              )),
        ),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: body)),
        if (hasCard)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _RoundButton(
                icon: Icons.close,
                color: C.terracotta,
                onTap: () => _animateOut(-1, () => _skip(cards[idx])),
              ),
              const SizedBox(width: 24),
              _RoundButton(
                icon: Icons.add,
                color: C.sage,
                large: true,
                onTap: () => _animateOut(1, () => _like(cards[idx])),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool large;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.color, required this.onTap, this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 64.0 : 52.0;
    final iconSize = large ? 32.0 : 24.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: C.paper,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Settings', style: serif(24)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: C.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          PaperCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: C.amberTint,
                    shape: BoxShape.circle,
                    border: Border.all(color: C.edge),
                  ),
                  child: const Icon(Icons.person_outline, color: C.amber, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Your account', style: serif(20, w: FontWeight.w500)),
                    if (Api.i.age != null)
                      Text('Age: ${Api.i.age}', style: const TextStyle(color: C.inkSoft, fontSize: 13)),
                  ]),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          PaperCard(
            color: C.linen,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.dns_outlined, size: 20, color: C.inkSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Server', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: C.inkSoft)),
                  const SizedBox(height: 2),
                  Text(kBaseUrl, style: GoogleFonts.firaCode(fontSize: 12, color: C.ink)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          _SettingsTile(
            icon: Icons.logout,
            iconColor: C.ink,
            title: 'Log out',
            subtitle: 'You can come back anytime',
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: C.canvas,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Text('Log out?', style: serif(24)),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    Pill('Log out', onTap: () => Navigator.pop(ctx, true)),
                  ],
                ),
              );
              if (ok == true) {
                await Api.i.logout();
                if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.delete_outline,
            iconColor: C.terracotta,
            title: 'Delete account',
            titleColor: C.terracotta,
            subtitle: 'Your account and data will be permanently deleted',
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: C.canvas,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Text('Delete account?', style: serif(24)),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Your account and all data will be permanently deleted. This action cannot be undone.'),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.roseTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber, color: C.rose, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('You will lose your board, chats and matches.',
                            style: TextStyle(fontSize: 13, color: C.rose))),
                      ]),
                    ),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: C.terracotta, shape: const StadiumBorder()),
                      child: const Text('Delete account', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                try {
                  await Api.i.deleteAccount();
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                } catch (e) {
                  if (context.mounted) toast(context, err(e));
                }
              }
            },
          ),
          const SizedBox(height: 32),
          Center(child: Text('Valores v1.0', style: serif(12, c: C.inkSoft))),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor = C.ink,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: C.paper,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: titleColor)),
                  Text(subtitle, style: const TextStyle(color: C.inkSoft, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: C.inkSoft),
            ]),
          ),
        ),
      );
}

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<Conv> list = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await Api.i.conversations();
      if (mounted) {
        setState(() {
          list = l;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = err(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const Align(alignment: Alignment.centerLeft, child: Header('Chats', 'people who chose you too')),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: C.terracotta))
              : error != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cloud_off, size: 48, color: C.inkSoft),
                      const SizedBox(height: 12),
                      Text(error!),
                    ]))
                  : RefreshIndicator(
                      color: C.terracotta,
                      onRefresh: _load,
                      child: list.isEmpty
                          ? ListView(children: [
                              Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Center(
                                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.chat_bubble_outline, size: 48, color: C.inkSoft),
                                    const SizedBox(height: 12),
                                    Text('Nothing here yet.', style: serif(20, italic: true)),
                                    const SizedBox(height: 6),
                                    Text('Browse boards and look for matches!',
                                        style: serif(14, c: C.inkSoft)),
                                  ])))
                            ])
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                              itemCount: list.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (_, n) {
                                final c = list[n];
                                return GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => ChatScreen(convId: c.id, title: c.nickname)));
                                    _load();
                                  },
                                  child: PaperCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(children: [
                                      // Avatar with initial
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: C.sageTint,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: C.edge),
                                        ),
                                        child: Center(
                                          child: Text(
                                            (c.nickname ?? '?')[0].toUpperCase(),
                                            style: serif(20, w: FontWeight.w600, c: C.sage),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(c.nickname ?? 'Unknown person', style: serif(18, w: FontWeight.w500)),
                                          if (c.lastText != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(c.lastText!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(color: C.inkSoft, fontSize: 14)),
                                            ),
                                        ]),
                                      ),
                                      if (c.unread > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: C.amber, borderRadius: BorderRadius.circular(9999)),
                                          child: Text('${c.unread}',
                                              style: const TextStyle(
                                                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                                        ),
                                    ]),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ]);
}

class ChatScreen extends StatefulWidget {
  final String convId;
  final String? title;
  const ChatScreen({super.key, required this.convId, this.title});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Message> msgs = [];
  bool loading = true;
  final ctrl = TextEditingController();
  Timer? timer;
  late String title = widget.title ?? 'Chat';

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
    if (widget.title == null) {
      Api.i.conversation(widget.convId).then((c) {
        if (mounted && c.nickname != null) setState(() => title = c.nickname!);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final l = await Api.i.messages(widget.convId);
      l.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      if (!mounted) return;
      final unread = l.any((m) => m.senderId != Api.i.userId && m.status == 'unread');
      setState(() {
        msgs = l;
        loading = false;
      });
      if (unread) Api.i.markRead(widget.convId).catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      if (!silent) toast(context, err(e));
    }
  }

  Future<void> _send() async {
    final t = ctrl.text.trim();
    if (t.isEmpty) return;
    ctrl.clear();
    try {
      await Api.i.send(widget.convId, t);
      await _load();
    } catch (e) {
      ctrl.text = t;
      if (mounted) toast(context, err(e));
    }
  }

  String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final rev = msgs.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: C.sageTint,
              shape: BoxShape.circle,
              border: Border.all(color: C.edge),
            ),
            child: Center(
              child: Text(title[0].toUpperCase(), style: serif(14, w: FontWeight.w600, c: C.sage)),
            ),
          ),
          const SizedBox(width: 10),
          Text(title, style: serif(22)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: C.terracotta))
              : rev.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.waving_hand, size: 40, color: C.amber),
                      const SizedBox(height: 12),
                      Text('Say hi ✦', style: serif(20, italic: true)),
                    ]))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: rev.length,
                      itemBuilder: (_, n) {
                        final m = rev[n];
                        final mine = m.senderId == Api.i.userId;
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: mine ? C.terracotta : C.paper,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(mine ? 16 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 16),
                              ),
                              border: mine ? null : Border.all(color: C.edge),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(m.content,
                                    style: TextStyle(color: mine ? Colors.white : C.ink, fontSize: 15, height: 1.4)),
                                const SizedBox(height: 2),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(_hm(m.sentAt),
                                      style: TextStyle(color: mine ? const Color(0xB3FFFFFF) : C.inkSoft, fontSize: 10)),
                                  if (mine) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      m.status == 'read' ? Icons.done_all : Icons.done,
                                      size: 12,
                                      color: const Color(0xB3FFFFFF),
                                    ),
                                  ],
                                ]),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: C.canvas,
              border: Border(top: BorderSide(color: C.edge.withValues(alpha: 0.5))),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 5000,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: InputDecoration(
                    hintText: 'Write a message…',
                    filled: true,
                    fillColor: C.linen,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _send,
                style: IconButton.styleFrom(backgroundColor: C.terracotta),
                icon: const Icon(Icons.arrow_upward, color: Colors.white),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late List<Block> blocks = Api.i.myBlocks.map((b) => Block(b.name, b.description)).toList();
  bool dirty = false, saving = false;

  Future<void> _edit([int? i]) async {
    final res = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BlockSheet(i == null ? null : blocks[i]),
    );
    if (res == null) return;
    setState(() {
      if (res == 'delete' && i != null) {
        blocks.removeAt(i);
      } else if (res is Block) {
        i == null ? blocks.add(res) : blocks[i] = res;
      }
      dirty = true;
    });
  }

  Future<void> _save() async {
    if (blocks.isEmpty) return toast(context, 'Add at least one block');
    setState(() => saving = true);
    try {
      await Api.i.saveBoard(blocks);
      if (mounted) {
        setState(() => dirty = false);
        toast(context, 'Board published ✓');
      }
    } catch (e) {
      if (mounted) toast(context, err(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
        children: [
          Header('My board', 'Your life in a few tiles',
              trailing: IconButton(
                icon: const Icon(Icons.settings_outlined, color: C.inkSoft),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              )),
          if (blocks.isEmpty)
            PaperCard(
              child: Column(children: [
                const Icon(Icons.dashboard_customize_outlined, size: 40, color: C.inkSoft),
                const SizedBox(height: 12),
                Text('Create your board', style: serif(20, w: FontWeight.w500)),
                const SizedBox(height: 6),
                Text('Add blocks describing your values, interests, favourite films, books and much more.',
                    textAlign: TextAlign.center,
                    style: serif(14, italic: true, c: C.inkSoft)),
              ]),
            )
          else
            BoardTiles(blocks, onTap: _edit),
          const SizedBox(height: 12),
          Row(children: [
            Pill('+ Add block', ghost: true, onTap: () => _edit()),
            const SizedBox(width: 12),
            if (dirty) Pill('Publish', busy: saving, onTap: _save),
          ]),
          if (blocks.isNotEmpty && !dirty) ...[
            const SizedBox(height: 16),
            Center(
              child: Text('Board is published ✓', style: serif(13, italic: true, c: C.sage)),
            ),
          ],
        ],
      );
}

class _BlockSheet extends StatefulWidget {
  final Block? block;
  const _BlockSheet(this.block);
  @override
  State<_BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends State<_BlockSheet> {
  late final name = TextEditingController(text: widget.block?.name);
  late final desc = TextEditingController(text: widget.block?.description);
  String? _selectedHint;

  @override
  void initState() {
    super.initState();
    if (widget.block != null) {
      for (final s in kBlockSuggestions) {
        if (s.name.toLowerCase() == widget.block!.name.toLowerCase()) {
          _selectedHint = s.hint;
          break;
        }
      }
    }
    name.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final lower = name.text.toLowerCase().trim();
    String? hint;
    for (final s in kBlockSuggestions) {
      if (s.name.toLowerCase() == lower) {
        hint = s.hint;
        break;
      }
    }
    if (hint != _selectedHint) {
      setState(() => _selectedHint = hint);
    }
  }

  @override
  void dispose() {
    name.removeListener(_onNameChanged);
    name.dispose();
    desc.dispose();
    super.dispose();
  }

  void _selectSuggestion(BlockSuggestion s) {
    setState(() {
      name.text = s.name;
      _selectedHint = s.hint;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: C.edge, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.block == null ? 'New block' : 'Edit block', style: serif(26)),
          const SizedBox(height: 4),
          Text(widget.block == null ? 'Choose a category or create your own' : 'Change the content your way',
              style: serif(14, italic: true, c: C.inkSoft)),
          const SizedBox(height: 14),
          // Suggestions with icons and colours
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in kBlockSuggestions)
              GestureDetector(
                onTap: () => _selectSuggestion(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: name.text.toLowerCase() == s.name.toLowerCase() ? s.color : s.tint,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: name.text.toLowerCase() == s.name.toLowerCase() ? s.color : C.edge,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.icon, size: 14,
                        color: name.text.toLowerCase() == s.name.toLowerCase() ? Colors.white : s.color),
                    const SizedBox(width: 4),
                    Text(s.name,
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: name.text.toLowerCase() == s.name.toLowerCase() ? Colors.white : C.ink)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: name,
            decoration: const InputDecoration(hintText: 'Block title (or type your own)'),
          ),
          const SizedBox(height: 10),
          TextField(
              controller: desc,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: _selectedHint ?? 'Describe it your way…',
              )),
          const SizedBox(height: 16),
          Row(children: [
            if (widget.block != null)
              TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  icon: const Icon(Icons.delete_outline, size: 18, color: C.terracotta),
                  label: const Text('Delete', style: TextStyle(color: C.terracotta))),
            const Spacer(),
            Pill('Save', onTap: () {
              if (name.text.trim().isEmpty) {
                toast(context, 'Enter a block title');
                return;
              }
              Navigator.pop(context, Block(name.text.trim(), desc.text.trim()));
            }),
          ]),
        ]),
      );
}