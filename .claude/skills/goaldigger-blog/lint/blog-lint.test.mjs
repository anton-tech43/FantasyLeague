import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { lint } from './blog-lint.mjs';

const dir = join(dirname(fileURLToPath(import.meta.url)), 'fixtures');
const read = (f) => readFileSync(join(dir, f), 'utf8');
const facts = read('facts.txt');
const rules = (r) => new Set(r.out.map((x) => x.rule));
const errors = (r) => r.out.filter((x) => x.level === 'ERROR');

test('bad.md: the obvious AI draft fails on the big tells', () => {
  const r = lint(read('bad.md'), facts);
  const got = rules(r);
  for (const want of ['banned-phrase', 'not-x-but-y', 'participle-tail', 'bold-label-bullets', 'recap-ending'])
    assert.ok(got.has(want), `expected ${want}, got ${[...got].join(', ')}`);
  assert.ok(errors(r).length >= 5);
});

test('good.md: a human-shaped draft with sourced facts has no errors', () => {
  const r = lint(read('good.md'), facts);
  assert.deepEqual(errors(r), [], JSON.stringify(errors(r)));
});

test('cadence tells that humans spotted in the first blind read are caught', () => {
  const s = [
    "Here's the short version. Nobody trusts it. Nobody has to.",
    "That's the rule. The argument is everything else.",
    "They argue for about four minutes. Say it and watch his face.",
  ].join('\n\n');
  const got = rules(lint(s, ''));
  for (const want of ['twin-fragments', 'signpost', 'fake-precision', 'stock-closer'])
    assert.ok(got.has(want), `expected ${want}, got ${[...got].join(', ')}`);
});

test('fact gate: an invented score is an error', () => {
  const doctored = read('good.md').replace('16 to 2', '17 to 3');
  const r = lint(doctored, facts);
  assert.ok(rules(r).has('unsourced-number'));
});

test('no facts block: warns instead of silently passing', () => {
  assert.ok(rules(lint(read('good.md'))).has('no-facts'));
});
