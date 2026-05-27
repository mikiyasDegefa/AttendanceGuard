// lib/screens/history_screen.dart
// NOTE: No delete buttons — history is permanent and tamper-proof by design.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/connection_record.dart';
import '../services/tracker_service.dart';

class HistoryScreen extends StatefulWidget {
  final TrackerService tracker;
  const HistoryScreen({super.key, required this.tracker});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ConnectionRecord> _records = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await widget.tracker.getHistory();
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  List<ConnectionRecord> get _filtered {
    switch (_filter) {
      case 'ontime':
        return _records
            .where((r) => r.status == ConnectionStatus.onTime)
            .toList();
      case 'delayed':
        return _records
            .where((r) => r.status == ConnectionStatus.delayed)
            .toList();
      default:
        return _records;
    }
  }

  double get _totalFines =>
      _records.fold(0, (sum, r) => sum + r.fineAmount);

  int get _delayedCount =>
      _records.where((r) => r.status == ConnectionStatus.delayed).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Attendance History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        // No delete/clear button — history is permanent
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
          : Column(
              children: [
                // ── Summary bar ────────────────────────────────────────────
                if (_records.isNotEmpty)
                  _SummaryBar(
                    total: _records.length,
                    delayed: _delayedCount,
                    totalFines: _totalFines,
                  ),

                // ── Filter chips ───────────────────────────────────────────
                if (_records.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _FilterChip('All', 'all', _filter,
                            (v) => setState(() => _filter = v)),
                        const SizedBox(width: 8),
                        _FilterChip('On Time', 'ontime', _filter,
                            (v) => setState(() => _filter = v)),
                        const SizedBox(width: 8),
                        _FilterChip('Late', 'delayed', _filter,
                            (v) => setState(() => _filter = v)),
                      ],
                    ),
                  ),

                // ── List ───────────────────────────────────────────────────
                Expanded(
                  child: _records.isEmpty
                      ? const _EmptyState()
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No ${_filter == "ontime" ? "on-time" : _filter} records.',
                                style: const TextStyle(color: Colors.white38),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 24),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) =>
                                  _RecordTile(record: filtered[i]),
                            ),
                ),
              ],
            ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int total;
  final int delayed;
  final double totalFines;
  const _SummaryBar(
      {required this.total,
      required this.delayed,
      required this.totalFines});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141828),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat('Total', '$total', Colors.white),
          _Stat('On Time', '${total - delayed}', const Color(0xFF4CAF50)),
          _Stat('Late', '$delayed', const Color(0xFFFF6B6B)),
          _Stat('Total Fines',
              'ETB ${totalFines.toStringAsFixed(2)}', const Color(0xFFFFB347)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10)),
        ],
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onChanged;
  const _FilterChip(this.label, this.value, this.current, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00D4FF)
              : const Color(0xFF1A1F35),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? const Color(0xFF0A0E1A)
                : Colors.white60,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// No onDelete callback — history is immutable
class _RecordTile extends StatelessWidget {
  final ConnectionRecord record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final isDelayed = record.status == ConnectionStatus.delayed;
    final color =
        isDelayed ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50);
    final fmt = DateFormat('EEE, MMM d  HH:mm');
    final dateFmt = DateFormat('MMM d, yyyy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141828),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDelayed
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isDelayed ? 'LATE' : 'ON TIME',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                dateFmt.format(record.connectedAt),
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
              // ← No delete button here
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checked in: ${fmt.format(record.connectedAt)}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Expected:   ${DateFormat('HH:mm').format(record.expectedTime)}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MAC: ${record.wifiBSSID}',
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              if (isDelayed)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+${record.delayMinutes} min late',
                      style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'ETB ${record.fineAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Color(0xFFFFB347),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.history_toggle_off_rounded,
                size: 64, color: Colors.white12),
            SizedBox(height: 16),
            Text(
              'No attendance records yet',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Connect to your attendance WiFi\nto start tracking',
              style: TextStyle(color: Colors.white24, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
