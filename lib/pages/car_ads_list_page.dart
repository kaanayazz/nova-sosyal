import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'home_page.dart';
import 'messages_page.dart';

class CarAdsListPage extends StatefulWidget {
  const CarAdsListPage({super.key});

  @override
  State<CarAdsListPage> createState() => _CarAdsListPageState();
}

class _CarAdsListPageState extends State<CarAdsListPage> {
  int stepIndex = 0;

  String selectedCategory = '';
  String selectedBrand = '';
  String selectedModel = '';
  String selectedSeries = '';
  String selectedEngine = '';

  String selectedCategoryId = '';
  String selectedBrandId = '';
  String selectedModelId = '';
  String selectedSeriesId = '';
  String selectedEngineId = '';

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final TextEditingController adNoSearchController = TextEditingController();

  final List<String> categories = const [
    'Otomobil',
    'Arazi, SUV & Pickup',
    'Elektrikli Araçlar 🌱',
    'Motosiklet',
    'Minivan & Panelvan',
    'Ticari Araçlar',
    'Kiralık Araçlar',
    'Deniz Araçları',
    'Hasarlı Araçlar',
    'Karavan',
    'Klasik Araçlar',
    'ATV',
    'UTV',
    'Engelli Plakalı Araçlar',
  ];

  final List<String> brands = const [
    'Abarth',
    'Acura',
    'Alfa Romeo',
    'Anadol',
    'Aston Martin',
    'Audi',
    'Bentley',
    'BMW',
    'BYD',
    'Cadillac',
    'Citroen',
    'Dacia',
    'Fiat',
    'Ford',
    'Honda',
    'Hyundai',
    'Mercedes-Benz',
    'Opel',
    'Peugeot',
    'Renault',
    'Volkswagen',
  ];

  final List<String> models = const [
    'A1',
    'A3',
    'A4',
    'A5',
    'A6',
    'A7',
    'A8',
    'E-Tron GT',
    'Q3',
    'Q5',
    'Q7',
    'R8',
    'RS',
    'S Serisi',
    'TT',
  ];

  final List<String> series = const [
    'A4 Avant',
    'A4 Cabrio',
    'A4 Sedan',
    'A4 Allroad Quattro',
  ];

  final List<String> engines = const [
    '40 TDI',
    '45 TFSI',
    '1.4 TFSI',
    '1.4 TFSI Design',
    '1.4 TFSI Dynamic',
    '1.4 TFSI Sport',
    '1.6',
    '1.8',
    '1.8 T',
    '1.8 TFSI',
    '1.8 T Quattro',
    '1.9 TDI',
    '2.0',
    '2.0 TDI',
    '2.0 TDI Design',
  ];

  @override
  void dispose() {
    adNoSearchController.dispose();
    super.dispose();
  }

  String get pageTitle {
    if (stepIndex == 0) return 'İlanlara Gözat';
    if (stepIndex == 1) return selectedCategory;
    if (stepIndex == 2) return selectedBrand;
    if (stepIndex == 3) return selectedModel;
    if (stepIndex == 4) return selectedSeries;
    return 'NOVA İlanları';
  }

  List<String> currentMenu() {
    if (stepIndex == 0) return categories;
    if (stepIndex == 1) return brands;
    if (stepIndex == 2) return models;
    if (stepIndex == 3) return series;
    return engines;
  }

  String get selectedPath {
    final items = [
      selectedCategory,
      selectedBrand,
      selectedModel,
      selectedSeries,
      selectedEngine,
    ].where((e) => e.trim().isNotEmpty).toList();

    if (items.isEmpty) return 'Tüm İlanlar';
    return items.join(' > ');
  }

  void goBackStep() {
    if (stepIndex == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      stepIndex--;
      if (stepIndex < 4) { selectedEngine = ''; selectedEngineId = ''; }
      if (stepIndex < 3) { selectedSeries = ''; selectedSeriesId = ''; }
      if (stepIndex < 2) { selectedModel = ''; selectedModelId = ''; }
      if (stepIndex < 1) { selectedBrand = ''; selectedBrandId = ''; }
    });
  }

  void selectItem(String value) {
    setState(() {
      if (stepIndex == 0) {
        selectedCategory = value;
        stepIndex = 1;
      } else if (stepIndex == 1) {
        selectedBrand = value;
        stepIndex = 2;
      } else if (stepIndex == 2) {
        selectedModel = value;
        stepIndex = 3;
      } else if (stepIndex == 3) {
        selectedSeries = value;
        stepIndex = 4;
      } else if (stepIndex == 4) {
        selectedEngine = value;
        stepIndex = 5;
      }
    });
  }

  void goHomePage() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomePage(onStoryTap: () {})),
          (route) => false,
    );
  }

  CollectionReference<Map<String, dynamic>> stepCollection() {
    if (stepIndex == 0) {
      return firestore.collection('vehiclePanel').doc('catalog').collection('categories');
    }
    if (stepIndex == 1) {
      return firestore
          .collection('vehiclePanel')
          .doc('catalog')
          .collection('categories')
          .doc(selectedCategoryId)
          .collection('brands');
    }
    if (stepIndex == 2) {
      return firestore
          .collection('vehiclePanel')
          .doc('catalog')
          .collection('categories')
          .doc(selectedCategoryId)
          .collection('brands')
          .doc(selectedBrandId)
          .collection('models');
    }
    if (stepIndex == 3) {
      return firestore
          .collection('vehiclePanel')
          .doc('catalog')
          .collection('categories')
          .doc(selectedCategoryId)
          .collection('brands')
          .doc(selectedBrandId)
          .collection('models')
          .doc(selectedModelId)
          .collection('packages');
    }
    return firestore
        .collection('vehiclePanel')
        .doc('catalog')
        .collection('categories')
        .doc(selectedCategoryId)
        .collection('brands')
        .doc(selectedBrandId)
        .collection('models')
        .doc(selectedModelId)
        .collection('packages')
        .doc(selectedSeriesId)
        .collection('engines');
  }

  List<CatalogItem> fallbackCatalogItems() {
    final list = currentMenu();
    return list.map((name) => CatalogItem(id: createSafeId(name), name: name)).toList();
  }

  String createSafeId(String value) {
    return value
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  void selectCatalogItem(CatalogItem item) {
    setState(() {
      if (stepIndex == 0) {
        selectedCategory = item.name;
        selectedCategoryId = item.id;
        selectedBrand = '';
        selectedBrandId = '';
        selectedModel = '';
        selectedModelId = '';
        selectedSeries = '';
        selectedSeriesId = '';
        selectedEngine = '';
        selectedEngineId = '';
        stepIndex = 1;
      } else if (stepIndex == 1) {
        selectedBrand = item.name;
        selectedBrandId = item.id;
        selectedModel = '';
        selectedModelId = '';
        selectedSeries = '';
        selectedSeriesId = '';
        selectedEngine = '';
        selectedEngineId = '';
        stepIndex = 2;
      } else if (stepIndex == 2) {
        selectedModel = item.name;
        selectedModelId = item.id;
        selectedSeries = '';
        selectedSeriesId = '';
        selectedEngine = '';
        selectedEngineId = '';
        stepIndex = 3;
      } else if (stepIndex == 3) {
        selectedSeries = item.name;
        selectedSeriesId = item.id;
        selectedEngine = '';
        selectedEngineId = '';
        stepIndex = 4;
      } else if (stepIndex == 4) {
        selectedEngine = item.name;
        selectedEngineId = item.id;
        stepIndex = 5;
      }
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _adsStream() {
    return firestore.collection('carAds').orderBy('createdAt', descending: true).snapshots();
  }

  bool _matchesSelectedPath(CarAd ad) {
    if (ad.status.trim().isNotEmpty && ad.status != 'active') return false;
    if (!ad.isApproved) return false;
    if (selectedCategory.trim().isNotEmpty && ad.category != selectedCategory.trim()) return false;
    if (selectedBrand.trim().isNotEmpty && ad.brand != selectedBrand.trim()) return false;
    if (selectedModel.trim().isNotEmpty && ad.series != selectedModel.trim()) return false;
    if (selectedSeries.trim().isNotEmpty && ad.model != selectedSeries.trim()) return false;
    if (selectedEngine.trim().isNotEmpty && ad.engine != selectedEngine.trim()) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: goBackStep,
          ),
          title: Text(
            pageTitle,
            textScaler: TextScaler.noScaling,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: stepIndex == 5
            ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _adsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.black));
            }

            if (snapshot.hasError) {
              return ErrorStateBox(
                title: 'İlanlar yüklenemedi',
                subtitle: 'Firebase bağlantısı veya carAds koleksiyonu kontrol edilmeli.',
                onRefresh: () => setState(() {}),
              );
            }

            final query = adNoSearchController.text.trim();
            final ads = (snapshot.data?.docs ?? [])
                .map(CarAd.fromDoc)
                .where(_matchesSelectedPath)
                .where((ad) {
              if (query.isEmpty) return true;
              return ad.adNo.contains(query);
            }).toList();

            return AdsResultList(
              ads: ads,
              selectedPath: selectedPath,
              searchController: adNoSearchController,
              onSearchChanged: (_) => setState(() {}),
              onHome: goHomePage,
            );
          },
        )
            : CatalogMenuStream(
          stream: stepCollection().snapshots(),
          fallbackItems: fallbackCatalogItems(),
          onTap: selectCatalogItem,
        ),
      ),
    );
  }
}


class CatalogItem {
  final String id;
  final String name;

  const CatalogItem({required this.id, required this.name});

  factory CatalogItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = (data['name'] ?? data['title'] ?? data['label'] ?? doc.id).toString().trim();
    return CatalogItem(id: doc.id, name: name.isEmpty ? doc.id : name);
  }
}

class CatalogMenuStream extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final List<CatalogItem> fallbackItems;
  final ValueChanged<CatalogItem> onTap;

  const CatalogMenuStream({
    super.key,
    required this.stream,
    required this.fallbackItems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        List<CatalogItem> items = fallbackItems;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          items = snapshot.data!.docs.map(CatalogItem.fromDoc).where((e) => e.name.trim().isNotEmpty).toList();
        }

        if (snapshot.connectionState == ConnectionState.waiting && fallbackItems.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
        }

        return CategoryMenuList(
          items: items,
          onTap: onTap,
        );
      },
    );
  }
}

class CategoryMenuList extends StatelessWidget {
  final List<CatalogItem> items;
  final ValueChanged<CatalogItem> onTap;

  const CategoryMenuList({
    super.key,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 0.8,
        color: Color(0xFFE3E3E8),
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () => onTap(item),
          child: Container(
            height: 56,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    textScaler: TextScaler.noScaling,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 24, color: Colors.black38),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AdsResultList extends StatelessWidget {
  final List<CarAd> ads;
  final String selectedPath;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onHome;

  const AdsResultList({
    super.key,
    required this.ads,
    required this.selectedPath,
    required this.searchController,
    required this.onSearchChanged,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AdNoSearchBox(controller: searchController, onChanged: onSearchChanged),
        Container(
          color: Colors.white,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
          child: Text(
            selectedPath,
            textScaler: TextScaler.noScaling,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: ads.isEmpty
              ? const EmptyAdsBox()
              : ListView.builder(
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = ads[index];
              return Column(
                children: [
                  VehicleListTile(
                    ad: ad,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CarAdDetailPage(ad: ad),
                        ),
                      );
                    },
                  ),
                  if (index != ads.length - 1) const GreyThinDivider(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class VehicleListTile extends StatelessWidget {
  final CarAd ad;
  final VoidCallback onTap;

  const VehicleListTile({
    super.key,
    required this.ad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 150),
        color: Colors.white,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 128,
                height: 122,
                child: NovaNetworkImage(url: ad.image, fit: BoxFit.cover, iconSize: 44),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 122,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title,
                      textScaler: TextScaler.noScaling,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${ad.year} • ${ad.fuel} • ${ad.gear}',
                      textScaler: TextScaler.noScaling,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      ad.location,
                      textScaler: TextScaler.noScaling,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Color(0xFF8A00FF),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 103,
              height: 122,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FavoriteButton(adId: ad.id),
                  const Spacer(),
                  Text(
                    ad.price,
                    textScaler: TextScaler.noScaling,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Color(0xFF00A86B),
                      fontSize: 17,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
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

class CarAdDetailPage extends StatefulWidget {
  final CarAd ad;

  const CarAdDetailPage({
    super.key,
    required this.ad,
  });

  @override
  State<CarAdDetailPage> createState() => _CarAdDetailPageState();
}

class _CarAdDetailPageState extends State<CarAdDetailPage> {
  int selectedTab = 0;

  Future<void> callSeller() async {
    final cleanPhone = widget.ad.sellerPhone.replaceAll(' ', '');
    if (cleanPhone.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void openMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MessagesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final galleryImages = ad.images.isEmpty ? [ad.image] : ad.images;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
          title: Text(
            ad.title,
            textScaler: TextScaler.noScaling,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black,
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 7, 7, 7),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: NeonFrameButton(
                    height: 52,
                    borderRadius: 7,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: callSeller,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Ara',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NeonFrameButton(
                    height: 52,
                    borderRadius: 7,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: openMessages,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Mesaj Gönder',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: ListView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: Colors.white,
              height: 268,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImageGallery(images: galleryImages, initialIndex: 0),
                          ),
                        );
                      },
                      child: PageView.builder(
                        itemCount: galleryImages.length,
                        itemBuilder: (context, index) {
                          return NovaNetworkImage(url: galleryImages[index], fit: BoxFit.cover, iconSize: 74);
                        },
                      ),
                    ),
                  ),
                  Positioned(top: 12, right: 12, child: FavoriteButton(adId: ad.id, darkMode: true)),
                  Positioned(bottom: 10, left: 10, child: NeonModelBadge(text: ad.year)),
                  Positioned(
                    bottom: 8,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '1/${galleryImages.length}',
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
              child: Column(
                children: [
                  Text(
                    '@${ad.username}',
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black,
                      fontSize: 15,
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ad.price,
                    textScaler: TextScaler.noScaling,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Color(0xFF00A86B),
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ad.location,
                    textScaler: TextScaler.noScaling,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Color(0xFF8A00FF),
                      fontSize: 17,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    ad.categoryPath,
                    textScaler: TextScaler.noScaling,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black45,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              child: Row(
                children: [
                  DetailTabButton(
                    title: 'İlan Bilgileri',
                    selected: selectedTab == 0,
                    onTap: () => setState(() => selectedTab = 0),
                  ),
                  DetailTabButton(
                    title: 'Açıklama',
                    selected: selectedTab == 1,
                    onTap: () => setState(() => selectedTab = 1),
                  ),
                ],
              ),
            ),
            if (selectedTab == 0) ...[
              SpecsTable(ad: ad),
              DetailedSpecsSection(ad: ad),
              PaintExpertiseSection(ad: ad),
              const SizedBox(height: 90),
            ] else ...[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Text(
                  ad.description,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black87,
                    fontSize: 15,
                    height: 1.48,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 90),
            ],
          ],
        ),
      ),
    );
  }
}

class FavoriteButton extends StatelessWidget {
  final String adId;
  final bool darkMode;

  const FavoriteButton({
    super.key,
    required this.adId,
    this.darkMode = false,
  });

  Future<void> _toggleFavorite(bool isFavorite) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || adId.isEmpty) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favoriteCarAds')
        .doc(adId);

    if (isFavorite) {
      await ref.delete();
    } else {
      await ref.set({
        'adId': adId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || adId.isEmpty) {
      return Icon(
        Icons.favorite_border_rounded,
        color: darkMode ? Colors.white : Colors.black,
        size: 28,
      );
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favoriteCarAds')
        .doc(adId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data?.exists ?? false;
        final icon = Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite ? Colors.redAccent : (darkMode ? Colors.white : Colors.black),
          size: darkMode ? 29 : 28,
        );

        if (!darkMode) {
          return GestureDetector(
            onTap: () => _toggleFavorite(isFavorite),
            child: icon,
          );
        }

        return GestureDetector(
          onTap: () => _toggleFavorite(isFavorite),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.72),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF00B8).withOpacity(0.35),
                  blurRadius: 14,
                ),
              ],
            ),
            child: icon,
          ),
        );
      },
    );
  }
}

class DetailTabButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const DetailTabButton({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.white,
            border: Border.all(color: const Color(0xFFE1E1E1), width: 0.8),
          ),
          child: Text(
            title,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: selected ? Colors.white : Colors.black54,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class SpecsTable extends StatelessWidget {
  final CarAd ad;

  const SpecsTable({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    final List<List<Object>> rows = [
      ['Konum', ad.location, true],
      ['İlan Tarihi', ad.date, false],
      ['İlan No', ad.adNo, false],
      ['Marka', ad.brand, false],
      ['Seri', ad.series, false],
      ['Model', ad.model, false],
      ['Yıl', ad.year, false],
      ['Yakıt Tipi', ad.fuel, false],
      ['Vites', ad.gear, false],
      ['Araç Durumu', ad.condition, false],
      ['KM', ad.km, false],
      ['Kasa Tipi', ad.body, false],
      ['Motor Gücü', ad.power, false],
      ['Motor Hacmi', ad.engineVolume, false],
      ['Çekiş', ad.traction, false],
      ['Renk', ad.color, false],
      ['Garanti', ad.warranty, false],
      ['Ağır Hasar Kayıtlı', ad.heavyDamage, false],
      ['Plaka / Uyruk', ad.plate, false],
      ['Kimden', ad.from, false],
      ['Takas', ad.trade, false],
    ];

    return Container(
      color: Colors.white,
      child: Column(
        children: rows.map<Widget>((row) {
          final special = row[2] as bool;
          final title = row[0] as String;

          return Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE1E1E1), width: 0.7)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black45,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row[1] as String,
                    textScaler: TextScaler.noScaling,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: title == 'Konum'
                          ? const Color(0xFF8A00FF)
                          : special
                          ? Colors.black87
                          : Colors.black54,
                      fontSize: 13,
                      fontWeight: special ? FontWeight.w900 : FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class DetailedSpecsSection extends StatelessWidget {
  final CarAd ad;

  const DetailedSpecsSection({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    final List<SpecSection> sections = [
      SpecSection(
        title: 'GENEL BİLGİLER',
        rows: [
          ['Model Üretim Yılı', ad.year],
          ['Segmenti', ad.segment],
          ['Kasa Tipi / Kapı Sayısı', ad.body],
          ['Motor Tipi', ad.fuel],
          ['Yakıt Tüketimi', ad.fuelConsumption],
          ['Motor Gücü', ad.power],
          ['Şanzıman / Çekiş', '${ad.gear} / ${ad.traction}'],
          ['Hızlanma 0-100 km/saat', ad.acceleration],
          ['Azami Sürat', ad.maxSpeed],
          ['Toplam Yıllık MTV', ad.mtv],
        ],
      ),
      SpecSection(
        title: 'MOTOR VE PERFORMANS',
        rows: [
          ['Motor Tipi', ad.fuel],
          ['Motor Hacmi', ad.engineVolume],
          ['Maksimum Güç', ad.power],
          ['Maksimum Tork', ad.torque],
          ['Hızlanma 0-100 km/saat', ad.acceleration],
          ['Azami Sürat', ad.maxSpeed],
        ],
      ),
      SpecSection(
        title: 'YAKIT TÜKETİMİ',
        rows: [
          ['Yakıt Tipi', ad.fuel],
          ['Şehir içi', ad.cityFuel],
          ['Şehir dışı', ad.highwayFuel],
          ['Ortalama', ad.averageFuel],
          ['Yakıt Depo Hacmi', ad.fuelTank],
        ],
      ),
      SpecSection(
        title: 'BOYUTLAR',
        rows: [
          ['Koltuk Sayısı', ad.seats],
          ['Uzunluk', ad.length],
          ['Genişlik', ad.width],
          ['Yükseklik', ad.height],
          ['Net Ağırlık', ad.weight],
          ['Bagaj Kapasitesi', ad.trunk],
          ['Lastik Ölçüleri', ad.tires],
        ],
      ),
    ];

    return Column(
      children: sections.map((section) {
        final cleanRows = section.rows.where((row) => row[1].trim().isNotEmpty && row[1] != '-').toList();
        if (cleanRows.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 8),
          color: Colors.white,
          child: Column(
            children: [
              NovaSectionHeader(title: section.title),
              ...cleanRows.map((row) => SimpleDataRow(title: row[0], value: row[1])),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class SimpleDataRow extends StatelessWidget {
  final String title;
  final String value;

  const SimpleDataRow({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE1E1E1), width: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NovaSectionHeader extends StatelessWidget {
  final String title;

  const NovaSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F1F1),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E2E2))),
      ),
      child: Text(
        title,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.black54,
          fontSize: 13,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class PaintExpertiseSection extends StatelessWidget {
  final CarAd ad;

  const PaintExpertiseSection({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    final hasExpertise = ad.localPaintParts.isNotEmpty || ad.paintedParts.isNotEmpty || ad.changedParts.isNotEmpty;
    if (!hasExpertise) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaSectionHeader(title: 'BOYA, DEĞİŞEN VE EKSPERTİZ BİLGİSİ'),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              height: 158,
              width: 158,
              child: CustomPaint(painter: CarExpertisePainter()),
            ),
          ),
          const SizedBox(height: 10),
          if (ad.localPaintParts.isNotEmpty)
            LegendInfoRow(color: const Color(0xFFFF8A00), title: 'Lokal Boyalı', value: ad.localPaintParts.join(', ')),
          if (ad.paintedParts.isNotEmpty)
            LegendInfoRow(color: const Color(0xFF1E6BFF), title: 'Boyalı', value: ad.paintedParts.join(', ')),
          if (ad.changedParts.isNotEmpty)
            LegendInfoRow(color: const Color(0xFFE53935), title: 'Değişen', value: ad.changedParts.join(', ')),
        ],
      ),
    );
  }
}

class LegendInfoRow extends StatelessWidget {
  final Color color;
  final String title;
  final String value;

  const LegendInfoRow({super.key, required this.color, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          LegendBox(color: color, title: title),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class LegendBox extends StatelessWidget {
  final Color color;
  final String title;

  const LegendBox({super.key, required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 9, height: 9, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class CarExpertisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grey = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;

    final orange = Paint()
      ..color = const Color(0xFFFF8A00)
      ..style = PaintingStyle.fill;

    final blue = Paint()
      ..color = const Color(0xFF1E6BFF)
      ..style = PaintingStyle.fill;

    final red = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(centerX, size.height / 2), width: 52, height: 126),
        const Radius.circular(20),
      ),
      grey,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(centerX - 21, 30, 42, 20), const Radius.circular(7)),
      whitePaint,
    );

    canvas.drawCircle(Offset(centerX - 49, 48), 14, grey);
    canvas.drawCircle(Offset(centerX + 49, 48), 14, red);
    canvas.drawCircle(Offset(centerX - 49, 111), 14, blue);
    canvas.drawCircle(Offset(centerX + 49, 111), 14, orange);

    final stroke = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(centerX - 26, 46), Offset(centerX - 51, 48), stroke);
    canvas.drawLine(Offset(centerX + 26, 46), Offset(centerX + 51, 48), stroke);
    canvas.drawLine(Offset(centerX - 26, 109), Offset(centerX - 51, 111), stroke);
    canvas.drawLine(Offset(centerX + 26, 109), Offset(centerX + 51, 111), stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NeonFrameButton extends StatefulWidget {
  final Widget child;
  final double height;
  final double? width;
  final double borderRadius;

  const NeonFrameButton({
    super.key,
    required this.child,
    required this.height,
    this.width,
    this.borderRadius = 16,
  });

  @override
  State<NeonFrameButton> createState() => _NeonFrameButtonState();
}

class _NeonFrameButtonState extends State<NeonFrameButton> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          padding: const EdgeInsets.all(1.7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + controller.value * 2, 0),
              end: Alignment(1 - controller.value * 2, 0),
              colors: const [
                Color(0xFFFF00B8),
                Color(0xFF00D9FF),
                Color(0xFF00FF85),
                Color(0xFFFFE600),
                Color(0xFFFF00B8),
              ],
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF00B8).withOpacity(0.26), blurRadius: 10),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius - 1.7),
            child: widget.child,
          ),
        );
      },
    );

    if (widget.width == null) return content;
    return SizedBox(width: widget.width, child: content);
  }
}

class GreyThinDivider extends StatelessWidget {
  const GreyThinDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0xFFD8D8D8));
  }
}

class AdNoSearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const AdNoSearchBox({super.key, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: '10 haneli ilan numarası ile ara',
          hintStyle: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.black38,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.black),
          filled: true,
          fillColor: Colors.black.withOpacity(0.035),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.black, width: 1.1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.black, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class NeonModelBadge extends StatefulWidget {
  final String text;

  const NeonModelBadge({super.key, required this.text});

  @override
  State<NeonModelBadge> createState() => _NeonModelBadgeState();
}

class _NeonModelBadgeState extends State<NeonModelBadge> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(1.6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: SweepGradient(
              transform: GradientRotation(controller.value * 6.28318),
              colors: const [
                Color(0xFFFF00B8),
                Color(0xFF00D9FF),
                Color(0xFF00FF85),
                Color(0xFFFFE600),
                Color(0xFFFF00B8),
              ],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(13)),
            child: Text(
              widget.text,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      },
    );
  }
}

class FullScreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageGallery> createState() => _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<FullScreenImageGallery> {
  late final PageController controller;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${currentIndex + 1}/${widget.images.length}',
          textScaler: TextScaler.noScaling,
          style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
        ),
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  return const Icon(Icons.directions_car_rounded, color: Colors.white, size: 80);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class NovaNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double iconSize;

  const NovaNetworkImage({
    super.key,
    required this.url,
    required this.fit,
    this.iconSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Container(
        color: Colors.black12,
        child: Icon(Icons.directions_car_rounded, size: iconSize),
      );
    }

    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.black12,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
          ),
        );
      },
      errorBuilder: (_, __, ___) {
        return Container(
          color: Colors.black12,
          child: Icon(Icons.directions_car_rounded, size: iconSize),
        );
      },
    );
  }
}

class EmptyAdsBox extends StatelessWidget {
  const EmptyAdsBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.directions_car_filled_rounded, size: 56, color: Colors.black26),
            SizedBox(height: 12),
            Text(
              'Bu filtreye uygun ilan yok',
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black87,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Yeni ilan eklendiğinde burada canlı olarak görünecek.',
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black45,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorStateBox extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRefresh;

  const ErrorStateBox({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              title,
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black87,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black45,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRefresh,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text('Yenile'),
            ),
          ],
        ),
      ),
    );
  }
}

class SpecSection {
  final String title;
  final List<List<String>> rows;

  const SpecSection({required this.title, required this.rows});
}

class CarAd {
  final String id;
  final String title;
  final String seller;
  final String username;
  final String sellerPhone;
  final String categoryPath;
  final String location;
  final String price;
  final String date;
  final String adNo;
  final String category;
  final String brand;
  final String series;
  final String model;
  final String engine;
  final String year;
  final String fuel;
  final String gear;
  final String condition;
  final String km;
  final String body;
  final String power;
  final String engineVolume;
  final String traction;
  final String color;
  final String warranty;
  final String heavyDamage;
  final String plate;
  final String from;
  final String trade;
  final String image;
  final List<String> images;
  final String description;
  final List<String> features;
  final String status;
  final bool isApproved;

  final String segment;
  final String fuelConsumption;
  final String acceleration;
  final String maxSpeed;
  final String mtv;
  final String torque;
  final String cityFuel;
  final String highwayFuel;
  final String averageFuel;
  final String fuelTank;
  final String seats;
  final String length;
  final String width;
  final String height;
  final String weight;
  final String trunk;
  final String tires;
  final List<String> localPaintParts;
  final List<String> paintedParts;
  final List<String> changedParts;

  const CarAd({
    required this.id,
    required this.title,
    required this.seller,
    required this.username,
    required this.sellerPhone,
    required this.categoryPath,
    required this.location,
    required this.price,
    required this.date,
    required this.adNo,
    required this.category,
    required this.brand,
    required this.series,
    required this.model,
    required this.engine,
    required this.year,
    required this.fuel,
    required this.gear,
    required this.condition,
    required this.km,
    required this.body,
    required this.power,
    required this.engineVolume,
    required this.traction,
    required this.color,
    required this.warranty,
    required this.heavyDamage,
    required this.plate,
    required this.from,
    required this.trade,
    required this.image,
    required this.images,
    required this.description,
    required this.features,
    required this.status,
    required this.isApproved,
    required this.segment,
    required this.fuelConsumption,
    required this.acceleration,
    required this.maxSpeed,
    required this.mtv,
    required this.torque,
    required this.cityFuel,
    required this.highwayFuel,
    required this.averageFuel,
    required this.fuelTank,
    required this.seats,
    required this.length,
    required this.width,
    required this.height,
    required this.weight,
    required this.trunk,
    required this.tires,
    required this.localPaintParts,
    required this.paintedParts,
    required this.changedParts,
  });

  factory CarAd.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final images = _stringList(data['images']);
    final image = _readString(data, ['image', 'mainImage', 'coverImage', 'photoUrl', 'thumbnail']);
    final category = _readString(data, ['category', 'vehicleCategory']);
    final brand = _readString(data, ['brand']);
    final series = _readString(data, ['series', 'seri']);
    final model = _readString(data, ['model']);
    final engine = _readString(data, ['engine', 'engineType', 'motor']);
    final city = _readString(data, ['city', 'il']);
    final district = _readString(data, ['district', 'ilce']);
    final location = _readString(data, ['location', 'konum']).trim().isNotEmpty
        ? _readString(data, ['location', 'konum'])
        : [city, district].where((e) => e.trim().isNotEmpty).join(' / ');

    final adNo = _readString(data, ['adNo', 'ilanNo', 'listingNo']).trim().isNotEmpty
        ? _readString(data, ['adNo', 'ilanNo', 'listingNo'])
        : doc.id.length > 10
        ? doc.id.substring(0, 10)
        : doc.id;

    return CarAd(
      id: doc.id,
      title: _readString(data, ['title', 'adTitle', 'baslik'], fallback: 'Araç ilanı'),
      seller: _readString(data, ['seller', 'sellerName', 'ownerName', 'name'], fallback: 'NOVA Kullanıcısı'),
      username: _readString(data, ['username', 'userName', 'sellerUsername'], fallback: 'nova'),
      sellerPhone: _readString(data, ['sellerPhone', 'phone', 'telefon']),
      categoryPath: _readString(data, ['categoryPath'], fallback: [category, brand, series, model, engine].where((e) => e.trim().isNotEmpty).join(' > ')),
      location: location.trim().isEmpty ? '-' : location,
      price: _formatPrice(data['priceText'] ?? data['price'] ?? data['fiyat']),
      date: _formatDate(data['createdAt'] ?? data['date'] ?? data['ilanTarihi']),
      adNo: adNo,
      category: category,
      brand: brand,
      series: series,
      model: model,
      engine: engine,
      year: _readString(data, ['year', 'yil'], fallback: '-'),
      fuel: _readString(data, ['fuel', 'fuelType', 'yakit'], fallback: '-'),
      gear: _readString(data, ['gear', 'transmission', 'vites'], fallback: '-'),
      condition: _readString(data, ['condition', 'vehicleCondition', 'durum'], fallback: 'İkinci El'),
      km: _readString(data, ['km', 'kilometer', 'kilometre'], fallback: '-'),
      body: _readString(data, ['body', 'bodyType', 'kasa'], fallback: '-'),
      power: _readString(data, ['power', 'motorPower', 'motorGucu'], fallback: '-'),
      engineVolume: _readString(data, ['engineVolume', 'motorHacmi'], fallback: '-'),
      traction: _readString(data, ['traction', 'cekis'], fallback: '-'),
      color: _readString(data, ['color', 'renk'], fallback: '-'),
      warranty: _readString(data, ['warranty', 'garanti'], fallback: '-'),
      heavyDamage: _damageText(data),
      plate: _readString(data, ['plate', 'plaka'], fallback: '-'),
      from: _readString(data, ['from', 'kimden'], fallback: '-'),
      trade: _readString(data, ['trade', 'takas'], fallback: '-'),
      image: image.trim().isNotEmpty ? image : (images.isNotEmpty ? images.first : ''),
      images: images.isNotEmpty ? images : (image.trim().isNotEmpty ? [image] : []),
      description: _readString(data, ['description', 'aciklama'], fallback: 'Açıklama girilmemiş.'),
      features: _stringList(data['features'] ?? data['ozellikler']),
      status: _readString(data, ['status'], fallback: 'active'),
      isApproved: data['isApproved'] is bool ? data['isApproved'] as bool : true,
      segment: _readString(data, ['segment'], fallback: '-'),
      fuelConsumption: _readString(data, ['fuelConsumption', 'yakitTuketimi'], fallback: '-'),
      acceleration: _readString(data, ['acceleration', 'hizlanma'], fallback: '-'),
      maxSpeed: _readString(data, ['maxSpeed', 'azamiSurat'], fallback: '-'),
      mtv: _readString(data, ['mtv'], fallback: '-'),
      torque: _readString(data, ['torque', 'tork'], fallback: '-'),
      cityFuel: _readString(data, ['cityFuel', 'sehirIci'], fallback: '-'),
      highwayFuel: _readString(data, ['highwayFuel', 'sehirDisi'], fallback: '-'),
      averageFuel: _readString(data, ['averageFuel', 'ortalamaYakit'], fallback: '-'),
      fuelTank: _readString(data, ['fuelTank', 'depo'], fallback: '-'),
      seats: _readString(data, ['seats', 'koltuk'], fallback: '-'),
      length: _readString(data, ['length', 'uzunluk'], fallback: '-'),
      width: _readString(data, ['width', 'genislik'], fallback: '-'),
      height: _readString(data, ['height', 'yukseklik'], fallback: '-'),
      weight: _readString(data, ['weight', 'agirlik'], fallback: '-'),
      trunk: _readString(data, ['trunk', 'bagaj'], fallback: '-'),
      tires: _readString(data, ['tires', 'lastik'], fallback: '-'),
      localPaintParts: _stringList(data['localPaintParts'] ?? data['lokalBoyali']),
      paintedParts: _stringList(data['paintedParts'] ?? data['boyali']),
      changedParts: _stringList(data['changedParts'] ?? data['degisen']),
    );
  }

  static String _readString(Map<String, dynamic> data, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty && e != 'null').toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return [];
  }

  static String _damageText(Map<String, dynamic> data) {
    final damage = _readString(data, ['damageRecord', 'damage', 'heavyDamage', 'agirHasar'], fallback: '-');
    final amount = _readString(data, ['damageAmount', 'damageAmountText', 'hasarTutari']);
    if (damage.toLowerCase().contains('var') && amount.trim().isNotEmpty) {
      return '$damage / $amount';
    }
    return damage;
  }

  static String _formatDate(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (value is String) date = DateTime.tryParse(value);

    if (date == null) return '-';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  static String _formatPrice(dynamic value) {
    if (value == null) return '₺0';
    if (value is num) {
      final text = value.round().toString();
      final buffer = StringBuffer();
      for (int i = 0; i < text.length; i++) {
        final reverseIndex = text.length - i;
        buffer.write(text[i]);
        if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write('.');
      }
      return '₺$buffer';
    }
    final text = value.toString().trim();
    if (text.isEmpty) return '₺0';
    return text.startsWith('₺') ? text : '₺$text';
  }
}
