import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

double novaSystemBottomGap(BuildContext context) {
  final bottom = MediaQuery.of(context).viewPadding.bottom;
  return bottom < 48 ? 48 : bottom + 8;
}

class EmergencyTowCreateAdPage extends StatefulWidget {
  const EmergencyTowCreateAdPage({super.key});

  @override
  State<EmergencyTowCreateAdPage> createState() => _EmergencyTowCreateAdPageState();
}

class _EmergencyTowCreateAdPageState extends State<EmergencyTowCreateAdPage> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final ImagePicker picker = ImagePicker();

  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  File? selectedImage;

  bool isPickingImage = false;
  bool isPublishing = false;
  bool isProfileLoading = true;
  String profileError = '';

  String selectedCity = '';
  String selectedDistrict = '';

  bool isOpen247 = true;
  bool acceptsAccidentTow = true;
  bool acceptsRoadHelp = true;
  bool acceptsBatterySupport = false;
  bool acceptsTireSupport = false;
  bool acceptsLongDistanceTow = false;

  @override
  void initState() {
    super.initState();
    loadProfileData();
  }

  bool get isProfileReady {
    return ownerNameController.text.trim().isNotEmpty &&
        phoneController.text.trim().isNotEmpty &&
        selectedCity.trim().isNotEmpty &&
        selectedDistrict.trim().isNotEmpty;
  }

  @override
  void dispose() {
    companyNameController.dispose();
    ownerNameController.dispose();
    phoneController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadProfileData() async {
    final user = auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        isProfileLoading = false;
        profileError = 'Çekici ilanı vermek için giriş yapmalısın.';
      });
      return;
    }

    try {
      final doc = await firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      final ownerName = readFirstString(data, [
        'authorizedName',
        'yetkiliAdi',
        'nameSurname',
        'fullName',
        'displayName',
        'name',
        'username',
      ]);

      final phone = readFirstString(data, [
        'phone',
        'phoneNumber',
        'telefon',
        'mobile',
        'gsm',
      ]);

      final city = readFirstString(data, ['city', 'il', 'province']);
      final district = readFirstString(data, ['district', 'ilce', 'county']);

      if (!mounted) return;
      setState(() {
        ownerNameController.text = ownerName;
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
      if (text.isNotEmpty && text != 'null') return text;
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

  String? requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Bu alan boş bırakılamaz';
    return null;
  }

  String? priceValidator(String? value) {
    final clean = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (clean.isEmpty) return 'Başlangıç ücreti gerekli';
    if (clean.length > 10) return 'Ücret en fazla 10 haneli olabilir';
    return null;
  }

  Future<void> pickImageFromGallery() async {
    if (isPickingImage || isPublishing) return;

    setState(() => isPickingImage = true);

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: 3000,
        maxHeight: 3000,
        requestFullMetadata: false,
      );

      if (image == null) return;

      final file = File(image.path);
      if (!await file.exists()) {
        if (mounted) {
          showMessage('Görsel dosyası okunamadı. Lütfen farklı bir görsel seç.');
        }
        return;
      }

      if (!mounted) return;
      await _openTowImageEditor(file, title: 'Çekici Görselini Ayarla');
    } on PlatformException catch (e) {
      if (!mounted) return;
      showMessage('Galeri açılamadı: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      showMessage('Görsel seçilirken hata oluştu: $e');
    } finally {
      if (mounted) setState(() => isPickingImage = false);
    }
  }

  Future<void> editSelectedImage() async {
    if (isPickingImage || isPublishing || selectedImage == null) return;
    setState(() => isPickingImage = true);
    try {
      await _openTowImageEditor(selectedImage!, title: 'Çekici Görselini Düzenle');
    } catch (e) {
      if (mounted) showMessage('Görsel düzenlenirken hata oluştu: $e');
    } finally {
      if (mounted) setState(() => isPickingImage = false);
    }
  }

  Future<void> _openTowImageEditor(File file, {required String title}) async {
    showPreparingImageDialog();
    await Future<void>.delayed(const Duration(milliseconds: 90));

    if (!mounted) return;
    closeTopDialogIfPossible();

    final File? editedFile = await Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (_) => TowImageEditorPage(
          sourceFile: file,
          title: title,
        ),
      ),
    );

    if (editedFile == null || !mounted) return;
    setState(() => selectedImage = editedFile);
  }

  void showPreparingImageDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ImagePreparingDialog(),
    );
  }

  void closeTopDialogIfPossible() {
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void removeSelectedImage() {
    if (isPickingImage || isPublishing) return;
    setState(() => selectedImage = null);
  }

  List<String> selectedServices() {
    final services = <String>[];
    if (isOpen247) services.add('7/24 çekici');
    if (acceptsAccidentTow) services.add('Kaza çekimi');
    if (acceptsRoadHelp) services.add('Yol yardım');
    if (acceptsBatterySupport) services.add('Akü takviye');
    if (acceptsTireSupport) services.add('Lastik destek');
    if (acceptsLongDistanceTow) services.add('Şehirler arası taşıma');
    return services;
  }

  String createTowAdNo() {
    final random = math.Random.secure();
    final firstDigit = random.nextInt(9) + 1;
    final otherDigits = List.generate(9, (_) => random.nextInt(10)).join();
    return '$firstDigit$otherDigits';
  }

  int digitsToInt(String value) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  Future<String> uploadTowImage(String uid, String adId) async {
    final file = selectedImage!;
    final ref = storage.ref().child('towAds/$uid/$adId/image_0.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  void showPublishingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PublishingLoadingDialog(),
    );
  }

  void closePublishingDialog() {
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> submitAd() async {
    if (isPublishing || isPickingImage) return;

    final user = auth.currentUser;
    if (user == null) {
      showMessage('Çekici ilanı vermek için giriş yapmalısın.');
      return;
    }

    if (!isProfileReady) {
      showMessage('Profilinde yetkili adı, telefon, il ve ilçe kayıtlı olmalı.');
      return;
    }

    if (!formKey.currentState!.validate()) return;

    if (selectedImage == null) {
      showMessage('Görsel boş bırakılamaz. Lütfen galeriden çekici görseli seç.');
      return;
    }

    final services = selectedServices();
    if (services.isEmpty) {
      showMessage('En az 1 hizmet seçmelisin.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return CreatedTowAdPreviewSheet(
          companyName: companyNameController.text.trim(),
          ownerName: ownerNameController.text.trim(),
          city: selectedCity,
          district: selectedDistrict,
          phone: phoneController.text.trim(),
          price: priceController.text.trim(),
          description: descriptionController.text.trim(),
          imageFile: selectedImage!,
          services: services,
          isPublishing: isPublishing,
          onPublish: () async {
            Navigator.pop(context);
            await uploadAndSaveTowAd(user, services);
          },
        );
      },
    );
  }

  Future<void> uploadAndSaveTowAd(User user, List<String> services) async {
    setState(() => isPublishing = true);
    showPublishingDialog();

    try {
      final docRef = firestore.collection('towAds').doc();
      final adId = docRef.id;
      final adNo = createTowAdNo();
      final imageUrl = await uploadTowImage(user.uid, adId);
      final now = FieldValue.serverTimestamp();
      final priceText = priceController.text.trim();

      await docRef.set({
        'id': adId,
        'userId': user.uid,
        'userEmail': user.email,
        'adNo': adNo,
        'companyName': companyNameController.text.trim(),
        'ownerName': ownerNameController.text.trim(),
        'authorizedName': ownerNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'city': selectedCity,
        'district': selectedDistrict,
        'location': '$selectedCity / $selectedDistrict',
        'price': priceText,
        'priceText': priceText.startsWith('₺') ? priceText : '₺$priceText',
        'priceValue': digitsToInt(priceText),
        'description': descriptionController.text.trim(),
        'services': services,
        'isOpen247': isOpen247,
        'acceptsAccidentTow': acceptsAccidentTow,
        'acceptsRoadHelp': acceptsRoadHelp,
        'acceptsBatterySupport': acceptsBatterySupport,
        'acceptsTireSupport': acceptsTireSupport,
        'acceptsLongDistanceTow': acceptsLongDistanceTow,
        'image': imageUrl,
        'images': [imageUrl],
        'imageType': 'jpg',
        'status': 'active',
        'isApproved': true,
        'createdAt': now,
        'updatedAt': now,
      });

      closePublishingDialog();
      if (!mounted) return;
      showMessage('Çekici ilanı yayına alındı.');
      Navigator.pop(context);
    } catch (e) {
      closePublishingDialog();
      if (!mounted) return;
      showMessage('Çekici ilanı yayınlanamadı: $e');
    } finally {
      if (mounted) setState(() => isPublishing = false);
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Çekici İlan Ver',
            textScaler: TextScaler.noScaling,
            style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
          ),
        ),
        body: Form(
          key: formKey,
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(14, 8, 14, novaSystemBottomGap(context)),
            children: [
              const CreateTowHero(),
              const SizedBox(height: 16),
              buildProfileBox(),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Firma Bilgileri'),
              const SizedBox(height: 10),
              NovaTextField(
                controller: companyNameController,
                label: 'Firma adı',
                hint: 'Örn: NOVA Çekici Hizmetleri',
                icon: Icons.business_rounded,
                validator: requiredValidator,
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Bölge Bilgisi'),
              const SizedBox(height: 10),
              ReadOnlyInfoTile(
                icon: Icons.location_on_rounded,
                title: 'Hizmet bölgesi',
                value: selectedCity.isEmpty || selectedDistrict.isEmpty
                    ? 'Profilde il / ilçe eksik'
                    : '$selectedCity / $selectedDistrict',
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Ücret ve Açıklama'),
              const SizedBox(height: 10),
              NovaTextField(
                controller: priceController,
                label: 'Başlangıç ücreti',
                hint: '₺750',
                icon: Icons.payments_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter(maxDigits: 10)],
                validator: priceValidator,
              ),
              const SizedBox(height: 10),
              NovaTextField(
                controller: descriptionController,
                label: 'Kısa açıklama',
                hint: 'Hizmet detaylarını yaz',
                icon: Icons.description_rounded,
                minLines: 3,
                maxLines: 5,
                validator: requiredValidator,
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Çekici Görseli'),
              const SizedBox(height: 10),
              ImagePickerBox(
                imageFile: selectedImage,
                isPicking: isPickingImage,
                onPick: pickImageFromGallery,
                onEdit: editSelectedImage,
                onRemove: removeSelectedImage,
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Verilen Hizmetler'),
              const SizedBox(height: 10),
              ServiceSwitchTile(
                title: '7/24 çekici',
                value: isOpen247,
                onChanged: (v) => setState(() => isOpen247 = v),
              ),
              ServiceSwitchTile(
                title: 'Kaza çekimi',
                value: acceptsAccidentTow,
                onChanged: (v) => setState(() => acceptsAccidentTow = v),
              ),
              ServiceSwitchTile(
                title: 'Yol yardım',
                value: acceptsRoadHelp,
                onChanged: (v) => setState(() => acceptsRoadHelp = v),
              ),
              ServiceSwitchTile(
                title: 'Akü takviye',
                value: acceptsBatterySupport,
                onChanged: (v) => setState(() => acceptsBatterySupport = v),
              ),
              ServiceSwitchTile(
                title: 'Lastik destek',
                value: acceptsTireSupport,
                onChanged: (v) => setState(() => acceptsTireSupport = v),
              ),
              ServiceSwitchTile(
                title: 'Şehirler arası taşıma',
                value: acceptsLongDistanceTow,
                onChanged: (v) => setState(() => acceptsLongDistanceTow = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isPublishing || isPickingImage ? null : submitAd,
                  icon: isPublishing
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    isPublishing ? 'Yayınlanıyor...' : 'İlanı Önizle',
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.black.withOpacity(0.55),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
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

  Widget buildProfileBox() {
    if (isProfileLoading) {
      return const ProfileStatusBox(
        icon: Icons.hourglass_top_rounded,
        title: 'Profil bilgileri okunuyor',
        message: 'Yetkili adı, telefon ve konum profilden otomatik çekiliyor.',
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
        message: 'İlan vermek için profilde yetkili adı, telefon numarası, il ve ilçe kayıtlı olmalı.',
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
            'Yetkili Bilgileri',
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
            icon: Icons.person_rounded,
            title: 'Yetkili adı',
            value: ownerNameController.text.trim(),
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


class _TowPhotoEditState extends ChangeNotifier {
  double scale = 1.0;
  Offset offset = Offset.zero;

  void updateScale(double value) {
    final next = value.clamp(1.0, 5.0).toDouble();
    if ((scale - next).abs() < 0.001) return;
    scale = next;
    notifyListeners();
  }

  void setOffsetSilently(Offset value) {
    offset = value;
  }

  void updateOffset(Offset value) {
    if (offset == value) return;
    offset = value;
    notifyListeners();
  }

  void reset() {
    scale = 1.0;
    offset = Offset.zero;
    notifyListeners();
  }
}

class TowImageEditorPage extends StatefulWidget {
  final File sourceFile;
  final String title;

  const TowImageEditorPage({
    super.key,
    required this.sourceFile,
    required this.title,
  });

  @override
  State<TowImageEditorPage> createState() => _TowImageEditorPageState();
}

class _TowImageEditorPageState extends State<TowImageEditorPage> {
  final _TowPhotoEditState editState = _TowPhotoEditState();

  Size? imageSize;
  bool isLoading = true;
  bool isSaving = false;

  static const double minScale = 1.0;
  static const double maxScale = 5.0;

  @override
  void initState() {
    super.initState();
    loadImageSize();
  }

  @override
  void dispose() {
    editState.dispose();
    super.dispose();
  }

  Future<void> loadImageSize() async {
    try {
      final bytes = await widget.sourceFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Görsel okunamadı.');
      final baked = img.bakeOrientation(decoded);
      if (!mounted) return;
      setState(() {
        imageSize = Size(baked.width.toDouble(), baked.height.toDouble());
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Görsel yüklenemedi: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Offset clampOffset({
    required Offset offset,
    required double scale,
    required double imageWidth,
    required double imageHeight,
    required double editorSize,
  }) {
    if (imageWidth <= 0 || imageHeight <= 0) return Offset.zero;

    final containScale = math.min(editorSize / imageWidth, editorSize / imageHeight);
    final visibleWidth = imageWidth * containScale * scale;
    final visibleHeight = imageHeight * containScale * scale;

    final maxDx = math.max(0.0, (visibleWidth - editorSize) / 2);
    final maxDy = math.max(0.0, (visibleHeight - editorSize) / 2);

    return Offset(
      offset.dx.clamp(-maxDx, maxDx).toDouble(),
      offset.dy.clamp(-maxDy, maxDy).toDouble(),
    );
  }

  Future<File> exportEditedImage() async {
    final bytes = await widget.sourceFile.readAsBytes();
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Görsel okunamadı.');
    decoded = img.bakeOrientation(decoded);

    const outputSize = 512;
    final sourceWidth = decoded.width.toDouble();
    final sourceHeight = decoded.height.toDouble();

    final containScale = math.min(outputSize / sourceWidth, outputSize / sourceHeight);
    final totalScale = containScale * editState.scale;

    final drawWidth = math.max(1, (sourceWidth * totalScale).round());
    final drawHeight = math.max(1, (sourceHeight * totalScale).round());

    final resized = img.copyResize(
      decoded,
      width: drawWidth,
      height: drawHeight,
      interpolation: img.Interpolation.average,
    );

    final canvas = img.Image(width: outputSize, height: outputSize);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    final safeOffset = clampOffset(
      offset: editState.offset,
      scale: editState.scale,
      imageWidth: sourceWidth,
      imageHeight: sourceHeight,
      editorSize: outputSize.toDouble(),
    );

    final dstX = ((outputSize - drawWidth) / 2 + safeOffset.dx).round();
    final dstY = ((outputSize - drawHeight) / 2 + safeOffset.dy).round();

    img.compositeImage(canvas, resized, dstX: dstX, dstY: dstY);

    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/nova_tow_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final file = File(path);
    await file.writeAsBytes(img.encodeJpg(canvas, quality: 94), flush: true);
    return file;
  }

  Future<void> saveAndClose() async {
    if (isSaving || isLoading) return;
    setState(() => isSaving = true);

    try {
      final file = await exportEditedImage();
      if (!mounted) return;
      Navigator.pop(context, file);
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Görsel kaydedilemedi: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  border: Border(bottom: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: isLoading || imageSize == null
                    ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Görsel yükleniyor...',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                )
                    : _TowEditableImageBox(
                  file: widget.sourceFile,
                  state: editState,
                  imageWidth: imageSize!.width,
                  imageHeight: imageSize!.height,
                  clampOffset: clampOffset,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Column(
                  children: [
                    const Text(
                      'Görsel editörde tam görünür. Tek parmakla konumlandır, alttaki çizgiyle yakınlaştır / uzaklaştır.',
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: editState,
                      builder: (context, _) {
                        return _TowZoomSliderBox(
                          value: editState.scale,
                          min: minScale,
                          max: maxScale,
                          enabled: !isSaving && !isLoading,
                          onChanged: (value) {
                            final next = value.clamp(minScale, maxScale).toDouble();
                            final size = imageSize;
                            if (size != null) {
                              final double editorSize = math.min<double>(MediaQuery.of(context).size.width, 430.0) - 30.0;
                              editState.offset = clampOffset(
                                offset: editState.offset,
                                scale: next,
                                imageWidth: size.width,
                                imageHeight: size.height,
                                editorSize: editorSize,
                              );
                            }
                            editState.updateScale(next);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSaving || isLoading ? null : editState.reset,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Sıfırla'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isSaving || isLoading ? null : saveAndClose,
                            icon: isSaving
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.2),
                            )
                                : const Icon(Icons.check_rounded),
                            label: Text(isSaving ? 'Kaydediliyor' : 'Kaydet ve Devam Et'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
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

class _TowEditableImageBox extends StatelessWidget {
  final File file;
  final _TowPhotoEditState state;
  final double imageWidth;
  final double imageHeight;
  final Offset Function({
  required Offset offset,
  required double scale,
  required double imageWidth,
  required double imageHeight,
  required double editorSize,
  }) clampOffset;

  const _TowEditableImageBox({
    super.key,
    required this.file,
    required this.state,
    required this.imageWidth,
    required this.imageHeight,
    required this.clampOffset,
  });

  void onPanUpdate(DragUpdateDetails details, double editorSize) {
    final clamped = clampOffset(
      offset: state.offset + details.delta,
      scale: state.scale,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      editorSize: editorSize,
    );
    state.updateOffset(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final double editorSize = math.min<double>(MediaQuery.of(context).size.width, 430.0) - 30.0;
    final safeWidth = imageWidth <= 0 ? 1.0 : imageWidth;
    final safeHeight = imageHeight <= 0 ? 1.0 : imageHeight;
    final containScale = math.min(editorSize / safeWidth, editorSize / safeHeight);
    final baseWidth = safeWidth * containScale;
    final baseHeight = safeHeight * containScale;

    state.setOffsetSilently(
      clampOffset(
        offset: state.offset,
        scale: state.scale,
        imageWidth: safeWidth,
        imageHeight: safeHeight,
        editorSize: editorSize,
      ),
    );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.20),
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Container(
              width: editorSize,
              height: editorSize,
              color: Colors.white,
              child: ClipRect(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => onPanUpdate(details, editorSize),
                  child: AnimatedBuilder(
                    animation: state,
                    builder: (context, _) {
                      return Center(
                        child: Transform.translate(
                          offset: state.offset,
                          child: Transform.scale(
                            scale: state.scale,
                            child: SizedBox(
                              width: baseWidth,
                              height: baseHeight,
                              child: Image.file(
                                file,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.low,
                                gaplessPlayback: true,
                                cacheWidth: 1600,
                                errorBuilder: (_, __, ___) {
                                  return const Center(
                                    child: Icon(Icons.broken_image_rounded, color: Colors.black, size: 44),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Beyaz karenin içinde görünen alan ilan görseli olacak.',
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TowZoomSliderBox extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _TowZoomSliderBox({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final percent = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Yakınlaştırma',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${value.toStringAsFixed(2)}x',
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 22),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
            ),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: 80,
              label: '${(percent * 100).round()}%',
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

class ImagePreparingDialog extends StatelessWidget {
  const ImagePreparingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
              ),
              SizedBox(height: 16),
              Text(
                'Görsel yükleniyor',
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Editör hazırlanıyor, lütfen bekle.',
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black54,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateTowHero extends StatelessWidget {
  const CreateTowHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Çekici ilanını oluştur',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Görsel editörde tam görünür, oranı bozulmadan 512x512 JPG hazırlanır.',
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

class ImagePickerBox extends StatelessWidget {
  final File? imageFile;
  final bool isPicking;
  final VoidCallback onPick;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const ImagePickerBox({
    super.key,
    required this.imageFile,
    this.isPicking = false,
    required this.onPick,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (imageFile != null) {
      return Container(
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.black, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: isPicking ? null : onEdit,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        imageFile!,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        cacheWidth: 1000,
                      ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            '512x512 JPG',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded, color: Colors.black, size: 15),
                              SizedBox(width: 4),
                              Text(
                                'Düzenle',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isPicking ? null : onPick,
                    icon: isPicking
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    )
                        : const Icon(Icons.photo_library_rounded),
                    label: Text(
                      isPicking ? 'Açılıyor...' : 'Değiştir',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isPicking ? null : onRemove,
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text(
                      'Kaldır',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: isPicking ? null : onPick,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 210,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.black, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isPicking
                ? const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
            )
                : const Icon(Icons.add_photo_alternate_rounded, color: Colors.black, size: 52),
            const SizedBox(height: 12),
            Text(
              isPicking ? 'Galeri açılıyor...' : 'Galeriden çekici görseli seç',
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Editörde tam gör, oranı bozmadan ayarla',
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

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
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(
        fontFamily: 'Roboto',
        color: Colors.black,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.black),
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
        filled: true,
        fillColor: Colors.black.withOpacity(0.035),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.black, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.red, width: 1.3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.red, width: 1.3),
        ),
      ),
    );
  }
}

class ServiceSwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ServiceSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: value ? Colors.black : Colors.black26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Switch(value: value, activeColor: Colors.black, onChanged: onChanged),
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

class CreatedTowAdPreviewSheet extends StatelessWidget {
  final String companyName;
  final String ownerName;
  final String city;
  final String district;
  final String phone;
  final String price;
  final String description;
  final File imageFile;
  final List<String> services;
  final VoidCallback onPublish;
  final bool isPublishing;

  const CreatedTowAdPreviewSheet({
    super.key,
    required this.companyName,
    required this.ownerName,
    required this.city,
    required this.district,
    required this.phone,
    required this.price,
    required this.description,
    required this.imageFile,
    required this.services,
    required this.onPublish,
    this.isPublishing = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            const SizedBox(height: 10),
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
            const SizedBox(height: 14),
            const Text(
              'İlan Önizleme',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(1.8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.black, width: 1.3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.file(imageFile, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    companyName,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$ownerName • $city / $district',
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black45,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DetailBox(icon: Icons.phone_rounded, title: 'Telefon', value: phone),
                  const SizedBox(height: 10),
                  DetailBox(icon: Icons.payments_rounded, title: 'Ücret', value: price),
                  const SizedBox(height: 10),
                  DetailBox(icon: Icons.description_rounded, title: 'Açıklama', value: description),
                  const SizedBox(height: 18),
                  const Text(
                    'Hizmetler',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: services.map((service) => ServiceChip(text: service)).toList(),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(18, 8, 18, novaSystemBottomGap(context)),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isPublishing ? null : onPublish,
                  icon: isPublishing
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Icon(Icons.publish_rounded),
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
                    disabledBackgroundColor: Colors.black.withOpacity(0.55),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const DetailBox({super.key, required this.icon, required this.title, required this.value});

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
          Icon(icon, color: Colors.black, size: 25),
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
                    height: 1.35,
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

class ServiceChip extends StatelessWidget {
  final String text;
  const ServiceChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(99)),
      child: Text(
        text,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class PublishingLoadingDialog extends StatelessWidget {
  const PublishingLoadingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
              ),
              SizedBox(height: 16),
              Text(
                'Çekici ilanı yayına alınıyor',
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Görsel JPG olarak yükleniyor, lütfen bekle.',
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black54,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MoneyInputFormatter extends TextInputFormatter {
  final int maxDigits;
  MoneyInputFormatter({required this.maxDigits});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
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
