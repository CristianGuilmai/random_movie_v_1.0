import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isAdSupported = true;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    try {
      _bannerAd = AdService().createBannerAd();
      if (_bannerAd != null) {
        _bannerAd!.load();
      } else {
        setState(() {
          _isAdSupported = false;
        });
      }
    } catch (e) {
      print('Banner ad not supported (likely emulator): $e');
      setState(() {
        _isAdSupported = false;
      });
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si los anuncios no son compatibles (emulador), no mostrar nada
    if (!_isAdSupported) {
      return const SizedBox.shrink();
    }

    return Container(
      width: _bannerAd?.size.width.toDouble() ?? 320,
      height: _bannerAd?.size.height.toDouble() ?? 50,
      child: _bannerAd != null && _isAdLoaded
          ? AdWidget(ad: _bannerAd!)
          : Container(
              color: Colors.grey[300],
              child: const Center(
                child: Text(
                  'Publicidad',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
    );
  }
}
