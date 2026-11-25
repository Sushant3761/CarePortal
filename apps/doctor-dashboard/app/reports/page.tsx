'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';
import { getAuthenticatedProfile } from '@/lib/auth';
import { DoctorHeader, DoctorSidebar } from '@/components/DoctorNavigation';
import {
  FileCheck,
  Search,
  Eye,
  Download,
  AlertTriangle,
  CheckCircle2,
  Clock,
  Plus,
  Filter,
  Microscope,
  FileSpreadsheet,
  ScanLine
} from 'lucide-react';

export default function ReportsPage() {
  const router = useRouter();
  const [user, setUser] = useState<any>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');

  const [reports, setReports] = useState<any[]>([]);

  useEffect(() => {
    checkAuth();
  }, []);

  const checkAuth = async () => {
    const profile = await getAuthenticatedProfile();
    if (profile) setUser(profile);
    else router.replace('/login');
  };

  const filteredReports = reports.filter((r) => {
    const matchesSearch = r.patientName.toLowerCase().includes(searchQuery.toLowerCase()) ||
                          r.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
                          r.findings.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesType = typeFilter === 'all' || r.type === typeFilter;
    return matchesSearch && matchesType;
  });

  return (
    <div className="bg-background font-body-md text-on-background min-h-screen">

      {/* Top Header */}
      <DoctorHeader
        doctorName={user?.name ? `${user.name.toUpperCase()} (OPD)` : 'Doctor Dashboard'}
        initials={user?.name ? user.name.split(' ').map((n: string) => n[0]).join('').slice(0, 2).toUpperCase() : 'AS'}
      />

      {/* Sidebar */}
      <DoctorSidebar activePath="/reports" />

      {/* Main Content */}
      <main className="pt-16 pl-64 min-h-screen flex flex-col bg-background">
        <div className="p-xl max-w-container-max mx-auto w-full flex flex-col gap-lg">

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-primary">Diagnostics & Scans</span>
            <h1 className="text-3xl font-extrabold text-on-background mt-1">Medical Reports & Diagnostics</h1>
          </div>

          {/* Search & Category Filter */}
          <div className="bg-surface-container-lowest p-md rounded-2xl shadow-xs border border-outline-variant/30 flex flex-col sm:flex-row items-center justify-between gap-4">
            <div className="relative w-full sm:w-80">
              <Search className="w-4 h-4 text-outline absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search test name, patient, findings..."
                className="w-full pl-10 pr-4 py-2 rounded-xl border border-outline-variant/60 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary bg-surface"
              />
            </div>

            <div className="flex items-center gap-2">
              <span className="text-xs font-bold text-on-surface-variant uppercase">Type:</span>
              <button
                onClick={() => setTypeFilter('all')}
                className={`px-3 py-1 rounded-lg text-xs font-bold ${typeFilter === 'all' ? 'bg-[#151c27] text-white' : 'bg-surface-container-low text-on-surface-variant'}`}
              >
                All
              </button>
              <button
                onClick={() => setTypeFilter('lab')}
                className={`px-3 py-1 rounded-lg text-xs font-bold ${typeFilter === 'lab' ? 'bg-[#151c27] text-white' : 'bg-surface-container-low text-on-surface-variant'}`}
              >
                Lab Tests
              </button>
              <button
                onClick={() => setTypeFilter('cardio')}
                className={`px-3 py-1 rounded-lg text-xs font-bold ${typeFilter === 'cardio' ? 'bg-[#151c27] text-white' : 'bg-surface-container-low text-on-surface-variant'}`}
              >
                Cardio (ECG)
              </button>
              <button
                onClick={() => setTypeFilter('radiology')}
                className={`px-3 py-1 rounded-lg text-xs font-bold ${typeFilter === 'radiology' ? 'bg-[#151c27] text-white' : 'bg-surface-container-low text-on-surface-variant'}`}
              >
                Radiology (X-Ray)
              </button>
            </div>
          </div>

          {/* Reports Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {filteredReports.length === 0 && <p className="col-span-full rounded-xl bg-surface-container-low p-4 text-sm text-on-surface-variant">No connected diagnostic reports are available.</p>}
            {filteredReports.map((report) => (
              <div
                key={report.id}
                className="bg-surface-container-lowest p-5 rounded-2xl shadow-xs border border-outline-variant/30 hover:border-primary/40 transition-all flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-start justify-between mb-2">
                    <div className="flex items-center gap-2.5">
                      <div className="w-10 h-10 rounded-xl bg-teal-50 text-[#00685f] flex items-center justify-center font-bold">
                        {report.type === 'lab' ? <Microscope className="w-5 h-5" /> : report.type === 'cardio' ? <FileSpreadsheet className="w-5 h-5" /> : <ScanLine className="w-5 h-5" />}
                      </div>
                      <div>
                        <h3 className="font-bold text-base text-on-surface">{report.title}</h3>
                        <p className="text-xs text-on-surface-variant font-medium">
                          Patient: <strong>{report.patientName}</strong> ({report.patientId})
                        </p>
                      </div>
                    </div>

                    <span className="text-[11px] font-mono text-outline">{report.id}</span>
                  </div>

                  {/* Findings Box */}
                  <div className={`p-3 rounded-xl text-xs font-medium mb-3 ${
                    report.isAbnormal ? 'bg-red-50 text-red-900 border border-red-200' : 'bg-[#f0f3ff] text-[#151c27]'
                  }`}>
                    <span className="font-bold block mb-0.5">Key Findings / Interpretation:</span>
                    {report.findings}
                  </div>
                </div>

                {/* Bottom Status & Actions */}
                <div className="flex items-center justify-between pt-3 border-t border-outline-variant/20 text-xs">
                  <div className="flex items-center gap-2">
                    <span className="text-on-surface-variant">{report.date}</span>
                    {report.ocrVerified && (
                      <span className="px-2 py-0.5 bg-green-50 text-green-700 text-[10px] font-bold rounded-md border border-green-200">
                        OCR Verified
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => alert(`Opening full digital report for ${report.title}`)}
                      className="px-3 py-1.5 bg-surface border border-outline-variant text-on-surface rounded-lg font-bold hover:bg-surface-variant transition-colors flex items-center gap-1"
                    >
                      <Eye className="w-3.5 h-3.5" />
                      <span>View</span>
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>

        </div>
      </main>

    </div>
  );
}
