part of 'main.dart';

// =====================================================================
//  Espace patient premium (même style que Laboratoire / Administration)
// =====================================================================

String greet() {
  final h = DateTime.now().hour;
  if (h < 12) return t('Bonjour', 'Good morning');
  if (h < 18) return t('Bon après-midi', 'Good afternoon');
  return t('Bonsoir', 'Good evening');
}

Future<String?> centerPhone() async {
  try {
    final cs = await q(db.from('contacts').select().order('id').limit(1));
    return cs.isEmpty ? null : '${cs.first['phone']}';
  } catch (_) {
    return null;
  }
}

Future<void> callCenter(BuildContext c) async {
  final ph = await centerPhone();
  if (ph == null) {
    if (c.mounted) snack(c, t('Le numéro du centre n’est pas disponible.', 'The center number is not available.'));
    return;
  }
  await launchUrl(Uri.parse('tel:$ph'.replaceAll(' ', '')));
}

Future<void> whatsappCenter(BuildContext c) async {
  final ph = await centerPhone();
  if (ph == null) {
    if (c.mounted) snack(c, t('Le numéro du centre n’est pas disponible.', 'The center number is not available.'));
    return;
  }
  await launchUrl(Uri.parse('https://wa.me/${digits(ph)}'), mode: LaunchMode.externalApplication);
}

double reqProgress(String s) {
  switch (s) {
    case 'pending':
      return 0.15;
    case 'accepted':
      return 0.4;
    case 'en_route':
      return 0.55;
    case 'arrived':
      return 0.65;
    case 'collected':
      return 0.8;
    case 'done':
      return 1.0;
    default:
      return 0.0;
  }
}

String stepText(String s) {
  switch (s) {
    case 'pending':
      return t('Demande envoyée : le centre va la confirmer', 'Request sent: the center will confirm it');
    case 'accepted':
      return t('Confirmée par le centre', 'Confirmed by the center');
    case 'en_route':
      return t('Le préleveur est en route', 'The sampler is on the way');
    case 'arrived':
      return t('Le préleveur est arrivé', 'The sampler has arrived');
    case 'collected':
      return t('Prélèvement effectué, analyse en cours', 'Sample taken, analysis in progress');
    case 'done':
      return t('Terminée : résultat disponible', 'Completed: result available');
    default:
      return '';
  }
}

Widget reqProgressBar(String st) => st == 'cancelled'
    ? const SizedBox()
    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: reqProgress(st), minHeight: 7, color: statusColor(st), backgroundColor: soft)),
        const SizedBox(height: 4),
        Text(stepText(st), style: const TextStyle(fontSize: 11.5, color: muted)),
      ]);

Widget quickTile(IconData ic, String title, String sub, Color col, VoidCallback onTap) => Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: cardShadow),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [col, col.withAlpha(190)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14)),
                child: Icon(ic, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              Text(sub, style: const TextStyle(fontSize: 12, color: muted)),
            ]),
          ),
        ),
      ),
    );

Widget pill(IconData ic, String s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: navy.withAlpha(18), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 15, color: navy),
        const SizedBox(width: 5),
        Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: navy)),
      ]),
    );

Widget serviceRow(IconData ic, Color col, String title, String sub) => Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: col.withAlpha(30), borderRadius: BorderRadius.circular(12)), child: Icon(ic, color: col)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(sub, style: const TextStyle(fontSize: 12.5, color: muted)),
        ]),
      ),
    ]);

// ---------- Accueil patient ----------
class PatientHome extends StatefulWidget {
  final void Function(int) go;
  final String name;
  const PatientHome({super.key, required this.go, required this.name});
  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  late Future<List<List<Map<String, dynamic>>>> fut = fetch();

  Future<List<List<Map<String, dynamic>>>> fetch() async => [
        await q(db.from('requests').select().eq('patient_id', db.auth.currentUser!.id).order('created_at', ascending: false).limit(10)),
        await q(db.from('results').select('id, title, file_path, service, created_at').order('created_at', ascending: false).limit(3)),
      ];

  @override
  Widget build(BuildContext c) => FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: fut,
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('Erreur : ${s.error}'));
          if (!s.hasData) return const ShimmerList();
          final reqs = s.data![0], res = s.data![1];
          final active = reqs.where((r) => !['done', 'cancelled'].contains(r['status'])).toList();
          return RefreshIndicator(
            onRefresh: () async => setState(() {
              fut = fetch();
            }),
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(14), children: [
              heroBanner('assets/banner_direction.jpg', '${greet()}${widget.name.trim().isEmpty ? '' : ', ${widget.name.trim().split(' ').first}'}', t('Bienvenue au Centre d’Imagerie et d’Analyse Médicale', 'Welcome to the Imaging and Medical Analysis Center')),
              sectionTitle(t('Que souhaitez-vous faire ?', 'What would you like to do?')),
              Row(children: [
                Expanded(child: quickTile(Icons.add_circle_rounded, t('Commander', 'Order'), t('Analyses et imagerie', 'Tests and imaging'), navy, () => widget.go(1))),
                const SizedBox(width: 12),
                Expanded(child: quickTile(Icons.assignment_rounded, t('Mes demandes', 'My requests'), t('Suivi en direct', 'Live tracking'), teal, () => widget.go(2))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: quickTile(Icons.image_rounded, t('Mes résultats', 'My results'), t('Voir et télécharger', 'View and download'), green, () => widget.go(3))),
                const SizedBox(width: 12),
                Expanded(child: quickTile(Icons.call_rounded, t('Appeler', 'Call'), t('Joindre le centre', 'Reach the center'), amber, () => callCenter(c))),
              ]),
              const SizedBox(height: 18),
              sectionTitle(t('Ma demande en cours', 'My current request')),
              if (active.isEmpty)
                panel(Row(children: [
                  const Icon(Icons.inbox_rounded, color: muted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t('Aucune demande en cours.', 'No request in progress.'))),
                  TextButton(onPressed: () => widget.go(1), child: Text(t('Commander', 'Order'))),
                ])),
              for (final r in active.take(2))
                panel(
                  InkWell(
                    onTap: () => openChat(c, r),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(r['service'] == 'imagerie' ? Icons.monitor_heart_rounded : Icons.science_rounded, color: r['service'] == 'imagerie' ? teal : navy, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text((r['exam_names'] as List).join(', '), style: const TextStyle(fontWeight: FontWeight.w800))),
                        statusChip(r['status']),
                      ]),
                      const SizedBox(height: 6),
                      infoLine(Icons.event_rounded, '${r['wanted_date']} · ${r['slot']}'),
                      const SizedBox(height: 10),
                      reqProgressBar('${r['status']}'),
                    ]),
                  ),
                ),
              const SizedBox(height: 6),
              sectionTitle(t('Mes derniers résultats', 'My latest results')),
              if (res.isEmpty) panel(Text(t('Vos résultats apparaîtront ici dès que le centre les aura envoyés.', 'Your results will appear here as soon as the center sends them.'))),
              for (final x in res)
                panel(
                  Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: green.withAlpha(30), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.image_rounded, color: green)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${x['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(day(x['created_at']), style: const TextStyle(fontSize: 12, color: muted)),
                      ]),
                    ),
                    IconButton(icon: const Icon(Icons.visibility_rounded, color: navy), tooltip: t('Voir', 'View'), onPressed: () => openResult(c, '${x['file_path']}')),
                    IconButton(icon: const Icon(Icons.download_rounded, color: navy), tooltip: t('Télécharger', 'Download'), onPressed: () => openResult(c, '${x['file_path']}', download: true)),
                  ]),
                  pad: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                ),
              if (res.isNotEmpty) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => widget.go(3), child: Text(t('Voir tous mes résultats', 'See all my results')))),
              const SizedBox(height: 6),
              sectionTitle(t('Nos services', 'Our services')),
              panel(Column(children: [
                serviceRow(Icons.monitor_heart_rounded, teal, t('Imagerie médicale', 'Medical imaging'), t('Radiographie, échographie', 'X-ray, ultrasound')),
                const Divider(height: 22),
                serviceRow(Icons.science_rounded, navy, t('Analyses médicales', 'Medical tests'), t('Prélèvements au centre ou à domicile', 'Sampling at the center or at home')),
              ])),
              panel(Wrap(spacing: 8, runSpacing: 8, children: [
                pill(Icons.workspace_premium_rounded, t('Professionnalisme', 'Professionalism')),
                pill(Icons.lock_rounded, t('Confidentialité', 'Confidentiality')),
                pill(Icons.verified_rounded, t('Qualité', 'Quality')),
                pill(Icons.favorite_rounded, t('Respect', 'Respect')),
              ])),
              panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('Une question ? Contactez le centre', 'A question? Contact the center'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: FilledButton.icon(icon: const Icon(Icons.call_rounded, size: 18), label: Text(t('Appeler', 'Call')), onPressed: () => callCenter(c))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.chat_rounded, size: 18), label: const Text('WhatsApp'), onPressed: () => whatsappCenter(c))),
                ]),
              ])),
            ]),
          );
        },
      );
}

// ---------- Commander ----------
class OrderTab extends StatefulWidget {
  final String? lab;
  final void Function(int)? go;
  const OrderTab({super.key, this.lab, this.go});
  @override
  State<OrderTab> createState() => _OrderTabState();
}

class _OrderTabState extends State<OrderTab> {
  final sel = <String>{}, centerOnly = <String>{}, imaging = <String>{};
  final quarter = TextEditingController(), addr = TextEditingController();
  String slot = slots.first, mode = 'domicile', filter = '';
  DateTime? date;
  XFile? rx;
  List<Map<String, dynamic>> allEx = [];
  double? lat, lng;
  bool busy = false;
  late final ex = q(db.from('lab_exams').select('custom_conditions, exams(name, discipline, conditions, at_center_only, service)').eq('lab_id', widget.lab ?? '').eq('active', true));

  List<String> get labSel => sel.where((n) => !imaging.contains(n)).toList();
  List<String> get imgSel => sel.where(imaging.contains).toList();
  bool get labAtCenter => mode == 'centre' || labSel.any(centerOnly.contains);

  Future<void> pickRx() async {
    final src = await showModalBottomSheet<String>(
      context: context,
      builder: (d) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_rounded), title: Text(t('Prendre une photo', 'Take a photo')), onTap: () => Navigator.pop(d, 'cam')),
          ListTile(leading: const Icon(Icons.photo_library_rounded), title: Text(t('Choisir dans la galerie', 'Choose from gallery')), onTap: () => Navigator.pop(d, 'gal')),
          if (rx != null) ListTile(leading: const Icon(Icons.delete_outline_rounded, color: danger), title: Text(t('Retirer la photo', 'Remove the photo')), onTap: () => Navigator.pop(d, 'del')),
        ]),
      ),
    );
    if (src == null) return;
    if (src == 'del') {
      setState(() {
        rx = null;
      });
      return;
    }
    final x = await ImagePicker().pickImage(source: src == 'cam' ? ImageSource.camera : ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
    if (x != null && mounted) {
      setState(() {
        rx = x;
      });
    }
  }

  Future<void> send() async {
    final lb = labSel, im = imgSel, labCtr = labAtCenter;
    if (sel.isEmpty || date == null || (lb.isNotEmpty && !labCtr && (quarter.text.trim().isEmpty || addr.text.trim().isEmpty))) {
      snack(context, 'Choisissez au moins un examen, la date et, pour un prélèvement à domicile, le quartier et le lieu.');
      return;
    }
    final prep = <String>[];
    for (final x in allEx) {
      final n = '${x['exams']['name']}';
      if (sel.contains(n)) {
        final cond = '${x['custom_conditions'] ?? x['exams']['conditions'] ?? ''}'.trim();
        if (cond.isNotEmpty) prep.add('$n : $cond');
      }
    }
    setState(() => busy = true);
    String? rxPath;
    final photo = rx;
    if (photo != null) {
      final png = photo.name.toLowerCase().endsWith('.png');
      final path = '${db.auth.currentUser!.id}/${DateTime.now().microsecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
      final bytes = await photo.readAsBytes();
      final good = await runAny(context, () => db.storage.from('ordonnances').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: png ? 'image/png' : 'image/jpeg')));
      if (!good) {
        if (mounted) setState(() => busy = false);
        return;
      }
      rxPath = path;
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
          if (rxPath != null) 'prescription_path': rxPath,
        };
    final rows0 = <Map<String, dynamic>>[
      if (lb.isNotEmpty) row('laboratoire', lb, labCtr),
      if (im.isNotEmpty) row('imagerie', im, true),
    ];
    final ok = await run(context, () => db.from('requests').insert(rows0),
        rows0.length > 1 ? 'Vos demandes d’analyses et d’imagerie sont envoyées. Le centre va vous confirmer.' : 'Demande envoyée. Le centre va vous confirmer.');
    if (ok) {
      lat = null;
      lng = null;
      sel.clear();
      quarter.clear();
      addr.clear();
      date = null;
      rx = null;
    }
    if (mounted) setState(() => busy = false);
    if (ok && mounted) {
      if (prep.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (d) => AlertDialog(
            title: Row(children: [const Icon(Icons.check_circle_rounded, color: green), const SizedBox(width: 8), Expanded(child: Text(t('Demande envoyée', 'Request sent')))]),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('À savoir avant votre examen :', 'Before your exam:'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (final p in prep)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_rounded, size: 18, color: navy), const SizedBox(width: 8), Expanded(child: Text(p))]),
                  ),
              ]),
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(d), child: Text(t('Voir mes demandes', 'See my requests')))],
          ),
        );
      }
      widget.go?.call(2);
    }
  }

  Widget stepHeader(int n, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
        child: Row(children: [
          Container(width: 26, height: 26, alignment: Alignment.center, decoration: const BoxDecoration(color: navy, shape: BoxShape.circle), child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: navy)),
        ]),
      );

  Widget examCard(Map<String, dynamic> x) {
    final name = '${x['exams']['name']}';
    final on = sel.contains(name);
    final img = x['exams']['service'] == 'imagerie';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: on ? const Color(0xFFEAF2FF) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? navy : const Color(0xFFE1E8F2), width: on ? 1.6 : 1)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() {
            if (on) {
              sel.remove(name);
            } else {
              sel.add(name);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: (img ? teal : navy).withAlpha(30), borderRadius: BorderRadius.circular(11)), child: Icon(img ? Icons.monitor_heart_rounded : Icons.science_rounded, color: img ? teal : navy, size: 21)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${x['exams']['discipline']} — ${x['custom_conditions'] ?? x['exams']['conditions']}', style: const TextStyle(fontSize: 12, color: muted)),
                ]),
              ),
              Icon(on ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: on ? navy : const Color(0xFFB8C4D6)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    if (widget.lab == null) return Center(child: Text(t('Centre indisponible. Reconnectez-vous.', 'Center unavailable. Please sign in again.')));
    return load(ex, (l) {
      for (final x in l) {
        final e = x['exams'];
        if (e['at_center_only'] == true) centerOnly.add(e['name']);
        if (e['service'] == 'imagerie') imaging.add(e['name']);
      }
      allEx = l;
      final hasLab = labSel.isNotEmpty, hasImg = imgSel.isNotEmpty, home = hasLab && !labAtCenter;
      final shown = l.where((x) => filter.isEmpty || '${x['exams']['name']} ${x['exams']['discipline']}'.toLowerCase().contains(filter)).toList();
      final imgs = shown.where((x) => x['exams']['service'] == 'imagerie').toList();
      final labs = shown.where((x) => x['exams']['service'] != 'imagerie').toList();
      return Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(14), children: [
            stepHeader(1, t('Choisissez vos examens', 'Choose your exams')),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: t('Rechercher un examen', 'Search for an exam'),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => filter = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            if (imgs.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t('IMAGERIE MÉDICALE', 'MEDICAL IMAGING'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: teal))),
              for (final x in imgs) examCard(x),
            ],
            if (labs.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.only(top: 4, bottom: 6), child: Text(t('ANALYSES MÉDICALES', 'MEDICAL TESTS'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: navy))),
              for (final x in labs) examCard(x),
            ],
            if (shown.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(t('Aucun examen trouvé.', 'No exam found.')))),
            stepHeader(2, t('Où et quand ?', 'Where and when?')),
            panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (hasImg)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: const Color(0xFFEAF2FF), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.info_rounded, color: navy, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t('Les examens d’imagerie se font au centre : venez avec votre ordonnance.', 'Imaging exams are done at the center: bring your prescription.'), style: const TextStyle(fontSize: 12.5, color: navy))),
                  ]),
                ),
              if (hasLab && !labSel.any(centerOnly.contains))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'domicile', label: Text(t('À domicile', 'At home')), icon: const Icon(Icons.home_rounded)),
                      ButtonSegment(value: 'centre', label: Text(t('Au centre', 'At the center')), icon: const Icon(Icons.local_hospital_rounded)),
                    ],
                    selected: {mode},
                    onSelectionChanged: (v) => setState(() => mode = v.first),
                  ),
                ),
              if (home) ...[
                TextField(controller: quarter, decoration: InputDecoration(labelText: t('Quartier', 'Neighborhood'))),
                const SizedBox(height: 8),
                TextField(controller: addr, decoration: InputDecoration(labelText: t('Adresse / lieu / repère', 'Address / place / landmark'))),
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<String>(
                value: slot,
                items: [for (final x in slots) DropdownMenuItem(value: x, child: Text(x))],
                onChanged: (v) => setState(() => slot = v ?? slot),
                decoration: InputDecoration(labelText: t('Créneau souhaité', 'Preferred time slot')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(date == null ? t('Choisir la date', 'Choose the date') : date!.toIso8601String().substring(0, 10)),
                onPressed: () async {
                  final d = await showDatePicker(context: c, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
                  if (d != null) setState(() => date = d);
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: Icon(rx == null ? Icons.add_a_photo_rounded : Icons.check_circle_rounded, size: 18),
                label: Text(rx == null ? t('Ajouter la photo de mon ordonnance (facultatif)', 'Add a photo of my prescription (optional)') : t('Ordonnance ajoutée · toucher pour changer', 'Prescription added · tap to change')),
                onPressed: pickRx,
              ),
              if (home)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(lat == null ? t('Partager ma position (GPS)', 'Share my location (GPS)') : t('Position enregistrée', 'Location saved')),
                    onPressed: () async {
                      final p = await myPosition(c);
                      if (p != null) {
                        setState(() {
                          lat = p.latitude;
                          lng = p.longitude;
                        });
                      }
                    },
                  ),
                ),
            ])),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, -2))]),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${sel.length} ${t('examen(s) choisi(s)', 'exam(s) selected')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(date == null ? t('Choisissez une date', 'Pick a date') : date!.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 12, color: muted)),
              ]),
            ),
            FilledButton(onPressed: busy ? null : send, child: Text(home ? t('Envoyer ma demande', 'Send my request') : t('Demander un rendez-vous', 'Request an appointment'))),
          ]),
        ),
      ]);
    });
  }
}

// ---------- Mes demandes ----------
class MyRequestsTab extends StatefulWidget {
  final void Function(int)? go;
  const MyRequestsTab({super.key, this.go});
  @override
  State<MyRequestsTab> createState() => _MyRequestsTabState();
}

class _MyRequestsTabState extends State<MyRequestsTab> {
  late Future<List<Map<String, dynamic>>> fut = fetch();
  String f = 'open';

  Future<List<Map<String, dynamic>>> fetch() => q(db.from('requests').select().eq('patient_id', db.auth.currentUser!.id).order('created_at', ascending: false));

  void refresh() {
    if (mounted) {
      setState(() {
        fut = fetch();
      });
    }
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<List<Map<String, dynamic>>>(
        future: fut,
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('Erreur : ${s.error}'));
          if (!s.hasData) return const ShimmerList();
          final all = s.data!;
          bool isOpen(dynamic st) => !['done', 'cancelled'].contains(st);
          final shown = all.where((r) => f == 'all' || (f == 'open' ? isOpen(r['status']) : !isOpen(r['status']))).toList();
          final labels = {'open': '${t('En cours', 'In progress')} (${all.where((r) => isOpen(r['status'])).length})', 'past': '${t('Terminées', 'Completed')} (${all.where((r) => !isOpen(r['status'])).length})', 'all': '${t('Toutes', 'All')} (${all.length})'};
          return Column(children: [
            SizedBox(
              height: 54,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 10, 12, 6), children: [
                for (final e in labels.entries)
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(e.value), selected: f == e.key, onSelected: (_) => setState(() => f = e.key))),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => refresh(),
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 20), children: [
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(children: [
                        const Icon(Icons.inbox_rounded, size: 46, color: muted),
                        const SizedBox(height: 10),
                        Text(t('Aucune demande ici pour le moment.', 'No request here yet.')),
                        if (widget.go != null) TextButton(onPressed: () => widget.go!(1), child: Text(t('Commander un examen', 'Order an exam'))),
                      ]),
                    ),
                  for (final r in shown)
                    panel(
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(r['service'] == 'imagerie' ? Icons.monitor_heart_rounded : Icons.science_rounded, color: r['service'] == 'imagerie' ? teal : navy, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text((r['exam_names'] as List).join(', '), style: const TextStyle(fontWeight: FontWeight.w800))),
                          statusChip(r['status']),
                        ]),
                        const SizedBox(height: 8),
                        Wrap(spacing: 14, runSpacing: 4, children: [
                          infoLine(Icons.event_rounded, '${r['wanted_date']} · ${r['slot']}'),
                          infoLine(r['mode'] == 'centre' ? Icons.apartment_rounded : Icons.home_rounded, r['mode'] == 'centre' ? t('Au centre', 'At the center') : '${r['quarter']} · ${r['address']}'),
                        ]),
                        const SizedBox(height: 10),
                        reqProgressBar('${r['status']}'),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          OutlinedButton.icon(icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18), label: Text(t('Message', 'Message')), onPressed: () => openChat(c, r)),
                          if (r['status'] == 'pending')
                            TextButton(
                              onPressed: () async {
                                if (await confirmBox(c, t('Annuler cette demande ?', 'Cancel this request?'), t('Le centre sera informé de l’annulation.', 'The center will be informed.'), t('Annuler la demande', 'Cancel request'))) {
                                  await run(c, () => db.from('requests').update({'status': 'cancelled'}).eq('id', r['id']));
                                  refresh();
                                }
                              },
                              child: Text(t('Annuler', 'Cancel'), style: const TextStyle(color: danger)),
                            ),
                        ]),
                      ]),
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    ),
                ]),
              ),
            ),
          ]);
        },
      );
}

// ---------- Mes résultats ----------
class ResultsTab extends StatefulWidget {
  const ResultsTab({super.key});
  @override
  State<ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<ResultsTab> {
  late Future<List<List<Map<String, dynamic>>>> fut = fetch();

  Future<List<List<Map<String, dynamic>>>> fetch() async {
    final r = await q(db.from('results').select('id, title, file_path, service, created_at').order('created_at', ascending: false));
    List<Map<String, dynamic>> fb = [];
    try {
      fb = await q(db.from('feedback').select('result_id, stars'));
    } catch (_) {}
    return [r, fb];
  }

  void refresh() {
    if (mounted) {
      setState(() {
        fut = fetch();
      });
    }
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: fut,
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('Erreur : ${s.error}'));
          if (!s.hasData) return const ShimmerList();
          final l = s.data![0];
          final stars = {for (final f in s.data![1]) '${f['result_id']}': (f['stars'] as num).toInt()};
          return RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(12, 12, 12, 24), children: [
              if (l.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    const Icon(Icons.image_search_rounded, size: 46, color: muted),
                    const SizedBox(height: 10),
                    Text(t('Vos résultats apparaîtront ici dès que le centre les aura envoyés.', 'Your results will appear here as soon as the center sends them.'), textAlign: TextAlign.center),
                  ]),
                ),
              for (final x in l)
                panel(
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: (x['service'] == 'imagerie' ? teal : navy).withAlpha(30), borderRadius: BorderRadius.circular(12)),
                        child: Icon(x['service'] == 'imagerie' ? Icons.monitor_heart_rounded : Icons.science_rounded, color: x['service'] == 'imagerie' ? teal : navy),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${x['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${x['service'] == 'imagerie' ? t('Imagerie médicale', 'Medical imaging') : t('Laboratoire', 'Laboratory')} · ${day(x['created_at'])}', style: const TextStyle(fontSize: 12, color: muted)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: FilledButton.icon(icon: const Icon(Icons.visibility_rounded, size: 18), label: Text(t('Voir', 'View')), onPressed: () => openResult(c, '${x['file_path']}'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.download_rounded, size: 18), label: Text(t('Télécharger', 'Download')), onPressed: () => openResult(c, '${x['file_path']}', download: true))),
                    ]),
                    const SizedBox(height: 8),
                    if (stars['${x['id']}'] != null)
                      Row(children: [
                        Text(t('Votre avis : ', 'Your feedback: '), style: const TextStyle(fontSize: 12.5, color: muted)),
                        for (var i = 1; i <= 5; i++) Icon(i <= stars['${x['id']}']! ? Icons.star_rounded : Icons.star_border_rounded, color: amber, size: 20),
                      ])
                    else
                      TextButton.icon(
                        icon: const Icon(Icons.star_border_rounded, color: amber),
                        label: Text(t('Donner mon avis', 'Give my feedback')),
                        onPressed: () async {
                          if (await rateResult(c, '${x['id']}')) refresh();
                        },
                      ),
                  ]),
                ),
            ]),
          );
        },
      );
}

// ---------- Paramètres ----------
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});
  @override
  Widget build(BuildContext c) => Container(
        color: soft,
        child: ListView(padding: const EdgeInsets.all(14), children: [
          loadIn(q(db.from('profiles').select('full_name, phone').eq('id', db.auth.currentUser!.id)), (l) {
            final nm = l.isEmpty ? '' : '${l.first['full_name'] ?? ''}';
            final ph = l.isEmpty ? '' : '${l.first['phone'] ?? ''}';
            return Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [navy, Color(0xFF1D5AB8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: cardShadow,
              ),
              child: Row(children: [
                CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Text(initial(nm), style: const TextStyle(color: navy, fontWeight: FontWeight.w800, fontSize: 22))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nm.isEmpty ? t('Mon compte', 'My account') : nm, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(ph, style: const TextStyle(color: pale, fontSize: 13)),
                  ]),
                ),
              ]),
            );
          }),
          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Langue', 'Language'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ValueListenableBuilder<String>(
              valueListenable: lang,
              builder: (c, l, _) => Column(children: [
                ListTile(contentPadding: EdgeInsets.zero, title: const Text('Français'), trailing: l == 'fr' ? const Icon(Icons.check_circle_rounded, color: lime) : null, onTap: () => setLang('fr')),
                ListTile(contentPadding: EdgeInsets.zero, title: const Text('English'), trailing: l == 'en' ? const Icon(Icons.check_circle_rounded, color: lime) : null, onTap: () => setLang('en')),
              ]),
            ),
          ])),
          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800)),
            ValueListenableBuilder<bool>(
              valueListenable: notifReq,
              builder: (c, v, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: v,
                title: Text(t('Avancement de mes demandes', 'Progress of my requests')),
                onChanged: (x) async {
                  notifReq.value = x;
                  (await SharedPreferences.getInstance()).setBool('notifReq', x);
                },
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: notifMsg,
              builder: (c, v, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: v,
                title: Text(t('Messages du centre', 'Messages from the center')),
                onChanged: (x) async {
                  notifMsg.value = x;
                  (await SharedPreferences.getInstance()).setBool('notifMsg', x);
                },
              ),
            ),
          ])),
          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Sécurité', 'Security'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ValueListenableBuilder<String?>(
              valueListenable: pinCode,
              builder: (c, p, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: p != null,
                title: Text(t('Verrouiller l’application par un code', 'Lock the app with a code')),
                subtitle: Text(t('Vos résultats restent protégés si quelqu’un prend votre téléphone.', 'Your results stay protected if someone takes your phone.')),
                onChanged: (v) => v ? setPinFlow(c) : clearPin(c),
              ),
            ),
          ])),
          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Appels et contact', 'Calls and contact'), style: const TextStyle(fontWeight: FontWeight.w800)),
            loadIn(q(db.from('contacts').select().order('id')), (cs) => Column(children: [for (final k in cs) contactTile(k)])),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.videocam_rounded, color: navy), title: Text(t('Appeler le centre', 'Call the center')), subtitle: Text(t('Dans une demande, touchez l’icône d’appel : le téléphone lance un appel normal.', 'In a request, tap the call icon: your phone starts a normal call.'))),
          ])),
          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Mes données', 'My data'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.policy_rounded, color: navy), title: Text(t('Politique de confidentialité', 'Privacy policy')), trailing: const Icon(Icons.open_in_new_rounded, size: 18), onTap: () => launchUrl(Uri.parse(kPolicyUrl), mode: LaunchMode.externalApplication)),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.delete_forever_rounded, color: danger), title: Text(t('Supprimer mon compte et mes données', 'Delete my account and data'), style: const TextStyle(color: danger)), subtitle: Text(t('Retire aussi votre consentement.', 'Also withdraws your consent.')), onTap: () => requestDeletion(c)),
          ])),
          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Mon compte', 'My account'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.key_rounded, color: navy), title: Text(t('J’ai un code d’invitation (personnel)', 'I have an invitation code (staff)')), onTap: () => redeem(c)),
            const SizedBox(height: 6),
            OutlinedButton.icon(icon: const Icon(Icons.logout_rounded), label: Text(t('Se déconnecter', 'Sign out')), onPressed: () => signOutAll()),
          ])),
        ]),
      );
}

// =====================================================================
//  Consentement éclairé, politique de confidentialité, suppression du compte
// =====================================================================

const kConsentVersion = '2026-10-v1';
const kPolicyUrl = 'https://saint-victor-bafia-9e5da.web.app/privacy.html';
const kDeleteUrl = 'https://saint-victor-bafia-9e5da.web.app/delete-account.html';

Widget consentPoint(IconData ic, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: navy.withAlpha(24), borderRadius: BorderRadius.circular(11)), child: Icon(ic, color: navy, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(fontSize: 13, color: Color(0xFF3B4C63), height: 1.35)),
          ]),
        ),
      ]),
    );

class ConsentGate extends StatefulWidget {
  final Widget child;
  const ConsentGate({super.key, required this.child});
  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  bool? ok;
  bool agree = false, notif = true, busy = false;

  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    final p = await SharedPreferences.getInstance();
    final uid = db.auth.currentUser?.id ?? '';
    var done = p.getString('consent_$uid') == kConsentVersion;
    if (!done) {
      try {
        final r = await q(db.from('consents').select('version').eq('version', kConsentVersion));
        if (r.isNotEmpty) {
          done = true;
          await p.setString('consent_$uid', kConsentVersion);
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        ok = done;
      });
    }
  }

  Future<void> accept() async {
    setState(() {
      busy = true;
    });
    try {
      await db.from('consents').insert({'version': kConsentVersion, 'notifications': notif});
    } catch (_) {}
    final p = await SharedPreferences.getInstance();
    await p.setString('consent_${db.auth.currentUser?.id ?? ''}', kConsentVersion);
    notifReq.value = notif;
    notifMsg.value = notif;
    await p.setBool('notifReq', notif);
    await p.setBool('notifMsg', notif);
    if (mounted) {
      setState(() {
        ok = true;
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext c) {
    if (ok == null) return const Scaffold(backgroundColor: ink);
    if (ok == true) return widget.child;
    return Scaffold(
      backgroundColor: soft,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(18), children: [
              Row(children: [
                Container(width: 52, height: 52, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), padding: const EdgeInsets.all(8), child: Image.asset('assets/logo.png')),
                const SizedBox(width: 12),
                const Expanded(child: Text('Saint-Victor de Bafia', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: navy))),
              ]),
              const SizedBox(height: 18),
              Text(t('Vos données de santé, en toute confidentialité', 'Your health data, kept confidential'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: navy)),
              const SizedBox(height: 8),
              Text(t('Avant de continuer, voici l’essentiel. Vous restez libre de refuser.', 'Before you continue, here is what matters. You are free to decline.'), style: const TextStyle(color: muted)),
              const SizedBox(height: 16),
              panel(Column(children: [
                consentPoint(Icons.badge_rounded, t('Ce que nous collectons', 'What we collect'), t('Votre nom et votre téléphone, les examens demandés, vos ordonnances, vos résultats, vos messages et, pour un prélèvement à domicile, votre position.', 'Your name and phone, the exams requested, prescriptions, results, messages and, for home sampling, your location.')),
                consentPoint(Icons.medical_services_rounded, t('Pourquoi', 'Why'), t('Pour traiter vos demandes, réaliser vos examens, vous envoyer vos résultats et vous contacter. Rien d’autre.', 'To handle your requests, carry out your exams, send your results and contact you. Nothing else.')),
                consentPoint(Icons.lock_rounded, t('Qui y accède', 'Who can see it'), t('Seulement le personnel autorisé du centre, selon son rôle. Vos données ne sont ni vendues ni publiées.', 'Only authorized center staff, depending on their role. Your data is neither sold nor published.')),
                consentPoint(Icons.cloud_rounded, t('Où elles sont conservées', 'Where it is stored'), t('Chez des prestataires informatiques sécurisés (Supabase, Google), dont les serveurs peuvent être situés hors du Cameroun. Les échanges sont chiffrés.', 'With secure IT providers (Supabase, Google) whose servers may be outside Cameroon. Transfers are encrypted.')),
                consentPoint(Icons.verified_user_rounded, t('Vos droits', 'Your rights'), t('Voir, corriger, retirer votre consentement ou supprimer votre compte à tout moment, dans Paramètres.', 'View, correct, withdraw your consent or delete your account at any time, in Settings.')),
              ])),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(t('Lire la politique de confidentialité complète', 'Read the full privacy policy')),
                onPressed: () => launchUrl(Uri.parse(kPolicyUrl), mode: LaunchMode.externalApplication),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: agree,
                onChanged: (v) => setState(() => agree = v ?? false),
                title: Text(t('J’ai lu ces informations et j’accepte que le centre traite mes données de santé pour traiter mes demandes et m’envoyer mes résultats. (obligatoire)', 'I have read this information and agree that the center processes my health data to handle my requests and send my results. (required)'), style: const TextStyle(fontSize: 13.5)),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: notif,
                onChanged: (v) => setState(() => notif = v ?? false),
                title: Text(t('Je souhaite être prévenu de l’avancement de mes demandes et des messages du centre. (facultatif)', 'I would like to be notified of the progress of my requests and messages from the center. (optional)'), style: const TextStyle(fontSize: 13.5)),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, -2))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: double.infinity, child: FilledButton(onPressed: agree && !busy ? accept : null, child: Text(t('Accepter et continuer', 'Accept and continue')))),
              TextButton(onPressed: () => signOutAll(), child: Text(t('Refuser et me déconnecter', 'Decline and sign out'), style: const TextStyle(color: danger))),
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<void> requestDeletion(BuildContext c) async {
  final yes = await confirmBox(
    c,
    t('Supprimer mon compte ?', 'Delete my account?'),
    t('Votre demande sera transmise au centre. Votre compte et vos données seront supprimés dans un délai de 30 jours, sauf les éléments que la loi oblige le centre à conserver. Vous serez déconnecté.', 'Your request will be sent to the center. Your account and data will be deleted within 30 days, except what the law requires the center to keep. You will be signed out.'),
    t('Envoyer la demande', 'Send request'),
  );
  if (!yes || !c.mounted) return;
  final ok = await run(c, () => db.from('deletion_requests').insert({}), t('Demande envoyée.', 'Request sent.'));
  if (ok) await signOutAll();
}

class DeletionRequests extends StatefulWidget {
  const DeletionRequests({super.key});
  @override
  State<DeletionRequests> createState() => _DeletionRequestsState();
}

class _DeletionRequestsState extends State<DeletionRequests> {
  late Future<List<Map<String, dynamic>>> fut = fetch();

  Future<List<Map<String, dynamic>>> fetch() => q(db.from('deletion_requests').select('id, requested_at, processed, user:profiles!user_id(full_name, phone)').order('requested_at', ascending: false).limit(200));

  void refresh() {
    if (mounted) {
      setState(() {
        fut = fetch();
      });
    }
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<List<Map<String, dynamic>>>(
        future: fut,
        builder: (c, s) {
          if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Erreur : ${s.error}\n\nAvez-vous exécuté le fichier SQL de cette version ?')));
          if (!s.hasData) return const ShimmerList();
          final l = s.data!;
          return ListView(padding: const EdgeInsets.all(12), children: [
            panel(const Text('Pour supprimer un compte : Supabase, menu Authentication, Users, trois points à droite de la personne, Delete user. Puis touchez « Marquer comme traité » ici. Conservez ce qui doit l’être légalement avant de supprimer.', style: TextStyle(fontSize: 12.5, color: muted))),
            if (l.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('Aucune demande de suppression.'))),
            for (final r in l)
              panel(
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${(r['user'] ?? {})['full_name'] ?? 'Compte'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('${(r['user'] ?? {})['phone'] ?? ''} · ${day(r['requested_at'])}', style: const TextStyle(fontSize: 12.5, color: muted)),
                    ]),
                  ),
                  if (r['processed'] == true)
                    const Text('Traité', style: TextStyle(color: green, fontWeight: FontWeight.w700))
                  else
                    OutlinedButton(
                      onPressed: () async {
                        await run(c, () => db.from('deletion_requests').update({'processed': true}).eq('id', r['id']));
                        refresh();
                      },
                      child: const Text('Marquer comme traité'),
                    ),
                ]),
                pad: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
              ),
          ]);
        },
      );
}
