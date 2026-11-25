'use client';

import { Upload } from 'lucide-react';
import { Card } from '@/components/ui/card';

export default function DocumentUpload() {
  return (
    <Card className="p-4 md:p-6">
      <div className="flex items-start gap-3">
        <Upload className="w-5 h-5 text-[#00685f] shrink-0 mt-0.5" />
        <div>
          <h3 className="text-lg md:text-xl font-semibold text-[#151c27] mb-2">Document upload unavailable</h3>
          <p className="text-sm text-[#5C5C5C]">
            No file is uploaded or saved. Private storage and an authenticated patient session are not configured.
          </p>
        </div>
      </div>
    </Card>
  );
}
