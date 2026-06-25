import random
import math
from typing import List, Dict, Any
from utils import generate_id, get_timestamp


def lab_simulator(experiment_type: str, parameters: Dict) -> Dict[str, Any]:
    experiments = {
        "ohms_law": {
            "title": "Ohm's Law Verification",
            "objective": "To verify the relationship V = IR and determine resistance",
            "materials": ["Ammeter", "Voltmeter", "Resistance wire", "Battery", "Connecting wires", "Rheostat"],
            "steps": [
                {"step": 1, "action": "Circuit diagram banao: Battery → Ammeter → Resistance → Rheostat → Battery", "observation": "Circuit ready"},
                {"step": 2, "action": "Rheostat ko maximum position pe rakho", "observation": "Current minimum hoga"},
                {"step": 3, "action": "Battery switch on karo aur current (I) aur voltage (V) note karo", "observation": "First set of readings"},
                {"step": 4, "action": "Rheostat change karo aur 5 alag readings lo", "observation": "Multiple V-I pairs"},
                {"step": 5, "action": "V vs I graph plot karo", "observation": "Straight line through origin"},
                {"step": 6, "action": "Graph ka slope calculate karo = Resistance (R)", "observation": f"R = slope ≈ {random.uniform(5, 20):.2f} Ω"},
            ],
            "expected_result": "V-I graph ek straight line dega jiska slope resistance hai. This verifies V ∝ I.",
            "precautions": ["Contact resistance avoid karo", "Readings carefully note karo", "Battery ka voltage fixed rakho"],
            "viva_questions": [
                {"q": "Agar V badhayein toh I kya hoga?", "a": "V badhne se I bhi badhega (V = IR)"},
                {"q": "Ye law kab apply nahi hota?", "a": "Non-ohmic devices pe (diode, bulb)"},
            ],
        },
        "pendulum": {
            "title": "Simple Pendulum - Time Period Investigation",
            "objective": "To study the relationship between length and time period of a pendulum",
            "materials": ["Pendulum bob", "String", "Stopwatch", "Meter scale", "Stand", "Protractor"],
            "steps": [
                {"step": 1, "action": "String ki length 50cm set karo", "observation": "L = 0.5m"},
                {"step": 2, "action": "Bob ko 10° se deflect karke chhodo", "observation": "Pendulum oscillate karega"},
                {"step": 3, "action": "20 oscillations ka time note karo", "observation": "T_total = time for 20 oscillations"},
                {"step": 4, "action": "Time period T = T_total / 20 calculate karo", "observation": f"T ≈ {2 * math.pi * math.sqrt(0.5 / 9.8):.3f} sec"},
                {"step": 5, "action": "Length 60cm, 70cm, 80cm, 90cm, 100cm ke liye repeat karo", "observation": "T increases with length"},
                {"step": 6, "action": "T² vs L graph plot karo", "observation": "Straight line - T² ∝ L"},
            ],
            "expected_result": f"T = 2π√(L/g). For L=1m, T ≈ {2 * math.pi * math.sqrt(1 / 9.8):.2f} seconds",
            "precautions": ["Small angle approximation use karo (<15°)", "Air resistance minimize karo", "Accurate timing ke liye 20 oscillations count karo"],
            "viva_questions": [
                {"q": "Mass se time period change hoga?", "a": "Nahi, T independent hai mass se"},
                {"q": "Gravity badhayein toh T kya hoga?", "a": "T kam ho jayega (T ∝ 1/√g)"},
            ],
        },
        "chemical_reaction": {
            "title": "Rate of Chemical Reaction",
            "objective": "To study effect of concentration on rate of reaction",
            "materials": ["Na₂S₂O₃ solution", "HCl", "Beakers", "Stopwatch", "White paper with cross mark", "Measuring cylinder"],
            "steps": [
                {"step": 1, "action": "50ml Na₂S₂O₃ (0.1M) beaker mein lo", "observation": "Solution ready"},
                {"step": 2, "action": "Beaker ke neeche white paper pe cross mark rakho", "observation": "Cross visible"},
                {"step": 3, "action": "10ml HCl add karo aur time start karo", "observation": "Reaction starts - solution turns milky"},
                {"step": 4, "action": "Jab cross completely invisible ho jaye, time note karo", "observation": f"Time ≈ {random.randint(30, 120)} seconds"},
                {"step": 5, "action": "Concentration change karke repeat karo (0.05M, 0.15M, 0.2M)", "observation": "Higher concentration = faster reaction"},
                {"step": 6, "action": "Rate vs Concentration graph plot karo", "observation": "Direct relationship"},
            ],
            "expected_result": "Rate ∝ Concentration. Jitna concentrated solution, utna fast reaction.",
            "precautions": ["Same temperature maintain karo", "Time accurately note karo", "Cross mark same size rakho"],
            "viva_questions": [
                {"q": "Temperature badhayein toh rate kya hoga?", "a": "Rate badhega - more kinetic energy"},
                {"q": "Catalyst lagayein toh kya hoga?", "a": "Rate badhega without catalyst being consumed"},
            ],
        },
    }
    exp = experiments.get(experiment_type, experiments["ohms_law"])
    return {
        "role": "lab_simulator",
        "experiment_type": experiment_type,
        "parameters": parameters,
        "experiment": exp,
        "virtual_lab_features": {
            "real_time_measurements": True,
            "error_simulation": True,
            "multiple_trials": True,
            "graph_generation": True,
        },
        "safety_notes": [
            "Virtual lab mein physical safety nahi chahiye, but real lab mein goggles pehno",
            "Chemicals ke saath proper handling karo",
            "Teacher supervision zaroori hai",
        ],
        "timestamp": get_timestamp(),
    }


def historical_travel(era: str, topic: str) -> Dict[str, Any]:
    dialogues = {
        "ancient_india": {
            "period": "3000 BCE - 500 CE",
            "character": "Chanakya (Kautilya)",
            "dialogue": f"Namaste! Main Chanakya hoon. Aapko {topic} ke baare mein jaanna hai? Main Arthashastra mein neeti aur rajniti ke baare mein likha hai. Kya aap jaanna chahte hain ki ek raja ko kaise rajya chalana chahiye?",
            "historical_context": "Ancient India mein Nalanda aur Takshashila jaise universities thi jahan duniya bhar se students aate the. Education kaafi structured thi.",
            "key_facts": [
                "Takshashila duniya ka pehla university mana jaata hai",
                "Vedas aur Upanishads ancient knowledge ke sources hain",
                "Zero aur decimal system India se aaya",
                "Ayurveda ancient medical science hai",
            ],
            "conversation_topics": ["Arthashastra", "Ancient education system", "Vedic period", "Maurya Empire"],
        },
        "medieval_india": {
            "period": "500 CE - 1700 CE",
            "character": "Akbar the Great",
            "dialogue": f"Main Akbar hoon! {topic} mein aapki ruchi hai? Mere darbar mein Birbal, Tansen aur Todar Mal the. Mene Din-i-Ilahi banaya aur sabhi dharmo ka samman kiya. Education ke liye mene maktab aur madrasa dono shuru kiye.",
            "historical_context": "Medieval India mein Mughal architecture, miniature paintings aur music ka bahut vikas hua. Sanskrit aur Farsi dono bhashaon mein padhai hoti thi.",
            "key_facts": [
                "Akbar ne 30% tax income education pe lagayi thi",
                "Hawa Mahal, Taj Mahal medieval architecture hain",
                "Bhakti movement ne sanskriti ko unite kiya",
                "Mughal-era manuscripts aaj bhi preserved hain",
            ],
            "conversation_topics": ["Mughal Empire", "Bhakti Movement", "Vijayanagara Empire", "Medieval science"],
        },
        "colonial_india": {
            "period": "1700 CE - 1947",
            "character": "Swami Vivekananda",
            "dialogue": f"Arise, awake and stop not till the goal is reached! {topic} ke baare mein baat karte hain. Main Chicago mein 1893 mein hinduism ka pratinidhitva kiya. Education se hi desh ki samasya ka hal niklega. Kya aap jaanna chahte hain independence movement mein students ki bhumika?",
            "historical_context": "Colonial period mein English education act (1835), universities act (1857) aur freedom struggle mein students ne major role play kiya.",
            "key_facts": [
                "1857 mein pehli universities bani - Mumbai, Kolkata, Chennai",
                "Lahore Resolution 1940 mein students ne support kiya",
                "Quit India Movement 1942 mein youth ne lead kiya",
                "Sarojini Naidu, Subhash Chandra Bose young leaders the",
            ],
            "conversation_topics": ["Freedom Struggle", "Social Reform", "Modern Education", "Nationalism"],
        },
    }
    period_data = dialogues.get(era, dialogues["ancient_india"])
    return {
        "role": "historical_travel",
        "era": era,
        "topic": topic,
        "time_period": period_data["period"],
        "character": period_data["character"],
        "dialogue": period_data["dialogue"],
        "historical_context": period_data["historical_context"],
        "key_facts": period_data["key_facts"],
        "conversation_topics": period_data["conversation_topics"],
        "learning_outcomes": [
            f"{era} ke {topic} ke baare mein samajh",
            "Historical perspectives develop karo",
            "Critical thinking: Past ko present se compare karo",
        ],
        "activity": f"Aap {period_data['character']} se mil rahe ho. Unse {topic} ke baare mein 3 sawaal pucho!",
        "timestamp": get_timestamp(),
    }


def science_explainer(image_description: str) -> Dict[str, Any]:
    concepts = {
        "rainbow": {
            "phenomenon": "Rainbow Formation",
            "explanation": "Rainbow tab banta hai jab sunlight water droplets se guzarti hai. Light ka refraction, reflection aur dispersion hota hai. White light 7 colors mein split hoti hai - VIBGYOR (Violet, Indigo, Blue, Green, Yellow, Orange, Red).",
            "principles": ["Refraction", "Total Internal Reflection", "Dispersion of Light"],
            "formula": "Snell's Law: n₁sin(θ₁) = n₂sin(θ₂)",
            "fun_fact": "Rainbow hamesha semi-circular hota hai aur aap hamesha sun ke opposite dekh sakte ho",
        },
        "shadow": {
            "phenomenon": "Shadow Formation",
            "explanation": "Shadow tab banta hai jab light kisi opaque object se block hoti hai. Light straight line mein travel karti hai (rectilinear propagation). Object ke peeche dark area banta hai - ye shadow hai.",
            "principles": ["Rectilinear Propagation of Light", "Umbra and Penumbra"],
            "formula": "Shadow size/Object size = (Distance from source + Object distance)/Object distance",
            "fun_fact": "Eclipse mein moon ki shadow earth pe girte hai - that's a massive shadow!",
        },
        "boiling_water": {
            "phenomenon": "Boiling of Water",
            "explanation": "Jab water 100°C pe heat hota hai, uski kinetic energy badhti hai. Molecules itna fast move karne lagte hain ki liquid se gas mein convert ho jaate hain. Bubbles bante hain kyunki water vapor pressure atmospheric pressure ke barabar ho jaata hai.",
            "principles": ["Heat Transfer", "Phase Change", "Vapor Pressure"],
            "formula": "Q = mL (Latent Heat)",
            "fun_fact": "High altitude pe water kam temperature pe沸腾 hota hai kyunki kam air pressure hai",
        },
        "rainbow": {
            "phenomenon": "Rainbow Formation",
            "explanation": "Sunlight water droplets se guzarti hai aur 7 colors mein split hoti hai due to dispersion. Har droplet ek mini prism ka kaam karta hai.",
            "principles": ["Refraction", "Dispersion", "Reflection"],
            "formula": "Deviation angle = 42° (for primary rainbow)",
            "fun_fact": "Double rainbow mein colors ulte hote hain!",
        },
    }
    desc_lower = image_description.lower()
    matched_concept = None
    for key in concepts:
        if key in desc_lower:
            matched_concept = concepts[key]
            break
    if not matched_concept:
        matched_concept = {
            "phenomenon": "Scientific Phenomenon",
            "explanation": f"Based on your description '{image_description}', this involves fundamental scientific principles. Light, gravity, friction, or energy conversion may be at play depending on the context.",
            "principles": ["Basic Physics", "Chemical Reactions", "Biological Processes"],
            "formula": "F = ma (if motion involved), E = mc² (if energy involved)",
            "fun_fact": "Everyday phenomena are governed by complex scientific laws!",
        }
    return {
        "role": "science_explainer",
        "image_description": image_description,
        "phenomenon": matched_concept["phenomenon"],
        "explanation": matched_concept["explanation"],
        "scientific_principles": matched_concept["principles"],
        "formula": matched_concept["formula"],
        "fun_fact": matched_concept["fun_fact"],
        "real_life_application": "Ye concept physics, chemistry aur engineering mein widely use hota hai.",
        "try_at_home": "Aap bhi iska chhota experiment ghar pe kar sakte ho!",
        "timestamp": get_timestamp(),
    }


def math_solver(problem: str) -> Dict[str, Any]:
    import re
    problem_lower = problem.lower()
    steps = []
    answer = None
    if any(op in problem for op in ['+', '-', '*', '×', '÷', '/']):
        numbers = re.findall(r'\d+\.?\d*', problem)
        if len(numbers) >= 2:
            a, b = float(numbers[0]), float(numbers[1])
            if '+' in problem or 'plus' in problem_lower or 'add' in problem_lower:
                answer = a + b
                steps = [
                    f"Step 1: Identify the operation - Addition (+)",
                    f"Step 2: Identify the numbers - {a} and {b}",
                    f"Step 3: Apply addition - {a} + {b}",
                    f"Step 4: Calculate - {a} + {b} = {answer}",
                    f"Answer: {a} + {b} = {answer}",
                ]
            elif '-' in problem or 'minus' in problem_lower or 'subtract' in problem_lower:
                answer = a - b
                steps = [
                    f"Step 1: Identify the operation - Subtraction (-)",
                    f"Step 2: Identify the numbers - {a} and {b}",
                    f"Step 3: Apply subtraction - {a} - {b}",
                    f"Step 4: Calculate - {a} - {b} = {answer}",
                    f"Answer: {a} - {b} = {answer}",
                ]
            elif '*' in problem or '×' in problem or 'multiply' in problem_lower or 'product' in problem_lower:
                answer = a * b
                steps = [
                    f"Step 1: Identify the operation - Multiplication (×)",
                    f"Step 2: Identify the numbers - {a} and {b}",
                    f"Step 3: Apply multiplication - {a} × {b}",
                    f"Step 4: Calculate - {a} × {b} = {answer}",
                    f"Answer: {a} × {b} = {answer}",
                ]
            elif '/' in problem or '÷' in problem or 'divide' in problem_lower:
                if b != 0:
                    answer = a / b
                    steps = [
                        f"Step 1: Identify the operation - Division (÷)",
                        f"Step 2: Identify the numbers - {a} and {b}",
                        f"Step 3: Apply division - {a} ÷ {b}",
                        f"Step 4: Calculate - {a} ÷ {b} = {answer}",
                        f"Answer: {a} ÷ {b} = {answer:.4f}",
                    ]
    if answer is None:
        steps = [
            "Step 1: Read the problem carefully",
            "Step 2: Identify what is given (knowns)",
            "Step 3: Identify what needs to be found (unknowns)",
            "Step 4: Choose the appropriate formula or method",
            "Step 5: Substitute values and solve step by step",
            "Step 6: Verify the answer makes logical sense",
            "Step 7: Write the final answer with units",
        ]
        answer = "Please provide the numerical values for exact calculation"
    return {
        "role": "math_solver",
        "problem": problem,
        "solution_steps": steps,
        "answer": answer,
        "method_used": "Step-by-step approach",
        "verification": "Always check: Does the answer make sense in context?",
        "similar_problems": [
            "Try solving similar problems with different numbers",
            "Practice the concept, not just the procedure",
        ],
        "timestamp": get_timestamp(),
    }


def writing_coach(text: str, genre: str) -> Dict[str, Any]:
    word_count = len(text.split())
    sentences = [s.strip() for s in text.replace("!", ".").replace("?", ".").split(".") if s.strip()]
    avg_sentence_length = word_count / max(len(sentences), 1)
    paragraphs = text.split("\n\n")
    has_hook = any(word in text[:100].lower() for word in ["did you know", "imagine", "what if", "in a world", "once upon"])
    has_thesis = any(phrase in text.lower() for phrase in ["this essay argues", "in this essay", "i believe", "it is clear that"])
    has_evidence = any(phrase in text.lower() for phrase in ["according to", "research shows", "studies indicate", "for example", "for instance"])
    has_counter = any(phrase in text.lower() for phrase in ["however", "on the other hand", "critics argue", "despite", "nevertheless"])
    has_conclusion = any(phrase in text.lower()[-300:] for phrase in ["in conclusion", "therefore", "thus", "to sum up", "ultimately"])
    structure_score = sum([has_hook * 15, has_thesis * 25, has_evidence * 25, has_counter * 15, has_conclusion * 20])
    transitions = ["firstly", "secondly", "furthermore", "moreover", "additionally", "consequently", "finally"]
    transition_count = sum(1 for t in transitions if t in text.lower())
    style_score = min(100, transition_count * 12 + (20 if avg_sentence_length < 25 else 0) + (15 if len(paragraphs) >= 4 else 0))
    genre_feedback = {
        "narrative": "Storytelling techniques use karo - dialogue, imagery, sensory details",
        "persuasive": "Strong thesis, evidence, counter-argument address karo",
        "expository": "Clear structure, examples, step-by-step explanation",
        "descriptive": "Sensory details, metaphors, vivid imagery use karo",
        "formal": "Formal tone maintain karo, passive voice appropriate hai",
        "creative": "Originality, imagination, literary devices use karo",
    }
    return {
        "role": "writing_coach",
        "genre": genre,
        "overall_score": round((structure_score + style_score) / 2, 1),
        "scores": {
            "structure": structure_score,
            "style": style_score,
            "vocabulary": min(100, len(set(text.lower().split())) * 2),
            "engagement": 70 if has_hook else 40,
        },
        "analysis": {
            "word_count": word_count,
            "sentence_count": len(sentences),
            "paragraph_count": len(paragraphs),
            "avg_sentence_length": round(avg_sentence_length, 1),
            "has_hook": has_hook,
            "has_thesis": has_thesis,
            "has_evidence": has_evidence,
            "has_counter_argument": has_counter,
            "has_conclusion": has_conclusion,
        },
        "genre_specific_tips": genre_feedback.get(genre, genre_feedback["expository"]),
        "improvement_suggestions": [
            "Strong opening hook add karo" if not has_hook else "Good hook!",
            "Thesis statement clearly state karo" if not has_thesis else "Clear thesis!",
            "Evidence aur examples add karo" if not has_evidence else "Good use of evidence!",
            "Counter-argument address karo" if not has_counter else "Good counter-argument!",
            "Strong conclusion likho" if not has_conclusion else "Good conclusion!",
            f"Aim for shorter sentences (avg {avg_sentence_length:.0f} words)" if avg_sentence_length > 25 else "Good sentence length!",
        ],
        "rewrite_suggestion": "Main aapke text ko improve kar sakta ho. Specific section batao!",
        "timestamp": get_timestamp(),
    }


def language_exchange(user_lang: str, target_lang: str, message: str) -> Dict[str, Any]:
    translations = {
        ("Hindi", "English"): {
            "hello": "Hello / Namaste",
            "thank_you": "Thank you / Dhanyavaad",
            "how_are_you": "How are you? / Aap kaise hain?",
            "good_morning": "Good morning / Suprabhat",
            "i_like": "I like / Mujhe pasand hai",
            "please": "Please / Kripya",
            "yes": "Yes / Haan",
            "no": "No / Nahi",
        },
        ("English", "Hindi"): {
            "hello": "नमस्ते (Namaste)",
            "thank_you": "धन्यवाद (Dhanyavaad)",
            "how_are_you": "आप कैसे हैं? (Aap kaise hain?)",
            "good_morning": "सुप्रभात (Suprabhat)",
            "i_like": "मुझे पसंद है (Mujhe pasand hai)",
            "please": "कृपया (Kripya)",
            "yes": "हाँ (Haan)",
            "no": "नहीं (Nahi)",
        },
        ("English", "Tamil"): {
            "hello": "வணக்கம் (Vanakkam)",
            "thank_you": "நன்றி (Nandri)",
            "how_are_you": "நீங்கள் எப்படி இருக்கிறீர்கள்? (Neengal eppadi irukkingal?)",
        },
        ("English", "Telugu"): {
            "hello": "నమస్కారం (Namaskaram)",
            "thank_you": "ధన్యవాదాలు (Dhanyavaadalu)",
        },
    }
    key = (user_lang, target_lang)
    reverse_key = (target_lang, user_lang)
    lang_dict = translations.get(key, translations.get(reverse_key, {}))
    message_lower = message.lower()
    matched_phrases = []
    for eng, trans in lang_dict.items():
        if eng.replace("_", " ") in message_lower or eng in message_lower:
            matched_phrases.append({"english": eng.replace("_", " "), "translation": trans})
    if not matched_phrases:
        matched_phrases = [{"english": "custom_message", "translation": f"Translation of: {message}"}]
    return {
        "role": "language_exchange",
        "user_language": user_lang,
        "target_language": target_lang,
        "original_message": message,
        "translations": matched_phrases,
        "grammar_notes": [
            f"{target_lang} mein sentence structure alag ho sakta hai",
            f"Word order: Subject-Object-Verb (SOV) common hai South Asian languages mein",
            "Gender agreement important hai kuch languages mein",
        ],
        "practice_sentences": [
            f"Try saying: '{random.choice(list(lang_dict.values())[:3])}' in {target_lang}",
            f"Practice: Introduce yourself in {target_lang}",
            f"Challenge: Describe your day in {target_lang}",
        ],
        "cultural_note": f"{target_lang} speakers se baat karte waqt cultural context bhi samjho",
        "encouragement": "Ek naya word roz seekho - ek saal mein 365 naye words honge!",
        "timestamp": get_timestamp(),
    }


def group_study_moderator(topic: str, questions: List[str]) -> Dict[str, Any]:
    roles = ["Discussion Leader", "Note Taker", "Devil's Advocate", "Summarizer", "Time Keeper"]
    assigned_roles = random.sample(roles, min(len(questions), len(roles)))
    session_plan = []
    for i, q in enumerate(questions):
        session_plan.append({
            "question_number": i + 1,
            "question": q,
            "time_minutes": 10,
            "moderator_note": f"Everyone discuss karo. {assigned_roles[i % len(assigned_roles)]} ensure karo sab bol rahe hain.",
            "follow_up": ["Any alternative perspectives?", "Can you give an example?", "How does this connect to previous topic?"],
        })
    return {
        "role": "group_study_moderator",
        "topic": topic,
        "session_plan": session_plan,
        "roles": [{"role": r, "responsibility": f"{'Lead discussion' if r == 'Discussion Leader' else 'Record key points' if r == 'Note Taker' else 'Challenge every answer' if r == 'Devil' else 'Summarize after each question' if r == 'Summarizer' else 'Keep everyone on time'}"} for r in assigned_roles],
        "ground_rules": [
            "Ek ek karke bolo - interrupt mat karo",
            "Har kisi ka point valid hai - respect rakho",
            "Phones silent pe rakho",
            "Main point bhi likho discussion ke saath",
            "Agar disagree ho, respectful way mein bolo",
        ],
        "study_tips": [
            "Pehle individual mein socho, phir discuss karo",
            "Examples se explain karo - abstract mat raho",
            "Doubts clear karo - koi question chhota nahi hai",
            "End mein sab summary note karo",
        ],
        "duration_minutes": len(questions) * 10,
        "break_schedule": f"Break after every {min(3, len(questions))} questions (5 min)",
        "timestamp": get_timestamp(),
    }


def project_guide(project_type: str, subject: str, deadline: str) -> Dict[str, Any]:
    from datetime import datetime
    try:
        end_date = datetime.strptime(deadline, "%Y-%m-%d")
    except ValueError:
        end_date = datetime.now()
    days_left = max(1, (end_date - datetime.now()).days)
    phases = [
        {
            "phase": "Research & Planning",
            "days": max(1, days_left // 5),
            "tasks": [
                f"{subject} related topic pe research karo",
                "Reference materials collect karo",
                "Project outline banao",
                "Timeline set karo",
            ],
            "deliverable": "Research document + Project plan",
        },
        {
            "phase": "Development/Implementation",
            "days": max(2, days_left // 2),
            "tasks": [
                "Main project work start karo",
                "Regular milestones set karo",
                "Daily progress note karo",
                "Peers se feedback lo",
            ],
            "deliverable": "Working model / Written content / Prototype",
        },
        {
            "phase": "Testing & Refinement",
            "days": max(1, days_left // 5),
            "tasks": [
                "Testing karo - kya kaam kar raha hai?",
                "Errors fix karo",
                "Improvements implement karo",
                "Final version ready karo",
            ],
            "deliverable": "Tested and refined project",
        },
        {
            "phase": "Presentation & Submission",
            "days": max(1, days_left // 5),
            "tasks": [
                "Presentation slides banao",
                "Practice karo - 5 min mein explain karo",
                "Documentation complete karo",
                "Final submission karo",
            ],
            "deliverable": "Presentation + Final submission",
        },
    ]
    return {
        "role": "project_guide",
        "project_type": project_type,
        "subject": subject,
        "deadline": deadline,
        "days_left": days_left,
        "phases": phases,
        "total_tasks": sum(len(p["tasks"]) for p in phases),
        "weekly_checkpoints": [
            f"Week {i+1}: {phase['phase']} complete karo" for i, phase in enumerate(phases[:4])
        ],
        "tools_suggested": [
            "Google Docs for writing projects",
            "Canva for presentations",
            "GitHub for coding projects",
            "Notion for project management",
            "Trello for task tracking",
        ],
        "presentation_tips": [
            "Pehle 30 seconds mein hook banao",
            "Visual aids use karo - graphs, images",
            "Q&A ke liye ready raho",
            "Backup plan rakho (pen drive + cloud)",
            "Confidence se bolo, speed se nahi",
        ],
        "common_mistakes": [
            "Last minute pe shuru karna",
            "Research skip karna",
            "Presentation pe dhyan na dena",
            "Documentation incomplete chhodna",
        ],
        "timestamp": get_timestamp(),
    }


def college_application(profile: Dict, target_colleges: List[str]) -> Dict[str, Any]:
    sop_templates = {
        "engineering": "I am passionate about technology and its potential to solve real-world problems. My interest in {subject} stems from {experience}. At {college}, I aim to explore {area} and contribute to the innovation culture.",
        "liberal_arts": "My interdisciplinary interests in {subject} and {experience} have shaped my desire to pursue liberal arts. I believe in the power of holistic education to create well-rounded individuals.",
        "management": "With a strong foundation in {subject} and leadership experience through {experience}, I am eager to develop my business acumen. My goal is to {goal}.",
        "science": "Scientific curiosity drives me to explore {subject} at an advanced level. My research experience in {experience} has prepared me for rigorous academic inquiry.",
    }
    college_sops = []
    for college in target_colleges:
        sop_type = random.choice(list(sop_templates.keys()))
        template = sop_templates[sop_type]
        sop = template.format(
            subject=profile.get("strong_subject", "Science"),
            experience=profile.get("extracurriculars", "school projects"),
            college=college,
            area="cutting-edge research",
            goal="create impact in the industry",
        )
        college_sops.append({
            "college": college,
            "sop_template": sop,
            "personalization_tips": [
                f"{college} ke specific programs research karo",
                "Faculty ke kaam ke baare mein mention karo",
                "College clubs aur activities se link karo",
                "Specific projects ya labs ka zikr karo",
            ],
        })
    return {
        "role": "college_application_helper",
        "profile_summary": profile,
        "target_colleges": target_colleges,
        "sop_drafts": college_sops,
        "application_checklist": [
            {"task": "Transcripts ready", "status": "pending"},
            {"task": "Recommendation letters request", "status": "pending"},
            {"task": "SOP final draft", "status": "pending"},
            {"task": "Resume/CV updated", "status": "pending"},
            {"task": "Test scores sent", "status": "pending"},
            {"task": "Essays proofread", "status": "pending"},
            {"task": "Application fee paid", "status": "pending"},
        ],
        "tips": [
            "Har college ka application tailor karo - generic mat bhejo",
            "Deadline se 1 week pehle submit karo",
            "Recommender ko resume aur achievements share karo",
            "SOP mein personal stories include karo",
            "Grammar check karo - ek bhi mistake nahi honi chahiye",
        ],
        "scholarship_info": [
            "Merit-based scholarships ke liye early apply karo",
            "Need-based financial aid ke liye documents ready rakho",
            "External scholarships bhi explore karo (Tata, Reliance, etc.)",
        ],
        "timestamp": get_timestamp(),
    }


def study_abroad_counselor(scores: Dict, target_country: str) -> Dict[str, Any]:
    country_info = {
        "USA": {
            "requirements": ["SAT/ACT", "TOEFL/IELTS", "GPA 3.0+", "Essays", "Recommendation Letters"],
            "top_universities": ["MIT", "Stanford", "Harvard", "Caltech", "UC Berkeley"],
            "deadlines": {"Early Decision": "November", "Regular Decision": "January", "Spring": "September"},
            "scholarships": ["Fulbright", "Hubert Humphrey", "University-specific merit aid"],
            "cost_estimate": "$30,000-70,000/year",
            "work_permit": "CPT during studies, OPT after graduation (12-36 months)",
        },
        "UK": {
            "requirements": ["A-Levels or equivalent", "IELTS 6.5+", "Personal Statement", "UCAS application"],
            "top_universities": ["Oxford", "Cambridge", "Imperial", "UCL", "Edinburgh"],
            "deadlines": {"UCAS": "January 15", "Oxbridge": "October 15"},
            "scholarships": ["Chevening", "Commonwealth", "GREAT Scholarships"],
            "cost_estimate": "£10,000-35,000/year",
            "work_permit": "20 hours/week during studies, Graduate Route visa (2 years)",
        },
        "Canada": {
            "requirements": ["IELTS 6.0+", "Transcripts", "Statement of Purpose", "Letters of Reference"],
            "top_universities": ["University of Toronto", "UBC", "McGill", "Alberta", "Waterloo"],
            "deadlines": {"Fall": "January-March", "Winter": "September"},
            "scholarships": ["Vanier", "Trudeau", "University-specific"],
            "cost_estimate": "CAD 20,000-40,000/year",
            "work_permit": "20 hours/week off-campus, PGWP after graduation (up to 3 years)",
        },
        "Australia": {
            "requirements": ["IELTS 6.5+", "Academic Transcripts", "SOP", "Financial Proof"],
            "top_universities": ["Melbourne", "Sydney", "ANU", "UNSW", "Queensland"],
            "deadlines": {"Semester 1": "October", "Semester 2": "April"},
            "scholarships": ["Australia Awards", "Research Training Program", "University scholarships"],
            "cost_estimate": "AUD 20,000-45,000/year",
            "work_permit": "48 hours/fortnight during studies, Temporary Graduate visa (18-48 months)",
        },
    }
    info = country_info.get(target_country, country_info["USA"])
    return {
        "role": "study_abroad_counselor",
        "target_country": target_country,
        "your_scores": scores,
        "country_info": info,
        "eligibility_check": {
            "academic_requirement": "Check needed - share your GPA",
            "language_requirement": "IELTS/TOEFL score required",
            "test_scores": f"{'Strong' if sum(scores.values()) / max(len(scores), 1) > 80 else 'Needs improvement'} profile",
        },
        "application_timeline": {
            "12_months_before": "Research universities, start test prep",
            "9_months_before": "Take IELTS/TOEFL, start SOP",
            "6_months_before": "Submit applications, apply for scholarships",
            "3_months_before": "Interview preparation, visa application",
            "1_month_before": "Book tickets, accommodation, pre-departure",
        },
        "financial_planning": {
            "tuition": info["cost_estimate"],
            "living_expenses": "Varies by city - $10,000-20,000/year",
            "scholarship_options": info["scholarships"],
            "part_time_work": info["work_permit"],
        },
        "tips": [
            "Start preparation 12-18 months in advance",
            "Build a strong profile - not just scores",
            "Networking with current students helps",
            "Apply to 6-8 universities (mix of reach, match, safety)",
            "Financial planning pehle se karo - scholarships ke liye early apply karo",
        ],
        "timestamp": get_timestamp(),
    }
