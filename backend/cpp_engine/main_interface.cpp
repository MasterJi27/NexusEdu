#include <cstring>
#include <cstdlib>
#include <string>
#include <vector>
#include <map>
#include <cmath>

extern "C" {
    double calculate_ebbinghaus_retention(double strength, double time);
    double calculate_elo_rating(double current_rating, double opponent_rating, int won, double K);
    double calculate_accuracy(int correct, int total);
    double calculate_mean(double* data, int length);
    double calculate_median(double* data, int length);
    double calculate_standard_deviation(double* data, int length);
    double calculate_trend(double* data, int length);
    int calculate_grade(double percentage);
    double calculate_study_efficiency(double hours_studied, double concepts_learned, double retention_rate);
    double predict_performance(double* historical_scores, int length, int days_ahead);
    int* generate_adaptive_question(int current_level, int correct_streak, int wrong_streak);
    double calculate_burnout_risk(double* recent_scores, int scores_len, double* study_hours, int hours_len);
    int calculate_optimal_study_time(double* performance_data, int length);
    double calculate_confidence_interval(double* data, int length, double confidence_level);
    int score_quiz(int* answers, int* correct_answers, int length);
    double calculate_negative_marking(int correct, int wrong, int total, double neg_mark);
    int get_next_difficulty(int current_level, int correct, int streak);
    char* calculate_grade_string(double percentage);
    char* calculate_letter_grade(double percentage);
    double calculate_cgpa(double* subject_percentages, int length);
    char* get_performance_comment(double percentage);
    char* get_rank_badge(int rank);
    double calculate_weighted_score(double* scores, double* weights, int length);
    double calculate_streak(char** dates, int length);
    char* get_board_info(const char* board);
    int calculate_days_left(const char* exam_date);
    double calculate_optimal_pace(const char* exam_date, int chapters_remaining);
    char* translate_to_hindi(const char* english_text);
    void free_string(char* str);
}

static char* stringToChar(const std::string& s) {
    char* result = static_cast<char*>(malloc(s.size() + 1));
    if (result) {
        strcpy(result, s.c_str());
    }
    return result;
}

static std::string doubleToString(double val) {
    char buffer[64];
    snprintf(buffer, sizeof(buffer), "%.2f", val);
    return std::string(buffer);
}

double calculate_ebbinghaus_retention(double strength, double time) {
    if (time <= 0) return strength;
    if (strength <= 0) return 0.0;
    return strength * std::exp(-time / strength);
}

double calculate_elo_rating(double current_rating, double opponent_rating, int won, double K) {
    double expected = 1.0 / (1.0 + std::pow(10, (opponent_rating - current_rating) / 400.0));
    double actual = won ? 1.0 : 0.0;
    return current_rating + K * (actual - expected);
}

double calculate_accuracy(int correct, int total) {
    if (total <= 0) return 0.0;
    return (static_cast<double>(correct) / total) * 100.0;
}

double calculate_mean(double* data, int length) {
    if (length <= 0 || !data) return 0.0;
    double sum = 0;
    for (int i = 0; i < length; ++i) sum += data[i];
    return sum / length;
}

double calculate_median(double* data, int length) {
    if (length <= 0 || !data) return 0.0;
    std::vector<double> sorted(data, data + length);
    std::sort(sorted.begin(), sorted.end());
    if (length % 2 == 0) return (sorted[length/2-1] + sorted[length/2]) / 2.0;
    return sorted[length/2];
}

double calculate_standard_deviation(double* data, int length) {
    if (length < 2 || !data) return 0.0;
    double mean = calculate_mean(data, length);
    double sum = 0;
    for (int i = 0; i < length; ++i) sum += (data[i] - mean) * (data[i] - mean);
    return std::sqrt(sum / (length - 1));
}

double calculate_trend(double* data, int length) {
    if (length < 2 || !data) return 0.0;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < length; ++i) {
        sumX += i; sumY += data[i];
        sumXY += i * data[i]; sumX2 += i * i;
    }
    double denom = length * sumX2 - sumX * sumX;
    if (std::abs(denom) < 1e-10) return 0.0;
    return (length * sumXY - sumX * sumY) / denom;
}

int calculate_grade(double percentage) {
    if (percentage >= 95) return 0;
    if (percentage >= 90) return 1;
    if (percentage >= 80) return 2;
    if (percentage >= 70) return 3;
    if (percentage >= 60) return 4;
    if (percentage >= 50) return 5;
    if (percentage >= 40) return 6;
    if (percentage >= 33) return 7;
    return 8;
}

double calculate_study_efficiency(double hours_studied, double concepts_learned, double retention_rate) {
    if (hours_studied <= 0) return 0.0;
    double efficiency = (concepts_learned / hours_studied) * (retention_rate / 100.0) * 10.0;
    return std::min(efficiency, 100.0);
}

double predict_performance(double* historical_scores, int length, int days_ahead) {
    if (length <= 0 || !historical_scores) return 0.0;
    double trend = calculate_trend(historical_scores, length);
    double lastScore = historical_scores[length - 1];
    double predicted = lastScore + trend * days_ahead;
    return std::max(0.0, std::min(predicted, 100.0));
}

int* generate_adaptive_question(int current_level, int correct_streak, int wrong_streak) {
    int* result = static_cast<int*>(malloc(2 * sizeof(int)));
    int difficulty = current_level;
    if (correct_streak >= 3) difficulty = std::min(current_level + 1, 5);
    else if (wrong_streak >= 2) difficulty = std::max(current_level - 1, 1);
    result[0] = difficulty;
    result[1] = rand() % 10;
    return result;
}

double calculate_burnout_risk(double* recent_scores, int scores_len, double* study_hours, int hours_len) {
    if (scores_len < 3 || hours_len < 3 || !recent_scores || !study_hours) return 0.0;
    double scoreTrend = calculate_trend(recent_scores, scores_len);
    double avgHours = calculate_mean(study_hours, hours_len);
    double risk = 0.0;
    if (scoreTrend < -1.0) risk += 30.0;
    else if (scoreTrend < -0.5) risk += 15.0;
    if (avgHours > 10.0) risk += 20.0;
    else if (avgHours > 8.0) risk += 10.0;
    double earlyAvg = calculate_mean(recent_scores, 3);
    double recentAvg = calculate_mean(recent_scores + scores_len - 3, 3);
    if (earlyAvg - recentAvg > 15.0) risk += 20.0;
    return std::min(risk, 100.0);
}

int calculate_optimal_study_time(double* performance_data, int length) {
    if (length <= 0 || !performance_data) return 9;
    int bestHour = 0;
    double bestPerf = performance_data[0];
    for (int i = 1; i < length; ++i) {
        if (performance_data[i] > bestPerf) {
            bestPerf = performance_data[i];
            bestHour = i;
        }
    }
    return bestHour;
}

double calculate_confidence_interval(double* data, int length, double confidence_level) {
    if (length < 2 || !data) return 0.0;
    double stdDev = calculate_standard_deviation(data, length);
    double zScore = 1.96;
    if (confidence_level == 0.90) zScore = 1.645;
    else if (confidence_level == 0.99) zScore = 2.576;
    return zScore * (stdDev / std::sqrt(length));
}

int score_quiz(int* answers, int* correct_answers, int length) {
    int score = 0;
    for (int i = 0; i < length; ++i) {
        if (answers[i] == correct_answers[i]) score += 4;
        else if (answers[i] != 0) score -= 1;
    }
    return score;
}

double calculate_negative_marking(int correct, int wrong, int total, double neg_mark) {
    if (total <= 0) return 0.0;
    return correct * 4.0 - wrong * neg_mark;
}

int get_next_difficulty(int current_level, int correct, int streak) {
    if (correct && streak >= 2) return std::min(current_level + 1, 5);
    if (!correct && streak >= 2) return std::max(current_level - 1, 1);
    return current_level;
}

char* calculate_grade_string(double percentage) {
    std::string grade;
    if (percentage >= 95) grade = "A+";
    else if (percentage >= 90) grade = "A";
    else if (percentage >= 80) grade = "B+";
    else if (percentage >= 70) grade = "B";
    else if (percentage >= 60) grade = "C+";
    else if (percentage >= 50) grade = "C";
    else if (percentage >= 40) grade = "D";
    else if (percentage >= 33) grade = "E";
    else grade = "F";
    return stringToChar(grade);
}

char* calculate_letter_grade(double percentage) {
    std::string grade;
    if (percentage >= 93) grade = "A";
    else if (percentage >= 90) grade = "A-";
    else if (percentage >= 87) grade = "B+";
    else if (percentage >= 83) grade = "B";
    else if (percentage >= 80) grade = "B-";
    else if (percentage >= 77) grade = "C+";
    else if (percentage >= 73) grade = "C";
    else if (percentage >= 70) grade = "C-";
    else if (percentage >= 67) grade = "D+";
    else if (percentage >= 63) grade = "D";
    else if (percentage >= 60) grade = "D-";
    else grade = "F";
    return stringToChar(grade);
}

double calculate_cgpa(double* subject_percentages, int length) {
    if (length <= 0 || !subject_percentages) return 0.0;
    double totalPoints = 0;
    for (int i = 0; i < length; ++i) {
        double pct = subject_percentages[i];
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
    return totalPoints / length;
}

char* get_performance_comment(double percentage) {
    std::string comment;
    if (percentage >= 95) comment = "Outstanding! You are among the top performers.";
    else if (percentage >= 90) comment = "Excellent work! Your dedication shows great results.";
    else if (percentage >= 80) comment = "Very good! Keep pushing for excellence.";
    else if (percentage >= 70) comment = "Good performance. Focus on weak areas to improve.";
    else if (percentage >= 60) comment = "Satisfactory. Regular practice will help improve.";
    else if (percentage >= 50) comment = "Average. Study regularly to improve scores.";
    else if (percentage >= 40) comment = "Below average. Seek help and study consistently.";
    else if (percentage >= 33) comment = "Just passing. Significantly more effort needed.";
    else comment = "Failing. Don't lose hope. Hard work will pay off.";
    return stringToChar(comment);
}

char* get_rank_badge(int rank) {
    std::string badge;
    if (rank <= 1) badge = "Top 1% - Gold Star";
    else if (rank <= 5) badge = "Top 5% - Silver Star";
    else if (rank <= 10) badge = "Top 10% - Bronze Star";
    else if (rank <= 25) badge = "Top 25% - Rising Star";
    else if (rank <= 50) badge = "Top 50% - Consistent Performer";
    else badge = "Keep Trying - Future Star";
    return stringToChar(badge);
}

double calculate_weighted_score(double* scores, double* weights, int length) {
    if (length <= 0 || !scores || !weights) return 0.0;
    double weightedSum = 0, totalWeight = 0;
    for (int i = 0; i < length; ++i) {
        weightedSum += scores[i] * weights[i];
        totalWeight += weights[i];
    }
    if (totalWeight == 0) return 0.0;
    return weightedSum / totalWeight;
}

double calculate_streak(char** dates, int length) {
    if (length <= 0 || !dates) return 0;
    int streak = 1;
    for (int i = 1; i < length; ++i) {
        int y1, m1, d1, y2, m2, d2;
        sscanf(dates[i-1], "%d-%d-%d", &y1, &m1, &d1);
        sscanf(dates[i], "%d-%d-%d", &y2, &m2, &d2);
        int diff = (y1 - y2) * 365 + (m1 - m2) * 30 + (d1 - d2);
        if (diff == 1) streak++;
        else break;
    }
    return streak;
}

char* get_board_info(const char* board) {
    std::string b(board);
    std::string result;
    if (b == "CBSE" || b == "cbse") {
        result = "{\"name\":\"CBSE\",\"totalMarks\":500,\"passMarks\":167,\"subjects\":[\"Mathematics\",\"Science\",\"Social Science\",\"English\",\"Hindi\"]}";
    } else if (b == "ICSE" || b == "icse") {
        result = "{\"name\":\"ICSE\",\"totalMarks\":500,\"passMarks\":167,\"subjects\":[\"Mathematics\",\"Physics\",\"Chemistry\",\"Biology\",\"English\",\"Hindi\"]}";
    } else {
        result = "{\"name\":\"" + b + "\",\"totalMarks\":500,\"passMarks\":167,\"subjects\":[\"Mathematics\",\"Science\",\"English\"]}";
    }
    return stringToChar(result);
}

int calculate_days_left(const char* exam_date) {
    time_t now = time(0);
    tm ltm;
    localtime_s(&ltm, &now);
    int today = (1900 + ltm.tm_year) * 10000 + (1 + ltm.tm_mon) * 100 + ltm.tm_mday;
    int y, m, d;
    sscanf(exam_date, "%d-%d-%d", &y, &m, &d);
    int exam = y * 10000 + m * 100 + d;
    return std::max(0, exam - today);
}

double calculate_optimal_pace(const char* exam_date, int chapters_remaining) {
    int daysLeft = calculate_days_left(exam_date);
    if (daysLeft <= 0) return chapters_remaining;
    return static_cast<double>(chapters_remaining) / daysLeft;
}

char* translate_to_hindi(const char* english_text) {
    std::string text(english_text);
    std::map<std::string, std::string> translations = {
        {"Hello", "नमस्ते"}, {"Good morning", "सुप्रभात"},
        {"Thank you", "धन्यवाद"}, {"Yes", "हाँ"}, {"No", "नहीं"},
        {"Mathematics", "गणित"}, {"Science", "विज्ञान"},
        {"Physics", "भौतिक विज्ञान"}, {"Chemistry", "रसायन विज्ञान"},
        {"Biology", "जीव विज्ञान"}, {"Student", "विद्यार्थी"},
        {"Teacher", "शिक्षक"}, {"Study", "पढ़ाई"}, {"Exam", "परीक्षा"}
    };
    if (translations.count(text)) return stringToChar(translations[text]);
    return stringToChar(text);
}

void free_string(char* str) {
    if (str) free(str);
}
