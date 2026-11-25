import { describe, expect, it, vi } from 'vitest';
import { clearPatientSession } from '../apps/patient-kiosk/lib/patient-session';

function makeStorage(initial: string[]) {
  const values = [...initial];
  return {
    get length() { return values.length; },
    key(index: number) { return values[index] ?? null; },
    removeItem(key: string) {
      const index = values.indexOf(key);
      if (index >= 0) values.splice(index, 1);
    },
    values,
  };
}

describe('clearPatientSession', () => {
  it('signs out and clears only CarePortal workflow keys', async () => {
    const signOut = vi.fn().mockResolvedValue({ error: null });
    const storage = makeStorage(['careportal_patient_id', 'supabase-auth-token', 'careportal_history']);

    await clearPatientSession(signOut, storage);

    expect(signOut).toHaveBeenCalledOnce();
    expect(storage.values).toEqual(['supabase-auth-token']);
  });

  it('falls back to local sign-out when remote sign-out fails', async () => {
    const signOut = vi.fn()
      .mockResolvedValueOnce({ error: new Error('offline') })
      .mockResolvedValueOnce({ error: null });
    const storage = makeStorage(['careportal_patient_id']);

    await clearPatientSession(signOut, storage);

    expect(signOut).toHaveBeenNthCalledWith(2, { scope: 'local' });
    expect(storage.values).toEqual([]);
  });
});
