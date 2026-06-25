import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  final bool enableParticles;

  const AnimatedBackground({
    super.key,
    required this.child,
    this.enableParticles = true,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _gradientController;
  late AnimationController _particleController;
  late List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _particles = List.generate(15, (i) => Particle.random(i));
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_gradientController, _particleController]),
      builder: (context, child) {
        return CustomPaint(
          painter: _BackgroundPainter(
            gradientProgress: _gradientController.value,
            particleProgress: _particleController.value,
            particles: _particles,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class Particle {
  double x, y, size, speed, opacity, angle;
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.angle,
    required this.color,
  });

  factory Particle.random(int seed) {
    final random = Random(seed);
    final colors = [
      const Color(0xFF7C5CFF),
      const Color(0xFF55D6A4),
      const Color(0xFFFFC857),
      const Color(0xFF64B5F6),
      const Color(0xFFFF6B6B),
    ];
    return Particle(
      x: random.nextDouble(),
      y: random.nextDouble(),
      size: 2.0 + random.nextDouble() * 4.0,
      speed: 0.0002 + random.nextDouble() * 0.0005,
      opacity: 0.1 + random.nextDouble() * 0.3,
      angle: random.nextDouble() * pi * 2,
      color: colors[random.nextInt(colors.length)],
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double gradientProgress;
  final double particleProgress;
  final List<Particle> particles;

  _BackgroundPainter({
    required this.gradientProgress,
    required this.particleProgress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    final gradient = LinearGradient(
      begin: Alignment(
        -1.0 + gradientProgress * 2.0,
        -1.0 + gradientProgress,
      ),
      end: Alignment(
        1.0 - gradientProgress * 2.0,
        1.0 - gradientProgress,
      ),
      colors: const [
        Color(0xFF0F0F13),
        Color(0xFF1A1528),
        Color(0xFF0F1115),
        Color(0xFF151520),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final glowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    final glow1 = Offset(
      size.width * (0.2 + gradientProgress * 0.1),
      size.height * (0.3 + gradientProgress * 0.1),
    );
    canvas.drawCircle(
      glow1,
      80,
      glowPaint..color = const Color(0xFF7C5CFF).withOpacity(0.08),
    );

    final glow2 = Offset(
      size.width * (0.8 - gradientProgress * 0.1),
      size.height * (0.7 - gradientProgress * 0.1),
    );
    canvas.drawCircle(
      glow2,
      100,
      glowPaint..color = const Color(0xFF55D6A4).withOpacity(0.05),
    );

    final glow3 = Offset(
      size.width * (0.5 + gradientProgress * 0.05),
      size.height * (0.5 - gradientProgress * 0.05),
    );
    canvas.drawCircle(
      glow3,
      120,
      glowPaint..color = const Color(0xFFFFC857).withOpacity(0.04),
    );

    for (final particle in particles) {
      final t = (particleProgress + particle.speed * 1000) % 1.0;
      final px = particle.x * size.width + sin(t * pi * 2 + particle.angle) * 30;
      final py = particle.y * size.height + cos(t * pi * 2 + particle.angle) * 20;

      canvas.drawCircle(
        Offset(px, py),
        particle.size,
        Paint()
          ..color = particle.color.withOpacity(particle.opacity * (0.5 + sin(t * pi) * 0.5))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      canvas.drawCircle(
        Offset(px, py),
        particle.size * 0.4,
        Paint()..color = particle.color.withOpacity(particle.opacity * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.gradientProgress != gradientProgress ||
        oldDelegate.particleProgress != particleProgress;
  }
}
