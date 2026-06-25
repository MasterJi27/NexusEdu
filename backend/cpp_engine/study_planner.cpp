#include <vector>
#include <string>
#include <map>
#include <algorithm>
#include <cmath>
#include <ctime>

struct StudyPlan {
    std::vector<std::map<std::string, std::string>> dailyTasks;
    double recommendedHours;
    std::string priority;
};

int parseDate(const std::string& dateStr) {
    int y, m, d;
    sscanf(dateStr.c_str(), "%d-%d-%d", &y, &m, &d);
    return y * 10000 + m * 100 + d;
}

int calculateDaysLeft(std::string examDate) {
    time_t now = time(0);
    tm ltm;
    localtime_s(&ltm, &now);
    int today = (1900 + ltm.tm_year) * 10000 + (1 + ltm.tm_mon) * 100 + ltm.tm_mday;
    int exam = parseDate(examDate);
    return std::max(0, exam - today);
}

StudyPlan generateStudyPlan(std::vector<std::string> subjects, std::string examDate, double dailyHours, std::map<std::string, double> subjectPriority) {
    StudyPlan plan;
    plan.recommendedHours = dailyHours;
    int daysLeft = calculateDaysLeft(examDate);

    double totalWeight = 0;
    for (auto& s : subjects) totalWeight += subjectPriority[s];

    std::sort(subjects.begin(), subjects.end(), [&subjectPriority](const std::string& a, const std::string& b) {
        return subjectPriority[a] > subjectPriority[b];
    });

    plan.priority = subjects.empty() ? "None" : subjects[0];

    for (int day = 0; day < daysLeft && day < 30; ++day) {
        std::map<std::string, std::string> task;
        task["day"] = std::to_string(day + 1);
        task["date"] = examDate;

        int subIdx = day % subjects.size();
        task["subject"] = subjects[subIdx];

        double hoursForSubject = dailyHours * (subjectPriority[subjects[subIdx]] / totalWeight);
        task["hours"] = std::to_string(hoursForSubject).substr(0, 4);

        if (day % 7 == 0) {
            task["type"] = "revision";
            task["description"] = "Revise all topics covered this week";
        } else if (day % 7 == 6) {
            task["type"] = "practice";
            task["description"] = "Solve practice problems for " + subjects[subIdx];
        } else {
            task["type"] = "new_topic";
            task["description"] = "Study new concepts in " + subjects[subIdx];
        }
        plan.dailyTasks.push_back(task);
    }
    return plan;
}

std::vector<std::map<std::string, std::string>> optimizeSchedule(std::vector<std::string> tasks, int daysLeft, double hoursPerDay) {
    std::vector<std::map<std::string, std::string>> schedule;
    double totalHours = daysLeft * hoursPerDay;
    int tasksPerDay = std::max(1, static_cast<int>(tasks.size() / daysLeft));

    for (int day = 0; day < daysLeft && !tasks.empty(); ++day) {
        std::map<std::string, std::string> dayPlan;
        dayPlan["day"] = std::to_string(day + 1);
        std::string taskList;
        for (int t = 0; t < tasksPerDay && !tasks.empty(); ++t) {
            taskList += tasks.back();
            tasks.pop_back();
            if (t < tasksPerDay - 1 && !tasks.empty()) taskList += ", ";
        }
        dayPlan["tasks"] = taskList;
        dayPlan["hours"] = std::to_string(hoursPerDay).substr(0, 4);
        schedule.push_back(dayPlan);
    }
    return schedule;
}

double calculateOptimalPace(std::string examDate, int chaptersRemaining) {
    int daysLeft = calculateDaysLeft(examDate);
    if (daysLeft <= 0) return chaptersRemaining;
    return static_cast<double>(chaptersRemaining) / daysLeft;
}

std::map<std::string, std::string> prioritizeChapters(std::map<std::string, double> chapterWeights, std::map<std::string, double> masteryLevels) {
    std::map<std::string, std::string> priorities;
    for (auto& pair : chapterWeights) {
        double weight = pair.second;
        double mastery = masteryLevels.count(pair.first) ? masteryLevels[pair.first] : 0.0;
        double urgency = weight * (100.0 - mastery) / 100.0;
        if (urgency > 70) priorities[pair.first] = "critical";
        else if (urgency > 40) priorities[pair.first] = "high";
        else if (urgency > 20) priorities[pair.first] = "medium";
        else priorities[pair.first] = "low";
    }
    return priorities;
}

std::vector<std::string> generateRevisionSchedule(std::vector<std::string> topics, std::string examDate) {
    std::vector<std::string> schedule;
    int daysLeft = calculateDaysLeft(examDate);
    int interval = 1;
    for (auto& topic : topics) {
        for (int day = interval; day <= daysLeft; day += interval) {
            schedule.push_back("Day " + std::to_string(day) + ": Revise " + topic);
        }
        interval = std::min(interval + 1, 7);
    }
    std::sort(schedule.begin(), schedule.end());
    return schedule;
}
