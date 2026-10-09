# PARRY (1972) in Python

PARRY is Kenneth Colby's simulation of a paranoid patient, written at the Stanford AI Lab. This is a port of the version that talked to ELIZA over the ARPANET on 18 September 1972 (RFC 439). Every function in the original MLISP has a Python counterpart with the same name, and the replies come from the original LISP data file, read at startup.

## Running it

```bash
python3 parry.py
```

It asks the same setup questions the original did. For the PARRY in RFC 439, answer N, STRONG, MILD, LOW, HIGH, then N to everything else. Say Y to TRACE VARIABLES if you want to watch fear, anger and mistrust change.

Type one sentence at a time and end it with a period or a question mark. Spell out numbers. `S.` means you say nothing, and `BYE.` ends the interview.

To replay the DOCTOR's side of RFC 439:

```bash
python3 rfc439_replay.py
```

## Files

- `parry.py`: the port
- `RDATA`: the original data file, with every reply, topic and keyword
- `PARRYR.MLI`: the original MLISP source, for comparison
- `rfc439_replay.py`: feeds ELIZA's lines from RFC 439 to the port and compares the answers

## Sources

Both originals come from SAILDART, the archive of the Stanford AI Lab disk, read through the Internet Archive:

- `PARRYR[4,KMC]`, dated 25 October 1972 (KMC is Colby's account)
- `RDATA[4,KMC]`, dated 24 August 1972

The PARRY in the CMU AI Repository is the later PARRY II (1974–76). Its reply file, PDAT, is missing from that package and the SAILDART copy isn't public, so that version can't be rebuilt as it was.

## How close is it?

PARRY never picks at random, so old transcripts make a good test. 55 of the 62 replies in RFC 439 come out word for word. Four of the others differ only in wording (ALOT for "a lot" and the like), probably because the data changed between August and September or because the RFC was retyped by hand. Two pick a different reply, likely for the same reason. The last one answers an ELIZA turn of two sentences, which PARRY couldn't have taken as it was typed.

Colby's group also kept logs of their own sessions. Replaying 24 of them from November and December 1972, 553 of 579 replies match.

## Differences from the original

- Input ends with Return instead of two ALTMODEs.
- Lower case is folded to upper case.
- The two-teletype mode, where PARRY and the interviewer's program sent each other messages, isn't there.
- End of file counts as `BYE.`

Everything else, quirks included, works as it did in the original. One thing is a guess: the original tests input characters with NUMBERP, but LISP 1.6's READCH returns digits as symbols, so here digits are illegal and a sentence containing one gets BAD INPUT. That fits the original's instruction to spell out numbers, but I couldn't check it on a real machine.
