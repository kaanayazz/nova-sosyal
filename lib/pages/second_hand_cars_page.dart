import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'car_ads_list_page.dart';
import 'news_page.dart';
import 'store_page.dart';
import 'emergency_tow_create_ad_page.dart';
import 'car_ad_create_page.dart';
import 'events_page.dart';

class SecondHandCarsPage extends StatefulWidget {
  const SecondHandCarsPage({super.key});

  @override
  State<SecondHandCarsPage> createState() => _SecondHandCarsPageState();
}

class _SecondHandCarsPageState extends State<SecondHandCarsPage> {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _refreshKey = 0;

  Stream<int> _countStream(String collectionPath) {
    return _firestore
        .collection(collectionPath)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<_BannerData?> _bannerStream() {
    return _firestore
        .collection('appBanners')
        .doc('secondHandCars')
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (data == null) return null;

      final active = data['active'] == true;
      final imageUrl = (data['imageUrl'] ?? '').toString().trim();
      if (!active || imageUrl.isEmpty) return null;

      return _BannerData(
        imageUrl: imageUrl,
        title: (data['title'] ?? 'Nova Banner').toString().trim(),
        subtitle: (data['subtitle'] ?? '').toString().trim(),
      );
    });
  }

  Future<void> _refreshPage() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _refreshKey++;
    });
  }

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
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
          child: RefreshIndicator(
            backgroundColor: Colors.white,
            color: Colors.black,
            strokeWidth: 3,
            onRefresh: _refreshPage,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 92),
                      child: StreamBuilder<_BannerData?>(
                        key: ValueKey('banner_$_refreshKey'),
                        stream: _bannerStream(),
                        builder: (context, bannerSnapshot) {
                          final banner = bannerSnapshot.data;

                          return Column(
                            children: [
                              if (banner != null) ...[
                                SizedBox(
                                  height: 92,
                                  child: _ImageMenuCard(
                                    title: banner.title.isEmpty
                                        ? 'Nova Banner'
                                        : banner.title,
                                    subtitle: banner.subtitle.isEmpty
                                        ? 'Panelden eklenen reklam görseli'
                                        : banner.subtitle,
                                    icon: Icons.campaign_rounded,
                                    imageUrl: banner.imageUrl,
                                    rightText: 'Reklam',
                                    strongDarkOverlay: true,
                                    onTap: () {},
                                  ),
                                ),
                                const SizedBox(height: 9),
                              ],
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: StreamBuilder<int>(
                                        key: ValueKey('carAds_$_refreshKey'),
                                        stream: _countStream('carAds'),
                                        builder: (context, snapshot) {
                                          return _ImageMenuCard(
                                            title: 'Araç İlanları',
                                            subtitle: 'Yayındaki araçları gör',
                                            icon: Icons
                                                .directions_car_filled_rounded,
                                            imageAsset:
                                            'assets/images/menu/car_ads.png',
                                            rightText:
                                            _rightCount(snapshot, 'ilan'),
                                            onTap: () => _go(
                                              context,
                                              const CarAdsListPage(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: StreamBuilder<int>(
                                        key: ValueKey('news_$_refreshKey'),
                                        stream: _countStream('news'),
                                        builder: (context, snapshot) {
                                          return _ImageMenuCard(
                                            title: 'Haberler',
                                            subtitle:
                                            'Nova gündemi ve duyurular',
                                            icon: Icons.article_rounded,
                                            imageAsset:
                                            'assets/images/menu/news.png',
                                            rightText:
                                            _rightCount(snapshot, 'haber'),
                                            onTap: () => _go(
                                              context,
                                              const NewsPage(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 9),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: StreamBuilder<int>(
                                        key: ValueKey('products_$_refreshKey'),
                                        stream: _countStream('products'),
                                        builder: (context, snapshot) {
                                          return _ImageMenuCard(
                                            title: 'Mağaza',
                                            subtitle: 'Ürünleri keşfet',
                                            icon: Icons.storefront_rounded,
                                            imageAsset:
                                            'assets/images/menu/store.png',
                                            rightText:
                                            _rightCount(snapshot, 'ürün'),
                                            onTap: () => _go(
                                              context,
                                              const StorePage(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: _ImageMenuCard(
                                        title: 'Etkinlikler',
                                        subtitle:
                                        'Yakındaki etkinlikleri keşfet',
                                        icon: Icons.event_rounded,
                                        imageAsset:
                                        'assets/images/menu/events.png',
                                        rightText: 'Canlı',
                                        onTap: () => _go(
                                          context,
                                          const EventsPage(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 9),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _BlackNeonButton(
                                        title: 'Çekici İlan Ver',
                                        subtitle: 'Acil çekici hizmeti ekle',
                                        icon: Icons.local_shipping_rounded,
                                        imageAsset:
                                        'assets/images/menu/tow_create.png',
                                        onTap: () => _go(
                                          context,
                                          const EmergencyTowCreateAdPage(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: _BlackNeonButton(
                                        title: 'Araç İlan Ver',
                                        subtitle: 'Aracını satışa çıkar',
                                        icon: Icons.add_rounded,
                                        imageAsset:
                                        'assets/images/menu/car_create.png',
                                        onTap: () => _go(
                                          context,
                                          const CarAdCreatePage(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _rightCount(AsyncSnapshot<int> snapshot, String label) {
    if (snapshot.hasError) return 'Hata';
    if (snapshot.connectionState == ConnectionState.waiting) return '...';
    final count = snapshot.data ?? 0;
    return '$count $label';
  }
}

class _BannerData {
  final String imageUrl;
  final String title;
  final String subtitle;

  const _BannerData({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
  });
}

class _ImageMenuCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? imageAsset;
  final String? imageUrl;
  final String rightText;
  final bool strongDarkOverlay;
  final VoidCallback onTap;

  const _ImageMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.rightText,
    required this.onTap,
    this.imageAsset,
    this.imageUrl,
    this.strongDarkOverlay = false,
  });

  @override
  State<_ImageMenuCard> createState() => _ImageMenuCardState();
}

class _ImageMenuCardState extends State<_ImageMenuCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: SweepGradient(
              transform: GradientRotation(_controller.value * 6.28318),
              colors: const [
                Color(0xFF000000),
                Color(0xFF5F5F5F),
                Color(0xFF111111),
                Color(0xFF9A9A9A),
                Color(0xFF000000),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.7),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: widget.onTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _CardBackground(
                        assetPath: widget.imageAsset,
                        imageUrl: widget.imageUrl,
                      ),
                      Container(
                        color: Colors.black.withOpacity(
                          widget.strongDarkOverlay ? 0.25 : 0.20,
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x99000000),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.20),
                                    ),
                                  ),
                                  child: Icon(
                                    widget.icon,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(9),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.24),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    widget.rightText,
                                    textScaler: TextScaler.noScaling,
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              widget.title,
                              textScaler: TextScaler.noScaling,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              textScaler: TextScaler.noScaling,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.white.withOpacity(0.82),
                                fontSize: 11.5,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 8,
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
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BlackNeonButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String imageAsset;
  final VoidCallback onTap;

  const _BlackNeonButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.imageAsset,
    required this.onTap,
  });

  @override
  State<_BlackNeonButton> createState() => _BlackNeonButtonState();
}

class _BlackNeonButtonState extends State<_BlackNeonButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: SweepGradient(
              transform: GradientRotation(_controller.value * 6.28318),
              colors: const [
                Color(0xFFFF00B8),
                Color(0xFF00D9FF),
                Color(0xFF00FF85),
                Color(0xFFFFE600),
                Color(0xFFFF00B8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF00B8).withOpacity(0.20),
                blurRadius: 24,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: const Color(0xFF00D9FF).withOpacity(0.18),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Material(
              color: Colors.black,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: widget.onTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _CardBackground(assetPath: widget.imageAsset),
                      Container(color: Colors.black.withOpacity(0.51)),
                      Padding(
                        padding: const EdgeInsets.all(13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.20),
                                ),
                              ),
                              child: Icon(
                                widget.icon,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.title,
                              textScaler: TextScaler.noScaling,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 8),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              textScaler: TextScaler.noScaling,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.white.withOpacity(0.78),
                                fontSize: 11.5,
                                height: 1.15,
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
            ),
          ),
        );
      },
    );
  }
}

class _CardBackground extends StatelessWidget {
  final String? assetPath;
  final String? imageUrl;

  const _CardBackground({
    this.assetPath,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    final asset = (assetPath ?? '').trim();

    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: 1200,
        errorBuilder: (_, __, ___) => const _FallbackBackground(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const _FallbackBackground();
        },
      );
    }

    if (asset.isNotEmpty) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _FallbackBackground(),
      );
    }

    return const _FallbackBackground();
  }
}

class _FallbackBackground extends StatelessWidget {
  const _FallbackBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF101010),
            Color(0xFF303030),
            Color(0xFF050505),
          ],
        ),
      ),
    );
  }
}