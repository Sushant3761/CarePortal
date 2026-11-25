'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';
import { getAuthenticatedProfile } from '@/lib/auth';
import { DoctorHeader, DoctorSidebar } from '@/components/DoctorNavigation';
import {
  FileText,
  Search,
  Download,
  Filter,
  CheckCircle2,
  Calendar,
  User,
  ExternalLink,
  Plus,
  Clock,
  Sparkles
} from 'lucide-react';

export default function RecordsPage() {
  const router = useRouter();
  const [user, setUser] = useState<any>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  const [records, setRecords] = useState<any[]>([]);

  useEffect(() => {
    checkAuth();
    loadLiveRecords();

    // Auto-polling fallback every 4s to ensure records are always up-to-date
    const pollInterval = setInterval(() => {
      loadLiveRecords();
    }, 4000);

    const channel = supabase
      .channel('records-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'clinical_summaries' },
        () => loadLiveRecords()
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'patients' },
        () => loadLiveRecords()
      )
      .subscribe();

    return () => {
      clearInterval(pollInterval);
      supabase.removeChannel(channel);
    };
  }, []);

  const loadLiveRecords = async () => {
    try {
      const { data: summaryData } = await supabase
        .from('clinical_summaries')
        .select('*')
        .order('created_at', { ascending: false });

      if (summaryData) {
        if (summaryData.length === 0) {
          setRecords([]);
          return;
        }
        const ptIds = Array.from(new Set(summaryData.map((s: any) => s.patient_id).filter(Boolean)));
        let patientMap: Record<string, any> = {};
        if (ptIds.length > 0) {
          const { data: pts } = await supabase
            .from('patients')
            .select('*')
            .in('id', ptIds);
          (pts || []).forEach((p: any) => {
            patientMap[p.id] = p;
          });
        }

        const liveRecords = summaryData.map((s: any) => {
          const pat = patientMap[s.patient_id] || {};
          return {
            id: `REC-${s.id.slice(0, 4).toUpperCase()}`,
            patientId: pat.id || s.patient_id,
            patientName: pat.name || 'Registered Patient',
            age: pat.age ?? '—',
            gender: pat.gender ? pat.gender[0].toUpperCase() : '—',
            date: new Date(s.created_at || Date.now()).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
            diagnosis: s.chief_complaint || 'General Clinical Assessment',
            chiefComplaint: s.history_present_illness?.slice(0, 80) || s.chief_complaint || 'Clinical intake completed',
            doctor: 'Not assigned',
            completeness: Math.round((s.ai_confidence || 0.95) * 100),
            status: s.status || 'pending',
          };
        });

        setRecords(liveRecords);
      }
    } catch (err) {
      console.warn('Records fetch error:', err);
    }
  };

  const checkAuth = async () => {
    const profile = await getAuthenticatedProfile();
    if (profile) setUser(profile);
    else router.replace('/login');
  };

  const handleExportPDF = (recordId: string, name: string) => {
    alert(`Generating & Downloading Comprehensive Clinical Summary PDF for ${name} (${recordId})...`);
  };

  const filteredRecords = records.filter((r) => {
    const matchesSearch = r.patientName.toLowerCase().includes(searchQuery.toLowerCase()) ||
                          r.diagnosis.toLowerCase().includes(searchQuery.toLowerCase()) ||
                          r.id.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus = statusFilter === 'all' || r.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  return (
    <div className="bg-background font-body-md text-on-background min-h-screen">

      {/* Top Header */}
      <DoctorHeader
        doctorName={user?.name ? `${user.name.toUpperCase()} (OPD)` : 'Doctor Dashboard'}
        initials={user?.name ? user.name.split(' ').map((n: string) => n[0]).join('').slice(0, 2).toUpperCase() : 'AS'}
      />

      {/* Sidebar */}
      <DoctorSidebar activePath="/records" />

      {/* Main Content */}
      <main className="pt-16 pl-64 min-h-screen flex flex-col bg-background">
        <div className="p-xl max-w-container-max mx-auto w-full flex flex-col gap-lg">

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-primary">Electronic Health Records (EHR)</span>
            <h1 className="text-3xl font-extrabold text-on-background mt-1">Clinical Records Archive</h1>
          </div>

          {/* Search and Filters */}
          <div className="bg-surface-container-lowest p-md rounded-2xl shadow-xs border border-outline-variant/30 flex flex-col sm:flex-row items-center justify-between gap-4">
            <div className="relative w-full sm:w-80">
              <Search className="w-4 h-4 text-outline absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search patient, diagnosis, record ID..."
                className="w-full pl-10 pr-4 py-2 rounded-xl border border-outline-variant/60 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary bg-surface"
              />
            </div>

            <div className="flex items-center gap-2">
              <span className="text-xs font-bold text-on-surface-variant uppercase">Status:</span>
              <button
                onClick={() => setStatusFilter('all')}
                className={`px-3 py-1 rounded-lg text-xs font-bold ${statusFilter === 'all' ? 'bg-[#151c27] text-white' : 'bg-surface-container-low text-on-surface-variant'}`}
              >
                All
              </button>
              <button
                onClick={() => setStatusFilter('verified')}
                className={`px-3 py-1 rounded-lg text-xs font-bold ${statusFilter === 'verified' ? 'bg-[#151c27] text-white' : 'bg-surface-container-low text-on-surface-variant'}`}
              >
                Verified
              </button>
              <button
                onClick={() => setStatusFilter('pending')}
                className={`px-3 py-1 rounded-lg text-xs font-bold ${statusFilter === 'pending' ? 'bg-[#151c27] text-white' : 'bg-surface-container-low text-on-surface-variant'}`}
              >
                Pending Review
              </button>
            </div>
          </div>

          {/* Records Table */}
          <div className="bg-surface-container-lowest rounded-2xl shadow-xs border border-outline-variant/30 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse min-w-[700px]">
                <thead className="bg-surface-container-low border-b border-outline-variant/30 text-xs font-bold uppercase text-on-surface-variant tracking-wider">
                  <tr>
                    <th className="p-md">Record ID / Date</th>
                    <th className="p-md">Patient</th>
                    <th className="p-md">Provisional Diagnosis</th>
                    <th className="p-md">Attending Physician</th>
                    <th className="p-md">Completeness</th>
                    <th className="p-md">Status</th>
                    <th className="p-md text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="text-sm">
                  {filteredRecords.length === 0 && <tr><td className="p-4 text-on-surface-variant" colSpan={7}>No authorized patient records are available.</td></tr>}
                  {filteredRecords.map((rec) => (
                    <tr key={rec.id} className="border-b border-outline-variant/20 hover:bg-surface-container-low transition-colors">
                      <td className="p-md">
                        <span className="font-mono font-bold text-xs text-primary block">{rec.id}</span>
                        <span className="text-xs text-on-surface-variant">{rec.date}</span>
                      </td>
                      <td className="p-md">
                        <span className="font-bold text-on-surface block">{rec.patientName}</span>
                        <span className="text-xs text-on-surface-variant">{rec.age} Y / {rec.gender} • {rec.patientId}</span>
                      </td>
                      <td className="p-md">
                        <span className="font-medium text-on-surface block">{rec.diagnosis}</span>
                        <span className="text-xs text-on-surface-variant line-clamp-1">{rec.chiefComplaint}</span>
                      </td>
                      <td className="p-md text-xs font-medium text-on-surface-variant">
                        {rec.doctor}
                      </td>
                      <td className="p-md">
                        <div className="flex items-center gap-2">
                          <span className="text-xs font-bold text-on-surface">{rec.completeness}%</span>
                          <div className="w-16 h-1.5 rounded-full bg-slate-100 overflow-hidden">
                            <div className="h-full bg-[#00685f]" style={{ width: `${rec.completeness}%` }} />
                          </div>
                        </div>
                      </td>
                      <td className="p-md">
                        {rec.status === 'verified' ? (
                          <span className="px-2.5 py-0.5 rounded-md bg-green-50 text-green-700 border border-green-200 text-xs font-bold inline-flex items-center gap-1">
                            <CheckCircle2 className="w-3 h-3" />
                            Verified
                          </span>
                        ) : (
                          <span className="px-2.5 py-0.5 rounded-md bg-amber-50 text-amber-700 border border-amber-200 text-xs font-bold inline-flex items-center gap-1">
                            <Clock className="w-3 h-3" />
                            Pending
                          </span>
                        )}
                      </td>
                      <td className="p-md text-right">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => handleExportPDF(rec.id, rec.patientName)}
                            title="Export PDF Summary"
                            className="p-2 rounded-lg bg-surface border border-outline-variant hover:bg-surface-variant text-on-surface transition-colors"
                          >
                            <Download className="w-4 h-4 text-primary" />
                          </button>
                          <button
                            onClick={() => router.push(`/patient/${rec.patientId}`)}
                            className="px-3 py-1.5 bg-primary hover:bg-[#005049] text-white text-xs font-bold rounded-lg transition-all"
                          >
                            View Case
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

        </div>
      </main>

    </div>
  );
}
