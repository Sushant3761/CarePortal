'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';
import {
  Stethoscope,
  ShieldCheck,
  Lock,
  Mail,
  ArrowRight,
  Building2,
  AlertCircle
} from 'lucide-react';

export default function LoginPage() {
  const router = useRouter();
  const [role, setRole] = useState<'doctor' | 'admin'>('doctor');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleRoleChange = (newRole: 'doctor' | 'admin') => {
    setRole(newRole);
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const { data, error: authError } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      });
      if (authError || !data.user) throw new Error('Invalid email or password.');

      const { data: profile, error: profileError } = await supabase
        .from('user_profiles')
        .select('full_name, role, department, specialization, license_number, active')
        .eq('id', data.user.id)
        .maybeSingle();
      const allowedRoles = role === 'admin' ? ['admin', 'system_admin'] : ['doctor'];
      if (profileError || !profile || !profile.active || !allowedRoles.includes(profile.role)) {
        await supabase.auth.signOut();
        throw new Error('This account is not authorized for the selected portal.');
      }

      if (profile.role === 'admin' || profile.role === 'system_admin') {
        router.push('/admin');
      } else {
        router.push('/dashboard');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed. Please check your credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#f9f9ff] flex flex-col justify-between select-none relative overflow-hidden font-sans">

      {/* Decorative Blur Orbs */}
      <div className="absolute -top-40 -right-40 w-[600px] h-[600px] bg-[#00685f]/10 rounded-full blur-[100px] pointer-events-none" />
      <div className="absolute -bottom-40 -left-40 w-[600px] h-[600px] bg-[#0058be]/10 rounded-full blur-[90px] pointer-events-none" />

      {/* Top Header */}
      <header className="w-full h-20 px-8 flex items-center justify-between border-b border-[#e2e8f0] bg-white/80 backdrop-blur-md relative z-10">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-teal-50 border border-[#00685f]/30 flex items-center justify-center text-[#00685f] shadow-xs">
            <Stethoscope className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-xl font-bold uppercase tracking-tight text-[#00685f]">
              CarePortal Clinical
            </h1>
            <p className="text-[11px] text-[#64748b] font-medium tracking-wide">
              Healthcare Professional & Administration Gateway
            </p>
          </div>
        </div>

        <div className="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-full bg-[#f0f3ff] border border-[#bcc9c6]/40 text-xs font-semibold text-[#00685f]">
          <ShieldCheck className="w-4 h-4 text-[#00685f]" />
          <span>Clinical Operations Portal</span>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 flex items-center justify-center p-6 relative z-10">
        <div className="w-full max-w-xl flex flex-col gap-6">

          {/* Main Card */}
          <div className="bg-white rounded-3xl shadow-xl border border-[#e2e8f0] p-8 md:p-10 relative overflow-hidden">

            {/* Top Accent Gradient Line */}
            <div className="absolute top-0 inset-x-0 h-1.5 bg-gradient-to-r from-[#00685f] via-[#008378] to-[#0058be]" />

            {/* Role Toggle Selector */}
            <div className="flex p-1 rounded-2xl bg-[#f0f3ff] border border-[#cbd5e1] mb-8">
              <button
                type="button"
                onClick={() => handleRoleChange('doctor')}
                className={`flex-1 py-2.5 rounded-xl font-bold text-xs sm:text-sm transition-all flex items-center justify-center gap-2 ${
                  role === 'doctor'
                    ? 'bg-[#00685f] text-white shadow-sm'
                    : 'text-[#475569] hover:text-[#00685f]'
                }`}
              >
                <Stethoscope className="w-4 h-4" />
                <span>Doctor / OPD Portal</span>
              </button>
              <button
                type="button"
                onClick={() => handleRoleChange('admin')}
                className={`flex-1 py-2.5 rounded-xl font-bold text-xs sm:text-sm transition-all flex items-center justify-center gap-2 ${
                  role === 'admin'
                    ? 'bg-[#0058be] text-white shadow-sm'
                    : 'text-[#475569] hover:text-[#0058be]'
                }`}
              >
                <Building2 className="w-4 h-4" />
                <span>Hospital Admin Portal</span>
              </button>
            </div>

            {/* Heading */}
            <div className="mb-6">
              <h2 className="text-2xl font-bold text-[#151c27]">
                {role === 'doctor' ? 'Physician Sign In' : 'Administrative Station Login'}
              </h2>
              <p className="text-xs sm:text-sm text-[#64748b] mt-1">
                {role === 'doctor'
                  ? 'Access real-time patient queue, AI clinical summaries, and e-prescriptions.'
                  : 'Manage kiosk stations, doctor allocations, triage rules, and analytics.'}
              </p>
            </div>

            {/* Error Banner */}
            {error && (
              <div className="flex items-center gap-2 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-xs sm:text-sm mb-4">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{error}</span>
              </div>
            )}

            {/* Form */}
            <form onSubmit={handleLogin} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-[#475569] mb-1.5">
                  Official Email / Hospital ID
                </label>
                <div className="relative">
                  <Mail className="w-5 h-5 text-[#94a3b8] absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full pl-11 pr-4 py-3 rounded-xl border border-[#cbd5e1] text-sm text-[#151c27] placeholder-[#94a3b8] focus:outline-none focus:ring-2 focus:ring-[#00685f] focus:border-[#00685f] transition-all bg-[#f9f9ff]"
                    placeholder="doctor@hospital.health"
                    required
                  />
                </div>
              </div>

              <div>
                <div className="flex justify-between items-center mb-1.5">
                  <label className="block text-xs font-bold uppercase tracking-wider text-[#475569]">
                    Security Password
                  </label>
                  <span className="text-xs text-[#00685f] hover:underline cursor-pointer">
                  </span>
                </div>
                <div className="relative">
                  <Lock className="w-5 h-5 text-[#94a3b8] absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="w-full pl-11 pr-4 py-3 rounded-xl border border-[#cbd5e1] text-sm text-[#151c27] placeholder-[#94a3b8] focus:outline-none focus:ring-2 focus:ring-[#00685f] focus:border-[#00685f] transition-all bg-[#f9f9ff]"
                    placeholder="••••••••"
                    required
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={loading}
                className={`w-full py-3.5 rounded-xl font-bold text-sm text-white shadow-md transition-all active:scale-98 flex items-center justify-center gap-2 mt-2 cursor-pointer ${
                  role === 'admin'
                    ? 'bg-[#0058be] hover:bg-[#0048a0] shadow-blue-500/20'
                    : 'bg-[#00685f] hover:bg-[#005049] shadow-teal-500/20'
                }`}
              >
                <span>{loading ? 'Authenticating Medical Credentials...' : 'Sign In to Clinical Workspace'}</span>
                <ArrowRight className="w-4 h-4" />
              </button>
            </form>

          </div>

        </div>
      </main>

      {/* Footer */}
      <footer className="w-full py-4 text-center text-xs text-[#64748b] border-t border-[#e2e8f0] bg-white/60">
        Sign in with your hospital account and assigned portal role.
      </footer>

    </div>
  );
}
