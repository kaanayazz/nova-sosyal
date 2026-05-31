import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class CarAdCreatePage extends StatefulWidget {
  const CarAdCreatePage({super.key});

  @override
  State<CarAdCreatePage> createState() => _CarAdCreatePageState();
}

class _CarAdCreatePageState extends State<CarAdCreatePage> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final ImagePicker picker = ImagePicker();
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  bool isPublishing = false;
  bool isProfileLoading = true;
  String profileError = '';

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController kmController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  final TextEditingController damagePriceController = TextEditingController();

  int stepIndex = 0;

  String selectedCategory = '';
  String selectedCategoryId = '';
  String selectedBrand = '';
  String selectedBrandId = '';
  String selectedModel = '';
  String selectedModelId = '';
  String selectedPackage = '';
  String selectedPackageId = '';
  String selectedEngine = '';
  String selectedEngineId = '';

  String selectedCity = '';
  String selectedDistrict = '';
  String selectedGear = 'Otomatik';
  String selectedDamage = 'Yok';

  final List<File> selectedImages = [];
  final List<String> selectedChangedParts = [];

  final List<String> fallbackCategories = const [
    'Otomobil',
    'Arazi, SUV & Pickup',
    'Elektrikli Araçlar',
    'Motosiklet',
    'Minivan & Panelvan',
    'Ticari Araçlar',
  ];

  final List<String> fallbackBrands = const [
    'Audi',
    'BMW',
    'Mercedes-Benz',
    'Volkswagen',
    'Renault',
    'Fiat',
    'Ford',
    'Honda',
    'Hyundai',
    'Peugeot',
  ];

  final List<String> fallbackModels = const [
    'A1',
    'A3',
    'A4',
    'A5',
    'A6',
    '320i',
    '520i',
    'Golf',
    'Megane',
    'Egea',
  ];

  final List<String> fallbackPackages = const [
    'Standart',
    'Design',
    'Dynamic',
    'Sport',
    'S-Line',
    'M Sport',
    'AMG',
    'Icon',
  ];

  final List<String> fallbackEngines = const [
    '1.4 TFSI',
    '1.6',
    '1.8 TFSI',
    '2.0 TDI',
    '40 TDI',
    '45 TFSI',
    'Elektrik',
    'Hibrit',
  ];

  final List<String> gears = const [
    'Otomatik',
    'Manuel',
    'Yarı Otomatik',
  ];

  final List<String> damageOptions = const [
    'Yok',
    'Var',
  ];

  final List<String> changedParts = const [
    'Değişen yok',
    'Ön kaput',
    'Tavan',
    'Bagaj kapağı',
    'Sol ön çamurluk',
    'Sağ ön çamurluk',
    'Sol arka çamurluk',
    'Sağ arka çamurluk',
    'Sol ön kapı',
    'Sağ ön kapı',
    'Sol arka kapı',
    'Sağ arka kapı',
    'Ön tampon',
    'Arka tampon',
  ];

  @override
  void initState() {
    super.initState();
    loadProfileData();
  }

  String get stepTitle {
    if (stepIndex == 0) return 'Vasıta Seç';
    if (stepIndex == 1) return selectedCategory;
    if (stepIndex == 2) return selectedBrand;
    if (stepIndex == 3) return selectedModel;
    if (stepIndex == 4) return selectedPackage;
    return 'Araç İlan Ver';
  }

  String get selectedPath {
    final parts = [
      selectedCategory,
      selectedBrand,
      selectedModel,
      selectedPackage,
      selectedEngine,
    ].where((e) => e.trim().isNotEmpty).toList();

    return parts.join(' > ');
  }

  bool get isProfileReady {
    return usernameController.text.trim().isNotEmpty &&
        phoneController.text.trim().isNotEmpty &&
        selectedCity.trim().isNotEmpty &&
        selectedDistrict.trim().isNotEmpty;
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    kmController.dispose();
    priceController.dispose();
    phoneController.dispose();
    usernameController.dispose();
    yearController.dispose();
    damagePriceController.dispose();
    super.dispose();
  }

  Future<void> loadProfileData() async {
    final user = auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        isProfileLoading = false;
        profileError = 'İlan vermek için giriş yapmalısın.';
      });
      return;
    }

    try {
      final doc = await firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      final username = readFirstString(data, [
        'username',
        'userName',
        'nameSurname',
        'fullName',
        'displayName',
        'name',
      ]);

      final phone = readFirstString(data, [
        'phone',
        'phoneNumber',
        'telefon',
        'mobile',
        'gsm',
      ]);

      final city = readFirstString(data, [
        'city',
        'il',
        'province',
      ]);

      final district = readFirstString(data, [
        'district',
        'ilce',
        'county',
      ]);

      if (!mounted) return;
      setState(() {
        usernameController.text = username;
        phoneController.text = formatPhone(phone);
        selectedCity = city;
        selectedDistrict = district;
        isProfileLoading = false;
        profileError = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isProfileLoading = false;
        profileError = 'Profil bilgileri okunamadı: $e';
      });
    }
  }

  String readFirstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String formatPhone(String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 10) {
      return '${clean.substring(0, 3)} ${clean.substring(3, 6)} ${clean.substring(6, 8)} ${clean.substring(8, 10)}';
    }
    if (clean.length == 11) {
      return '${clean.substring(0, 4)} ${clean.substring(4, 7)} ${clean.substring(7, 9)} ${clean.substring(9, 11)}';
    }
    return value.trim();
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
        .doc(selectedPackageId)
        .collection('engines');
  }

  List<CatalogItem> fallbackItems() {
    List<String> list;
    if (stepIndex == 0) {
      list = fallbackCategories;
    } else if (stepIndex == 1) {
      list = fallbackBrands;
    } else if (stepIndex == 2) {
      list = fallbackModels;
    } else if (stepIndex == 3) {
      list = fallbackPackages;
    } else {
      list = fallbackEngines;
    }

    return list.map((name) {
      return CatalogItem(
        id: createSafeId(name),
        name: name,
      );
    }).toList();
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

  void selectStepItem(CatalogItem item) {
    setState(() {
      if (stepIndex == 0) {
        selectedCategory = item.name;
        selectedCategoryId = item.id;
        selectedBrand = '';
        selectedBrandId = '';
        selectedModel = '';
        selectedModelId = '';
        selectedPackage = '';
        selectedPackageId = '';
        selectedEngine = '';
        selectedEngineId = '';
        stepIndex = 1;
      } else if (stepIndex == 1) {
        selectedBrand = item.name;
        selectedBrandId = item.id;
        selectedModel = '';
        selectedModelId = '';
        selectedPackage = '';
        selectedPackageId = '';
        selectedEngine = '';
        selectedEngineId = '';
        stepIndex = 2;
      } else if (stepIndex == 2) {
        selectedModel = item.name;
        selectedModelId = item.id;
        selectedPackage = '';
        selectedPackageId = '';
        selectedEngine = '';
        selectedEngineId = '';
        stepIndex = 3;
      } else if (stepIndex == 3) {
        selectedPackage = item.name;
        selectedPackageId = item.id;
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

  void goBack() {
    if (stepIndex == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      stepIndex--;
      if (stepIndex < 4) {
        selectedEngine = '';
        selectedEngineId = '';
      }
      if (stepIndex < 3) {
        selectedPackage = '';
        selectedPackageId = '';
      }
      if (stepIndex < 2) {
        selectedModel = '';
        selectedModelId = '';
      }
      if (stepIndex < 1) {
        selectedBrand = '';
        selectedBrandId = '';
      }
    });
  }

  String? requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bu alan boş bırakılamaz';
    }
    return null;
  }

  String? descriptionValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Açıklama gerekli';
    if (text.length > 5000) return 'Açıklama en fazla 5000 karakter olabilir';
    return null;
  }

  String? yearValidator(String? value) {
    final clean = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (clean.length != 4) return 'Model yılı 4 haneli olmalı';
    final year = int.tryParse(clean);
    if (year == null || year < 1900 || year > 2030) {
      return 'Model yılı 1900 - 2030 arası olmalı';
    }
    return null;
  }

  String? kmValidator(String? value) {
    final clean = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (clean.isEmpty) return 'KM gerekli';
    if (clean.length > 7) return 'KM en fazla 7 haneli olabilir';
    return null;
  }

  String? priceValidator(String? value) {
    final clean = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (clean.isEmpty) return 'Fiyat gerekli';
    if (clean.length > 10) return 'Fiyat en fazla 10 haneli olabilir';
    return null;
  }

  String? damagePriceValidator(String? value) {
    if (selectedDamage == 'Yok') return null;
    final clean = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (clean.isEmpty) return 'Hasar tutarı gerekli';
    if (clean.length > 10) return 'Hasar tutarı en fazla 10 haneli olabilir';
    return null;
  }

  Future<void> pickImages() async {
    final remaining = 25 - selectedImages.length;

    if (remaining <= 0) {
      showMessage('En fazla 25 görsel ekleyebilirsin.');
      return;
    }

    final List<XFile> pickedImages = await picker.pickMultiImage(
      imageQuality: 85,
    );

    if (pickedImages.isEmpty) return;

    final limitedImages = pickedImages.take(remaining).toList();

    setState(() {
      selectedImages.addAll(
        limitedImages.map((image) => File(image.path)),
      );
    });

    if (pickedImages.length > remaining) {
      showMessage('25 görsel sınırı nedeniyle bazı görseller eklenmedi.');
    }
  }

  void removeImage(int index) {
    setState(() {
      selectedImages.removeAt(index);
    });
  }

  void toggleChangedPart(String part) {
    setState(() {
      if (selectedChangedParts.contains(part)) {
        selectedChangedParts.remove(part);
      } else {
        if (part == 'Değişen yok') {
          selectedChangedParts
            ..clear()
            ..add(part);
        } else {
          selectedChangedParts.remove('Değişen yok');
          selectedChangedParts.add(part);
        }
      }
    });
  }

  Future<void> publishAd() async {
    if (isPublishing) return;

    if (auth.currentUser == null) {
      showMessage('İlan yayınlamak için giriş yapmalısın.');
      return;
    }

    if (!isProfileReady) {
      showMessage('Profilinde kullanıcı adı, telefon, il ve ilçe kayıtlı olmalı.');
      return;
    }

    if (!formKey.currentState!.validate()) return;

    if (selectedImages.isEmpty) {
      showMessage('En az 1 araç görseli eklemelisin.');
      return;
    }

    if (selectedChangedParts.isEmpty) {
      showMessage('Değişen bilgisini seçmelisin.');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return CarAdPreviewSheet(
          title: titleController.text.trim(),
          username: usernameController.text.trim(),
          price: priceController.text.trim(),
          km: kmController.text.trim(),
          year: yearController.text.trim(),
          phone: phoneController.text.trim(),
          city: selectedCity,
          district: selectedDistrict,
          gear: selectedGear,
          damage: selectedDamage,
          damagePrice: damagePriceController.text.trim(),
          path: selectedPath,
          image: selectedImages.first,
          changedParts: selectedChangedParts,
          isPublishing: isPublishing,
          onPublish: () async {
            Navigator.pop(context);
            final user = auth.currentUser;
            if (user != null) await uploadAndSaveAd(user);
          },
        );
      },
    );
  }

  String createAdNo() {
    final random = Random.secure();
    final firstDigit = random.nextInt(9) + 1;
    final otherDigits = List.generate(9, (_) => random.nextInt(10)).join();
    return '$firstDigit$otherDigits';
  }

  int digitsToInt(String value) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  Future<List<String>> uploadImages(String uid, String adId) async {
    final urls = <String>[];

    for (int i = 0; i < selectedImages.length; i++) {
      final file = selectedImages[i];

      // Storage tarafında tüm araç görselleri .jpg olarak kaydedilir.
      final ref = storage.ref().child('carAds/$uid/$adId/image_$i.jpg');

      final task = await ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedAs': 'jpg',
            'adId': adId,
            'ownerId': uid,
          },
        ),
      );

      final url = await task.ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  void openPublishingLoading() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.74),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const PublishingLoadingScreen();
      },
    );
  }

  void closePublishingLoading() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> uploadAndSaveAd(User user) async {
    if (isPublishing) return;

    setState(() => isPublishing = true);
    openPublishingLoading();

    try {
      final docRef = firestore.collection('carAds').doc();
      final adId = docRef.id;
      final adNo = createAdNo();
      final imageUrls = await uploadImages(user.uid, adId);
      final now = FieldValue.serverTimestamp();
      final formattedPrice = priceController.text.trim();
      final formattedKm = kmController.text.trim();
      final damageAmount = selectedDamage == 'Var' ? damagePriceController.text.trim() : '';

      await docRef.set({
        'id': adId,
        'userId': user.uid,
        'userEmail': user.email,
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'seller': usernameController.text.trim(),
        'username': usernameController.text.trim(),
        'sellerPhone': phoneController.text.trim(),
        'category': selectedCategory,
        'categoryId': selectedCategoryId,
        'brand': selectedBrand,
        'brandId': selectedBrandId,
        'series': selectedModel,
        'modelName': selectedModel,
        'modelId': selectedModelId,
        'model': selectedPackage,
        'package': selectedPackage,
        'packageId': selectedPackageId,
        'engine': selectedEngine,
        'engineId': selectedEngineId,
        'categoryPath': selectedPath,
        'city': selectedCity,
        'district': selectedDistrict,
        'location': '$selectedCity / $selectedDistrict',
        'price': formattedPrice,
        'priceValue': digitsToInt(formattedPrice),
        'priceText': formattedPrice.startsWith('₺') ? formattedPrice : '₺$formattedPrice',
        'km': formattedKm,
        'kmValue': digitsToInt(formattedKm),
        'year': yearController.text.trim(),
        'yearValue': digitsToInt(yearController.text.trim()),
        'gear': selectedGear,
        'damage': selectedDamage,
        'damageRecord': selectedDamage,
        'damageAmount': damageAmount,
        'damageAmountValue': digitsToInt(damageAmount),
        'changedParts': selectedChangedParts,
        'image': imageUrls.first,
        'images': imageUrls,
        'adNo': adNo,
        'date': '',
        'fuel': '',
        'condition': 'İkinci El',
        'body': '',
        'power': '',
        'engineVolume': selectedEngine,
        'traction': '',
        'color': '',
        'warranty': '',
        'plate': 'Türkiye (TR) Plakalı',
        'from': 'Sahibinden',
        'trade': '',
        'features': selectedChangedParts,
        'status': 'active',
        'isApproved': true,
        'createdAt': now,
        'updatedAt': now,
      });

      if (!mounted) return;
      closePublishingLoading();
      setState(() => isPublishing = false);
      showMessage('Araç ilanı yayına alındı.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      closePublishingLoading();
      setState(() => isPublishing = false);
      showMessage('İlan yayınlanamadı: $e');
    }
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
            onPressed: goBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            stepTitle,
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
        body: stepIndex < 5 ? buildStepList() : buildForm(),
      ),
    );
  }

  Widget buildStepList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stepCollection().orderBy('order').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final panelItems = docs.map((doc) {
          final data = doc.data();
          final name = (data['name'] ?? data['title'] ?? doc.id).toString().trim();
          return CatalogItem(id: doc.id, name: name);
        }).where((item) => item.name.isNotEmpty).toList();

        final items = panelItems.isNotEmpty ? panelItems : fallbackItems();

        return Column(
          children: [
            if (panelItems.isEmpty)
              const PanelInfoBox(
                text: '      İlan Vermek Araç Kategorinizi seçin ve devam edin',
              ),
            Expanded(
              child: CreateAdSelectList(
                items: items,
                onTap: selectStepItem,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildForm() {
    return Form(
      key: formKey,
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          CreateAdPathBox(path: selectedPath),
          const SizedBox(height: 12),
          buildProfileBox(),
          const SizedBox(height: 14),
          const SectionTitle(title: 'Araç Görselleri'),
          const SizedBox(height: 10),
          ImagePickerArea(
            images: selectedImages,
            onPick: pickImages,
            onRemove: removeImage,
          ),
          const SizedBox(height: 18),
          const SectionTitle(title: 'İlan Bilgileri'),
          const SizedBox(height: 10),
          NovaTextField(
            controller: titleController,
            label: 'Başlık',
            hint: 'Örn: Değişensiz temiz Audi A4',
            icon: Icons.title_rounded,
            validator: requiredValidator,
          ),
          const SizedBox(height: 10),
          NovaTextField(
            controller: descriptionController,
            label: 'Açıklama',
            hint: 'Aracın durumunu ve önemli bilgileri yaz',
            icon: Icons.description_rounded,
            minLines: 5,
            maxLines: 8,
            maxLength: 5000,
            validator: descriptionValidator,
          ),
          const SizedBox(height: 10),
          NovaTextField(
            controller: yearController,
            label: 'Model Yılı',
            hint: 'Örn: 2020',
            icon: Icons.calendar_month_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: yearValidator,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: NovaTextField(
                  controller: kmController,
                  label: 'KM',
                  hint: '185.000',
                  icon: Icons.speed_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    ThousandsInputFormatter(maxDigits: 7),
                  ],
                  validator: kmValidator,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NovaTextField(
                  controller: priceController,
                  label: 'Fiyat',
                  hint: '₺1.215.000',
                  icon: Icons.payments_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    MoneyInputFormatter(maxDigits: 10),
                  ],
                  validator: priceValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionTitle(title: 'Konum ve Vites'),
          const SizedBox(height: 10),
          ReadOnlyInfoTile(
            icon: Icons.location_on_rounded,
            title: 'Konum',
            value: selectedCity.isEmpty || selectedDistrict.isEmpty
                ? 'Profilde konum eksik'
                : '$selectedCity / $selectedDistrict',
          ),
          const SizedBox(height: 10),
          BlackDropdown(
            value: selectedGear,
            items: gears,
            onChanged: (value) {
              if (value == null) return;
              setState(() => selectedGear = value);
            },
          ),
          const SizedBox(height: 18),
          const SectionTitle(title: 'Hasar Kaydı'),
          const SizedBox(height: 10),
          BlackDropdown(
            value: selectedDamage,
            items: damageOptions,
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                selectedDamage = value;
                if (selectedDamage == 'Yok') damagePriceController.clear();
              });
            },
          ),
          if (selectedDamage == 'Var') ...[
            const SizedBox(height: 10),
            NovaTextField(
              controller: damagePriceController,
              label: 'Hasar Tutarı',
              hint: '₺25.000',
              icon: Icons.car_crash_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [
                MoneyInputFormatter(maxDigits: 10),
              ],
              validator: damagePriceValidator,
            ),
          ],
          const SizedBox(height: 18),
          const SectionTitle(title: 'Değişen Parçalar'),
          const SizedBox(height: 10),
          ChangedPartsList(
            parts: changedParts,
            selectedParts: selectedChangedParts,
            onTap: toggleChangedPart,
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: isPublishing ? null : publishAd,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                isPublishing ? 'Yayınlanıyor...' : 'Araç İlanını Yayınla',
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProfileBox() {
    if (isProfileLoading) {
      return const ProfileStatusBox(
        icon: Icons.hourglass_top_rounded,
        title: 'Profil bilgileri okunuyor',
        message: 'Kullanıcı adı, telefon ve konum profilden otomatik çekiliyor.',
        isError: false,
      );
    }

    if (profileError.isNotEmpty) {
      return ProfileStatusBox(
        icon: Icons.error_rounded,
        title: 'Profil okunamadı',
        message: profileError,
        isError: true,
      );
    }

    if (!isProfileReady) {
      return const ProfileStatusBox(
        icon: Icons.lock_rounded,
        title: 'Profil eksik',
        message: 'İlan vermek için profilde kullanıcı adı, telefon numarası, il ve ilçe kayıtlı olmalı.',
        isError: true,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Satıcı Bilgileri',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          ReadOnlyInfoTile(
            icon: Icons.alternate_email_rounded,
            title: 'Kullanıcı adı',
            value: usernameController.text.trim(),
          ),
          const SizedBox(height: 8),
          ReadOnlyInfoTile(
            icon: Icons.phone_rounded,
            title: 'Telefon',
            value: phoneController.text.trim(),
          ),
        ],
      ),
    );
  }
}

class CatalogItem {
  final String id;
  final String name;

  const CatalogItem({
    required this.id,
    required this.name,
  });
}

class ThousandsInputFormatter extends TextInputFormatter {
  final int maxDigits;

  ThousandsInputFormatter({required this.maxDigits});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;
    final formatted = formatThousands(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class MoneyInputFormatter extends TextInputFormatter {
  final int maxDigits;

  MoneyInputFormatter({required this.maxDigits});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final limited = digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;
    final formatted = '₺${formatThousands(limited)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String formatThousands(String digits) {
  if (digits.isEmpty) return '';
  final buffer = StringBuffer();
  int count = 0;
  for (int i = digits.length - 1; i >= 0; i--) {
    buffer.write(digits[i]);
    count++;
    if (count == 3 && i != 0) {
      buffer.write('.');
      count = 0;
    }
  }
  return buffer.toString().split('').reversed.join();
}

class PanelInfoBox extends StatelessWidget {
  final String text;

  const PanelInfoBox({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.white,
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ProfileStatusBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  const ProfileStatusBox({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isError ? Colors.red : Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isError ? Colors.red : Colors.black, size: 25),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: isError ? Colors.red : Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black54,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
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

class ReadOnlyInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const ReadOnlyInfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 22),
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
                    color: Colors.black45,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_rounded, color: Colors.black26, size: 18),
        ],
      ),
    );
  }
}

class CreateAdSelectList extends StatelessWidget {
  final List<CatalogItem> items;
  final ValueChanged<CatalogItem> onTap;

  const CreateAdSelectList({
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
        color: Color(0xFFE6E6EA),
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return InkWell(
          onTap: () => onTap(item),
          child: Container(
            height: 60,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black87,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black38,
                  size: 24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CreateAdPathBox extends StatelessWidget {
  final String path;

  const CreateAdPathBox({
    super.key,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        path,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.white,
          fontSize: 13.5,
          height: 1.35,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class ImagePickerArea extends StatelessWidget {
  final List<File> images;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;

  const ImagePickerArea({
    super.key,
    required this.images,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 164,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black, width: 1.3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: Colors.black,
                  size: 48,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Galeriden araç görselleri seç',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${images.length}/25 görsel seçildi',
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
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 106,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        images[index],
                        width: 126,
                        height: 106,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => onRemove(index),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class ChangedPartsList extends StatelessWidget {
  final List<String> parts;
  final List<String> selectedParts;
  final ValueChanged<String> onTap;

  const ChangedPartsList({
    super.key,
    required this.parts,
    required this.selectedParts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      child: Column(
        children: parts.map((part) {
          final selected = selectedParts.contains(part);
          return InkWell(
            onTap: () => onTap(part),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEDEDF0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    color: selected ? Colors.black : Colors.black38,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      part,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.black,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textScaler: TextScaler.noScaling,
      style: const TextStyle(
        fontFamily: 'Roboto',
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class NovaTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const NovaTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(
        fontFamily: 'Roboto',
        color: Colors.black,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.black),
        filled: true,
        fillColor: Colors.white,
        counterStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.black45,
          fontWeight: FontWeight.w700,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.black54,
          fontWeight: FontWeight.w800,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.black26,
          fontWeight: FontWeight.w700,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.black.withOpacity(0.13),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Colors.black,
            width: 1.3,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1.3,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1.3,
          ),
        ),
      ),
    );
  }
}

class BlackDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const BlackDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : items.isNotEmpty ? items.first : null;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.black,
          ),
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class CarAdPreviewSheet extends StatelessWidget {
  final String title;
  final String username;
  final String price;
  final String km;
  final String year;
  final String phone;
  final String city;
  final String district;
  final String gear;
  final String damage;
  final String damagePrice;
  final String path;
  final File image;
  final List<String> changedParts;
  final VoidCallback onPublish;
  final bool isPublishing;

  const CarAdPreviewSheet({
    super.key,
    required this.title,
    required this.username,
    required this.price,
    required this.km,
    required this.year,
    required this.phone,
    required this.city,
    required this.district,
    required this.gear,
    required this.damage,
    required this.damagePrice,
    required this.path,
    required this.image,
    required this.changedParts,
    required this.onPublish,
    this.isPublishing = false,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(
                  image,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '@$username',
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              price,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Color(0xFF00A86B),
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            DetailLine(title: 'Seçim', value: path),
            DetailLine(title: 'Konum', value: '$city / $district'),
            DetailLine(title: 'Model yılı', value: year),
            DetailLine(title: 'KM', value: km),
            DetailLine(title: 'Vites', value: gear),
            DetailLine(title: 'Telefon', value: phone),
            DetailLine(title: 'Hasar', value: damage == 'Var' ? 'Var - $damagePrice' : 'Yok'),
            DetailLine(title: 'Değişen', value: changedParts.join(', ')),
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isPublishing ? null : onPublish,
                icon: const Icon(Icons.publish_rounded),
                label: Text(
                  isPublishing ? 'Yayınlanıyor...' : 'Yayına Al',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}


class PublishingLoadingScreen extends StatelessWidget {
  const PublishingLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Center(
            child: Container(
              width: 268,
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 4,
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'İlan yayına alınıyor',
                    textScaler: TextScaler.noScaling,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Görseller JPG olarak yükleniyor ve ilan Firebase’e kaydediliyor. Lütfen bekle.',
                    textScaler: TextScaler.noScaling,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black54,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E5E5)),
        ),
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
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
