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
  double _birdY = 0.0;
  double _birdX = -0.5;
  double _velocity = 0.0;

  final double _gravity = -0.0028;
  final double _flapImpulse = 0.055;
  final double _maxRise = 0.12;
  final double _maxFall = -0.04;

  final List<_Pipe> _pipes = [];
  final Random _rand = Random();
  final double _gap = 0.36;
  double _pipeSpeed = 0.008;
  int _score = 0;
  bool _running = false;
  bool _gameOver = false;
  bool _countingDown = false;
  int _countdown = 3;

  Timer? _timer;
  Timer? _countdownTimer;

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
    final center = (_rand.nextDouble() * 1.4) - 0.7;
    return _Pipe(x: startX, gapCenter: center, gap: _gap, passed: false);
  }

  void _start() {
    _resetGame();
    _countingDown = true;
    _countdown = 3;
    setState(() {});

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _countdown--;
      });
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
        content: Text('Skorun: $
