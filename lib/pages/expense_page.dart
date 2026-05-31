import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage>
    with SingleTickerProviderStateMixin {
  String selectedFilter = "Aylık";
  String selectedCarId = "";

  late final AnimationController neonController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _carsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _expensesSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  final List<NovaCar> cars = [];
  final List<NovaExpense> expenses = [];

  bool pageLoading = true;
  bool showExpensesOnProfile = false;

  @override
  void initState() {
    super.initState();

    neonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _listenFirebaseData();
  }

  @override
  void dispose() {
    _carsSub?.cancel();
    _expensesSub?.cancel();
    _profileSub?.cancel();
    neonController.dispose();
    super.dispose();
  }


  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _carsRef {
    final uid = currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('expenseCars');
  }

  CollectionReference<Map<String, dynamic>>? get _expensesRef {
    final uid = currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('expenses');
  }

  DocumentReference<Map<String, dynamic>>? get _profileRef {
    final uid = currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  void _listenFirebaseData() {
    final carsRef = _carsRef;
    final expensesRef = _expensesRef;
    final profileRef = _profileRef;

    if (carsRef == null || expensesRef == null || profileRef == null) {
      setState(() => pageLoading = false);
      return;
    }

    _profileSub = profileRef.snapshots().listen((doc) {
      final data = doc.data() ?? {};
      if (!mounted) return;
      setState(() {
        showExpensesOnProfile = data['showExpensesOnProfile'] == true;
      });
    });

    _carsSub = carsRef.orderBy('createdAt', descending: false).snapshots().listen(
          (snapshot) {
        final loadedCars = snapshot.docs.map((doc) {
          return NovaCar.fromFirestore(doc.id, doc.data());
        }).toList();

        if (!mounted) return;
        setState(() {
          cars
            ..clear()
            ..addAll(loadedCars);

          if (cars.isNotEmpty &&
              (selectedCarId.isEmpty || !cars.any((car) => car.id == selectedCarId))) {
            selectedCarId = cars.firstWhere(
                  (car) => car.isFavorite,
              orElse: () => cars.first,
            ).id;
          }

          if (cars.isEmpty) selectedCarId = "";
          pageLoading = false;
        });
      },
      onError: (_) {
        if (mounted) setState(() => pageLoading = false);
      },
    );

    _expensesSub = expensesRef.orderBy('date', descending: true).snapshots().listen(
          (snapshot) {
        final loadedExpenses = snapshot.docs.map((doc) {
          return NovaExpense.fromFirestore(doc.id, doc.data());
        }).toList();

        if (!mounted) return;
        setState(() {
          expenses
            ..clear()
            ..addAll(loadedExpenses);
        });
      },
    );
  }

  Future<void> refreshFirebaseData() async {
    _carsSub?.cancel();
    _expensesSub?.cancel();
    _profileSub?.cancel();

    if (mounted) {
      setState(() {
        pageLoading = true;
        cars.clear();
        expenses.clear();
        selectedCarId = "";
      });
    }

    _listenFirebaseData();

    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted) {
      setState(() {
        pageLoading = false;
      });
    }
  }

  Future<void> saveCar(NovaCar car) async {
    final ref = _carsRef;
    if (ref == null) return;

    await ref.doc(car.id).set(car.toFirestore(), SetOptions(merge: true));
  }

  Future<void> removeCarFromFirebase(NovaCar car) async {
    final carsRef = _carsRef;
    final expensesRef = _expensesRef;
    if (carsRef == null || expensesRef == null || car.id.isEmpty) return;

    final carExpenses = await expensesRef.where('carId', isEqualTo: car.id).get();
    final batch = _firestore.batch();

    for (final doc in carExpenses.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(carsRef.doc(car.id));
    await batch.commit();
  }

  Future<void> deleteCar(NovaCar car) async {
    if (car.id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            "Araç silinsin mi?",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontFamily: "Roboto",
            ),
          ),
          content: Text(
            "${car.name} aracı ve bu araca ait masraf kayıtları silinecek.",
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontFamily: "Roboto",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Vazgeç",
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Roboto",
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Sil",
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w900,
                  fontFamily: "Roboto",
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await removeCarFromFirebase(car);

    if (!mounted) return;
    setState(() {
      if (selectedCarId == car.id) selectedCarId = "";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Araç silindi."),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> saveExpense(NovaExpense expense) async {
    final ref = _expensesRef;
    final uid = currentUserId;
    if (ref == null || uid == null) return;

    await ref.doc(expense.id).set(expense.toFirestore(), SetOptions(merge: true));

    if (expense.reminderEnabled && expense.reminderDate != null) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenseReminders')
          .doc(expense.id)
          .set({
        'expenseId': expense.id,
        'carId': expense.carId,
        'title': expense.title,
        'category': expense.category,
        'reminderAt': Timestamp.fromDate(expense.reminderDate!),
        'reminderAtText': expense.reminderDate!.toIso8601String(),
        'note': expense.reminderNote,
        'notificationTitle': 'NOVA Hatırlatma',
        'notificationBody': expense.reminderNote.trim().isEmpty
            ? '${expense.title} için hatırlatma zamanı yaklaşıyor.'
            : expense.reminderNote,
        'pushShouldSend': true,
        'type': 'expense_reminder',
        'isDone': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenseReminders')
          .doc(expense.id)
          .delete()
          .catchError((_) {});
    }
  }

  Future<void> removeExpenseFromFirebase(NovaExpense expense) async {
    final ref = _expensesRef;
    final uid = currentUserId;
    if (ref == null) return;

    await ref.doc(expense.id).delete();
    if (uid != null) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenseReminders')
          .doc(expense.id)
          .delete()
          .catchError((_) {});
    }
  }

  Future<void> updateProfileExpenseVisibility(bool value) async {
    final ref = _profileRef;
    if (ref == null) return;

    await ref.set({
      'showExpensesOnProfile': value,
      'expenseProfileCard': value
          ? {
        'visible': true,
        'selectedCarName': selectedCar.name,
        'selectedCarPlate': selectedCar.plate,
        'selectedPeriod': selectedFilter,
        'totalExpense': totalExpense,
        'allCarTotal': allCarTotal,
        'averageExpense': averageExpense,
        'recordCount': filteredExpenses.length,
        'biggestCategory': biggestCategory,
        'updatedAt': FieldValue.serverTimestamp(),
      }
          : {
        'visible': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<NovaExpense> get filteredExpenses {
    final now = DateTime.now();

    return expenses.where((e) {
      if (e.carId != selectedCarId) return false;

      if (selectedFilter == "Haftalık") {
        return e.date.isAfter(now.subtract(const Duration(days: 7)));
      }

      if (selectedFilter == "Aylık") {
        return e.date.isAfter(now.subtract(const Duration(days: 30)));
      }

      return e.date.isAfter(now.subtract(const Duration(days: 365)));
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  double get totalExpense {
    return filteredExpenses.fold(0, (sum, item) => sum + item.price);
  }

  double get allCarTotal {
    return expenses.fold(0, (sum, item) => sum + item.price);
  }

  double get averageExpense {
    if (filteredExpenses.isEmpty) return 0;
    return totalExpense / filteredExpenses.length;
  }

  List<NovaExpense> get receiptExpenses {
    return filteredExpenses.where((expense) => expense.hasReceiptImage).toList();
  }

  List<NovaExpense> get fuelReceiptExpenses {
    return filteredExpenses
        .where((expense) =>
    expense.category == "Yakıt" && expense.hasReceiptImage)
        .toList();
  }

  NovaCar get selectedCar {
    if (cars.isEmpty) {
      return NovaCar(
        id: "",
        name: "Araç eklenmedi",
        plate: "Önce araç ekle",
        isFavorite: false,
        color1: Colors.black,
        color2: Colors.black,
        imageUrl: "",
        imageFileName: "",
      );
    }

    return cars.firstWhere(
          (car) => car.id == selectedCarId,
      orElse: () => cars.first,
    );
  }

  Map<String, double> get categoryTotals {
    final Map<String, double> data = {};

    for (final expense in filteredExpenses) {
      data[expense.category] = (data[expense.category] ?? 0) + expense.price;
    }

    return data;
  }

  String get biggestCategory {
    if (categoryTotals.isEmpty) return "Veri yok";

    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  List<ChartPoint> get chartPoints {
    if (selectedFilter == "Haftalık") {
      return List.generate(7, (index) {
        final day = DateTime.now().subtract(Duration(days: 6 - index));
        final total = filteredExpenses
            .where(
              (e) =>
          e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day,
        )
            .fold(0.0, (sum, item) => sum + item.price);

        return ChartPoint(
          label: "${day.day}.${day.month}",
          title: "Günlük Gider",
          total: total,
        );
      });
    }

    if (selectedFilter == "Aylık") {
      return List.generate(4, (index) {
        final now = DateTime.now();
        final start = now.subtract(Duration(days: (3 - index) * 7 + 6));
        final end = now.subtract(Duration(days: (3 - index) * 7));

        final total = filteredExpenses.where((e) {
          return e.date.isAfter(start.subtract(const Duration(days: 1))) &&
              e.date.isBefore(end.add(const Duration(days: 1)));
        }).fold(0.0, (sum, item) => sum + item.price);

        return ChartPoint(
          label: "${index + 1}. Hafta",
          title: "Haftalık Gider",
          total: total,
        );
      });
    }

    return List.generate(12, (index) {
      final now = DateTime.now();
      final month = DateTime(now.year, index + 1, 1);

      final total = filteredExpenses
          .where((e) => e.date.year == month.year && e.date.month == month.month)
          .fold(0.0, (sum, item) => sum + item.price);

      return ChartPoint(
        label: monthName(index + 1),
        title: "Aylık Gider",
        total: total,
      );
    });
  }

  static String monthName(int month) {
    const months = [
      "Oca",
      "Şub",
      "Mar",
      "Nis",
      "May",
      "Haz",
      "Tem",
      "Ağu",
      "Eyl",
      "Eki",
      "Kas",
      "Ara",
    ];

    return months[month - 1];
  }

  String formatMoney(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => "${match[1]}.",
    );
  }

  void openAddExpenseSheet({NovaExpense? expense}) {
    if (selectedCarId.isEmpty && expense == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Masraf eklemek için önce araç ekle."),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) {
          return AddExpenseSheet(
            carId: selectedCarId,
            expense: expense,
            onSave: (savedExpense) async {
              await saveExpense(savedExpense);
            },
          );
        },
      ),
    );
  }

  Future<bool> hasCompletedProfileForCar() async {
    final ref = _profileRef;
    if (ref == null) return false;

    try {
      final snap = await ref.get();
      final data = snap.data() ?? <String, dynamic>{};
      final username = (data['username'] ?? '').toString().trim();
      final fullName = (data['fullName'] ?? data['displayName'] ?? data['name'] ?? '').toString().trim();
      final city = (data['city'] ?? data['province'] ?? data['il'] ?? '').toString().trim();
      final district = (data['district'] ?? data['ilce'] ?? '').toString().trim();
      return username.isNotEmpty && fullName.isNotEmpty && city.isNotEmpty && district.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAddCarSheet() async {
    final ok = await hasCompletedProfileForCar();
    if (!ok) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Text(
              "Profil bilgileri eksik",
              style: TextStyle(fontFamily: "Roboto", fontWeight: FontWeight.w900),
            ),
            content: const Text(
              "Araç eklemek için profil düzenle bölümünden ad, kullanıcı adı, il ve ilçe bilgilerini tamamlaman gerekiyor.",
              style: TextStyle(fontFamily: "Roboto", fontWeight: FontWeight.w700),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Tamam"),
              ),
            ],
          );
        },
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) {
          return AddCarSheet(
            onAdd: (car) async {
              selectedCarId = car.id;
              await saveCar(car);
            },
          );
        },
      ),
    );
  }

  void openCarPicker() {
    if (cars.isEmpty) {
      openAddCarSheet();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return NovaBottomSheet(
          title: "Araç Seç",
          child: Column(
            children: cars.map((car) {
              final selected = car.id == selectedCarId;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCarId = car.id;
                  });

                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? Colors.black : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? Colors.black : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      NovaCarAvatar(
                        car: car,
                        controller: neonController,
                        size: 44,
                        iconSize: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              car.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              car.plate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white.withOpacity(0.60)
                                    : Colors.black54,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (car.isFavorite)
                        Icon(
                          Icons.star_rounded,
                          color: selected ? Colors.white : const Color(0xFFFF7A00),
                        ),
                      if (selected)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                          ),
                        ),
                      IconButton(
                        tooltip: "Aracı Sil",
                        onPressed: () {
                          Navigator.pop(context);
                          deleteCar(car);
                        },
                        icon: Icon(
                          Icons.delete_rounded,
                          color: selected
                              ? Colors.white.withOpacity(0.85)
                              : const Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> deleteExpense(NovaExpense expense) async {
    await removeExpenseFromFirebase(expense);
  }

  void openChartDetail(ChartPoint point) {
    final maxTotal = chartPoints.map((e) => e.total).fold(0.0, max);
    final percent = maxTotal == 0 ? 0.0 : point.total / maxTotal;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return NovaBottomSheet(
          title: "Grafik Detayı",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetLabel("Dönem"),
              const SizedBox(height: 8),
              Text(
                point.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Roboto",
                ),
              ),
              const SizedBox(height: 18),
              const SheetLabel("Toplam Masraf"),
              const SizedBox(height: 8),
              Text(
                "${formatMoney(point.total)} TL",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Roboto",
                ),
              ),
              const SizedBox(height: 18),
              const SheetLabel("Grafik Yoğunluğu"),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Container(
                      height: 14,
                      color: Colors.black.withOpacity(0.07),
                    ),
                    FractionallySizedBox(
                      widthFactor: percent.clamp(0, 1),
                      child: Container(
                        height: 14,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFFF2E88),
                              Color(0xFF7C4DFF),
                              Color(0xFF3C7BFF),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                point.total == 0
                    ? "Bu dönem için kayıtlı masraf yok."
                    : "Bu dönem, seçili grafikte ${(percent * 100).toStringAsFixed(0)}% yoğunluğa sahip.",
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  fontFamily: "Roboto",
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void openExpenseDetail(NovaExpense expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return NovaBottomSheet(
          title: "Masraf Detayı",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: expense.color.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(expense.icon, color: expense.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      expense.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: "Roboto",
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              DetailLine(title: "Kategori", value: expense.category),
              DetailLine(title: "Tutar", value: "${formatMoney(expense.price)} TL"),
              DetailLine(
                title: "Tarih",
                value:
                "${expense.date.day}.${expense.date.month}.${expense.date.year}",
              ),
              if (expense.note.isNotEmpty)
                DetailLine(title: "Not", value: expense.note),
              if (expense.hasReceiptImage) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    expense.receiptImageUrl,
                    height: 210,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const EmptyNovaBox(
                      text: "Fatura görseli yüklenemedi.",
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: BottomActionButton(
                      title: "Düzenle",
                      icon: Icons.edit_rounded,
                      color: Colors.black,
                      onTap: () {
                        Navigator.pop(context);
                        openAddExpenseSheet(expense: expense);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BottomActionButton(
                      title: "Sil",
                      icon: Icons.delete_rounded,
                      color: const Color(0xFFE53935),
                      onTap: () {
                        Navigator.pop(context);
                        deleteExpense(expense);
                      },
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

  void openShareExpenseWithFriendSheet() {
    if (filteredExpenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Paylaşılacak masraf kaydı yok.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ShareExpenseWithFriendPage(
          expenses: filteredExpenses,
          car: selectedCar,
          formatMoney: formatMoney,
          onSend: sendExpenseToFriend,
        ),
      ),
    );
  }

  Future<void> sendExpenseToFriend({
    required NovaExpense expense,
    required String receiverText,
    required String note,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final cleanReceiver = receiverText.trim();
    if (cleanReceiver.isEmpty) return;

    await _firestore.collection('users').doc(uid).collection('sharedExpenses').add({
      'expenseId': expense.id,
      'carId': expense.carId,
      'carName': selectedCar.name,
      'carPlate': selectedCar.plate,
      'title': expense.title,
      'category': expense.category,
      'price': expense.price,
      'note': note.trim(),
      'receiverText': cleanReceiver,
      'senderId': uid,
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void openPenaltyWarningPostPage() {
    final uid = currentUserId;
    if (uid == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PenaltyWarningPostPage(
          car: selectedCar,
          onShare: publishPenaltyWarningPost,
        ),
      ),
    );
  }

  Future<void> publishPenaltyWarningPost({
    required double penaltyAmount,
    required String description,
    required List<String> imageUrls,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    if (imageUrls.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ceza paylaşımı için en az 1 görsel seçmelisin.")),
      );
      return;
    }

    final userSnap = await _firestore.collection('users').doc(uid).get();
    final user = userSnap.data() ?? <String, dynamic>{};
    final username = (user['username'] ?? '').toString().replaceAll('@', '').trim();
    final displayName = (user['displayName'] ?? user['fullName'] ?? user['name'] ?? '').toString().trim();
    final userPhoto = (user['photoUrl'] ??
        user['profileImage'] ??
        user['profileImageUrl'] ??
        user['userPhoto'] ??
        '')
        .toString()
        .trim();

    final title = "Ceza yedim, dikkat edin";
    final body = description.trim().isEmpty
        ? "${selectedCar.name} için ${formatMoney(penaltyAmount)} TL ceza kaydı paylaşıldı. Bu bölgeden geçenler dikkatli olsun."
        : description.trim();

    await _firestore.collection('posts').add({
      'type': 'expense_penalty_warning',
      'ownerId': uid,
      'userId': uid,
      'uid': uid,
      'username': username.isEmpty ? 'nova.user' : username,
      'displayName': displayName,
      'userPhoto': userPhoto,
      'photoUrl': userPhoto,
      'title': title,
      'caption': body,
      'text': body,
      'description': body,
      'carName': selectedCar.name,
      'carPlate': selectedCar.plate,
      'penaltyAmount': penaltyAmount,
      'penaltyAmountText': "${formatMoney(penaltyAmount)} TL",
      'expenseCategory': 'Ceza',
      'imageUrl': imageUrls.first,
      'postImageUrl': imageUrls.first,
      'images': imageUrls,
      'imageUrls': imageUrls,
      'mediaUrls': imageUrls,
      'imageCount': imageUrls.length,
      'likeCount': 0,
      'commentCount': 0,
      'shareCount': 0,
      'likedBy': <String>[],
      'savedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ceza uyarısı görsellerle ana sayfada paylaşıldı.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            const NovaWhiteBackground(),
            SafeArea(
              child: RefreshIndicator(
                color: Colors.black,
                backgroundColor: Colors.white,
                onRefresh: refreshFirebaseData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (pageLoading) ...[
                              const LoadingExpensePanel(),
                              const SizedBox(height: 12),
                            ],
                            buildActionButtons(),
                            const SizedBox(height: 12),
                            buildProfileVisibilityCard(),
                            const SizedBox(height: 12),
                            buildCarPickerButton(),
                            const SizedBox(height: 16),
                            buildFilterTabs(),
                            const SizedBox(height: 16),
                            buildTotalCard(),
                            const SizedBox(height: 16),
                            buildAnalysisGrid(),
                            const SizedBox(height: 16),
                            buildDetailedChart(),
                            const SizedBox(height: 16),
                            buildCategoryBars(),
                            const SizedBox(height: 16),
                            buildVehicleSystemHub(),
                            const SizedBox(height: 16),
                            buildFuelIntelligencePanel(),
                            const SizedBox(height: 16),
                            buildKmAveragePanel(),
                            const SizedBox(height: 16),
                            buildSharedExpensePanel(),
                            const SizedBox(height: 16),
                            buildPenaltySharePanel(),
                            const SizedBox(height: 16),
                            buildMaintenanceReminderPanel(),
                            const SizedBox(height: 16),
                            buildReminderCenterPanel(),
                            const SizedBox(height: 16),
                            buildDocumentVaultPanel(),
                            const SizedBox(height: 16),
                            buildSmartNovaAnalysisPanel(),
                            const SizedBox(height: 16),
                            buildReceiptGallery(),
                            const SizedBox(height: 16),
                            buildRecentExpenses(),
                            const SizedBox(height: 28),
                          ],
                        ),
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


  Widget buildProfileVisibilityCard() {
    return PlainCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_circle_rounded,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Profilde Göster",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    fontFamily: "Roboto",
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "Açınca profilinde neon fatura kutusu için özet veriler hazırlanır.",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    fontFamily: "Roboto",
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: showExpensesOnProfile,
            activeColor: Colors.black,
            onChanged: (value) {
              setState(() => showExpensesOnProfile = value);
              updateProfileExpenseVisibility(value);
            },
          ),
        ],
      ),
    );
  }

  Widget buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: NovaActionButton(
            title: "Masraf Ekle",
            icon: Icons.add_rounded,
            controller: neonController,
            onTap: () => openAddExpenseSheet(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: NovaActionButton(
            title: "Araç Ekle",
            icon: Icons.directions_car_filled_rounded,
            controller: neonController,
            onTap: openAddCarSheet,
          ),
        ),
      ],
    );
  }

  Widget buildCarPickerButton() {
    return GestureDetector(
      onTap: openCarPicker,
      child: PlainCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            NovaCarAvatar(
              car: selectedCar,
              controller: neonController,
              size: 46,
              iconSize: 23,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedCar.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      fontFamily: "Roboto",
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedCar.plate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      fontFamily: "Roboto",
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              "Araç Seç",
              maxLines: 1,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                fontFamily: "Roboto",
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFilterTabs() {
    final filters = ["Haftalık", "Aylık", "Yıllık"];

    return PlainCard(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: filters.map((filter) {
          final selected = selectedFilter == filter;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedFilter = filter;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  color: selected ? Colors.black : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    filter,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      fontFamily: "Roboto",
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildTotalCard() {
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.black),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Toplam Gider",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Roboto",
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  selectedFilter,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Roboto",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              "${formatMoney(totalExpense)} TL",
              style: const TextStyle(
                color: Colors.black,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
                fontFamily: "Roboto",
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${selectedCar.name} için seçili dönem masraf analizi",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: "Roboto",
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: NovaSmallInfo(
                  title: "Tüm Araçlar",
                  value: "${formatMoney(allCarTotal)} TL",
                  icon: Icons.directions_car_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NovaSmallInfo(
                  title: "Ortalama",
                  value: "${formatMoney(averageExpense)} TL",
                  icon: Icons.analytics_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildAnalysisGrid() {
    return Row(
      children: [
        Expanded(
          child: MiniAnalysisCard(
            icon: Icons.trending_up_rounded,
            title: "En Çok Gider",
            value: biggestCategory,
            color: const Color(0xFFFF2E88),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MiniAnalysisCard(
            icon: Icons.fact_check_rounded,
            title: "Kayıt Sayısı",
            value: "${filteredExpenses.length} işlem",
            color: const Color(0xFF3C7BFF),
          ),
        ),
      ],
    );
  }

  Widget buildDetailedChart() {
    final points = chartPoints;
    final maxTotal = points.map((e) => e.total).fold(0.0, max);

    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Gider Grafiği",
            subtitle: "Grafikte her sütuna tıklayıp detayını görebilirsin.",
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 158,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / points.length;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: points.map((point) {
                    final percent = maxTotal == 0 ? 0.08 : point.total / maxTotal;
                    final height = 28.0 + (percent * 82);

                    return SizedBox(
                      width: itemWidth,
                      child: GestureDetector(
                        onTap: () => openChartDetail(point),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                height: 14,
                                width: double.infinity,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    point.total == 0
                                        ? "-"
                                        : formatMoney(point.total),
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                      fontFamily: "Roboto",
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: double.infinity,
                                height: height.clamp(28, 116),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: Colors.black,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF2E88)
                                          .withOpacity(0.16),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 14,
                                width: double.infinity,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    point.label,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                      fontFamily: "Roboto",
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCategoryBars() {
    final data = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Kategori Dağılımı",
            subtitle: "Masrafların hangi alana gittiğini gör.",
          ),
          const SizedBox(height: 18),
          if (data.isEmpty)
            const EmptyNovaBox(text: "Bu filtrede henüz masraf yok.")
          else
            Column(
              children: data.map((entry) {
                final percent =
                totalExpense == 0 ? 0.0 : entry.value / totalExpense;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CategoryBar(
                    title: entry.key,
                    price: entry.value,
                    percent: percent,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget buildReceiptGallery() {
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Fatura ve Yakıt Fişleri",
            subtitle:
            "Kamera veya galeriyle eklediğin fatura ve benzin fişleri burada listelenir.",
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: NovaSmallInfo(
                  title: "Tüm Fişler",
                  value: "${receiptExpenses.length} görsel",
                  icon: Icons.image_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NovaSmallInfo(
                  title: "Yakıt Fişleri",
                  value: "${fuelReceiptExpenses.length} görsel",
                  icon: Icons.local_gas_station_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (receiptExpenses.isEmpty)
            const EmptyNovaBox(
              text:
              "Henüz fatura veya yakıt fişi görseli yok. Masraf eklerken kamera/galeriyle görsel yükleyebilirsin.",
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: receiptExpenses.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final expense = receiptExpenses[index];
                return ReceiptGalleryCard(
                  expense: expense,
                  onTap: () => openExpenseDetail(expense),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget buildRecentExpenses() {
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Kayıtlı Masraflar",
            subtitle:
            "En yeni kayıt en üstte görünür. Düzenleyebilir veya silebilirsin.",
          ),
          const SizedBox(height: 16),
          if (filteredExpenses.isEmpty)
            const EmptyNovaBox(text: "Henüz masraf kaydı bulunmuyor.")
          else
            Column(
              children: filteredExpenses.map((expense) {
                return ExpenseTile(
                  expense: expense,
                  onTap: () => openExpenseDetail(expense),
                  onEdit: () => openAddExpenseSheet(expense: expense),
                  onDelete: () => deleteExpense(expense),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }



  Widget buildVehicleSystemHub() {
    final carCount = cars.length;
    final currentCarExpenseCount = expenses.where((e) => e.carId == selectedCarId).length;
    final allReceiptCount = expenses.where((e) => e.hasReceiptImage).length;
    final fuelCount = expenses.where((e) => e.category == "Yakıt").length;

    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Araç Maliyet Yönetimi",
            subtitle: "Araç, yakıt, bakım, evrak, hatırlatma ve analiz tek merkezde.",
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Araç", value: "$carCount kayıt", icon: Icons.directions_car_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "Seçili Araç", value: "$currentCarExpenseCount işlem", icon: Icons.fact_check_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Yakıt", value: "$fuelCount kayıt", icon: Icons.local_gas_station_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "Evrak/Fiş", value: "$allReceiptCount görsel", icon: Icons.folder_copy_rounded)),
            ],
          ),
          const SizedBox(height: 14),
          const NovaSystemNoteBox(
            icon: Icons.verified_rounded,
            title: "Müşteri modu hazır",
            text: "Kullanıcı arabasını ekler, masrafını/faturasını kaydeder, NOVA otomatik analiz çıkarır.",
          ),
        ],
      ),
    );
  }

  Widget buildFuelIntelligencePanel() {
    final fuelItems = filteredExpenses.where((e) => e.category == "Yakıt").toList();
    final fuelTotal = fuelItems.fold(0.0, (sum, e) => sum + e.price);
    final fuelShare = totalExpense == 0 ? 0.0 : fuelTotal / totalExpense;
    final monthlyEstimate = selectedFilter == "Haftalık" ? fuelTotal * 4 : selectedFilter == "Aylık" ? fuelTotal : fuelTotal / 12;
    final yearlyEstimate = selectedFilter == "Yıllık" ? fuelTotal : monthlyEstimate * 12;

    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Yakıt Zekası",
            subtitle: "Yakıt giderlerini otomatik ayrıştırır ve tahmini maliyet çıkarır.",
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Yakıt Toplam", value: "${formatMoney(fuelTotal)} TL", icon: Icons.local_gas_station_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "Pay", value: "%${(fuelShare * 100).toStringAsFixed(0)}", icon: Icons.pie_chart_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Aylık Tahmin", value: "${formatMoney(monthlyEstimate)} TL", icon: Icons.calendar_month_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "Yıllık Tahmin", value: "${formatMoney(yearlyEstimate)} TL", icon: Icons.insights_rounded)),
            ],
          ),
          const SizedBox(height: 14),
          NovaProgressLine(title: "Yakıt gider oranı", percent: fuelShare, value: "${(fuelShare * 100).toStringAsFixed(0)}%"),
        ],
      ),
    );
  }

  Widget buildMaintenanceReminderPanel() {
    final maintenanceItems = filteredExpenses.where((e) => e.category == "Bakım" || e.category == "Muayene" || e.category == "Sigorta").toList();
    final lastMaintenance = maintenanceItems.isEmpty ? null : maintenanceItems.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    final nextSoftReminder = lastMaintenance == null ? null : lastMaintenance.date.add(const Duration(days: 180));
    final remainingDays = nextSoftReminder == null ? null : nextSoftReminder.difference(DateTime.now()).inDays;

    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Bakım ve Hatırlatmalar",
            subtitle: "Yağ bakımı, muayene, sigorta ve kasko için takip merkezi.",
          ),
          const SizedBox(height: 16),
          if (lastMaintenance == null)
            const EmptyNovaBox(text: "Henüz bakım, muayene veya sigorta kaydı yok. İlk kayıt sonrası NOVA hatırlatma üretir.")
          else ...[
            NovaSystemNoteBox(
              icon: Icons.build_rounded,
              title: "Son işlem: ${lastMaintenance.title}",
              text: "${lastMaintenance.date.day}.${lastMaintenance.date.month}.${lastMaintenance.date.year} tarihinde ${formatMoney(lastMaintenance.price)} TL kayıt girildi.",
            ),
            const SizedBox(height: 12),
            NovaSystemNoteBox(
              icon: Icons.notifications_active_rounded,
              title: remainingDays == null ? "Hatırlatma hazırlanıyor" : remainingDays >= 0 ? "Yaklaşık $remainingDays gün kaldı" : "Bakım zamanı geçmiş olabilir",
              text: "Müşteri isterse bu alan telefon bildirim sistemine bağlanıp bakım zamanı yaklaşınca uyarı verir.",
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              NovaMiniTag(text: "Yağ"),
              NovaMiniTag(text: "Triger"),
              NovaMiniTag(text: "Fren"),
              NovaMiniTag(text: "Lastik"),
              NovaMiniTag(text: "Muayene"),
              NovaMiniTag(text: "Sigorta"),
              NovaMiniTag(text: "Kasko"),
              NovaMiniTag(text: "Akü"),
            ],
          ),
        ],
      ),
    );
  }


  Widget buildKmAveragePanel() {
    final selectedExpenses = expenses.where((e) => e.carId == selectedCarId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final kmItems = selectedExpenses.where((e) => e.odometerKm > 0).toList();
    final fuelItems = selectedExpenses.where((e) => e.category == "Yakıt").toList();
    final totalFuel = fuelItems.fold(0.0, (sum, e) => sum + e.price);
    final totalLiters = fuelItems.fold(0.0, (sum, e) => sum + e.fuelLiters);
    final firstKm = kmItems.isEmpty ? 0 : kmItems.first.odometerKm;
    final lastKm = kmItems.length < 2 ? 0 : kmItems.last.odometerKm;
    final drivenKm = lastKm > firstKm ? lastKm - firstKm : 0;
    final costPerKm = drivenKm <= 0 ? 0.0 : totalFuel / drivenKm;
    final literPer100 = drivenKm <= 0 || totalLiters <= 0 ? 0.0 : (totalLiters / drivenKm) * 100;

    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "KM ve Ortalama Analizi",
            subtitle: "KM, litre ve yakıt kayıtlarından aracın gerçek kullanım maliyetini hesaplar.",
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Toplam KM", value: drivenKm <= 0 ? "Veri yok" : "$drivenKm km", icon: Icons.route_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "KM Başına", value: costPerKm <= 0 ? "-" : "${costPerKm.toStringAsFixed(2)} TL", icon: Icons.speed_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Yakıt Litre", value: totalLiters <= 0 ? "Veri yok" : "${totalLiters.toStringAsFixed(1)} L", icon: Icons.local_gas_station_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "100 KM Ort.", value: literPer100 <= 0 ? "-" : "${literPer100.toStringAsFixed(1)} L", icon: Icons.analytics_rounded)),
            ],
          ),
          const SizedBox(height: 14),
          NovaSystemNoteBox(
            icon: Icons.info_rounded,
            title: drivenKm <= 0 ? "KM verisi bekleniyor" : "Gerçek maliyet hazır",
            text: drivenKm <= 0
                ? "Masraf eklerken KM alanını doldurursan NOVA km başına maliyet ve yakıt ortalamasını otomatik çıkarır."
                : "${selectedCar.name} için yakıt maliyeti yaklaşık ${costPerKm.toStringAsFixed(2)} TL/km olarak hesaplandı.",
          ),
        ],
      ),
    );
  }

  Widget buildSharedExpensePanel() {
    final sharedItems = filteredExpenses.where((e) => e.sharedWithText.trim().isNotEmpty || e.sharedTotalPeople > 1).toList();
    final sharedTotal = sharedItems.fold(0.0, (sum, e) => sum + e.price);
    final myShare = sharedItems.fold(0.0, (sum, e) {
      final people = e.sharedTotalPeople <= 0 ? 1 : e.sharedTotalPeople;
      return sum + (e.price / people);
    });

    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Arkadaşımla Masraflarımı Paylaş",
            subtitle: "Kayıtlı masraf varsa seçip arkadaşına gönderebilirsin. Masraf ekleme formunda kişi seçimi yoktur.",
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Paylaşılan", value: "${sharedItems.length} kayıt", icon: Icons.groups_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "Toplam", value: "${formatMoney(sharedTotal)} TL", icon: Icons.payments_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Benim Payım", value: "${formatMoney(myShare)} TL", icon: Icons.person_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "Ortaklar", value: sharedItems.isEmpty ? "Yok" : "Aktif", icon: Icons.handshake_rounded)),
            ],
          ),
          const SizedBox(height: 14),
          BottomActionButton(
            title: "Masraf seç ve arkadaşına gönder",
            icon: Icons.send_rounded,
            color: Colors.black,
            onTap: openShareExpenseWithFriendSheet,
          ),
          const SizedBox(height: 12),
          const NovaSystemNoteBox(
            icon: Icons.info_rounded,
            title: "Paylaşım ayrı yönetilir",
            text: "Masraf kaydı temiz kalır. Paylaşım yapmak istersen buradan masraf seçip göndereceğin kişiyi yazarsın.",
          ),
        ],
      ),
    );
  }

  Widget buildPenaltySharePanel() {
    final penalties = expenses.where((e) => e.carId == selectedCarId && e.category == "Ceza").length;
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Ceza Uyarısı Paylaş",
            subtitle: "Ceza yedim dikkat edin paylaşımı ana sayfada post olarak yayınlanır.",
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Ceza Kaydı", value: "$penalties adet", icon: Icons.report_problem_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "Ana Sayfa", value: "Beğeni/Yorum", icon: Icons.forum_rounded)),
            ],
          ),
          const SizedBox(height: 14),
          BottomActionButton(
            title: "Ceza yedim, dikkat edin diye paylaş",
            icon: Icons.campaign_rounded,
            color: const Color(0xFFE53935),
            onTap: openPenaltyWarningPostPage,
          ),
        ],
      ),
    );
  }

  Widget buildReminderCenterPanel() {
    final reminderItems = expenses.where((e) => e.reminderEnabled).toList()
      ..sort((a, b) {
        final ad = a.reminderDate ?? DateTime(2099);
        final bd = b.reminderDate ?? DateTime(2099);
        return ad.compareTo(bd);
      });

    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Bildirimli Hatırlatma Merkezi",
            subtitle: "Bakım, muayene, sigorta, kasko ve özel hatırlatmalar için kayıt oluşturur.",
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Aktif", value: "${reminderItems.length} adet", icon: Icons.notifications_active_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "Yaklaşan", value: reminderItems.isEmpty ? "Yok" : novaShortDate(reminderItems.first.reminderDate), icon: Icons.event_available_rounded)),
            ],
          ),
          const SizedBox(height: 14),
          if (reminderItems.isEmpty)
            const EmptyNovaBox(text: "Masraf eklerken hatırlatma açarsan NOVA bunu bildirim için Firestore'a kaydeder. Kullanıcı isterse kendi tarihini belirleyebilir.")
          else
            Column(
              children: reminderItems.take(5).map((expense) {
                final days = expense.reminderDate == null ? null : expense.reminderDate!.difference(DateTime.now()).inDays;
                return NovaSystemNoteBox(
                  icon: Icons.alarm_rounded,
                  title: days == null ? expense.title : days >= 0 ? "${expense.title} • $days gün kaldı" : "${expense.title} • zamanı geçti",
                  text: expense.reminderNote.isEmpty
                      ? "Hatırlatma tarihi: ${novaShortDate(expense.reminderDate)}"
                      : "${expense.reminderNote} • ${novaShortDate(expense.reminderDate)}",
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  String novaShortDate(DateTime? date) {
    if (date == null) return "Yok";
    return "${date.day}.${date.month}.${date.year}";
  }

  Widget buildDocumentVaultPanel() {
    final docs = receiptExpenses;
    final insuranceDocs = expenses.where((e) => e.category == "Sigorta" && e.hasReceiptImage).length;
    final inspectionDocs = expenses.where((e) => e.category == "Muayene" && e.hasReceiptImage).length;
    final maintenanceDocs = expenses.where((e) => e.category == "Bakım" && e.hasReceiptImage).length;

    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Evrak Kasası",
            subtitle: "Ruhsat, sigorta, kasko, muayene, fatura ve yakıt fişleri için dijital arşiv.",
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Tüm Evrak", value: "${docs.length} dosya", icon: Icons.folder_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "Sigorta", value: "$insuranceDocs dosya", icon: Icons.verified_user_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Muayene", value: "$inspectionDocs dosya", icon: Icons.fact_check_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "Bakım", value: "$maintenanceDocs dosya", icon: Icons.build_rounded)),
            ],
          ),
          const SizedBox(height: 14),
          const NovaSystemNoteBox(
            icon: Icons.lock_rounded,
            title: "Güvenli arşiv",
            text: "Her görsel Firebase Storage içinde kullanıcı hesabına bağlı saklanır. Kullanıcı silerse kayıt da silinir.",
          ),
        ],
      ),
    );
  }

  Widget buildSmartNovaAnalysisPanel() {
    final yearlyProjection = selectedFilter == "Yıllık" ? totalExpense : selectedFilter == "Aylık" ? totalExpense * 12 : totalExpense * 52;
    final dailyAverage = selectedFilter == "Haftalık" ? totalExpense / 7 : selectedFilter == "Aylık" ? totalExpense / 30 : totalExpense / 365;
    final message = totalExpense == 0
        ? "Henüz analiz için masraf yok. İlk kayıttan sonra NOVA yorum üretir."
        : "${selectedCar.name} için seçili dönemde ${formatMoney(totalExpense)} TL harcandı. En yoğun kategori: $biggestCategory.";

    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "NOVA Yapay Analiz",
            subtitle: "Müşteriye anlaşılır maliyet yorumu verir.",
          ),
          const SizedBox(height: 16),
          NovaSystemNoteBox(
            icon: Icons.auto_awesome_rounded,
            title: "Akıllı Özet",
            text: message,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: NovaSmallInfo(title: "Günlük Ort.", value: "${formatMoney(dailyAverage)} TL", icon: Icons.today_rounded)),
              const SizedBox(width: 10),
              Expanded(child: NovaSmallInfo(title: "Yıllık Tahmin", value: "${formatMoney(yearlyProjection)} TL", icon: Icons.trending_up_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          const NovaSystemNoteBox(
            icon: Icons.tips_and_updates_rounded,
            title: "Kullanıcıyı uygulamada tutar",
            text: "Bu bölüm müşteriye 'aracım bana ne kadara mal oluyor?' sorusunun cevabını net verir.",
          ),
        ],
      ),
    );
  }
}

class AddExpenseSheet extends StatefulWidget {
  final String carId;
  final NovaExpense? expense;
  final Function(NovaExpense expense) onSave;

  const AddExpenseSheet({
    super.key,
    required this.carId,
    required this.onSave,
    this.expense,
  });

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  late final TextEditingController titleController;
  late final TextEditingController priceController;
  late final TextEditingController noteController;
  late final TextEditingController odometerController;
  late final TextEditingController fuelLiterController;
  late final TextEditingController paidByController;
  late final TextEditingController sharedWithController;
  late final TextEditingController sharedPeopleController;
  late final TextEditingController reminderNoteController;

  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  XFile? selectedReceiptFile;
  String receiptImageUrl = "";
  String receiptFileName = "";
  bool saving = false;

  String selectedCategory = "Yakıt";
  bool reminderEnabled = false;
  DateTime? reminderDate;

  final List<ExpenseCategoryData> categories = const [
    ExpenseCategoryData(
      "Yakıt",
      Icons.local_gas_station_rounded,
      Color(0xFFFF2E88),
    ),
    ExpenseCategoryData(
      "Bakım",
      Icons.build_rounded,
      Color(0xFF3C7BFF),
    ),
    ExpenseCategoryData(
      "Sigorta",
      Icons.verified_user_rounded,
      Color(0xFF7C4DFF),
    ),
    ExpenseCategoryData(
      "Muayene",
      Icons.fact_check_rounded,
      Color(0xFF00D9FF),
    ),
    ExpenseCategoryData(
      "Parça",
      Icons.tire_repair_rounded,
      Color(0xFFFF7A00),
    ),
    ExpenseCategoryData(
      "Yıkama",
      Icons.water_drop_rounded,
      Color(0xFF00C853),
    ),
    ExpenseCategoryData(
      "Fatura",
      Icons.receipt_long_rounded,
      Color(0xFF111111),
    ),
    ExpenseCategoryData(
      "Lastik",
      Icons.album_rounded,
      Color(0xFF4CAF50),
    ),
    ExpenseCategoryData(
      "Kasko",
      Icons.health_and_safety_rounded,
      Color(0xFF9C27B0),
    ),
    ExpenseCategoryData(
      "Ceza",
      Icons.report_problem_rounded,
      Color(0xFFD32F2F),
    ),
    ExpenseCategoryData(
      "Otopark",
      Icons.local_parking_rounded,
      Color(0xFF795548),
    ),
    ExpenseCategoryData(
      "Aksesuar",
      Icons.extension_rounded,
      Color(0xFF009688),
    ),
    ExpenseCategoryData(
      "Ruhsat/Evrak",
      Icons.description_rounded,
      Color(0xFF607D8B),
    ),
    ExpenseCategoryData(
      "Diğer",
      Icons.more_horiz_rounded,
      Color(0xFF111111),
    ),
  ];

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.expense?.title ?? "",
    );

    priceController = TextEditingController(
      text: widget.expense == null
          ? ""
          : widget.expense!.price.toStringAsFixed(0),
    );

    noteController = TextEditingController(
      text: widget.expense?.note ?? "",
    );

    odometerController = TextEditingController(
      text: widget.expense == null || widget.expense!.odometerKm <= 0
          ? ""
          : widget.expense!.odometerKm.toString(),
    );

    fuelLiterController = TextEditingController(
      text: widget.expense == null || widget.expense!.fuelLiters <= 0
          ? ""
          : widget.expense!.fuelLiters.toStringAsFixed(1),
    );

    paidByController = TextEditingController(
      text: widget.expense?.paidByName ?? "",
    );

    sharedWithController = TextEditingController(
      text: widget.expense?.sharedWithText ?? "",
    );

    sharedPeopleController = TextEditingController(
      text: widget.expense == null || widget.expense!.sharedTotalPeople <= 1
          ? ""
          : widget.expense!.sharedTotalPeople.toString(),
    );

    reminderNoteController = TextEditingController(
      text: widget.expense?.reminderNote ?? "",
    );

    selectedCategory = widget.expense?.category ?? "Yakıt";
    reminderEnabled = widget.expense?.reminderEnabled ?? false;
    reminderDate = widget.expense?.reminderDate;
    receiptImageUrl = widget.expense?.receiptImageUrl ?? "";
    receiptFileName = widget.expense?.receiptFileName ?? "";
  }

  @override
  void dispose() {
    titleController.dispose();
    priceController.dispose();
    noteController.dispose();
    odometerController.dispose();
    fuelLiterController.dispose();
    paidByController.dispose();
    sharedWithController.dispose();
    sharedPeopleController.dispose();
    reminderNoteController.dispose();
    super.dispose();
  }

  Future<void> pickReceiptImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );

    if (picked == null) return;

    setState(() {
      selectedReceiptFile = picked;
      receiptFileName = picked.name;
    });
  }

  Future<String> uploadReceiptImage(String expenseId) async {
    if (selectedReceiptFile == null) return receiptImageUrl;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return receiptImageUrl;

    final bytes = await selectedReceiptFile!.readAsBytes();
    final safeName = selectedReceiptFile!.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storageRef = _storage
        .ref()
        .child('users')
        .child(uid)
        .child('expense_receipts')
        .child('$expenseId-$safeName');

    final metadata = SettableMetadata(
      contentType: selectedReceiptFile!.mimeType ?? 'image/jpeg',
      customMetadata: {
        'expenseId': expenseId,
        'category': selectedCategory,
      },
    );

    await storageRef.putData(bytes, metadata);
    return storageRef.getDownloadURL();
  }

  Future<void> submit() async {
    if (saving) return;

    final title = titleController.text.trim();
    final price = double.tryParse(
      priceController.text.replaceAll(".", "").replaceAll(",", "."),
    );

    if (title.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Başlık ve geçerli tutar zorunlu."),
          duration: Duration(milliseconds: 1300),
        ),
      );
      return;
    }

    final odometerKm = int.tryParse(odometerController.text.replaceAll(".", "").trim()) ?? 0;
    final fuelLiters = double.tryParse(fuelLiterController.text.replaceAll(",", ".").trim()) ?? 0;
    final sharedPeople = int.tryParse(sharedPeopleController.text.trim()) ?? 1;

    setState(() => saving = true);

    try {
      final category = categories.firstWhere((c) => c.name == selectedCategory);
      final now = DateTime.now();
      final expenseId = widget.expense?.id ?? "exp_${now.millisecondsSinceEpoch}";
      final uploadedUrl = await uploadReceiptImage(expenseId);

      await widget.onSave(
        NovaExpense(
          id: expenseId,
          carId: widget.expense?.carId ?? widget.carId,
          title: title,
          category: selectedCategory,
          price: price,
          date: widget.expense?.date ?? now,
          icon: category.icon,
          color: category.color,
          receiptImageUrl: uploadedUrl,
          receiptFileName: receiptFileName,
          note: noteController.text.trim(),
          odometerKm: odometerKm,
          fuelLiters: fuelLiters,
          paidByName: paidByController.text.trim(),
          sharedWithText: '',
          sharedTotalPeople: 1,
          reminderEnabled: reminderEnabled,
          reminderDate: reminderDate,
          reminderNote: reminderNoteController.text.trim(),
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kayıt sırasında hata oluştu. Tekrar dene."),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NovaFullScreenSheet(
      title: widget.expense == null ? "Yeni Masraf Ekle" : "Masrafı Düzenle",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetLabel("Kategori"),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: categories.map((category) {
              final selected = selectedCategory == category.name;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = category.name;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? category.color.withOpacity(0.16)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? category.color : Colors.black12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(category.icon, color: category.color, size: 18),
                      const SizedBox(width: 7),
                      Text(
                        category.name,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          fontFamily: "Roboto",
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const SheetLabel("Masraf Başlığı"),
          const SizedBox(height: 8),
          NovaInput(
            controller: titleController,
            hint: "Örn: Yakıt alımı, bakım, lastik...",
          ),
          const SizedBox(height: 14),
          const SheetLabel("Tutar"),
          const SizedBox(height: 8),
          NovaInput(
            controller: priceController,
            hint: "Örn: 1850",
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          SheetLabel(selectedCategory == "Ceza" ? "Ceza / Konum Açıklaması" : "Not / Açıklama"),
          const SizedBox(height: 8),
          NovaInput(
            controller: noteController,
            hint: selectedCategory == "Ceza"
                ? "Örn: Radar vardı, emniyet şeridi, park cezası..."
                : "Kısa not yazabilirsin.",
          ),
          if (selectedCategory == "Yakıt" || selectedCategory == "Bakım" || selectedCategory == "Muayene" || selectedCategory == "Sigorta" || selectedCategory == "Kasko" || selectedCategory == "Lastik") ...[
            const SizedBox(height: 14),
            const SheetLabel("KM Bilgisi"),
            const SizedBox(height: 8),
            NovaInput(
              controller: odometerController,
              hint: "Örn: 145000",
              keyboardType: TextInputType.number,
            ),
          ],
          if (selectedCategory == "Yakıt") ...[
            const SizedBox(height: 14),
            const SheetLabel("Yakıt Litre Bilgisi"),
            const SizedBox(height: 8),
            NovaInput(
              controller: fuelLiterController,
              hint: "Örn: 42.5 litre",
              keyboardType: TextInputType.number,
            ),
          ],
          if (selectedCategory == "Bakım" || selectedCategory == "Muayene" || selectedCategory == "Sigorta" || selectedCategory == "Kasko" || selectedCategory == "Lastik") ...[
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: Colors.black,
              title: const Text(
                "Bu kayıt için hatırlatma oluştur",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Roboto",
                ),
              ),
              subtitle: Text(
                reminderDate == null
                    ? "Bakım / muayene / sigorta zamanı için bildirim al."
                    : "Hatırlatma: ${reminderDate!.day}.${reminderDate!.month}.${reminderDate!.year}",
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                  fontFamily: "Roboto",
                ),
              ),
              value: reminderEnabled,
              onChanged: (value) => setState(() => reminderEnabled = value),
            ),
            if (reminderEnabled) ...[
              const SizedBox(height: 8),
              BottomActionButton(
                title: reminderDate == null ? "Hatırlatma Tarihi Seç" : "Hatırlatma Tarihini Değiştir",
                icon: Icons.event_rounded,
                color: Colors.black,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: reminderDate ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setState(() => reminderDate = picked);
                },
              ),
              const SizedBox(height: 10),
              NovaInput(
                controller: reminderNoteController,
                hint: "Örn: Yağ bakımını yaptır, muayeneyi yenile...",
              ),
            ],
          ],
          const SizedBox(height: 14),
          SheetLabel(selectedCategory == "Yakıt" ? "Yakıt Fişi / Fatura Görseli" : "Fatura / Evrak Görseli"),
          const SizedBox(height: 10),
          ReceiptPickerBox(
            imageUrl: receiptImageUrl,
            fileName: selectedReceiptFile?.name ?? receiptFileName,
            onCamera: () => pickReceiptImage(ImageSource.camera),
            onGallery: () => pickReceiptImage(ImageSource.gallery),
          ),
          const SizedBox(height: 10),
          const Text(
            "Tarih otomatik eklenir. Masraf paylaşımı ayrı kutudan yapılır.",
            style: TextStyle(
              color: Colors.black45,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: "Roboto",
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: submit,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black,
              ),
              child: Center(
                child: Text(
                  saving
                      ? "Kaydediliyor..."
                      : widget.expense == null
                      ? "Masrafı Kaydet"
                      : "Güncelle",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    fontFamily: "Roboto",
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddCarSheet extends StatefulWidget {
  final Function(NovaCar car) onAdd;

  const AddCarSheet({
    super.key,
    required this.onAdd,
  });

  @override
  State<AddCarSheet> createState() => _AddCarSheetState();
}

class _AddCarSheetState extends State<AddCarSheet> {
  final TextEditingController carNameController = TextEditingController();
  final TextEditingController plateController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  XFile? selectedCarImageFile;
  String carImageUrl = "";
  String carImageFileName = "";
  bool saving = false;

  @override
  void dispose() {
    carNameController.dispose();
    plateController.dispose();
    super.dispose();
  }

  Future<void> pickCarImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );

    if (picked == null) return;

    setState(() {
      selectedCarImageFile = picked;
      carImageFileName = picked.name;
    });
  }

  Future<String> uploadCarImage(String carId) async {
    if (selectedCarImageFile == null) return carImageUrl;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return carImageUrl;

    final bytes = await selectedCarImageFile!.readAsBytes();
    final safeName = selectedCarImageFile!.name.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );

    final storageRef = _storage
        .ref()
        .child('users')
        .child(uid)
        .child('expense_cars')
        .child('$carId-$safeName');

    final metadata = SettableMetadata(
      contentType: selectedCarImageFile!.mimeType ?? 'image/jpeg',
      customMetadata: {
        'carId': carId,
      },
    );

    await storageRef.putData(bytes, metadata);
    return storageRef.getDownloadURL();
  }

  Future<void> submit() async {
    if (saving) return;

    final name = carNameController.text.trim();
    final plate = plateController.text.trim();

    if (name.isEmpty || plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Araç adı ve plaka zorunlu."),
          duration: Duration(milliseconds: 1300),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final carId = "car_${DateTime.now().millisecondsSinceEpoch}";
      final uploadedUrl = await uploadCarImage(carId);

      await widget.onAdd(
        NovaCar(
          id: carId,
          name: name,
          plate: plate,
          isFavorite: false,
          color1: Colors.black,
          color2: Colors.black,
          imageUrl: uploadedUrl,
          imageFileName: carImageFileName,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Araç kaydedilirken hata oluştu. Tekrar dene."),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NovaFullScreenSheet(
      title: "Yeni Araç Ekle",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetLabel("Araç Görseli"),
          const SizedBox(height: 10),
          CarImagePickerBox(
            imageUrl: carImageUrl,
            fileName: selectedCarImageFile?.name ?? carImageFileName,
            onCamera: () => pickCarImage(ImageSource.camera),
            onGallery: () => pickCarImage(ImageSource.gallery),
          ),
          const SizedBox(height: 16),
          const SheetLabel("Araç Adı"),
          const SizedBox(height: 8),
          NovaInput(
            controller: carNameController,
            hint: "Örn: BMW 3.20i",
          ),
          const SizedBox(height: 14),
          const SheetLabel("Plaka"),
          const SizedBox(height: 8),
          NovaInput(
            controller: plateController,
            hint: "Örn: 26 NOVA 026",
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: submit,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black,
              ),
              child: Center(
                child: Text(
                  saving ? "Kaydediliyor..." : "Aracı Ekle",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    fontFamily: "Roboto",
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NovaCar {
  final String id;
  final String name;
  final String plate;
  final bool isFavorite;
  final Color color1;
  final Color color2;
  final String imageUrl;
  final String imageFileName;

  NovaCar({
    required this.id,
    required this.name,
    required this.plate,
    required this.isFavorite,
    required this.color1,
    required this.color2,
    this.imageUrl = "",
    this.imageFileName = "",
  });

  bool get hasImage => imageUrl.trim().isNotEmpty;

  factory NovaCar.fromFirestore(String id, Map<String, dynamic> data) {
    return NovaCar(
      id: id,
      name: (data['name'] ?? '').toString(),
      plate: (data['plate'] ?? '').toString(),
      isFavorite: data['isFavorite'] == true,
      color1: Colors.black,
      color2: Colors.black,
      imageUrl: (data['imageUrl'] ?? '').toString(),
      imageFileName: (data['imageFileName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'plate': plate,
      'isFavorite': isFavorite,
      'color1': Colors.black.value,
      'color2': Colors.black.value,
      'imageUrl': imageUrl,
      'imageFileName': imageFileName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class NovaExpense {
  final String id;
  final String carId;
  final String title;
  final String category;
  final double price;
  final DateTime date;
  final IconData icon;
  final Color color;
  final String receiptImageUrl;
  final String receiptFileName;
  final String note;
  final int odometerKm;
  final double fuelLiters;
  final String paidByName;
  final String sharedWithText;
  final int sharedTotalPeople;
  final bool reminderEnabled;
  final DateTime? reminderDate;
  final String reminderNote;

  NovaExpense({
    required this.id,
    required this.carId,
    required this.title,
    required this.category,
    required this.price,
    required this.date,
    required this.icon,
    required this.color,
    this.receiptImageUrl = "",
    this.receiptFileName = "",
    this.note = "",
    this.odometerKm = 0,
    this.fuelLiters = 0,
    this.paidByName = "",
    this.sharedWithText = "",
    this.sharedTotalPeople = 1,
    this.reminderEnabled = false,
    this.reminderDate,
    this.reminderNote = "",
  });

  bool get hasReceiptImage => receiptImageUrl.trim().isNotEmpty;

  factory NovaExpense.fromFirestore(String id, Map<String, dynamic> data) {
    final category = (data['category'] ?? 'Diğer').toString();
    final rawDate = data['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse((data['dateText'] ?? '').toString()) ?? DateTime.now();
    final rawReminderDate = data['reminderDate'];
    final reminderDate = rawReminderDate is Timestamp
        ? rawReminderDate.toDate()
        : DateTime.tryParse((data['reminderDateText'] ?? '').toString());

    return NovaExpense(
      id: id,
      carId: (data['carId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      category: category,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      date: date,
      icon: expenseIconForCategory(category),
      color: expenseColorForCategory(category),
      receiptImageUrl: (data['receiptImageUrl'] ?? '').toString(),
      receiptFileName: (data['receiptFileName'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
      odometerKm: (data['odometerKm'] as num?)?.toInt() ?? 0,
      fuelLiters: (data['fuelLiters'] as num?)?.toDouble() ?? 0,
      paidByName: (data['paidByName'] ?? '').toString(),
      sharedWithText: (data['sharedWithText'] ?? '').toString(),
      sharedTotalPeople: (data['sharedTotalPeople'] as num?)?.toInt() ?? 1,
      reminderEnabled: data['reminderEnabled'] == true,
      reminderDate: reminderDate,
      reminderNote: (data['reminderNote'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'carId': carId,
      'title': title,
      'category': category,
      'price': price,
      'date': Timestamp.fromDate(date),
      'dateText': date.toIso8601String(),
      'receiptImageUrl': receiptImageUrl,
      'receiptFileName': receiptFileName,
      'note': note,
      'odometerKm': odometerKm,
      'fuelLiters': fuelLiters,
      'paidByName': paidByName,
      'sharedWithText': sharedWithText,
      'sharedTotalPeople': sharedTotalPeople,
      'reminderEnabled': reminderEnabled,
      'reminderDate': reminderDate == null ? null : Timestamp.fromDate(reminderDate!),
      'reminderDateText': reminderDate?.toIso8601String() ?? '',
      'reminderNote': reminderNote,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}


Color _colorFromInt(dynamic value, Color fallback) {
  if (value is int) return Color(value);
  return fallback;
}

IconData expenseIconForCategory(String category) {
  switch (category) {
    case "Yakıt":
      return Icons.local_gas_station_rounded;
    case "Bakım":
      return Icons.build_rounded;
    case "Sigorta":
      return Icons.verified_user_rounded;
    case "Muayene":
      return Icons.fact_check_rounded;
    case "Parça":
      return Icons.tire_repair_rounded;
    case "Yıkama":
      return Icons.water_drop_rounded;
    case "Fatura":
      return Icons.receipt_long_rounded;
    default:
      return Icons.more_horiz_rounded;
  }
}

Color expenseColorForCategory(String category) {
  switch (category) {
    case "Yakıt":
      return const Color(0xFFFF2E88);
    case "Bakım":
      return const Color(0xFF3C7BFF);
    case "Sigorta":
      return const Color(0xFF7C4DFF);
    case "Muayene":
      return const Color(0xFF00D9FF);
    case "Parça":
      return const Color(0xFFFF7A00);
    case "Yıkama":
      return const Color(0xFF00C853);
    case "Fatura":
      return const Color(0xFF111111);
    default:
      return const Color(0xFF111111);
  }
}

class ExpenseCategoryData {
  final String name;
  final IconData icon;
  final Color color;
  const ExpenseCategoryData(this.name, this.icon, this.color);
}

class ChartPoint {
  final String label;
  final String title;
  final double total;

  ChartPoint({
    required this.label,
    required this.title,
    required this.total,
  });
}

class NovaWhiteBackground extends StatelessWidget {
  const NovaWhiteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.white,
    );
  }
}

class NovaGlow extends StatelessWidget {
  final Color color;

  const NovaGlow({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 120,
            spreadRadius: 60,
          ),
        ],
      ),
    );
  }
}

class NeonBorderCard extends StatelessWidget {
  final AnimationController controller;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  const NeonBorderCard({
    super.key,
    required this.controller,
    required this.child,
    this.radius = 26,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(1.8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: SweepGradient(
              transform: GradientRotation(controller.value * pi * 2),
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
                color: const Color(0xFF7C4DFF).withOpacity(0.20),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(radius - 1.8),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class NeonIconCircle extends StatelessWidget {
  final AnimationController controller;
  final IconData icon;
  final double size;
  final double iconSize;

  const NeonIconCircle({
    super.key,
    required this.controller,
    required this.icon,
    this.size = 38,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(1.7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(controller.value * pi * 2),
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
                color: const Color(0xFFFF00B8).withOpacity(0.20),
                blurRadius: 13,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: const Color(0xFF00D9FF).withOpacity(0.16),
                blurRadius: 13,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        );
      },
    );
  }
}


class NovaCarAvatar extends StatelessWidget {
  final NovaCar car;
  final AnimationController controller;
  final double size;
  final double iconSize;

  const NovaCarAvatar({
    super.key,
    required this.car,
    required this.controller,
    this.size = 46,
    this.iconSize = 23,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(1.8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(controller.value * pi * 2),
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
                color: const Color(0xFFFF00B8).withOpacity(0.18),
                blurRadius: 12,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: const Color(0xFF00D9FF).withOpacity(0.14),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
            clipBehavior: Clip.antiAlias,
            child: car.hasImage
                ? Image.network(
              car.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.directions_car_rounded,
                color: Colors.white,
                size: iconSize,
              ),
            )
                : Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        );
      },
    );
  }
}

class CarImagePickerBox extends StatelessWidget {
  final String imageUrl;
  final String fileName;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const CarImagePickerBox({
    super.key,
    required this.imageUrl,
    required this.fileName,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty || fileName.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.trim().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const EmptyNovaBox(
                  text: "Araç görseli önizlenemedi.",
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Container(
            width: double.infinity,
            height: 92,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: hasImage
                  ? Text(
                "Seçilen görsel: ${fileName.isEmpty ? 'araç görseli' : fileName}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Roboto",
                ),
              )
                  : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_car_filled_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Araç görseli ekle",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontFamily: "Roboto",
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: BottomActionButton(
                  title: "Kamera",
                  icon: Icons.photo_camera_rounded,
                  color: Colors.black,
                  onTap: onCamera,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BottomActionButton(
                  title: "Galeri",
                  icon: Icons.photo_library_rounded,
                  color: Colors.black,
                  onTap: onGallery,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlainCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PlainCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: const [],
      ),
      child: child,
    );
  }
}

class NovaActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final AnimationController controller;
  final VoidCallback onTap;

  const NovaActionButton({
    super.key,
    required this.title,
    required this.icon,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NeonBorderCard(
      controller: controller,
      radius: 22,
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NeonIconCircle(
                controller: controller,
                icon: icon,
                size: 34,
                iconSize: 19,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Roboto",
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

class NovaCardTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const NovaCardTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Roboto",
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: "Roboto",
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class NovaSmallInfo extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const NovaSmallInfo({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: "Roboto",
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Roboto",
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

class MiniAnalysisCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const MiniAnalysisCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PlainCard(
      child: SizedBox(
        height: 94,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: "Roboto",
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: "Roboto",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryBar extends StatelessWidget {
  final String title;
  final double price;
  final double percent;

  const CategoryBar({
    super.key,
    required this.title,
    required this.price,
    required this.percent,
  });

  String formatMoney(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => "${match[1]}.",
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayPercent = (percent * 100).clamp(0, 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Roboto",
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "${formatMoney(price)} TL • $displayPercent%",
              maxLines: 1,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                fontFamily: "Roboto",
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(
                height: 11,
                color: Colors.black.withOpacity(0.07),
              ),
              FractionallySizedBox(
                widthFactor: percent.clamp(0, 1),
                child: Container(
                  height: 11,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final NovaExpense expense;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  String formatMoney(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => "${match[1]}.",
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.035),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: expense.color.withOpacity(0.17),
                shape: BoxShape.circle,
              ),
              child: Icon(expense.icon, color: expense.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      fontFamily: "Roboto",
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${expense.category} • ${expense.date.day}.${expense.date.month}.${expense.date.year}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: "Roboto",
                    ),
                  ),
                ],
              ),
            ),
            if (expense.hasReceiptImage) ...[
              const SizedBox(width: 6),
              const Icon(Icons.image_rounded, color: Colors.black45, size: 18),
            ],
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  "${formatMoney(expense.price)} TL",
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    fontFamily: "Roboto",
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.black),
              onSelected: (value) {
                if (value == "edit") onEdit();
                if (value == "delete") onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: "edit",
                  child: Text(
                    "Düzenle",
                    style: TextStyle(fontFamily: "Roboto"),
                  ),
                ),
                PopupMenuItem(
                  value: "delete",
                  child: Text(
                    "Sil",
                    style: TextStyle(fontFamily: "Roboto"),
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



class ReceiptPickerBox extends StatelessWidget {
  final String imageUrl;
  final String fileName;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const ReceiptPickerBox({
    super.key,
    required this.imageUrl,
    required this.fileName,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty || fileName.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.trim().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const EmptyNovaBox(
                  text: "Kayıtlı görsel önizlenemedi.",
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: BottomActionButton(
                  title: "Kamera",
                  icon: Icons.photo_camera_rounded,
                  color: Colors.black,
                  onTap: onCamera,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BottomActionButton(
                  title: "Galeri",
                  icon: Icons.photo_library_rounded,
                  color: Colors.black,
                  onTap: onGallery,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasImage
                ? "Seçilen/kayıtlı görsel: ${fileName.isEmpty ? 'fatura görseli' : fileName}"
                : "İstersen fatura, benzin fişi veya yakıt fişi görseli ekle.",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: "Roboto",
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiptGalleryCard extends StatelessWidget {
  final NovaExpense expense;
  final VoidCallback onTap;

  const ReceiptGalleryCard({
    super.key,
    required this.expense,
    required this.onTap,
  });

  String formatMoney(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => "${match[1]}.",
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
          boxShadow: const [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Image.network(
                  expense.receiptImageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black.withOpacity(0.04),
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        fontFamily: "Roboto",
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${expense.category} • ${formatMoney(expense.price)} TL",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: "Roboto",
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

class LoadingExpensePanel extends StatelessWidget {
  const LoadingExpensePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlainCard(
      child: Center(
        child: Text(
          "Masraf verileri yükleniyor...",
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w900,
            fontFamily: "Roboto",
          ),
        ),
      ),
    );
  }
}

class EmptyNovaBox extends StatelessWidget {
  final String text;

  const EmptyNovaBox({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w700,
          fontFamily: "Roboto",
        ),
      ),
    );
  }
}

class DetailLine extends StatelessWidget {
  final String title;
  final String value;

  const DetailLine({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black45,
                fontWeight: FontWeight.w800,
                fontFamily: "Roboto",
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontFamily: "Roboto",
              ),
            ),
          ),
        ],
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
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Roboto",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




class PenaltyWarningPostPage extends StatefulWidget {
  final NovaCar car;
  final Future<void> Function({
  required double penaltyAmount,
  required String description,
  required List<String> imageUrls,
  }) onShare;

  const PenaltyWarningPostPage({
    super.key,
    required this.car,
    required this.onShare,
  });

  @override
  State<PenaltyWarningPostPage> createState() => _PenaltyWarningPostPageState();
}

class _PenaltyWarningPostPageState extends State<PenaltyWarningPostPage> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();
  final FirebaseStorage storage = FirebaseStorage.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  final List<XFile> selectedImages = [];
  bool sharing = false;

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    if (selectedImages.length >= 5) {
      showMessage("En fazla 5 görsel seçebilirsin.");
      return;
    }

    final picked = await imagePicker.pickMultiImage(
      imageQuality: 84,
      maxWidth: 1600,
    );

    if (picked.isEmpty) return;

    final remaining = 5 - selectedImages.length;
    final items = picked.take(remaining).toList();

    setState(() {
      selectedImages.addAll(items);
    });

    if (picked.length > remaining) {
      showMessage("5 görsel sınırı var. Fazla seçilenler eklenmedi.");
    }
  }

  void removeImage(int index) {
    if (index < 0 || index >= selectedImages.length) return;
    setState(() {
      selectedImages.removeAt(index);
    });
  }

  Future<List<String>> uploadImages(String postId) async {
    final uid = auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return <String>[];

    final urls = <String>[];

    for (var i = 0; i < selectedImages.length; i++) {
      final file = selectedImages[i];
      final bytes = await file.readAsBytes();
      final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      final ref = storage
          .ref()
          .child('users')
          .child(uid)
          .child('penalty_warning_posts')
          .child('$postId-$i-$safeName');

      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: file.mimeType ?? 'image/jpeg',
          customMetadata: {
            'type': 'penalty_warning_post',
            'postId': postId,
            'index': '$i',
          },
        ),
      );

      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }

  Future<void> submit() async {
    if (sharing) return;

    final amount = double.tryParse(
      amountController.text.replaceAll('.', '').replaceAll(',', '.').trim(),
    );

    if (selectedImages.isEmpty) {
      showMessage("Ceza paylaşımı için en az 1 görsel seçmelisin.");
      return;
    }

    if (amount == null || amount <= 0) {
      showMessage("Geçerli bir ceza tutarı girmelisin.");
      return;
    }

    final description = descriptionController.text.trim();
    if (description.isEmpty) {
      showMessage("Ceza açıklaması yazmalısın.");
      return;
    }

    setState(() => sharing = true);

    try {
      final postId = 'penalty_${DateTime.now().millisecondsSinceEpoch}';
      final urls = await uploadImages(postId);

      if (urls.isEmpty) {
        showMessage("Görseller yüklenemedi.");
        if (mounted) setState(() => sharing = false);
        return;
      }

      await widget.onShare(
        penaltyAmount: amount,
        description: description,
        imageUrls: urls,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      showMessage("Ceza paylaşımı yapılamadı. Tekrar dene.");
      if (mounted) setState(() => sharing = false);
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String formatMoneyInputPreview() {
    final value = double.tryParse(
      amountController.text.replaceAll('.', '').replaceAll(',', '.').trim(),
    );
    if (value == null || value <= 0) return "Ceza tutarı girilmedi";
    return "${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} TL";
  }

  @override
  Widget build(BuildContext context) {
    return NovaFullScreenSheet(
      title: "Ceza Uyarısı Paylaş",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Ana sayfaya post olarak paylaş",
            subtitle: "En fazla 5 görsel seç, ceza tutarını ve açıklamasını gir. Paylaşım beğeni, yorum ve paylaşım alabilecek post olarak yayınlanır.",
          ),
          const SizedBox(height: 16),
          PlainCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.directions_car_filled_rounded, color: Colors.black),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${widget.car.name} • ${widget.car.plate}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Roboto",
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SheetLabel("Ceza Görselleri"),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: pickImages,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_photo_alternate_rounded, color: Colors.black),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedImages.isEmpty
                          ? "Görsel seç • 0/5"
                          : "Görsel seçildi • ${selectedImages.length}/5",
                      style: const TextStyle(
                        fontFamily: "Roboto",
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.black),
                ],
              ),
            ),
          ),
          if (selectedImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedImages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final file = selectedImages[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(file.path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black12,
                          child: const Icon(Icons.image_not_supported_rounded),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => removeImage(index),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 17),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          const SheetLabel("Ceza Tutarı"),
          const SizedBox(height: 8),
          NovaInput(
            controller: amountController,
            hint: "Örn: 1506",
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoneyInputPreview(),
            style: const TextStyle(
              fontFamily: "Roboto",
              color: Colors.black54,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          const SheetLabel("Ceza Açıklaması"),
          const SizedBox(height: 8),
          NovaInput(
            controller: descriptionController,
            hint: "Örn: Eskişehir çevre yolunda radar vardı, dikkat edin.",
            maxLines: 4,
          ),
          const SizedBox(height: 18),
          NovaSystemNoteBox(
            icon: Icons.info_rounded,
            title: "Post olarak yayınlanır",
            text: "Bu paylaşım ana sayfada görünür. Kullanıcılar beğeni, yorum ve paylaşım yapabilir.",
          ),
          const SizedBox(height: 22),
          BottomActionButton(
            title: sharing ? "Paylaşılıyor..." : "Ceza Uyarısını Paylaş",
            icon: Icons.campaign_rounded,
            color: const Color(0xFFE53935),
            onTap: submit,
          ),
        ],
      ),
    );
  }
}


class ShareExpenseWithFriendPage extends StatefulWidget {
  final List<NovaExpense> expenses;
  final NovaCar car;
  final String Function(double value) formatMoney;
  final Future<void> Function({
  required NovaExpense expense,
  required String receiverText,
  required String note,
  }) onSend;

  const ShareExpenseWithFriendPage({
    super.key,
    required this.expenses,
    required this.car,
    required this.formatMoney,
    required this.onSend,
  });

  @override
  State<ShareExpenseWithFriendPage> createState() => _ShareExpenseWithFriendPageState();
}

class _ShareExpenseWithFriendPageState extends State<ShareExpenseWithFriendPage> {
  final TextEditingController receiverController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  NovaExpense? selectedExpense;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    selectedExpense = widget.expenses.isEmpty ? null : widget.expenses.first;
  }

  @override
  void dispose() {
    receiverController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final expense = selectedExpense;
    final receiver = receiverController.text.trim();
    if (expense == null || receiver.isEmpty || sending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Masraf ve gönderilecek kişi zorunlu.")),
      );
      return;
    }

    setState(() => sending = true);
    try {
      await widget.onSend(
        expense: expense,
        receiverText: receiver,
        note: noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Masraf paylaşımı gönderildi.")),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Masraf gönderilemedi.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NovaFullScreenSheet(
      title: "Arkadaşımla Masraf Paylaş",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaCardTitle(
            title: "Masraf Seç",
            subtitle: "Kayıtlı masraflarından birini seçip arkadaşına gönderebilirsin.",
          ),
          const SizedBox(height: 14),
          ...widget.expenses.take(25).map((expense) {
            final selected = selectedExpense?.id == expense.id;
            return GestureDetector(
              onTap: () => setState(() => selectedExpense = expense),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: selected ? Colors.black : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: selected ? Colors.black : Colors.black12),
                ),
                child: Row(
                  children: [
                    Icon(expense.icon, color: selected ? Colors.white : expense.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w900,
                              fontFamily: "Roboto",
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "${expense.category} • ${widget.formatMoney(expense.price)} TL",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w700,
                              fontFamily: "Roboto",
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected) const Icon(Icons.check_circle_rounded, color: Colors.white),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          const SheetLabel("Gönderilecek kişi"),
          const SizedBox(height: 8),
          NovaInput(
            controller: receiverController,
            hint: "Kullanıcı adı, isim veya telefon yaz",
          ),
          const SizedBox(height: 12),
          const SheetLabel("Not"),
          const SizedBox(height: 8),
          NovaInput(
            controller: noteController,
            hint: "Örn: Bu yakıt masrafını ortak bölüşelim.",
          ),
          const SizedBox(height: 18),
          BottomActionButton(
            title: sending ? "Gönderiliyor..." : "Masrafı Gönder",
            icon: Icons.send_rounded,
            color: Colors.black,
            onTap: submit,
          ),
        ],
      ),
    );
  }
}

class NovaFullScreenSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const NovaFullScreenSheet({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.black),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontFamily: "Roboto",
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E5E5)),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 96,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
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
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 88,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Roboto",
                  ),
                ),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SheetLabel extends StatelessWidget {
  final String text;

  const SheetLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.black54,
        fontWeight: FontWeight.w800,
        fontSize: 13,
        fontFamily: "Roboto",
      ),
    );
  }
}

class NovaInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const NovaInput({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w800,
        fontFamily: "Roboto",
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.black38,
          fontFamily: "Roboto",
        ),
        filled: true,
        fillColor: Colors.black.withOpacity(0.035),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.black),
        ),
      ),
    );
  }
}

class NovaSystemNoteBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const NovaSystemNoteBox({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    fontFamily: "Roboto",
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.35,
                    fontFamily: "Roboto",
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

class NovaProgressLine extends StatelessWidget {
  final String title;
  final double percent;
  final String value;

  const NovaProgressLine({
    super.key,
    required this.title,
    required this.percent,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Roboto",
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w900,
                fontFamily: "Roboto",
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(
            children: [
              Container(height: 10, color: Colors.black.withOpacity(0.07)),
              FractionallySizedBox(
                widthFactor: percent.clamp(0, 1),
                child: Container(height: 10, color: Colors.black),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class NovaMiniTag extends StatelessWidget {
  final String text;

  const NovaMiniTag({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.055),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 11.5,
          fontFamily: "Roboto",
        ),
      ),
    );
  }
}
