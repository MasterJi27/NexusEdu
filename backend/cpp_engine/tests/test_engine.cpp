#include <cassert>
#include <iostream>
#include <vector>
#include <string>
#include <map>
#include <cmath>

#include "../math_engine.cpp"
#include "../quiz_engine.cpp"
#include "../analytics_engine.cpp"
#include "../question_bank.cpp"
#include "../study_planner.cpp"
#include "../grading_engine.cpp"
#include "../indian_education.cpp"

void testEbbinghaus() {
    double r = calculateEbbinghausRetention(100, 1);
    assert(r > 0 && r <= 100);
    assert(calculateEbbinghausRetention(100, 0) == 100);
    assert(calculateEbbinghausRetention(0, 5) == 0);
    std::cout << "✓ Ebbinghaus test passed" << std::endl;
}

void testEloRating() {
    double newRating = calculateEloRating(1500, 1600, true);
    assert(newRating > 1500);
    double newRating2 = calculateEloRating(1500, 1600, false);
    assert(newRating2 < 1500);
    std::cout << "✓ Elo rating test passed" << std::endl;
}

void testAccuracy() {
    assert(calculateAccuracy(5, 10) == 50.0);
    assert(calculateAccuracy(0, 0) == 0.0);
    assert(calculateAccuracy(10, 10) == 100.0);
    std::cout << "✓ Accuracy test passed" << std::endl;
}

void testMeanMedian() {
    std::vector<double> data = {10, 20, 30, 40, 50};
    assert(std::abs(calculateMean(data) - 30.0) < 0.001);
    assert(std::abs(calculateMedian(data) - 30.0) < 0.001);
    std::vector<double> data2 = {10, 20, 30, 40};
    assert(std::abs(calculateMedian(data2) - 25.0) < 0.001);
    std::cout << "✓ Mean/Median test passed" << std::endl;
}

void testStandardDeviation() {
    std::vector<double> data = {2, 4, 4, 4, 5, 5, 7, 9};
    double sd = calculateStandardDeviation(data);
    assert(sd > 2.0 && sd < 2.5);
    std::cout << "✓ Standard deviation test passed" << std::endl;
}

void testTrend() {
    std::vector<double> scores = {50, 60, 70, 80, 90};
    double trend = calculateTrend(scores);
    assert(trend > 9.0 && trend < 11.0);
    std::cout << "✓ Trend test passed" << std::endl;
}

void testGrade() {
    assert(calculateGrade(96) == 0);  // A+
    assert(calculateGrade(91) == 1);  // A
    assert(calculateGrade(75) == 3);  // B
    assert(calculateGrade(20) == 8);  // F
    std::cout << "✓ Grade test passed" << std::endl;
}

void testStudyEfficiency() {
    double eff = calculateStudyEfficiency(5, 10, 80);
    assert(eff > 0);
    assert(calculateStudyEfficiency(0, 10, 80) == 0);
    std::cout << "✓ Study efficiency test passed" << std::endl;
}

void testPredictPerformance() {
    std::vector<double> scores = {50, 55, 60, 65, 70};
    double predicted = predictPerformance(scores, 5);
    assert(predicted > 70 && predicted < 100);
    std::cout << "✓ Predict performance test passed" << std::endl;
}

void testAdaptiveQuestion() {
    auto result = generateAdaptiveQuestion(3, 3, 0);
    assert(result.size() == 2);
    assert(result[0] >= 1 && result[0] <= 5);
    assert(result[1] >= 0 && result[1] <= 9);
    std::cout << "✓ Adaptive question test passed" << std::endl;
}

void testBurnoutRisk() {
    std::vector<double> scores = {80, 75, 70, 65, 60, 55};
    std::vector<double> hours = {4, 5, 6, 7, 8, 9};
    double risk = calculateBurnoutRisk(scores, hours);
    assert(risk >= 0 && risk <= 100);
    std::cout << "✓ Burnout risk test passed" << std::endl;
}

void testConfidenceInterval() {
    std::vector<double> data = {10, 12, 11, 13, 10, 12};
    double ci = calculateConfidenceInterval(data, 0.95);
    assert(ci > 0);
    std::cout << "✓ Confidence interval test passed" << std::endl;
}

void testGenerateQuiz() {
    auto questions = generateQuiz("Physics", "Mechanics", 3, 2);
    assert(!questions.empty());
    assert(questions.size() <= 3);
    std::cout << "✓ Generate quiz test passed" << std::endl;
}

void testScoreQuiz() {
    std::vector<int> answers = {1, 2, 3, 1};
    std::vector<int> correct = {1, 2, 2, 1};
    int score = scoreQuiz(answers, correct);
    assert(score == 11); // 3 correct * 4 = 12, 1 wrong * 1 = 1, 12-1=11
    std::cout << "✓ Score quiz test passed" << std::endl;
}

void testNegativeMarking() {
    double result = calculateNegativeMarking(20, 5, 25, 0.25);
    assert(result == 78.75); // 20*4 - 5*0.25 = 80-1.25 = 78.75
    std::cout << "✓ Negative marking test passed" << std::endl;
}

void testNextDifficulty() {
    assert(getNextDifficulty(3, true, 3) == 4);
    assert(getNextDifficulty(3, false, 3) == 2);
    assert(getNextDifficulty(3, true, 1) == 3);
    std::cout << "✓ Next difficulty test passed" << std::endl;
}

void testWeakTopics() {
    std::map<std::string, double> scores = {{"Physics", 40.0}, {"Chemistry", 80.0}, {"Maths", 30.0}};
    auto weak = identifyWeakTopics(scores, 50.0);
    assert(weak.size() == 2);
    assert(weak[0] == "Maths");
    std::cout << "✓ Weak topics test passed" << std::endl;
}

void testPerformanceAnalysis() {
    std::vector<PerformanceData> data = {
        {"2026-01-01", 80.0, "Physics", "Motion", 30},
        {"2026-01-02", 85.0, "Physics", "Forces", 25},
        {"2026-01-03", 90.0, "Physics", "Energy", 35}
    };
    auto result = analyzePerformance(data);
    assert(result.mean > 0);
    assert(!result.grade.empty());
    std::cout << "✓ Performance analysis test passed" << std::endl;
}

void testMovingAverage() {
    std::vector<double> data = {1, 2, 3, 4, 5, 6};
    auto result = movingAverage(data, 3);
    assert(result.size() == 4);
    assert(std::abs(result[0] - 2.0) < 0.001);
    std::cout << "✓ Moving average test passed" << std::endl;
}

void testGradeString() {
    assert(calculateGrade(95) == "A+");
    assert(calculateGrade(85) == "B+");
    assert(calculateGrade(55) == "C");
    assert(calculateGrade(30) == "F");
    std::cout << "✓ Grade string test passed" << std::endl;
}

void testCGPA() {
    std::vector<double> pcts = {90, 80, 70, 85, 75};
    double cgpa = calculateCGPA(pcts);
    assert(cgpa > 0 && cgpa <= 10);
    std::cout << "✓ CGPA test passed" << std::endl;
}

void testBoardInfo() {
    auto info = getBoardInfo("CBSE");
    assert(info.name == "CBSE");
    assert(info.totalMarks == 500);
    assert(!info.subjects.empty());
    std::cout << "✓ Board info test passed" << std::endl;
}

void testDaysLeft() {
    int days = calculateDaysLeft("2027-12-31");
    assert(days > 0);
    std::cout << "✓ Days left test passed" << std::endl;
}

void testOptimalPace() {
    double pace = calculateOptimalPace("2027-12-31", 20);
    assert(pace > 0);
    std::cout << "✓ Optimal pace test passed" << std::endl;
}

void testJEERanking() {
    std::vector<double> marks = {280, 300, 260};
    auto result = getJEERanking(marks);
    assert(result.count("estimated_rank"));
    assert(result["estimated_rank"] > 0);
    std::cout << "✓ JEE ranking test passed" << std::endl;
}

void testNEETRanking() {
    std::vector<double> marks = {600, 620, 580};
    auto result = getNEETRanking(marks);
    assert(result.count("estimated_rank"));
    assert(result["estimated_rank"] > 0);
    std::cout << "✓ NEET ranking test passed" << std::endl;
}

void testScholarships() {
    auto result = getScholarships("SC", 150000, "Maharashtra");
    assert(!result.empty());
    assert(result[0].count("name"));
    std::cout << "✓ Scholarships test passed" << std::endl;
}

void testTranslateToHindi() {
    assert(translateToHindi("Hello") == "नमस्ते");
    assert(translateToHindi("Thank you") == "धन्यवाद");
    assert(translateToHindi("Mathematics") == "गणित");
    std::cout << "✓ Translate to Hindi test passed" << std::endl;
}

void testStudyPlan() {
    std::vector<std::string> subjects = {"Maths", "Physics", "Chemistry"};
    std::map<std::string, double> priority = {{"Maths", 0.4}, {"Physics", 0.35}, {"Chemistry", 0.25}};
    auto plan = generateStudyPlan(subjects, "2027-06-01", 6.0, priority);
    assert(plan.recommendedHours == 6.0);
    assert(!plan.dailyTasks.empty());
    std::cout << "✓ Study plan test passed" << std::endl;
}

void testWeightedScore() {
    std::vector<double> scores = {80, 90, 70};
    std::vector<double> weights = {0.4, 0.35, 0.25};
    double result = calculateWeightedScore(scores, weights);
    assert(result > 0 && result <= 100);
    std::cout << "✓ Weighted score test passed" << std::endl;
}

void testReportCard() {
    std::map<std::string, double> scores = {{"Maths", 85.0}, {"Physics", 90.0}, {"Chemistry", 78.0}};
    auto report = generateReportCard(scores);
    assert(report.count("overall_grade"));
    assert(report.count("remark"));
    std::cout << "✓ Report card test passed" << std::endl;
}

void testGetChapters() {
    auto chapters = getChapters("CBSE", 12, "Mathematics");
    assert(!chapters.empty());
    assert(chapters.size() > 5);
    std::cout << "✓ Get chapters test passed" << std::endl;
}

void testRegionalLanguage() {
    assert(getRegionalLanguage("Tamil Nadu") == "Tamil");
    assert(getRegionalLanguage("Karnataka") == "Kannada");
    assert(getRegionalLanguage("Kerala") == "Malayalam");
    std::cout << "✓ Regional language test passed" << std::endl;
}

void testChapterWeightage() {
    auto w = getChapterWeightage("CBSE", "Mathematics", "Trigonometry");
    assert(w.count("weightage_percent"));
    assert(w["weightage_percent"] > 0);
    std::cout << "✓ Chapter weightage test passed" << std::endl;
}

void testGenerateMathProblem() {
    auto problem = generateMathProblem(1, 2);
    assert(problem.count("question"));
    assert(problem.count("answer"));
    assert(problem.count("explanation"));
    std::cout << "✓ Generate math problem test passed" << std::endl;
}

void testPercentileRank() {
    std::vector<double> classScores = {60, 70, 80, 90, 100};
    auto result = calculatePercentileRank(classScores, 80);
    assert(result.count("percentile"));
    assert(result["percentile"] >= 0 && result["percentile"] <= 100);
    std::cout << "✓ Percentile rank test passed" << std::endl;
}

int main() {
    std::cout << "Running C++ Engine Tests..." << std::endl;
    std::cout << "============================" << std::endl;

    testEbbinghaus();
    testEloRating();
    testAccuracy();
    testMeanMedian();
    testStandardDeviation();
    testTrend();
    testGrade();
    testStudyEfficiency();
    testPredictPerformance();
    testAdaptiveQuestion();
    testBurnoutRisk();
    testConfidenceInterval();
    testGenerateQuiz();
    testScoreQuiz();
    testNegativeMarking();
    testNextDifficulty();
    testWeakTopics();
    testPerformanceAnalysis();
    testMovingAverage();
    testGradeString();
    testCGPA();
    testBoardInfo();
    testDaysLeft();
    testOptimalPace();
    testJEERanking();
    testNEETRanking();
    testScholarships();
    testTranslateToHindi();
    testStudyPlan();
    testWeightedScore();
    testReportCard();
    testGetChapters();
    testRegionalLanguage();
    testChapterWeightage();
    testGenerateMathProblem();
    testPercentileRank();

    std::cout << "============================" << std::endl;
    std::cout << "All 36 tests passed!" << std::endl;
    return 0;
}
