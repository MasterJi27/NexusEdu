from pydantic import BaseModel
from typing import List, Optional, Dict, Any


class QuestionRequest(BaseModel):
    board: str = "CBSE"
    class_level: int = 10
    subject: str = "Mathematics"
    chapter: str = "Polynomials"
    num_questions: int = 10
    difficulty: str = "medium"
    time_limit: int = 30


class Question(BaseModel):
    id: str
    text: str
    options: List[str]
    correct_index: int
    difficulty: str
    chapter: str


class QuizSession(BaseModel):
    questions: List[Question]
    score: int
    total: int
    time_taken: int
    subject: str
    chapter: str


class TutorMessage(BaseModel):
    role: str
    content: str
    timestamp: str


class StudyPlanRequest(BaseModel):
    subjects: List[str]
    exam_date: str
    daily_hours: float = 4.0


class PerformanceData(BaseModel):
    tests: List[Dict]
    subjects: List[str]


class HomeworkRequest(BaseModel):
    image_description: str
    subject: str
    class_level: int = 10


class EssayRequest(BaseModel):
    text: str
    subject: str
    class_level: int = 10


class DebateRequest(BaseModel):
    topic: str
    user_position: str
    round: int = 1


class CareerRequest(BaseModel):
    interests: List[str]
    marks: Dict[str, float]
    class_level: int = 12


class ContentRequest(BaseModel):
    topic: str
    class_level: int = 10
    board: str = "CBSE"
    format: str = "textbook"


class VivaRequest(BaseModel):
    subject: str
    chapter: str
    round: int = 1


class MindMapRequest(BaseModel):
    topic: str
    depth: int = 3


class MnemonicRequest(BaseModel):
    content: str
    type: str = "formula"


class CheatSheetRequest(BaseModel):
    chapter: str
    subject: str
    class_level: int = 10


class AdaptiveQuizRequest(BaseModel):
    subject: str
    chapter: str
    current_level: int = 500


class ConceptGapRequest(BaseModel):
    answers: List[Dict]


class StudyEfficiencyRequest(BaseModel):
    study_hours: float
    topics_covered: int
    retention_rate: float


class ExamReadinessRequest(BaseModel):
    subjects: List[Dict]
    target_exam: str


class PerformancePredictRequest(BaseModel):
    current_scores: Dict
    study_plan: Dict


class OptimalTimeRequest(BaseModel):
    performance_data: List[Dict]


class BurnoutRequest(BaseModel):
    recent_scores: List[float]
    study_hours: List[float]


class LabSimRequest(BaseModel):
    experiment_type: str
    parameters: Dict = {}


class HistoryRequest(BaseModel):
    era: str
    topic: str


class WritingCoachRequest(BaseModel):
    text: str
    genre: str


class LanguageExchangeRequest(BaseModel):
    user_language: str
    target_language: str
    message: str


class ProjectGuideRequest(BaseModel):
    project_type: str
    subject: str
    deadline: str


class CollegeAppRequest(BaseModel):
    profile: Dict
    target_colleges: List[str]


class StudyAbroadRequest(BaseModel):
    scores: Dict
    target_country: str


class GroupStudyRequest(BaseModel):
    topic: str
    questions: List[str]


class ScienceExplainerRequest(BaseModel):
    image_description: str


class MathSolverRequest(BaseModel):
    problem_text: str


class SpellingCheckRequest(BaseModel):
    text: str


class PlagiarismCheckRequest(BaseModel):
    text: str


class DiagramCheckRequest(BaseModel):
    description: str
    expected_parts: List[str]


class SpeedMathRequest(BaseModel):
    operation: str = "add"
    range_min: int = 1
    range_max: int = 100
    count: int = 10


class MockInterviewRequest(BaseModel):
    field: str
    experience: str
    round: int = 1


class AudioNotesRequest(BaseModel):
    content: str
    emphasis_topics: List[str] = []


class VideoScriptRequest(BaseModel):
    topic: str
    duration_minutes: int = 5
    style: str = "educational"


class PeerComparisonRequest(BaseModel):
    scores: Dict
    subject: str


class LongTermMemoryRequest(BaseModel):
    topic: str
    last_studied: str


class ForgettingCurveRequest(BaseModel):
    memory_strength: float
    difficulty: float


class ExamStrategyRequest(BaseModel):
    exam: str
    subjects: List[Dict]
    days_left: int


class AnxietyCheckRequest(BaseModel):
    message: str


class DailyChallengeRequest(BaseModel):
    subject: str
    difficulty: str = "medium"


class StateBoardRequest(BaseModel):
    state: str
    subject: str
    class_level: int = 10
