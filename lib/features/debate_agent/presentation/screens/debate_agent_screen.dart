import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';

class DebateAgentScreen extends StatefulWidget {
  const DebateAgentScreen({super.key});

  @override
  State<DebateAgentScreen> createState() => _DebateAgentScreenState();
}

class _DebateAgentScreenState extends State<DebateAgentScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _argumentController = TextEditingController();
  bool _isLoading = false;
  bool _debateStarted = false;
  String _topic = '';
  String _userSide = 'For';
  int _round = 0;
  int _userScore = 0;
  int _aiScore = 0;
  final List<Map<String, dynamic>> _rounds = [];
  bool _debateOver = false;
  static const int _maxRounds = 5;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('debate_history');
    if (saved != null && saved.isNotEmpty) {
      final last = jsonDecode(saved.last) as Map<String, dynamic>;
      if (last['debateOver'] == false && last['topic'] != null) {
        _topic = last['topic'] ?? '';
        _topicController.text = _topic;
      }
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('debate_history') ?? [];
    history.add(jsonEncode({
      'topic': _topic,
      'userSide': _userSide,
      'rounds': _rounds,
      'userScore': _userScore,
      'aiScore': _aiScore,
      'debateOver': _debateOver,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (history.length > 20) history.removeAt(0);
    await prefs.setStringList('debate_history', history);
  }

  void _startDebate() {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;
    setState(() {
      _topic = topic;
      _debateStarted = true;
      _round = 0;
      _userScore = 0;
      _aiScore = 0;
      _rounds.clear();
      _debateOver = false;
    });
  }

  void _pickSide(String side) {
    setState(() => _userSide = side);
  }

  Future<void> _submitArgument() async {
    final text = _argumentController.text.trim();
    if (text.isEmpty || _isLoading || _debateOver) return;

    setState(() {
      _isLoading = true;
    });
    _argumentController.clear();

    final userArgument = {
      'round': _round + 1,
      'userText': text,
      'userSide': _userSide,
    };

    final aiSide = _userSide == 'For' ? 'Against' : 'For';
    final aiPrompt = 'Topic: $_topic\n'
        'The student argues ${_userSide}: "$text"\n'
        'You argue $aiSide. Provide a strong counter-argument. '
        'Then rate the student\'s argument quality from 1-10. '
        'Format your response as:\nARGUMENT: [your counter-argument]\n'
        'SCORE: [1-10]';

    final aiResponse = await AiAgentService.callAgent('custom', {'prompt': aiPrompt});

    String aiArgument = aiResponse;
    int userArgumentScore = 7;

    if (aiResponse.contains('ARGUMENT:') && aiResponse.contains('SCORE:')) {
      final parts = aiResponse.split('SCORE:');
      aiArgument = parts.first.replaceAll('ARGUMENT:', '').trim();
      final scoreStr = parts.last.trim();
      final parsed = int.tryParse(scoreStr.replaceAll(RegExp(r'[^0-9]'), ''));
      if (parsed != null && parsed >= 1 && parsed <= 10) {
        userArgumentScore = parsed;
      }
    }

    final aiArgumentScore = (10 - userArgumentScore + Random().nextInt(3) - 1).clamp(1, 10);

    if (!mounted) return;

    setState(() {
      _round++;
      _userScore += userArgumentScore;
      _aiScore += aiArgumentScore;
      _rounds.add({
        ...userArgument,
        'aiText': aiArgument,
        'userArgumentScore': userArgumentScore,
        'aiArgumentScore': aiArgumentScore,
      });
      _isLoading = false;

      if (_round >= _maxRounds) {
        _debateOver = true;
      }
    });

    _saveHistory();
  }

  void _resetDebate() {
    setState(() {
      _debateStarted = false;
      _topic = '';
      _topicController.clear();
      _round = 0;
      _userScore = 0;
      _aiScore = 0;
      _rounds.clear();
      _debateOver = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Debate Agent', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_debateStarted)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withAlpha(40),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurpleAccent.withAlpha(80)),
              ),
              child: Text('R${_round + 1}/$_maxRounds',
                  style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      ),
      body: !_debateStarted ? _buildSetupScreen() : _debateOver ? _buildVerdictScreen() : _buildDebateScreen(),
    );
  }

  Widget _buildSetupScreen() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.gavel, size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
          const SizedBox(height: 16),
          const Text('Start a Debate', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Challenge the AI to a debate! Enter a topic and pick your side.',
              style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14)),
          const SizedBox(height: 24),
          TextField(
            controller: _topicController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter debate topic...',
              hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.deepPurpleAccent)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Pick your side:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSideButton('For', Icons.thumb_up, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildSideButton('Against', Icons.thumb_down, Colors.redAccent)),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _topicController.text.trim().isEmpty ? null : _startDebate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Start Debate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSideButton(String side, IconData icon, Color color) {
    final isSelected = _userSide == side;
    return GestureDetector(
      onTap: () => _pickSide(side),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(40) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : Colors.white.withAlpha(20), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.white54, size: 28),
            const SizedBox(height: 8),
            Text(side, style: TextStyle(color: isSelected ? color : Colors.white54, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ).animate().fade();
  }

  Widget _buildDebateScreen() {
    return Column(
      children: [
        _buildScoreBar(),
        Expanded(child: _buildRoundList()),
        _buildArgumentInput(),
      ],
    );
  }

  Widget _buildScoreBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          _buildScoreChip('You', _userScore, _userSide == 'For' ? Colors.green : Colors.redAccent),
          const SizedBox(width: 8),
          Text(_topic, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          _buildScoreChip('AI', _aiScore, Colors.deepPurpleAccent),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildScoreChip(String label, int score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$label: $score', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildRoundList() {
    if (_rounds.isEmpty) {
      return Center(
        child: Text('Your turn! Submit your first argument.',
            style: TextStyle(color: Colors.white.withAlpha(100))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rounds.length,
      itemBuilder: (context, index) {
        final round = _rounds[index];
        return _buildRoundCard(round);
      },
    );
  }

  Widget _buildRoundCard(Map<String, dynamic> round) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Round ${round['round']}', style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text('Score: ${round['userArgumentScore']}/10',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          _buildArgumentBubble('You (${round['userSide']})', round['userText'], Colors.green),
          const SizedBox(height: 8),
          _buildArgumentBubble('AI', round['aiText'], Colors.deepPurpleAccent),
        ],
      ),
    ).animate().fade().slideX(begin: 0.1);
  }

  Widget _buildArgumentBubble(String speaker, String text, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(speaker, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(text, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13, height: 1.4)),
      ],
    );
  }

  Widget _buildArgumentInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1E1E1E),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _argumentController,
                enabled: !_isLoading && !_debateOver,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Your argument (${_userSide})...',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                  filled: true,
                  fillColor: const Color(0xFF0F0F13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.deepPurpleAccent)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _submitArgument(),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _submitArgument,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent))
                    : const Icon(Icons.send, color: Colors.deepPurpleAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerdictScreen() {
    final winner = _userScore > _aiScore ? 'You' : _userScore < _aiScore ? 'AI' : 'Tie';
    final winnerColor = winner == 'You' ? Colors.green : winner == 'AI' ? Colors.redAccent : Colors.amberAccent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Icon(Icons.emoji_events, size: 72, color: winnerColor),
          const SizedBox(height: 16),
          Text('$winner ${winner == 'Tie' ? '' : 'Wins!'}',
              style: TextStyle(color: winnerColor, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_topic, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14)),
          const SizedBox(height: 24),
          _buildVerdictScoreCard(),
          const SizedBox(height: 20),
          _buildScoreBreakdown(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetDebate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('New Debate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerdictScoreCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              const Text('You', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text('$_userScore', style: const TextStyle(color: Colors.green, fontSize: 36, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(8)),
            child: const Text('VS', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
          Column(
            children: [
              const Text('AI', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text('$_aiScore', style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 36, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    ).animate().fade().scale();
  }

  Widget _buildScoreBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Round-by-Round', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._rounds.asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text('R${i + 1}', style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12)),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: (r['userArgumentScore'] as int) * 12.0,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(180),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${r['userArgumentScore']}', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: (r['aiArgumentScore'] as int) * 12.0,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.deepPurpleAccent.withAlpha(180),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${r['aiArgumentScore']}', style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
