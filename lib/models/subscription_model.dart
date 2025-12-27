enum SubscriptionTier { free, monthly, yearly }

class SubscriptionPlan {
  final SubscriptionTier tier;
  final String name;
  final double price;
  final String duration;
  final List<String> features;
  final bool isMostPopular;
  final String? discount;

  SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.price,
    required this.duration,
    required this.features,
    this.isMostPopular = false,
    this.discount,
  });

  // Predefined plans
  static SubscriptionPlan get free => SubscriptionPlan(
    tier: SubscriptionTier.free,
    name: 'Free',
    price: 0,
    duration: 'Forever',
    features: [
      'Up to 10 leads',
      'Basic task management',
      'Call logging',
      'Basic dashboard',
      'Single user',
    ],
  );

  static SubscriptionPlan get monthly => SubscriptionPlan(
    tier: SubscriptionTier.monthly,
    name: 'Monthly Pro',
    price: 99,
    duration: 'per month',
    features: [
      'Unlimited leads',
      'Advanced task management',
      'Call logging & auto-messages',
      'Advanced analytics',
      'Team collaboration',
      'Quotations & Invoices',
      'Priority support',
      'Custom labels & categories',
    ],
  );

  static SubscriptionPlan get yearly => SubscriptionPlan(
    tier: SubscriptionTier.yearly,
    name: 'Yearly Pro',
    price: 999,
    duration: 'per year',
    features: [
      'Everything in Monthly Pro',
      'Save ₹189 (17% off)',
      'Unlimited leads',
      'Advanced analytics',
      'Team collaboration',
      'Quotations & Invoices',
      'Priority support',
      'Early access to new features',
      'Dedicated account manager',
    ],
    isMostPopular: true,
    discount: 'Save ₹189',
  );

  static List<SubscriptionPlan> get allPlans => [free, monthly, yearly];

  static List<SubscriptionPlan> get paidPlans => [monthly, yearly];
}

class UserSubscription {
  final SubscriptionTier currentTier;
  final DateTime? expiryDate;
  final bool isActive;

  UserSubscription({
    required this.currentTier,
    this.expiryDate,
    required this.isActive,
  });

  bool get isPremium => currentTier != SubscriptionTier.free && isActive;

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  int get daysRemaining {
    if (expiryDate == null) return 0;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  UserSubscription copyWith({
    SubscriptionTier? currentTier,
    DateTime? expiryDate,
    bool? isActive,
  }) {
    return UserSubscription(
      currentTier: currentTier ?? this.currentTier,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentTier': currentTier.name,
      'expiryDate': expiryDate?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      currentTier: SubscriptionTier.values.firstWhere(
        (e) => e.name == json['currentTier'],
        orElse: () => SubscriptionTier.free,
      ),
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'])
          : null,
      isActive: json['isActive'] ?? false,
    );
  }
}
