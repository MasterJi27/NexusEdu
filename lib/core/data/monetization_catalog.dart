import 'package:flutter/material.dart';

enum AccessTier { free, pro, sponsored }

class MonetizationFeature {
  const MonetizationFeature({
    required this.title,
    required this.description,
    required this.icon,
    required this.tier,
  });

  final String title;
  final String description;
  final IconData icon;
  final AccessTier tier;
}

class PricingPlan {
  const PricingPlan({
    required this.name,
    required this.price,
    required this.subtitle,
    required this.features,
    required this.recommended,
  });

  final String name;
  final String price;
  final String subtitle;
  final List<String> features;
  final bool recommended;
}

class MonetizationCatalog {
  static const List<MonetizationFeature> features = [
    MonetizationFeature(
      title: 'Syllabus, notes, scanner',
      description: 'Daily learning essentials stay free for every student.',
      icon: Icons.school_outlined,
      tier: AccessTier.free,
    ),
    MonetizationFeature(
      title: 'Limited AI tutor',
      description: 'Free doubts with fair usage limits and topic guidance.',
      icon: Icons.smart_toy_outlined,
      tier: AccessTier.free,
    ),
    MonetizationFeature(
      title: 'Unlimited AI tutor',
      description: 'Longer conversations, voice explanations, and exam drills.',
      icon: Icons.record_voice_over_outlined,
      tier: AccessTier.pro,
    ),
    MonetizationFeature(
      title: 'Advanced revision engine',
      description:
          'Weak-topic detection, spaced revision, and progress reports.',
      icon: Icons.insights_outlined,
      tier: AccessTier.pro,
    ),
    MonetizationFeature(
      title: 'School-sponsored access',
      description:
          'Bulk unlocks for classrooms, CSR pilots, and partner schools.',
      icon: Icons.apartment_outlined,
      tier: AccessTier.sponsored,
    ),
    MonetizationFeature(
      title: 'Scholarship seats',
      description: 'Sponsored Pro access for high-need students.',
      icon: Icons.volunteer_activism_outlined,
      tier: AccessTier.sponsored,
    ),
  ];

  static const List<PricingPlan> plans = [
    PricingPlan(
      name: 'Free',
      price: '₹0',
      subtitle: 'Start learning today',
      recommended: false,
      features: [
        'Syllabus feed',
        'Book scanner',
        'Smart notes',
        'Limited AI tutor',
      ],
    ),
    PricingPlan(
      name: 'Pro Student',
      price: '₹99/mo',
      subtitle: 'Intro launch price',
      recommended: true,
      features: [
        'Unlimited AI tutor',
        'Voice explanations',
        'Exam readiness reports',
        'No ads or distractions',
      ],
    ),
    PricingPlan(
      name: 'School / Sponsor',
      price: 'Custom',
      subtitle: 'For classes and CSR',
      recommended: false,
      features: [
        'Bulk student seats',
        'Teacher dashboard',
        'Parent reports',
        'Sponsored scholarship access',
      ],
    ),
  ];
}
