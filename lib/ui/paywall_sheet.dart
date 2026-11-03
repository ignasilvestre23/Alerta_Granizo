import 'package:flutter/material.dart';
import 'paywall_page.dart';

const kGold = Color(0xFFF2C14E);

/// Abre la pantalla de Premium.
Future<void> showPaywall(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => const PaywallPage(),
  ));
}
