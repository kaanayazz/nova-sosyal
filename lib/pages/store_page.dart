import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cart_page.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController neonController;
  final TextEditingController searchController = TextEditingController();

  StoreCategory selectedCategory = StoreCategory.all;
  String searchText = '';

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

  Query<Map<String, dynamic>> productsQuery() {
    return FirebaseFirestore.instance
        .collection('storeProducts')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true);
  }

  List<StoreProduct> filterProducts(List<StoreProduct> products) {
    final query = searchText.trim().toLowerCase();

    return products.where((product) {
      final matchesCategory =
          selectedCategory == StoreCategory.all ||
              product.category == selectedCategory;

      final matchesSearch = query.isEmpty ||
          product.title.toLowerCase().contains(query) ||
          product.subtitle.toLowerCase().contains(query) ||
          product.productCode.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  String money(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    int count = 0;

    for (int i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }

    return '₺${buffer.toString().split('').reversed.join()}';
  }

  void openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StoreCartPage()),
    );
  }

  Future<void> addToCart(StoreProduct product) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('Sepete eklemek için giriş yapmalısın.');
      return;
    }

    if (product.stock <= 0) {
      showMessage('Bu ürün şu anda stokta yok.');
      return;
    }

    try {
      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc(product.id);

      final snapshot = await cartRef.get();
      final currentQty = (snapshot.data()?['quantity'] as num?)?.toInt() ?? 0;

      if (!snapshot.exists) {
        await cartRef.set({
          'productId': product.id,
          'title': product.title,
          'subtitle': product.subtitle,
          'imageUrl': product.imageUrl,
          'price': product.price,
          'oldPrice': product.oldPrice,
          'category': product.category.key,
          'productCode': product.productCode,
          'quantity': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await cartRef.update({
          'title': product.title,
          'subtitle': product.subtitle,
          'imageUrl': product.imageUrl,
          'price': product.price,
          'oldPrice': product.oldPrice,
          'category': product.category.key,
          'productCode': product.productCode,
          'quantity': currentQty + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      showMessage('${product.title} sepete eklendi.');
    } catch (e) {
      showMessage('Sepete eklenemedi: $e');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showProductDetail(StoreProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return ProductDetailSheet(
          product: product,
          money: money,
          onAddToCart: () async {
            Navigator.pop(context);
            await addToCart(product);
          },
          onGoCart: () {
            Navigator.pop(context);
            openCart();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              StoreHeader(onCartTap: openCart),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: productsQuery().snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const StoreLoadingState();
                    }

                    if (snapshot.hasError) {
                      return StoreErrorState(
                        error: snapshot.error.toString(),
                        onRetry: () => setState(() {}),
                      );
                    }

                    final allProducts = (snapshot.data?.docs ?? [])
                        .map(StoreProduct.fromDoc)
                        .toList();

                    final list = filterProducts(allProducts);

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                      physics: const ClampingScrollPhysics(),
                      children: [
                        StoreHeroCard(controller: neonController),
                        const SizedBox(height: 14),
                        StoreSearchBar(
                          controller: searchController,
                          onChanged: (value) {
                            setState(() => searchText = value);
                          },
                        ),
                        const SizedBox(height: 14),
                        CategorySelector(
                          selected: selectedCategory,
                          onChanged: (category) {
                            setState(() => selectedCategory = category);
                          },
                        ),
                        const SizedBox(height: 16),
                        StoreSectionTitle(
                          title: selectedCategory.title,
                          subtitle: '${list.length} ürün',
                        ),
                        const SizedBox(height: 12),
                        if (allProducts.isEmpty)
                          const EmptyStoreResult(
                            title: 'Henüz ürün eklenmedi',
                            subtitle:
                            'Panelden ürün eklendiğinde burada canlı olarak görünecek.',
                          )
                        else if (list.isEmpty)
                          const EmptyStoreResult(
                            title: 'Ürün bulunamadı',
                            subtitle:
                            'Arama veya kategori filtresini değiştir.',
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: list.length,
                            gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.69,
                            ),
                            itemBuilder: (context, index) {
                              return ProductCard(
                                product: list[index],
                                controller: neonController,
                                money: money,
                                onTap: () => showProductDetail(list[index]),
                              );
                            },
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

class StoreHeader extends StatelessWidget {
  final VoidCallback onCartTap;

  const StoreHeader({
    super.key,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black,
            ),
          ),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'NOVA Mağaza',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Yedek parça ve aksesuar',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCartTap,
            icon: const Icon(
              Icons.shopping_bag_rounded,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreHeroCard extends StatelessWidget {
  final AnimationController controller;

  const StoreHeroCard({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(2.2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: SweepGradient(
              transform: GradientRotation(controller.value * math.pi * 2),
              colors: const [
                Color(0xFF00D9FF),
                Color(0xFFFF00B8),
                Color(0xFFFFE600),
                Color(0xFF00FF85),
                Color(0xFF00D9FF),
              ],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 38,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aracın için ihtiyacın burada',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Panelden eklenen ürünler burada canlı listelenir.',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
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

class StoreSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const StoreSearchBar({
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
                hintText: 'Ürün ara...',
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

class CategorySelector extends StatelessWidget {
  final StoreCategory selected;
  final ValueChanged<StoreCategory> onChanged;

  const CategorySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = StoreCategory.values;

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selected == category;

          return GestureDetector(
            onTap: () => onChanged(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    category.icon,
                    size: 16,
                    color: isSelected ? Colors.white : Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.chipTitle,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      color: isSelected ? Colors.white : Colors.black54,
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

class StoreSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const StoreSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
        Text(
          subtitle,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black45,
          ),
        ),
      ],
    );
  }
}

class ProductCard extends StatelessWidget {
  final StoreProduct product;
  final AnimationController controller;
  final String Function(int value) money;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.controller,
    required this.money,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(1.7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
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
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            product.badge,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          product.category.icon,
                          size: 18,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                    const Spacer(),
                    ProductVisual(product: product, size: 66),
                    const Spacer(),
                    Text(
                      product.title,
                      textScaler: TextScaler.noScaling,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.subtitle,
                      textScaler: TextScaler.noScaling,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (product.oldPrice > 0) ...[
                          Flexible(
                            child: Text(
                              money(product.oldPrice),
                              textScaler: TextScaler.noScaling,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.black38,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            money(product.price),
                            textScaler: TextScaler.noScaling,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.stock > 0 ? 'Detay için dokun' : 'Stokta yok',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: product.stock > 0 ? Colors.black45 : Colors.red,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
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

class ProductVisual extends StatelessWidget {
  final StoreProduct product;
  final double size;

  const ProductVisual({
    super.key,
    required this.product,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (product.imageUrl.trim().isNotEmpty) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(
            product.imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ProductIconFallback(
              product: product,
              size: size,
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return ProductIconFallback(product: product, size: size);
            },
          ),
        ),
      );
    }

    return ProductIconFallback(product: product, size: size);
  }
}

class ProductIconFallback extends StatelessWidget {
  final StoreProduct product;
  final double size;

  const ProductIconFallback({
    super.key,
    required this.product,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
        child: Icon(
          product.icon,
          color: Colors.white,
          size: size * 0.52,
        ),
      ),
    );
  }
}

class ProductDetailSheet extends StatelessWidget {
  final StoreProduct product;
  final String Function(int value) money;
  final VoidCallback onAddToCart;
  final VoidCallback onGoCart;

  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.money,
    required this.onAddToCart,
    required this.onGoCart,
  });

  @override
  Widget build(BuildContext context) {
    final canAddToCart = product.stock > 0;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.84,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  ProductVisual(product: product, size: 82),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.black,
                            fontSize: 22,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          product.subtitle,
                          textScaler: TextScaler.noScaling,
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
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StoreInfoChip(text: product.category.chipTitle),
                  StoreInfoChip(text: '${product.stock} stok'),
                  StoreInfoChip(text: product.cargoInfo),
                  StoreInfoChip(text: product.productCode),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (product.oldPrice > 0) ...[
                    Text(
                      money(product.oldPrice),
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.black38,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    money(product.price),
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black,
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Ürün Açıklaması',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.description,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black87,
                  fontSize: 15,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              DetailInfoBox(
                icon: Icons.verified_rounded,
                title: 'Garanti',
                value: product.warranty,
              ),
              const SizedBox(height: 10),
              DetailInfoBox(
                icon: Icons.directions_car_rounded,
                title: 'Uyumluluk',
                value: product.compatibility,
              ),
              const SizedBox(height: 20),
              const Text(
                'Öne Çıkan Özellikler',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (product.features.isEmpty)
                const Text(
                  'Özellik bilgisi eklenmemiş.',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black45,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                ...product.features.map(
                      (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onGoCart,
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text(
                        'Sepete Git',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canAddToCart ? onAddToCart : null,
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: Text(
                        canAddToCart ? 'Sepete Ekle' : 'Stok Yok',
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        disabledBackgroundColor: Colors.black12,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.black38,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class StoreInfoChip extends StatelessWidget {
  final String text;

  const StoreInfoChip({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.055),
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

class DetailInfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const DetailInfoBox({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.045),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class EmptyStoreResult extends StatelessWidget {
  final String title;
  final String subtitle;

  const EmptyStoreResult({
    super.key,
    this.title = 'Ürün bulunamadı',
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.storefront_rounded,
            color: Colors.black26,
            size: 52,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textScaler: TextScaler.noScaling,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black45,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StoreLoadingState extends StatelessWidget {
  const StoreLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Colors.black),
    );
  }
}

class StoreErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const StoreErrorState({
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 58,
            ),
            const SizedBox(height: 12),
            const Text(
              'Ürünler yüklenemedi',
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
              maxLines: 5,
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
        ),
      ),
    );
  }
}

enum StoreCategory { all, spareParts, accessories }

extension StoreCategoryData on StoreCategory {
  String get key {
    switch (this) {
      case StoreCategory.all:
        return 'all';
      case StoreCategory.spareParts:
        return 'spareParts';
      case StoreCategory.accessories:
        return 'accessories';
    }
  }

  String get chipTitle {
    switch (this) {
      case StoreCategory.all:
        return 'Tümü';
      case StoreCategory.spareParts:
        return 'Yedek Parça';
      case StoreCategory.accessories:
        return 'Aksesuar';
    }
  }

  String get title {
    switch (this) {
      case StoreCategory.all:
        return 'Tüm Ürünler';
      case StoreCategory.spareParts:
        return 'Yedek Parça';
      case StoreCategory.accessories:
        return 'Aksesuar';
    }
  }

  IconData get icon {
    switch (this) {
      case StoreCategory.all:
        return Icons.storefront_rounded;
      case StoreCategory.spareParts:
        return Icons.settings_rounded;
      case StoreCategory.accessories:
        return Icons.auto_awesome_rounded;
    }
  }

  static StoreCategory fromKey(String value) {
    final clean = value.trim().toLowerCase();

    if (clean == 'spareparts' ||
        clean == 'spare_parts' ||
        clean == 'yedekparca' ||
        clean == 'yedek_parca' ||
        clean == 'yedek parça') {
      return StoreCategory.spareParts;
    }

    if (clean == 'accessories' ||
        clean == 'accessory' ||
        clean == 'aksesuar') {
      return StoreCategory.accessories;
    }

    return StoreCategory.all;
  }
}

class StoreProduct {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final int price;
  final int oldPrice;
  final StoreCategory category;
  final IconData icon;
  final String badge;
  final int stock;
  final String cargoInfo;
  final String warranty;
  final String compatibility;
  final String productCode;
  final List<String> features;
  final String imageUrl;
  final bool isActive;

  const StoreProduct({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.price,
    required this.oldPrice,
    required this.category,
    required this.icon,
    required this.badge,
    required this.stock,
    required this.cargoInfo,
    required this.warranty,
    required this.compatibility,
    required this.productCode,
    required this.features,
    required this.imageUrl,
    required this.isActive,
  });

  factory StoreProduct.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final category = StoreCategoryData.fromKey(
      readString(
        data,
        ['category', 'categoryKey', 'type'],
        fallback: 'all',
      ),
    );

    return StoreProduct(
      id: doc.id,
      title: readString(
        data,
        ['title', 'name', 'productName'],
        fallback: 'Ürün',
      ),
      subtitle: readString(
        data,
        ['subtitle', 'shortDescription'],
        fallback: '',
      ),
      description: readString(
        data,
        ['description', 'detail'],
        fallback: 'Ürün açıklaması eklenmemiş.',
      ),
      price: readInt(data, ['price', 'priceValue', 'salePrice']),
      oldPrice: readInt(data, ['oldPrice', 'discountPrice']),
      category: category,
      icon: iconFromKey(readString(data, ['icon', 'iconKey'])),
      badge: readString(data, ['badge', 'label'], fallback: 'Stokta'),
      stock: readInt(data, ['stock', 'stockCount']),
      cargoInfo: readString(
        data,
        ['cargoInfo', 'shippingInfo'],
        fallback: 'Kargo bilgisi yok',
      ),
      warranty: readString(
        data,
        ['warranty'],
        fallback: 'Garanti bilgisi yok',
      ),
      compatibility: readString(
        data,
        ['compatibility', 'compatible'],
        fallback: 'Uyumluluk bilgisi yok',
      ),
      productCode: readString(
        data,
        ['productCode', 'code', 'sku'],
        fallback: doc.id,
      ),
      features: readStringList(data['features']),
      imageUrl: readString(data, ['imageUrl', 'image', 'photoUrl']),
      isActive: readBool(data, ['isActive'], fallback: true),
    );
  }

  static String readString(
      Map<String, dynamic> data,
      List<String> keys, {
        String fallback = '',
      }) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  static int readInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      final clean = value.toString().replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(clean);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static bool readBool(
      Map<String, dynamic> data,
      List<String> keys, {
        bool fallback = false,
      }) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is bool) return value;
      final text = value.toString().toLowerCase();
      if (text == 'true') return true;
      if (text == 'false') return false;
    }
    return fallback;
  }

  static List<String> readStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty && e != 'null')
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  static IconData iconFromKey(String value) {
    final key = value.trim().toLowerCase();

    if (key.contains('oil') || key.contains('yag') || key.contains('yağ')) {
      return Icons.opacity_rounded;
    }
    if (key.contains('brake') || key.contains('fren')) {
      return Icons.disc_full_rounded;
    }
    if (key.contains('light') || key.contains('far') || key.contains('led')) {
      return Icons.lightbulb_rounded;
    }
    if (key.contains('phone') || key.contains('telefon')) {
      return Icons.phone_android_rounded;
    }
    if (key.contains('battery') || key.contains('aku') || key.contains('akü')) {
      return Icons.battery_charging_full_rounded;
    }
    if (key.contains('tire') || key.contains('lastik')) {
      return Icons.circle_rounded;
    }

    return Icons.settings_rounded;
  }
}
