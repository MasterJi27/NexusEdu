import 'package:flutter/material.dart';
import 'package:nexus_edu/core/data/monetization_catalog.dart';

class NexusProPaywallScreen extends StatelessWidget {
  const NexusProPaywallScreen({super.key});

  static const Color _bg = Color(0xFF0F1115);
  static const Color _accent = Color(0xFF7C5CFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Nexus Pro'),
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const Text(
            'Upgrade only when you need more depth.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Core studying stays free. Pro is for heavy AI tutor use, exam reports, and distraction-free revision.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 20),
          for (final plan in MonetizationCatalog.plans) _PlanCard(plan: plan),
          const SizedBox(height: 20),
          const Text(
            'What goes where',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          for (final tier in AccessTier.values)
            _TierSection(
              tier: tier,
              features: MonetizationCatalog.features
                  .where((feature) => feature.tier == tier)
                  .toList(),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Billing will connect after Play Console product setup.',
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Continue with Pro Student',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final PricingPlan plan;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7C5CFF);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171A21),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: plan.recommended ? accent : const Color(0xFF2A2F3A),
          width: plan.recommended ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (plan.recommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Best value',
                    style: TextStyle(color: accent, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  plan.subtitle,
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final feature in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  const Icon(Icons.check, color: Color(0xFF55D6A4), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TierSection extends StatelessWidget {
  const _TierSection({required this.tier, required this.features});

  final AccessTier tier;
  final List<MonetizationFeature> features;

  @override
  Widget build(BuildContext context) {
    final title = switch (tier) {
      AccessTier.free => 'Free',
      AccessTier.pro => 'Paid Pro',
      AccessTier.sponsored => 'Sponsored',
    };
    final color = switch (tier) {
      AccessTier.free => const Color(0xFF55D6A4),
      AccessTier.pro => const Color(0xFF7C5CFF),
      AccessTier.sponsored => const Color(0xFFFFC857),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171A21),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2F3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          for (final feature in features)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(feature.icon, color: color),
              title: Text(
                feature.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                feature.description,
                style: const TextStyle(color: Colors.white60),
              ),
            ),
        ],
      ),
    );
  }
}
