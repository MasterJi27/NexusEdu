import random
import math
import hashlib
from typing import List, Dict, Any
from utils import (
    generate_id, get_timestamp, question_banks, subject_chapters,
    difficulty_levels, get_grade, calculate_accuracy,
)


def adaptive_quiz(subject: str, chapter: str, current_level: int) -> Dict[str, Any]:
    elo_rating = current_level
    bank = question_banks.get(subject, {}).get(10, {}).get(chapter, [])
    if not bank:
        bank = question_banks.get(subject, {}).get(10, {}).get("Real Numbers", [])
    if not bank:
        all_chapters = list(question_banks.get(subject, {}).get(10, {}).keys())
        if all_chapters:
            bank = question_banks[subject][10][all_chapters[0]]
    if not bank:
        bank = [{"q": f"Solve the {chapter} problem", "opts": ["A", "B", "C", "D"], "ans": 0}]
    if elo_rating < 400:
        difficulty = "easy"
        k_factor = 32
    elif elo_rating < 700:
        difficulty = "medium"
        k_factor = 24
    else:
        difficulty = "hard"
        k_factor = 16
    selected_questions = []
    for _ in range(min(5, len(bank))):
        q = random.choice(bank)
        selected_questions.append({
            "id": generate_id(),
            "text": q["q"],
            "options": q["opts"],
            "correct_index": q["ans"],
            "difficulty": difficulty,
            "chapter": chapter,
            "elo_weight": k_factor,
        })
    return {
        "role": "adaptive_quiz",
        "subject": subject,
        "chapter": chapter,
        "current_elo_rating": elo_rating,
        "difficulty_level": difficulty,
        "k_factor": k_factor,
        "questions": selected_questions,
        "total_questions": len(selected_questions),
        "adaptive_info": {
            "rating_thresholds": {"easy": "< 400", "medium": "400-700", "hard": "> 700"},
            "current_range": difficulty,
            "next_level_criteria": f"Answer {len(selected_questions)} out of {len(selected_questions)} correctly to advance",
        },
        "elo_formula": "New Rating = Old Rating + K × (Actual - Expected)",
        "instructions": [
            "Har question ka sahi jawab do",
            "Galat jawab pe rating giregi, sahi pe badhegi",
            "Difficulty automatically adjust hogi",
            "Har question ke baar rating update hogi",
        ],
        "timestamp": get_timestamp(),
    }


def update_elo_rating(old_rating: int, correct: bool, k_factor: int) -> int:
    expected = 1 / (1 + 10 ** ((500 - old_rating) / 400))
    actual = 1 if correct else 0
    new_rating = old_rating + k_factor * (actual - expected)
    return max(100, min(1500, int(new_rating)))


def voice_viva(subject: str, chapter: str, round_num: int) -> Dict[str, Any]:
    viva_questions = {
        "Physics": {
            1: [
                {"q": "Ohm's Law kya hai? Iska mathematical form batao.", "expected": "V = IR. Voltage current ke proportional hota hai jab resistance constant ho.", "marks": 5},
                {"q": "Newton's Three Laws of Motion explain karo with examples.", "expected": "1. Inertia law, 2. F=ma, 3. Action-Reaction. Har law ka real-life example do.", "marks": 10},
                {"q": "Light ka wavelength range kya hai visible spectrum mein?", "expected": "400nm se 700nm tak. Violet se Red tak.", "marks": 5},
            ],
            2: [
                {"q": "Electromagnetic induction kya hai? Faraday's law explain karo.", "expected": "Changing magnetic flux se EMF induced hota hai. ε = -dΦ/dt.", "marks": 10},
                {"q": "AC aur DC mein kya difference hai?", "expected": "AC direction change hoti hai, DC ek direction mein. AC frequency 50Hz India mein.", "marks": 5},
                {"q": "Semiconductor ka kya matlab hai? P-type aur N-type explain karo.", "expected": "Conductivity insulator aur conductor ke beech. P-type mein holes majority carriers.", "marks": 10},
            ],
        },
        "Chemistry": {
            1: [
                {"q": "Periodic Table ka structure explain karo. Periods aur Groups kya hain?", "expected": "Horizontal rows = Periods (7), Vertical columns = Groups (18). Properties periodic fashion mein repeat hoti hain.", "marks": 5},
                {"q": "Chemical bonding ke types batao.", "expected": "Ionic, Covalent, Metallic bonding. Electronegativity difference se determine hota hai.", "marks": 10},
                {"q": "pH scale kya hai? 7 se kam aur zyada ka kya matlab hai?", "expected": "pH = -log[H+]. 7 se kam = acidic, 7 se zyada = basic, 7 = neutral.", "marks": 5},
            ],
            2: [
                {"q": "Organic Chemistry mein functional groups ke examples do.", "expected": "-OH (Alcohol), -CHO (Aldehyde), -COOH (Carboxylic acid), -NH2 (Amine).", "marks": 10},
                {"q": "Reaction kinetics mein order kya hai?", "expected": "Rate law mein reactants ke exponents ka sum. Zero, first, second order reactions.", "marks": 10},
            ],
        },
        "Biology": {
            1: [
                {"q": "Cell ka structure explain karo with labeled diagram.", "expected": "Cell membrane, cytoplasm, nucleus, mitochondria, ER, Golgi apparatus.", "marks": 10},
                {"q": "Photosynthesis ka process step-by-step explain karo.", "expected": "Light reactions (thylakoid) → Calvin cycle (stroma). 6CO2 + 6H2O → C6H12O6 + 6O2.", "marks": 10},
            ],
        },
    }
    subject_q = viva_questions.get(subject, viva_questions.get("Physics", {}))
    round_q = subject_q.get(round_num, subject_q.get(1, [{"q": f"{chapter} ke baare mein batao", "expected": f"{chapter} ek important topic hai", "marks": 5}]))
    selected = random.sample(round_q, min(3, len(round_q)))
    return {
        "role": "voice_viva",
        "subject": subject,
        "chapter": chapter,
        "round": round_num,
        "questions": [
            {
                "id": i + 1,
                "question": q["q"],
                "expected_answer": q["expected"],
                "marks": q["marks"],
                "tips": [
                    "Answer clear aur concise mein do",
                    "Examples do jab possible ho",
                    "Confidence se bolo, hesitation nahi",
                ],
            }
            for i, q in enumerate(selected)
        ],
        "total_marks": sum(q["marks"] for q in selected),
        "viva_tips": [
            "Eye contact rakho (camera ke saath virtual mein)",
            "Answer start karo definition se",
            "Agar nahi aata toh politely bolo 'I'll need to review this'",
            "Thank you bolo end mein",
        ],
        "timestamp": get_timestamp(),
    }


def essay_evaluator(text: str, subject: str) -> Dict[str, Any]:
    word_count = len(text.split())
    sentences = [s.strip() for s in text.replace("!", ".").replace("?", ".").split(".") if s.strip()]
    sentence_count = len(sentences)
    avg_sentence_length = word_count / max(sentence_count, 1)
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    paragraph_count = max(1, len(paragraphs))
    vocabulary_words = set(text.lower().split())
    vocabulary_score = min(100, len(vocabulary_words) * 2)
    unique_ratio = len(vocabulary_words) / max(word_count, 1)
    transition_words = [
        "however", "therefore", "furthermore", "moreover", "in addition",
        "consequently", "nevertheless", "on the other hand", "for example",
        "in conclusion", "to summarize", "firstly", "secondly", "finally",
    ]
    transition_count = sum(1 for tw in transition_words if tw in text.lower())
    has_introduction = any(word in text.lower()[:200] for word in ["introduction", "today", "this essay", "in this"])
    has_conclusion = any(word in text.lower()[-300:] for word in ["conclusion", "therefore", "thus", "in conclusion", "to sum up"])
    simple_words = ["good", "bad", "nice", "big", "small", "happy", "sad"]
    sophistication_score = max(0, 100 - sum(text.lower().count(w) * 5 for w in simple_words))
    subject_relevance = {
        "Mathematics": ["theorem", "proof", "equation", "formula", "calculate", "derive"],
        "Physics": ["force", "energy", "law", "principle", "experiment", "velocity"],
        "Chemistry": ["reaction", "bond", "element", "compound", "solution", "acid"],
        "Biology": ["cell", "organism", "evolution", "protein", "gene", "ecosystem"],
        "English": ["literary", "metaphor", "theme", "character", "narrative", "symbolism"],
        "History": ["era", "dynasty", "revolution", "colonial", "independence", "movement"],
    }
    subject_terms = subject_relevance.get(subject, subject_relevance["English"])
    subject_count = sum(1 for term in subject_terms if term in text.lower())
    subject_score = min(100, subject_count * 15 + 30)
    structure_score = 0
    if has_introduction:
        structure_score += 30
    if has_conclusion:
        structure_score += 30
    if paragraph_count >= 3:
        structure_score += 20
    if transition_count >= 3:
        structure_score += 20
    structure_score = min(100, structure_score)
    grammar_issues = []
    if text and text[0].islower():
        grammar_issues.append("Sentence should start with capital letter")
    if "  " in text:
        grammar_issues.append("Multiple spaces detected")
    issues_count = len(grammar_issues)
    grammar_score = max(0, 100 - issues_count * 10)
    argument_score = min(100, (transition_count * 10 + subject_count * 8 + paragraph_count * 5))
    overall = int(
        0.25 * structure_score +
        0.20 * vocabulary_score +
        0.20 * grammar_score +
        0.20 * argument_score +
        0.15 * subject_score
    )
    return {
        "role": "essay_evaluator",
        "subject": subject,
        "overall_score": overall,
        "grade": get_grade(overall),
        "breakdown": {
            "structure": {"score": structure_score, "feedback": "Introduction and conclusion check kiya, paragraph organization dekha"},
            "vocabulary": {"score": vocabulary_score, "feedback": f"{len(vocabulary_words)} unique words use kiye. Unique ratio: {unique_ratio:.2f}"},
            "grammar": {"score": grammar_score, "feedback": f"{issues_count} issues found" if grammar_issues else "No major grammar issues"},
            "arguments": {"score": argument_score, "feedback": f"{transition_count} transition words, {subject_count} subject-specific terms"},
            "subject_relevance": {"score": subject_score, "feedback": f"{subject_count} relevant terms found for {subject}"},
        },
        "stats": {
            "word_count": word_count,
            "sentence_count": sentence_count,
            "paragraph_count": paragraph_count,
            "avg_sentence_length": round(avg_sentence_length, 1),
            "vocabulary_richness": round(unique_ratio, 2),
        },
        "improvement_suggestions": [
            "Add more transition words for better flow" if transition_count < 5 else "Good use of transitions",
            "Include more subject-specific terminology" if subject_count < 3 else "Good subject integration",
            "Work on paragraph structure" if paragraph_count < 3 else "Good paragraph organization",
            f"Aim for {max(300, word_count + 100)} words for better depth" if word_count < 300 else "Good word count",
        ],
        "grammar_issues": grammar_issues,
        "timestamp": get_timestamp(),
    }


def speed_math(operation: str, range_min: int, range_max: int, count: int) -> Dict[str, Any]:
    problems = []
    for _ in range(count):
        a = random.randint(range_min, range_max)
        b = random.randint(range_min, range_max)
        if operation == "add":
            problem = f"{a} + {b}"
            answer = a + b
        elif operation == "subtract":
            a, b = max(a, b), min(a, b)
            problem = f"{a} - {b}"
            answer = a - b
        elif operation == "multiply":
            a = random.randint(2, 20)
            b = random.randint(2, 20)
            problem = f"{a} × {b}"
            answer = a * b
        elif operation == "divide":
            b = random.randint(2, 15)
            answer = random.randint(2, 20)
            a = b * answer
            problem = f"{a} ÷ {b}"
        elif operation == "square":
            a = random.randint(2, 30)
            problem = f"{a}²"
            answer = a * a
        elif operation == "percentage":
            a = random.randint(10, 500)
            b = random.choice([10, 15, 20, 25, 30, 40, 50, 75])
            problem = f"{b}% of {a}"
            answer = int(a * b / 100)
        else:
            problem = f"{a} + {b}"
            answer = a + b
        problems.append({
            "id": len(problems) + 1,
            "problem": problem,
            "answer": answer,
            "time_limit_seconds": max(10, 60 - (range_max // 10)),
        })
    return {
        "role": "speed_math",
        "operation": operation,
        "total_problems": count,
        "problems": problems,
        "difficulty": "Easy" if range_max <= 50 else "Medium" if range_max <= 200 else "Hard",
        "scoring": {
            "correct": f"+{10} points each",
            "speed_bonus": "Under 10 sec = +5 bonus points",
            "streak_bonus": "5 correct in a row = 2x points",
        },
        "instructions": [
            "Jaldi se solve karo, accuracy bhi zaroori hai",
            "Calculator mat use karo",
            "Mental math practice karo",
            "Time track karo improvement ke liye",
        ],
        "timestamp": get_timestamp(),
    }


def diagram_practice(description: str, expected_parts: List[str]) -> Dict[str, Any]:
    found_parts = []
    missing_parts = []
    incorrect_parts = []
    for part in expected_parts:
        if part.lower() in description.lower():
            found_parts.append({"part": part, "status": "correct"})
        else:
            missing_parts.append({"part": part, "status": "missing"})
    completeness = (len(found_parts) / max(len(expected_parts), 1)) * 100
    return {
        "role": "diagram_checker",
        "expected_parts": expected_parts,
        "user_description": description,
        "results": {
            "found": found_parts,
            "missing": missing_parts,
            "incorrect": incorrect_parts,
        },
        "completeness_percentage": round(completeness, 1),
        "grade": get_grade(completeness),
        "feedback": f"Aapne {len(found_parts)} out of {len(expected_parts)} parts correctly identify kiye.",
        "tips": [
            "Har part label karo clearly",
            "Arrow ya pointer use karo important parts ke liye",
            "Colors different parts ke liye use karo",
            "Scale aur dimensions include karo jab applicable ho",
            "Title zaroor likho diagram ke upar",
        ],
        "improvement_suggestions": [
            f"Missing parts practice karo: {', '.join(p['part'] for p in missing_parts)}" if missing_parts else "All parts covered! Great job!",
            "Labeling improve karo",
            "Neatness pe dhyan do",
        ],
        "timestamp": get_timestamp(),
    }


def concept_gap_detector(answers: List[Dict]) -> Dict[str, Any]:
    topic_scores = {}
    prerequisite_map = {
        "Quadratic Equations": ["Polynomials", "Linear Equations", "Factoring"],
        "Calculus": ["Limits", "Functions", "Trigonometry"],
        "Electromagnetism": ["Electricity", "Magnetism", "Force"],
        "Organic Chemistry": ["Chemical Bonding", "Hydrocarbons", "Functional Groups"],
        "Genetics": ["Cell Biology", "DNA Structure", "Mendelian Genetics"],
        "Thermodynamics": ["Heat", "Energy", "Work"],
        "Statistics": ["Mean", "Probability", "Data Analysis"],
        "Trigonometry": ["Ratios", "Right Triangles", "Identities"],
    }
    gaps = []
    for answer in answers:
        topic = answer.get("topic", "Unknown")
        correct = answer.get("correct", False)
        if topic not in topic_scores:
            topic_scores[topic] = {"correct": 0, "total": 0}
        topic_scores[topic]["total"] += 1
        if correct:
            topic_scores[topic]["correct"] += 1
    weak_topics = []
    for topic, scores in topic_scores.items():
        accuracy = (scores["correct"] / max(scores["total"], 1)) * 100
        if accuracy < 60:
            weak_topics.append({"topic": topic, "accuracy": accuracy, "level": "weak"})
        elif accuracy < 80:
            weak_topics.append({"topic": topic, "accuracy": accuracy, "level": "needs_review"})
        else:
            weak_topics.append({"topic": topic, "accuracy": accuracy, "level": "strong"})
    for wt in weak_topics:
        if wt["level"] in ["weak", "needs_review"]:
            prereqs = prerequisite_map.get(wt["topic"], ["Basic concepts", "Fundamentals"])
            gaps.append({
                "topic": wt["topic"],
                "accuracy": wt["accuracy"],
                "missing_prerequisites": prereqs,
                "recommendation": f"Pehle {', '.join(prereqs)} ache se padho, phir {wt['topic']} pe wapas aao",
            })
    return {
        "role": "concept_gap_detector",
        "total_answers": len(answers),
        "topic_scores": topic_scores,
        "weak_topics": weak_topics,
        "identified_gaps": gaps,
        "action_plan": [
            {"priority": "High", "topic": g["topic"], "action": g["recommendation"]}
            for g in gaps
        ],
        "study_suggestion": "Roz 30 min weak topics pe spend karo. Pehle prerequisites complete karo.",
        "timestamp": get_timestamp(),
    }


def mock_interview(field: str, experience: str, round_num: int) -> Dict[str, Any]:
    questions_by_round = {
        1: [
            {"q": "Tell me about yourself.", "type": "Introduction", "tips": "2 minute ka pitch: education, interests, goal"},
            {"q": f"Why are you interested in {field}?", "type": "Motivation", "tips": "Specific examples do, passion dikhao"},
            {"q": "What are your strengths and weaknesses?", "type": "Self-awareness", "tips": "Honest raho, weakness ke saath improvement plan bhi do"},
            {"q": "Where do you see yourself in 5 years?", "type": "Goal-setting", "tips": "Realistic goals, growth mindset"},
        ],
        2: [
            {"q": f"Describe a challenging project you worked on in {field}.", "type": "Experience", "tips": "STAR method use karo: Situation, Task, Action, Result"},
            {"q": "How do you handle pressure and deadlines?", "type": "Stress Management", "tips": "Real example do, positive outcome batao"},
            {"q": f"What technical skills do you have for {field}?", "type": "Technical", "tips": "Specific skills list karo with examples"},
            {"q": "Tell me about a time you failed. What did you learn?", "type": "Learning", "tips": "Honest mistake batao, learning emphasis karo"},
        ],
        3: [
            {"q": "Where do you see the future of {field}?", "type": "Industry Knowledge", "tips": "Current trends research karo, opinions banao"},
            {"q": "How would you handle a disagreement with a team member?", "type": "Teamwork", "tips": "Communication, empathy, professional approach"},
            {"q": "Do you have any questions for us?", "type": "Engagement", "tips": "Hamesha 2-3 thoughtful questions rakho"},
        ],
    }
    round_qs = questions_by_round.get(round_num, questions_by_round[1])
    return {
        "role": "mock_interview",
        "field": field,
        "experience": experience,
        "round": round_num,
        "questions": [
            {
                "id": i + 1,
                "question": q["q"],
                "type": q["type"],
                "tips": q["tips"],
                "sample_answer_approach": f"Start with context → Give specific example → Explain result → Show learning",
            }
            for i, q in enumerate(round_qs)
        ],
        "general_tips": [
            "Professional dress pehno (even virtual mein)",
            "Eye contact rakho",
            "Confident but polite raho",
            "Research karo company/college ke baare mein",
            "Thank you email bhejo after interview",
        ],
        "evaluation_criteria": {
            "communication": "Clarity, confidence, eye contact",
            "technical_knowledge": f"{field} ke concepts kitne strong hain",
            "problem_solving": "Approach to challenges",
            "cultural_fit": "Team dynamics mein fit honge ya nahi",
        },
        "timestamp": get_timestamp(),
    }


def plagiarism_checker(text: str) -> Dict[str, Any]:
    text_hash = hashlib.md5(text.encode()).hexdigest()
    text_length = len(text.split())
    unique_phrases = set()
    sentences = text.split(".")
    for s in sentences:
        words = s.strip().split()
        for i in range(len(words) - 3):
            phrase = " ".join(words[i:i+4])
            unique_phrases.add(phrase.lower())
    phrase_overlap = 0
    common_academic_phrases = [
        "in this essay", "it is important to note", "according to research",
        "as we can see", "in conclusion", "to sum up", "it has been proven",
        "studies show that", "evidence suggests", "furthermore",
    ]
    for phrase in common_academic_phrases:
        if phrase in text.lower():
            phrase_overlap += 1
    unique_ratio = len(unique_phrases) / max(text_length, 1)
    if unique_ratio > 0.8:
        similarity = random.uniform(2, 10)
    elif unique_ratio > 0.6:
        similarity = random.uniform(10, 25)
    else:
        similarity = random.uniform(25, 45)
    similarity += phrase_overlap * 2
    similarity = min(similarity, 100)
    return {
        "role": "plagiarism_checker",
        "text_hash": text_hash,
        "text_length_words": text_length,
        "results": {
            "similarity_percentage": round(similarity, 1),
            "verdict": "Original" if similarity < 15 else "Possibly Plagiarized" if similarity < 30 else "High Similarity Detected",
            "unique_phrases_found": len(unique_phrases),
            "academic_phrase_overlap": phrase_overlap,
        },
        "analysis": {
            "unique_content_ratio": round(unique_ratio, 2),
            "sentence_variety": len([s for s in sentences if len(s.split()) > 5]),
            "original_estimation": f"Approximately {100 - similarity:.0f}% appears to be original content",
        },
        "recommendations": [
            "Aur apne words mein likho" if similarity > 15 else "Content original lag raha hai",
            "Citations add karo agar borrowed ideas hain",
            "Paraphrasing improve karo",
            "Quote marks lagao jab directly quote karo",
        ],
        "disclaimer": "Ye estimate hai. Official plagiarism check ke liye Turnitin ya Grammarly use karo.",
        "timestamp": get_timestamp(),
    }


def spelling_grammar(text: str) -> Dict[str, Any]:
    errors = []
    common_misspellings = {
        "recieve": "receive", "occured": "occurred", "definately": "definitely",
        "seperate": "separate", "occurence": "occurrence", "begining": "beginning",
        "accomodate": "accommodate", "embarass": "embarrass", "goverment": "government",
        "independant": "independent", "maintainance": "maintenance", "neccessary": "necessary",
        "priviledge": "privilege", "wierd": "weird", "acheive": "achieve",
        "arguement": "argument", "commitee": "committee", "decieve": "deceive",
        "enviroment": "environment", "existance": "existence", "foriegn": "foreign",
        "happend": "happened", "immediatly": "immediately", "knowlege": "knowledge",
        "millenium": "millennium", "noticable": "noticeable", "persistant": "persistent",
        "occassion": "occasion", "publically": "publicly", "que": "queue",
        "refered": "referred", "relevent": "relevant", "tommorow": "tomorrow",
        "untill": "until", "withold": "withhold", "yeild": "yield",
    }
    text_lower = text.lower()
    for wrong, correct in common_misspellings.items():
        if wrong in text_lower:
            errors.append({
                "type": "Spelling",
                "error": wrong,
                "suggestion": correct,
                "position": text_lower.index(wrong),
            })
    grammar_patterns = {
        " their ": "they're/their/there confusion",
        " your ": "you're/your confusion",
        " its ": "it's/its confusion",
        " then ": "then/than confusion (if comparison)",
        " alot ": "a lot (two words)",
        " could of ": "could have (not could of)",
        " should of ": "should have (not should of)",
        " would of ": "would have (not would of)",
    }
    for pattern, issue in grammar_patterns.items():
        if pattern in text_lower:
            errors.append({
                "type": "Grammar",
                "error": pattern.strip(),
                "suggestion": issue,
                "position": text_lower.index(pattern),
            })
    sentences = [s.strip() for s in text.replace("!", ".").replace("?", ".").split(".") if s.strip()]
    for i, sentence in enumerate(sentences):
        if sentence and sentence[0].islower():
            errors.append({
                "type": "Capitalization",
                "error": f"Sentence {i+1} doesn't start with capital letter",
                "suggestion": f"Capitalize: '{sentence[0].upper()}{sentence[1:]}'",
                "position": text_lower.index(sentence[:10].lower()) if sentence[:10].lower() in text_lower else 0,
            })
    word_count = len(text.split())
    error_density = (len(errors) / max(word_count, 1)) * 1000
    return {
        "role": "spelling_grammar_checker",
        "text_length_words": word_count,
        "errors_found": len(errors),
        "errors": errors[:20],
        "error_density": f"{error_density:.1f} errors per 1000 words",
        "quality_score": max(0, min(100, 100 - len(errors) * 5)),
        "summary": {
            "spelling_errors": len([e for e in errors if e["type"] == "Spelling"]),
            "grammar_errors": len([e for e in errors if e["type"] == "Grammar"]),
            "capitalization_errors": len([e for e in errors if e["type"] == "Capitalization"]),
        },
        "suggestions": [
            "Grammarly ya LanguageTool use karo proofreading ke liye",
            "Read aloud karke errors pakdo",
            "Spell check enable karo writing apps mein",
            "Commonly confused words ki list yaad karo",
        ],
        "timestamp": get_timestamp(),
    }


def peer_comparison(scores: Dict, subject: str) -> Dict[str, Any]:
    user_scores = list(scores.values())
    user_avg = sum(user_scores) / max(len(user_scores), 1)
    class_avg = random.uniform(55, 70)
    class_std = random.uniform(10, 20)
    if user_avg > class_avg:
        percentile = min(99, int(50 + ((user_avg - class_avg) / class_std) * 20))
    else:
        percentile = max(1, int(50 - ((class_avg - user_avg) / class_std) * 20))
    rank_estimate = max(1, int((100 - percentile) * 0.5))
    return {
        "role": "peer_comparison",
        "subject": subject,
        "your_performance": {
            "average_score": round(user_avg, 1),
            "highest_score": max(user_scores),
            "lowest_score": min(user_scores),
            "total_tests": len(user_scores),
            "consistency": round(100 - (max(user_scores) - min(user_scores)), 1),
        },
        "class_benchmark": {
            "average_score": round(class_avg, 1),
            "standard_deviation": round(class_std, 1),
            "estimated_top_score": round(min(100, class_avg + 2 * class_std), 1),
            "estimated_bottom_score": round(max(0, class_avg - 2 * class_std), 1),
        },
        "comparison": {
            "percentile": percentile,
            "estimated_rank": f"Top {percentile}%",
            "relative_position": "Above Average" if user_avg > class_avg else "Average" if user_avg > class_avg - class_std else "Below Average",
            "difference_from_average": round(user_avg - class_avg, 1),
        },
        "subject_insights": {
            "strength": f"Aap class average se {abs(round(user_avg - class_avg, 1))} points {'upar' if user_avg > class_avg else 'neeche'} hain",
            "improvement_potential": f"Target: Top 10% banne ke liye {round(class_avg + 1.5 * class_std - user_avg, 1)} points aur chahiye" if percentile < 90 else "You're already in top 10%! Keep it up!",
        },
        "recommendations": [
            "Regular practice se consistency improve hogi" if max(user_scores) - min(user_scores) > 20 else "Good consistency!",
            f"Top performers se seekho - unka study method kya hai",
            "Mock tests regularly do aur analyze karo",
        ],
        "timestamp": get_timestamp(),
    }
