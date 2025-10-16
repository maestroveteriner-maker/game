import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlappyAnimeApp());
}

class FlappyAnimeApp extends StatelessWidget {
  const FlappyAnimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flappy Anime',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  // Physics
  double _birdY = 0.0; // -1..1 (normalized world)
  double _birdX = -0.5; // x is mostly fixed; pipes move
  double _velocity = 0.0;
  final double _gravity = -0.0045;
  final double _flapImpulse = 0.08;

  // Pipes
  final List<_Pipe> _pipes = [];
  double _pipeSpeed = 0.008;
  final double _gap = 0.32; // normalized height gap
  final Random _rand = Random();
  int _score = 0;
  bool _running = false;
  bool _gameOver = false;

  Timer? _timer;

  // World width in normalized units (x -1..1), we use x in same normalized space
  void _resetGame() {
    _birdY = 0.0;
    _velocity = 0.0;
    _pipes.clear();
    _score = 0;
    _gameOver = false;
    // initial pipes
    for (int i = 0; i < 3; i++) {
      _pipes.add(_generatePipe(startX: 1.2 + i * 0.8));
    }
  }

  _Pipe _generatePipe({double startX = 1.2}) {
    // gap center between -0.7 .. 0.7
    final center = (_rand.nextDouble() * 1.4) - 0.7;
    return _Pipe(x: startX, gapCenter: center, gap: _gap, passed: false);
  }

  void _start() {
    _resetGame();
    _running = true;
    const dt = Duration(milliseconds: 16);
    _timer?.cancel();
    _timer = Timer.periodic(dt, (_) => _update());
    setState(() {});
  }

  void _end() {
    _running = false;
    _gameOver = true;
    _timer?.cancel();
    setState(() {});
    // Show dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Oyun Bitti!'),
        content: Text('Skorun: $_score'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Kapat'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _start();
            },
            child: const Text('Yeniden Oyna'),
          ),
        ],
      ),
    );
  }

  void _update() {
    if (!_running) return;

    // Physics step
    _velocity += _gravity;
    _birdY += _velocity;

    // Move pipes
    for (int i = 0; i < _pipes.length; i++) {
      _pipes[i] = _pipes[i].shift(-_pipeSpeed);
    }

    // Recycle pipes + score
    if (_pipes.isNotEmpty && _pipes.first.x < -1.4) {
      _pipes.removeAt(0);
      _pipes.add(_generatePipe(startX: _pipes.last.x + 0.8));
    }
    for (int i = 0; i < _pipes.length; i++) {
      final p = _pipes[i];
      if (!p.passed && p.x < _birdX) {
        _pipes[i] = p.copyWith(passed: true);
        _score++;
        // softly ramp difficulty
        _pipeSpeed = min(0.014, _pipeSpeed + 0.0004);
      }
    }

    // Collision check
    // World coordinate: y -1..1; the gap is (gapCenter-gap/2 .. gapCenter+gap/2)
    final pipeW = 0.18;
    for (final p in _pipes) {
      final xMin = p.x - pipeW / 2;
      final xMax = p.x + pipeW / 2;
      // Bird as circle with radius
      const birdR = 0.07;
      if (_birdX + birdR > xMin && _birdX - birdR < xMax) {
        // Inside pipe's x-span; check y vs gap
        final gmin = p.gapCenter - p.gap / 2;
        final gmax = p.gapCenter + p.gap / 2;
        if (_birdY + birdR > gmax || _birdY - birdR < gmin) {
          _end();
          return;
        }
      }
    }

    // Bounds (floor/ceiling)
    if (_birdY < -1.0 || _birdY > 1.0) {
      _end();
      return;
    }

    if (mounted) setState(() {});
  }

  void _flap() {
    if (!_running) {
      _start();
      return;
    }
    _velocity = _flapImpulse;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        title: const Text('Flappy Anime'),
        actions: [
          IconButton(
            onPressed: _running ? null : _start,
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Başlat',
          ),
          IconButton(
            onPressed: !_running ? null : () { _resetGame(); _running = false; setState(() {}); },
            icon: const Icon(Icons.stop),
            tooltip: 'Durdur',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _flap,
            child: Stack(
              children: [
                // Starry background
                Positioned.fill(child: CustomPaint(painter: _StarsPainter())),
                // Pipes
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PipePainter(pipes: _pipes),
                  ),
                ),
                // Bird (anime sprite)
                _buildBird(size),
                // HUD
                Positioned(
                  top: 12, left: 12, right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Chip(icon: Icons.timer, label: _running ? 'Uç!' : (_gameOver ? 'Bitti' : 'Hazır')),
                      _Chip(icon: Icons.star, label: '$_score'),
                    ],
                  ),
                ),
                if (!_running && !_gameOver)
                  Center(
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('Flappy Anime', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            Text('Ekrana dokunarak zıpla. Boruların arasından geç ve skor topla!'),
                            SizedBox(height: 12),
                            Text('Başlamak için ekrana dokun.'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBird(Size size) {
    // Convert normalized world coords to pixels: x -1..1 => 0..width, y -1..1 => 0..height (inverted y)
    double px = ( (_birdX + 1) / 2 ) * size.width;
    double py = ( (1 - (_birdY + 1) / 2) ) * size.height;
    const birdSize = 56.0;
    return Positioned(
      left: px - birdSize/2,
      top: py - birdSize/2,
      width: birdSize,
      height: birdSize,
      child: Image.asset('assets/anime_bird.png'),
    );
  }
}

class _Pipe {
  final double x;        // center x (-inf..inf)
  final double gapCenter; // y center (-1..1)
  final double gap;
  final bool passed;
  const _Pipe({required this.x, required this.gapCenter, required this.gap, this.passed = false});
  _Pipe shift(double dx) => _Pipe(x: x + dx, gapCenter: gapCenter, gap: gap, passed: passed);
  _Pipe copyWith({double? x, double? gapCenter, double? gap, bool? passed}) =>
      _Pipe(x: x ?? this.x, gapCenter: gapCenter ?? this.gapCenter, gap: gap ?? this.gap, passed: passed ?? this.passed);
}

class _PipePainter extends CustomPainter {
  final List<_Pipe> pipes;
  _PipePainter({required this.pipes});

  @override
  void paint(Canvas canvas, Size size) {
    final pipeW = size.width * 0.18;
    final paint = Paint()..color = const Color(0xFF48E5C2);
    final capPaint = Paint()..color = const Color(0xFF2EC4B6);

    for (final p in pipes) {
      final cx = ( (p.x + 1)/2 ) * size.width;
      final gapH = p.gap * size.height / 2; // since y normalized -1..1
      final cy = ( (1 - (p.gapCenter + 1)/2) ) * size.height;
      final topRect = Rect.fromLTWH(cx - pipeW/2, 0, pipeW, max(0, cy - gapH));
      final botRect = Rect.fromLTWH(cx - pipeW/2, cy + gapH, pipeW, size.height - (cy + gapH));

      canvas.drawRect(topRect, paint);
      canvas.drawRect(Rect.fromLTWH(topRect.left, topRect.bottom - 16, pipeW, 16), capPaint);

      canvas.drawRect(botRect, paint);
      canvas.drawRect(Rect.fromLTWH(botRect.left, botRect.top, pipeW, 16), capPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PipePainter oldDelegate) => oldDelegate.pipes != pipes;
}

class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(42);
    final star = Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.7);
    for (int i = 0; i < 160; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), rnd.nextDouble() * 1.5, star);
    }
  }
  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) => false;
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}
