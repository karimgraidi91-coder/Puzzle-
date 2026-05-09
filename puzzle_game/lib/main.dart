import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

// ملاحظة: تم تعطيل الإعلانات مؤقتاً لتشغيل نسخة الويب بنجاح
// import 'package:google_mobile_ads/google_mobile_ads.dart'; 

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DifficultyMenu(),
  ));
}

// --- 1. واجهة اختيار الصعوبة ---
class DifficultyMenu extends StatefulWidget {
  @override
  _DifficultyMenuState createState() => _DifficultyMenuState();
}

class _DifficultyMenuState extends State<DifficultyMenu> {
  int? selectedSize;

  @override
  Widget build(BuildContext context) {
    if (selectedSize != null) {
      return Scaffold(
        body: GameWidget(
          game: MyPuzzleGame(gridSize: selectedSize!),
          overlayBuilderMap: {
            'VictoryMenu': (context, MyPuzzleGame game) => _buildVictoryUI(game),
            'HintButton': (context, MyPuzzleGame game) => _buildHintUI(game),
          },
          initialActiveOverlays: const ['HintButton'],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("لعبة الألغاز 🧩", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 50),
            _diffBtn("سهل (3x3)", 3, Colors.green),
            _diffBtn("متوسط (4x4)", 4, Colors.orange),
            _diffBtn("صعب (5x5)", 5, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _diffBtn(String label, int size, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, minimumSize: const Size(250, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: () => setState(() => selectedSize = size),
        child: Text(label, style: const TextStyle(fontSize: 22, color: Colors.white)),
      ),
    );
  }

  Widget _buildVictoryUI(MyPuzzleGame game) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("أحسنت! 🎉", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DifficultyMenu())),
            child: const Text("لعبة جديدة"),
          )
        ]),
      ),
    );
  }

  Widget _buildHintUI(MyPuzzleGame game) {
    return Positioned(
      top: 50, right: 20,
      child: FloatingActionButton.extended(
        backgroundColor: Colors.amber,
        onPressed: () => game.showHint(),
        label: const Text("مساعدة", style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.lightbulb_outline),
      ),
    );
  }
}

// --- 2. محرك اللعبة الرئيسي ---
class MyPuzzleGame extends FlameGame with DragCallbacks {
  final int gridSize;
  late ui.Image fullImage;
  int lockedCount = 0;

  MyPuzzleGame({required this.gridSize});

  @override
  Future<void> onLoad() async {
    // جلب صورة عشوائية من الإنترنت
    final image = await loadNetworkImage("https://picsum.photos");
    fullImage = image;

    double pieceSize = (size.x - 60) / gridSize;
    Vector2 offset = Vector2(30, 150);

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        Vector2 correctPos = offset + Vector2(j * pieceSize, i * pieceSize);
        // توزيع القطع في أسفل الشاشة بشكل مبعثر
        Vector2 startPos = Vector2(Random().nextDouble() * (size.x - pieceSize), size.y - 180 + (Random().nextDouble() * 50));

        add(PuzzlePiece(
          sprite: Sprite(image, 
            srcPosition: Vector2(j * (image.width / gridSize), i * (image.height / gridSize)),
            srcSize: Vector2(image.width / gridSize, image.height / gridSize)),
          position: startPos,
          correctPosition: correctPos,
          size: Vector2(pieceSize, pieceSize),
        ));
      }
    }
  }

  void onPieceLocked() {
    lockedCount++;
    if (lockedCount == gridSize * gridSize) {
      _victory();
    }
  }

  void _victory() {
    add(ParticleSystemComponent(
      particle: Particle.generate(count: 100, lifespan: 3, generator: (i) => AcceleratedParticle(
        acceleration: Vector2(0, 300),
        speed: Vector2((Random().nextDouble() - 0.5) * 500, -700),
        position: size / 2,
        child: CircleParticle(radius: 3, paint: Paint()..color = Colors.primaries[Random().nextInt(Colors.primaries.length)]),
      )),
    ));
    overlays.add('VictoryMenu');
  }

  void showHint() {
    final hint = SpriteComponent(
      sprite: Sprite(fullImage),
      size: size * 0.8,
      position: size / 2,
      anchor: Anchor.center,
    )..opacity = 0.3; // إصلاح خاصية الشفافية
    
    add(hint);
    Future.delayed(const Duration(seconds: 3), () => hint.removeFromParent());
  }

  Future<ui.Image> loadNetworkImage(String url) async {
    final completer = Completer<ImageInfo>();
    final img = NetworkImage(url);
    img.resolve(const ImageConfiguration()).addListener(ImageStreamListener((info, _) => completer.complete(info)));
    return (await completer.future).image;
  }
}

// --- 3. قطعة البازل ---
class PuzzlePiece extends SpriteComponent with DragCallbacks, HasGameRef<MyPuzzleGame> {
  final Vector2 correctPosition;
  bool isLocked = false;
  Vector2? _startPos;

  PuzzlePiece({required Sprite sprite, required Vector2 position, required Vector2 size, required this.correctPosition})
      : super(sprite: sprite, position: position, size: size);

  @override
  void onDragStart(DragStartEvent event) {
    if (isLocked) return;
    _startPos = position.clone();
    priority = 20;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!isLocked) position += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (isLocked) return;
    // التحقق من المطابقة (بمدى 30 بكسل)
    if (position.distanceTo(correctPosition) < 30) {
      position = correctPosition.clone();
      isLocked = true;
      gameRef.onPieceLocked();
      priority = 0;
    } else {
      // العودة للمكان الأصلي إذا لم تتطابق
      add(MoveEffect.to(_startPos!, EffectController(duration: 0.3, curve: Curves.easeOut)));
      priority = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = isLocked ? Colors.green.withOpacity(0.7) : Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // رسم حدود القطعة
    canvas.drawRect(size.toRect(), paint);
    super.render(canvas);
  }
}
