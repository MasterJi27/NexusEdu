#include <string>
#include <vector>
#include <map>
#include <algorithm>

struct BoardInfo {
    std::string name;
    int totalMarks;
    int passMarks;
    std::vector<std::string> subjects;
};

BoardInfo getBoardInfo(std::string board) {
    BoardInfo info;
    if (board == "CBSE" || board == "cbse") {
        info.name = "CBSE";
        info.totalMarks = 500;
        info.passMarks = 167;
        info.subjects = {"Mathematics", "Science", "Social Science", "English", "Hindi"};
    } else if (board == "ICSE" || board == "icse") {
        info.name = "ICSE";
        info.totalMarks = 500;
        info.passMarks = 167;
        info.subjects = {"Mathematics", "Physics", "Chemistry", "Biology", "English", "Hindi"};
    } else if (board == "Maharashtra" || board == "maharashtra") {
        info.name = "Maharashtra State Board";
        info.totalMarks = 500;
        info.passMarks = 167;
        info.subjects = {"Mathematics", "Science", "Social Science", "English", "Marathi"};
    } else if (board == "UP" || board == "up") {
        info.name = "UP Board";
        info.totalMarks = 500;
        info.passMarks = 167;
        info.subjects = {"Mathematics", "Science", "Social Science", "English", "Hindi"};
    } else {
        info.name = board;
        info.totalMarks = 500;
        info.passMarks = 167;
        info.subjects = {"Mathematics", "Science", "Social Science", "English"};
    }
    return info;
}

std::vector<std::string> getChapters(std::string board, int classLevel, std::string subject) {
    std::map<std::string, std::vector<std::string>> chapters;

    if (subject == "Mathematics" || subject == "Maths") {
        if (classLevel <= 10) {
            chapters["CBSE"] = {"Real Numbers", "Polynomials", "Pair of Linear Equations",
                "Quadratic Equations", "Arithmetic Progressions", "Triangles",
                "Coordinate Geometry", "Introduction to Trigonometry", "Circles",
                "Constructions", "Areas Related to Circles", "Surface Areas and Volumes",
                "Statistics", "Probability"};
        } else {
            chapters["CBSE"] = {"Relations and Functions", "Inverse Trigonometric Functions",
                "Matrices", "Determinants", "Continuity and Differentiability",
                "Application of Derivatives", "Integrals", "Application of Integrals",
                "Differential Equations", "Vector Algebra", "Three Dimensional Geometry",
                "Linear Programming", "Probability"};
        }
    } else if (subject == "Science" || subject == "Physics") {
        if (classLevel <= 10) {
            chapters["CBSE"] = {"Motion", "Force and Laws of Motion", "Gravitation",
                "Work and Energy", "Sound", "Light - Reflection and Refraction",
                "Human Eye and Colourful World", "Electricity", "Magnetic Effects of Electric Current",
                "Sources of Energy", "Chemical Reactions", "Acids Bases and Salts",
                "Metals and Non Metals", "Carbon and its Compounds", "Life Processes",
                "Control and Coordination", "How do Organisms Reproduce", "Heredity"};
        } else {
            chapters["CBSE"] = {"Physical World", "Units and Measurements", "Motion in a Straight Line",
                "Motion in a Plane", "Laws of Motion", "Work Energy and Power",
                "System of Particles and Rotational Motion", "Gravitation",
                "Mechanical Properties of Solids", "Mechanical Properties of Fluids",
                "Thermal Properties of Matter", "Thermodynamics", "Kinetic Theory"};
        }
    } else if (subject == "Chemistry") {
        chapters["CBSE"] = {"Atomic Structure", "Chemical Bonding", "States of Matter",
            "Thermodynamics", "Equilibrium", "Redox Reactions", "Electrochemistry",
            "Chemical Kinetics", "Surface Chemistry", "p-Block Elements",
            "d-Block Elements", "Coordination Compounds", "Haloalkanes", "Alcohols",
            "Aldehydes and Ketones", "Carboxylic Acids", "Amines", "Biomolecules"};
    } else if (subject == "Biology") {
        chapters["CBSE"] = {"The Living World", "Biological Classification", "Plant Kingdom",
            "Animal Kingdom", "Morphology of Flowering Plants", "Anatomy of Flowering Plants",
            "Structural Organisation in Animals", "Cell: The Unit of Life", "Biomolecules",
            "Cell Cycle and Cell Division", "Transport in Plants", "Mineral Nutrition",
            "Photosynthesis in Higher Plants", "Respiration in Plants", "Plant Growth and Development",
            "Digestion and Absorption", "Breathing and Exchange of Gases",
            "Body Fluids and Circulation", "Excretory Products", "Locomotion and Movement",
            "Neural Control and Coordination", "Chemical Coordination"};
    } else if (subject == "Social Science") {
        chapters["CBSE"] = {"India and the Contemporary World", "Democratic Politics",
            "Understanding Economic Development", "India - Resources and Development",
            "Civic Skills", "Geography of India", "History of India",
            "Indian Constitution at Work"};
    } else {
        chapters["CBSE"] = {"Chapter 1", "Chapter 2", "Chapter 3", "Chapter 4", "Chapter 5"};
    }

    if (chapters.count(board)) return chapters[board];
    if (chapters.count("CBSE")) return chapters["CBSE"];
    return {"General Chapter 1", "General Chapter 2", "General Chapter 3"};
}

std::map<std::string, double> getChapterWeightage(std::string board, std::string subject, std::string chapter) {
    std::map<std::string, double> weightage;
    weightage["weightage_percent"] = 8.0;
    weightage["expected_questions"] = 2.0;
    weightage["difficulty_level"] = 3.0;

    if (chapter.find("Trigonometry") != std::string::npos ||
        chapter.find("Calculus") != std::string::npos ||
        chapter.find("Derivatives") != std::string::npos) {
        weightage["weightage_percent"] = 12.0;
        weightage["expected_questions"] = 3.0;
        weightage["difficulty_level"] = 4.0;
    } else if (chapter.find("Motion") != std::string::npos ||
               chapter.find("Laws") != std::string::npos) {
        weightage["weightage_percent"] = 10.0;
        weightage["expected_questions"] = 2.0;
        weightage["difficulty_level"] = 3.5;
    } else if (chapter.find("Atomic") != std::string::npos ||
               chapter.find("Chemical") != std::string::npos) {
        weightage["weightage_percent"] = 9.0;
        weightage["expected_questions"] = 2.0;
        weightage["difficulty_level"] = 3.0;
    }
    return weightage;
}

std::vector<std::string> getStatesWithBoards() {
    return {"Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh",
            "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand",
            "Karnataka", "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur",
            "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab",
            "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura",
            "Uttar Pradesh", "Uttarakhand", "West Bengal", "Delhi", "Jammu & Kashmir"};
}

std::string getRegionalLanguage(std::string state) {
    std::map<std::string, std::string> languages = {
        {"Andhra Pradesh", "Telugu"}, {"Arunachal Pradesh", "English"},
        {"Assam", "Assamese"}, {"Bihar", "Hindi"}, {"Chhattisgarh", "Hindi"},
        {"Goa", "Konkani"}, {"Gujarat", "Gujarati"}, {"Haryana", "Hindi"},
        {"Himachal Pradesh", "Hindi"}, {"Jharkhand", "Hindi"},
        {"Karnataka", "Kannada"}, {"Kerala", "Malayalam"},
        {"Madhya Pradesh", "Hindi"}, {"Maharashtra", "Marathi"},
        {"Manipur", "Manipuri"}, {"Meghalaya", "English"},
        {"Mizoram", "Mizo"}, {"Nagaland", "English"}, {"Odisha", "Odia"},
        {"Punjab", "Punjabi"}, {"Rajasthan", "Hindi"}, {"Sikkim", "Nepali"},
        {"Tamil Nadu", "Tamil"}, {"Telangana", "Telugu"}, {"Tripura", "Bengali"},
        {"Uttar Pradesh", "Hindi"}, {"Uttarakhand", "Hindi"}, {"West Bengal", "Bengali"},
        {"Delhi", "Hindi"}, {"Jammu & Kashmir", "Urdu"}
    };
    if (languages.count(state)) return languages[state];
    return "Hindi";
}

std::map<std::string, double> getJEERanking(std::vector<double> marks) {
    std::map<std::string, double> result;
    if (marks.empty()) return result;
    double total = 0;
    for (double m : marks) total += m;
    double avg = total / marks.size();

    result["estimated_score"] = avg;
    if (avg >= 300) result["estimated_rank"] = 100;
    else if (avg >= 250) result["estimated_rank"] = 1000;
    else if (avg >= 200) result["estimated_rank"] = 5000;
    else if (avg >= 150) result["estimated_rank"] = 20000;
    else if (avg >= 100) result["estimated_rank"] = 50000;
    else result["estimated_rank"] = 100000;

    result["percentile"] = std::min(99.9, (avg / 360.0) * 100.0);
    result["qualifying_probability"] = avg >= 80 ? 85.0 : (avg >= 50 ? 40.0 : 10.0);
    return result;
}

std::map<std::string, double> getNEETRanking(std::vector<double> marks) {
    std::map<std::string, double> result;
    if (marks.empty()) return result;
    double total = 0;
    for (double m : marks) total += m;
    double avg = total / marks.size();

    result["estimated_score"] = avg;
    if (avg >= 650) result["estimated_rank"] = 50;
    else if (avg >= 600) result["estimated_rank"] = 500;
    else if (avg >= 550) result["estimated_rank"] = 2000;
    else if (avg >= 500) result["estimated_rank"] = 10000;
    else if (avg >= 450) result["estimated_rank"] = 30000;
    else result["estimated_rank"] = 100000;

    result["percentile"] = std::min(99.9, (avg / 720.0) * 100.0);
    result["qualifying_probability"] = avg >= 400 ? 80.0 : (avg >= 300 ? 35.0 : 8.0);
    return result;
}

std::vector<std::map<std::string, std::string>> getScholarships(std::string category, double familyIncome, std::string state) {
    std::vector<std::map<std::string, std::string>> scholarships;

    if (category == "SC" || category == "ST") {
        scholarships.push_back({{"name", "Post-Matric Scholarship"},
            {"amount", "Up to ₹1,000/month"}, {"eligibility", "SC/ST students with family income < ₹2.5 lakh"},
            {"source", "Ministry of Social Justice"}});
        scholarships.push_back({{"name", "Pre-Matric Scholarship"},
            {"amount", "Up to ₹500/month"}, {"eligibility", "SC/ST students in Class 9-10"},
            {"source", "State Government"}});
    }
    if (category == "OBC" || category == "General") {
        scholarships.push_back({{"name", "Merit-cum-Means Scholarship"},
            {"amount", "Up to ₹5,000/year"}, {"eligibility", "Family income < ₹6 lakh, 75%+ marks"},
            {"source", "Ministry of Education"}});
    }
    if (familyIncome < 200000) {
        scholarships.push_back({{"name", "INSPIRE Scholarship"},
            {"amount", "₹80,000/year"}, {"eligibility", "Top 1% of board exams, family income < ₹8 lakh"},
            {"source", "DST, Government of India"}});
        scholarships.push_back({{"name", "National Means Merit Scholarship"},
            {"amount", "₹12,000/year"}, {"eligibility", "Class 9 students scoring 55%+, family income < ₹3.5 lakh"},
            {"source", "Ministry of Education"}});
    }
    scholarships.push_back({{"name", "AICTE Scholarship"},
        {"amount", "₹50,000/year"}, {"eligibility", "Students in technical courses"},
        {"source", "AICTE"}});
    return scholarships;
}

std::string translateToHindi(std::string englishText) {
    std::map<std::string, std::string> translations = {
        {"Hello", "नमस्ते"},
        {"Good morning", "सुप्रभात"},
        {"How are you?", "आप कैसे हैं?"},
        {"Thank you", "धन्यवाद"},
        {"Please", "कृपया"},
        {"Yes", "हाँ"},
        {"No", "नहीं"},
        {"Mathematics", "गणित"},
        {"Science", "विज्ञान"},
        {"Physics", "भौतिक विज्ञान"},
        {"Chemistry", "रसायन विज्ञान"},
        {"Biology", "जीव विज्ञान"},
        {"History", "इतिहास"},
        {"Geography", "भूगोल"},
        {"English", "अंग्रेजी"},
        {"Hindi", "हिंदी"},
        {"Goodbye", "अलविदा"},
        {"Welcome", "स्वागत"},
        {"Study", "पढ़ाई"},
        {"Exam", "परीक्षा"},
        {"Teacher", "शिक्षक"},
        {"Student", "विद्यार्थी"}
    };
    if (translations.count(englishText)) return translations[englishText];
    return englishText;
}
