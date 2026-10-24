import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');
SupabaseClient get db => Supabase.instance.client;

const slots = ['Matin (7h–10h)', 'Fin de matinée (10h–12h)', 'Après-midi (14h–17h)'];
const statusFr = {'pending': 'En attente', 'accepted': 'Acceptée', 'en_route': 'Préleveur en route', 'arrived': 'Préleveur arrivé', 'collected': 'Prélèvement fait', 'done': 'Terminée', 'cancelled': 'Annulée'};

List<Map<String, dynamic>> rows(dynamic d) => List<Map<String, dynamic>>.from(d as List);
Widget logoutBtn() => Row(mainAxisSize: MainAxisSize.min, children: [const BellBtn(), IconButton(icon: const Icon(Icons.logout), tooltip: 'Se déconnecter', onPressed: () => db.auth.signOut())]);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _url, anonKey: _key);
  runApp(MaterialApp(
    title: 'SantéLab',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF64FFDA), brightness: Brightness.dark), scaffoldBackgroundColor: const Color(0xFF0A192F), appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF112240))),
    home: const Gate(),
  ));
}

class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext c) => StreamBuilder<AuthState>(
        stream: db.auth.onAuthStateChange,
        builder: (c, _) => db.auth.currentSession == null ? const AuthPage() : const Home(),
      );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(), pass = TextEditingController(), name = TextEditingController(), phone = TextEditingController();
  bool signup = false, busy = false, ok = false;
  void msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> submit() async {
    if (email.text.trim().isEmpty || pass.text.length < 6) { msg('E-mail et mot de passe (6 caractères minimum) requis.'); return; }
    if (signup && (name.text.trim().isEmpty || !ok)) { msg('Indiquez votre nom et acceptez les conditions.'); return; }
    setState(() => busy = true);
    try {
      if (signup) {
        final r = await db.auth.signUp(email: email.text.trim(), password: pass.text, data: {'full_name': name.text.trim(), 'phone': phone.text.trim()});
        if (r.session == null) msg('Compte créé. Confirmez votre e-mail puis connectez-vous.');
      } else {
        await db.auth.signInWithPassword(email: email.text.trim(), password: pass.text);
      }
    } on AuthException catch (e) {
      msg(e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('SantéLab', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF64FFDA))),
                const Text('Le laboratoire proche de chez vous'),
                const SizedBox(height: 24),
                if (signup) TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom complet')),
                if (signup) TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone')),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
                TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe')),
                if (signup)
                  CheckboxListTile(
                    value: ok,
                    onChanged: (v) => setState(() => ok = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text("J’accepte que mes informations soient utilisées par le centre pour organiser mon prélèvement.", style: TextStyle(fontSize: 13)),
                  ),
                const SizedBox(height: 12),
                FilledButton(onPressed: busy ? null : submit, child: Text(signup ? 'Créer mon compte' : 'Se connecter')),
                TextButton(onPressed: () => setState(() => signup = !signup), child: Text(signup ? 'J’ai déjà un compte' : 'Créer un compte')),
                const SizedBox(height: 16),
                const Text('Développé par TSOPBEING Loic', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
          ),
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
              return const SuperPage();
            case 'major':
              return MajorPage(lab: p['lab_id']);
            case 'preleveur':
              return const MissionsPage();
            default:
              return PatientPage(favLab: p['fav_lab_id']);
          }
        },
      );
}

// ---------- PATIENT ----------
class PatientPage extends StatefulWidget {
  final String? favLab;
  const PatientPage({super.key, this.favLab});
  @override
  State<PatientPage> createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  String? lab;
  @override
  void initState() {
    super.initState();
    lab = widget.favLab;
  }

  @override
  Widget build(BuildContext c) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('SantéLab'),
            actions: [logoutBtn()],
            bottom: const TabBar(tabs: [Tab(text: 'Établissement'), Tab(text: 'Commander'), Tab(text: 'Mes demandes')]),
          ),
          body: TabBarView(children: [
            load(q(db.from('labs').select().eq('active', true).order('name')), (l) => lst([
                  const Padding(padding: EdgeInsets.all(12), child: Text('Choisissez votre laboratoire')),
                  ListTile(leading: const Icon(Icons.key), title: const Text('J’ai un code d’invitation (personnel du laboratoire)'), onTap: () => redeem(c)),
                  for (final x in l)
                    ListTile(
                      title: Text(x['name']),
                      trailing: x['id'] == lab ? const Icon(Icons.check_circle, color: Colors.green) : null,
                      onTap: () async {
                        final ok = await run(c, () => db.from('profiles').update({'fav_lab_id': x['id']}).eq('id', db.auth.currentUser!.id));
                        if (ok && mounted) setState(() => lab = x['id']);
                      },
                    ),
                ], () async => setState(() {}))),
            OrderTab(key: ValueKey(lab), lab: lab),
            const MyRequestsTab(),
          ]),
        ),
      );
}

class OrderTab extends StatefulWidget {
  final String? lab;
  const OrderTab({super.key, this.lab});
  @override
  State<OrderTab> createState() => _OrderTabState();
}

class _OrderTabState extends State<OrderTab> {
  final sel = <String>{};
  final quarter = TextEditingController(), addr = TextEditingController();
  String slot = slots.first;
  DateTime? date;
  double? lat, lng;
  bool busy = false;
  late final ex = q(db.from('lab_exams').select('custom_conditions, exams(name, discipline, conditions)').eq('lab_id', widget.lab ?? '').eq('active', true));

  Future<void> send() async {
    if (sel.isEmpty || quarter.text.trim().isEmpty || addr.text.trim().isEmpty || date == null) {
      snack(context, 'Choisissez au moins un examen, la date, le quartier et le lieu.');
      return;
    }
    setState(() => busy = true);
    final ok = await run(
        context,
        () => db.from('requests').insert({
              'patient_id': db.auth.currentUser!.id,
              'lab_id': widget.lab,
              'exam_names': sel.toList(),
              'quarter': quarter.text.trim(),
              'address': addr.text.trim(),
              'wanted_date': date!.toIso8601String().substring(0, 10),
              'slot': slot,
              'lat': lat,
              'lng': lng,
            }),
        'Demande envoyée. Le laboratoire va vous contacter.');
    if (ok) { lat = null; lng = null; sel.clear(); quarter.clear(); addr.clear(); date = null; }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    if (widget.lab == null) return const Center(child: Text('Choisissez d’abord votre laboratoire.'));
    return load(ex, (l) => ListView(padding: const EdgeInsets.all(12), children: [
          const Text('1. Choisissez vos examens', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final x in l)
            CheckboxListTile(
              value: sel.contains(x['exams']['name']),
              onChanged: (v) => setState(() => v == true ? sel.add(x['exams']['name']) : sel.remove(x['exams']['name'])),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(x['exams']['name']),
              subtitle: Text('${x['exams']['discipline']} — ${x['custom_conditions'] ?? x['exams']['conditions']}'),
            ),
          const Divider(),
          const Text('2. Où et quand ?', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: quarter, decoration: const InputDecoration(labelText: 'Quartier')),
          TextField(controller: addr, decoration: const InputDecoration(labelText: 'Adresse / lieu / repère')),
          DropdownButtonFormField<String>(
            value: slot,
            items: [for (final x in slots) DropdownMenuItem(value: x, child: Text(x))],
            onChanged: (v) => setState(() => slot = v ?? slot),
            decoration: const InputDecoration(labelText: 'Créneau souhaité'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(date == null ? 'Choisir la date' : date!.toIso8601String().substring(0, 10)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(context: c, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
              if (d != null) setState(() => date = d);
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.my_location),
            label: Text(lat == null ? 'Partager ma position (GPS)' : 'Position enregistrée'),
            onPressed: () async {
              final p = await myPosition(c);
              if (p != null) setState(() { lat = p.latitude; lng = p.longitude; });
            },
          ),
          FilledButton(onPressed: busy ? null : send, child: const Text('Envoyer ma demande')),
        ]));
  }
}

class MyRequestsTab extends StatefulWidget {
  const MyRequestsTab({super.key});
  @override
  State<MyRequestsTab> createState() => _MyRequestsTabState();
}

class _MyRequestsTabState extends State<MyRequestsTab> {
  @override
  Widget build(BuildContext c) => load(q(db.from('requests').select().eq('patient_id', db.auth.currentUser!.id).order('created_at', ascending: false)), (l) => lst([
        for (final r in l)
          Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text((r['exam_names'] as List).join(', ')),
              subtitle: Text('${r['wanted_date']} · ${r['slot']}\n${r['quarter']} · ${r['address']}\n${statusFr[r['status']] ?? r['status']}'),
              isThreeLine: true,
              onTap: () => openChat(c, r),
              trailing: ['pending', 'accepted'].contains(r['status'])
                  ? TextButton(
                      onPressed: () async {
                        await run(c, () => db.from('requests').update({'status': 'cancelled'}).eq('id', r['id']));
                        if (mounted) setState(() {});
                      },
                      child: const Text('Annuler'))
                  : null,
            ),
          ),
      ], () async => setState(() {})));
}

// ---------- MAJOR ----------
class MajorPage extends StatelessWidget {
  final String? lab;
  const MajorPage({super.key, this.lab});
  @override
  Widget build(BuildContext c) {
    if (lab == null) return Scaffold(appBar: AppBar(actions: [logoutBtn()]), body: const Center(child: Text('Aucun laboratoire rattaché à ce compte.')));
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Espace Major'),
          actions: [logoutBtn()],
          bottom: const TabBar(tabs: [Tab(text: 'Demandes'), Tab(text: 'Examens'), Tab(text: 'Équipe')]),
        ),
        body: TabBarView(children: [MajorReqs(lab: lab!), MajorExams(lab: lab!), Team(lab: lab!)]),
      ),
    );
  }
}

class MajorReqs extends StatefulWidget {
  final String lab;
  const MajorReqs({super.key, required this.lab});
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
      load(q(db.from('requests').select(reqSel).eq('lab_id', widget.lab).order('created_at', ascending: false)), (l) => lst([
            for (final r in l)
              Card(
                margin: const EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ...reqInfo(r),
                    if (['pending', 'accepted', 'en_route'].contains(r['status']))
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
  const MajorExams({super.key, required this.lab});
  @override
  State<MajorExams> createState() => _MajorExamsState();
}

class _MajorExamsState extends State<MajorExams> {
  Future<void> upd(dynamic examId, Map<String, dynamic> v) async {
    await run(context, () => db.from('lab_exams').update(v).eq('lab_id', widget.lab).eq('exam_id', examId));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) => load(q(db.from('lab_exams').select('exam_id, active, custom_conditions, exams(name, conditions)').eq('lab_id', widget.lab)), (l) => lst([
        for (final x in l)
          SwitchListTile(
            value: x['active'] as bool,
            onChanged: (v) => upd(x['exam_id'], {'active': v}),
            title: Text(x['exams']['name']),
            subtitle: Text('${x['custom_conditions'] ?? x['exams']['conditions']}'),
            secondary: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final v = await ask(c, 'Conditions de prélèvement', 'Vide = conditions du catalogue');
                if (v != null) upd(x['exam_id'], {'custom_conditions': v.isEmpty ? null : v});
              },
            ),
          ),
      ], () async => setState(() {})));
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
            final e = await ask(c, 'Ajouter un préleveur', 'E-mail de son compte SantéLab');
            if (e != null && e.isNotEmpty) go(() => db.rpc('assign_user', params: {'p_email': e, 'p_role': 'preleveur', 'p_lab': widget.lab}), 'Préleveur ajouté.');
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
                  subtitle: Text('${p['role']} · ${p['phone'] ?? ''}'),
                  trailing: p['role'] == 'preleveur'
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
                          onPressed: () async {
                            final e = await ask(c, 'Nommer un Major', 'E-mail de son compte SantéLab');
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
  if (ok) await db.auth.signOut();
}

void openChat(BuildContext c, Map<String, dynamic> r) => Navigator.push(
    c, MaterialPageRoute(builder: (_) => ChatPage(id: r['id'].toString(), title: (r['exam_names'] as List).join(', '))));

class ChatPage extends StatefulWidget {
  final String id, title;
  const ChatPage({super.key, required this.id, required this.title});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final t = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> st = db.from('messages').stream(primaryKey: ['id']).eq('request_id', widget.id).order('created_at', ascending: true);

  Future<void> send(String body) async {
    if (body.trim().isEmpty) return;
    t.clear();
    await run(context, () => db.from('messages').insert({'request_id': widget.id, 'sender_id': db.auth.currentUser!.id, 'body': body.trim()}));
  }

  Future<void> call() async {
    final url = 'https://meet.jit.si/SanteLab-${widget.id.replaceAll('-', '')}';
    await send('Appel audio/vidéo : $url');
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title, overflow: TextOverflow.ellipsis),
          actions: [IconButton(icon: const Icon(Icons.call), tooltip: 'Appeler', onPressed: call)],
        ),
        body: Column(children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: st,
              builder: (c, s) {
                if (s.hasError) return Center(child: Text('Erreur : ${s.error}'));
                if (!s.hasData) return const ShimmerList();
                final l = s.data!;
                return ListView(padding: const EdgeInsets.all(8), children: [
                  for (final m in l)
                    Align(
                      alignment: m['sender_id'] == db.auth.currentUser!.id ? Alignment.centerRight : Alignment.centerLeft,
                      child: Card(
                        color: m['sender_id'] == db.auth.currentUser!.id ? const Color(0xFF1D3B63) : const Color(0xFF112240),
                        child: InkWell(
                          onTap: () {
                            final u = RegExp(r'https://\S+').firstMatch('${m['body']}');
                            if (u != null) launchUrl(Uri.parse(u.group(0)!), mode: LaunchMode.externalApplication);
                          },
                          child: Padding(padding: const EdgeInsets.all(10), child: Text('${m['body']}')),
                        ),
                      ),
                    ),
                ]);
              },
            ),
          ),
          SafeArea(
            child: Row(children: [
              Expanded(child: Padding(padding: const EdgeInsets.all(8), child: TextField(controller: t, decoration: const InputDecoration(hintText: 'Votre message'), onSubmitted: send))),
              IconButton(icon: const Icon(Icons.send), onPressed: () => send(t.text)),
            ]),
          ),
        ]),
      );
}

class BellBtn extends StatelessWidget {
  const BellBtn({super.key});
  @override
  Widget build(BuildContext c) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.from('notifications').stream(primaryKey: ['id']).eq('user_id', db.auth.currentUser!.id),
        builder: (c, s) {
          final n = (s.data ?? []).where((x) => x['read'] == false).length;
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
              for (final n in s.data!)
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
            Container(height: 72, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12))),
        ]),
      );
}
