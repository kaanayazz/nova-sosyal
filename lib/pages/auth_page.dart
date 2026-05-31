// lib/pages/auth_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final districtController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isRegister = false;
  bool loading = false;
  bool passwordVisible = false;

  String? selectedCity;

  late final AnimationController neonController;

  final List<String> cities = const [
    'Adana',
    'Adıyaman',
    'Afyonkarahisar',
    'Ağrı',
    'Amasya',
    'Ankara',
    'Antalya',
    'Artvin',
    'Aydın',
    'Balıkesir',
    'Bilecik',
    'Bingöl',
    'Bitlis',
    'Bolu',
    'Burdur',
    'Bursa',
    'Çanakkale',
    'Çankırı',
    'Çorum',
    'Denizli',
    'Diyarbakır',
    'Edirne',
    'Elazığ',
    'Erzincan',
    'Erzurum',
    'Eskişehir',
    'Gaziantep',
    'Giresun',
    'Gümüşhane',
    'Hakkari',
    'Hatay',
    'Isparta',
    'Mersin',
    'İstanbul',
    'İzmir',
    'Kars',
    'Kastamonu',
    'Kayseri',
    'Kırklareli',
    'Kırşehir',
    'Kocaeli',
    'Konya',
    'Kütahya',
    'Malatya',
    'Manisa',
    'Kahramanmaraş',
    'Mardin',
    'Muğla',
    'Muş',
    'Nevşehir',
    'Niğde',
    'Ordu',
    'Rize',
    'Sakarya',
    'Samsun',
    'Siirt',
    'Sinop',
    'Sivas',
    'Tekirdağ',
    'Tokat',
    'Trabzon',
    'Tunceli',
    'Şanlıurfa',
    'Uşak',
    'Van',
    'Yozgat',
    'Zonguldak',
    'Aksaray',
    'Bayburt',
    'Karaman',
    'Kırıkkale',
    'Batman',
    'Şırnak',
    'Bartın',
    'Ardahan',
    'Iğdır',
    'Yalova',
    'Karabük',
    'Kilis',
    'Osmaniye',
    'Düzce',
  ];

  @override
  void initState() {
    super.initState();
    neonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    neonController.dispose();
    nameController.dispose();
    phoneController.dispose();
    districtController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String friendlyAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'E-posta adresi geçerli değil.';
        case 'user-disabled':
          return 'Bu hesap devre dışı bırakılmış.';
        case 'user-not-found':
          return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-posta veya şifre hatalı.';
        case 'email-already-in-use':
          return 'Bu e-posta adresi zaten kayıtlı.';
        case 'weak-password':
          return 'Şifre en az 6 karakter olmalı.';
        case 'network-request-failed':
          return 'İnternet bağlantını kontrol et.';
        default:
          return 'İşlem tamamlanamadı. Tekrar dene.';
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
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> createUserDoc(
      User user, {
        String provider = 'email',
      }) async {
    final userRef =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    final currentDoc = await userRef.get();
    final isFirstCreate = !currentDoc.exists;

    await userRef.set({
      'uid': user.uid,
      'email': user.email ?? emailController.text.trim(),
      'displayName': provider == 'google'
          ? (user.displayName ?? '')
          : nameController.text.trim(),
      'phone': provider == 'google' ? '' : phoneController.text.trim(),
      'city': provider == 'google' ? '' : selectedCity,
      'district':
      provider == 'google' ? '' : districtController.text.trim(),
      'photoUrl': user.photoURL ?? '',
      'provider': provider,
      'role': 'user',
      'profileCompleted': provider == 'email',
      'followersCount': 0,
      'followingCount': 0,
      'postsCount': 0,
      'lastLoginAt': FieldValue.serverTimestamp(),
      if (isFirstCreate) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signInWithGoogle() async {
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

      final result =
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (result.user != null) {
        await createUserDoc(result.user!, provider: 'google');
      }
    } catch (_) {
      showError('Google ile giriş yapılamadı. Lütfen tekrar dene.');
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> submitEmailPassword() async {
    FocusScope.of(context).unfocus();

    try {
      setState(() => loading = true);

      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        showError('E-posta ve şifre alanlarını doldur.');
        setState(() => loading = false);
        return;
      }

      if (isRegister) {
        if (nameController.text.trim().isEmpty ||
            phoneController.text.trim().isEmpty ||
            selectedCity == null ||
            districtController.text.trim().isEmpty) {
          showError('Lütfen tüm kayıt bilgilerini doldur.');
          setState(() => loading = false);
          return;
        }

        final result =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (result.user != null) {
          await result.user!.updateDisplayName(nameController.text.trim());
          await createUserDoc(result.user!, provider: 'email');
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } catch (e) {
      showError(friendlyAuthError(e));
    }

    if (mounted) setState(() => loading = false);
  }

  void toggleMode() {
    setState(() {
      isRegister = !isRegister;
    });
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
            const _NovaBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    children: [
                      _NovaHeader(controller: neonController),
                      const SizedBox(height: 26),
                      _AuthGlassCard(
                        isRegister: isRegister,
                        loading: loading,
                        passwordVisible: passwordVisible,
                        nameController: nameController,
                        phoneController: phoneController,
                        districtController: districtController,
                        emailController: emailController,
                        passwordController: passwordController,
                        selectedCity: selectedCity,
                        cities: cities,
                        onCityChanged: (value) {
                          setState(() => selectedCity = value);
                        },
                        onPasswordVisibilityTap: () {
                          setState(() {
                            passwordVisible = !passwordVisible;
                          });
                        },
                        onSubmit: submitEmailPassword,
                        onGoogleTap: signInWithGoogle,
                        onToggleMode: toggleMode,
                      ),
                    ],
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

class _NovaBackground extends StatelessWidget {
  const _NovaBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -120,
          child: _GlowCircle(
            size: 270,
            color: const Color(0xFFFF00B8).withOpacity(0.20),
          ),
        ),
        Positioned(
          top: 180,
          left: -150,
          child: _GlowCircle(
            size: 300,
            color: const Color(0xFF00D9FF).withOpacity(0.18),
          ),
        ),
        Positioned(
          bottom: -120,
          right: -100,
          child: _GlowCircle(
            size: 260,
            color: const Color(0xFFFF7A00).withOpacity(0.14),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(),
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.025)
      ..strokeWidth = 1;

    const step = 34.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NovaHeader extends StatelessWidget {
  final AnimationController controller;

  const _NovaHeader({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Container(
              width: 118,
              height: 118,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment(-1 + controller.value * 2, -1),
                  end: Alignment(1 - controller.value * 2, 1),
                  colors: const [
                    Color(0xFF00D9FF),
                    Color(0xFF3C7BFF),
                    Color(0xFFFF00B8),
                    Color(0xFFFF7A00),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF00B8).withOpacity(0.22),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: RichText(
                    textScaler: TextScaler.noScaling,
                    text: const TextSpan(
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Colors.black,
                      ),
                      children: [
                        TextSpan(text: 'NO'),
                        TextSpan(
                          text: 'V',
                          style: TextStyle(
                            color: Color(0xFFFF00B8),
                          ),
                        ),
                        TextSpan(text: 'A'),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'NOVA',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Araç dünyanı, ilanlarını, mağazanı ve profilini tek ekranda birleştiren yeni nesil platform.',
            textScaler: TextScaler.noScaling,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black54,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthGlassCard extends StatelessWidget {
  final bool isRegister;
  final bool loading;
  final bool passwordVisible;

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController districtController;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  final String? selectedCity;
  final List<String> cities;

  final ValueChanged<String?> onCityChanged;
  final VoidCallback onPasswordVisibilityTap;
  final VoidCallback onSubmit;
  final VoidCallback onGoogleTap;
  final VoidCallback onToggleMode;

  const _AuthGlassCard({
    required this.isRegister,
    required this.loading,
    required this.passwordVisible,
    required this.nameController,
    required this.phoneController,
    required this.districtController,
    required this.emailController,
    required this.passwordController,
    required this.selectedCity,
    required this.cities,
    required this.onCityChanged,
    required this.onPasswordVisibilityTap,
    required this.onSubmit,
    required this.onGoogleTap,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                isRegister ? 'Yeni hesap oluştur' : 'Hesabına giriş yap',
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
                isRegister
                    ? 'NOVA profilini oluştur ve platforma katıl.'
                    : 'Kaldığın yerden devam et.',
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black45,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),

              if (!isRegister) ...[
                _GoogleButton(
                  loading: loading,
                  onTap: onGoogleTap,
                ),
                const SizedBox(height: 18),
                const _DividerText(text: 'veya e-posta ile devam et'),
                const SizedBox(height: 18),
              ],

              if (isRegister) ...[
                _NovaInput(
                  controller: nameController,
                  label: 'Ad Soyad',
                  icon: Icons.person_rounded,
                ),
                const SizedBox(height: 12),
                _NovaInput(
                  controller: phoneController,
                  label: 'Telefon Numarası',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _CityDropdown(
                  value: selectedCity,
                  cities: cities,
                  onChanged: onCityChanged,
                ),
                const SizedBox(height: 12),
                _NovaInput(
                  controller: districtController,
                  label: 'İlçe',
                  icon: Icons.map_rounded,
                ),
                const SizedBox(height: 12),
              ],

              _NovaInput(
                controller: emailController,
                label: 'E-posta',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _NovaInput(
                controller: passwordController,
                label: 'Şifre',
                icon: Icons.lock_rounded,
                obscureText: !passwordVisible,
                suffix: IconButton(
                  onPressed: onPasswordVisibilityTap,
                  icon: Icon(
                    passwordVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.black45,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _PrimaryButton(
                loading: loading,
                text: isRegister ? 'Kayıt Ol' : 'Giriş Yap',
                onTap: onSubmit,
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: loading ? null : onToggleMode,
                child: Text(
                  isRegister
                      ? 'Zaten hesabın var mı? Giriş yap'
                      : 'Hesabın yok mu? Kayıt ol',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
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

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _GoogleButton({
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: BorderSide(color: Colors.black.withOpacity(0.10)),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google.png',
              width: 23,
              height: 23,
            ),
            const SizedBox(width: 10),
            const Text(
              'Google ile giriş yap',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DividerText extends StatelessWidget {
  final String text;

  const _DividerText({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.black.withOpacity(0.10))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            text,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black38,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.black.withOpacity(0.10))),
      ],
    );
  }
}

class _CityDropdown extends StatelessWidget {
  final String? value;
  final List<String> cities;
  final ValueChanged<String?> onChanged;

  const _CityDropdown({
    required this.value,
    required this.cities,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      dropdownColor: Colors.white,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(
        labelText: 'İl Seç',
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w700,
          color: Colors.black45,
        ),
        prefixIcon: const Icon(Icons.location_city_rounded),
        filled: true,
        fillColor: Colors.white.withOpacity(0.88),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF00B8), width: 1.4),
        ),
      ),
      items: cities.map((city) {
        return DropdownMenuItem(
          value: city,
          child: Text(
            city,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _NovaInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffix;

  const _NovaInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: 'Roboto',
        color: Colors.black,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w700,
          color: Colors.black45,
        ),
        prefixIcon: Icon(icon, color: Colors.black54),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.88),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF00B8), width: 1.4),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final bool loading;
  final String text;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.loading,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00D9FF),
              Color(0xFF3C7BFF),
              Color(0xFFFF00B8),
              Color(0xFFFF7A00),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF00B8).withOpacity(0.26),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.black12,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(19),
            ),
          ),
          child: loading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          )
              : Text(
            text,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}