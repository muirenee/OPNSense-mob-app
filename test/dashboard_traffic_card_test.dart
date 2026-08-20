import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/dashboard/dashboard_models.dart';
import 'package:netsource_opn_manager/features/dashboard/dashboard_traffic_card.dart';
import 'package:netsource_opn_manager/features/profiles/firewall_profile.dart';

void main() {
  testWidgets('Demo Mode shows live WAN internet traffic', (tester) async {
    const interfaces = [
      InterfaceSummary(
        identifier: 'wan',
        description: 'WAN',
        status: 'up',
        addresses: ['203.0.113.18/30'],
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardTrafficCard(
              profile: FirewallProfile.demo,
              credentials: FirewallCredentials.demo,
              interfaces: interfaces,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Live Internet Traffic'), findsOneWidget);
    expect(find.text('WAN throughput · last 60 seconds'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Download'), findsWidgets);
    expect(find.text('Upload'), findsWidgets);
    expect(find.textContaining('Mbps'), findsWidgets);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(CustomPaint), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
