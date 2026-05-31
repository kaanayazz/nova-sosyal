import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage>
    with SingleTickerProviderStateMixin {
  String? leftBrand;
  String? leftModel;
  String? leftPackage;

  String? rightBrand;
  String? rightModel;
  String? rightPackage;

  double leftDraftScore = 7.5;
  double rightDraftScore = 7.5;

  bool loading = false;
  bool firebaseLoading = true;
  String? firebaseError;

  late final AnimationController neonController;

  Map<String, dynamic> vehicleData = {
    'BMW': {
      'logo': 'https://upload.wikimedia.org/wikipedia/commons/4/44/BMW.svg',
      'models': {
        '3 Serisi': {
          'image':
          'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&w=1200&q=80',
          'packages': {
            '320i M Sport': {
              'zeroPrice': 3650000,
              'usedPrice': 2850000,
              'ratingTotal': 421,
              'ratingCount': 49,
              'engine': '1.6 Turbo Benzin',
              'powerText': '170 HP',
              'torqueText': '250 Nm',
              'fuelText': '6.5 L / 100 km',
              'gear': '8 ileri otomatik',
              'traction': 'Arkadan itiş',
              'accelerationText': '7.6 sn',
              'topSpeedText': '235 km/s',
              'power': 170,
              'torque': 250,
              'fuel': 74,
              'acceleration': 84,
              'topSpeed': 86,
              'comfort': 88,
              'safety': 89,
              'maintenance': 68,
              'market': 90,
              'handling': 92,
              'features': {
                'Dijital klima': true,
                'Adaptif hız sabitleyici': true,
                'Şerit takip': true,
                'Geri görüş kamerası': true,
                'Anahtarsız giriş': true,
                'Elektrikli koltuk': true,
                'Ambiyans aydınlatma': true,
                'Kablosuz şarj': false,
              },
            },
            '320i Luxury Line': {
              'zeroPrice': 3450000,
              'usedPrice': 2650000,
              'ratingTotal': 386,
              'ratingCount': 46,
              'engine': '1.6 Turbo Benzin',
              'powerText': '170 HP',
              'torqueText': '250 Nm',
              'fuelText': '6.6 L / 100 km',
              'gear': '8 ileri otomatik',
              'traction': 'Arkadan itiş',
              'accelerationText': '7.8 sn',
              'topSpeedText': '232 km/s',
              'power': 170,
              'torque': 250,
              'fuel': 76,
              'acceleration': 82,
              'topSpeed': 84,
              'comfort': 91,
              'safety': 88,
              'maintenance': 70,
              'market': 87,
              'handling': 86,
              'features': {
                'Dijital klima': true,
                'Adaptif hız sabitleyici': false,
                'Şerit takip': true,
                'Geri görüş kamerası': true,
                'Anahtarsız giriş': true,
                'Elektrikli koltuk': true,
                'Ambiyans aydınlatma': true,
                'Kablosuz şarj': false,
              },
            },
          },
        },
        '5 Serisi': {
          'image':
          'https://images.unsplash.com/photo-1556189250-72ba954cfc2b?auto=format&fit=crop&w=1200&q=80',
          'packages': {
            '520i M Sport': {
              'zeroPrice': 5650000,
              'usedPrice': 4250000,
              'ratingTotal': 514,
              'ratingCount': 57,
              'engine': '1.6 Turbo Benzin',
              'powerText': '170 HP',
              'torqueText': '250 Nm',
              'fuelText': '7.1 L / 100 km',
              'gear': '8 ileri otomatik',
              'traction': 'Arkadan itiş',
              'accelerationText': '8.3 sn',
              'topSpeedText': '226 km/s',
              'power': 170,
              'torque': 250,
              'fuel': 68,
              'acceleration': 78,
              'topSpeed': 80,
              'comfort': 96,
              'safety': 94,
              'maintenance': 61,
              'market': 92,
              'handling': 88,
              'features': {
                'Dijital klima': true,
                'Adaptif hız sabitleyici': true,
                'Şerit takip': true,
                'Geri görüş kamerası': true,
                'Anahtarsız giriş': true,
                'Elektrikli koltuk': true,
                'Ambiyans aydınlatma': true,
                'Kablosuz şarj': true,
              },
            },
          },
        },
      },
    },
    'Audi': {
      'logo':
      'https://upload.wikimedia.org/wikipedia/commons/9/92/Audi-Logo_2016.svg',
      'models': {
        'A4': {
          'image':
          'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a?auto=format&fit=crop&w=1200&q=80',
          'packages': {
            'A4 S Line': {
              'zeroPrice': 3850000,
              'usedPrice': 3050000,
              'ratingTotal': 402,
              'ratingCount': 46,
              'engine': '2.0 TFSI',
              'powerText': '190 HP',
              'torqueText': '320 Nm',
              'fuelText': '6.9 L / 100 km',
              'gear': 'S tronic otomatik',
              'traction': 'Önden çekiş',
              'accelerationText': '7.3 sn',
              'topSpeedText': '240 km/s',
              'power': 190,
              'torque': 320,
              'fuel': 72,
              'acceleration': 87,
              'topSpeed': 89,
              'comfort': 90,
              'safety': 92,
              'maintenance': 65,
              'market': 88,
              'handling': 89,
              'features': {
                'Dijital klima': true,
                'Adaptif hız sabitleyici': true,
                'Şerit takip': true,
                'Geri görüş kamerası': true,
                'Anahtarsız giriş': true,
                'Elektrikli koltuk': false,
                'Ambiyans aydınlatma': true,
                'Kablosuz şarj': true,
              },
            },
            'A4 Design': {
              'zeroPrice': 3550000,
              'usedPrice': 2750000,
              'ratingTotal': 354,
              'ratingCount': 43,
              'engine': '1.4 TFSI',
              'powerText': '150 HP',
              'torqueText': '250 Nm',
              'fuelText': '6.1 L / 100 km',
              'gear': 'S tronic otomatik',
              'traction': 'Önden çekiş',
              'accelerationText': '8.7 sn',
              'topSpeedText': '210 km/s',
              'power': 150,
              'torque': 250,
              'fuel': 75,
              'acceleration': 76,
              'topSpeed': 74,
              'comfort': 88,
              'safety': 91,
              'maintenance': 67,
              'market': 84,
              'handling': 82,
              'features': {
                'Dijital klima': true,
                'Adaptif hız sabitleyici': false,
                'Şerit takip': true,
                'Geri görüş kamerası': true,
                'Anahtarsız giriş': false,
                'Elektrikli koltuk': false,
                'Ambiyans aydınlatma': true,
                'Kablosuz şarj': false,
              },
            },
          },
        },
      },
    },
    'Volkswagen': {
      'logo':
      'https://upload.wikimedia.org/wikipedia/commons/6/6d/Volkswagen_logo_2019.svg',
      'models': {
        'Passat': {
          'image':
          'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&w=1200&q=80',
          'packages': {
            'Passat Highline': {
              'zeroPrice': 3100000,
              'usedPrice': 2300000,
              'ratingTotal': 472,
              'ratingCount': 55,
              'engine': '1.5 TSI',
              'powerText': '150 HP',
              'torqueText': '250 Nm',
              'fuelText': '5.8 L / 100 km',
              'gear': 'DSG otomatik',
              'traction': 'Önden çekiş',
              'accelerationText': '8.7 sn',
              'topSpeedText': '220 km/s',
              'power': 150,
              'torque': 250,
              'fuel': 82,
              'acceleration': 76,
              'topSpeed': 78,
              'comfort': 91,
              'safety': 90,
              'maintenance': 81,
              'market': 91,
              'handling': 80,
              'features': {
                'Dijital klima': true,
                'Adaptif hız sabitleyici': true,
                'Şerit takip': true,
                'Geri görüş kamerası': true,
                'Anahtarsız giriş': true,
                'Elektrikli koltuk': false,
                'Ambiyans aydınlatma': true,
                'Kablosuz şarj': true,
              },
            },
            'Passat Comfortline': {
              'zeroPrice': 2850000,
              'usedPrice': 2050000,
              'ratingTotal': 390,
              'ratingCount': 48,
              'engine': '1.5 TSI',
              'powerText': '150 HP',
              'torqueText': '250 Nm',
              'fuelText': '5.9 L / 100 km',
              'gear': 'DSG otomatik',
              'traction': 'Önden çekiş',
              'accelerationText': '8.9 sn',
              'topSpeedText': '218 km/s',
              'power': 150,
              'torque': 250,
              'fuel': 84,
              'acceleration': 74,
              'topSpeed': 76,
              'comfort': 86,
              'safety': 87,
              'maintenance': 83,
              'market': 88,
              'handling': 78,
              'features': {
                'Dijital klima': true,
                'Adaptif hız sabitleyici': false,
                'Şerit takip': false,
                'Geri görüş kamerası': true,
                'Anahtarsız giriş': false,
                'Elektrikli koltuk': false,
                'Ambiyans aydınlatma': false,
                'Kablosuz şarj': false,
              },
            },
          },
        },
      },
    },
  };

  @override
  void initState() {
    super.initState();

    neonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    loadVehicleDataFromFirebase();
  }

  @override
  void dispose() {
    neonController.dispose();
    super.dispose();
  }

  List<String> get brands => vehicleData.keys.toList();

  Future<void> loadVehicleDataFromFirebase() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('compareVehicles')
          .orderBy('name')
          .get();

      final Map<String, dynamic> liveData = {};

      for (final brandDoc in snapshot.docs) {
        final brandMap = brandDoc.data();
        final brandName = (brandMap['name'] ?? brandDoc.id).toString();
        final brandLogo = (brandMap['logo'] ?? '').toString();

        liveData[brandName] = {
          'logo': brandLogo,
          'docId': brandDoc.id,
          'models': <String, dynamic>{},
        };

        final modelSnapshot = await brandDoc.reference
            .collection('models')
            .orderBy('name')
            .get();

        for (final modelDoc in modelSnapshot.docs) {
          final modelMap = modelDoc.data();
          final modelName = (modelMap['name'] ?? modelDoc.id).toString();

          liveData[brandName]['models'][modelName] = {
            'image': (modelMap['image'] ?? '').toString(),
            'docId': modelDoc.id,
            'packages': <String, dynamic>{},
          };

          final packageSnapshot = await modelDoc.reference
              .collection('packages')
              .orderBy('name')
              .get();

          for (final packageDoc in packageSnapshot.docs) {
            final packageMap = Map<String, dynamic>.from(packageDoc.data());
            final packageName = (packageMap['name'] ?? packageDoc.id).toString();

            packageMap['name'] = packageName;
            packageMap['docPath'] = packageDoc.reference.path;
            packageMap['ratingTotal'] = _asNum(packageMap['ratingTotal'], 0);
            packageMap['ratingCount'] = _asInt(packageMap['ratingCount'], 0);
            packageMap['zeroPrice'] = _asInt(packageMap['zeroPrice'], 0);
            packageMap['usedPrice'] = _asInt(packageMap['usedPrice'], 0);
            packageMap['power'] = _asInt(packageMap['power'], 0);
            packageMap['torque'] = _asInt(packageMap['torque'], 0);
            packageMap['fuel'] = _asInt(packageMap['fuel'], 0);
            packageMap['acceleration'] = _asInt(packageMap['acceleration'], 0);
            packageMap['topSpeed'] = _asInt(packageMap['topSpeed'], 0);
            packageMap['comfort'] = _asInt(packageMap['comfort'], 0);
            packageMap['safety'] = _asInt(packageMap['safety'], 0);
            packageMap['maintenance'] = _asInt(packageMap['maintenance'], 0);
            packageMap['market'] = _asInt(packageMap['market'], 0);
            packageMap['handling'] = _asInt(packageMap['handling'], 0);
            packageMap['features'] = Map<String, bool>.from(packageMap['features'] ?? {});

            liveData[brandName]['models'][modelName]['packages'][packageName] = packageMap;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        if (liveData.isNotEmpty) vehicleData = liveData;
        firebaseLoading = false;
        firebaseError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        firebaseLoading = false;
        firebaseError = e.toString();
      });
    }
  }

  num _asNum(dynamic value, num fallback) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }


  List<String> modelsOf(String? brand) {
    if (brand == null) return [];
    return (vehicleData[brand]['models'] as Map<String, dynamic>).keys.toList();
  }

  List<String> packagesOf(String? brand, String? model) {
    if (brand == null || model == null) return [];
    return (vehicleData[brand]['models'][model]['packages']
    as Map<String, dynamic>)
        .keys
        .toList();
  }

  Map<String, dynamic>? selectedCar(String? brand, String? model, String? pack) {
    if (brand == null) return null;

    if (model == null) {
      return {
        'brand': brand,
        'logo': vehicleData[brand]['logo'],
        'model': null,
        'package': null,
        'image': null,
      };
    }

    final modelData = vehicleData[brand]['models'][model];

    if (pack == null) {
      return {
        'brand': brand,
        'logo': vehicleData[brand]['logo'],
        'model': model,
        'package': null,
        'image': modelData['image'],
      };
    }

    return {
      'brand': brand,
      'logo': vehicleData[brand]['logo'],
      'model': model,
      'package': pack,
      'image': modelData['image'],
      ...modelData['packages'][pack],
    };
  }

  bool get ready =>
      leftBrand != null &&
          leftModel != null &&
          leftPackage != null &&
          rightBrand != null &&
          rightModel != null &&
          rightPackage != null &&
          !loading;

  Future<void> simulateLoading() async {
    setState(() => loading = true);
    await Future.delayed(const Duration(milliseconds: 650));
    if (mounted) setState(() => loading = false);
  }

  String money(int value) {
    return '${value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
    )} TL';
  }

  Future<void> submitScore(Map<String, dynamic>? car, double score) async {
    if (car == null || car['package'] == null) return;

    setState(() {
      final data =
      vehicleData[car['brand']]['models'][car['model']]['packages'][car['package']];
      data['ratingTotal'] = (data['ratingTotal'] as num) + score;
      data['ratingCount'] = (data['ratingCount'] as int) + 1;
    });

    final docPath = car['docPath']?.toString();

    if (docPath != null && docPath.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.doc(docPath).update({
          'ratingTotal': FieldValue.increment(score),
          'ratingCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Puan Firebase’e kaydedilemedi: $e'),
            duration: const Duration(milliseconds: 1500),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Puanın gönderildi'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  double averageScore(Map<String, dynamic> car) {
    final total = car['ratingTotal'] as num;
    final count = car['ratingCount'] as int;
    if (count <= 0) return 0;
    return total / count;
  }

  int totalScore(Map<String, dynamic> car) {
    final keys = [
      'power',
      'torque',
      'fuel',
      'acceleration',
      'topSpeed',
      'comfort',
      'safety',
      'maintenance',
      'market',
      'handling',
    ];

    final total = keys.fold<int>(0, (sum, key) => sum + (car[key] as int));
    return (total / keys.length).round();
  }

  Map<String, dynamic> winnerCar(Map<String, dynamic> left, Map<String, dynamic> right) {
    return totalScore(left) >= totalScore(right) ? left : right;
  }

  void openCompareSummary(Map<String, dynamic> left, Map<String, dynamic> right) {
    final winner = winnerCar(left, right);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return NovaBottomSheet(
          title: "Karşılaştırma Özeti",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetLabel("Öne çıkan araç"),
              const SizedBox(height: 8),
              Text(
                "${winner['brand']} ${winner['model']} ${winner['package']}",
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              DetailLine(
                title: "Genel skor",
                value: "${totalScore(winner)} / 100",
              ),
              DetailLine(
                title: "Piyasa gücü",
                value: "${winner['market']} / 100",
              ),
              DetailLine(
                title: "Konfor",
                value: "${winner['comfort']} / 100",
              ),
              DetailLine(
                title: "Bakım uygunluğu",
                value: "${winner['maintenance']} / 100",
              ),
              const SizedBox(height: 12),
              const Text(
                "Bu sonuç motor, yakıt, konfor, güvenlik, bakım, piyasa ve yol tutuş değerlerinin toplam dengesine göre hazırlanmıştır.",
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void openMetricDetail({
    required String title,
    required String leftText,
    required String rightText,
    required int leftValue,
    required int rightValue,
    required Map<String, dynamic> left,
    required Map<String, dynamic> right,
  }) {
    final leftWins = leftValue >= rightValue;
    final better = leftWins ? left : right;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return NovaBottomSheet(
          title: "$title Detayı",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetLabel("Daha avantajlı"),
              const SizedBox(height: 8),
              Text(
                "${better['brand']} ${better['model']} ${better['package']}",
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              DetailLine(
                title: "1. Araç",
                value: leftText,
              ),
              DetailLine(
                title: "2. Araç",
                value: rightText,
              ),
              const SizedBox(height: 14),
              CompareDetailBar(
                leftValue: leftValue,
                rightValue: rightValue,
              ),
              const SizedBox(height: 14),
              Text(
                leftWins
                    ? "Bu metrikte 1. araç daha güçlü görünüyor. Kıyaslamada seçili veriler üzerinden avantajlı tarafta."
                    : "Bu metrikte 2. araç daha güçlü görünüyor. Kıyaslamada seçili veriler üzerinden avantajlı tarafta.",
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> generateAnalysisPool(Map<String, dynamic> left, Map<String, dynamic> right) {
    final analysisTypes = [
      'motor gücü',
      'tork üretimi',
      'yakıt ekonomisi',
      'konfor seviyesi',
      'bakım uygunluğu',
    ];

    return List.generate(500, (index) {
      final type = analysisTypes[index % analysisTypes.length];

      if (type == 'motor gücü') {
        final better = left['power'] >= right['power'] ? left : right;
        return '${index + 1}. Motor gücü tarafında ${better['brand']} ${better['model']} ${better['package']} daha atak bir karakter sunuyor. Bu fark özellikle hızlanma ve ara hızlanmalarda daha belirgin hissedilebilir.';
      }

      if (type == 'tork üretimi') {
        final better = left['torque'] >= right['torque'] ? left : right;
        return '${index + 1}. Tork üretimi açısından ${better['brand']} ${better['model']} ${better['package']} daha güçlü görünüyor. Şehir içi düşük devir kullanımında ve sollamalarda daha rahat tepki verebilir.';
      }

      if (type == 'yakıt ekonomisi') {
        final better = left['fuel'] >= right['fuel'] ? left : right;
        return '${index + 1}. Yakıt ekonomisi tarafında ${better['brand']} ${better['model']} ${better['package']} daha avantajlı duruyor. Günlük kullanımda uzun vadeli maliyeti azaltma potansiyeli daha yüksek.';
      }

      if (type == 'konfor seviyesi') {
        final better = left['comfort'] >= right['comfort'] ? left : right;
        return '${index + 1}. Konfor tarafında ${better['brand']} ${better['model']} ${better['package']} daha olgun bir kullanım sunuyor. Uzun yolda yalıtım, süspansiyon dengesi ve kabin hissi daha güçlü olabilir.';
      }

      final better = left['maintenance'] >= right['maintenance'] ? left : right;
      return '${index + 1}. Bakım uygunluğu tarafında ${better['brand']} ${better['model']} ${better['package']} daha mantıklı görünüyor. Servis, parça ve kullanım maliyeti açısından daha dengeli bir tercih olabilir.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final left = selectedCar(leftBrand, leftModel, leftPackage);
    final right = selectedCar(rightBrand, rightModel, rightPackage);

    final leftFull = ready ? left! : null;
    final rightFull = ready ? right! : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const NovaWhiteBackground(),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                if (firebaseLoading) ...[
                  const LoadingPanel(text: 'Firebase araç verileri yükleniyor...'),
                  const SizedBox(height: 14),
                ] else if (firebaseError != null) ...[
                  FirebaseInfoPanel(error: firebaseError!),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(
                      child: VehicleSelector(
                        title: '1. Araç',
                        brand: leftBrand,
                        model: leftModel,
                        package: leftPackage,
                        brands: brands,
                        models: modelsOf(leftBrand),
                        packages: packagesOf(leftBrand, leftModel),
                        onBrand: (value) {
                          setState(() {
                            leftBrand = value;
                            leftModel = null;
                            leftPackage = null;
                          });
                        },
                        onModel: (value) {
                          setState(() {
                            leftModel = value;
                            leftPackage = null;
                          });
                        },
                        onPackage: (value) async {
                          setState(() => leftPackage = value);
                          await simulateLoading();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: VehicleSelector(
                        title: '2. Araç',
                        brand: rightBrand,
                        model: rightModel,
                        package: rightPackage,
                        brands: brands,
                        models: modelsOf(rightBrand),
                        packages: packagesOf(rightBrand, rightModel),
                        onBrand: (value) {
                          setState(() {
                            rightBrand = value;
                            rightModel = null;
                            rightPackage = null;
                          });
                        },
                        onModel: (value) {
                          setState(() {
                            rightModel = value;
                            rightPackage = null;
                          });
                        },
                        onPackage: (value) async {
                          setState(() => rightPackage = value);
                          await simulateLoading();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: VehiclePreview(
                        car: left,
                        draftScore: leftDraftScore,
                        onScoreChanged: (v) {
                          setState(() => leftDraftScore = v);
                        },
                        onSubmitScore: () => submitScore(left, leftDraftScore),
                        money: money,
                        averageScore: left != null && left['package'] != null
                            ? averageScore(left)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: VehiclePreview(
                        car: right,
                        draftScore: rightDraftScore,
                        onScoreChanged: (v) {
                          setState(() => rightDraftScore = v);
                        },
                        onSubmitScore: () => submitScore(right, rightDraftScore),
                        money: money,
                        averageScore: right != null && right['package'] != null
                            ? averageScore(right)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (loading)
                  const LoadingPanel()
                else if (!ready)
                  const EmptyComparePanel()
                else ...[
                    ResultPanel(
                      left: leftFull!,
                      right: rightFull!,
                      leftScore: totalScore(leftFull),
                      rightScore: totalScore(rightFull),
                      onTap: () => openCompareSummary(leftFull, rightFull),
                    ),
                    const SizedBox(height: 16),
                    ScoreOverviewChart(
                      left: leftFull,
                      right: rightFull,
                      leftScore: totalScore(leftFull),
                      rightScore: totalScore(rightFull),
                      onTap: () => openCompareSummary(leftFull, rightFull),
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: "Teknik Kıyaslama",
                      subtitle: "Her satıra tıklayarak detayını görebilirsin.",
                      child: Column(
                        children: [
                          FeatureCompareBar(
                            title: 'Motor Gücü',
                            leftText: leftFull['powerText'],
                            rightText: rightFull['powerText'],
                            leftValue: leftFull['power'],
                            rightValue: rightFull['power'],
                            onTap: () => openMetricDetail(
                              title: 'Motor Gücü',
                              leftText: leftFull['powerText'],
                              rightText: rightFull['powerText'],
                              leftValue: leftFull['power'],
                              rightValue: rightFull['power'],
                              left: leftFull,
                              right: rightFull,
                            ),
                          ),
                          FeatureCompareBar(
                            title: 'Tork',
                            leftText: leftFull['torqueText'],
                            rightText: rightFull['torqueText'],
                            leftValue: leftFull['torque'],
                            rightValue: rightFull['torque'],
                            onTap: () => openMetricDetail(
                              title: 'Tork',
                              leftText: leftFull['torqueText'],
                              rightText: rightFull['torqueText'],
                              leftValue: leftFull['torque'],
                              rightValue: rightFull['torque'],
                              left: leftFull,
                              right: rightFull,
                            ),
                          ),
                          FeatureCompareBar(
                            title: 'Yakıt Tüketimi',
                            leftText: leftFull['fuelText'],
                            rightText: rightFull['fuelText'],
                            leftValue: leftFull['fuel'],
                            rightValue: rightFull['fuel'],
                            onTap: () => openMetricDetail(
                              title: 'Yakıt Tüketimi',
                              leftText: leftFull['fuelText'],
                              rightText: rightFull['fuelText'],
                              leftValue: leftFull['fuel'],
                              rightValue: rightFull['fuel'],
                              left: leftFull,
                              right: rightFull,
                            ),
                          ),
                          FeatureCompareBar(
                            title: 'Hızlanma',
                            leftText: leftFull['accelerationText'],
                            rightText: rightFull['accelerationText'],
                            leftValue: leftFull['acceleration'],
                            rightValue: rightFull['acceleration'],
                            onTap: () => openMetricDetail(
                              title: 'Hızlanma',
                              leftText: leftFull['accelerationText'],
                              rightText: rightFull['accelerationText'],
                              leftValue: leftFull['acceleration'],
                              rightValue: rightFull['acceleration'],
                              left: leftFull,
                              right: rightFull,
                            ),
                          ),
                          FeatureCompareBar(
                            title: 'Maksimum Hız',
                            leftText: leftFull['topSpeedText'],
                            rightText: rightFull['topSpeedText'],
                            leftValue: leftFull['topSpeed'],
                            rightValue: rightFull['topSpeed'],
                            onTap: () => openMetricDetail(
                              title: 'Maksimum Hız',
                              leftText: leftFull['topSpeedText'],
                              rightText: rightFull['topSpeedText'],
                              leftValue: leftFull['topSpeed'],
                              rightValue: rightFull['topSpeed'],
                              left: leftFull,
                              right: rightFull,
                            ),
                          ),
                          FeatureCompareBar(
                            title: 'Konfor',
                            leftText: '${leftFull['comfort']} seviye',
                            rightText: '${rightFull['comfort']} seviye',
                            leftValue: leftFull['comfort'],
                            rightValue: rightFull['comfort'],
                            onTap: () => openMetricDetail(
                              title: 'Konfor',
                              leftText: '${leftFull['comfort']} seviye',
                              rightText: '${rightFull['comfort']} seviye',
                              leftValue: leftFull['comfort'],
                              rightValue: rightFull['comfort'],
                              left: leftFull,
                              right: rightFull,
                            ),
                          ),
                          FeatureCompareBar(
                            title: 'Güvenlik',
                            leftText: '${leftFull['safety']} seviye',
                            rightText: '${rightFull['safety']} seviye',
                            leftValue: leftFull['safety'],
                            rightValue: rightFull['safety'],
                            onTap: () => openMetricDetail(
                              title: 'Güvenlik',
                              leftText: '${leftFull['safety']} seviye',
                              rightText: '${rightFull['safety']} seviye',
                              leftValue: leftFull['safety'],
                              rightValue: rightFull['safety'],
                              left: leftFull,
                              right: rightFull,
                            ),
                          ),
                          FeatureCompareBar(
                            title: 'Bakım Uygunluğu',
                            leftText: '${leftFull['maintenance']} seviye',
                            rightText: '${rightFull['maintenance']} seviye',
                            leftValue: leftFull['maintenance'],
                            rightValue: rightFull['maintenance'],
                            onTap: () => openMetricDetail(
                              title: 'Bakım Uygunluğu',
                              leftText: '${leftFull['maintenance']} seviye',
                              rightText: '${rightFull['maintenance']} seviye',
                              leftValue: leftFull['maintenance'],
                              rightValue: rightFull['maintenance'],
                              left: leftFull,
                              right: rightFull,
                            ),
                          ),
                          FeatureCompareBar(
                            title: 'Piyasa Gücü',
                            leftText: '${leftFull['market']} seviye',
                            rightText: '${rightFull['market']} seviye',
                            leftValue: leftFull['market'],
                            rightValue: rightFull['market'],
                            onTap: () => openMetricDetail(
                              title: 'Piyasa Gücü',
                              leftText: '${leftFull['market']} seviye',
                              rightText: '${rightFull['market']} seviye',
                              leftValue: leftFull['market'],
                              rightValue: rightFull['market'],
                              left: leftFull,
                              right: rightFull,
                            ),
                          ),
                          FeatureCompareBar(
                            title: 'Yol Tutuş',
                            leftText: '${leftFull['handling']} seviye',
                            rightText: '${rightFull['handling']} seviye',
                            leftValue: leftFull['handling'],
                            rightValue: rightFull['handling'],
                            onTap: () => openMetricDetail(
                              title: 'Yol Tutuş',
                              leftText: '${leftFull['handling']} seviye',
                              rightText: '${rightFull['handling']} seviye',
                              leftValue: leftFull['handling'],
                              rightValue: rightFull['handling'],
                              left: leftFull,
                              right: rightFull,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnalysisSection(
                      analyses: generateAnalysisPool(leftFull, rightFull),
                    ),
                    const SizedBox(height: 16),
                    ParallelFeaturesSection(
                      left: leftFull,
                      right: rightFull,
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleSelector extends StatelessWidget {
  final String title;
  final String? brand;
  final String? model;
  final String? package;
  final List<String> brands;
  final List<String> models;
  final List<String> packages;
  final ValueChanged<String> onBrand;
  final ValueChanged<String> onModel;
  final ValueChanged<String> onPackage;

  const VehicleSelector({
    super.key,
    required this.title,
    required this.brand,
    required this.model,
    required this.package,
    required this.brands,
    required this.models,
    required this.packages,
    required this.onBrand,
    required this.onModel,
    required this.onPackage,
  });

  @override
  Widget build(BuildContext context) {
    return CleanCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            NovaSelect(
              hint: 'Marka seç',
              value: brand,
              items: brands,
              onChanged: onBrand,
            ),
            const SizedBox(height: 8),
            NovaSelect(
              hint: brand == null ? 'Önce marka' : 'Model seç',
              value: model,
              items: models,
              enabled: brand != null,
              onChanged: onModel,
            ),
            const SizedBox(height: 8),
            NovaSelect(
              hint: model == null ? 'Önce model' : 'Paket seç',
              value: package,
              items: packages,
              enabled: model != null,
              onChanged: onPackage,
            ),
          ],
        ),
      ),
    );
  }
}

class NovaSelect extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const NovaSelect({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: enabled
            ? Colors.black.withOpacity(0.035)
            : Colors.black.withOpacity(0.015),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: enabled
              ? items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }).toList()
              : [],
          onChanged: enabled
              ? (value) {
            if (value != null) onChanged(value);
          }
              : null,
        ),
      ),
    );
  }
}

class VehiclePreview extends StatelessWidget {
  final Map<String, dynamic>? car;
  final double draftScore;
  final ValueChanged<double> onScoreChanged;
  final VoidCallback onSubmitScore;
  final String Function(int value) money;
  final double? averageScore;

  const VehiclePreview({
    super.key,
    required this.car,
    required this.draftScore,
    required this.onScoreChanged,
    required this.onSubmitScore,
    required this.money,
    required this.averageScore,
  });

  @override
  Widget build(BuildContext context) {
    if (car == null) {
      return const CleanCard(
        child: SizedBox(
          height: 330,
          child: Center(
            child: Text(
              'Araç seçimi bekleniyor',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    final hasModel = car!['model'] != null;
    final hasPackage = car!['package'] != null;

    return CleanCard(
      child: Column(
        children: [
          SizedBox(
            height: 136,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasModel && car!['image'] != null)
                  Image.network(
                    car!['image'],
                    fit: BoxFit.cover,
                  )
                else
                  Container(color: Colors.black.withOpacity(0.035)),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.28),
                      ],
                    ),
                  ),
                ),
                if (!hasPackage)
                  Center(
                    child: Container(
                      width: hasModel ? 46 : 76,
                      height: hasModel ? 46 : 76,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Image.network(car!['logo']),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              children: [
                Text(
                  '${car!['brand']} ${car!['model'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  car!['package'] ?? 'Paket seçimi bekleniyor',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                if (hasPackage) ...[
                  const SizedBox(height: 10),
                  RatingBox(
                    draftScore: draftScore,
                    averageScore: averageScore ?? 0,
                    ratingCount: car!['ratingCount'],
                    onScoreChanged: onScoreChanged,
                    onSubmitScore: onSubmitScore,
                  ),
                  const SizedBox(height: 10),
                  PriceMini(title: '0 KM', value: money(car!['zeroPrice'])),
                  const SizedBox(height: 6),
                  PriceMini(title: '2. EL', value: money(car!['usedPrice'])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RatingBox extends StatelessWidget {
  final double draftScore;
  final double averageScore;
  final int ratingCount;
  final ValueChanged<double> onScoreChanged;
  final VoidCallback onSubmitScore;

  const RatingBox({
    super.key,
    required this.draftScore,
    required this.averageScore,
    required this.ratingCount,
    required this.onScoreChanged,
    required this.onSubmitScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            'Puan ${averageScore.toStringAsFixed(1)} / 10',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$ratingCount oy',
            style: const TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
          Slider(
            value: draftScore,
            min: 0,
            max: 10,
            divisions: 20,
            activeColor: const Color(0xFFFF2E88),
            inactiveColor: Colors.black12,
            onChanged: onScoreChanged,
          ),
          SizedBox(
            height: 36,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubmitScore,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Gönder: ${draftScore.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PriceMini extends StatelessWidget {
  final String title;
  final String value;

  const PriceMini({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black45,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingPanel extends StatelessWidget {
  final String text;

  const LoadingPanel({
    super.key,
    this.text = 'Paket verileri yükleniyor...',
  });

  @override
  Widget build(BuildContext context) {
    return CleanCard(
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}


class FirebaseInfoPanel extends StatelessWidget {
  final String error;

  const FirebaseInfoPanel({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return CleanCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.black45),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Firebase verisi alınamadı, sayfa yedek araç listesiyle açıldı. $error',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyComparePanel extends StatelessWidget {
  const EmptyComparePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const CleanCard(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'Karşılaştırma için iki araçta marka, model ve paket seç.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class ResultPanel extends StatelessWidget {
  final Map<String, dynamic> left;
  final Map<String, dynamic> right;
  final int leftScore;
  final int rightScore;
  final VoidCallback onTap;

  const ResultPanel({
    super.key,
    required this.left,
    required this.right,
    required this.leftScore,
    required this.rightScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final leftWins = leftScore >= rightScore;
    final winner = leftWins ? left : right;

    return GestureDetector(
      onTap: onTap,
      child: SectionCard(
        title: "NOVA Sonucu",
        subtitle: "Genel denge ve piyasa analizine göre.",
        child: Column(
          children: [
            Text(
              '${winner['brand']} ${winner['model']} ${winner['package']} daha avantajlı görünüyor.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            CompareScoreLine(
              leftLabel: "${left['brand']} ${left['model']}",
              rightLabel: "${right['brand']} ${right['model']}",
              leftScore: leftScore,
              rightScore: rightScore,
            ),
          ],
        ),
      ),
    );
  }
}

class ScoreOverviewChart extends StatelessWidget {
  final Map<String, dynamic> left;
  final Map<String, dynamic> right;
  final int leftScore;
  final int rightScore;
  final VoidCallback onTap;

  const ScoreOverviewChart({
    super.key,
    required this.left,
    required this.right,
    required this.leftScore,
    required this.rightScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: "Genel Performans Grafiği",
      subtitle: "Skor kartına dokunarak özet detayı açabilirsin.",
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            CompareScoreColumn(
              title: "${left['brand']} ${left['model']}",
              score: leftScore,
              color1: const Color(0xFFFF2E88),
              color2: const Color(0xFF3C7BFF),
            ),
            const SizedBox(height: 14),
            CompareScoreColumn(
              title: "${right['brand']} ${right['model']}",
              score: rightScore,
              color1: const Color(0xFF00D9FF),
              color2: const Color(0xFFFF7A00),
            ),
          ],
        ),
      ),
    );
  }
}

class CompareScoreColumn extends StatelessWidget {
  final String title;
  final int score;
  final Color color1;
  final Color color2;

  const CompareScoreColumn({
    super.key,
    required this.title,
    required this.score,
    required this.color1,
    required this.color2,
  });

  @override
  Widget build(BuildContext context) {
    final percent = score.clamp(0, 100) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              "$score / 100",
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(
            children: [
              Container(
                height: 14,
                color: Colors.black.withOpacity(0.07),
              ),
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color1, color2],
                    ),
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

class CompareScoreLine extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final int leftScore;
  final int rightScore;

  const CompareScoreLine({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftScore,
    required this.rightScore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MiniScoreBox(
            title: leftLabel,
            score: "$leftScore",
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MiniScoreBox(
            title: rightLabel,
            score: "$rightScore",
          ),
        ),
      ],
    );
  }
}

class MiniScoreBox extends StatelessWidget {
  final String title;
  final String score;

  const MiniScoreBox({
    super.key,
    required this.title,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "$score / 100",
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureCompareBar extends StatelessWidget {
  final String title;
  final String leftText;
  final String rightText;
  final int leftValue;
  final int rightValue;
  final VoidCallback onTap;

  const FeatureCompareBar({
    super.key,
    required this.title,
    required this.leftText,
    required this.rightText,
    required this.leftValue,
    required this.rightValue,
    required this.onTap,
  });

  bool get leftWins => leftValue >= rightValue;

  @override
  Widget build(BuildContext context) {
    final total = leftValue + rightValue;
    final leftPercent = total == 0 ? 0.5 : leftValue / total;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.07)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: Colors.black38,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    leftText,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: leftWins ? Colors.black : Colors.black45,
                      fontSize: leftWins ? 13 : 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: Colors.black12),
                        ),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: leftPercent,
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF2E88),
                                Color(0xFF7C4DFF),
                                Color(0xFF3C7BFF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment(
                          leftPercent.clamp(0.08, 0.92) * 2 - 1,
                          0,
                        ),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF00B8).withOpacity(0.30),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rightText,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: !leftWins ? Colors.black : Colors.black45,
                      fontSize: !leftWins ? 13 : 12,
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

class CompareDetailBar extends StatelessWidget {
  final int leftValue;
  final int rightValue;

  const CompareDetailBar({
    super.key,
    required this.leftValue,
    required this.rightValue,
  });

  @override
  Widget build(BuildContext context) {
    final total = leftValue + rightValue;
    final leftPercent = total == 0 ? 0.5 : leftValue / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Stack(
        children: [
          Container(
            height: 18,
            color: Colors.black.withOpacity(0.07),
          ),
          FractionallySizedBox(
            widthFactor: leftPercent,
            child: Container(
              height: 18,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFF2E88),
                    Color(0xFF3C7BFF),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnalysisSection extends StatelessWidget {
  final List<String> analyses;

  const AnalysisSection({
    super.key,
    required this.analyses,
  });

  @override
  Widget build(BuildContext context) {
    final shown = [
      analyses[0],
      analyses[101],
      analyses[202],
      analyses[303],
      analyses[404],
    ];

    return SectionCard(
      title: 'Detaylı Araç Analizleri',
      subtitle: 'NOVA seçili araçların karakterini yorumlar.',
      child: Column(
        children: shown.map((text) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.035),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.07)),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
                height: 1.38,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ParallelFeaturesSection extends StatelessWidget {
  final Map<String, dynamic> left;
  final Map<String, dynamic> right;

  const ParallelFeaturesSection({
    super.key,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    final leftFeatures = Map<String, bool>.from(left['features']);
    final rightFeatures = Map<String, bool>.from(right['features']);
    final keys = leftFeatures.keys.toList();

    return SectionCard(
      title: 'Konfor ve Özellik Kıyaslaması',
      subtitle: 'İki aracın donanımlarını yan yana incele.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${left['brand']} ${left['model']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'Özellik',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black45,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${right['brand']} ${right['model']}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          ...keys.map((key) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Icon(
                      leftFeatures[key]!
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: leftFeatures[key]!
                          ? const Color(0xFF00C853)
                          : Colors.black26,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      key,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        rightFeatures[key]!
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: rightFeatures[key]!
                            ? const Color(0xFF00C853)
                            : Colors.black26,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CleanCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NovaCardTitle(
              title: title,
              subtitle: subtitle,
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class CleanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const CleanCard({
    super.key,
    required this.child,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
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
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFF2E88),
                Color(0xFF3C7BFF),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class NovaWhiteBackground extends StatelessWidget {
  const NovaWhiteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.white);
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
                style: const TextStyle(
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

class SheetLabel extends StatelessWidget {
  final String text;

  const SheetLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black54,
        fontWeight: FontWeight.w800,
        fontSize: 13,
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}