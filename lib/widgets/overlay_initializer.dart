import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/call_overlay_service.dart';

/// Wrapper widget to initialize overlay service for any screen
class OverlayInitializer extends StatefulWidget {
  final Widget child;

  const OverlayInitializer({super.key, required this.child});

  @override
  State<OverlayInitializer> createState() => _OverlayInitializerState();
}

class _OverlayInitializerState extends State<OverlayInitializer> {
  @override
  void initState() {
    super.initState();
    // Initialize overlay service with overlay state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final overlayService = Provider.of<CallOverlayService>(
          context,
          listen: false,
        );
        overlayService.initialize(Overlay.of(context));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
