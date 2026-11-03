import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/ads_config.dart';
import '../core/theme.dart';
import '../services/premium_service.dart';
import 'widgets.dart';

bool _adsStarted = false;
Future<void> _startAds() async {
  if (_adsStarted) return;
  _adsStarted = true;
  await MobileAds.instance.initialize();
}

/// Tarjeta "PUBLICIDAD". Con Premium no se carga nada (ni se inicia el SDK).
class AdCard extends ConsumerStatefulWidget {
  const AdCard({super.key});
  @override
  ConsumerState<AdCard> createState() => _AdCardState();
}

class _AdCardState extends ConsumerState<AdCard>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Espera a que se lea el estado de Premium antes de pedir anuncios.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || ref.read(premiumProvider).isPremium) return;
    await _startAds();
    if (!mounted || ref.read(premiumProvider).isPremium) return;
    final ad = BannerAd(
      adUnitId: AdsConfig.bannerId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final premium = ref.watch(premiumProvider).isPremium;
    final ad = _ad;
    if (premium || !_loaded || ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PUBLICIDAD',
                style: TextStyle(
                    fontSize: 15, letterSpacing: 1.4, color: context.muted)),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(width: 300, height: 250, child: AdWidget(ad: ad)),
            ),
          ],
        ),
      ),
    );
  }
}
