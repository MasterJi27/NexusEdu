import { Request, Response, Router } from 'express';
import express from 'express';
import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import { z } from 'zod';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { env } from '../lib/env';
import { requireConfig, fetchJsonOrRespondError } from '../services/externalApi';

const router = Router();

/**
 * Azure AI services are rate-limited per user (like the GROQ routes) so one
 * account can't burn the free F0 quotas for everyone.
 */
const azureAiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 120,
  message: { error: 'Too many AI requests. Please slow down and try again in a few minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    const authReq = req as AuthRequest;
    if (authReq.user?.id) return `user:${authReq.user.id}`;
    return ipKeyGenerator(req.ip || '');
  },
});

router.use(authenticate, azureAiLimiter);

// ---------------------------------------------------------------------------
// Azure AI Speech — text-to-speech (neural voices incl. Hindi/regional)
// ---------------------------------------------------------------------------

const ttsSchema = z.object({
  text: z.string().min(1).max(1000),
  voice: z.string().default('hi-IN-SwaraNeural'),
  rate: z.string().regex(/^[+-]?\d+%$/).default('+0%'),
});

router.post('/speech/tts', validateBody(ttsSchema), async (req: Request, res: Response) => {
  const cfg = requireConfig({ AZURE_SPEECH_KEY: env.AZURE_SPEECH_KEY }, res, 'Azure Speech');
  if (!cfg) return;
  const { text, voice, rate } = req.body as z.infer<typeof ttsSchema>;
  try {
    const ssml = `<speak version='1.0' xml:lang='${voice.split('-').slice(0, 2).join('-')}'>` +
      `<voice name='${voice}'>` +
      `<prosody rate='${rate}'>${escapeXml(text)}</prosody>` +
      `</voice></speak>`;
    const r = await fetch(
      `https://${env.AZURE_SPEECH_REGION}.tts.speech.microsoft.com/cognitiveservices/v1`,
      {
        method: 'POST',
        headers: {
          'Ocp-Apim-Subscription-Key': cfg.AZURE_SPEECH_KEY,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-24khz-96kbitrate-mono-mp3',
        },
        body: ssml,
      },
    );
    if (!r.ok) {
      res.status(502).json({ error: `TTS failed (${r.status})`, detail: (await r.text()).slice(0, 300) });
      return;
    }
    const audio = Buffer.from(await r.arrayBuffer());
    res.set('Content-Type', 'audio/mpeg');
    res.set('Cache-Control', 'no-store');
    res.send(audio);
  } catch (error) {
    res.status(500).json({ error: 'TTS failed', detail: (error as Error).message });
  }
});

// ---------------------------------------------------------------------------
// Azure AI Translator — text translation to any supported language
// ---------------------------------------------------------------------------

const translateSchema = z.object({
  text: z.string().min(1).max(10000),
  to: z.string().regex(/^[a-z]{2,5}(-[A-Z]{2,4})?$/).default('hi'),
  from: z.string().regex(/^[a-z]{2,5}(-[A-Z]{2,4})?$/).optional(),
});

router.post('/translate', validateBody(translateSchema), async (req: Request, res: Response) => {
  const cfg = requireConfig({ AZURE_TRANSLATOR_KEY: env.AZURE_TRANSLATOR_KEY }, res, 'Azure Translator');
  if (!cfg) return;
  const { text, to, from } = req.body as z.infer<typeof translateSchema>;
  const url = `https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=${to}` +
    (from ? `&from=${from}` : '');
  const data = (await fetchJsonOrRespondError(
    url,
    {
      method: 'POST',
      headers: {
        'Ocp-Apim-Subscription-Key': cfg.AZURE_TRANSLATOR_KEY,
        'Ocp-Apim-Subscription-Region': env.AZURE_TRANSLATOR_REGION,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify([{ text }]),
    },
    res,
    'Translation',
  )) as { translations: { to: string; text: string }[] }[] | null;
  if (!data) return;
  res.json({ translatedText: data[0]?.translations?.[0]?.text ?? '' });
});

// ---------------------------------------------------------------------------
// Azure AI Document Intelligence — OCR for handwritten/printed notes
// ---------------------------------------------------------------------------

router.post(
  '/ocr',
  express.raw({ type: ['image/*', 'application/pdf'], limit: '8mb' }),
  async (req: Request, res: Response) => {
    const cfg = requireConfig(
      { AZURE_DOC_INTEL_KEY: env.AZURE_DOC_INTEL_KEY, AZURE_DOC_INTEL_ENDPOINT: env.AZURE_DOC_INTEL_ENDPOINT },
      res,
      'Azure Document Intelligence',
    );
    if (!cfg) return;
    if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
      res.status(400).json({ error: 'Send the image as raw binary body' });
      return;
    }
    try {
      const base = cfg.AZURE_DOC_INTEL_ENDPOINT.replace(/\/$/, '');
      const analyze = await fetch(
        `${base}/formrecognizer/documentModels/prebuilt-read:analyze?api-version=2023-07-31`,
        {
          method: 'POST',
          headers: {
            'Ocp-Apim-Subscription-Key': cfg.AZURE_DOC_INTEL_KEY,
            'Content-Type': 'image/jpeg',
          },
          body: Buffer.from(req.body),
        },
      );
      if (!analyze.ok) {
        res.status(502).json({ error: `OCR analyze failed (${analyze.status})`, detail: (await analyze.text()).slice(0, 300) });
        return;
      }
      const operationLocation = analyze.headers.get('operation-location');
      if (!operationLocation) {
        res.status(502).json({ error: 'OCR analyze returned no operation-location' });
        return;
      }
      // Poll the result (usually ready within 2-5s for a single page).
      for (let attempt = 0; attempt < 30; attempt++) {
        await new Promise((resolve) => setTimeout(resolve, 1000));
        const result = await fetch(operationLocation, {
          headers: { 'Ocp-Apim-Subscription-Key': cfg.AZURE_DOC_INTEL_KEY },
        });
        if (!result.ok) {
          res.status(502).json({ error: `OCR poll failed (${result.status})` });
          return;
        }
        const payload = (await result.json()) as {
          status: string;
          analyzeResult?: {
            content?: string;
            pages?: { words?: { content: string }[] }[];
          };
        };
        if (payload.status === 'succeeded') {
          const content = payload.analyzeResult?.content ?? '';
          const words = payload.analyzeResult?.pages?.flatMap((p) => p.words?.map((w) => w.content) ?? []) ?? [];
          res.json({ text: content, words });
          return;
        }
        if (payload.status === 'failed') {
          res.status(502).json({ error: 'OCR analysis failed' });
          return;
        }
      }
      res.status(504).json({ error: 'OCR analysis timed out' });
    } catch (error) {
      res.status(500).json({ error: 'OCR failed', detail: (error as Error).message });
    }
  },
);

// ---------------------------------------------------------------------------
// Azure AI Content Safety — moderate user text (hate, sexual, violence, self-harm)
// ---------------------------------------------------------------------------

const moderateSchema = z.object({
  text: z.string().min(1).max(1000),
});

router.post('/moderate', validateBody(moderateSchema), async (req: Request, res: Response) => {
  const cfg = requireConfig(
    { AZURE_CONTENT_SAFETY_KEY: env.AZURE_CONTENT_SAFETY_KEY, AZURE_CONTENT_SAFETY_ENDPOINT: env.AZURE_CONTENT_SAFETY_ENDPOINT },
    res,
    'Azure Content Safety',
  );
  if (!cfg) return;
  const { text } = req.body as z.infer<typeof moderateSchema>;
  const base = cfg.AZURE_CONTENT_SAFETY_ENDPOINT.replace(/\/$/, '');
  const data = (await fetchJsonOrRespondError(
    `${base}/contentsafety/text:analyze?api-version=2023-10-01`,
    {
      method: 'POST',
      headers: {
        'Ocp-Apim-Subscription-Key': cfg.AZURE_CONTENT_SAFETY_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        text,
        categories: ['Hate', 'Sexual', 'Violence', 'SelfHarm'],
        haltOnBlocklistHit: false,
      }),
    },
    res,
    'Moderation',
  )) as { categoriesAnalysis: { category: string; severity: number }[] } | null;
  if (!data) return;
  const flagged = data.categoriesAnalysis?.filter((c) => c.severity > 0) ?? [];
  res.json({
    flagged: flagged.length > 0,
    action: flagged.length > 0 ? 'reject' : 'allow',
    categories: flagged.map((c) => ({ category: c.category, severity: c.severity })),
  });
});

// ---------------------------------------------------------------------------
// Azure AI Speech — speech-to-text (STT) + pronunciation assessment
// ---------------------------------------------------------------------------

const sttSchema = z.object({
  language: z.string().regex(/^[a-z]{2,3}(-[A-Z]{2,4})?$/).default('en-US'),
});

// Audio comes as the raw body; language goes in a query param to keep the
// upload simple from Flutter (no multipart needed).
router.post('/speech/stt', express.raw({ type: ['audio/*'], limit: '10mb' }), async (req: Request, res: Response) => {
  const cfg = requireConfig({ AZURE_SPEECH_KEY: env.AZURE_SPEECH_KEY }, res, 'Azure Speech');
  if (!cfg) return;
  if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
    res.status(400).json({ error: 'Send the audio as raw binary body' });
    return;
  }
  const language = typeof req.query.language === 'string' && req.query.language
    ? req.query.language
    : 'en-US';
  const url =
    `https://${env.AZURE_SPEECH_REGION}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1` +
    `?language=${encodeURIComponent(language)}&format=detailed`;
  const data = await fetchJsonOrRespondError(
    url,
    {
      method: 'POST',
      headers: {
        'Ocp-Apim-Subscription-Key': cfg.AZURE_SPEECH_KEY,
        'Content-Type': req.headers['content-type'] || 'audio/wav',
        'Accept': 'application/json',
      },
      body: Buffer.from(req.body),
      signal: AbortSignal.timeout(60000),
    },
    res,
    'STT',
  );
  if (!data) return;
  const nbest = data?.NBest?.[0];
  res.json({
    text: nbest?.DisplayText ?? data?.DisplayText ?? '',
    confidence: nbest?.Confidence ?? null,
    words: (nbest?.Words ?? []).map((w: any) => ({ word: w.Word, start: w.Offset, duration: w.Duration })),
  });
});

const pronunciationSchema = z.object({
  referenceText: z.string().min(1).max(500),
  language: z.string().regex(/^[a-z]{2,3}(-[A-Z]{2,4})?$/).default('en-US'),
});

// Audio raw body; reference text + language via query params.
router.post('/speech/pronunciation', express.raw({ type: ['audio/*'], limit: '10mb' }), async (req: Request, res: Response) => {
  const cfg = requireConfig({ AZURE_SPEECH_KEY: env.AZURE_SPEECH_KEY }, res, 'Azure Speech');
  if (!cfg) return;
  if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
    res.status(400).json({ error: 'Send the audio as raw binary body' });
    return;
  }
  const referenceText = typeof req.query.referenceText === 'string' ? req.query.referenceText : '';
  if (!referenceText) {
    res.status(400).json({ error: 'Missing referenceText query param' });
    return;
  }
  const language = typeof req.query.language === 'string' && req.query.language ? req.query.language : 'en-US';
  try {
    // Pronunciation assessment params go in the Pronunciation-Assessment header
    // as Base64-encoded JSON (query param variant is not honoured by the service).
    const assessmentJson = JSON.stringify({
      ReferenceText: referenceText,
      GradingSystem: 'HundredMark',
      Granularity: 'Phoneme',
      Dimension: 'Comprehensive',
    });
    const assessmentHeader = Buffer.from(assessmentJson).toString('base64');
    const url =
      `https://${env.AZURE_SPEECH_REGION}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1` +
      `?language=${encodeURIComponent(language)}&format=detailed`;
    const data = await fetchJsonOrRespondError(
      url,
      {
        method: 'POST',
        headers: {
          'Ocp-Apim-Subscription-Key': cfg.AZURE_SPEECH_KEY,
          'Pronunciation-Assessment': assessmentHeader,
          'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
          'Accept': 'application/json',
        },
        body: Buffer.from(req.body),
        signal: AbortSignal.timeout(60000),
      },
      res,
      'Pronunciation assessment',
    );
    if (!data) return;
    const nbest = data?.NBest?.[0];
    const pa = nbest; // scores are flat on NBest[0] (AccuracyScore, FluencyScore, PronScore...)
    res.json({
      text: data?.DisplayText ?? nbest?.Display ?? '',
      accuracy: pa?.AccuracyScore ?? null,
      fluency: pa?.FluencyScore ?? null,
      prosody: pa?.ProsodyScore ?? null,
      completeness: pa?.CompletenessScore ?? null,
      pronunciation: pa?.PronScore ?? null,
      words: (nbest?.Words ?? []).map((w: any) => ({
        word: w.Word,
        accuracy: w.AccuracyScore ?? null,
        errorType: w.ErrorType ?? null,
      })),
    });
  } catch (error) {
    res.status(500).json({ error: 'Pronunciation assessment failed', detail: (error as Error).message });
  }
});

// ---------------------------------------------------------------------------
// Azure AI Language — sentiment, key phrases, PII
// ---------------------------------------------------------------------------

const languageSchema = z.object({
  text: z.string().min(1).max(5000),
});

async function languageEndpoint(path: string, body: unknown, res: Response, key: string, base: string) {
  return fetchJsonOrRespondError(
    `${base.replace(/\/$/, '')}${path}`,
    {
      method: 'POST',
      headers: {
        'Ocp-Apim-Subscription-Key': key,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(30000),
    },
    res,
    'Language API',
  );
}

router.post('/language/sentiment', validateBody(languageSchema), async (req: Request, res: Response) => {
  const cfg = requireConfig(
    { AZURE_LANGUAGE_KEY: env.AZURE_LANGUAGE_KEY, AZURE_LANGUAGE_ENDPOINT: env.AZURE_LANGUAGE_ENDPOINT },
    res,
    'Azure AI Language',
  );
  if (!cfg) return;
  const { text } = req.body as z.infer<typeof languageSchema>;
  const data = await languageEndpoint(
    '/text/analytics/v3.1/sentiment',
    { documents: [{ id: '1', language: 'en', text }] },
    res,
    cfg.AZURE_LANGUAGE_KEY,
    cfg.AZURE_LANGUAGE_ENDPOINT,
  );
  if (!data) return;
  const doc = (data as any).documents?.[0];
  res.json({
    sentiment: doc?.sentiment ?? 'neutral',
    scores: doc?.confidenceScores ?? null,
    sentences: (doc?.sentences ?? []).map((s: any) => ({
      text: s.text,
      sentiment: s.sentiment,
      scores: s.confidenceScores,
    })),
  });
});

router.post('/language/keyphrases', validateBody(languageSchema), async (req: Request, res: Response) => {
  const cfg = requireConfig(
    { AZURE_LANGUAGE_KEY: env.AZURE_LANGUAGE_KEY, AZURE_LANGUAGE_ENDPOINT: env.AZURE_LANGUAGE_ENDPOINT },
    res,
    'Azure AI Language',
  );
  if (!cfg) return;
  const { text } = req.body as z.infer<typeof languageSchema>;
  const data = await languageEndpoint(
    '/text/analytics/v3.1/keyPhrases',
    { documents: [{ id: '1', language: 'en', text }] },
    res,
    cfg.AZURE_LANGUAGE_KEY,
    cfg.AZURE_LANGUAGE_ENDPOINT,
  );
  if (!data) return;
  res.json({ keyPhrases: (data as any).documents?.[0]?.keyPhrases ?? [] });
});

router.post('/language/pii', validateBody(languageSchema), async (req: Request, res: Response) => {
  const cfg = requireConfig(
    { AZURE_LANGUAGE_KEY: env.AZURE_LANGUAGE_KEY, AZURE_LANGUAGE_ENDPOINT: env.AZURE_LANGUAGE_ENDPOINT },
    res,
    'Azure AI Language',
  );
  if (!cfg) return;
  const { text } = req.body as z.infer<typeof languageSchema>;
  const data = await languageEndpoint(
    '/text/analytics/v3.1/entities/recognition/pii',
    { documents: [{ id: '1', language: 'en', text }] },
    res,
    cfg.AZURE_LANGUAGE_KEY,
    cfg.AZURE_LANGUAGE_ENDPOINT,
  );
  if (!data) return;
  const doc = (data as any).documents?.[0];
  const entities: any[] = doc?.entities ?? [];
  let redacted = text;
  for (const e of entities) {
    redacted = redacted.replace(e.text, '[REDACTED]');
  }
  res.json({ entities, redactedText: redacted });
});

// ---------------------------------------------------------------------------
// Azure AI Vision — image analysis (caption, tags, faces, objects, OCR)
// ---------------------------------------------------------------------------

router.post('/vision/analyze', express.raw({ type: ['image/*'], limit: '8mb' }), async (req: Request, res: Response) => {
  const cfg = requireConfig(
    { AZURE_VISION_KEY: env.AZURE_VISION_KEY, AZURE_VISION_ENDPOINT: env.AZURE_VISION_ENDPOINT },
    res,
    'Azure AI Vision',
  );
  if (!cfg) return;
  if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
    res.status(400).json({ error: 'Send the image as raw binary body' });
    return;
  }
  const features = ['Description', 'Tags', 'Faces', 'Objects', 'Color'];
  try {
    const base = cfg.AZURE_VISION_ENDPOINT.replace(/\/$/, '');
    const url =
      `${base}/vision/v3.2/analyze` +
      `?visualFeatures=${features.join(',')}&language=en`;
    const data = await fetchJsonOrRespondError(
      url,
      {
        method: 'POST',
        headers: {
          'Ocp-Apim-Subscription-Key': cfg.AZURE_VISION_KEY,
          'Content-Type': req.headers['content-type'] || 'application/octet-stream',
        },
        body: Buffer.from(req.body),
        signal: AbortSignal.timeout(60000),
      },
      res,
      'Vision',
    );
    if (!data) return;
    const d = data as any;
    res.json({
      caption: d.description?.captions?.[0]?.text ?? null,
      captionConfidence: d.description?.captions?.[0]?.confidence ?? null,
      tags: (d.tags ?? []).map((t: any) => ({ name: t.name, confidence: t.confidence })),
      faces: (d.faces ?? []).map((f: any) => ({
        age: f.age,
        gender: f.gender,
        rectangle: f.faceRectangle,
      })),
      objects: (d.objects ?? []).map((o: any) => ({
        object: o.object,
        confidence: o.confidence,
        rectangle: o.rectangle,
      })),
      dominantColors: d.color?.dominantColors ?? [],
      accentColor: d.color?.accentColor ?? null,
    });
  } catch (error) {
    res.status(500).json({ error: 'Vision analysis failed', detail: (error as Error).message });
  }
});

// Health endpoint for diagnostics
router.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'ok',
    speech: env.AZURE_SPEECH_KEY ? 'configured' : 'missing',
    translator: env.AZURE_TRANSLATOR_KEY ? 'configured' : 'missing',
    docIntel: env.AZURE_DOC_INTEL_KEY ? 'configured' : 'missing',
    contentSafety: env.AZURE_CONTENT_SAFETY_KEY ? 'configured' : 'missing',
    language: env.AZURE_LANGUAGE_KEY ? 'configured' : 'missing',
    vision: env.AZURE_VISION_KEY ? 'configured' : 'missing',
  });
});

function escapeXml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

export default router;
