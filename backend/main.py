from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import json, random, math, datetime

from models import (
    QuestionRequest, Question, QuizSession, TutorMessage, StudyPlanRequest,
    PerformanceData, HomeworkRequest, EssayRequest, DebateRequest,
    CareerRequest, ContentRequest, VivaRequest, MindMapRequest,
    MnemonicRequest, CheatSheetRequest, AdaptiveQuizRequest,
    ConceptGapRequest, StudyEfficiencyRequest, ExamReadinessRequest,
    PerformancePredictRequest, OptimalTimeRequest, BurnoutRequest,
    LabSimRequest, HistoryRequest, WritingCoachRequest,
    LanguageExchangeRequest, ProjectGuideRequest, CollegeAppRequest,
    StudyAbroadRequest, GroupStudyRequest, ScienceExplainerRequest,
    MathSolverRequest, SpellingCheckRequest, PlagiarismCheckRequest,
    DiagramCheckRequest, SpeedMathRequest, MockInterviewRequest,
    AudioNotesRequest, VideoScriptRequest, PeerComparisonRequest,
    LongTermMemoryRequest, ForgettingCurveRequest, ExamStrategyRequest,
    AnxietyCheckRequest, DailyChallengeRequest, StateBoardRequest,
)
from utils import (
    generate_id, get_timestamp, calculate_accuracy, get_grade,
    indian_boards, subject_chapters, difficulty_levels, motivational_quotes,
)
from agents.tutor_agent import (
    socratic_method, debate_agent, personalized_tutor, anxiety_coach,
    accountability_agent, career_counselor, parent_report, exam_strategy,
    multi_language_tutor, daily_challenge,
)
from agents.content_agent import (
    generate_textbook, generate_question_paper, generate_lab_manual,
    story_based_learning, generate_mnemonics, generate_cheat_sheet,
    generate_mind_map, generate_audio_notes, generate_video_script,
    auto_flashcards,
)
from agents.assessment_agent import (
    adaptive_quiz, voice_viva, essay_evaluator, speed_math,
    diagram_practice, concept_gap_detector, mock_interview,
    plagiarism_checker, spelling_grammar, peer_comparison,
    update_elo_rating,
)
from agents.analytics_agent import (
    learning_dna, performance_predictor, optimal_study_time,
    burnout_detector, forgetting_curve, study_efficiency,
    exam_readiness, topic_mastery, comparative_analytics,
    long_term_retention,
)
from agents.interactive_agent import (
    lab_simulator, historical_travel, science_explainer, math_solver,
    writing_coach, language_exchange, group_study_moderator,
    project_guide, college_application, study_abroad_counselor,
)

app = FastAPI(
    title="Nexus Edu AI Backend",
    description="AI Brain powering 50+ agent features for Indian Education",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ========== TUTOR AGENTS (10 endpoints) ==========

@app.post("/api/tutor/socratic")
def socratic_endpoint(question: str = "What is Photosynthesis?", subject: str = "Biology"):
    return socratic_method(question, subject)

@app.post("/api/tutor/debate")
def debate_endpoint(topic: str = "Technology in Education", user_position: str = "Technology is essential", round: int = 1):
    return debate_agent(topic, user_position, round)

@app.post("/api/tutor/personalized")
def personalized_endpoint(subject: str = "Mathematics", weak_areas: List[str] = ["Calculus", "Trigonometry"], learning_style: str = "visual"):
    return personalized_tutor(subject, weak_areas, learning_style)

@app.post("/api/tutor/anxiety-coach")
def anxiety_endpoint(message: str = "I am very stressed about my exams"):
    return anxiety_coach(message)

@app.post("/api/tutor/accountability")
def accountability_endpoint(study_log: List[Dict] = [{"topic": "Polynomials", "hours": 2, "subject": "Mathematics"}, {"topic": "Electricity", "hours": 1.5, "subject": "Physics"}]):
    return accountability_agent(study_log)

@app.post("/api/tutor/career")
def career_endpoint(interests: List[str] = ["Technology", "Science"], marks: Dict[str, float] = {"Mathematics": 85, "Physics": 80, "Chemistry": 75}, class_level: int = 12):
    return career_counselor(interests, marks, class_level)

@app.post("/api/tutor/parent-report")
def parent_report_endpoint(student_data: Dict = {"subjects": {"Mathematics": {"avg": 85, "high": 95, "low": 70, "trend": "improving"}, "Physics": {"avg": 70, "high": 85, "low": 55, "trend": "stable"}}, "total_tests": 10, "average_score": 77.5, "weekly_study_hours": 18}):
    return parent_report(student_data)

@app.post("/api/tutor/exam-strategy")
def exam_strategy_endpoint(exam: str = "JEE", subjects: List[Dict] = [{"name": "Physics", "weightage": 25, "total_chapters": 20, "completed": 15}, {"name": "Chemistry", "weightage": 25, "total_chapters": 20, "completed": 12}, {"name": "Mathematics", "weightage": 50, "total_chapters": 20, "completed": 18}], days_left: int = 60):
    return exam_strategy(exam, subjects, days_left)

@app.post("/api/tutor/multi-language")
def multi_lang_endpoint(topic: str = "Quadratic Equations", language: str = "Hindi"):
    return multi_language_tutor(topic, language)

@app.post("/api/tutor/daily-challenge")
def daily_challenge_endpoint(subject: str = "Mathematics", difficulty: str = "medium"):
    return daily_challenge(subject, difficulty)

# ========== CONTENT AGENTS (10 endpoints) ==========

@app.post("/api/content/textbook")
def textbook_endpoint(topic: str = "Polynomials", class_level: int = 10, board: str = "CBSE"):
    return generate_textbook(topic, class_level, board)

@app.post("/api/content/question-paper")
def question_paper_endpoint(blueprint: Dict = {"subject": "Mathematics", "total_marks": 80, "time_hours": 3, "difficulty_distribution": {"easy": 30, "medium": 50, "hard": 20}}):
    return generate_question_paper(blueprint)

@app.post("/api/content/lab-manual")
def lab_manual_endpoint(experiment: Dict = {"name": "Ohm's Law Verification", "subject": "Physics"}):
    return generate_lab_manual(experiment)

@app.post("/api/content/story-learning")
def story_endpoint(chapter: str = "Polynomials"):
    return story_based_learning(chapter)

@app.post("/api/content/mnemonics")
def mnemonics_endpoint(content: str = "Trigonometry ratios SOH CAH TOA"):
    return generate_mnemonics(content)

@app.post("/api/content/cheat-sheet")
def cheat_sheet_endpoint(chapter: str = "Polynomials", subject: str = "Mathematics", class_level: int = 10):
    return generate_cheat_sheet(chapter, subject)

@app.post("/api/content/mind-map")
def mind_map_endpoint(topic: str = "Photosynthesis", depth: int = 3):
    return generate_mind_map(topic)

@app.post("/api/content/audio-notes")
def audio_notes_endpoint(content: str = "Newton's Laws of Motion", emphasis_topics: List[str] = ["Third Law", "Applications"]):
    return generate_audio_notes(content)

@app.post("/api/content/video-script")
def video_script_endpoint(topic: str = "Photosynthesis", duration_minutes: int = 5, style: str = "educational"):
    return generate_video_script(topic, duration_minutes)

@app.post("/api/content/flashcards")
def flashcards_endpoint(content: str = "Quadratic Equations and their applications in real life"):
    return auto_flashcards(content)

# ========== ASSESSMENT AGENTS (10 endpoints) ==========

@app.post("/api/assessment/adaptive-quiz")
def adaptive_quiz_endpoint(subject: str = "Mathematics", chapter: str = "Polynomials", current_level: int = 500):
    return adaptive_quiz(subject, chapter, current_level)

@app.post("/api/assessment/voice-viva")
def voice_viva_endpoint(subject: str = "Physics", chapter: str = "Electricity", round: int = 1):
    return voice_viva(subject, chapter, round)

@app.post("/api/assessment/essay-eval")
def essay_eval_endpoint(text: str = "This essay discusses the importance of renewable energy. According to recent studies, solar and wind energy are the future. However, we must consider the challenges.", subject: str = "Environmental Science", class_level: int = 12):
    return essay_evaluator(text, subject)

@app.post("/api/assessment/speed-math")
def speed_math_endpoint(operation: str = "add", range_min: int = 1, range_max: int = 100, count: int = 10):
    return speed_math(operation, range_min, range_max, count)

@app.post("/api/assessment/diagram-check")
def diagram_check_endpoint(description: str = "Human heart with chambers, valves, and blood vessels labeled", expected_parts: List[str] = ["Left Atrium", "Right Atrium", "Left Ventricle", "Right Ventricle", "Aorta", "Pulmonary Artery"]):
    return diagram_practice(description, expected_parts)

@app.post("/api/assessment/concept-gap")
def concept_gap_endpoint(answers: List[Dict] = [{"topic": "Quadratic Equations", "correct": True}, {"topic": "Polynomials", "correct": False}, {"topic": "Linear Equations", "correct": True}, {"topic": "Quadratic Equations", "correct": False}]):
    return concept_gap_detector(answers)

@app.post("/api/assessment/mock-interview")
def mock_interview_endpoint(field: str = "Computer Science", experience: str = "2 years coding projects", round: int = 1):
    return mock_interview(field, experience, round)

@app.post("/api/assessment/plagiarism-check")
def plagiarism_check_endpoint(text: str = "This is an original piece of writing about technology in education. It explores how digital tools have transformed learning methodologies."):
    return plagiarism_checker(text)

@app.post("/api/assessment/spelling-grammar")
def spelling_grammar_endpoint(text: str = "This is a sample text with some potential errrors to check. Their are many ways to improve writing skills."):
    return spelling_grammar(text)

@app.post("/api/assessment/peer-comparison")
def peer_comparison_endpoint(scores: Dict = {"Test 1": 85, "Test 2": 78, "Test 3": 92, "Test 4": 88}, subject: str = "Mathematics"):
    return peer_comparison(scores, subject)

# ========== ANALYTICS AGENTS (10 endpoints) ==========

@app.post("/api/analytics/learning-dna")
def learning_dna_endpoint(history: List[Dict] = [{"subject": "Mathematics", "score": 85, "time_spent": 45}, {"subject": "Physics", "score": 72, "time_spent": 60}, {"subject": "Mathematics", "score": 90, "time_spent": 40}, {"subject": "Physics", "score": 78, "time_spent": 55}]):
    return learning_dna(history)

@app.post("/api/analytics/performance-predict")
def performance_predict_endpoint(scores: Dict = {"Mathematics": [70, 75, 80, 85], "Physics": [60, 65, 62, 68]}, study_plan: Dict = {"Mathematics": {"hours_per_week": 10}, "Physics": {"hours_per_week": 8}}):
    return performance_predictor(scores, study_plan)

@app.post("/api/analytics/optimal-time")
def optimal_time_endpoint(performance_data: List[Dict] = [{"hour": 8, "score": 85, "duration": 60}, {"hour": 10, "score": 92, "duration": 45}, {"hour": 14, "score": 75, "duration": 50}, {"hour": 16, "score": 80, "duration": 55}, {"hour": 20, "score": 70, "duration": 40}]):
    return optimal_study_time(performance_data)

@app.post("/api/analytics/burnout-check")
def burnout_endpoint(recent_scores: List[float] = [85, 82, 78, 72, 65, 60], study_hours: List[float] = [6, 8, 10, 12, 14, 15]):
    return burnout_detector(recent_scores, study_hours)

@app.post("/api/analytics/forgetting-curve")
def forgetting_curve_endpoint(memory_strength: float = 7.0, difficulty: float = 0.5):
    return forgetting_curve(memory_strength, difficulty)

@app.post("/api/analytics/study-efficiency")
def study_efficiency_endpoint(study_hours: float = 10.0, topics_covered: int = 8, retention_rate: float = 75.0):
    return study_efficiency(study_hours, topics_covered, retention_rate)

@app.post("/api/analytics/exam-readiness")
def exam_readiness_endpoint(subjects: List[Dict] = [{"name": "Physics", "prepared_chapters": 15, "total_chapters": 20, "average_score": 75, "confidence": 70}, {"name": "Chemistry", "prepared_chapters": 12, "total_chapters": 20, "average_score": 65, "confidence": 60}, {"name": "Mathematics", "prepared_chapters": 18, "total_chapters": 20, "average_score": 85, "confidence": 80}], target_exam: str = "JEE"):
    return exam_readiness(subjects, target_exam)

@app.post("/api/analytics/topic-mastery")
def topic_mastery_endpoint(test_results: List[Dict] = [{"topic": "Algebra", "score": 85}, {"topic": "Geometry", "score": 72}, {"topic": "Algebra", "score": 90}, {"topic": "Trigonometry", "score": 60}, {"topic": "Geometry", "score": 78}]):
    return topic_mastery(test_results)

@app.post("/api/analytics/peer-comparison")
def analytics_peer_endpoint(scores: Dict = {"Mathematics": 85, "Physics": 72, "Chemistry": 78}, subject: str = "Overall"):
    return comparative_analytics(scores, 70.0)

@app.post("/api/analytics/long-term-memory")
def long_term_memory_endpoint(topic: str = "Newton's Laws", last_studied: str = "2024-01-15"):
    return long_term_retention(topic, last_studied)

# ========== INTERACTIVE AGENTS (10 endpoints) ==========

@app.post("/api/interactive/lab-sim")
def lab_sim_endpoint(experiment_type: str = "ohms_law", parameters: Dict = {"voltage_range": "0-12V", "resistance": "10 ohm"}):
    return lab_simulator(experiment_type, parameters)

@app.post("/api/interactive/historical-travel")
def historical_travel_endpoint(era: str = "ancient_india", topic: str = "Education System"):
    return historical_travel(era, topic)

@app.post("/api/interactive/science-explainer")
def science_explainer_endpoint(image_description: str = "A rainbow appearing after rain with sunlight"):
    return science_explainer(image_description)

@app.post("/api/interactive/math-solver")
def math_solver_endpoint(problem_text: str = "What is 25 + 37?"):
    return math_solver(problem_text)

@app.post("/api/interactive/writing-coach")
def writing_coach_endpoint(text: str = "Technology has changed education. Students can now access information online. However, traditional methods still have value.", genre: str = "expository"):
    return writing_coach(text, genre)

@app.post("/api/interactive/language-exchange")
def language_exchange_endpoint(user_language: str = "Hindi", target_language: str = "English", message: str = "Namaste, aaj ka din kaisa hai?"):
    return language_exchange(user_language, target_language, message)

@app.post("/api/interactive/group-study")
def group_study_endpoint(topic: str = "Photosynthesis", questions: List[str] = ["What is photosynthesis?", "Where does it occur?", "What are the products?"]):
    return group_study_moderator(topic, questions)

@app.post("/api/interactive/project-guide")
def project_guide_endpoint(project_type: str = "Science Exhibition", subject: str = "Physics", deadline: str = "2024-03-15"):
    return project_guide(project_type, subject, deadline)

@app.post("/api/interactive/college-app")
def college_app_endpoint(profile: Dict = {"strong_subject": "Computer Science", "extracurriculars": "Coding club president", "test_scores": {"SAT": 1450, "JEE": 95}}, target_colleges: List[str] = ["IIT Bombay", "BITS Pilani", "IIIT Hyderabad"]):
    return college_application(profile, target_colleges)

@app.post("/api/interactive/study-abroad")
def study_abroad_endpoint(scores: Dict = {"GPA": 3.8, "SAT": 1400, "IELTS": 7.0}, target_country: str = "USA"):
    return study_abroad_counselor(scores, target_country)

# ========== UTILITY ENDPOINTS ==========

@app.get("/api/boards")
def get_boards():
    return {"boards": indian_boards}

@app.get("/api/chapters/{subject}/{class_level}")
def get_chapters(subject: str, class_level: int):
    chapters = subject_chapters.get(subject, {}).get(class_level, [])
    return {"subject": subject, "class_level": class_level, "chapters": chapters}

@app.get("/api/quote")
def get_quote():
    quote, author = random.choice(motivational_quotes)
    return {"quote": quote, "author": author, "timestamp": get_timestamp()}

@app.get("/api/health")
def health_check():
    return {"status": "healthy", "version": "1.0.0", "timestamp": get_timestamp(), "agents": 50}

@app.get("/api/stats")
def get_stats():
    return {
        "total_endpoints": 53,
        "agent_categories": {
            "tutor": 10,
            "content": 10,
            "assessment": 10,
            "analytics": 10,
            "interactive": 10,
            "utility": 3,
        },
        "supported_boards": list(indian_boards.keys()),
        "supported_subjects": list(subject_chapters.keys()),
    }

@app.get("/")
def root():
    return {"message": "Nexus Edu AI Backend - 50 Agent Features", "docs": "/docs", "version": "1.0.0"}
