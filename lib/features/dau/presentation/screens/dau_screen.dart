import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DauScreen extends StatefulWidget {
  const DauScreen({super.key});

  @override
  State<DauScreen> createState() => _DauScreenState();
}

class _DauScreenState extends State<DauScreen> {
  String _walletAddress = '';
  Map<String, dynamic> _wallet = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final prefs = await SharedPreferences.getInstance();
    var addr = prefs.getString('dau_wallet_address');
    if (addr == null) {
      addr = '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(40, '0').substring(0, 40)}';
      await prefs.setString('dau_wallet_address', addr);
    }
    final raw = prefs.getString('dau_wallet_data');
    if (raw != null) {
      _wallet = Map<String, dynamic>.from(json.decode(raw));
    } else {
      _wallet = {
        'enrolled': <String>[],
        'voted': <String>[],
        'degreeMinted': false,
        'tokens': ['Genesis Learner', 'Quiz Master', 'Streak Holder', 'Knowledge Miner'],
      };
    }
    _walletAddress = addr;
    setState(() => _loading = false);
  }

  Future<void> _saveWallet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dau_wallet_data', json.encode(_wallet));
    setState(() {});
  }

  void _enrollCourse(String courseName) async {
    final enrolled = List<String>.from(_wallet['enrolled'] as List);
    if (!enrolled.contains(courseName)) {
      enrolled.add(courseName);
      _wallet['enrolled'] = enrolled;
      await _saveWallet();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enrolled via smart contract #${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}')),
      );
    }
  }

  void _voteProposal(String proposalId) async {
    final voted = List<String>.from(_wallet['voted'] as List);
    if (!voted.contains(proposalId)) {
      voted.add(proposalId);
      _wallet['voted'] = voted;
      await _saveWallet();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vote cast on-chain.')),
      );
    }
  }

  void _mintDegree() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        title: Text('Minting Degree...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating Zero-Knowledge Proof...'),
          ],
        ),
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context);

    _wallet['degreeMinted'] = true;
    await _saveWallet();

    final txHash = '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}${Random().nextInt(99999).toRadixString(16)}';
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.verified, color: Colors.greenAccent),
            const SizedBox(width: 8),
            const Text('Degree Minted'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nexus Edu Bachelor of Knowledge'),
            const SizedBox(height: 8),
            Text(txHash, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            const SizedBox(height: 4),
            const Text('ZKP Verified | Soulbound | Non-transferable'),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final enrolled = List<String>.from(_wallet['enrolled'] as List);
    final voted = List<String>.from(_wallet['voted'] as List);
    final tokens = List<String>.from(_wallet['tokens'] as List);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Decentralized University', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.withAlpha(40), Colors.orange.withAlpha(20)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.amberAccent),
                    const SizedBox(width: 8),
                    const Text('Student Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_walletAddress, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white70)),
                const SizedBox(height: 4),
                Text('$tokens Tokens | ${enrolled.length} Courses${_wallet['degreeMinted'] == true ? ' | Degree Minted' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(150))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Soulbound Tokens', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: GridView.count(
              crossAxisCount: 4,
              childAspectRatio: 0.9,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: tokens.map((t) => Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(40)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified, color: Colors.amberAccent, size: 18),
                    const SizedBox(height: 4),
                    Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9)),
                    Text('on-chain', style: TextStyle(fontSize: 7, color: Colors.green.withAlpha(180))),
                  ],
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Active Courses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...[
            'Quantum Computing',
            'Neural Interface',
            'DAO Governance',
            'Zero-Knowledge Crypto',
          ].map((course) => Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                enrolled.contains(course) ? Icons.check_circle : Icons.radio_button_unchecked,
                color: enrolled.contains(course) ? Colors.greenAccent : Colors.white54,
              ),
              title: Text(course, style: const TextStyle(fontSize: 14)),
              trailing: enrolled.contains(course)
                  ? Text('Enrolled', style: TextStyle(fontSize: 12, color: Colors.greenAccent))
                  : ElevatedButton(onPressed: () => _enrollCourse(course), child: const Text('Enroll')),
            ),
          )),
          const SizedBox(height: 24),
          const Text('DAO Proposals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...[
            {'id': 'p1', 'title': 'Add Quantum Computing', 'votes': '1.2K Yes / 340 No'},
            {'id': 'p2', 'title': 'Increase quiz difficulty 20%', 'votes': '890 Yes / 567 No'},
            {'id': 'p3', 'title': 'Partner with MIT OCW', 'votes': '2.1K Yes / 120 No'},
          ].map((prop) => Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prop['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(prop['votes'] as String, style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(120))),
                  const SizedBox(height: 8),
                  Row(
                    children: voted.contains(prop['id'])
                        ? [Text('Voted', style: TextStyle(color: Colors.greenAccent))]
                        : [
                            ElevatedButton(
                              onPressed: () => _voteProposal(prop['id'] as String),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withAlpha(60)),
                              child: const Text('Yes', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _voteProposal(prop['id'] as String),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withAlpha(60)),
                              child: const Text('No', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                  ),
                ],
              ),
            ),
          )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(_wallet['degreeMinted'] == true ? Icons.verified : Icons.workspace_premium),
              label: Text(_wallet['degreeMinted'] == true ? 'Degree Minted' : 'Mint Your Degree'),
              onPressed: _wallet['degreeMinted'] == true ? null : _mintDegree,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.withAlpha(60),
                minimumSize: const Size(double.infinity, 52),
                side: BorderSide(color: Colors.amber.withAlpha(120)),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
