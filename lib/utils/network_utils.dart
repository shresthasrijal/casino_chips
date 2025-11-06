// utils/network_utils.dart
import 'dart:io';

import 'package:flutter/material.dart';

Future<String> getLocalIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );

    for (var interface in interfaces) {
      // Prefer WiFi (wlan), skip mobile (rmnet)
      if (interface.name.contains('wlan') || interface.name.contains('wifi')) {
        for (var addr in interface.addresses) {
          if (!addr.address.startsWith('169.254')) {
            return addr.address;
          }
        }
      }
    }

    // Fallback: any non-link-local
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (!addr.address.startsWith('169.254')) {
          return addr.address;
        }
      }
    }
  } catch (e) {
    debugPrint('IP Error: $e');
  }
  return 'Unknown';
}
