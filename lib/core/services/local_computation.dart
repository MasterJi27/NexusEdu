import 'dart:math';

class LocalComputation {
  /// Forgetting curve: R = e^(-t/S)
  /// memoryStrength (S) in days, timeElapsed (t) in days
  /// Returns retention probability 0.0 to 1.0
  static double forgettingCurve(double memoryStrength, double timeElapsed) {
    if (memoryStrength <= 0) return 0.0;
    return exp(-timeElapsed / memoryStrength);
  }

  /// Elo rating system
  /// current: player's current rating
  /// opponent: opponent's rating
  /// won: whether the player won
  /// K-factor defaults to 32
  static double eloRating(
    double current,
    double opponent, {
    bool won = false,
    double kFactor = 32,
  }) {
    final expectedScore = 1.0 / (1.0 + pow(10, (opponent - current) / 400));
    final actualScore = won ? 1.0 : 0.0;
    return current + kFactor * (actualScore - expectedScore);
  }

  static double mean(List<double> data) {
    if (data.isEmpty) return 0.0;
    return data.reduce((a, b) => a + b) / data.length;
  }

  static double median(List<double> data) {
    if (data.isEmpty) return 0.0;
    final sorted = List<double>.from(data)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static double standardDeviation(List<double> data) {
    if (data.length < 2) return 0.0;
    final avg = mean(data);
    final sumSquaredDiff = data.fold<double>(
      0.0,
      (sum, val) => sum + pow(val - avg, 2),
    );
    return sqrt(sumSquaredDiff / (data.length - 1));
  }

  /// Linear regression slope (trend)
  /// Returns the slope indicating upward/downward trend
  static double trend(List<double> data) {
    if (data.length < 2) return 0.0;
    final n = data.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += data[i];
      sumXY += i * data[i];
      sumX2 += i * i;
    }
    final denominator = n * sumX2 - sumX * sumX;
    if (denominator == 0) return 0.0;
    return (n * sumXY - sumX * sumY) / denominator;
  }

  static String grade(double percentage) {
    if (percentage >= 95) return 'A+';
    if (percentage >= 90) return 'A';
    if (percentage >= 80) return 'B+';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    if (percentage >= 33) return 'E';
    return 'F';
  }

  /// Study efficiency = (concepts * retention) / hours
  /// Higher is better
  static double studyEfficiency(
    double hours,
    int concepts,
    double retention,
  ) {
    if (hours <= 0) return 0.0;
    return (concepts * retention) / hours;
  }

  /// Simple linear projection based on recent scores
  static double predictPerformance(List<double> scores, int daysAhead) {
    if (scores.isEmpty) return 0.0;
    if (scores.length == 1) return scores.first;
    final slope = trend(scores);
    final projected = scores.last + slope * daysAhead;
    return projected.clamp(0, 100);
  }

  /// Burnout risk based on declining scores and increasing hours
  /// Returns risk 0.0 to 1.0
  static double burnoutRisk(List<double> scores, List<double> hours) {
    if (scores.length < 2 || hours.length < 2) return 0.0;
    final scoreTrend = trend(scores);
    final hourTrend = trend(hours);
    double risk = 0.0;
    if (scoreTrend < -0.5) risk += 0.4;
    if (scoreTrend < -1.0) risk += 0.2;
    if (hourTrend > 0.5) risk += 0.2;
    if (hourTrend > 1.0) risk += 0.2;
    return risk.clamp(0.0, 1.0);
  }

  /// Adaptive difficulty based on accuracy and streak
  /// Returns new difficulty level 1-5
  static int adaptiveDifficulty(
    int current,
    bool correct,
    int streak,
  ) {
    if (correct) {
      if (streak >= 3 && current < 5) return current + 1;
      if (streak >= 5 && current < 5) return min(current + 2, 5);
      return current;
    } else {
      if (streak == 0 && current > 1) return current - 1;
      return max(current - 1, 1);
    }
  }

  /// Days left until exam date
  static int daysLeft(String examDate) {
    try {
      final exam = DateTime.parse(examDate);
      final now = DateTime.now();
      return exam.difference(now).inDays;
    } catch (_) {
      return 0;
    }
  }

  /// Optimized study schedule based on subject weights and mastery
  /// weights: {subject: priority_weight}
  /// mastery: {subject: mastery_0_to_1}
  /// Returns {subject: hours_to_study}
  static Map<String, double> optimizeSchedule(
    Map<String, double> weights,
    Map<String, double> mastery,
    int days,
    double hoursPerDay,
  ) {
    final result = <String, double>{};
    if (weights.isEmpty || days <= 0 || hoursPerDay <= 0) return result;

    double totalWeight = 0;
    final adjustedWeights = <String, double>{};

    for (final entry in weights.entries) {
      final masteryVal = mastery[entry.key] ?? 0.5;
      final need = entry.value * (1.0 - masteryVal);
      adjustedWeights[entry.key] = need;
      totalWeight += need;
    }

    if (totalWeight == 0) return result;

    final totalHours = days * hoursPerDay;
    for (final entry in adjustedWeights.entries) {
      result[entry.key] = (entry.value / totalWeight) * totalHours;
    }

    return result;
  }

  static double calculatePercentile(
    double userScore,
    List<double> classScores,
  ) {
    if (classScores.isEmpty) return 0.0;
    int below = 0;
    for (final score in classScores) {
      if (score < userScore) below++;
    }
    return (below / classScores.length) * 100;
  }

  /// Calculate CGPA from list of percentages (10-point scale)
  static double calculateCGPA(List<double> percentages) {
    if (percentages.isEmpty) return 0.0;
    final cgpaSum = percentages.fold<double>(
      0.0,
      (sum, p) => sum + (p / 9.5),
    );
    return (cgpaSum / percentages.length).clamp(0.0, 10.0);
  }
}
