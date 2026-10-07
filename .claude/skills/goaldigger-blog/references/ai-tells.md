# AI tells: what to avoid and why

Built 2026-10-02 from: the Wikipedia field guide "Signs of AI writing", Kobak et al. (2024, excess style words in 150k+ PubMed abstracts), a 2024 study of overused focal words, Google's guidance on AI content, and a read of seven public humaniser skills. The word list is `lint/banned.json`. This file is the reasoning. If they disagree, fix both.

## Read this first: what the evidence actually supports

| Claim | Strength | So |
|---|---|---|
| Certain words are wildly overused by LLMs (delve, showcasing, underscores, intricate, pivotal, tapestry) | **Solid.** Measured at 9x to 25x in 2024 abstracts. | Ban them. |
| Word habits drift with each model release | **Solid.** Wikipedia dates them: 2023 to mid-2024 gave *delve, boasts, testament*; mid-2024 to mid-2025 gave *fostering, highlighting, showcasing*. | A word list ages. **Structure outlasts vocabulary**, so lean on the structural rules below. |
| "Not X but Y", rule of three, participle tails, tidy summaries | **Consistent** across Wikipedia and every humaniser skill. No published frequency study. | Treat as strong, not proven. |
| Em dashes mean AI | **Weak and model-specific.** Humans use them (about 3 per 1,000 words in published essays). Some models overused them, then were tuned down. | We ban them anyway: brand rule, and the UK women we sampled don't use them as rhythm. Not because they prove anything. |
| AI detectors work | **No.** Biased against non-native writers, collapse under paraphrase, humans are near 50% too. | Never optimise for a detector score. |
| Google punishes AI text | **No.** Google punishes *scaled content abuse*: many pages with no added value, however made. | One post with original information and checked facts is the defence. Volume and templates are the risk. |

**Honest limit.** No checklist guarantees a post will never be flagged. This file removes known tells and forces real specifics. The specifics are the defence.

## The trap in "humanising"

Several skills tell the model to "add personality". The best-evidenced one (avoid-ai-writing) documents that this creates its own tells: staged candour, fake fragments, forced rhythm. So:

- **Do not inject voice.** Supply facts, names, numbers and one real small scene, and let the voice come from those.
- Do not add a fragment "for rhythm" unless a short sentence is genuinely the right length for that thought.
- A rule that over-corrects is also a tell. Skipped on purpose from third-party skills: "no adverbs", "no passive voice", "no Wh- sentence openers", "no three-item lists ever", "remove all dashes and every contrast". Real writers use all of these. We cap and check; we don't ban the whole device.

## 1. Lexical

| Tell | Why it reads machine | Do instead |
|---|---|---|
| delve, tapestry, realm, beacon, testament, pivotal, paramount, robust, seamless, meticulous, intricate, vibrant, bustling, nestled, renowned, groundbreaking, cutting-edge, world-class | The model reaches for the word that suits the widest audience | The plain word, or the fact |
| elevate, empower, streamline, facilitate, leverage, utilise, harness, unlock, foster, bolster, spearhead, embark, navigate (abstractly) | Business-brochure verbs for ordinary actions | "use", "help", "start", "get" |
| moreover, furthermore, additionally, notably, importantly, interestingly | Connective padding on every paragraph | Cut. Paragraphs just start (real posts do this) |
| it's worth noting, in today's…, when it comes to, at the end of the day, in terms of, in order to | Throat-clearing before the point | Delete, start at the point |
| showcase, underscore, highlight (as verb), reflect, symbolise, contribute to | Fake analysis stapled onto a plain fact | State the fact |
| stands as, serves as, boasts, features, represents | Longer verb replacing "is" or "has" | is, has |
| game-changer, hidden gem, must-visit, rich heritage, the beautiful game, football fever | Brochure and sports-marketing register | Say what the thing is |
| Hollow intensifiers: truly, deeply, quietly, fundamentally, inherently | Emphasis with no content | Cut. Keep a real contrast only |
| Gamification words: level up, unlock, awesome, amazing, streak, badge | The brand's reader is a friend on a sofa, not a player | Don't |

**Not banned, because real UK women in the sample use them:** honestly, actually, obviously, genuinely, literally, a bit, quite, rather, apparently, proper, mad, gutted, lovely. Usage counts from 50 posts: *actually* 18, *a bit* 15, *quite* 13, *rather* 13, *kind of* 11. Banning these would push the text away from how people write.

## 2. Syntactic

| Tell | Why | Do instead |
|---|---|---|
| **Negative parallelism**: "not just X but Y", "it's not X, it's Y", "this isn't about X", "more than just", "this doesn't mean X, it means Y" | Rejects a claim nobody made so the second half sounds bigger. The strongest structural tell in every source | State Y. Lint: 1 is a warning, 2 is an error |
| **Rule of three**: "A, B and C" adjectives, clauses or sections | Triads used for completeness, not because there are three things | Use the real number of items. Two, or one developed. Lint warns above 4 per 1,000 words |
| **Participle tails**: ", highlighting…", ", ensuring…", ", reflecting…", ", demonstrating…" | Fake significance tacked onto a fact | Cut it or say the real consequence. Lint error |
| **Rhetorical question, then answer**: "The result?", "Why does this matter?", "The catch?" | Manufactured suspense | Say the answer |
| **Colon reveal**: "The best part: it learns." | Fake drama | A plain sentence |
| **Fragment drumrolls**: "No fluff. No filler. Just results." | Staccato profundity | One sentence |
| **Staged candour**: "Honestly?", "Look,", "Here's the thing", "Let's be real", "Don't get me wrong" | Advertises honesty instead of being honest | Say the thing |
| **Reader-steering**: "Here's what's interesting", "This is the part most people miss" | Tells the reader what to feel | Let the fact carry it |
| **False agency**: "the data tells us", "the culture shifts" | A thing acts in place of a person | Name who did it |
| **Fake ranges**: "from X to Y" with nothing between them | False breadth | List the real items |
| **Stacked hedges**: "could potentially", "might arguably" | Each hedge cancels the last | One qualifier, only where doubt is real |
| **Same-subject runs**: three sentences opening with the same word | Template rhythm | Merge or reorder |

**Hedging is not a tell by itself.** Real posts hedge constantly but lightly (3 to 10 hedge words per 1,500 words), and they hedge *knowledge* ("I'm told", "from what I can gather", "apparently"), not opinions. The machine hedges everything evenly. Hedge what she doesn't know. State what she feels flatly.

## 2b. Cadence tells (found by our own blind read, 2026-10-02)

These survived every word-list check. Two independent readers (a 28-year-old UK woman, a sceptical editor) both flagged them in drafts that had zero banned words. The controls written without this skill were called AI with confidence 5/5; the drafts written with it were called "unsure", and what gave them away was this list. **This is where the real gap is.**

| Tell | Example shape | Why it reads machine | Do instead |
|---|---|---|---|
| **Aphorism pair**: two short parallel sentences | "Nobody trusts it. Nobody has to." / "That's the rule. The argument is everything else." | Staged wisdom, rhythm by recipe | One sentence that says the thing, or drop the second |
| **Signpost sentence** | "That last bit is the story." "That's the rule." | Announces a point instead of making it | Make the point |
| **Stock closer** | "…whether you ask or not." "Say it and watch his face." "…which is the nice part." | A tidy button on every ending | End on the last concrete thing, even if it is flat |
| **Fake precision** | "usually for about four minutes", "within about ten seconds" | An invented number dressed as observation | Cut it, or use a number from the facts block |
| **Generic "he" stated as fact** | "He'll bring that up himself." "If he goes quiet around Friday…" | Asserts behaviour nobody observed | Make it conditional ("if he brings it up") or cut |
| **Reassure-then-explain** | "Nothing's wrong. That's the first thing to know…" | Chatbot empathy shape | State it once, move on |
| **Wink aside** | "(This is a real rule. Nobody wrote it down.)" | A gag-in-brackets used as a tic | One per post at most, and only if it's actually funny |
| **Template slots in prose** | "Ask him: … Say this: …" as labelled blocks | Reads as a product formula | Fold into a sentence or two |
| **Data dump with jokes sprinkled** | Stats paragraph, then a quip, then stats | The jokes are not about the data | Weave the numbers into the thing they mean |
| **Padding lines** | "You'll see both on the touchline looking worried." | Stock filler to fill a slot | If the slot has no fact, delete the slot |
| **Garbled simplification** | "Is a toe offside? Yes, if it's the head, body or feet that count." | A fact flattened until it contradicts itself | Re-read each factual sentence as a stranger. Does it say what is true? |
| **Ambiguous shorthand** | "Arsenal away" when the match is *at* Arsenal | True in football-speak, confusing to a newcomer | Say "going to the Emirates" |

What the top-ranked drafts had instead: a **specific, slightly mean observation about a plain situation** (the tea, the salt shaker, a man shouting at someone who can't hear him), and a willingness to end a paragraph on a short flat line **without a punchline**.

## 3. Structural

| Tell | Why | Do instead |
|---|---|---|
| **Announcing intro**: "In this article we will…", "Let's dive in", "Imagine a world where…" | Meta-narration | Open on one concrete incident or fact, in a plain sentence |
| **Mic-drop paragraph endings**: "That's the real win." "Let that sink in." | Closers that add nothing | End on the last concrete fact |
| **Recap ending**: "In conclusion", "Ultimately", "Overall", "The future looks bright" | The reader was just there | Stop at the last point. A small deflating joke is fine. Lint error |
| **Uniform paragraph size**; point-detail-background shape in every section | Both readers and detectors see the mould | Let paragraphs follow the thought. Real posts: median 29 words, ~39% of paragraphs are 20 words or fewer |
| Heading that restates the intro, then a sentence restating the heading | Scaffolding | Delete the warm-up line |
| Stock sections: "Key takeaways", "Overview", "Challenges and future outlook" | Template sections | Name the real content or drop |
| A bolted-on FAQ | A common SEO-slop shape (no source rules on it either way) | Only if people really ask those questions |
| Sections that could be shuffled without anyone noticing | No through-line | Make each depend on the last |

## 4. Tonal

| Tell | Why | Do instead |
|---|---|---|
| Uniform positivity and fake balance: "While X is impressive, Y remains a challenge" | Sounds balanced without weighing anything | Take a side. Hers |
| Chatbot residue: "Great question!", "I hope this helps", "Certainly!" | Leftover from chat | Remove |
| No opinion, no uncertainty, no mixed feelings | Over-polished neutrality | Keep real opinions. Do not invent them |
| Sycophancy and cheerleading ("you've got this") | Brand rule: never sycophantic | Dry, on her side |
| Sustained exclamation marks, enthusiasm runs | Real posts: about 2 per 1,000 words, mostly in dialogue | Lint warns above 3 per 1,000 |

## 5. Content (the ones that actually sink a post)

| Tell | Why | Do instead |
|---|---|---|
| **Portable sentences.** Replace the club name; the sentence still works | No specifics. The core "scaled content" signal | Names, numbers, dates, a mechanism. See the swap test in SKILL.md |
| Vague attribution: "experts say", "studies show", "many argue" | Authority with no source | Name the source or cut the claim |
| Significance inflation: "marks a pivotal moment", "plays a vital role" | Ordinary facts dressed as history | State the fact |
| Invented foils: "everyone else was still debating…" | The crowd is made up | Cut |
| **Invented or stale facts**, fake quotes, "as of my last update" | Hallucination and cutoff leakage | Facts only from the supplied data block. See fact gate |
| **A true sentence about the wrong person** | Documented failure in this project (DATA_SOURCES.md) | Check names against the block |
| Present-tense superlatives that rot: only, last, most, record, still, never | Go stale; we have been burned | Write the dated fact instead |
| Prestige name-dropping; stacked analogies | Borrowed credibility | One relevant parallel |
| Emotional arcs that are too tidy: problem, struggle, lesson, uplift | Template | Leave loose ends |

## 6. Formatting

Bold lead-in bullets ("**Passion:** …"), Title Case Headings, emoji headings or bullets, arrows as decoration, a rule between every section, bullets where two sentences would do, a heading over a two-sentence section, "5 things to know" padding. Use sentence case, prose, and bullets only when the content is genuinely a list. Casual posts almost never use five-bullet lists, unless the list *is* the joke and every item is a fragment.

## 7. SEO slop (the Google angle)

Keyword stuffing, thin listicles, boilerplate intros, the same template stamped across many pages, recycled "best practices". This is what the scaled-content-abuse policy describes. The defence: one real angle per post, original information (our head-to-head figure, a line she can actually say), checked facts, a published-and-updated date, and a pace that a small team could plausibly keep.

## Sources

- Wikipedia: Signs of AI writing: https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing
- Kobak et al., excess vocabulary in 2024 abstracts: https://arxiv.org/abs/2406.07016 (word lists: https://github.com/berenslab/llm-excess-vocab)
- Focal-word study (delve +1,375%): https://arxiv.org/html/2412.11385v1
- Google on AI content: https://developers.google.com/search/docs/fundamentals/using-gen-ai-content
- Em dash rates: https://arxiv.org/html/2603.27006v1 and https://www.seangoedecke.com/em-dashes/
- Skills read (not installed): blader/humanizer, hardikpandya/stop-slop, petergyang/no-ai-slop, conorbronsdon/avoid-ai-writing (the most evidence-aware; its edit mode runs local node scripts, so do not install without reading them), theclaymethod/unslop, zc277584121 remove-ai-style. Not used: the proseify skill, which is for fiction and needs a paid third-party server that would receive the manuscript.
