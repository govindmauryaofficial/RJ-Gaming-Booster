import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'access_plans.dart';

void main() => runApp(const RJGamingBoosterApp());

const red = Color(0xFFFF334F);
const bg = Color(0xFF090A0F);
const panel = Color(0xFF171922);
const muted = Color(0xFF9DA3B4);
const host = '1.1.1.1';
const port = 443;

class RJGamingBoosterApp extends StatelessWidget {
  const RJGamingBoosterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RJ Gaming Booster',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: red, brightness: Brightness.dark, surface: panel),
        useMaterial3: true,
        cardTheme: const CardThemeData(color: panel, elevation: 0),
      ),
      home: const BoosterHome(),
    );
  }
}

class PingSample {
  final DateTime time;
  final int? ms;
  PingSample(this.time, this.ms);
}

class BoosterHome extends StatefulWidget {
  const BoosterHome({super.key});
  @override
  State<BoosterHome> createState() => _BoosterHomeState();
}

class _BoosterHomeState extends State<BoosterHome> with WidgetsBindingObserver {
  Timer? _timer;
  bool _monitoring = false, _checking = false, _speedTesting = false;
  int? _ping, _jitter;
  double _probeFailure = 0;
  double? _download, _upload;
  String _status = 'Ready to test', _connection = 'Not checked';
  final List<PingSample> _samples = [];
  int _probeCount = 0, _probeFailed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopMonitoring();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList('ping_history') ?? [];
    if (!mounted) return;
    setState(() {
      for (final value in values.take(30)) {
        final parts = value.split('|');
        if (parts.length == 2) {
          final date = DateTime.tryParse(parts[0]);
          final ms = int.tryParse(parts[1]);
          if (date != null) _samples.add(PingSample(date, ms));
        }
      }
      if (_samples.isNotEmpty) _ping = _samples.last.ms;
    });
  }

  Future<void> _saveSample(PingSample sample) async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList('ping_history') ?? [];
    values.insert(0, '${sample.time.toIso8601String()}|${sample.ms ?? -1}');
    await prefs.setStringList('ping_history', values.take(30).toList());
  }

  Future<int?> _measureTcpLatency() async {
    final watch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      watch.stop();
      return watch.elapsedMilliseconds;
    } catch (_) {
      watch.stop();
      return null;
    } finally {
      socket?.destroy();
    }
  }

  Future<void> _probe() async {
    if (_checking) return;
    _checking = true;
    final result = await _measureTcpLatency();
    if (!mounted) { _checking = false; return; }
    setState(() {
      _probeCount++;
      if (result == null) {
        _probeFailed++;
        _ping = null;
        _status = 'Probe failed — check connection';
      } else {
        final previous = _ping;
        _ping = result;
        _jitter = previous == null ? 0 : (result - previous).abs();
        _status = result < 80 ? 'Connection looks responsive' : result < 150 ? 'Moderate latency' : 'High latency detected';
      }
      _probeFailure = _probeCount == 0 ? 0 : _probeFailed / _probeCount * 100;
      final sample = PingSample(DateTime.now(), result);
      _samples.insert(0, sample);
      if (_samples.length > 30) _samples.removeLast();
    });
    await _saveSample(PingSample(DateTime.now(), result));
    _checking = false;
  }

  Future<void> _autoCheck() async {
    setState(() => _connection = 'Checking…');
    final result = await _measureTcpLatency();
    if (!mounted) return;
    setState(() => _connection = result == null ? 'Connection check failed' : 'Internet reachable • TCP ${result} ms');
  }

  void _startMonitoring() {
    if (_monitoring) return;
    setState(() {
      _monitoring = true;
      _status = 'Live monitoring active';
      _probeCount = 0;
      _probeFailed = 0;
    });
    _probe();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _probe());
  }

  void _stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    if (mounted && _monitoring) setState(() { _monitoring = false; _status = 'Monitoring paused'; });
  }

  Future<void> _runSpeedTest() async {
    if (_speedTesting) return;
    setState(() { _speedTesting = true; _download = null; _upload = null; _status = 'Running speed test…'; });
    final client = http.Client();
    try {
      final downWatch = Stopwatch()..start();
      final response = await client.get(Uri.parse('https://speed.cloudflare.com/__down?bytes=5000000')).timeout(const Duration(seconds: 25));
      downWatch.stop();
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) throw Exception('Download test unavailable');
      final downMbps = response.bodyBytes.length * 8 / downWatch.elapsedMilliseconds / 1000;
      final payload = List<int>.generate(1000000, (i) => i % 251);
      final upWatch = Stopwatch()..start();
      final uploadResponse = await client.post(Uri.parse('https://speed.cloudflare.com/__up'), body: payload, headers: {'Content-Type': 'application/octet-stream'}).timeout(const Duration(seconds: 25));
      upWatch.stop();
      if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) throw Exception('Upload test unavailable');
      final upMbps = payload.length * 8 / upWatch.elapsedMilliseconds / 1000;
      if (!mounted) return;
      setState(() { _download = downMbps; _upload = upMbps; _status = 'Speed test complete'; });
    } catch (_) {
      if (mounted) setState(() => _status = 'Speed test unavailable. Try again.');
    } finally {
      client.close();
      if (mounted) setState(() => _speedTesting = false);
    }
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ping_history');
    if (mounted) setState(() => _samples.clear());
  }

  Color _pingColor() {
    if (_ping == null) return muted;
    if (_ping! < 80) return const Color(0xFF4DE0A1);
    if (_ping! < 150) return const Color(0xFFFFC857);
    return red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        titleSpacing: 20,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RJ GAMING', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 18)),
          Text('BOOSTER', style: TextStyle(color: red, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 3)),
        ]),
        actions: [
          IconButton(tooltip: 'Access plans and admin', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccessPlansPage())), icon: const Icon(Icons.workspace_premium_outlined, color: red)),
          IconButton(tooltip: 'Clear ping history', onPressed: _clearHistory, icon: const Icon(Icons.delete_outline, color: muted)),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
          _heroCard(),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _metricCard('JITTER', _jitter == null ? '—' : '${_jitter!} ms', Icons.swap_vert, 'Change between readings')),
            const SizedBox(width: 12),
            Expanded(child: _metricCard('PROBE FAILURES', '${_probeFailure.toStringAsFixed(1)}%', Icons.warning_amber_rounded, 'Not ICMP packet loss')),
          ]),
          const SizedBox(height: 14),
          _sectionTitle('NETWORK TOOLS'),
          const SizedBox(height: 10),
          _toolCard(icon: Icons.radar, title: 'Auto Network Check', subtitle: _connection, button: 'CHECK', onPressed: _autoCheck),
          const SizedBox(height: 10),
          _toolCard(icon: Icons.speed, title: 'Internet Speed Test', subtitle: _download == null ? 'Measure download and upload throughput' : '↓ ${_download!.toStringAsFixed(1)} Mbps   ↑ ${_upload!.toStringAsFixed(1)} Mbps', button: _speedTesting ? 'TESTING' : 'TEST', onPressed: _speedTesting ? null : _runSpeedTest),
          const SizedBox(height: 14),
          _sectionTitle('PING HISTORY'),
          const SizedBox(height: 8),
          _historyCard(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(.06))),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: red, size: 19),
              SizedBox(width: 10),
              Expanded(child: Text('This app measures TCP connection latency to 1.1.1.1, not the actual game server ping. Probe failures are not true ICMP packet loss. Keep the app open while monitoring.', style: TextStyle(color: muted, fontSize: 11, height: 1.45))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF35111B), Color(0xFF19121A), Color(0xFF171922)]),
        border: Border.all(color: red.withOpacity(.35)),
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.wifi_tethering, color: red, size: 18),
          const SizedBox(width: 7),
          const Text('LIVE NETWORK PING', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Colors.white70, fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: _monitoring ? const Color(0xFF17452F) : Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(20)),
            child: Text(_monitoring ? 'MONITORING' : 'READY', style: TextStyle(fontSize: 9, color: _monitoring ? const Color(0xFF4DE0A1) : Colors.white70)),
          ),
        ]),
        const SizedBox(height: 20),
        Text(_ping == null ? '--' : '$_ping', style: TextStyle(fontSize: 62, height: 1, fontWeight: FontWeight.w900, color: _pingColor())),
        const Text('milliseconds • TCP latency', style: TextStyle(color: muted, fontSize: 11)),
        const SizedBox(height: 13),
        Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _monitoring ? const Color(0xFF343640) : red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _monitoring ? _stopMonitoring : _startMonitoring,
          icon: Icon(_monitoring ? Icons.pause : Icons.play_arrow),
          label: Text(_monitoring ? 'STOP MONITORING' : 'START LIVE MONITOR'),
        )),
      ]),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, String note) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: red, size: 19),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 21)),
        const SizedBox(height: 3),
        Text(title, style: const TextStyle(fontSize: 9, color: muted, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(note, style: const TextStyle(fontSize: 9, color: muted)),
      ]),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: Colors.white70));

  Widget _toolCard({required IconData icon, required String title, required String subtitle, required String button, required VoidCallback? onPressed}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: red.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: red)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: muted, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onPressed, style: OutlinedButton.styleFrom(foregroundColor: red, side: const BorderSide(color: red), padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(58, 36)), child: Text(button, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _historyCard() {
    if (_samples.isEmpty) {
      return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('No readings yet. Start live monitoring.', style: TextStyle(color: muted, fontSize: 12))));
    }
    final recent = _samples.take(12).toList().reversed.toList();
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 92, width: double.infinity, child: CustomPaint(painter: PingChartPainter(recent))),
        const SizedBox(height: 10),
        ..._samples.take(5).map((sample) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            const Icon(Icons.circle, color: red, size: 7),
            const SizedBox(width: 8),
            Text('${sample.time.hour.toString().padLeft(2, '0')}:${sample.time.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: muted, fontSize: 10)),
            const Spacer(),
            Text(sample.ms == null ? 'Failed' : '${sample.ms} ms', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ]),
        )),
      ]),
    );
  }
}

class PingChartPainter extends CustomPainter {
  final List<PingSample> samples;
  PingChartPainter(this.samples);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withOpacity(.07)..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final values = samples.where((s) => s.ms != null).toList();
    if (values.length < 2) return;
    final maxValue = max(100, values.map((s) => s.ms!).reduce(max)).toDouble();
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i].ms! / maxValue) * (size.height - 8) - 4;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    final paint = Paint()..color = red..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PingChartPainter oldDelegate) => true;
}
