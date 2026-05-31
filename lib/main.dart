import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

import 'pages/auth_page.dart';
import 'pages/home_page.dart';
import 'pages/messages_page.dart';
import 'pages/events_page.dart';
import 'pages/expense_page.dart';
import 'pages/camera_page.dart';
import 'pages/second_hand_cars_page.dart';
import 'pages/create_post_page.dart';
import 'pages/profile_page.dart';
import 'pages/user_profile_page.dart' as user_profile;


final FlutterLocalNotificationsPlugin localNotifications =
FlutterLocalNotificationsPlugin();

String novaCleanText(dynamic value, {String fallback = ''}) {
  final text = (value ?? '').toString().trim();
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}

String novaNotificationImageUrl(Map<String, dynamic> data, RemoteNotification? notification) {
  final fromData = novaCleanText(
    data['senderPhotoUrl'],
    fallback: novaCleanText(
      data['fromUserPhotoUrl'],
      fallback: novaCleanText(
        data['actorPhotoUrl'],
        fallback: novaCleanText(
          data['requestUserPhotoUrl'],
          fallback: novaCleanText(
            data['commentUserPhotoUrl'],
            fallback: novaCleanText(
              data['likedUserPhotoUrl'],
              fallback: novaCleanText(
                data['storyUserPhotoUrl'],
                fallback: novaCleanText(
                  data['photoUrl'],
                  fallback: novaCleanText(
                    data['profileImageUrl'],
                    fallback: novaCleanText(
                      data['avatarUrl'],
                      fallback: novaCleanText(
                        data['largeIconUrl'],
                        fallback: novaCleanText(
                          data['imageUrl'],
                          fallback: novaCleanText(notification?.android?.imageUrl),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  return fromData;
}

Future<Uint8List?> novaDownloadImageBytes(String url) async {
  final cleanUrl = url.trim();
  if (cleanUrl.isEmpty) return null;
  if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
    return null;
  }

  HttpClient? client;
  try {
    client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    final request = await client.getUrl(Uri.parse(cleanUrl));
    final response = await request.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > 1024 * 1024 * 4) break;
    }

    if (bytes.isEmpty) return null;
    return Uint8List.fromList(bytes);
  } catch (_) {
    return null;
  } finally {
    client?.close(force: true);
  }
}

Future<AndroidNotificationDetails> novaAndroidNotificationDetails({
  required String imageUrl,
  String body = '',
}) async {
  final imageBytes = await novaDownloadImageBytes(imageUrl);
  final avatarBitmap = imageBytes == null ? null : ByteArrayAndroidBitmap(imageBytes);

  return AndroidNotificationDetails(
    'nova_high_channel',
    'NOVA Bildirimleri',
    channelDescription: 'NOVA mesaj ve uygulama bildirimleri',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    category: AndroidNotificationCategory.social,
    largeIcon: avatarBitmap,
    styleInformation: BigTextStyleInformation(body),
  );
}

Future<bool> novaShouldMuteForegroundNotification(RemoteMessage message) async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (currentUid.isEmpty) return false;

  final data = message.data;

  final type = novaCleanText(data['type']);
  final pushType = novaCleanText(data['pushType']);
  final route = novaCleanText(data['route']);
  final notificationKind = novaCleanText(data['notificationKind']);
  final clickAction = novaCleanText(data['clickAction']);

  final chatId = novaCleanText(
    data['chatId'],
    fallback: novaCleanText(
      data['conversationId'],
      fallback: novaCleanText(data['roomId']),
    ),
  );

  final receiverId = novaCleanText(
    data['receiverId'],
    fallback: novaCleanText(
      data['toUserId'],
      fallback: novaCleanText(data['targetUserId']),
    ),
  );

  final isDmNotification =
      type == 'dm' ||
          type == 'message' ||
          pushType == 'dm' ||
          pushType == 'message' ||
          route == 'chat' ||
          route == 'dm' ||
          notificationKind == 'dm' ||
          clickAction == 'OPEN_CHAT';

  // Payload yanlış kullanıcıya gelirse asla gösterme.
  if (receiverId.isNotEmpty && receiverId != currentUid) {
    return true;
  }

  // DM değilse normal bildirim gösterilebilir.
  if (!isDmNotification || chatId.isEmpty) {
    return false;
  }

  // Kesin kontrol:
  // messages_page.dart içindeki ChatDetailPage, kullanıcı DM kutusuna girince
  // users/{uid} dokümanına activeChatId / activeDmChatId / foregroundChatId yazar.
  // Burada aynı chatId açıksa local notification kesinlikle gösterilmez.
  try {
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();

    final userData = userSnap.data() ?? <String, dynamic>{};

    final activeChatId = novaCleanText(userData['activeChatId']);
    final activeDmChatId = novaCleanText(userData['activeDmChatId']);
    final foregroundChatId = novaCleanText(userData['foregroundChatId']);
    final activeRoute = novaCleanText(userData['activeRoute']);

    final isInsideSameChat =
        activeChatId == chatId ||
            activeDmChatId == chatId ||
            foregroundChatId == chatId ||
            (activeRoute == 'dm' && activeChatId == chatId);

    if (isInsideSameChat) {
      return true;
    }
  } catch (_) {
    // Firestore kontrolü hata verirse bildirim sistemini komple bozma.
  }

  return false;
}



@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<void> setupNovaNotifications() async {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  const initSettings = InitializationSettings(
    android: androidSettings,
  );

  await localNotifications.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Bildirime basınca yönlendirme istersen burada data payload'a göre sayfa açacağız.
    },
  );

  const androidChannel = AndroidNotificationChannel(
    'nova_high_channel',
    'NOVA Bildirimleri',
    description: 'NOVA mesaj ve uygulama bildirimleri',
    importance: Importance.high,
    playSound: true,
  );

  await localNotifications
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

  await localNotifications
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (Platform.isIOS || Platform.isMacOS) {
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    if (await novaShouldMuteForegroundNotification(message)) return;

    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ??
        novaCleanText(
          data['title'],
          fallback: novaCleanText(
            data['senderName'],
            fallback: novaCleanText(
              data['fromUserName'],
              fallback: 'NOVA',
            ),
          ),
        );

    final body = notification?.body ??
        novaCleanText(
          data['body'],
          fallback: novaCleanText(
            data['text'],
            fallback: 'Yeni bildirim',
          ),
        );

    final imageUrl = novaNotificationImageUrl(data, notification);
    final androidDetails = await novaAndroidNotificationDetails(imageUrl: imageUrl, body: body);

    await localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
      ),
      payload: data['chatId']?.toString() ??
          data['postId']?.toString() ??
          data['fromUserId']?.toString(),
    );
  });
}


StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? novaNotificationDocSub;
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? novaFollowRequestDocSub;
String? novaListeningUid;
final Set<String> novaShownLocalNotificationKeys = <String>{};

String novaNotificationTitleFromData(Map<String, dynamic> data) {
  final type = novaCleanText(data['type'], fallback: novaCleanText(data['notificationType']));
  final actorName = novaCleanText(
    data['actorUsername'],
    fallback: novaCleanText(
      data['fromUserName'],
      fallback: novaCleanText(
        data['senderName'],
        fallback: novaCleanText(data['username'], fallback: 'NOVA'),
      ),
    ),
  );

  final explicitTitle = novaCleanText(data['title']);
  if (explicitTitle.isNotEmpty) return explicitTitle;

  switch (type) {
    case 'follow_request':
      return 'Yeni takip isteği';
    case 'follow_request_accepted':
      return 'Takip isteğin kabul edildi';
    case 'post_like':
    case 'like':
      return 'Yeni beğeni';
    case 'post_comment':
    case 'comment':
      return 'Yeni yorum';
    case 'comment_like':
      return 'Yorumun beğenildi';
    case 'story_like':
      return 'Hikayen beğenildi';
    case 'dm':
    case 'message':
      return actorName;
    default:
      return 'NOVA';
  }
}

String novaNotificationBodyFromData(Map<String, dynamic> data) {
  final type = novaCleanText(data['type'], fallback: novaCleanText(data['notificationType']));
  final actorName = novaCleanText(
    data['actorUsername'],
    fallback: novaCleanText(
      data['fromUserName'],
      fallback: novaCleanText(
        data['senderName'],
        fallback: novaCleanText(data['username'], fallback: 'Bir kullanıcı'),
      ),
    ),
  );

  final explicitBody = novaCleanText(
    data['body'],
    fallback: novaCleanText(data['message'], fallback: novaCleanText(data['text'])),
  );
  if (explicitBody.isNotEmpty) return explicitBody;

  switch (type) {
    case 'follow_request':
      return '$actorName seni takip etmek istiyor.';
    case 'follow_request_accepted':
      return '$actorName takip isteğini kabul etti.';
    case 'post_like':
    case 'like':
      return '$actorName gönderini beğendi.';
    case 'post_comment':
    case 'comment':
      return '$actorName gönderine yorum yaptı.';
    case 'comment_like':
      return '$actorName yorumunu beğendi.';
    case 'story_like':
      return '$actorName hikayeni beğendi.';
    case 'dm':
    case 'message':
      return 'Yeni mesaj gönderdi.';
    default:
      return 'Yeni bildirim var.';
  }
}

String novaPayloadFromData(Map<String, dynamic> data) {
  return novaCleanText(
    data['chatId'],
    fallback: novaCleanText(
      data['conversationId'],
      fallback: novaCleanText(
        data['postId'],
        fallback: novaCleanText(
          data['storyId'],
          fallback: novaCleanText(
            data['fromUserId'],
            fallback: novaCleanText(data['actorId']),
          ),
        ),
      ),
    ),
  );
}

bool novaIsDmNotificationData(Map<String, dynamic> data) {
  final type = novaCleanText(data['type']);
  final pushType = novaCleanText(data['pushType']);
  final route = novaCleanText(data['route']);
  final notificationKind = novaCleanText(data['notificationKind']);
  final clickAction = novaCleanText(data['clickAction']);
  final chatId = novaCleanText(
    data['chatId'],
    fallback: novaCleanText(
      data['conversationId'],
      fallback: novaCleanText(data['roomId']),
    ),
  );

  return chatId.isNotEmpty &&
      (type == 'dm' ||
          type == 'message' ||
          pushType == 'dm' ||
          pushType == 'message' ||
          route == 'chat' ||
          route == 'dm' ||
          notificationKind == 'dm' ||
          notificationKind == 'data_only' ||
          clickAction == 'OPEN_CHAT');
}

Future<void> novaShowLocalNotificationFromData(
    Map<String, dynamic> data, {
      String? uniqueKey,
    }) async {
  // DM bildirimlerinde ikinci local bildirimi engelle.
  // Profil resimli asıl bildirim Firebase Messaging (FCM) üzerinden gelir.
  // Firestore users/{uid}/notifications listener'ı DM için tekrar bildirim basmasın.
  if (novaIsDmNotificationData(data)) return;

  final key = uniqueKey ?? novaPayloadFromData(data) + DateTime.now().millisecondsSinceEpoch.toString();
  if (key.isNotEmpty && novaShownLocalNotificationKeys.contains(key)) return;
  if (key.isNotEmpty) {
    novaShownLocalNotificationKeys.add(key);
    if (novaShownLocalNotificationKeys.length > 250) {
      novaShownLocalNotificationKeys.remove(novaShownLocalNotificationKeys.first);
    }
  }

  final title = novaNotificationTitleFromData(data);
  final body = novaNotificationBodyFromData(data);
  final imageUrl = novaNotificationImageUrl(data, null);
  final androidDetails = await novaAndroidNotificationDetails(imageUrl: imageUrl, body: body);

  await localNotifications.show(
    id: DateTime.now().microsecondsSinceEpoch.remainder(2147483647),
    title: title,
    body: body,
    notificationDetails: NotificationDetails(android: androidDetails),
    payload: novaPayloadFromData(data),
  );
}

void startNovaRealtimeNotificationListeners(String uid) {
  if (uid.trim().isEmpty) return;
  if (novaListeningUid == uid && novaNotificationDocSub != null && novaFollowRequestDocSub != null) return;

  novaNotificationDocSub?.cancel();
  novaFollowRequestDocSub?.cancel();
  novaListeningUid = uid;

  var notificationFirstSnapshot = true;
  novaNotificationDocSub = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .listen((snapshot) async {
    if (notificationFirstSnapshot) {
      notificationFirstSnapshot = false;
      for (final doc in snapshot.docs) {
        novaShownLocalNotificationKeys.add('notification_${doc.id}');
      }
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data() ?? <String, dynamic>{};
      await novaShowLocalNotificationFromData(
        data,
        uniqueKey: 'notification_${change.doc.id}',
      );
    }
  });

  var followFirstSnapshot = true;
  novaFollowRequestDocSub = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('followRequests')
      .snapshots()
      .listen((snapshot) async {
    if (followFirstSnapshot) {
      followFirstSnapshot = false;
      for (final doc in snapshot.docs) {
        novaShownLocalNotificationKeys.add('follow_request_${doc.id}');
      }
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data() ?? <String, dynamic>{};
      final fromUserName = novaCleanText(
        data['displayName'],
        fallback: novaCleanText(data['username'], fallback: 'Bir kullanıcı'),
      );
      await novaShowLocalNotificationFromData(
        {
          ...data,
          'type': 'follow_request',
          'title': 'Yeni takip isteği',
          'body': '$fromUserName seni takip etmek istiyor.',
          'fromUserId': novaCleanText(data['fromUserId'], fallback: change.doc.id),
          'actorUsername': fromUserName,
          'actorPhotoUrl': novaCleanText(data['photoUrl'], fallback: novaCleanText(data['profileImageUrl'])),
          'requestUserPhotoUrl': novaCleanText(data['photoUrl'], fallback: novaCleanText(data['profileImageUrl'])),
        },
        uniqueKey: 'follow_request_${change.doc.id}',
      );
    }
  });
}

void stopNovaRealtimeNotificationListeners() {
  novaNotificationDocSub?.cancel();
  novaFollowRequestDocSub?.cancel();
  novaNotificationDocSub = null;
  novaFollowRequestDocSub = null;
  novaListeningUid = null;
}

Future<void> saveUserFcmToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final token = await FirebaseMessaging.instance.getToken();
  if (token == null || token.isEmpty) return;

  await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
    'fcmToken': token,
    'fcmUpdatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
      'fcmToken': newToken,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      // Firebase zaten başlamışsa devam et
    } else {
      rethrow;
    }
  }

  await setupNovaNotifications();

  runApp(const NovaApp());
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NOVA',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const NovaInstantBootScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          final uid = snapshot.data!.uid;
          saveUserFcmToken();
          startNovaRealtimeNotificationListeners(uid);
          return const MainShell();
        }

        stopNovaRealtimeNotificationListeners();
        return const AuthPage();
      },
    );
  }
}

class NovaInstantBootScreen extends StatefulWidget {
  const NovaInstantBootScreen({super.key});

  @override
  State<NovaInstantBootScreen> createState() => _NovaInstantBootScreenState();
}

class _NovaInstantBootScreenState extends State<NovaInstantBootScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget shimmerBox({
    double? width,
    required double height,
    double radius = 14,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.8 + controller.value * 3.6, 0),
              end: Alignment(-0.2 + controller.value * 3.6, 0),
              colors: const [
                Color(0xFFEDEDED),
                Color(0xFFF9F9F9),
                Color(0xFFEDEDED),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(
            children: [
              Row(
                children: [
                  shimmerBox(width: 40, height: 40, radius: 13),
                  const Spacer(),
                  shimmerBox(width: 116, height: 22, radius: 99),
                  const Spacer(),
                  shimmerBox(width: 40, height: 40, radius: 13),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, __) {
                    return Column(
                      children: [
                        shimmerBox(width: 62, height: 62, shape: BoxShape.circle),
                        const SizedBox(height: 7),
                        shimmerBox(width: 50, height: 9, radius: 99),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            shimmerBox(width: 42, height: 42, shape: BoxShape.circle),
                            const SizedBox(width: 10),
                            shimmerBox(width: 140, height: 13, radius: 99),
                          ],
                        ),
                        const SizedBox(height: 10),
                        shimmerBox(width: double.infinity, height: 300, radius: 18),
                        const SizedBox(height: 10),
                        shimmerBox(width: 210, height: 12, radius: 99),
                        const SizedBox(height: 7),
                        shimmerBox(width: 120, height: 10, radius: 99),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int currentIndex = 0;

  late final AnimationController neonController;
  int homeRefreshKey = 0;

  double? dragStartX;
  double dragDeltaX = 0;

  static const double edgeWidth = 28;
  static const double pageSwipeDistance = 130;
  static const double pageSwipeVelocity = 760;
  static const double cameraSwipeDistance = 150;
  static const double cameraSwipeVelocity = 860;

  @override
  void initState() {
    super.initState();

    neonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

  }

  @override
  void dispose() {
    neonController.dispose();
    super.dispose();
  }

  void changePage(int index) {
    if (index == 0 && currentIndex == 0) {
      setState(() => homeRefreshKey++);
      return;
    }

    if (index == currentIndex) return;
    setState(() => currentIndex = index);
  }

  List<Widget> buildShellPages() {
    return [
      KeyedSubtree(
        key: ValueKey('home_refresh_$homeRefreshKey'),
        child: HomePage(onStoryTap: openStoryGallery),
      ),
      const MessagesPage(),
      const SecondHandCarsPage(),
      const ExpensePage(),
      const ProfilePage(),
    ];
  }

  void openCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPage()),
    );
  }

  void openStoryGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPage()),
    );
  }

  void openPostCreatePage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostPage()),
    );
  }


  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void openNotificationsSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const NotificationsSheet(),
      ),
    );
  }

  void openFollowRequestsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const FollowRequestsPage(),
      ),
    );
  }

  void handleDragStart(DragStartDetails details) {
    dragStartX = details.globalPosition.dx;
    dragDeltaX = 0;
  }

  void handleDragUpdate(DragUpdateDetails details) {
    dragDeltaX += details.delta.dx;
  }

  void handleDragEnd(DragEndDetails details) {
    final startX = dragStartX;
    if (startX == null) return;

    final width = MediaQuery.of(context).size.width;
    final velocity = details.primaryVelocity ?? 0;

    final startedFromLeftEdge = startX <= edgeWidth;
    final startedFromRightEdge = startX >= width - edgeWidth;

    if (currentIndex == 0 &&
        startedFromLeftEdge &&
        dragDeltaX > cameraSwipeDistance &&
        velocity > cameraSwipeVelocity) {
      openCamera();
      resetDrag();
      return;
    }

    if (startedFromRightEdge &&
        dragDeltaX < -pageSwipeDistance &&
        velocity < -pageSwipeVelocity &&
        currentIndex < 4) {
      changePage(currentIndex + 1);
    }

    if (startedFromLeftEdge &&
        dragDeltaX > pageSwipeDistance &&
        velocity > pageSwipeVelocity &&
        currentIndex > 0) {
      changePage(currentIndex - 1);
    }

    resetDrag();
  }

  void resetDrag() {
    dragStartX = null;
    dragDeltaX = 0;
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  NovaTopBar(
                    neonController: neonController,
                    onCameraTap: openCamera,
                    onNotificationTap: openNotificationsSheet,
                    onFollowRequestsTap: openFollowRequestsPage,
                    onPostTap: openPostCreatePage,
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: handleDragStart,
                      onHorizontalDragUpdate: handleDragUpdate,
                      onHorizontalDragEnd: handleDragEnd,
                      child: IndexedStack(
                        index: currentIndex,
                        children: buildShellPages(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: MediaQuery.of(context).viewPadding.bottom + 12,
              child: NovaBottomBar(
                controller: neonController,
                currentIndex: currentIndex,
                onTap: changePage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NovaTopBar extends StatelessWidget {
  final AnimationController neonController;
  final VoidCallback onCameraTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onFollowRequestsTap;
  final VoidCallback onPostTap;

  const NovaTopBar({
    super.key,
    required this.neonController,
    required this.onCameraTap,
    required this.onNotificationTap,
    required this.onFollowRequestsTap,
    required this.onPostTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black, width: 1),
        ),
      ),
      child: Row(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onCameraTap,
                icon: const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.black,
                  size: 25,
                ),
              ),
              IconButton(
                onPressed: onPostTap,
                icon: const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: Colors.black,
                  size: 25,
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: NovaLogoText(controller: neonController),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FollowRequestTopIcon(onTap: onFollowRequestsTap),
              IconButton(
                onPressed: onNotificationTap,
                icon: const Icon(
                  Icons.notifications_rounded,
                  color: Colors.black,
                  size: 26,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NovaLogoText extends StatelessWidget {
  final AnimationController controller;

  const NovaLogoText({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              textScaler: TextScaler.noScaling,
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: Colors.black,
                  height: 1,
                ),
                children: [
                  const TextSpan(text: 'NO'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment(-1 + controller.value * 2, 0),
                          end: Alignment(1 - controller.value * 2, 0),
                          colors: const [
                            Color(0xFF00D9FF),
                            Color(0xFF3C7BFF),
                            Color(0xFFFF00B8),
                            Color(0xFFFF7A00),
                          ],
                        ).createShader(bounds);
                      },
                      child: const Text(
                        'V',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: 'A'),
                ],
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              'Kaan Ayaz Studio',
              textScaler: TextScaler.noScaling,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                height: 1,
              ),
            ),
          ],
        );
      },
    );
  }
}

class NovaBottomBar extends StatelessWidget {
  final AnimationController controller;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const NovaBottomBar({
    super.key,
    required this.controller,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFBDBDBD),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          NovaBottomIcon(
            selected: currentIndex == 0,
            icon: Icons.home_rounded,
            onTap: () => onTap(0),
          ),
          MessageBottomIcon(
            selected: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          Expanded(
            child: Center(
              child: NovaCenterAddButton(
                controller: controller,
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ),
          ),
          NovaBottomIcon(
            selected: currentIndex == 3,
            icon: Icons.receipt_long_rounded,
            onTap: () => onTap(3),
          ),
          NovaBottomIcon(
            selected: currentIndex == 4,
            icon: Icons.person_rounded,
            onTap: () => onTap(4),
          ),
        ],
      ),
    );
  }
}


class NovaBottomIcon extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const NovaBottomIcon({
    super.key,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: selected ? 44 : 40,
            height: selected ? 44 : 40,
            decoration: BoxDecoration(
              color: selected ? Colors.black : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
                  : [],
            ),
            child: Icon(
              icon,
              color: selected ? Colors.white : Colors.black,
              size: selected ? 25 : 23,
            ),
          ),
        ),
      ),
    );
  }
}


class MessageBottomIcon extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const MessageBottomIcon({
    super.key,
    required this.selected,
    required this.onTap,
  });

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  int _unreadTotal(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var total = 0;

    for (final doc in docs) {
      final data = doc.data();
      final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
      final raw = unreadCounts[currentUid];

      if (raw is num) {
        total += raw.toInt();
        continue;
      }

      final unreadBy = List<String>.from(data['unreadBy'] ?? []);
      if (unreadBy.contains(currentUid)) total += 1;
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (currentUid.isEmpty) {
      return NovaBottomIcon(
        selected: selected,
        icon: Icons.chat_bubble_rounded,
        onTap: onTap,
      );
    }

    return Expanded(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .where('participants', arrayContains: currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          final unread = _unreadTotal(snapshot.data?.docs ?? []);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: selected ? 44 : 40,
                    height: selected ? 44 : 40,
                    decoration: BoxDecoration(
                      color: selected ? Colors.black : Colors.transparent,
                      shape: BoxShape.circle,
                      boxShadow: selected
                          ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ]
                          : [],
                    ),
                    child: Icon(
                      Icons.chat_bubble_rounded,
                      color: selected ? Colors.white : Colors.black,
                      size: selected ? 25 : 23,
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 19),
                        height: 19,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : unread.toString(),
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


class NovaCenterAddButton extends StatelessWidget {
  final AnimationController controller;
  final bool selected;
  final VoidCallback onTap;

  const NovaCenterAddButton({
    super.key,
    required this.controller,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: selected ? 1.04 : 1.0,
            child: Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(2.2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  transform: GradientRotation(controller.value * 6.283185307),
                  colors: const [
                    Color(0xFFFF00B8),
                    Color(0xFF7C4DFF),
                    Color(0xFF00D9FF),
                    Color(0xFF00FF85),
                    Color(0xFFFFE600),
                    Color(0xFFFF7A00),
                    Color(0xFFFF00B8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF00B8).withOpacity(0.36),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedNeonLine extends StatelessWidget {
  final AnimationController controller;

  const AnimatedNeonLine({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + controller.value * 2, 0),
              end: Alignment(1 - controller.value * 2, 0),
              colors: const [
                Color(0xFF00D9FF),
                Color(0xFF0066FF),
                Color(0xFF8A00FF),
                Color(0xFFFF00B8),
                Color(0xFFFF7A00),
                Color(0xFFFFE600),
                Color(0xFFB7FF00),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF00B8).withOpacity(0.45),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}


class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  int selectedTab = 0;
  bool busy = false;

  User? get currentUser => FirebaseAuth.instance.currentUser;
  FirebaseFirestore get db => FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserNotificationsStream() {
    final uid = currentUser?.uid;
    if (uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(120)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getNovaMessagesStream() {
    final uid = currentUser?.uid;
    if (uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return db
        .collection('novaMessages')
        .where('targets', arrayContainsAny: ['all', uid])
        .limit(80)
        .snapshots();
  }

  IconData iconForType(String type, bool isNova) {
    if (isNova) return Icons.auto_awesome_rounded;

    switch (type) {
      case 'follow_request':
      case 'follow_request_accepted':
        return Icons.person_add_alt_1_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.mode_comment_rounded;
      case 'share':
        return Icons.ios_share_rounded;
      case 'post':
      case 'image_shared':
        return Icons.image_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day.$month.$year  $hour:$minute';
    }
    return '';
  }

  String notificationPhotoUrl(Map<String, dynamic> data, bool isNova) {
    if (isNova) {
      return novaCleanText(
        data['imageUrl'],
        fallback: novaCleanText(
          data['photoUrl'],
          fallback: novaCleanText(data['logoUrl']),
        ),
      );
    }

    return novaCleanText(
      data['senderPhotoUrl'],
      fallback: novaCleanText(
        data['fromUserPhotoUrl'],
        fallback: novaCleanText(
          data['photoUrl'],
          fallback: novaCleanText(
            data['avatarUrl'],
            fallback: novaCleanText(
              data['userPhotoUrl'],
              fallback: novaCleanText(
                data['likedUserPhotoUrl'],
                fallback: novaCleanText(
                  data['commentUserPhotoUrl'],
                  fallback: novaCleanText(data['requestUserPhotoUrl']),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> confirmAction(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            title,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          content: Text(
            message,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Onayla', style: TextStyle(color: Color(0xFFE53935))),
            ),
          ],
        );
      },
    );

    return ok == true;
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> deleteNotification(DocumentReference<Map<String, dynamic>> ref) async {
    if (busy) return;

    setState(() => busy = true);
    try {
      await ref.delete();
      showMessage('Bildirim silindi.');
    } catch (_) {
      showMessage('Bildirim silinemedi.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> clearAllNotifications(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (busy || docs.isEmpty) return;

    final ok = await confirmAction(
      'Bildirimleri sıfırla',
      'Tüm bildirimlerini silmek istediğine emin misin?',
    );
    if (!ok) return;

    setState(() => busy = true);
    try {
      final batch = db.batch();
      for (final doc in docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      showMessage('Bildirimler sıfırlandı.');
    } catch (_) {
      showMessage('Bildirimler sıfırlanamadı.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeStream = selectedTab == 0
        ? getUserNotificationsStream()
        : getNovaMessagesStream();

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text(
                      'Kapat',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: NotificationTabButton(
                        title: 'Bildirimlerim',
                        selected: selectedTab == 0,
                        onTap: () => setState(() => selectedTab = 0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NotificationTabButton(
                        title: 'NOVA’dan Mesaj',
                        selected: selectedTab == 1,
                        onTap: () => setState(() => selectedTab = 1),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: activeStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Bildirimler yüklenirken hata oluştu.',
                            textScaler: TextScaler.noScaling,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w800,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    docs.sort((a, b) {
                      final aTime = a.data()['createdAt'];
                      final bTime = b.data()['createdAt'];
                      if (aTime is Timestamp && bTime is Timestamp) {
                        return bTime.compareTo(aTime);
                      }
                      return 0;
                    });

                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            selectedTab == 0
                                ? 'Henüz bildirimin yok.'
                                : 'NOVA’dan gelen mesaj yok.',
                            textScaler: TextScaler.noScaling,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                      itemCount: docs.length + (selectedTab == 0 ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (selectedTab == 0 && index == 0) {
                          return SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: busy ? null : () => clearAllNotifications(docs),
                              icon: const Icon(Icons.delete_sweep_rounded),
                              label: const Text(
                                'Tüm Bildirimleri Sıfırla',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          );
                        }

                        final doc = docs[selectedTab == 0 ? index - 1 : index];
                        final data = doc.data();
                        final title = (data['title'] ?? '').toString().trim();
                        final text = (data['body'] ?? data['text'] ?? '').toString().trim();
                        final type = (data['type'] ?? '').toString();
                        final dateText = formatDate(data['createdAt']);
                        final imageUrl = notificationPhotoUrl(data, selectedTab == 1);

                        return NotificationCard(
                          title: title.isEmpty
                              ? (selectedTab == 0 ? 'Bildirim' : 'NOVA')
                              : title,
                          text: text.isEmpty ? 'Yeni bildirim.' : text,
                          dateText: dateText,
                          icon: iconForType(type, selectedTab == 1),
                          imageUrl: imageUrl,
                          isNova: selectedTab == 1,
                          canDelete: selectedTab == 0,
                          onDelete: selectedTab == 0
                              ? () => deleteNotification(doc.reference)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationTabButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const NotificationTabButton({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.black.withOpacity(0.045),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: selected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}


class NotificationAvatar extends StatelessWidget {
  final String imageUrl;
  final IconData icon;
  final bool isNova;

  const NotificationAvatar({
    super.key,
    required this.imageUrl,
    required this.icon,
    required this.isNova,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isNova ? Colors.black : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      clipBehavior: Clip.antiAlias,
      child: cleanUrl.isEmpty
          ? Icon(
        icon,
        color: isNova ? Colors.white : Colors.black,
        size: 23,
      )
          : Image.network(
        cleanUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Icon(
            icon,
            color: isNova ? Colors.white : Colors.black,
            size: 23,
          );
        },
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String title;
  final String text;
  final String dateText;
  final IconData icon;
  final String imageUrl;
  final bool isNova;
  final bool canDelete;
  final VoidCallback? onDelete;

  const NotificationCard({
    super.key,
    required this.title,
    required this.text,
    required this.dateText,
    required this.icon,
    this.imageUrl = '',
    required this.isNova,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NotificationAvatar(
            imageUrl: imageUrl,
            icon: icon,
            isNova: isNova,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        textScaler: TextScaler.noScaling,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (dateText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        dateText,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black45,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (canDelete) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onDelete,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6, bottom: 6),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFE53935),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class FollowRequestTopIcon extends StatelessWidget {
  final VoidCallback onTap;

  const FollowRequestTopIcon({
    super.key,
    required this.onTap,
  });

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    if (currentUid.isEmpty) {
      return IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black, size: 25),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('followRequests')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Takip istekleri',
              onPressed: onTap,
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.black,
                size: 25,
              ),
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 7,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}


class FollowRequestsPage extends StatefulWidget {
  const FollowRequestsPage({super.key});

  @override
  State<FollowRequestsPage> createState() => _FollowRequestsPageState();
}

class _FollowRequestsPageState extends State<FollowRequestsPage> {
  int selectedTab = 0;
  bool busy = false;

  FirebaseFirestore get db => FirebaseFirestore.instance;
  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> receivedStream() {
    if (currentUid.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return db
        .collection('users')
        .doc(currentUid)
        .collection('followRequests')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sentStream() {
    if (currentUid.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    // Gönderilen istekler artık kullanıcının kendi altında tutulur.
    // users/{currentUid}/sentFollowRequests/{targetUid}
    // Böylece collectionGroup index hatasına takılmadan anlık görünür.
    return db
        .collection('users')
        .doc(currentUid)
        .collection('sentFollowRequests')
        .snapshots();
  }

  String cleanText(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  String requestDate(dynamic value) {
    if (value is! Timestamp) return 'Tarih bilinmiyor';

    final date = value.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.$year  $hour:$minute';
  }

  String targetUidFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final targetFromData = cleanText(
      data['targetUserId'],
      fallback: cleanText(
        data['toUserId'],
        fallback: cleanText(data['userId']),
      ),
    );
    if (targetFromData.isNotEmpty) return targetFromData;
    return doc.id;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> targetUserStream(String uid) {
    if (uid.trim().isEmpty) {
      return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }
    return db.collection('users').doc(uid).snapshots();
  }

  Future<bool> confirmAction(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            title,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          content: Text(
            message,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Onayla', style: TextStyle(color: Color(0xFFE53935))),
            ),
          ],
        );
      },
    );

    return ok == true;
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> acceptRequest({
    required String requestUserId,
    required String requestDocId,
  }) async {
    if (busy || currentUid.isEmpty || requestUserId.isEmpty) return;

    setState(() => busy = true);

    try {
      final myRef = db.collection('users').doc(currentUid);
      final requesterRef = db.collection('users').doc(requestUserId);
      final requestRef = myRef.collection('followRequests').doc(requestDocId);

      final mySnap = await myRef.get();
      final my = mySnap.data() ?? <String, dynamic>{};

      final batch = db.batch();

      batch.set(myRef, {
        'followerIds': FieldValue.arrayUnion([requestUserId]),
        'followersCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(requesterRef, {
        'followingIds': FieldValue.arrayUnion([currentUid]),
        'followingCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.delete(requestRef);
      batch.delete(requesterRef.collection('sentFollowRequests').doc(currentUid));

      final notificationRef = requesterRef.collection('notifications').doc();
      final myName = cleanText(
        my['displayName'] ?? my['fullName'] ?? my['name'],
        fallback: cleanText(my['username'], fallback: 'Nova Kullanıcısı'),
      );
      final myPhoto = cleanText(
        my['photoUrl'] ??
            my['profileImage'] ??
            my['profileImageUrl'] ??
            my['profilePhotoUrl'] ??
            my['avatar'] ??
            my['userPhoto'],
      );
      batch.set(notificationRef, {
        'id': notificationRef.id,
        'type': 'follow_request_accepted',
        'pushType': 'follow_request_accepted',
        'notificationKind': 'follow_request_accepted',
        'title': 'Takip isteğin kabul edildi',
        'body': '$myName takip isteğini kabul etti.',
        'message': '$myName takip isteğini kabul etti.',
        'receiverId': requestUserId,
        'toUserId': requestUserId,
        'senderId': currentUid,
        'fromUserId': currentUid,
        'actorId': currentUid,
        'targetUserId': currentUid,
        'fromUserName': myName,
        'actorUsername': myName,
        'senderName': myName,
        'fromUserPhotoUrl': myPhoto,
        'senderPhotoUrl': myPhoto,
        'actorPhotoUrl': myPhoto,
        'photoUrl': myPhoto,
        'largeIconUrl': myPhoto,
        'read': false,
        'seen': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      showMessage('Takip isteği onaylandı.');
    } catch (_) {
      showMessage('İstek onaylanamadı. Firebase kurallarını kontrol et.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteReceivedRequest(String requestDocId) async {
    if (busy || currentUid.isEmpty || requestDocId.isEmpty) return;

    setState(() => busy = true);

    try {
      final batch = db.batch();
      batch.delete(
        db
            .collection('users')
            .doc(currentUid)
            .collection('followRequests')
            .doc(requestDocId),
      );
      batch.delete(
        db
            .collection('users')
            .doc(requestDocId)
            .collection('sentFollowRequests')
            .doc(currentUid),
      );
      await batch.commit();

      showMessage('Takip isteği silindi.');
    } catch (_) {
      showMessage('İstek silinemedi.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancelSentRequest({
    required String targetUserId,
    required String requestDocId,
  }) async {
    if (busy || currentUid.isEmpty || targetUserId.isEmpty || requestDocId.isEmpty) return;

    setState(() => busy = true);

    try {
      final batch = db.batch();
      batch.delete(
        db
            .collection('users')
            .doc(targetUserId)
            .collection('followRequests')
            .doc(currentUid),
      );
      batch.delete(
        db
            .collection('users')
            .doc(currentUid)
            .collection('sentFollowRequests')
            .doc(requestDocId),
      );
      if (requestDocId != targetUserId) {
        batch.delete(
          db
              .collection('users')
              .doc(currentUid)
              .collection('sentFollowRequests')
              .doc(targetUserId),
        );
      }
      await batch.commit();

      showMessage('Gönderdiğin istek geri alındı.');
    } catch (_) {
      showMessage('İstek geri alınamadı.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> clearReceivedRequests(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (busy || docs.isEmpty || currentUid.isEmpty) return;

    final ok = await confirmAction(
      'Gelen istekleri sil',
      'Tüm gelen takip isteklerini silmek istediğine emin misin?',
    );
    if (!ok) return;

    setState(() => busy = true);
    try {
      final batch = db.batch();
      for (final doc in docs) {
        final requestUserId = cleanText(doc.data()['fromUserId'], fallback: doc.id);
        batch.delete(doc.reference);
        if (requestUserId.isNotEmpty) {
          batch.delete(
            db
                .collection('users')
                .doc(requestUserId)
                .collection('sentFollowRequests')
                .doc(currentUid),
          );
        }
      }
      await batch.commit();
      showMessage('Gelen takip istekleri silindi.');
    } catch (_) {
      showMessage('Gelen takip istekleri silinemedi.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> clearSentRequests(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (busy || docs.isEmpty || currentUid.isEmpty) return;

    final ok = await confirmAction(
      'Gönderdiğin istekleri sil',
      'Gönderdiğin tüm takip isteklerini geri almak istediğine emin misin?',
    );
    if (!ok) return;

    setState(() => busy = true);
    try {
      final batch = db.batch();
      for (final doc in docs) {
        final targetUserId = targetUidFromDoc(doc);
        batch.delete(doc.reference);
        if (targetUserId.isNotEmpty) {
          batch.delete(
            db
                .collection('users')
                .doc(targetUserId)
                .collection('followRequests')
                .doc(currentUid),
          );
        }
      }
      await batch.commit();
      showMessage('Gönderdiğin takip istekleri geri alındı.');
    } catch (_) {
      showMessage('Gönderdiğin istekler silinemedi.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void openUserProfile(String uid) {
    if (uid.trim().isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => user_profile.UserProfilePage(userId: uid),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> sortedDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final items = [...docs];
    items.sort((a, b) {
      final at = a.data()['createdAt'];
      final bt = b.data()['createdAt'];
      final av = at is Timestamp ? at.millisecondsSinceEpoch : 0;
      final bv = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
      return bv.compareTo(av);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final activeStream = selectedTab == 0 ? receivedStream() : sentStream();

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text(
                      'Kapat',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Takip İstekleri',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: NotificationTabButton(
                        title: 'Gelen İstekler',
                        selected: selectedTab == 0,
                        onTap: () => setState(() => selectedTab = 0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NotificationTabButton(
                        title: 'Gönderdiğin İstekler',
                        selected: selectedTab == 1,
                        onTap: () => setState(() => selectedTab = 1),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: activeStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.black));
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Takip istekleri yüklenirken hata oluştu.',
                            textScaler: TextScaler.noScaling,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black54,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }

                    final docs = sortedDocs(snapshot.data?.docs ?? []);

                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            selectedTab == 0
                                ? 'Gelen takip isteği yok.'
                                : 'Gönderdiğin takip isteği yok.',
                            textScaler: TextScaler.noScaling,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black54,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                      itemCount: docs.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final title = selectedTab == 0
                              ? 'Tüm Gelen İstekleri Sil'
                              : 'Tüm Gönderilen İstekleri Sil';
                          return SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: busy
                                  ? null
                                  : () {
                                if (selectedTab == 0) {
                                  clearReceivedRequests(docs);
                                } else {
                                  clearSentRequests(docs);
                                }
                              },
                              icon: const Icon(Icons.delete_sweep_rounded),
                              label: Text(
                                title,
                                textScaler: TextScaler.noScaling,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          );
                        }

                        final doc = docs[index - 1];
                        final data = doc.data();

                        if (selectedTab == 0) {
                          final requestUserId = cleanText(
                            data['fromUserId'],
                            fallback: doc.id,
                          );

                          return FollowRequestCard(
                            mode: FollowRequestCardMode.received,
                            userId: requestUserId,
                            title: cleanText(data['displayName'], fallback: cleanText(data['username'], fallback: 'Nova Kullanıcısı')),
                            username: cleanText(data['username'], fallback: 'nova.user'),
                            photoUrl: cleanText(data['photoUrl']),
                            dateText: requestDate(data['createdAt']),
                            busy: busy,
                            onProfileTap: () => openUserProfile(requestUserId),
                            onAccept: () => acceptRequest(
                              requestUserId: requestUserId,
                              requestDocId: doc.id,
                            ),
                            onDelete: () => deleteReceivedRequest(doc.id),
                          );
                        }

                        final targetUserId = targetUidFromDoc(doc);

                        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: targetUserStream(targetUserId),
                          builder: (context, userSnap) {
                            final user = userSnap.data?.data() ?? <String, dynamic>{};
                            final docTitle = cleanText(
                              data['toDisplayName'] ?? data['targetDisplayName'] ?? data['displayName'],
                              fallback: cleanText(data['toUsername'] ?? data['targetUsername']),
                            );
                            final docUsername = cleanText(
                              data['toUsername'] ?? data['targetUsername'] ?? data['username'],
                              fallback: 'nova.user',
                            );
                            final docPhoto = cleanText(
                              data['toPhotoUrl'] ?? data['targetPhotoUrl'] ?? data['photoUrl'],
                            );

                            return FollowRequestCard(
                              mode: FollowRequestCardMode.sent,
                              userId: targetUserId,
                              title: cleanText(
                                user['displayName'] ?? user['fullName'] ?? user['name'],
                                fallback: cleanText(
                                  user['username'],
                                  fallback: docTitle.isEmpty ? 'Nova Kullanıcısı' : docTitle,
                                ),
                              ),
                              username: cleanText(
                                user['username'],
                                fallback: docUsername,
                              ),
                              photoUrl: cleanText(
                                user['photoUrl'] ??
                                    user['profileImage'] ??
                                    user['profileImageUrl'] ??
                                    user['userPhoto'],
                                fallback: docPhoto,
                              ),
                              dateText: requestDate(data['createdAt']),
                              busy: busy,
                              onProfileTap: () => openUserProfile(targetUserId),
                              onAccept: null,
                              onDelete: () => cancelSentRequest(
                                targetUserId: targetUserId,
                                requestDocId: doc.id,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum FollowRequestCardMode { received, sent }

class FollowRequestCard extends StatelessWidget {
  final FollowRequestCardMode mode;
  final String userId;
  final String title;
  final String username;
  final String photoUrl;
  final String dateText;
  final bool busy;
  final VoidCallback onProfileTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDelete;

  const FollowRequestCard({
    super.key,
    required this.mode,
    required this.userId,
    required this.title,
    required this.username,
    required this.photoUrl,
    required this.dateText,
    required this.busy,
    required this.onProfileTap,
    required this.onAccept,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUsername = username.replaceAll('@', '').trim();
    final isReceived = mode == FollowRequestCardMode.received;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.black,
                  backgroundImage: photoUrl.trim().isEmpty ? null : NetworkImage(photoUrl.trim()),
                  child: photoUrl.trim().isEmpty
                      ? const Icon(Icons.person_rounded, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.trim().isEmpty ? 'Nova Kullanıcısı' : title,
                        textScaler: TextScaler.noScaling,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@${cleanUsername.isEmpty ? 'nova.user' : cleanUsername}',
                        textScaler: TextScaler.noScaling,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black54,
                          fontSize: 12.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateText,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black45,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!isReceived) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'İstek gönderildi • aktif',
                            textScaler: TextScaler.noScaling,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.black),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isReceived)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Onayla',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : onDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Sil',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text(
                  'İsteği Geri Al',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
