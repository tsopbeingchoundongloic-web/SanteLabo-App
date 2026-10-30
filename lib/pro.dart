part of 'main.dart';

// =====================================================================
//  Version 3 : interfaces professionnelles
//  - barre de navigation avec bouton central (menu d'actions)
//  - espaces Laboratoire et Imagerie unifiés
//  - espace Direction (promoteur) : suivi de tout le centre
//  - messagerie : modifier / supprimer un message
// =====================================================================

const ink = Color(0xFF0E2A55);
const amber = Color(0xFFE69A0B), green = Color(0xFF2E9B4F), teal = Color(0xFF0E7C86), danger = Color(0xFFB3261E), muted = Color(0xFF5A6B82);
const List<BoxShadow> cardShadow = [BoxShadow(color: Color(0x1A123C80), blurRadius: 10, offset: Offset(0, 3))];

// ---------- Outils d'affichage ----------
Color statusColor(dynamic s) {
  switch ('$s') {
    case 'pending':
      return amber;
    case 'accepted':
      return navy;
    case 'en_route':
    case 'arrived':
    case 'collected':
      return teal;
    case 'done':
      return green;
    case 'cancelled':
      return danger;
    default:
      return muted;
  }
}

Widget statusChip(dynamic s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: statusColor(s).withAlpha(32), borderRadius: BorderRadius.circular(20)),
      child: Text('${statusFr[s] ?? s}', style: TextStyle(color: statusColor(s), fontSize: 11.5, fontWeight: FontWeight.w700)),
    );

String money(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

const _mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const _jours = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
String dateFr(DateTime d) => '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]} ${d.year}';

String hhmm(dynamic s) {
  final d = DateTime.tryParse('$s')?.toLocal();
  return d == null ? '' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String initial(String s) => s.trim().isEmpty ? '?' : s.trim().substring(0, 1).toUpperCase();

Future<bool> confirmBox(BuildContext c, String title, String msg, String yes) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Non')),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(yes)),
      ],
    ),
  );
  return r == true;
}

void pushPage(BuildContext c, String title, Widget body) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: body)));

Widget panel(Widget child, {EdgeInsets pad = const EdgeInsets.all(14), EdgeInsets margin = const EdgeInsets.only(bottom: 12)}) => Container(
      margin: margin,
      padding: pad,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: cardShadow),
      child: child,
    );

Widget sectionTitle(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
      child: Text(s, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: navy)),
    );

Widget heroBanner(String asset, String title, String sub) => Container(
      height: 168,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
      child: Stack(fit: StackFit.expand, children: [
        Image.asset(asset, fit: BoxFit.cover, errorBuilder: (c, e, st) => Container(color: navy)),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xE60E2A55), Color(0x000E2A55)]))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(sub, style: const TextStyle(color: pale, fontSize: 12.5)),
          ]),
        ),
      ]),
    );

Widget kpiCard(IconData ic, String v, String label, Color col) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: cardShadow),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: col.withAlpha(32), borderRadius: BorderRadius.circular(12)), child: Icon(ic, color: col, size: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: col)),
            Text(label, style: const TextStyle(fontSize: 11.5, color: muted)),
          ]),
        ),
      ]),
    );

Widget kpiRow(List<Widget> a) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        for (var i = 0; i < a.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: a[i]),
        ],
      ]),
    );

Widget infoLine(IconData ic, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ic, size: 15, color: muted),
      const SizedBox(width: 4),
      Flexible(child: Text(s, style: const TextStyle(fontSize: 12.5, color: Color(0xFF3B4C63)))),
    ]);

Widget barChart(List<String> labels, List<num> vals, Color col) {
  final mx = vals.fold<num>(1, (a, b) => b > a ? b : a);
  return SizedBox(
    height: 124,
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < vals.length; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (vals.length <= 10) Text('${vals[i]}', style: const TextStyle(fontSize: 10, color: muted)),
              Container(height: 4 + 80 * (vals[i] / mx), decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 4),
              Text(labels[i], maxLines: 1, overflow: TextOverflow.clip, style: const TextStyle(fontSize: 9, color: muted)),
            ]),
          ),
        ),
    ]),
  );
}

// ---------- Barre de navigation professionnelle (avec bouton central) ----------
class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

class HubAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const HubAction(this.icon, this.label, this.color, this.onTap);
}

Future<void> showHub(BuildContext c, String title, List<HubAction> acts) => showModalBottomSheet<void>(
      context: c,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (d) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 42, height: 4, decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 8,
              childAspectRatio: 0.92,
              children: [
                for (final a in acts)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(d);
                      a.onTap();
                    },
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 56, height: 56, decoration: BoxDecoration(color: a.color, borderRadius: BorderRadius.circular(18)), child: Icon(a.icon, color: Colors.white, size: 28)),
                      const SizedBox(height: 7),
                      Text(a.label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );

class ProShell extends StatefulWidget {
  final String title, subtitle;
  final List<NavItem> items;
  final List<Widget> Function(void Function(int) go) pages;
  final List<HubAction> Function(BuildContext c, void Function(int) go) hub;
  const ProShell({super.key, required this.title, this.subtitle = '', required this.items, required this.pages, required this.hub});
  @override
  State<ProShell> createState() => _ProShellState();
}

class _ProShellState extends State<ProShell> {
  int i = 0;
  void go(int n) => setState(() => i = n);

  Widget slot(int k) {
    final it = widget.items[k];
    final sel = i == k;
    final col = sel ? limeLight : Colors.white70;
    return Expanded(
      child: InkWell(
        onTap: () => go(k),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: sel ? limeLight.withAlpha(55) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
              child: Icon(it.icon, color: col, size: 24),
            ),
            const SizedBox(height: 3),
            Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: col)),
          ]),
        ),
      ),
    );
  }

  Widget bottomBar(BuildContext c, List<HubAction> acts) {
    final n = widget.items.length;
    final half = n ~/ 2;
    return Container(
      color: ink,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(children: [
            for (var k = 0; k < half; k++) slot(k),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () => showHub(c, widget.title, acts),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(color: lime, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))]),
                    child: const Icon(Icons.apps_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
            for (var k = half; k < n; k++) slot(k),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final wide = MediaQuery.of(c).size.width >= 900;
    final acts = widget.hub(c, go);
    final pages = widget.pages(go);
    final body = KeyedSubtree(key: ValueKey(i), child: pages[i]);
    final bar = AppBar(
      titleSpacing: 16,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        if (widget.subtitle.isNotEmpty) Text(widget.subtitle, style: const TextStyle(fontSize: 11.5, color: pale)),
      ]),
      actions: const [BellBtn(), SizedBox(width: 6)],
    );
    if (wide) {
      return Scaffold(
        appBar: bar,
        backgroundColor: soft,
        body: Row(children: [
          NavigationRail(
            backgroundColor: ink,
            selectedIndex: i,
            onDestinationSelected: go,
            labelType: NavigationRailLabelType.all,
            indicatorColor: limeLight,
            selectedIconTheme: const IconThemeData(color: ink),
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            selectedLabelTextStyle: const TextStyle(color: limeLight, fontWeight: FontWeight.w700),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
            leading: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: FloatingActionButton(elevation: 0, backgroundColor: lime, foregroundColor: Colors.white, onPressed: () => showHub(c, widget.title, acts), child: const Icon(Icons.apps_rounded)),
            ),
            destinations: [for (final it in widget.items) NavigationRailDestination(icon: Icon(it.icon), label: Text(it.label))],
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: body),
            ),
          ),
        ]),
      );
    }
    return Scaffold(appBar: bar, backgroundColor: soft, body: body, bottomNavigationBar: bottomBar(c, acts));
  }
}

// ---------- Envoi d'un résultat depuis le menu central ----------
class RequestPicker extends StatefulWidget {
  final List<Map<String, dynamic>> all;
  const RequestPicker({super.key, required this.all});
  @override
  State<RequestPicker> createState() => _RequestPickerState();
}

class _RequestPickerState extends State<RequestPicker> {
  String s = '';
  @override
  Widget build(BuildContext c) {
    final mq = MediaQuery.of(c);
    final l = widget.all.where((x) {
      final p = (x['patient'] ?? {}) as Map;
      return '${p['full_name']} ${p['phone']} ${(x['exam_names'] as List).join(' ')}'.toLowerCase().contains(s);
    }).toList();
    return SizedBox(
      height: (mq.size.height - mq.viewInsets.bottom) * 0.85,
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 42, height: 4, decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(4))),
        const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 4), child: Text('À quelle demande envoyer le résultat ?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: navy))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Nom, numéro ou examen',
              filled: true,
              fillColor: soft,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => s = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: l.isEmpty
              ? const Center(child: Text('Aucune demande trouvée.'))
              : ListView(children: [
                  for (final x in l)
                    ListTile(
                      leading: CircleAvatar(backgroundColor: x['service'] == 'imagerie' ? teal : navy, child: Icon(x['service'] == 'imagerie' ? Icons.monitor_heart_rounded : Icons.science_rounded, color: Colors.white, size: 20)),
                      title: Text('${(x['patient'] ?? {})['full_name'] ?? 'Patient'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${(x['exam_names'] as List).join(', ')}\n${x['wanted_date']} · ${statusFr[x['status']] ?? x['status']}'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(c, x),
                    ),
                ]),
        ),
      ]),
    );
  }
}

Future<void> pickAndSend(BuildContext c, String? service) async {
  List<Map<String, dynamic>> all;
  try {
    final base = db.from('requests').select(reqSel).neq('status', 'cancelled');
    all = await q((service == null ? base : base.eq('service', service)).order('created_at', ascending: false).limit(150));
  } catch (e) {
    if (c.mounted) snack(c, 'Erreur : $e');
    return;
  }
  if (!c.mounted) return;
  final r = await showModalBottomSheet<Map<String, dynamic>>(
    context: c,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (d) => RequestPicker(all: all),
  );
  if (r != null && c.mounted) await sendResult(c, r);
}

// ---------- Accueil d'un service (laboratoire / imagerie) ----------
class ServiceHome extends StatefulWidget {
  final String lab, service;
  final void Function(int) go;
  const ServiceHome({super.key, required this.lab, required this.service, required this.go});
  @override
  State<ServiceHome> createState() => _ServiceHomeState();
}

class _ServiceHomeState extends State<ServiceHome> {
  late Future<List<List<Map<String, dynamic>>>> fut = fetch();

  Future<List<List<Map<String, dynamic>>>> fetch() async => [
        await q(db.from('requests').select(reqSel).eq('lab_id', widget.lab).eq('service', widget.service).order('created_at', ascending: false).limit(300)),
        await q(db.from('results').select('id, created_at').eq('service', widget.service).order('created_at', ascending: false).limit(300)),
      ];

  @override
  Widget build(BuildContext c) => FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: fut,
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('Erreur : ${s.error}'));
          if (!s.hasData) return const ShimmerList();
          final reqs = s.data![0], res = s.data![1];
          final now = DateTime.now();
          bool isToday(dynamic d) {
            final l = DateTime.parse('$d').toLocal();
            return l.year == now.year && l.month == now.month && l.day == now.day;
          }

          final pending = reqs.where((r) => r['status'] == 'pending').toList();
          final doing = reqs.where((r) => ['accepted', 'en_route', 'arrived', 'collected'].contains(r['status'])).toList();
          final doneToday = reqs.where((r) => r['status'] == 'done' && isToday(r['done_at'] ?? r['created_at'])).length;
          final sentToday = res.where((r) => isToday(r['created_at'])).length;
          final todo = [...pending, ...doing].take(6).toList();
          final imag = widget.service == 'imagerie';
          return RefreshIndicator(
            onRefresh: () async => setState(() { fut = fetch(); }),
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(14), children: [
              heroBanner(imag ? 'assets/banner_imagerie.jpg' : 'assets/banner_labo.jpg', imag ? 'Imagerie médicale' : 'Laboratoire d’analyses', dateFr(now)),
              kpiRow([kpiCard(Icons.pending_actions_rounded, '${pending.length}', 'À traiter', amber), kpiCard(Icons.autorenew_rounded, '${doing.length}', 'En cours', navy)]),
              kpiRow([kpiCard(Icons.check_circle_rounded, '$doneToday', 'Terminées aujourd’hui', green), kpiCard(Icons.send_rounded, '$sentToday', 'Résultats envoyés aujourd’hui', teal)]),
              const SizedBox(height: 4),
              sectionTitle('À traiter maintenant'),
              if (todo.isEmpty) panel(const Text('Aucune demande en attente pour le moment.')),
              for (final r in todo)
                panel(
                  InkWell(
                    onTap: () => widget.go(1),
                    child: Row(children: [
                      CircleAvatar(backgroundColor: navy, child: Text(initial('${(r['patient'] ?? {})['full_name'] ?? ''}'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${(r['patient'] ?? {})['full_name'] ?? 'Patient'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text((r['exam_names'] as List).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: muted)),
                        ]),
                      ),
                      statusChip(r['status']),
                    ]),
                  ),
                  pad: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                ),
              const SizedBox(height: 6),
              OutlinedButton.icon(icon: const Icon(Icons.assignment_rounded), label: const Text('Voir toutes les demandes'), onPressed: () => widget.go(1)),
            ]),
          );
        },
      );
}

// ---------- Demandes : tableau de suivi ----------
class ReqBoard extends StatefulWidget {
  final String lab, service;
  final bool homeOnly;
  const ReqBoard({super.key, required this.lab, required this.service, this.homeOnly = false});
  @override
  State<ReqBoard> createState() => _ReqBoardState();
}

class _ReqBoardState extends State<ReqBoard> {
  String f = 'todo';
  String search = '';
  late Future<Map<String, List<Map<String, dynamic>>>> fut = fetch();

  static const flow = {
    'accepted': ['en_route', 'Me mettre en route'],
    'en_route': ['arrived', 'Je suis arrivé'],
    'arrived': ['collected', 'Prélèvement fait'],
    'collected': ['done', 'Terminer'],
  };
  static const groups = {
    'todo': ['pending'],
    'doing': ['accepted', 'en_route', 'arrived', 'collected'],
    'done': ['done'],
    'cancel': ['cancelled'],
  };
  static const labels = {'todo': 'À traiter', 'doing': 'En cours', 'done': 'Terminées', 'cancel': 'Annulées', 'all': 'Toutes'};

  Future<Map<String, List<Map<String, dynamic>>>> fetch() async {
    final team = await q(db.from('profiles').select('id, full_name').eq('lab_id', widget.lab).eq('role', 'major'));
    final base = db.from('requests').select(reqSel).eq('lab_id', widget.lab).eq('service', widget.service);
    final all = await q((widget.homeOnly ? base.neq('mode', 'centre') : base).order('created_at', ascending: false).limit(300));
    return {'team': team, 'all': all};
  }

  void refresh() {
    if (mounted) setState(() { fut = fetch(); });
  }

  Future<void> act(String id, Map<String, dynamic> v) async {
    await run(context, () => db.from('requests').update(v).eq('id', id));
    refresh();
  }

  Widget card(BuildContext c, Map<String, dynamic> r, List<Map<String, dynamic>> team) {
    final p = (r['patient'] ?? {}) as Map;
    final name = '${p['full_name'] ?? 'Patient'}';
    final st = '${r['status']}';
    final center = r['mode'] == 'centre';
    final open = !['done', 'cancelled'].contains(st);
    return panel(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: navy, child: Text(initial(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text('${p['phone'] ?? ''}', style: const TextStyle(fontSize: 12, color: muted)),
            ]),
          ),
          statusChip(st),
        ]),
        const SizedBox(height: 10),
        Text((r['exam_names'] as List).join(', '), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 14, runSpacing: 4, children: [
          infoLine(Icons.event_rounded, '${r['wanted_date']} · ${r['slot']}'),
          infoLine(center ? Icons.apartment_rounded : Icons.home_rounded, center ? 'Au centre' : '${r['quarter']} · ${r['address']}'),
        ]),
        const SizedBox(height: 10),
        if (!center && ['pending', 'accepted', 'en_route'].contains(st))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Agent chargé du prélèvement', border: OutlineInputBorder(), isDense: true),
              value: team.any((x) => x['id'] == r['assigned_to']) ? r['assigned_to'] as String : null,
              items: [for (final x in team) DropdownMenuItem(value: x['id'] as String, child: Text('${x['full_name'] ?? 'Agent'}'))],
              onChanged: (v) => act('${r['id']}', {'assigned_to': v, if (st == 'pending') 'status': 'accepted'}),
            ),
          ),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (st != 'cancelled')
            FilledButton.icon(
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Envoyer le résultat'),
              onPressed: () => sendResult(c, r).then((_) => refresh()),
            ),
          if (center && st == 'pending') OutlinedButton(onPressed: () => act('${r['id']}', {'status': 'accepted'}), child: const Text('Confirmer le rendez-vous')),
          if (center && st == 'accepted') OutlinedButton(onPressed: () => act('${r['id']}', {'status': 'done'}), child: const Text('Examen terminé')),
          if (!center && st == 'pending') OutlinedButton(onPressed: () => act('${r['id']}', {'status': 'accepted'}), child: const Text('Accepter')),
          if (!center && flow[st] != null) OutlinedButton(onPressed: () => act('${r['id']}', {'status': flow[st]![0]}), child: Text(flow[st]![1])),
          if (!center && open)
            OutlinedButton.icon(
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text('Itinéraire'),
              onPressed: () => launchUrl(Uri.parse(mapsUrl(r)), mode: LaunchMode.externalApplication),
            ),
          if (!center && open) OutlinedButton(onPressed: () => showDistance(c, r), child: const Text('Distance')),
          if (r['prescription_path'] != null) OutlinedButton.icon(icon: const Icon(Icons.description_rounded, size: 18), label: const Text('Ordonnance'), onPressed: () => openPrescription(c, '${r['prescription_path']}')),
          OutlinedButton.icon(icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18), label: const Text('Message'), onPressed: () => openChat(c, r)),
          if (open)
            TextButton(
              onPressed: () async {
                if (await confirmBox(c, 'Annuler cette demande ?', 'Le patient sera informé que la demande est annulée.', 'Annuler la demande')) {
                  act('${r['id']}', {'status': 'cancelled'});
                }
              },
              child: const Text('Annuler', style: TextStyle(color: danger)),
            ),
        ]),
      ]),
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
    );
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: fut,
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('Erreur : ${s.error}'));
          if (!s.hasData) return const ShimmerList();
          final team = s.data!['team']!, all = s.data!['all']!;
          final cnt = {for (final k in groups.keys) k: all.where((r) => groups[k]!.contains(r['status'])).length};
          final shown = all.where((r) {
            if (f != 'all' && !groups[f]!.contains(r['status'])) return false;
            if (search.isEmpty) return true;
            final p = (r['patient'] ?? {}) as Map;
            return '${p['full_name']} ${p['phone']} ${(r['exam_names'] as List).join(' ')}'.toLowerCase().contains(search);
          }).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Rechercher un patient, un numéro, un examen',
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [
                for (final k in [...groups.keys, 'all'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text('${labels[k]} (${k == 'all' ? all.length : cnt[k]})'), selected: f == k, onSelected: (_) => setState(() => f = k)),
                  ),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: shown.isEmpty
                      ? [const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('Aucune demande dans cette catégorie.')))]
                      : [for (final r in shown) card(c, r, team), const SizedBox(height: 24)],
                ),
              ),
            ),
          ]);
        },
      );
}

// ---------- Résultats envoyés ----------
class ResultsBoard extends StatefulWidget {
  final String service;
  const ResultsBoard({super.key, required this.service});
  @override
  State<ResultsBoard> createState() => _ResultsBoardState();
}

class _ResultsBoardState extends State<ResultsBoard> {
  String search = '';
  late Future<List<Map<String, dynamic>>> fut = fetch();

  Future<List<Map<String, dynamic>>> fetch() => q(db.from('results').select('id, title, file_path, created_at, patient:profiles!patient_id(full_name, phone)').eq('service', widget.service).order('created_at', ascending: false).limit(300));

  void refresh() {
    if (mounted) setState(() { fut = fetch(); });
  }

  Future<void> del(Map<String, dynamic> x) async {
    final yes = await confirmBox(context, 'Retirer ce résultat ?', 'Le patient ne pourra plus le voir. À utiliser si l’image a été envoyée au mauvais patient.', 'Retirer');
    if (!yes || !mounted) return;
    await runAny(context, () async {
      await db.storage.from('resultats').remove([x['file_path']]);
      await db.from('results').delete().eq('id', x['id']);
    }, 'Résultat retiré.');
    refresh();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: lime,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Envoyer un résultat'),
          onPressed: () async {
            await pickAndSend(c, widget.service);
            refresh();
          },
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: fut,
          builder: (c, s) {
            if (s.hasError) return Center(child: Text('Erreur : ${s.error}'));
            if (!s.hasData) return const ShimmerList();
            final l = s.data!.where((x) => search.isEmpty || '${(x['patient'] ?? {})['full_name']} ${(x['patient'] ?? {})['phone']} ${x['title']}'.toLowerCase().contains(search)).toList();
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Rechercher un patient ou un examen',
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => refresh(),
                  child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(12, 4, 12, 90), children: [
                    if (l.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('Aucun résultat envoyé pour le moment.'))),
                    for (final x in l)
                      panel(
                        Row(children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: navy.withAlpha(25), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.image_rounded, color: navy)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${(x['patient'] ?? {})['full_name'] ?? 'Patient'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${x['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                              Text('${day(x['created_at'])} · ${hhmm(x['created_at'])}', style: const TextStyle(fontSize: 11.5, color: muted)),
                            ]),
                          ),
                          IconButton(icon: const Icon(Icons.visibility_rounded, color: navy), tooltip: 'Voir', onPressed: () => openResult(c, '${x['file_path']}')),
                          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: danger), tooltip: 'Retirer', onPressed: () => del(x)),
                        ]),
                        pad: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                      ),
                  ]),
                ),
              ),
            ]);
          },
        ),
      );
}

// ---------- Direction : calcul des chiffres ----------
class DirStats {
  int total = 0, done = 0, pending = 0, doing = 0, cancelled = 0, results = 0, patients = 0, home = 0, center = 0;
  double avgHours = -1, avgStars = 0;
  int ratings = 0;
  final byService = <String, int>{'laboratoire': 0, 'imagerie': 0};
  final topCount = <String, int>{};
  final trendLabels = <String>[];
  final trendVals = <num>[];
  final byHour = List<int>.filled(24, 0);
}

class DirAlerts {
  final lateReqs = <Map<String, dynamic>>[];
  final noAgent = <Map<String, dynamic>>[];
  final noResult = <Map<String, dynamic>>[];
  int get total => lateReqs.length + noAgent.length + noResult.length;
}

Future<Map<String, List<Map<String, dynamic>>>> loadDir() async {
  final since = DateTime.now().subtract(const Duration(days: 90)).toUtc().toIso8601String();
  final reqs = await q(db
      .from('requests')
      .select('id, service, status, created_at, done_at, exam_names, mode, patient_id, assigned_to, quarter, address, patient:profiles!patient_id(full_name, phone), agent:profiles!assigned_to(full_name)')
      .gte('created_at', since)
      .order('created_at', ascending: false)
      .limit(1000));
  final res = await q(db.from('results').select('id, request_id, service, created_at, created_by').gte('created_at', since).order('created_at', ascending: false).limit(1000));
  List<Map<String, dynamic>> fb = [];
  try {
    fb = await q(db.from('feedback').select('stars, created_at').gte('created_at', since).limit(1000));
  } catch (_) {}
  return {'requests': reqs, 'results': res, 'feedback': fb};
}

DateTime periodStart(int period) {
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  return period == 0 ? today : today.subtract(Duration(days: period - 1));
}

String ageText(DateTime d) {
  final x = DateTime.now().difference(d);
  if (x.inMinutes < 60) return '${x.inMinutes < 1 ? 1 : x.inMinutes} min';
  if (x.inHours < 48) return '${x.inHours} h';
  return '${x.inDays} j';
}

DirAlerts computeAlerts(Map<String, List<Map<String, dynamic>>> raw) {
  final a = DirAlerts();
  final withResult = <String>{for (final x in raw['results']!) '${x['request_id']}'};
  final now = DateTime.now();
  for (final r in raw['requests']!) {
    final st = '${r['status']}';
    final age = now.difference(DateTime.parse('${r['created_at']}').toLocal());
    if (st == 'pending' && age.inHours >= 2) a.lateReqs.add(r);
    if (r['mode'] != 'centre' && ['accepted', 'en_route'].contains(st) && r['assigned_to'] == null) a.noAgent.add(r);
    if (st == 'done' && !withResult.contains('${r['id']}')) a.noResult.add(r);
  }
  return a;
}

DirStats computeDir(Map<String, List<Map<String, dynamic>>> raw, int period) {
  final s = DirStats();
  final start = periodStart(period);
  bool inP(dynamic d) => !DateTime.parse('$d').toLocal().isBefore(start);
  final reqs = raw['requests']!.where((r) => inP(r['created_at'])).toList();
  final pats = <dynamic>{};
  var hours = 0.0, hn = 0;
  for (final r in reqs) {
    final st = '${r['status']}';
    final svc = '${r['service']}';
    s.total++;
    pats.add(r['patient_id']);
    s.byHour[DateTime.parse('${r['created_at']}').toLocal().hour]++;
    if (st == 'cancelled') {
      s.cancelled++;
      continue;
    }
    if (st == 'done') {
      s.done++;
    } else if (st == 'pending') {
      s.pending++;
    } else {
      s.doing++;
    }
    if (r['mode'] == 'centre') {
      s.center++;
    } else {
      s.home++;
    }
    s.byService[svc] = (s.byService[svc] ?? 0) + 1;
    for (final n in (r['exam_names'] as List)) {
      final nm = '$n';
      s.topCount[nm] = (s.topCount[nm] ?? 0) + 1;
    }
    if (st == 'done' && r['done_at'] != null) {
      hours += DateTime.parse('${r['done_at']}').difference(DateTime.parse('${r['created_at']}')).inMinutes / 60;
      hn++;
    }
  }
  s.patients = pats.length;
  s.avgHours = hn == 0 ? -1 : hours / hn;
  s.results = raw['results']!.where((x) => inP(x['created_at'])).length;
  final fbs = (raw['feedback'] ?? <Map<String, dynamic>>[]).where((x) => inP(x['created_at'])).toList();
  s.ratings = fbs.length;
  s.avgStars = fbs.isEmpty ? 0.0 : fbs.fold<num>(0, (a, x) => a + (x['stars'] as num)) / fbs.length;
  final days = period <= 7 ? 7 : 30;
  final nowT = DateTime.now();
  final today = DateTime(nowT.year, nowT.month, nowT.day);
  final perDay = <String, int>{};
  for (final r in raw['requests']!) {
    final l = DateTime.parse('${r['created_at']}').toLocal();
    final k = '${l.year}-${l.month}-${l.day}';
    perDay[k] = (perDay[k] ?? 0) + 1;
  }
  const wd = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  for (var i = days - 1; i >= 0; i--) {
    final d = today.subtract(Duration(days: i));
    s.trendVals.add(perDay['${d.year}-${d.month}-${d.day}'] ?? 0);
    s.trendLabels.add(days == 7 ? wd[d.weekday - 1] : (i % 5 == 0 ? '${d.day}' : ''));
  }
  return s;
}

String delayText(double h) => h < 0 ? '—' : (h < 1 ? '${(h * 60).round()} min' : '${h.toStringAsFixed(1)} h');

Future<void> copyReport(BuildContext c, int period, String label) async {
  try {
    final raw = await loadDir();
    final d = computeDir(raw, period);
    final al = computeAlerts(raw);
    final b = StringBuffer()
      ..writeln('Centre Saint-Victor de Bafia — rapport ($label)')
      ..writeln(dateFr(DateTime.now()))
      ..writeln('')
      ..writeln('Demandes : ${d.total} (terminées ${d.done}, en attente ${d.pending}, en cours ${d.doing}, annulées ${d.cancelled})')
      ..writeln('Laboratoire : ${d.byService['laboratoire'] ?? 0} · Imagerie : ${d.byService['imagerie'] ?? 0}')
      ..writeln('Au centre : ${d.center} · À domicile : ${d.home}')
      ..writeln('Résultats envoyés : ${d.results}')
      ..writeln('Patients différents : ${d.patients}')
      ..writeln('Satisfaction des patients : ${d.ratings == 0 ? 'aucun avis' : '${d.avgStars.toStringAsFixed(1)}/5 (${d.ratings} avis)'}')
      ..writeln('Délai moyen de traitement : ${delayText(d.avgHours)}')
      ..writeln('Points de contrôle : ${al.lateReqs.length} en retard, ${al.noAgent.length} sans agent, ${al.noResult.length} terminées sans résultat');
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (c.mounted) snack(c, 'Rapport copié : collez-le dans WhatsApp.');
  } catch (e) {
    if (c.mounted) snack(c, 'Erreur : $e');
  }
}

// Liste de demandes dans une fenêtre (points de contrôle)
void showReqList(BuildContext c, String title, List<Map<String, dynamic>> l) {
  showModalBottomSheet<void>(
    context: c,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (d) => SizedBox(
      height: MediaQuery.of(d).size.height * 0.75,
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 42, height: 4, decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(4))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: Text('$title (${l.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: navy))),
        Expanded(
          child: ListView(children: [
            for (final r in l)
              ListTile(
                leading: CircleAvatar(backgroundColor: r['service'] == 'imagerie' ? teal : navy, child: Icon(r['service'] == 'imagerie' ? Icons.monitor_heart_rounded : Icons.science_rounded, color: Colors.white, size: 20)),
                title: Text('${(r['patient'] ?? {})['full_name'] ?? 'Patient'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${(r['exam_names'] as List).join(', ')}\nReçue il y a ${ageText(DateTime.parse('${r['created_at']}').toLocal())}${r['agent'] != null ? ' · ${(r['agent'] ?? {})['full_name'] ?? ''}' : ''}'),
                isThreeLine: true,
                trailing: IconButton(icon: const Icon(Icons.chat_bubble_outline_rounded), onPressed: () => openChat(c, r)),
              ),
          ]),
        ),
      ]),
    ),
  );
}

// ---------- Direction : tableau de bord ----------
class DirDashboard extends StatefulWidget {
  const DirDashboard({super.key});
  @override
  State<DirDashboard> createState() => _DirDashboardState();
}

class _DirDashboardState extends State<DirDashboard> {
  late Future<Map<String, List<Map<String, dynamic>>>> fut = loadDir();
  int period = 7;
  static const periods = <int, String>{0: 'Aujourd’hui', 7: '7 jours', 30: '30 jours', 90: '90 jours'};

  Widget shareRow(String name, IconData ic, Color col, int n, int tot) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ic, color: col, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('$n · ${tot == 0 ? 0 : (n * 100 / tot).round()} %', style: const TextStyle(fontSize: 12.5, color: muted)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: tot == 0 ? 0.0 : n / tot, minHeight: 8, color: col, backgroundColor: soft)),
      ]);

  Widget alertRow(BuildContext c, IconData ic, String label, List<Map<String, dynamic>> l) => InkWell(
        onTap: l.isEmpty ? null : () => showReqList(c, label, l),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Icon(l.isEmpty ? Icons.check_circle_rounded : ic, color: l.isEmpty ? green : danger, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: (l.isEmpty ? green : danger).withAlpha(30), borderRadius: BorderRadius.circular(12)),
              child: Text('${l.length}', style: TextStyle(fontWeight: FontWeight.w800, color: l.isEmpty ? green : danger)),
            ),
            if (l.isNotEmpty) const Icon(Icons.chevron_right_rounded, color: muted),
          ]),
        ),
      );

  @override
  Widget build(BuildContext c) => FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: fut,
        builder: (c, s) {
          if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Erreur : ${s.error}\n\nAvez-vous bien exécuté le fichier SQL de cette version dans Supabase ?')));
          if (!s.hasData) return const ShimmerList();
          final d = computeDir(s.data!, period);
          final al = computeAlerts(s.data!);
          final lbl = periods[period]!;
          final tot = (d.byService['laboratoire'] ?? 0) + (d.byService['imagerie'] ?? 0);
          final top = d.topCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final topMax = top.isEmpty ? 1 : top.first.value;
          final cancelRate = d.total == 0 ? '0 %' : '${(d.cancelled * 100 / d.total).round()} %';
          final doneRate = tot == 0 ? 0 : (d.done * 100 / tot).round();
          final hourLabels = <String>[], hourVals = <num>[];
          for (var h = 6; h <= 20; h++) {
            hourLabels.add(h % 2 == 0 ? '${h}h' : '');
            hourVals.add(d.byHour[h]);
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() {
              fut = loadDir();
            }),
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(14), children: [
              SizedBox(
                height: 42,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final e in periods.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(label: Text(e.value), selected: period == e.key, onSelected: (_) => setState(() => period = e.key)),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              heroBanner('assets/banner_direction.jpg', '${d.total} demandes · $lbl', 'Centre Saint-Victor de Bafia · $doneRate % terminées · délai moyen ${delayText(d.avgHours)}'),
              panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('Points de contrôle', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: navy))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: (al.total == 0 ? green : amber).withAlpha(32), borderRadius: BorderRadius.circular(14)),
                    child: Text(al.total == 0 ? 'Tout est en ordre' : '${al.total} à traiter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: al.total == 0 ? green : amber)),
                  ),
                ]),
                const SizedBox(height: 4),
                alertRow(c, Icons.hourglass_top_rounded, 'En attente depuis plus de 2 h', al.lateReqs),
                const Divider(height: 1),
                alertRow(c, Icons.person_off_rounded, 'Prélèvement à domicile sans agent', al.noAgent),
                const Divider(height: 1),
                alertRow(c, Icons.mark_email_unread_rounded, 'Terminées sans résultat envoyé', al.noResult),
              ])),
              kpiRow([kpiCard(Icons.assignment_rounded, '${d.total}', 'Demandes', navy), kpiCard(Icons.check_circle_rounded, '${d.done}', 'Terminées', green)]),
              kpiRow([kpiCard(Icons.pending_actions_rounded, '${d.pending}', 'En attente', amber), kpiCard(Icons.cancel_rounded, '${d.cancelled}', 'Annulées ($cancelRate)', danger)]),
              kpiRow([kpiCard(Icons.send_rounded, '${d.results}', 'Résultats envoyés', teal), kpiCard(Icons.people_rounded, '${d.patients}', 'Patients différents', navy)]),
              kpiRow([kpiCard(Icons.star_rounded, d.ratings == 0 ? '—' : d.avgStars.toStringAsFixed(1), 'Satisfaction (${d.ratings} avis)', amber), kpiCard(Icons.autorenew_rounded, '${d.doing}', 'En cours', navy)]),
              const SizedBox(height: 4),
              panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Répartition de l’activité', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: navy)),
                const SizedBox(height: 12),
                shareRow('Laboratoire', Icons.science_rounded, navy, d.byService['laboratoire'] ?? 0, tot),
                const SizedBox(height: 12),
                shareRow('Imagerie médicale', Icons.monitor_heart_rounded, teal, d.byService['imagerie'] ?? 0, tot),
                const SizedBox(height: 12),
                shareRow('Au centre', Icons.apartment_rounded, lime, d.center, tot),
                const SizedBox(height: 12),
                shareRow('À domicile', Icons.home_rounded, amber, d.home, tot),
              ])),
              panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Demandes reçues · ${d.trendVals.length} derniers jours', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: navy)),
                const SizedBox(height: 12),
                barChart(d.trendLabels, d.trendVals, navy),
              ])),
              panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Heures d’affluence · $lbl', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: navy)),
                const SizedBox(height: 12),
                barChart(hourLabels, hourVals, teal),
              ])),
              panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Examens les plus demandés', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: navy)),
                const SizedBox(height: 10),
                if (top.isEmpty) const Text('Aucune donnée pour cette période.'),
                for (final e in top.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text('${e.value}×', style: const TextStyle(fontSize: 12, color: muted)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: e.value / topMax, minHeight: 6, color: lime, backgroundColor: soft)),
                    ]),
                  ),
              ])),
              if (s.data!['requests']!.length >= 1000) panel(const Text('Affichage limité aux 1000 demandes les plus récentes des 90 derniers jours.', style: TextStyle(color: muted, fontSize: 12.5))),
            ]),
          );
        },
      );
}

// ---------- Suivi de toutes les demandes (contrôle) ----------
class DirTracking extends StatefulWidget {
  const DirTracking({super.key});
  @override
  State<DirTracking> createState() => _DirTrackingState();
}

class _DirTrackingState extends State<DirTracking> {
  late Future<Map<String, List<Map<String, dynamic>>>> fut = loadDir();
  String f = 'all';
  String search = '';
  static const labels = {'all': 'Toutes', 'laboratoire': 'Laboratoire', 'imagerie': 'Imagerie', 'open': 'En cours', 'late': 'En retard', 'norest': 'Sans résultat'};

  @override
  Widget build(BuildContext c) => FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: fut,
        builder: (c, s) {
          if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Erreur : ${s.error}')));
          if (!s.hasData) return const ShimmerList();
          final al = computeAlerts(s.data!);
          final lateIds = {for (final r in al.lateReqs) '${r['id']}'};
          final noResIds = {for (final r in al.noResult) '${r['id']}'};
          final shown = s.data!['requests']!.where((r) {
            final st = '${r['status']}';
            if (f == 'laboratoire' && r['service'] != 'laboratoire') return false;
            if (f == 'imagerie' && r['service'] != 'imagerie') return false;
            if (f == 'open' && ['done', 'cancelled'].contains(st)) return false;
            if (f == 'late' && !lateIds.contains('${r['id']}')) return false;
            if (f == 'norest' && !noResIds.contains('${r['id']}')) return false;
            if (search.isEmpty) return true;
            final p = (r['patient'] ?? {}) as Map;
            return '${p['full_name']} ${p['phone']} ${(r['exam_names'] as List).join(' ')} ${(r['agent'] ?? {})['full_name']}'.toLowerCase().contains(search);
          }).take(200).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Patient, numéro, examen ou agent',
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [
                for (final e in labels.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(e.value), selected: f == e.key, onSelected: (_) => setState(() => f = e.key)),
                  ),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => setState(() {
                  fut = loadDir();
                }),
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
                  if (shown.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('Aucune demande dans cette catégorie.'))),
                  for (final r in shown)
                    panel(
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(r['service'] == 'imagerie' ? Icons.monitor_heart_rounded : Icons.science_rounded, color: r['service'] == 'imagerie' ? teal : navy, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${(r['patient'] ?? {})['full_name'] ?? 'Patient'}', style: const TextStyle(fontWeight: FontWeight.w800))),
                          statusChip(r['status']),
                        ]),
                        const SizedBox(height: 6),
                        Text((r['exam_names'] as List).join(', '), style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 14, runSpacing: 4, children: [
                          infoLine(Icons.schedule_rounded, 'Reçue il y a ${ageText(DateTime.parse('${r['created_at']}').toLocal())}'),
                          infoLine(r['mode'] == 'centre' ? Icons.apartment_rounded : Icons.home_rounded, r['mode'] == 'centre' ? 'Au centre' : 'À domicile'),
                          infoLine(Icons.badge_rounded, r['agent'] == null ? 'Aucun agent' : '${(r['agent'] ?? {})['full_name'] ?? 'Agent'}'),
                          if (lateIds.contains('${r['id']}')) infoLine(Icons.hourglass_top_rounded, 'En retard'),
                          if (noResIds.contains('${r['id']}')) infoLine(Icons.mark_email_unread_rounded, 'Résultat non envoyé'),
                        ]),
                      ]),
                      pad: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                    ),
                ]),
              ),
            ),
          ]);
        },
      );
}

// ---------- Direction : journal d'activité ----------
class DirActivity extends StatefulWidget {
  const DirActivity({super.key});
  @override
  State<DirActivity> createState() => _DirActivityState();
}

class _DirActivityState extends State<DirActivity> {
  late Future<List<Map<String, dynamic>>> fut = fetch();

  String svcName(dynamic s) => s == 'imagerie' ? 'Imagerie' : 'Laboratoire';

  Future<List<Map<String, dynamic>>> fetch() async {
    final reqs = await q(db.from('requests').select('id, status, created_at, done_at, exam_names, service, patient:profiles!patient_id(full_name)').order('created_at', ascending: false).limit(60));
    final res = await q(db.from('results').select('id, title, service, created_at, patient:profiles!patient_id(full_name), author:profiles!created_by(full_name)').order('created_at', ascending: false).limit(60));
    final ev = <Map<String, dynamic>>[];
    for (final r in reqs) {
      final who = '${(r['patient'] ?? {})['full_name'] ?? 'Patient'}';
      final ex = (r['exam_names'] as List).join(', ');
      ev.add({'at': r['created_at'], 'kind': 'new', 'title': 'Nouvelle demande · ${svcName(r['service'])}', 'sub': '$who — $ex'});
      if (r['status'] == 'done' && r['done_at'] != null) {
        ev.add({'at': r['done_at'], 'kind': 'done', 'title': 'Demande terminée · ${svcName(r['service'])}', 'sub': '$who — $ex'});
      }
    }
    for (final x in res) {
      ev.add({
        'at': x['created_at'],
        'kind': 'result',
        'title': 'Résultat envoyé · ${svcName(x['service'])}',
        'sub': '${(x['patient'] ?? {})['full_name'] ?? 'Patient'} — ${x['title']} (par ${(x['author'] ?? {})['full_name'] ?? 'le personnel'})',
      });
    }
    ev.sort((a, b) => DateTime.parse('${b['at']}').compareTo(DateTime.parse('${a['at']}')));
    return ev.take(80).toList();
  }

  String dayLabel(DateTime l) {
    final n = DateTime.now();
    final t0 = DateTime(n.year, n.month, n.day);
    final d0 = DateTime(l.year, l.month, l.day);
    final diff = t0.difference(d0).inDays;
    if (diff == 0) return 'Aujourd’hui';
    if (diff == 1) return 'Hier';
    return '${l.day} ${_mois[l.month - 1]}';
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<List<Map<String, dynamic>>>(
        future: fut,
        builder: (c, s) {
          if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Erreur : ${s.error}')));
          if (!s.hasData) return const ShimmerList();
          final w = <Widget>[];
          String? last;
          for (final e in s.data!) {
            final l = DateTime.parse('${e['at']}').toLocal();
            final lab = dayLabel(l);
            if (lab != last) {
              last = lab;
              w.add(Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 6), child: Text(lab.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: navy, fontSize: 12.5))));
            }
            final kind = e['kind'];
            final col = kind == 'result' ? teal : (kind == 'done' ? green : navy);
            final ic = kind == 'result' ? Icons.send_rounded : (kind == 'done' ? Icons.check_circle_rounded : Icons.add_circle_rounded);
            w.add(panel(
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: col.withAlpha(32), borderRadius: BorderRadius.circular(12)), child: Icon(ic, color: col, size: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    Text('${e['sub']}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF3B4C63))),
                  ]),
                ),
                const SizedBox(width: 8),
                Text(hhmm(e['at']), style: const TextStyle(fontSize: 12, color: muted)),
              ]),
              pad: const EdgeInsets.all(11),
              margin: const EdgeInsets.only(bottom: 7),
            ));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() { fut = fetch(); }),
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: w.isEmpty ? [const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('Aucune activité pour le moment.')))] : w),
          );
        },
      );
}

// ---------- Direction : équipe ----------
class DirTeam extends StatefulWidget {
  const DirTeam({super.key});
  @override
  State<DirTeam> createState() => _DirTeamState();
}

class _DirTeamState extends State<DirTeam> {
  late Future<List<List<Map<String, dynamic>>>> fut = fetch();

  Future<List<List<Map<String, dynamic>>>> fetch() async {
    final since = DateTime.now().subtract(const Duration(days: 30)).toUtc().toIso8601String();
    return [
      await q(db.from('profiles').select('id, full_name, phone, role').inFilter('role', ['major', 'preleveur', 'imagerie', 'promoteur', 'superadmin'])),
      await q(db.from('results').select('created_by').gte('created_at', since).limit(1000)),
    ];
  }

  Widget section(String title, IconData ic, Color col, List<Map<String, dynamic>> people, Map<String, int> sent, bool showSent) => panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(ic, color: col), const SizedBox(width: 8), Text('$title (${people.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))]),
        if (people.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Personne pour le moment.')),
        for (final p in people)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: CircleAvatar(radius: 17, backgroundColor: col, child: Text(initial('${p['full_name'] ?? ''}'), style: const TextStyle(color: Colors.white))),
            title: Text('${p['full_name'] ?? ''}'),
            subtitle: Text('${p['phone'] ?? ''}'),
            trailing: showSent ? Text('${sent['${p['id']}'] ?? 0} résultat(s)\n30 jours', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: muted)) : null,
          ),
      ]));

  @override
  Widget build(BuildContext c) => FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: fut,
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('Erreur : ${s.error}'));
          if (!s.hasData) return const ShimmerList();
          final staff = s.data![0];
          final sent = <String, int>{};
          for (final r in s.data![1]) {
            final k = '${r['created_by']}';
            sent[k] = (sent[k] ?? 0) + 1;
          }
          List<Map<String, dynamic>> by(List<String> roles) => staff.where((p) => roles.contains(p['role'])).toList();
          return RefreshIndicator(
            onRefresh: () async => setState(() { fut = fetch(); }),
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(14), children: [
              section('Direction', Icons.admin_panel_settings_rounded, const Color(0xFF7A4BB8), by(['promoteur', 'superadmin']), sent, false),
              section('Laboratoire', Icons.science_rounded, navy, by(['major', 'preleveur']), sent, true),
              section('Imagerie médicale', Icons.monitor_heart_rounded, teal, by(['imagerie']), sent, true),
            ]),
          );
        },
      );
}

// ---------- Administration : utilisateurs et rôles ----------
class UsersAdmin extends StatefulWidget {
  final String lab;
  final bool isSuper;
  const UsersAdmin({super.key, required this.lab, required this.isSuper});
  @override
  State<UsersAdmin> createState() => _UsersAdminState();
}

class _UsersAdminState extends State<UsersAdmin> {
  late Future<List<Map<String, dynamic>>> fut = fetch();
  String f = 'all';
  String search = '';
  static const labels = {'all': 'Tous', 'patient': 'Patients', 'major': 'Laboratoire', 'imagerie': 'Imagerie', 'promoteur': 'Direction'};

  Future<List<Map<String, dynamic>>> fetch() => q(db.from('profiles').select('id, full_name, phone, role').order('full_name').limit(1000));

  Future<void> assign(Map<String, dynamic> u, String role, String ok) async {
    final phone = '${u['phone'] ?? ''}';
    if (digits(phone).isEmpty) {
      snack(context, 'Cette personne n’a pas de numéro enregistré.');
      return;
    }
    await run(context, () => db.rpc('assign_user', params: {'p_email': phone, 'p_role': role, 'p_lab': widget.lab}), ok);
    if (mounted) setState(() => fut = fetch());
  }

  Future<void> release(Map<String, dynamic> u) async {
    final yes = await confirmBox(context, 'Retirer le rôle ?', '${u['full_name'] ?? 'Cette personne'} redeviendra simple patient et perdra l’accès à son espace.', 'Retirer');
    if (!yes || !mounted) return;
    await run(context, () => db.rpc('release_user', params: {'p_user': u['id']}), 'Rôle retiré.');
    if (mounted) setState(() => fut = fetch());
  }

  void actions(Map<String, dynamic> u) {
    final role = '${u['role']}';
    if (role == 'superadmin') {
      snack(context, 'Le compte Super Administrateur ne se modifie pas ici.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (d) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Row(children: [
              CircleAvatar(backgroundColor: navy, child: Text(initial('${u['full_name'] ?? ''}'), style: const TextStyle(color: Colors.white))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${u['full_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('${u['phone'] ?? ''} · ${roleFr(role)}', style: const TextStyle(color: muted, fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
          if (role != 'major') ListTile(leading: const Icon(Icons.science_rounded, color: navy), title: const Text('Nommer au laboratoire'), onTap: () { Navigator.pop(d); assign(u, 'major', 'Nommé(e) au laboratoire.'); }),
          if (role != 'imagerie') ListTile(leading: const Icon(Icons.monitor_heart_rounded, color: teal), title: const Text('Nommer à l’imagerie médicale'), onTap: () { Navigator.pop(d); assign(u, 'imagerie', 'Nommé(e) à l’imagerie.'); }),
          if (widget.isSuper && role != 'promoteur') ListTile(leading: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF7A4BB8)), title: const Text('Nommer promoteur (Direction)'), onTap: () { Navigator.pop(d); assign(u, 'promoteur', 'Nommé(e) promoteur.'); }),
          if (role != 'patient' && (widget.isSuper || role != 'promoteur')) ListTile(leading: const Icon(Icons.person_remove_rounded, color: danger), title: const Text('Retirer le rôle', style: TextStyle(color: danger)), onTap: () { Navigator.pop(d); release(u); }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<List<Map<String, dynamic>>>(
        future: fut,
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('Erreur : ${s.error}'));
          if (!s.hasData) return const ShimmerList();
          final all = s.data!;
          int count(String k) => k == 'all' ? all.length : all.where((u) => u['role'] == k).length;
          final shown = all.where((u) {
            if (f != 'all' && u['role'] != f) return false;
            if (search.isEmpty) return true;
            return '${u['full_name']} ${u['phone']}'.toLowerCase().contains(search);
          }).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Rechercher par nom ou numéro',
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [
                for (final e in labels.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text('${e.value} (${count(e.key)})'), selected: f == e.key, onSelected: (_) => setState(() => f = e.key)),
                  ),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => setState(() {
                  fut = fetch();
                }),
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
                  if (shown.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('Personne dans cette catégorie.'))),
                  for (final u in shown)
                    panel(
                      InkWell(
                        onTap: () => actions(u),
                        child: Row(children: [
                          CircleAvatar(backgroundColor: u['role'] == 'patient' ? muted : navy, child: Text(initial('${u['full_name'] ?? ''}'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${u['full_name'] ?? 'Sans nom'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${u['phone'] ?? ''}', style: const TextStyle(fontSize: 12.5, color: muted)),
                            ]),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: (u['role'] == 'patient' ? muted : navy).withAlpha(28), borderRadius: BorderRadius.circular(14)),
                            child: Text(u['role'] == 'patient' ? 'Patient' : roleFr(u['role']), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: u['role'] == 'patient' ? muted : navy)),
                          ),
                        ]),
                      ),
                      pad: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                    ),
                ]),
              ),
            ),
          ]);
        },
      );
}

// ---------- Espaces ----------
HubAction notifAction(BuildContext c) => HubAction(Icons.notifications_rounded, 'Notifications', teal, () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NotifPage())));
HubAction logoutAction() => HubAction(Icons.logout_rounded, 'Déconnexion', danger, () => signOutAll());

class NoCenter extends StatelessWidget {
  final String title;
  const NoCenter(this.title, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(title), actions: [logoutBtn()]),
        body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Aucun centre n’est rattaché à ce compte. Demandez au Super Administrateur de vous ajouter à l’équipe.', textAlign: TextAlign.center))),
      );
}

class LabSpace extends StatelessWidget {
  final String? lab;
  const LabSpace({super.key, this.lab});
  @override
  Widget build(BuildContext c) {
    final l = lab;
    if (l == null) return const NoCenter('Laboratoire');
    return ProShell(
      title: 'Laboratoire',
      subtitle: 'Espace du personnel',
      items: const [NavItem(Icons.home_rounded, 'Accueil'), NavItem(Icons.assignment_rounded, 'Demandes'), NavItem(Icons.home_work_rounded, 'À domicile'), NavItem(Icons.image_rounded, 'Résultats')],
      pages: (go) => [
        ServiceHome(lab: l, service: 'laboratoire', go: go),
        ReqBoard(lab: l, service: 'laboratoire'),
        ReqBoard(lab: l, service: 'laboratoire', homeOnly: true),
        const ResultsBoard(service: 'laboratoire'),
      ],
      hub: (c, go) => [
        HubAction(Icons.send_rounded, 'Envoyer un résultat', lime, () => pickAndSend(c, 'laboratoire')),
        HubAction(Icons.biotech_rounded, 'Examens', navy, () => pushPage(c, 'Examens du laboratoire', MajorExams(lab: l, service: 'laboratoire'))),
        notifAction(c),
        logoutAction(),
      ],
    );
  }
}

class ImagerieSpace extends StatelessWidget {
  final String? lab;
  const ImagerieSpace({super.key, this.lab});
  @override
  Widget build(BuildContext c) {
    final l = lab;
    if (l == null) return const NoCenter('Imagerie médicale');
    return ProShell(
      title: 'Imagerie médicale',
      subtitle: 'Espace du personnel',
      items: const [NavItem(Icons.home_rounded, 'Accueil'), NavItem(Icons.event_available_rounded, 'Rendez-vous'), NavItem(Icons.image_rounded, 'Résultats'), NavItem(Icons.biotech_rounded, 'Examens')],
      pages: (go) => [
        ServiceHome(lab: l, service: 'imagerie', go: go),
        ReqBoard(lab: l, service: 'imagerie'),
        const ResultsBoard(service: 'imagerie'),
        MajorExams(lab: l, service: 'imagerie'),
      ],
      hub: (c, go) => [
        HubAction(Icons.send_rounded, 'Envoyer un résultat', lime, () => pickAndSend(c, 'imagerie')),
        notifAction(c),
        logoutAction(),
      ],
    );
  }
}

class ServicePanel extends StatefulWidget {
  final String lab, service;
  const ServicePanel({super.key, required this.lab, required this.service});
  @override
  State<ServicePanel> createState() => _ServicePanelState();
}

class _ServicePanelState extends State<ServicePanel> {
  int sub = 0;
  @override
  Widget build(BuildContext c) {
    final lab = widget.service == 'laboratoire';
    final labels = ['Demandes', if (lab) 'À domicile', 'Résultats', 'Examens', 'Équipe'];
    final keys = ['req', if (lab) 'home', 'res', 'ex', 'team'];
    final Widget body = switch (keys[sub]) {
      'req' => ReqBoard(key: const ValueKey('req'), lab: widget.lab, service: widget.service),
      'home' => ReqBoard(key: const ValueKey('home'), lab: widget.lab, service: widget.service, homeOnly: true),
      'res' => ResultsBoard(service: widget.service),
      'ex' => MajorExams(lab: widget.lab, service: widget.service),
      _ => StaffList(lab: widget.lab, service: widget.service, isAdmin: true),
    };
    return Column(children: [
      SizedBox(
        height: 56,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(10), children: [
          for (var i = 0; i < labels.length; i++)
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(labels[i]), selected: sub == i, onSelected: (_) => setState(() => sub = i))),
        ]),
      ),
      Expanded(child: body),
    ]);
  }
}

class SuperShell extends StatelessWidget {
  const SuperShell({super.key});
  @override
  Widget build(BuildContext c) => FutureBuilder<List<Map<String, dynamic>>>(
        future: q(db.from('labs').select('id').order('created_at').limit(1)),
        builder: (c, s) {
          if (s.hasError) return Scaffold(appBar: AppBar(actions: [logoutBtn()]), body: Center(child: Text('Erreur : ${s.error}')));
          if (!s.hasData) return const Scaffold(body: ShimmerList());
          if (s.data!.isEmpty) return Scaffold(appBar: AppBar(actions: [logoutBtn()]), body: const Center(child: Text('Aucun centre créé.')));
          final lab = s.data!.first['id'] as String;
          return ProShell(
            title: 'Administration',
            subtitle: 'Super Administrateur · contrôle total',
            items: const [NavItem(Icons.insights_rounded, 'Tableau de bord'), NavItem(Icons.track_changes_rounded, 'Suivi'), NavItem(Icons.science_rounded, 'Laboratoire'), NavItem(Icons.monitor_heart_rounded, 'Imagerie')],
            pages: (go) => [
              const DirDashboard(),
              const DirTracking(),
              ServicePanel(lab: lab, service: 'laboratoire'),
              ServicePanel(lab: lab, service: 'imagerie'),
            ],
            hub: (c, go) => [
              HubAction(Icons.send_rounded, 'Envoyer un résultat', lime, () => pickAndSend(c, null)),
              HubAction(Icons.manage_accounts_rounded, 'Utilisateurs', navy, () => pushPage(c, 'Utilisateurs et rôles', UsersAdmin(lab: lab, isSuper: true))),
              HubAction(Icons.apartment_rounded, 'Centre', const Color(0xFF7A4BB8), () => pushPage(c, 'Centre : contacts et réglages', CenterAdmin(lab: lab, isSuper: true))),
              HubAction(Icons.history_rounded, 'Activité', teal, () => pushPage(c, 'Activité du centre', const DirActivity())),
              HubAction(Icons.groups_rounded, 'Équipe', green, () => pushPage(c, 'Équipe du centre', const DirTeam())),
              HubAction(Icons.delete_sweep_rounded, 'Suppressions', danger, () => pushPage(c, 'Demandes de suppression', const DeletionRequests())),
              HubAction(Icons.today_rounded, 'Rapport du jour', amber, () => copyReport(c, 0, 'aujourd’hui')),
              HubAction(Icons.admin_panel_settings_rounded, 'Vue Direction', ink, () => Navigator.push(c, MaterialPageRoute(builder: (_) => const DirectionPage()))),
              notifAction(c),
              logoutAction(),
            ],
          );
        },
      );
}

class DirectionPage extends StatelessWidget {
  const DirectionPage({super.key});
  @override
  Widget build(BuildContext c) => ProShell(
        title: 'Direction',
        subtitle: 'Centre Saint-Victor de Bafia · bureau de suivi',
        items: const [NavItem(Icons.insights_rounded, 'Tableau de bord'), NavItem(Icons.track_changes_rounded, 'Suivi'), NavItem(Icons.history_rounded, 'Activité'), NavItem(Icons.groups_rounded, 'Équipe')],
        pages: (go) => [const DirDashboard(), const DirTracking(), const DirActivity(), const DirTeam()],
        hub: (c, go) => [
          HubAction(Icons.today_rounded, 'Rapport du jour', lime, () => copyReport(c, 0, 'aujourd’hui')),
          HubAction(Icons.date_range_rounded, 'Rapport 7 jours', navy, () => copyReport(c, 7, '7 derniers jours')),
          HubAction(Icons.date_range_rounded, 'Rapport 30 jours', teal, () => copyReport(c, 30, '30 derniers jours')),
          notifAction(c),
          logoutAction(),
        ],
      );
}

// ---------- Messagerie : modifier / supprimer / effacer la conversation ----------
class _ChatPageState extends State<ChatPage> {
  final ctl = TextEditingController();
  dynamic editing;
  DateTime? clearedAt;
  bool ready = false;
  late final Stream<List<Map<String, dynamic>>> st = db.from('messages').stream(primaryKey: ['id']).eq('request_id', widget.id).order('created_at', ascending: true);

  @override
  void initState() {
    super.initState();
    loadClear();
  }

  Future<void> loadClear() async {
    try {
      final r = await q(db.from('chat_clears').select('cleared_at').eq('request_id', widget.id));
      if (r.isNotEmpty) clearedAt = DateTime.parse('${r.first['cleared_at']}');
    } catch (_) {}
    if (mounted) setState(() => ready = true);
  }

  Future<void> clearChat() async {
    final yes = await confirmBox(context, 'Effacer la conversation ?', 'Les messages seront effacés pour vous seulement. L’autre personne les conserve.', 'Effacer');
    if (!yes || !mounted) return;
    try {
      final ts = await db.rpc('clear_chat', params: {'p_req': widget.id});
      if (!mounted) return;
      setState(() {
        clearedAt = DateTime.parse('$ts');
        editing = null;
        ctl.clear();
      });
      snack(context, 'Conversation effacée.');
    } on PostgrestException catch (e) {
      if (mounted) snack(context, e.message);
    }
  }

  Future<void> send(String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    final eid = editing;
    ctl.clear();
    setState(() => editing = null);
    if (eid != null) {
      await run(context, () => db.from('messages').update({'body': text, 'edited_at': DateTime.now().toUtc().toIso8601String()}).eq('id', eid));
    } else {
      await run(context, () => db.from('messages').insert({'request_id': widget.id, 'sender_id': db.auth.currentUser!.id, 'body': text}));
    }
  }

  // Appel téléphonique normal : ouvre le composeur du téléphone avec le bon numéro.
  Future<void> call() async {
    String? ph;
    try {
      final r = await q(db.from('requests').select('patient_id').eq('id', widget.id));
      final pid = r.isEmpty ? null : '${r.first['patient_id']}';
      if (pid != null && pid != db.auth.currentUser!.id) {
        final p = await q(db.from('profiles').select('phone').eq('id', pid));
        if (p.isNotEmpty) ph = '${p.first['phone'] ?? ''}';
      } else {
        ph = await centerPhone();
      }
    } catch (_) {}
    if (ph == null || digits(ph).isEmpty) {
      if (mounted) snack(context, 'Le numéro à appeler n’est pas disponible.');
      return;
    }
    await launchUrl(Uri.parse('tel:${ph.replaceAll(' ', '')}'));
  }

  Future<void> menu(Map<String, dynamic> m) async {
    final mine = m['sender_id'] == db.auth.currentUser!.id;
    final act = await showModalBottomSheet<String>(
      context: context,
      builder: (d) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.copy_rounded), title: const Text('Copier'), onTap: () => Navigator.pop(d, 'copy')),
          if (mine) ListTile(leading: const Icon(Icons.edit_rounded), title: const Text('Modifier'), onTap: () => Navigator.pop(d, 'edit')),
          if (mine) ListTile(leading: const Icon(Icons.delete_outline_rounded, color: danger), title: const Text('Supprimer pour tous', style: TextStyle(color: danger)), onTap: () => Navigator.pop(d, 'del')),
        ]),
      ),
    );
    if (act == null || !mounted) return;
    if (act == 'copy') {
      await Clipboard.setData(ClipboardData(text: '${m['body']}'));
      if (mounted) snack(context, 'Message copié.');
    } else if (act == 'edit') {
      setState(() {
        editing = m['id'];
        ctl.text = '${m['body']}';
      });
    } else if (act == 'del') {
      final yes = await confirmBox(context, 'Supprimer ce message ?', 'Il sera remplacé par « Message supprimé » pour tout le monde.', 'Supprimer');
      if (yes && mounted) {
        await run(context, () => db.from('messages').update({'deleted': true, 'body': 'Message supprimé'}).eq('id', m['id']));
      }
    }
  }

  Widget bubble(Map<String, dynamic> m) {
    final mine = m['sender_id'] == db.auth.currentUser!.id;
    final del = m['deleted'] == true;
    final edited = m['edited_at'] != null && !del;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: GestureDetector(
          onLongPress: del ? null : () => menu(m),
          onTap: () {
            final u = RegExp(r'https://\S+').firstMatch('${m['body']}');
            if (u != null && !del) launchUrl(Uri.parse(u.group(0)!), mode: LaunchMode.externalApplication);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: mine ? const Color(0xFFDDEFB5) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(mine ? 14 : 3),
                bottomRight: Radius.circular(mine ? 3 : 14),
              ),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Text(del ? 'Message supprimé' : '${m['body']}', style: TextStyle(fontStyle: del ? FontStyle.italic : FontStyle.normal, color: del ? Colors.grey : const Color(0xFF14233B))),
              const SizedBox(height: 2),
              Text('${edited ? 'modifié · ' : ''}${hhmm(m['created_at'])}', style: const TextStyle(fontSize: 10, color: Color(0xFF7A8798))),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: soft,
        appBar: AppBar(
          title: Text(widget.title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(icon: const Icon(Icons.call), tooltip: 'Appeler', onPressed: call),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'clear') clearChat();
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'clear', child: Text('Effacer la conversation'))],
            ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: !ready
                ? const ShimmerList()
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: st,
                    builder: (c, s) {
                      if (s.hasError) return Center(child: Text('Erreur : ${s.error}'));
                      if (!s.hasData) return const ShimmerList();
                      final ca = clearedAt;
                      final list = s.data!.where((m) => ca == null || DateTime.parse('${m['created_at']}').isAfter(ca)).toList();
                      return ListView(padding: const EdgeInsets.all(10), children: [
                        if (list.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun message. Écrivez le premier.'))),
                        for (final m in list) bubble(m),
                      ]);
                    },
                  ),
          ),
          if (editing != null)
            Container(
              color: pale,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(children: [
                const Icon(Icons.edit_rounded, size: 18, color: navy),
                const SizedBox(width: 8),
                const Expanded(child: Text('Modification du message', style: TextStyle(fontWeight: FontWeight.w600, color: navy))),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    editing = null;
                    ctl.clear();
                  }),
                ),
              ]),
            ),
          SafeArea(
            child: Container(
              color: Colors.white,
              child: Row(children: [
                Expanded(child: Padding(padding: const EdgeInsets.all(8), child: TextField(controller: ctl, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Votre message'), onSubmitted: send))),
                IconButton(icon: Icon(editing != null ? Icons.check_rounded : Icons.send_rounded, color: navy), onPressed: () => send(ctl.text)),
              ]),
            ),
          ),
        ]),
      );
}

// =====================================================================
//  Lot 1 : verrouillage par code, bienvenue, avis, ordonnance
// =====================================================================

final pinCode = ValueNotifier<String?>(null);

class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});
  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  bool loaded = false, locked = false;
  DateTime? pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pinCode.addListener(onPin);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pinCode.removeListener(onPin);
    super.dispose();
  }

  Future<void> load() async {
    final p = (await SharedPreferences.getInstance()).getString('pin');
    pinCode.value = p;
    if (mounted) {
      setState(() {
        loaded = true;
        locked = p != null;
      });
    }
  }

  void onPin() {
    if (pinCode.value == null && locked && mounted) {
      setState(() {
        locked = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) pausedAt = DateTime.now();
    if (s == AppLifecycleState.resumed && pinCode.value != null && pausedAt != null && DateTime.now().difference(pausedAt!).inSeconds > 120) {
      setState(() {
        locked = true;
      });
    }
  }

  @override
  Widget build(BuildContext c) {
    if (!loaded) return const Scaffold(backgroundColor: ink);
    return Stack(fit: StackFit.expand, children: [
      widget.child,
      if (locked)
        Positioned.fill(
          child: LockScreen(
            pin: pinCode.value ?? '',
            onUnlock: () => setState(() {
              locked = false;
            }),
          ),
        ),
    ]);
  }
}

class LockScreen extends StatefulWidget {
  final String pin;
  final VoidCallback onUnlock;
  const LockScreen({super.key, required this.pin, required this.onUnlock});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String entry = '';
  bool wrong = false;

  void tap(String d) {
    if (entry.length >= 4) return;
    setState(() {
      entry += d;
      wrong = false;
    });
    if (entry.length == 4) {
      if (entry == widget.pin) {
        widget.onUnlock();
      } else {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            setState(() {
              entry = '';
              wrong = true;
            });
          }
        });
      }
    }
  }

  void back() => setState(() {
        if (entry.isNotEmpty) entry = entry.substring(0, entry.length - 1);
      });

  Widget key(String k) {
    if (k.isEmpty) return const SizedBox();
    return Material(
      color: Colors.white.withAlpha(24),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => k == '<' ? back() : tap(k),
        child: Center(child: k == '<' ? const Icon(Icons.backspace_rounded, color: Colors.white) : Text(k, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600))),
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: ink,
        body: SafeArea(
          child: Column(children: [
            const Spacer(flex: 2),
            Container(width: 84, height: 84, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), padding: const EdgeInsets.all(12), child: Image.asset('assets/logo.png')),
            const SizedBox(height: 16),
            const Text('Saint-Victor', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(t('Entrez votre code', 'Enter your code'), style: const TextStyle(color: pale)),
            const SizedBox(height: 22),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 4; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i < entry.length ? limeLight : Colors.transparent, border: Border.all(color: wrong ? const Color(0xFFFF8A80) : Colors.white54, width: 1.5)),
                ),
            ]),
            const SizedBox(height: 10),
            Text(wrong ? t('Code incorrect', 'Wrong code') : '', style: const TextStyle(color: Color(0xFFFF8A80))),
            const Spacer(),
            SizedBox(
              width: 300,
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<']) key(k)],
              ),
            ),
            TextButton(
              onPressed: () async {
                await (await SharedPreferences.getInstance()).remove('pin');
                pinCode.value = null;
                await signOutAll();
              },
              child: Text(t('Code oublié ? Se déconnecter', 'Forgot the code? Sign out'), style: const TextStyle(color: pale)),
            ),
            const Spacer(),
          ]),
        ),
      );
}

Future<void> setPinFlow(BuildContext c) async {
  final a = await ask(c, t('Choisissez un code à 4 chiffres', 'Choose a 4-digit code'), t('Code', 'Code'));
  if (a == null || !c.mounted) return;
  if (!RegExp(r'^\d{4}$').hasMatch(a.trim())) {
    snack(c, t('Le code doit comporter exactement 4 chiffres.', 'The code must have exactly 4 digits.'));
    return;
  }
  final b = await ask(c, t('Confirmez le code', 'Confirm the code'), t('Code', 'Code'));
  if (b == null || !c.mounted) return;
  if (b.trim() != a.trim()) {
    snack(c, t('Les deux codes ne sont pas identiques.', 'The two codes do not match.'));
    return;
  }
  await (await SharedPreferences.getInstance()).setString('pin', a.trim());
  pinCode.value = a.trim();
  if (c.mounted) snack(c, t('Verrouillage activé.', 'Lock enabled.'));
}

Future<void> clearPin(BuildContext c) async {
  await (await SharedPreferences.getInstance()).remove('pin');
  pinCode.value = null;
  if (c.mounted) snack(c, t('Verrouillage désactivé.', 'Lock disabled.'));
}

// ---------- Écrans de bienvenue (une seule fois) ----------
class Onboarding extends StatefulWidget {
  final Widget child;
  const Onboarding({super.key, required this.child});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  bool? seen;
  final pc = PageController();
  int page = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          seen = p.getBool('onboarded') ?? false;
        });
      }
    });
  }

  Future<void> finish() async {
    (await SharedPreferences.getInstance()).setBool('onboarded', true);
    if (mounted) {
      setState(() {
        seen = true;
      });
    }
  }

  List<List<dynamic>> get slides => [
        ['assets/banner_labo.jpg', Icons.add_circle_rounded, t('Commandez en quelques secondes', 'Order in seconds'), t('Choisissez vos analyses ou vos examens d’imagerie, la date et le lieu. Le centre vous confirme.', 'Choose your tests or imaging exams, the date and the place. The center confirms.')],
        ['assets/banner_imagerie.jpg', Icons.timeline_rounded, t('Suivez votre demande en direct', 'Follow your request live'), t('Du prélèvement au résultat, vous voyez chaque étape et vous pouvez écrire ou appeler le centre.', 'From sampling to result, see every step and message or call the center.')],
        ['assets/banner_direction.jpg', Icons.image_rounded, t('Recevez vos résultats en haute définition', 'Receive your results in high definition'), t('Vos résultats arrivent dans l’application, en toute confidentialité. Vous pouvez les revoir et les télécharger à tout moment.', 'Your results arrive in the app, in full confidentiality. View and download them anytime.')],
      ];

  Widget slide(List<dynamic> p) => Column(children: [
        Expanded(
          flex: 5,
          child: SizedBox(width: double.infinity, child: ClipRRect(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)), child: Image.asset(p[0] as String, fit: BoxFit.cover))),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            child: Column(children: [
              Container(width: 58, height: 58, decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(18)), child: Icon(p[1] as IconData, color: limeLight, size: 30)),
              const SizedBox(height: 16),
              Text(p[2] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: navy)),
              const SizedBox(height: 10),
              Text(p[3] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, color: muted, height: 1.4)),
            ]),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext c) {
    if (seen == null) return const Scaffold(backgroundColor: ink);
    if (seen == true) return widget.child;
    final n = slides.length;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(child: PageView(controller: pc, onPageChanged: (i) => setState(() => page = i), children: [for (final p in slides) slide(p)])),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              TextButton(onPressed: finish, child: Text(t('Passer', 'Skip'))),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < n; i++)
                    AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 3), width: i == page ? 22 : 8, height: 8, decoration: BoxDecoration(color: i == page ? navy : const Color(0xFFC9D4E4), borderRadius: BorderRadius.circular(6))),
                ]),
              ),
              FilledButton(
                onPressed: () => page == n - 1 ? finish() : pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                child: Text(page == n - 1 ? t('Commencer', 'Start') : t('Suivant', 'Next')),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------- Avis du patient (étoiles) ----------
class RatingSheet extends StatefulWidget {
  const RatingSheet({super.key});
  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
  int stars = 0;
  final ctl = TextEditingController();

  @override
  Widget build(BuildContext c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 42, height: 4, decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 16),
          Text(t('Comment s’est passé votre passage ?', 'How was your visit?'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                iconSize: 38,
                onPressed: () => setState(() => stars = i),
                icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_border_rounded, color: amber),
              ),
          ]),
          TextField(controller: ctl, maxLength: 300, minLines: 1, maxLines: 3, decoration: InputDecoration(hintText: t('Un commentaire ? (facultatif)', 'A comment? (optional)'))),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: stars == 0 ? null : () => Navigator.pop(c, {'stars': stars, 'comment': ctl.text.trim()}), child: Text(t('Envoyer mon avis', 'Send my feedback'))),
          ),
        ]),
      );
}

Future<bool> rateResult(BuildContext c, String resultId) async {
  final r = await showModalBottomSheet<Map<String, dynamic>>(
    context: c,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (d) => const RatingSheet(),
  );
  if (r == null || !c.mounted) return false;
  final cm = '${r['comment']}';
  return run(c, () => db.from('feedback').insert({'result_id': resultId, 'stars': r['stars'], if (cm.isNotEmpty) 'comment': cm}), t('Merci pour votre avis !', 'Thank you for your feedback!'));
}

Future<void> openPrescription(BuildContext c, String path) async {
  try {
    final url = await db.storage.from('ordonnances').createSignedUrl(path, 600);
    if (c.mounted) Navigator.push(c, MaterialPageRoute(builder: (_) => ResultViewer(url: url, title: 'Ordonnance')));
  } catch (e) {
    if (c.mounted) snack(c, 'Erreur : $e');
  }
}
