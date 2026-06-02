// lib/screens/home/leaderboard_screen.dart
// CHANGES from previous version:
//   • Fetches real data from /api/v1/leaderboard via ApiClient.getLeaderboard()
//   • Falls back to mock data when backend returns empty (no clicks yet)
//   • Shows "Live" badge when using real data, "Demo" when using mock
//   • my_entry from backend drives the rank pin (no hardcoded rank 23)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/places_provider.dart';
import '../../../services/api_client.dart';

// ── Unified display model (used by both real + mock paths) ────────────────────
class _LeaderEntry {
  final int          rank;
  final String       username;
  final int          weeklyXp;
  final int          totalXp;
  final int          badgeCount;
  final bool         isYou;

  const _LeaderEntry({
    required this.rank,
    required this.username,
    required this.weeklyXp,
    required this.totalXp,
    required this.badgeCount,
    this.isYou = false,
  });
}

// ── Mock data (used when backend has no data yet) ─────────────────────────────
List<_LeaderEntry> _buildMock(String myUsername) {
  const names = [
    'Rahul K', 'Priya S', 'Aman J',  'Sneha P',  'Vikram R',
    'Ananya M','Rohan T', 'Divya N',  'Karan L',  'Meera B',
    'Arjun D', 'Pooja G', 'Sahil W',  'Nisha C',  'Tarun E',
  ];
  return List.generate(names.length, (i) => _LeaderEntry(
    rank:       i + 1,
    username:   names[i],
    weeklyXp:   2400 - i * 140 + (i % 3 * 30),
    totalXp:    15000 - i * 800,
    badgeCount: (3 - i ~/ 5).clamp(0, 4),
    isYou:      names[i] == myUsername,
  )) + [
    _LeaderEntry(
      rank: 23, username: myUsername,
      weeklyXp: 340, totalXp: 1200,
      badgeCount: 2, isYou: true,
    ),
  ];
}

// ── Convert backend model to display model ────────────────────────────────────
_LeaderEntry _fromApi(LeaderboardEntryModel m, String myUsername) =>
    _LeaderEntry(
      rank:       m.rank,
      username:   m.username,
      weeklyXp:   m.weeklyXp,
      totalXp:    m.totalXp,
      badgeCount: m.badgeCount,
      isYou:      m.username == myUsername,
    );

// ════════════════════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════════════════════
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {

  late TabController    _tabs;
  List<_LeaderEntry>    _entries    = [];
  _LeaderEntry?         _myEntry;
  bool                  _loading    = true;
  bool                  _isLiveData = false;  // true = from backend

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<PlacesProvider>();
    final city     = provider.currentCity;
    final me       = provider.userName;

    // Try real backend first
    final result = await ApiClient.getLeaderboard(
      city:     city,
      username: me,
    );

    if (!mounted) return;

    if (!result.isEmpty && result.entries.isNotEmpty) {
      // ── Real data ─────────────────────────────────────────
      setState(() {
        _entries    = result.entries.map((e) => _fromApi(e, me)).toList();
        _myEntry    = result.myEntry != null
            ? _fromApi(result.myEntry!, me)
            : null;
        _isLiveData = true;
        _loading    = false;
      });
    } else {
      // ── Mock fallback ─────────────────────────────────────
      // Small delay so the spinner feels intentional
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _entries    = _buildMock(me);
        _myEntry    = _entries.firstWhere(
          (e) => e.isYou,
          orElse: () => _entries.last,
        );
        _isLiveData = false;
        _loading    = false;
      });
    }
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final city = context.read<PlacesProvider>().currentCity;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('LEADERBOARD',
                    style: TextStyle(
                      color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.w700, letterSpacing: 2,
                    )),
                const SizedBox(width: 6),
                // Live / Demo badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isLiveData
                        ? const Color(0xFF2ECC71).withOpacity(0.18)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isLiveData ? '● LIVE' : 'DEMO',
                    style: TextStyle(
                      color: _isLiveData
                          ? const Color(0xFF2ECC71)
                          : Colors.white38,
                      fontSize: 9, fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            Text(city.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white38, fontSize: 11, letterSpacing: 1.5,
                )),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor:       const Color(0xFFFF6B35),
          labelColor:           const Color(0xFFFF6B35),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'This Week'), Tab(text: 'All Time')],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : Stack(
              children: [
                TabBarView(
                  controller: _tabs,
                  children: [
                    _buildList(weekly: true),
                    _buildList(weekly: false),
                  ],
                ),
                if (_myEntry != null && _myEntry!.rank > 10)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: _MyRankPin(entry: _myEntry!),
                  ),
              ],
            ),
    );
  }

  Widget _buildList({required bool weekly}) {
    final top3 = _entries.take(3).toList();
    final rest = _entries.skip(3).take(12).toList();

    return ListView(
      padding: EdgeInsets.only(
        bottom: _myEntry != null && _myEntry!.rank > 10 ? 80 : 16,
      ),
      children: [
        if (top3.length >= 3) _Podium(top3: top3, weekly: weekly),
        const SizedBox(height: 8),
        ...rest.map((e) => _LeaderRow(entry: e, weekly: weekly)),
        // Demo note when using mock data
        if (!_isLiveData)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'Leaderboard fills up as people explore restaurants in ${ context.read<PlacesProvider>().currentCity}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────
class _Podium extends StatelessWidget {
  final List<_LeaderEntry> top3;
  final bool weekly;
  const _Podium({required this.top3, required this.weekly});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF161B27), Color(0xFF1A1F2E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _PodiumItem(entry: top3[1], height: 80,  weekly: weekly)),
          Expanded(child: _PodiumItem(entry: top3[0], height: 110, weekly: weekly, isFirst: true)),
          Expanded(child: _PodiumItem(entry: top3[2], height: 60,  weekly: weekly)),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final _LeaderEntry entry;
  final double height;
  final bool   weekly;
  final bool   isFirst;
  const _PodiumItem({
    required this.entry, required this.height,
    required this.weekly, this.isFirst = false,
  });

  static const _medals = ['🥇','🥈','🥉'];
  static const _colors = [
    Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[entry.rank - 1];
    final xp    = weekly ? entry.weeklyXp : entry.totalXp;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst) const Text('👑', style: TextStyle(fontSize: 20)),
        Container(
          width:  isFirst ? 52 : 44,
          height: isFirst ? 52 : 44,
          decoration: BoxDecoration(
            color:  color.withOpacity(0.2),
            shape:  BoxShape.circle,
            border: Border.all(color: color, width: isFirst ? 2 : 1),
          ),
          child: Center(
            child: Text(entry.username[0].toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: isFirst ? 20 : 16,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ),
        const SizedBox(height: 6),
        Text(entry.username.split(' ')[0],
            style: const TextStyle(
                color: Colors.white70, fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('${(xp / 1000).toStringAsFixed(1)}k XP',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border:       Border.all(color: color.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(_medals[entry.rank - 1],
                style: const TextStyle(fontSize: 20)),
          ),
        ),
      ],
    );
  }
}

// ── Rank row ──────────────────────────────────────────────────────────────────
class _LeaderRow extends StatelessWidget {
  final _LeaderEntry entry;
  final bool weekly;
  const _LeaderRow({required this.entry, required this.weekly});

  // Build badge emojis from badgeCount
  String get _badgeStr {
    const emojis = ['🏆','🔥','⭐','💎','🌍','🎯','🥇','🍛'];
    return emojis.take(entry.badgeCount).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final xp = weekly ? entry.weeklyXp : entry.totalXp;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin:  const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: entry.isYou
            ? const Color(0xFFFF6B35).withOpacity(0.1)
            : const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.isYou
              ? const Color(0xFFFF6B35).withOpacity(0.4)
              : Colors.white.withOpacity(0.05),
          width: entry.isYou ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('#${entry.rank}',
                style: TextStyle(
                  color: entry.isYou
                      ? const Color(0xFFFF6B35)
                      : Colors.white30,
                  fontSize: 13, fontWeight: FontWeight.w700,
                )),
          ),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (entry.isYou
                  ? const Color(0xFFFF6B35)
                  : Colors.white).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(entry.username[0].toUpperCase(),
                  style: TextStyle(
                    color: entry.isYou
                        ? const Color(0xFFFF6B35)
                        : Colors.white60,
                    fontWeight: FontWeight.w700, fontSize: 14,
                  )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isYou ? '${entry.username} (You)' : entry.username,
                  style: TextStyle(
                    color: entry.isYou
                        ? const Color(0xFFFF6B35)
                        : Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.badgeCount > 0)
                  Text(_badgeStr,
                      style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
          Text('${(xp / 1000).toStringAsFixed(1)}k',
              style: TextStyle(
                color: entry.isYou
                    ? const Color(0xFFFF6B35)
                    : Colors.white60,
                fontSize: 14, fontWeight: FontWeight.w700,
              )),
          const SizedBox(width: 4),
          const Text('XP',
              style: TextStyle(color: Colors.white24, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── My rank pin ───────────────────────────────────────────────────────────────
class _MyRankPin extends StatelessWidget {
  final _LeaderEntry entry;
  const _MyRankPin({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        const Color(0xFF1A0D00),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFFF6B35).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF6B35).withOpacity(0.15),
              blurRadius: 20),
        ],
      ),
      child: Row(
        children: [
          const Text('📍 Your rank',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const Spacer(),
          Text('#${entry.rank}',
              style: const TextStyle(
                color: Color(0xFFFF6B35), fontSize: 16,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(width: 12),
          Text('${entry.weeklyXp} XP this week',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}