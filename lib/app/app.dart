import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/idcard/id_result_page.dart';
import '../features/registration/registration_page.dart';
import '../features/splash/splash_page.dart';
import '../services/biometric_service.dart';
import '../services/card_link.dart';
import '../services/id_record_store.dart';
import '../shared/widgets/brand_widgets.dart';
import 'theme/app_theme.dart';
import 'theme/brand_colors.dart';

/// Root of the A Digital Identity experience: splash → registration → card.
class ADigitalIdApp extends StatefulWidget {
  const ADigitalIdApp({
    super.key,
    this.storeOpener,
    this.enableDeepLinks = true,
    this.biometricService,
  });

  /// Overridable store factory for tests; defaults to [IdRecordStore.open].
  final Future<IdRecordStore> Function()? storeOpener;

  /// Listening for `adigitalid://card?…` links needs a platform channel, so
  /// widget tests switch it off.
  final bool enableDeepLinks;

  /// Overridable hardware-biometrics service; defaults to the real sensor.
  final BiometricService? biometricService;

  @override
  State<ADigitalIdApp> createState() => _ADigitalIdAppState();
}

class _ADigitalIdAppState extends State<ADigitalIdApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  Future<IdRecordStore>? _storeFuture;
  StreamSubscription<Uri>? _linkSubscription;
  bool _showRegistration = false;

  /// A card link that arrived before the app was ready to show it.
  Uri? _pendingLink;

  @override
  void initState() {
    super.initState();
    _openStore();
    if (widget.enableDeepLinks) _listenForCardLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _openStore() {
    _storeFuture = (widget.storeOpener ?? IdRecordStore.open)();
  }

  /// Scanning a card with the system camera opens `adigitalid://card?…`,
  /// which lands here and takes the user straight to the rebuilt card.
  Future<void> _listenForCardLinks() async {
    final links = AppLinks();
    try {
      final initial = await links.getInitialLink();
      if (initial != null) _handleLink(initial);
    } catch (_) {
      // A missing platform channel must never block the app from starting.
    }
    _linkSubscription = links.uriLinkStream.listen(
      _handleLink,
      onError: (_) {},
    );
  }

  void _handleLink(Uri uri) {
    if (!CardLink.looksLikeCard(uri.toString())) return;
    // The splash still owns the screen: remember it and open once we land.
    if (!_showRegistration) {
      _pendingLink = uri;
      return;
    }
    _openCard(uri);
  }

  void _openCard(Uri uri) {
    final card = CardLink.decode(uri.toString());
    final navigator = _navigatorKey.currentState;
    if (card == null || navigator == null) return;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => IdResultPage(
          applicant: card.applicant,
          personalId: card.personalId,
          issuedAt: card.issuedAt,
          mode: IdResultMode.scanned,
        ),
      ),
    );
  }

  void _finishSplash() {
    setState(() => _showRegistration = true);
    final pending = _pendingLink;
    if (pending == null) return;
    _pendingLink = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCard(pending));
  }

  void _retryStore() {
    setState(_openStore);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'الهوية الرقمية',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Keep interfaces readable on TV screens and huge text scales.
        final media = MediaQuery.of(context);
        final scaled = media.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.3,
        );
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: media.copyWith(textScaler: scaled),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: _AppHome(
        storeFuture: _storeFuture!,
        showRegistration: _showRegistration,
        onSplashFinished: _finishSplash,
        onRetry: _retryStore,
        biometricService: widget.biometricService,
      ),
    );
  }
}

/// Home flow: splash plays immediately while the local store opens in the
/// background, so the user never stares at a blank white screen.
class _AppHome extends StatelessWidget {
  const _AppHome({
    required this.storeFuture,
    required this.showRegistration,
    required this.onSplashFinished,
    required this.onRetry,
    this.biometricService,
  });

  final Future<IdRecordStore> storeFuture;
  final bool showRegistration;
  final VoidCallback onSplashFinished;
  final VoidCallback onRetry;
  final BiometricService? biometricService;

  @override
  Widget build(BuildContext context) {
    if (!showRegistration) {
      return SplashPage(onFinished: onSplashFinished);
    }
    return FutureBuilder<IdRecordStore>(
      future: storeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StoreErrorView(onRetry: onRetry);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StoreLoadingView();
        }
        return RegistrationPage(
          store: snapshot.data!,
          biometricService: biometricService,
        );
      },
    );
  }
}

class _StoreLoadingView extends StatelessWidget {
  const _StoreLoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 72),
            const SizedBox(height: 24),
            const SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: 12),
            Text(
              'جارٍ التجهيز…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BrandColors.inkMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreErrorView extends StatelessWidget {
  const _StoreErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 80),
              const SizedBox(height: 24),
              Text(
                'تعذّر فتح قاعدة البيانات',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'حدث خطأ أثناء تجهيز الجهاز. أعد المحاولة أو أعد فتح التطبيق.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: BrandColors.inkMuted,
                    ),
              ),
              const SizedBox(height: 20),
              BrandButton(
                label: 'إعادة المحاولة',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
