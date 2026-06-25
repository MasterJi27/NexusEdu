#include <vector>
#include <string>
#include <map>
#include <algorithm>
#include <numeric>
#include <cmath>

struct PerformanceData {
    std::string date;
    double score;
    std::string subject;
    std::string chapter;
    int timeTaken;
};

struct AnalyticsResult {
    double mean;
    double median;
    double stdDev;
    double trend;
    double readiness;
    std::string grade;
};

double calcMean(std::vector<double> data) {
    if (data.empty()) return 0.0;
    return std::accumulate(data.begin(), data.end(), 0.0) / data.size();
}

double calcMedian(std::vector<double> data) {
    if (data.empty()) return 0.0;
    std::sort(data.begin(), data.end());
    size_t n = data.size();
    if (n % 2 == 0) return (data[n/2-1] + data[n/2]) / 2.0;
    return data[n/2];
}

double calcStdDev(std::vector<double> data) {
    if (data.size() < 2) return 0.0;
    double mean = calcMean(data);
    double sum = 0.0;
    for (double v : data) sum += (v - mean) * (v - mean);
    return std::sqrt(sum / (data.size() - 1));
}

double calcTrend(std::vector<double> scores) {
    if (scores.size() < 2) return 0.0;
    int n = scores.size();
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; ++i) {
        sumX += i; sumY += scores[i];
        sumXY += i * scores[i]; sumX2 += i * i;
    }
    double denom = n * sumX2 - sumX * sumX;
    if (std::abs(denom) < 1e-10) return 0.0;
    return (n * sumXY - sumX * sumY) / denom;
}

std::string getGradeFromScore(double score) {
    if (score >= 95) return "A+";
    if (score >= 90) return "A";
    if (score >= 80) return "B+";
    if (score >= 70) return "B";
    if (score >= 60) return "C+";
    if (score >= 50) return "C";
    if (score >= 40) return "D";
    if (score >= 33) return "E";
    return "F";
}

AnalyticsResult analyzePerformance(std::vector<PerformanceData> data) {
    AnalyticsResult result;
    if (data.empty()) {
        result.mean = 0; result.median = 0; result.stdDev = 0;
        result.trend = 0; result.readiness = 0; result.grade = "N/A";
        return result;
    }
    std::vector<double> scores;
    for (auto& d : data) scores.push_back(d.score);

    result.mean = calcMean(scores);
    result.median = calcMedian(scores);
    result.stdDev = calcStdDev(scores);
    result.trend = calcTrend(scores);
    result.readiness = std::max(0.0, std::min(100.0, result.mean + result.trend * 5));
    result.grade = getGradeFromScore(result.mean);
    return result;
}

std::map<std::string, double> subjectWiseAnalysis(std::vector<PerformanceData> data) {
    std::map<std::string, std::vector<double>> subjectScores;
    for (auto& d : data) subjectScores[d.subject].push_back(d.score);
    std::map<std::string, double> results;
    for (auto& pair : subjectScores) {
        results[pair.first + "_mean"] = calcMean(pair.second);
        results[pair.first + "_stdDev"] = calcStdDev(pair.second);
        results[pair.first + "_trend"] = calcTrend(pair.second);
    }
    return results;
}

std::vector<std::pair<std::string, double>> weaknessHeatmap(std::vector<PerformanceData> data) {
    std::map<std::string, std::vector<double>> chapterScores;
    for (auto& d : data) chapterScores[d.chapter].push_back(d.score);
    std::vector<std::pair<std::string, double>> weaknesses;
    for (auto& pair : chapterScores) {
        weaknesses.push_back({pair.first, calcMean(pair.second)});
    }
    std::sort(weaknesses.begin(), weaknesses.end(), [](const auto& a, const auto& b) {
        return a.second < b.second;
    });
    return weaknesses;
}

double predictExamScore(std::vector<PerformanceData> data, int daysUntilExam) {
    if (data.empty()) return 0.0;
    std::vector<double> scores;
    for (auto& d : data) scores.push_back(d.score);
    double trend = calcTrend(scores);
    double lastScore = scores.back();
    double predicted = lastScore + trend * daysUntilExam;
    return std::max(0.0, std::min(predicted, 100.0));
}

std::map<std::string, bool> calculateAchievements(std::vector<PerformanceData> data, int streakDays) {
    std::map<std::string, bool> achievements;
    achievements["first_quiz"] = !data.empty();
    achievements["streak_3"] = streakDays >= 3;
    achievements["streak_7"] = streakDays >= 7;
    achievements["streak_30"] = streakDays >= 30;

    std::vector<double> scores;
    for (auto& d : data) scores.push_back(d.score);
    double mean = calcMean(scores);
    achievements["score_90"] = mean >= 90.0;
    achievements["score_80"] = mean >= 80.0;
    achievements["improving"] = calcTrend(scores) > 0.5;

    std::map<std::string, int> subjectCount;
    for (auto& d : data) subjectCount[d.subject]++;
    achievements["multi_subject"] = subjectCount.size() >= 3;

    achievements["century"] = false;
    for (double s : scores) {
        if (s >= 100.0) { achievements["century"] = true; break; }
    }
    return achievements;
}

std::vector<double> movingAverage(std::vector<double> data, int windowSize) {
    std::vector<double> result;
    if (windowSize <= 0 || data.empty()) return result;
    for (size_t i = 0; i <= data.size() - windowSize; ++i) {
        double sum = 0;
        for (int j = 0; j < windowSize; ++j) sum += data[i + j];
        result.push_back(sum / windowSize);
    }
    return result;
}

double calculateStreak(std::vector<std::string> dates) {
    if (dates.empty()) return 0;
    std::vector<std::string> sorted = dates;
    std::sort(sorted.begin(), sorted.end(), std::greater<std::string>());
    int streak = 1;
    for (size_t i = 1; i < sorted.size(); ++i) {
        int y1, m1, d1, y2, m2, d2;
        sscanf(sorted[i-1].c_str(), "%d-%d-%d", &y1, &m1, &d1);
        sscanf(sorted[i].c_str(), "%d-%d-%d", &y2, &m2, &d2);
        int diff = (y1 - y2) * 365 + (m1 - m2) * 30 + (d1 - d2);
        if (diff == 1) streak++;
        else break;
    }
    return streak;
}

std::map<std::string, double> comparativeAnalysis(std::vector<PerformanceData> userData, std::vector<PerformanceData> classData) {
    std::map<std::string, double> results;
    std::vector<double> userScores, classScores;
    for (auto& d : userData) userScores.push_back(d.score);
    for (auto& d : classData) classScores.push_back(d.score);

    double userMean = calcMean(userScores);
    double classMean = calcMean(classScores);
    results["user_mean"] = userMean;
    results["class_mean"] = classMean;
    results["difference"] = userMean - classMean;
    results["user_rank"] = 0;
    int better = 0;
    for (double s : classScores) {
        if (userMean > s) better++;
    }
    results["percentile"] = classScores.empty() ? 0 : (static_cast<double>(better) / classScores.size()) * 100.0;
    results["user_stdDev"] = calcStdDev(userScores);
    results["class_stdDev"] = calcStdDev(classScores);
    return results;
}
