import 'package:flutter/material.dart';

import '../dhcp/dhcp_screen.dart';
import '../neighbors/neighbor_screen.dart';
import '../profiles/firewall_profile.dart';
import 'network_screen.dart';

class NetworkModuleScreen extends StatelessWidget {
  const NetworkModuleScreen({super.key, required this.profile, required this.credentials});
  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        const Material(child: TabBar(
          tabs: [
            Tab(text: 'Overview', icon: Icon(Icons.hub_outlined)),
            Tab(text: 'Leases', icon: Icon(Icons.devices_outlined)),
            Tab(text: 'Neighbors', icon: Icon(Icons.lan_outlined)),
          ],
        )),
        Expanded(child: TabBarView(children: [
          NetworkScreen(profile: profile, credentials: credentials),
          DhcpScreen(profile: profile, credentials: credentials),
          NeighborScreen(profile: profile, credentials: credentials),
        ])),
      ]),
    );
  }
}
