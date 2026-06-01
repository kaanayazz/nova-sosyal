import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
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
  late final AnimationController _neonController;

  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _captionController = TextEditingController();

  static const int maxPostImages = 5;
  static const int captionLimit = 300;

  final List<File> _selectedImages = <File>[];

  PostVisibility _visibility = PostVisibility.explore;

  bool _isSharing = false;
  bool _profileLoading = true;
  double _uploadProgress = 0;

  String _lockedLocation = '';

  User? get _user => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _neonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _captionController.addListener(_refresh);
    _loadProfileLocation();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _neonController.dispose();
    _captionController.removeListener(_refresh);
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileLocation() async {
    final user = _user;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
        _lockedLocation = '';
      });
      return;
    }

    try {
      final snap = await _db.collection('users').doc(user.uid).get();
      final data = snap.data() ?? <String, dynamic>{};
      final location = _profileLocation(data);

      if (!mounted) return;
      setState(() {
        _lockedLocation = location;
        _profileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lockedLocation = '';
        _profileLoading = false;
      });
    }
  }

  String _safeString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _profileLocation(Map<String, dynamic> data) {
    final city = _safeString(data['city'] ?? data['il'] ?? data['province']);
    final district = _safeString(
      data['district'] ?? data['ilce'] ?? data['ilçe'] ?? data['county'],
    );

    if (city.isNotEmpty && district.isNotEmpty) return '$city / $district';
    if (city.isNotEmpty) return city;
    if (district.isNotEmpty) return district;
    return '';
  }

  String _visibilityValue() {
    return _visibility == PostVisibility.explore ? 'public' : 'followers';
  }

  String _visibilityText() {
    return _visibility == PostVisibility.explore ? 'NOVA Keşfet' : 'Takipçilerin';
  }

  String _feedTarget() {
    return _visibility == PostVisibility.explore ? 'explore' : 'following';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage() async {
    if (_isSharing) return;

    final int remaining = maxPostImages - _selectedImages.length;
    if (remaining <= 0) {
      _showMessage('En fazla $maxPostImages fotoğraf seçebilirsin.');
      return;
    }

    try {
      final List<XFile> pickedList = await _picker.pickMultiImage(
        imageQuality: 100,
        maxWidth: 3000,
        maxHeight: 3000,
        requestFullMetadata: false,
      );

      if (pickedList.isEmpty || !mounted) return;

      final List<File> sourceFiles = pickedList
          .take(remaining)
          .map((xFile) => File(xFile.path))
          .toList();

      if (pickedList.length > remaining) {
        _showMessage('En fazla $maxPostImages fotoğraf seçebilirsin. İlk $remaining fotoğraf alındı.');
      }

      final List<File>? editedFiles = await Navigator.push<List<File>?>(
        context,
        MaterialPageRoute(
          builder: (_) => InstagramBatchImageEditorPage(
            sourceFiles: sourceFiles,
            title: 'Fotoğrafları Ayarla',
          ),
        ),
      );

      if (editedFiles == null || editedFiles.isEmpty || !mounted) return;

      final List<File> fixedFiles = <File>[];
      for (final File editedFile in editedFiles) {
        final File? fixedFile = await _prepareImage(editedFile);
        if (fixedFile != null) fixedFiles.add(fixedFile);
      }

      if (fixedFiles.isEmpty || !mounted) {
        _showMessage('Fotoğraflar hazırlanamadı. Başka görsel dene.');
        return;
      }

      setState(() => _selectedImages.addAll(fixedFiles));
    } catch (e) {
      _showMessage('Fotoğraf seçilirken hata oluştu: $e');
    }
  }

  Future<void> _changeImage(int index) async {
    if (_isSharing) return;
    if (index < 0 || index >= _selectedImages.length) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: 3000,
        maxHeight: 3000,
        requestFullMetadata: false,
      );

      if (picked == null || !mounted) return;

      final File? editedFile = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (_) => InstagramImageEditorPage(
            sourceFile: File(picked.path),
            title: 'Fotoğrafı Değiştir',
          ),
        ),
      );

      if (editedFile == null || !mounted) return;

      final File? fixedFile = await _prepareImage(editedFile);
      if (fixedFile == null || !mounted) {
        _showMessage('Fotoğraf hazırlanamadı. Başka bir görsel dene.');
        return;
      }

      setState(() => _selectedImages[index] = fixedFile);
    } catch (e) {
      _showMessage('Fotoğraf değiştirilirken hata oluştu: $e');
    }
  }

  Future<void> _editExistingImage(int index) async {
    if (_isSharing) return;
    if (index < 0 || index >= _selectedImages.length) return;

    try {
      final File? editedFile = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (_) => InstagramImageEditorPage(
            sourceFile: _selectedImages[index],
            title: 'Fotoğrafı Ayarla',
          ),
        ),
      );

      if (editedFile == null || !mounted) return;

      final File? fixedFile = await _prepareImage(editedFile);
      if (fixedFile == null || !mounted) return;

      setState(() => _selectedImages[index] = fixedFile);
    } catch (e) {
      _showMessage('Fotoğraf ayarlanırken hata oluştu: $e');
    }
  }

  Future<File?> _prepareImage(File originalFile) async {
    try {
      final Uint8List bytes = await originalFile.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      decoded = img.bakeOrientation(decoded);

      const int targetSize = 1080;
      if (decoded.width != targetSize || decoded.height != targetSize) {
        decoded = img.copyResizeCropSquare(
          decoded,
          size: targetSize,
          interpolation: img.Interpolation.average,
        );
      }

      final Directory tempDir = await getTemporaryDirectory();
      final String path =
          '${tempDir.path}/nova_post_${DateTime.now().microsecondsSinceEpoch}.jpg';

      final File jpgFile = File(path);
      await jpgFile.writeAsBytes(
        img.encodeJpg(decoded, quality: 92),
        flush: true,
      );

      return jpgFile;
    } catch (_) {
      return null;
    }
  }

  void _removeImage(int index) {
    if (_isSharing) return;
    if (index < 0 || index >= _selectedImages.length) return;
    setState(() => _selectedImages.removeAt(index));
  }

  void _moveImageLeft(int index) {
    if (_isSharing || index <= 0 || index >= _selectedImages.length) return;
    setState(() {
      final file = _selectedImages.removeAt(index);
      _selectedImages.insert(index - 1, file);
    });
  }

  void _moveImageRight(int index) {
    if (_isSharing || index < 0 || index >= _selectedImages.length - 1) return;
    setState(() {
      final file = _selectedImages.removeAt(index);
      _selectedImages.insert(index + 1, file);
    });
  }

  Future<void> _sharePost() async {
    if (_isSharing) return;

    final user = _user;
    final images = List<File>.from(_selectedImages);
    final caption = _captionController.text.trim();

    if (user == null) {
      _showMessage('Post paylaşmak için giriş yapmalısın.');
      return;
    }

    if (images.isEmpty) {
      _showMessage('Önce en az 1 fotoğraf seçmelisin.');
      return;
    }

    if (images.length > maxPostImages) {
      _showMessage('En fazla $maxPostImages fotoğraf seçebilirsin.');
      return;
    }

    setState(() {
      _isSharing = true;
      _uploadProgress = 0;
    });

    try {
      final userRef = _db.collection('users').doc(user.uid);
      final userDoc = await userRef.get();
      final userData = userDoc.data() ?? <String, dynamic>{};

      final bool profileCompleted = userData['profileCompleted'] == true;

      final displayName = _safeString(
        userData['displayName'] ?? userData['name'] ?? userData['fullName'],
        fallback: _safeString(user.displayName),
      );
      final username = _safeString(userData['username']);
      final userPhoto = _safeString(
        userData['photoUrl'] ??
            userData['userPhoto'] ??
            userData['profileImage'] ??
            userData['profilePhoto'],
        fallback: _safeString(user.photoURL),
      );
      final userEmail = _safeString(
        userData['email'],
        fallback: _safeString(user.email),
      );
      final userCity = _safeString(userData['city'] ?? userData['il']);
      final userDistrict = _safeString(
        userData['district'] ?? userData['ilce'] ?? userData['ilçe'],
      );
      final userBio = _safeString(userData['bio']);
      final location = _profileLocation(userData);

      if (!userDoc.exists ||
          !profileCompleted ||
          displayName.isEmpty ||
          username.isEmpty ||
          userCity.isEmpty ||
          userDistrict.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isSharing = false;
          _uploadProgress = 0;
        });
        _showMessage('Post paylaşmak için önce profil bilgilerini tamamlamalısın.');
        return;
      }

      final postRef = _db.collection('posts').doc();
      final postId = postRef.id;

      final List<String> imageUrls = <String>[];
      final List<String> imagePaths = <String>[];

      int completedUploads = 0;

      for (int i = 0; i < images.length; i++) {
        final imageFile = images[i];
        final imagePath =
            'posts/${user.uid}/$postId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        final storageRef = _storage.ref().child(imagePath);

        final uploadTask = storageRef.putFile(
          imageFile,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uid': user.uid,
              'postId': postId,
              'index': i.toString(),
              'type': 'post_image',
              'format': 'instagram_square_1080',
            },
          ),
        );

        final sub = uploadTask.snapshotEvents.listen((snapshot) {
          final total = snapshot.totalBytes;
          final transferred = snapshot.bytesTransferred;
          if (total <= 0 || !mounted) return;

          final single = (transferred / total).clamp(0.0, 1.0);
          final all = ((completedUploads + single) / images.length).clamp(0.0, 1.0);
          setState(() => _uploadProgress = all);
        });

        final snapshot = await uploadTask;
        await sub.cancel();

        final url = await snapshot.ref.getDownloadURL();
        imageUrls.add(url);
        imagePaths.add(imagePath);

        completedUploads++;
        if (mounted) {
          setState(() {
            _uploadProgress =
                (completedUploads / images.length).clamp(0.0, 1.0);
          });
        }
      }

      final batch = _db.batch();

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
        'imageUrl': imageUrls.first,
        'imagePath': imagePaths.first,
        'images': imageUrls,
        'imageUrls': imageUrls,
        'mediaUrls': imageUrls,
        'imagePaths': imagePaths,
        'imageCount': imageUrls.length,
        'mediaType': imageUrls.length > 1 ? 'images' : 'image',
        'imageFormat': 'jpg',
        'imageRatio': '1:1',
        'imageSize': 1080,
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

      setState(() => _uploadProgress = 1);
      await _showSuccessDialog();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSharing = false;
        _uploadProgress = 0;
      });
      _showMessage('Post paylaşılırken hata oluştu: $e');
    }
  }

  Future<void> _showSuccessDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, color: Colors.black, size: 58),
                const SizedBox(height: 12),
                const Text(
                  'Post Paylaşıldı',
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
                  'Gönderin başarıyla yüklendi.',
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                    ),
                    child: const Text(
                      'Tamam',
                      style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
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

  Future<bool> _confirmExit() async {
    if (_isSharing) return false;
    if (_selectedImages.isEmpty && _captionController.text.trim().isEmpty) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'Çıkılsın mı?',
            style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Seçtiğin fotoğraflar ve yazdığın açıklama silinecek.',
            style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Çık'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final int captionLength = _captionController.text.characters.length;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
      child: WillPopScope(
        onWillPop: _confirmExit,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    CreatePostHeader(
                      onBackTap: () async {
                        final canExit = await _confirmExit();
                        if (!mounted) return;
                        if (canExit) Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: ListView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 118),
                        children: [
                          NeonImagePickButton(
                            controller: _neonController,
                            isSharing: _isSharing,
                            selected: _selectedImages.isNotEmpty,
                            selectedCount: _selectedImages.length,
                            maxCount: maxPostImages,
                            onTap: _pickImage,
                          ),
                          const SizedBox(height: 8),
                          const InfoText(
                            text:
                            'Instagram gibi: fotoğrafları toplu seç, sağa-sola kaydırarak hepsini kontrol et, sürükle/zoom yap ve Kaydet ile görünen alanları post olarak hazırla.',
                          ),
                          if (_selectedImages.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            SelectedImagesPreview(
                              files: _selectedImages,
                              isSharing: _isSharing,
                              maxCount: maxPostImages,
                              onEditTap: _editExistingImage,
                              onChangeTap: _changeImage,
                              onRemoveTap: _removeImage,
                              onMoveLeft: _moveImageLeft,
                              onMoveRight: _moveImageRight,
                            ),
                          ],
                          const SizedBox(height: 14),
                          LockedLocationBox(location: _lockedLocation, loading: _profileLoading),
                          const SizedBox(height: 14),
                          CaptionInputBox(
                            controller: _captionController,
                            limit: captionLimit,
                            currentLength: captionLength,
                          ),
                          const SizedBox(height: 14),
                          VisibilitySelectorBox(
                            selectedVisibility: _visibility,
                            enabled: !_isSharing,
                            onChanged: (value) {
                              if (_isSharing) return;
                              setState(() => _visibility = value);
                            },
                          ),
                        ],
                      ),
                    ),
                    BottomPublishBar(
                      isSharing: _isSharing,
                      hasImage: _selectedImages.isNotEmpty,
                      progress: _uploadProgress,
                      onShareTap: _sharePost,
                    ),
                  ],
                ),
                if (_isSharing) UploadLoadingOverlay(progress: _uploadProgress),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




class InstagramBatchImageEditorPage extends StatefulWidget {
  final List<File> sourceFiles;
  final String title;

  const InstagramBatchImageEditorPage({
    super.key,
    required this.sourceFiles,
    required this.title,
  });

  @override
  State<InstagramBatchImageEditorPage> createState() =>
      _InstagramBatchImageEditorPageState();
}

class _PhotoEditState extends ChangeNotifier {
  double scale = 1.0;
  Offset offset = Offset.zero;

  void setOffsetSilently(Offset value) {
    offset = value;
  }

  void updateOffset(Offset value) {
    if ((offset - value).distance < 0.05) return;
    offset = value;
    notifyListeners();
  }

  void updateScale(double value) {
    if ((scale - value).abs() < 0.001) return;
    scale = value;
    notifyListeners();
  }

  void reset() {
    scale = 1.0;
    offset = Offset.zero;
    notifyListeners();
  }
}

class _InstagramBatchImageEditorPageState
    extends State<InstagramBatchImageEditorPage> {
  late final PageController _pageController;
  late final List<_PhotoEditState> _states;

  final List<ui.Size> _imageSizes = <ui.Size>[];

  int _currentIndex = 0;
  bool _saving = false;
  bool _loadingImages = true;

  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _states = List<_PhotoEditState>.generate(
      widget.sourceFiles.length,
          (_) => _PhotoEditState(),
    );
    _loadImageSizes();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final state in _states) {
      state.dispose();
    }
    super.dispose();
  }

  Future<void> _loadImageSizes() async {
    try {
      final List<ui.Size> sizes = <ui.Size>[];
      for (final file in widget.sourceFiles) {
        sizes.add(await _readImageSize(file));
      }

      if (!mounted) return;
      setState(() {
        _imageSizes
          ..clear()
          ..addAll(sizes);
        _loadingImages = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _imageSizes
          ..clear()
          ..addAll(
            List<ui.Size>.generate(
              widget.sourceFiles.length,
                  (_) => const ui.Size(1080, 1080),
            ),
          );
        _loadingImages = false;
      });
    }
  }

  Future<ui.Size> _readImageSize(File file) async {
    final Uint8List bytes = await file.readAsBytes();
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded != null) {
      final img.Image baked = img.bakeOrientation(decoded);
      return ui.Size(baked.width.toDouble(), baked.height.toDouble());
    }

    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    return ui.Size(image.width.toDouble(), image.height.toDouble());
  }

  Offset _clampOffset({
    required Offset offset,
    required double scale,
    required double imageWidth,
    required double imageHeight,
    required double editorSize,
  }) {
    if (imageWidth <= 0 || imageHeight <= 0) return Offset.zero;

    final double containScale =
    math.min(editorSize / imageWidth, editorSize / imageHeight);

    final double visibleWidth = imageWidth * containScale * scale;
    final double visibleHeight = imageHeight * containScale * scale;

    final double maxDx = math.max(0, (visibleWidth - editorSize) / 2);
    final double maxDy = math.max(0, (visibleHeight - editorSize) / 2);

    return Offset(
      offset.dx.clamp(-maxDx, maxDx).toDouble(),
      offset.dy.clamp(-maxDy, maxDy).toDouble(),
    );
  }

  void _resetCurrent() {
    if (_currentIndex < 0 || _currentIndex >= _states.length) return;
    _states[_currentIndex].reset();
  }

  Future<void> _goToPhoto(int index) async {
    if (_saving || _loadingImages) return;
    if (index < 0 || index >= widget.sourceFiles.length) return;

    setState(() => _currentIndex = index);
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _previousPhoto() => _goToPhoto(_currentIndex - 1);

  Future<void> _nextPhoto() => _goToPhoto(_currentIndex + 1);

  Future<File> _exportEditedPhoto({
    required File file,
    required _PhotoEditState state,
    required int index,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Görsel okunamadı.');
    decoded = img.bakeOrientation(decoded);

    const int outputSize = 1080;
    final double imageWidth = decoded.width.toDouble();
    final double imageHeight = decoded.height.toDouble();

    final double containScale =
    math.min(outputSize / imageWidth, outputSize / imageHeight);
    final double totalScale = containScale * state.scale;

    final int drawWidth = math.max(1, (imageWidth * totalScale).round());
    final int drawHeight = math.max(1, (imageHeight * totalScale).round());

    final Offset clampedOffset = _clampOffset(
      offset: state.offset,
      scale: state.scale,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      editorSize: outputSize.toDouble(),
    );

    final img.Image canvas = img.Image(
      width: outputSize,
      height: outputSize,
      numChannels: 3,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    final img.Image resized = img.copyResize(
      decoded,
      width: drawWidth,
      height: drawHeight,
      interpolation: img.Interpolation.average,
    );

    final int dstX = ((outputSize - drawWidth) / 2 + clampedOffset.dx).round();
    final int dstY = ((outputSize - drawHeight) / 2 + clampedOffset.dy).round();

    img.compositeImage(canvas, resized, dstX: dstX, dstY: dstY);

    final Directory tempDir = await getTemporaryDirectory();
    final String path =
        '${tempDir.path}/nova_post_full_editor_${DateTime.now().microsecondsSinceEpoch}_$index.jpg';

    final File result = File(path);
    await result.writeAsBytes(img.encodeJpg(canvas, quality: 94), flush: true);
    return result;
  }

  Future<void> _saveAll() async {
    if (_saving || _loadingImages) return;
    setState(() => _saving = true);

    try {
      final List<File> resultFiles = <File>[];

      for (int i = 0; i < widget.sourceFiles.length; i++) {
        resultFiles.add(
          await _exportEditedPhoto(
            file: widget.sourceFiles[i],
            state: _states[i],
            index: i,
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, resultFiles);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraflar kaydedilemedi: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.sourceFiles.length;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1),
      ),
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
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (total > 1)
                            Text(
                              '${_currentIndex + 1}/$total',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: _loadingImages
                    ? const _EditorLoadingView()
                    : PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: total,
                  onPageChanged: (index) {
                    if (mounted) setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final ui.Size imageSize = _imageSizes[index];

                    return AdvancedInstagramEditableImageBox(
                      file: widget.sourceFiles[index],
                      state: _states[index],
                      imageWidth: imageSize.width,
                      imageHeight: imageSize.height,
                      minScale: _minScale,
                      maxScale: _maxScale,
                      clampOffset: _clampOffset,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Column(
                  children: [
                    const Text(
                      'Fotoğraf albümden geldiği gibi tam görünür. Tek parmakla konumlandır, çizgiden yakınlaştır/uzaklaştır.',
                      textAlign: TextAlign.center,
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
                      animation: _states[_currentIndex],
                      builder: (context, _) {
                        return _ZoomSliderBox(
                          value: _states[_currentIndex].scale,
                          min: _minScale,
                          max: _maxScale,
                          enabled: !_saving && !_loadingImages,
                          onChanged: (value) {
                            if (_saving || _loadingImages) return;
                            final ui.Size imageSize = _imageSizes[_currentIndex];
                            _states[_currentIndex].updateScale(value);
                            _states[_currentIndex].updateOffset(
                              _clampOffset(
                                offset: _states[_currentIndex].offset,
                                scale: value,
                                imageWidth: imageSize.width,
                                imageHeight: imageSize.height,
                                editorSize:
                                math.min(MediaQuery.of(context).size.width, 430) - 30,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _AnalogPhotoButton(
                          icon: Icons.keyboard_arrow_left_rounded,
                          label: 'Önceki',
                          enabled: !_saving && !_loadingImages && _currentIndex > 0,
                          onTap: _previousPhoto,
                        ),
                        const SizedBox(width: 10),
                        _RoundEditorButton(
                          icon: Icons.refresh_rounded,
                          label: 'Sıfırla',
                          enabled: !_saving && !_loadingImages,
                          onTap: _resetCurrent,
                        ),
                        const SizedBox(width: 10),
                        _AnalogPhotoButton(
                          icon: Icons.keyboard_arrow_right_rounded,
                          label: 'Sonraki',
                          enabled: !_saving &&
                              !_loadingImages &&
                              _currentIndex < total - 1,
                          onTap: _nextPhoto,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saving || _loadingImages ? null : _saveAll,
                        icon: _saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.black,
                          ),
                        )
                            : const Icon(Icons.check_rounded),
                        label: Text(
                          _saving
                              ? 'Kaydediliyor'
                              : _loadingImages
                              ? 'Yükleniyor'
                              : 'Kaydet ve Devam Et',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white70,
                          disabledForegroundColor: Colors.black45,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
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

class _EditorLoadingView extends StatelessWidget {
  const _EditorLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 178,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF101010),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Görseller yükleniyor',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstagramImageEditorPage extends StatelessWidget {
  final File sourceFile;
  final String title;

  const InstagramImageEditorPage({
    super.key,
    required this.sourceFile,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return InstagramBatchImageEditorPage(
      sourceFiles: [sourceFile],
      title: title,
    );
  }
}

class AdvancedInstagramEditableImageBox extends StatelessWidget {
  final File file;
  final _PhotoEditState state;
  final double imageWidth;
  final double imageHeight;
  final double minScale;
  final double maxScale;
  final Offset Function({
  required Offset offset,
  required double scale,
  required double imageWidth,
  required double imageHeight,
  required double editorSize,
  }) clampOffset;

  const AdvancedInstagramEditableImageBox({
    super.key,
    required this.file,
    required this.state,
    required this.imageWidth,
    required this.imageHeight,
    required this.minScale,
    required this.maxScale,
    required this.clampOffset,
  });

  void _onPanUpdate(DragUpdateDetails details, double editorSize) {
    final Offset nextOffset = state.offset + details.delta;

    final Offset clamped = clampOffset(
      offset: nextOffset,
      scale: state.scale,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      editorSize: editorSize,
    );

    state.updateOffset(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double editorSize = math.min(screenWidth, 430) - 30;

    final double safeImageWidth = imageWidth <= 0 ? 1 : imageWidth;
    final double safeImageHeight = imageHeight <= 0 ? 1 : imageHeight;

    final double containScale =
    math.min(editorSize / safeImageWidth, editorSize / safeImageHeight);

    final double baseWidth = safeImageWidth * containScale;
    final double baseHeight = safeImageHeight * containScale;

    state.setOffsetSilently(
      clampOffset(
        offset: state.offset,
        scale: state.scale,
        imageWidth: safeImageWidth,
        imageHeight: safeImageHeight,
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
                  color: Colors.white.withOpacity(0.22),
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
                  onPanUpdate: (details) => _onPanUpdate(details, editorSize),
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
                                    child: Icon(
                                      Icons.broken_image_rounded,
                                      color: Colors.black,
                                      size: 44,
                                    ),
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
            'Beyaz karenin içinde görünen alan paylaşılacak.',
            textAlign: TextAlign.center,
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

class _ZoomSliderBox extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _ZoomSliderBox({
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final double percent = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final String zoomText = '${value.toStringAsFixed(2)}x';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 0),
          ),
        ],
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
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                zoomText,
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
              valueIndicatorColor: Colors.white,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.black,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w900,
              ),
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

class _AnalogPhotoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _AnalogPhotoButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF101010),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 30),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white70,
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
  }
}

class _RoundEditorButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _RoundEditorButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.black, size: 24),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black,
                    fontSize: 10.5,
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


class CreatePostHeader extends StatelessWidget {
  final VoidCallback onBackTap;

  const CreatePostHeader({super.key, required this.onBackTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Post Paylaş',
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
    required this.selectedCount,
    required this.maxCount,
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
            height: 58,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSharing ? null : onTap,
              icon: Icon(
                selected ? Icons.add_photo_alternate_rounded : Icons.photo_library_rounded,
              ),
              label: Text(
                selected ? 'Fotoğraf Ekle ($selectedCount/$maxCount)' : 'Fotoğraf Seç (En fazla $maxCount)',
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class InfoText extends StatelessWidget {
  final String text;

  const InfoText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
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
  final void Function(int index) onChangeTap;
  final void Function(int index) onRemoveTap;
  final void Function(int index) onMoveLeft;
  final void Function(int index) onMoveRight;

  const SelectedImagesPreview({
    super.key,
    required this.files,
    required this.isSharing,
    required this.maxCount,
    required this.onEditTap,
    required this.onChangeTap,
    required this.onRemoveTap,
    required this.onMoveLeft,
    required this.onMoveRight,
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
                      errorBuilder: (_, __, ___) {
                        return const Center(
                          child: Icon(Icons.broken_image_rounded, color: Colors.white, size: 34),
                        );
                      },
                    ),
                  ),
                  Positioned(top: 8, left: 8, child: _SmallBadge(text: '${index + 1}')),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Row(
                      children: [
                        RoundActionButton(
                          icon: Icons.tune_rounded,
                          size: 34,
                          iconSize: 18,
                          onTap: isSharing ? null : () => onEditTap(index),
                        ),
                        const SizedBox(width: 6),
                        RoundActionButton(
                          icon: Icons.change_circle_rounded,
                          size: 34,
                          iconSize: 18,
                          onTap: isSharing ? null : () => onChangeTap(index),
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
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Row(
                      children: [
                        RoundActionButton(
                          icon: Icons.chevron_left_rounded,
                          size: 34,
                          iconSize: 22,
                          onTap: isSharing || index == 0 ? null : () => onMoveLeft(index),
                        ),
                        const Spacer(),
                        RoundActionButton(
                          icon: Icons.chevron_right_rounded,
                          size: 34,
                          iconSize: 22,
                          onTap: isSharing || index == files.length - 1 ? null : () => onMoveRight(index),
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

class _SmallBadge extends StatelessWidget {
  final String text;

  const _SmallBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
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
        opacity: onTap == null ? 0.38 : 1,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.72),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}

class LockedLocationBox extends StatelessWidget {
  final String location;
  final bool loading;

  const LockedLocationBox({super.key, required this.location, required this.loading});

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
          inputFormatters: [LengthLimitingTextInputFormatter(limit)],
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
            const Icon(Icons.info_outline_rounded, color: Colors.black38, size: 17),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Açıklama sınırı 300 karakterdir.',
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

  const OptionSection({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
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
        border: Border(top: BorderSide(color: Colors.black12)),
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
                : Icon(hasImage ? Icons.send_rounded : Icons.photo_library_rounded),
            label: Text(
              isSharing ? 'Yükleniyor %$percent' : 'Paylaş',
              style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: Colors.black54,
              disabledForegroundColor: Colors.white,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ),
    );
  }
}

class UploadLoadingOverlay extends StatelessWidget {
  final double progress;

  const UploadLoadingOverlay({super.key, required this.progress});

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
