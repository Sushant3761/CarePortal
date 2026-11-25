export type StaffRole = 'doctor' | 'nurse' | 'admin' | 'system_admin' | string;

export function isClinicalRole(role: StaffRole): boolean {
  return role === 'doctor' || role === 'nurse';
}

export function isAdminRole(role: StaffRole): boolean {
  return role === 'admin' || role === 'system_admin';
}

export function canAccessDashboardPath(role: StaffRole, pathname: string): boolean {
  if (pathname === '/' || pathname === '/login') return true;
  if (!isClinicalRole(role) && !isAdminRole(role)) return false;
  if (pathname === '/admin' || pathname.startsWith('/admin/')) {
    return isAdminRole(role);
  }
  if (pathname.startsWith('/api/admin/doctors')) {
    return role === 'system_admin';
  }
  return isClinicalRole(role);
}
