import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InterestSelectionScreen extends StatefulWidget {
  const InterestSelectionScreen({super.key});

  @override
  State<InterestSelectionScreen> createState() => _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  final List<String> _interests = [
    'Computer Science', 'Mathematics', 'Physics', 'Biology', 
    'Chemistry', 'History', 'Literature', 'Languages', 
    'Pre-Med', 'Engineering', 'Psychology', 'Economics'
  ];
  
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                'Personalize Your AI.',
                style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1.2),
              ).animate().slideY(begin: -0.2).fade(),
              const SizedBox(height: 16),
              const Text(
                'What are you currently studying? Pick 3 or more to configure your personalized AI tutor.',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ).animate().slideY(begin: -0.2, delay: 200.ms).fade(),
              const SizedBox(height: 48),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 16,
                    children: _interests.asMap().entries.map((entry) {
                      final index = entry.key;
                      final interest = entry.value;
                      final isSelected = _selected.contains(interest);
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(interest);
                            } else {
                              _selected.add(interest);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.deepPurpleAccent : Colors.white.withAlpha(20),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: isSelected ? Colors.deepPurpleAccent : Colors.white24),
                            boxShadow: isSelected ? [BoxShadow(color: Colors.deepPurpleAccent.withAlpha(100), blurRadius: 15)] : [],
                          ),
                          child: Text(
                            interest,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ).animate().scale(delay: (300 + (index * 50)).ms, curve: Curves.easeOutBack);
                    }).toList(),
                  ),
                ),
              ),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selected.length >= 3 ? () => context.go('/login') : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white24,
                    disabledForegroundColor: Colors.white54,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ).animate().slideY(begin: 1, delay: 1.seconds),
            ],
          ),
        ),
      ),
    );
  }
}
