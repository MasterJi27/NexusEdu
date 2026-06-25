import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert data["version"] == "1.0.0"


def test_health_check():
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["agents"] == 50


def test_get_stats():
    response = client.get("/api/stats")
    assert response.status_code == 200
    data = response.json()
    assert data["total_endpoints"] == 53
    assert "tutor" in data["agent_categories"]


def test_get_boards():
    response = client.get("/api/boards")
    assert response.status_code == 200
    data = response.json()
    assert "CBSE" in data["boards"]
    assert "ICSE" in data["boards"]


def test_get_chapters():
    response = client.get("/api/chapters/Mathematics/10")
    assert response.status_code == 200
    data = response.json()
    assert len(data["chapters"]) > 0
    assert "Polynomials" in data["chapters"]


def test_get_quote():
    response = client.get("/api/quote")
    assert response.status_code == 200
    data = response.json()
    assert "quote" in data
    assert "author" in data


# ========== TUTOR AGENT TESTS ==========

def test_socratic_agent():
    response = client.post("/api/tutor/socratic", json={"question": "What is 2+2?", "subject": "Mathematics"})
    assert response.status_code == 200
    data = response.json()
    assert "follow_up_questions" in data
    assert len(data["follow_up_questions"]) > 0


def test_debate_agent():
    response = client.post("/api/tutor/debate", json={"topic": "AI in Education", "user_position": "AI is beneficial", "round": 1})
    assert response.status_code == 200
    data = response.json()
    assert "opponent_argument" in data
    assert "score" in data


def test_personalized_tutor():
    response = client.post("/api/tutor/personalized", json={"subject": "Physics", "weak_areas": ["Electromagnetism"], "learning_style": "visual"})
    assert response.status_code == 200
    data = response.json()
    assert "strategy" in data
    assert "study_plan" in data


def test_anxiety_coach():
    response = client.post("/api/tutor/anxiety-coach", json={"message": "I am very stressed about my board exams"})
    assert response.status_code == 200
    data = response.json()
    assert "severity" in data
    assert "techniques" in data


def test_accountability_agent():
    response = client.post("/api/tutor/accountability", json={"study_log": [{"topic": "Polynomials", "hours": 2, "subject": "Math"}]})
    assert response.status_code == 200
    data = response.json()
    assert "summary" in data
    assert "nudge" in data


def test_career_counselor():
    response = client.post("/api/tutor/career", json={"interests": ["Science", "Technology"], "marks": {"Math": 85, "Physics": 80}, "class_level": 12})
    assert response.status_code == 200
    data = response.json()
    assert "recommended_careers" in data
    assert len(data["recommended_careers"]) > 0


def test_parent_report():
    response = client.post("/api/tutor/parent-report", json={"student_data": {"subjects": {"Math": {"avg": 85}}, "total_tests": 5, "average_score": 85, "weekly_study_hours": 15}})
    assert response.status_code == 200
    data = response.json()
    assert "student_summary" in data
    assert "recommendations" in data


def test_exam_strategy():
    response = client.post("/api/tutor/exam-strategy", json={"exam": "JEE", "subjects": [{"name": "Physics", "weightage": 25, "total_chapters": 20, "completed": 15}], "days_left": 60})
    assert response.status_code == 200
    data = response.json()
    assert "daily_plan" in data
    assert "tips" in data


def test_multi_language_tutor():
    response = client.post("/api/tutor/multi-language", json={"topic": "Algebra", "language": "Hindi"})
    assert response.status_code == 200
    data = response.json()
    assert "lesson" in data
    assert "greeting" in data["lesson"]


def test_daily_challenge():
    response = client.post("/api/tutor/daily-challenge", json={"subject": "Mathematics", "difficulty": "easy"})
    assert response.status_code == 200
    data = response.json()
    assert "challenge" in data
    assert "hint" in data


# ========== CONTENT AGENT TESTS ==========

def test_content_textbook():
    response = client.post("/api/content/textbook", json={"topic": "Polynomials", "class_level": 10, "board": "CBSE"})
    assert response.status_code == 200
    data = response.json()
    assert "sections" in data
    assert "theory" in data["sections"]


def test_content_question_paper():
    response = client.post("/api/content/question-paper", json={"blueprint": {"subject": "Math", "total_marks": 80, "time_hours": 3}})
    assert response.status_code == 200
    data = response.json()
    assert "sections" in data
    assert "instructions" in data


def test_content_lab_manual():
    response = client.post("/api/content/lab-manual", json={"experiment": {"name": "Ohm's Law", "subject": "Physics"}})
    assert response.status_code == 200
    data = response.json()
    assert "sections" in data
    assert "procedure" in data["sections"]


def test_content_story_learning():
    response = client.post("/api/content/story-learning", json={"chapter": "Electricity"})
    assert response.status_code == 200
    data = response.json()
    assert "story" in data
    assert "moral" in data


def test_content_mnemonics():
    response = client.post("/api/content/mnemonics", json={"content": "Trigonometry SOH CAH TOA"})
    assert response.status_code == 200
    data = response.json()
    assert "mnemonics" in data
    assert "tips" in data


def test_content_cheat_sheet():
    response = client.post("/api/content/cheat-sheet", json={"chapter": "Polynomials", "subject": "Mathematics", "class_level": 10})
    assert response.status_code == 200
    data = response.json()
    assert "sheet" in data
    assert "formulas" in data["sheet"]


def test_content_mind_map():
    response = client.post("/api/content/mind-map", json={"topic": "Photosynthesis", "depth": 3})
    assert response.status_code == 200
    data = response.json()
    assert "mind_map" in data
    assert "central_node" in data["mind_map"]


def test_content_audio_notes():
    response = client.post("/api/content/audio-notes", json={"content": "Newton's Laws", "emphasis_topics": ["Third Law"]})
    assert response.status_code == 200
    data = response.json()
    assert "ssml_script" in data


def test_content_video_script():
    response = client.post("/api/content/video-script", json={"topic": "Photosynthesis", "duration_minutes": 5, "style": "educational"})
    assert response.status_code == 200
    data = response.json()
    assert "segments" in data
    assert len(data["segments"]) > 0


def test_content_flashcards():
    response = client.post("/api/content/flashcards", json={"content": "Quadratic Equations applications"})
    assert response.status_code == 200
    data = response.json()
    assert "flashcards" in data
    assert len(data["flashcards"]) > 0


# ========== ASSESSMENT AGENT TESTS ==========

def test_adaptive_quiz():
    response = client.post("/api/assessment/adaptive-quiz", json={"subject": "Mathematics", "chapter": "Polynomials", "current_level": 500})
    assert response.status_code == 200
    data = response.json()
    assert "questions" in data
    assert "current_elo_rating" in data


def test_voice_viva():
    response = client.post("/api/assessment/voice-viva", json={"subject": "Physics", "chapter": "Electricity", "round": 1})
    assert response.status_code == 200
    data = response.json()
    assert "questions" in data
    assert "total_marks" in data


def test_essay_evaluator():
    response = client.post("/api/assessment/essay-eval", json={"text": "This essay discusses renewable energy. According to research, solar power is the future. However, challenges exist.", "subject": "Science", "class_level": 12})
    assert response.status_code == 200
    data = response.json()
    assert "overall_score" in data
    assert "breakdown" in data


def test_speed_math():
    response = client.post("/api/assessment/speed-math", json={"operation": "add", "range_min": 1, "range_max": 50, "count": 5})
    assert response.status_code == 200
    data = response.json()
    assert "problems" in data
    assert len(data["problems"]) == 5


def test_diagram_check():
    response = client.post("/api/assessment/diagram-check", json={"description": "Human heart with left atrium and ventricle", "expected_parts": ["Left Atrium", "Left Ventricle", "Aorta"]})
    assert response.status_code == 200
    data = response.json()
    assert "completeness_percentage" in data
    assert "results" in data


def test_concept_gap_detector():
    response = client.post("/api/assessment/concept-gap", json={"answers": [{"topic": "Algebra", "correct": True}, {"topic": "Geometry", "correct": False}]})
    assert response.status_code == 200
    data = response.json()
    assert "weak_topics" in data
    assert "identified_gaps" in data


def test_mock_interview():
    response = client.post("/api/assessment/mock-interview", json={"field": "Engineering", "experience": "2 years projects", "round": 1})
    assert response.status_code == 200
    data = response.json()
    assert "questions" in data
    assert "general_tips" in data


def test_plagiarism_checker():
    response = client.post("/api/assessment/plagiarism-check", json={"text": "This is an original essay about environmental science and sustainability."})
    assert response.status_code == 200
    data = response.json()
    assert "results" in data
    assert "verdict" in data["results"]


def test_spelling_grammar():
    response = client.post("/api/assessment/spelling-grammar", json={"text": "This text has no major errros. Their are many ways to improve."})
    assert response.status_code == 200
    data = response.json()
    assert "errors_found" in data
    assert "quality_score" in data


def test_peer_comparison():
    response = client.post("/api/assessment/peer-comparison", json={"scores": {"T1": 85, "T2": 90}, "subject": "Math"})
    assert response.status_code == 200
    data = response.json()
    assert "your_performance" in data
    assert "class_benchmark" in data


# ========== ANALYTICS AGENT TESTS ==========

def test_learning_dna():
    response = client.post("/api/analytics/learning-dna", json={"history": [{"subject": "Math", "score": 85, "time_spent": 45}, {"subject": "Physics", "score": 70, "time_spent": 60}]})
    assert response.status_code == 200
    data = response.json()
    assert "overall_profile" in data
    assert "subject_patterns" in data


def test_performance_predictor():
    response = client.post("/api/analytics/performance-predict", json={"scores": {"Math": [70, 80, 85]}, "study_plan": {"Math": {"hours_per_week": 10}}})
    assert response.status_code == 200
    data = response.json()
    assert "subject_predictions" in data
    assert "overall_prediction" in data


def test_optimal_time():
    response = client.post("/api/analytics/optimal-time", json={"performance_data": [{"hour": 8, "score": 85, "duration": 60}, {"hour": 14, "score": 70, "duration": 45}]})
    assert response.status_code == 200
    data = response.json()
    assert "best_study_hour" in data
    assert "recommended_schedule" in data


def test_burnout_detector():
    response = client.post("/api/analytics/burnout-check", json={"recent_scores": [85, 80, 75, 70, 65], "study_hours": [6, 8, 10, 12, 14]})
    assert response.status_code == 200
    data = response.json()
    assert "burnout_risk" in data
    assert "recommendations" in data


def test_forgetting_curve():
    response = client.post("/api/analytics/forgetting-curve", json={"memory_strength": 7.0, "difficulty": 0.5})
    assert response.status_code == 200
    data = response.json()
    assert "retention_curve" in data
    assert "optimal_review_schedule" in data


def test_study_efficiency():
    response = client.post("/api/analytics/study-efficiency", json={"study_hours": 10.0, "topics_covered": 8, "retention_rate": 75.0})
    assert response.status_code == 200
    data = response.json()
    assert "efficiency_score" in data
    assert "rating" in data


def test_exam_readiness():
    response = client.post("/api/analytics/exam-readiness", json={"subjects": [{"name": "Physics", "prepared_chapters": 15, "total_chapters": 20, "average_score": 75, "confidence": 70}], "target_exam": "JEE"})
    assert response.status_code == 200
    data = response.json()
    assert "overall_readiness" in data
    assert "subject_readiness" in data


def test_topic_mastery():
    response = client.post("/api/analytics/topic-mastery", json={"test_results": [{"topic": "Algebra", "score": 85}, {"topic": "Geometry", "score": 70}]})
    assert response.status_code == 200
    data = response.json()
    assert "mastery_heatmap" in data
    assert "total_topics" in data


def test_comparative_analytics():
    response = client.post("/api/analytics/peer-comparison", json={"scores": {"Math": 85, "Science": 72}, "subject": "Overall"})
    assert response.status_code == 200
    data = response.json()
    assert "your_average" in data
    assert "subject_comparisons" in data


def test_long_term_retention():
    response = client.post("/api/analytics/long-term-memory", json={"topic": "Newton's Laws", "last_studied": "2024-01-15"})
    assert response.status_code == 200
    data = response.json()
    assert "retention_percentage" in data
    assert "status" in data


# ========== INTERACTIVE AGENT TESTS ==========

def test_lab_simulator():
    response = client.post("/api/interactive/lab-sim", json={"experiment_type": "ohms_law", "parameters": {"voltage": "12V"}})
    assert response.status_code == 200
    data = response.json()
    assert "experiment" in data
    assert "steps" in data["experiment"]


def test_historical_travel():
    response = client.post("/api/interactive/historical-travel", json={"era": "ancient_india", "topic": "Education"})
    assert response.status_code == 200
    data = response.json()
    assert "dialogue" in data
    assert "character" in data


def test_science_explainer():
    response = client.post("/api/interactive/science-explainer", json={"image_description": "A rainbow appearing after rain"})
    assert response.status_code == 200
    data = response.json()
    assert "explanation" in data
    assert "scientific_principles" in data


def test_math_solver():
    response = client.post("/api/interactive/math-solver", json={"problem_text": "What is 25 + 37?"})
    assert response.status_code == 200
    data = response.json()
    assert "solution_steps" in data
    assert "answer" in data


def test_writing_coach():
    response = client.post("/api/interactive/writing-coach", json={"text": "Technology transforms education. It provides access to information.", "genre": "expository"})
    assert response.status_code == 200
    data = response.json()
    assert "overall_score" in data
    assert "scores" in data


def test_language_exchange():
    response = client.post("/api/interactive/language-exchange", json={"user_language": "Hindi", "target_language": "English", "message": "Namaste, thank you"})
    assert response.status_code == 200
    data = response.json()
    assert "translations" in data
    assert "grammar_notes" in data


def test_group_study():
    response = client.post("/api/interactive/group-study", json={"topic": "Photosynthesis", "questions": ["What is it?", "How does it work?"]})
    assert response.status_code == 200
    data = response.json()
    assert "session_plan" in data
    assert "ground_rules" in data


def test_project_guide():
    response = client.post("/api/interactive/project-guide", json={"project_type": "Science Fair", "subject": "Physics", "deadline": "2024-06-01"})
    assert response.status_code == 200
    data = response.json()
    assert "phases" in data
    assert "days_left" in data


def test_college_application():
    response = client.post("/api/interactive/college-app", json={"profile": {"strong_subject": "CS", "extracurriculars": "Coding"}, "target_colleges": ["IIT Bombay"]})
    assert response.status_code == 200
    data = response.json()
    assert "sop_drafts" in data
    assert "application_checklist" in data


def test_study_abroad():
    response = client.post("/api/interactive/study-abroad", json={"scores": {"GPA": 3.8, "IELTS": 7.0}, "target_country": "USA"})
    assert response.status_code == 200
    data = response.json()
    assert "country_info" in data
    assert "application_timeline" in data
