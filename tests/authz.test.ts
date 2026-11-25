import { describe, expect, it } from 'vitest';
import { canAccessDashboardPath, isAdminRole, isClinicalRole } from '../apps/doctor-dashboard/lib/authz';

describe('dashboard role authorization', () => {
  it('recognizes only the configured staff roles', () => {
    expect(isClinicalRole('doctor')).toBe(true);
    expect(isClinicalRole('nurse')).toBe(true);
    expect(isClinicalRole('patient')).toBe(false);
    expect(isAdminRole('admin')).toBe(true);
    expect(isAdminRole('system_admin')).toBe(true);
    expect(isAdminRole('doctor')).toBe(false);
  });

  it('denies unknown and patient roles from protected dashboard routes', () => {
    expect(canAccessDashboardPath('patient', '/dashboard')).toBe(false);
    expect(canAccessDashboardPath('unexpected', '/reports')).toBe(false);
  });

  it('limits admin pages and staff management to authorized roles', () => {
    expect(canAccessDashboardPath('doctor', '/admin')).toBe(false);
    expect(canAccessDashboardPath('admin', '/admin')).toBe(true);
    expect(canAccessDashboardPath('admin', '/dashboard')).toBe(false);
    expect(canAccessDashboardPath('admin', '/api/admin/doctors')).toBe(false);
    expect(canAccessDashboardPath('system_admin', '/api/admin/doctors')).toBe(true);
  });
});
