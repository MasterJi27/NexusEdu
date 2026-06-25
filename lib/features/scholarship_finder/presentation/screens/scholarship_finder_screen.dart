import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScholarshipFinderScreen extends StatefulWidget {
  const ScholarshipFinderScreen({super.key});

  @override
  State<ScholarshipFinderScreen> createState() =>
      _ScholarshipFinderScreenState();
}

class _ScholarshipFinderScreenState extends State<ScholarshipFinderScreen> {
  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _bookmarks = [];
  List<Map<String, dynamic>> _scholarships = [];
  bool _isSearching = false;
  bool _isLoading = true;

  String _filterState = 'All';
  String _filterCategory = 'All';
  String _filterAmount = 'All';

  final List<String> _states = [
    'All',
    'Andhra Pradesh',
    'Bihar',
    'Delhi',
    'Gujarat',
    'Karnataka',
    'Kerala',
    'Maharashtra',
    'Punjab',
    'Rajasthan',
    'Tamil Nadu',
    'Uttar Pradesh',
    'West Bengal',
  ];
  final List<String> _categories = [
    'All',
    'General',
    'OBC',
    'SC',
    'ST',
  ];
  final List<String> _amounts = [
    'All',
    'Up to ₹10,000',
    '₹10,000 - ₹50,000',
    '₹50,000 - ₹1,00,000',
    'Above ₹1,00,000',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('scholarship_data');
    if (raw != null) {
      final decoded = Map<String, dynamic>.from(json.decode(raw));
      _profile = Map<String, dynamic>.from(decoded['profile'] ?? {});
      _bookmarks = (decoded['bookmarks'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      _scholarships = (decoded['scholarships'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'profile': _profile,
      'bookmarks': _bookmarks,
      'scholarships': _scholarships,
    };
    await prefs.setString('scholarship_data', json.encode(data));
  }

  void _showProfileForm() {
    final nameCtrl = TextEditingController(text: _profile['name'] ?? '');
    final classCtrl = TextEditingController(text: _profile['class'] ?? '');
    final incomeCtrl =
        TextEditingController(text: _profile['familyIncome'] ?? '');
    final percentageCtrl =
        TextEditingController(text: _profile['percentage'] ?? '');
    String category = _profile['category'] ?? 'General';
    String state = _profile['state'] ?? 'Delhi';
    String board = _profile['board'] ?? 'CBSE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Your Profile',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _profileField('Name', nameCtrl),
                const SizedBox(height: 10),
                _profileField('Class', classCtrl),
                const SizedBox(height: 10),
                _profileField('Family Income (Annual)', incomeCtrl),
                const SizedBox(height: 10),
                _profileField('Percentage', percentageCtrl),
                const SizedBox(height: 10),
                _dropdownField('Category', category, _categories, (v) {
                  setDialogState(() => category = v!);
                }),
                const SizedBox(height: 10),
                _dropdownField('State', state, _states, (v) {
                  setDialogState(() => state = v!);
                }),
                const SizedBox(height: 10),
                _dropdownField(
                    'Board',
                    board,
                    ['CBSE', 'ICSE', 'State Board', 'IB', 'Other'],
                    (v) {
                  setDialogState(() => board = v!);
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _profile = {
                    'name': nameCtrl.text.trim(),
                    'class': classCtrl.text.trim(),
                    'category': category,
                    'familyIncome': incomeCtrl.text.trim(),
                    'state': state,
                    'board': board,
                    'percentage': percentageCtrl.text.trim(),
                  };
                });
                _saveData();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withAlpha(10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dropdownField(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF1E1E1E),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withAlpha(10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _findScholarships() async {
    if (_profile.isEmpty) {
      _showProfileForm();
      return;
    }
    setState(() => _isSearching = true);

    final response = await AiService.sendMessageToTutor(
      "Find scholarships for a student with profile: "
      "Name: ${_profile['name']}, Class: ${_profile['class']}, "
      "Category: ${_profile['category']}, Income: ${_profile['familyIncome']}, "
      "State: ${_profile['state']}, Board: ${_profile['board']}, "
      "Percentage: ${_profile['percentage']}. "
      "Return JSON array of 5-8 scholarships. Each must have: "
      "\"name\", \"amount\" (string like '₹50,000'), \"deadline\" (string), "
      "\"eligibility\" (string), \"link\" (string, placeholder URL), "
      "\"provider\" (string). Raw JSON only, no markdown.",
    );

    try {
      String cleaned = response.trim();
      if (cleaned.startsWith('```')) {
        final lines = cleaned.split('\n');
        if (lines.first.startsWith('```')) lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
        cleaned = lines.join('\n').trim();
      }
      final parsed = json.decode(cleaned);
      if (parsed is List) {
        final results = parsed
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() {
          _scholarships = results;
          _isSearching = false;
        });
        _saveData();
        return;
      }
    } catch (_) {}

    final fallback = [
      {
        'name': 'National Merit Scholarship',
        'amount': '₹50,000/year',
        'deadline': '2026-08-15',
        'eligibility': 'Class 10+, 80%+ marks, Any category',
        'link': 'https://scholarships.gov.in',
        'provider': 'Government of India',
      },
      {
        'name': 'State Merit Award',
        'amount': '₹25,000/year',
        'deadline': '2026-07-30',
        'eligibility': 'Class 12, 75%+ marks, ${_profile['state']} domicile',
        'link': 'https://scholarships.gov.in',
        'provider': '${_profile['state']} Government',
      },
      {
        'name': '${_profile['category']} Community Scholarship',
        'amount': '₹30,000/year',
        'deadline': '2026-09-01',
        'eligibility': '${_profile['category']} category, Family income < ₹8 LPA',
        'link': 'https://scholarships.gov.in',
        'provider': 'Social Welfare Dept',
      },
    ];
    setState(() {
      _scholarships = fallback;
      _isSearching = false;
    });
    _saveData();
  }

  void _toggleBookmark(Map<String, dynamic> scholarship) {
    final exists = _bookmarks
        .any((b) => b['name'] == scholarship['name']);
    setState(() {
      if (exists) {
        _bookmarks
            .removeWhere((b) => b['name'] == scholarship['name']);
      } else {
        _bookmarks.add(scholarship);
      }
    });
    _saveData();
  }

  bool _isBookmarked(Map<String, dynamic> scholarship) {
    return _bookmarks.any((b) => b['name'] == scholarship['name']);
  }

  List<Map<String, dynamic>> _getFilteredScholarships() {
    return _scholarships.where((s) {
      if (_filterState != 'All' &&
          !(s['eligibility'] ?? '').contains(_filterState) &&
          !(s['provider'] ?? '').contains(_filterState)) {
        return false;
      }
      if (_filterCategory != 'All' &&
          !(s['eligibility'] ?? '').contains(_filterCategory)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Scholarship Finder',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white70),
            onPressed: _showProfileForm,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.deepPurpleAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProfileSummary(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSearching ? null : _findScholarships,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search, color: Colors.white),
                    label: Text(
                      _isSearching ? 'Searching...' : 'Find Scholarships',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildFilterChips(),
                const SizedBox(height: 16),
                if (_scholarships.isNotEmpty) ...[
                  Row(
                    children: [
                      const Text('Results',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('${_getFilteredScholarships().length} found',
                          style: TextStyle(
                              color: Colors.white.withAlpha(100),
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._getFilteredScholarships()
                      .asMap()
                      .entries
                      .map((entry) => _buildScholarshipCard(entry.value, entry.key)),
                ],
                if (_bookmarks.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('Bookmarked',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._bookmarks.asMap().entries.map(
                      (entry) => _buildBookmarkCard(entry.value, entry.key)),
                ],
                if (_scholarships.isEmpty && !_isSearching) ...[
                  const SizedBox(height: 60),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.school,
                            size: 80,
                            color: Colors.white.withAlpha(20)),
                        const SizedBox(height: 16),
                        Text(
                          'Complete your profile and\nsearch for scholarships',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(80),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildProfileSummary() {
    if (_profile.isEmpty) {
      return GestureDetector(
        onTap: _showProfileForm,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.deepPurpleAccent.withAlpha(40)),
          ),
          child: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.deepPurpleAccent, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Complete your profile to find\npersonalized scholarships',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ).animate().fade();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.deepPurpleAccent.withAlpha(30),
                child: Text(
                  (_profile['name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.deepPurpleAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_profile['name'] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text(
                        'Class ${_profile['class'] ?? ''} · ${_profile['board'] ?? ''}',
                        style: TextStyle(
                            color: Colors.white.withAlpha(100),
                            fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                onPressed: _showProfileForm,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _profileChip('Category', _profile['category'] ?? ''),
              _profileChip('State', _profile['state'] ?? ''),
              _profileChip(
                  'Income', '₹${_profile['familyIncome'] ?? 'N/A'}'),
              _profileChip(
                  'Marks', '${_profile['percentage'] ?? 'N/A'}%'),
            ],
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _profileChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('State', _filterState, _states, (v) {
            setState(() => _filterState = v);
          }),
          const SizedBox(width: 8),
          _filterChip('Category', _filterCategory, _categories, (v) {
            setState(() => _filterCategory = v);
          }),
          const SizedBox(width: 8),
          _filterChip('Amount', _filterAmount, _amounts, (v) {
            setState(() => _filterAmount = v);
          }),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, List<String> options,
      Function(String) onChanged) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1E1E1E),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: options
                .map((opt) => ListTile(
                      title: Text(opt,
                          style: TextStyle(
                            color: opt == value
                                ? Colors.deepPurpleAccent
                                : Colors.white,
                            fontWeight: opt == value
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                      trailing: opt == value
                          ? const Icon(Icons.check,
                              color: Colors.deepPurpleAccent)
                          : null,
                      onTap: () {
                        onChanged(opt);
                        Navigator.pop(ctx);
                      },
                    ))
                .toList(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value != 'All'
              ? Colors.deepPurpleAccent.withAlpha(30)
              : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value != 'All'
                ? Colors.deepPurpleAccent.withAlpha(60)
                : Colors.white.withAlpha(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: $value',
              style: TextStyle(
                color: value != 'All'
                    ? Colors.deepPurpleAccent
                    : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                color:
                    value != 'All' ? Colors.deepPurpleAccent : Colors.white54,
                size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildScholarshipCard(
      Map<String, dynamic> scholarship, int index) {
    final bookmarked = _isBookmarked(scholarship);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: bookmarked
                ? Colors.amber.withAlpha(40)
                : Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scholarship['name'] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text(scholarship['provider'] ?? '',
                        style: TextStyle(
                            color: Colors.white.withAlpha(100),
                            fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: bookmarked ? Colors.amber : Colors.white54,
                ),
                onPressed: () => _toggleBookmark(scholarship),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _scholarshipBadge('Amount', scholarship['amount'] ?? '',
                  Colors.green),
              const SizedBox(width: 8),
              _scholarshipBadge('Deadline', scholarship['deadline'] ?? '',
                  Colors.orange),
            ],
          ),
          const SizedBox(height: 10),
          Text('Eligibility',
              style: TextStyle(
                  color: Colors.white.withAlpha(120),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(scholarship['eligibility'] ?? '',
              style:
                  TextStyle(color: Colors.white.withAlpha(150), fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Apply Now'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurpleAccent,
                side: BorderSide(
                    color: Colors.deepPurpleAccent.withAlpha(60)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade(delay: (60 * index).ms).slideY(begin: 0.03);
  }

  Widget _buildBookmarkCard(
      Map<String, dynamic> scholarship, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scholarship['name'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text('${scholarship['amount'] ?? ''} · ${scholarship['deadline'] ?? ''}',
                    style: TextStyle(
                        color: Colors.white.withAlpha(100), fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white38, size: 18),
            onPressed: () => _toggleBookmark(scholarship),
          ),
        ],
      ),
    ).animate().fade(delay: (40 * index).ms);
  }

  Widget _scholarshipBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
