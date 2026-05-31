import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'user_profile_page.dart';

String novaTimeAgo(dynamic value, {bool activeSuffix = false}) {
  if (value is! Timestamp) return activeSuffix ? 'Yakın zamanda aktifti' : '';

  final date = value.toDate();
  final diff = DateTime.now().difference(date);

  if (diff.inSeconds < 45) return activeSuffix ? 'Az önce aktifti' : 'Şimdi';
  if (diff.inMinutes < 60) {
    return activeSuffix ? '${diff.inMinutes} dk önce aktifti' : '${diff.inMinutes} dk';
  }
  if (diff.inHours < 24) {
    return activeSuffix ? '${diff.inHours} saat önce aktifti' : '${diff.inHours} sa';
  }
  if (diff.inDays == 1) return activeSuffix ? 'Dün aktifti' : 'Dün';
  if (diff.inDays < 7) {
    return activeSuffix ? '${diff.inDays} gün önce aktifti' : '${diff.inDays} gün';
  }

  final formatted = '${date.day}.${date.month}.${date.year}';
  return activeSuffix ? '$formatted aktifti' : formatted;
}

String novaPresenceText(Map<String, dynamic> userData, {String fallback = '@novauser'}) {
  final isOnline = userData['isOnline'] == true;
  if (isOnline) return 'Şu an aktif';

  final lastSeen = userData['lastSeenAt'] ?? userData['lastActiveAt'] ?? userData['updatedAt'];
  final seenText = novaTimeAgo(lastSeen, activeSuffix: true);
  if (seenText.trim().isNotEmpty) return seenText;

  return fallback;
}

bool novaUserIsInsideChat({
  required Map<String, dynamic> chatData,
  required Map<String, dynamic> receiverData,
  required String receiverUid,
  required String chatId,
}) {
  final receiverActiveChatId = (receiverData['activeChatId'] ?? '').toString().trim();
  final receiverActiveDmChatId = (receiverData['activeDmChatId'] ?? '').toString().trim();
  final receiverForegroundChatId = (receiverData['foregroundChatId'] ?? '').toString().trim();
  final activeUsers = List<String>.from(chatData['activeUsers'] ?? const <String>[]);

  return receiverActiveChatId == chatId ||
      receiverActiveDmChatId == chatId ||
      receiverForegroundChatId == chatId ||
      activeUsers.contains(receiverUid);
}

/// DM ekranının açık olduğu sohbeti hem bu dosya içinde hem Firestore'da güvenli takip eder.
/// Not: FCM/local notification tarafı main.dart içinde bu değeri ya da Firestore'daki
/// activeChatId / activeDmChatId alanını kontrol ederse aynı sohbet açıkken bildirim göstermez.
class NovaForegroundState {
  static String activeChatId = '';

  static void setActiveChat(String chatId) {
    activeChatId = chatId.trim();
  }

  static void clearActiveChat(String chatId) {
    if (activeChatId == chatId.trim()) {
      activeChatId = '';
    }
  }
}


class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController searchController = TextEditingController();
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  late final AnimationController neonController;
  String searchText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    neonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    updateMyPresence(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    updateMyPresence(false);
    searchController.dispose();
    neonController.dispose();
    super.dispose();
  }

  User? get currentUser => auth.currentUser;

  CollectionReference<Map<String, dynamic>> get usersRef =>
      db.collection('users');

  CollectionReference<Map<String, dynamic>> get chatsRef =>
      db.collection('conversations');

  DocumentReference<Map<String, dynamic>> getCurrentUserPrivateDoc(String key) {
    return usersRef.doc(currentUser!.uid).collection('private').doc(key);
  }

  String cleanText(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  String getUserDisplayName(Map<String, dynamic> data) {
    final fullName = cleanText(data['fullName']);
    if (fullName.isNotEmpty) return fullName;

    final name = cleanText(data['name']);
    final surname = cleanText(data['surname']);
    final joined = '$name $surname'.trim();
    if (joined.isNotEmpty) return joined;

    final displayName = cleanText(data['displayName']);
    if (displayName.isNotEmpty) return displayName;

    final username = cleanText(data['username']);
    if (username.isNotEmpty) return username;

    return 'Nova Kullanıcısı';
  }

  String getUsername(Map<String, dynamic> data) {
    final username = cleanText(data['username']);
    if (username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }

    final email = cleanText(data['email']);
    if (email.contains('@')) return '@${email.split('@').first}';

    return '@novauser';
  }

  String getAvatar(Map<String, dynamic> data) {
    return cleanText(
      data['photoUrl'],
      fallback: cleanText(
        data['profileImageUrl'],
        fallback: cleanText(
          data['profilePhotoUrl'],
          fallback: cleanText(data['avatar']),
        ),
      ),
    );
  }

  String createChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatListStream(String uid) {
    return chatsRef.where('participants', arrayContains: uid).snapshots();
  }

  Future<void> refreshMessages() async {
    if (currentUser == null) return;
    setState(() {});
  }


  Future<void> updateMyPresence(bool online) async {
    final me = currentUser;
    if (me == null) return;

    try {
      await usersRef.doc(me.uid).set({
        'isOnline': online,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'presenceUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      updateMyPresence(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      updateMyPresence(false);
    }
  }

  Future<void> hideNovaWelcome() async {
    if (currentUser == null) return;

    await getCurrentUserPrivateDoc('novaWelcome').set({
      'hidden': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    showSnack('Nova mesajı gizlendi.');
  }

  Future<void> openOrCreateChat(String otherUid) async {
    final me = currentUser;
    if (me == null) return;
    if (otherUid == me.uid) return;

    final chatId = createChatId(me.uid, otherUid);
    final chatDoc = chatsRef.doc(chatId);
    final snap = await chatDoc.get();

    if (!snap.exists) {
      await chatDoc.set({
        'participants': [me.uid, otherUid],
        'participantMap': {
          me.uid: true,
          otherUid: true,
        },
        'hiddenFor': <String>[],
        'deletedFor': <String>[],
        'lastMessage': '',
        'lastMessageType': 'text',
        'lastSenderId': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts': {
          me.uid: 0,
          otherUid: 0,
        },
        'typing': {
          me.uid: false,
          otherUid: false,
        },
      });
    } else {
      await chatDoc.set({
        'hiddenFor': FieldValue.arrayRemove([me.uid]),
        'deletedFor': FieldValue.arrayRemove([me.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(chatId: chatId, otherUid: otherUid),
      ),
    );
  }

  Future<void> hideChat(String chatId) async {
    final me = currentUser;
    if (me == null) return;

    await chatsRef.doc(chatId).set({
      'hiddenFor': FieldValue.arrayUnion([me.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    showSnack('Sohbet gizlendi.');
  }

  Future<void> unhideChat(String chatId) async {
    final me = currentUser;
    if (me == null) return;

    await chatsRef.doc(chatId).set({
      'hiddenFor': FieldValue.arrayRemove([me.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    showSnack('Sohbet geri getirildi.');
  }

  Future<void> deleteChatForMe(String chatId) async {
    final me = currentUser;
    if (me == null) return;

    await chatsRef.doc(chatId).set({
      'hiddenFor': FieldValue.arrayUnion([me.uid]),
      'deletedFor': FieldValue.arrayUnion([me.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    showSnack('Sohbet silindi.');
  }

  void openHiddenMessagesPage() {
    final me = currentUser;
    if (me == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HiddenMessagesPage(
          currentUid: me.uid,
          onOpenChat: openOrCreateChat,
          onUnhideChat: unhideChat,
        ),
      ),
    );
  }

  void showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void openNewMessageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return NewMessageSheet(
          currentUid: currentUser?.uid ?? '',
          onUserSelected: openOrCreateChat,
        );
      },
    );
  }

  void openChatOptions({
    required String chatId,
    required String otherUid,
    required Map<String, dynamic> otherData,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return CenteredNovaDialog(
          title: 'Sohbet Seçenekleri',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BottomActionButton(
                title: 'Mesajlaştığın Kişinin Profilini Aç',
                icon: Icons.person_rounded,
                color: Colors.black,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfilePage(userId: otherUid),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              BottomActionButton(
                title: 'Sohbeti Gizle',
                icon: Icons.visibility_off_rounded,
                color: const Color(0xFFFF8A00),
                onTap: () {
                  Navigator.pop(context);
                  hideChat(chatId);
                },
              ),
              const SizedBox(height: 10),
              BottomActionButton(
                title: 'Sohbeti Sil',
                icon: Icons.delete_rounded,
                color: const Color(0xFFE53935),
                onTap: () {
                  Navigator.pop(context);
                  deleteChatForMe(chatId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void openNovaWelcomeOptions() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return CenteredNovaDialog(
          title: 'Nova Mesajı',
          child: BottomActionButton(
            title: 'Mesajı Gizle',
            icon: Icons.visibility_off_rounded,
            color: const Color(0xFFE53935),
            onTap: () {
              Navigator.pop(context);
              hideNovaWelcome();
            },
          ),
        );
      },
    );
  }

  Widget buildNovaWelcomeTile() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: currentUser == null
          ? null
          : getCurrentUserPrivateDoc('novaWelcome').snapshots(),
      builder: (context, snapshot) {
        final hidden = snapshot.data?.data()?['hidden'] == true;
        if (hidden) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ChatTileShell(
            hasUnread: true,
            neonController: neonController,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NovaWelcomeChatPage(),
                ),
              );
            },
            onLongPress: openNovaWelcomeOptions,
            avatar: const AssetImage('assets/images/logo.png'),
            title: 'Nova Destek',
            subtitle: 'Nova’ya hoş geldin 🚀',
            bottomText: 'Resmi bilgilendirme mesajı',
            timeText: 'Şimdi',
            unreadText: '1',
            isOnline: true,
            isPinned: true,
            isAssetAvatar: true,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = currentUser;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 65),
          child: FloatingActionButton(
            onPressed: openNewMessageSheet,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            child: const Icon(Icons.edit_rounded),
          ),
        ),
        body: SafeArea(
          child: me == null
              ? const LoginRequiredView()
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: NovaSearchBox(
                        controller: searchController,
                        onChanged: (value) {
                          setState(() => searchText = value.trim().toLowerCase());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    _HeaderCircleIcon(
                      tooltip: 'Gizlenmiş mesajlar',
                      icon: Icons.visibility_off_rounded,
                      onTap: openHiddenMessagesPage,
                    ),
                    const SizedBox(width: 8),
                    _HeaderCircleIcon(
                      tooltip: 'Yenile',
                      icon: Icons.refresh_rounded,
                      onTap: refreshMessages,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.7, color: Color(0xFFE2E2E2)),
              Expanded(
                child: RefreshIndicator(
                  color: Colors.black,
                  onRefresh: refreshMessages,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _chatListStream(me.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const MessagesLoadingView();
                      }

                      if (snapshot.hasError) {
                        return MessagesErrorView(
                          error: snapshot.error.toString(),
                          onRetry: refreshMessages,
                        );
                      }

                      final docs = (snapshot.data?.docs ?? []).where((doc) {
                        final data = doc.data();
                        final hiddenFor =
                        List<String>.from(data['hiddenFor'] ?? []);
                        if (hiddenFor.contains(me.uid)) return false;

                        final deletedFor =
                        List<String>.from(data['deletedFor'] ?? []);
                        if (deletedFor.contains(me.uid)) return false;

                        final participants =
                        List<String>.from(data['participants'] ?? data['participantIds'] ?? []);
                        if (!participants.contains(me.uid)) return false;

                        return true;
                      }).toList();

                      docs.sort((a, b) {
                        final ta = a.data()['lastMessageTime'] ?? a.data()['updatedAt'] ?? a.data()['createdAt'];
                        final tb = b.data()['lastMessageTime'] ?? b.data()['updatedAt'] ?? b.data()['createdAt'];
                        final ma = ta is Timestamp
                            ? ta.millisecondsSinceEpoch
                            : 0;
                        final mb = tb is Timestamp
                            ? tb.millisecondsSinceEpoch
                            : 0;
                        return mb.compareTo(ma);
                      });

                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
                        children: [
                          buildNovaWelcomeTile(),
                          if (docs.isEmpty)
                            const EmptyMessagesHint()
                          else
                            ...docs.map((doc) {
                              final chat = doc.data();
                              final participants = List<String>.from(chat['participants'] ?? chat['participantIds'] ?? []);
                              final otherUid = participants.firstWhere(
                                    (id) => id != me.uid,
                                orElse: () => '',
                              );

                              if (otherUid.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return UserChatTile(
                                chatId: doc.id,
                                chatData: chat,
                                otherUid: otherUid,
                                currentUid: me.uid,
                                neonController: neonController,
                                query: searchText,
                                onTap: () => openOrCreateChat(otherUid),
                                onOptions: (otherData) {
                                  openChatOptions(
                                    chatId: doc.id,
                                    otherUid: otherUid,
                                    otherData: otherData,
                                  );
                                },
                              );
                            }),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class HiddenMessagesPage extends StatelessWidget {
  final String currentUid;
  final ValueChanged<String> onOpenChat;
  final ValueChanged<String> onUnhideChat;

  const HiddenMessagesPage({
    super.key,
    required this.currentUid,
    required this.onOpenChat,
    required this.onUnhideChat,
  });

  String cleanText(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Gizlenmiş Mesajlar',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('conversations')
                      .where('participants', arrayContains: currentUid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const MessagesLoadingView();
                    }

                    if (snapshot.hasError) {
                      return MessagesErrorView(
                        error: snapshot.error.toString(),
                        onRetry: () {},
                      );
                    }

                    final docs = (snapshot.data?.docs ?? []).where((doc) {
                      final data = doc.data();
                      final hiddenFor = List<String>.from(data['hiddenFor'] ?? []);
                      final deletedFor = List<String>.from(data['deletedFor'] ?? []);
                      return hiddenFor.contains(currentUid) &&
                          !deletedFor.contains(currentUid);
                    }).toList();

                    docs.sort((a, b) {
                      final ta = a.data()['lastMessageTime'] ?? a.data()['updatedAt'] ?? a.data()['createdAt'];
                      final tb = b.data()['lastMessageTime'] ?? b.data()['updatedAt'] ?? b.data()['createdAt'];
                      final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
                      final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
                      return mb.compareTo(ma);
                    });

                    if (docs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Gizlenmiş sohbet yok.',
                            textScaler: TextScaler.noScaling,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black45,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final chat = doc.data();
                        final participants = List<String>.from(chat['participants'] ?? chat['participantIds'] ?? []);
                        final otherUid = participants.firstWhere(
                              (id) => id != currentUid,
                          orElse: () => '',
                        );

                        if (otherUid.isEmpty) return const SizedBox.shrink();

                        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(otherUid)
                              .snapshots(),
                          builder: (context, userSnap) {
                            final user = userSnap.data?.data() ?? {};
                            final name = cleanText(
                              user['fullName'],
                              fallback: cleanText(
                                user['displayName'],
                                fallback: cleanText(
                                  user['username'],
                                  fallback: 'Nova Kullanıcısı',
                                ),
                              ),
                            );
                            final lastMessage = cleanText(
                              chat['lastMessage'],
                              fallback: 'Henüz mesaj yok',
                            );
                            final photoUrl = cleanText(
                              user['photoUrl'],
                              fallback: cleanText(
                                user['profileImageUrl'],
                                fallback: cleanText(
                                  user['profilePhotoUrl'],
                                  fallback: cleanText(user['avatar']),
                                ),
                              ),
                            );
                            final imageProvider = photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl) as ImageProvider
                                : const AssetImage('assets/images/logo.png');

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.black,
                                    backgroundImage: imageProvider,
                                    onBackgroundImageError: (_, __) {},
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          textScaler: TextScaler.noScaling,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Roboto',
                                            color: Colors.black,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          lastMessage,
                                          textScaler: TextScaler.noScaling,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Roboto',
                                            color: Colors.black45,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Geri getir',
                                    onPressed: () => onUnhideChat(doc.id),
                                    icon: const Icon(
                                      Icons.restore_rounded,
                                      color: Colors.black,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Aç',
                                    onPressed: () {
                                      Navigator.pop(context);
                                      onOpenChat(otherUid);
                                    },
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
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


class UserChatTile extends StatelessWidget {
  final String chatId;
  final Map<String, dynamic> chatData;
  final String otherUid;
  final String currentUid;
  final AnimationController neonController;
  final String query;
  final VoidCallback onTap;
  final ValueChanged<Map<String, dynamic>> onOptions;

  const UserChatTile({
    super.key,
    required this.chatId,
    required this.chatData,
    required this.otherUid,
    required this.currentUid,
    required this.neonController,
    required this.query,
    required this.onTap,
    required this.onOptions,
  });

  String cleanText(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  String getDisplayName(Map<String, dynamic> data) {
    final fullName = cleanText(data['fullName']);
    if (fullName.isNotEmpty) return fullName;

    final name = cleanText(data['name']);
    final surname = cleanText(data['surname']);
    final joined = '$name $surname'.trim();
    if (joined.isNotEmpty) return joined;

    final displayName = cleanText(data['displayName']);
    if (displayName.isNotEmpty) return displayName;

    final username = cleanText(data['username']);
    if (username.isNotEmpty) return username;

    return 'Nova Kullanıcısı';
  }

  String getUsername(Map<String, dynamic> data) {
    final username = cleanText(data['username']);
    if (username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }

    final email = cleanText(data['email']);
    if (email.contains('@')) return '@${email.split('@').first}';

    return '@novauser';
  }

  String getAvatar(Map<String, dynamic> data) {
    return cleanText(
      data['photoUrl'],
      fallback: cleanText(
        data['profileImageUrl'],
        fallback: cleanText(
          data['profilePhotoUrl'],
          fallback: cleanText(data['avatar']),
        ),
      ),
    );
  }

  String timeAgo(dynamic value) => novaTimeAgo(value);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(otherUid).snapshots(),
      builder: (context, userSnap) {
        final otherData = userSnap.data?.data() ?? {};

        final title = getDisplayName(otherData);
        final username = getUsername(otherData);
        final lower = '$title $username'.toLowerCase();
        if (query.isNotEmpty && !lower.contains(query)) {
          return const SizedBox.shrink();
        }

        final unreadMap = Map<String, dynamic>.from(chatData['unreadCounts'] ?? {});
        final unreadBy = List<String>.from(chatData['unreadBy'] ?? []);
        final unread = (unreadMap[currentUid] is num)
            ? (unreadMap[currentUid] as num).toInt()
            : (unreadBy.contains(currentUid) ? 1 : 0);
        final hasUnread = unread > 0;

        final lastMessage = cleanText(
          chatData['lastMessage'],
          fallback: 'Henüz mesaj yok',
        );
        final isOnline = otherData['isOnline'] == true;
        final avatarUrl = getAvatar(otherData);

        ImageProvider avatar;
        bool isAsset = false;

        if (avatarUrl.isNotEmpty) {
          avatar = NetworkImage(avatarUrl);
        } else {
          avatar = const AssetImage('assets/images/logo.png');
          isAsset = true;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ChatTileShell(
            hasUnread: hasUnread,
            neonController: neonController,
            onTap: onTap,
            onLongPress: () => onOptions(otherData),
            avatar: avatar,
            title: title,
            subtitle: lastMessage,
            bottomText: novaPresenceText(otherData, fallback: username),
            timeText: timeAgo(chatData['lastMessageTime'] ?? chatData['updatedAt'] ?? chatData['createdAt']),
            unreadText: unread.toString(),
            isOnline: isOnline,
            isPinned: false,
            isAssetAvatar: isAsset,
          ),
        );
      },
    );
  }
}

class ChatTileShell extends StatelessWidget {
  final bool hasUnread;
  final AnimationController neonController;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ImageProvider avatar;
  final String title;
  final String subtitle;
  final String bottomText;
  final String timeText;
  final String unreadText;
  final bool isOnline;
  final bool isPinned;
  final bool isAssetAvatar;

  const ChatTileShell({
    super.key,
    required this.hasUnread,
    required this.neonController,
    required this.onTap,
    required this.onLongPress,
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.bottomText,
    required this.timeText,
    required this.unreadText,
    required this.isOnline,
    required this.isPinned,
    required this.isAssetAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedBuilder(
        animation: neonController,
        builder: (context, _) {
          return Container(
            padding: EdgeInsets.all(hasUnread ? 2.2 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: hasUnread
                  ? SweepGradient(
                transform: GradientRotation(
                  neonController.value * math.pi * 2,
                ),
                colors: const [
                  Color(0xFF000000),
                  Color(0xFF4A4A4A),
                  Color(0xFF000000),
                  Color(0xFF8A8A8A),
                  Color(0xFF000000),
                ],
              )
                  : null,
              boxShadow: hasUnread
                  ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  blurRadius: 18,
                  spreadRadius: 1.4,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 28,
                  spreadRadius: 2.2,
                ),
              ]
                  : const [],
            ),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(hasUnread ? 26 : 24),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
                boxShadow: const [],
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: hasUnread
                              ? SweepGradient(
                            transform: GradientRotation(
                              neonController.value * math.pi * 2,
                            ),
                            colors: const [
                              Color(0xFF000000),
                              Color(0xFF5A5A5A),
                              Color(0xFF000000),
                              Color(0xFF8A8A8A),
                              Color(0xFF000000),
                            ],
                          )
                              : null,
                          color: hasUnread ? null : Colors.black.withOpacity(0.08),
                        ),
                        child: CircleAvatar(
                          radius: 31,
                          backgroundColor: Colors.black,
                          backgroundImage: avatar,
                          onBackgroundImageError: (_, __) {},
                        ),
                      ),
                      if (isOnline)
                        Positioned(
                          right: 1,
                          bottom: 2,
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: const Color(0xFF11B85A),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isPinned) ...[
                              const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: Color(0xFF2196F3),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                textScaler: TextScaler.noScaling,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight:
                                  hasUnread ? FontWeight.w900 : FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          textScaler: TextScaler.noScaling,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: hasUnread ? Colors.black : Colors.black45,
                            fontSize: 13,
                            fontWeight:
                            hasUnread ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bottomText,
                          textScaler: TextScaler.noScaling,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: isOnline
                                ? const Color(0xFF11B85A)
                                : Colors.black38,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeText,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: hasUnread ? Colors.black : Colors.black38,
                          fontSize: 11.5,
                          fontWeight:
                          hasUnread ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (hasUnread)
                        Container(
                          constraints: const BoxConstraints(minWidth: 24),
                          height: 24,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            unreadText,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 24, height: 24),
                    ],
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


class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String otherUid;

  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.otherUid,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with WidgetsBindingObserver {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final ImagePicker imagePicker = ImagePicker();

  final TextEditingController messageController = TextEditingController();
  final FocusNode messageFocusNode = FocusNode();
  final ScrollController scrollController = ScrollController();

  late final DocumentReference<Map<String, dynamic>> chatDoc;
  late final CollectionReference<Map<String, dynamic>> messagesRef;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? otherUserStream;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _seenSubscription;
  Timer? _typingTimer;

  bool emojiOpen = false;
  bool sending = false;

  final List<String> emojis = const [
    '🔥',
    '❤️',
    '😂',
    '😍',
    '👏',
    '😎',
    '🚗',
    '🏁',
  ];

  String get currentUid => auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    chatDoc = db.collection('conversations').doc(widget.chatId);
    messagesRef = chatDoc.collection('messages');

    // En önemli düzeltme:
    // Bu stream build içinde kurulmaz. Klavye açılınca yeniden stream üretmez.
    messagesStream = messagesRef
        .orderBy('createdAt', descending: true)
        .limit(150)
        .snapshots();

    // Üst bar aktiflik/son görülme anlık güncellensin.
    // Mesaj listesi ayrı stable widget olduğu için klavye açılınca liste sıfırlanmaz.
    otherUserStream = db.collection('users').doc(widget.otherUid).snapshots();

    // En kritik kısım:
    // DM kutusu açılır açılmaz aktif sohbeti lokal + Firestore olarak işaretle.
    // Böylece aynı sohbetten gelen mesajda bildirim susturulabilir.
    NovaForegroundState.setActiveChat(widget.chatId);
    setActiveChat(true);
    markRead();
    listenIncomingMessagesForSeen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    _seenSubscription?.cancel();
    updateTyping(false);
    NovaForegroundState.clearActiveChat(widget.chatId);
    setActiveChat(false);
    messageController.dispose();
    messageFocusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (currentUid.isEmpty) return;

    if (state == AppLifecycleState.resumed) {
      NovaForegroundState.setActiveChat(widget.chatId);
      setMyOnline(true);
      setActiveChat(true);
      markRead();
    } else {
      updateTyping(false);
      NovaForegroundState.clearActiveChat(widget.chatId);
      setActiveChat(false);
      setMyOnline(false);
    }
  }

  String cleanText(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  String displayName(Map<String, dynamic> data) {
    final fullName = cleanText(data['fullName']);
    if (fullName.isNotEmpty) return fullName;

    final name = cleanText(data['name']);
    final surname = cleanText(data['surname']);
    final joined = '$name $surname'.trim();
    if (joined.isNotEmpty) return joined;

    final displayName = cleanText(data['displayName']);
    if (displayName.isNotEmpty) return displayName;

    final userName = cleanText(data['username']);
    if (userName.isNotEmpty) return userName;

    return 'Nova Kullanıcısı';
  }

  String username(Map<String, dynamic> data) {
    final userName = cleanText(data['username']);
    if (userName.isNotEmpty) {
      return userName.startsWith('@') ? userName : '@$userName';
    }

    final email = cleanText(data['email']);
    if (email.contains('@')) return '@${email.split('@').first}';

    return '@novauser';
  }

  String avatar(Map<String, dynamic> data) {
    return cleanText(
      data['photoUrl'],
      fallback: cleanText(
        data['profileImageUrl'],
        fallback: cleanText(
          data['profilePhotoUrl'],
          fallback: cleanText(data['avatar']),
        ),
      ),
    );
  }

  Future<void> setActiveChat(bool active) async {
    if (currentUid.isEmpty) return;

    try {
      final userDoc = db.collection('users').doc(currentUid);

      if (active) {
        await userDoc.set({
          'activeChatId': widget.chatId,
          'activeDmChatId': widget.chatId,
          'foregroundChatId': widget.chatId,
          'activeChatWith': widget.otherUid,
          'activeRoute': 'dm',
          'activeChatUpdatedAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'presenceUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await chatDoc.set({
          'activeUsers': FieldValue.arrayUnion([currentUid]),
        }, SetOptions(merge: true));
      } else {
        await userDoc.set({
          'activeChatId': FieldValue.delete(),
          'activeDmChatId': FieldValue.delete(),
          'foregroundChatId': FieldValue.delete(),
          'activeChatWith': FieldValue.delete(),
          'activeRoute': FieldValue.delete(),
          'activeChatUpdatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
          'presenceUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await chatDoc.set({
          'activeUsers': FieldValue.arrayRemove([currentUid]),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> setMyOnline(bool online) async {
    if (currentUid.isEmpty) return;

    try {
      await db.collection('users').doc(currentUid).set({
        'isOnline': online,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'presenceUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> markRead() async {
    if (currentUid.isEmpty) return;

    try {
      await chatDoc.set({
        'unreadBy': FieldValue.arrayRemove([currentUid]),
      }, SetOptions(merge: true));

      await chatDoc.update(<Object, Object?>{
        FieldPath(['unreadCounts', currentUid]): 0,
      });
    } catch (_) {}
  }

  void listenIncomingMessagesForSeen() {
    if (currentUid.isEmpty) return;

    _seenSubscription = messagesStream.listen((snapshot) async {
      final batch = db.batch();
      bool hasWrite = false;

      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final senderId = cleanText(data['senderId'] ?? data['senderUid']);
        final receiverId = cleanText(data['receiverId'] ?? data['receiverUid']);
        final seenBy = List<String>.from(data['seenBy'] ?? []);

        if (senderId != currentUid &&
            receiverId == currentUid &&
            !seenBy.contains(currentUid)) {
          batch.set(change.doc.reference, {
            'seenBy': FieldValue.arrayUnion([currentUid]),
            'seenAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          hasWrite = true;
        }
      }

      if (!hasWrite) return;

      try {
        await batch.commit();
        await markRead();
      } catch (_) {}
    });
  }

  Future<void> updateTyping(bool value) async {
    if (currentUid.isEmpty) return;

    try {
      await chatDoc.set({
        'typing': {
          currentUid: value,
        },
      }, SetOptions(merge: true));

      await chatDoc.update(<Object, Object?>{
        FieldPath(['typing', currentUid]): value,
      });
    } catch (_) {}
  }

  void onTypingChanged(String value) {
    _typingTimer?.cancel();

    final hasText = value.trim().isNotEmpty;
    updateTyping(hasText);

    if (hasText) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        updateTyping(false);
      });
    }
  }

  Future<Map<String, dynamic>?> getSendContext() async {
    if (currentUid.isEmpty) return null;

    final chatSnap = await chatDoc.get();
    final chatData = chatSnap.data() ?? {};
    final participants = List<String>.from(
      chatData['participants'] ?? chatData['participantIds'] ?? [],
    );

    final receiverUid = participants.firstWhere(
          (id) => id != currentUid,
      orElse: () => widget.otherUid,
    );

    if (receiverUid.isEmpty || receiverUid == currentUid) return null;

    final senderSnap = await db.collection('users').doc(currentUid).get();
    final senderData = senderSnap.data() ?? {};
    final authUser = auth.currentUser;

    String senderName = displayName(senderData);
    if (senderName == 'Nova Kullanıcısı' &&
        cleanText(authUser?.displayName).isNotEmpty) {
      senderName = cleanText(authUser?.displayName);
    }

    String senderPhotoUrl = avatar(senderData);
    if (senderPhotoUrl.isEmpty && cleanText(authUser?.photoURL).isNotEmpty) {
      senderPhotoUrl = cleanText(authUser?.photoURL);
    }

    final receiverSnap = await db.collection('users').doc(receiverUid).get();
    final receiverData = receiverSnap.data() ?? {};
    final receiverIsInsideChat = novaUserIsInsideChat(
      chatData: chatData,
      receiverData: receiverData,
      receiverUid: receiverUid,
      chatId: widget.chatId,
    );
    final shouldNotifyReceiver = !receiverIsInsideChat;

    return {
      'receiverUid': receiverUid,
      'senderName': senderName,
      'senderUsername': username(senderData),
      'senderPhotoUrl': senderPhotoUrl,
      'shouldNotifyReceiver': shouldNotifyReceiver,
    };
  }

  Future<void> sendImageMessage() async {
    if (currentUid.isEmpty || sending) return;

    try {
      final picked = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (picked == null) return;

      setState(() => sending = true);
      _typingTimer?.cancel();
      await updateTyping(false);

      final sendContext = await getSendContext();
      if (sendContext == null) return;

      final receiverUid = sendContext['receiverUid'] as String;
      final senderName = sendContext['senderName'] as String;
      final senderUserName = sendContext['senderUsername'] as String;
      final senderPhotoUrl = sendContext['senderPhotoUrl'] as String;
      final shouldNotifyReceiver = sendContext['shouldNotifyReceiver'] as bool;

      final file = File(picked.path);
      final messageId = messagesRef.doc().id;
      final storagePath =
          'dm_images/${widget.chatId}/$messageId-${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = storage.ref().child(storagePath);
      await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final imageUrl = await ref.getDownloadURL();
      final now = FieldValue.serverTimestamp();
      const messagePreview = '📷 Görsel';

      await messagesRef.doc(messageId).set({
        'senderId': currentUid,
        'receiverId': receiverUid,
        'type': 'image',
        'text': '',
        'imageUrl': imageUrl,
        'storagePath': storagePath,
        'senderName': senderName,
        'senderUsername': senderUserName,
        'senderPhotoUrl': senderPhotoUrl,
        'createdAt': now,
        'seenBy': [currentUid],
        'seenAt': null,
        'reaction': '',
        'deletedFor': <String>[],
        'notifyReceiver': shouldNotifyReceiver,
      });

      await chatDoc.set({
        'participants': [currentUid, receiverUid],
        'participantIds': [currentUid, receiverUid],
        'participantMap': {
          currentUid: true,
          receiverUid: true,
        },
        'lastMessage': messagePreview,
        'lastMessageType': 'image',
        'lastSenderId': currentUid,
        'lastSenderName': senderName,
        'lastSenderUsername': senderUserName,
        'lastSenderPhotoUrl': senderPhotoUrl,
        'lastMessageTime': now,
        'updatedAt': now,
        'hiddenFor': FieldValue.arrayRemove([receiverUid]),
        'deletedFor': FieldValue.arrayRemove([receiverUid]),
        'unreadBy': shouldNotifyReceiver
            ? FieldValue.arrayUnion([receiverUid])
            : FieldValue.arrayRemove([receiverUid]),
        'lastMessageSeenBy': [currentUid],
        'lastMessageSeenAt': null,
      }, SetOptions(merge: true));

      await chatDoc.update(<Object, Object?>{
        FieldPath(['unreadCounts', currentUid]): 0,
        FieldPath(['unreadCounts', receiverUid]):
        shouldNotifyReceiver ? FieldValue.increment(1) : 0,
        FieldPath(['typing', currentUid]): false,
      });

      // DM bildirimi için Firestore notifications kaydı eklenmiyor.
      // Profil resimli gerçek push bildirimi FCM tarafında tek kez gelir.

      scrollToBottom();
    } catch (_) {
      showSnack('Görsel gönderilemedi.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> sendTextMessage({String? directText}) async {
    final text = (directText ?? messageController.text).trim();
    if (text.isEmpty || currentUid.isEmpty || sending) return;

    setState(() => sending = true);

    if (directText == null) {
      messageController.clear();
    }

    _typingTimer?.cancel();
    await updateTyping(false);

    try {
      final chatSnap = await chatDoc.get();
      final chatData = chatSnap.data() ?? {};
      final participants = List<String>.from(
        chatData['participants'] ?? chatData['participantIds'] ?? [],
      );

      final receiverUid = participants.firstWhere(
            (id) => id != currentUid,
        orElse: () => widget.otherUid,
      );

      if (receiverUid.isEmpty || receiverUid == currentUid) return;

      final now = FieldValue.serverTimestamp();

      final senderSnap = await db.collection('users').doc(currentUid).get();
      final senderData = senderSnap.data() ?? {};
      final authUser = auth.currentUser;

      String senderName = displayName(senderData);
      if (senderName == 'Nova Kullanıcısı' &&
          cleanText(authUser?.displayName).isNotEmpty) {
        senderName = cleanText(authUser?.displayName);
      }

      String senderPhotoUrl = avatar(senderData);
      if (senderPhotoUrl.isEmpty && cleanText(authUser?.photoURL).isNotEmpty) {
        senderPhotoUrl = cleanText(authUser?.photoURL);
      }

      final senderUserName = username(senderData);
      final messagePreview =
      text.length > 80 ? '${text.substring(0, 80)}...' : text;

      final receiverSnap = await db.collection('users').doc(receiverUid).get();
      final receiverData = receiverSnap.data() ?? {};
      final receiverIsInsideChat = novaUserIsInsideChat(
        chatData: chatData,
        receiverData: receiverData,
        receiverUid: receiverUid,
        chatId: widget.chatId,
      );
      final shouldNotifyReceiver = !receiverIsInsideChat;

      await messagesRef.add({
        'senderId': currentUid,
        'receiverId': receiverUid,
        'type': 'text',
        'text': text,
        'imageUrl': '',
        'senderName': senderName,
        'senderUsername': senderUserName,
        'senderPhotoUrl': senderPhotoUrl,
        'createdAt': now,
        'seenBy': [currentUid],
        'seenAt': null,
        'reaction': '',
        'deletedFor': <String>[],
        'notifyReceiver': shouldNotifyReceiver,
      });

      await chatDoc.set({
        'participants': [currentUid, receiverUid],
        'participantIds': [currentUid, receiverUid],
        'participantMap': {
          currentUid: true,
          receiverUid: true,
        },
        'lastMessage': text,
        'lastMessageType': 'text',
        'lastSenderId': currentUid,
        'lastSenderName': senderName,
        'lastSenderUsername': senderUserName,
        'lastSenderPhotoUrl': senderPhotoUrl,
        'lastMessageTime': now,
        'updatedAt': now,
        'hiddenFor': FieldValue.arrayRemove([receiverUid]),
        'deletedFor': FieldValue.arrayRemove([receiverUid]),
        'unreadBy': shouldNotifyReceiver
            ? FieldValue.arrayUnion([receiverUid])
            : FieldValue.arrayRemove([receiverUid]),
        'lastMessageSeenBy': [currentUid],
        'lastMessageSeenAt': null,
      }, SetOptions(merge: true));

      await chatDoc.update(<Object, Object?>{
        FieldPath(['unreadCounts', currentUid]): 0,
        FieldPath(['unreadCounts', receiverUid]):
        shouldNotifyReceiver ? FieldValue.increment(1) : 0,
        FieldPath(['typing', currentUid]): false,
      });

      // DM bildirimi için Firestore notifications kaydı eklenmiyor.
      // Profil resimli gerçek push bildirimi FCM tarafında tek kez gelir.

      scrollToBottom();
    } catch (_) {
      showSnack('Mesaj gönderilemedi.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> deleteMessageForMe(String messageId) async {
    if (currentUid.isEmpty) return;

    try {
      await messagesRef.doc(messageId).set({
        'deletedFor': FieldValue.arrayUnion([currentUid]),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> setReaction(String messageId, String reaction) async {
    try {
      await messagesRef.doc(messageId).set({
        'reaction': reaction,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textScaler: TextScaler.noScaling),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void openMessageActions(String messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return NovaBottomSheet(
          title: 'Mesaj İşlemleri',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setReaction(messageId, emoji);
                    },
                    child: Text(
                      emoji,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontSize: 30),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              BottomActionButton(
                title: 'Benden Sil',
                icon: Icons.delete_rounded,
                color: const Color(0xFFE53935),
                onTap: () {
                  Navigator.pop(context);
                  deleteMessageForMe(messageId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void openProfile() {
    if (widget.otherUid.trim().isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(userId: widget.otherUid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUid.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: LoginRequiredView(),
      );
    }

    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        // Klavye açılınca Scaffold komple yeniden boyutlanıp listeyi sıfırlamasın.
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: otherUserStream ??
                    db.collection('users').doc(widget.otherUid).snapshots(),
                builder: (context, userSnap) {
                  final otherData = userSnap.data?.data() ?? {};
                  final title = displayName(otherData);
                  final userName = username(otherData);
                  final sub = novaPresenceText(otherData, fallback: userName);
                  final avatarUrl = avatar(otherData);

                  return ChatTopBar(
                    title: title,
                    subtitle: sub,
                    avatarUrl: avatarUrl,
                    isOnline: otherData['isOnline'] == true,
                    onBack: () => Navigator.pop(context),
                    onProfile: openProfile,
                  );
                },
              ),
              Expanded(
                child: StableMessagesList(
                  stream: messagesStream,
                  controller: scrollController,
                  currentUid: currentUid,
                  otherUid: widget.otherUid,
                  onLongPressMessage: openMessageActions,
                  onDoubleTapMessage: (messageId) => setReaction(messageId, '❤️'),
                ),
              ),
              if (emojiOpen)
                EmojiBar(
                  emojis: emojis,
                  onEmoji: (emoji) => sendTextMessage(directText: emoji),
                ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: MessageInputBox(
                            controller: messageController,
                            focusNode: messageFocusNode,
                            emojiOpen: emojiOpen,
                            sending: sending,
                            onEmojiToggle: () {
                              setState(() => emojiOpen = !emojiOpen);

                              if (emojiOpen) {
                                messageFocusNode.unfocus();
                              } else {
                                Future.delayed(
                                  const Duration(milliseconds: 80),
                                      () {
                                    if (mounted) {
                                      messageFocusNode.requestFocus();
                                    }
                                  },
                                );
                              }
                            },
                            onChanged: onTypingChanged,
                            onSubmit: () => sendTextMessage(),
                            onImagePick: sendImageMessage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        NovaCircleButton(
                          icon: Icons.favorite_border_rounded,
                          onTap: () => sendTextMessage(directText: '❤️'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StableMessagesList extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final ScrollController controller;
  final String currentUid;
  final String otherUid;
  final ValueChanged<String> onLongPressMessage;
  final ValueChanged<String> onDoubleTapMessage;

  const StableMessagesList({
    super.key,
    required this.stream,
    required this.controller,
    required this.currentUid,
    required this.otherUid,
    required this.onLongPressMessage,
    required this.onDoubleTapMessage,
  });

  @override
  State<StableMessagesList> createState() => _StableMessagesListState();
}

class _StableMessagesListState extends State<StableMessagesList>
    with AutomaticKeepAliveClientMixin {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> cachedDocs = [];

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          cachedDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            final deletedFor = List<String>.from(data['deletedFor'] ?? []);
            return !deletedFor.contains(widget.currentUid);
          }).toList();
        }

        if (snapshot.hasError) {
          return MessagesErrorView(
            error: snapshot.error.toString(),
            onRetry: () => setState(() {}),
          );
        }

        // Klavye açılırken Firestore connection waiting verse bile eski mesajlar tutulur.
        if (cachedDocs.isEmpty &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.expand();
        }

        if (cachedDocs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Henüz mesaj yok.\nİlk mesajı sen gönder.',
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black45,
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          key: const PageStorageKey<String>('stable_dm_messages_list'),
          controller: widget.controller,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          itemCount: cachedDocs.length,
          itemBuilder: (context, index) {
            final doc = cachedDocs[index];
            final data = doc.data();

            return MessageBubble(
              key: ValueKey(doc.id),
              message: data,
              currentUid: widget.currentUid,
              otherUid: widget.otherUid,
              fromMe: data['senderId'] == widget.currentUid ||
                  data['senderUid'] == widget.currentUid,
              neonController: null,
              onLongPress: () => widget.onLongPressMessage(doc.id),
              onDoubleTap: () => widget.onDoubleTapMessage(doc.id),
            );
          },
        );
      },
    );
  }
}

class NovaWelcomeChatPage extends StatelessWidget {
  const NovaWelcomeChatPage({super.key});

  static const String welcomeText =
      'Merhaba 👋\n\n'
      'Nova’ya hoş geldin.\n\n'
      'Nova içinde kendi profilini oluşturabilir, story paylaşabilir, gönderi yayınlayabilir, diğer kullanıcılarla mesajlaşabilir ve araç dünyasına özel alanları kullanabilirsin.\n\n'
      'Uygulamada mağaza, haberler, ikinci el araç ilanları ve acil çekici gibi bölümler zamanla daha da gelişecek. Profil bilgilerini eksiksiz doldurman, diğer kullanıcıların seni daha doğru tanımasına yardımcı olur.\n\n'
      'Mesajlar bölümünde istediğin kullanıcıya DM gönderebilir ve sohbetlerini yönetebilirsin.\n\n'
      'İyi kullanımlar 🚀\n'
      'Nova Ekibi';

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              ChatTopBar(
                title: 'Nova Destek',
                subtitle: 'Resmi Nova hesabı',
                avatarUrl: '',
                assetAvatar: 'assets/images/logo.png',
                isOnline: true,
                onBack: () => Navigator.pop(context),
                onProfile: () {},
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                  children: const [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MessageBubble(
                        message: {
                          'type': 'text',
                          'text': welcomeText,
                          'reaction': '',
                        },
                        fromMe: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatTopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final String avatarUrl;
  final String? assetAvatar;
  final bool isOnline;
  final VoidCallback onBack;
  final VoidCallback onProfile;

  const ChatTopBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    this.assetAvatar,
    required this.isOnline,
    required this.onBack,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider avatar;

    if (assetAvatar != null && assetAvatar!.isNotEmpty) {
      avatar = AssetImage(assetAvatar!);
    } else if (avatarUrl.trim().isNotEmpty) {
      avatar = NetworkImage(avatarUrl.trim());
    } else {
      avatar = const AssetImage('assets/images/logo.png');
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onProfile,
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.black,
                        backgroundImage: avatar,
                        onBackgroundImageError: (_, __) {},
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: const Color(0xFF11B85A),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          textScaler: TextScaler.noScaling,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          subtitle,
                          textScaler: TextScaler.noScaling,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: isOnline
                                ? const Color(0xFF11B85A)
                                : Colors.black45,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool fromMe;
  final String currentUid;
  final String otherUid;
  final AnimationController? neonController;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.fromMe,
    this.currentUid = '',
    this.otherUid = '',
    this.neonController,
    this.onLongPress,
    this.onDoubleTap,
  });

  bool _looksLikeEmojiOnly(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;

    const emojiOnlyMessages = <String>{
      '🔥',
      '❤️',
      '😂',
      '😍',
      '👏',
      '😎',
      '🚗',
      '🏁',
    };

    return emojiOnlyMessages.contains(text);
  }

  String _bubbleTime(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool get _isSeenByReceiver {
    if (!fromMe || otherUid.isEmpty) return false;
    final seenBy = List<String>.from(message['seenBy'] ?? []);
    return seenBy.contains(otherUid);
  }

  String get _seenText {
    if (!fromMe) return '';
    return _isSeenByReceiver ? 'Görüldü' : 'Gönderildi';
  }
  @override
  Widget build(BuildContext context) {
    final type = (message['type'] ?? message['messageType'] ?? 'text').toString();
    final reaction = (message['reaction'] ?? '').toString();
    final text = (message['text'] ?? message['body'] ?? '').toString().trim();
    final timeText = _bubbleTime(message['createdAt'] ?? message['time'] ?? message['sentAt']);

    if (type == 'post') {
      return _buildPostMessage(context, reaction, text);
    }

    if (type == 'image') {
      final imageUrl = (message['imageUrl'] ?? message['url'] ?? '').toString().trim();

      return _messageShell(
        context: context,
        reaction: reaction,
        timeText: timeText,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: imageUrl.isEmpty
              ? Container(
            width: 220,
            height: 220,
            color: fromMe
                ? Colors.black.withOpacity(0.04)
                : Colors.white.withOpacity(0.08),
            child: Icon(
              Icons.image_not_supported_rounded,
              color: fromMe ? Colors.black38 : Colors.white70,
              size: 42,
            ),
          )
              : Image.network(
            imageUrl,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Container(
              width: 220,
              height: 220,
              color: fromMe
                  ? Colors.black.withOpacity(0.04)
                  : Colors.white.withOpacity(0.08),
              child: Icon(
                Icons.broken_image_rounded,
                color: fromMe ? Colors.black38 : Colors.white70,
                size: 42,
              ),
            ),
          ),
        ),
      );
    }

    final bool emojiOnly = _looksLikeEmojiOnly(text);

    if (emojiOnly) {
      return GestureDetector(
        onLongPress: onLongPress,
        onDoubleTap: onDoubleTap,
        child: Align(
          alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  text,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontSize: 34,
                    height: 1.0,
                  ),
                ),
              ),
              if (timeText.isNotEmpty || _seenText.isNotEmpty)
                Positioned(
                  right: fromMe ? 0 : null,
                  left: fromMe ? null : 0,
                  bottom: -8,
                  child: Text(
                    fromMe && _seenText.isNotEmpty
                        ? '$timeText · $_seenText'
                        : timeText,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black45,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (reaction.isNotEmpty)
                Positioned(
                  right: fromMe ? -2 : null,
                  left: fromMe ? null : -2,
                  bottom: 0,
                  child: ReactionBadge(reaction: reaction),
                ),
            ],
          ),
        ),
      );
    }

    return _messageShell(
      context: context,
      reaction: reaction,
      timeText: timeText,
      child: Text(
        text,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: fromMe ? Colors.black : Colors.white,
          fontWeight: FontWeight.w800,
          height: 1.34,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _messageShell({
    required BuildContext context,
    required String reaction,
    required String timeText,
    required Widget child,
  }) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(fromMe ? 18 : 5),
      bottomRight: Radius.circular(fromMe ? 5 : 18),
    );

    final borderGradient = fromMe
        ? const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF00D9FF),
        Color(0xFFFF00B8),
        Color(0xFFFFFF00),
        Color(0xFF00D9FF),
      ],
    )
        : const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0xFFFF4FA3),
        Color(0xFF00C8FF),
        Color(0xFFFFD400),
      ],
    );

    Widget bubble = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(1.8),
      decoration: BoxDecoration(
        gradient: borderGradient,
        borderRadius: radius,
        boxShadow: fromMe
            ? [
          BoxShadow(
            color: const Color(0xFFFF00B8).withOpacity(0.18),
            blurRadius: 14,
            spreadRadius: 0.4,
          ),
          BoxShadow(
            color: const Color(0xFF00D9FF).withOpacity(0.14),
            blurRadius: 18,
            spreadRadius: 0.3,
          ),
        ]
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.38),
            blurRadius: 18,
            spreadRadius: 1.2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromMe ? Colors.white : Colors.black,
          borderRadius: radius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            child,
            if (timeText.isNotEmpty || _seenText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                fromMe && _seenText.isNotEmpty
                    ? '$timeText · $_seenText'
                    : timeText,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: fromMe ? Colors.black45 : Colors.white70,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return GestureDetector(
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      child: Align(
        alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            bubble,
            if (reaction.isNotEmpty)
              Positioned(
                right: fromMe ? 4 : null,
                left: fromMe ? null : 4,
                bottom: 0,
                child: ReactionBadge(reaction: reaction),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostMessage(BuildContext context, String reaction, String text) {
    final postImage = (message['postImage'] ?? '').toString().trim();
    final postUsername = (message['postUsername'] ?? 'nova.user').toString().trim();
    final postCaption = (message['postCaption'] ?? '').toString().trim();
    final postCar = (message['postCar'] ?? '').toString().trim();

    return _messageShell(
      context: context,
      reaction: reaction,
      timeText: _bubbleTime(message['createdAt'] ?? message['time'] ?? message['sentAt']),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.isNotEmpty) ...[
            Text(
              text,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: fromMe ? Colors.black : Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.34,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: fromMe ? const Color(0xFFF3F3F3) : Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: fromMe ? Colors.black.withOpacity(0.08) : Colors.white.withOpacity(0.16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: postImage.isEmpty
                        ? Container(
                      color: fromMe ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.08),
                      child: Icon(Icons.image_rounded, color: fromMe ? Colors.black26 : Colors.white54, size: 42),
                    )
                        : Image.network(
                      postImage,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => Container(
                        color: fromMe ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.08),
                        child: Icon(Icons.broken_image_rounded, color: fromMe ? Colors.black26 : Colors.white54),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@$postUsername',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: fromMe ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                      if (postCar.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          postCar,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: fromMe ? Colors.black54 : Colors.white70,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                      if (postCaption.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          postCaption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: fromMe ? Colors.black87 : Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
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

class ReactionBadge extends StatelessWidget {
  final String reaction;

  const ReactionBadge({
    super.key,
    required this.reaction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        reaction,
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}

class EmojiBar extends StatelessWidget {
  final List<String> emojis;
  final ValueChanged<String> onEmoji;

  const EmojiBar({
    super.key,
    required this.emojis,
    required this.onEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: emojis.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => onEmoji(emojis[index]),
            child: Text(
              emojis[index],
              textScaler: TextScaler.noScaling,
              style: const TextStyle(fontSize: 30),
            ),
          );
        },
      ),
    );
  }
}


class MessageInputBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool emojiOpen;
  final bool sending;
  final VoidCallback onEmojiToggle;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback? onImagePick;

  const MessageInputBox({
    super.key,
    required this.controller,
    this.focusNode,
    required this.emojiOpen,
    this.sending = false,
    required this.onEmojiToggle,
    required this.onChanged,
    required this.onSubmit,
    this.onImagePick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onEmojiToggle,
            icon: Icon(
              emojiOpen
                  ? Icons.keyboard_alt_outlined
                  : Icons.emoji_emotions_outlined,
              color: Colors.black,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              onChanged: onChanged,
              textInputAction: TextInputAction.send,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: 'Mesaj...',
                hintStyle: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black38,
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          IconButton(
            tooltip: 'Görsel gönder',
            onPressed: sending ? null : onImagePick,
            icon: const Icon(
              Icons.image_rounded,
              color: Colors.black,
            ),
          ),
          IconButton(
            onPressed: sending ? null : onSubmit,
            icon: sending
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            )
                : const Icon(
              Icons.send_rounded,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class NewMessageSheet extends StatefulWidget {
  final String currentUid;
  final ValueChanged<String> onUserSelected;

  const NewMessageSheet({
    super.key,
    required this.currentUid,
    required this.onUserSelected,
  });

  @override
  State<NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<NewMessageSheet> {
  final TextEditingController searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String cleanText(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  String displayName(Map<String, dynamic> data) {
    final fullName = cleanText(data['fullName']);
    if (fullName.isNotEmpty) return fullName;

    final name = cleanText(data['name']);
    final surname = cleanText(data['surname']);
    final joined = '$name $surname'.trim();
    if (joined.isNotEmpty) return joined;

    final displayName = cleanText(data['displayName']);
    if (displayName.isNotEmpty) return displayName;

    final username = cleanText(data['username']);
    if (username.isNotEmpty) return username;

    return 'Nova Kullanıcısı';
  }

  String username(Map<String, dynamic> data) {
    final username = cleanText(data['username']);
    if (username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }

    final email = cleanText(data['email']);
    if (email.contains('@')) return '@${email.split('@').first}';

    return '@novauser';
  }

  String avatar(Map<String, dynamic> data) {
    return cleanText(
      data['photoUrl'],
      fallback: cleanText(
        data['profileImageUrl'],
        fallback: cleanText(
          data['profilePhotoUrl'],
          fallback: cleanText(data['avatar']),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NovaBottomSheet(
      title: 'Yeni Mesaj',
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          children: [
            NovaSearchBox(
              controller: searchController,
              hintText: 'Kullanıcı ara',
              onChanged: (value) {
                setState(() => query = value.trim().toLowerCase());
              },
            ),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').limit(80).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const MessagesLoadingView();
                  }

                  final docs = (snapshot.data?.docs ?? []).where((doc) {
                    if (doc.id == widget.currentUid) return false;

                    final data = doc.data();
                    final text = '${displayName(data)} ${username(data)}'.toLowerCase();
                    if (query.isEmpty) return true;
                    return text.contains(query);
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Kullanıcı bulunamadı',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black45,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();

                      final avatarUrl = avatar(data);
                      final image = avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl) as ImageProvider
                          : const AssetImage('assets/images/logo.png');

                      return ListTile(
                        onTap: () {
                          Navigator.pop(context);
                          widget.onUserSelected(doc.id);
                        },
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.black,
                          backgroundImage: image,
                          onBackgroundImageError: (_, __) {},
                        ),
                        title: Text(
                          displayName(data),
                          textScaler: TextScaler.noScaling,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          username(data),
                          textScaler: TextScaler.noScaling,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.black45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NovaSearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const NovaSearchBox({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Mesajlarda ara',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Colors.black38, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black38,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NovaCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const NovaCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: 21),
      ),
    );
  }
}

class _HeaderCircleIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderCircleIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: Icon(
            icon,
            color: Colors.black,
            size: 21,
          ),
        ),
      ),
    );
  }
}


class BottomActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const BottomActionButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: 7),
            Text(
              title,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class CenteredNovaDialog extends StatelessWidget {
  final String title;
  final Widget child;

  const CenteredNovaDialog({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 35,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    textScaler: TextScaler.noScaling,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class NovaBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const NovaBottomSheet({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class DmProfilePage extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> userData;

  const DmProfilePage({
    super.key,
    required this.uid,
    required this.userData,
  });

  String cleanText(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  String displayName() {
    final fullName = cleanText(userData['fullName']);
    if (fullName.isNotEmpty) return fullName;

    final name = cleanText(userData['name']);
    final surname = cleanText(userData['surname']);
    final joined = '$name $surname'.trim();
    if (joined.isNotEmpty) return joined;

    final displayName = cleanText(userData['displayName']);
    if (displayName.isNotEmpty) return displayName;

    final username = cleanText(userData['username']);
    if (username.isNotEmpty) return username;

    return 'Nova Kullanıcısı';
  }

  String username() {
    final username = cleanText(userData['username']);
    if (username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }
    return '@novauser';
  }

  String avatar() {
    return cleanText(
      userData['photoUrl'],
      fallback: cleanText(
        userData['profileImageUrl'],
        fallback: cleanText(
          userData['profilePhotoUrl'],
          fallback: cleanText(userData['avatar']),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = avatar();
    final image = avatarUrl.isNotEmpty
        ? NetworkImage(avatarUrl) as ImageProvider
        : const AssetImage('assets/images/logo.png');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF00D9FF),
                          Color(0xFF8A00FF),
                          Color(0xFFFF00B8),
                          Color(0xFFFF7A00),
                        ],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 54,
                      backgroundColor: Colors.black,
                      backgroundImage: image,
                      onBackgroundImageError: (_, __) {},
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName(),
                    textScaler: TextScaler.noScaling,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    username(),
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black54,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bu kullanıcıyla mesajlaşma ekranından iletişime devam edebilirsin.',
                    textScaler: TextScaler.noScaling,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black45,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessagesLoadingView extends StatefulWidget {
  const MessagesLoadingView({super.key});

  @override
  State<MessagesLoadingView> createState() => _MessagesLoadingViewState();
}

class _MessagesLoadingViewState extends State<MessagesLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
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

  Widget tile() {
    return Container(
      height: 78,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          shimmerBox(width: 48, height: 48, shape: BoxShape.circle),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shimmerBox(height: 11, width: 120, radius: 99),
                const SizedBox(height: 8),
                shimmerBox(height: 10, width: double.infinity, radius: 99),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
      children: [tile(), tile(), tile(), tile()],
    );
  }
}

class MessagesErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const MessagesErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.error_outline_rounded,
          color: Colors.redAccent,
          size: 58,
        ),
        const SizedBox(height: 12),
        const Text(
          'Mesajlar yüklenemedi',
          textScaler: TextScaler.noScaling,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          error,
          textScaler: TextScaler.noScaling,
          textAlign: TextAlign.center,
          maxLines: 7,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.black45,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: const Text('Yenile'),
        ),
      ],
    );
  }
}

class EmptyMessagesHint extends StatelessWidget {
  const EmptyMessagesHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: Colors.black26,
            size: 52,
          ),
          SizedBox(height: 10),
          Text(
            'Henüz sohbet yok',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Alttaki butondan kullanıcı arayıp yeni mesaj başlatabilirsin.',
            textScaler: TextScaler.noScaling,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black45,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class LoginRequiredView extends StatelessWidget {
  const LoginRequiredView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.lock_outline_rounded,
              color: Colors.black26,
              size: 78,
            ),
            SizedBox(height: 16),
            Text(
              'Giriş gerekli',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Mesajları görmek için hesabına giriş yapmalısın.',
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black45,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
