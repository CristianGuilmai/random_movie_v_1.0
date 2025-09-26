import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/api_config.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // IDs de AdMob - Configuración segura
  static String get _bannerAdUnitId => Platform.isAndroid
      ? ApiConfig.admobBannerId
      : 'ca-app-pub-2605832983846978/1797463366'; // ID de prueba iOS

  static String get _interstitialAdUnitId => Platform.isAndroid
      ? ApiConfig.admobInterstitialId
      : 'ca-app-pub-2605832983846978/9333172606'; // ID de prueba iOS

  static String get _rewardedAdUnitId => Platform.isAndroid
      ? ApiConfig.admobRewardedId
      : 'ca-app-pub-3940256099942544/1712485313'; // ID de prueba iOS

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool _isBannerAdReady = false;
  bool _isInterstitialAdReady = false;
  bool _isRewardedAdReady = false;

  // Inicializar AdMob
  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      print('AdMob initialized successfully');
    } catch (e) {
      print('AdMob initialization failed (likely running on emulator): $e');
      // No lanzar excepción, permitir que la app continúe sin anuncios
    }
  }

  // Crear banner ad
  BannerAd? createBannerAd() {
    try {
      _bannerAd = BannerAd(
        adUnitId: _bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _isBannerAdReady = true;
            print('Banner ad loaded');
          },
          onAdFailedToLoad: (ad, error) {
            _isBannerAdReady = false;
            print('Banner ad failed to load: $error');
            ad.dispose();
          },
        ),
      );
      return _bannerAd!;
    } catch (e) {
      print('Banner ad creation failed: $e');
      return null;
    }
  }

  // Cargar interstitial ad
  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          print('Interstitial ad loaded');
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdReady = false;
          print('Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  // Mostrar interstitial ad
  void showInterstitialAd() {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isInterstitialAdReady = false;
          loadInterstitialAd(); // Cargar siguiente ad
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isInterstitialAdReady = false;
          loadInterstitialAd(); // Cargar siguiente ad
        },
      );
      _interstitialAd!.show();
    }
  }

  // Cargar rewarded ad
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          print('Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdReady = false;
          print('Rewarded ad failed to load: $error');
        },
      ),
    );
  }

  // Mostrar rewarded ad
  void showRewardedAd({required Function() onRewarded}) {
    if (_isRewardedAdReady && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isRewardedAdReady = false;
          loadRewardedAd(); // Cargar siguiente ad
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isRewardedAdReady = false;
          loadRewardedAd(); // Cargar siguiente ad
        },
      );
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        onRewarded();
      });
    }
  }

  // Getters
  bool get isBannerAdReady => _isBannerAdReady;
  bool get isInterstitialAdReady => _isInterstitialAdReady;
  bool get isRewardedAdReady => _isRewardedAdReady;

  // Dispose
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
