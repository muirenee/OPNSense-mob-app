import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'ad_service.dart';

class SentinelBanner extends StatefulWidget {
  const SentinelBanner({
    super.key,
    required this.adService,
    this.visible = true,
  });

  final AdService adService;
  final bool visible;

  @override
  State<SentinelBanner> createState() => _SentinelBannerState();
}

class _SentinelBannerState extends State<SentinelBanner> {
  BannerAd? _banner;
  int? _loadedWidth;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.adService.addListener(_onAdStateChanged);
  }

  @override
  void didUpdateWidget(covariant SentinelBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adService != widget.adService) {
      oldWidget.adService.removeListener(_onAdStateChanged);
      widget.adService.addListener(_onAdStateChanged);
      _disposeBanner();
    }
    if (!widget.visible && oldWidget.visible) _disposeBanner();
  }

  @override
  void dispose() {
    widget.adService.removeListener(_onAdStateChanged);
    _banner?.dispose();
    super.dispose();
  }

  void _onAdStateChanged() {
    if (!mounted) return;
    if (!widget.adService.canRequestAds) _disposeBanner();
    setState(() {});
  }

  void _disposeBanner() {
    _banner?.dispose();
    _banner = null;
    _loadedWidth = null;
    _loading = false;
  }

  Future<void> _ensureBanner(int width) async {
    if (!mounted ||
        !widget.visible ||
        !AdConfig.enabled ||
        !widget.adService.canRequestAds ||
        width <= 0 ||
        _loading ||
        (_banner != null && _loadedWidth == width)) {
      return;
    }

    _loading = true;
    final size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted) return;
    if (size == null) {
      _loading = false;
      return;
    }

    _banner?.dispose();
    late final BannerAd banner;
    banner = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || ad != banner) return;
          setState(() {
            _banner = banner;
            _loadedWidth = width;
            _loading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _banner = null;
            _loadedWidth = null;
            _loading = false;
          });
        },
      ),
    );
    await banner.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible ||
        !AdConfig.enabled ||
        !widget.adService.canRequestAds) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final width = available.floor();
        WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBanner(width));

        final banner = _banner;
        if (banner == null) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: SizedBox(
                width: banner.size.width.toDouble(),
                height: banner.size.height.toDouble(),
                child: AdWidget(ad: banner),
              ),
            ),
          ),
        );
      },
    );
  }
}
