import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/subscription_model.dart';

class SubscriptionService extends ChangeNotifier {
  UserSubscription _currentSubscription = UserSubscription(
    currentTier: SubscriptionTier.free,
    isActive: true,
  );

  UserSubscription get currentSubscription => _currentSubscription;

  bool get isPremium => _currentSubscription.isPremium;

  SubscriptionTier get currentTier => _currentSubscription.currentTier;

  // Initialize and load saved subscription
  Future<void> initialize() async {
    await _loadSubscription();
  }

  // Load subscription from local storage
  Future<void> _loadSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subscriptionJson = prefs.getString('user_subscription');

      if (subscriptionJson != null) {
        final data = json.decode(subscriptionJson);
        _currentSubscription = UserSubscription.fromJson(data);

        // Check if expired
        if (_currentSubscription.isExpired) {
          await _downgradeToFree();
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading subscription: $e');
    }
  }

  // Save subscription to local storage
  Future<void> _saveSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subscriptionJson = json.encode(_currentSubscription.toJson());
      await prefs.setString('user_subscription', subscriptionJson);
    } catch (e) {
      debugPrint('Error saving subscription: $e');
    }
  }

  // Activate a subscription plan (mock activation for now)
  Future<bool> activatePlan(SubscriptionPlan plan) async {
    try {
      DateTime? expiryDate;

      // Calculate expiry date based on plan
      if (plan.tier == SubscriptionTier.monthly) {
        expiryDate = DateTime.now().add(const Duration(days: 30));
      } else if (plan.tier == SubscriptionTier.yearly) {
        expiryDate = DateTime.now().add(const Duration(days: 365));
      }

      _currentSubscription = UserSubscription(
        currentTier: plan.tier,
        expiryDate: expiryDate,
        isActive: true,
      );

      await _saveSubscription();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error activating plan: $e');
      return false;
    }
  }

  // Cancel subscription
  Future<void> cancelSubscription() async {
    await _downgradeToFree();
  }

  // Downgrade to free tier
  Future<void> _downgradeToFree() async {
    _currentSubscription = UserSubscription(
      currentTier: SubscriptionTier.free,
      isActive: true,
    );

    await _saveSubscription();
    notifyListeners();
  }

  // Check if user has access to a premium feature
  bool hasFeatureAccess(String featureName) {
    // All features available in premium
    if (isPremium) return true;

    // Free tier limitations
    switch (featureName) {
      case 'unlimited_leads':
      case 'advanced_analytics':
      case 'team_collaboration':
      case 'priority_support':
        return false;
      default:
        return true;
    }
  }

  // Get remaining days in subscription
  int get daysRemaining => _currentSubscription.daysRemaining;

  // Get current plan details
  SubscriptionPlan get currentPlan {
    switch (_currentSubscription.currentTier) {
      case SubscriptionTier.monthly:
        return SubscriptionPlan.monthly;
      case SubscriptionTier.yearly:
        return SubscriptionPlan.yearly;
      default:
        return SubscriptionPlan.free;
    }
  }
}
