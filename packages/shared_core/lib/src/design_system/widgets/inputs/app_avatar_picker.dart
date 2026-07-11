import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_icons.dart';

/// Resultado de uma seleção de imagem no [AppAvatarPicker].
typedef AppAvatarPick = ({Uint8List bytes, String filename});

/// Avatar circular com seletor de imagem — único ponto de escolha de foto
/// do produto (Alunos, Professores, Perfil todos usam o mesmo). Só
/// seleciona um arquivo de imagem do dispositivo e devolve os bytes via
/// [onPicked]; **não sabe pra onde isso vai** — enviar ao backend
/// (`AlunosApi.uploadFoto` etc.) é decisão de quem usa o componente.
///
/// Exemplo:
/// ```dart
/// AppAvatarPicker(
///   imageBytes: _fotoBytes,
///   imageUrl: aluno?.fotoUrl,
///   onPicked: (pick) => setState(() {
///     _fotoBytes = pick.bytes;
///     _fotoNomeArquivo = pick.filename;
///   }),
/// )
/// ```
class AppAvatarPicker extends StatelessWidget {
  /// Bytes de uma imagem recém-selecionada (tem prioridade sobre [imageUrl]).
  final Uint8List? imageBytes;

  /// URL de uma imagem já existente (ex.: foto já salva no backend) —
  /// mostrada só quando [imageBytes] é nulo.
  final String? imageUrl;

  final double radius;
  final bool enabled;
  final bool loading;
  final ValueChanged<AppAvatarPick>? onPicked;

  const AppAvatarPicker({
    super.key,
    this.imageBytes,
    this.imageUrl,
    this.radius = 44,
    this.enabled = true,
    this.loading = false,
    this.onPicked,
  });

  Future<void> _escolher() async {
    final resultado = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final arquivos = resultado?.files ?? const [];
    if (arquivos.isEmpty || arquivos.first.bytes == null) return;
    onPicked?.call((bytes: arquivos.first.bytes!, filename: arquivos.first.name));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final diameter = radius * 2;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: colors.cardRaised,
            backgroundImage: imageBytes != null
                ? MemoryImage(imageBytes!)
                : (imageUrl != null ? NetworkImage(imageUrl!) as ImageProvider : null),
            child: (imageBytes == null && imageUrl == null)
                ? Icon(AppIcons.profile, size: radius, color: colors.textFaint)
                : null,
          ),
          if (loading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                child: Center(
                  child: SizedBox(
                    width: radius * 0.6,
                    height: radius * 0.6,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(colors.text)),
                  ),
                ),
              ),
            ),
          if (enabled && !loading)
            Positioned(
              right: -2,
              bottom: -2,
              child: Material(
                color: colors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _escolher,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(AppIcons.camera, size: 14, color: colors.primaryInk),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
