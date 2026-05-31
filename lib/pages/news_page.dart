import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> with SingleTickerProviderStateMixin {
  late final AnimationController neonController;
  final TextEditingController searchController = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    neonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    neonController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> fuelStream() {
    return firestore.collection('appPanel').doc('fuelPrices').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> newsStream() {
    return firestore
        .collection('news')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> toggleReaction(NewsArticle article, NewsReaction newReaction) async {
    final user = auth.currentUser;
    if (user == null || article.id.isEmpty) {
      showMessage('Beğenmek için giriş yapmalısın.');
      return;
    }

    final newsRef = firestore.collection('news').doc(article.id);
    final reactionRef = newsRef.collection('reactions').doc(user.uid);

    await firestore.runTransaction((transaction) async {
      final reactionSnap = await transaction.get(reactionRef);
      final oldReactionText = reactionSnap.data()?['reaction']?.toString() ?? 'none';
      final oldReaction = NewsArticle.reactionFromString(oldReactionText);

      int likeDelta = 0;
      int dislikeDelta = 0;
      int interactionDelta = 0;

      if (oldReaction == newReaction) {
        if (oldReaction == NewsReaction.like) likeDelta = -1;
        if (oldReaction == NewsReaction.dislike) dislikeDelta = -1;
        interactionDelta = -1;
        transaction.delete(reactionRef);
      } else {
        if (oldReaction == NewsReaction.like) likeDelta -= 1;
        if (oldReaction == NewsReaction.dislike) dislikeDelta -= 1;
        if (newReaction == NewsReaction.like) likeDelta += 1;
        if (newReaction == NewsReaction.dislike) dislikeDelta += 1;
        if (oldReaction == NewsReaction.none) interactionDelta = 1;

        transaction.set(reactionRef, {
          'userId': user.uid,
          'reaction': newReaction.name,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      transaction.update(newsRef, {
        'likes': FieldValue.increment(likeDelta),
        'dislikes': FieldValue.increment(dislikeDelta),
        'interactions': FieldValue.increment(interactionDelta),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> increaseView(NewsArticle article) async {
    if (article.id.isEmpty) return;
    await firestore.collection('news').doc(article.id).update({
      'viewsValue': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void openDetail(NewsArticle article) {
    increaseView(article);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailPage(
          article: article,
          onLike: () => toggleReaction(article, NewsReaction.like),
          onDislike: () => toggleReaction(article, NewsReaction.dislike),
        ),
      ),
    );
  }

  List<NewsArticle> filterArticles(List<NewsArticle> articles) {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return articles;

    return articles.where((article) {
      return article.title.toLowerCase().contains(query) ||
          article.description.toLowerCase().contains(query) ||
          article.detail.toLowerCase().contains(query) ||
          article.category.toLowerCase().contains(query);
    }).toList();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const NewsHeader(),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: newsStream(),
                  builder: (context, newsSnapshot) {
                    if (newsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      );
                    }

                    if (newsSnapshot.hasError) {
                      return NewsErrorBox(
                        message: 'Haberler yüklenemedi. Firestore index veya bağlantı hatası olabilir.',
                        onRetry: () => setState(() {}),
                      );
                    }

                    final articles = (newsSnapshot.data?.docs ?? [])
                        .map(NewsArticle.fromDoc)
                        .toList();
                    final list = filterArticles(articles);

                    return ListView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                      children: [
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: fuelStream(),
                          builder: (context, fuelSnapshot) {
                            final fuelPanel = FuelPanelData.fromDoc(fuelSnapshot.data);
                            return FuelPricePanel(
                              prices: fuelPanel.prices,
                              updatedAt: fuelPanel.updatedAtText,
                              isLoading: fuelSnapshot.connectionState == ConnectionState.waiting,
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        NewsSearchBar(
                          controller: searchController,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Haber Akışı',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Text(
                              '${list.length} haber',
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
                        const SizedBox(height: 12),
                        if (list.isEmpty)
                          const EmptyNewsState()
                        else
                          ...list.map(
                                (article) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: UserReactionBuilder(
                                articleId: article.id,
                                builder: (reaction) {
                                  final liveArticle = article.copyWith(userReaction: reaction);
                                  return NewsCard(
                                    article: liveArticle,
                                    controller: neonController,
                                    onTap: () => openDetail(liveArticle),
                                    onLike: () => toggleReaction(liveArticle, NewsReaction.like),
                                    onDislike: () => toggleReaction(liveArticle, NewsReaction.dislike),
                                  );
                                },
                              ),
                            ),
                          ),
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

enum NewsReaction { none, like, dislike }

class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String detail;
  final String category;
  final String readTime;
  final String date;
  final String image;
  final int viewsValue;
  final int likes;
  final int dislikes;
  final int interactions;
  final NewsReaction userReaction;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.detail,
    required this.category,
    required this.readTime,
    required this.date,
    required this.image,
    required this.viewsValue,
    required this.likes,
    required this.dislikes,
    required this.interactions,
    this.userReaction = NewsReaction.none,
  });

  factory NewsArticle.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return NewsArticle(
      id: doc.id,
      title: readString(data, ['title', 'baslik'], 'Başlıksız haber'),
      description: readString(data, ['description', 'summary', 'shortText', 'aciklama'], ''),
      detail: readString(data, ['detail', 'content', 'body', 'detay'], ''),
      category: readString(data, ['category', 'kategori'], 'Genel'),
      readTime: readString(data, ['readTime', 'okumaSuresi'], '2 dk'),
      date: formatDate(data['createdAt'] ?? data['date']),
      image: readString(data, ['image', 'imageUrl', 'coverImage', 'photoUrl'], ''),
      viewsValue: readInt(data['viewsValue'] ?? data['views']),
      likes: readInt(data['likes']),
      dislikes: readInt(data['dislikes']),
      interactions: readInt(data['interactions']),
    );
  }

  NewsArticle copyWith({NewsReaction? userReaction}) {
    return NewsArticle(
      id: id,
      title: title,
      description: description,
      detail: detail,
      category: category,
      readTime: readTime,
      date: date,
      image: image,
      viewsValue: viewsValue,
      likes: likes,
      dislikes: dislikes,
      interactions: interactions,
      userReaction: userReaction ?? this.userReaction,
    );
  }

  String get viewsText => '${formatNumber(viewsValue)} görüntülenme';

  static NewsReaction reactionFromString(String value) {
    if (value == 'like') return NewsReaction.like;
    if (value == 'dislike') return NewsReaction.dislike;
    return NewsReaction.none;
  }
}

class FuelPanelData {
  final List<FuelPrice> prices;
  final String updatedAtText;

  const FuelPanelData({
    required this.prices,
    required this.updatedAtText,
  });

  factory FuelPanelData.fromDoc(DocumentSnapshot<Map<String, dynamic>>? doc) {
    final data = doc?.data() ?? <String, dynamic>{};
    final rawPrices = data['prices'];

    final prices = <FuelPrice>[];
    if (rawPrices is List) {
      for (final item in rawPrices) {
        if (item is Map) {
          final name = (item['name'] ?? '').toString().trim();
          final price = (item['price'] ?? '').toString().trim();
          if (name.isNotEmpty && price.isNotEmpty) {
            prices.add(FuelPrice(name: name, price: price.startsWith('₺') ? price : '₺$price'));
          }
        }
      }
    }

    final fallbackPrices = const [
      FuelPrice(name: 'Benzin', price: '₺0.00'),
      FuelPrice(name: 'Mazot', price: '₺0.00'),
      FuelPrice(name: 'LPG', price: '₺0.00'),
    ];

    return FuelPanelData(
      prices: prices.isEmpty ? fallbackPrices : prices,
      updatedAtText: formatFuelUpdatedAt(data['updatedAt'] ?? data['dateText'] ?? data['updatedAtText']),
    );
  }
}

class FuelPrice {
  final String name;
  final String price;

  const FuelPrice({
    required this.name,
    required this.price,
  });
}

class FuelPricePanel extends StatelessWidget {
  final List<FuelPrice> prices;
  final String updatedAt;
  final bool isLoading;

  const FuelPricePanel({
    super.key,
    required this.prices,
    required this.updatedAt,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF00D9FF),
            Color(0xFFFF00B8),
            Color(0xFFFFFF00),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ortalama Akaryakıt Fiyatları',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              updatedAt,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: prices.take(3).map((item) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          item.name,
                          textScaler: TextScaler.noScaling,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.price,
                          textScaler: TextScaler.noScaling,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class UserReactionBuilder extends StatelessWidget {
  final String articleId;
  final Widget Function(NewsReaction reaction) builder;

  const UserReactionBuilder({
    super.key,
    required this.articleId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || articleId.isEmpty) return builder(NewsReaction.none);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('news')
          .doc(articleId)
          .collection('reactions')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final reactionText = snapshot.data?.data()?['reaction']?.toString() ?? 'none';
        return builder(NewsArticle.reactionFromString(reactionText));
      },
    );
  }
}

class NewsHeader extends StatelessWidget {
  const NewsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Haberler',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class NewsSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const NewsSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.045),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Colors.black45),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                hintText: 'Haber ara...',
                hintStyle: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black45,
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  final NewsArticle article;
  final AnimationController controller;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  const NewsCard({
    super.key,
    required this.article,
    required this.controller,
    required this.onTap,
    required this.onLike,
    required this.onDislike,
  });

  @override
  Widget build(BuildContext context) {
    final liked = article.userReaction == NewsReaction.like;
    final disliked = article.userReaction == NewsReaction.dislike;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(1.8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
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
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: NovaNewsImage(url: article.image, height: 190),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: onTap,
                        child: Text(
                          article.title,
                          textScaler: TextScaler.noScaling,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.black,
                            fontSize: 18,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        article.description,
                        textScaler: TextScaler.noScaling,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black54,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          InfoChip(text: article.category),
                          InfoChip(text: article.date),
                          InfoChip(text: article.readTime),
                          InfoChip(text: article.viewsText),
                          InfoChip(text: '${formatNumber(article.interactions)} etkileşim'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          ReactionButton(
                            icon: Icons.thumb_up_alt_rounded,
                            text: formatNumber(article.likes),
                            active: liked,
                            onTap: onLike,
                          ),
                          const SizedBox(width: 10),
                          ReactionButton(
                            icon: Icons.thumb_down_alt_rounded,
                            text: formatNumber(article.dislikes),
                            active: disliked,
                            onTap: onDislike,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: const Text(
                            'Haberi Oku',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
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

class NewsDetailPage extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  const NewsDetailPage({
    super.key,
    required this.article,
    required this.onLike,
    required this.onDislike,
  });

  @override
  Widget build(BuildContext context) {
    return UserReactionBuilder(
      articleId: article.id,
      builder: (reaction) {
        final liveArticle = article.copyWith(userReaction: reaction);
        final liked = liveArticle.userReaction == NewsReaction.like;
        final disliked = liveArticle.userReaction == NewsReaction.dislike;

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 330,
                  pinned: true,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        NovaNewsImage(url: liveArticle.image, height: 330),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.18),
                                Colors.transparent,
                                Colors.black.withOpacity(0.82),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 24,
                          child: Text(
                            liveArticle.title,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontSize: 27,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            InfoChip(text: liveArticle.category),
                            InfoChip(text: liveArticle.date),
                            InfoChip(text: liveArticle.readTime),
                            InfoChip(text: liveArticle.viewsText),
                            InfoChip(text: '${formatNumber(liveArticle.interactions)} etkileşim'),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          liveArticle.description,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.black54,
                            height: 1.5,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            ReactionButton(
                              icon: Icons.thumb_up_alt_rounded,
                              text: formatNumber(liveArticle.likes),
                              active: liked,
                              onTap: onLike,
                            ),
                            const SizedBox(width: 10),
                            ReactionButton(
                              icon: Icons.thumb_down_alt_rounded,
                              text: formatNumber(liveArticle.dislikes),
                              active: disliked,
                              onTap: onDislike,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Haber Detayı',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          liveArticle.detail,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.black87,
                            height: 1.6,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
      },
    );
  }
}

class NovaNewsImage extends StatelessWidget {
  final String url;
  final double height;

  const NovaNewsImage({super.key, required this.url, required this.height});

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return fallback();

    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return fallback(isLoading: true);
      },
      errorBuilder: (_, __, ___) => fallback(),
    );
  }

  Widget fallback({bool isLoading = false}) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.black,
      alignment: Alignment.center,
      child: isLoading
          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
          : const Icon(Icons.article_rounded, color: Colors.white, size: 68),
    );
  }
}

class ReactionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool active;
  final VoidCallback onTap;

  const ReactionButton({
    super.key,
    required this.icon,
    required this.text,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.black.withOpacity(0.055),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : Colors.black),
            const SizedBox(width: 6),
            Text(
              text,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: active ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final String text;

  const InfoChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.black54,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class EmptyNewsState extends StatelessWidget {
  const EmptyNewsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Text(
        'Aramana uygun haber bulunamadı.',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: Colors.black45,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class NewsErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const NewsErrorBox({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
            const SizedBox(height: 12),
            Text(
              message,
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text('Yenile'),
            ),
          ],
        ),
      ),
    );
  }
}

String readString(Map<String, dynamic> data, List<String> keys, String fallback) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return fallback;
}

int readInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

String formatDate(dynamic value) {
  DateTime? date;
  if (value is Timestamp) date = value.toDate();
  if (value is DateTime) date = value;
  if (value is String) date = DateTime.tryParse(value);
  if (date == null) return 'Yeni';

  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inMinutes < 1) return 'Şimdi';
  if (difference.inMinutes < 60) return '${difference.inMinutes} dk önce';
  if (difference.inHours < 24) return '${difference.inHours} saat önce';
  if (difference.inDays == 1) return 'Dün';
  if (difference.inDays < 7) return '${difference.inDays} gün önce';

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day.$month.$year';
}

String formatFuelUpdatedAt(dynamic value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  final dateText = formatDate(value);
  if (dateText == 'Yeni') return 'Panelden fiyat bekleniyor';
  return 'Son güncelleme: $dateText';
}

String formatNumber(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}B';
  return value.toString();
}
