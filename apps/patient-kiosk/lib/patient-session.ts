type SignOutOptions = { scope?: 'global' | 'local' | 'others' };
type SignOut = (options?: SignOutOptions) => Promise<{ error: unknown | null }>;
type SessionStorageLike = Pick<Storage, 'length' | 'key' | 'removeItem'>;

/** Sign out the Auth user and clear kiosk workflow data from the current tab. */
export async function clearPatientSession(signOut: SignOut, storage?: SessionStorageLike) {
  let needsLocalFallback = false;

  try {
    const { error } = await signOut();
    needsLocalFallback = Boolean(error);
  } catch {
    needsLocalFallback = true;
  }

  if (needsLocalFallback) {
    try {
      await signOut({ scope: 'local' });
    } catch {
      // The tab-scoped Auth storage disappears when the kiosk tab closes.
    }
  }

  if (storage) {
    for (let index = storage.length - 1; index >= 0; index -= 1) {
      const key = storage.key(index);
      if (key?.startsWith('careportal_')) storage.removeItem(key);
    }
  }
}
