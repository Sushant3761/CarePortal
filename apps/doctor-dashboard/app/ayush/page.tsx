'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { getAuthenticatedProfile } from '@/lib/auth';
import { DoctorHeader, DoctorSidebar } from '@/components/DoctorNavigation';
import { Info } from 'lucide-react';

export default function AyushPage() {
  const router = useRouter();
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    getAuthenticatedProfile().then((profile) => {
      if (profile) setUser(profile);
      else router.replace('/login');
    });
  }, [router]);

  return (
    <div className="bg-background font-body-md text-on-background min-h-screen">
      <DoctorHeader
        doctorName={user?.name ? `${user.name.toUpperCase()} (OPD)` : 'Doctor Dashboard'}
        initials={user?.name ? user.name.split(' ').map((n: string) => n[0]).join('').slice(0, 2).toUpperCase() : 'DR'}
      />
      <DoctorSidebar activePath="/ayush" />
      <main className="pt-16 pl-64 min-h-screen flex flex-col bg-background">
        <div className="p-xl max-w-container-max mx-auto w-full flex flex-col gap-lg">
          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-primary">Integrated Holistic Medicine</span>
            <h1 className="text-3xl font-extrabold text-on-background mt-1">AYUSH &amp; Prakriti Assessment</h1>
          </div>
          <section role="status" className="flex items-start gap-3 rounded-2xl border border-amber-300 bg-amber-50 p-5 text-amber-950">
            <Info className="mt-0.5 h-5 w-5 shrink-0" />
            <div>
              <h2 className="font-bold">No patient assessment is available</h2>
              <p className="mt-1 text-sm">Select an authorized patient record and complete a clinician-reviewed assessment before displaying recommendations. This screen does not generate or prescribe treatment.</p>
            </div>
          </section>
        </div>
      </main>
    </div>
  );
}
