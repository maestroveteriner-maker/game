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

class _GamePageState extends State<GamePage> {
  // Kuş durumu
  double _birdY = 0.0;     // -1..1
  final double _birdX = -0.5;
  double _velocity = 0.0;

  // Yumuşatılmış fizik
  final double _gravity = -0.0028;
  final double _flapImpulse = 0.055;
  final double _maxRise = 0.12;
  final double _maxFall = -0.04;

  // Borular ve oyun
  final List<_Pipe> _pipes = [];
  final Random _rand = Random();
  final double _gap = 0.36;
  double _pipeSpeed = 0.008;
  int _score = 0;
  bool _running = false;
  bool _gameOver = false;

  // Geri sayım
  bool _countingDown = false;
  int _countdown = 3;

  Timer? _timer;
  Timer? _countdownTimer;

  // --- Oyun akışı ---
  void _resetGame() {
    _birdY = 0.0;
    _velocity = 0.0;
    _pipes.clear();
    _score = 0;
    _pipeSpeed = 0.008;
    _gameOver = false;
    _countingDown = false;
    _countdown = 3;

    for (int i = 0; i < 3; i++) {
      _pipes.add(_generatePipe(startX: 1.2 + i * 0.8));
    }
  }

  _Pipe _generatePipe({double startX = 1.2}) {
    final center = (_rand.nextDouble() * 1.4) - 0.7; // -0.7..0.7
    return _Pipe(x: startX, gapCenter: center, gap: _gap, passed: false);
  }

  void _start() {
    _resetGame();
    _countingDown = true;
    _countdown = 3;
    setState(() {});

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _countingDown = false;
        _running = true;
        _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _update());
      }
    });
  }

  void _end() {
    _running = false;
    _gameOver = true;
    _timer?.cancel();
    setState(() {});
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Oyun Bitti!'),
        content: Text('Skorun: $_score'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Kapat')),
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

    // Fizik
    _velocity += _gravity;
    if (_velocity > _maxRise) _velocity = _maxRise;
    if (_velocity < _maxFall) _velocity = _maxFall;
    _birdY += _velocity;

    // Borular hareket/geri dönüşüm
    for (int i = 0; i < _pipes.length; i++) {
      _pipes[i] = _pipes[i].shift(-_pipeSpeed);
    }
    if (_pipes.isNotEmpty && _pipes.first.x < -1.4) {
      _pipes.removeAt(0);
      _pipes.add(_generatePipe(startX: _pipes.last.x + 0.8));
    }

    // Skor ve zorluk artışı
    for (int i = 0; i < _pipes.length; i++) {
      final p = _pipes[i];
      if (!p.passed && p.x < _birdX) {
        _pipes[i] = p.copyWith(passed: true);
        _score++;
        _pipeSpeed = min(0.014, _pipeSpeed + 0.0004);
      }
    }

    // Çarpışma
    const double birdR = 0.07;
    const double pipeWNorm = 0.18; // normalized genişlik
    for (final p in _pipes) {
      final xMin = p.x - pipeWNorm / 2;
      final xMax = p.x + pipeWNorm / 2;
      if (_birdX + birdR > xMin && _birdX - birdR < xMax) {
        final gmin = p.gapCenter - p.gap / 2;
        final gmax = p.gapCenter + p.gap / 2;
        if (_birdY + birdR > gmax || _birdY - birdR < gmin) {
          _end();
          return;
        }
      }
    }

    // Tavan/zemin
    if (_birdY < -1.0 || _birdY > 1.0) {
      _end();
      return;
    }

    if (mounted) setState(() {});
  }

  void _flap() {
    if (_countingDown) return;
    if (!_running && !_gameOver) {
      _start();
      return;
    }
    // momentum sönümleme + zıplama
    final double damped = _velocity * 0.3;
    _velocity = damped + _flapImpulse;
    if (_velocity > _maxRise) _velocity = _maxRise;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ---- ZORUNLU build METODU (hata bundan kaynaklanıyordu) ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(title: const Text('Flappy Anime')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _flap,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _StarsPainter())),
                Positioned.fill(child: CustomPaint(painter: _PipePainter(pipes: _pipes))),
                _buildBird(size),
                // HUD
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Chip(icon: Icons.timer, label: _running ? 'Uç!' : (_gameOver ? 'Bitti' : 'Hazır')),
                      _Chip(icon: Icons.star, label: '$_score'),
                    ],
                  ),
                ),
                // Başlangıç kartı
                if (!_running && !_gameOver && !_countingDown)
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
                // Geri sayım
                if (_countingDown)
                  const _CountdownOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBird(Size size) {
    // normalized (-1..1) -> pixel
    final px = ((_birdX + 1) / 2) * size.width;
    final py = (1 - (_birdY + 1) / 2) * size.height;
    const birdSize = 56.0;
    return Positioned(
      left: px - birdSize / 2,
      top: py - birdSize / 2,
      width: birdSize,
      height: birdSize,
      child: Image.asset('assets/anime_bird.png'),
    );
  }
}

// Basit geri sayım overlay’i
class _CountdownOverlay extends StatefulWidget {
  const _CountdownOverlay();
  @override
  State<_CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<_CountdownOverlay> {
  int _n = 3;
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      setState(() => _n--);
      if (_n < -1) _t.cancel();
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _n > 0 ? '$_n' : (_n == 0 ? 'Başla!' : '');
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: text.isEmpty ? 0 : 1,
          duration: const Duration(milliseconds: 250),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.pink, blurRadius: 10)],
            ),
          ),
        ),
      ),
    );
  }
}

// Veri sınıfları ve çizerler
class _Pipe {
  final double x;         // merkez x
  final double gapCenter; // -1..1
  final double gap;       // aralık yüksekliği
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
      final cx = ((p.x + 1) / 2) * size.width;
      final gapH = p.gap * size.height / 2;
      final cy = (1 - (p.gapCenter + 1) / 2) * size.height;

      final topRect = Rect.fromLTWH(cx - pipeW / 2, 0, pipeW, max(0, cy - gapH));
      final botRect = Rect.fromLTWH(cx - pipeW / 2, cy + gapH, pipeW, size.height - (cy + gapH));

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
