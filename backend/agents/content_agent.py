import random
import json
from typing import List, Dict, Any
from utils import (
    generate_id, get_timestamp, subject_chapters, indian_boards,
    difficulty_levels, question_banks,
)


def generate_textbook(topic: str, class_level: int, board: str) -> Dict[str, Any]:
    sections = {
        "introduction": {
            "title": f"{topic} - Parichay",
            "content": f"Aaj hum {topic} ke baare mein padhenge. Ye {class_level}th class {board} curriculum ka important chapter hai. Is chapter mein hum basics se advanced concepts tak jaayenge.",
            "key_points": [
                f"{topic} ka definition aur basic concept",
                f"{topic} ke types aur classifications",
                f"{topic} ke real-life applications",
                f"{topic} ke important formulas aur theorems",
            ],
        },
        "theory": {
            "title": f"{topic} - Sidhant",
            "content": f"{topic} ke theoretical foundation samajhna bahut zaroori hai. Ye concept kai doosre topics se linked hai. Fundamental principle ye hai ki har action ka ek reaction hota hai aur ye concept universally applicable hai.",
            "subtopics": [
                {"name": "Basic Definition", "detail": f"{topic} ko formally define karte hain: Ye ek fundamental concept hai jo describes karta hai natural phenomena ko.", "formula": "F = ma (applicable principle)"},
                {"name": "Mathematical Representation", "detail": "Is concept ko mathematical equations se represent karte hain.", "formula": "y = mx + c (general form)"},
                {"name": "Graphical Interpretation", "detail": "Graph pe ye concept ko plot karne se patterns samajh aate hain.", "note": "Graph pe slope, intercept aur area important hai"},
            ],
        },
        "examples": {
            "title": f"{topic} - Udaharan",
            "solved_examples": [
                {
                    "problem": f"Example 1: Basic application of {topic}",
                    "solution": "Step 1: Given data identify karo\nStep 2: Applicable formula lagao\nStep 3: Values substitute karo\nStep 4: Calculate karo\nStep 5: Units lagao",
                    "difficulty": "Easy",
                },
                {
                    "problem": f"Example 2: Advanced problem on {topic}",
                    "solution": "Step 1: Problem ko diagram ke saath samjho\nStep 2: Multiple concepts apply karo\nStep 3: Equation set up karo\nStep 4: Solve karo step by step\nStep 5: Verify karo ki answer meaningful hai",
                    "difficulty": "Medium",
                },
            ],
        },
        "practice": {
            "title": f"{topic} - Abhyas Prashn",
            "questions": [
                {"q": f"{topic} ka basic definition kya hai?", "marks": 2},
                {"q": f"{topic} ke do important properties list karo.", "marks": 2},
                {"q": f"Ek real-life example dijiye jahan {topic} apply hota hai.", "marks": 3},
                {"q": f"Given problem solve karo: Apply {topic} concepts.", "marks": 5},
                {"q": f"{topic} ke advantages aur disadvantages discuss karo.", "marks": 5},
            ],
            "total_marks": 17,
        },
        "summary": {
            "title": f"{topic} - Saar",
            "key_formulas": [
                f"Formula 1: Basic equation of {topic}",
                f"Formula 2: Derived relation",
                f"Formula 3: Special case formula",
            ],
            "mnemonics": f"Yaad rakhne ka tarika: '{topic[:3].upper()}' se start karo!",
            "common_mistakes": [
                "Units galat lagana - hamesha SI units check karo",
                "Sign convention bhoolna - diagram zaroor banao",
                "Approximation galat karna - significant figures dhyan mein rakho",
            ],
        },
    }
    return {
        "role": "textbook_generator",
        "topic": topic,
        "class_level": class_level,
        "board": board,
        "sections": sections,
        "estimated_reading_time": f"{random.randint(15, 30)} minutes",
        "difficulty": "Class appropriate",
        "ncert_reference": f"{board} {class_level}th textbook, Chapter on {topic}",
        "timestamp": get_timestamp(),
    }


def generate_question_paper(blueprint: Dict) -> Dict[str, Any]:
    subject = blueprint.get("subject", "Mathematics")
    total_marks = blueprint.get("total_marks", 80)
    time_hours = blueprint.get("time_hours", 3)
    difficulty_dist = blueprint.get("difficulty_distribution", {"easy": 30, "medium": 50, "hard": 20})
    sections = []
    section_a_marks = int(total_marks * difficulty_dist["easy"] / 100)
    section_b_marks = int(total_marks * difficulty_dist["medium"] / 100)
    section_c_marks = total_marks - section_a_marks - section_b_marks
    sections.append({
        "section": "A",
        "title": "Objective Type Questions",
        "instruction": "All questions are compulsory. Each question carries 1 mark.",
        "marks_per_question": 1,
        "num_questions": section_a_marks,
        "type": "MCQ/Very Short Answer",
        "sample_questions": [
            f"Q1: Choose the correct option for {subject} fundamental concept.",
            f"Q2: Define any two terms related to {subject}.",
            f"Q3: State whether True or False with reason.",
        ],
        "total_marks": section_a_marks,
    })
    section_b_q = section_b_marks // 3
    sections.append({
        "section": "B",
        "title": "Short Answer Type Questions",
        "instruction": "Answer in 80-120 words. Each question carries 3 marks.",
        "marks_per_question": 3,
        "num_questions": section_b_q,
        "type": "Short Answer",
        "sample_questions": [
            f"Q{section_a_marks + 1}: Explain the concept of {subject} with a diagram.",
            f"Q{section_a_marks + 2}: Differentiate between two related concepts in {subject}.",
            f"Q{section_a_marks + 3}: Solve the following problem with all steps.",
        ],
        "total_marks": section_b_marks,
    })
    section_c_q = max(1, section_c_marks // 5)
    sections.append({
        "section": "C",
        "title": "Long Answer Type Questions",
        "instruction": "Answer in 200-300 words. Each question carries 5 marks.",
        "marks_per_question": 5,
        "num_questions": section_c_q,
        "type": "Long Answer/Essay",
        "sample_questions": [
            f"Q{section_a_marks + section_b_q + 1}: Derive and explain the relationship in {subject} with examples.",
            f"Q{section_a_marks + section_b_q + 2}: Analyze the given scenario using {subject} principles.",
        ],
        "total_marks": section_c_marks,
    })
    return {
        "role": "question_paper_generator",
        "subject": subject,
        "total_marks": total_marks,
        "time_hours": time_hours,
        "difficulty_distribution": difficulty_dist,
        "sections": sections,
        "instructions": [
            "Read all questions carefully before answering",
            "Draw diagrams wherever necessary",
            "Show all working for calculation questions",
            "Attempt all questions",
            "Extra marks for neat presentation",
        ],
        "marking_scheme": {
            "step_marking": "Partial marks awarded for correct steps",
            "diagram_marks": "1 extra mark for neat, labeled diagrams",
            "bonus": "Up to 2 bonus marks for exceptional answers",
        },
        "timestamp": get_timestamp(),
    }


def generate_lab_manual(experiment: Dict) -> Dict[str, Any]:
    exp_name = experiment.get("name", "To verify Ohm's Law")
    subject = experiment.get("subject", "Physics")
    return {
        "role": "lab_manual_generator",
        "experiment": exp_name,
        "subject": subject,
        "sections": {
            "objective": f"To verify {exp_name} and determine the relationship between the involved quantities.",
            "theory": f"According to the principles of {subject}, {exp_name} states a fundamental relationship. This experiment validates the theoretical predictions through practical observation and measurement.",
            "apparatus": [
                "Meter scale / Vernier caliper",
                "Weight box",
                "Spring balance",
                "Water, beaker, stand",
                "Thread, thermometer",
                "Electrical components (as needed)",
            ],
            "procedure": [
                "Apparatus ko properly set up karo according to diagram",
                "Initial readings note karo carefully",
                "Gradually change the independent variable",
                "At each step, record dependent variable readings",
                "Repeat each measurement 3 times for accuracy",
                "Tabulate all readings systematically",
                "Plot graphs as required",
                "Clean up apparatus after experiment",
            ],
            "observations": {
                "table_headers": ["S.No", "Independent Variable", "Dependent Variable (Trial 1)", "Trial 2", "Trial 3", "Mean"],
                "sample_data": [[1, "0.5", "2.4", "2.5", "2.4", "2.43"], [2, "1.0", "4.8", "4.9", "4.8", "4.83"]],
            },
            "calculations": [
                "Mean value calculate karo for each reading",
                "Graph plot karo: X-axis vs Y-axis",
                "Slope calculate karo from the best-fit line",
                "Slope se relationship establish karo",
                "Percentage error = |(Experimental - Theoretical)/Theoretical| × 100",
            ],
            "result": f"The experiment successfully verified {exp_name}. The observed relationship matches theoretical predictions within {random.randint(2,8)}% error.",
            "precautions": [
                "Measurements carefully lene chahiye - parallax error avoid karo",
                "Apparatus properly aligned hona chahiye",
                "Record readings at regular intervals",
                "Repeat readings for reliability",
                "Safety precautions follow karo",
            ],
            "viva_questions": [
                {"q": "Is experiment ka main objective kya hai?", "expected": "Verify the relationship between variables"},
                {"q": "Ye experiment daily life mein kahan use hota hai?", "expected": "Applications in engineering, technology, research"},
                {"q": "Sources of error kya ho sakte hain?", "expected": "Instrumental, personal, environmental errors"},
                {"q": "Is experiment ko aur accurate kaise kar sakte hain?", "expected": "Better instruments, more trials, controlled environment"},
            ],
        },
        "timestamp": get_timestamp(),
    }


def story_based_learning(chapter: str) -> Dict[str, Any]:
    characters = ["Chintu", "Mintu", "Guddu", "Pinki", "Bunty"]
   主角 = random.choice(characters)
    story_templates = {
        "Polynomials": f"Ek gaon mein {主角} naam ka bachcha rehta tha. Usse numbers se bahut pyaar tha. Ek din use ek ajeeb polynomial mila: x² - 5x + 6. Usne socha - agar ye zero ho jaye toh x ki values kya hongi? Usne factor kiya: (x-2)(x-3) = 0. Toh x = 2 ya 3! {主角} ne seekha ki polynomials ke zeroes factors se milte hain.",
        "Electricity": f"{主角} ka naya ghar tha. Usne dekha ki bijli bill bahut zyada aa raha hai. Usne socha - kya wajah hai? Usne formula yaad kiya: P = VI. Agar V = 220V hai aur appliance 1000W ka hai, toh I = P/V = 1000/220 = 4.54A. {主角} ne energy efficient appliances lagwaye aur bill kam ho gaya!",
        "Photosynthesis": f"{主角} ne apne garden mein ek experiment kiya. Usne ek plant ko sunlight mein rakha aur ek ko andhera kamre mein. 7 din baad, sunlight wala plant healthy tha, andhera wala murjha gaya. {主角} ne samjha ki plants ko khana banane ke liye sunlight chahiye - ye hai photosynthesis: 6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂.",
        "Newton's Laws": f"{主角} cricket khel raha tha. Usne ball ko catch kiya toh haath dukha. Usne socha - kyun dukha? Newton ke Third Law ke according: har action ka equal aur opposite reaction hota hai. Ball ne force lagaya haath par, haath ne force lagaya ball par. {主角} ne gloves lagaye - force distribute ho gayi!",
    }
    story = story_templates.get(chapter, f"{主角} ek din padhai kar raha tha aur use {chapter} pada. Usne slowly samjha ki ye topic kitna interesting hai. Usne examples dekhe, practice ki, aur dheere dheere master kar liya. {主角} ne bola: 'Mehnat rang laati hai!'")
    return {
        "role": "story_tutor",
        "chapter": chapter,
        "story": story,
        "moral": "Har topic interesting hai agar sahi tarike se padho!",
        "learning_points": [
            f"{chapter} ke core concept ko daily life se link karo",
            "Examples khud dhundho apne aas-paas se",
            "Practice se confidence badhta hai",
        ],
        "quiz_after_story": [
            {"q": f"Story mein {主角} ne {chapter} ke kis concept ko apply kiya?", "opts": ["Concept 1", "Concept 2", "Concept 3", "Concept 4"], "ans": 0},
            {"q": "Kya aap real life mein is concept ka example de sakte ho?", "type": "Open ended"},
        ],
        "timestamp": get_timestamp(),
    }


def generate_mnemonics(content: str) -> Dict[str, Any]:
    mnemonics = {
        "planets": {"trick": "My Very Educated Mother Just Served Us Noodles", "meaning": "Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune"},
        "order": {"trick": "Please Stop Calling Me A Cute Zebra In Class", "meaning": "Please, Stop, Call, Me, A, Cute, Zebra, In, Class (Math operations)"},
        "colours": {"trick": "VIBGYOR - Violet, Indigo, Blue, Green, Yellow, Orange, Red", "meaning": "Visible light spectrum order"},
        "trigonometry": {"trick": "Pandit Badri Prasad / Hari Hari Bolo", "meaning": "Sin = P/H, Cos = B/H, Tan = P/B"},
        "electronegativity": {"trick": "FONClBrISCH", "meaning": "Fluorine, Oxygen, Nitrogen, Chlorine, Bromine, Iodine, Sulfur, Carbon, Hydrogen"},
        "taxonomic_hierarchy": {"trick": "Dear King Philip Came Over For Good Soup", "meaning": "Domain, Kingdom, Phylum, Class, Order, Family, Genus, Species"},
    }
    content_lower = content.lower()
    matched_mnemonics = []
    for key, val in mnemonics.items():
        if key in content_lower or any(word in content_lower for word in key.split()):
            matched_mnemonics.append({"topic": key, **val})
    if not matched_mnemonics:
        words = content.split()
        first_letters = [w[0].upper() for w in words[:6] if w]
        matched_mnemonics.append({
            "topic": "Custom",
            "trick": f"Try making an acronym: {' '.join(first_letters)}",
            "meaning": "Apne content ke first letters se ek word banao jo yaad rahe",
        })
    return {
        "role": "mnemonic_generator",
        "content": content,
        "mnemonics": matched_mnemonics,
        "tips": [
            "Visualization use karo - mental picture banao",
            "Rhymes ya songs mein convert karo",
            "Story banao elements ke saath",
            "Chunking karo - chhote parts mein todo",
            "Spaced repetition karo - regular revise karo",
        ],
        "timestamp": get_timestamp(),
    }


def generate_cheat_sheet(chapter: str, subject: str) -> Dict[str, Any]:
    return {
        "role": "cheat_sheet_generator",
        "chapter": chapter,
        "subject": subject,
        "sheet": {
            "title": f"{subject}: {chapter} - Quick Reference",
            "key_concepts": [
                f"{chapter} ka fundamental principle",
                f"Important definitions related to {chapter}",
                f"Key relationships and formulas",
            ],
            "formulas": [
                "F = ma (Newton's Second Law)",
                "E = mc² (Mass-Energy equivalence)",
                "PV = nRT (Ideal Gas Law)",
                f"Special formula for {chapter}",
            ],
            "diagram_labels": ["Label all parts clearly", "Include dimensions", "Mark important angles/points"],
            "common_problems": [
                {"type": "Conceptual", "tip": "Definition yaad rakho, usme kya included hai aur kya nahi"},
                {"type": "Numerical", "tip": "Formula laga ke solve karo, units check karo"},
                {"type": "Diagram", "tip": "Pencil se banao, labels lagao, neat rakho"},
            ],
            "exam_tips": [
                "Pehle wo questions karo jo aate hain",
                "Time manage karo - 1 mark ka 1 minute",
                "Diagrams zaroor banao - extra marks milte hain",
                "Units aur significant figures dhyan mein rakho",
            ],
        },
        "format": "Single A4 page, both sides",
        "color_coding": {"red": "Important formulas", "blue": "Definitions", "green": "Tips", "black": "Examples"},
        "timestamp": get_timestamp(),
    }


def generate_mind_map(topic: str) -> Dict[str, Any]:
    return {
        "role": "mind_map_generator",
        "topic": topic,
        "mind_map": {
            "central_node": topic,
            "main_branches": [
                {
                    "name": "Definition",
                    "children": [
                        {"name": "Basic concept", "detail": f"{topic} ka core idea"},
                        {"name": "Technical definition", "detail": "Formal language mein definition"},
                        {"name": "Simple explanation", "detail": "Aam bhasha mein samjhao"},
                    ],
                },
                {
                    "name": "Types",
                    "children": [
                        {"name": "Type 1", "detail": f"{topic} ka pehla type"},
                        {"name": "Type 2", "detail": f"{topic} ka doosra type"},
                        {"name": "Type 3", "detail": f"{topic} ka teesra type"},
                    ],
                },
                {
                    "name": "Formulas",
                    "children": [
                        {"name": "Primary Formula", "detail": "Main equation"},
                        {"name": "Derived Formula", "detail": "Secondary equations"},
                        {"name": "Special Cases", "detail": "特殊情况"},
                    ],
                },
                {
                    "name": "Applications",
                    "children": [
                        {"name": "Real Life", "detail": "Daily life applications"},
                        {"name": "Industrial", "detail": "Industry mein use"},
                        {"name": "Research", "detail": "Scientific research mein use"},
                    ],
                },
                {
                    "name": "Common Errors",
                    "children": [
                        {"name": "Mistake 1", "detail": "Galat approach"},
                        {"name": "Mistake 2", "detail": "Units galat"},
                        {"name": "Mistake 3", "detail": "Sign convention"},
                    ],
                },
            ],
        },
        "colors_suggested": {"central": "Red", "branches": ["Blue", "Green", "Orange", "Purple", "Teal"]},
        "software_suggestion": "Use FreeMind, XMind, or draw manually on A3 paper",
        "timestamp": get_timestamp(),
    }


def generate_audio_notes(content: str) -> Dict[str, Any]:
    return {
        "role": "audio_notes_generator",
        "content": content,
        "ssml_script": f"""
<speak>
  <p>
    <s>Let's review today's topic: <emphasis level="strong">{content}</emphasis>.</s>
    <s>This is a key concept you need to remember.</s>
  </p>
  <break time="500ms"/>
  <p>
    <s>The most important points are:</s>
    <s><emphasis level="strong">First</emphasis>: Understand the basic definition.</s>
    <s><emphasis level="strong">Second</emphasis>: Learn the main formulas.</s>
    <s><emphasis level="strong">Third</emphasis>: Practice with examples.</s>
  </p>
  <break time="300ms"/>
  <p>
    <s><emphasis level="moderate">Remember</emphasis>: Use the <say-as interpret-as="spell-out">PQRS</say-as> method for retention.</s>
    <s><break time="200ms"/>Pause and recall what you just learned.</s>
  </p>
  <prosody rate="slow" pitch="low">
    <s>Take a deep breath and review the key points mentally.</s>
  </prosody>
</speak>
""",
        "recording_tips": [
            "Slow speed pe record karo - 0.75x is best for studying",
            "Key points pe emphasis do",
            "Between sections 2-3 second ka gap rakho",
            "Night pe suno before sleeping for better retention",
        ],
        "suggested_speed": "0.75x for learning, 1x for revision",
        "timestamp": get_timestamp(),
    }


def generate_video_script(topic: str, duration_minutes: int) -> Dict[str, Any]:
    segments = []
    remaining = duration_minutes * 60
    intro_time = min(60, remaining // 5)
    segments.append({
        "segment": "Introduction",
        "duration_seconds": intro_time,
        "script": f"Hello students! Aaj hum interesting topic {topic} ke baare mein jaanenge. Ye topic bahut important hai aur real life mein bahut use hota hai.",
        "visual": "Host on screen with topic title animation",
        "tone": "Enthusiastic, welcoming",
    })
    remaining -= intro_time
    main_time = int(remaining * 0.7)
    segments.append({
        "segment": "Main Content",
        "duration_seconds": main_time,
        "script": f"Chaliye shuru karte hain. {topic} ko samajhne ke liye pehle basics jaante hain. [PAUSE] Ab detailed explanation dekhte hain with examples. [CUT TO DIAGRAM] Ye diagram dekho - isme clearly dikh raha hai.",
        "visual": "Animations, diagrams, text overlays",
        "tone": "Educational, clear pace",
    })
    quiz_time = int(remaining * 0.2)
    segments.append({
        "segment": "Interactive Quiz",
        "duration_seconds": quiz_time,
        "script": "Ab quiz time! Comment section mein answer karo. Question 1: [QUESTION]. Ruko 5 seconds... 5, 4, 3, 2, 1... Answer hai [ANSWER]!",
        "visual": "Quiz interface with countdown timer",
        "tone": "Exciting, interactive",
    })
    outro_time = remaining - main_time - quiz_time
    segments.append({
        "segment": "Outro",
        "duration_seconds": max(30, outro_time),
        "script": "Toh aaj humne {topic} ke baare mein detail mein jaana. Agar video pasand aaya toh like karo, share karo, aur subscribe karo! Next video mein hum aur interesting topic cover karenge. Tab tak practice karte raho!",
        "visual": "Host with end screen cards",
        "tone": "Warm, encouraging",
    })
    return {
        "role": "video_script_generator",
        "topic": topic,
        "total_duration_minutes": duration_minutes,
        "segments": segments,
        "production_notes": {
            "intro_animation": "Dynamic title reveal with topic name",
            "background_music": "Soft instrumental during explanations",
            "thumbnail_idea": f"Bold text '{topic}' with eye-catching colors",
            "hashtags": [f"#{topic.replace(' ', '')}", "#Education", "#StudyWithMe", "#IndianEducation"],
        },
        "timestamp": get_timestamp(),
    }


def auto_flashcards(content: str) -> Dict[str, Any]:
    words = content.split()
    key_terms = [w for w in words if len(w) > 5][:8]
    flashcards = []
    for i, term in enumerate(key_terms):
        flashcards.append({
            "id": i + 1,
            "front": f"What is {term}?",
            "back": f"{term} is a key concept in this topic. It refers to the fundamental principle that underlies the chapter's main theme.",
            "difficulty": random.choice(["Easy", "Medium", "Hard"]),
            "revision_count": 0,
        })
    flashcards.append({
        "id": len(flashcards) + 1,
        "front": f"State the main formula for {content[:30]}",
        "back": "The main formula involves the relationship between the key variables. Apply it step by step for numericals.",
        "difficulty": "Hard",
        "revision_count": 0,
    })
    return {
        "role": "flashcard_generator",
        "content": content[:100],
        "num_cards": len(flashcards),
        "flashcards": flashcards,
        "study_tip": "Har card ko 3 baar revise karo - once today, once tomorrow, once in a week",
        "spaced_repetition_schedule": ["Day 1", "Day 2", "Day 4", "Day 7", "Day 15", "Day 30"],
        "timestamp": get_timestamp(),
    }
