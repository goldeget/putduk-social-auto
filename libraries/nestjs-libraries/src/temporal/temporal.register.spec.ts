import { Logger } from '@nestjs/common';
import { TemporalService } from 'nestjs-temporal-core';
import { TemporalRegister } from './temporal.register';

describe('TemporalRegister', () => {
  const originalTls = process.env.TEMPORAL_TLS;
  const originalNamespace = process.env.TEMPORAL_NAMESPACE;

  afterEach(() => {
    process.env.TEMPORAL_TLS = originalTls;
    process.env.TEMPORAL_NAMESPACE = originalNamespace;
    jest.useRealTimers();
    jest.restoreAllMocks();
  });

  it('retries transient Temporal unavailability until the RPC is ready', async () => {
    process.env.TEMPORAL_TLS = 'false';
    process.env.TEMPORAL_NAMESPACE = 'default';
    jest.useFakeTimers();
    jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);

    const listSearchAttributes = jest
      .fn()
      .mockRejectedValueOnce({ code: 14 })
      .mockRejectedValueOnce({ code: 'ECONNREFUSED' })
      .mockResolvedValue({
        customAttributes: {
          organizationId: {},
          postId: {},
        },
      });
    const addSearchAttributes = jest.fn();
    const client = {
      getRawClient: () => ({
        connection: {
          operatorService: { listSearchAttributes, addSearchAttributes },
        },
      }),
    };
    const register = new TemporalRegister({ client } as unknown as TemporalService);

    const initialization = register.onModuleInit();
    await jest.runAllTimersAsync();
    await expect(initialization).resolves.toBeUndefined();

    expect(listSearchAttributes).toHaveBeenCalledTimes(3);
    expect(listSearchAttributes).toHaveBeenLastCalledWith({ namespace: 'default' });
    expect(addSearchAttributes).not.toHaveBeenCalled();
  });

  it('does not retry non-transient Temporal errors', async () => {
    process.env.TEMPORAL_TLS = 'false';
    const error = new Error('permission denied');
    const listSearchAttributes = jest.fn().mockRejectedValue(error);
    const client = {
      getRawClient: () => ({
        connection: { operatorService: { listSearchAttributes } },
      }),
    };
    const register = new TemporalRegister({ client } as unknown as TemporalService);

    await expect(register.onModuleInit()).rejects.toBe(error);
    expect(listSearchAttributes).toHaveBeenCalledTimes(1);
  });
});
