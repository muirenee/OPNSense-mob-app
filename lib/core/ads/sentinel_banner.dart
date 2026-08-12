import 'package:flutter/material.dart';

import 'ad_service.dart';

/// Placeholder that keeps the Free/ad-supported layout contract stable while
/// the native ads SDK is completely excluded from the v1.1.2 recovery binary.
class SentinelBanner extends StatelessWidget {
  const SentinelBanner({
    super.key,
    required this.adService,
    this.visible = true,
  });

  final AdService adService;
  final bool visible;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
