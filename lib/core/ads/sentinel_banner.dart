import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ad_config.dart';
import 'ad_service.dart';

class SentinelBanner extends StatelessWidget {
  const SentinelBanner({
    super.key,
    required this.adService,
    this.visible = true,
  });

  static const String _viewType = 'com.netsource.sentinel/banner';

  final AdService adService;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible ||
        !AdConfig.enabled ||
        !adService.canRequestAds ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: SizedBox(
              height: 50,
              width: double.infinity,
              child: Center(
                child: SizedBox(
                  width: 320,
                  height: 50,
                  child: AndroidView(
                    viewType: _viewType,
                    creationParams: <String, Object?>{
                      'adUnitId': AdConfig.bannerAdUnitId,
                    },
                    creationParamsCodec: const StandardMessageCodec(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
