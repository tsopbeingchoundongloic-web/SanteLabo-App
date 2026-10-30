part of 'main.dart';

// =====================================================================
//  Notifications : alerte visible quand l'application est ouverte,
//  et notifications Firebase (Google) quand elle est fermée.
// =====================================================================

final appMessenger = GlobalKey<ScaffoldMessengerState>();
RealtimeChannel? _notifChannel;
String? _pushUser;
String? _pushToken;

// À appeler une fois au démarrage : suit la connexion de l'utilisateur.
void watchPush() {
  try {
    db.auth.onAuthStateChange.listen((s) {
      if (s.session != null) {
        initPush();
      } else {
        _pushUser = null;
        try {
          _notifChannel?.unsubscribe();
        } catch (_) {}
      }
    });
    if (db.auth.currentSession != null) initPush();
  } catch (_) {}
}

Future<void> initPush() async {
  final uid = db.auth.currentUser?.id;
  if (uid == null || _pushUser == uid) return;
  _pushUser = uid;
  _listenNotifications(uid);
  await _initFcm();
}

// Application ouverte : bandeau en haut + vibration dès qu'une notification arrive.
void _listenNotifications(String uid) {
  try {
    _notifChannel?.unsubscribe();
  } catch (_) {}
  try {
    _notifChannel = db
        .channel('alerts-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (p) {
            final r = p.newRecord;
            if (!notifOn(r)) return;
            HapticFeedback.heavyImpact();
            appMessenger.currentState?.showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: ink,
                duration: const Duration(seconds: 5),
                content: Row(children: [
                  const Icon(Icons.notifications_active_rounded, color: limeLight),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${r['title']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                ]),
              ),
            );
          },
        )
        .subscribe();
  } catch (_) {}
}

// Application fermée : notifications Firebase (nécessite les identifiants dans config.dart).
Future<void> _initFcm() async {
  if (kIsWeb || kFcmAppId.isEmpty) return;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: const FirebaseOptions(apiKey: kFcmApiKey, appId: kFcmAppId, messagingSenderId: kFcmSenderId, projectId: kFcmProjectId));
    }
    final m = FirebaseMessaging.instance;
    await m.requestPermission();
    final tok = await m.getToken();
    if (tok != null) await _registerToken(tok);
    m.onTokenRefresh.listen(_registerToken);
  } catch (_) {}
}

Future<void> _registerToken(String tok) async {
  _pushToken = tok;
  try {
    await db.rpc('register_device', params: {'p_token': tok, 'p_platform': 'android'});
  } catch (_) {}
}

// Déconnexion : retire d'abord ce téléphone de la liste des appareils à notifier.
Future<void> signOutAll() async {
  final tok = _pushToken;
  if (tok != null) {
    try {
      await db.rpc('unregister_device', params: {'p_token': tok});
    } catch (_) {}
  }
  await db.auth.signOut();
}
