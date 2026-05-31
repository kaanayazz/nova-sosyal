import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'user_profile_page.dart' as public_profile;
import 'emergency_tow_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onStoryTap;

  const HomePage({
    super.key,
    required this.onStoryTap,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

enum FeedMode { following, explore }

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final AnimationController neonController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late Future<DocumentSnapshot<Map<String, dynamic>>> _myProfileFuture;
  late Future<QuerySnapshot<Map<String, dynamic>>> _storiesFuture;
  late Future<QuerySnapshot<Map<String, dynamic>>> _postsFuture;

  FeedMode feedMode = FeedMode.explore;

  String get currentUid => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();

    neonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _reloadHomeFutures();
  }

  @override
  void dispose() {
    neonController.dispose();
    super.dispose();
  }

  void _reloadHomeFutures() {
    _myProfileFuture = _db.collection('users').doc(currentUid).get();

    _storiesFuture = _db
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: false)
        .orderBy('createdAt', descending: true)
        .limit(60)
        .get();

    _postsFuture = _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
  }

  List<String> _followingIds(Map<String, dynamic>? profile) {
    final raw = profile?['followingIds'] ?? profile?['following'] ?? [];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return <String>[];
  }

  List<HomeStory> _buildStories({
    required Map<String, dynamic>? myProfile,
    required QuerySnapshot<Map<String, dynamic>> snapshot,
  }) {
    final following = _followingIds(myProfile);

    final myOwnStories = snapshot.docs
        .map(HomeStory.fromDoc)
        .where((story) => story.ownerId == currentUid && story.isActive())
        .toList();

    final myImage = _safeString(
      myProfile?['profileImage'],
      fallback: _safeString(myProfile?['photoUrl']),
    );

    final me = HomeStory(
      id: myOwnStories.isNotEmpty ? myOwnStories.first.id : 'me',
      ownerId: currentUid,
      username: 'Hikayen',
      image: myOwnStories.isNotEmpty ? myOwnStories.first.image : '',
      profileImage: myImage.isEmpty
          ? 'https://ui-avatars.com/api/?name=NOVA&background=000000&color=ffffff'
          : myImage,
      viewedBy: myOwnStories.isNotEmpty ? myOwnStories.first.viewedBy : const [],
      hasNewStory: myOwnStories.isNotEmpty,
      isMe: true,
      createdAt: myOwnStories.isNotEmpty ? myOwnStories.first.createdAt : DateTime.now(),
      expiresAt: myOwnStories.isNotEmpty
          ? myOwnStories.first.expiresAt
          : DateTime.now().add(const Duration(hours: 24)),
    );

    final items = snapshot.docs.map(HomeStory.fromDoc).where((story) {
      if (story.ownerId == currentUid) return false;
      if (!story.isActive()) return false;
      if (feedMode == FeedMode.following) return following.contains(story.ownerId);
      return true;
    }).toList();

    return [me, ...items];
  }

  List<HomePost> _buildPosts({
    required Map<String, dynamic>? myProfile,
    required QuerySnapshot<Map<String, dynamic>> snapshot,
  }) {
    final following = _followingIds(myProfile);
    final posts = snapshot.docs.map(HomePost.fromDoc).where((post) {
      if (!post.active || post.deleted || post.archivedBy.contains(currentUid) || (post.isArchived && post.ownerId == currentUid)) return false;
      if (feedMode == FeedMode.following) {
        return following.contains(post.ownerId) || post.ownerId == currentUid;
      }
      return true;
    }).toList();

    return posts;
  }

  Future<void> refreshHome() async {
    if (!mounted) return;
    setState(_reloadHomeFutures);
    await Future.wait<dynamic>([
      _myProfileFuture,
      _storiesFuture,
      _postsFuture,
    ]);
  }

  String likeText(int likes) {
    if (likes >= 1000000) return '${(likes / 1000000).toStringAsFixed(1)}M';
    if (likes >= 1000) return '${(likes / 1000).toStringAsFixed(1)}B';
    return likes.toString();
  }


  Future<Map<String, String>> _currentActorPayload() async {
    final authUser = _auth.currentUser;
    final snap = await _db.collection('users').doc(currentUid).get();
    final data = snap.data() ?? <String, dynamic>{};

    final username = _safeString(
      data['username'],
      fallback: _safeString(authUser?.displayName, fallback: 'nova.user'),
    );
    final displayName = _safeString(
      data['displayName'],
      fallback: _safeString(authUser?.displayName, fallback: username),
    );
    final photo = _safeString(
      data['photoUrl'] ??
          data['userPhoto'] ??
          data['profileImage'] ??
          data['profileImageUrl'] ??
          data['avatarUrl'],
      fallback: _safeString(authUser?.photoURL),
    );

    return {
      'actorUsername': username,
      'actorDisplayName': displayName,
      'actorPhotoUrl': photo,
    };
  }

  Future<void> _createNovaNotification({
    required String receiverId,
    required String type,
    required String title,
    required String body,
    String postId = '',
    String storyId = '',
    String commentId = '',
    Map<String, String>? actor,
  }) async {
    if (receiverId.trim().isEmpty || receiverId == currentUid || currentUid.isEmpty) return;

    final payloadActor = actor ?? await _currentActorPayload();
    final now = FieldValue.serverTimestamp();
    final notificationRef = _db.collection('notifications').doc();
    final userNotificationRef = _db
        .collection('users')
        .doc(receiverId)
        .collection('notifications')
        .doc(notificationRef.id);

    final payload = <String, dynamic>{
      'id': notificationRef.id,
      'receiverId': receiverId,
      'toUserId': receiverId,
      'senderId': currentUid,
      'fromUserId': currentUid,
      'actorId': currentUid,
      'type': type,
      'title': title,
      'body': body,
      'message': body,
      'postId': postId,
      'storyId': storyId,
      'commentId': commentId,
      'read': false,
      'seen': false,
      'createdAt': now,
      ...payloadActor,
    };

    final batch = _db.batch();
    batch.set(notificationRef, payload, SetOptions(merge: true));
    batch.set(userNotificationRef, payload, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> openStory(List<HomeStory> stories, int index) async {
    final story = stories[index];

    if (story.isMe) {
      final ownSnap = await _db
          .collection('stories')
          .where('ownerId', isEqualTo: currentUid)
          .limit(20)
          .get();

      var ownStories = ownSnap.docs.map(HomeStory.fromDoc).where((s) => s.isActive()).toList();

      if (ownStories.isEmpty) {
        final legacySnap = await _db
            .collection('stories')
            .where('userId', isEqualTo: currentUid)
            .limit(20)
            .get();

        ownStories = legacySnap.docs.map(HomeStory.fromDoc).where((s) => s.isActive()).toList();
      }

      if (!mounted) return;

      if (ownStories.isEmpty) {
        widget.onStoryTap();
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MyStoryViewerPage(
            stories: ownStories,
            currentUid: currentUid,
            onAddStory: widget.onStoryTap,
          ),
        ),
      );
      return;
    }

    await _db.collection('stories').doc(story.id).set({
      'viewedBy': FieldValue.arrayUnion([currentUid]),
    }, SetOptions(merge: true));

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenStoryPage(
          stories: stories.where((s) => !s.isMe).toList(),
          initialIndex: math.max(0, index - 1),
          currentUid: currentUid,
          onProfileTap: openUserProfileById,
        ),
      ),
    );
  }

  void openUserProfileById(String userId) {
    if (userId.trim().isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => public_profile.UserProfilePage(userId: userId),
      ),
    );
  }

  void openEmergencyTowPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EmergencyTowPage()),
    );
  }

  Future<void> setPostLike(HomePost post, bool shouldLike) async {
    if (currentUid.isEmpty) return;

    final postRef = _db.collection('posts').doc(post.id);
    bool createdLike = false;

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(postRef);
      final data = snap.data() ?? <String, dynamic>{};

      final likedBy = _stringList(data['likedBy']);
      final alreadyLiked = likedBy.contains(currentUid);

      if (alreadyLiked == shouldLike) return;

      final currentCount = math.max(
        _safeInt(data['likeCount']),
        math.max(_safeInt(data['likes']), _safeInt(data['likesCount'])),
      );

      final nextCount = math.max(0, currentCount + (shouldLike ? 1 : -1));
      createdLike = shouldLike;

      transaction.set(postRef, {
        'likedBy': shouldLike
            ? FieldValue.arrayUnion([currentUid])
            : FieldValue.arrayRemove([currentUid]),
        'likeCount': nextCount,
        'likes': nextCount,
        'likesCount': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    if (createdLike) {
      final actor = await _currentActorPayload();
      await _createNovaNotification(
        receiverId: post.ownerId,
        type: 'post_like',
        title: 'Yeni beğeni',
        body: '${actor['actorUsername']} gönderini beğendi.',
        postId: post.id,
        actor: actor,
      );
    }
  }

  Future<void> registerPostView(HomePost post) async {
    if (currentUid.isEmpty || post.id.trim().isEmpty) return;

    final postRef = _db.collection('posts').doc(post.id);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(postRef);
      final data = snap.data() ?? <String, dynamic>{};

      final viewedBy = _stringList(data['viewedBy'] ?? data['seenBy']);
      if (viewedBy.contains(currentUid)) return;

      final currentCount = math.max(
        _safeInt(data['viewCount']),
        math.max(_safeInt(data['viewsCount']), _safeInt(data['seenCount'])),
      );

      final nextCount = math.max(0, currentCount + 1);

      transaction.set(postRef, {
        'viewedBy': FieldValue.arrayUnion([currentUid]),
        'seenBy': FieldValue.arrayUnion([currentUid]),
        'viewCount': nextCount,
        'viewsCount': nextCount,
        'seenCount': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> toggleSave(HomePost post) async {
    if (currentUid.isEmpty) return;

    final saveRef = _db
        .collection('users')
        .doc(currentUid)
        .collection('savedPosts')
        .doc(post.id);

    final snap = await saveRef.get();

    if (snap.exists) {
      await saveRef.delete();
    } else {
      await saveRef.set({
        'postId': post.id,
        'ownerId': post.ownerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void openComments(HomePost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return NovaCommentsSheet(
          post: post,
          currentUid: currentUid,
          auth: _auth,
          db: _db,
          onUserTap: openUserProfileById,
          onNotify: ({
            required String receiverId,
            required String type,
            required String title,
            required String body,
            String? postId,
            String? storyId,
            String? commentId,
            Map<String, String>? actor,
          }) {
            return _createNovaNotification(
              receiverId: receiverId,
              type: type,
              title: title,
              body: body,
              postId: postId ?? '',
              storyId: storyId ?? '',
              commentId: commentId ?? '',
              actor: actor,
            );
          },
        );
      },
    );
  }

  void sharePost(HomePost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return NovaPostShareSheet(
          post: post,
          currentUid: currentUid,
          db: _db,
        );
      },
    );
  }

  void openOwnerPostMenu(HomePost post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Gönderi işlemleri',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Colors.black),
                  title: const Text('Düzenle', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800)),
                  onTap: () {
                    Navigator.pop(context);
                    openEditPostSheet(post);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.archive_outlined, color: Colors.black),
                  title: const Text('Arşivle', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800)),
                  onTap: () async {
                    Navigator.pop(context);
                    await archivePost(post);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Sil', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    confirmDeletePost(post);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openEditPostSheet(HomePost post) {
    final controller = TextEditingController(text: post.desc);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Gönderiyi düzenle', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 6,
                    style: const TextStyle(fontFamily: 'Roboto'),
                    decoration: InputDecoration(
                      hintText: 'Açıklama yaz...',
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _db.collection('posts').doc(post.id).set({
                          'caption': controller.text.trim(),
                          'desc': controller.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                        if (mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text('Kaydet', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> archivePost(HomePost post) async {
    if (currentUid.isEmpty || post.ownerId != currentUid) return;
    await _db.collection('posts').doc(post.id).set({
      'archivedBy': FieldValue.arrayUnion([currentUid]),
      'isArchived': true,
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> confirmDeletePost(HomePost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Gönderi silinsin mi?', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)),
          content: const Text('Bu gönderi ana sayfadan kaldırılacak.', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
          ],
        );
      },
    );

    if (ok != true || currentUid.isEmpty || post.ownerId != currentUid) return;
    await _db.collection('posts').doc(post.id).set({
      'active': false,
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void openReportPostSheet(HomePost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return NovaReportPostSheet(
          post: post,
          currentUid: currentUid,
          db: _db,
        );
      },
    );
  }

  void openUserSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return UserSearchSheet(
          currentUid: currentUid,
          db: _db,
          onUserTap: openUserProfileById,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUid.isEmpty) {
      return const AuthRequiredHome();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HomeTopDock(
              mode: feedMode,
              onSearchTap: openUserSearch,
              onChanged: (mode) {
                if (mode != feedMode) setState(() => feedMode = mode);
              },
            ),
            const Divider(height: 1, color: Color(0xFFE7E7E7)),
            Expanded(
              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _myProfileFuture,
                builder: (context, profileSnap) {
                  final myProfile = profileSnap.data?.data();

                  return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    future: _storiesFuture,
                    builder: (context, storySnap) {
                      return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        future: _postsFuture,
                        builder: (context, postSnap) {
                          if (profileSnap.connectionState == ConnectionState.waiting ||
                              storySnap.connectionState == ConnectionState.waiting ||
                              postSnap.connectionState == ConnectionState.waiting ||
                              !storySnap.hasData ||
                              !postSnap.hasData) {
                            return const HomeFeedLoading();
                          }

                          if (profileSnap.hasError || storySnap.hasError || postSnap.hasError) {
                            return FirebaseHomeErrorBody(
                              error: '${profileSnap.error ?? storySnap.error ?? postSnap.error}',
                              onRetry: () => refreshHome(),
                            );
                          }

                          final stories = _buildStories(
                            myProfile: myProfile,
                            snapshot: storySnap.data!,
                          );

                          final posts = _buildPosts(
                            myProfile: myProfile,
                            snapshot: postSnap.data!,
                          );

                          return RefreshIndicator(
                            color: Colors.black,
                            backgroundColor: Colors.white,
                            onRefresh: refreshHome,
                            child: ScrollConfiguration(
                              behavior: const NoGlowScrollBehavior(),
                              child: ListView(
                                cacheExtent: 1400,
                                addAutomaticKeepAlives: true,
                                addRepaintBoundaries: true,
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                padding: EdgeInsets.zero,
                                children: [
                                  StoriesRow(
                                    stories: stories,
                                    controller: neonController,
                                    currentUid: currentUid,
                                    onStoryTap: (index) => openStory(stories, index),
                                    onTowTap: openEmergencyTowPage,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 14),
                                    child: Divider(height: 1, color: Color(0xFFE4E4E4)),
                                  ),
                                  if (posts.isEmpty)
                                    EmptyHomeFeed(
                                      mode: feedMode,
                                      onExplore: () => setState(() => feedMode = FeedMode.explore),
                                    )
                                  else
                                    ...posts.map((post) {
                                      return RepaintBoundary(
                                        child: NovaPostCard(
                                          key: ValueKey(post.id),
                                          post: post,
                                          currentUid: currentUid,
                                          likeText: likeText(post.likes),
                                          onLike: (shouldLike) => setPostLike(post, shouldLike),
                                          onView: () => registerPostView(post),
                                          onComment: () => openComments(post),
                                          onShare: () => sharePost(post),
                                          onSave: () => toggleSave(post),
                                          onProfileTap: () => openUserProfileById(post.ownerId),
                                          onOwnerMenu: () => openOwnerPostMenu(post),
                                          onReport: () => openReportPostSheet(post),
                                        ),
                                      );
                                    }),
                                  SizedBox(
                                    height: MediaQuery.of(context).viewPadding.bottom + 80,
                                  ),
                                ],
                              ),
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
    );
  }
}

class HomeStory {
  final String id;
  final String ownerId;
  final String username;
  final String image;
  final String profileImage;
  final List<String> viewedBy;
  final bool hasNewStory;
  final bool isMe;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool active;

  const HomeStory({
    required this.id,
    required this.ownerId,
    required this.username,
    required this.image,
    required this.profileImage,
    required this.viewedBy,
    required this.hasNewStory,
    required this.isMe,
    required this.createdAt,
    required this.expiresAt,
    this.active = true,
  });

  factory HomeStory.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final storyImage = _safeString(
      data['imageUrl'] ??
          data['mediaUrl'] ??
          data['storyImage'] ??
          data['image'] ??
          data['photoUrl'],
    );

    final avatarImage = _safeString(
      data['userPhoto'] ??
          data['photoUrl'] ??
          data['profileImage'] ??
          data['profileImageUrl'] ??
          data['userImage'] ??
          data['avatarUrl'] ??
          data['userPhotoUrl'],
      fallback: storyImage,
    );

    final storyCreatedAt = _toDate(data['createdAt'], fallback: DateTime.now());
    final storyExpiresAt = _toDate(
      data['expiresAt'],
      fallback: storyCreatedAt.add(const Duration(hours: 24)),
    );

    return HomeStory(
      id: doc.id,
      ownerId: _safeString(data['ownerId'] ?? data['userId'] ?? data['uid']),
      username: _safeString(
        data['username'],
        fallback: _safeString(data['displayName'], fallback: 'nova.user'),
      ),
      image: storyImage,
      profileImage: avatarImage,
      viewedBy: _stringList(data['viewedBy']),
      hasNewStory: data['hasNewStory'] != false,
      isMe: false,
      createdAt: storyCreatedAt,
      expiresAt: storyExpiresAt,
      active: data['active'] != false,
    );
  }

  bool isActive() => active && DateTime.now().isBefore(expiresAt);

  bool viewedByUser(String uid) => viewedBy.contains(uid);
}

class HomePost {
  final String id;
  final String ownerId;

  final String username;
  final String displayName;
  final String profileImage;

  final String car;
  final String location;
  final String category;

  final List<String> images;
  final String desc;

  final int likes;
  final int commentCount;
  final int saveCount;
  final int shareCount;
  final int viewCount;

  final List<String> likedBy;
  final List<String> savedBy;
  final List<String> viewedBy;
  final List<String> archivedBy;

  final bool active;
  final bool deleted;
  final bool isArchived;

  final DateTime createdAt;

  const HomePost({
    required this.id,
    required this.ownerId,
    required this.username,
    required this.displayName,
    required this.profileImage,
    required this.car,
    required this.location,
    required this.category,
    required this.images,
    required this.desc,
    required this.likes,
    required this.commentCount,
    required this.saveCount,
    required this.shareCount,
    required this.viewCount,
    required this.likedBy,
    required this.savedBy,
    required this.viewedBy,
    required this.archivedBy,
    required this.active,
    required this.deleted,
    required this.isArchived,
    required this.createdAt,
  });

  factory HomePost.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final images = _stringList(
      data['images'] ?? data['imageUrls'] ?? data['mediaUrls'],
    );

    final single = _safeString(
      data['imageUrl'] ??
          data['image'] ??
          data['mediaUrl'] ??
          data['photoUrl'],
    );

    final username = _safeString(
      data['username'],
      fallback: _safeString(data['displayName'], fallback: 'nova.user'),
    );

    final displayName = _safeString(
      data['displayName'],
      fallback: username,
    );

    final profileImage = _safeString(
      data['userPhoto'] ??
          data['photoUrl'] ??
          data['profileImage'] ??
          data['profileImageUrl'] ??
          data['userImage'] ??
          data['avatarUrl'],
    );

    return HomePost(
      id: doc.id,
      ownerId: _safeString(data['ownerId'] ?? data['userId'] ?? data['uid']),
      username: username,
      displayName: displayName,
      profileImage: profileImage,
      car: _safeString(
        data['carModel'] ??
            data['car'] ??
            data['carTitle'] ??
            data['vehicle'] ??
            data['title'],
        fallback: 'NOVA paylaşımı',
      ),
      location: _safeString(data['location']),
      category: _safeString(data['category']),
      images: images.isNotEmpty ? images : (single.isEmpty ? <String>[] : <String>[single]),
      desc: _safeString(data['caption'] ?? data['desc'] ?? data['description']),
      likes: _safeInt(data['likeCount'] ?? data['likes'] ?? data['likesCount']),
      commentCount: _safeInt(data['commentCount'] ?? data['commentsCount']),
      saveCount: _safeInt(data['saveCount'] ?? data['savesCount']),
      shareCount: _safeInt(data['shareCount'] ?? data['sharesCount'] ?? data['sendCount']),
      viewCount: math.max(_safeInt(data['viewCount']), math.max(_safeInt(data['viewsCount']), math.max(_safeInt(data['seenCount']), _safeInt(data['impressionCount'])))),
      likedBy: _stringList(data['likedBy']),
      savedBy: _stringList(data['savedBy']),
      viewedBy: _stringList(data['viewedBy'] ?? data['seenBy']),
      archivedBy: _stringList(data['archivedBy']),
      active: data['active'] != false,
      deleted: data['deleted'] == true,
      isArchived: data['isArchived'] == true || data['archived'] == true,
      createdAt: _toDate(data['createdAt']),
    );
  }

  bool isLiked(String uid) => likedBy.contains(uid);

  bool isSaved(String uid) => savedBy.contains(uid);
}

String _safeString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _safeInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

String _compactCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}B';
  return value.toString();
}

String _storyDateText(DateTime date) {
  if (date.millisecondsSinceEpoch <= 0) return '· zaman bilinmiyor';

  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 1) return '· şimdi paylaşıldı';
  if (diff.inMinutes < 60) return '· ${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '· ${diff.inHours} sa önce';

  String two(int v) => v.toString().padLeft(2, '0');
  return '· ${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)}';
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }
  return <String>[];
}


DateTime _toDate(dynamic value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class OptimizedNovaImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double quality;
  final Color backgroundColor;
  final IconData errorIcon;
  final Color iconColor;
  final double iconSize;

  const OptimizedNovaImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.quality = 0.75,
    this.backgroundColor = const Color(0xFFF2F2F2),
    this.errorIcon = Icons.broken_image_rounded,
    this.iconColor = Colors.black26,
    this.iconSize = 46,
  });

  int _cacheWidth(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = (mq.size.width * mq.devicePixelRatio * quality).round();
    return width.clamp(320, 1440);
  }

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Container(
        color: backgroundColor,
        alignment: Alignment.center,
        child: Icon(errorIcon, color: iconColor, size: iconSize),
      );
    }

    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: _cacheWidth(context),
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) {
        return Container(
          color: backgroundColor,
          alignment: Alignment.center,
          child: Icon(errorIcon, color: iconColor, size: iconSize),
        );
      },
    );
  }
}


class NovaProfileAvatar extends StatefulWidget {
  final String imageUrl;
  final double radius;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;

  const NovaProfileAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 21,
    this.backgroundColor = Colors.black,
    this.icon = Icons.person_rounded,
    this.iconColor = Colors.white,
  });

  @override
  State<NovaProfileAvatar> createState() => _NovaProfileAvatarState();
}

class _NovaProfileAvatarState extends State<NovaProfileAvatar> {
  ImageProvider? provider;

  @override
  void initState() {
    super.initState();
    _prepareImage();
  }

  @override
  void didUpdateWidget(covariant NovaProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _prepareImage();
  }

  void _prepareImage() {
    final url = widget.imageUrl.trim();
    if (url.isEmpty) {
      provider = null;
      return;
    }

    final nextProvider = NetworkImage(url);
    provider = nextProvider;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) precacheImage(nextProvider, context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor,
      backgroundImage: provider,
      child: provider == null ? Icon(widget.icon, color: widget.iconColor, size: widget.radius) : null,
    );
  }
}

class AuthRequiredHome extends StatelessWidget {
  const AuthRequiredHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'Ana sayfa için giriş yapılması gerekiyor.',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class FirebaseHomeError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const FirebaseHomeError({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.black),
              const SizedBox(height: 12),
              const Text(
                'Firebase bağlantısı kontrol edilmeli',
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FirebaseHomeErrorBody extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const FirebaseHomeErrorBody({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.black),
            const SizedBox(height: 12),
            const Text(
              'Firebase bağlantısı kontrol edilmeli',
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeFeedLoading extends StatelessWidget {
  const HomeFeedLoading({super.key});

  @override
  Widget build(BuildContext context) {
    Widget box({required double h, double? w, double r = 14, BoxShape shape = BoxShape.rectangle}) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          shape: shape,
          borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(r),
        ),
      );
    }

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 124,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => SizedBox(
              width: 76,
              child: Column(
                children: [
                  box(w: 74, h: 74, shape: BoxShape.circle),
                  const SizedBox(height: 8),
                  box(w: 58, h: 10, r: 99),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE4E4E4)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              box(w: 42, h: 42, shape: BoxShape.circle),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(w: 118, h: 13, r: 99),
                  const SizedBox(height: 8),
                  box(w: 170, h: 11, r: 99),
                ],
              ),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: 1,
          child: box(w: double.infinity, h: double.infinity, r: 0),
        ),
      ],
    );
  }
}

class EmptyHomeFeed extends StatelessWidget {
  final FeedMode mode;
  final VoidCallback onExplore;

  const EmptyHomeFeed({
    super.key,
    required this.mode,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 42, color: Colors.black),
          const SizedBox(height: 12),
          Text(
            mode == FeedMode.following
                ? 'Takip ettiğin kullanıcılardan henüz paylaşım yok.'
                : 'Henüz paylaşım yok.',
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w900,
              color: Colors.black,
              fontSize: 16,
            ),
          ),
          if (mode == FeedMode.following) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onExplore,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('NOVA Keşfet’e geç'),
            ),
          ],
        ],
      ),
    );
  }
}

class HomeTopDock extends StatelessWidget {
  final FeedMode mode;
  final VoidCallback onSearchTap;
  final ValueChanged<FeedMode> onChanged;

  const HomeTopDock({
    super.key,
    required this.mode,
    required this.onSearchTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final followingSelected = mode == FeedMode.following;

    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            Expanded(
              flex: 12,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSearchTap,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                    border: Border.all(color: const Color(0xFFE6E6E6)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_rounded, color: Colors.black54, size: 21),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Ara',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.black54,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 20,
              child: Container(
                height: 42,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                  border: Border.all(color: const Color(0xFFE6E6E6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TopDockButton(
                        title: 'Takipçilerin',
                        selected: followingSelected,
                        onTap: () => onChanged(FeedMode.following),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: _TopDockButton(
                        title: 'NOVA Keşfet',
                        selected: !followingSelected,
                        onTap: () => onChanged(FeedMode.explore),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopDockButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _TopDockButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: selected ? Colors.white : Colors.black54,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
            fontSize: 12.2,
          ),
        ),
      ),
    );
  }
}

class UserSearchSheet extends StatefulWidget {
  final String currentUid;
  final FirebaseFirestore db;
  final void Function(String userId) onUserTap;

  const UserSearchSheet({
    super.key,
    required this.currentUid,
    required this.db,
    required this.onUserTap,
  });

  @override
  State<UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<UserSearchSheet> {
  final TextEditingController searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool _matches(Map<String, dynamic> data) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final username = _safeString(data['username']).toLowerCase();
    final displayName = _safeString(data['displayName']).toLowerCase();
    final email = _safeString(data['email']).toLowerCase();

    return username.contains(q) || displayName.contains(q) || email.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Kullanıcı ara',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => query = value),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontFamily: 'Roboto'),
                    decoration: InputDecoration(
                      hintText: 'Kullanıcı adı veya isim yaz...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.045),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: widget.db
                        .collection('users')
                        .orderBy('username')
                        .limit(80)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.black));
                      }

                      if (snap.hasError) {
                        return const Center(
                          child: Text(
                            'Kullanıcılar yüklenemedi.',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(fontFamily: 'Roboto', color: Colors.black54),
                          ),
                        );
                      }

                      final docs = (snap.data?.docs ?? [])
                          .where((doc) => doc.id != widget.currentUid)
                          .where((doc) => _matches(doc.data()))
                          .toList();

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'Sonuç bulunamadı.',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(fontFamily: 'Roboto', color: Colors.black45),
                          ),
                        );
                      }

                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 14, color: Colors.black12),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final username = _safeString(
                            data['username'],
                            fallback: _safeString(data['displayName'], fallback: 'nova.user'),
                          );
                          final displayName = _safeString(data['displayName']);
                          final photo = _safeString(
                            data['photoUrl'] ??
                                data['userPhoto'] ??
                                data['profileImage'] ??
                                data['profileImageUrl'],
                          );

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.pop(context);
                              widget.onUserTap(doc.id);
                            },
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.black,
                              backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                              child: photo.isEmpty
                                  ? const Icon(Icons.person_rounded, color: Colors.white)
                                  : null,
                            ),
                            title: Text(
                              username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: displayName.isEmpty
                                ? null
                                : Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class NovaCommentsSheet extends StatefulWidget {
  final HomePost post;
  final String currentUid;
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  final void Function(String userId) onUserTap;
  final Future<void> Function({
  required String receiverId,
  required String type,
  required String title,
  required String body,
  String? postId,
  String? storyId,
  String? commentId,
  Map<String, String>? actor,
  }) onNotify;

  const NovaCommentsSheet({
    super.key,
    required this.post,
    required this.currentUid,
    required this.auth,
    required this.db,
    required this.onUserTap,
    required this.onNotify,
  });

  @override
  State<NovaCommentsSheet> createState() => _NovaCommentsSheetState();
}

class _NovaCommentsSheetState extends State<NovaCommentsSheet> {
  final TextEditingController controller = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> sendComment() async {
    final text = controller.text.trim();
    if (text.isEmpty || widget.currentUid.isEmpty || sending) return;

    setState(() => sending = true);

    try {
      final userSnap = await widget.db.collection('users').doc(widget.currentUid).get();
      final user = userSnap.data() ?? {};

      final username = _safeString(
        user['username'],
        fallback: _safeString(widget.auth.currentUser?.displayName, fallback: 'nova.user'),
      );

      final displayName = _safeString(
        user['displayName'],
        fallback: _safeString(widget.auth.currentUser?.displayName),
      );

      final profileImage = _safeString(
        user['photoUrl'] ?? user['userPhoto'] ?? user['profileImage'],
        fallback: _safeString(widget.auth.currentUser?.photoURL),
      );

      await widget.db.collection('posts').doc(widget.post.id).collection('comments').add({
        'text': text,
        'userId': widget.currentUid,
        'uid': widget.currentUid,
        'username': username,
        'displayName': displayName,
        'profileImage': profileImage,
        'userPhoto': profileImage,
        'likedBy': <String>[],
        'likeCount': 0,
        'likesCount': 0,
        'active': true,
        'deleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await widget.db.collection('posts').doc(widget.post.id).set({
        'commentCount': FieldValue.increment(1),
        'commentsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await widget.onNotify(
        receiverId: widget.post.ownerId,
        type: 'post_comment',
        title: 'Yeni yorum',
        body: '$username gönderine yorum yaptı: $text',
        postId: widget.post.id,
      );

      controller.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> toggleCommentLike(String commentId, Map<String, dynamic> data) async {
    if (widget.currentUid.isEmpty) return;

    final commentRef = widget.db
        .collection('posts')
        .doc(widget.post.id)
        .collection('comments')
        .doc(commentId);

    bool createdLike = false;
    String commentOwnerId = _safeString(data['userId'] ?? data['uid']);

    await widget.db.runTransaction((transaction) async {
      final snap = await transaction.get(commentRef);
      final fresh = snap.data() ?? <String, dynamic>{};

      commentOwnerId = _safeString(fresh['userId'] ?? fresh['uid'], fallback: commentOwnerId);
      final likedBy = _stringList(fresh['likedBy']);
      final alreadyLiked = likedBy.contains(widget.currentUid);
      final shouldLike = !alreadyLiked;

      final currentCount = math.max(
        _safeInt(fresh['likeCount']),
        _safeInt(fresh['likesCount']),
      );
      final nextCount = math.max(0, currentCount + (shouldLike ? 1 : -1));
      createdLike = shouldLike;

      transaction.set(commentRef, {
        'likedBy': shouldLike
            ? FieldValue.arrayUnion([widget.currentUid])
            : FieldValue.arrayRemove([widget.currentUid]),
        'likeCount': nextCount,
        'likesCount': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    if (createdLike) {
      await widget.onNotify(
        receiverId: commentOwnerId,
        type: 'comment_like',
        title: 'Yorum beğenildi',
        body: 'Yorumun beğenildi.',
        postId: widget.post.id,
        commentId: commentId,
      );
    }
  }

  Future<void> deleteComment(String commentId, Map<String, dynamic> data) async {
    if (widget.currentUid.isEmpty) return;

    final commentOwnerId = _safeString(data['userId'] ?? data['uid']);
    final canDelete = widget.post.ownerId == widget.currentUid || commentOwnerId == widget.currentUid;
    if (!canDelete) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Yorum silinsin mi?',
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Bu yorum gönderiden kaldırılacak.',
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontFamily: 'Roboto'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok != true) return;

    final postRef = widget.db.collection('posts').doc(widget.post.id);
    final commentRef = postRef.collection('comments').doc(commentId);

    await widget.db.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      final postData = postSnap.data() ?? <String, dynamic>{};
      final currentCount = math.max(
        _safeInt(postData['commentCount']),
        _safeInt(postData['commentsCount']),
      );
      final nextCount = math.max(0, currentCount - 1);

      transaction.delete(commentRef);
      transaction.set(postRef, {
        'commentCount': nextCount,
        'commentsCount': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.68,
        minChildSize: 0.42,
        maxChildSize: 0.93,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Yorumlar',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Roboto',
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: widget.db
                        .collection('posts')
                        .doc(widget.post.id)
                        .collection('comments')
                        .orderBy('createdAt', descending: true)
                        .limit(80)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.black));
                      }

                      if (snap.hasError) {
                        return const Center(
                          child: Text(
                            'Yorumlar yüklenemedi.',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              color: Colors.black45,
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }

                      final docs = snap.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'Henüz yorum yok. İlk yorumu sen yaz.',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              color: Colors.black45,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 18, color: Colors.black12),
                        itemBuilder: (context, i) {
                          final data = docs[i].data();
                          final username = _safeString(data['username'], fallback: 'nova.user');
                          final text = _safeString(data['text']);
                          final photo = _safeString(
                            data['profileImage'] ?? data['userPhoto'] ?? data['photoUrl'],
                          );
                          final commentUserId = _safeString(data['userId'] ?? data['uid']);
                          final commentLikedBy = _stringList(data['likedBy']);
                          final commentLiked = commentLikedBy.contains(widget.currentUid);
                          final commentLikeCount = _safeInt(data['likeCount'] ?? data['likesCount']);
                          final canDeleteComment = widget.post.ownerId == widget.currentUid || commentUserId == widget.currentUid;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: commentUserId.isEmpty
                                    ? null
                                    : () {
                                  Navigator.pop(context);
                                  widget.onUserTap(commentUserId);
                                },
                                child: NovaProfileAvatar(
                                  imageUrl: photo,
                                  radius: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: commentUserId.isEmpty
                                          ? null
                                          : () {
                                        Navigator.pop(context);
                                        widget.onUserTap(commentUserId);
                                      },
                                      child: RichText(
                                        textScaler: TextScaler.noScaling,
                                        text: TextSpan(
                                          style: const TextStyle(
                                            color: Colors.black,
                                            height: 1.35,
                                            fontFamily: 'Roboto',
                                          ),
                                          children: [
                                            TextSpan(
                                              text: '$username ',
                                              style: const TextStyle(fontWeight: FontWeight.w900),
                                            ),
                                            TextSpan(text: text),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () => toggleCommentLike(docs[i].id, data),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            commentLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            size: 17,
                                            color: commentLiked ? Colors.red : Colors.black45,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            commentLikeCount == 0 ? 'Beğen' : '$commentLikeCount beğeni',
                                            textScaler: TextScaler.noScaling,
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                              color: Colors.black45,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (canDeleteComment)
                                IconButton(
                                  tooltip: 'Yorumu sil',
                                  onPressed: () => deleteComment(docs[i].id, data),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.black45,
                                    size: 21,
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => sendComment(),
                            style: const TextStyle(fontFamily: 'Roboto'),
                            decoration: InputDecoration(
                              hintText: 'Yorum yaz...',
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.04),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: sending ? null : sendComment,
                          icon: sending
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


class NovaPostShareSheet extends StatefulWidget {
  final HomePost post;
  final String currentUid;
  final FirebaseFirestore db;

  const NovaPostShareSheet({
    super.key,
    required this.post,
    required this.currentUid,
    required this.db,
  });

  @override
  State<NovaPostShareSheet> createState() => _NovaPostShareSheetState();
}

class _NovaPostShareSheetState extends State<NovaPostShareSheet> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  final Map<String, _ShareUser> selectedUsers = {};

  String query = '';
  bool sending = false;
  bool showMessageBox = false;

  @override
  void dispose() {
    searchController.dispose();
    messageController.dispose();
    super.dispose();
  }

  bool _matches(Map<String, dynamic> data) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final username = _safeString(data['username']).toLowerCase();
    final displayName = _safeString(data['displayName']).toLowerCase();
    final email = _safeString(data['email']).toLowerCase();

    return username.contains(q) || displayName.contains(q) || email.contains(q);
  }

  String _conversationId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  void _toggleUser(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final user = _ShareUser(
      uid: doc.id,
      username: _safeString(
        data['username'],
        fallback: _safeString(data['displayName'], fallback: 'nova.user'),
      ),
      displayName: _safeString(data['displayName']),
      photoUrl: _safeString(
        data['photoUrl'] ??
            data['userPhoto'] ??
            data['profileImage'] ??
            data['profileImageUrl'] ??
            data['avatarUrl'],
      ),
    );

    setState(() {
      if (selectedUsers.containsKey(doc.id)) {
        selectedUsers.remove(doc.id);
      } else {
        selectedUsers[doc.id] = user;
      }
    });
  }

  Future<Map<String, dynamic>> _currentUserPayload() async {
    final uid = widget.currentUid;
    if (uid.isEmpty) return <String, dynamic>{};

    final authUser = FirebaseAuth.instance.currentUser;
    final snap = await widget.db.collection('users').doc(uid).get();
    final data = snap.data() ?? <String, dynamic>{};

    final username = _safeString(
      data['username'],
      fallback: _safeString(authUser?.displayName, fallback: 'nova.user'),
    );

    final displayName = _safeString(
      data['displayName'],
      fallback: _safeString(authUser?.displayName, fallback: username),
    );

    final photo = _safeString(
      data['photoUrl'] ??
          data['userPhoto'] ??
          data['profileImage'] ??
          data['profileImageUrl'] ??
          data['avatarUrl'],
      fallback: _safeString(authUser?.photoURL),
    );

    return {
      'senderUsername': username,
      'senderDisplayName': displayName,
      'senderPhotoUrl': photo,
    };
  }

  Future<void> _sendSelected() async {
    if (sending) return;

    if (widget.currentUid.isEmpty) {
      _showMessage('Göndermek için giriş yapman gerekiyor.');
      return;
    }

    if (selectedUsers.isEmpty) {
      _showMessage('Göndermek için en az bir kullanıcı seç.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => sending = true);

    try {
      final sender = await _currentUserPayload();
      final text = messageController.text.trim();
      final firstImage = widget.post.images.isEmpty ? '' : widget.post.images.first;
      final now = FieldValue.serverTimestamp();
      final batch = widget.db.batch();

      for (final receiver in selectedUsers.values) {
        final conversationId = _conversationId(widget.currentUid, receiver.uid);
        final conversationRef = widget.db.collection('conversations').doc(conversationId);
        final messageRef = conversationRef.collection('messages').doc();

        final lastMessage = text.isEmpty ? 'Bir post gönderildi' : text;

        batch.set(conversationRef, {
          'id': conversationId,
          'participants': [widget.currentUid, receiver.uid],
          'participantIds': [widget.currentUid, receiver.uid],
          'participantMap': {
            widget.currentUid: true,
            receiver.uid: true,
          },
          'lastMessage': lastMessage,
          'lastMessageType': 'post',
          'lastPostId': widget.post.id,
          'lastPostImage': firstImage,
          'lastSenderId': widget.currentUid,
          'updatedAt': now,
          'createdAt': now,
          'unreadBy': FieldValue.arrayUnion([receiver.uid]),
        }, SetOptions(merge: true));

        batch.set(messageRef, {
          'id': messageRef.id,
          'type': 'post',
          'messageType': 'post',
          'text': text,
          'body': text,
          'postId': widget.post.id,
          'postOwnerId': widget.post.ownerId,
          'postUsername': widget.post.username,
          'postDisplayName': widget.post.displayName,
          'postCaption': widget.post.desc,
          'postImage': firstImage,
          'postImages': widget.post.images,
          'postLocation': widget.post.location,
          'postCar': widget.post.car,
          'senderId': widget.currentUid,
          'senderUid': widget.currentUid,
          'receiverId': receiver.uid,
          'receiverUid': receiver.uid,
          'seen': false,
          'read': false,
          'createdAt': now,
          ...sender,
        });
      }

      batch.set(widget.db.collection('posts').doc(widget.post.id), {
        'shareCount': FieldValue.increment(selectedUsers.length),
        'sharesCount': FieldValue.increment(selectedUsers.length),
        'sendCount': FieldValue.increment(selectedUsers.length),
        'updatedAt': now,
      }, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;
      _showMessage(
        selectedUsers.length == 1
            ? 'Post mesaj olarak gönderildi.'
            : 'Post ${selectedUsers.length} kişiye mesaj olarak gönderildi.',
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Post gönderilemedi. İnternet bağlantısını ve Firebase izinlerini kontrol et.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _sliverBox(Widget child) {
    return SliverToBoxAdapter(child: child);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: bottom > 0 ? 0.92 : 0.82,
        minChildSize: 0.48,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: widget.db
                        .collection('users')
                        .orderBy('username')
                        .limit(120)
                        .snapshots(),
                    builder: (context, snap) {
                      final docs = (snap.data?.docs ?? [])
                          .where((doc) => doc.id != widget.currentUid)
                          .where((doc) => _matches(doc.data()))
                          .toList();

                      return CustomScrollView(
                        controller: scrollController,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          _sliverBox(const SizedBox(height: 14)),
                          _sliverBox(
                            const Text(
                              'Postu mesaj olarak gönder',
                              textAlign: TextAlign.center,
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          if (bottom == 0) _sliverBox(_SharePostPreview(post: widget.post)),
                          _sliverBox(
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                              child: TextField(
                                controller: searchController,
                                onChanged: (value) => setState(() => query = value),
                                textInputAction: TextInputAction.search,
                                style: const TextStyle(fontFamily: 'Roboto'),
                                decoration: InputDecoration(
                                  hintText: 'Göndereceğin kişileri ara...',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.045),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (selectedUsers.isNotEmpty)
                            _sliverBox(
                              SizedBox(
                                height: 54,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: selectedUsers.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final user = selectedUsers.values.elementAt(index);
                                    return _SelectedShareUserChip(
                                      user: user,
                                      onRemove: () => setState(() => selectedUsers.remove(user.uid)),
                                    );
                                  },
                                ),
                              ),
                            ),
                          _sliverBox(
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => setState(() => showMessageBox = !showMessageBox),
                                      child: Row(
                                        children: [
                                          Icon(
                                            showMessageBox
                                                ? Icons.check_box_rounded
                                                : Icons.check_box_outline_blank_rounded,
                                            color: Colors.black,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Mesaj ekle',
                                              textScaler: TextScaler.noScaling,
                                              style: TextStyle(
                                                fontFamily: 'Roboto',
                                                color: Colors.black,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${selectedUsers.length} kişi seçildi',
                                    textScaler: TextScaler.noScaling,
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (showMessageBox)
                            _sliverBox(
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                child: TextField(
                                  controller: messageController,
                                  minLines: 1,
                                  maxLines: 3,
                                  textInputAction: TextInputAction.newline,
                                  style: const TextStyle(fontFamily: 'Roboto'),
                                  decoration: InputDecoration(
                                    hintText: 'İstersen postla beraber mesaj yaz...',
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.045),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (snap.connectionState == ConnectionState.waiting)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(child: CircularProgressIndicator(color: Colors.black)),
                            )
                          else if (snap.hasError)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Text(
                                  'Kişiler yüklenemedi.',
                                  textScaler: TextScaler.noScaling,
                                  style: TextStyle(fontFamily: 'Roboto', color: Colors.black45),
                                ),
                              ),
                            )
                          else if (docs.isEmpty)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    'Gönderilecek kullanıcı bulunamadı.',
                                    textScaler: TextScaler.noScaling,
                                    style: TextStyle(fontFamily: 'Roboto', color: Colors.black45),
                                  ),
                                ),
                              )
                            else
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                    final doc = docs[index];
                                    final data = doc.data();
                                    final user = _ShareUser(
                                      uid: doc.id,
                                      username: _safeString(
                                        data['username'],
                                        fallback: _safeString(data['displayName'], fallback: 'nova.user'),
                                      ),
                                      displayName: _safeString(data['displayName']),
                                      photoUrl: _safeString(
                                        data['photoUrl'] ??
                                            data['userPhoto'] ??
                                            data['profileImage'] ??
                                            data['profileImageUrl'],
                                      ),
                                    );
                                    final selected = selectedUsers.containsKey(doc.id);

                                    return Column(
                                      children: [
                                        ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                          onTap: () => _toggleUser(doc),
                                          leading: CircleAvatar(
                                            radius: 24,
                                            backgroundColor: Colors.black,
                                            backgroundImage: user.photoUrl.isEmpty ? null : NetworkImage(user.photoUrl),
                                            child: user.photoUrl.isEmpty
                                                ? const Icon(Icons.person_rounded, color: Colors.white)
                                                : null,
                                          ),
                                          title: Text(
                                            '@${user.username}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textScaler: TextScaler.noScaling,
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                              fontWeight: FontWeight.w900,
                                              color: Colors.black,
                                            ),
                                          ),
                                          subtitle: user.displayName.isEmpty
                                              ? null
                                              : Text(
                                            user.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textScaler: TextScaler.noScaling,
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          trailing: AnimatedContainer(
                                            duration: const Duration(milliseconds: 160),
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: selected ? Colors.black : Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: selected ? Colors.black : Colors.black26,
                                                width: 1.3,
                                              ),
                                            ),
                                            child: Icon(
                                              selected ? Icons.check_rounded : Icons.add_rounded,
                                              color: selected ? Colors.white : Colors.black,
                                              size: 21,
                                            ),
                                          ),
                                        ),
                                        const Divider(height: 14, color: Colors.black12, indent: 16, endIndent: 16),
                                      ],
                                    );
                                  },
                                  childCount: docs.length,
                                ),
                              ),
                          const SliverToBoxAdapter(child: SizedBox(height: 10)),
                        ],
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: sending ? null : _sendSelected,
                        icon: sending
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          sending
                              ? 'Gönderiliyor...'
                              : selectedUsers.isEmpty
                              ? 'Kişi seç'
                              : '${selectedUsers.length} kişiye gönder',
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          disabledBackgroundColor: Colors.black45,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShareUser {
  final String uid;
  final String username;
  final String displayName;
  final String photoUrl;

  const _ShareUser({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.photoUrl,
  });
}

class _SelectedShareUserChip extends StatelessWidget {
  final _ShareUser user;
  final VoidCallback onRemove;

  const _SelectedShareUserChip({
    required this.user,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 178),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.black,
            backgroundImage: user.photoUrl.isEmpty ? null : NetworkImage(user.photoUrl),
            child: user.photoUrl.isEmpty
                ? const Icon(Icons.person_rounded, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '@${user.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, color: Colors.black54, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SharePostPreview extends StatelessWidget {
  final HomePost post;

  const _SharePostPreview({required this.post});

  @override
  Widget build(BuildContext context) {
    final image = post.images.isEmpty ? '' : post.images.first;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: 62,
              height: 62,
              color: const Color(0xFFEFEFEF),
              child: image.isEmpty
                  ? const Icon(Icons.image_rounded, color: Colors.black26)
                  : OptimizedNovaImage(
                url: image,
                quality: 0.75,
                errorIcon: Icons.image_rounded,
                iconSize: 28,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${post.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  post.desc.isEmpty ? post.car : post.desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.25,
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

class StoriesRow extends StatelessWidget {
  final List<HomeStory> stories;
  final AnimationController controller;
  final String currentUid;
  final void Function(int index) onStoryTap;
  final VoidCallback onTowTap;

  const StoriesRow({
    super.key,
    required this.stories,
    required this.controller,
    required this.currentUid,
    required this.onStoryTap,
    required this.onTowTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: stories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 1) {
            return TowStoryShortcut(onTap: onTowTap);
          }

          final int storyIndex = index == 0 ? 0 : index - 1;
          final story = stories[storyIndex];
          final viewed = story.viewedByUser(currentUid);
          final isMe = story.isMe;
          final hasNew = story.isActive() && story.hasNewStory && (isMe || !viewed);

          return GestureDetector(
            onTap: () => onStoryTap(storyIndex),
            child: SizedBox(
              width: 76,
              height: 106,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (hasNew)
                        AnimatedBuilder(
                          animation: controller,
                          builder: (context, _) {
                            return Container(
                              width: 74,
                              height: 74,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  transform: GradientRotation(controller.value * math.pi * 2),
                                  colors: const [
                                    Color(0xFF00D9FF),
                                    Color(0xFFFF00B8),
                                    Color(0xFFFFFF00),
                                    Color(0xFF00D9FF),
                                  ],
                                ),
                              ),
                              child: StoryAvatar(image: story.profileImage),
                            );
                          },
                        )
                      else
                        Container(
                          width: 74,
                          height: 74,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: viewed ? Colors.black12 : Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: StoryAvatar(image: story.profileImage),
                        ),
                      if (isMe)
                        Positioned(
                          right: -2,
                          bottom: 2,
                          child: Container(
                            width: 25,
                            height: 25,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: Icon(
                              story.hasNewStory ? Icons.visibility_rounded : Icons.add_rounded,
                              color: Colors.white,
                              size: story.hasNewStory ? 14 : 17,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  SizedBox(
                    width: 74,
                    height: 12,
                    child: Text(
                      story.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 9,
                        height: 1.0,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
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


class TowStoryShortcut extends StatelessWidget {
  final VoidCallback onTap;

  const TowStoryShortcut({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        height: 106,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFF00D9FF),
                    Color(0xFFFF00B8),
                    Color(0xFFFFFF00),
                    Color(0xFF00D9FF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFF00B8).withOpacity(0.28),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 31,
                ),
              ),
            ),
            const SizedBox(height: 7),
            const SizedBox(
              width: 74,
              height: 12,
              child: Text(
                'Acil Çekici',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 9,
                  height: 1.0,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoryAvatar extends StatelessWidget {
  final String image;

  const StoryAvatar({
    super.key,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = image.trim().isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(3),
      child: CircleAvatar(
        backgroundColor: Colors.black12,
        backgroundImage: hasImage ? NetworkImage(image) : null,
        child: hasImage ? null : const Icon(Icons.person_rounded, color: Colors.black54),
      ),
    );
  }
}

class NovaActionCount extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  const NovaActionCount({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 5),
          Text(
            text,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class NovaViewCounter extends StatelessWidget {
  final String text;

  const NovaViewCounter({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.visibility_outlined, color: Colors.black87, size: 24),
        const SizedBox(width: 4),
        Text(
          text,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 12.3,
          ),
        ),
      ],
    );
  }
}

class NovaPostMetric extends StatelessWidget {
  final String text;

  const NovaPostMetric({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textScaler: TextScaler.noScaling,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w900,
        color: Colors.black,
        fontSize: 12.5,
      ),
    );
  }
}

class NovaPostCard extends StatefulWidget {
  final HomePost post;
  final String currentUid;
  final String likeText;
  final Future<void> Function(bool shouldLike) onLike;
  final Future<void> Function() onView;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onProfileTap;
  final VoidCallback onOwnerMenu;
  final VoidCallback onReport;

  const NovaPostCard({
    super.key,
    required this.post,
    required this.currentUid,
    required this.likeText,
    required this.onLike,
    required this.onView,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    required this.onProfileTap,
    required this.onOwnerMenu,
    required this.onReport,
  });

  @override
  State<NovaPostCard> createState() => _NovaPostCardState();
}

class _NovaPostCardState extends State<NovaPostCard>
    with AutomaticKeepAliveClientMixin {
  int imageIndex = 0;
  bool? localSaved;
  bool? localLiked;
  int? localLikeCount;
  int? localViewCount;
  bool likeBusy = false;
  bool viewRegistered = false;
  bool showDoubleTapHeart = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    localLiked = widget.post.isLiked(widget.currentUid);
    localLikeCount = widget.post.likes;
    localViewCount = widget.post.viewCount;
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerViewOnce());
  }

  @override
  void didUpdateWidget(covariant NovaPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.likes != widget.post.likes ||
        oldWidget.post.likedBy.length != widget.post.likedBy.length) {
      localLiked = widget.post.isLiked(widget.currentUid);
      localLikeCount = widget.post.likes;
      localViewCount = widget.post.viewCount;
      viewRegistered = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _registerViewOnce());
      likeBusy = false;
    }
  }

  Future<void> _registerViewOnce() async {
    if (!mounted || viewRegistered || widget.currentUid.isEmpty) return;
    viewRegistered = true;

    final alreadyViewed = widget.post.viewedBy.contains(widget.currentUid);
    if (!alreadyViewed) {
      setState(() => localViewCount = math.max(0, (localViewCount ?? widget.post.viewCount) + 1));
    }

    try {
      await widget.onView();
    } catch (_) {
      // Görüntülenme sayacı uygulamayı düşürmesin.
    }
  }

  String _likeTextFromCount(int likes) {
    if (likes >= 1000000) return '${(likes / 1000000).toStringAsFixed(1)}M';
    if (likes >= 1000) return '${(likes / 1000).toStringAsFixed(1)}B';
    return likes.toString();
  }

  Future<void> _toggleLikeLocal({bool showHeart = false}) async {
    if (widget.currentUid.isEmpty || likeBusy) return;

    final wasLiked = localLiked ?? widget.post.isLiked(widget.currentUid);
    final oldCount = math.max(0, localLikeCount ?? widget.post.likes);
    final nextLiked = !wasLiked;
    final nextCount = math.max(0, oldCount + (nextLiked ? 1 : -1));

    setState(() {
      likeBusy = true;
      localLiked = nextLiked;
      localLikeCount = nextCount;
      showDoubleTapHeart = showHeart && nextLiked;
    });

    try {
      await widget.onLike(nextLiked);
    } catch (_) {
      if (mounted) {
        setState(() {
          localLiked = wasLiked;
          localLikeCount = oldCount;
        });
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() {
        likeBusy = false;
        if (showDoubleTapHeart) showDoubleTapHeart = false;
      });
    }
  }


  String _liveUsername(Map<String, dynamic>? user) {
    return _safeString(
      user?['username'],
      fallback: _safeString(
        user?['displayName'],
        fallback: widget.post.username,
      ),
    );
  }

  String _liveDisplayName(Map<String, dynamic>? user) {
    return _safeString(
      user?['displayName'],
      fallback: _safeString(
        user?['username'],
        fallback: widget.post.displayName,
      ),
    );
  }

  String _livePhoto(Map<String, dynamic>? user) {
    return _safeString(
      user?['photoUrl'] ??
          user?['userPhoto'] ??
          user?['profileImage'] ??
          user?['profileImageUrl'],
      fallback: widget.post.profileImage,
    );
  }

  String _liveSubtitle(Map<String, dynamic>? user) {
    final city = _safeString(user?['city'] ?? user?['il'] ?? user?['province']);
    final district = _safeString(user?['district'] ?? user?['ilce'] ?? user?['ilçe'] ?? user?['county']);

    if (city.isNotEmpty && district.isNotEmpty) return '$city / $district';
    if (city.isNotEmpty) return city;
    if (district.isNotEmpty) return district;
    return 'Konum bilgisi yok';
  }

  String _postDateText(DateTime date) {
    if (date.millisecondsSinceEpoch <= 0) return 'Paylaşım zamanı bilinmiyor';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Şimdi paylaşıldı';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce paylaşıldı';
    if (diff.inHours < 24) return '${diff.inHours} sa önce paylaşıldı';

    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)} tarihinde paylaşıldı';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.post.ownerId)
          .snapshots(),
      builder: (context, userSnap) {
        final Map<String, dynamic>? liveUser = userSnap.data?.data();

        final String liveUsername = _liveUsername(liveUser);
        final String liveDisplayName = _liveDisplayName(liveUser);
        final String livePhoto = _livePhoto(liveUser);
        final String liveSubtitle = _liveSubtitle(liveUser);

        final List<String> images = widget.post.images;
        final bool liked = localLiked ?? widget.post.isLiked(widget.currentUid);
        final int visibleLikeCount = math.max(0, localLikeCount ?? widget.post.likes);
        final int visibleViewCount = math.max(0, localViewCount ?? widget.post.viewCount);
        final bool saved = localSaved ?? widget.post.isSaved(widget.currentUid);

        return Container(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onProfileTap,
                      child: NovaProfileAvatar(
                        imageUrl: livePhoto,
                        radius: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onProfileTap,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              liveUsername,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w900,
                                fontSize: 13.2,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              liveSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 11.2,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (userSnap.connectionState == ConnectionState.waiting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.7,
                          color: Colors.black26,
                        ),
                      ),
                    if (widget.post.ownerId == widget.currentUid)
                      IconButton(
                        tooltip: 'Gönderi işlemleri',
                        onPressed: widget.onOwnerMenu,
                        icon: const Icon(Icons.more_horiz_rounded, color: Colors.black, size: 28),
                      )
                    else
                      IconButton(
                        tooltip: 'Şikayet et',
                        onPressed: widget.onReport,
                        icon: const Icon(Icons.privacy_tip_outlined, color: Colors.black87, size: 26),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onDoubleTap: () => _toggleLikeLocal(showHeart: true),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (images.isEmpty)
                        Container(
                          color: const Color(0xFFF2F2F2),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_rounded,
                            color: Colors.black26,
                            size: 48,
                          ),
                        )
                      else
                        PageView.builder(
                          itemCount: images.length,
                          physics: const ClampingScrollPhysics(),
                          onPageChanged: (i) {
                            if (mounted) {
                              setState(() => imageIndex = i);
                            }
                          },
                          itemBuilder: (context, i) {
                            return OptimizedNovaImage(
                              url: images[i],
                              quality: 0.82,
                              errorIcon: Icons.broken_image_rounded,
                              iconSize: 46,
                            );
                          },
                        ),
                      IgnorePointer(
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 170),
                          scale: showDoubleTapHeart ? 1 : 0.72,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 210),
                            opacity: showDoubleTapHeart ? 1 : 0,
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 86,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (images.length > 1)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.58),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${imageIndex + 1}/${images.length}',
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (images.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(images.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: imageIndex == i ? 7 : 5,
                        height: imageIndex == i ? 7 : 5,
                        decoration: BoxDecoration(
                          color:
                          imageIndex == i ? Colors.black : Colors.black26,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                child: Row(
                  children: [
                    NovaActionCount(
                      icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      text: _likeTextFromCount(visibleLikeCount),
                      color: liked ? Colors.red : Colors.black,
                      onTap: () => _toggleLikeLocal(),
                    ),
                    const SizedBox(width: 12),
                    NovaActionCount(
                      icon: Icons.chat_bubble_outline_rounded,
                      text: _compactCount(widget.post.commentCount),
                      onTap: widget.onComment,
                    ),
                    const SizedBox(width: 12),
                    NovaActionCount(
                      icon: Icons.send_rounded,
                      text: _compactCount(widget.post.shareCount),
                      onTap: widget.onShare,
                    ),
                    const Spacer(),
                    NovaViewCounter(text: _compactCount(visibleViewCount)),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: saved ? 'Kaydetmeden çıkar' : 'Kaydet',
                      onPressed: () {
                        setState(() => localSaved = !saved);
                        widget.onSave();
                      },
                      icon: Icon(
                        saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: Text(
                  _postDateText(widget.post.createdAt),
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black45,
                    fontSize: 10.7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.post.desc.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                  child: GestureDetector(
                    onTap: widget.onProfileTap,
                    child: RichText(
                      textScaler: TextScaler.noScaling,
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black,
                          fontSize: 12.6,
                          height: 1.32,
                        ),
                        children: [
                          TextSpan(
                            text: '$liveUsername ',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          TextSpan(text: widget.post.desc),
                        ],
                      ),
                    ),
                  ),
                ),
              TopLikedCommentPreview(
                postId: widget.post.id,
                onTap: widget.onComment,
              ),
              GestureDetector(
                onTap: widget.onComment,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Text(
                    widget.post.commentCount == 0
                        ? 'Yorum ekle'
                        : '${widget.post.commentCount} yorumu gör',
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black45,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Divider(height: 1, color: Color(0xFFE4E4E4)),
              ),
            ],
          ),
        );
      },
    );
  }
}



class TopLikedCommentPreview extends StatelessWidget {
  final String postId;
  final VoidCallback onTap;

  const TopLikedCommentPreview({
    super.key,
    required this.postId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('likeCount', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final data = snap.data!.docs.first.data();
        final text = _safeString(data['text']);
        if (text.isEmpty) return const SizedBox.shrink();

        final username = _safeString(data['username'], fallback: 'nova.user');
        final likeCount = _safeInt(data['likeCount'] ?? data['likesCount']);

        return GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEAEAEA)),
              ),
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black87,
                    fontSize: 12.5,
                    height: 1.25,
                  ),
                  children: [
                    const TextSpan(
                      text: 'En çok beğenilen yorum  ',
                      style: TextStyle(
                        color: Colors.black45,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: '$username ',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    TextSpan(text: text),
                    if (likeCount > 0)
                      TextSpan(
                        text: '  ${_compactCount(likeCount)} beğeni',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class NovaReportPostSheet extends StatefulWidget {
  final HomePost post;
  final String currentUid;
  final FirebaseFirestore db;

  const NovaReportPostSheet({
    super.key,
    required this.post,
    required this.currentUid,
    required this.db,
  });

  @override
  State<NovaReportPostSheet> createState() => _NovaReportPostSheetState();
}

class _NovaReportPostSheetState extends State<NovaReportPostSheet> {
  final TextEditingController reasonController = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  Future<void> sendReport() async {
    final reason = reasonController.text.trim();
    if (sending || reason.isEmpty || widget.currentUid.isEmpty) return;

    setState(() => sending = true);
    try {
      await widget.db.collection('postReports').add({
        'postId': widget.post.id,
        'postOwnerId': widget.post.ownerId,
        'reporterId': widget.currentUid,
        'reason': reason,
        'status': 'pending',
        'source': 'home_page',
        'postUsername': widget.post.username,
        'postCaption': widget.post.desc,
        'postImage': widget.post.images.isEmpty ? '' : widget.post.images.first,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şikayet kaydedildi.')),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.privacy_tip_outlined, color: Colors.black),
                  SizedBox(width: 8),
                  Text('Gönderiyi şikayet et', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Şikayet sebebini yaz. Bu kayıt panel hazır olunca yönetim tarafında görünecek.',
                textScaler: TextScaler.noScaling,
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'Roboto'),
                decoration: InputDecoration(
                  hintText: 'Şikayet sebebi...',
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: sending ? null : sendReport,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Şikayeti gönder', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FullScreenStoryPage extends StatefulWidget {
  final List<HomeStory> stories;
  final int initialIndex;
  final String currentUid;
  final void Function(String userId) onProfileTap;

  const FullScreenStoryPage({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.currentUid,
    required this.onProfileTap,
  });

  @override
  State<FullScreenStoryPage> createState() => _FullScreenStoryPageState();
}

class _FullScreenStoryPageState extends State<FullScreenStoryPage> with SingleTickerProviderStateMixin {
  late int currentIndex;
  late AnimationController progressController;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController messageController = TextEditingController();

  bool liked = false;

  @override
  void initState() {
    super.initState();

    currentIndex = widget.initialIndex.clamp(0, math.max(0, widget.stories.length - 1)).toInt();

    progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) nextStory();
    });

    _markViewed();
    progressController.forward();
  }

  @override
  void dispose() {
    progressController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void _markViewed() {
    if (widget.stories.isEmpty) return;

    final story = widget.stories[currentIndex];
    _db.collection('stories').doc(story.id).set({
      'viewedBy': FieldValue.arrayUnion([widget.currentUid]),
    }, SetOptions(merge: true));
  }

  void restartProgress() {
    liked = false;
    _markViewed();
    progressController
      ..reset()
      ..forward();
  }

  void nextStory() {
    if (currentIndex < widget.stories.length - 1) {
      setState(() => currentIndex++);
      restartProgress();
    } else {
      Navigator.pop(context);
    }
  }

  void previousStory() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
      restartProgress();
    } else {
      restartProgress();
    }
  }

  Future<Map<String, String>> _storyActorPayload() async {
    final authUser = FirebaseAuth.instance.currentUser;
    final snap = await _db.collection('users').doc(widget.currentUid).get();
    final data = snap.data() ?? <String, dynamic>{};

    final username = _safeString(
      data['username'],
      fallback: _safeString(authUser?.displayName, fallback: 'nova.user'),
    );
    final displayName = _safeString(
      data['displayName'],
      fallback: _safeString(authUser?.displayName, fallback: username),
    );
    final photo = _safeString(
      data['photoUrl'] ?? data['userPhoto'] ?? data['profileImage'] ?? data['profileImageUrl'] ?? data['avatarUrl'],
      fallback: _safeString(authUser?.photoURL),
    );

    return {
      'actorUsername': username,
      'actorDisplayName': displayName,
      'actorPhotoUrl': photo,
    };
  }

  Future<void> _sendStoryLikeNotification(HomeStory story) async {
    if (widget.currentUid.isEmpty || story.ownerId == widget.currentUid || story.ownerId.isEmpty) return;

    final actor = await _storyActorPayload();
    final now = FieldValue.serverTimestamp();
    final notificationRef = _db.collection('notifications').doc();
    final userNotificationRef = _db
        .collection('users')
        .doc(story.ownerId)
        .collection('notifications')
        .doc(notificationRef.id);

    final payload = <String, dynamic>{
      'id': notificationRef.id,
      'receiverId': story.ownerId,
      'toUserId': story.ownerId,
      'senderId': widget.currentUid,
      'fromUserId': widget.currentUid,
      'actorId': widget.currentUid,
      'type': 'story_like',
      'title': 'Hikaye beğenildi',
      'body': '${actor['actorUsername']} hikayeni beğendi.',
      'message': '${actor['actorUsername']} hikayeni beğendi.',
      'storyId': story.id,
      'read': false,
      'seen': false,
      'createdAt': now,
      ...actor,
    };

    final batch = _db.batch();
    batch.set(notificationRef, payload, SetOptions(merge: true));
    batch.set(userNotificationRef, payload, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> sendStoryMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || widget.stories.isEmpty) return;

    final story = widget.stories[currentIndex];

    await _db.collection('storyMessages').add({
      'storyId': story.id,
      'storyOwnerId': story.ownerId,
      'senderId': widget.currentUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'seen': false,
    });

    messageController.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> toggleStoryLike() async {
    if (widget.stories.isEmpty) return;

    final story = widget.stories[currentIndex];

    setState(() => liked = !liked);

    await _db.collection('stories').doc(story.id).set({
      'likedBy': liked
          ? FieldValue.arrayUnion([widget.currentUid])
          : FieldValue.arrayRemove([widget.currentUid]),
      'likeCount': FieldValue.increment(liked ? 1 : -1),
      'likesCount': FieldValue.increment(liked ? 1 : -1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (liked) {
      await _sendStoryLikeNotification(story);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Aktif story yok', style: TextStyle(color: Colors.white))),
      );
    }

    final story = widget.stories[currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 250) Navigator.pop(context);
        },
        onLongPressStart: (_) => progressController.stop(),
        onLongPressEnd: (_) => progressController.forward(),
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -250) nextStory();
          if ((details.primaryVelocity ?? 0) > 250) previousStory();
        },
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          final dx = details.globalPosition.dx;
          if (dx < width * 0.35) previousStory();
          if (dx > width * 0.65) nextStory();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            OptimizedNovaImage(
              url: story.image,
              quality: 0.85,
              backgroundColor: Colors.black,
              errorIcon: Icons.broken_image_rounded,
              iconColor: Colors.white38,
              iconSize: 54,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.65),
                    Colors.transparent,
                    Colors.black.withOpacity(0.76),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: List.generate(widget.stories.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: AnimatedBuilder(
                              animation: progressController,
                              builder: (context, _) {
                                double value;
                                if (i < currentIndex) {
                                  value = 1;
                                } else if (i == currentIndex) {
                                  value = progressController.value;
                                } else {
                                  value = 0;
                                }

                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    minHeight: 3,
                                    backgroundColor: Colors.white.withOpacity(0.28),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            progressController.stop();
                            widget.onProfileTap(story.ownerId);
                          },
                          child: CircleAvatar(
                            radius: 21,
                            backgroundImage: story.profileImage.isEmpty ? null : NetworkImage(story.profileImage),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            progressController.stop();
                            widget.onProfileTap(story.ownerId);
                          },
                          child: Text(
                            story.username,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _storyDateText(story.createdAt),
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            style: const TextStyle(color: Colors.white, fontFamily: 'Roboto'),
                            decoration: InputDecoration(
                              hintText: 'Mesaj gönder...',
                              hintStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.35),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(99),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.45)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(99),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.45)),
                              ),
                            ),
                            onTap: () => progressController.stop(),
                          ),
                        ),
                        IconButton(
                          onPressed: toggleStoryLike,
                          icon: Icon(
                            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: liked ? Colors.red : Colors.white,
                            size: 31,
                          ),
                        ),
                        IconButton(
                          onPressed: sendStoryMessage,
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 29),
                        ),
                      ],
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

class MyStoryViewerPage extends StatefulWidget {
  final List<HomeStory> stories;
  final String currentUid;
  final VoidCallback onAddStory;

  const MyStoryViewerPage({
    super.key,
    required this.stories,
    required this.currentUid,
    required this.onAddStory,
  });

  @override
  State<MyStoryViewerPage> createState() => _MyStoryViewerPageState();
}

class _MyStoryViewerPageState extends State<MyStoryViewerPage> with SingleTickerProviderStateMixin {
  late int currentIndex;
  late AnimationController progressController;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    currentIndex = 0;
    progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) nextStory();
    });
    progressController.forward();
  }

  @override
  void dispose() {
    progressController.dispose();
    super.dispose();
  }

  void restartProgress() {
    progressController
      ..reset()
      ..forward();
  }

  void nextStory() {
    if (currentIndex < widget.stories.length - 1) {
      setState(() => currentIndex++);
      restartProgress();
    } else {
      Navigator.pop(context);
    }
  }

  void previousStory() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
      restartProgress();
    } else {
      restartProgress();
    }
  }

  void openViewersSheet(HomeStory story) {
    progressController.stop();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return StoryViewersSheet(
          storyId: story.id,
          fallbackViewedBy: story.viewedBy,
        );
      },
    ).whenComplete(() {
      if (mounted) progressController.forward();
    });
  }

  Future<void> deleteStory(HomeStory story) async {
    progressController.stop();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Hikaye silinsin mi?',
            textScaler: TextScaler.noScaling,
            style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Bu hikaye profilden ve ana sayfadan kaldırılacak.',
            textScaler: TextScaler.noScaling,
            style: TextStyle(fontFamily: 'Roboto'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (ok != true) {
      if (mounted) progressController.forward();
      return;
    }

    await _db.collection('stories').doc(story.id).set({
      'active': false,
      'expiresAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(seconds: 1))),
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    final next = [...widget.stories]..removeWhere((s) => s.id == story.id);
    if (next.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      widget.stories
        ..clear()
        ..addAll(next);
      currentIndex = currentIndex.clamp(0, widget.stories.length - 1).toInt();
    });
    restartProgress();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Aktif hikayen yok', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final story = widget.stories[currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 250) Navigator.pop(context);
        },
        onLongPressStart: (_) => progressController.stop(),
        onLongPressEnd: (_) => progressController.forward(),
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -250) nextStory();
          if ((details.primaryVelocity ?? 0) > 250) previousStory();
        },
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          final dx = details.globalPosition.dx;
          final dy = details.globalPosition.dy;
          final height = MediaQuery.of(context).size.height;

          if (dy > height - 145) return;
          if (dx < width * 0.35) previousStory();
          if (dx > width * 0.65) nextStory();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            OptimizedNovaImage(
              url: story.image,
              quality: 0.85,
              backgroundColor: Colors.black,
              errorIcon: Icons.broken_image_rounded,
              iconColor: Colors.white38,
              iconSize: 54,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.65),
                    Colors.transparent,
                    Colors.black.withOpacity(0.82),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: List.generate(widget.stories.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: AnimatedBuilder(
                              animation: progressController,
                              builder: (context, _) {
                                double value;
                                if (i < currentIndex) {
                                  value = 1;
                                } else if (i == currentIndex) {
                                  value = progressController.value;
                                } else {
                                  value = 0;
                                }

                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    minHeight: 3,
                                    backgroundColor: Colors.white.withOpacity(0.28),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 21,
                          backgroundColor: Colors.white,
                          backgroundImage: story.profileImage.isEmpty ? null : NetworkImage(story.profileImage),
                          child: story.profileImage.isEmpty
                              ? const Icon(Icons.person_rounded, color: Colors.black)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Hikayen',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _storyDateText(story.createdAt),
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => deleteStory(story),
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => openViewersSheet(story),
                            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _db.collection('stories').doc(story.id).snapshots(),
                              builder: (context, snap) {
                                final data = snap.data?.data();
                                final viewedBy = _stringList(data?['viewedBy']);
                                final count = viewedBy.length;

                                return Container(
                                  height: 54,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.46),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.visibility_rounded, color: Colors.white, size: 24),
                                      const SizedBox(width: 10),
                                      Text(
                                        count == 0 ? 'Henüz gören yok' : '$count görüntüleme',
                                        textScaler: TextScaler.noScaling,
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 28),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            widget.onAddStory();
                          },
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.black, size: 30),
                          ),
                        ),
                      ],
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

class StoryViewersSheet extends StatelessWidget {
  final String storyId;
  final List<String> fallbackViewedBy;

  const StoryViewersSheet({
    super.key,
    required this.storyId,
    required this.fallbackViewedBy,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.68,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.visibility_rounded, color: Colors.black),
                SizedBox(width: 8),
                Text(
                  'Hikayeyi görenler',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: db.collection('stories').doc(storyId).snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final viewedBy = _stringList(data?['viewedBy']).isNotEmpty
                      ? _stringList(data?['viewedBy'])
                      : fallbackViewedBy;

                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.black));
                  }

                  if (viewedBy.isEmpty) {
                    return const Center(
                      child: Text(
                        'Henüz kimse görmedi.',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: viewedBy.length,
                    separatorBuilder: (_, __) => const Divider(height: 18, color: Colors.black12),
                    itemBuilder: (context, index) {
                      final uid = viewedBy[index];

                      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: db.collection('users').doc(uid).get(),
                        builder: (context, userSnap) {
                          final user = userSnap.data?.data() ?? {};
                          final firstName = _safeString(user['firstName'] ?? user['name']);
                          final lastName = _safeString(user['lastName'] ?? user['surname']);
                          final fullName = _safeString(
                            user['fullName'] ?? user['displayName'],
                            fallback: ('$firstName $lastName').trim(),
                          );
                          final username = _safeString(fullName, fallback: _safeString(user['username'], fallback: 'Kullanıcı'));
                          final image = _safeString(user['photoUrl'] ?? user['userPhoto'] ?? user['profileImage']);
                          final city = _safeString(user['city']);
                          final district = _safeString(user['district']);
                          final location = city.isNotEmpty && district.isNotEmpty
                              ? '$city / $district'
                              : city.isNotEmpty
                              ? city
                              : district;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => public_profile.UserProfilePage(userId: uid)),
                              );
                            },
                            leading: CircleAvatar(
                              radius: 23,
                              backgroundColor: Colors.black,
                              backgroundImage: image.isEmpty ? null : NetworkImage(image),
                              child: image.isEmpty
                                  ? const Icon(Icons.person_rounded, color: Colors.white)
                                  : null,
                            ),
                            title: Text(
                              username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              location.isEmpty ? 'Profiline git' : location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
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
    );
  }
}

class UserProfilePage extends StatelessWidget {
  final String userId;

  const UserProfilePage({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        final user = snap.data?.data() ?? {};
        final username = _safeString(user['username'], fallback: 'nova.user');
        final image = _safeString(user['photoUrl'] ?? user['userPhoto'] ?? user['profileImage']);
        final car = _safeString(user['car'] ?? user['vehicle'], fallback: 'Araç profili');
        final postCount = _safeInt(user['postsCount'] ?? user['postCount']);
        final followerCount = _safeInt(user['followersCount'] ?? user['followerCount']);
        final followingCount = _safeInt(user['followingCount'] ?? user['followingCount']);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
            title: Text(
              username,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
            ),
          ),
          body: snap.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.black,
                    backgroundImage: image.isEmpty ? null : NetworkImage(image),
                    child: image.isEmpty ? const Icon(Icons.person_rounded, color: Colors.white, size: 42) : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ProfileStat(title: 'Gönderi', value: '$postCount'),
                        ProfileStat(title: 'Takipçi', value: '$followerCount'),
                        ProfileStat(title: 'Takip', value: '$followingCount'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                username,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                car,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _safeString(
                  user['bio'],
                  fallback: 'NOVA araç profili • inceleme, karşılaştırma ve otomobil deneyimleri.',
                ),
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Takip Et',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Mesaj',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Divider(color: Colors.black12),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db
                    .collection('posts')
                    .where('ownerId', isEqualTo: userId)
                    .orderBy('createdAt', descending: true)
                    .limit(30)
                    .snapshots(),
                builder: (context, postSnap) {
                  final docs = postSnap.data?.docs ?? [];

                  if (postSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.black));
                  }

                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Henüz gönderi yok.',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(fontFamily: 'Roboto', color: Colors.black45),
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    itemCount: docs.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemBuilder: (context, index) {
                      final post = HomePost.fromDoc(docs[index]);
                      final cover = post.images.isEmpty ? '' : post.images.first;

                      return cover.isEmpty
                          ? Container(color: const Color(0xFFF2F2F2))
                          : OptimizedNovaImage(url: cover, quality: 0.75);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProfileStat extends StatelessWidget {
  final String title;
  final String value;

  const ProfileStat({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class NoGlowScrollBehavior extends ScrollBehavior {
  const NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    return child;
  }
}
