#include <cmath>
#include <vector>
#include <string>
#include <map>
#include <random>
#include <algorithm>
#include <numeric>

double calculateEbbinghausRetention(double strength, double time) {
    if (time <= 0) return strength;
    if (strength <= 0) return 0.0;
    return strength * std::exp(-time / strength);
}

double calculateEloRating(double currentRating, double opponentRating, bool won, double K) {
    double expected = 1.0 / (1.0 + std::pow(10, (opponentRating - currentRating) / 400.0));
    double actual = won ? 1.0 : 0.0;
    return currentRating + K * (actual - expected);
}

double calculateAccuracy(int correct, int total) {
    if (total <= 0) return 0.0;
    return (static_cast<double>(correct) / total) * 100.0;
}

double calculateStandardDeviation(std::vector<double> data) {
    if (data.size() < 2) return 0.0;
    double mean = calculateMean(data);
    double sumSquaredDiff = 0.0;
    for (double val : data) {
        sumSquaredDiff += (val - mean) * (val - mean);
    }
    return std::sqrt(sumSquaredDiff / (data.size() - 1));
}

double calculateMean(std::vector<double> data) {
    if (data.empty()) return 0.0;
    double sum = std::accumulate(data.begin(), data.end(), 0.0);
    return sum / data.size();
}

double calculateMedian(std::vector<double> data) {
    if (data.empty()) return 0.0;
    std::sort(data.begin(), data.end());
    size_t n = data.size();
    if (n % 2 == 0) {
        return (data[n / 2 - 1] + data[n / 2]) / 2.0;
    }
    return data[n / 2];
}

double calculateTrend(std::vector<double> scores) {
    if (scores.size() < 2) return 0.0;
    int n = scores.size();
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; ++i) {
        sumX += i;
        sumY += scores[i];
        sumXY += i * scores[i];
        sumX2 += i * i;
    }
    double denominator = n * sumX2 - sumX * sumX;
    if (std::abs(denominator) < 1e-10) return 0.0;
    return (n * sumXY - sumX * sumY) / denominator;
}

int calculateGrade(double percentage) {
    if (percentage >= 95) return 0;   // A+
    if (percentage >= 90) return 1;   // A
    if (percentage >= 80) return 2;   // B+
    if (percentage >= 70) return 3;   // B
    if (percentage >= 60) return 4;   // C+
    if (percentage >= 50) return 5;   // C
    if (percentage >= 40) return 6;   // D
    if (percentage >= 33) return 7;   // E
    return 8;                          // F
}

double calculateStudyEfficiency(double hoursStudied, double conceptsLearned, double retentionRate) {
    if (hoursStudied <= 0) return 0.0;
    double conceptsPerHour = conceptsLearned / hoursStudied;
    double efficiency = conceptsPerHour * (retentionRate / 100.0) * 10.0;
    return std::min(efficiency, 100.0);
}

double predictPerformance(std::vector<double> historicalScores, int daysAhead) {
    if (historicalScores.empty()) return 0.0;
    double trend = calculateTrend(historicalScores);
    int n = historicalScores.size();
    double lastScore = historicalScores.back();
    double predicted = lastScore + trend * daysAhead;
    return std::max(0.0, std::min(predicted, 100.0));
}

std::vector<int> generateAdaptiveQuestion(int currentLevel, int correctStreak, int wrongStreak) {
    std::mt19937 rng(std::random_device{}());
    int difficulty = currentLevel;
    if (correctStreak >= 3) {
        difficulty = std::min(currentLevel + 1, 5);
    } else if (wrongStreak >= 2) {
        difficulty = std::max(currentLevel - 1, 1);
    }
    std::uniform_int_distribution<int> topicDist(0, 9);
    int topicIndex = topicDist(rng);
    return {difficulty, topicIndex};
}

double calculateBurnoutRisk(std::vector<double> recentScores, std::vector<double> studyHours) {
    if (recentScores.size() < 3 || studyHours.size() < 3) return 0.0;
    double scoreTrend = calculateTrend(recentScores);
    double hourTrend = calculateTrend(studyHours);
    double avgHours = calculateMean(studyHours);
    double risk = 0.0;
    if (scoreTrend < -1.0) risk += 30.0;
    else if (scoreTrend < -0.5) risk += 15.0;
    if (hourTrend > 0.5 && avgHours > 8.0) risk += 25.0;
    else if (avgHours > 10.0) risk += 20.0;
    double recentAvg = calculateMean(std::vector<double>(recentScores.end() - 3, recentScores.end()));
    double earlyAvg = calculateMean(std::vector<double>(recentScores.begin(), recentScores.begin() + 3));
    if (earlyAvg - recentAvg > 15.0) risk += 20.0;
    return std::min(risk, 100.0);
}

std::map<std::string, double> analyzeSubjectPerformance(std::map<std::string, std::vector<double>> subjectScores) {
    std::map<std::string, double> results;
    for (auto& pair : subjectScores) {
        double mean = calculateMean(pair.second);
        double median = calculateMedian(pair.second);
        double stdDev = calculateStandardDeviation(pair.second);
        double trend = calculateTrend(pair.second);
        results[pair.first + "_mean"] = mean;
        results[pair.first + "_median"] = median;
        results[pair.first + "_stdDev"] = stdDev;
        results[pair.first + "_trend"] = trend;
        results[pair.first + "_consistency"] = 100.0 - stdDev;
    }
    return results;
}

int calculateOptimalStudyTime(std::vector<std::pair<int, double>> timePerformancePairs) {
    if (timePerformancePairs.empty()) return 9;
    int bestHour = timePerformancePairs[0].first;
    double bestPerformance = timePerformancePairs[0].second;
    for (auto& pair : timePerformancePairs) {
        if (pair.second > bestPerformance) {
            bestPerformance = pair.second;
            bestHour = pair.first;
        }
    }
    return bestHour;
}

double calculateConfidenceInterval(std::vector<double> data, double confidenceLevel) {
    if (data.size() < 2) return 0.0;
    double mean = calculateMean(data);
    double stdDev = calculateStandardDeviation(data);
    double n = data.size();
    double zScore = 1.96;
    if (confidenceLevel == 0.90) zScore = 1.645;
    else if (confidenceLevel == 0.99) zScore = 2.576;
    return zScore * (stdDev / std::sqrt(n));
}
