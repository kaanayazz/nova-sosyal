import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StoreCartPage extends StatefulWidget {
  const StoreCartPage({super.key});

  @override
  State<StoreCartPage> createState() => _StoreCartPageState();
}

class _StoreCartPageState extends State<StoreCartPage> {
  CollectionReference<Map<String, dynamic>>? cartCollection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cart');
  }

  int subtotal(List<CartItem> items) {
    return items.fold(
      0,
          (total, item) => total + (item.price * item.quantity),
    );
  }

  int oldTotal(List<CartItem> items) {
    return items.fold(
      0,
          (total, item) {
        final oldPrice = item.oldPrice > 0 ? item.oldPrice : item.price;
        return total + (oldPrice * item.quantity);
      },
    );
  }

  int discount(List<CartItem> items) {
    final value = oldTotal(items) - subtotal(items);
    return value < 0 ? 0 : value;
  }

  int cargoPrice(List<CartItem> items) {
    if (items.isEmpty) return 0;
    if (subtotal(items) >= 1500) return 0;
    return 120;
  }

  int total(List<CartItem> items) => subtotal(items) + cargoPrice(items);

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

  Future<void> increaseItem(CartItem item) async {
    final ref = cartCollection();
    if (ref == null) return;

    await ref.doc(item.id).update({
      'quantity': item.quantity + 1,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> decreaseItem(CartItem item) async {
    final ref = cartCollection();
    if (ref == null) return;

    if (item.quantity <= 1) return;

    await ref.doc(item.id).update({
      'quantity': item.quantity - 1,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeItem(CartItem item) async {
    final ref = cartCollection();
    if (ref == null) return;

    await ref.doc(item.id).delete();
  }

  void checkout(List<CartItem> items) {
    if (items.isEmpty) {
      showMessage('Sepetin boş.');
      return;
    }

    showMessage('Ödeme sistemi daha sonra iyzico ile bağlanacak.');
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

  @override
  Widget build(BuildContext context) {
    final ref = cartCollection();

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Sepetim',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: ref == null
            ? const LoginRequiredCartView()
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ref.orderBy('updatedAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CartLoadingView();
            }

            if (snapshot.hasError) {
              return CartErrorView(
                error: snapshot.error.toString(),
                onRetry: () => setState(() {}),
              );
            }

            final cartItems = (snapshot.data?.docs ?? [])
                .map(CartItem.fromDoc)
                .where((item) => item.quantity > 0)
                .toList();

            if (cartItems.isEmpty) {
              return const EmptyCartView();
            }

            final subtotalValue = subtotal(cartItems);
            final discountValue = discount(cartItems);
            final cargoValue = cargoPrice(cartItems);
            final totalValue = total(cartItems);

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                    children: [
                      const CartInfoBanner(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Sepetteki Ürünler',
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
                            '${cartItems.length} ürün',
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...cartItems.map(
                            (item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CartProductCard(
                              item: item,
                              onIncrease: () => increaseItem(item),
                              onDecrease: () => decreaseItem(item),
                              onRemove: () => removeItem(item),
                              money: money,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      OrderNoteBox(
                        cargoText: cargoValue == 0
                            ? 'Kargo ücretsiz'
                            : '${money(cargoValue)} kargo ücreti',
                      ),
                      const SizedBox(height: 14),
                      CartSummaryBox(
                        subtotal: money(subtotalValue),
                        cargo: cargoValue == 0
                            ? 'Ücretsiz'
                            : money(cargoValue),
                        discount: money(discountValue),
                        total: money(totalValue),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
                CartBottomBar(
                  total: money(totalValue),
                  onTap: () => checkout(cartItems),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CartInfoBanner extends StatelessWidget {
  const CartInfoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.shopping_bag_rounded,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sepetini Kontrol Et',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Ürün adetlerini düzenleyip güvenli ödeme ile devam edebilirsin.',
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
    );
  }
}

class CartProductCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  final String Function(int value) money;

  const CartProductCard({
    super.key,
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final oldPrice = item.oldPrice > 0 ? item.oldPrice : item.price;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CartProductVisual(item: item),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        textScaler: TextScaler.noScaling,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.black54,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.subtitle,
                  textScaler: TextScaler.noScaling,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black45,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.productCode,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black38,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (oldPrice > item.price)
                            Text(
                              money(oldPrice),
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.black38,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            money(item.price),
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    QuantitySelector(
                      quantity: item.quantity,
                      onIncrease: onIncrease,
                      onDecrease: onDecrease,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CartProductVisual extends StatelessWidget {
  final CartItem item;

  const CartProductVisual({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    if (item.imageUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.network(
          item.imageUrl,
          width: 82,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CartIconBox(item: item),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return CartIconBox(item: item);
          },
        ),
      );
    }

    return CartIconBox(item: item);
  }
}

class CartIconBox extends StatelessWidget {
  final CartItem item;

  const CartIconBox({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(
        item.icon,
        color: Colors.white,
        size: 40,
      ),
    );
  }
}

class QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrease,
            child: const SizedBox(
              width: 30,
              height: 30,
              child: Icon(
                Icons.remove_rounded,
                color: Colors.black,
                size: 18,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              quantity.toString(),
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          GestureDetector(
            onTap: onIncrease,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderNoteBox extends StatelessWidget {
  final String cargoText;

  const OrderNoteBox({
    super.key,
    required this.cargoText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.green.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_rounded,
            color: Colors.green,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cargoText,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.green,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CartSummaryBox extends StatelessWidget {
  final String subtotal;
  final String cargo;
  final String discount;
  final String total;

  const CartSummaryBox({
    super.key,
    required this.subtotal,
    required this.cargo,
    required this.discount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.045),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          SummaryRow(title: 'Ara Toplam', value: subtotal),
          const SizedBox(height: 10),
          SummaryRow(title: 'İndirim', value: discount),
          const SizedBox(height: 10),
          SummaryRow(title: 'Kargo', value: cargo),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1, color: Colors.black12),
          ),
          SummaryRow(title: 'Genel Toplam', value: total, isTotal: true),
        ],
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isTotal;

  const SummaryRow({
    super.key,
    required this.title,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: isTotal ? Colors.black : Colors.black54,
              fontSize: isTotal ? 16 : 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          value,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: Colors.black,
            fontSize: isTotal ? 22 : 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class CartBottomBar extends StatelessWidget {
  final String total;
  final VoidCallback onTap;

  const CartBottomBar({
    super.key,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.045),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security_rounded, color: Colors.black),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bu sistem ileride iyzico Checkout Form altyapısına bağlanacaktır.',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.black54,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Genel Toplam',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black45,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        total,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.lock_rounded),
                    label: const Text(
                      'iyzico ile Devam Et',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyCartView extends StatelessWidget {
  const EmptyCartView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              color: Colors.black26,
              size: 84,
            ),
            SizedBox(height: 18),
            Text(
              'Sepetin boş',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Ürünleri sepete eklediğinde burada listelenecek.',
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

class LoginRequiredCartView extends StatelessWidget {
  const LoginRequiredCartView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: Colors.black26,
              size: 84,
            ),
            SizedBox(height: 18),
            Text(
              'Giriş gerekli',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Sepeti görüntülemek için hesabına giriş yapmalısın.',
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

class CartLoadingView extends StatelessWidget {
  const CartLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Colors.black),
    );
  }
}

class CartErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const CartErrorView({
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
              'Sepet yüklenemedi',
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

class CartItem {
  final String id;
  final String productId;
  final String title;
  final String subtitle;
  final int price;
  final int oldPrice;
  final int quantity;
  final IconData icon;
  final String productCode;
  final String imageUrl;
  final String category;

  const CartItem({
    required this.id,
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.oldPrice,
    required this.quantity,
    required this.icon,
    required this.productCode,
    required this.imageUrl,
    required this.category,
  });

  factory CartItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    return CartItem(
      id: doc.id,
      productId: readString(data, ['productId'], fallback: doc.id),
      title: readString(data, ['title'], fallback: 'Ürün'),
      subtitle: readString(data, ['subtitle'], fallback: ''),
      price: readInt(data, ['price']),
      oldPrice: readInt(data, ['oldPrice']),
      quantity: readInt(data, ['quantity'], fallback: 1),
      icon: iconFromCategory(readString(data, ['category', 'icon'])),
      productCode: readString(data, ['productCode', 'code'], fallback: doc.id),
      imageUrl: readString(data, ['imageUrl', 'image']),
      category: readString(data, ['category']),
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

  static int readInt(
      Map<String, dynamic> data,
      List<String> keys, {
        int fallback = 0,
      }) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      final clean = value.toString().replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(clean);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static IconData iconFromCategory(String value) {
    final key = value.trim().toLowerCase();

    if (key.contains('spare') ||
        key.contains('yedek') ||
        key.contains('settings')) {
      return Icons.settings_rounded;
    }

    if (key.contains('access') ||
        key.contains('aksesuar') ||
        key.contains('phone')) {
      return Icons.auto_awesome_rounded;
    }

    if (key.contains('oil') || key.contains('yağ') || key.contains('yag')) {
      return Icons.opacity_rounded;
    }

    if (key.contains('fren') || key.contains('brake')) {
      return Icons.disc_full_rounded;
    }

    return Icons.shopping_bag_rounded;
  }
}
