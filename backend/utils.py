import uuid
import datetime
import math
import random
import hashlib
from typing import Dict, List, Any


def generate_id() -> str:
    return str(uuid.uuid4())[:8]


def get_timestamp() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def calculate_accuracy(score: int, total: int) -> float:
    if total == 0:
        return 0.0
    return round((score / total) * 100, 2)


def get_grade(percentage: float) -> str:
    if percentage >= 95:
        return "A+"
    elif percentage >= 90:
        return "A"
    elif percentage >= 80:
        return "B+"
    elif percentage >= 70:
        return "B"
    elif percentage >= 60:
        return "C"
    elif percentage >= 50:
        return "D"
    elif percentage >= 33:
        return "E"
    else:
        return "F"


def standard_deviation(values: List[float]) -> float:
    if len(values) < 2:
        return 0.0
    mean = sum(values) / len(values)
    variance = sum((x - mean) ** 2 for x in values) / (len(values) - 1)
    return math.sqrt(variance)


def mean(values: List[float]) -> float:
    if not values:
        return 0.0
    return sum(values) / len(values)


def trend_direction(values: List[float]) -> str:
    if len(values) < 2:
        return "stable"
    diffs = [values[i + 1] - values[i] for i in range(len(values) - 1)]
    avg_diff = sum(diffs) / len(diffs)
    if avg_diff > 2:
        return "improving"
    elif avg_diff < -2:
        return "declining"
    return "stable"


indian_boards = {
    "CBSE": {
        "classes": list(range(1, 13)),
        "subjects": {
            10: ["Mathematics", "Science", "Social Science", "English", "Hindi", "Information Technology"],
            12: ["Physics", "Chemistry", "Mathematics", "Biology", "English", "Computer Science", "Economics"],
        },
        "passing_marks": 33,
        "total_marks": 100,
    },
    "ICSE": {
        "classes": list(range(1, 13)),
        "subjects": {
            10: ["Mathematics", "Physics", "Chemistry", "Biology", "English", "History", "Geography"],
            12: ["Physics", "Chemistry", "Mathematics", "Biology", "English"],
        },
        "passing_marks": 35,
        "total_marks": 100,
    },
    "State": {
        "classes": list(range(1, 13)),
        "subjects": {
            10: ["Mathematics", "Science", "Social Science", "English", "Hindi"],
            12: ["Physics", "Chemistry", "Mathematics", "Biology", "English"],
        },
        "passing_marks": 33,
        "total_marks": 100,
    },
}

subject_chapters = {
    "Mathematics": {
        10: [
            "Real Numbers", "Polynomials", "Pair of Linear Equations in Two Variables",
            "Quadratic Equations", "Arithmetic Progressions", "Triangles",
            "Coordinate Geometry", "Introduction to Trigonometry",
            "Circles", "Constructions", "Areas Related to Circles",
            "Surface Areas and Volumes", "Statistics", "Probability",
        ],
        12: [
            "Relations and Functions", "Inverse Trigonometric Functions",
            "Matrices", "Determinants", "Continuity and Differentiability",
            "Application of Derivatives", "Integrals", "Application of Integrals",
            "Differential Equations", "Vector Algebra", "Three Dimensional Geometry",
            "Linear Programming", "Probability",
        ],
    },
    "Physics": {
        10: [
            "Light - Reflection and Refraction", "Human Eye and Colourful World",
            "Electricity", "Magnetic Effects of Electric Current", "Sources of Energy",
            "Our Environment", "Sustainable Management of Natural Resources",
        ],
        12: [
            "Electric Charges and Fields", "Electrostatic Potential and Capacitance",
            "Current Electricity", "Moving Charges and Magnetism",
            "Magnetism and Matter", "Electromagnetic Induction",
            "Alternating Current", "Electromagnetic Waves",
            "Ray Optics", "Wave Optics", "Dual Nature of Radiation",
            "Atoms", "Nuclei", "Semiconductor Electronics",
        ],
    },
    "Chemistry": {
        10: [
            "Chemical Reactions and Equations", "Acids, Bases and Salts",
            "Metals and Non-metals", "Carbon and Its Compounds",
            "Life Processes", "Control and Coordination",
            "How do Organisms Reproduce", "Heredity and Evolution",
        ],
        12: [
            "The Solid State", "Solutions", "Electrochemistry",
            "Chemical Kinetics", "Surface Chemistry",
            "The p-Block Elements", "The d- and f-Block Elements",
            "Coordination Compounds", "Haloalkanes and Haloarenes",
            "Alcohols, Phenols and Ethers", "Aldehydes, Ketones and Carboxylic Acids",
            "Amines", "Biomolecules", "Polymers", "Chemistry in Everyday Life",
        ],
    },
    "Biology": {
        10: [
            "Life Processes", "Control and Coordination",
            "How do Organisms Reproduce", "Heredity and Evolution",
            "Our Environment", "Sustainable Management of Natural Resources",
        ],
        12: [
            "Reproduction in Organisms", "Sexual Reproduction in Flowering Plants",
            "Human Reproduction", "Reproductive Health",
            "Principles of Inheritance and Variation",
            "Molecular Basis of Inheritance",
            "Evolution", "Human Health and Disease",
            "Strategies for Enhancement in Food Production",
            "Microbes in Human Welfare",
            "Biotechnology: Principles and Processes",
            "Biotechnology and Its Applications",
            "Organisms and Populations",
            "Ecosystem", "Biodiversity and Conservation",
            "Environmental Issues",
        ],
    },
    "Social Science": {
        10: [
            "The Rise of Nationalism in Europe", "Nationalism in India",
            "The Making of a Global World", "The Age of Industrialisation",
            "Print Culture and the Modern World",
            "Resources and Development", "Forest and Wildlife Resources",
            "Water Resources", "Agriculture", "Minerals and Energy Resources",
            "Manufacturing Industries", "Lifelines of National Economy",
            "Power Sharing", "Federalism", "Democracy and Diversity",
            "Gender, Religion and Caste", "Political Parties",
            "Outcomes of Democracy",
            "Development", "Sectors of the Indian Economy",
            "Money and Credit", "Globalisation and the Indian Economy",
            "Consumer Rights",
        ],
    },
    "English": {
        10: [
            "A Letter to God", "Nelson Mandela: Long Walk to Freedom",
            "Two Stories about Flying", "From the Diary of Anne Frank",
            "The Hundred Dresses I", "Glimpses of India",
            "Mijbil the Otter", "Madam Rides the Bus",
            "The Sermon at Benares", "The Proposal",
            "Dust of Snow", "Fire and Ice", "A Tiger in the Zoo",
            "How to Tell Wild Animals", "The Ball Poem",
            "Amanda!", "Animals", "The Tale of Custard the Dragon",
            "For Anne Gregory",
        ],
    },
    "Hindi": {
        10: [
            "सूरदास", "तुलसीदास", "देव", "जयशंकर प्रसाद",
            "सविता सिंह", "हबीब तनवीर", "सीताराम सेकसरिया",
            "नागार्जुन", "प्रेमचंद", "महावीर प्रसाद द्विवेदी",
        ],
    },
}

difficulty_levels = {
    "easy": {
        "question_templates": [
            "What is the value of {formula}?",
            "Define {concept}.",
            "Name the {item}.",
            "State the formula for {topic}.",
            "What is the SI unit of {quantity}?",
        ],
        "bloom_level": "Remember",
        "time_per_question": 60,
    },
    "medium": {
        "question_templates": [
            "Explain the process of {process} with a diagram.",
            "Differentiate between {concept1} and {concept2}.",
            "Solve: {problem}. Show all steps.",
            "What are the applications of {concept}?",
            "Compare {item1} and {item2}.",
        ],
        "bloom_level": "Understand/Apply",
        "time_per_question": 120,
    },
    "hard": {
        "question_templates": [
            "Derive the expression for {formula} from first principles.",
            "Analyze the given scenario and explain using {concept}.",
            "Evaluate the effectiveness of {method} in {context}.",
            "Design an experiment to verify {principle}.",
            "Critically examine the relationship between {concept1} and {concept2}.",
        ],
        "bloom_level": "Analyze/Evaluate/Create",
        "time_per_question": 180,
    },
}

motivational_quotes = [
    ("Success is not final, failure is not fatal: it is the courage to continue that counts.", "Winston Churchill"),
    ("बहुत हुआ अब और नहीं, अब तो कुछ कर दिखा।", "Motivation"),
    ("The only way to do great work is to love what you do.", "Steve Jobs"),
    ("शिक्षा सबसे अच्छी मित्र है।", "डॉ. ए.पी.जे. अब्दुल कलाम"),
    ("In the middle of difficulty lies opportunity.", "Albert Einstein"),
    ("ज्ञान ही शक्ति है।", "फ्रांसिस बेकन"),
    ("Don't watch the clock; do what it does. Keep going.", "Sam Levenson"),
    ("सपने वो नहीं जो नींद में आएं, सपने वो हैं जो नींद न आने दें।", "अब्दुल कलाम"),
    ("The expert in anything was once a beginner.", "Helen Hayes"),
    ("पढ़ोगे लिखोगे बनेंगे नवाब, खेलोगे कूदोगे होंगे खराब।", "कहावत"),
    ("Education is the passport to the future.", "Malcolm X"),
    ("मेहनत इतनी खामोशी से करो कि सफलता शोर मचा दे।", "Motivation"),
    ("The beautiful thing about learning is that nobody can take it away from you.", "B.B. King"),
    ("जो लोग कहते हैं कि यह असंभव है, उन्हें उन लोगों से नहीं मिलना चाहिए जो इसे कर रहे हैं।", "Motivation"),
    ("Success usually comes to those who are too busy to be looking for it.", "Henry David Thoreau"),
    ("सफलता हमारा परिचय दुनिया को करवाती है, और असफलता हमें दुनिया से।", "Motivation"),
    ("The only limit to our realization of tomorrow is our doubts of today.", "Franklin D. Roosevelt"),
    ("कठिनाइयां इसलिए आती हैं ताकि आप उन्हें पार करने के लिए मजबूत बनें।", "Motivation"),
    ("It does not matter how slowly you go as long as you do not stop.", "Confucius"),
    ("पढ़ाई का फल मीठा होता है।", "कहावत"),
    ("Believe you can and you're halfway there.", "Theodore Roosevelt"),
    ("जीतने वाले कभी हार नहीं मानते और हार मानने वाले कभी जीतते नहीं।", "Motivation"),
    ("The future belongs to those who believe in the beauty of their dreams.", "Eleanor Roosevelt"),
    ("सफलता एक यात्रा है, मंजिल नहीं।", "Motivation"),
    ("It always seems impossible until it's done.", "Nelson Mandela"),
    ("ज्ञान बांटने से बढ़ता है।", "कहावत"),
    ("Start where you are. Use what you have. Do what you can.", "Arthur Ashe"),
    ("शिक्षा का उद्देश्य ज्ञान नहीं, व्यक्तित्व का निर्माण है।", "Motivation"),
    ("The roots of education are bitter, but the fruit is sweet.", "Aristotle"),
    ("जो खुद पर विश्वास करता है, वो कुछ भी हासिल कर सकता है।", "Motivation"),
    ("Innovation distinguishes between a leader and a follower.", "Steve Jobs"),
    ("परिश्रम का फल मीठा होता है।", "कहावत"),
    ("Your time is limited, don't waste it living someone else's life.", "Steve Jobs"),
    ("हार वही होता है जो मान ले।", "Motivation"),
    ("The way to get started is to quit talking and begin doing.", "Walt Disney"),
    ("सफल लोग वो हैं जो जिज्ञासा के साथ सीखते रहते हैं।", "Motivation"),
    ("If you look at what you have in life, you'll always have more.", "Oprah Winfrey"),
    ("कोशिश करने वालों की कभी हार नहीं होती।", "Motivation"),
    ("Life is what happens when you're busy making other plans.", "John Lennon"),
    ("हर दिन एक नया मौका है खुद को बदलने का।", "Motivation"),
    ("The greatest glory in living lies not in never falling, but in rising every time we fall.", "Nelson Mandela"),
    ("पढ़ाई में मजा तब आता है जब तुम उसे समझते हो।", "Motivation"),
    ("Get busy living or get busy dying.", "Stephen King"),
    ("सपना वो नहीं जो तुम सोते हुए देखो, सपना वो है जो तुम्हें सोने न दे।", "Motivation"),
    ("You miss 100% of the shots you don't take.", "Wayne Gretzky"),
    ("बड़ा बनने के लिए बड़ी सोच ज़रूरी है।", "Motivation"),
    ("Strive not to be a success, but rather to be of value.", "Albert Einstein"),
    ("जीत उसी की होती है जो हिम्मत नहीं हारता।", "Motivation"),
    ("Two things are infinite: the universe and human stupidity; and I'm not sure about the universe.", "Albert Einstein"),
]


question_banks = {
    "Mathematics": {
        10: {
            "Polynomials": [
                {"q": "What is the degree of polynomial p(x) = 4x³ + 3x² + 2x + 1?", "opts": ["1", "2", "3", "4"], "ans": 2},
                {"q": "If p(x) = x² - 5x + 6, find p(2).", "opts": ["0", "1", "2", "-1"], "ans": 0},
                {"q": "The zeroes of x² - 5x + 6 are:", "opts": ["2, 3", "1, 6", "-2, -3", "1, 5"], "ans": 0},
                {"q": "What is the sum of zeroes of x² - 7x + 12?", "opts": ["7", "-7", "12", "-12"], "ans": 0},
                {"q": "If one zero of 2x² + kx + 3 is 1, find k.", "opts": ["-5", "5", "-3", "3"], "ans": 0},
                {"q": "The number of zeroes of p(x) = x² - 1 is:", "opts": ["1", "2", "3", "0"], "ans": 1},
                {"q": "What is the product of zeroes of x² - 5x + 6?", "opts": ["5", "6", "-5", "-6"], "ans": 1},
                {"q": "If p(x) = x³ - 1, one factor is (x-1). What are the other factors?", "opts": ["x² + x + 1", "x² - x + 1", "x² + x - 1", "x² - x - 1"], "ans": 0},
            ],
            "Real Numbers": [
                {"q": "√2 is a/an _____ number.", "opts": ["Rational", "Irrational", "Integer", "Natural"], "ans": 1},
                {"q": "The decimal expansion of 7/8 is:", "opts": ["0.875", "0.885", "0.785", "0.775"], "ans": 0},
                {"q": "HCF of 12 and 18 is:", "opts": ["6", "12", "18", "36"], "ans": 0},
                {"q": "LCM of 4, 6, 8 is:", "opts": ["12", "24", "48", "8"], "ans": 1},
                {"q": "The product of a rational and irrational number is always:", "opts": ["Rational", "Irrational", "Integer", "Zero"], "ans": 1},
            ],
            "Triangles": [
                {"q": "In a right triangle, the hypotenuse is the:", "opts": ["Longest side", "Shortest side", "Middle side", "None"], "ans": 0},
                {"q": "If two sides of a triangle are 3 and 4, the third side must be:", "opts": ["Less than 7", "Greater than 7", "Equal to 7", "None"], "ans": 0},
                {"q": "AA similarity criterion states two triangles are similar if:", "opts": ["Two angles equal", "All angles equal", "Two sides proportional", "All sides equal"], "ans": 0},
                {"q": "The ratio of areas of two similar triangles is equal to:", "opts": ["Ratio of sides", "Square of ratio of sides", "Cube of ratio", "None"], "ans": 1},
            ],
            "Quadratic Equations": [
                {"q": "The quadratic formula is:", "opts": ["x = (-b ± √(b²-4ac))/2a", "x = (-b ± √(b²+4ac))/2a", "x = (b ± √(b²-4ac))/2a", "x = (-b ± √(b²-4ac))/a"], "ans": 0},
                {"q": "If discriminant D > 0, the equation has:", "opts": ["Two real roots", "One root", "No real roots", "Complex roots"], "ans": 0},
                {"q": "The roots of x² - 5x + 6 = 0 are:", "opts": ["2, 3", "1, 6", "-2, -3", "1, 5"], "ans": 0},
                {"q": "Sum of roots of ax² + bx + c = 0 is:", "opts": ["-b/a", "b/a", "-c/a", "c/a"], "ans": 0},
                {"q": "Product of roots of ax² + bx + c = 0 is:", "opts": ["c/a", "-c/a", "b/a", "-b/a"], "ans": 0},
            ],
            "Coordinate Geometry": [
                {"q": "The distance formula between (x₁,y₁) and (x₂,y₂) is:", "opts": ["√((x₂-x₁)²+(y₂-y₁)²)", "√((x₂+x₁)²+(y₂+y₁)²)", "|x₂-x₁|+|y₂-y₁|", "(x₂-x₁)²+(y₂-y₁)²"], "ans": 0},
                {"q": "The section formula for internal division in ratio m:n is:", "opts": ["((mx₂+nx₁)/(m+n), (my₂+ny₁)/(m+n))", "((mx₁+nx₂)/(m+n), (my₁+ny₂)/(m+n))", "((x₁+x₂)/2, (y₁+y₂)/2)", "((mx₁-nx₂)/(m-n), (my₁-ny₂)/(m-n))"], "ans": 0},
                {"q": "Midpoint of (2,3) and (4,7) is:", "opts": ["(3, 5)", "(6, 10)", "(2, 4)", "(4, 6)"], "ans": 0},
            ],
        },
        12: {
            "Matrices": [
                {"q": "If A is a 2×2 matrix and |A| = 0, then A is:", "opts": ["Singular", "Non-singular", "Identity", "Diagonal"], "ans": 0},
                {"q": "(AB)' = ?", "opts": ["B'A'", "A'B'", "AB", "BA"], "ans": 0},
                {"q": "For a symmetric matrix, A' = ?", "opts": ["A", "-A", "A²", "I"], "ans": 0},
                {"q": "The inverse of a matrix exists if:", "opts": ["Determinant ≠ 0", "Determinant = 0", "Matrix is square", "All elements are 1"], "ans": 0},
            ],
            "Calculus": [
                {"q": "d/dx(xⁿ) = ?", "opts": ["nxⁿ⁻¹", "nxⁿ", "xⁿ⁻¹", "n²xⁿ⁻¹"], "ans": 0},
                {"q": "∫xⁿdx = ?", "opts": ["xⁿ⁺¹/(n+1) + C", "nxⁿ⁻¹ + C", "xⁿ/n + C", "(n+1)xⁿ + C"], "ans": 0},
                {"q": "d/dx(sin x) = ?", "opts": ["cos x", "-cos x", "sin x", "-sin x"], "ans": 0},
                {"q": "∫cos x dx = ?", "opts": ["sin x + C", "-sin x + C", "cos x + C", "-cos x + C"], "ans": 0},
            ],
        },
    },
    "Physics": {
        10: {
            "Electricity": [
                {"q": "SI unit of resistance is:", "opts": ["Ohm", "Volt", "Ampere", "Watt"], "ans": 0},
                {"q": "V = IR is known as:", "opts": ["Ohm's Law", "Faraday's Law", "Kirchhoff's Law", "Newton's Law"], "ans": 0},
                {"q": "In series combination, total resistance is:", "opts": ["Sum of resistances", "Less than smallest", "Greater than largest", "Average"], "ans": 0},
                {"q": "Power dissipated in a resistor is:", "opts": ["I²R", "IR²", "I²/R", "R/I²"], "ans": 0},
                {"q": "1 kilowatt-hour = _____ Joules:", "opts": ["3.6 × 10⁶", "3.6 × 10⁵", "36 × 10⁵", "360 × 10⁵"], "ans": 0},
            ],
            "Light": [
                {"q": "Speed of light in vacuum is:", "opts": ["3 × 10⁸ m/s", "3 × 10⁶ m/s", "3 × 10¹⁰ m/s", "3 × 10⁵ m/s"], "ans": 0},
                {"q": "The refractive index of glass is approximately:", "opts": ["1.5", "1.0", "2.0", "0.5"], "ans": 0},
                {"q": "Convex lens is also called:", "opts": ["Converging lens", "Diverging lens", "Cylindrical lens", "None"], "ans": 0},
            ],
        },
        12: {
            "Electrostatics": [
                {"q": "Coulomb's law states force is proportional to:", "opts": ["q₁q₂/r²", "q₁q₂/r", "(q₁+q₂)/r²", "q₁q₂r²"], "ans": 0},
                {"q": "Electric field due to point charge is:", "opts": ["kq/r²", "kq/r", "kq²/r", "kr²/q"], "ans": 0},
                {"q": "The unit of electric flux is:", "opts": ["Nm²/C", "NC", "Nm/C", "C/m²"], "ans": 0},
            ],
        },
    },
    "Chemistry": {
        10: {
            "Chemical Reactions": [
                {"q": "Rusting of iron is a:", "opts": ["Slow oxidation", "Fast oxidation", "Decomposition", "Displacement"], "ans": 0},
                {"q": "Balancing is based on law of:", "opts": ["Conservation of mass", "Conservation of energy", "Constant proportions", "Multiple proportions"], "ans": 0},
                {"q": "An exothermic reaction:", "opts": ["Releases heat", "Absorbs heat", "No heat change", "Releases gas"], "ans": 0},
            ],
            "Carbon Compounds": [
                {"q": "General formula of alkane is:", "opts": ["CₙH₂ₙ₊₂", "CₙH₂ₙ", "CₙH₂ₙ₋₂", "CₙHₙ"], "ans": 0},
                {"q": "Ethanol reacts with sodium to produce:", "opts": ["Sodium ethoxide + H₂", "Ethyl acetate", "Acetic acid", "Ethene"], "ans": 0},
                {"q": "The functional group in ethanol is:", "opts": ["-OH", "-CHO", "-COOH", "-CO-"], "ans": 0},
            ],
        },
    },
    "Biology": {
        10: {
            "Life Processes": [
                {"q": "The process by which plants make food is:", "opts": ["Photosynthesis", "Respiration", "Transpiration", "Fermentation"], "ans": 0},
                {"q": "Digestion of starch begins in:", "opts": ["Mouth", "Stomach", "Small intestine", "Large intestine"], "ans": 0},
                {"q": "Hemoglobin is found in:", "opts": ["Red blood cells", "White blood cells", "Platelets", "Plasma"], "ans": 0},
            ],
        },
    },
    "Social Science": {
        10: {
            "Indian National Movement": [
                {"q": "Quit India Movement was launched in:", "opts": ["1942", "1940", "1944", "1930"], "ans": 0},
                {"q": "Jallianwala Bagh massacre occurred in:", "opts": ["Amritsar", "Delhi", "Lahore", "Chandigarh"], "ans": 0},
                {"q": "First Session of Indian National Congress was held at:", "opts": ["Bombay", "Calcutta", "Madras", "Delhi"], "ans": 0},
            ],
            "Economics": [
                {"q": "GDP stands for:", "opts": ["Gross Domestic Product", "General Domestic Product", "Gross Development Product", "General Development Product"], "ans": 0},
                {"q": "NREGA guarantees how many days of employment:", "opts": ["100", "150", "200", "50"], "ans": 0},
            ],
        },
    },
}

state_board_info = {
    "Maharashtra": {"board_name": "Maharashtra State Board", "medium": ["Marathi", "English", "Hindi"], "key_subjects": ["Marathi", "English", "Mathematics", "Science", "Social Science"]},
    "Uttar Pradesh": {"board_name": "UP Board (UPMSP)", "medium": ["Hindi", "English"], "key_subjects": ["Hindi", "English", "Mathematics", "Science", "Social Science"]},
    "Tamil Nadu": {"board_name": "Tamil Nadu State Board", "medium": ["Tamil", "English"], "key_subjects": ["Tamil", "English", "Mathematics", "Physics", "Chemistry", "Biology"]},
    "Karnataka": {"board_name": "Karnataka State Board", "medium": ["Kannada", "English"], "key_subjects": ["Kannada", "English", "Mathematics", "Science", "Social Science"]},
    "West Bengal": {"board_name": "West Bengal Board (WBBSE)", "medium": ["Bengali", "English"], "key_subjects": ["Bengali", "English", "Mathematics", "Physical Science", "Life Science"]},
    "Rajasthan": {"board_name": "Rajasthan Board (RBSE)", "medium": ["Hindi", "English"], "key_subjects": ["Hindi", "English", "Mathematics", "Science", "Social Science"]},
    "Gujarat": {"board_name": "Gujarat Board (GSEB)", "medium": ["Gujarati", "English"], "key_subjects": ["Gujarati", "English", "Mathematics", "Science", "Social Science"]},
    "Kerala": {"board_name": "Kerala State Board", "medium": ["Malayalam", "English"], "key_subjects": ["Malayalam", "English", "Mathematics", "Physics", "Chemistry", "Biology"]},
    "Andhra Pradesh": {"board_name": "Andhra Pradesh Board (BSEAP)", "medium": ["Telugu", "English"], "key_subjects": ["Telugu", "English", "Mathematics", "Physics", "Chemistry", "Biology"]},
    "Bihar": {"board_name": "Bihar Board (BSEB)", "medium": ["Hindi", "English"], "key_subjects": ["Hindi", "English", "Mathematics", "Science", "Social Science"]},
}
