import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Request, Response } from 'express';

interface ErrorResponseBody {
  statusCode: number;
  message: string | string[];
  error: string;
  timestamp: string;
  path: string;
}

/// Formato de erro consistente para toda a API. O stack trace nunca vai
/// para a resposta HTTP, em nenhum ambiente — só para o log do servidor.
/// Isso é mais simples e mais seguro que uma checagem condicional por
/// NODE_ENV (uma variável mal configurada em produção não vaza nada).
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('ExceptionsFilter');

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const isHttpException = exception instanceof HttpException;
    const status = isHttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;

    const body: ErrorResponseBody = {
      statusCode: status,
      message: this.extractMessage(exception, isHttpException),
      error: isHttpException ? exception.constructor.name : 'InternalServerError',
      timestamp: new Date().toISOString(),
      path: request.url,
    };

    if (!isHttpException || status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      this.logger.error(
        `${request.method} ${request.url} -> ${status}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    response.status(status).json(body);
  }

  private extractMessage(exception: unknown, isHttpException: boolean): string | string[] {
    if (!isHttpException) {
      return 'Erro interno do servidor';
    }

    const responseBody = (exception as HttpException).getResponse();
    if (typeof responseBody === 'string') {
      return responseBody;
    }

    const message = (responseBody as { message?: string | string[] }).message;
    return message ?? (exception as HttpException).message;
  }
}
