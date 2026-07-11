import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_radius.dart';

/// Formato do bloco de [LoadingSkeleton].
enum AppSkeletonShape {
  /// Bloco retangular — texto, linha, botão.
  rectangle,

  /// Bloco circular — avatar, ícone.
  circle,
}

/// Placeholder de carregamento em bloco — nunca usar
/// `CircularProgressIndicator` solto numa tela ou dentro de um card; todo
/// carregamento usa este widget, para que o layout não "pule" quando o
/// conteúdo real chega (o esqueleto ocupa aproximadamente o espaço do
/// conteúdo final).
///
/// [width] tem default finito de propósito — um `Row` do Flutter dá largura
/// *não limitada* a um filho que não seja `Expanded`/`Flexible`, e
/// `width: double.infinity` nessa situação derruba o layout. Passe
/// `width: double.infinity` explicitamente quando o contexto for garantido
/// de largura limitada (ex.: dentro de uma `Column`/`AppCard`, como em
/// [AppCard]); dentro de um `Row`, sempre envolva em `Expanded`/`Flexible`.
///
/// Anima um brilho discreto varrendo o bloco; respeita a preferência de
/// acessibilidade "reduzir movimento" (fica estático nesse caso).
class LoadingSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final AppSkeletonShape shape;

  const LoadingSkeleton({
    super.key,
    this.width = 120,
    this.height = 12,
    this.shape = AppSkeletonShape.rectangle,
  });

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    // Se "reduzir movimento" estiver ativo, o build() abaixo nunca chega a
    // consumir este controller (retorna um bloco estático antes) — o tick
    // continua rodando em segundo plano, mas sem custo visual nem de rebuild.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colors.cardRaised;
    final highlight = context.colors.border;
    final radius = widget.shape == AppSkeletonShape.circle
        ? BorderRadius.circular(widget.height / 2)
        : BorderRadius.circular(AppRadius.sm);

    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Widget block = DecoratedBox(
      decoration: BoxDecoration(color: base, borderRadius: radius),
    );

    if (reduceMotion) {
      return SizedBox(width: widget.width, height: widget.height, child: block);
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return ClipRRect(
            borderRadius: radius,
            child: ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: [base, highlight, base],
                  stops: const [0.35, 0.5, 0.65],
                  begin: Alignment(-1 - t * 2, 0),
                  end: Alignment(1 - t * 2, 0),
                ).createShader(bounds);
              },
              child: block,
            ),
          );
        },
      ),
    );
  }
}
