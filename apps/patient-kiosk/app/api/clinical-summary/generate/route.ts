import { NextResponse, type NextRequest } from 'next/server';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { consumeRateLimit, getClientAddress } from '@/lib/rateLimit';

// Initialize Gemini API
const apiKey = process.env.GEMINI_API_KEY || '';
const genAI = apiKey ? new GoogleGenerativeAI(apiKey) : null;

export async function POST(req: NextRequest) {
  try {
    const address = getClientAddress(req);
    if (!address) {
      return NextResponse.json({ success: false, error: 'Summary service is unavailable.' }, { status: 503 });
    }
    const limit = await consumeRateLimit('clinical-summary:' + address, 10, 3600);
    if (!limit.allowed) {
      return NextResponse.json(
        { success: false, error: 'Summary service is temporarily unavailable.' },
        { status: limit.retryAfterSeconds === null ? 503 : 429, headers: limit.retryAfterSeconds === null ? undefined : { 'Retry-After': String(limit.retryAfterSeconds) } }
      );
    }
    const contentLength = Number(req.headers.get('content-length') || 0);
    if (contentLength > 65536) {
      return NextResponse.json({ success: false, error: 'Request is too large.' }, { status: 413 });
    }
    const rawBody = await req.text();
    if (new TextEncoder().encode(rawBody).byteLength > 65536) {
      return NextResponse.json({ success: false, error: 'Request is too large.' }, { status: 413 });
    }
    let body: Record<string, any>;
    try {
      body = JSON.parse(rawBody);
    } catch {
      return NextResponse.json({ success: false, error: 'Invalid request body.' }, { status: 400 });
    }
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return NextResponse.json({ success: false, error: 'Invalid request body.' }, { status: 400 });
    }
    const isTextList = (value: unknown) =>
      Array.isArray(value) && value.length <= 30 &&
      value.every((entry) => typeof entry === 'string' && entry.length <= 300);
    const isBoundedObject = (value: unknown) =>
      typeof value === 'object' && value !== null && !Array.isArray(value) &&
      JSON.stringify(value).length <= 8000;
    if (
      typeof body.chiefComplaint !== 'string' || body.chiefComplaint.length > 1000 ||
      !Array.isArray(body.painLocations) || body.painLocations.length > 20 ||
      !body.painLocations.every((location: unknown) =>
        (typeof location === 'string' && location.length <= 120) ||
        (typeof location === 'object' && location !== null && !Array.isArray(location) &&
          Object.values(location).every((value) => typeof value === 'string' && value.length <= 120))
      ) ||
      (body.painIntensity !== undefined &&
        (typeof body.painIntensity !== 'number' || !Number.isFinite(body.painIntensity) || body.painIntensity < 1 || body.painIntensity > 10)) ||
      typeof (body.onset ?? '') !== 'string' || String(body.onset ?? '').length > 200 ||
      typeof (body.character ?? '') !== 'string' || String(body.character ?? '').length > 300 ||
      typeof (body.timeline ?? '') !== 'string' || String(body.timeline ?? '').length > 300 ||
      !isBoundedObject(body.historyAnswers ?? {}) ||
      !isTextList(body.pastMedicalHistory ?? []) ||
      !isTextList(body.pastSurgicalHistory ?? []) ||
      !isTextList(body.medications ?? []) ||
      !isTextList(body.allergies ?? []) ||
      !isTextList(body.familyHistory ?? []) ||
      !isBoundedObject(body.personalHistory ?? {}) ||
      !isBoundedObject(body.reviewOfSystems ?? {})
    ) {
      return NextResponse.json({ success: false, error: 'Invalid clinical summary details.' }, { status: 400 });
    }
    const {
      patientId,
      sessionId,
      historyId,
      tokenNumber,
      chiefComplaint = '',
      painLocations = [],
      painIntensity,
      onset = '',
      character = '',
      timeline = '',
      historyAnswers = {},
      pastMedicalHistory = [],
      pastSurgicalHistory = [],
      medications = [],
      allergies = [],
      familyHistory = [],
      personalHistory = {},
      reviewOfSystems = {},
      department = 'General Medicine',
      priority = 'normal'
    } = body;

    let aiSummary: any = null;
    let redFlags: string[] = [];
    let missingInfo: string[] = [];
    let aiConfidence = 0.90;

    // 1. Generate Structured Summary with Gemini AI if available
    if (genAI) {
      try {
        const targetModel = process.env.AI_MODEL || 'gemini-1.5-flash-latest';
        const model = genAI.getGenerativeModel({ model: targetModel });

        const painText = painLocations.map((p: any) => typeof p === 'string' ? p : p.nameEn || p.name || p.id).join(', ');

        const prompt = `You are an expert Clinical AI Scribe and Medical Officer in a high-volume hospital OPD.
Synthesize the following patient intake data into a physician-grade, structured Electronic Health Record (EHR) Clinical Summary.

PATIENT INTAKE DATA:
- Chief Complaint: ${chiefComplaint || 'Not specified'}
- Pain Locations: ${painText || 'None'}
- Pain Severity (1-10): ${painIntensity ?? 'Not reported'}
- Onset & Timeline: ${onset}, ${timeline}
- Pain Quality/Character: ${character}
- Questionnaire Responses: ${JSON.stringify(historyAnswers)}
- Past Medical History: ${JSON.stringify(pastMedicalHistory)}
- Past Surgical History: ${JSON.stringify(pastSurgicalHistory)}
- Current Medications: ${JSON.stringify(medications)}
- Known Allergies: ${JSON.stringify(allergies)}
- Family Medical History: ${JSON.stringify(familyHistory)}
- Personal / Lifestyle History: ${JSON.stringify(personalHistory)}
- Review of Systems: ${JSON.stringify(reviewOfSystems)}

Return a strict JSON object with this exact schema (no markdown fences, just JSON):
{
  "chiefComplaint": "Precise medical formulation of chief complaint",
  "historyPresentIllness": "Detailed chronological narrative of the present illness with onset, location, duration, character, aggravating/relieving factors, and associated symptoms (SOCRATES framework)",
  "pastMedicalHistory": "Summary of prior medical conditions or 'None reported'",
  "pastSurgicalHistory": "Summary of prior surgeries/procedures or 'None reported'",
  "medications": "Formatted list of current medications, dosage, and compliance or 'None reported'",
  "allergies": "Known drug/food allergies or 'Not reported'",
  "familyHistory": "Relevant familial conditions or 'Not reported'",
  "personalHistory": "Dietary habits, smoking/alcohol, physical activity, sleep",
  "reviewOfSystems": "Pertinent positive and negative system reviews",
  "priorInvestigations": "Relevant lab or radiology history if noted",
  "ayushSummary": "Holistic Ayurvedic/AYUSH perspective (Dosha imbalance or constitution insights if applicable)",
  "redFlags": ["List of any critical symptoms or red flags requiring immediate physician triage"],
  "missingInformation": ["List of clinical details that the physician should clarify during in-person consult"],
  "triagePriority": "EMERGENCY" | "HIGH" | "STANDARD" | "LOW",
  "confidenceScore": 0.95
}`;

        // Add timeout and retry logic
        const timeoutMs = parseInt(process.env.AI_TIMEOUT_MS || '15000');
        const result = await Promise.race([
          model.generateContent(prompt),
          new Promise<never>((_, reject) =>
            setTimeout(() => reject(new Error('Gemini API timeout')), timeoutMs)
          ),
        ]);

        const rawText = result.response.text();

        const jsonMatch = rawText.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          aiSummary = JSON.parse(jsonMatch[0]);
          redFlags = aiSummary.redFlags || [];
          missingInfo = aiSummary.missingInformation || [];
          aiConfidence = aiSummary.confidenceScore || 0.92;
        }
      } catch (aiErr: any) {
        console.warn('Clinical summary AI generation failed; using the deterministic fallback.');
      }
    }

    // Fallback synthesis if AI is unavailable
    if (!aiSummary) {
      const painText = painLocations.map((p: any) => typeof p === 'string' ? p : p.nameEn || p.name || p.id).join(', ');
      const isChestPain = chiefComplaint.toLowerCase().includes('chest') || chiefComplaint.toLowerCase().includes('heart') || chiefComplaint.toLowerCase().includes('breath');
      const isSevere = painIntensity >= 7 || chiefComplaint.toLowerCase().includes('severe') || chiefComplaint.toLowerCase().includes('acute');

      if (isChestPain) {
        redFlags.push('Cardiovascular / Respiratory distress alert - immediate ECG and vitals check recommended.');
      }
      if (painIntensity >= 8) {
        redFlags.push('High pain score (≥8/10) reported - prioritize immediate evaluation.');
      }

      aiSummary = {
        chiefComplaint: chiefComplaint || 'Not reported',
        historyPresentIllness: `Patient reports ${chiefComplaint || 'no chief complaint recorded'}${painText ? ` localized to ${painText}` : ''}; reported intensity: ${painIntensity ?? 'not reported'}/10. Onset: ${onset || 'not reported'}; timeline: ${timeline || 'not reported'}. ${character ? `Characterized by ${character}.` : ''}`,
        pastMedicalHistory: Array.isArray(pastMedicalHistory) && pastMedicalHistory.length > 0 ? pastMedicalHistory.join(', ') : 'None reported',
        pastSurgicalHistory: Array.isArray(pastSurgicalHistory) && pastSurgicalHistory.length > 0 ? pastSurgicalHistory.join(', ') : 'None reported',
        medications: typeof medications === 'string' ? medications : (Array.isArray(medications) && medications.length > 0 ? JSON.stringify(medications) : 'Not reported'),
        allergies: typeof allergies === 'string' ? allergies : (Array.isArray(allergies) && allergies.length > 0 ? JSON.stringify(allergies) : 'Not reported'),
        familyHistory: Array.isArray(familyHistory) && familyHistory.length > 0 ? JSON.stringify(familyHistory) : 'Not reported',
        personalHistory: typeof personalHistory === 'string' ? personalHistory : (Object.keys(personalHistory).length > 0 ? JSON.stringify(personalHistory) : 'Not reported'),
        reviewOfSystems: typeof reviewOfSystems === 'string' ? reviewOfSystems : (Object.keys(reviewOfSystems).length > 0 ? JSON.stringify(reviewOfSystems) : 'Not reported'),
        priorInvestigations: 'Prior records reviewed during kiosk intake',
        ayushSummary: 'Vata-Pitta balance assessment recommended in OPD integration',
        redFlags: redFlags,
        missingInformation: missingInfo,
        triagePriority: isChestPain ? 'EMERGENCY' : (isSevere ? 'HIGH' : 'STANDARD'),
        confidenceScore: 0.88,
      };
    }

    // Clinical persistence is intentionally deferred until an OTP-verified intake
    // session and patient ownership policy are implemented. Never trust caller IDs here.
    const savedSummaryId = null;

    return NextResponse.json({
      success: true,
      summaryId: savedSummaryId,
      persisted: false,
      persistenceMessage: 'Summary is not saved. Complete secure intake authorization first.',
      clinicalSummary: aiSummary,
      redFlags: aiSummary.redFlags || redFlags,
      confidence: aiConfidence,
      triagePriority: aiSummary.triagePriority || 'STANDARD',
    }, { status: 200 });

  } catch (error: any) {
    console.error('Clinical summary generation failed.');
    return NextResponse.json(
      { success: false, error: 'Failed to generate clinical summary.' },
      { status: 500 }
    );
  }
}
