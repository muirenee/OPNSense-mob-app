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
  bool _loading = false;
  bool _failedForSession = false;

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
      _failedForSession = false;
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
    _loading = false;
  }

  Future<void> _ensureBanner() async {
    if (!mounted ||
        !widget.visible ||
        !AdConfig.enabled ||
        !widget.adService.canRequestAds ||
        _loading ||
        _failedForSession ||
        _banner != null) {
      return;
    }

    _loading = true;
    try {
      late final BannerAd banner;
      banner = BannerAd(
        adUnitId: AdConfig.bannerAdUnitId,
        request: const AdRequest(),
        size: AdSize.banner,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted || ad != banner) {
              ad.dispose();
              return;
            }
            setState(() {
              _banner = banner;
              _loading = false;
            });
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (!mounted) return;
            setState(() {
              _banner = null;
              _loading = false;
              _failedForSession = true;
            });
          },
        ),
      );
      await banner.load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _banner = null;
        _loading = false;
        _failedForSession = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible ||
        !AdConfig.enabled ||
        !widget.adService.canRequestAds ||
        _failedForSession) {
      return const SizedBox.shrink();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBanner());

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
  }
}
