import 'package:flutter/material.dart';
import '../models/lead_model.dart';
import '../widgets/floating_call_button.dart';
import '../widgets/call_details_popup.dart';

class CallOverlayService extends ChangeNotifier {
  OverlayEntry? _floatingButtonEntry;
  OverlayEntry? _popupEntry;
  Lead? _currentLead;
  OverlayState? _overlayState;
  BuildContext? _context;
  bool _isPopupVisible = false;

  bool get isFloatingButtonVisible => _floatingButtonEntry != null;
  bool get isPopupVisible => _isPopupVisible;
  BuildContext? get context => _context;

  void initialize(OverlayState overlayState, {BuildContext? context}) {
    _overlayState = overlayState;
    _context = context;
  }

  void showFloatingIcon(Lead lead) {
    if (_overlayState == null) {
      return;
    }

    // If already showing for a different lead, update it
    if (_floatingButtonEntry != null && _currentLead?.id != lead.id) {
      hideFloatingIcon();
    }

    _currentLead = lead;

    // Only create if not already visible
    if (_floatingButtonEntry == null) {
      _floatingButtonEntry = OverlayEntry(
        builder: (context) => FloatingCallButton(
          onTap: () {
            _showPopup();
          },
        ),
      );

      _overlayState!.insert(_floatingButtonEntry!);
      notifyListeners();
    }
  }

  void hideFloatingIcon() {
    _floatingButtonEntry?.remove();
    _floatingButtonEntry = null;
    _hidePopup();
    _currentLead = null;
    notifyListeners();
  }

  void updateLeadData(Lead lead) {
    _currentLead = lead;
    // Always show the popup when lead data is updated
    // This ensures clicking SBS icon triggers the full details view
    if (_isPopupVisible) {
      // Refresh popup with new data
      _hidePopup();
    }
    // Show popup with (potentially updated) data
    _showPopup();
    notifyListeners();
  }

  void _showPopup() {
    if (_currentLead == null || _overlayState == null) return;

    // Hide if already visible
    if (_popupEntry != null) {
      _hidePopup();
      return;
    }

    _popupEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: () => _hidePopup(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: GestureDetector(
            onTap: () {}, // Prevent dismissal when tapping popup content
            child: Align(
              alignment: Alignment.bottomCenter,
              child: CallDetailsPopup(lead: _currentLead!, onClose: _hidePopup),
            ),
          ),
        ),
      ),
    );

    _overlayState!.insert(_popupEntry!);
    _isPopupVisible = true;
    notifyListeners();
  }

  void _hidePopup() {
    _popupEntry?.remove();
    _popupEntry = null;
    _isPopupVisible = false;
    notifyListeners();
  }

  /// Test method to show in-app floating icon and popup
  void testInAppOverlay(Lead lead) {
    showFloatingIcon(lead);
    // Automatically show popup after a brief delay
    Future.delayed(const Duration(milliseconds: 300), () {
      updateLeadData(lead);
    });
  }

  @override
  void dispose() {
    hideFloatingIcon();
    super.dispose();
  }
}
