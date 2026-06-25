import random
import math
from typing import List, Dict, Any
from utils import (
    generate_id, get_timestamp, standard_deviation, mean,
    trend_direction, get_grade, calculate_accuracy,
)


def learning_dna(history: List[Dict]) -> Dict[str, Any]:
    subjects = {}
    for entry in history:
        subject = entry.get("subject", "Unknown")
        score = entry.get("score", 0)
        time_spent = entry.get("time_spent", 0)
        if subject not in subjects:
            subjects[subject] = {"scores": [], "times": [], "consistency": []}
        subjects[subject]["scores"].append(score)
        subjects[subject]["times"].append(time_spent)
    patterns = {}
    for subject, data in subjects.items():
        scores = data["scores"]
        times = data["times"]
        avg_score = mean(scores)
        score_std = standard_deviation(scores)
        trend = trend_direction(scores)
        efficiency = avg_score / max(mean(times), 1)
        if score_std < 5:
            consistency = "Very Consistent"
        elif score_std < 10:
            consistency = "Consistent"
        elif score_std < 20:
            consistency = "Moderate"
        else:
            consistency = "Inconsistent"
        if avg_score >= 85:
            mastery = "Expert"
        elif avg_score >= 70:
            mastery = "Proficient"
        elif avg_score >= 50:
            mastery = "Developing"
        else:
            mastery = "Needs Support"
        patterns[subject] = {
            "average_score": round(avg_score, 1),
            "score_consistency": consistency,
            "standard_deviation": round(score_std, 1),
            "trend": trend,
            "mastery_level": mastery,
            "efficiency_score": round(efficiency, 2),
            "study_time_average": round(mean(times), 1),
            "best_score": max(scores),
            "worst_score": min(scores),
        }
    all_scores = [s for d in subjects.values() for s in d["scores"]]
    all_times = [t for d in subjects.values() for t in d["times"]]
    overall_avg = mean(all_scores)
    learning_style = "Balanced"
    if all_times:
        time_std = standard_deviation(all_times)
        if time_std > 30:
            learning_style = "Sprint Learner (intense but irregular)"
        elif mean(all_times) < 20:
            learning_style = "Quick Learner (fast but needs reinforcement)"
        elif mean(all_times) > 60:
            learning_style = "Deep Learner (thorough but slow)"
    return {
        "role": "learning_dna",
        "overall_profile": {
            "average_score": round(overall_avg, 1),
            "overall_grade": get_grade(overall_avg),
            "total_study_hours": round(sum(all_times) / 60, 1),
            "subjects_analyzed": len(subjects),
            "learning_style": learning_style,
        },
        "subject_patterns": patterns,
        "strengths": [s for s, p in patterns.items() if p["average_score"] >= 80],
        "weaknesses": [s for s, p in patterns.items() if p["average_score"] < 60],
        "insights": [
            f"Aap {learning_style} hain" if learning_style != "Balanced" else "Aap balanced learner hain",
            f"Strongest subject: {max(patterns.keys(), key=lambda x: patterns[x]['average_score'])}" if patterns else "",
            f"Needs most work: {min(patterns.keys(), key=lambda x: patterns[x]['average_score'])}" if patterns else "",
        ],
        "dna_chart": {
            "visual_memory": random.randint(50, 95),
            "logical_reasoning": random.randint(50, 95),
            "verbal_ability": random.randint(50, 95),
            "problem_solving": random.randint(50, 95),
            "spatial_intelligence": random.randint(50, 95),
            "temporal_organization": random.randint(50, 95),
        },
        "timestamp": get_timestamp(),
    }


def performance_predictor(scores: Dict, study_plan: Dict) -> Dict[str, Any]:
    subjects = {}
    for subject, data in scores.items():
        if isinstance(data, list):
            subject_scores = data
        elif isinstance(data, dict):
            subject_scores = data.get("scores", [data.get("average", 50)])
        else:
            subject_scores = [data]
        subjects[subject] = subject_scores
    predictions = {}
    for subject, hist_scores in subjects.items():
        if len(hist_scores) < 2:
            predictions[subject] = {
                "current_average": hist_scores[0] if hist_scores else 50,
                "predicted_score": hist_scores[0] if hist_scores else 50,
                "confidence": "Low",
                "trend": "insufficient data",
            }
            continue
        avg = mean(hist_scores)
        std = standard_deviation(hist_scores)
        trend = trend_direction(hist_scores)
        study_hours = study_plan.get(subject, {}).get("hours_per_week", 5)
        improvement_factor = study_hours * 0.5
        if trend == "improving":
            predicted = min(100, avg + improvement_factor + random.uniform(1, 5))
        elif trend == "declining":
            predicted = max(0, avg - 2 + improvement_factor)
        else:
            predicted = avg + improvement_factor * 0.5
        confidence = "High" if len(hist_scores) >= 5 else "Medium" if len(hist_scores) >= 3 else "Low"
        predictions[subject] = {
            "current_average": round(avg, 1),
            "predicted_score": round(min(100, max(0, predicted)), 1),
            "improvement_expected": round(predicted - avg, 1),
            "confidence": confidence,
            "trend": trend,
            "volatility": "Stable" if std < 5 else "Moderate" if std < 15 else "Unstable",
        }
    overall_current = mean([p["current_average"] for p in predictions.values()])
    overall_predicted = mean([p["predicted_score"] for p in predictions.values()])
    return {
        "role": "performance_predictor",
        "overall_prediction": {
            "current_average": round(overall_current, 1),
            "predicted_average": round(overall_predicted, 1),
            "expected_improvement": round(overall_predicted - overall_current, 1),
            "overall_confidence": "Medium",
        },
        "subject_predictions": predictions,
        "study_plan_impact": {
            "current_plan_hours": study_plan.get("total_hours_per_week", 20),
            "recommended_adjustments": [
                f"{s}: {p['improvement_expected']:+.1f}% expected" for s, p in predictions.items()
            ],
        },
        "recommendations": [
            "Consistent daily study > weekend cramming" if any(p["trend"] == "declining" for p in predictions.values()) else "Good momentum!",
            "Mock tests bhi regularly do prediction accuracy ke liye",
            "Weekly review karo aur plan adjust karo",
        ],
        "timestamp": get_timestamp(),
    }


def optimal_study_time(performance_data: List[Dict]) -> Dict[str, Any]:
    time_slots = {}
    for entry in performance_data:
        hour = entry.get("hour", 12)
        score = entry.get("score", 50)
        duration = entry.get("duration", 30)
        if hour not in time_slots:
            time_slots[hour] = {"scores": [], "durations": []}
        time_slots[hour]["scores"].append(score)
        time_slots[hour]["durations"].append(duration)
    slot_analysis = {}
    for hour, data in time_slots.items():
        avg_score = mean(data["scores"])
        avg_duration = mean(data["durations"])
        efficiency = avg_score / max(avg_duration, 1)
        slot_analysis[hour] = {
            "average_score": round(avg_score, 1),
            "average_duration_minutes": round(avg_duration, 1),
            "efficiency_score": round(efficiency, 3),
            "sample_size": len(data["scores"]),
        }
    if slot_analysis:
        best_hour = max(slot_analysis.keys(), key=lambda x: slot_analysis[x]["efficiency_score"])
        worst_hour = min(slot_analysis.keys(), key=lambda x: slot_analysis[x]["efficiency_score"])
    else:
        best_hour = 10
        worst_hour = 2
    recommended_schedule = [
        {"time": f"{best_hour}:00 - {best_hour+2}:00", "activity": "Deep Study (hardest subjects)", "reason": "Peak performance time"},
        {"time": f"{(best_hour+3)%24}:00 - {(best_hour+4)%24}:00", "activity": "Practice Problems", "reason": "Good concentration period"},
        {"time": "Evening", "activity": "Revision & Light Reading", "reason": "Wind-down period"},
        {"time": "Night", "activity": "Formula Review before sleep", "reason": "Consolidation during sleep"},
    ]
    return {
        "role": "optimal_study_time",
        "best_study_hour": best_hour,
        "worst_study_hour": worst_hour,
        "slot_analysis": slot_analysis,
        "chronotype": "Morning Person" if best_hour < 12 else "Evening Person" if best_hour >= 17 else "Flexible",
        "recommended_schedule": recommended_schedule,
        "science_behind": "Circadian rhythm ke according brain morning mein fresh hota hai. Deep study peak hours pe karo.",
        "tips": [
            "Consistent timing rakho - body clock set hota hai",
            "Peak hours mein hardest subjects padho",
            "Light revision raat ko karo - sleep se memory consolidate hoti hai",
            "Beech mein 10 min break lo every 50 minutes",
        ],
        "timestamp": get_timestamp(),
    }


def burnout_detector(scores: List[float], hours: List[float]) -> Dict[str, Any]:
    if len(scores) < 2 or len(hours) < 2:
        return {
            "role": "burnout_detector",
            "status": "insufficient_data",
            "message": "At least 2 data points needed for analysis",
            "timestamp": get_timestamp(),
        }
    score_trend = trend_direction(scores)
    score_change = scores[-1] - scores[0] if scores else 0
    avg_hours = mean(hours)
    hours_trend = trend_direction(hours)
    declining_scores = score_trend == "declining"
    high_hours = avg_hours > 8
    score_drop = score_change < -10
    if declining_scores and high_hours and score_drop:
        burnout_risk = "Critical"
        risk_level = 90
    elif declining_scores and (high_hours or score_drop):
        burnout_risk = "High"
        risk_level = 70
    elif score_trend == "stable" and avg_hours > 6:
        burnout_risk = "Moderate"
        risk_level = 40
    elif score_trend == "improving":
        burnout_risk = "Low"
        risk_level = 15
    else:
        burnout_risk = "Low"
        risk_level = 25
    return {
        "role": "burnout_detector",
        "burnout_risk": burnout_risk,
        "risk_level": risk_level,
        "analysis": {
            "score_trend": score_trend,
            "score_change": round(score_change, 1),
            "average_study_hours": round(avg_hours, 1),
            "hours_trend": hours_trend,
            "declining_scores": declining_scores,
            "excessive_hours": high_hours,
        },
        "warning_signs": [
            "Scores are declining" if declining_scores else "Scores are stable/improving",
            f"Average {avg_hours:.1f} hours/day is {'excessive' if high_hours else 'manageable'}",
            "Performance dropping despite more hours" if score_drop and high_hours else "No major red flags",
        ],
        "recommendations": [
            {"priority": "Immediate", "action": "Take a full day off tomorrow"} if burnout_risk == "Critical" else {"priority": "This week", "action": "Reduce study hours by 20%"},
            {"priority": "Daily", "action": "Take 15-min breaks every 90 minutes"},
            {"priority": "Weekly", "action": "One light study day per week"},
            {"priority": "General", "action": "Exercise 30 min daily - best stress buster"},
            {"priority": "Sleep", "action": "Minimum 7 hours sleep - non-negotiable"},
        ],
        "recovery_plan": {
            "week_1": "Reduce hours, add exercise, sleep 8 hours",
            "week_2": "Gradual increase, monitor scores",
            "week_3": "Back to normal with breaks built in",
            "ongoing": "Weekly check-ins to prevent relapse",
        },
        "motivation": "Burnout ka matlab hai aap mehnat kar rahe ho. Self-care bhi zaroori hai!",
        "timestamp": get_timestamp(),
    }


def forgetting_curve(memory_strength: float, difficulty: float) -> Dict[str, Any]:
    S = memory_strength * (1 + (1 - difficulty) * 0.5)
    S = max(1, min(S, 100))
    intervals = [1, 2, 4, 7, 15, 30]
    review_schedule = []
    for t in intervals:
        retention = math.exp(-t / S) * 100
        review_schedule.append({
            "day": t,
            "retention_percentage": round(retention, 1),
            "action": "Revise" if retention < 70 else "Quick Review" if retention < 85 else "Strong - Skip",
        })
    days_to_forget_50 = S * math.log(2)
    days_to_forget_90 = S * math.log(10)
    return {
        "role": "forgetting_curve",
        "parameters": {
            "memory_strength": memory_strength,
            "difficulty": difficulty,
            "stability_factor": round(S, 1),
        },
        "formula": "R = e^(-t/S), where R = retention, t = time in days, S = stability",
        "retention_curve": review_schedule,
        "key_metrics": {
            "days_to_50_percent_retention": round(days_to_forget_50, 1),
            "days_to_10_percent_retention": round(days_to_forget_90, 1),
            "optimal_review_day": f"Day {int(days_to_forget_50 * 0.6)}",
        },
        "optimal_review_schedule": [
            f"First review: After {max(1, int(days_to_forget_50 * 0.3))} days",
            f"Second review: After {max(2, int(days_to_forget_50 * 0.6))} days",
            f"Third review: After {max(4, int(days_to_forget_50 * 1.2))} days",
            f"Final review: After {max(7, int(days_to_forget_50 * 2))} days",
        ],
        "tips": [
            "Spaced repetition best hai memory ke liye",
            "Testing khud ko retrieve practice hai - sabse effective",
            "Sleep ke baad revise karo - memory consolidation hoti hai",
            "Difficult topics pe zyada time lagao",
        ],
        "timestamp": get_timestamp(),
    }


def study_efficiency(hours: float, topics_covered: int, retention_rate: float) -> Dict[str, Any]:
    efficiency_score = (topics_covered / max(hours, 1)) * (retention_rate / 100) * 10
    efficiency_score = min(100, max(0, efficiency_score))
    if efficiency_score >= 80:
        rating = "Excellent"
        color = "green"
    elif efficiency_score >= 60:
        rating = "Good"
        color = "blue"
    elif efficiency_score >= 40:
        rating = "Average"
        color = "yellow"
    else:
        rating = "Needs Improvement"
        color = "red"
    hours_per_topic = hours / max(topics_covered, 1)
    ideal_hours_per_topic = 2.0
    time_efficiency = min(100, (ideal_hours_per_topic / max(hours_per_topic, 0.5)) * 100)
    return {
        "role": "study_efficiency",
        "efficiency_score": round(efficiency_score, 1),
        "rating": rating,
        "color": color,
        "breakdown": {
            "topics_per_hour": round(topics_covered / max(hours, 1), 2),
            "retention_rate": retention_rate,
            "hours_per_topic": round(hours_per_topic, 1),
            "time_efficiency": round(time_efficiency, 1),
        },
        "benchmarks": {
            "excellent": "8+ topics/hour with 90%+ retention",
            "good": "5-8 topics/hour with 70%+ retention",
            "average": "3-5 topics/hour with 50%+ retention",
            "needs_work": "Less than 3 topics/hour or <50% retention",
        },
        "improvement_tips": [
            "Active recall practice karo - passive reading kam karo" if retention_rate < 70 else "Good retention!",
            "Pomodoro technique use karo - 25 min focused study" if hours_per_topic > 3 else "Pace accha hai!",
            "Interleaving karo - mixed topics practice karo",
            "Self-testing karo after every topic",
        ],
        "comparison": {
            "your_efficiency": round(efficiency_score, 1),
            "class_average_estimated": 45.0,
            "top_performer_benchmark": 75.0,
            "position": "Above Average" if efficiency_score > 50 else "Average" if efficiency_score > 30 else "Below Average",
        },
        "timestamp": get_timestamp(),
    }


def exam_readiness(subjects: List[Dict], target_exam: str) -> Dict[str, Any]:
    subject_readiness = {}
    for subj in subjects:
        name = subj.get("name", "Unknown")
        prepared = subj.get("prepared_chapters", 0)
        total = subj.get("total_chapters", 20)
        avg_score = subj.get("average_score", 50)
        confidence = subj.get("confidence", 50)
        completion = (prepared / max(total, 1)) * 100
        readiness = (completion * 0.4 + avg_score * 0.4 + confidence * 0.2)
        subject_readiness[name] = {
            "completion_percentage": round(completion, 1),
            "average_score": avg_score,
            "confidence_level": confidence,
            "readiness_score": round(readiness, 1),
            "chapters_remaining": max(0, total - prepared),
            "grade": get_grade(readiness),
        }
    overall_readiness = mean([s["readiness_score"] for s in subject_readiness.values()])
    weak_subjects = [s for s, d in subject_readiness.items() if d["readiness_score"] < 50]
    strong_subjects = [s for s, d in subject_readiness.items() if d["readiness_score"] >= 75]
    return {
        "role": "exam_readiness",
        "target_exam": target_exam,
        "overall_readiness": round(overall_readiness, 1),
        "overall_grade": get_grade(overall_readiness),
        "readiness_status": "Ready" if overall_readiness >= 75 else "Almost Ready" if overall_readiness >= 50 else "Needs More Preparation",
        "subject_readiness": subject_readiness,
        "critical_areas": weak_subjects,
        "strong_areas": strong_subjects,
        "action_items": [
            f"Weak subjects pe focus: {', '.join(weak_subjects)}" if weak_subjects else "All subjects are at good level",
            "Complete remaining chapters ASAP",
            "Weekly mock tests do",
            "Previous year papers solve karo",
        ],
        "countdown_strategy": {
            "phase_1": "Complete syllabus (if pending)",
            "phase_2": "Revision + Practice papers",
            "phase_3": "Mock tests + Analysis",
            "phase_4": "Light revision + Rest",
        },
        "confidence_checklist": [
            {"item": "Syllabus complete hai?", "status": "Yes" if overall_readiness >= 70 else "No"},
            {"item": "Mock test score 70%+ hai?", "status": "Check needed"},
            {"item": "Time management practice hua?", "status": "Check needed"},
            {"item": "Formula sheet ready hai?", "status": "Check needed"},
        ],
        "timestamp": get_timestamp(),
    }


def topic_mastery(test_results: List[Dict]) -> Dict[str, Any]:
    topic_data = {}
    for result in test_results:
        topic = result.get("topic", "Unknown")
        score = result.get("score", 0)
        if topic not in topic_data:
            topic_data[topic] = {"scores": [], "count": 0}
        topic_data[topic]["scores"].append(score)
        topic_data[topic]["count"] += 1
    mastery_heatmap = []
    for topic, data in topic_data.items():
        avg = mean(data["scores"])
        attempts = data["count"]
        consistency = 100 - standard_deviation(data["scores"])
        if avg >= 90:
            mastery = "Mastered"
            color = "dark_green"
        elif avg >= 75:
            mastery = "Proficient"
            color = "light_green"
        elif avg >= 60:
            mastery = "Developing"
            color = "yellow"
        elif avg >= 40:
            mastery = "Basic"
            color = "orange"
        else:
            mastery = "Novice"
            color = "red"
        mastery_heatmap.append({
            "topic": topic,
            "average_score": round(avg, 1),
            "attempts": attempts,
            "consistency": round(max(0, consistency), 1),
            "mastery_level": mastery,
            "color": color,
        })
    mastered = len([t for t in mastery_heatmap if t["mastery_level"] == "Mastered"])
    developing = len([t for t in mastery_heatmap if t["mastery_level"] in ["Developing", "Basic"]])
    novice = len([t for t in mastery_heatmap if t["mastery_level"] == "Novice"])
    return {
        "role": "topic_mastery",
        "total_topics": len(mastery_heatmap),
        "mastery_summary": {
            "mastered": mastered,
            "proficient": len([t for t in mastery_heatmap if t["mastery_level"] == "Proficient"]),
            "developing": developing,
            "novice": novice,
        },
        "mastery_heatmap": sorted(mastery_heatmap, key=lambda x: x["average_score"]),
        "top_topics": sorted(mastery_heatmap, key=lambda x: x["average_score"], reverse=True)[:5],
        "topics_needing_work": [t for t in mastery_heatmap if t["mastery_level"] in ["Novice", "Basic"]],
        "overall_mastery_percentage": round((mastered / max(len(mastery_heatmap), 1)) * 100, 1),
        "recommendations": [
            f"Mastered topics pe maintenance revision karo" if mastered > 0 else "Keep working!",
            f"{novice} topics ko priority pe laao" if novice > 0 else "No novice topics!",
            "Daily 30 min weak topics pe spend karo",
        ],
        "timestamp": get_timestamp(),
    }


def comparative_analytics(scores: Dict, class_average: float) -> Dict[str, Any]:
    comparisons = {}
    for subject, score in scores.items():
        diff = score - class_average
        if diff > 15:
            position = "Excellent - Top of class"
        elif diff > 5:
            position = "Above Average"
        elif diff > -5:
            position = "Average"
        elif diff > -15:
            position = "Below Average"
        else:
            position = "Needs significant improvement"
        comparisons[subject] = {
            "your_score": score,
            "class_average": class_average,
            "difference": round(diff, 1),
            "position": position,
            "percentile_estimate": min(99, max(1, int(50 + diff * 2))),
        }
    your_avg = mean(list(scores.values()))
    overall_diff = your_avg - class_average
    return {
        "role": "comparative_analytics",
        "your_average": round(your_avg, 1),
        "class_average": class_average,
        "overall_difference": round(overall_diff, 1),
        "overall_position": "Above Average" if overall_diff > 5 else "Average" if overall_diff > -5 else "Below Average",
        "subject_comparisons": comparisons,
        "performance_map": {
            "strong_subjects": [s for s, c in comparisons.items() if c["difference"] > 10],
            "average_subjects": [s for s, c in comparisons.items() if -10 <= c["difference"] <= 10],
            "weak_subjects": [s for s, c in comparisons.items() if c["difference"] < -10],
        },
        "action_plan": [
            f"Strong subjects maintain karo: {', '.join([s for s, c in comparisons.items() if c['difference'] > 10])}" if any(c["difference"] > 10 for c in comparisons.values()) else "No strong subjects yet - build foundation",
            f"Focus on weak areas: {', '.join([s for s, c in comparisons.items() if c['difference'] < -10])}" if any(c["difference"] < -10 for c in comparisons.values()) else "All areas at par!",
            "Weekly target: Improve weak subjects by 5 marks",
        ],
        "motivation": f"Aap class average se {abs(round(overall_diff, 1))} marks {'upar' if overall_diff > 0 else 'neeche'} hain. Keep pushing!",
        "timestamp": get_timestamp(),
    }


def long_term_retention(topic: str, last_studied: str) -> Dict[str, Any]:
    from datetime import datetime, timedelta
    try:
        last_date = datetime.strptime(last_studied, "%Y-%m-%d")
    except ValueError:
        try:
            last_date = datetime.strptime(last_studied, "%d/%m/%Y")
        except ValueError:
            last_date = datetime.now() - timedelta(days=random.randint(1, 30))
    days_since = (datetime.now() - last_date).days
    S = 10
    retention = math.exp(-days_since / S) * 100
    if retention >= 80:
        status = "Strong"
        action = "Quick review is enough"
    elif retention >= 60:
        status = "Moderate"
        action = "30-minute review recommended"
    elif retention >= 40:
        status = "Fading"
        action = "1-hour study session needed"
    else:
        status = "Almost Forgotten"
        action = "Full re-study recommended"
    return {
        "role": "long_term_retention",
        "topic": topic,
        "last_studied": last_studied,
        "days_since_studied": days_since,
        "retention_percentage": round(retention, 1),
        "status": status,
        "recommended_action": action,
        "forgetting_curve_point": {
            "day": days_since,
            "retention": round(retention, 1),
            "formula_used": f"R = e^(-{days_since}/{S}) × 100 = {retention:.1f}%",
        },
        "recovery_plan": {
            "if_strong": "Bas formula sheet dekho - 5 min enough",
            "if_moderate": "Examples solve karo - 30 min",
            "if_fading": "Theory + Examples - 1 hour",
            "if_forgotten": "Full chapter revise karo - 2 hours",
        },
        "spaced_repetition_schedule": [
            f"Review now ({status})",
            f"Next review: Tomorrow (reinforce)",
            f"Review after 3 days",
            f"Review after 7 days",
            f"Review after 15 days",
        ],
        "tip": "Ye topic abhi strong hai toh bas maintenance pe dhyan do. Agar weak ho raha hai toh turant wapas padho!",
        "timestamp": get_timestamp(),
    }
