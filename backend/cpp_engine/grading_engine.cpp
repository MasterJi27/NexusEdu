#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <numeric>
#include <cmath>

std::string calculateGrade(double percentage) {
    if (percentage >= 95) return "A+";
    if (percentage >= 90) return "A";
    if (percentage >= 80) return "B+";
    if (percentage >= 70) return "B";
    if (percentage >= 60) return "C+";
    if (percentage >= 50) return "C";
    if (percentage >= 40) return "D";
    if (percentage >= 33) return "E";
    return "F";
}

std::string calculateLetterGrade(double percentage) {
    if (percentage >= 93) return "A";
    if (percentage >= 90) return "A-";
    if (percentage >= 87) return "B+";
    if (percentage >= 83) return "B";
    if (percentage >= 80) return "B-";
    if (percentage >= 77) return "C+";
    if (percentage >= 73) return "C";
    if (percentage >= 70) return "C-";
    if (percentage >= 67) return "D+";
    if (percentage >= 63) return "D";
    if (percentage >= 60) return "D-";
    return "F";
}

double calculateCGPA(std::vector<double> subjectPercentages) {
    if (subjectPercentages.empty()) return 0.0;
    double totalPoints = 0;
    for (double pct : subjectPercentages) {
        double gp;
        if (pct >= 90) gp = 10.0;
        else if (pct >= 80) gp = 9.0;
        else if (pct >= 70) gp = 8.0;
        else if (pct >= 60) gp = 7.0;
        else if (pct >= 50) gp = 6.0;
        else if (pct >= 40) gp = 5.0;
        else if (pct >= 33) gp = 4.0;
        else gp = 0.0;
        totalPoints += gp;
    }
    return totalPoints / subjectPercentages.size();
}

std::map<std::string, std::string> generateReportCard(std::map<std::string, double> subjectScores) {
    std::map<std::string, std::string> report;
    double totalPct = 0;
    for (auto& pair : subjectScores) {
        report[pair.first] = calculateGrade(pair.second);
        totalPct += pair.second;
    }
    double avgPct = totalPct / subjectScores.size();
    report["overall_grade"] = calculateGrade(avgPct);
    report["cgpa"] = std::to_string(calculateCGPA({})).substr(0, 4);
    report["percentage"] = std::to_string(avgPct).substr(0, 5);

    std::vector<double> pcts;
    for (auto& pair : subjectScores) pcts.push_back(pair.second);
    report["cgpa"] = std::to_string(calculateCGPA(pcts)).substr(0, 4);

    if (avgPct >= 90) report["remark"] = "Excellent! Keep up the outstanding work!";
    else if (avgPct >= 75) report["remark"] = "Very good performance. Aim higher!";
    else if (avgPct >= 60) report["remark"] = "Good effort. There is room for improvement.";
    else if (avgPct >= 40) report["remark"] = "Satisfactory. Focus on weak areas.";
    else report["remark"] = "Needs improvement. Seek help and study regularly.";

    return report;
}

std::string getPerformanceComment(double percentage) {
    if (percentage >= 95) return "Outstanding! You are among the top performers. Keep shining!";
    if (percentage >= 90) return "Excellent work! Your dedication is showing great results.";
    if (percentage >= 80) return "Very good! You're doing well. Keep pushing for excellence.";
    if (percentage >= 70) return "Good performance. With more effort, you can reach the top grades.";
    if (percentage >= 60) return "Satisfactory. Focus on understanding concepts better.";
    if (percentage >= 50) return "Average. Regular practice will help improve your scores.";
    if (percentage >= 40) return "Below average. Don't give up! Seek help and study consistently.";
    if (percentage >= 33) return "Just passing. You need to put in significantly more effort.";
    return "Failing. Don't lose hope. With proper guidance and hard work, you can improve.";
}

std::string getRankBadge(int rank) {
    if (rank <= 1) return "Top 1% - Gold Star";
    if (rank <= 5) return "Top 5% - Silver Star";
    if (rank <= 10) return "Top 10% - Bronze Star";
    if (rank <= 25) return "Top 25% - Rising Star";
    if (rank <= 50) return "Top 50% - Consistent Performer";
    return "Keep Trying - Future Star";
}

double calculateWeightedScore(std::vector<double> scores, std::vector<double> weights) {
    if (scores.size() != weights.size() || scores.empty()) return 0.0;
    double weightedSum = 0, totalWeight = 0;
    for (size_t i = 0; i < scores.size(); ++i) {
        weightedSum += scores[i] * weights[i];
        totalWeight += weights[i];
    }
    if (totalWeight == 0) return 0.0;
    return weightedSum / totalWeight;
}

std::map<std::string, double> calculatePercentileRank(std::vector<double> classScores, double userScore) {
    std::map<std::string, double> result;
    int below = 0;
    for (double s : classScores) {
        if (s < userScore) below++;
    }
    double percentile = classScores.empty() ? 0 : (static_cast<double>(below) / classScores.size()) * 100.0;
    result["percentile"] = percentile;
    result["rank_out_of"] = classScores.size();
    result["position"] = classScores.size() - below;
    return result;
}
