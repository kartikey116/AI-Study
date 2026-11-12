import * as crypto from 'crypto';

/**
 * Structure-aware chunking. Each page's text is split into blocks (paragraphs, list
 * items, tables, [Figure: …] descriptions), then blocks are packed into chunks of about
 * TARGET_WORDS without cutting sentences. Each chunk is prefixed with the section heading
 * it falls under, so a passage deep in "2.3 Sun-Earth Angles" still matches questions about
 * that section. Chunks never cross pages, so page citations stay exact.
 */
const TARGET_WORDS = 300;
const MAX_WORDS = 420;      // a single block longer than this is split by sentences
const OVERLAP_WORDS = 40;   // trailing sentences repeated at the start of the next chunk
const MIN_CHUNK_CHARS = 50;

export interface TextChunk {
  text: string;
  pageNumber: number;
  chunkIndex: number;
  contentHash: string;
}

const wordCount = (s: string) => (s.match(/\S+/g) ?? []).length;

/** Markdown headings, or short numbered/titled lines like "2.1 Solar Radiation:" / "UNIT II". */
function headingOf(block: string): string | null {
  // Only the first line matters: a heading is often followed by its paragraph in the same block
  const firstLine = block.split('\n')[0].trim();
  const md = firstLine.match(/^#{1,6}\s+(.+)$/);
  if (md) return md[1].replace(/[*_`]/g, '').replace(/:$/, '').trim();
  if (firstLine.length > 90 || wordCount(firstLine) > 12) return null;
  // Questions, MCQ stems ("4. Total distance ... is -") and sentences are not headings
  if (/[.?!,;\-–—=]$/.test(firstLine) || /\(\d\)|\?/.test(firstLine)) return null;
  // "2.1 Solar Radiation", "2.3.1 Declination:" — multi-level numbering is a strong heading signal
  if (/^\d+\.\d+(\.\d+)*\.?\s+\p{Lu}/u.test(firstLine)) return firstLine.replace(/:$/, '');
  // "1. Introduction", "IV. Results", "A. Methods" — single level only when short and Title Case
  const single = firstLine.match(/^(\d+\.|[IVX]+\.|[A-Z]\.)\s+(.+)$/);
  if (single && wordCount(single[2]) <= 6 && /^\p{Lu}/u.test(single[2]) && !/\d/.test(single[2])) return firstLine.replace(/:$/, '');
  if (/^(unit|chapter|section|module|part)\s+[\dIVX]/i.test(firstLine)) return firstLine.replace(/:$/, '');
  return null;
}

/** Paragraph blocks; falls back to lines when a page has no blank lines. */
function splitBlocks(pageText: string): string[] {
  const text = pageText.replace(/\r/g, '').trim();
  if (!text) return [];
  const paragraphs = text.split(/\n\s*\n/).map(b => b.trim()).filter(Boolean);
  if (paragraphs.length > 1 || !text.includes('\n')) return paragraphs;
  // One giant block with single line breaks: group lines, breaking before heading-like lines
  const blocks: string[] = [];
  let current: string[] = [];
  for (const line of text.split('\n').map(l => l.trim()).filter(Boolean)) {
    if (current.length && (headingOf(line) || /^([-*•]|\d+[.)])\s/.test(line))) {
      blocks.push(current.join('\n'));
      current = [];
    }
    current.push(line);
  }
  if (current.length) blocks.push(current.join('\n'));
  return blocks;
}

const splitSentences = (block: string) =>
  block.split(/(?<=[.?!])\s+(?=[A-Z0-9("'[$])/).map(s => s.trim()).filter(Boolean);

/** Splits an oversized block into sentence groups of at most MAX_WORDS. */
function splitLongBlock(block: string): string[] {
  const parts: string[] = [];
  let current = '';
  for (const sentence of splitSentences(block)) {
    if (current && wordCount(current) + wordCount(sentence) > MAX_WORDS) {
      parts.push(current);
      current = '';
    }
    // A single sentence longer than MAX_WORDS (e.g. a table): hard-split by words
    if (wordCount(sentence) > MAX_WORDS) {
      const w = sentence.split(/\s+/);
      for (let i = 0; i < w.length; i += MAX_WORDS) parts.push(w.slice(i, i + MAX_WORDS).join(' '));
      continue;
    }
    current = current ? `${current} ${sentence}` : sentence;
  }
  if (current) parts.push(current);
  return parts;
}

/** Last sentences of a chunk, up to OVERLAP_WORDS, to carry context into the next chunk. */
function tailOverlap(text: string): string {
  const sentences = splitSentences(text.replace(/\n+/g, ' '));
  const kept: string[] = [];
  let words = 0;
  for (let i = sentences.length - 1; i >= 0; i--) {
    const n = wordCount(sentences[i]);
    if (words + n > OVERLAP_WORDS) break;
    kept.unshift(sentences[i]);
    words += n;
  }
  return kept.join(' ');
}

/**
 * Removes running headers/footers: lines near the top or bottom of the page that repeat
 * (ignoring numbers, so "Page 3" == "Page 4") on at least 60% of pages. Only for ≥3 pages.
 */
export function removeRepeatedHeaders(pages: { text: string; pageNumber: number }[]) {
  if (pages.length < 3) return pages;
  const norm = (l: string) => l.toLowerCase().replace(/\d+/g, '#').replace(/\s+/g, ' ').trim();
  const edgeLines = (text: string) => {
    const lines = text.split('\n').map(l => l.trim()).filter(Boolean);
    return [...lines.slice(0, 3), ...lines.slice(-3)];
  };
  const counts = new Map<string, number>();
  for (const p of pages) new Set(edgeLines(p.text).map(norm)).forEach(l => counts.set(l, (counts.get(l) ?? 0) + 1));
  const repeated = new Set([...counts].filter(([l, n]) => l.length > 3 && n >= pages.length * 0.6).map(([l]) => l));
  if (repeated.size === 0) return pages;

  return pages.map(p => {
    const lines = p.text.split('\n');
    const edges = new Set(edgeLines(p.text));
    return { ...p, text: lines.filter(l => !(edges.has(l.trim()) && repeated.has(norm(l)))).join('\n') };
  });
}

export function chunkPages(inputPages: { text: string; pageNumber: number }[]): TextChunk[] {
  const pages = removeRepeatedHeaders(inputPages);
  const chunks: TextChunk[] = [];
  let chunkIndex = 0;
  let heading: string | null = null; // carries across pages: sections often span pages

  const hash = (s: string) => crypto.createHash('sha256').update(s).digest('hex');

  for (const page of pages) {
    const pieces = splitBlocks(page.text).flatMap(b => (wordCount(b) > MAX_WORDS ? splitLongBlock(b) : [b]));
    let body: string[] = [];   // new content for the next chunk
    let carry = '';            // overlap from the previous chunk on this page
    let bodyHeading = heading; // section the next chunk belongs to

    const flush = () => {
      const content = body.join('\n\n').trim();
      if (!content) return;
      body = [];
      if (content.length < MIN_CHUNK_CHARS) {
        const prev = chunks[chunks.length - 1];
        if (prev && prev.pageNumber === page.pageNumber) {
          // Too small to stand alone: keep it with the previous chunk on this page
          prev.text = `${prev.text}\n\n${content}`;
          prev.contentHash = hash(prev.text);
        } else {
          body = [content]; // keep it and prepend to whatever comes next on this page
        }
        return;
      }
      const joined = carry ? `${carry}\n\n${content}` : content;
      const prefix = bodyHeading && !joined.startsWith(bodyHeading) && !joined.includes(`# ${bodyHeading}`)
        ? `[Section: ${bodyHeading}]\n` : '';
      const text = prefix + joined;
      chunks.push({ text, pageNumber: page.pageNumber, chunkIndex: chunkIndex++, contentHash: hash(text) });
      carry = tailOverlap(content);
    };

    for (const piece of pieces) {
      const h = headingOf(piece);
      if (h) {
        // A new section starts a new chunk; no overlap is carried across sections
        flush();
        carry = '';
        heading = h;
        bodyHeading = h;
      } else if (body.length && wordCount(body.join(' ')) + wordCount(piece) > TARGET_WORDS) {
        flush();
        bodyHeading = heading;
      }
      body.push(piece);
    }
    flush(); // chunks never span pages (a leftover under MIN_CHUNK_CHARS, e.g. a page number, is dropped)
  }

  return chunks;
}
