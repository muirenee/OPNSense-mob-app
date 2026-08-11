import 'package:flutter/material.dart';

import '../profiles/firewall_profile.dart';
import 'aliases/alias_screen.dart';
import 'firewall_log_screen.dart';
import 'firewall_screen.dart';
import 'nat/nat_screen.dart';
import 'states/firewall_state_screen.dart';

class FirewallModuleScreen extends StatelessWidget {
  const FirewallModuleScreen({super.key, required this.profile, required this.credentials});

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(children: [
        const Material(
          child: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Rules', icon: Icon(Icons.rule_outlined)),
              Tab(text: 'NAT', icon: Icon(Icons.swap_horiz_outlined)),
              Tab(text: 'Aliases', icon: Icon(Icons.label_outline)),
              Tab(text: 'States', icon: Icon(Icons.compare_arrows)),
              Tab(text: 'Live Log', icon: Icon(Icons.receipt_long_outlined)),
            ],
          ),
        ),
        Expanded(child: TabBarView(children: [
          FirewallScreen(profile: profile, credentials: credentials),
          NatScreen(profile: profile, credentials: credentials),
          AliasScreen(profile: profile, credentials: credentials),
          FirewallStateScreen(profile: profile, credentials: credentials),
          FirewallLogScreen(profile: profile, credentials: credentials),
        ])),
      ]),
    );
  }
}
