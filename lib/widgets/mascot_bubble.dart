import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Diálogos por contexto
// ─────────────────────────────────────────────────────────────────────────────
enum MascotContext {
  dashboard,
  scanning,
  analyzing,
  recipes,
  cooking,
  done,
}

const _dialogues = {
  MascotContext.dashboard: [
    '¡Hola, Chef! 👋',
    '¿Qué cocinamos hoy?',
    '¡Tengo hambre! 🍽️',
    'Escanea el refri 📸',
    '¡Seré tu sous-chef!',
    'Hoy me antoja pasta 🍝',
  ],
  MascotContext.scanning: [
    'Apunta bien 📷',
    '¡Busco ingredientes!',
    'Sin mover la mano...',
    'Busca buena luz 💡',
    '¡Veo algo rico!',
  ],
  MascotContext.analyzing: [
    'Analizando... 🔍',
    '¡Casi listo!',
    'Hay mucho aquí 👀',
    'Calculando recetas...',
    '¡Interesante! 🤔',
  ],
  MascotContext.recipes: [
    '¡Elige bien! 😄',
    'Todas se ven ricas 🤤',
    '¡Yo haría la primera!',
    '¿Cuál se antoja más?',
    '¡Vamos a cocinar!',
  ],
  MascotContext.cooking: [
    '¡Sigue así, Chef! 💪',
    '¡Huele delicioso! 👃',
    '¡Vas muy bien!',
    'Con calma y amor 🍳',
    '¡Casi terminamos!',
    '¡Tú puedes! ✨',
  ],
  MascotContext.done: [
    '¡Excelente, Chef! 🎉',
    '¡Buen provecho! 🍽️',
    '¡Lo lograste! 🏆',
    '¡Eres un crack! 👨‍🍳',
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────────────────────
class MascotBubble extends StatefulWidget {
  final MascotContext context;
  final String? fixedMessage;
  final double size;

  const MascotBubble({
    super.key,
    required this.context,
    this.fixedMessage,
    this.size = 72,
  });

  @override
  State<MascotBubble> createState() => _MascotBubbleState();
}

class _MascotBubbleState extends State<MascotBubble>
    with TickerProviderStateMixin {
  late AnimationController _bubbleCtrl;
  late Animation<double> _bubbleFade;
  late Animation<double> _bubbleScale;

  late List<String> _messages;
  int _msgIndex = 0;
  String _currentMsg = '';
  Timer? _rotateTimer;

  @override
  void initState() {
    super.initState();

    _messages = widget.fixedMessage != null
        ? [widget.fixedMessage!]
        : List<String>.from(
            _dialogues[widget.context] ?? _dialogues[MascotContext.dashboard]!);
    _messages.shuffle(Random());
    _currentMsg = _messages[0];

    // Solo animación de entrada/salida del bubble, sin flotado
    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bubbleFade = CurvedAnimation(parent: _bubbleCtrl, curve: Curves.easeOut);
    _bubbleScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _bubbleCtrl, curve: Curves.elasticOut),
    );

    _bubbleCtrl.forward();

    if (widget.fixedMessage == null) {
      _rotateTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _nextMessage();
      });
    }
  }

  Future<void> _nextMessage() async {
    await _bubbleCtrl.reverse();
    if (!mounted) return;
    setState(() {
      _msgIndex = (_msgIndex + 1) % _messages.length;
      _currentMsg = _messages[_msgIndex];
    });
    _bubbleCtrl.forward();
  }

  @override
  void didUpdateWidget(MascotBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.context != widget.context ||
        oldWidget.fixedMessage != widget.fixedMessage) {
      _rotateTimer?.cancel();
      _messages = widget.fixedMessage != null
          ? [widget.fixedMessage!]
          : List<String>.from(_dialogues[widget.context] ??
              _dialogues[MascotContext.dashboard]!);
      _messages.shuffle(Random());
      _msgIndex = 0;
      _currentMsg = _messages[0];
      _bubbleCtrl.forward(from: 0);

      if (widget.fixedMessage == null) {
        _rotateTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          _nextMessage();
        });
      }
    }
  }

  @override
  void dispose() {
    _bubbleCtrl.dispose();
    _rotateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Nube de diálogo ────────────────────────────────────────────
        FadeTransition(
          opacity: _bubbleFade,
          child: ScaleTransition(
            scale: _bubbleScale,
            alignment: Alignment.centerRight,
            child: _SpeechBubble(message: _currentMsg),
          ),
        ),
        const SizedBox(width: 4),

        // ── GIF mascot ─────────────────────────────────────────────────
        GestureDetector(
          onTap: _nextMessage,
          child: Image.asset(
            'assets/images/chef_wolf.gif',
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nube de diálogo mejorada
// ─────────────────────────────────────────────────────────────────────────────
class _SpeechBubble extends StatelessWidget {
  final String message;
  const _SpeechBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 155, minWidth: 70),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Burbuja principal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
                letterSpacing: -0.1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Cola apuntando a la derecha (hacia el lobo)
          Positioned(
            right: -7,
            bottom: 14,
            child: CustomPaint(
              size: const Size(10, 14),
              painter: _TailPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 2)
      ..lineTo(size.width, size.height * 0.45)
      ..lineTo(0, size.height - 2)
      ..close();

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TailPainter old) => false;
}
