import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/// Marca um endpoint como não exigindo access token (ex.: login, refresh).
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
