import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback;
import 'config.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase, FirebaseOptions;
import 'package:firebase_messaging/firebase_messaging.dart' show FirebaseMessaging;

part 'pro.dart';
part 'patient.dart';
part 'push.dart';

SupabaseClient get db => Supabase.instance.client;

const slots = ['Matin (7h–10h)', 'Fin de matinée (10h–12h)', 'Après-midi (14h–17h)'];
const statusFr = {'pending': 'En attente', 'accepted': 'Acceptée', 'en_route': 'Préleveur en route', 'arrived': 'Préleveur arrivé', 'collected': 'Prélèvement fait', 'done': 'Terminée', 'cancelled': 'Annulée'};

List<Map<String, dynamic>> rows(dynamic d) => List<Map<String, dynamic>>.from(d as List);
Widget logoutBtn() => Row(mainAxisSize: MainAxisSize.min, children: [const BellBtn(), IconButton(icon: const Icon(Icons.logout), tooltip: 'Se déconnecter', onPressed: () => signOutAll())]);

const navy = Color(0xFF123C80), lime = Color(0xFF7AB51D), limeLight = Color(0xFF9FD43A), pale = Color(0xFFC9D8F0), soft = Color(0xFFF3F7FB);
final lang = ValueNotifier<String>('fr');
final freshLogin = ValueNotifier<bool>(false);
final notifReq = ValueNotifier<bool>(true), notifMsg = ValueNotifier<bool>(true);
String gUrl = '', gKey = '';
String t(String fr, String en) => lang.value == 'en' ? en : fr;
String cleanUrl(String s) => RegExp(r'https://[A-Za-z0-9\-]+\.supabase\.co').firstMatch(s)?.group(0) ?? '';
String cleanKey(String s) => s.replaceAll(RegExp(r'[\s"]'), '');
String techEmail(String phone) {
  final p = kTechEmail.split('@');
  return '${p[0]}+${digits(normPhone(phone))}@${p[1]}';
}
bool notifOn(Map<String, dynamic> x) => x['title'] == 'Nouveau message' ? notifMsg.value : notifReq.value;
Future<void> setLang(String l) async {
  lang.value = l;
  (await SharedPreferences.getInstance()).setString('lang', l);
}
String frErr(String m) {
  final l = m.toLowerCase();
  if (l.contains('invalid login')) return t('Numéro ou mot de passe incorrect.', 'Wrong number or password.');
  if (l.contains('already registered')) return t('Ce numéro a déjà un compte : connectez-vous.', 'This number already has an account: sign in.');
  if (l.contains('password')) return t('Mot de passe trop court (6 caractères minimum).', 'Password too short (6 characters minimum).');
  if (l.contains('rate limit')) return t('Trop de tentatives : réessayez dans quelques minutes.', 'Too many attempts: try again in a few minutes.');
  return m;
}
String spaceName(dynamic role) => {
      'patient': t('Espace patient', 'Patient space'),
      'superadmin': 'Super Administrateur',
      'promoteur': 'Promoteur',
      'major': t('Espace laboratoire', 'Laboratory space'),
      'preleveur': t('Espace laboratoire', 'Laboratory space'),
      'imagerie': t('Espace imagerie médicale', 'Medical imaging space'),
    }[role] ?? '$role';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final pr = await SharedPreferences.getInstance();
  lang.value = pr.getString('lang') ?? 'fr';
  notifReq.value = pr.getBool('notifReq') ?? true;
  notifMsg.value = pr.getBool('notifMsg') ?? true;
  gUrl = cleanUrl(kSupabaseUrl);
  gKey = cleanKey(kSupabaseKey);
  if (gUrl.isEmpty || gKey.length < 40) {
    runApp(const ConfigError('L’adresse ou la clé Supabase est absente ou incorrecte dans le fichier lib/config.dart.'));
    return;
  }
  try {
    await Supabase.initialize(url: gUrl, anonKey: gKey);
  } catch (e) {
    runApp(ConfigError('$e'));
    return;
  }
  watchPush();
  runApp(const StVictorApp());
}

class ConfigError extends StatelessWidget {
  final String msg;
  const ConfigError(this.msg, {super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.settings_suggest, size: 64, color: navy),
                const SizedBox(height: 12),
                const Text('Configuration à compléter', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(msg, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text('Ouvrez lib/config.dart sur GitHub, collez l’adresse et la clé de votre projet Supabase, puis refabriquez l’application.', textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}

class StVictorApp extends StatelessWidget {
  const StVictorApp({super.key});
  @override
  Widget build(BuildContext c) => ValueListenableBuilder<String>(
        valueListenable: lang,
        builder: (c, _, __) => MaterialApp(
          scaffoldMessengerKey: appMessenger,
          title: 'Saint-Victor',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: navy).copyWith(primary: navy, secondary: lime),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white, surfaceTintColor: navy),
          ),
          home: const SplashPage(),
        ),
      );
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Gate()));
    });
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: navy,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 150, height: 150, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), padding: const EdgeInsets.all(16), child: Image.asset('assets/logo.png')),
              const SizedBox(height: 24),
              Text(t('BIENVENUE', 'WELCOME'), style: const TextStyle(color: limeLight, letterSpacing: 2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(t('au Centre d’Imagerie et d’Analyse Médicale', 'to the Medical Imaging and Analysis Center'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Saint-Victor de Bafia', textAlign: TextAlign.center, style: TextStyle(color: limeLight, fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Text(t('Voir juste, diagnostiquer mieux, soigner efficacement', 'See clearly, diagnose better, care effectively'), textAlign: TextAlign.center, style: const TextStyle(color: pale)),
              const SizedBox(height: 32),
              const SizedBox(width: 130, child: LinearProgressIndicator(color: limeLight, backgroundColor: Colors.white24)),
            ]),
          ),
        ),
      );
}

class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext c) => StreamBuilder<AuthState>(
        stream: db.auth.onAuthStateChange,
        builder: (c, _) {
          if (db.auth.currentSession == null) return const AuthPage();
          return ValueListenableBuilder<bool>(valueListenable: freshLogin, builder: (c, f, __) => f ? const WelcomeAfter() : const UpdateGuard(child: Home()));
        },
      );
}

class WelcomeAfter extends StatefulWidget {
  const WelcomeAfter({super.key});
  @override
  State<WelcomeAfter> createState() => _WelcomeAfterState();
}

class _WelcomeAfterState extends State<WelcomeAfter> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) freshLogin.value = false;
    });
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        body: FutureBuilder<Map<String, dynamic>>(
          future: db.from('profiles').select('full_name, role').eq('id', db.auth.currentUser!.id).single(),
          builder: (c, s) {
            final name = s.hasData ? '${s.data!['full_name'] ?? ''}' : '';
            final role = s.hasData ? s.data!['role'] : 'patient';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 96, height: 96, decoration: const BoxDecoration(color: Color(0xFFE2F2C8), shape: BoxShape.circle), child: const Icon(Icons.verified_user, size: 48, color: Color(0xFF2F5A00))),
                  const SizedBox(height: 16),
                  Text(t('Connexion réussie', 'Signed in'), style: const TextStyle(color: Color(0xFF5A6B82))),
                  const SizedBox(height: 8),
                  Text(t('Bienvenue,', 'Welcome,'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)),
                  Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)),
                  const SizedBox(height: 12),
                  Chip(label: Text(spaceName(role)), backgroundColor: const Color(0xFFE2F2C8)),
                  const SizedBox(height: 28),
                  FilledButton(onPressed: () => freshLogin.value = false, child: Text(t('Continuer', 'Continue'))),
                ]),
              ),
            );
          },
        ),
      );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final pass = TextEditingController(), name = TextEditingController(), phone = TextEditingController();
  bool signup = false, busy = false, ok = false, hide = true;
  late final Future<String> health = _health();

  Future<String> _health() async {
    try {
      final r = await http.get(Uri.parse('$gUrl/auth/v1/health'), headers: {'apikey': gKey}).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return 'ok';
      if (r.statusCode == 401 || r.statusCode == 403) return 'key';
      return 'down';
    } catch (_) {
      return 'net';
    }
  }

  void msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> submit() async {
    if (digits(phone.text).length < 8 || pass.text.length < 6) {
      msg(t('Numéro de téléphone et mot de passe (6 caractères minimum) requis.', 'Phone number and password (6 characters minimum) required.'));
      return;
    }
    if (signup && (name.text.trim().isEmpty || !ok)) {
      msg(t('Indiquez votre nom et acceptez les conditions.', 'Enter your name and accept the conditions.'));
      return;
    }
    setState(() => busy = true);
    freshLogin.value = true;
    try {
      final email = techEmail(phone.text);
      if (signup) {
        final r = await db.auth.signUp(email: email, password: pass.text, data: {'full_name': name.text.trim(), 'phone': normPhone(phone.text)});
        if (r.session == null) {
          freshLogin.value = false;
          msg('Compte créé, mais Supabase demande une confirmation : désactivez « Confirm email » (Authentication, Sign In / Providers, Email).');
        }
      } else {
        await db.auth.signInWithPassword(email: email, password: pass.text);
      }
    } on AuthException catch (e) {
      freshLogin.value = false;
      msg(frErr(e.message));
    } catch (e) {
      freshLogin.value = false;
      msg(t('Connexion impossible. Vérifiez votre accès Internet.', 'Cannot connect. Check your Internet access.'));
    }
    if (mounted) setState(() => busy = false);
  }

  Widget langChip(String code) => ChoiceChip(
        label: Text(code.toUpperCase()),
        selected: lang.value == code,
        onSelected: (_) async {
          await setLang(code);
          if (mounted) setState(() {});
        },
      );

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: soft,
        body: SingleChildScrollView(
          child: Column(children: [
            Container(
              width: double.infinity,
              color: navy,
              padding: const EdgeInsets.fromLTRB(24, 50, 24, 30),
              child: Column(children: [
                Align(alignment: Alignment.centerRight, child: Row(mainAxisSize: MainAxisSize.min, children: [langChip('fr'), const SizedBox(width: 6), langChip('en')])),
                Container(width: 96, height: 96, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), padding: const EdgeInsets.all(10), child: Image.asset('assets/logo.png')),
                const SizedBox(height: 10),
                const Text('Saint-Victor de Bafia', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                Text(signup ? t('Créer votre compte', 'Create your account') : t('Connexion à votre espace', 'Sign in to your space'), style: const TextStyle(color: pale)),
              ]),
            ),
            Container(
              margin: const EdgeInsets.all(18),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x1F123C80), blurRadius: 10, offset: Offset(0, 3))]),
              child: Column(children: [
                if (signup) TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: t('Nom complet', 'Full name'))),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: t('Numéro de téléphone', 'Phone number'), hintText: '692024812')),
                TextField(
                  controller: pass,
                  obscureText: hide,
                  decoration: InputDecoration(labelText: t('Mot de passe', 'Password'), suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide))),
                ),
                if (signup)
                  CheckboxListTile(
                    value: ok,
                    onChanged: (v) => setState(() => ok = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('J’accepte que mes informations soient utilisées par le centre pour organiser mon prélèvement ou mon rendez-vous.', 'I agree that my information is used by the center to organize my sampling or appointment.'), style: const TextStyle(fontSize: 13)),
                  ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(signup ? t('Créer mon compte', 'Create my account') : t('Se connecter', 'Sign in')))),
                TextButton(onPressed: () => setState(() => signup = !signup), child: Text(signup ? t('J’ai déjà un compte', 'I already have an account') : t('Créer un compte', 'Create an account'))),
              ]),
            ),
            FutureBuilder<String>(
              future: health,
              builder: (c, s) {
                final v = s.data;
                final good = v == 'ok';
                final text = v == null
                    ? t('Vérification du serveur…', 'Checking server…')
                    : good
                        ? t('Serveur connecté', 'Server connected')
                        : v == 'key'
                            ? t('Clé de l’application refusée : vérifiez lib/config.dart', 'Application key rejected: check lib/config.dart')
                            : t('Serveur injoignable : vérifiez Internet', 'Server unreachable: check Internet');
                return Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: TextStyle(fontSize: 12, color: v == null ? const Color(0xFF5A6B82) : good ? const Color(0xFF2F5A00) : Colors.red.shade800)));
              },
            ),
            const Padding(padding: EdgeInsets.fromLTRB(0, 6, 0, 20), child: Text('Développé par TSOPBEING Loic', style: TextStyle(fontSize: 12, color: Color(0xFF5A6B82)))),
          ]),
        ),
      );
}

void snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> run(BuildContext c, Future<dynamic> Function() f, [String? ok]) async {
  try {
    await f();
    if (ok != null && c.mounted) snack(c, ok);
    return true;
  } on PostgrestException catch (e) {
    if (c.mounted) snack(c, e.message);
    return false;
  }
}

Future<String?> ask(BuildContext c, String title, String label) {
  final t = TextEditingController();
  return showDialog<String>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(controller: t, decoration: InputDecoration(labelText: label)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(d, t.text.trim()), child: const Text('OK')),
      ],
    ),
  );
}

Future<List<Map<String, dynamic>>> q(Future<dynamic> b) async => rows(await b);

Widget load(Future<List<Map<String, dynamic>>> f, Widget Function(List<Map<String, dynamic>>) b) =>
    FutureBuilder<List<Map<String, dynamic>>>(
      future: f,
      builder: (c, s) {
        if (s.hasError) return Center(child: Text('Erreur : ${s.error}'));
        if (!s.hasData) return const ShimmerList();
        return b(s.data!);
      },
    );

Widget lst(List<Widget> ch, Future<void> Function() refresh) => RefreshIndicator(
      onRefresh: refresh,
      child: ListView(children: ch.isEmpty ? [const Padding(padding: EdgeInsets.all(24), child: Text('Rien à afficher pour le moment.'))] : ch),
    );

const disciplines = ['Biochimie', 'Hématologie', 'Bactériologie', 'Parasitologie', 'Immuno-sérologie', 'Imagerie - Radiographie', 'Imagerie - Échographie'];
const reqSel = '*, patient:profiles!patient_id(full_name, phone)';

List<Widget> reqInfo(Map<String, dynamic> r) {
  final p = (r['patient'] ?? {}) as Map;
  return [
    Text("${p['full_name'] ?? 'Patient'} — ${p['phone'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
    Text((r['exam_names'] as List).join(', ')),
    Text('${r['quarter']} · ${r['address']}'),
    Text('${r['wanted_date']} · ${r['slot']} — ${statusFr[r['status']] ?? r['status']}'),
  ];
}

String mapsUrl(Map<String, dynamic> r) {
  final place = r['lat'] != null ? '${r['lat']},${r['lng']}' : '${r['address']}, ${r['quarter']}';
  return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(place)}';
}

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext c) => FutureBuilder<Map<String, dynamic>>(
        future: db.from('profiles').select().eq('id', db.auth.currentUser!.id).single(),
        builder: (c, s) {
          if (s.hasError) return Scaffold(appBar: AppBar(actions: [logoutBtn()]), body: Center(child: Text('Erreur : ${s.error}')));
          if (!s.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final p = s.data!;
          switch (p['role']) {
            case 'superadmin':
              return const SuperShell();
            case 'promoteur':
              return const DirectionPage();
            case 'major':
            case 'preleveur':
              return LabSpace(lab: p['lab_id']);
            case 'imagerie':
              return ImagerieSpace(lab: p['lab_id']);
            default:
              return AppLock(child: Onboarding(child: ConsentGate(child: PatientPage(favLab: p['fav_lab_id']))));
          }
        },
      );
}

// ---------- PATIENT ----------
Widget box(List<Widget> ch) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x1F123C80), blurRadius: 8, offset: Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: ch),
    );

Widget homeTile(IconData ic, String title, String sub, Color col, VoidCallback? onTap) => Material(
      color: Colors.white,
      elevation: 1.5,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(12)), child: Icon(ic, color: Colors.white)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B82))),
          ]),
        ),
      ),
    );

class PatientPage extends StatefulWidget {
  final String? favLab;
  const PatientPage({super.key, this.favLab});
  @override
  State<PatientPage> createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  String? lab;
  int tab = 0;
  String name = '';

  @override
  void initState() {
    super.initState();
    lab = widget.favLab;
    _init();
  }

  Future<void> _init() async {
    try {
      final me = await db.from('profiles').select('full_name').eq('id', db.auth.currentUser!.id).single();
      name = '${me['full_name'] ?? ''}';
      if (lab == null) {
        final l = await db.from('labs').select('id').eq('active', true).order('created_at').limit(1);
        if ((l as List).isNotEmpty) {
          lab = l.first['id'];
          await db.from('profiles').update({'fav_lab_id': lab}).eq('id', db.auth.currentUser!.id);
        }
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) => ProShell(
        title: '${greet()}${name.isEmpty ? '' : ', ${name.split(' ').first}'}',
        subtitle: t('Espace patient · Saint-Victor de Bafia', 'Patient space · Saint-Victor de Bafia'),
        items: [
          NavItem(Icons.home_rounded, t('Accueil', 'Home')),
          NavItem(Icons.add_circle_rounded, t('Commander', 'Order')),
          NavItem(Icons.assignment_rounded, t('Demandes', 'Requests')),
          NavItem(Icons.image_rounded, t('Résultats', 'Results')),
        ],
        pages: (go) => [
          PatientHome(go: go, name: name),
          OrderTab(key: ValueKey(lab), lab: lab, go: go),
          MyRequestsTab(go: go),
          const ResultsTab(),
        ],
        hub: (c, go) => [
          HubAction(Icons.add_circle_rounded, t('Commander', 'Order'), lime, () => go(1)),
          HubAction(Icons.call_rounded, t('Appeler', 'Call'), teal, () => callCenter(c)),
          HubAction(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25A244), () => whatsappCenter(c)),
          HubAction(Icons.settings_rounded, t('Paramètres', 'Settings'), navy, () => pushPage(c, t('Paramètres', 'Settings'), const SettingsTab())),
          notifAction(c),
          logoutAction(),
        ],
      );
}

// ---------- MAJOR ----------
class MajorPage extends StatelessWidget {
  final String? lab;
  const MajorPage({super.key, this.lab});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(t('Espace laboratoire', 'Laboratory space')), actions: [logoutBtn()]),
        body: lab == null ? const Center(child: Text('Aucun laboratoire rattaché à ce compte.')) : ServiceSpace(lab: lab!, service: 'laboratoire', manage: true, isAdmin: false),
      );
}

class MajorReqs extends StatefulWidget {
  final String lab;
  final String? service;
  const MajorReqs({super.key, required this.lab, this.service});
  @override
  State<MajorReqs> createState() => _MajorReqsState();
}

class _MajorReqsState extends State<MajorReqs> {
  Future<void> act(String id, Map<String, dynamic> v) async {
    await run(context, () => db.from('requests').update(v).eq('id', id));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) => load(q(db.from('profiles').select('id, full_name').eq('lab_id', widget.lab).eq('role', 'preleveur')), (team) =>
      load(q((widget.service == null ? db.from('requests').select(reqSel).eq('lab_id', widget.lab) : db.from('requests').select(reqSel).eq('lab_id', widget.lab).eq('service', widget.service!)).order('created_at', ascending: false)), (l) => lst([
            for (final r in l)
              Card(
                margin: const EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ...reqInfo(r),
                    if (r['status'] != 'cancelled') OutlinedButton.icon(icon: const Icon(Icons.image), label: const Text('Envoyer le résultat'), onPressed: () => sendResult(c, r)),
                    if (r['mode'] == 'centre' && ['pending', 'accepted'].contains(r['status']))
                      Wrap(spacing: 8, children: [
                        if (r['status'] == 'pending') FilledButton(onPressed: () => act(r['id'], {'status': 'accepted'}), child: const Text('Confirmer le rendez-vous')),
                        if (r['status'] == 'accepted') FilledButton(onPressed: () => act(r['id'], {'status': 'done'}), child: const Text('Examen terminé')),
                        TextButton(onPressed: () => openChat(c, r), child: const Text('Message')),
                        TextButton(onPressed: () => act(r['id'], {'status': 'cancelled'}), child: const Text('Annuler')),
                      ]),
                    if (r['mode'] != 'centre' && ['pending', 'accepted', 'en_route'].contains(r['status']))
                      Row(children: [
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text('Attribuer à un préleveur'),
                            value: team.any((t) => t['id'] == r['assigned_to']) ? r['assigned_to'] : null,
                            items: [for (final t in team) DropdownMenuItem(value: t['id'] as String, child: Text(t['full_name'] ?? 'Préleveur'))],
                            onChanged: (v) => act(r['id'], {'assigned_to': v, if (r['status'] == 'pending') 'status': 'accepted'}),
                          ),
                        ),
                        TextButton(onPressed: () => openChat(c, r), child: const Text('Message')),
                        TextButton(onPressed: () => act(r['id'], {'status': 'cancelled'}), child: const Text('Annuler')),
                      ]),
                  ]),
                ),
              ),
          ], () async => setState(() {}))));
}

class MajorExams extends StatefulWidget {
  final String lab;
  final String? service;
  const MajorExams({super.key, required this.lab, this.service});
  @override
  State<MajorExams> createState() => _MajorExamsState();
}

class _MajorExamsState extends State<MajorExams> {
  Future<void> upd(dynamic examId, Map<String, dynamic> v) async {
    await run(context, () => db.from('lab_exams').update(v).eq('lab_id', widget.lab).eq('exam_id', examId));
    if (mounted) setState(() {});
  }

  Future<void> addExam() async {
    final name = TextEditingController(), cond = TextEditingController();
    final ds = discFor(widget.service);
    String disc = ds.first;
    bool center = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, st) => AlertDialog(
          title: const Text('Ajouter un examen'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom de l’examen')),
              DropdownButtonFormField<String>(
                value: disc,
                items: [for (final x in ds) DropdownMenuItem(value: x, child: Text(x))],
                onChanged: (v) => st(() => disc = v ?? disc),
                decoration: const InputDecoration(labelText: 'Catégorie'),
              ),
              TextField(controller: cond, maxLines: 3, decoration: const InputDecoration(labelText: 'Conditions de prélèvement ou de préparation')),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: center, onChanged: (v) => st(() => center = v), title: const Text('Uniquement au centre')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Ajouter')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      await run(context, () => db.rpc('add_exam', params: {'p_name': name.text, 'p_discipline': disc, 'p_conditions': cond.text, 'p_center': center}), 'Examen ajouté.');
      if (mounted) setState(() {});
    }
  }

  Future<void> delExam(dynamic id, String nom) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Supprimer cet examen ?'),
        content: Text('« $nom » sera supprimé définitivement de la liste. Pour le cacher seulement, utilisez l’interrupteur.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (yes == true && mounted) {
      await run(context, () => db.rpc('remove_exam', params: {'p_exam': id}), 'Examen supprimé.');
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.add), label: const Text('Ajouter un examen'), onPressed: addExam),
        body: load(q((widget.service == null ? db.from('lab_exams').select('exam_id, active, custom_conditions, exams!inner(name, conditions, service)').eq('lab_id', widget.lab) : db.from('lab_exams').select('exam_id, active, custom_conditions, exams!inner(name, conditions, service)').eq('lab_id', widget.lab).eq('exams.service', widget.service!))), (l) => lst([
              for (final x in l)
                SwitchListTile(
                  value: x['active'] as bool,
                  onChanged: (v) => upd(x['exam_id'], {'active': v}),
                  title: Text(x['exams']['name']),
                  subtitle: Text('${x['custom_conditions'] ?? x['exams']['conditions']}'),
                  secondary: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final v = await ask(c, 'Conditions de prélèvement', 'Vide = conditions du catalogue');
                        if (v != null) upd(x['exam_id'], {'custom_conditions': v.isEmpty ? null : v});
                      },
                    ),
                    IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => delExam(x['exam_id'], x['exams']['name'])),
                  ]),
                ),
            ], () async => setState(() {}))),
      );
}

class Team extends StatefulWidget {
  final String lab;
  const Team({super.key, required this.lab});
  @override
  State<Team> createState() => _TeamState();
}

class _TeamState extends State<Team> {
  Future<void> go(Future<dynamic> Function() f, [String? ok]) async {
    await run(context, f, ok);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.person_add),
          label: const Text('Ajouter un préleveur'),
          onPressed: () async {
            final e = await ask(c, 'Ajouter un préleveur', 'Numéro de téléphone de son compte');
            if (e != null && e.isNotEmpty) go(() => db.rpc('assign_user', params: {'p_email': normPhone(e), 'p_role': 'preleveur', 'p_lab': widget.lab}), 'Préleveur ajouté.');
          },
        ),
        body: load(q(db.from('profiles').select('id, full_name, phone, role').eq('lab_id', widget.lab)), (l) => lst([
              ListTile(
                leading: const Icon(Icons.key),
                title: const Text('Générer un code d’invitation'),
                subtitle: const Text('À envoyer par SMS ou WhatsApp au préleveur (valable 7 jours)'),
                onTap: () async {
                  try {
                    final code = await db.rpc('create_invite');
                    if (c.mounted) {
                      await showDialog(context: c, builder: (d) => AlertDialog(title: const Text('Code d’invitation'), content: SelectableText('$code', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Fermer'))]));
                    }
                  } on PostgrestException catch (e) {
                    if (c.mounted) snack(c, e.message);
                  }
                },
              ),
              for (final p in l)
                ListTile(
                  title: Text(p['full_name'] ?? ''),
                  subtitle: Text('${roleFr(p['role'])} · ${p['phone'] ?? ''}'),
                  trailing: ['preleveur', 'imagerie'].contains(p['role'])
                      ? IconButton(icon: const Icon(Icons.person_remove), onPressed: () => go(() => db.rpc('release_user', params: {'p_user': p['id']})))
                      : null,
                ),
            ], () async => setState(() {}))),
      );
}

// ---------- PRÉLEVEUR ----------
class MissionsPage extends StatefulWidget {
  const MissionsPage({super.key});
  @override
  State<MissionsPage> createState() => _MissionsPageState();
}

class _MissionsPageState extends State<MissionsPage> {
  static const next = {
    'accepted': ['en_route', 'Me mettre en route'],
    'en_route': ['arrived', 'Je suis arrivé'],
    'arrived': ['collected', 'Prélèvement fait'],
    'collected': ['done', 'Terminer la mission'],
  };

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Mes missions'), actions: [logoutBtn()]),
        body: load(q(db.from('requests').select(reqSel).order('created_at', ascending: false)), (l) => lst([
              for (final r in l)
                Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ...reqInfo(r),
                      Wrap(spacing: 8, children: [
                        if (!['done', 'cancelled'].contains(r['status']))
                          OutlinedButton.icon(
                            icon: const Icon(Icons.map),
                            label: const Text('Ouvrir dans Google Maps'),
                            onPressed: () => launchUrl(Uri.parse(mapsUrl(r)), mode: LaunchMode.externalApplication),
                          ),
                        OutlinedButton(onPressed: () => openChat(c, r), child: const Text('Message')),
                        OutlinedButton(onPressed: () => showDistance(c, r), child: const Text('Distance')),
                        if (next[r['status']] != null)
                          FilledButton(
                            onPressed: () async {
                              await run(c, () => db.from('requests').update({'status': next[r['status']]![0]}).eq('id', r['id']));
                              if (mounted) setState(() {});
                            },
                            child: Text(next[r['status']]![1]),
                          ),
                      ]),
                    ]),
                  ),
                ),
            ], () async => setState(() {}))),
      );
}

// ---------- SUPER ADMINISTRATEUR ----------
class SuperPage extends StatefulWidget {
  const SuperPage({super.key});
  @override
  State<SuperPage> createState() => _SuperPageState();
}

class _SuperPageState extends State<SuperPage> {
  Future<void> go(Future<dynamic> Function() f, [String? ok]) async {
    await run(context, f, ok);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Super Administrateur'), actions: [logoutBtn()]),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un laboratoire'),
          onPressed: () async {
            final n = await ask(c, 'Nouveau laboratoire', 'Nom du laboratoire');
            if (n != null && n.isNotEmpty) go(() => db.rpc('create_lab', params: {'p_name': n}), 'Laboratoire créé.');
          },
        ),
        body: load(q(db.rpc('lab_stats')), (l) => lst([
              for (final x in l)
                Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(x['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${x['active'] ? 'Actif' : 'Suspendu'} · ${x['total']} demandes dont ${x['pending']} en attente'),
                      Wrap(spacing: 8, children: [
                        TextButton(
                          onPressed: () => go(() => db.rpc('set_lab_active', params: {'p_lab': x['lab_id'], 'p_active': !(x['active'] as bool)})),
                          child: Text(x['active'] ? 'Suspendre' : 'Réactiver'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Examens du centre')), body: MajorExams(lab: x['lab_id'])))),
                          child: const Text('Gérer les examens')
                        ),
                        TextButton(
                          onPressed: () async {
                            final e = await ask(c, 'Nommer un Major', 'Numéro de téléphone de son compte');
                            if (e != null && e.isNotEmpty) go(() => db.rpc('assign_user', params: {'p_email': e, 'p_role': 'major', 'p_lab': x['lab_id']}), 'Major nommé.');
                          },
                          child: const Text('Nommer un Major'),
                        ),
                      ]),
                    ]),
                  ),
                ),
            ], () async => setState(() {}))),
      );
}

// ---------- V3 : GPS, messagerie, notifications, invitation, chargement ----------
Future<Position?> myPosition(BuildContext c) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (c.mounted) snack(c, 'Activez la localisation du téléphone.');
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (c.mounted) snack(c, 'Autorisez la localisation pour l’application.');
      return null;
    }
    return await Geolocator.getCurrentPosition();
  } catch (e) {
    if (c.mounted) snack(c, 'Position indisponible.');
    return null;
  }
}

Future<void> showDistance(BuildContext c, Map<String, dynamic> r) async {
  if (r['lat'] == null) {
    snack(c, 'Le patient n’a pas partagé sa position : utilisez l’adresse et Google Maps.');
    return;
  }
  final p = await myPosition(c);
  if (p == null || !c.mounted) return;
  final km = Geolocator.distanceBetween(p.latitude, p.longitude, (r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()) / 1000;
  snack(c, 'À vol d’oiseau : ${km.toStringAsFixed(1)} km, environ ${(km / 25 * 60).ceil()} min (estimation). Pour l’itinéraire exact, ouvrez Google Maps.');
}

Future<void> redeem(BuildContext c) async {
  final code = await ask(c, 'Code d’invitation', 'Code reçu de votre laboratoire');
  if (code == null || code.isEmpty || !c.mounted) return;
  final ok = await run(c, () => db.rpc('redeem_invite', params: {'p_code': code}), 'Compte activé. Reconnectez-vous.');
  if (ok) await signOutAll();
}

void openChat(BuildContext c, Map<String, dynamic> r) => Navigator.push(
    c, MaterialPageRoute(builder: (_) => ChatPage(id: r['id'].toString(), title: (r['exam_names'] as List).join(', '))));

class ChatPage extends StatefulWidget {
  final String id, title;
  const ChatPage({super.key, required this.id, required this.title});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class BellBtn extends StatelessWidget {
  const BellBtn({super.key});
  @override
  Widget build(BuildContext c) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.from('notifications').stream(primaryKey: ['id']).eq('user_id', db.auth.currentUser!.id),
        builder: (c, s) {
          final n = (s.data ?? []).where((x) => x['read'] == false && notifOn(x)).length;
          return IconButton(
            tooltip: 'Notifications',
            icon: Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.notifications)),
            onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NotifPage())),
          );
        },
      );
}

class NotifPage extends StatefulWidget {
  const NotifPage({super.key});
  @override
  State<NotifPage> createState() => _NotifPageState();
}

class _NotifPageState extends State<NotifPage> {
  @override
  void initState() {
    super.initState();
    db.from('notifications').update({'read': true}).eq('user_id', db.auth.currentUser!.id).eq('read', false).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: db.from('notifications').stream(primaryKey: ['id']).eq('user_id', db.auth.currentUser!.id).order('created_at', ascending: false),
          builder: (c, s) {
            if (!s.hasData) return const ShimmerList();
            if (s.data!.isEmpty) return const Center(child: Text('Aucune notification.'));
            return ListView(children: [
              for (final n in s.data!.where(notifOn))
                ListTile(title: Text(n['title']), subtitle: Text('${n['body'] ?? ''}'), trailing: Text('${n['created_at']}'.substring(0, 10))),
            ]);
          },
        ),
      );
}

class ShimmerList extends StatefulWidget {
  const ShimmerList({super.key});
  @override
  State<ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<ShimmerList> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => FadeTransition(
        opacity: Tween<double>(begin: 0.3, end: 0.8).animate(a),
        child: ListView(padding: const EdgeInsets.all(12), children: [
          for (var i = 0; i < 5; i++)
            Container(height: 72, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12))),
        ]),
      );
}

// ---------- Promoteur / Super Administrateur ----------
String digits(String p) => p.replaceAll(RegExp(r'[^0-9]'), '');
String normPhone(String p) {
  final d = digits(p);
  if (p.trim().startsWith('+')) return '+$d';
  return d.length == 9 ? '+237$d' : '+$d';
}

Widget loadIn(Future<List<Map<String, dynamic>>> f, Widget Function(List<Map<String, dynamic>>) b) => FutureBuilder<List<Map<String, dynamic>>>(
      future: f,
      builder: (c, s) {
        if (s.hasError) return Text('Erreur : ${s.error}');
        if (!s.hasData) return const LinearProgressIndicator();
        return b(s.data!);
      },
    );

Widget contactTile(Map<String, dynamic> k) => ListTile(
      leading: const Icon(Icons.call),
      title: Text('${k['label']}'),
      subtitle: Text('${k['phone']}'),
      onTap: () => launchUrl(Uri.parse('tel:${k['phone']}'.replaceAll(' ', ''))),
      trailing: IconButton(
        icon: const Icon(Icons.chat),
        tooltip: 'WhatsApp',
        onPressed: () => launchUrl(Uri.parse('https://wa.me/${digits('${k['phone']}')}'), mode: LaunchMode.externalApplication),
      ),
    );

class AdminPage extends StatelessWidget {
  final bool isSuper;
  const AdminPage({super.key, required this.isSuper});
  @override
  Widget build(BuildContext c) => FutureBuilder<List<Map<String, dynamic>>>(
        future: q(db.from('labs').select('id').order('created_at').limit(1)),
        builder: (c, s) {
          if (s.hasError) return Scaffold(appBar: AppBar(actions: [logoutBtn()]), body: Center(child: Text('Erreur : ${s.error}')));
          if (!s.hasData) return const Scaffold(body: ShimmerList());
          if (s.data!.isEmpty) return Scaffold(appBar: AppBar(actions: [logoutBtn()]), body: const Center(child: Text('Aucun centre créé.')));
          final lab = s.data!.first['id'] as String;
          return DefaultTabController(
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                title: Text(isSuper ? 'Super Administrateur' : 'Promoteur'),
                actions: [logoutBtn()],
                bottom: const TabBar(labelColor: Colors.white, unselectedLabelColor: pale, indicatorColor: limeLight, isScrollable: true, tabs: [Tab(text: 'Tableau de bord'), Tab(text: 'Laboratoire'), Tab(text: 'Imagerie'), Tab(text: 'Centre')]),
              ),
              body: TabBarView(children: [const AdminHome(), ServiceSpace(lab: lab, service: 'laboratoire', manage: true, isAdmin: true, isSuper: isSuper), ServiceSpace(lab: lab, service: 'imagerie', manage: true, isAdmin: true, isSuper: isSuper), CenterAdmin(lab: lab, isSuper: isSuper)]),
            ),
          );
        },
      );
}

class CenterAdmin extends StatefulWidget {
  final String lab;
  final bool isSuper;
  const CenterAdmin({super.key, required this.lab, required this.isSuper});
  @override
  State<CenterAdmin> createState() => _CenterAdminState();
}

class _CenterAdminState extends State<CenterAdmin> {
  Future<void> go(Future<dynamic> Function() f, [String? ok]) async {
    await run(context, f, ok);
    if (mounted) setState(() {});
  }

  Future<void> nominate(String role, String title) async {
    final e = await ask(context, title, 'Numéro de téléphone de son compte (déjà créé dans l’application)');
    if (e != null && e.isNotEmpty) go(() => db.rpc('assign_user', params: {'p_email': normPhone(e), 'p_role': role, 'p_lab': widget.lab}), 'Fait.');
  }

  Future<void> addContact() async {
    final label = TextEditingController(), phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Ajouter un numéro'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: label, decoration: const InputDecoration(labelText: 'Nom (ex. Accueil, Promoteur)')),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Numéro (ex. 686863091)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Ajouter')),
        ],
      ),
    );
    if (ok == true && digits(phone.text).isNotEmpty) {
      go(() => db.from('contacts').insert({'label': label.text.trim().isEmpty ? 'Centre' : label.text.trim(), 'phone': normPhone(phone.text)}), 'Numéro ajouté.');
    }
  }

  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(12), children: [
        loadIn(q(db.rpc('lab_stats')), (l) => Column(children: [
              for (final x in l)
                Card(
                  child: ListTile(
                    title: Text(x['name']),
                    subtitle: Text('${x['active'] ? 'Actif' : 'Suspendu'} · ${x['total']} demandes dont ${x['pending']} en attente'),
                    trailing: TextButton(
                      onPressed: () => go(() => db.rpc('set_lab_active', params: {'p_lab': x['lab_id'], 'p_active': !(x['active'] as bool)})),
                      child: Text(x['active'] ? 'Suspendre' : 'Réactiver'),
                    ),
                  ),
                ),
            ])),
        const SizedBox(height: 12),
        const Text('Promoteur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Wrap(spacing: 8, children: [
          
          
          if (widget.isSuper) OutlinedButton(onPressed: () => nominate('promoteur', 'Nommer le promoteur'), child: const Text('Nommer le promoteur')),
        ]),
        loadIn(q(db.from('profiles').select('id, full_name, phone, role').inFilter('role', ['promoteur'])), (l) => Column(children: [
              for (final p in l)
                ListTile(
                  title: Text(p['full_name'] ?? ''),
                  subtitle: Text('${roleFr(p['role'])} · ${p['phone'] ?? ''}'),
                  trailing: (p['role'] != 'promoteur' || widget.isSuper)
                      ? IconButton(icon: const Icon(Icons.person_remove), tooltip: 'Retirer', onPressed: () => go(() => db.rpc('release_user', params: {'p_user': p['id']}), 'Retiré.'))
                      : null,
                ),
            ])),
        const SizedBox(height: 12),
        const Text('Numéros de contact (visibles par les patients)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        loadIn(q(db.from('contacts').select().order('id')), (l) => Column(children: [
              for (final k in l)
                ListTile(
                  leading: const Icon(Icons.call),
                  title: Text('${k['label']}'),
                  subtitle: Text('${k['phone']}'),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Retirer', onPressed: () => go(() => db.from('contacts').delete().eq('id', k['id']), 'Numéro retiré.')),
                ),
            ])),
        OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Ajouter un numéro'), onPressed: addContact),
      ]);
}

// ---------- Personnel d'imagerie ----------
String roleFr(dynamic r) => const {'promoteur': 'Promoteur', 'superadmin': 'Super Administrateur', 'imagerie': 'Imagerie médicale', 'major': 'Laboratoire', 'preleveur': 'Laboratoire'}[r] ?? '$r';

class ImagerieStaffPage extends StatelessWidget {
  final String? lab;
  const ImagerieStaffPage({super.key, this.lab});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Imagerie médicale'), actions: [logoutBtn()]),
        body: lab == null ? const Center(child: Text('Aucun centre rattaché à ce compte.')) : ServiceSpace(lab: lab!, service: 'imagerie', manage: false, isAdmin: false),
      );
}

// ---------- Tableau de bord Super Administrateur / Promoteur ----------
class AdminHome extends StatelessWidget {
  const AdminHome({super.key});
  Widget stat(String n, String l, Color col) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x1F123C80), blurRadius: 8, offset: Offset(0, 2))]),
          child: Column(children: [Text(n, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: col)), Text(l, style: const TextStyle(fontSize: 11, color: Color(0xFF5A6B82)))]),
        ),
      );

  Widget team(String title, List<String> roles, IconData ic, Color col) => box([
        Row(children: [Icon(ic, color: col), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w700))]),
        loadIn(q(db.from('profiles').select('full_name, role').inFilter('role', roles)), (l) => Column(children: [
              if (l.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Personne pour le moment.')),
              for (final p in l)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(radius: 16, backgroundColor: col, child: Text('${p['full_name'] ?? '?'}'.isEmpty ? '?' : '${p['full_name']}'.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white))),
                  title: Text('${p['full_name'] ?? ''}'),
                  subtitle: Text(roleFr(p['role'])),
                ),
            ])),
      ]);

  @override
  Widget build(BuildContext c) {
    void go(int i) => DefaultTabController.of(c).animateTo(i);
    return Container(
      color: soft,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        loadIn(q(db.from('requests').select('service, status')), (r) {
          final p = r.where((x) => x['status'] == 'pending').toList();
          final lb = p.where((x) => x['service'] == 'laboratoire').length, im = p.where((x) => x['service'] == 'imagerie').length;
          return Row(children: [stat('${p.length}', 'En attente', navy), const SizedBox(width: 10), stat('$lb', 'Laboratoire', lime), const SizedBox(width: 10), stat('$im', 'Imagerie', const Color(0xFF0E7C86))]);
        }),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: homeTile(Icons.science, 'Laboratoire', 'Demandes, résultats, équipe', navy, () => go(1))),
          const SizedBox(width: 12),
          Expanded(child: homeTile(Icons.monitor_heart, 'Imagerie', 'Rendez-vous, résultats', lime, () => go(2))),
        ]),
        const SizedBox(height: 12),
        homeTile(Icons.apartment, 'Centre', 'Promoteur, contacts, suspension', const Color(0xFF7A4BB8), () => go(3)),
        const SizedBox(height: 12),
        team('Laboratoire : Major et préleveurs', ['major', 'preleveur'], Icons.science, navy),
        team('Imagerie médicale', ['imagerie'], Icons.monitor_heart, lime),
      ]),
    );
  }
}

// ---------- Avis de mise à jour (Android) ----------
class UpdateGuard extends StatefulWidget {
  final Widget child;
  const UpdateGuard({super.key, required this.child});
  @override
  State<UpdateGuard> createState() => _UpdateGuardState();
}

class _UpdateGuardState extends State<UpdateGuard> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _check();
  }

  Future<Map<String, dynamic>?> _fromRelease() async {
    try {
      final base = 'https://github.com/$kRepo/releases/latest/download';
      final r = await http.get(Uri.parse('$base/version.txt')).timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return null;
      final n = int.tryParse(r.body.trim());
      if (n == null) return null;
      return {'build': n, 'url': '$base/SaintVictor.apk'};
    } catch (_) {
      return null;
    }
  }

  Future<void> _check() async {
    if (kPlay) return;
    try {
      var info = await _fromRelease();
      if (info == null) {
        final r = await db.from('app_config').select().eq('id', 1).limit(1);
        if ((r as List).isEmpty) return;
        info = {'build': (r.first['latest_build'] as num).toInt(), 'url': '${r.first['download_url'] ?? ''}'};
      }
      final latest = info['build'] as int;
      final url = '${info['url']}';
      if (latest > kBuild && mounted) {
        showDialog(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(t('Nouvelle version disponible', 'New version available')),
            content: Text(t('Une version plus récente de Saint-Victor est disponible. Appuyez sur « Mettre à jour », puis installez-la par-dessus l’ancienne : il n’y a rien à désinstaller et vos données sont conservées.', 'A newer version of Saint-Victor is available. Tap "Update", then install it over the old one: nothing to uninstall and your data is kept.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d), child: Text(t('Plus tard', 'Later'))),
              if (url.isNotEmpty) FilledButton(onPressed: () { Navigator.pop(d); launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }, child: Text(t('Mettre à jour', 'Update'))),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext c) => widget.child;
}

// ---------- Espaces séparés : laboratoire et imagerie ----------
List<String> discFor(String? service) => service == 'imagerie'
    ? ['Imagerie - Radiographie', 'Imagerie - Échographie']
    : service == 'laboratoire'
        ? ['Biochimie', 'Hématologie', 'Bactériologie', 'Parasitologie', 'Immuno-sérologie']
        : disciplines;
String day(dynamic s) => '$s'.substring(0, 10);

Future<bool> runAny(BuildContext c, Future<dynamic> Function() f, [String? ok]) async {
  try {
    await f();
    if (ok != null && c.mounted) snack(c, ok);
    return true;
  } catch (e) {
    if (c.mounted) snack(c, 'Erreur : $e');
    return false;
  }
}

class ServiceSpace extends StatefulWidget {
  final String lab, service;
  final bool manage, isAdmin, isSuper;
  const ServiceSpace({super.key, required this.lab, required this.service, required this.manage, required this.isAdmin, this.isSuper = false});
  @override
  State<ServiceSpace> createState() => _ServiceSpaceState();
}

class _ServiceSpaceState extends State<ServiceSpace> {
  int sub = 0;
  @override
  Widget build(BuildContext c) {
    final labels = ['Demandes', 'Résultats', if (widget.manage) 'Examens', if (widget.manage) 'Équipe'];
    final Widget body = switch (sub) {
      0 => MajorReqs(lab: widget.lab, service: widget.service),
      1 => ResultsStaff(service: widget.service),
      2 => MajorExams(lab: widget.lab, service: widget.service),
      _ => StaffList(lab: widget.lab, service: widget.service, isAdmin: widget.isAdmin),
    };
    return Column(children: [
      SizedBox(
        height: 54,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(10), children: [
          for (var i = 0; i < labels.length; i++) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(labels[i]), selected: sub == i, onSelected: (_) => setState(() => sub = i))),
        ]),
      ),
      Expanded(child: body),
    ]);
  }
}

class StaffList extends StatefulWidget {
  final String lab, service;
  final bool isAdmin;
  const StaffList({super.key, required this.lab, required this.service, required this.isAdmin});
  @override
  State<StaffList> createState() => _StaffListState();
}

class _StaffListState extends State<StaffList> {
  Future<void> go(Future<dynamic> Function() f, [String? ok]) async {
    await run(context, f, ok);
    if (mounted) setState(() {});
  }

  Future<void> add(String role, String title) async {
    final e = await ask(context, title, 'Numéro de téléphone de son compte');
    if (e != null && e.isNotEmpty) go(() => db.rpc('assign_user', params: {'p_email': normPhone(e), 'p_role': role, 'p_lab': widget.lab}), 'Fait.');
  }

  Future<void> invite() async {
    try {
      final code = await db.rpc('create_invite');
      if (mounted) {
        await showDialog(context: context, builder: (d) => AlertDialog(title: const Text('Code d’invitation'), content: SelectableText('$code', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Fermer'))]));
      }
    } on PostgrestException catch (e) {
      if (mounted) snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) {
    final lab = widget.service == 'laboratoire';
    final title = lab ? 'Ajouter un agent du laboratoire' : 'Ajouter du personnel d’imagerie';
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (widget.isAdmin)
        FilledButton.icon(icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(title), onPressed: () => add(lab ? 'major' : 'imagerie', title)),
      if (widget.isAdmin) const Padding(padding: EdgeInsets.only(top: 6), child: Text('La personne doit d’abord créer son compte dans l’application. Vous saisissez ensuite son numéro de téléphone.', style: TextStyle(fontSize: 12, color: Color(0xFF5A6B82)))),
      loadIn(q(db.from('profiles').select('id, full_name, phone, role').eq('lab_id', widget.lab).inFilter('role', lab ? ['major', 'preleveur'] : ['imagerie'])), (l) => Column(children: [
            if (l.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('Personne pour le moment.')),
            for (final p in l)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: navy, child: Text('${p['full_name'] ?? '?'}'.isEmpty ? '?' : '${p['full_name']}'.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white))),
                title: Text('${p['full_name'] ?? ''}'),
                subtitle: Text('${roleFr(p['role'])} · ${p['phone'] ?? ''}'),
                trailing: widget.isAdmin ? IconButton(icon: const Icon(Icons.person_remove), tooltip: 'Retirer', onPressed: () => go(() => db.rpc('release_user', params: {'p_user': p['id']}), 'Retiré.')) : null,
              ),
          ])),
    ]);
  }
}

// ---------- Résultats (images haute définition) ----------
Future<void> sendResult(BuildContext c, Map<String, dynamic> r) async {
  final src = await showModalBottomSheet<String>(
    context: c,
    builder: (d) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choisir dans la galerie'), onTap: () => Navigator.pop(d, 'gal')),
        ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Prendre une photo'), onTap: () => Navigator.pop(d, 'cam')),
      ]),
    ),
  );
  if (src == null) return;
  final picker = ImagePicker();
  List<XFile> files = [];
  if (src == 'cam') {
    final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 100);
    if (x != null) files = [x];
  } else {
    files = await picker.pickMultiImage(imageQuality: 100);
  }
  if (files.isEmpty || !c.mounted) return;
  final who = '${(r['patient'] ?? {})['full_name'] ?? 'ce patient'}';
  final yes = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      title: const Text('Envoyer le résultat ?'),
      content: Text('${files.length} image(s) seront envoyées à $who. Vérifiez que c’est le bon patient : il pourra les voir et les télécharger.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Envoyer')),
      ],
    ),
  );
  if (yes != true || !c.mounted) return;
  final pid = r['patient_id'], rid = r['id'], service = r['service'];
  final title = (r['exam_names'] as List).join(', ');
  var n = 0;
  for (final f in files) {
    final png = f.name.toLowerCase().endsWith('.png');
    final path = '$pid/$rid/${DateTime.now().microsecondsSinceEpoch}_$n.${png ? 'png' : 'jpg'}';
    final bytes = await f.readAsBytes();
    final good = await runAny(c, () async {
      await db.storage.from('resultats').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: png ? 'image/png' : 'image/jpeg'));
      await db.from('results').insert({'patient_id': pid, 'request_id': rid, 'service': service, 'title': title, 'file_path': path});
    });
    if (!good) return;
    n++;
  }
  await runAny(c, () => db.from('requests').update({'status': 'done'}).eq('id', rid));
  if (c.mounted) snack(c, 'Résultat envoyé au patient ($n image(s)).');
}

Future<void> openResult(BuildContext c, String path, {bool download = false}) async {
  try {
    final url = await db.storage.from('resultats').createSignedUrl(path, 600);
    if (!c.mounted) return;
    if (download) {
      await launchUrl(Uri.parse('$url&download=resultat-saint-victor.jpg'), mode: LaunchMode.externalApplication);
    } else {
      Navigator.push(c, MaterialPageRoute(builder: (_) => ResultViewer(url: url)));
    }
  } catch (e) {
    if (c.mounted) snack(c, 'Erreur : $e');
  }
}

class ResultViewer extends StatelessWidget {
  final String url;
  final String? title;
  const ResultViewer({super.key, required this.url, this.title});
  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(title ?? t('Résultat', 'Result')),
          actions: [IconButton(icon: const Icon(Icons.download), tooltip: t('Télécharger', 'Download'), onPressed: () => launchUrl(Uri.parse('$url&download=resultat-saint-victor.jpg'), mode: LaunchMode.externalApplication))],
        ),
        body: InteractiveViewer(
          maxScale: 8,
          child: Center(
            child: Image.network(url, loadingBuilder: (c, w, p) => p == null ? w : const Center(child: CircularProgressIndicator()), errorBuilder: (c, e, s) => const Text('Image indisponible', style: TextStyle(color: Colors.white))),
          ),
        ),
      );
}

class ResultsStaff extends StatefulWidget {
  final String service;
  const ResultsStaff({super.key, required this.service});
  @override
  State<ResultsStaff> createState() => _ResultsStaffState();
}

class _ResultsStaffState extends State<ResultsStaff> {
  Future<void> del(Map<String, dynamic> x) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Retirer ce résultat ?'),
        content: const Text('Le patient ne pourra plus le voir. À utiliser si l’image a été envoyée au mauvais patient.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await runAny(context, () async {
      await db.storage.from('resultats').remove([x['file_path']]);
      await db.from('results').delete().eq('id', x['id']);
    }, 'Résultat retiré.');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) => load(q(db.from('results').select('id, title, file_path, created_at, patient:profiles!patient_id(full_name)').eq('service', widget.service).order('created_at', ascending: false)), (l) => lst([
        for (final x in l)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: ListTile(
              leading: const Icon(Icons.image, color: navy),
              title: Text('${(x['patient'] ?? {})['full_name'] ?? ''}'),
              subtitle: Text('${x['title']}\n${day(x['created_at'])}'),
              isThreeLine: true,
              onTap: () => openResult(c, x['file_path']),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Retirer', onPressed: () => del(x)),
            ),
          ),
      ], () async => setState(() {})));
}
