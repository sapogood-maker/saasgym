import { BadRequestException } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

const IMAGE_MIME_TYPES = ['image/png', 'image/jpeg', 'image/webp'];
const IMAGE_MAX_SIZE_BYTES = 2 * 1024 * 1024;

/// Interceptor reaproveitado por todo endpoint de upload de imagem (logo
/// da academia, foto de aluno/professor, avatar do usuário) — mesma
/// validação de tipo/tamanho em um único lugar.
export function ImageFileInterceptor(fieldName = 'file') {
  return FileInterceptor(fieldName, {
    limits: { fileSize: IMAGE_MAX_SIZE_BYTES },
    fileFilter: (_req, file, callback) => {
      if (!IMAGE_MIME_TYPES.includes(file.mimetype)) {
        callback(new BadRequestException('Formato não suportado — use PNG, JPEG ou WebP'), false);
        return;
      }
      callback(null, true);
    },
  });
}
