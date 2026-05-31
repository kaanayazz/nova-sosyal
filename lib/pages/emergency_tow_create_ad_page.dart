import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;
    setState(() => selectedImage = File(image.path));
  }

  void removeSelectedImage() => setState(() => selectedImage = null);

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
    final random = Random.secure();
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
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> submitAd() async {
    if (isPublishing) return;

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
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
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
                value: selectedCity.isEmpty || selectedDistrict.isEmpty ? 'Profilde il / ilçe eksik' : '$selectedCity / $selectedDistrict',
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
              ImagePickerBox(imageFile: selectedImage, onPick: pickImageFromGallery, onRemove: removeSelectedImage),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Verilen Hizmetler'),
              const SizedBox(height: 10),
              ServiceSwitchTile(title: '7/24 çekici', value: isOpen247, onChanged: (v) => setState(() => isOpen247 = v)),
              ServiceSwitchTile(title: 'Kaza çekimi', value: acceptsAccidentTow, onChanged: (v) => setState(() => acceptsAccidentTow = v)),
              ServiceSwitchTile(title: 'Yol yardım', value: acceptsRoadHelp, onChanged: (v) => setState(() => acceptsRoadHelp = v)),
              ServiceSwitchTile(title: 'Akü takviye', value: acceptsBatterySupport, onChanged: (v) => setState(() => acceptsBatterySupport = v)),
              ServiceSwitchTile(title: 'Lastik destek', value: acceptsTireSupport, onChanged: (v) => setState(() => acceptsTireSupport = v)),
              ServiceSwitchTile(title: 'Şehirler arası taşıma', value: acceptsLongDistanceTow, onChanged: (v) => setState(() => acceptsLongDistanceTow = v)),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: isPublishing ? null : submitAd,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(
                    isPublishing ? 'Yayınlanıyor...' : 'İlanı Önizle',
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
            style: TextStyle(fontFamily: 'Roboto', fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black),
          ),
          const SizedBox(height: 10),
          ReadOnlyInfoTile(icon: Icons.person_rounded, title: 'Yetkili adı', value: ownerNameController.text.trim()),
          const SizedBox(height: 8),
          ReadOnlyInfoTile(icon: Icons.phone_rounded, title: 'Telefon', value: phoneController.text.trim()),
        ],
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
        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), shape: BoxShape.circle),
            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Çekici ilanını oluştur', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('Yetkili bilgileri profilden gelir, görsel JPG olarak Storage’a kaydedilir.', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', color: Colors.white70, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700)),
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
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const ImagePickerBox({super.key, required this.imageFile, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (imageFile != null) {
      return Container(
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black, width: 1.4)),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(aspectRatio: 16 / 9, child: Image.file(imageFile!, fit: BoxFit.cover)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: onPick, icon: const Icon(Icons.photo_library_rounded), label: const Text('Değiştir', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)), style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: const BorderSide(color: Colors.black), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton.icon(onPressed: onRemove, icon: const Icon(Icons.delete_rounded), label: const Text('Kaldır', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
              ],
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.035), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black, width: 1.4)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded, color: Colors.black, size: 52),
            SizedBox(height: 12),
            Text('Galeriden çekici görseli seç', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 15, fontWeight: FontWeight.w900)),
            SizedBox(height: 5),
            Text('Görsel Storage’a .jpg olarak yüklenecek', textScaler: TextScaler.noScaling, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Roboto', color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w700)),
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
    return Text(title, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900));
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

  const NovaTextField({super.key, required this.controller, required this.label, required this.hint, required this.icon, this.keyboardType, this.minLines = 1, this.maxLines = 1, this.inputFormatters, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 14, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.black),
        labelStyle: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontWeight: FontWeight.w800),
        hintStyle: const TextStyle(fontFamily: 'Roboto', color: Colors.black26, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: Colors.black.withOpacity(0.035),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.black.withOpacity(0.10))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.black, width: 1.3)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.red, width: 1.3)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.red, width: 1.3)),
      ),
    );
  }
}

class ServiceSwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ServiceSwitchTile({super.key, required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black.withOpacity(0.06))),
      child: Row(
        children: [
          Icon(value ? Icons.check_circle_rounded : Icons.circle_outlined, color: value ? Colors.black : Colors.black26),
          const SizedBox(width: 10),
          Expanded(child: Text(title, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900))),
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

  const ReadOnlyInfoTile({super.key, required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF8F8FA), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.08))),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(value, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 14.5, fontWeight: FontWeight.w900)),
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

  const ProfileStatusBox({super.key, required this.icon, required this.title, required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: isError ? Colors.red : Colors.black12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isError ? Colors.red : Colors.black, size: 25),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', color: isError ? Colors.red : Colors.black, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(message, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontSize: 13, height: 1.35, fontWeight: FontWeight.w800)),
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

  const CreatedTowAdPreviewSheet({super.key, required this.companyName, required this.ownerName, required this.city, required this.district, required this.phone, required this.price, required this.description, required this.imageFile, required this.services, required this.onPublish, this.isPublishing = false});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.84,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 18),
            ClipRRect(borderRadius: BorderRadius.circular(24), child: AspectRatio(aspectRatio: 16 / 9, child: Image.file(imageFile, fit: BoxFit.cover))),
            const SizedBox(height: 16),
            Text(companyName, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('$ownerName • $city / $district', textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            DetailBox(icon: Icons.phone_rounded, title: 'Telefon', value: phone),
            const SizedBox(height: 10),
            DetailBox(icon: Icons.payments_rounded, title: 'Ücret', value: price),
            const SizedBox(height: 10),
            DetailBox(icon: Icons.description_rounded, title: 'Açıklama', value: description),
            const SizedBox(height: 18),
            const Text('Hizmetler', textScaler: TextScaler.noScaling, style: TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: services.map((service) => ServiceChip(text: service)).toList()),
            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isPublishing ? null : onPublish,
                icon: const Icon(Icons.publish_rounded),
                label: Text(isPublishing ? 'Yayınlanıyor...' : 'Yayına Al', textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              ),
            ),
          ],
        );
      },
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
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.045), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 25),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(value, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w700, height: 1.35)),
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
      child: Text(text, textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class PublishingLoadingDialog extends StatelessWidget {
  const PublishingLoadingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 42, height: 42, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3)),
              SizedBox(height: 16),
              Text('Çekici ilanı yayına alınıyor', textScaler: TextScaler.noScaling, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 17, fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text('Görsel JPG olarak yükleniyor, lütfen bekle.', textScaler: TextScaler.noScaling, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontSize: 12.5, fontWeight: FontWeight.w700)),
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
    if (digits.isEmpty) return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    final limited = digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;
    final formatted = '₺${formatThousands(limited)}';
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
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
