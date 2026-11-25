'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';
import { getAuthenticatedProfile } from '@/lib/auth';
import {
  Building2,
  Monitor,
  Users,
  ShieldCheck,
  RotateCw,
  LogOut,
  Plus,
  CheckCircle2,
  Sparkles
} from 'lucide-react';

export default function AdminPortalPage() {
  const router = useRouter();
  // Kiosk Fleet State
  const kiosks: any[] = [];

  // Doctor Allocations State
  const doctors: any[] = [];

  useEffect(() => {
    checkAdminAuth();
  }, []);

  const checkAdminAuth = async () => {
    const profile = await getAuthenticatedProfile();
    if (!profile) router.replace('/login');
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    router.replace('/login');
  };

  return (
    <div className="bg-background font-body-md text-on-background min-h-screen">

      {/* Top Header */}
      <header className="fixed top-0 w-full z-50 bg-surface border-b border-outline-variant h-16 shadow-[0_1px_8px_rgba(0,0,0,0.03)]">
        <div className="h-full w-full px-lg flex items-center justify-between">
          <div className="flex items-center gap-md">
            <div className="w-8 h-8 rounded-xl bg-blue-50 border border-blue-200 flex items-center justify-center text-blue-600 shadow-xs">
              <Building2 className="w-5 h-5 stroke-[2.5]" />
            </div>
            <div>
              <span className="font-title-lg text-[#0058be] uppercase tracking-tight font-bold text-lg">
                CarePortal Administration Station
              </span>
              <span className="text-[10px] text-on-surface-variant font-mono block -mt-1">
                Administration prototype · integrations not configured
              </span>
            </div>
          </div>

          <div className="flex items-center gap-md">
            <div className="flex items-center gap-sm bg-blue-50 px-md py-xs rounded-full border border-blue-200">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
              <span className="text-label-md text-blue-900 font-bold tracking-wide">
                NOT CONNECTED
              </span>
            </div>

            <button
              onClick={() => router.push('/dashboard')}
              className="px-3 py-1.5 rounded-lg border border-outline-variant text-xs font-bold hover:bg-surface-variant transition-colors"
            >
              Doctor View
            </button>

            <button
              onClick={handleLogout}
              className="p-2 rounded-lg bg-error/10 text-error hover:bg-error/20 transition-colors"
              title="Sign Out"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="pt-20 px-8 max-w-container-max mx-auto w-full pb-16 flex flex-col gap-8">

        {/* System Stats Overview */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-md">

          <div className="bg-surface-container-lowest p-5 rounded-2xl shadow-xs border border-outline-variant/30 flex items-start justify-between">
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-on-surface-variant">Active Kiosks</span>
              <h3 className="text-lg font-extrabold text-on-surface mt-1">Not configured</h3>
              <p className="text-[11px] text-on-surface-variant font-semibold mt-1">No fleet telemetry connected</p>
            </div>
            <div className="w-10 h-10 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
              <Monitor className="w-5 h-5" />
            </div>
          </div>

          <div className="bg-surface-container-lowest p-5 rounded-2xl shadow-xs border border-outline-variant/30 flex items-start justify-between">
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-on-surface-variant">Today&apos;s Total Intake</span>
              <h3 className="text-lg font-extrabold text-on-surface mt-1">Unavailable</h3>
              <p className="text-[11px] text-on-surface-variant font-semibold mt-1">No intake metrics connected</p>
            </div>
            <div className="w-10 h-10 rounded-xl bg-teal-50 text-primary flex items-center justify-center">
              <Users className="w-5 h-5" />
            </div>
          </div>

          <div className="bg-surface-container-lowest p-5 rounded-2xl shadow-xs border border-outline-variant/30 flex items-start justify-between">
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-on-surface-variant">Gemini AI Latency</span>
              <h3 className="text-lg font-extrabold text-on-surface mt-1">Not measured</h3>
              <p className="text-[11px] text-on-surface-variant font-semibold mt-1">No AI telemetry connected</p>
            </div>
            <div className="w-10 h-10 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center">
              <Sparkles className="w-5 h-5" />
            </div>
          </div>

          <div className="bg-surface-container-lowest p-5 rounded-2xl shadow-xs border border-outline-variant/30 flex items-start justify-between">
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-on-surface-variant">ABDM / M1 Network</span>
              <h3 className="text-lg font-extrabold text-on-surface mt-1">Not connected</h3>
              <p className="text-[11px] text-on-surface-variant font-medium mt-1">No ABDM/FHIR integration configured</p>
            </div>
            <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
              <ShieldCheck className="w-5 h-5" />
            </div>
          </div>

        </div>

        {/* Section 1: Kiosk Fleet Management */}
        <div className="bg-surface-container-lowest p-6 rounded-3xl shadow-xs border border-outline-variant/30">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-xl font-bold text-on-surface flex items-center gap-2">
                <Monitor className="w-5 h-5 text-blue-600" />
                <span>Physical Kiosk Stations Deployment</span>
              </h2>
              <p className="text-xs text-on-surface-variant mt-0.5">
                Real-time hardware heartbeat, optical OCR scanners, and peripheral status.
              </p>
            </div>

            <button
              disabled
              className="px-4 py-2 bg-primary hover:bg-[#005049] text-white text-xs font-bold rounded-xl flex items-center gap-1.5"
            >
              <Plus className="w-4 h-4" />
              <span>Deployment unavailable</span>
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {kiosks.length === 0 && <p className="col-span-full rounded-xl bg-surface-container-low p-4 text-sm text-on-surface-variant">No kiosk fleet is connected.</p>}
            {kiosks.map((kiosk) => (
              <div key={kiosk.id} className="p-4 rounded-2xl border border-outline-variant/40 bg-surface flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-mono font-bold text-xs text-primary">{kiosk.id}</span>
                    <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                      kiosk.status === 'Online' ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-amber-50 text-amber-700 border border-amber-200'
                    }`}>
                      {kiosk.status}
                    </span>
                  </div>

                  <h3 className="font-bold text-sm text-on-surface">{kiosk.name}</h3>
                  <p className="text-[11px] text-on-surface-variant mb-3">{kiosk.location}</p>

                  <div className="text-[11px] space-y-1 bg-surface-container-low p-2.5 rounded-xl text-on-surface-variant font-medium">
                    <div className="flex justify-between">
                      <span>Power:</span> <strong>{kiosk.battery}</strong>
                    </div>
                    <div className="flex justify-between">
                      <span>Sessions Today:</span> <strong>{kiosk.activeSessions}</strong>
                    </div>
                    <div className="flex justify-between">
                      <span>Last Heartbeat:</span> <strong>{kiosk.lastPing}</strong>
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2 mt-4 pt-3 border-t border-outline-variant/30">
                  <button
                    disabled
                    className="flex-1 py-1.5 rounded-lg border border-outline-variant text-[11px] font-bold hover:bg-surface-variant transition-colors flex items-center justify-center gap-1"
                  >
                    <RotateCw className="w-3 h-3" />
                    <span>Recalibrate</span>
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Section 2: Doctor Rostering & Room Allocation */}
        <div className="bg-surface-container-lowest p-6 rounded-3xl shadow-xs border border-outline-variant/30">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-xl font-bold text-on-surface flex items-center gap-2">
                <Users className="w-5 h-5 text-teal-600" />
                <span>Doctor Scheduling & OPD Room Allocation</span>
              </h2>
              <p className="text-xs text-on-surface-variant mt-0.5">
                Connected doctor roster will appear here when a roster source is configured.
              </p>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead className="bg-surface-container-low border-b border-outline-variant/30 text-xs font-bold uppercase text-on-surface-variant">
                <tr>
                  <th className="p-md">Doctor Name</th>
                  <th className="p-md">Specialty</th>
                  <th className="p-md">Assigned OPD Room</th>
                  <th className="p-md">Active Queue</th>
                  <th className="p-md">Status</th>
                  <th className="p-md text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="text-sm">
                {doctors.length === 0 && <tr><td className="p-4 text-on-surface-variant" colSpan={6}>No doctor roster is connected.</td></tr>}
                {doctors.map((doc, i) => (
                  <tr key={i} className="border-b border-outline-variant/20 hover:bg-surface-container-low transition-colors">
                    <td className="p-md">
                      <strong className="text-on-surface block">{doc.name}</strong>
                      <span className="text-xs text-on-surface-variant font-mono">{doc.email}</span>
                    </td>
                    <td className="p-md font-medium text-xs text-on-surface">
                      {doc.specialty}
                    </td>
                    <td className="p-md font-bold text-xs text-primary">
                      {doc.room}
                    </td>
                    <td className="p-md">
                      <span className="px-2.5 py-0.5 rounded-full bg-blue-50 text-blue-700 text-xs font-bold">
                        {doc.activeQueue} Patients
                      </span>
                    </td>
                    <td className="p-md">
                      <span className="px-2.5 py-0.5 rounded-md bg-emerald-50 text-emerald-700 text-xs font-bold inline-flex items-center gap-1">
                        <CheckCircle2 className="w-3.5 h-3.5" />
                        {doc.status}
                      </span>
                    </td>
                    <td className="p-md text-right">
                      <button
                        onClick={() => alert(`Reallocating room or shift for ${doc.name}`)}
                        className="px-3 py-1.5 bg-surface border border-outline-variant text-on-surface rounded-lg text-xs font-bold hover:bg-surface-variant transition-colors"
                      >
                        Reallocate
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

      </main>

    </div>
  );
}
