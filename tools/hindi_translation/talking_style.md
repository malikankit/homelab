# Critique: multi-question prompts, and "lost in the middle"

Written 2026-09-03. A critique given in response to being asked to
critique a dense, multi-part prompt (7 distinct asks bundled into one
message: a data-handling question, a hook design ask, an intent
statement, a transliteration confirmation, a "how does the model
listen" technical question, a glossary request, and a model-download
pointer).

## What worked

Bundling related sub-topics into one turn is efficient — it beat sending
7 separate messages, and having everything together allowed prioritizing/
ordering the answer sensibly (e.g. grouping the two model-architecture
questions together). All seven asks got addressed in that case.

## What was riskier than it needed to be

- One dense paragraph, no numbering or line breaks between asks. A
  yes/no confirmation request ("confirm your understanding of which
  option I want") was buried mid-sentence rather than standing alone —
  exactly the kind of sub-ask that's easy to under-attend to in a wall of
  text, since it's a different *kind* of ask (a confirmation) than the
  others (open technical questions, a reference request).
- Several different response *modes* were mixed together: introspective/
  honest ("did you read this"), a design proposal ("gate reads with a
  hook"), a decision confirmation, a conceptual explanation, and a
  reference list. Each benefits from being answered differently — mixing
  them raises the chance one gets a shallower answer than it deserves, or
  gets folded into the wrong register.
- A couple of typos (`trans*tion`, `diatrsation`) forced inference of
  intent rather than reading it directly — worked out fine that time, but
  unnecessary risk.

## "Lost in the middle" — two different phenomena, often conflated

1. **Long-context retrieval degradation** (the actual "lost in the
   middle" research finding) is about a model failing to recall a fact
   buried in the *middle of a long document or transcript* — thousands
   of tokens away, surrounded by unrelated content. At ~153k/1M tokens
   (15%) of context used in that session, nowhere close to where that
   effect would meaningfully bite. Not why a single dense message risks
   dropped sub-asks.
2. **Under-attending to a sub-request in a single unstructured message**
   is a different, more mundane effect: about salience and
   instruction-parsing *within one turn*, not context-window length.
   Numbered/bulleted asks give an explicit anchor per item, which
   measurably improves the odds every item gets addressed — especially
   as effort/model quality varies, or as the message grows longer.

## Practical takeaway

Numbering distinct asks (even just "1) ... 2) ... 3) ...") costs nothing
and removes the main risk here — not because of context-length limits,
but because it turns "did the model happen to notice this" into "the
model has an explicit checklist to work through." Especially worth doing
when mixing meta-questions about Claude's own behavior with concrete
technical decisions, since those genuinely need different tones of
answer.
