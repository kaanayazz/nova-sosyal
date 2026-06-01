import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';


class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  static List<CameraDescription>? cachedCameras;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription> cameras = [];

  bool loading = true;
  bool switchingCamera = false;
  bool takingPhoto = false;
  bool flashOn = false;
  bool cameraError = false;

  int cameraIndex = 0;

  double minZoom = 1.0;
  double maxZoom = 1.0;
  double currentZoom = 1.0;
  double baseZoom = 1.0;

  DateTime _lastZoomChange = DateTime.fromMillisecondsSinceEpoch(0);
  final ValueNotifier<double> zoomNotifier = ValueNotifier<double>(1.0);

  bool get _hasReadyController =>
      controller != null && controller!.value.isInitialized;

  bool get isFront =>
      cameras.isNotEmpty &&
          cameraIndex >= 0 &&
          cameraIndex < cameras.length &&
          cameras[cameraIndex].lensDirection == CameraLensDirection.front;

  bool get isBack =>
      cameras.isNotEmpty &&
          cameraIndex >= 0 &&
          cameraIndex < cameras.length &&
          cameras[cameraIndex].lensDirection == CameraLensDirection.back;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) initCamera();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? activeController = controller;

    if (activeController == null || !activeController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      activeController.dispose();
      controller = null;
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (mounted) initCamera(showFullLoading: false);
    }
  }

  Future<List<CameraDescription>> _getCamerasFast() async {
    final cached = CameraPage.cachedCameras;
    if (cached != null && cached.isNotEmpty) return cached;

    final result = await availableCameras();
    CameraPage.cachedCameras = result;
    return result;
  }

  Future<void> _setupZoom(CameraController newController) async {
    try {
      minZoom = await newController.getMinZoomLevel();
      maxZoom = await newController.getMaxZoomLevel();

      currentZoom = minZoom;
      baseZoom = minZoom;
      zoomNotifier.value = currentZoom;

      await newController.setZoomLevel(currentZoom);
    } catch (e) {
      debugPrint('Zoom ayarı hatası: $e');
    }
  }

  Future<CameraController> _createController(CameraDescription description) async {
    final CameraController newController = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await newController.initialize();
    await newController.lockCaptureOrientation(DeviceOrientation.portraitUp);
    await _setupZoom(newController);

    if (description.lensDirection == CameraLensDirection.back) {
      await newController.setFlashMode(FlashMode.off);
    }

    return newController;
  }

  Future<void> initCamera({bool showFullLoading = true}) async {
    if (showFullLoading && mounted) {
      setState(() {
        loading = true;
        cameraError = false;
      });
    }

    try {
      cameras = await _getCamerasFast();

      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          loading = false;
          cameraError = true;
        });
        return;
      }

      final int backIndex = cameras.indexWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
      );

      cameraIndex = backIndex == -1 ? 0 : backIndex;

      final CameraController newController =
      await _createController(cameras[cameraIndex]);

      if (!mounted) {
        await newController.dispose();
        return;
      }

      final oldController = controller;

      if (!mounted) {
        await newController.dispose();
        return;
      }

      setState(() {
        controller = newController;
        flashOn = false;
        loading = false;
        switchingCamera = false;
        cameraError = false;
      });

      await oldController?.dispose();
    } catch (e) {
      debugPrint('Kamera açılış hatası: $e');
      if (!mounted) return;
      setState(() {
        loading = false;
        switchingCamera = false;
        cameraError = true;
      });
    }
  }

  Future<void> switchCamera() async {
    if (cameras.length < 2 || takingPhoto || switchingCamera) return;

    final int nextIndex = (cameraIndex + 1) % cameras.length;
    final CameraController? oldController = controller;

    setState(() {
      switchingCamera = true;
      flashOn = false;
    });

    try {
      try {
        if (oldController != null &&
            oldController.value.isInitialized &&
            isBack) {
          await oldController.setFlashMode(FlashMode.off);
        }
      } catch (_) {}

      await oldController?.dispose();

      final CameraController newController =
      await _createController(cameras[nextIndex]);

      if (!mounted) {
        await newController.dispose();
        return;
      }

      setState(() {
        cameraIndex = nextIndex;
        controller = newController;
        switchingCamera = false;
        flashOn = false;
      });
    } catch (e) {
      debugPrint('Kamera değiştirme hatası: $e');
      if (!mounted) return;
      setState(() {
        switchingCamera = false;
        flashOn = false;
        controller = null;
      });
      await initCamera(showFullLoading: false);
    }
  }

  Future<void> toggleFlash() async {
    if (!_hasReadyController || !isBack || switchingCamera) return;

    try {
      final bool nextFlash = !flashOn;

      await controller!.setFlashMode(
        nextFlash ? FlashMode.torch : FlashMode.off,
      );

      if (!mounted) return;

      setState(() => flashOn = nextFlash);
    } catch (e) {
      debugPrint('Flash hatası: $e');
    }
  }

  Future<File> fixFrontCameraMirrorIfNeeded(String path) async {
    if (!isFront) return File(path);

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) return file;

      final fixed = img.flipHorizontal(decoded);
      final fixedBytes = img.encodeJpg(fixed, quality: 94);
      final directory = await getTemporaryDirectory();

      final fixedFile = File(
        '${directory.path}/nova_front_fixed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await fixedFile.writeAsBytes(fixedBytes, flush: true);
      return fixedFile;
    } catch (e) {
      debugPrint('Ön kamera ayna düzeltme hatası: $e');
      return File(path);
    }
  }

  Future<void> takePhoto() async {
    if (!_hasReadyController) return;
    if (takingPhoto || switchingCamera) return;

    setState(() => takingPhoto = true);

    try {
      if (isBack) {
        await controller!.setFlashMode(flashOn ? FlashMode.torch : FlashMode.off);
      }

      final XFile image = await controller!.takePicture();
      final File finalImage = await fixFrontCameraMirrorIfNeeded(image.path);

      // Galeriye kaydetmeyi ekranda bekletmiyoruz. Önizleme daha hızlı açılır.
      unawaited(GallerySaver.saveImage(finalImage.path));

      if (!mounted) return;

      setState(() => takingPhoto = false);

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => PreviewPage(imagePath: finalImage.path),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 120),
        ),
      );
    } catch (e) {
      debugPrint('Fotoğraf çekme hatası: $e');
      if (mounted) setState(() => takingPhoto = false);
    }
  }

  Future<void> openGallery() async {
    if (takingPhoto || switchingCamera) return;

    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
      maxWidth: 2200,
      maxHeight: 2200,
      requestFullMetadata: false,
    );

    if (image == null || !mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PreviewPage(imagePath: image.path),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 120),
      ),
    );
  }

  void _setZoomFast(double nextZoom) {
    if (!_hasReadyController || switchingCamera) return;

    final double fixedZoom = nextZoom.clamp(minZoom, maxZoom).toDouble();

    if ((fixedZoom - currentZoom).abs() < 0.025) return;

    final now = DateTime.now();
    if (now.difference(_lastZoomChange).inMilliseconds < 24) return;

    _lastZoomChange = now;
    currentZoom = fixedZoom;
    zoomNotifier.value = fixedZoom;

    controller!.setZoomLevel(fixedZoom).catchError((_) {});
  }

  Widget cameraPreview() {
    if (!_hasReadyController) {
      return const SizedBox.expand(child: ColoredBox(color: Colors.black));
    }

    final previewSize = controller!.value.previewSize;

    if (previewSize == null) {
      return const SizedBox.expand(child: ColoredBox(color: Colors.black));
    }

    return RepaintBoundary(
      child: GestureDetector(
        onScaleStart: (_) => baseZoom = currentZoom,
        onScaleUpdate: (details) {
          final nextZoom = (baseZoom * details.scale).clamp(minZoom, maxZoom);
          _setZoomFast(nextZoom.toDouble());
        },
        child: SizedBox.expand(
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize.height,
                height: previewSize.width,
                child: CameraPreview(controller!),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    zoomNotifier.dispose();

    try {
      if (isBack) controller?.setFlashMode(FlashMode.off);
    } catch (_) {}

    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (cameraError && !loading) {
      return CameraErrorBody(onRetry: initCamera);
    }

    final double navigationSafeBottom = math.max(
      74.0,
      MediaQuery.of(context).viewPadding.bottom + 46.0,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          cameraPreview(),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.transparent,
                    Colors.black.withOpacity(0.80),
                  ],
                ),
              ),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: zoomNotifier,
            builder: (context, zoom, _) {
              if (zoom <= 1.05 || switchingCamera || loading) {
                return const SizedBox.shrink();
              }

              return Positioned(
                left: 0,
                right: 0,
                top: 92,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${zoom.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 17, 16, 0),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: CameraCircleButton(
                        icon: flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        onTap: isBack ? toggleFlash : () {},
                        disabled: !isBack || switchingCamera || loading,
                      ),
                    ),
                    const Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        'NOVA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 5,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: CameraCircleButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: navigationSafeBottom,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CameraSmallButton(
                  icon: Icons.photo_library_rounded,
                  onTap: openGallery,
                  square: true,
                ),
                GestureDetector(
                  onTap: _hasReadyController && !loading ? takePhoto : null,
                  child: Opacity(
                    opacity: _hasReadyController && !loading ? 1 : 0.55,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 5),
                      ),
                      child: Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                CameraSmallButton(
                  icon: Icons.flip_camera_ios_rounded,
                  onTap: switchCamera,
                  square: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class CameraInstantLoadingBody extends StatelessWidget {
  const CameraInstantLoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NOVA',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.6,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Kamera açılıyor',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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

class CameraErrorBody extends StatelessWidget {
  final Future<void> Function({bool showFullLoading}) onRetry;

  const CameraErrorBody({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Kamera açılamadı',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kamera iznini kontrol edip tekrar dene.',
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => onRetry(showFullLoading: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text(
                  'Tekrar dene',
                  textScaler: TextScaler.noScaling,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PreviewPage extends StatefulWidget {
  final String imagePath;

  const PreviewPage({
    super.key,
    required this.imagePath,
  });

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  final GlobalKey repaintKey = GlobalKey();
  final TextEditingController textController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  bool showTextPanel = false;
  bool showEmojiPanel = false;
  bool showMentionPanel = false;
  bool showLocationPanel = false;
  bool saving = false;
  bool draggingItem = false;
  bool deleteActive = false;

  List<EditStoryItem> items = [];

  final List<String> emojis = const [
    '🔥',
    '🚗',
    '🏎️',
    '😍',
    '⚡',
    '💎',
    '🖤',
    '💯',
    '🔧',
    '📸',
  ];

  final List<String> mentions = const [
    '@nova.garage',
    '@kaan.ayaz',
    '@bmwclub',
    '@audilife',
    '@passat.tr',
  ];

  @override
  void dispose() {
    textController.dispose();
    locationController.dispose();
    super.dispose();
  }

  void closePanels() {
    showTextPanel = false;
    showEmojiPanel = false;
    showMentionPanel = false;
    showLocationPanel = false;
  }

  void addText() {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      items.add(
        EditStoryItem(
          text: text,
          type: StoryOverlayType.text,
          position: const Offset(70, 220),
          color: Colors.white,
          size: 30,
        ),
      );
      textController.clear();
      closePanels();
    });
  }

  void addEmoji(String emoji) {
    setState(() {
      items.add(
        EditStoryItem(
          text: emoji,
          type: StoryOverlayType.emoji,
          position: const Offset(120, 260),
          color: Colors.white,
          size: 42,
        ),
      );
      closePanels();
    });
  }

  void addMention(String mention) {
    setState(() {
      items.add(
        EditStoryItem(
          text: mention,
          type: StoryOverlayType.mention,
          position: const Offset(70, 260),
          color: Colors.white,
          size: 26,
        ),
      );
      closePanels();
    });
  }

  void addLocation() {
    final text = locationController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      items.add(
        EditStoryItem(
          text: text,
          type: StoryOverlayType.location,
          position: const Offset(64, 285),
          color: Colors.white,
          size: 20,
        ),
      );
      locationController.clear();
      closePanels();
    });
  }

  bool isInDeleteArea(Offset globalPosition, BuildContext context) {
    final size = MediaQuery.of(context).size;
    return globalPosition.dy > size.height - 155 &&
        globalPosition.dx > size.width / 2 - 90 &&
        globalPosition.dx < size.width / 2 + 90;
  }

  Future<File?> createEditedImageFile() async {
    try {
      final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final decoded = img.decodeImage(pngBytes);
      if (decoded == null) return null;

      final resized = decoded.width > 1080
          ? img.copyResize(decoded, width: 1080)
          : decoded;

      final jpgBytes = img.encodeJpg(resized, quality: 78);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/nova_story_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await file.writeAsBytes(jpgBytes);
      return file;
    } catch (e) {
      debugPrint('Görsel oluşturma hatası: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      throw Exception('Profil bulunamadı');
    }

    final data = userDoc.data() ?? <String, dynamic>{};

    final bool profileCompleted = data['profileCompleted'] == true;

    final String displayName = _safeString(
      data['displayName'] ?? data['name'],
      fallback: _safeString(user.displayName, fallback: 'Nova Kullanıcısı'),
    );

    final String username = _safeString(data['username']);

    final String profileImage = _safeString(
      data['photoUrl'] ??
          data['userPhoto'] ??
          data['profileImage'] ??
          data['profileImageUrl'] ??
          data['userPhotoUrl'],
      fallback: _safeString(user.photoURL),
    );

    final String city = _safeString(data['city']);
    final String district = _safeString(data['district']);
    final String bio = _safeString(data['bio']);

    if (!profileCompleted ||
        displayName.isEmpty ||
        username.isEmpty ||
        city.isEmpty ||
        district.isEmpty) {
      throw Exception('Profil tamamlanmamış');
    }

    return {
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': displayName,
      'username': username,
      'profileImage': profileImage,
      'userPhoto': profileImage,
      'photoUrl': profileImage,
      'city': city,
      'district': district,
      'bio': bio,
    };
  }

  List<Map<String, dynamic>> overlayItemsForFirestore() {
    final size = MediaQuery.of(context).size;
    return items.map((item) {
      return {
        'text': item.text,
        'type': item.type.name,
        'x': item.position.dx / size.width,
        'y': item.position.dy / size.height,
        'size': item.size,
        'scale': item.scale,
        'rotation': item.rotation,
      };
    }).toList();
  }

  Future<void> shareToFirebaseStory() async {
    if (saving) return;

    setState(() => saving = true);

    try {
      final Map<String, dynamic> userProfile = await getCurrentUserProfile();

      final DocumentReference<Map<String, dynamic>> storyRef =
      FirebaseFirestore.instance.collection('stories').doc();

      final String storyId = storyRef.id;
      final String uid = userProfile['uid'] as String;
      final List<Map<String, dynamic>> overlays = overlayItemsForFirestore();

      final File? file = await createEditedImageFile();

      if (file == null) {
        if (!mounted) return;
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görsel hazırlanamadı')),
        );
        return;
      }

      final String storagePath =
          'stories/$uid/$storyId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Reference storageRef =
      FirebaseStorage.instance.ref().child(storagePath);

      final UploadTask uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uid': uid,
            'storyId': storyId,
            'username': userProfile['username'].toString(),
            'displayName': userProfile['displayName'].toString(),
            'type': 'story_image',
            'createdBy': 'nova_camera_page',
          },
        ),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String mediaUrl = await snapshot.ref.getDownloadURL();

      final Timestamp expiresAt =
      Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24)));

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.set(storyRef, {
        'id': storyId,
        'storyId': storyId,

        // Sahip bilgileri
        'uid': uid,
        'userId': uid,
        'ownerId': uid,
        'userEmail': userProfile['email'],

        // Profil bilgileri
        'displayName': userProfile['displayName'],
        'username': userProfile['username'],
        'profileImage': userProfile['profileImage'],
        'userPhoto': userProfile['userPhoto'],
        'photoUrl': userProfile['photoUrl'],

        // Medya
        'imageUrl': mediaUrl,
        'mediaUrl': mediaUrl,
        'storyImage': mediaUrl,
        'videoUrl': '',
        'storagePath': storagePath,
        'mediaType': 'image',
        'type': 'image',
        'imageFormat': 'jpg',
        'source': 'camera',

        // Durum
        'active': true,
        'viewedBy': <String>[],
        'likedBy': <String>[],
        'viewCount': 0,
        'likeCount': 0,
        'overlays': overlays,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt,
      });

      batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('stories')
            .doc(storyId),
        {
          'id': storyId,
          'storyId': storyId,
          'storyRef': storyRef.path,
          'mediaUrl': mediaUrl,
          'imageUrl': mediaUrl,
          'videoUrl': '',
          'storagePath': storagePath,
          'mediaType': 'image',
          'type': 'image',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': expiresAt,
        },
        SetOptions(merge: true),
      );

      batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'storiesCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      await GallerySaver.saveImage(file.path);

      if (!mounted) return;

      setState(() => saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hikaye paylaşıldı'),
          duration: Duration(milliseconds: 900),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Hikaye Firebase paylaşma hatası: $e');

      if (!mounted) return;

      setState(() => saving = false);

      String message = 'Hikaye paylaşılamadı';

      final String errorText = e.toString();

      if (errorText.contains('Kullanıcı oturumu')) {
        message = 'Önce giriş yapmalısın';
      } else if (errorText.contains('Profil bulunamadı')) {
        message = 'Önce profilini oluşturmalısın';
      } else if (errorText.contains('Profil tamamlanmamış')) {
        message = 'Hikaye paylaşmak için profil bilgilerini tamamlamalısın';
      } else if (errorText.contains('permission-denied') ||
          errorText.contains('unauthorized') ||
          errorText.contains('not authorized')) {
        message = 'Firebase izinleri hikaye paylaşımını engelliyor';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1800),
        ),
      );
    }
  }

  Widget overlayItemWidget(int i) {
    final item = items[i];

    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: GestureDetector(
        onScaleStart: (details) {
          item.baseScale = item.scale;
          item.baseRotation = item.rotation;
          setState(() {
            draggingItem = true;
            deleteActive = false;
            closePanels();
          });
        },
        onScaleUpdate: (details) {
          setState(() {
            item.position += details.focalPointDelta;
            item.scale = (item.baseScale * details.scale).clamp(0.45, 4.0);
            item.rotation = item.baseRotation + details.rotation;
            deleteActive = isInDeleteArea(details.focalPoint, context);
          });
        },
        onScaleEnd: (_) {
          setState(() {
            if (deleteActive) items.removeAt(i);
            draggingItem = false;
            deleteActive = false;
          });
        },
        onDoubleTap: () {
          setState(() => items.removeAt(i));
        },
        child: Transform.rotate(
          angle: item.rotation,
          child: Transform.scale(
            scale: item.scale,
            child: StoryOverlayChip(item: item),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: repaintKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                for (int i = 0; i < items.length; i++) overlayItemWidget(i),
              ],
            ),
          ),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.42),
                    Colors.transparent,
                    Colors.black.withOpacity(0.76),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: CameraCircleButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 115,
            child: Column(
              children: [
                EditToolButton(
                  icon: Icons.text_fields_rounded,
                  title: 'Yazı',
                  onTap: () {
                    setState(() {
                      showTextPanel = !showTextPanel;
                      showEmojiPanel = false;
                      showMentionPanel = false;
                      showLocationPanel = false;
                    });
                  },
                ),
                const SizedBox(height: 14),
                EditToolButton(
                  icon: Icons.emoji_emotions_rounded,
                  title: 'Emoji',
                  onTap: () {
                    setState(() {
                      showEmojiPanel = !showEmojiPanel;
                      showTextPanel = false;
                      showMentionPanel = false;
                      showLocationPanel = false;
                    });
                  },
                ),
                const SizedBox(height: 14),
                EditToolButton(
                  icon: Icons.alternate_email_rounded,
                  title: 'Bahset',
                  onTap: () {
                    setState(() {
                      showMentionPanel = !showMentionPanel;
                      showTextPanel = false;
                      showEmojiPanel = false;
                      showLocationPanel = false;
                    });
                  },
                ),
                const SizedBox(height: 14),
                EditToolButton(
                  icon: Icons.location_on_rounded,
                  title: 'Konum',
                  onTap: () {
                    setState(() {
                      showLocationPanel = !showLocationPanel;
                      showTextPanel = false;
                      showEmojiPanel = false;
                      showMentionPanel = false;
                    });
                  },
                ),
              ],
            ),
          ),
          if (showTextPanel)
            Positioned(
              left: 16,
              right: 16,
              bottom: 105,
              child: EditorPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        decoration: const InputDecoration(
                          hintText: 'Yazı ekle...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: addText,
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),
            ),
          if (showLocationPanel)
            Positioned(
              left: 16,
              right: 16,
              bottom: 105,
              child: EditorPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: locationController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        decoration: const InputDecoration(
                          hintText: 'Konum ekle...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: addLocation,
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),
            ),
          if (showEmojiPanel)
            Positioned(
              left: 16,
              right: 16,
              bottom: 105,
              child: EditorPanel(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: emojis.map((emoji) {
                    return GestureDetector(
                      onTap: () => addEmoji(emoji),
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (showMentionPanel)
            Positioned(
              left: 16,
              right: 16,
              bottom: 105,
              child: EditorPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: mentions.map((mention) {
                    return ListTile(
                      dense: true,
                      leading: const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person_rounded, color: Colors.black),
                      ),
                      title: Text(
                        mention,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                      onTap: () => addMention(mention),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (draggingItem)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: deleteActive ? 108 : 88,
                    height: deleteActive ? 108 : 88,
                    decoration: BoxDecoration(
                      color: deleteActive ? Colors.red.withOpacity(0.95) : Colors.black.withOpacity(0.72),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: deleteActive ? Colors.redAccent : Colors.white30,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.delete_rounded,
                      color: Colors.white,
                      size: deleteActive ? 44 : 36,
                    ),
                  ),
                ),
              ),
            ),
          if (!draggingItem)
            Positioned(
              left: 18,
              right: 18,
              bottom: 34,
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : shareToFirebaseStory,
                  icon: saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                      : const Icon(Icons.auto_stories_rounded),
                  label: Text(saving ? 'Paylaşılıyor...' : 'Hikaye Olarak Paylaş'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white70,
                    disabledForegroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum StoryOverlayType { text, emoji, mention, location }

class EditStoryItem {
  String text;
  StoryOverlayType type;
  Offset position;
  Color color;
  double size;
  double scale;
  double baseScale;
  double rotation;
  double baseRotation;

  EditStoryItem({
    required this.text,
    required this.type,
    required this.position,
    required this.color,
    required this.size,
    this.scale = 1,
    this.baseScale = 1,
    this.rotation = 0,
    this.baseRotation = 0,
  });
}

class StoryOverlayChip extends StatelessWidget {
  final EditStoryItem item;

  const StoryOverlayChip({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    if (item.type == StoryOverlayType.location) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.58),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 5),
            Text(
              item.text,
              style: TextStyle(
                color: item.color,
                fontSize: item.size,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      item.text,
      style: TextStyle(
        color: item.color,
        fontSize: item.size,
        fontWeight: FontWeight.w900,
        shadows: const [Shadow(color: Colors.black, blurRadius: 12)],
      ),
    );
  }
}

class CameraCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;

  const CameraCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.35 : 1,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.40),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class CameraSmallButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool square;

  const CameraSmallButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.square,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(18) : null,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 29),
      ),
    );
  }
}

class EditToolButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const EditToolButton({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class EditorPanel extends StatelessWidget {
  final Widget child;

  const EditorPanel({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
      ),
      child: child,
    );
  }
}

String _safeString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}
