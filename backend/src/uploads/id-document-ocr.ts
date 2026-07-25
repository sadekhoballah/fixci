import { createWorker } from 'tesseract.js';

// A worker per call has a ~1-2s cold start, but this only runs on the
// id-card upload path (once per registration), not a hot request — not
// worth a pooled scheduler for that volume. French because FixCi's
// documents (CNI/passeport de Côte d'Ivoire) are French; tesseract.js
// downloads and caches this language's traineddata to disk on first use,
// so the first call after a fresh deploy needs outbound network access.
export async function extractDocumentText(filePath: string): Promise<string> {
  const worker = await createWorker('fra');
  try {
    const {
      data: { text },
    } = await worker.recognize(filePath);
    return text.replace(/\s+/g, ' ').trim();
  } finally {
    await worker.terminate();
  }
}
