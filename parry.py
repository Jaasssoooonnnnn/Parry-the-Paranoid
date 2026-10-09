#!/usr/bin/env python3
"""PARRY (Kenneth Colby, Stanford AI Lab) -- Python port of the 1972 program.

Ported from the original MLISP source PARRYR[4,KMC] (filedate 1972-10-25) and
its data file RDATA[4,KMC] (filedate 1972-08-24), both preserved in the
SAILDART archive of the Stanford AI Lab disk.  This is the version that talked
to ELIZA ("the DOCTOR") over the ARPANET on 18 September 1972 (RFC 439).

The data file RDATA is read at start-up exactly as the original did: it is a
file of LISP forms, evaluated by a tiny LISP interpreter below.  Every function
of PARRYR is translated one-for-one and keeps its original name; the original
MLISP is in PARRYR.MLI next to this file.

Deviations from the 1972 program (all at the terminal-I/O level):
  * a line ends with RETURN instead of two ALTMODEs;
  * lower-case input is folded to upper case (1972 terminals had no lower case);
  * the two-teletype "TALK" mode (inter-job mail between PARRY and the
    interviewer's DOCJOB) is not supported;
  * end-of-file on input is treated like "BYE.".
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


# ---------------------------------------------------------------------------
#  A minimal LISP 1.6 reader/evaluator, just enough to load RDATA.
#  NIL is the empty Python list; T is the symbol 'T'.
# ---------------------------------------------------------------------------

NIL = []


def is_atom(x):
    return not isinstance(x, list) or x == []


class Lisp:
    def __init__(self):
        self.props = {}      # (atom, indicator) -> value
        self.globals = {}

    # property lists ---------------------------------------------------------
    def get(self, atom, ind):
        if isinstance(atom, list) or atom is None or isinstance(ind, list):
            return NIL
        return self.props.get((atom, ind), NIL)

    def putprop(self, atom, val, ind):
        self.props[(atom, ind)] = val
        return val

    # reader -----------------------------------------------------------------
    @staticmethod
    def tokens(text):
        """'~' starts a comment, '/' quotes the next character, '@' is QUOTE,
        and blanks, tabs, newlines, form feeds and commas separate atoms."""
        i, n = 0, len(text)
        while i < n:
            c = text[i]
            if c == '~':
                while i < n and text[i] != '\n':
                    i += 1
            elif c in ' \t\r\n\f,':
                i += 1
            elif c in '()@':
                yield c
                i += 1
            else:
                atom = []
                while i < n and text[i] not in ' \t\r\n\f,()@~':
                    if text[i] == '/' and i + 1 < n:
                        i += 1
                    atom.append(text[i])
                    i += 1
                s = ''.join(atom)
                yield int(s) if s.isdigit() else s

    def read_all(self, text):
        toks = list(self.tokens(text))
        pos = 0

        def read():
            nonlocal pos
            t = toks[pos]
            pos += 1
            if t == '(':
                lst = []
                while toks[pos] != ')':
                    lst.append(read())
                pos += 1
                return lst
            if t == '@':
                return ['QUOTE', read()]
            if t == 'NIL':
                return NIL
            return t

        forms = []
        while pos < len(toks):
            forms.append(read())
        return forms

    # evaluator --------------------------------------------------------------
    def eval(self, x, env=None):
        env = env if env is not None else {}
        if isinstance(x, int):
            return x
        if isinstance(x, str):
            if x == 'T':
                return 'T'
            if x in env:
                return env[x]
            return self.globals[x]
        if x == []:
            return NIL
        op, args = x[0], x[1:]
        if op == 'QUOTE':
            return args[0]
        if op == 'SETQ':
            v = self.eval(args[1], env)
            (env if args[0] in env else self.globals)[args[0]] = v
            return v
        if op == 'DEFPROP':
            return self.putprop(args[0], args[1], args[2])
        if op in ('FUNCTION', 'LAMBDA'):
            lam = args[0] if op == 'FUNCTION' else x
            return ('CLOSURE', lam[1], lam[2:], env)
        if op == 'PROG':
            local = dict(env)
            for v in args[0]:
                local[v] = NIL
            for f in args[1:]:
                self.eval(f, local)
            return NIL
        if op == 'PROG2':
            self.eval(args[0], env)
            return self.eval(args[1], env)
        vals = [self.eval(a, env) for a in args]
        if op == 'MAPCAR':
            return [self.apply(vals[0], [e]) for e in vals[1]]
        if op == 'PUTPROP':
            return self.putprop(vals[0], vals[1], vals[2])
        if op == 'GET':
            return self.get(vals[0], vals[1])
        if op == 'CONS':
            return [vals[0]] + vals[1]
        if op == 'APPEND':
            out = []
            for v in vals:
                out = out + v
            return out
        if op == 'EVAL':
            return self.eval(vals[0], env)
        if op[0] == 'C' and op[-1] == 'R' and set(op[1:-1]) <= set('AD'):
            v = vals[0]
            for c in reversed(op[1:-1]):
                v = (v[0] if v else NIL) if c == 'A' else v[1:]
            return v
        raise ValueError('RDATA: unknown function ' + op)

    def apply(self, fn, args):
        _, params, body, env = fn
        local = dict(env)
        local.update(zip(params, args))
        val = NIL
        for f in body:
            val = self.eval(f, local)
        return val

    def load(self, path):
        with open(path, encoding='utf-8') as f:
            text = f.read()
        # The rest of RDATA is PDP-10 assembly (LAP) for the inter-job mail
        # used by the two-teletype mode; it is not LISP data.
        text = text.split('(SETQ IBASE 8.)')[0]
        for form in self.read_all(text):
            self.eval(form)


# ---------------------------------------------------------------------------
#  Helpers for MLISP built-ins
# ---------------------------------------------------------------------------

def suflist(l, n):
    return (l or NIL)[max(n, 0):]


def car(l):
    return l[0] if l else NIL


def cadr(l):
    return l[1] if l and len(l) > 1 else NIL


def nth(l, n):                     # MLISP L[N], 1-origin
    return l[n - 1] if l and len(l) >= n else NIL


def last(l):
    return l[-1] if l else NIL


def lisp_str(x):
    if isinstance(x, list):
        return '(' + ' '.join(lisp_str(e) for e in x) + ')' if x else 'NIL'
    if isinstance(x, float):
        s = '%.8g' % x
        return s if ('.' in s or 'E' in s.upper()) else s + '.0'
    return str(x)


def stringate(l):
    return ''.join(lisp_str(wd) + ' ' for wd in (l or NIL))


def delete(wd, l):
    """DELETE removes the first element EQ to WD."""
    for i, e in enumerate(l or NIL):
        if e is wd or (not isinstance(e, list) and e == wd):
            return l[:i] + l[i + 1:]
    return l or NIL


def member1(wlist, inp):
    """Returns the first atom or group of words in WLIST present in INP."""
    for group in wlist or NIL:
        if is_atom(group):
            found = group != [] and group in inp
        else:
            found = all(x in inp for x in group)
        if found:
            return group
    return NIL


BLANK, CR, LF, COMMA, DASH, PERIOD = ' ', '\r', '\n', ',', '-', '.'


# ---------------------------------------------------------------------------
#  PARRY
# ---------------------------------------------------------------------------

class Parry:
    def __init__(self, suppress=False, weak=False, anger='MILD', fear='MILD',
                 mistrust='HIGH', tracev=False, save_file=None, echo=True,
                 rdata=os.path.join(HERE, 'RDATA')):
        self.L = Lisp()
        self.L.load(rdata)
        self.echo = echo
        self.out = []                    # everything SAY has said
        self.talk = False
        self.save_file = save_file

        # INITIALIZE
        get = self.get
        self.nlist = get('NEGS', 'IND')
        self.sacts = get('SACTS', 'IND')
        self.delno = 0
        self.flare = 'INIT'
        self.liveflares = get('FLARELIST', 'SETS')
        self.deadflares = NIL
        self.sensitivelist = get('SENSITIVELIST', 'SETS')
        self.delnlist = get('DELWDS', 'NOUNS')
        self.delvlist = get('DELWDS', 'VERBS')
        self.delalist = get('DELWDS', 'AMBIG')
        self.dlim = 6
        self.lasttop = self.qword = 'INTROTOP'
        self.suppress = suppress
        self.weak = weak
        if weak:
            self.anger = self.anger0 = self.fear = self.fear0 = 0
            self.mistrust = self.mistrust0 = 0
        else:
            self.anger = self.anger0 = 0 if anger == 'LOW' else 10
            self.fear = self.fear0 = 0 if fear == 'LOW' else 10
            self.mistrust = self.mistrust0 = 0 if mistrust == 'MILD' else 15
        self.tracev = tracev

        self.delflag = self.delend = self.skep = NIL
        self.laststmt = NIL
        self.ajump = self.fjump = None
        self.weight = 0
        self.flag = NIL
        self.tval = True
        self.interpers = NIL
        self.concept = NIL
        self.ende = False
        self.termin = self.restsent = self.remark = NIL

    def get(self, atom, ind):
        return self.L.get(atom, ind)

    def putprop(self, atom, val, ind):
        return self.L.putprop(atom, val, ind)

    # --- MAIN FUNCTIONS ------------------------------------------------------

    # ANGERMODE   PROVIDES RESPONSES FOR HIGH ANGER LEVEL
    def angermode(self):
        self.terpri()
        if self.anger > 17.5:
            return self.say(self.choose('ANGER'))
        return self.say(self.choose('HOSTILEREPLIES'))

    # CHECKFLARE  SCANS THE INPUT SENTENCE FOR THE FLARE WORD WHICH HAS THE
    #             HIGHEST WEIGHT
    def checkflare(self, inp, flarelist):
        nflare, result, wt = 'INIT', NIL, NIL
        for word in inp or NIL:
            fset = self.get(word, 'SET')
            if fset and fset in flarelist:
                wt = self.get(fset, 'WT')
                if wt > self.get(self.get(nflare, 'SET'), 'WT'):
                    nflare, result = word, True
        if result:
            # IF FLARE ALREADY BEING DISCUSSED, DISREGARD ANY VERY WEAK NEW FLARE
            if self.flare != 'INIT' and \
                    not (wt := self.get(self.get(nflare, 'SET'), 'WT')) > 1:
                result = NIL
            else:
                self.flare = nflare
                self.weight = wt
        return result

    # DELREF   SCANS THE INPUT SENTENCE FOR THE FIRST DIRECT REFERENCE TO 'SELF'S
    #          DELUSIONAL COMPLEX AND RETURNS A FEARFUL REACTION
    def delref(self, inp):
        found = self.delcheck(inp)
        if found:
            if self.delflag:
                self.fjump = 0.4 if self.get(car(found), 'STRONG') else 0.2
            else:
                self.fjump = 0.5
                self.delnlist = delete('MAFIA', self.delnlist)
                self.flmod('MAFIASET')
            if not self.delend:
                self.delflag = True
            self.flare = 'INIT'
            self.say(self.delstmt())
            self.lasttop = self.qword = 'INTROTOP'
        elif 'MAFIA' in inp:
            if self.delend:
                found = self.choose('MAFIASET')
            else:
                found = self.delstmt()
            self.say(found)
        return found

    # DELSTMT  CAUSES THE "NEXT" DELUSION TO BE EXPRESSED
    def delstmt(self):
        if self.weak:
            return self.flstmt('RACKETSET')
        self.delno = 1 if self.delno == self.dlim else self.delno + 1
        if self.fear > 12 or self.anger > 12 or \
                self.fear + self.anger + self.mistrust > 20:
            self.delflag = NIL
            return self.choose('CHANGESUBJ')
        self.delflag = True
        self.flare = 'INIT'
        stmt = self.choosedel(self.delno)
        self.delcheck(stmt)
        self.laststmt = 'DEL' + str(self.delno)
        return stmt

    # DELTALK  PRODUCES RESPONSE OF 'SELF IN CONTEXT OF EXPRESSION OF DELUSIONS
    def deltalk(self, stmt):
        if not self.skep:
            if member1(self.get('DISBELIEF', 'IND'), stmt):
                self.ajump = 0.3
                self.fjump = 0.1
                self.say(self.choose('BELIEVEREPLIES'))
                self.skep = True
            else:
                return self.specques(stmt) or self.say(self.answer(stmt))
        else:
            if self.yes(stmt):
                self.say(self.delstmt())
            else:
                self.say(self.distrust())
            self.skep = NIL

    # FEARMODE  PROVIDES FEARFUL REACTIONS TO STATEMENTS OF 'OTHER
    def fearmode(self):
        self.terpri()
        if self.fear > 18.4:
            return self.say([['EXITS']])
        return self.qthreat(self.remark) or self.say(self.choose('AFRAID'))

    # FLAREREF  HANDLES FLARE REFERENCES
    def flareref(self, inp):
        if self.checkflare(inp, self.liveflares):
            self.flrecord(self.get(self.flare, 'SET'))
        if self.checkflare(inp, self.deadflares):
            fset = self.get(self.flare, 'SET')
            self.say(self.fltalk(fset, ['Q', fset] + inp))
            return True
        return NIL

    def fltalk(self, flset, inp):
        if self.fear > 14 or self.anger > 14:
            self.flare = 'INIT'
            return self.choose('CHANGESUBJ')
        return self.answer(inp)

    # IYOUME  HANDLES INTERPERSONAL ATTITUDE STATEMENTS
    def iyoume(self, inp):
        get = self.get
        s, sact, attitude, aword = NIL, NIL, NIL, NIL
        nwords, count, reply = 0, NIL, NIL
        self.tval = True
        # COLLECT RELEVANT ITEMS IN INPUT
        for wd in inp:
            if wd in ('YOU', 'I', 'ME'):
                s = [wd] + s
                if attitude:
                    count = NIL
            elif wd in self.nlist:
                self.tval = not self.tval
            elif wd in self.sacts and not sact:
                sact = [wd] + s
                s = suflist(s, 2)
            elif not attitude and (attitude := get(wd, 'ATTIT')):
                aword = wd
                s = [wd] + s
                nwords = 0
                count = True
            elif count:
                nwords += 1
            if len(s) == 3:
                break
        # TRANSFORM E.G. (I BELIEVE) (YOU) INTO (I BELIEVE YOU)
        if sact and len(s) < 2:
            if not attitude and (attitude := get(aword := car(sact), 'ATTIT')):
                s = s + sact
            else:
                return NIL
        # CHECK NO. OF WORDS BETWEEN ATTITUDE AND OBJECT
        if nwords > 3:
            return NIL
        if get(aword, 'NEG'):
            self.tval = not self.tval
        S = lambda n: nth(s, n)
        flip = lambda w: get(w, 'FLIP')
        if len(s) < 3:
            # CHECK FOR GENERAL ATTITUDE, E.G. (YOU ANGRY)
            if S(2) == 'YOU' and S(1) == aword and not flip(aword) \
                    and not get(aword, 'RELN'):
                if car(inp) == 'Q':
                    self.interpers = True
                    reply = self.answer(inp)
                else:
                    reply = self.choose('SEEM')
            else:
                return NIL
        elif (S(3) == 'YOU' and S(2) == aword and not flip(aword) and S(1) == 'ME') or \
                (S(3) == 'I' and flip(S(2)) and S(1) == 'YOU') or \
                (S(3) == 'I' and S(2) == 'YOU' and S(1) == aword and not flip(aword)):
            # CHECK FOR "YOU <ATTITUDE> ME" SITUATIONS
            if not get(aword, 'RELN') or car(s) == 'ME':
                att = attitude if self.tval else get(attitude, 'OPP')
                reply = self.choose((att, 'YMREPLIES'))
        elif (S(3) == 'I' and S(2) == aword and not flip(aword) and S(1) == 'YOU') or \
                (S(3) == 'YOU' and flip(S(2)) and S(1) == 'ME') or \
                (S(3) == 'YOU' and S(2) == 'ME' and S(1) == aword and not flip(aword)):
            # CHECK FOR "I <ATTITUDE> YOU" SITUATIONS
            if ((car(inp) == 'Q' or sact) and last(sact) == 'YOU') or self.tval:
                reply = self.choose((attitude, 'IYREPLIES'))
            else:
                reply = self.choose((get(attitude, 'OPP'), 'IYREPLIES'))
                self.fjump = 0.1
                self.ajump = 0.2
        if reply:
            self.say(reply)
            return True
        return NIL

    # NORMAL  HANDLES STATEMENT OF 'OTHER IN THE ABSENCE OF PROVOCATIVE INPUT
    def normal(self, statement):
        if self.fear > 14:
            return self.fearmode()
        if self.anger > 14:
            return self.angermode()
        if self.delflag:
            return self.deltalk(statement)
        return self.prompt(statement)

    def persrel(self, inp):
        return self.iyoume(inp) or self.apolog(inp) or self.threat(inp)

    # SELFREF  SCANS THE INPUT SENTENCE FOR DIRECT OR INDIRECT REFERENCE TO THE
    #          SENSITIVE AREAS OF 'SELF AND CALLS FOR THE APPROPRIATE REPLY
    def selfref(self, inp):
        get, choose = self.get, self.choose
        you = 'YOU' in inp or 'YOUR' in inp or "YOU'RE" in inp
        neg = bool(member1(self.nlist, inp))
        found = NIL
        # CHECK FOR GENERAL INSULTS OR COMPLIMENTS
        for word in inp:
            if word in get('INSULT', 'IND'):
                if you:
                    if not neg:
                        self.ajump = 0.8
                        found = choose('ANGER')
                    else:
                        if self.mistrust > 9:
                            self.ajump = 0.2
                        found = choose('DISTANCE')
                else:
                    self.ajump = 0.3
                    found = choose('PERS')
            elif word in get('COMPL', 'IND'):
                if you:
                    if not neg:
                        if self.mistrust > 9:
                            self.ajump = 0.2
                        found = choose('DISTANCE')
                    else:
                        self.ajump = 0.7
                        found = choose('HOSTILEREPLIES')
                else:
                    self.ajump = 0.5
                    found = choose('SENSREPLIES') + [word, '?']
            else:
                found = NIL
            if found:
                break
        if found:
            self.say(found)
            return True

        # CHECK FOR POSITIVE OR NEGATIVE REFERENCE TO 'SELF IN SENSITIVE AREA
        adj = self.adjtype(inp)
        for word in inp:
            self.concept = get(word, 'SET')
            if self.concept and self.concept in self.sensitivelist:
                concept = self.concept
                if not get(concept, 'SPECIAL') and car(inp) == 'Q' and you:
                    self.ajump = 0.2
                    found = self.answer(inp)
                elif you and get(adj, 'TYPE') == 'NEG':
                    if not neg:
                        self.ajump = 0.7
                        found = choose('HOSTILEREPLIES')
                    else:
                        if self.mistrust > 9:
                            self.ajump = 0.3
                        found = choose('DISTANCE')
                elif you and get(adj, 'TYPE') == 'POS':
                    if not neg:
                        if self.mistrust > 9:
                            self.ajump = 0.3
                        found = choose('DISTANCE')
                    else:
                        self.ajump = 0.7
                        found = choose('HOSTILEREPLIES')
                elif you and (get(concept, 'SPECIAL') or get(adj, 'TYPE')):
                    self.ajump = 0.5
                    self.concept = [concept]
                    found = choose('DEFENSREPLIES')
                    found = found + (self.concept or NIL)
                elif get(adj, 'TYPE'):
                    self.ajump = 0.5
                    found = self.selfrefreply(adj, word)
                elif get(concept, 'SPECIAL'):
                    self.ajump = 0.4
                    found = choose('PERS')
                else:
                    self.ajump = 0.2
                    self.concept = [concept]
                    found = choose('GUARD')
                    found = found + (self.concept or NIL)
            else:
                found = NIL
            if found:
                break
        if found:
            self.say(found)
            return True
        return NIL

    # --- AUXILIARY FUNCTIONS -------------------------------------------------

    # ADJTYPE  RETURNS AND TRIES TO IDENTIFY ANY VALUE-TYPE MODIFIERS IN STATEMENT
    def adjtype(self, stmt):
        word, found = NIL, NIL
        for word in stmt:
            for typ in ('POS', 'NEG', 'AMBIG'):
                if word in self.get('ADJLIST', typ):
                    self.putprop(word, typ, 'TYPE')
                    found = word
                if found:
                    break
            if found:
                break
        return word

    # ANSVAR  ALTERNATIVELY SELECTS ONE OF TWO VARIANTS OF AN ANSWER
    def ansvar(self, keywd):
        a = self.get(keywd, 'A')
        if not a:
            if self.flare == 'INIT':
                return self.choose('EXHAUST')
            return self.flstmt(self.get(self.flare, 'SET'))
        if not is_atom(car(a)):
            # 'A' CONSISTS OF A LIST OF 2 ANSWERS: ((---)(---))
            return self.choose((keywd, 'A'))
        return a

    # ANSWER  HANDLES QUESTIONS OF 'OTHER
    def answer(self, q):
        ans = NIL
        # "INTERROGATIVE IMPERATIVES" ARE CONSIDERED AS QUESTIONS ABOUT 'SELF
        if 'TELL' in q:
            q = ['Q', 'YOU'] + q
        # STATEMENTS THAT THE 'OTHER HAS A QUESTION ARE CONSIDERED AS QUESTIONS
        elif member1(self.get('QUES', 'IND'), q):
            q = ['Q', 'QUESTION'] + q
        if car(q) == 'Q' and self.qword == 'INTROTOP' and ('YOU' in q or 'YOUR' in q):
            ans = self.answer1(q, self.get('INTROTOP', 'Q'))
        elif self.qword != 'INTROTOP':
            if member1(['YOU', 'YOUR'], q):
                ans = self.answer1(q, self.get('INTROTOP', 'Q'))
            if not ans:
                ans = self.answer2(q)
                if not ans and self.qword != self.lasttop:
                    self.qword = self.lasttop
                    ans = self.answer2(q)
        if not ans:
            # NO QUESTIONS RECOGNIZED
            ans = self.miscq(q) if car(q) == 'Q' else self.miscs(q)
            self.lasttop = self.qword = 'INTROTOP'
        self.ascan(ans, q)
        return ans

    def answer1(self, q, topics):
        ans = NIL
        # TRY TO MATCH WORDS OF QUESTION WITH ONE OF THE SELF-TOPICS
        for concept in topics:
            if member1(concept, q):
                self.lasttop = car(concept)
                for spec in self.get(self.lasttop, 'Q'):
                    if member1(spec, q):
                        self.qword = car(spec)
                        ans = self.ansvar(self.qword)
                    if ans:
                        break
                if not ans:
                    self.qword = car(concept)
                    ans = self.ansvar(self.qword)
            if ans:
                break
        return ans

    def answer2(self, q):
        ans = NIL
        for concept in self.get(self.qword, 'Q'):
            if member1(concept, q):
                self.qword = car(concept)
                ans = self.ansvar(self.qword)
            if ans:
                break
        return ans

    # APOLOG  RESPONDS DIFFERENTIALLY TO APOLOGIES ACCORDING TO MISTRUST LEVEL
    def apolog(self, stmt):
        if member1(self.get('APOL', 'IND'), stmt):
            if self.mistrust > 9:
                self.ajump = 0.2
            else:
                self.anger = self.anger - 1
            self.say(self.choose('ACCUSE'))
            return True
        return NIL

    # ASCAN  SCANS 'SELF'S ANSWER FOR MENTION OF FLARE OR MAFIA
    def ascan(self, ans, q):
        if self.checkflare(ans, self.liveflares):
            self.flmod(self.get(self.flare, 'SET'))
        if 'MAFIA' in (ans or NIL):
            self.delflag = True
            self.flare = 'INIT'

    # CHOOSE  SELECTS THE NEXT REPLY FROM THE RELEVANT GROUP
    def choose(self, replies):
        if isinstance(replies, tuple):
            replies, ind = replies
        else:
            ind = 'IND'
        responses = self.get(replies, ind)
        if not responses:
            if replies == 'EXHAUST':
                self.ende = True
                return [['FED', 'UP']]
            self.concept = NIL
            return self.choose('EXHAUST')
        self.putprop(replies, responses[1:], ind)
        return responses[0]

    # CHOOSEDEL  CHOOSES A DELUSIONAL RESPONSE ACCORDING TO "TYPE"
    def choosedel(self, typ):
        dl = 'DEL' + str(typ) if isinstance(typ, int) else typ
        oldf = self.get(dl, 'FREQ')
        if oldf < 3:
            freq = oldf + 1
            self.putprop(dl, freq, 'FREQ')
            deln = car(suflist(self.get('DELUSIONS', dl), freq - 1))
            if typ == 1 or typ == 4:                 # FOR VARIATION ONLY
                return self.get('PREFACE', self.get(dl, 'FREQ')) + deln
            return deln
        # 'SELF HAS MENTIONED THIS DELUSION 3 TIMES
        self.delflag = NIL
        self.delend = True
        return ["LET'S", 'TALK', 'ABOUT', 'SOMETHING', 'ELSE-', "I'VE", 'GIVEN',
                'YOU', 'SOME', 'IDEA', 'OF', "WHAT'S", 'GOING', 'ON']

    # DELCHECK  RETURNS ANY NEW DELUSION-EXPRESSIONS FOUND IN INPUT AND DELETES AS SUCH
    def delcheck(self, inp):
        words = NIL
        if words := member1(self.delnlist, inp):
            self.delnlist = delete(words, self.delnlist)
        elif words := member1(self.delvlist, inp):
            self.delvlist = delete(words, self.delvlist)
        elif self.mistrust > 10 and (words := member1(self.delalist, inp)):
            self.delalist = delete(words, self.delalist)
        return [words] if words and is_atom(words) else words

    # DISTRUST  HANDLES FOLLOW-UPS TO LOCAL SITUATIONS OF DISTRUST
    def distrust(self):
        if self.fear > 10 or self.anger > 10 or self.fear + self.anger > 14:
            return self.choose('TURNOFF')
        return self.choose('ALOOF')

    # FIXPTRS  TRANSFERS HIERARCHICAL POINTERS TO NEW FLARE TO NEXT HIGHER FLARE
    def fixptrs(self, flset):
        for concept in self.liveflares + self.deadflares:
            if self.get(concept, 'NEXT') == flset:
                self.putprop(concept, self.get(flset, 'NEXT'), 'NEXT')

    # FLRECORD  NOTES MENTION OF FLARE AND RAISES FEAR
    def flrecord(self, flset):
        self.flmod(flset)
        self.fjump = self.weight / 40.0
        self.lasttop = self.qword = 'INTROTOP'

    # FLMOD  MOVES NEW FLARE FROM "LIVELIST" TO "DEADLIST"
    def flmod(self, flset):
        self.liveflares = delete(flset, self.liveflares)
        self.deadflares = [flset] + self.deadflares
        self.fixptrs(flset)

    # FLARELEAD  DECIDES WHAT TYPE OF "SUSPICIOUSNESS" REPLY IS SUITED
    #            TO INTRODUCE THE FLARE CONCEPT
    def flarelead(self, flset):
        if self.get(flset, 'TYPE') == 'INSTITUTION':
            return self.choose('NEXTFL') + ['THE'] + [car(self.get(flset, 'WORDS'))]
        # DO NOT TREAT SINGULARS AS A GENERIC TOPIC
        if str(self.flare)[-1] == 'S':
            return self.choose('NEXTFL') + [self.flare]
        return self.choose('NEXTFL') + [car(self.get(flset, 'WORDS'))]

    # FLSTMT  PROVIDES NEXT STATEMENT ABOUT FLARE
    def flstmt(self, fset):
        # IF REACH 'MAFIASET THRU FLARE HIERARCHY, ENTER DELUSIONAL MODE
        if fset == 'MAFIASET' and not self.delend:
            self.delflag = True
            return self.delstmt()
        nref = self.get(fset, 'NREF') or 0
        if nref < 2:
            nref = nref + 1
            self.putprop(fset, nref, 'NREF')
            return car(suflist(self.get(fset, 'STMTS'), nref - 1))
        # GO TO NEXT FLARE TOPIC
        return self.leadon(self.get(fset, 'NEXT'))

    def leadon(self, newset):
        if newset != 'MAFIASET':
            # RECORD NEW FLARE
            self.flmod(newset)
            self.flare = car(self.get(newset, 'WORDS'))
        elif self.delend:
            # ARRIVE AT 'MAFIASET BUT THROUGH WITH DELUSIONS
            self.flare = 'INIT'
            return self.choose('FEELER')
        elif self.weak or self.fear > 12 or self.anger > 12 or \
                self.fear + self.anger + self.mistrust > 20:
            # ARRIVED AT 'MAFIASET BUT DOES NOT HAVE DELUSIONS ABOUT
            # MAFIA OR IS UNWILLING TO DISCUSS THEM
            return self.choose('CHANGESUBJ')
        else:
            delete('MAFIA', self.delnlist)     # (sic: result not stored)
            self.delflag = True
            self.flare = 'INIT'
        # RESPOND WITH NEW FLARE
        return self.flarelead(newset)

    # MISCQ  TRIES TO DETECT AND ANSWER CERTAIN RECOGNIZABLE QUESTIONS
    def miscq(self, q):
        ans = NIL
        if suflist(q, len(q) - 3) == ['HOW', 'ARE', 'YOU']:
            ans = ['ALL', 'RIGHT']
        elif self.interpers:
            # INTERPERSONAL ATTITUDE MAY HAVE BEEN SET IN IYOUME
            self.interpers = NIL
            if member1(self.get('QLIST', 'IND'), q):
                return self.choose('WFEEL')
            return self.choose('QFEEL')
        elif not (ans := self.objq(q)):
            # UNIDENTIFIABLE "HOW-TYPE" QUESTION
            if 'HOW' in q:
                for concept in ('MANY', 'MUCH', 'LONG', 'OFTEN'):
                    if concept in q:
                        ans = self.choose(concept)
                    if ans:
                        break
        if ans:
            return ans
        # IF QUESTION NOT RECOGNIZED, TRY TO ANSWER ACCORDING TO CONTEXT
        if self.flare != 'INIT':
            return self.flstmt(self.get(self.flare, 'SET'))
        if self.delflag:
            return self.delstmt()
        # WH- QUESTIONS
        if 'WHY' in q:
            ans = self.choose('WHY')
        else:
            for qword in self.get('QLIST', 'IND'):
                ans = self.choose('UNKNOWN') if qword in q else NIL
                if ans:
                    break
        if ans:
            return ans
        # MISCELLANEOUS "TELL-" QUESTION
        if 'TELL' in q:
            return ['I', "DON'T", 'KNOW', 'ANYTHING', 'ABOUT', 'THAT']
        # NO CLUES - ANSWER NONCOMMITTALLY
        return self.choose('QREPLIES')

    # MISCS  TRIES TO DETECT AND ANSWER CERTAIN RECOGNIZABLE STATEMENTS
    def miscs(self, s):
        if 'JUMP' in s:
            return [['EXITS']]
        if car(s) in ('HI', 'HELLO', 'HOWDY') or \
                cadr(s) in ('MORNING', 'AFTERNOON', 'EVENING'):
            return ['HELLO']
        if ('AM' in s and 'DOCTOR' in s) or 'DR' in s or ('MY' in s and 'NAME' in s):
            return ['GLAD', 'TO', 'MEET', 'YOU']
        if ('ALREADY' in s or 'BEFORE' in s) and ('SAID' in s or 'MENTIONED' in s):
            return ['I', 'GUESS', 'I', 'DID']
        # LOOK AT CONTEXT OF CONVERSATION
        if self.flare != 'INIT':
            return self.flstmt(self.get(self.flare, 'SET'))
        if self.delflag:
            return self.delstmt()
        # NONCOMMITTAL REPLY
        return self.choose('SREPLIES')

    # MODIFVAR  MODIFIES AFFECT VARIABLES AFTER EACH I-O PAIR
    def modifvar(self):
        self.raise_()
        # ACCOUNT FOR NORMAL DROP IN EACH VARIABLE
        self.anger = self.anger - 1 if self.anger > self.anger0 + 1 else self.anger0
        if self.delflag:
            # ADD 5 TO BASE VALUE OF FEAR IF DELUSIONS UNDER DISCUSSION
            self.fear = self.fear - 0.1 if self.fear > self.fear0 + 5.1 else self.fear0 + 5
        elif self.flare != 'INIT':
            # ADD 3 TO BASE VALUE OF FEAR IF FLARES UNDER DISCUSSION
            self.fear = self.fear - 0.2 if self.fear > self.fear0 + 3.2 else self.fear0 + 3
        else:
            self.fear = self.fear - 0.3 if self.fear > self.fear0 + 0.3 else self.fear0
        self.mistrust = self.mistrust - 0.05 if self.mistrust > self.mistrust0 + 0.05 \
            else self.mistrust0
        if self.tracev:
            self.terpri()
            self.printstr('      FEAR = ' + lisp_str(self.fear))
            self.printstr('      ANGER = ' + lisp_str(self.anger))
            self.printstr('      MISTRUST = ' + lisp_str(self.mistrust))
        self.terpri()

    # OBJQ  HANDLES "OBJECTIVE"-TYPE QUESTIONS (ABOUT LOCAL EXTERNAL WORLD)
    def objq(self, q):
        if 'WHAT' in q or 'WHO' in q or 'WHICH' in q:
            found = NIL
            for pair in self.get('OBJDATA', 'IND'):
                found = cadr(pair) if member1([car(pair)], q) else NIL
                if found:
                    break
            if found:
                return found
        return NIL

    # PROMPT  HANDLES "TELL-ABOUT-YOURSELF" QUESTIONS
    def prompt(self, inp):
        if member1(self.get('DISCUSS', 'IND'), inp) and member1(self.get('SELF', 'IND'), inp):
            inp = ['TELL'] + inp
            ans = self.answer1(inp, self.get('INTROTOP', 'Q'))
            self.say(ans)
            self.ascan(ans, inp)
        else:
            self.say(self.answer(inp))

    # QTHREAT  RESPONDS SUSPICIOUSLY TO QUESTIONS AT HIGH FEAR LEVEL
    def qthreat(self, stmt):
        if car(stmt) == 'Q':
            self.say(self.choose('THREATQ'))
            return True
        return NIL

    # RAISE  RAISES LEVEL OF RELEVANT AFFECT VARIABLES
    def raise_(self):
        if self.fjump:
            if self.weak:
                self.fjump = 0.3 * self.fjump
            self.fear = self.fear + self.fjump * (20 - self.fear)
            self.mistrust = self.mistrust + (0.5 * self.fjump) * (20 - self.mistrust)
            self.mistrust0 = self.mistrust0 + 0.1 * self.fjump * (20 - self.mistrust0)
            self.fjump = None
        if self.ajump:
            if self.weak:
                self.ajump = 0.7 * self.ajump
            self.anger = self.anger + self.ajump * (20 - self.anger)
            self.mistrust = self.mistrust + (0.5 * self.ajump) * (20 - self.mistrust)
            self.mistrust0 = self.mistrust0 + 0.1 * self.ajump * (20 - self.mistrust0)
            self.ajump = None

    # READSENT  RETURNS SCANNED SENTENCE IN THE FORM OF A LIST OF WORDS
    #           (SENT IS A LIST OF INPUT CHARACTERS)
    def readsent(self, sent):
        self.termin = NIL
        # SKIP OVER LEADING CHARACTERS WHICH AREN'T LETTERS OR NUMBERS
        # (READCH returns digits as identifiers, so NUMBERP CHAR is never true)
        while sent and not self.get(sent[0], 'LET'):
            sent = sent[1:]
        if not sent:
            self.termin = 'ILL'
            return NIL
        return self.readsent1(self.scanwd(self.blankskip(sent)))

    # READSENT1  ASSEMBLES REMAINDER OF SENTENCE STARTING AT BEGINNING OF NEXT WORD
    def readsent1(self, word):
        words = []
        while not self.termin:
            words.append(''.join(word))
            word = self.scanwd(self.restsent)
        self.restsent = NIL
        if self.termin != 'ILL' and word:
            words.append(''.join(word))
        return words

    # SCANWD  RETURNS NEXT WORD IN SENT AS LIST OF CHARACTERS
    def scanwd(self, sent):
        word = []
        while True:
            char = car(sent)
            if char in (PERIOD, '?'):
                # ILLEGAL FOR TERMINATOR TO BE FOLLOWED BY OTHER CHARACTERS
                self.termin = char if not self.blankskip(sent[1:]) else 'ILL'
                return word
            if char in (BLANK, CR, COMMA, DASH):
                self.restsent = self.nullskip(sent)
                return word
            if self.get(char, 'LET'):
                word.append(char)
                sent = sent[1:]
                continue
            self.termin = 'ILL'
            return word

    @staticmethod
    def blankskip(sent):
        while sent and sent[0] in (BLANK, CR, LF):
            sent = sent[1:]
        return sent

    @staticmethod
    def nullskip(sent):
        while sent and sent[0] in (BLANK, CR, LF, COMMA, DASH):
            sent = sent[1:]
        return sent

    @staticmethod
    def rtpar(s):
        i = s.find(')')
        return s[i + 1:] if i >= 0 else ''

    # SAY  HANDLES OUTPUT OF LIST 'STMT'
    def say(self, stmt):
        stmt = stringate(stmt)
        # IN "SUPPRESS" VERSION, ELIMINATE LEADING PARENTHETICAL EXPRESSIONS
        if (self.suppress or self.talk) and stmt.startswith('('):
            stmt = self.rtpar(stmt)
        self.out.append(stmt)
        self.printstr(stmt)
        if self.save_file:
            with open(self.save_file, 'a') as f:
                f.write(stmt + '\n')
        return stmt

    # SELFREFREPLY  INTRODUCES VARIATION INTO CHOSEN "SENSITIVE" REPLY
    def selfrefreply(self, adj, noun):
        self.flag = not self.flag
        return self.choose('SENSREPLIES') + ([adj] if self.flag else [adj, noun]) + ['?']

    # SENTYPE  SETS UP TYPE OF SENTENCE (STATEMENT, QUESTION, ILLEGAL)
    def sentype(self, sent):
        if self.termin == 'ILL':
            return [':', 'BAD', 'INPUT;', 'TRY', 'AGAIN.']
        if self.termin == '?':
            return ['Q'] + sent
        return sent

    # SPECQUES  PROVIDES ANSWERS TO SPECIFIC QUESTIONS RELATED TO THE
    #           DELUSIONAL COMPLEX
    def specques(self, inp):
        found, value, pair = NIL, NIL, NIL
        qa = self.get('ANSWERS', self.laststmt)
        for pair in qa or NIL:
            found = member1(car(pair), inp)
            if found:
                break
        if found:
            # FOUND KEY WORDS ASSOCIATED WITH LAST DELUSIONAL STATEMENT
            self.laststmt = cadr(pair)
            value = self.choosedel(cadr(pair))
        if not value:
            # IF 'WHO' IS NOT OTHERWISE RECOGNIZED, ASSUME AS REFERRING TO MAFIA
            wd = nth(inp, 2)
            if wd in ('WHO', 'WHOM'):
                value = ['THE', 'MAFIA']
        if not found:
            if 'THEY' in inp and ('DO' in inp or 'ARE' in inp) and len(inp) < 4 \
                    and car(inp) == 'Q':
                value = ["THAT'S", 'RIGHT']
        if value:
            # DELETE ANY NEW DELUSIONAL WORDS IN 'SELF'S STATEMENT FROM DELUSION LIST
            self.delcheck(value)
            self.say(value)
        return value

    # SPECREAX  PROVIDES THE APPROPRIATE REACTION OF 'SELF TO SPECIAL TYPES
    #           OF STATEMENT OF 'OTHER
    def specreax(self, stmt):
        if car(stmt) == 'S':
            self.say(self.choose('SILENCE'))
            return True
        if 'YOU' in stmt and member1(self.get('ABNORMAL', 'IND'), stmt):
            # INSINUATION THAT 'SELF IS MENTALLY ILL
            self.fjump = self.ajump = 0.3 if car(stmt) == 'Q' else 0.5
            self.say(self.choose('ALIEN'))
            return True
        return NIL

    def threat(self, stmt):
        found = member1(self.get('DELWDS', 'NOUNS') + self.get('DELWDS', 'VERBS'), stmt)
        if found:
            if member1(self.nlist, stmt):
                self.fear = self.fear - 1
                found = self.choose('CAUTION')
            elif 'I' in stmt:
                self.fjump = 0.5
                found = self.choose('PANIC')
            else:
                found = NIL
        if found:
            self.say(found)
            return True
        return NIL

    # YES  SCANS STATEMENT OF 'OTHER FOR AFFIRMATIVE EXPRESSIONS
    def yes(self, inp):
        disbelief = member1(self.get('DISBELIEF', 'IND'), inp)
        if self.get('BELIEVEREPLIES', 'IND'):
            return not disbelief and 'NO' not in inp and \
                ('YES' in inp or 'CERTAINLY' in inp or 'GUESS' in inp or 'SURE' in inp)
        return not disbelief and 'NO' in inp

    # --- terminal --------------------------------------------------------------

    def printstr(self, s):
        if self.echo:
            print(s)

    def terpri(self):
        if self.echo:
            print()

    # One turn of the MAIN PROGRAM loop.  Returns False when the input was bad.
    def hear(self, line):
        self.interpers = NIL          # REINITIALIZE INTERPERSONAL ATTITUDE
        message = list(line.upper())
        self.remark = self.sentype(self.readsent(message))
        if self.badinp(self.remark):
            return False
        if self.save_file:
            with open(self.save_file, 'a') as f:
                f.write('\n\n' + line + '\n')
        if 'BYE' in self.remark or self.fear > 18.4:
            self.ende = True
        else:
            r = self.remark
            self.specreax(r) or self.delref(r) or self.selfref(r) or \
                self.flareref(r) or self.persrel(r) or self.normal(r)
            self.modifvar()
        return True

    def badinp(self, sent):
        self.terpri()
        if ':' in sent:
            self.printstr(stringate(sent))
            return True
        return False

    def goodbye(self):
        if (self.delflag or self.flare != 'INIT') and not self.fear > 18.4:
            self.ajump = 0.1
            self.say([['OFFENDED'], 'GOOD', 'BYE'])
        else:
            self.say(['BYE'])
        self.tracev = True
        self.modifvar()


# ---------------------------------------------------------------------------
#  MAIN PROGRAM
# ---------------------------------------------------------------------------

def read_atom():
    try:
        line = input()
    except EOFError:
        return ''
    parts = line.upper().split()
    return parts[0] if parts else ''


def main():
    print()
    print('END INPUT PARAMETERS WITH CARRIAGE RETURN OR ALTMODE')
    print()
    print('SUPPRESS NON VERBAL FEATURE? [Y,N]')
    suppress = read_atom() == 'Y'
    print()
    print('VERSION [WEAK, STRONG]')
    weak = read_atom() == 'WEAK'
    anger = fear = mistrust = None
    if not weak:
        print()
        print('ANGER [LOW, MILD]')
        anger = read_atom()
        print()
        print('FEAR [LOW, MILD]')
        fear = read_atom()
        print()
        print('MISTRUST [MILD, HIGH]')
        mistrust = read_atom()
    print()
    print('TRACE VARIABLES? [Y,N]')
    tracev = read_atom() == 'Y'
    print()
    print('ARE TWO TELETYPES BEING USED? (Y,N)')
    if read_atom() == 'Y':
        print('(PORT NOTE: THE TWO-TELETYPE MODE IS NOT AVAILABLE; USING ONE.)')
    save_file = None
    print('DO YOU WANT THIS INTERVIEW SAVED ON A FILE?(Y,N)')
    if read_atom() == 'Y':
        print()
        print('WHAT FILE DO YOU WANT THIS INTERVIEW SAVED ON?(5 LETTERS ONLY)')
        save_file = read_atom()[:5] or 'PARRY'

    p = Parry(suppress=suppress, weak=weak, anger=anger, fear=fear,
              mistrust=mistrust, tracev=tracev, save_file=save_file)

    print('''
END INPUT WITH A PERIOD OR QUESTION MARK, FOLLOWED BY TWO ALTMODES.
SPELL OUT NUMBERS.
TO INDICATE SILENCE, TYPE 'S.'
WHEN FINISHED, TYPE 'BYE.'

(PORT NOTE: PRESS RETURN INSTEAD OF TWO ALTMODES.)
''')
    while not p.ende:
        while True:
            print('READY:')
            try:
                line = input()
            except EOFError:
                line = 'BYE.'
            if p.hear(line):
                break
    p.goodbye()


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print()
        sys.exit(130)
