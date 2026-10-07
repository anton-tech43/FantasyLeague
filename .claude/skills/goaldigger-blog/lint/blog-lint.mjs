#!/usr/bin/env node
// goaldigger-blog linter. Reports, never rewrites.
// usage: node blog-lint.mjs draft.md [--facts facts.txt]
// exit 1 on any ERROR. WARN is a prompt to reread, not a failure.
// ponytail: regex heuristics only. Ceiling: it cannot judge whether a joke lands or a
// claim is true. Upgrade path: none wanted; the human read is the real check.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const BANNED = JSON.parse(readFileSync(join(here, 'banned.json'), 'utf8'));
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const phraseRe = (p) => new RegExp(`(^|[^a-z'])${esc(p)}(?![a-z])`, 'i');

const median = (a) => { const s = [...a].sort((x, y) => x - y); return s.length ? s[Math.floor(s.length / 2)] : 0; };
const words = (s) => (s.match(/[A-Za-z0-9'’£-]+/g) || []);

export function lint(draft, facts = null) {
  const out = [];
  const add = (level, rule, detail) => out.push({ level, rule, detail });

  // strip front matter and code fences; keep the prose
  const body = draft.replace(/^---[\s\S]*?---\n/, '').replace(/```[\s\S]*?```/g, '');
  const paras = body.split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean);
  const prose = paras.filter((p) => !/^#{1,6}\s/.test(p));
  const text = prose.join('\n\n');
  const nWords = words(text).length || 1;
  const per1000 = (n) => (n / nWords) * 1000;

  // sentences (rough): split on . ? ! followed by space+capital/quote, or newlines
  const sentences = text.split(/(?<=[.!?])["')\]]*\s+(?=["'(\[A-Z0-9£])|\n+/).map((s) => s.trim()).filter((s) => words(s).length);
  const lens = sentences.map((s) => words(s).length);

  // 1. banned phrases
  for (const p of BANNED.tier1) if (phraseRe(p).test(text)) add('ERROR', 'banned-phrase', `"${p}"`);
  prose.forEach((para, i) => {
    const hits = BANNED.tier2.filter((p) => phraseRe(p).test(para));
    if (hits.length >= 2) add('WARN', 'tier2-cluster', `paragraph ${i + 1}: ${hits.join(', ')}`);
  });
  for (const s of sentences) {
    const low = s.toLowerCase();
    const o = BANNED.openers.find((x) => low.startsWith(x));
    if (o) add('WARN', 'stock-opener', `"${s.slice(0, 50)}"`);
  }

  // 2. brand mechanics that carry over to the blog
  if (/[—–]/.test(text)) add('ERROR', 'dash', 'em/en dash found; use a comma, full stop or brackets');
  const bangs = (text.match(/!/g) || []).length;
  if (per1000(bangs) > 3) add('WARN', 'exclamations', `${bangs} in ${nWords} words`);
  if (/\bsoccer\b|\bcleats?\b|\bcolor\b|\bfavorite\b|\bcenter\b|\bdefense\b|\boffense\b|\bmom\b|\bmetres?\b/i.test(text))
    add('ERROR', 'us-spelling', 'soccer/color/center/metres etc: British English, yards');
  if (/\bkick ?off\b|\bhalf ?time\b|\bfull ?time\b/i.test(text.replace(/kick-off|half-time|full-time/gi, '')))
    add('ERROR', 'hyphenate', 'kick-off, half-time, full-time');
  if (/(^|[\s(])we(['’]re|['’]ve|['’]ll)?\s/i.test(text.replace(/"[^"]*"|“[^”]*”|'[^']*'/g, '')))
    add('WARN', 'we', 'never fan "we" for the club; check it is you-and-the-reader only');
  if (/^\s*[-*]\s+\*\*[^*]+\*\*/m.test(body)) add('ERROR', 'bold-label-bullets', 'bold lead-in bullets');
  if (/^#{1,6}\s+(?:[A-Z][a-z]+\s+){2,}[A-Z]/m.test(body)) add('WARN', 'title-case-heading', 'use sentence case');

  // 3. syntactic tells
  const negPar = text.match(/\b(?:is|are|was|were|it['’]s|this|that)\s*(?:not|n['’]t)\s+(?:just|only|merely|about)\b[^.]{0,80}\b(?:but|it['’]s|it is)\b|\bnot (?:just|only|merely) [^.]{0,60}\bbut\b|\bmore than just\b|\b(?:this|that|it) doesn['’]t mean[^.]{0,60}\b(?:it means|it['’]s)\b/gi) || [];
  if (negPar.length) add(negPar.length > 1 ? 'ERROR' : 'WARN', 'not-x-but-y', `${negPar.length}: "${negPar[0].slice(0, 60)}"`);
  const partTail = text.match(/,\s*(?:highlighting|reflecting|ensuring|showcasing|underscoring|emphasi[sz]ing|symboli[sz]ing|demonstrating|illustrating)\b/gi) || [];
  if (partTail.length) add('ERROR', 'participle-tail', `${partTail.length}x ", ${partTail[0].slice(2)}…"`);
  const triads = text.match(/\b[\w'-]+(?: [\w'-]+)?,\s[\w'-]+(?: [\w'-]+)?,?\s(?:and|or)\s[\w'-]+/gi) || [];
  if (per1000(triads.length) > 4) add('WARN', 'rule-of-three', `${triads.length} "A, B and C" lists`);
  const rq = sentences.filter((s, i) => /\?$/.test(s) && sentences[i + 1] && words(sentences[i + 1]).length < 8 && !/"/.test(s)).length;
  if (rq > 1) add('WARN', 'question-then-answer', `${rq} rhetorical question + short answer pairs`);

  // 3b. tells that survived the first blind read (2026-10-02): the cadence, not the vocabulary
  for (const s of sentences) {
    if (words(s).length <= 8 && /^(?:that|this)(?:['’]s| is| was) (?:the|a|where|what|why|how|it)\b/i.test(s) && !/\d/.test(s))
      add('WARN', 'signpost', `"${s}" announces a point instead of making it`);
  }
  for (let i = 0; i + 1 < sentences.length; i++) {
    const a = words(sentences[i]), b = words(sentences[i + 1]);
    if (a.length <= 6 && b.length <= 6 && a[0] && a[0].toLowerCase() === b[0].toLowerCase() && a.length > 1)
      add('WARN', 'twin-fragments', `"${sentences[i]} ${sentences[i + 1]}" reads as an aphorism`);
  }
  const closer = text.match(/\b(?:whether you (?:ask|want|like)(?: it)? or not|which is the nice part|which is most of the job|say it and watch|watch (?:his|their) face|and that['’]s (?:okay|ok|fine|the point)|let that sink in)\b/gi) || [];
  if (closer.length) add('WARN', 'stock-closer', `"${closer[0]}"`);
  const fakePrecise = text.match(/\b(?:usually |often |typically )?(?:for |about |around )?(?:about |around )?(?:two|three|four|five|six|seven|eight|nine|ten|\d+) (?:minutes|seconds|hours|times a (?:day|week))\b/gi) || [];
  if (fakePrecise.length) add('WARN', 'fake-precision', `"${fakePrecise[0]}" is an invented number unless it is in the facts block`);
  if (/\bthe (?:first|last) thing\b|\bthe hardest (?:one|part)\b/i.test(text)) add('WARN', 'reassure-then-explain', 'check for "that\'s the first thing to know" padding');
  if ((text.match(/\(\s*(?:this is|nobody|yes,? really|trust me|true story)[^)]{0,60}\)/gi) || []).length > 1)
    add('WARN', 'wink-parentheses', 'more than one wink aside; real posts use brackets for a second thought, not a gag every time');
  const heLines = (text.match(/\bhe(?:['’]ll| will) (?!probably|possibly|likely|say he|tell you)\w+/gi) || []).length;
  if (heLines >= 4) add('WARN', 'generic-he', `${heLines} "he'll…" claims stated as fact; make them conditional ("if he…") or cut`);

  // number budget: a post that reads like a table in prose is hard to read (Anton, 2026-10-03)
  const numTokens = (text.match(/\b\d+(?:[-–:]\d+)?\b/g) || []).length;
  if (nWords >= 80 && (numTokens / nWords) * 100 > 3)
    add('WARN', 'number-heavy', `${numTokens} numbers in ${nWords} words; keep one or two that carry the story, turn the rest into words (second, fifth, every time lately)`);

  // 4. rhythm (calibrated on ~1,840 sentences of real UK first-person posts:
  //    median 16, p10 4, p90 33, ~14% <=5 words, ~14% >=30)
  if (lens.length >= 12) {
    const mean = lens.reduce((a, b) => a + b, 0) / lens.length;
    const sd = Math.sqrt(lens.reduce((a, b) => a + (b - mean) ** 2, 0) / lens.length);
    const cv = sd / mean;
    if (cv < 0.45) add('WARN', 'flat-rhythm', `sentence-length variation ${cv.toFixed(2)} (human posts ~0.6)`);
    const short = lens.filter((n) => n <= 5).length / lens.length;
    if (short < 0.06) add('WARN', 'no-fragments', `${(short * 100).toFixed(0)}% sentences are 5 words or fewer (human ~14%)`);
    if (mean > 24) add('WARN', 'long-sentences', `mean ${mean.toFixed(1)} words (casual human ~17)`);
    // 3 same opener in a row
    for (let i = 0; i + 2 < sentences.length; i++) {
      const f = (s) => (s.match(/[A-Za-z']+/) || [''])[0].toLowerCase();
      if (f(sentences[i]) && f(sentences[i]) === f(sentences[i + 1]) && f(sentences[i]) === f(sentences[i + 2]))
        add('WARN', 'repeated-opener', `3 sentences in a row start "${f(sentences[i])}"`);
    }
  }
  if (prose.length >= 5) {
    const pl = prose.map((p) => words(p).length);
    const m = median(pl);
    const near = pl.filter((n) => Math.abs(n - m) <= m * 0.2).length / pl.length;
    if (near > 0.6) add('WARN', 'uniform-paragraphs', `${(near * 100).toFixed(0)}% of paragraphs are within 20% of the median length`);
    const single = pl.filter((n) => n <= 20).length / pl.length;
    if (single < 0.15) add('WARN', 'no-short-paragraphs', 'real posts have many one-liners (~39% are 20 words or fewer)');
  }
  const last = prose[prose.length - 1] || '';
  if (/^(in conclusion|in summary|to sum up|overall|ultimately|so there you have it|whether you)/i.test(last))
    add('ERROR', 'recap-ending', 'end on the last real point, not a recap');
  if (/\b(download|get goaldigger|app store)\b/i.test(last) === false && !/goaldigger/i.test(text))
    add('WARN', 'no-app-link', 'no mention of the app; fine for an evergreen, but check the page type');

  // 5. fact gate: every number, score, year and capitalised name must exist in the facts block
  if (facts !== null) {
    const F = facts.toLowerCase();
    const nums = new Set((text.match(/\b\d+(?:[-–]\d+)?\b/g) || []));
    for (const n of nums) {
      if (F.includes(n.toLowerCase())) continue;
      if (/^(?:[1-9]|10|11)$/.test(n)) continue; // small counting words, rule numbers
      add('ERROR', 'unsourced-number', `${n} is not in the facts block`);
    }
    const caps = new Set();
    for (const s of sentences) {
      // capitalised word that is neither the sentence start nor the start of a quote
      for (const m of s.matchAll(/(?<=[\p{L}\d,;:)] )([A-Z][a-z]{2,}(?:['’][a-z]+)?)/gu)) {
        if (/['’](?:ll|re|ve|d|m)$/.test(m[1])) continue;
        caps.add(m[1].replace(/['’]s$/, ''));
      }
    }
    const common = new Set(['App','Store','Premier','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday','January','February','March','April','May','June','July','August','September','October','November','December','British','English','Premier','League','Strictly','Eurovision','Tesco','Greggs','Bake','Love','Island','Lidl','Sunday','Netflix','London','Mumsnet','GoalDigger','Apple','Google']);
    for (const c of caps) if (!common.has(c) && !F.includes(c.toLowerCase())) add('WARN', 'unsourced-name', `${c} is not in the facts block; verify before publishing`);
    if (/\[VERIFY\]/.test(draft)) add('ERROR', 'verify-marker', 'draft still contains [VERIFY]');
  } else {
    add('WARN', 'no-facts', 'no --facts given: names, scores and dates were NOT checked');
  }

  return { out, stats: { words: nWords, sentences: sentences.length, paragraphs: prose.length } };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const file = args.find((a) => !a.startsWith('--') && args[args.indexOf(a) - 1] !== '--facts');
  const fi = args.indexOf('--facts');
  if (!file) { console.error('usage: blog-lint.mjs draft.md [--facts facts.txt]'); process.exit(2); }
  const { out, stats } = lint(readFileSync(file, 'utf8'), fi >= 0 ? readFileSync(args[fi + 1], 'utf8') : null);
  for (const r of out) console.log(`${r.level.padEnd(5)} ${r.rule.padEnd(20)} ${r.detail}`);
  const errs = out.filter((r) => r.level === 'ERROR').length;
  console.log(`\n${stats.words} words, ${stats.sentences} sentences, ${stats.paragraphs} paragraphs. ${errs} error(s), ${out.length - errs} warning(s).`);
  process.exit(errs ? 1 : 0);
}
