import { Global, Injectable, Logger, Module, OnModuleInit } from '@nestjs/common';
import type { TemporalService } from 'nestjs-temporal-core';
import type { Connection } from '@temporalio/client';

const TRANSIENT_TEMPORAL_CODES = new Set([
  '14',
  'UNAVAILABLE',
  'ECONNREFUSED',
  'ECONNRESET',
  'ETIMEDOUT',
  'EHOSTUNREACH',
  'ENETUNREACH',
]);

function isTransientTemporalError(error: unknown): boolean {
  let current: unknown = error;
  const visited = new Set<unknown>();
  while (current && typeof current === 'object' && !visited.has(current)) {
    visited.add(current);
    const details = current as {
      code?: unknown;
      status?: unknown;
      cause?: unknown;
    };
    if (
      TRANSIENT_TEMPORAL_CODES.has(String(details.code)) ||
      TRANSIENT_TEMPORAL_CODES.has(String(details.status))
    ) {
      return true;
    }
    current = details.cause;
  }
  return false;
}

@Injectable()
export class TemporalRegister implements OnModuleInit {
  constructor(private _client: TemporalService) {}

  async onModuleInit(): Promise<void> {
    if (process.env.TEMPORAL_TLS === 'true') {
      return;
    }
    const connection = this._client?.client?.getRawClient()
      ?.connection as Connection;

    let customAttributes: Record<string, unknown>;
    let retryDelayMs = 1_000;
    while (true) {
      try {
        ({ customAttributes } =
          await connection.operatorService.listSearchAttributes({
            namespace: process.env.TEMPORAL_NAMESPACE || 'default',
          }));
        break;
      } catch (error) {
        if (!isTransientTemporalError(error)) {
          throw error;
        }
        new Logger(TemporalRegister.name).warn(
          `Temporal is not ready; retrying search-attribute lookup in ${retryDelayMs}ms`
        );
        await new Promise((resolve) => setTimeout(resolve, retryDelayMs));
        retryDelayMs = Math.min(retryDelayMs * 2, 30_000);
      }
    }

    const neededAttribute = ['organizationId', 'postId'];
    const missingAttributes = neededAttribute.filter(
      (attr) => !customAttributes[attr]
    );

    if (missingAttributes.length > 0) {
      await connection.operatorService.addSearchAttributes({
        namespace: process.env.TEMPORAL_NAMESPACE || 'default',
        searchAttributes: missingAttributes.reduce((all, current) => {
          // @ts-ignore
          all[current] = 1;
          return all;
        }, {}),
      });
    }
  }
}

@Global()
@Module({
  imports: [],
  controllers: [],
  providers: [TemporalRegister],
  get exports() {
    return this.providers;
  },
})
export class TemporalRegisterMissingSearchAttributesModule {}
