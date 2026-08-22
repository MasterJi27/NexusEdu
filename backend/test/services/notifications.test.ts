import { describe, it, expect, vi, beforeEach } from 'vitest';

const findMany = vi.fn();
const createMany = vi.fn();

vi.mock('../../src/lib/prisma', () => ({
  default: {
    enrollment: { findMany: (...args: unknown[]) => findMany(...args) },
    notification: { createMany: (...args: unknown[]) => createMany(...args) },
  },
}));

import { notifySection } from '../../src/services/notifications';

describe('notifySection', () => {
  beforeEach(() => {
    findMany.mockClear();
    createMany.mockClear();
  });

  it('fans out one notification row per enrolled student', async () => {
    findMany.mockResolvedValue([{ studentId: 's1' }, { studentId: 's2' }, { studentId: 's3' }]);
    await notifySection(
      { id: 'section-1', label: 'Class 10-B' },
      'live_class',
      'Live now: Physics revision',
      'Class 10-B · Ms Teacher just started a live class.',
      '/classroom',
    );
    expect(createMany).toHaveBeenCalledOnce();
    expect(createMany.mock.calls[0][0]).toEqual({
      data: [
        {
          userId: 's1',
          type: 'live_class',
          title: 'Live now: Physics revision',
          body: 'Class 10-B · Ms Teacher just started a live class.',
          link: '/classroom',
        },
        { userId: 's2', type: 'live_class', title: 'Live now: Physics revision', body: 'Class 10-B · Ms Teacher just started a live class.', link: '/classroom' },
        { userId: 's3', type: 'live_class', title: 'Live now: Physics revision', body: 'Class 10-B · Ms Teacher just started a live class.', link: '/classroom' },
      ],
    });
  });

  it('creates nothing for an empty section', async () => {
    findMany.mockResolvedValue([]);
    await notifySection({ id: 'section-1', label: 'Class 10-B' }, 'live_class', 't', 'b', '/classroom');
    expect(createMany).not.toHaveBeenCalled();
  });
});