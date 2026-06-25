#include <vector>
#include <string>
#include <map>
#include <random>
#include <algorithm>
#include <numeric>

std::vector<std::map<std::string, std::string>> generateQuiz(std::string subject, std::string chapter, int numQuestions, int difficulty) {
    std::vector<std::map<std::string, std::string>> questions;
    std::mt19937 rng(std::random_device{}());

    std::map<std::string, std::vector<std::map<std::string, std::string>>> questionBank;

    questionBank["Physics"]["1"] = {{"question", "What is the SI unit of force?"},
        {"option_a", "Joule"}, {"option_b", "Newton"}, {"option_c", "Watt"}, {"option_d", "Pascal"}, {"answer", "B"},
        {"explanation", "Newton is the SI unit of force. 1 Newton = 1 kg·m/s²."}};
    questionBank["Physics"]["2"] = {{"question", "A train travels 360 km in 4 hours. What is its speed?"},
        {"option_a", "80 km/h"}, {"option_b", "90 km/h"}, {"option_c", "100 km/h"}, {"option_d", "70 km/h"}, {"answer", "B"},
        {"explanation", "Speed = Distance/Time = 360/4 = 90 km/h."}};

    questionBank["Chemistry"]["1"] = {{"question", "What is the chemical formula of water?"},
        {"option_a", "H2O"}, {"option_b", "HO2"}, {"option_c", "H2O2"}, {"option_d", "OH"}, {"answer", "A"},
        {"explanation", "Water is composed of 2 hydrogen atoms and 1 oxygen atom: H₂O."}};
    questionBank["Chemistry"]["2"] = {{"question", "What is the pH of a neutral solution?"},
        {"option_a", "0"}, {"option_b", "7"}, {"option_c", "14"}, {"option_d", "1"}, {"answer", "B"},
        {"explanation", "A neutral solution has pH = 7. Acids have pH < 7, bases have pH > 7."}};

    questionBank["Biology"]["1"] = {{"question", "Which organelle is known as the powerhouse of the cell?"},
        {"option_a", "Nucleus"}, {"option_b", "Ribosome"}, {"option_c", "Mitochondria"}, {"option_d", "Golgi apparatus"}, {"answer", "C"},
        {"explanation", "Mitochondria produce ATP through cellular respiration, hence called powerhouse."}};
    questionBank["Biology"]["2"] = {{"question", "What is the largest organ in the human body?"},
        {"option_a", "Heart"}, {"option_b", "Liver"}, {"option_c", "Brain"}, {"option_d", "Skin"}, {"answer", "D"},
        {"explanation", "Skin is the largest organ, covering approximately 20 square feet in adults."}};

    questionBank["Maths"]["1"] = {{"question", "What is the value of π (pi) to two decimal places?"},
        {"option_a", "3.12"}, {"option_b", "3.14"}, {"option_c", "3.16"}, {"option_d", "3.18"}, {"answer", "B"},
        {"explanation", "π ≈ 3.14159..., so to two decimal places it is 3.14."}};
    questionBank["Maths"]["2"] = {{"question", "What is the square root of 144?"},
        {"option_a", "11"}, {"option_b", "12"}, {"option_c", "13"}, {"option_d", "14"}, {"answer", "B"},
        {"explanation", "√144 = 12 because 12 × 12 = 144."}};

    auto& bank = questionBank[subject];
    std::vector<std::string> keys;
    for (auto& p : bank) keys.push_back(p.first);

    if (keys.empty()) {
        for (int i = 0; i < numQuestions; ++i) {
            std::map<std::string, std::string> q;
            q["question"] = "Sample " + subject + " question " + std::to_string(i + 1);
            q["option_a"] = "Option A";
            q["option_b"] = "Option B";
            q["option_c"] = "Option C";
            q["option_d"] = "Option D";
            q["answer"] = "A";
            q["explanation"] = "This is a placeholder question.";
            questions.push_back(q);
        }
        return questions;
    }

    std::uniform_int_distribution<int> dist(0, keys.size() - 1);
    for (int i = 0; i < numQuestions && i < static_cast<int>(keys.size()); ++i) {
        int idx = dist(rng);
        questions.push_back(bank[keys[idx]]);
    }
    return questions;
}

int scoreQuiz(std::vector<int> answers, std::vector<int> correctAnswers) {
    int score = 0;
    size_t limit = std::min(answers.size(), correctAnswers.size());
    for (size_t i = 0; i < limit; ++i) {
        if (answers[i] == correctAnswers[i]) {
            score += 4;
        } else if (answers[i] != 0) {
            score -= 1;
        }
    }
    return score;
}

double calculateNegativeMarking(int correct, int wrong, int total, double negMark) {
    if (total <= 0) return 0.0;
    double positive = correct * 4.0;
    double negative = wrong * negMark;
    return positive - negative;
}

std::map<std::string, double> analyzeQuizPerformance(std::vector<std::map<std::string, std::string>> questions, std::vector<int> userAnswers) {
    std::map<std::string, double> topicScores;
    std::map<std::string, int> topicTotal;
    std::map<std::string, int> topicCorrect;

    for (size_t i = 0; i < questions.size() && i < userAnswers.size(); ++i) {
        std::string topic = questions[i].count("topic") ? questions[i]["topic"] : "General";
        topicTotal[topic]++;
        if (userAnswers[i] == std::stoi(questions[i]["answer"])) {
            topicCorrect[topic]++;
        }
    }

    for (auto& pair : topicTotal) {
        topicScores[pair.first] = calculateAccuracy(topicCorrect[pair.first], pair.second);
    }
    return topicScores;
}

int getNextDifficulty(int currentLevel, bool correct, int streak) {
    if (correct && streak >= 2) {
        return std::min(currentLevel + 1, 5);
    } else if (!correct && streak >= 2) {
        return std::max(currentLevel - 1, 1);
    }
    return currentLevel;
}

std::vector<std::string> identifyWeakTopics(std::map<std::string, double> topicScores, double threshold) {
    std::vector<std::string> weakTopics;
    for (auto& pair : topicScores) {
        if (pair.second < threshold) {
            weakTopics.push_back(pair.first);
        }
    }
    std::sort(weakTopics.begin(), weakTopics.end(), [&topicScores](const std::string& a, const std::string& b) {
        return topicScores[a] < topicScores[b];
    });
    return weakTopics;
}

std::map<std::string, double> calculatePercentile(std::map<std::string, double> userScores, std::map<std::string, std::vector<double>> allScores) {
    std::map<std::string, double> percentiles;
    for (auto& pair : userScores) {
        if (allScores.count(pair.first)) {
            auto& scores = allScores[pair.first];
            int belowCount = 0;
            for (double s : scores) {
                if (s < pair.second) belowCount++;
            }
            percentiles[pair.first] = (static_cast<double>(belowCount) / scores.size()) * 100.0;
        }
    }
    return percentiles;
}
