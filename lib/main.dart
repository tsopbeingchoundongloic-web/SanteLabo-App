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
    title: 'St Victor de Bafia',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF123C80)).copyWith(primary: const Color(0xFF123C80), secondary: const Color(0xFF7AB51D)), scaffoldBackgroundColor: Colors.white, appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Color(0xFF123C80), surfaceTintColor: Colors.white)),
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
                Image.asset('assets/logo.png', height: 120),
                const Text('St Victor de Bafia', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF123C80))),
                const Text('Voir juste, diagnostiquer mieux, soigner efficacement', textAlign: TextAlign.center),
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
              return const AdminPage(isSuper: true);
            case 'promoteur':
              return const AdminPage(isSuper: false);
            case 'major':
              return MajorPage(lab: p['lab_id']);
            case 'preleveur':
              return const MissionsPage();
            case 'imagerie':
              return ImagerieStaffPage(lab: p['lab_id']);
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
            title: Row(children: [Image.asset('assets/logo.png', height: 34), const SizedBox(width: 8), const Flexible(child: Text('St Victor de Bafia', overflow: TextOverflow.ellipsis))]),
            actions: [logoutBtn()],
            bottom: const TabBar(tabs: [Tab(text: 'Le centre'), Tab(text: 'Commander'), Tab(text: 'Mes demandes')]),
          ),
          body: TabBarView(children: [
            load(q(db.from('labs').select().eq('active', true).order('name')), (l) => lst([
                  for (final im in ['radio', 'labo', 'accueil']) Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/$im.jpg', height: 150, width: double.infinity, fit: BoxFit.cover))),
                  const Padding(padding: EdgeInsets.all(12), child: Text('Radiographie, échographie et analyses médicales : voir juste, diagnostiquer mieux, soigner efficacement.', style: TextStyle(fontWeight: FontWeight.bold))),
                  loadIn(q(db.from('contacts').select().order('id')), (cs) => Column(children: [for (final k in cs) contactTile(k)])),
                  
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
  final sel = <String>{}, centerOnly = <String>{}, imaging = <String>{};
  final quarter = TextEditingController(), addr = TextEditingController();
  String slot = slots.first, mode = 'domicile';
  DateTime? date;
  double? lat, lng;
  bool busy = false;
  late final ex = q(db.from('lab_exams').select('custom_conditions, exams(name, discipline, conditions, at_center_only, service)').eq('lab_id', widget.lab ?? '').eq('active', true));

  List<String> get labSel => sel.where((n) => !imaging.contains(n)).toList();
  List<String> get imgSel => sel.where(imaging.contains).toList();
  bool get labAtCenter => mode == 'centre' || labSel.any(centerOnly.contains);

  Future<void> send() async {
    final lb = labSel, im = imgSel, labCtr = labAtCenter;
    if (sel.isEmpty || date == null || (lb.isNotEmpty && !labCtr && (quarter.text.trim().isEmpty || addr.text.trim().isEmpty))) {
      snack(context, 'Choisissez au moins un examen, la date et, pour un prélèvement à domicile, le quartier et le lieu.');
      return;
    }
    Map<String, dynamic> row(String service, List<String> names, bool centre) => {
          'patient_id': db.auth.currentUser!.id,
          'lab_id': widget.lab,
          'service': service,
          'exam_names': names,
          'mode': centre ? 'centre' : 'domicile',
          'quarter': centre ? 'Au centre' : quarter.text.trim(),
          'address': centre ? 'Centre St Victor de Bafia' : addr.text.trim(),
          'wanted_date': date!.toIso8601String().substring(0, 10),
          'slot': slot,
          'lat': centre ? null : lat,
          'lng': centre ? null : lng,
        };
    final rows0 = <Map<String, dynamic>>[
      if (lb.isNotEmpty) row('laboratoire', lb, labCtr),
      if (im.isNotEmpty) row('imagerie', im, true),
    ];
    setState(() => busy = true);
    final ok = await run(context, () => db.from('requests').insert(rows0),
        rows0.length > 1 ? 'Vos demandes d’analyses et d’imagerie sont envoyées. Le centre va vous confirmer.' : 'Demande envoyée. Le centre va vous confirmer.');
    if (ok) { lat = null; lng = null; sel.clear(); quarter.clear(); addr.clear(); date = null; }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    if (widget.lab == null) return const Center(child: Text('Centre indisponible. Reconnectez-vous.'));
    return load(ex, (l) {
      for (final x in l) {
        final e = x['exams'];
        if (e['at_center_only'] == true) centerOnly.add(e['name']);
        if (e['service'] == 'imagerie') imaging.add(e['name']);
      }
      final hasLab = labSel.isNotEmpty, hasImg = imgSel.isNotEmpty, home = hasLab && !labAtCenter;
      return ListView(padding: const EdgeInsets.all(12), children: [
        ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/accueil.jpg', height: 140, width: double.infinity, fit: BoxFit.cover)),
        const SizedBox(height: 12),
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
        if (hasImg)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Les examens d’imagerie se font au centre : venez avec votre ordonnance.', style: TextStyle(color: Color(0xFF123C80)))),
        if (hasLab && !labSel.any(centerOnly.contains))
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'domicile', label: Text('Analyses à domicile'), icon: Icon(Icons.home)),
              ButtonSegment(value: 'centre', label: Text('Analyses au centre'), icon: Icon(Icons.local_hospital)),
            ],
            selected: {mode},
            onSelectionChanged: (v) => setState(() => mode = v.first),
          ),
        if (home) ...[
          TextField(controller: quarter, decoration: const InputDecoration(labelText: 'Quartier')),
          TextField(controller: addr, decoration: const InputDecoration(labelText: 'Adresse / lieu / repère')),
        ],
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
        if (home)
          OutlinedButton.icon(
            icon: const Icon(Icons.my_location),
            label: Text(lat == null ? 'Partager ma position (GPS)' : 'Position enregistrée'),
            onPressed: () async {
              final p = await myPosition(c);
              if (p != null) setState(() { lat = p.latitude; lng = p.longitude; });
            },
          ),
        FilledButton(onPressed: busy ? null : send, child: Text(home ? 'Envoyer ma demande' : 'Demander un rendez-vous')),
      ]);
    });
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
        body: TabBarView(children: [MajorReqs(lab: lab!, service: 'laboratoire'), MajorExams(lab: lab!), Team(lab: lab!)]),
      ),
    );
  }
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
  const MajorExams({super.key, required this.lab});
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
    String disc = disciplines.first;
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
                items: [for (final x in disciplines) DropdownMenuItem(value: x, child: Text(x))],
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
        body: load(q(db.from('lab_exams').select('exam_id, active, custom_conditions, exams(name, conditions)').eq('lab_id', widget.lab)), (l) => lst([
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
                        color: m['sender_id'] == db.auth.currentUser!.id ? const Color(0xFFDDEFB5) : Colors.white,
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
            length: 5,
            child: Scaffold(
              appBar: AppBar(
                title: Text(isSuper ? 'Super Administrateur' : 'Promoteur'),
                actions: [logoutBtn()],
                bottom: const TabBar(isScrollable: true, tabs: [Tab(text: 'Laboratoire'), Tab(text: 'Imagerie'), Tab(text: 'Examens'), Tab(text: 'Équipe'), Tab(text: 'Centre')]),
              ),
              body: TabBarView(children: [MajorReqs(lab: lab, service: 'laboratoire'), MajorReqs(lab: lab, service: 'imagerie'), MajorExams(lab: lab), Team(lab: lab), CenterAdmin(lab: lab, isSuper: isSuper)]),
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
    final e = await ask(context, title, 'E-mail de son compte (déjà créé dans l’application)');
    if (e != null && e.isNotEmpty) go(() => db.rpc('assign_user', params: {'p_email': e, 'p_role': role, 'p_lab': widget.lab}), 'Fait.');
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
        const Text('Responsables', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: () => nominate('major', 'Nommer un Major'), child: const Text('Nommer un Major')),
          OutlinedButton(onPressed: () => nominate('imagerie', 'Ajouter du personnel d’imagerie'), child: const Text('Ajouter du personnel d’imagerie')),
          if (widget.isSuper) OutlinedButton(onPressed: () => nominate('promoteur', 'Nommer le promoteur'), child: const Text('Nommer le promoteur')),
        ]),
        loadIn(q(db.from('profiles').select('id, full_name, phone, role').inFilter('role', ['major', 'promoteur', 'imagerie'])), (l) => Column(children: [
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
String roleFr(dynamic r) => const {'promoteur': 'Promoteur', 'imagerie': 'Imagerie', 'major': 'Major', 'preleveur': 'Préleveur'}[r] ?? '$r';

class ImagerieStaffPage extends StatelessWidget {
  final String? lab;
  const ImagerieStaffPage({super.key, this.lab});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Imagerie médicale'), actions: [logoutBtn()]),
        body: lab == null ? const Center(child: Text('Aucun centre rattaché à ce compte.')) : MajorReqs(lab: lab!, service: 'imagerie'),
      );
}
