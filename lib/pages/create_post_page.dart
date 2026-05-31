import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

enum PostVisibility { explore, followers }

class _CreatePostPageState extends State<CreatePostPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController neonController;

  final ImagePicker picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController captionController = TextEditingController();

  final List<File> selectedImageFiles = <File>[];
  static const int maxPostImages = 5;
  PostVisibility selectedVisibility = PostVisibility.explore;

  bool isSharing = false;
  double uploadProgress = 0;

  String lockedProfileLocation = '';
  bool profileLocationLoading = true;

  static const int captionLimit = 300;

  String get currentUid => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();

    neonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    captionController.addListener(_refresh);
    _loadLockedProfileLocation();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLockedProfileLocation() async {
    final uid = currentUid;

    if (uid.isEmpty) {
      if (mounted) {
        setState(() {
          lockedProfileLocation = '';
          profileLocationLoading = false;
        });
      }
      return;
    }

    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data() ?? <String, dynamic>{};
      final location = _profileLocation(data);

      if (!mounted) return;
      setState(() {
        lockedProfileLocation = location;
        profileLocationLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        lockedProfileLocation = '';
        profileLocationLoading = false;
      });
    }
  }

  @override
  void dispose() {
    neonController.dispose();
    captionController.removeListener(_refresh);
    captionController.dispose();
    super.dispose();
  }

  Future<void> pickImageFromGallery() async {
    if (isSharing) return;

    final int remaining = maxPostImages - selectedImageFiles.length;
    if (remaining <= 0) {
      showMessage('En fazla 5 fotoğraf seçebilirsin.');
      return;
    }

    try {
      final List<XFile> pickedFiles = await picker.pickMultiImage(
        imageQuality: 95,
        limit: remaining,
      );

      if (pickedFiles.isEmpty || !mounted) return;

      final List<XFile> limitedFiles = pickedFiles.take(remaining).toList();
      final List<File> readyFiles = <File>[];

      for (final XFile picked in limitedFiles) {
        final File jpgFile = await convertImageToJpg(File(picked.path));
        readyFiles.add(jpgFile);
      }

      if (!mounted) return;
      setState(() {
        selectedImageFiles.addAll(readyFiles);
      });

      if (pickedFiles.length > remaining) {
        showMessage('En fazla 5 fotoğraf seçilebilir. Fazla fotoğraflar eklenmedi.');
      }
    } catch (e) {
      showMessage('Görsel seçilirken hata oluştu: $e');
    }
  }

  Future<void> cropImage({required String imagePath, int? index}) async {
    if (isSharing) return;

    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 95,
        maxWidth: 1080,
        maxHeight: 1080,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '1080 x 1080 Post Görseli',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: '1080 x 1080 Post Görseli',
            doneButtonTitle: 'Tamam',
            cancelButtonTitle: 'İptal',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null || !mounted) return;

      final File jpgFile = await convertImageToJpg(File(croppedFile.path));
      if (!mounted) return;

      setState(() {
        if (index != null && index >= 0 && index < selectedImageFiles.length) {
          selectedImageFiles[index] = jpgFile;
        } else if (selectedImageFiles.length < maxPostImages) {
          selectedImageFiles.add(jpgFile);
        }
      });
    } catch (e) {
      showMessage('Kırpma ekranı açılamadı: $e');
    }
  }

  Future<void> editSelectedImage(int index) async {
    if (isSharing) return;
    if (index < 0 || index >= selectedImageFiles.length) return;
    await cropImage(imagePath: selectedImageFiles[index].path, index: index);
  }

  Future<File> convertImageToJpg(File file) async {
    final Uint8List bytes = await file.readAsBytes();
    final img.Image? decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) return file;

    final Directory tempDir = await getTemporaryDirectory();
    final String jpgPath =
        '${tempDir.path}/nova_post_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final img.Image squareImage = img.copyResizeCropSquare(
      decodedImage,
      size: 1080,
    );

    final File jpgFile = File(jpgPath);
    await jpgFile.writeAsBytes(
      img.encodeJpg(squareImage, quality: 95),
      flush: true,
    );

    return jpgFile;
  }

  void removeImage(int index) {
    if (isSharing) return;
    if (index < 0 || index >= selectedImageFiles.length) return;
    setState(() => selectedImageFiles.removeAt(index));
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

  String _visibilityValue() {
    switch (selectedVisibility) {
      case PostVisibility.followers:
        return 'followers';
      case PostVisibility.explore:
        return 'public';
    }
  }

  String _visibilityText() {
    switch (selectedVisibility) {
      case PostVisibility.followers:
        return 'Takipçilerin';
      case PostVisibility.explore:
        return 'NOVA Keşfet';
    }
  }

  String _feedTarget() {
    switch (selectedVisibility) {
      case PostVisibility.followers:
        return 'following';
      case PostVisibility.explore:
        return 'explore';
    }
  }

  String _safeString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _profileLocation(Map<String, dynamic> userData) {
    final city = _safeString(
      userData['city'] ?? userData['il'] ?? userData['province'],
    );
    final district = _safeString(
      userData['district'] ?? userData['ilce'] ?? userData['ilçe'] ?? userData['county'],
    );

    if (city.isNotEmpty && district.isNotEmpty) return '$city / $district';
    if (city.isNotEmpty) return city;
    if (district.isNotEmpty) return district;
    return '';
  }

  Future<void> sharePost() async {
    if (isSharing) return;

    final User? user = _auth.currentUser;
    final List<File> imageFiles = List<File>.from(selectedImageFiles);
    final String caption = captionController.text.trim();

    if (user == null) {
      showMessage('Post paylaşmak için giriş yapmalısın.');
      return;
    }

    if (imageFiles.isEmpty) {
      showMessage('Önce galeriden en az bir görsel seçmelisin.');
      return;
    }

    if (imageFiles.length > maxPostImages) {
      showMessage('En fazla 5 fotoğraf seçebilirsin.');
      return;
    }

    setState(() {
      isSharing = true;
      uploadProgress = 0;
    });

    try {
      final DocumentReference<Map<String, dynamic>> userRef =
      _db.collection('users').doc(user.uid);

      final DocumentSnapshot<Map<String, dynamic>> userDoc = await userRef.get();
      final Map<String, dynamic> userData = userDoc.data() ?? <String, dynamic>{};

      final bool profileCompleted = userData['profileCompleted'] == true;

      final String displayName = _safeString(
        userData['displayName'],
        fallback: _safeString(user.displayName),
      );

      final String username = _safeString(userData['username']);
      final String userPhoto = _safeString(
        userData['photoUrl'] ?? userData['userPhoto'] ?? userData['profileImage'],
        fallback: _safeString(user.photoURL),
      );
      final String userEmail = _safeString(
        userData['email'],
        fallback: _safeString(user.email),
      );
      final String userCity = _safeString(userData['city'] ?? userData['il']);
      final String userDistrict = _safeString(
        userData['district'] ?? userData['ilce'] ?? userData['ilçe'],
      );
      final String userBio = _safeString(userData['bio']);
      final String location = _profileLocation(userData);

      if (!userDoc.exists ||
          !profileCompleted ||
          displayName.isEmpty ||
          username.isEmpty ||
          userCity.isEmpty ||
          userDistrict.isEmpty) {
        if (!mounted) return;
        setState(() {
          isSharing = false;
          uploadProgress = 0;
        });
        showMessage('Post paylaşmak için profil bilgilerini tamamlamalısın.');
        return;
      }

      final DocumentReference<Map<String, dynamic>> postRef =
      _db.collection('posts').doc();

      final String postId = postRef.id;
      final List<String> imageUrls = <String>[];
      final List<String> imagePaths = <String>[];
      int uploadedCount = 0;

      for (int i = 0; i < imageFiles.length; i++) {
        final File imageFile = imageFiles[i];
        final String imagePath =
            'posts/${user.uid}/$postId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        final Reference storageRef = _storage.ref().child(imagePath);
        final UploadTask uploadTask = storageRef.putFile(
          imageFile,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uid': user.uid,
              'postId': postId,
              'username': username,
              'displayName': displayName,
              'type': 'post_image',
              'index': i.toString(),
            },
          ),
        );

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final int total = snapshot.totalBytes;
          final int transferred = snapshot.bytesTransferred;

          if (total > 0 && mounted) {
            final double singleProgress = (transferred / total).clamp(0.0, 1.0);
            setState(() {
              uploadProgress = ((uploadedCount + singleProgress) / imageFiles.length).clamp(0.0, 1.0);
            });
          }
        });

        final TaskSnapshot snapshot = await uploadTask;
        final String imageUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(imageUrl);
        imagePaths.add(imagePath);
        uploadedCount++;

        if (mounted) {
          setState(() {
            uploadProgress = (uploadedCount / imageFiles.length).clamp(0.0, 1.0);
          });
        }
      }

      final String firstImageUrl = imageUrls.isEmpty ? '' : imageUrls.first;
      final String firstImagePath = imagePaths.isEmpty ? '' : imagePaths.first;

      final WriteBatch batch = _db.batch();

      batch.set(postRef, {
        'postId': postId,

        'uid': user.uid,
        'userId': user.uid,
        'ownerId': user.uid,

        'displayName': displayName,
        'username': username,
        'userPhoto': userPhoto,
        'userEmail': userEmail,
        'userCity': userCity,
        'userDistrict': userDistrict,
        'userBio': userBio,

        'imageUrl': firstImageUrl,
        'imagePath': firstImagePath,
        'images': imageUrls,
        'imageUrls': imageUrls,
        'mediaUrls': imageUrls,
        'imagePaths': imagePaths,
        'imageCount': imageUrls.length,
        'mediaType': imageUrls.length > 1 ? 'images' : 'image',
        'imageFormat': 'jpg',

        'caption': caption,
        'desc': caption,
        'description': caption,

        'location': location,
        'locationLocked': true,
        'locationSource': 'profile',

        'visibility': _visibilityValue(),
        'visibilityText': _visibilityText(),
        'feedTarget': _feedTarget(),

        'commentsEnabled': true,
        'likesEnabled': true,
        'locationEnabled': true,

        'likeCount': 0,
        'likes': 0,
        'likesCount': 0,
        'commentCount': 0,
        'commentsCount': 0,
        'saveCount': 0,
        'shareCount': 0,
        'viewCount': 0,
        'likedBy': <String>[],
        'savedBy': <String>[],
        'archivedBy': <String>[],

        'active': true,
        'deleted': false,
        'isDeleted': false,
        'isArchived': false,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        userRef,
        {
          'postsCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;

      setState(() {
        uploadProgress = 1;
      });

      await showSuccessDialog();

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSharing = false;
        uploadProgress = 0;
      });

      showMessage('Post paylaşılırken hata oluştu: $e');
    }
  }

  Future<void> showSuccessDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: Colors.black,
                  size: 58,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Post Paylaşıldı',
                  textScaler: TextScaler.noScaling,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gönderin başarıyla yüklendi. Tamam dediğinde ana sayfaya döneceksin.',
                  textScaler: TextScaler.noScaling,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black54,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      'Tamam',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w900,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final int captionLength = captionController.text.characters.length;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const CreatePostHeader(),
                  Expanded(
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
                      children: [
                        NeonImagePickButton(
                          controller: neonController,
                          isSharing: isSharing,
                          selected: selectedImageFiles.isNotEmpty,
                          selectedCount: selectedImageFiles.length,
                          maxCount: maxPostImages,
                          onTap: pickImageFromGallery,
                        ),
                        const SizedBox(height: 8),
                        const CropInfoText(),
                        if (selectedImageFiles.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          SelectedImagesPreview(
                            files: selectedImageFiles,
                            isSharing: isSharing,
                            maxCount: maxPostImages,
                            onEditTap: editSelectedImage,
                            onRemoveTap: removeImage,
                          ),
                        ],
                        const SizedBox(height: 14),
                        LockedLocationBox(
                          location: lockedProfileLocation,
                          loading: profileLocationLoading,
                        ),
                        const SizedBox(height: 14),
                        CaptionInputBox(
                          controller: captionController,
                          limit: captionLimit,
                          currentLength: captionLength,
                        ),
                        const SizedBox(height: 14),
                        VisibilitySelectorBox(
                          selectedVisibility: selectedVisibility,
                          enabled: !isSharing,
                          onChanged: (value) {
                            if (isSharing || value == selectedVisibility) return;
                            setState(() => selectedVisibility = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  BottomPublishBar(
                    isSharing: isSharing,
                    hasImage: selectedImageFiles.isNotEmpty,
                    progress: uploadProgress,
                    onShareTap: sharePost,
                  ),
                ],
              ),
              if (isSharing)
                UploadLoadingOverlay(progress: uploadProgress),
            ],
          ),
        ),
      ),
    );
  }
}

class CreatePostHeader extends StatelessWidget {
  const CreatePostHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black12),
        ),
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
            child: Center(
              child: Text(
                'Post Paylaş',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
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

class NeonImagePickButton extends StatelessWidget {
  final AnimationController controller;
  final bool isSharing;
  final bool selected;
  final int selectedCount;
  final int maxCount;
  final VoidCallback onTap;

  const NeonImagePickButton({
    super.key,
    required this.controller,
    required this.isSharing,
    required this.selected,
    this.selectedCount = 0,
    this.maxCount = 5,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(2),
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
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF00B8).withOpacity(0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSharing ? null : onTap,
              icon: Icon(
                selected ? Icons.add_photo_alternate_rounded : Icons.photo_library_rounded,
              ),
              label: Text(
                selected ? 'Fotoğraf Ekle ($selectedCount/$maxCount)' : 'Fotoğraf Seç (En fazla $maxCount)',
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: Colors.white70,
                disabledForegroundColor: Colors.black45,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class CropInfoText extends StatelessWidget {
  const CropInfoText({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Post için en fazla 5 fotoğraf seçebilirsin. Seçilen fotoğraflar otomatik 1080 x 1080 JPG formatına hazırlanır.',
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: 'Roboto',
        color: Colors.black45,
        fontSize: 11.5,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class SelectedImagesPreview extends StatelessWidget {
  final List<File> files;
  final bool isSharing;
  final int maxCount;
  final void Function(int index) onEditTap;
  final void Function(int index) onRemoveTap;

  const SelectedImagesPreview({
    super.key,
    required this.files,
    required this.isSharing,
    required this.maxCount,
    required this.onEditTap,
    required this.onRemoveTap,
  });

  @override
  Widget build(BuildContext context) {
    return OptionSection(
      title: 'Seçilen Fotoğraflar (${files.length}/$maxCount)',
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: files.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final file = files[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                      cacheWidth: 720,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${index + 1}',
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        RoundActionButton(
                          icon: Icons.crop_rotate_rounded,
                          size: 34,
                          iconSize: 18,
                          onTap: isSharing ? null : () => onEditTap(index),
                        ),
                        const SizedBox(width: 6),
                        RoundActionButton(
                          icon: Icons.close_rounded,
                          size: 34,
                          iconSize: 18,
                          onTap: isSharing ? null : () => onRemoveTap(index),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class RoundActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  const RoundActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconSize = 21,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.72),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

class LockedLocationBox extends StatelessWidget {
  final String location;
  final bool loading;

  const LockedLocationBox({
    super.key,
    required this.location,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final text = loading
        ? 'Profil konumu yükleniyor...'
        : location.isEmpty
        ? 'Profil konumu eksik'
        : location;

    return OptionSection(
      title: 'Konum Bilgisi',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.045),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.black, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: location.isEmpty && !loading ? Colors.red : Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Konum bilgisi kilitlidir, sadece profilden düzenlenebilir.',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: Colors.black45,
            fontSize: 11.5,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class CaptionInputBox extends StatelessWidget {
  final TextEditingController controller;
  final int limit;
  final int currentLength;

  const CaptionInputBox({
    super.key,
    required this.controller,
    required this.limit,
    required this.currentLength,
  });

  @override
  Widget build(BuildContext context) {
    return OptionSection(
      title: 'Post Açıklaması',
      children: [
        TextField(
          controller: controller,
          maxLines: 5,
          maxLength: limit,
          inputFormatters: [
            LengthLimitingTextInputFormatter(limit),
          ],
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Paylaşmak istediğin açıklamayı yaz...',
            hintStyle: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black38,
              fontWeight: FontWeight.w700,
            ),
            counterText: '',
            filled: true,
            fillColor: Colors.black.withOpacity(0.045),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Colors.black38,
              size: 17,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Açıklama sınırı 300 karakterdir.',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black45,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$currentLength/$limit',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: currentLength >= limit ? Colors.red : Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class VisibilitySelectorBox extends StatelessWidget {
  final PostVisibility selectedVisibility;
  final bool enabled;
  final ValueChanged<PostVisibility> onChanged;

  const VisibilitySelectorBox({
    super.key,
    required this.selectedVisibility,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OptionSection(
      title: 'Görünürlük',
      children: [
        Container(
          height: 46,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6E6E6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: VisibilityChoiceButton(
                  title: 'NOVA Keşfet',
                  selected: selectedVisibility == PostVisibility.explore,
                  enabled: enabled,
                  onTap: () => onChanged(PostVisibility.explore),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: VisibilityChoiceButton(
                  title: 'Takipçilerin',
                  selected: selectedVisibility == PostVisibility.followers,
                  enabled: enabled,
                  onTap: () => onChanged(PostVisibility.followers),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VisibilityChoiceButton extends StatelessWidget {
  final String title;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const VisibilityChoiceButton({
    super.key,
    required this.title,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: selected ? Colors.white : Colors.black54,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
            fontSize: 12.4,
          ),
        ),
      ),
    );
  }
}

class OptionSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const OptionSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class BottomPublishBar extends StatelessWidget {
  final bool isSharing;
  final bool hasImage;
  final double progress;
  final VoidCallback onShareTap;

  const BottomPublishBar({
    super.key,
    required this.isSharing,
    required this.hasImage,
    required this.progress,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    final int percent = (progress * 100).clamp(0, 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black12),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: isSharing ? null : onShareTap,
            icon: isSharing
                ? const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
                : Icon(
              hasImage
                  ? Icons.send_rounded
                  : Icons.photo_library_rounded,
            ),
            label: Text(
              isSharing ? 'Yükleniyor %$percent' : 'Paylaş',
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w900,
              ),
            ),
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: Colors.black54,
              disabledForegroundColor: Colors.white,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UploadLoadingOverlay extends StatelessWidget {
  final double progress;

  const UploadLoadingOverlay({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final int percent = (progress * 100).clamp(0, 100).round();

    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.78),
        child: Center(
          child: Container(
            width: 178,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: CircularProgressIndicator(
                        value: progress <= 0 ? null : progress,
                        strokeWidth: 5,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    Text(
                      '%$percent',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Yükleniyor',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
