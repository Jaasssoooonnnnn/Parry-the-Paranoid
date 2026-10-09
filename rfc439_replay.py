#!/usr/bin/env python3
"""Replays the DOCTOR's side of "PARRY Encounters the DOCTOR" (RFC 439,
18 September 1972) into the ported PARRY and compares PARRY's answers with
the ones printed in the RFC.

The DOCTOR's first and two other turns contained several sentences; PARRY only
accepts one sentence per input, so the sentence PARRY evidently answered is
fed instead (marked * below).
"""

import re
import sys

from parry import Parry

# (what the DOCTOR said, what PARRY answered in RFC 439)
RFC439 = [
    ("TELL ME YOUR PROBLEMS.*", "People get on my nerves sometimes."),
    ("I am not sure I understand you fully.", "You should pay more attention."),
    ("Suppose you should pay more attention.", "You're entitled to your own opinion."),
    ("What makes you think I am entitled to my own opinion?",
     "It bothers me just to be around people in general."),
    ("Please go on.", "I went to the track at Bay Meadows a while back."),
    ("What does that suggest to you?", "I went to the races."),
    ("What else would you like to discuss?", "Horseracing interests me."),
    ("Why do you say that just now?", "There's a lot of crooked gambling going on there."),
    ("I am not sure I understand you fully.", "It's clear to me if not to you."),
    ("Do you think its likely that not to I?", "I went to the races."),
    ("Please go on.", "I gamble on horses."),
    ("What does that suggest to you?", "I went to the races."),
    ("What else would you like to discuss?", "Gambling has been nothing but trouble to me."),
    ("Why do you say that just now?", "I've had experience with crooks gambling at the track."),
    ("I am not sure I understand you fully.", "I've already told you enough about that."),
    ("I enough about that?*", "I went to the races."),
    ("Please go on.", "Do you know anything about bookies?"),
    ("What makes you think I know anything about bookies?", "A bookie didn't pay me off once."),
    ("What does that suggest to you?",
     "I beat up the bookie who did not pay off, and I thought he might use his "
     "friends in the underworld to get even with me."),
    ("What else would you like to discuss?", "What do you know about racketeers?"),
    ("Why do you ask?", "What experience have you had gambling?"),
    ("Why does that question interest you?", "I like horseraces."),
    ("What else do you like?", "I know the mob controls the big rackets."),
    ("Who are you really talking about?", "Have you ever really thought about the MAFIA?"),
    ("Suppose you ever really thought about the MAFIA.", "Let's talk about something else."),
    ("I am not sure I understand you fully.",
     "You keep asking me the same things, why not change the topic?"),
    ("In what way?", "What do you mean?"),
    ("Why are such questions on your mind?", "I thought I told you, people get on my nerves."),
    ("Your nerves?", "Well, I don't know."),
    ("Don't you really know?", "I would say so."),
    ("Please go on.", "I would rather not discuss that anymore."),
    ("Would you like to discuss your nerves?", "I guess so."),
    ("What does that suggest to you?", "What are you getting at?"),
    ("What answer would please you most?", "It's not a matter or like or dislike."),
    ("What else would you like to discuss?",
     "I am getting tired of answering the same questions over and over."),
    ("What resemblance do you see?", "Why do you need to know that?"),
    ("What do you think?", "I don't understand your motives."),
    ("Why don't you understand my motives?", "Shouldn't I be?"),
    ("Why do you say that just now?", "That's just the way it is."),
    ("Suppose that's just the way it were not.", "So?"),
    ("I am not sure I understand you fully.", "You harp on the same questions too much."),
    ("What does that similarity suggest to you?", "I don't get you."),
    ("Do you wish that you did get I?",
     "It's about time you showed some interest in my feelings."),
    ("I showed some interest in your feelings?*", "I will help you if I trust you."),
    ("Do you wish that you trust I?", "Maybe yes, maybe no."),
    ("You don't seem quite certain.", "Really?"),
    ("Please go on.", "In my opinion you have a one-track mind."),
    ("What makes you think I have a one-track mind?", "I used to go to the track every week."),
    ("What does that suggest to you?", "I avoid racetracks now because the races are fixed."),
    ("Is that the real reason?", "I'd rather not discuss it."),
    ("What else would you like to discuss?", "That's something I don't want to go into."),
    ("Does that trouble you?", "I went to the races."),
    ("Why do you say that just now.", "It's none of your business."),
    ("Why are you concerned over my business?", "I don't confide in strangers."),
    ("Don't you really confide in strangers?", "Let's change the subject."),
    ("Perhaps that concerns your feelings.", "I went to the races."),
    ("I am not sure I understand you fully.",
     "What's wrong with you that you keep on bugging me about this?"),
    ("Who are you really talking about?", "The way you repeat yourself is getting ridiculous."),
    ("Suppose you repeat myself is getting ridiculous.",
     "There are some tricky operators down there."),
    ("Are there really some tricky operators down there?",
     "The guys involved in the horseracing racket."),
    ("Please go on.", "You are a real nag."),
    ("Does it please you to believe I am a real nag?", "I have had enough of this."),
]


def norm(s):
    s = re.sub(r'\([^)]*\)', ' ', s.upper())          # drop non-verbals
    s = s.replace("'", '')
    return re.sub(r'[^A-Z]+', ' ', s).split()


def replay(echo=False, **params):
    p = Parry(echo=False, suppress=True, **params)
    rows = []
    for doctor, rfc in RFC439:
        p.out.clear()
        p.hear(doctor.rstrip('*'))
        rows.append((doctor, rfc, ' / '.join(o.strip() for o in p.out)))
    return rows


def score(rows):
    return sum(norm(rfc) == norm(port) for _, rfc, port in rows)


def main():
    best = None
    for anger in ('LOW', 'MILD'):
        for fear in ('LOW', 'MILD'):
            for mistrust in ('MILD', 'HIGH'):
                params = dict(anger=anger, fear=fear, mistrust=mistrust)
                n = score(replay(**params))
                if not best or n > best[0]:
                    best = (n, params)
    n_weak = score(replay(weak=True))
    if n_weak > best[0]:
        best = (n_weak, dict(weak=True))
    n, params = best
    print('Best matching start-up parameters: %s' % params)
    print('Identical replies: %d of %d\n' % (n, len(RFC439)))
    for i, (doctor, rfc, port) in enumerate(replay(**params), 1):
        mark = '=' if norm(rfc) == norm(port) else 'x'
        print('%2d DOCTOR: %s' % (i, doctor))
        print('   %s RFC 439 PARRY: %s' % (mark, rfc))
        print('     ported PARRY:  %s' % port)
    return 0


if __name__ == '__main__':
    sys.exit(main())
