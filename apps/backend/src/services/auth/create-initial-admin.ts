import { PrismaClient, Provider, Role } from '@prisma/client';
import { AuthService as AuthChecker } from '@gitroom/helpers/auth/auth.service';
import { makeSecureId } from '@gitroom/nestjs-libraries/services/make.secure.id';
import { createInterface } from 'node:readline/promises';

type InitialAdminInput = {
  company: string;
  email: string;
  password: string;
};

const INITIAL_ADMIN_LOCK_ID = 2026121701;

export async function createInitialAdmin(
  prisma: PrismaClient,
  input: InitialAdminInput
) {
  if (process.env.DISABLE_REGISTRATION !== 'true') {
    throw new Error('Initial admin bootstrap requires DISABLE_REGISTRATION=true');
  }
  if (input.company.trim().length < 3 || input.company.length > 128) {
    throw new Error('Company name must contain 3 to 128 characters');
  }
  if (!/^\S+@\S+\.\S+$/.test(input.email.trim())) {
    throw new Error('Enter a valid email address');
  }
  const passwordBytes = Buffer.byteLength(input.password, 'utf8');
  if (passwordBytes < 12 || passwordBytes > 72) {
    throw new Error('Password must contain 12 to 72 UTF-8 bytes');
  }

  return prisma.$transaction(async (tx) => {
    await tx.$queryRaw`SELECT pg_advisory_xact_lock(${INITIAL_ADMIN_LOCK_ID})`;

    if ((await tx.organization.count()) !== 0) {
      throw new Error('Initial administrator has already been created');
    }

    return tx.organization.create({
      data: {
        name: input.company.trim(),
        apiKey: AuthChecker.fixedEncryption(makeSecureId(20)),
        allowTrial: true,
        isTrailing: true,
        users: {
          create: {
            role: Role.SUPERADMIN,
            user: {
              create: {
                activated: true,
                email: input.email.trim().toLowerCase(),
                isSuperAdmin: true,
                password: AuthChecker.hashPassword(input.password),
                providerName: Provider.LOCAL,
                providerId: '',
                timezone: 0,
              },
            },
          },
        },
      },
      select: {
        id: true,
        users: {
          select: {
            role: true,
            user: { select: { id: true, email: true } },
          },
        },
      },
    });
  });
}

async function askHidden(prompt: string) {
  const input = process.stdin;
  if (!input.isTTY || typeof input.setRawMode !== 'function') {
    throw new Error('Run this command from an interactive terminal');
  }

  process.stdout.write(prompt);
  input.setRawMode(true);
  input.resume();

  return new Promise<string>((resolve, reject) => {
    const bytes: number[] = [];
    const finish = (error?: Error) => {
      input.setRawMode(false);
      input.pause();
      input.removeListener('data', onData);
      process.stdout.write('\n');
      if (error) reject(error);
      else resolve(Buffer.from(bytes).toString('utf8'));
    };
    const onData = (chunk: Buffer) => {
      for (const byte of chunk) {
        if (byte === 3) {
          finish(new Error('Cancelled'));
          return;
        }
        if (byte === 13 || byte === 10) {
          finish();
          return;
        }
        if (byte === 8 || byte === 127) {
          let last = bytes.pop();
          while (last !== undefined && bytes.length && (last & 0xc0) === 0x80) {
            last = bytes.pop();
          }
          continue;
        }
        if (byte >= 32) bytes.push(byte);
      }
    };
    input.on('data', onData);
  });
}

async function main() {
  const terminal = createInterface({ input: process.stdin, output: process.stdout });
  const company = await terminal.question('Organization name: ');
  const email = await terminal.question('Administrator email: ');
  terminal.close();
  const password = await askHidden('Administrator password (input hidden): ');
  const confirmPassword = await askHidden('Confirm password (input hidden): ');
  if (password !== confirmPassword) throw new Error('Passwords do not match');
  const passwordBytes = Buffer.byteLength(password, 'utf8');
  if (passwordBytes < 12 || passwordBytes > 72) {
    throw new Error('Password must contain 12 to 72 UTF-8 bytes');
  }
  if (!/^\S+@\S+\.\S+$/.test(email)) throw new Error('Enter a valid email address');

  const prisma = new PrismaClient();
  try {
    const created = await createInitialAdmin(prisma, { company, email, password });
    process.stdout.write(
      `Initial SUPERADMIN created for ${created.users[0].user.email}. Public registration remains disabled.\n`
    );
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`Initial admin creation failed: ${error.message}\n`);
    process.exitCode = 1;
  });
}
