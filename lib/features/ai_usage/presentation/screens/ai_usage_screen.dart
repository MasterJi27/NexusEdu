import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_section_header.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';

/// Shows exactly what the AI is consuming: tokens today/week/month, per
/// feature, remaining daily quota, and recent failures ("kya aa raha hai,
/// kya nahi"). Every figure here comes straight from `AiUsageLog` on the
/// backend — this screen has no invented numbers.
class AiUsageScreen extends StatefulWidget {
  const AiUsageScreen({super.key});

  @override
  State<AiUsageScreen> createState() => _AiUsageScreenState();
}

class _AiUsageScreenState extends State<AiUsageScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await SecureApiService().getAiUsage();
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() {
        _loading = false;
        _error = result['error'].toString();
      });
      return;
    }
    setState(() {
      _loading = false;
      _data = result;
    });
  }

  String _format(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return '$tokens';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI usage and tokens')),
      body: SafeArea(
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(AppSpace.lg),
                child: NexusStateView.loading(rows: 5),
              )
            : _error != null
            ? Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: NexusStateView.error(message: _error!, onRetry: _load),
              )
            : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final today = (_data?['today'] as Map?) ?? const {};
    final week = (_data?['week'] as Map?) ?? const {};
    final month = (_data?['month'] as Map?) ?? const {};
    final quota = (_data?['quota'] as Map?) ?? const {};
    final byFeature = ((_data?['byFeature'] as List?) ?? const []).cast<Map>();
    final errors = ((_data?['recentErrors'] as List?) ?? const []).cast<Map>();

    final limit = (quota['limit'] as num?)?.toInt() ?? 0;
    final usedToday = (quota['usedToday'] as num?)?.toInt() ?? 0;
    final usedPct = limit > 0 ? (usedToday / limit).clamp(0.0, 1.0) : 0.0;

    final t = context.tokens;

    return RefreshIndicator(
      onRefresh: _load,
      color: t.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          _quotaCard(context, usedToday, limit, usedPct, quota),
          const SizedBox(height: AppSpace.md),
          _summaryRow(
            context,
            'Today',
            (today['requests'] as num?)?.toInt() ?? 0,
            (today['totalTokens'] as num?)?.toInt() ?? 0,
            Icons.today_outlined,
          ),
          const SizedBox(height: AppSpace.xs),
          _summaryRow(
            context,
            'This week',
            (week['requests'] as num?)?.toInt() ?? 0,
            (week['totalTokens'] as num?)?.toInt() ?? 0,
            Icons.calendar_view_week_outlined,
          ),
          const SizedBox(height: AppSpace.xs),
          _summaryRow(
            context,
            'This month',
            (month['requests'] as num?)?.toInt() ?? 0,
            (month['totalTokens'] as num?)?.toInt() ?? 0,
            Icons.calendar_month_outlined,
          ),
          NexusSectionHeader(title: 'Breakdown by feature'),
          if (byFeature.isEmpty)
            Text('No AI usage recorded yet this month.', style: context.text.bodySmall)
          else
            ...byFeature.map((f) => _featureRow(context, f)),
          NexusSectionHeader(title: 'Recent failures'),
          if (errors.isEmpty)
            Text('No failures — everything is working.', style: context.text.bodySmall)
          else
            ...errors.map((e) => _errorRow(context, e)),
        ],
      ),
    );
  }

  Widget _quotaCard(BuildContext context, int used, int limit, double pct, Map quota) {
    final t = context.tokens;
    final usedRequests = (quota['usedRequestsToday'] as num?)?.toInt() ?? 0;
    final remaining = limit - used;
    final isExhausted = remaining <= 0;

    return NexusCard(
      background: t.primaryTint,
      borderColor: t.primaryTintBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily AI budget', style: context.text.labelMedium),
          const SizedBox(height: AppSpace.xs),
          Text(
            isExhausted
                ? 'Limit reached for today'
                : '${_format(used)} of ${_format(limit)} tokens used',
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: AppSpace.sm),
          ClipRRect(
            borderRadius: AppRadius.brSm,
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: t.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(
                isExhausted ? t.statusAbsent : t.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            isExhausted
                ? 'Come back tomorrow — your quota resets daily.'
                : '${_format(remaining)} tokens remaining, $usedRequests requests today',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, int requests, int tokens, IconData icon) {
    final t = context.tokens;
    return NexusCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
      child: Row(
        children: [
          Icon(icon, color: t.primary, size: 20),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(label, style: context.text.bodyMedium)),
          Text(
            '$requests requests, ${_format(tokens)} tokens',
            style: context.typeExtras.bodyStrong,
          ),
        ],
      ),
    );
  }

  Widget _featureRow(BuildContext context, Map f) {
    final name = (f['feature'] as String?) ?? '?';
    final requests = (f['requests'] as num?)?.toInt() ?? 0;
    final totalTokens = (f['totalTokens'] as num?)?.toInt() ?? 0;
    final prompt = (f['promptTokens'] as num?)?.toInt() ?? 0;
    final completion = (f['completionTokens'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: NexusCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: context.typeExtras.bodyStrong)),
                Text(
                  '${_format(totalTokens)} tokens, $requests calls',
                  style: context.text.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              'Input ${_format(prompt)} · output ${_format(completion)}',
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorRow(BuildContext context, Map e) {
    final t = context.tokens;
    final feature = (e['feature'] as String?) ?? '?';
    final error = (e['error'] as String?) ?? 'Unknown error';
    final at = e['at'];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: NexusCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
        background: t.statusAbsent.withValues(alpha: 0.06),
        borderColor: t.statusAbsent.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: t.statusAbsent, size: 16),
                const SizedBox(width: AppSpace.xs),
                Text(
                  feature,
                  style: context.text.labelMedium?.copyWith(color: t.statusAbsent),
                ),
                const Spacer(),
                if (at != null)
                  Text(at.toString().split('.').first, style: context.text.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              error,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
