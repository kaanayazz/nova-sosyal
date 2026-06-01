// lib/pages/auth_page.dart
//
// NOVA giriş sayfası
// - 6 saniye premium hoş geldin / loading ekranı
// - NOVA logosu main.dart ile aynı V renkleri
// - Açıklama yazıları kaldırıldı
// - Kırmızı ekran hatasına sebep olan withOpacity değerleri güvenli hale getirildi
// - Tüm ekranlar küçük telefonlarda taşmasın diye responsive hazırlandı

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  final PageController pageController = PageController();

  late final AnimationController welcomeController;
  late final AnimationController bgController;
  late final AnimationController logoController;
  late final AnimationController floatController;
  late final AnimationController iconController;

  bool showWelcome = true;
  bool loading = false;
  int currentPage = 0;

  final List<_OnboardingData> pages = const [
    _OnboardingData(
      title: 'Araç dünyan tek ekranda',
      icon: Icons.directions_car_filled_rounded,
      secondIcon: Icons.auto_awesome_rounded,
      miniIcons: [
        Icons.speed_rounded,
        Icons.favorite_rounded,
        Icons.location_on_rounded,
      ],
    ),
    _OnboardingData(
      title: 'Takip et, mesajlaş, bağlan',
      icon: Icons.chat_bubble_rounded,
      secondIcon: Icons.people_alt_rounded,
      miniIcons: [
        Icons.notifications_rounded,
        Icons.person_add_alt_1_rounded,
        Icons.lock_rounded,
      ],
    ),
    _OnboardingData(
      title: 'İlan ve çekici desteği',
      icon: Icons.car_repair_rounded,
      secondIcon: Icons.local_shipping_rounded,
      miniIcons: [
        Icons.sell_rounded,
        Icons.call_rounded,
        Icons.map_rounded,
      ],
    ),
    _OnboardingData(
      title: 'Masraflarını kontrol et',
      icon: Icons.insert_chart_rounded,
      secondIcon: Icons.account_balance_wallet_rounded,
      miniIcons: [
        Icons.receipt_long_rounded,
        Icons.event_rounded,
        Icons.storefront_rounded,
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();

    welcomeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => showWelcome = false);
      welcomeController.stop();
    });
  }

  @override
  void dispose() {
    pageController.dispose();
    welcomeController.dispose();
    bgController.dispose();
    logoController.dispose();
    floatController.dispose();
    iconController.dispose();
    super.dispose();
  }

  String friendlyAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'account-exists-with-different-credential':
          return 'Bu e-posta farklı bir giriş yöntemiyle kullanılıyor.';
        case 'invalid-credential':
          return 'Giriş bilgisi doğrulanamadı. Tekrar dene.';
        case 'network-request-failed':
          return 'İnternet bağlantını kontrol et.';
        case 'user-disabled':
          return 'Bu hesap devre dışı bırakılmış.';
        default:
          return 'Google ile giriş tamamlanamadı. Tekrar dene.';
      }
    }
    return 'Bir sorun oluştu. Lütfen tekrar dene.';
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Future<void> createUserDoc(User user) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final currentDoc = await userRef.get();
    final oldData = currentDoc.data() ?? <String, dynamic>{};
    final isFirstCreate = !currentDoc.exists;

    await userRef.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'phone': oldData['phone'] ?? '',
      'city': oldData['city'] ?? '',
      'district': oldData['district'] ?? '',
      'photoUrl': user.photoURL ?? oldData['photoUrl'] ?? '',
      'provider': 'google',
      'role': oldData['role'] ?? 'user',
      'profileCompleted': oldData['profileCompleted'] ?? false,
      'followersCount': oldData['followersCount'] ?? 0,
      'followingCount': oldData['followingCount'] ?? 0,
      'postsCount': oldData['postsCount'] ?? 0,
      'lastLoginAt': FieldValue.serverTimestamp(),
      if (isFirstCreate) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signInWithGoogle() async {
    if (loading) return;

    try {
      setState(() => loading = true);

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => loading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user;
      if (user != null) {
        await createUserDoc(user);
      }
    } catch (e) {
      showError(friendlyAuthError(e));
    }

    if (mounted) setState(() => loading = false);
  }

  void showAppleSoon() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.32),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF00B8).withOpacity(0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: const Color(0xFF00D9FF).withOpacity(0.14),
                  blurRadius: 24,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apple_rounded, size: 54, color: Colors.black),
                const SizedBox(height: 12),
                const Text(
                  'Apple ile giriş yakında',
                  textScaler: TextScaler.noScaling,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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

  void nextPage() {
    if (currentPage >= pages.length) return;
    pageController.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  void previousPage() {
    if (currentPage <= 0) return;
    pageController.previousPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  void skipToLogin() {
    pageController.animateToPage(
      pages.length,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: showWelcome
              ? _WelcomeScreen(
            key: const ValueKey('welcome'),
            welcomeController: welcomeController,
            logoController: logoController,
          )
              : _MainFlow(
            key: const ValueKey('main_flow'),
            bgController: bgController,
            logoController: logoController,
            floatController: floatController,
            iconController: iconController,
            pageController: pageController,
            pages: pages,
            currentPage: currentPage,
            loading: loading,
            onPageChanged: (index) => setState(() => currentPage = index),
            onGoogleTap: signInWithGoogle,
            onAppleTap: showAppleSoon,
            onBack: previousPage,
            onNext: nextPage,
            onSkip: skipToLogin,
          ),
        ),
      ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  final AnimationController welcomeController;
  final AnimationController logoController;

  const _WelcomeScreen({
    super.key,
    required this.welcomeController,
    required this.logoController,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final small = height < 680;

    return Stack(
      children: [
        Positioned.fill(child: _SoftWelcomeBackground(controller: logoController)),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: AnimatedBuilder(
                        animation: welcomeController,
                        builder: (context, _) {
                          final opacity = (0.52 + welcomeController.value * 0.48).clamp(0.0, 1.0);
                          final scale = 0.98 + welcomeController.value * 0.03;

                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _NovaLogoText(
                                    controller: logoController,
                                    fontSize: small ? 42 : 50,
                                    letterSpacing: small ? 5 : 6,
                                    studio: false,
                                  ),
                                  SizedBox(height: small ? 18 : 24),
                                  const Text(
                                    'Yeni sosyal araç platformu',
                                    textScaler: TextScaler.noScaling,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      color: Colors.black54,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'NOVA’ya hoş geldin',
                                    textScaler: TextScaler.noScaling,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      color: Colors.black,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: small ? 24 : 34),
                                  const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
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
      ],
    );
  }
}

class _MainFlow extends StatelessWidget {
  final AnimationController bgController;
  final AnimationController logoController;
  final AnimationController floatController;
  final AnimationController iconController;
  final PageController pageController;
  final List<_OnboardingData> pages;
  final int currentPage;
  final bool loading;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onGoogleTap;
  final VoidCallback onAppleTap;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _MainFlow({
    super.key,
    required this.bgController,
    required this.logoController,
    required this.floatController,
    required this.iconController,
    required this.pageController,
    required this.pages,
    required this.currentPage,
    required this.loading,
    required this.onPageChanged,
    required this.onGoogleTap,
    required this.onAppleTap,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _NovaAnimatedBackground(controller: bgController)),
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: Center(
                  child: _NovaLogoText(controller: logoController),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  itemCount: pages.length + 1,
                  onPageChanged: onPageChanged,
                  itemBuilder: (context, index) {
                    if (index == pages.length) {
                      return _LoginPage(
                        loading: loading,
                        floatController: floatController,
                        iconController: iconController,
                        onGoogleTap: onGoogleTap,
                        onAppleTap: onAppleTap,
                      );
                    }

                    return _OnboardingPage(
                      data: pages[index],
                      index: index,
                      floatController: floatController,
                      iconController: iconController,
                    );
                  },
                ),
              ),
              _BottomControls(
                currentPage: currentPage,
                totalPages: pages.length + 1,
                isLoginPage: currentPage == pages.length,
                onBack: onBack,
                onNext: onNext,
                onSkip: onSkip,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NovaLogoText extends StatelessWidget {
  final AnimationController controller;
  final double fontSize;
  final double letterSpacing;
  final bool studio;

  const _NovaLogoText({
    required this.controller,
    this.fontSize = 25,
    this.letterSpacing = 4,
    this.studio = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              textScaler: TextScaler.noScaling,
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: letterSpacing,
                  color: Colors.black,
                  height: 1,
                ),
                children: [
                  const TextSpan(text: 'NO'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment(-1 + controller.value * 2, 0),
                          end: Alignment(1 - controller.value * 2, 0),
                          colors: const [
                            Color(0xFF00D9FF),
                            Color(0xFF3C7BFF),
                            Color(0xFFFF00B8),
                            Color(0xFFFF7A00),
                          ],
                        ).createShader(bounds);
                      },
                      child: Text(
                        'V',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: letterSpacing,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: 'A'),
                ],
              ),
            ),
            if (studio) ...[
              const SizedBox(height: 1),
              const Text(
                'Kaan Ayaz Studio',
                textScaler: TextScaler.noScaling,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  height: 1,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _OnboardingData {
  final String title;
  final IconData icon;
  final IconData secondIcon;
  final List<IconData> miniIcons;

  const _OnboardingData({
    required this.title,
    required this.icon,
    required this.secondIcon,
    required this.miniIcons,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  final int index;
  final AnimationController floatController;
  final AnimationController iconController;

  const _OnboardingPage({
    required this.data,
    required this.index,
    required this.floatController,
    required this.iconController,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final small = height < 680;

    return Padding(
      padding: EdgeInsets.fromLTRB(22, small ? 0 : 8, 22, 4),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([floatController, iconController]),
                builder: (context, _) {
                  final floatY = math.sin(floatController.value * math.pi) * -10;
                  final pulse = 1 + (math.sin(iconController.value * math.pi * 2) * 0.025);
                  return Transform.translate(
                    offset: Offset(0, floatY),
                    child: Transform.scale(
                      scale: pulse,
                      child: _AnimatedIconStage(
                        icon: data.icon,
                        secondIcon: data.secondIcon,
                        miniIcons: data.miniIcons,
                        controller: iconController,
                        index: index,
                        size: small ? 236 : 286,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Text(
            data.title,
            textScaler: TextScaler.noScaling,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: small ? 24 : 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: Colors.black,
            ),
          ),
          SizedBox(height: small ? 8 : 14),
        ],
      ),
    );
  }
}

class _LoginPage extends StatelessWidget {
  final bool loading;
  final AnimationController floatController;
  final AnimationController iconController;
  final VoidCallback onGoogleTap;
  final VoidCallback onAppleTap;

  const _LoginPage({
    required this.loading,
    required this.floatController,
    required this.iconController,
    required this.onGoogleTap,
    required this.onAppleTap,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final small = height < 680;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([floatController, iconController]),
                builder: (context, _) {
                  final y = math.sin(floatController.value * math.pi) * -10;
                  return Transform.translate(
                    offset: Offset(0, y),
                    child: _LoginOrb(
                      controller: iconController,
                      size: small ? 230 : 286,
                    ),
                  );
                },
              ),
            ),
          ),
          Text(
            'NOVA’ya giriş yap',
            textScaler: TextScaler.noScaling,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: small ? 24 : 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: Colors.black,
            ),
          ),
          SizedBox(height: small ? 18 : 24),
          _NeonSocialButton(
            text: 'Google ile devam et',
            iconAsset: 'assets/images/google.png',
            fallbackIcon: Icons.g_mobiledata_rounded,
            loading: loading,
            onTap: onGoogleTap,
          ),
          const SizedBox(height: 12),
          _NeonSocialButton(
            text: 'Apple ile devam et',
            fallbackIcon: Icons.apple_rounded,
            loading: false,
            muted: true,
            onTap: onAppleTap,
          ),
          SizedBox(height: small ? 10 : 18),
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isLoginPage;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _BottomControls({
    required this.currentPage,
    required this.totalPages,
    required this.isLoginPage,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (index) {
                final active = index == currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: active
                        ? const LinearGradient(
                      colors: [
                        Color(0xFF00D9FF),
                        Color(0xFF3C7BFF),
                        Color(0xFFFF00B8),
                      ],
                    )
                        : null,
                    color: active ? null : Colors.black.withOpacity(0.15),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 86,
                  child: TextButton(
                    onPressed: isLoginPage ? null : onSkip,
                    child: Text(
                      isLoginPage ? '' : 'Atla',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w900,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: currentPage > 0
                        ? _SmallNeonButton(text: 'Geri', onTap: onBack)
                        : const SizedBox(height: 44),
                  ),
                ),
                SizedBox(
                  width: 86,
                  child: isLoginPage
                      ? const SizedBox.shrink()
                      : TextButton(
                    onPressed: onNext,
                    child: const Text(
                      'İleri',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
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

class _SmallNeonButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SmallNeonButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D9FF).withOpacity(0.14),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color: const Color(0xFFFF00B8).withOpacity(0.09),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _NeonSocialButton extends StatelessWidget {
  final String text;
  final String? iconAsset;
  final IconData fallbackIcon;
  final bool loading;
  final bool muted;
  final VoidCallback onTap;

  const _NeonSocialButton({
    required this.text,
    this.iconAsset,
    required this.fallbackIcon,
    required this.loading,
    this.muted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00D9FF),
              Color(0xFF3C7BFF),
              Color(0xFFFF00B8),
              Color(0xFFFF7A00),
            ],
          ),
          boxShadow: muted
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ]
              : [
            BoxShadow(
              color: const Color(0xFFFF00B8).withOpacity(0.20),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFF00D9FF).withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.6),
          child: ElevatedButton(
            onPressed: loading ? null : onTap,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shadowColor: Colors.transparent,
              backgroundColor: Colors.white,
              disabledBackgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: loading
                ? const SizedBox(
              width: 23,
              height: 23,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.black,
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconAsset != null)
                  Image.asset(
                    iconAsset!,
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(fallbackIcon, size: 30, color: Colors.black);
                    },
                  )
                else
                  Icon(fallbackIcon, size: 28, color: Colors.black),
                const SizedBox(width: 11),
                Text(
                  text,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: muted ? Colors.black.withOpacity(0.78) : Colors.black,
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

class _SoftWelcomeBackground extends StatelessWidget {
  final AnimationController controller;

  const _SoftWelcomeBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _SoftWelcomePainter(value: controller.value),
        );
      },
    );
  }
}

class _SoftWelcomePainter extends CustomPainter {
  final double value;

  const _SoftWelcomePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final t = value * math.pi * 2;

    void blob(Offset center, double radius, Color color, double opacity) {
      final safeOpacity = opacity.clamp(0.0, 1.0);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(safeOpacity),
            color.withOpacity((safeOpacity * 0.42).clamp(0.0, 1.0)),
            color.withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    blob(
      Offset(size.width * (0.12 + math.sin(t) * 0.03), size.height * 0.22),
      210,
      const Color(0xFF00D9FF),
      0.18,
    );
    blob(
      Offset(size.width * (0.88 + math.cos(t) * 0.03), size.height * 0.35),
      230,
      const Color(0xFFFF00B8),
      0.15,
    );
    blob(
      Offset(size.width * 0.50, size.height * (0.82 + math.sin(t * 0.8) * 0.02)),
      260,
      const Color(0xFFFF7A00),
      0.10,
    );
  }

  @override
  bool shouldRepaint(covariant _SoftWelcomePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _NovaAnimatedBackground extends StatelessWidget {
  final AnimationController controller;

  const _NovaAnimatedBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _NovaBackgroundPainter(value: controller.value),
        );
      },
    );
  }
}

class _NovaBackgroundPainter extends CustomPainter {
  final double value;

  const _NovaBackgroundPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final t = value * math.pi * 2;

    void drawBlob(Offset center, double radius, Color color, double opacity) {
      final safeOpacity = opacity.clamp(0.0, 1.0);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(safeOpacity),
            color.withOpacity((safeOpacity * 0.45).clamp(0.0, 1.0)),
            color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    drawBlob(
      Offset(
        size.width * (0.12 + math.sin(t) * 0.035),
        size.height * (0.19 + math.cos(t * 0.8) * 0.025),
      ),
      210,
      const Color(0xFF00D9FF),
      0.16,
    );

    drawBlob(
      Offset(
        size.width * (0.88 + math.cos(t * 0.9) * 0.035),
        size.height * (0.31 + math.sin(t * 0.7) * 0.026),
      ),
      230,
      const Color(0xFFFF00B8),
      0.14,
    );

    drawBlob(
      Offset(
        size.width * (0.52 + math.sin(t * 0.65) * 0.04),
        size.height * (0.86 + math.cos(t * 0.55) * 0.025),
      ),
      260,
      const Color(0xFFFF7A00),
      0.10,
    );

    drawBlob(
      Offset(
        size.width * (0.18 + math.cos(t * 0.7) * 0.035),
        size.height * (0.78 + math.sin(t * 0.9) * 0.025),
      ),
      200,
      const Color(0xFF3C7BFF),
      0.10,
    );
  }

  @override
  bool shouldRepaint(covariant _NovaBackgroundPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _AnimatedIconStage extends StatelessWidget {
  final IconData icon;
  final IconData secondIcon;
  final List<IconData> miniIcons;
  final AnimationController controller;
  final int index;
  final double size;

  const _AnimatedIconStage({
    required this.icon,
    required this.secondIcon,
    required this.miniIcons,
    required this.controller,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final rotation = controller.value * math.pi * 2;
    final colors = [
      const Color(0xFF00D9FF),
      const Color(0xFF3C7BFF),
      const Color(0xFFFF00B8),
      const Color(0xFFFF7A00),
    ];

    final big = size * 0.85;
    final inner = size * 0.75;
    final core = size * 0.61;
    final center = size / 2;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: rotation * 0.16,
            child: Container(
              width: big,
              height: big,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFF00D9FF),
                    Color(0xFF3C7BFF),
                    Color(0xFFFF00B8),
                    Color(0xFFFF7A00),
                    Color(0xFF00D9FF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF00B8).withOpacity(0.16),
                    blurRadius: 26,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: inner,
            height: inner,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: core,
            height: core,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              gradient: RadialGradient(
                colors: [
                  colors[index % colors.length].withOpacity(0.12),
                  Colors.white,
                ],
              ),
            ),
            child: Icon(icon, size: size * 0.29, color: Colors.black),
          ),
          Positioned(
            right: size * 0.15 + math.sin(rotation) * 4,
            top: size * 0.15 + math.cos(rotation) * 4,
            child: _FloatingMiniIcon(
              icon: secondIcon,
              color: colors[(index + 1) % colors.length],
              size: size * 0.19,
            ),
          ),
          ...List.generate(miniIcons.length, (i) {
            final angle = rotation + (i * math.pi * 2 / miniIcons.length) + index;
            final radius = size * 0.39;
            final mini = size * 0.16;
            return Positioned(
              left: center + math.cos(angle) * radius - mini / 2,
              top: center + math.sin(angle) * radius - mini / 2,
              child: _FloatingMiniIcon(
                icon: miniIcons[i],
                color: colors[(i + index) % colors.length],
                size: mini,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FloatingMiniIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _FloatingMiniIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.24),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.black, size: size * 0.48),
    );
  }
}

class _LoginOrb extends StatelessWidget {
  final AnimationController controller;
  final double size;

  const _LoginOrb({
    required this.controller,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final rotation = controller.value * math.pi * 2;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: rotation * 0.2,
            child: Container(
              width: size * 0.86,
              height: size * 0.86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFFFF00B8),
                    Color(0xFF3C7BFF),
                    Color(0xFF00D9FF),
                    Color(0xFFFF7A00),
                    Color(0xFFFF00B8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF00B8).withOpacity(0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withOpacity(0.13),
                    blurRadius: 24,
                    offset: const Offset(0, -7),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: size * 0.75,
            height: size * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: size * 0.61,
            height: size * 0.61,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Icon(
              Icons.verified_user_rounded,
              size: size * 0.29,
              color: Colors.black,
            ),
          ),
          Positioned(
            top: size * 0.12 + math.sin(rotation) * 5,
            right: size * 0.17 + math.cos(rotation) * 5,
            child: _FloatingMiniIcon(
              icon: Icons.g_mobiledata_rounded,
              color: const Color(0xFF00D9FF),
              size: size * 0.20,
            ),
          ),
          Positioned(
            bottom: size * 0.15 + math.cos(rotation) * 5,
            left: size * 0.17 + math.sin(rotation) * 5,
            child: _FloatingMiniIcon(
              icon: Icons.apple_rounded,
              color: const Color(0xFFFF00B8),
              size: size * 0.19,
            ),
          ),
          Positioned(
            bottom: size * 0.20 + math.sin(rotation) * 4,
            right: size * 0.13 + math.cos(rotation) * 4,
            child: _FloatingMiniIcon(
              icon: Icons.lock_rounded,
              color: const Color(0xFFFF7A00),
              size: size * 0.16,
            ),
          ),
        ],
      ),
    );
  }
}
