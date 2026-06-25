#include <vector>
#include <string>
#include <map>
#include <random>
#include <algorithm>

std::vector<std::map<std::string, std::string>> getQuestions(std::string subject, std::string chapter, int difficulty, int count) {
    std::vector<std::map<std::string, std::string>> questions;
    std::mt19937 rng(std::random_device{}());

    std::vector<std::map<std::string, std::string>> physicsQ = {
        {{"question", "A body of mass 5 kg is acted upon by two forces of 3N and 4N at right angles. What is the acceleration?"},
         {"option_a", "0.7 m/s²"}, {"option_b", "1.0 m/s²"}, {"option_c", "5.0 m/s²"}, {"option_d", "7.0 m/s²"}, {"answer", "B"},
         {"explanation", "Resultant force = √(3²+4²) = 5N. a = F/m = 5/5 = 1 m/s²."}},
        {{"question", "A car accelerates from rest to 72 km/h in 10 seconds. What is the acceleration?"},
         {"option_a", "2 m/s²"}, {"option_b", "7.2 m/s²"}, {"option_c", "72 m/s²"}, {"option_d", "0.2 m/s²"}, {"answer", "A"},
         {"explanation", "72 km/h = 20 m/s. a = (20-0)/10 = 2 m/s²."}},
        {{"question", "What is the gravitational potential energy of a 10 kg object at height 5 m? (g=10 m/s²)"},
         {"option_a", "50 J"}, {"option_b", "150 J"}, {"option_c", "500 J"}, {"option_d", "100 J"}, {"answer", "C"},
         {"explanation", "PE = mgh = 10 × 10 × 5 = 500 J."}},
        {{"question", "A wave has frequency 50 Hz and wavelength 4 m. What is its speed?"},
         {"option_a", "12.5 m/s"}, {"option_b", "100 m/s"}, {"option_c", "200 m/s"}, {"option_d", "54 m/s"}, {"answer", "C"},
         {"explanation", "v = fλ = 50 × 4 = 200 m/s."}},
        {{"question", "The work done in moving a 10 C charge through a potential difference of 25 V is:"},
         {"option_a", "2.5 J"}, {"option_b", "250 J"}, {"option_c", "35 J"}, {"option_d", "150 J"}, {"answer": "B"},
         {"explanation", "W = qV = 10 × 25 = 250 J."}},
        {{"question", "What is the SI unit of electric current?"},
         {"option_a", "Volt"}, {"option_b", "Ohm"}, {"option_c", "Ampere"}, {"option_d", "Watt"}, {"answer", "C"},
         {"explanation", "Ampere is the SI unit of electric current."}},
        {{"question", "A ball is thrown vertically upward with velocity 20 m/s. What is the maximum height? (g=10 m/s²)"},
         {"option_a", "10 m"}, {"option_b", "20 m"}, {"option_c", "40 m"}, {"option_d", "30 m"}, {"answer", "B"},
         {"explanation", "v²=u²-2gh → 0=400-20h → h=20 m."}},
        {{"question", "The moment of inertia of a solid sphere about its diameter is:"},
         {"option_a", "2/5 MR²"}, {"option_b", "2/3 MR²"}, {"option_c", "MR²"}, {"option_d", "1/2 MR²"}, {"answer", "A"},
         {"explanation", "For a solid sphere, I = (2/5)MR² about its diameter."}}
    };

    std::vector<std::map<std::string, std::string>> chemistryQ = {
        {{"question", "What is the molecular mass of NaCl? (Na=23, Cl=35.5)"},
         {"option_a", "58.5 g/mol"}, {"option_b", "35.5 g/mol"}, {"option_c", "23 g/mol"}, {"option_d", "46 g/mol"}, {"answer", "A"},
         {"explanation", "NaCl = 23 + 35.5 = 58.5 g/mol."}},
        {{"question", "How many moles are in 44 g of CO₂? (C=12, O=16)"},
         {"option_a", "1 mole"}, {"option_b", "2 moles"}, {"option_c", "0.5 mole"}, {"option_d", "4 moles"}, {"answer", "A"},
         {"explanation", "CO₂ = 44 g/mol. 44g / 44 g/mol = 1 mole."}},
        {{"question", "The reaction of NaOH with HCl produces:"},
         {"option_a", "NaCl + H₂O"}, {"option_b", "NaCl + H₂"}, {"option_c", "NaOH + HCl"}, {"option_d", "Na + Cl₂"}, {"answer", "A"},
         {"explanation", "NaOH + HCl → NaCl + H₂O (neutralization reaction)."}},
        {{"question", "What is the atomic number of Carbon?"},
         {"option_a", "12"}, {"option_b", "6"}, {"option_c", "14"}, {"option_d", "8"}, {"answer", "B"},
         {"explanation", "Carbon has atomic number 6 (6 protons)."}},
        {{"question", "Which gas is released when Zinc reacts with dilute HCl?"},
         {"option_a", "Oxygen"}, {"option_b", "Chlorine"}, {"option_c", "Hydrogen"}, {"option_d", "Nitrogen"}, {"answer", "C"},
         {"explanation", "Zn + 2HCl → ZnCl₂ + H₂↑."}},
        {{"question", "pH of human blood is approximately:"},
         {"option_a", "6.4"}, {"option_b", "7.0"}, {"option_c", "7.4"}, {"option_d", "8.0"}, {"answer", "C"},
         {"explanation", "Human blood pH is approximately 7.4 (slightly alkaline)."}},
        {{"question", "The chemical formula of baking soda is:"},
         {"option_a", "Na₂CO₃"}, {"option_b", "NaHCO₃"}, {"option_c", "NaOH"}, {"option_d", "NaCl"}, {"answer", "B"},
         {"explanation", "Baking soda is sodium bicarbonate: NaHCO₃."}},
        {{"question", "Which element has the electronic configuration 2,8,1?"},
         {"option_a", "Magnesium"}, {"option_b", "Aluminium"}, {"option_c", "Sodium"}, {"option_d", "Silicon"}, {"answer", "C"},
         {"explanation", "Sodium (Na) has atomic number 11: configuration 2,8,1."}}
    };

    std::vector<std::map<std::string, std::string>> biologyQ = {
        {{"question", "DNA stands for:"},
         {"option_a", "Deoxyribonucleic Acid"}, {"option_b", "Dinitrogen Acid"}, {"option_c", "Di-nuclear Acid"}, {"option_d", "Deoxynitrate Acid"}, {"answer", "A"},
         {"explanation", "DNA = Deoxyribonucleic Acid, the genetic material."}},
        {{"question", "Which vitamin is produced when a person is exposed to sunlight?"},
         {"option_a", "Vitamin A"}, {"option_b", "Vitamin B"}, {"option_c", "Vitamin C"}, {"option_d", "Vitamin D"}, {"answer", "D"},
         {"explanation", "Vitamin D is synthesized in the skin upon UV exposure."}},
        {{"question", "The functional unit of the kidney is:"},
         {"option_a", "Neuron"}, {"option_b", "Nephron"}, {"option_c", "Alveoli"}, {"option_d", "Villus"}, {"answer", "B"},
         {"explanation", "Nephron is the structural and functional unit of the kidney."}},
        {{"question", "Which blood group is called the universal donor?"},
         {"option_a", "A+"}, {"option_b", "B+"}, {"option_c", "AB+"}, {"option_d", "O−"}, {"answer", "D"},
         {"explanation", "O− blood can be transfused to any blood group safely."}},
        {{"question", "Photosynthesis occurs in which cell organelle?"},
         {"option_a", "Mitochondria"}, {"option_b", "Chloroplast"}, {"option_c", "Ribosome"}, {"option_d", "Lysosome"}, {"answer", "B"},
         {"explanation", "Chloroplasts contain chlorophyll which captures light for photosynthesis."}},
        {{"question", "The powerhouse of the cell is:"},
         {"option_a", "Nucleus"}, {"option_b", "Golgi body"}, {"option_c", "Mitochondria"}, {"option_d", "Endoplasmic reticulum"}, {"answer", "C"},
         {"explanation", "Mitochondria generate ATP through cellular respiration."}},
        {{"question", "Which organ purifies blood in the human body?"},
         {"option_a", "Heart"}, {"option_b", "Liver"}, {"option_c", "Kidney"}, {"option_d", "Lungs"}, {"answer", "C"},
         {"explanation", "Kidneys filter blood and remove waste products."}},
        {{"question", "The study of fungi is called:"},
         {"option_a", "Virology"}, {"option_b", "Mycology"}, {"option_c", "Botany"}, {"option_d", "Zoology"}, {"answer", "B"},
         {"explanation", "Mycology is the branch of biology dealing with fungi."}}
    };

    std::vector<std::map<std::string, std::string>> mathsQ = {
        {{"question", "If x² - 5x + 6 = 0, what are the values of x?"},
         {"option_a", "2, 3"}, {"option_b", "1, 6"}, {"option_c", "-2, -3"}, {"option_d", "2, -3"}, {"answer", "A"},
         {"explanation", "x²-5x+6 = (x-2)(x-3) = 0, so x = 2 or 3."}},
        {{"question", "What is the value of sin(90°)?"},
         {"option_a", "0"}, {"option_b", "1"}, {"option_c", "-1"}, {"option_d", "0.5"}, {"answer", "B"},
         {"explanation", "sin(90°) = 1 from the unit circle."}},
        {{"question", "A train travels from Delhi to Mumbai at 80 km/h and returns at 120 km/h. What is the average speed?"},
         {"option_a", "96 km/h"}, {"option_b", "100 km/h"}, {"option_c", "90 km/h"}, {"option_d", "110 km/h"}, {"answer", "A"},
         {"explanation", "Average speed = 2×80×120/(80+120) = 19200/200 = 96 km/h."}},
        {{"question", "What is the derivative of x³?"},
         {"option_a", "x²"}, {"option_b", "3x"}, {"option_c", "3x²"}, {"option_d", "3x³"}, {"answer", "C"},
         {"explanation", "Using power rule: d/dx(x³) = 3x²."}},
        {{"question", "The sum of first 10 natural numbers is:"},
         {"option_a", "45"}, {"option_b", "55"}, {"option_c", "50"}, {"option_d", "60"}, {"answer", "B"},
         {"explanation", "Sum = n(n+1)/2 = 10×11/2 = 55."}},
        {{"question", "What is the value of log₁₀(1000)?"},
         {"option_a", "1"}, {"option_b", "2"}, {"option_c", "3"}, {"option_d", "4"}, {"answer", "C"},
         {"explanation", "log₁₀(1000) = log₁₀(10³) = 3."}},
        {{"question", "In a right triangle, if one angle is 30°, the other acute angle is:"},
         {"option_a", "45°"}, {"option_b", "60°"}, {"option_c", "90°"}, {"option_d", "30°"}, {"answer", "B"},
         {"explanation", "Sum of angles in a triangle = 180°. 90°+30°+60° = 180°."}},
        {{"question", "What is the probability of getting a head when tossing a fair coin?"},
         {"option_a", "0"}, {"option_b", "0.25"}, {"option_c", "0.5"}, {"option_d", "1"}, {"answer", "C"},
         {"explanation", "A fair coin has 2 outcomes, P(head) = 1/2 = 0.5."}}
    };

    std::vector<std::map<std::string, std::string>>* bank = nullptr;
    if (subject == "Physics") bank = &physicsQ;
    else if (subject == "Chemistry") bank = &chemistryQ;
    else if (subject == "Biology") bank = &biologyQ;
    else if (subject == "Maths") bank = &mathsQ;

    if (!bank) return questions;

    std::uniform_int_distribution<int> dist(0, bank->size() - 1);
    for (int i = 0; i < count; ++i) {
        int idx = dist(rng);
        questions.push_back((*bank)[idx]);
    }
    return questions;
}

std::map<std::string, std::string> generateMathProblem(int type, int difficulty) {
    std::mt19937 rng(std::random_device{}());
    std::map<std::string, std::string> problem;

    if (type == 1) {
        int a = std::uniform_int_distribution<int>(1, 10 * difficulty)(rng);
        int b = std::uniform_int_distribution<int>(1, 10 * difficulty)(rng);
        int op = std::uniform_int_distribution<int>(0, 3)(rng);
        if (op == 0) {
            problem["question"] = "What is " + std::to_string(a) + " + " + std::to_string(b) + "?";
            problem["answer"] = std::to_string(a + b);
            problem["explanation"] = "Addition: " + std::to_string(a) + " + " + std::to_string(b) + " = " + std::to_string(a + b);
        } else if (op == 1) {
            problem["question"] = "What is " + std::to_string(a) + " × " + std::to_string(b) + "?";
            problem["answer"] = std::to_string(a * b);
            problem["explanation"] = "Multiplication: " + std::to_string(a) + " × " + std::to_string(b) + " = " + std::to_string(a * b);
        } else if (op == 2) {
            int prod = a * b;
            problem["question"] = "What is " + std::to_string(prod) + " ÷ " + std::to_string(a) + "?";
            problem["answer"] = std::to_string(b);
            problem["explanation"] = "Division: " + std::to_string(prod) + " ÷ " + std::to_string(a) + " = " + std::to_string(b);
        } else {
            problem["question"] = "What is " + std::to_string(a) + " - " + std::to_string(b) + "?";
            problem["answer"] = std::to_string(a - b);
            problem["explanation"] = "Subtraction: " + std::to_string(a) + " - " + std::to_string(b) + " = " + std::to_string(a - b);
        }
    } else if (type == 2) {
        int a = std::uniform_int_distribution<int>(1, 5 * difficulty)(rng);
        int exp = std::uniform_int_distribution<int>(2, 3 + difficulty)(rng);
        int result = 1;
        for (int i = 0; i < exp; ++i) result *= a;
        problem["question"] = "What is " + std::to_string(a) + "^" + std::to_string(exp) + "?";
        problem["answer"] = std::to_string(result);
        problem["explanation"] = std::to_string(a) + " raised to power " + std::to_string(exp) + " = " + std::to_string(result);
    } else {
        int a = std::uniform_int_distribution<int>(2, 20)(rng);
        int b = std::uniform_int_distribution<int>(2, 20)(rng);
        int result = a * b;
        problem["question"] = "Find the LCM of " + std::to_string(a) + " and " + std::to_string(b) + ".";
        int g = std::__gcd(a, b);
        int lcm = result / g;
        problem["answer"] = std::to_string(lcm);
        problem["explanation"] = "LCM = (a × b) / GCD(a,b) = " + std::to_string(result) + " / " + std::to_string(g) + " = " + std::to_string(lcm);
    }
    return problem;
}

std::map<std::string, std::string> generateScienceQuestion(std::string topic, int difficulty) {
    std::mt19937 rng(std::random_device{}());
    std::map<std::string, std::string> q;

    if (topic == "Physics" || topic == "physics") {
        int mass = std::uniform_int_distribution<int>(1, 50)(rng);
        int force = std::uniform_int_distribution<int>(1, 100)(rng);
        double accel = static_cast<double>(force) / mass;
        q["question"] = "A force of " + std::to_string(force) + " N acts on a body of mass " + std::to_string(mass) + " kg. What is the acceleration?";
        q["option_a"] = std::to_string(accel - 0.5) + " m/s²";
        q["option_b"] = std::to_string(accel) + " m/s²";
        q["option_c"] = std::to_string(accel + 1.0) + " m/s²";
        q["option_d"] = std::to_string(accel * 2) + " m/s²";
        q["answer"] = "B";
        q["explanation"] = "a = F/m = " + std::to_string(force) + "/" + std::to_string(mass) + " = " + std::to_string(accel) + " m/s²";
    } else if (topic == "Chemistry" || topic == "chemistry") {
        q["question"] = "Which of these is an acid?";
        q["option_a"] = "NaOH"}, q["option_b"] = "HCl"}, q["option_c"] = "KOH"}, q["option_d"] = "NaCl"};
        q["answer"] = "B";
        q["explanation"] = "HCl (Hydrochloric acid) is a strong acid.";
    } else {
        q["question"] = "What is the powerhouse of the cell?";
        q["option_a"] = "Nucleus"}, q["option_b"] = "Ribosome"}, q["option_c"] = "Mitochondria"}, q["option_d"] = "Golgi body"};
        q["answer"] = "C";
        q["explanation"] = "Mitochondria produce ATP, the energy currency of the cell.";
    }
    return q;
}

std::string generateExplanation(std::string question, int correctIndex) {
    std::vector<std::string> explanations = {
        "The correct answer follows directly from the fundamental principles.",
        "This can be derived using the basic formula for the concept.",
        "Applying the standard method gives us this result.",
        "From the given conditions, we can logically deduce this answer.",
        "This is a standard result that can be verified by substitution."
    };
    std::mt19937 rng(std::random_device{}());
    return explanations[std::uniform_int_distribution<int>(0, explanations.size() - 1)(rng)];
}
