import random
import math
from typing import List, Dict, Any, Optional
from utils import (
    generate_id, get_timestamp, question_banks, subject_chapters,
    motivational_quotes, difficulty_levels, get_grade, calculate_accuracy,
)


def socratic_method(question: str, subject: str) -> Dict[str, Any]:
    prompts = {
        "Mathematics": [
            "Pehle sochiye, iska fundamental concept kya hai?",
            "Kya aap bata sakte hain ye formula kaise derive hota hai?",
            "Agar hum isko simple case mein dekhein, toh kya hota hai?",
            "Aap kya assumptions le rahe hain is problem mein?",
            "Kya aap isko doosre tarike se soch sakte hain?",
            "Iska reverse problem kya hoga?",
        ],
        "Physics": [
            "Ye phenomenon real life mein kahan dekhne ko milta hai?",
            "Agar hum koi parameter change karein, toh kya effect hoga?",
            "Iske peeche ka physical law kya hai?",
            "Kya aap isko everyday example se explain kar sakte hain?",
            "Agar gravity change ho jaye, toh ye kaise affect karega?",
        ],
        "Chemistry": [
            "Ye reaction kyun hoti hai? Thermodynamically favorable hai?",
            "Iska mechanism step-by-step kya hoga?",
            "Agar hum temperature badhaayein, toh kya hoga?",
            "Iska real-life application kya hai?",
            "Ye compound aur uske similar compound mein kya difference hai?",
        ],
        "Biology": [
            "Ye process evolutionary advantage kya deta hai?",
            "Agar ye process ruk jaye, toh kya hoga?",
            "Ye kisi dusre organism se kaise different hai?",
            "Iska cellular level par mechanism kya hai?",
            "Kya ye process reversible hai?",
        ],
        "Social Science": [
            "Is event ke multiple perspectives kya ho sakte hain?",
            "Ye event aaj ke context mein kaise relevant hai?",
            "Iske economic, social, aur political dimensions kya hain?",
            "Agar history mein ye event na hota, toh kya hota?",
            "Iska long-term impact kya raha hai?",
        ],
    }
    subject_prompts = prompts.get(subject, prompts["Mathematics"])
    selected = random.sample(subject_prompts, min(3, len(subject_prompts)))
    return {
        "role": "socratic_tutor",
        "original_question": question,
        "follow_up_questions": selected,
        "hint": f"Think about the core principle of {subject} involved here.",
        "encouragement": "Bilkul sahi direction mein soch rahe ho! Thoda aur deep socho.",
        "timestamp": get_timestamp(),
    }


def debate_agent(topic: str, user_position: str, round_num: int) -> Dict[str, Any]:
    counter_points = {
        "technology": [
            "Technology ke bina bhi scientific discoveries hui hain - Archimedes, Newton ne basic tools se kaam kiya.",
            "Technology access inequality creates digital divide, jo education gap aur badhaata hai.",
            "Over-reliance on technology se critical thinking skills kamzor hoti hain.",
        ],
        "education": [
            "Rote learning bhi kuch contexts mein effective hai - medical terminology, legal frameworks.",
            "Exam system flaws hain, but alternative systems bhi equally flawed hain.",
            "Traditional education ne successful leaders bhi banaye hain.",
        ],
        "environment": [
            "Economic development bhi equally important hai - garibhi khatam karna zaroori hai.",
            "Technology-driven solutions (nuclear, geo-engineering) bhi exist karti hain.",
            "Individual action se zyada systemic changes ki zaroorat hai.",
        ],
    }
    topic_key = "education"
    for key in counter_points:
        if key in topic.lower():
            topic_key = key
            break
    points = counter_points[topic_key]
    if round_num == 1:
        response = f"Interesting perspective! Main aapke viewpoint ko challenge karta hoon:\n\n{random.choice(points)}\n\nAap kya sochte hain is counter-argument ke baare mein? Kya aap apne position ko aur strengthen kar sakte hain?"
    elif round_num == 2:
        response = f"Achha point! Lekin consider kijiye:\n\n{random.choice(points)}\n\nIske alawa, historical evidence kya kehta hai is debate mein? Data aur real examples se apni baat rakhijiye."
    else:
        response = f"Final round! Aapne bahut acchi arguments diye. Meri taraf se:\n\n{random.choice(points)}\n\nAb dono taraf ke arguments summarize kijiye aur apna final verdict dijiye. Remember: Good debaters understand both sides!"

    return {
        "role": "debate_opponent",
        "topic": topic,
        "user_position": user_position,
        "round": round_num,
        "opponent_argument": response,
        "tips": ["Data use kijiye, opinions nahi", "Personal attacks mat kijiye", "Counter-argument ko respectfully address kijiye"],
        "score": random.randint(60, 95),
        "timestamp": get_timestamp(),
    }


def personalized_tutor(subject: str, weak_areas: List[str], learning_style: str) -> Dict[str, Any]:
    style_strategies = {
        "visual": {
            "method": "Diagrams, charts, aur color-coded notes use karenge.",
            "resources": ["Mind maps", "Flowcharts", "Video tutorials", "Infographics"],
            "tip": "Har concept ka diagram banayein. Visual memory sabse strong hoti hai.",
        },
        "auditory": {
            "method": "Audio notes, discussions, aur self-explanation technique use karenge.",
            "resources": ["Podcasts", "Recorded lectures", "Group discussions", "Read aloud"],
            "tip": "Concept ko kisi ko samjhao - jab aap kuch sunke padhte ho, zyada yaad rehta hai.",
        },
        "kinesthetic": {
            "method": "Hands-on experiments, models, aur real-life applications pe focus karenge.",
            "resources": ["Lab experiments", "Project-based learning", "Physical models", "Field trips"],
            "tip": "Har topic ka ek chhota project banao. Learning by doing is the best way!",
        },
        "reading": {
            "method": "Detailed notes, textbooks, aur written practice karenge.",
            "resources": ["NCERT textbooks", "Reference books", "Written summaries", "Flashcards"],
            "tip": "Notes banao aur revise karo. Writing se memory strong hoti hai.",
        },
    }
    strategy = style_strategies.get(learning_style, style_strategies["visual"])
    study_plan = []
    for area in weak_areas[:5]:
        study_plan.append({
            "topic": area,
            "priority": "High" if area in weak_areas[:2] else "Medium",
            "strategy": strategy["method"],
            "estimated_time": f"{random.randint(30, 120)} minutes",
            "practice_questions": random.randint(5, 15),
            "milestone": f"{area} master karne ke baad quiz dena hai",
        })
    return {
        "role": "personalized_tutor",
        "subject": subject,
        "learning_style": learning_style,
        "strategy": strategy,
        "weak_areas": weak_areas,
        "study_plan": study_plan,
        "daily_schedule": {
            "morning": "New concepts padho (fresh mind)",
            "afternoon": "Practice questions karo",
            "evening": "Revision aur weak topics pe kaam",
            "night": "Formula revision aur light reading",
        },
        "motivation": random.choice(motivational_quotes)[0],
        "timestamp": get_timestamp(),
    }


def anxiety_coach(message: str) -> Dict[str, Any]:
    stress_keywords = [
        "stress", "anxiety", "nervous", "panic", "worried", "tension",
        "exam", "fear", "fail", "pressure", "overwhelmed", "exhausted",
        "stressed", "anxious", "nervous", "scared", "terrified",
        "टेंशन", "घबराहट", "डर", "प्रेशर", "परेशान",
    ]
    stress_level = sum(1 for kw in stress_keywords if kw in message.lower())
    if stress_level >= 3:
        severity = "high"
        response = "Main samajh sakta hoon ki aap bahut stressed hain. Pehle ek deep breath lijiye - 4 seconds andar, 7 seconds hold, 8 seconds bahar. Ye 7-11 breathing technique hai. Aap akele nahi hain - har student ye feel karta hai. Chaliye ek plan banate hain:"
    elif stress_level >= 1:
        severity = "medium"
        response = "Lagta hai thoda tension ho raha hai. Ye bilkul normal hai! Exam se pehle sabko hota hai. Ye sign hai ki aap care karte ho. Chaliye isko positive energy mein convert karte hain:"
    else:
        severity = "low"
        response = "Aap kaafi calm lag rahe hain! That's great. Ye maintain karte rahiye. Positive mindset se better performance hoti hai."

    techniques = [
        {"name": "Box Breathing", "duration": "5 min", "instruction": "4 sec inhale, 4 sec hold, 4 sec exhale, 4 sec hold. Repeat 5 times."},
        {"name": "Progressive Muscle Relaxation", "duration": "10 min", "instruction": "Pair se start karke upar jayein - 5 sec tense, 10 sec relax."},
        {"name": "5-4-3-2-1 Grounding", "duration": "3 min", "instruction": "5 cheezein dekho, 4 suno, 3 chho, 2 soongho, 1 taste."},
        {"name": "Positive Visualization", "duration": "5 min", "instruction": "Aankhein band karo, exam hall mein successful hone ka visualization karo."},
        {"name": "Quick Walk", "duration": "10 min", "instruction": "Bahar jao, brisk walk karo. Fresh air se brain reset hota hai."},
    ]
    selected_techniques = random.sample(techniques, min(3, len(techniques)))
    return {
        "role": "anxiety_coach",
        "severity": severity,
        "response": response,
        "techniques": selected_techniques,
        "affirmations": [
            "Main capable hoon aur mehnat kar raha hoon.",
            "Ek exam meri poori zindagi define nahi karta.",
            "Main progress kar raha hoon, chahe dheere se.",
            "Har expert kabhi beginner tha.",
            "Mehnat rang laati hai, chahe deri se.",
        ],
        "emergency_note": "Agar anxiety bahut zyada ho toh kisi trusted adult se baat karo. Ye brave step hai, kamzori nahi.",
        "timestamp": get_timestamp(),
    }


def accountability_agent(study_log: List[Dict]) -> Dict[str, Any]:
    total_hours = sum(entry.get("hours", 0) for entry in study_log)
    topics_covered = len(set(entry.get("topic", "") for entry in study_log))
    subjects_covered = len(set(entry.get("subject", "") for entry in study_log))
    avg_hours = total_hours / max(len(study_log), 1)
    if total_hours < 5:
        status = "needs_improvement"
        nudge = "Aapka study time kaafi kam hai. Kya aap 30 min extra padh sakte hain aaj? Har minute counts!"
    elif total_hours < 15:
        status = "on_track"
        nudge = "Accha chal raha hai! Lekin aur improve kar sakte hain. Target hai 20 hours/week."
    else:
        status = "excellent"
        nudge = "Bahut badhiya! Aap consistent hain. Ye momentum maintain karo!"

    consistency_score = min(100, int((len(study_log) / 7) * 100))
    return {
        "role": "accountability_agent",
        "summary": {
            "total_study_hours": total_hours,
            "topics_covered": topics_covered,
            "subjects_covered": subjects_covered,
            "avg_hours_per_session": round(avg_hours, 1),
            "consistency_score": consistency_score,
        },
        "status": status,
        "nudge": nudge,
        "achievements": [
            "Study streak maintained!" if len(study_log) >= 3 else None,
            "Multi-subject coverage!" if subjects_covered >= 3 else None,
            "Deep dive sessions!" if avg_hours >= 2 else None,
        ],
        "next_goals": [
            f"Aaj ka target: {max(2, avg_hours + 0.5):.1f} hours padho",
            f"Kam se kam {max(2, topics_covered)} topics cover karo",
            "Ek weak topic pe special focus karo",
        ],
        "timestamp": get_timestamp(),
    }


def career_counselor(interests: List[str], marks: Dict[str, float], class_level: int) -> Dict[str, Any]:
    avg_stem = 0
    stem_subjects = ["Mathematics", "Physics", "Chemistry", "Biology", "Computer Science"]
    stem_marks = [marks.get(s, 0) for s in stem_subjects if s in marks]
    if stem_marks:
        avg_stem = sum(stem_marks) / len(stem_marks)
    avg_humanities = 0
    humanities_subjects = ["English", "History", "Economics", "Political Science", "Sociology"]
    hum_marks = [marks.get(s, 0) for s in humanities_subjects if s in marks]
    if hum_marks:
        avg_humanities = sum(hum_marks) / len(hum_marks)
    career_paths = []
    if avg_stem >= 80:
        career_paths.extend([
            {"career": "Engineering (IIT/NIT)", "entrance_exam": "JEE Main/Advanced", "colleges": ["IIT Bombay", "IIT Delhi", "NIT Trichy"], "required_score": "90+ percentile in JEE"},
            {"career": "Medicine (AIIMS)", "entrance_exam": "NEET", "colleges": ["AIIMS Delhi", "JIPMER", "CMC Vellore"], "required_score": "650+ in NEET"},
            {"career": "Research (IISc)", "entrance_exam": "KVPY/IISER Aptitude", "colleges": ["IISc Bangalore", "IISER Pune", "IISER Kolkata"], "required_score": "Top 1% in KVPY"},
        ])
    if "Computer Science" in interests or "Programming" in interests:
        career_paths.append({"career": "Computer Science Engineering", "entrance_exam": "JEE Main", "colleges": ["IIIT Hyderabad", "BITS Pilani", "VIT Vellore"], "required_score": "95+ percentile"})
    if avg_humanities >= 75:
        career_paths.extend([
            {"career": "Law (NLU)", "entrance_exam": "CLAT", "colleges": ["NLSIU Bangalore", "NALSAR Hyderabad", "NUJS Kolkata"], "required_score": "Top 500 in CLAT"},
            {"career": "Civil Services (IAS)", "entrance_exam": "UPSC CSE", "colleges": ["Any recognized university"], "required_score": "Graduation required"},
        ])
    if "Business" in interests or "Economics" in interests:
        career_paths.append({"career": "Management (IIM)", "entrance_exam": "CAT", "colleges": ["IIM Ahmedabad", "IIM Bangalore", "IIM Calcutta"], "required_score": "99+ percentile in CAT"})
    if not career_paths:
        career_paths = [
            {"career": "General Graduate + Competitive Exams", "entrance_exam": "Various", "colleges": ["Delhi University", "Mumbai University", "Bangalore University"], "required_score": "80%+ in boards"},
            {"career": "Diploma/Polytechnic", "entrance_exam": "State Polytechnic", "colleges": ["Government Polytechnics"], "required_score": "60%+ in 10th"},
        ]
    return {
        "role": "career_counselor",
        "profile_analysis": {
            "class_level": class_level,
            "strength_areas": [s for s, m in marks.items() if m >= 80],
            "improvement_areas": [s for s, m in marks.items() if m < 60],
            "interests": interests,
        },
        "recommended_careers": career_paths[:5],
        "action_plan": [
            f"Class {class_level} mein minimum {career_paths[0]['required_score']} target karo",
            "Entrance exam ki coaching join karo (online/offline)",
            "Regular mock tests do aur analyze karo",
            "Extracurricular activities mein participate karo",
            "Summer internships explore karo agar possible",
        ],
        "scholarship_info": [
            "NTA Scholarship for top performers",
            "State Government Merit Scholarships",
            "INSPIRE Scholarship (DST)",
            "Prime Minister Scholarship Scheme",
        ],
        "timestamp": get_timestamp(),
    }


def parent_report(student_data: Dict) -> Dict[str, Any]:
    subjects = student_data.get("subjects", {})
    total_tests = student_data.get("total_tests", 0)
    avg_score = student_data.get("average_score", 0)
    study_hours = student_data.get("weekly_study_hours", 0)
    strengths = [s for s, d in subjects.items() if d.get("avg", 0) >= 80]
    weaknesses = [s for s, d in subjects.items() if d.get("avg", 0) < 60]
    improvement_needed = [s for s, d in subjects.items() if d.get("trend", "stable") == "declining"]
    return {
        "role": "parent_report",
        "report_period": "Weekly",
        "student_summary": {
            "overall_grade": get_grade(avg_score),
            "overall_percentage": avg_score,
            "total_tests_taken": total_tests,
            "weekly_study_hours": study_hours,
            "class_rank_estimate": f"Top {max(5, 100 - int(avg_score))}%",
        },
        "subject_performance": {
            subject: {
                "average": data.get("avg", 0),
                "highest": data.get("high", 0),
                "lowest": data.get("low", 0),
                "trend": data.get("trend", "stable"),
                "grade": get_grade(data.get("avg", 0)),
            }
            for subject, data in subjects.items()
        },
        "highlights": [
            f"Strong performance in: {', '.join(strengths)}" if strengths else "Consistent effort across all subjects",
            f"Average score: {avg_score}%",
            f"Studied {study_hours} hours this week",
        ],
        "concerns": [
            f"Needs improvement in: {', '.join(weaknesses)}" if weaknesses else "No major concerns",
            f"Declining performance in: {', '.join(improvement_needed)}" if improvement_needed else "Performance is stable",
        ],
        "recommendations": [
            "Daily 2-hour focused study sessions maintain karo",
            "Weak subjects ke liye extra 30 min/day allocate karo",
            "Weekly mock tests do progress track karne ke liye",
            "Phone/screen time limit karo study hours mein",
            "Regular breaks lo - Pomodoro technique use karo",
        ],
        "message_for_parents": "Bacche ke saath supportive rahein. Pressure kam rakhein lekin encourage karein. Regular check-ins karein but surveillance na karein.",
        "timestamp": get_timestamp(),
    }


def exam_strategy(exam: str, subjects: List[Dict], days_left: int) -> Dict[str, Any]:
    total_chapters = sum(s.get("total_chapters", 20) for s in subjects)
    completed = sum(s.get("completed", 0) for s in subjects)
    remaining = total_chapters - completed
    hours_per_day = min(12, max(4, 24 - days_left // 10))
    subject_priority = sorted(subjects, key=lambda x: x.get("weightage", 0), reverse=True)
    daily_plan = []
    for day in range(min(days_left, 30)):
        day_subjects = []
        for i, subj in enumerate(subject_priority):
            if day % max(1, len(subject_priority)) == i % len(subject_priority):
                day_subjects.append({
                    "subject": subj["name"],
                    "hours": round(hours_per_day / len(subject_priority), 1),
                    "topics": f"Revise {random.randint(1, 3)} chapters from {subj['name']}",
                })
        daily_plan.append({
            "day": day + 1,
            "date": f"Day {day + 1}",
            "schedule": day_subjects,
            "total_hours": hours_per_day,
            "breaks": f"{hours_per_day // 2} breaks of 15 min each",
        })
    exam_tips = {
        "JEE": ["NCERT first, then reference books", "Formula sheet daily revise karo", "Previous year papers mandatory hain", "Time management practice karo"],
        "NEET": ["NCERT Biology is 85% of paper", "Diagrams aur labels yaad karo", "Weekly full-length mock test do", "Negative marking dhyan mein rakhkar attempt karo"],
        "CBSE Boards": ["NCERT line-by-line padho", "Previous year papers 10 saal ke solve karo", "Diagrams aur examples compulsory hain", "Presentation skills improve karo"],
        "ICSE Boards": ["Textbooks ke examples important hain", "Literature section ke liye notes banao", "Internal assessment pe dhyan do", "Time management practice karo"],
        "UPSC": ["NCERTs as foundation padho", "Current affairs daily follow karo", "Optional subject pe 40% time do", "Answer writing practice daily karo"],
    }
    return {
        "role": "exam_strategist",
        "exam": exam,
        "days_left": days_left,
        "analysis": {
            "total_chapters": total_chapters,
            "completed": completed,
            "remaining": remaining,
            "completion_percentage": round((completed / max(total_chapters, 1)) * 100, 1),
        },
        "subject_priority": [
            {
                "subject": s["name"],
                "weightage": s.get("weightage", 20),
                "chapters_remaining": s.get("total_chapters", 20) - s.get("completed", 0),
                "priority": "High" if s.get("weightage", 0) >= 25 else "Medium",
            }
            for s in subject_priority
        ],
        "daily_plan": daily_plan[:7],
        "weekly_plan": {
            "week_1": "Complete remaining syllabus + weak areas",
            "week_2": "Full revision + practice papers",
            "week_3": "Mock tests + analysis",
            "week_4": "Light revision + formula sheets + rest",
        },
        "tips": exam_tips.get(exam, exam_tips["CBSE Boards"]),
        "time_management": {
            "study_hours_per_day": hours_per_day,
            "breaks": "After every 2 hours, 15 min break",
            "sleep": "Minimum 7 hours sleep zaroori hai",
            "exercise": "30 min daily exercise keeps brain sharp",
        },
        "timestamp": get_timestamp(),
    }


def multi_language_tutor(topic: str, language: str) -> Dict[str, Any]:
    translations = {
        "Hindi": {
            "greeting": "Namaste! Aaj hum {topic} ke baare mein padhenge.",
            "explanation": "{topic} ek important concept hai. Isko samajhne ke liye pehle basics clear karo.",
            "example": "Udaharan ke liye: ye bilkul waisa hai jaise {topic} real life mein kaam karta hai.",
            "summary": "Toh aaj humne {topic} ke baare mein padha. Yaad rakho, practice se master hote hain!",
        },
        "Tamil": {
            "greeting": "Vanakkam! Indru naam {topic} -ai paarka porom.",
            "explanation": "{topic} oru mukkiyamana karuthu. Idhai purindhu koollaga mudhalla aadhara karuthigalai theervu seiyungal.",
            "example": "Edharkkana eduththarkkaga: idhu {topic} nijatil ezhundhu seiyum vishayam pola.",
            "summary": "Aam, indru naam {topic} -ai patri paarkinom. Ninaiviruppil, payirchiyala MASTER aagalam!",
        },
        "Telugu": {
            "greeting": "Namaskaram! Ee roju manam {topic} gurinchi chuddam.",
            "explanation": "{topic} oka mukhyamaina concept. Deenni ardam cheskovadamiki mundu basics clear cheskondi.",
            "example": "Udaharanaki: idi {topic} real life lo ela panichestundo alauntundi.",
            "summary": "Kabatti ee roju manam {topic} gurinchi nerchukunnam. Gurtunchukondi, practice tho master avvachu!",
        },
        "Bengali": {
            "greeting": "Namaskar! Aaj amra {topic} niye porbo.",
            "explanation": "{topic} ekta gurutwopurna dharona. Eta bujhar jonno prothome basics porishkar koro.",
            "example": "Udaharonar jonno: eta {topic} real life-e kemon kaj kore tai.",
            "summary": "Toh aaj amra {topic} niye porlam. Mone rakho, practice kore MASTER hote hoy!",
        },
        "Marathi": {
            "greeting": "Namaskar! Aaj aamhi {topic} badal shikato.",
            "explanation": "{topic} he ek mahatvache concept aahe. Hya samajun ghyayla pudhil basics spashta kara.",
            "example": "Udaharanasathi: he {topic} real life madhe kasa kaam karto tase.",
            "summary": "Mhanun aaj aamhi {topic} badal shiklo. Lakshat theva, practice ne MASTER hoeta yet!",
        },
        "Kannada": {
            "greeting": "Namaskara! Indu naavu {topic} bagge odona.",
            "explanation": "{topic} ondu mukhyavada concept. Idannu arthmaadikolluvake modalu basics spashtapadisikolli.",
            "example": "Udaharanakke: idu {topic} real life-nalli heg kaadutte hange.",
            "summary": "Hagare indu naavu {topic} bagge odidvi. Gurtidtiri, practice inda MASTER agabahudu!",
        },
        "Gujarati": {
            "greeting": "Namaskar! Aaje apde {topic} vishye echiye.",
            "explanation": "{topic} ek mahatvapurn concept che. Ene samajva mate pehla basics clear karo.",
            "example": "Udaharanarth: {topic} real life ma jeve kaam kare chhe teve.",
            "summary": "Toh aaje apde {topic} vishye vanchhiyo. Yaad rakho, practice thi MASTER thay!",
        },
    }
    lang_data = translations.get(language, translations["Hindi"])
    return {
        "role": "multi_language_tutor",
        "topic": topic,
        "language": language,
        "lesson": {
            "greeting": lang_data["greeting"].format(topic=topic),
            "explanation": lang_data["explanation"].format(topic=topic),
            "example": lang_data["example"].format(topic=topic),
            "summary": lang_data["summary"].format(topic=topic),
        },
        "key_vocabulary": [
            {"english": "Definition", "translated": f"{topic} ki paribhasha"},
            {"english": "Formula", "translated": f"{topic} ka formula"},
            {"english": "Example", "translated": f"{topic} ka udaharan"},
        ],
        "timestamp": get_timestamp(),
    }


def daily_challenge(subject: str, difficulty: str) -> Dict[str, Any]:
    challenge_templates = {
        "Mathematics": {
            "easy": [
                {"problem": f"Solve: {random.randint(10,50)} × {random.randint(2,9)} + {random.randint(5,20)}", "answer": "Use BODMAS"},
                {"problem": f"What is {random.randint(1,10)}² + {random.randint(1,10)}²?", "answer": "Calculate squares first, then add"},
            ],
            "medium": [
                {"problem": f"If f(x) = {random.randint(2,5)}x² + {random.randint(1,3)}x - {random.randint(1,5)}, find f({random.randint(1,3)})", "answer": "Substitute the value of x"},
                {"problem": f"Find the HCF of {random.randint(12,36)} and {random.randint(18,48)}", "answer": "Use Euclid's division algorithm"},
            ],
            "hard": [
                {"problem": f"Solve the system: {random.randint(1,3)}x + {random.randint(1,2)}y = {random.randint(5,15)}, x - y = {random.randint(1,5)}", "answer": "Use substitution or elimination method"},
                {"problem": f"Find the derivative of f(x) = {random.randint(2,5)}x³ - {random.randint(1,3)}x² + {random.randint(1,5)}x", "answer": "Apply power rule term by term"},
            ],
        },
        "Physics": {
            "easy": [
                {"problem": f"A car travels {random.randint(50,200)} km in {random.randint(2,5)} hours. Find its average speed.", "answer": "Speed = Distance / Time"},
                {"problem": f"A force of {random.randint(5,20)}N acts on a mass of {random.randint(2,10)}kg. Find acceleration.", "answer": "Use F = ma"},
            ],
            "medium": [
                {"problem": f"A ball is thrown upward with velocity {random.randint(10,30)} m/s. Find max height. (g = 10 m/s²)", "answer": "Use v² = u² - 2gh, at max height v = 0"},
                {"problem": f"Find resistance if V = {random.randint(5,20)}V and I = {random.randint(1,5)}A", "answer": "Use Ohm's law: R = V/I"},
            ],
            "hard": [
                {"problem": f"A body of mass {random.randint(1,5)}kg is projected at {random.randint(10,30)} m/s at {random.randint(30,60)}°. Find range.", "answer": "Use R = u²sin2θ/g"},
                {"problem": f"Two charges {random.randint(1,5)}μC and {random.randint(1,5)}μC are {random.randint(10,50)}cm apart. Find force.", "answer": "Use Coulomb's law: F = kq₁q₂/r²"},
            ],
        },
        "Chemistry": {
            "easy": [
                {"problem": f"Balance: Fe + O₂ → Fe₂O₃", "answer": "4Fe + 3O₂ → 2Fe₂O₃"},
                {"problem": f"Name the functional group in CH₃OH", "answer": "Hydroxyl group (-OH) - Alcohol"},
            ],
            "medium": [
                {"problem": f"Calculate pH of a solution with [H⁺] = {random.randint(1,9)} × 10⁻³ M", "answer": "pH = -log[H⁺]"},
                {"problem": f"Write the IUPAC name of CH₃CH₂COOH", "answer": "Propanoic acid"},
            ],
            "hard": [
                {"problem": f"Calculate the entropy change when {random.randint(1,5)} mol of ideal gas expands from V to 3V at constant T.", "answer": "ΔS = nR ln(V₂/V₁)"},
                {"problem": f"Determine the order of reaction if rate = k[A]²[B]", "answer": "Order = 2 + 1 = 3 (overall)"},
            ],
        },
    }
    subj_challenges = challenge_templates.get(subject, challenge_templates["Mathematics"])
    challenges = subj_challenges.get(difficulty, subj_challenges["medium"])
    selected = random.choice(challenges)
    return {
        "role": "daily_challenge",
        "subject": subject,
        "difficulty": difficulty,
        "challenge": selected["problem"],
        "hint": selected["answer"],
        "time_limit": f"{difficulty_levels[difficulty]['time_per_question']} seconds",
        "points": {"easy": 10, "medium": 25, "hard": 50}.get(difficulty, 25),
        "streak_bonus": "5 consecutive correct answers = 2x points!",
        "timestamp": get_timestamp(),
    }
