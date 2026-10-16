import { Provider, User } from '@prisma/client';
import { LoginUserDto } from '@gitroom/nestjs-libraries/dtos/auth/login.user.dto';
import { AuthService as AuthChecker } from '@gitroom/helpers/auth/auth.service';
import { AuthService } from './auth.service';

describe('AuthService registration security', () => {
  const originalDisableRegistration = process.env.DISABLE_REGISTRATION;
  const originalJwtSecret = process.env.JWT_SECRET;

  afterEach(() => {
    if (originalDisableRegistration === undefined) {
      delete process.env.DISABLE_REGISTRATION;
    } else {
      process.env.DISABLE_REGISTRATION = originalDisableRegistration;
    }
    if (originalJwtSecret === undefined) {
      delete process.env.JWT_SECRET;
    } else {
      process.env.JWT_SECRET = originalJwtSecret;
    }
  });

  function serviceWithOrganizationCount(count: number) {
    const service = Object.create(AuthService.prototype) as AuthService;
    (service as any)._organizationService = {
      getCount: jest.fn().mockResolvedValue(count),
    };
    return service;
  }

  it('blocks generic OAuth registration when registration is disabled', async () => {
    process.env.DISABLE_REGISTRATION = 'true';
    const service = serviceWithOrganizationCount(0);

    await expect(service.canRegister(Provider.GENERIC)).resolves.toBe(false);
  });

  it('keeps public registration closed before private bootstrap creates an organization', async () => {
    process.env.DISABLE_REGISTRATION = 'true';
    const service = serviceWithOrganizationCount(0);

    await expect(service.canRegister(Provider.LOCAL)).resolves.toBe(false);
  });

  it('keeps registration disabled after an organization exists', async () => {
    process.env.DISABLE_REGISTRATION = 'true';
    const service = serviceWithOrganizationCount(1);

    await expect(service.canRegister(Provider.LOCAL)).resolves.toBe(false);
  });

  it.each([true, false])(
    'keeps existing %s superadmin and general user Local logins working',
    async (isSuperAdmin) => {
      process.env.DISABLE_REGISTRATION = 'true';
      process.env.JWT_SECRET = 'test-only-auth-secret';
      const password = 'existing-account-password';
      const user = {
        id: `existing-${isSuperAdmin ? 'admin' : 'user'}`,
        email: `${isSuperAdmin ? 'admin' : 'user'}@example.invalid`,
        password: AuthChecker.hashPassword(password),
        providerName: Provider.LOCAL,
        activated: true,
        isSuperAdmin,
      } as User;
      const service = Object.create(AuthService.prototype) as AuthService;
      (service as any)._userService = {
        getUserByEmail: jest.fn().mockResolvedValue(user),
      };
      (service as any)._organizationService = {
        getCount: jest.fn().mockResolvedValue(1),
      };

      const login = new LoginUserDto();
      login.email = user.email;
      login.password = password;
      login.provider = Provider.LOCAL;

      await expect(
        service.routeAuth(Provider.LOCAL, login, '127.0.0.1', 'test')
      ).resolves.toEqual({ addedOrg: false, jwt: expect.any(String) });
    }
  );
});
