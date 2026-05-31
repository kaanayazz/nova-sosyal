import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'car_ads_list_page.dart';
import 'messages_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final AnimationController _neonController;

  late Future<DocumentSnapshot<Map<String, dynamic>>> _profileFuture;
  late Future<QuerySnapshot<Map<String, dynamic>>> _postsFuture;
  late Future<QuerySnapshot<Map<String, dynamic>>> _adsFuture;
  late Future<_FollowState> _followFuture;

  _FollowState? _localFollowState;
  bool _followBusy = false;
  int _followersDelta = 0;

  int _tabIndex = 0;

  String get _currentUid => _auth.currentUser?.uid ?? '';
  bool get _isMe => _currentUid.isNotEmpty && _currentUid == widget.userId;

  @override
  void initState() {
    super.initState();
    _neonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _loadData();
    _recordProfileView();
  }

  @override
  void dispose() {
    _neonController.dispose();
    super.dispose();
  }

  void _loadData() {
    _profileFuture = _db.collection('users').doc(widget.userId).get();
    _postsFuture = _db
        .collection('posts')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .limit(120)
        .get();
    _adsFuture = _db
        .collection('carAds')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .limit(120)
        .get();
    _followFuture = _getFollowState();
  }

  Future<void> _refresh() async {
    setState(_loadData);
    await Future.wait<dynamic>([
      _profileFuture,
      _postsFuture,
      _adsFuture,
      _followFuture,
    ]);
  }

  Future<void> _recordProfileView() async {
    if (_currentUid.isEmpty || _isMe) return;
    final id = '${widget.userId}_$_currentUid';
    try {
      final viewerSnap = await _db.collection('users').doc(_currentUid).get();
      final viewer = viewerSnap.data() ?? <String, dynamic>{};
      final batch = _db.batch();
      batch.set(_db.collection('profileViews').doc(id), {
        'userId': widget.userId,
        'profileUserId': widget.userId,
        'viewerUserId': _currentUid,
        'viewerName': _safeString(viewer['displayName'] ?? viewer['fullName']),
        'viewerUsername': _safeString(viewer['username']),
        'viewerPhotoUrl': _safeString(viewer['photoUrl'] ?? viewer['profileImage']),
        'viewCount': FieldValue.increment(1),
        'lastViewedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(_db.collection('users').doc(widget.userId), {
        'profileViewsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
    } catch (_) {}
  }

  Future<_FollowState> _getFollowState() async {
    if (_currentUid.isEmpty || _isMe) return _FollowState.none;

    final targetRef = _db.collection('users').doc(widget.userId);
    final targetSnap = await targetRef.get();
    final target = targetSnap.data() ?? <String, dynamic>{};
    final followers = _stringList(target['followerIds'] ?? target['followers']);
    if (followers.contains(_currentUid)) return _FollowState.following;

    final requestDoc = await targetRef
        .collection('followRequests')
        .doc(_currentUid)
        .get();
    if (requestDoc.exists) return _FollowState.requested;

    return _FollowState.none;
  }

  Future<void> _followOrRequest(NovaPublicProfile profile) async {
    if (_currentUid.isEmpty || _isMe || _followBusy) return;

    setState(() => _followBusy = true);

    try {
      final myRef = _db.collection('users').doc(_currentUid);
      final targetRef = _db.collection('users').doc(widget.userId);
      final mySnap = await myRef.get();
      final my = mySnap.data() ?? <String, dynamic>{};

      final state = _localFollowState ?? await _getFollowState();
      _FollowState nextState = state;
      int followerChange = 0;
      String snackText = '';

      if (state == _FollowState.following) {
        final batch = _db.batch();
        batch.set(targetRef, {
          'followerIds': FieldValue.arrayRemove([_currentUid]),
          'followersCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batch.set(myRef, {
          'followingIds': FieldValue.arrayRemove([widget.userId]),
          'followingCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await batch.commit();
        nextState = _FollowState.none;
        followerChange = -1;
        snackText = 'Takipten çıkarıldı.';
      } else if (state == _FollowState.requested) {
        final batch = _db.batch();

        batch.delete(targetRef.collection('followRequests').doc(_currentUid));
        batch.delete(myRef.collection('sentFollowRequests').doc(widget.userId));

        await batch.commit();

        nextState = _FollowState.none;
        snackText = 'Takip isteği geri alındı.';
      } else if (profile.privateProfile) {
        final requestData = {
          'fromUserId': _currentUid,
          'toUserId': widget.userId,
          'username': _safeString(my['username']),
          'displayName': _safeString(my['displayName'] ?? my['fullName']),
          'photoUrl': _safeString(my['photoUrl'] ?? my['profileImage']),
          'targetUsername': profile.usernameText,
          'targetDisplayName': profile.displayName,
          'targetPhotoUrl': profile.photoUrl,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final batch = _db.batch();

        batch.set(
          targetRef.collection('followRequests').doc(_currentUid),
          requestData,
          SetOptions(merge: true),
        );

        // Gönderdiğin İstekler sekmesi kesin dolsun diye aynı isteğin
        // kullanıcı tarafındaki kopyasını da tutuyoruz.
        batch.set(
          myRef.collection('sentFollowRequests').doc(widget.userId),
          requestData,
          SetOptions(merge: true),
        );

        final notificationRef = targetRef.collection('notifications').doc();
        batch.set(notificationRef, {
          'id': notificationRef.id,
          'type': 'follow_request',
          'pushType': 'follow_request',
          'notificationKind': 'follow_request',
          'title': 'Yeni takip isteği',
          'body': '${_safeString(my['username'], fallback: 'Bir kullanıcı')} seni takip etmek istiyor.',
          'receiverId': widget.userId,
          'toUserId': widget.userId,
          'senderId': _currentUid,
          'fromUserId': _currentUid,
          'actorId': _currentUid,
          'fromUserName': _safeString(my['displayName'] ?? my['fullName'], fallback: _safeString(my['username'], fallback: 'Bir kullanıcı')),
          'actorUsername': _safeString(my['username'], fallback: 'Bir kullanıcı'),
          'senderName': _safeString(my['displayName'] ?? my['fullName'], fallback: _safeString(my['username'], fallback: 'Bir kullanıcı')),
          'fromUserPhotoUrl': _safeString(my['photoUrl'] ?? my['profileImage']),
          'senderPhotoUrl': _safeString(my['photoUrl'] ?? my['profileImage']),
          'actorPhotoUrl': _safeString(my['photoUrl'] ?? my['profileImage']),
          'photoUrl': _safeString(my['photoUrl'] ?? my['profileImage']),
          'read': false,
          'seen': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();

        nextState = _FollowState.requested;
        snackText = 'Takip isteği gönderildi.';
      } else {
        final batch = _db.batch();
        batch.set(targetRef, {
          'followerIds': FieldValue.arrayUnion([_currentUid]),
          'followersCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batch.set(myRef, {
          'followingIds': FieldValue.arrayUnion([widget.userId]),
          'followingCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await batch.commit();
        nextState = _FollowState.following;
        followerChange = 1;
        snackText = 'Takip edildi.';
      }

      if (!mounted) return;
      setState(() {
        _localFollowState = nextState;
        _followersDelta += followerChange;
        _followBusy = false;
      });
      _snack(snackText);
    } catch (_) {
      if (mounted) setState(() => _followBusy = false);
      _snack('İşlem tamamlanamadı. İnternet bağlantını kontrol et.');
    }
  }

  Future<void> _openChat() async {
    if (_currentUid.isEmpty || _isMe) return;
    final ids = [_currentUid, widget.userId]..sort();
    final chatId = '${ids[0]}_${ids[1]}';
    final chatRef = _db.collection('conversations').doc(chatId);
    final snap = await chatRef.get();
    if (!snap.exists) {
      await chatRef.set({
        'participants': [_currentUid, widget.userId],
        'participantMap': {
          _currentUid: true,
          widget.userId: true,
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
          _currentUid: 0,
          widget.userId: 0,
        },
        'typing': {
          _currentUid: false,
          widget.userId: false,
        },
      });
    } else {
      await chatRef.set({
        'hiddenFor': FieldValue.arrayRemove([_currentUid]),
        'deletedFor': FieldValue.arrayRemove([_currentUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(chatId: chatId, otherUid: widget.userId),
      ),
    );
  }

  Future<void> _openWebsite(String website) async {
    final value = website.trim();
    if (value.isEmpty) return;
    final fixed = value.startsWith('https://') ? value : 'https://$value';
    final uri = Uri.tryParse(fixed);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('Web sitesi açılamadı.');
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(' ', '').trim();
    if (clean.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: clean);
    final ok = await launchUrl(uri);
    if (!ok) _snack('Telefon açılamadı.');
  }

  void _openPhoto(String imageUrl) {
    if (imageUrl.trim().isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) => _ProfilePhotoDialog(imageUrl: imageUrl),
    );
  }

  void _openReport(NovaPublicProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportUserSheet(
        reportedUserId: widget.userId,
        reportedUsername: profile.usernameText,
        currentUid: _currentUid,
        db: _db,
      ),
    );
  }

  void _openPostDetail(String postId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.76,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _PublicPostPreview(postId: postId, data: data),
        ),
      ),
    );
  }

  void _openAdDetail(CarAd ad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.86,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: CarAdDetailPage(ad: ad),
        ),
      ),
    );
  }


  void _openProfileActions(NovaPublicProfile profile, _FollowState followState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ProfileActionsSheet(
          isMe: _isMe,
          isFollowing: followState == _FollowState.following,
          onReport: () {
            Navigator.pop(context);
            _openReport(profile);
          },
          onBlock: () async {
            Navigator.pop(context);
            await _blockUser(profile);
          },
          onUnfollow: () async {
            Navigator.pop(context);
            await _unfollowUser(profile);
          },
        );
      },
    );
  }

  Future<void> _unfollowUser(NovaPublicProfile profile) async {
    if (_currentUid.isEmpty || _isMe) return;
    try {
      final myRef = _db.collection('users').doc(_currentUid);
      final targetRef = _db.collection('users').doc(widget.userId);
      final batch = _db.batch();
      batch.set(targetRef, {
        'followerIds': FieldValue.arrayRemove([_currentUid]),
        'followers': FieldValue.arrayRemove([_currentUid]),
        'followersCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(myRef, {
        'followingIds': FieldValue.arrayRemove([widget.userId]),
        'following': FieldValue.arrayRemove([widget.userId]),
        'followingCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _localFollowState = _FollowState.none;
        _followersDelta -= 1;
      });
      _snack('Takipten çıkarıldı.');
    } catch (_) {
      _snack('Takipten çıkarılamadı. İnternet bağlantını kontrol et.');
    }
  }

  Future<void> _blockUser(NovaPublicProfile profile) async {
    if (_currentUid.isEmpty || _isMe) return;
    try {
      final myRef = _db.collection('users').doc(_currentUid);
      final targetRef = _db.collection('users').doc(widget.userId);
      await _db.runTransaction((transaction) async {
        final mySnap = await transaction.get(myRef);
        final targetSnap = await transaction.get(targetRef);
        final my = mySnap.data() ?? <String, dynamic>{};
        final target = targetSnap.data() ?? <String, dynamic>{};
        final myFollowing = _stringList(my['followingIds'] ?? my['following']);
        final myFollowers = _stringList(my['followerIds'] ?? my['followers']);
        final targetFollowers = _stringList(target['followerIds'] ?? target['followers']);
        final targetFollowing = _stringList(target['followingIds'] ?? target['following']);

        transaction.set(myRef, {
          'blockedUserIds': FieldValue.arrayUnion([widget.userId]),
          'followingIds': FieldValue.arrayRemove([widget.userId]),
          'following': FieldValue.arrayRemove([widget.userId]),
          'followerIds': FieldValue.arrayRemove([widget.userId]),
          'followers': FieldValue.arrayRemove([widget.userId]),
          if (myFollowing.contains(widget.userId)) 'followingCount': FieldValue.increment(-1),
          if (myFollowers.contains(widget.userId)) 'followersCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(targetRef, {
          'followerIds': FieldValue.arrayRemove([_currentUid]),
          'followers': FieldValue.arrayRemove([_currentUid]),
          'followingIds': FieldValue.arrayRemove([_currentUid]),
          'following': FieldValue.arrayRemove([_currentUid]),
          if (targetFollowers.contains(_currentUid)) 'followersCount': FieldValue.increment(-1),
          if (targetFollowing.contains(_currentUid)) 'followingCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
      await _db.collection('users').doc(_currentUid).collection('blockedUsers').doc(widget.userId).set({
        'userId': widget.userId,
        'username': profile.usernameText,
        'displayName': profile.displayName,
        'photoUrl': profile.photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _db.collection('users').doc(widget.userId).collection('followRequests').doc(_currentUid).delete().catchError((_) {});
      await _db.collection('users').doc(_currentUid).collection('sentFollowRequests').doc(widget.userId).delete().catchError((_) {});
      if (!mounted) return;
      setState(() {
        _localFollowState = _FollowState.none;
      });
      _snack('Kullanıcı engellendi.');
    } catch (_) {
      _snack('Kullanıcı engellenemedi. İnternet bağlantını kontrol et.');
    }
  }

  Future<void> _approveFollowRequest(String requestUserId, Map<String, dynamic> requestData) async {
    if (_currentUid.isEmpty || requestUserId.trim().isEmpty) return;
    try {
      final myRef = _db.collection('users').doc(_currentUid);
      final requesterRef = _db.collection('users').doc(requestUserId);
      final requestRef = myRef.collection('followRequests').doc(requestUserId);
      final batch = _db.batch();
      batch.set(myRef, {
        'followerIds': FieldValue.arrayUnion([requestUserId]),
        'followers': FieldValue.arrayUnion([requestUserId]),
        'followersCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(requesterRef, {
        'followingIds': FieldValue.arrayUnion([_currentUid]),
        'following': FieldValue.arrayUnion([_currentUid]),
        'followingCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.delete(requestRef);
      batch.delete(requesterRef.collection('sentFollowRequests').doc(_currentUid));
      batch.set(requesterRef.collection('notifications').doc(), {
        'type': 'follow_request_approved',
        'title': 'Takip isteğin onaylandı',
        'body': 'Takip isteğin onaylandı.',
        'fromUserId': _currentUid,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (!mounted) return;
      setState(() => _followersDelta += 1);
      _snack('Takip isteği onaylandı.');
    } catch (_) {
      _snack('Takip isteği onaylanamadı.');
    }
  }

  Future<void> _deleteFollowRequest(String requestUserId) async {
    if (_currentUid.isEmpty || requestUserId.trim().isEmpty) return;
    try {
      final batch = _db.batch();
      final myRef = _db.collection('users').doc(_currentUid);
      final requesterRef = _db.collection('users').doc(requestUserId);

      batch.delete(myRef.collection('followRequests').doc(requestUserId));
      batch.delete(requesterRef.collection('sentFollowRequests').doc(_currentUid));

      await batch.commit();
      _snack('Takip isteği silindi.');
    } catch (_) {
      _snack('Takip isteği silinemedi.');
    }
  }

  Future<void> _blockFollowerFromRequest(String requestUserId, Map<String, dynamic> data) async {
    if (_currentUid.isEmpty || requestUserId.trim().isEmpty) return;
    try {
      final myRef = _db.collection('users').doc(_currentUid);
      final otherRef = _db.collection('users').doc(requestUserId);
      final batch = _db.batch();
      batch.set(myRef, {
        'blockedUserIds': FieldValue.arrayUnion([requestUserId]),
        'followerIds': FieldValue.arrayRemove([requestUserId]),
        'followers': FieldValue.arrayRemove([requestUserId]),
        'followingIds': FieldValue.arrayRemove([requestUserId]),
        'following': FieldValue.arrayRemove([requestUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(otherRef, {
        'followingIds': FieldValue.arrayRemove([_currentUid]),
        'following': FieldValue.arrayRemove([_currentUid]),
        'followerIds': FieldValue.arrayRemove([_currentUid]),
        'followers': FieldValue.arrayRemove([_currentUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.delete(myRef.collection('followRequests').doc(requestUserId));
      await batch.commit();
      _snack('Kullanıcı engellendi.');
    } catch (_) {
      _snack('Kullanıcı engellenemedi.');
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.trim().isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Kullanıcı bulunamadı.')),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _profileFuture,
      builder: (context, profileSnap) {
        if (profileSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: UserProfileSkeleton(),
          );
        }

        if (profileSnap.hasError || !profileSnap.hasData || !profileSnap.data!.exists) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
            body: const Center(child: Text('Profil yüklenemedi veya kullanıcı bulunamadı.')),
          );
        }

        final profile = NovaPublicProfile.fromMap(
          profileSnap.data!.data() ?? <String, dynamic>{},
          fallbackUid: widget.userId,
        );

        return FutureBuilder<_FollowState>(
          future: _followFuture,
          builder: (context, followSnap) {
            final followState = _localFollowState ?? followSnap.data ?? _FollowState.none;
            final canSeePrivateContent =
                !profile.privateProfile || followState == _FollowState.following || _isMe;

            return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: _postsFuture,
              builder: (context, postsSnap) {
                final posts = (postsSnap.data?.docs ?? [])
                    .where((doc) => doc.data()['deleted'] != true && doc.data()['isArchived'] != true)
                    .toList();

                return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  future: _adsFuture,
                  builder: (context, adsSnap) {
                    final ads = (adsSnap.data?.docs ?? [])
                        .where((doc) => doc.data()['deleted'] != true && (doc.data()['status'] ?? 'active') == 'active')
                        .toList();
                    final loadingContent = postsSnap.connectionState == ConnectionState.waiting ||
                        adsSnap.connectionState == ConnectionState.waiting ||
                        followSnap.connectionState == ConnectionState.waiting;

                    return Scaffold(
                      backgroundColor: Colors.white,
                      body: SafeArea(
                        bottom: false,
                        child: RefreshIndicator(
                          color: Colors.black,
                          onRefresh: _refresh,
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    _UserTopBar(
                                      username: profile.usernameText,
                                      privateProfile: profile.privateProfile,
                                      onBack: () => Navigator.pop(context),
                                      onMore: () => _openProfileActions(profile, followState),
                                    ),
                                    if (_isMe)
                                      _FollowRequestsBox(
                                        db: _db,
                                        currentUid: _currentUid,
                                        onApprove: _approveFollowRequest,
                                        onDelete: _deleteFollowRequest,
                                        onBlock: _blockFollowerFromRequest,
                                        onOpenProfile: (userId) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => UserProfilePage(userId: userId),
                                            ),
                                          );
                                        },
                                      ),
                                    if (!_isMe && _currentUid.isNotEmpty)
                                      _ViewingUserFollowRequestBox(
                                        db: _db,
                                        currentUid: _currentUid,
                                        requestUserId: widget.userId,
                                        onApprove: _approveFollowRequest,
                                        onDelete: _deleteFollowRequest,
                                        onBlock: _blockFollowerFromRequest,
                                      ),
                                    _UserProfileHeader(
                                      profile: profile,
                                      postCount: posts.length,
                                      followersDelta: _followersDelta,
                                      followState: followState,
                                      followBusy: _followBusy,
                                      neonController: _neonController,
                                      canAct: !_isMe && _currentUid.isNotEmpty,
                                      onPhotoTap: () => _openPhoto(profile.photoUrl),
                                      onFollow: () => _followOrRequest(profile),
                                      onMessage: _openChat,
                                      onWebsite: () => _openWebsite(profile.website),
                                      onPhone: () => _callPhone(profile.phone),
                                    ),
                                    if (canSeePrivateContent && profile.expenseCard.visible)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                                        child: _ExpenseProfileCard(
                                          card: profile.expenseCard,
                                          controller: _neonController,
                                        ),
                                      ),
                                    if (canSeePrivateContent)
                                      _UserTabs(
                                        selectedIndex: _tabIndex,
                                        onChanged: (index) {
                                          if (_tabIndex == index) return;
                                          setState(() => _tabIndex = index);
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              if (!canSeePrivateContent)
                                const SliverToBoxAdapter(child: _PrivateAccountBox())
                              else if (loadingContent)
                                const SliverToBoxAdapter(child: UserProfileMiniLoading())
                              else if (_tabIndex == 0)
                                  _PublicPostsGrid(
                                    docs: posts,
                                    onTap: _openPostDetail,
                                  )
                                else
                                  _PublicAdsList(
                                    docs: ads,
                                    onTap: _openAdDetail,
                                  ),
                              const SliverToBoxAdapter(child: SizedBox(height: 90)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

enum _FollowState { none, requested, following }

class NovaPublicProfile {
  final String uid;
  final String username;
  final String displayName;
  final String city;
  final String district;
  final String bio;
  final String photoUrl;
  final String website;
  final String phone;
  final bool phoneVisible;
  final bool privateProfile;
  final int followersCount;
  final int followingCount;
  final DateTime createdAt;
  final NovaExpenseProfileCardData expenseCard;

  const NovaPublicProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.city,
    required this.district,
    required this.bio,
    required this.photoUrl,
    required this.website,
    required this.phone,
    required this.phoneVisible,
    required this.privateProfile,
    required this.followersCount,
    required this.followingCount,
    required this.createdAt,
    required this.expenseCard,
  });

  factory NovaPublicProfile.fromMap(Map<String, dynamic> data, {required String fallbackUid}) {
    return NovaPublicProfile(
      uid: _safeString(data['uid'], fallback: fallbackUid),
      username: _safeString(data['username'], fallback: 'nova.user').replaceAll('@', ''),
      displayName: _safeString(data['displayName'] ?? data['fullName'] ?? data['name'], fallback: 'Nova Kullanıcısı'),
      city: _safeString(data['city'] ?? data['il'] ?? data['province']),
      district: _safeString(data['district'] ?? data['ilce'] ?? data['ilçe'] ?? data['county']),
      bio: _safeString(data['bio'] ?? data['biography']),
      photoUrl: _safeString(data['photoUrl'] ?? data['profileImage'] ?? data['profileImageUrl'] ?? data['userPhoto']),
      website: _safeString(data['website'] ?? data['webSite'] ?? data['site']),
      phone: _safeString(data['phone'] ?? data['phoneNumber']),
      phoneVisible: data['phoneVisible'] == true || data['showPhoneNumber'] == true,
      privateProfile: data['privateProfile'] == true || data['isPrivate'] == true,
      followersCount: _safeInt(data['followersCount']),
      followingCount: _safeInt(data['followingCount']),
      createdAt: _toDate(data['createdAt']),
      expenseCard: NovaExpenseProfileCardData.fromMap(
        data['expenseProfileCard'],
        showExpensesOnProfile: data['showExpensesOnProfile'] == true,
      ),
    );
  }

  String get usernameText => username.startsWith('@') ? username.substring(1) : username;
  String get displayUsername => '@$usernameText';
  String get locationText {
    if (city.isNotEmpty && district.isNotEmpty) return '$city / $district';
    if (city.isNotEmpty) return city;
    if (district.isNotEmpty) return district;
    return '';
  }

  String get createdAtText {
    if (createdAt.millisecondsSinceEpoch <= 0) return 'Hesap açılış tarihi bilinmiyor';
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Hesap açılışı: ${two(createdAt.day)}.${two(createdAt.month)}.${createdAt.year}';
  }

}

class NovaExpenseProfileCardData {
  final bool visible;
  final String selectedCarName;
  final String selectedCarPlate;
  final String selectedPeriod;
  final double totalExpense;
  final double allCarTotal;
  final double averageExpense;
  final int recordCount;
  final String biggestCategory;
  final DateTime updatedAt;

  const NovaExpenseProfileCardData({
    required this.visible,
    required this.selectedCarName,
    required this.selectedCarPlate,
    required this.selectedPeriod,
    required this.totalExpense,
    required this.allCarTotal,
    required this.averageExpense,
    required this.recordCount,
    required this.biggestCategory,
    required this.updatedAt,
  });

  factory NovaExpenseProfileCardData.empty() {
    return NovaExpenseProfileCardData(
      visible: false,
      selectedCarName: '',
      selectedCarPlate: '',
      selectedPeriod: '',
      totalExpense: 0,
      allCarTotal: 0,
      averageExpense: 0,
      recordCount: 0,
      biggestCategory: '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory NovaExpenseProfileCardData.fromMap(
      dynamic raw, {
        required bool showExpensesOnProfile,
      }) {
    if (raw is! Map || !showExpensesOnProfile) {
      return NovaExpenseProfileCardData.empty();
    }

    final data = Map<String, dynamic>.from(raw);
    final visible = data['visible'] == true;
    if (!visible) return NovaExpenseProfileCardData.empty();

    return NovaExpenseProfileCardData(
      visible: true,
      selectedCarName: _safeString(data['selectedCarName'], fallback: 'Araç bilgisi'),
      selectedCarPlate: _safeString(data['selectedCarPlate']),
      selectedPeriod: _safeString(data['selectedPeriod'], fallback: 'Dönem'),
      totalExpense: _safeDouble(data['totalExpense']),
      allCarTotal: _safeDouble(data['allCarTotal']),
      averageExpense: _safeDouble(data['averageExpense']),
      recordCount: _safeInt(data['recordCount']),
      biggestCategory: _safeString(data['biggestCategory'], fallback: 'Veri yok'),
      updatedAt: _toDate(data['updatedAt']),
    );
  }
}

class _ExpenseProfileCard extends StatelessWidget {
  final NovaExpenseProfileCardData card;
  final AnimationController controller;

  const _ExpenseProfileCard({
    required this.card,
    required this.controller,
  });

  String _money(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
    );
  }

  String get _updatedText {
    if (card.updatedAt.millisecondsSinceEpoch <= 0) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(card.updatedAt.day)}.${two(card.updatedAt.month)}.${card.updatedAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(2.2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: SweepGradient(
              transform: GradientRotation(controller.value * math.pi * 2),
              colors: const [
                Color(0xFFFF00B8),
                Color(0xFF7C4DFF),
                Color(0xFF00D9FF),
                Color(0xFFFFE600),
                Color(0xFFFF7A00),
                Color(0xFFFF00B8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF00B8).withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fatura / Masraf Özeti',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${card.selectedCarName}${card.selectedCarPlate.isEmpty ? '' : ' • ${card.selectedCarPlate}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        card.selectedPeriod,
                        maxLines: 1,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ExpenseMiniInfo(
                        title: 'Toplam',
                        value: '${_money(card.totalExpense)} TL',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ExpenseMiniInfo(
                        title: 'Ortalama',
                        value: '${_money(card.averageExpense)} TL',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ExpenseMiniInfo(
                        title: 'Tüm Araçlar',
                        value: '${_money(card.allCarTotal)} TL',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ExpenseMiniInfo(
                        title: 'Kayıt',
                        value: '${card.recordCount} işlem',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'En yoğun kategori: ${card.biggestCategory}${_updatedText.isEmpty ? '' : ' • Güncellendi: $_updatedText'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExpenseMiniInfo extends StatelessWidget {
  final String title;
  final String value;

  const _ExpenseMiniInfo({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F6),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black45,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTopBar extends StatelessWidget {
  final String username;
  final bool privateProfile;
  final VoidCallback onBack;
  final VoidCallback onMore;

  const _UserTopBar({
    required this.username,
    required this.privateProfile,
    required this.onBack,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 27),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  privateProfile ? Icons.lock_rounded : Icons.public_rounded,
                  color: privateProfile ? const Color(0xFF12A150) : Colors.redAccent,
                  size: 18,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'İşlemler',
            onPressed: onMore,
            icon: const Icon(Icons.more_vert_rounded, color: Colors.black, size: 27),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _UserProfileHeader extends StatelessWidget {
  final NovaPublicProfile profile;
  final int postCount;
  final int followersDelta;
  final _FollowState followState;
  final bool followBusy;
  final AnimationController neonController;
  final bool canAct;
  final VoidCallback onPhotoTap;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final VoidCallback onWebsite;
  final VoidCallback onPhone;

  const _UserProfileHeader({
    required this.profile,
    required this.postCount,
    required this.followersDelta,
    required this.followState,
    required this.followBusy,
    required this.neonController,
    required this.canAct,
    required this.onPhotoTap,
    required this.onFollow,
    required this.onMessage,
    required this.onWebsite,
    required this.onPhone,
  });

  String get _buttonText {
    if (followState == _FollowState.following) return 'Takiptesin';
    if (followState == _FollowState.requested) return 'İstek gönderildi';
    return profile.privateProfile ? 'Takip isteği gönder' : 'Takip et';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onPhotoTap,
                child: _BlackRingAvatar(imageUrl: profile.photoUrl, size: 90),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatsBox(
                  posts: postCount,
                  followers: (profile.followersCount + followersDelta).clamp(0, 1 << 31),
                  following: profile.followingCount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProfileLine(text: profile.displayName, bold: true),
          if (profile.locationText.isNotEmpty) _ProfileLine(text: profile.locationText),
          if (profile.bio.isNotEmpty) _ProfileLine(text: profile.bio, maxLines: 3),
          _ProfileLine(text: profile.createdAtText, color: Colors.black54),
          if (profile.phoneVisible && profile.phone.isNotEmpty)
            GestureDetector(
              onTap: onPhone,
              child: _ProfileLine(
                text: profile.phone,
                color: const Color(0xFF13A34A),
                bold: true,
                underline: true,
              ),
            ),
          if (profile.website.isNotEmpty)
            GestureDetector(
              onTap: onWebsite,
              child: _ProfileLine(
                text: profile.website,
                color: const Color(0xFF00AFCB),
                bold: true,
                underline: true,
              ),
            ),
          const SizedBox(height: 12),
          if (canAct)
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    title: followBusy ? 'Bekle...' : _buttonText,
                    black: followState == _FollowState.none,
                    onTap: followBusy ? () {} : onFollow,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NeonMessageButton(
                    controller: neonController,
                    title: 'Mesaj gönder',
                    onTap: onMessage,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatsBox extends StatelessWidget {
  final int posts;
  final int followers;
  final int following;

  const _StatsBox({required this.posts, required this.followers, required this.following});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5D5D5), width: 1.1),
      ),
      child: Row(
        children: [
          _HeaderStat(value: posts, label: 'gönderi'),
          const _StatDivider(),
          _HeaderStat(value: followers, label: 'takipçi'),
          const _StatDivider(),
          _HeaderStat(value: following, label: 'takip'),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final int value;
  final String label;

  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_formatCount(value), textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 48, color: const Color(0xFFE7E7E7));
}

class _ProfileLine extends StatelessWidget {
  final String text;
  final Color color;
  final bool bold;
  final bool underline;
  final int maxLines;

  const _ProfileLine({
    required this.text,
    this.color = Colors.black,
    this.bold = false,
    this.underline = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: color,
          fontSize: 12.8,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          decoration: underline ? TextDecoration.underline : TextDecoration.none,
          height: 1.23,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final bool black;
  final VoidCallback onTap;

  const _ActionButton({required this.title, required this.black, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: black ? Colors.black : const Color(0xFFF1F2F6),
          foregroundColor: black ? Colors.white : Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, fontSize: 12.5),
        ),
      ),
    );
  }
}


class _NeonMessageButton extends StatelessWidget {
  final AnimationController controller;
  final String title;
  final VoidCallback onTap;

  const _NeonMessageButton({
    required this.controller,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 40,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: SweepGradient(
              transform: GradientRotation(controller.value * math.pi * 2),
              colors: const [
                Color(0xFF00D9FF),
                Color(0xFFFF00B8),
                Color(0xFFFFFF00),
                Color(0xFF00D9FF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF00B8).withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _UserTabs({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tabs = [Icons.grid_on_rounded, Icons.directions_car_filled_rounded];
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE6E6E6), width: 0.7))),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(index),
              child: Column(
                children: [
                  Expanded(child: Icon(tabs[index], color: selected ? Colors.black : Colors.black45, size: 25)),
                  Container(height: 2, color: selected ? Colors.black : Colors.transparent),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}


class _ProfileActionsSheet extends StatelessWidget {
  final bool isMe;
  final bool isFollowing;
  final VoidCallback onReport;
  final VoidCallback onBlock;
  final VoidCallback onUnfollow;

  const _ProfileActionsSheet({
    required this.isMe,
    required this.isFollowing,
    required this.onReport,
    required this.onBlock,
    required this.onUnfollow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            const Text(
              'Profil İşlemleri',
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (!isMe && isFollowing)
              _ActionSheetTile(
                title: 'Takipten çıkar',
                icon: Icons.person_remove_alt_1_rounded,
                color: Colors.black,
                onTap: onUnfollow,
              ),
            if (!isMe)
              _ActionSheetTile(
                title: 'Kullanıcıyı engelle',
                icon: Icons.block_rounded,
                color: const Color(0xFFE53935),
                onTap: onBlock,
              ),
            if (!isMe)
              _ActionSheetTile(
                title: 'Şikayet et',
                icon: Icons.report_gmailerrorred_rounded,
                color: const Color(0xFFFF8A00),
                onTap: onReport,
              ),
            if (isMe)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Bu senin profilin.',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionSheetTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionSheetTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(fontFamily: 'Roboto', color: color, fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ViewingUserFollowRequestBox extends StatelessWidget {
  final FirebaseFirestore db;
  final String currentUid;
  final String requestUserId;
  final Future<void> Function(String userId, Map<String, dynamic> data) onApprove;
  final Future<void> Function(String userId) onDelete;
  final Future<void> Function(String userId, Map<String, dynamic> data) onBlock;

  const _ViewingUserFollowRequestBox({
    required this.db,
    required this.currentUid,
    required this.requestUserId,
    required this.onApprove,
    required this.onDelete,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    if (currentUid.isEmpty || requestUserId.trim().isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('users')
          .doc(currentUid)
          .collection('followRequests')
          .doc(requestUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final data = snapshot.data!.data() ?? <String, dynamic>{};

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5E5E5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: Colors.black, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu kullanıcı takip isteği gönderdi',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.black,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _FollowRequestTile(
                db: db,
                userId: requestUserId,
                requestData: data,
                onApprove: () => onApprove(requestUserId, data),
                onDelete: () => onDelete(requestUserId),
                onBlock: () => onBlock(requestUserId, data),
                onOpenProfile: () {},
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FollowRequestsBox extends StatelessWidget {
  final FirebaseFirestore db;
  final String currentUid;
  final Future<void> Function(String userId, Map<String, dynamic> data) onApprove;
  final Future<void> Function(String userId) onDelete;
  final Future<void> Function(String userId, Map<String, dynamic> data) onBlock;
  final ValueChanged<String> onOpenProfile;

  const _FollowRequestsBox({
    required this.db,
    required this.currentUid,
    required this.onApprove,
    required this.onDelete,
    required this.onBlock,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (currentUid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('users')
          .doc(currentUid)
          .collection('followRequests')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5E5E5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, color: Colors.black, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Takip İstekleri (${docs.length})',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 15.5, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...docs.map((doc) {
                final data = doc.data();
                final userId = _safeString(data['fromUserId'], fallback: doc.id);
                return _FollowRequestTile(
                  db: db,
                  userId: userId,
                  requestData: data,
                  onApprove: () => onApprove(userId, data),
                  onDelete: () => onDelete(userId),
                  onBlock: () => onBlock(userId, data),
                  onOpenProfile: () => onOpenProfile(userId),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _FollowRequestTile extends StatelessWidget {
  final FirebaseFirestore db;
  final String userId;
  final Map<String, dynamic> requestData;
  final VoidCallback onApprove;
  final VoidCallback onDelete;
  final VoidCallback onBlock;
  final VoidCallback onOpenProfile;

  const _FollowRequestTile({
    required this.db,
    required this.userId,
    required this.requestData,
    required this.onApprove,
    required this.onDelete,
    required this.onBlock,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').doc(userId).snapshots(),
      builder: (context, userSnap) {
        final user = userSnap.data?.data() ?? <String, dynamic>{};
        final username = _safeString(
          user['username'],
          fallback: _safeString(requestData['username'], fallback: 'nova.user'),
        ).replaceAll('@', '');
        final displayName = _safeString(
          user['displayName'] ?? user['fullName'] ?? user['name'],
          fallback: _safeString(requestData['displayName']),
        );
        final photo = _safeString(
          user['photoUrl'] ?? user['profileImage'] ?? user['profileImageUrl'] ?? user['userPhoto'],
          fallback: _safeString(requestData['photoUrl']),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onOpenProfile,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.black,
                      backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                      child: photo.isEmpty ? const Icon(Icons.person_rounded, color: Colors.white) : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onOpenProfile,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          if (displayName.isNotEmpty)
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.black),
                    onSelected: (value) {
                      if (value == 'block') onBlock();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'block',
                        child: Text('Takipçiyi engelle'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: onApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14A44D),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                        child: const Text('Onayla', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: onDelete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                        child: const Text('Sil', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrivateAccountBox extends StatelessWidget {
  const _PrivateAccountBox();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E2E2)),
        ),
        child: const Column(
          children: [
            Icon(Icons.lock_rounded, color: Colors.black, size: 38),
            SizedBox(height: 10),
            Text(
              'Bu hesap gizli',
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black, fontWeight: FontWeight.w900, fontSize: 17),
            ),
            SizedBox(height: 6),
            Text(
              'Gönderileri ve ilanları görmek için takip isteği gönder.',
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontWeight: FontWeight.w700, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicPostsGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final void Function(String postId, Map<String, dynamic> data) onTap;

  const _PublicPostsGrid({required this.docs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyContent(icon: Icons.grid_on_rounded, text: 'Henüz gönderi yok'));
    }

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final doc = docs[index];
          return GestureDetector(
            onTap: () => onTap(doc.id, doc.data()),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _NetImage(url: _firstImage(doc.data()), icon: Icons.image_rounded),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(Icons.copy_rounded, color: Colors.white, size: 18, shadows: const [Shadow(color: Colors.black, blurRadius: 5)]),
                ),
              ],
            ),
          );
        },
        childCount: docs.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1.2,
        crossAxisSpacing: 1.2,
        childAspectRatio: 0.78,
      ),
    );
  }
}

class _PublicAdsList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final ValueChanged<CarAd> onTap;

  const _PublicAdsList({required this.docs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyContent(icon: Icons.directions_car_rounded, text: 'Henüz ilan yok'));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final ad = CarAd.fromDoc(docs[index]);
          return Column(
            children: [
              _VehicleTile(ad: ad, onTap: () => onTap(ad)),
              if (index != docs.length - 1) const Divider(height: 1, color: Color(0xFFE7E7E7)),
            ],
          );
        },
        childCount: docs.length,
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  final CarAd ad;
  final VoidCallback onTap;

  const _VehicleTile({required this.ad, required this.onTap});

  String get _brandModelPackage {
    final parts = [ad.brand, ad.series, ad.model, ad.engine]
        .where((e) => e.trim().isNotEmpty && e.trim() != '-')
        .toList();
    return parts.isEmpty ? 'Araç bilgisi' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 118,
                height: 126,
                child: NovaNetworkImage(url: ad.image, fit: BoxFit.cover, iconSize: 42),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ad.title, maxLines: 2, overflow: TextOverflow.ellipsis, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', fontSize: 14.5, height: 1.16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(_brandModelPackage, maxLines: 1, overflow: TextOverflow.ellipsis, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Model yılı: ${ad.year}', textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('KM: ${ad.km}', textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(ad.location, maxLines: 1, overflow: TextOverflow.ellipsis, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(ad.price, maxLines: 1, overflow: TextOverflow.ellipsis, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Color(0xFF00A86B), fontSize: 16.5, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicPostPreview extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> data;

  const _PublicPostPreview({required this.postId, required this.data});

  @override
  Widget build(BuildContext context) {
    final image = _firstImage(data);
    final username = _safeString(data['username'], fallback: 'nova.user');
    final desc = _safeString(data['caption'] ?? data['desc'] ?? data['description']);
    final location = _safeString(data['location']);

    return Column(
      children: [
        const _SheetHandle(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _SmallAvatar(imageUrl: _safeString(data['userPhoto'] ?? data['photoUrl']), size: 42),
                    const SizedBox(width: 10),
                    Expanded(child: Text('@$username', textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontWeight: FontWeight.w900))),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 1,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: _NetImage(url: image, icon: Icons.image_rounded),
                ),
              ),
              if (location.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Text(location, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontWeight: FontWeight.w800)),
                ),
              if (desc.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(desc, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontWeight: FontWeight.w600, height: 1.35)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportUserSheet extends StatefulWidget {
  final String reportedUserId;
  final String reportedUsername;
  final String currentUid;
  final FirebaseFirestore db;

  const _ReportUserSheet({
    required this.reportedUserId,
    required this.reportedUsername,
    required this.currentUid,
    required this.db,
  });

  @override
  State<_ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends State<_ReportUserSheet> {
  final TextEditingController controller = TextEditingController();
  String reason = 'Uygunsuz profil';
  bool sending = false;

  final reasons = const [
    'Uygunsuz profil',
    'Sahte hesap',
    'Taciz / rahatsızlık',
    'Spam',
    'Dolandırıcılık şüphesi',
    'Diğer',
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> sendReport() async {
    if (sending) return;
    if (widget.currentUid.isEmpty) {
      _show('Şikayet için giriş yapmalısın.');
      return;
    }
    setState(() => sending = true);
    try {
      await widget.db.collection('reports').add({
        'type': 'user_profile',
        'reportedUserId': widget.reportedUserId,
        'reportedUsername': widget.reportedUsername,
        'reporterUserId': widget.currentUid,
        'reason': reason,
        'detail': controller.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şikayet gönderildi. NOVA ekibi inceleyecek.')),
      );
    } catch (_) {
      _show('Şikayet gönderilemedi. İnternet bağlantını kontrol et.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottom),
      child: FractionallySizedBox(
        heightFactor: 0.68,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              const _SheetHandle(),
              const Text('Profili Şikayet Et', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    ...reasons.map((item) {
                      final selected = item == reason;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => setState(() => reason = item),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: selected ? Colors.black : const Color(0xFFF4F5F7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? Colors.white : Colors.black),
                                const SizedBox(width: 10),
                                Text(item, textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      minLines: 3,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Açıklama ekle (isteğe bağlı)',
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: sending ? null : sendReport,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Şikayet Gönder', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)),
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

class _ProfilePhotoDialog extends StatelessWidget {
  final String imageUrl;

  const _ProfilePhotoDialog({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 80),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 12,
          right: 12,
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Kapat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlackRingAvatar extends StatelessWidget {
  final String imageUrl;
  final double size;

  const _BlackRingAvatar({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.8),
      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: CircleAvatar(
          backgroundColor: const Color(0xFFF1F1F1),
          backgroundImage: imageUrl.trim().isEmpty ? null : NetworkImage(imageUrl),
          child: imageUrl.trim().isEmpty ? const Icon(Icons.person_rounded, color: Colors.black, size: 34) : null,
        ),
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  final String imageUrl;
  final double size;

  const _SmallAvatar({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.black,
      backgroundImage: imageUrl.trim().isEmpty ? null : NetworkImage(imageUrl),
      child: imageUrl.trim().isEmpty ? const Icon(Icons.person_rounded, color: Colors.white) : null,
    );
  }
}

class _NetImage extends StatelessWidget {
  final String url;
  final IconData icon;

  const _NetImage({required this.url, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Container(color: const Color(0xFFF1F1F1), child: Icon(icon, color: Colors.black26));
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      loadingBuilder: (context, child, loading) {
        if (loading == null) return child;
        return Container(color: const Color(0xFFF1F1F1));
      },
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF1F1F1), child: Icon(icon, color: Colors.black26)),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyContent({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 40, 18, 18),
      child: Column(
        children: [
          Icon(icon, color: Colors.black, size: 38),
          const SizedBox(height: 10),
          Text(text, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48,
        height: 5,
        margin: const EdgeInsets.only(top: 10, bottom: 12),
        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)),
      ),
    );
  }
}

class UserProfileSkeleton extends StatelessWidget {
  const UserProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget box({double? w, required double h, double r = 14, BoxShape shape = BoxShape.rectangle}) {
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          children: [
            Row(children: [box(w: 38, h: 38, r: 12), const SizedBox(width: 10), box(w: 150, h: 18, r: 99), const Spacer(), box(w: 38, h: 38, r: 12)]),
            const SizedBox(height: 18),
            Row(children: [box(w: 90, h: 90, shape: BoxShape.circle), const SizedBox(width: 12), Expanded(child: box(h: 88, r: 16))]),
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft, child: box(w: 160, h: 13, r: 99)),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: box(w: 120, h: 11, r: 99)),
            const SizedBox(height: 14),
            Row(children: [Expanded(child: box(h: 40, r: 12)), const SizedBox(width: 8), Expanded(child: box(h: 40, r: 12))]),
            const SizedBox(height: 18),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 9,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 1.2, crossAxisSpacing: 1.2, childAspectRatio: 0.78),
                itemBuilder: (_, __) => box(h: 120, r: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserProfileMiniLoading extends StatelessWidget {
  const UserProfileMiniLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 1.2, crossAxisSpacing: 1.2, childAspectRatio: 0.78),
        itemBuilder: (_, __) => const ColoredBox(color: Color(0xFFF1F1F1)),
      ),
    );
  }
}

String _safeString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}

double _safeDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _safeInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

List<String> _stringList(dynamic value) {
  if (value is List) return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  return <String>[];
}

DateTime _toDate(dynamic value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}B';
  return value.toString();
}

String _firstImage(Map<String, dynamic> data) {
  final list = data['images'] ?? data['imageUrls'] ?? data['mediaUrls'];
  if (list is List && list.isNotEmpty) return _safeString(list.first);
  return _safeString(data['imageUrl'] ?? data['image'] ?? data['mediaUrl'] ?? data['photoUrl']);
}
