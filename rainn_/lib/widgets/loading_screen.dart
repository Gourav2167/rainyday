import 'dart:math' as math;
import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  final String? loadingText;
  final Duration? duration;
  final Stream<double>? progressStream;
  final VoidCallback? onProgressComplete;

  const LoadingScreen({
    super.key,
    this.loadingText = "Raining Sky Loading...",
    this.duration = const Duration(seconds: 10),
    this.progressStream,
    this.onProgressComplete,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _rainController;
  late List<_Cloud> clouds;
  late List<_Raindrop> raindrops;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    // ☁ Clouds setup
    final random = math.Random();
    clouds = List.generate(6, (i) {
      return _Cloud(
        size: 80 + random.nextInt(70).toDouble(),
        yOffset: 30.0 + random.nextInt(180).toDouble(),
        speed: 0.4 + random.nextDouble() * 0.8,
        opacity: 0.5 + random.nextDouble() * 0.4,
      );
    });

    // 💧 Raindrops setup
    raindrops = List.generate(50, (i) {
      return _Raindrop(
        x: random.nextDouble(),
        y: random.nextDouble(),
        speed: 2 + random.nextDouble() * 2,
      );
    });

    // 🔵 Progress controller
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(() {
        setState(() {
          _progress = _progressController.value;
        });
      });

    // 🌧 Rain controller (loops)
    _rainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Listen to progress stream if provided
    if (widget.progressStream != null) {
      widget.progressStream!.listen((progress) {
        setState(() {
          _progress = progress;
        });

        // Call completion callback when progress reaches 100%
        if (progress >= 1.0 && widget.onProgressComplete != null) {
          widget.onProgressComplete!();
        }
      });
    } else {
      // Fallback to animation if no stream provided
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _rainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _rainController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF001B48), // Deep blue
                  Color(0xFF3AA0FF), // Light blue
                ],
              ),
            ),
            child: Stack(
              children: [
                // ☁ Moving clouds
                ...clouds.map((c) => c.build(context, size, _progress)),

                // 💧 Raindrops
                ...raindrops.map((r) => r.build(size, _rainController.value)),

                // 🌈 Loading section
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 120, left: 30, right: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.loadingText ?? "Raining Sky Loading...",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 30),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: _progress,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.lightBlueAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "${(_progress * 100).toInt()}%",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
}

// ☁ Cloud class
class _Cloud {
  final double size;
  final double yOffset;
  final double speed;
  final double opacity;
  final double initialOffset = math.Random().nextDouble() * 200;

  _Cloud({
    required this.size,
    required this.yOffset,
    required this.speed,
    required this.opacity,
  });

  Widget build(BuildContext context, Size screenSize, double progress) {
    double xPos = (screenSize.width * progress * speed + initialOffset) %
        (screenSize.width + size);

    return Positioned(
      top: yOffset,
      left: xPos - size,
      child: Icon(
        Icons.cloud,
        size: size,
        color: Colors.white.withOpacity(opacity),
        shadows: [
          Shadow(
            blurRadius: 30,
            color: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

// 💧 Raindrop class
class _Raindrop {
  double x;
  double y;
  double speed;

  _Raindrop({required this.x, required this.y, required this.speed});

  Widget build(Size size, double progress) {
    double dropY = (y + progress * speed) % 1.0; // loop falling motion
    return Positioned(
      left: x * size.width,
      top: dropY * size.height,
      child: Container(
        width: 2,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
