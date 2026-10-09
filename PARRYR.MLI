BEGIN

%               #####   PARANOID MODEL   #####               %


   NEW POINTERS, DELNO, LASTSTMT, DELFLAG, FLARE, FLAG, FLARELIST, REMARK,
      WEIGHT, DELAY, NREF, QWORD, GLOBX, GLOBY, TERMIN, RESTSENT, ANGER, FEAR, MISTRUST, ANGER0, FEAR0,
      MISTRUST0, TRACEV, DLIM, SUPPRESS,  SENSITIVELIST, DELNLIST, DELVLIST, DELALIST, LIVEFLARES,
      LASTTOP, DEADFLARES, X, REST, SKEP, DELEND, AJUMP, FJUMP, TELL, NLIST, TVAL, SACTS, WEAK, INTERPERS,
      EOF, MESSAGE, ENDE, TALK, SAVE_FILE;

   SPECIAL POINTERS, DELNO, LASTSTMT, DELFLAG, FLARE,
           SENSITIVELIST, FLAG, FLARELIST, WEIGHT, DELAY, NREF, QWORD, GLOBX, GLOBY,
           TERMIN, RESTSENT, ANGER, FEAR, MISTRUST, ANGER0, FEAR0, MISTRUST0, SUPPRESS,
           TRACEV, X, DLIM, DELNLIST, DELVLIST, DELALIST, LIVEFLARES, DEADFLARES, DELEND, SKEP, REST,
           LASTTOP, AJUMP, FJUMP, TELL, NLIST, TVAL, SACTS, WEAK, INTERPERS,
	   EOF, MESSAGE, ENDE, TALK, SAVE_FILE, FILE1, FILE2, REMARK, CHAR;
  %ALOOCATIONS FOR RECONSTRUCTING PARRY
     R LISP 39
FULL WORDS=3300
BINARY PROGRAM SPACE=12000   %


%               *****   MAIN FUNCTIONS   *****               %


          %
INITIALIZE     %

      EXPR  INITIALIZE ();
         BEGIN
            NEW VALUE,I, CONCEPT, WORD, SL, FL, DN, DV, AN, AV, ANV,  AL, QL, RL, WTS, WT;
            SPECIAL VALUE, CONCEPT, WORD, SL, FL, DN, DV, AN, AV, ANV, AL, QL, RL, WTS, WT;
            
	INITFN 'RESTART;
            IF ¬GET('SEND_MAIL,'SUBR) THEN		% MAKE SURE THE DATA HAS BEEN READ IN. %
            BEGIN
               EVAL '(INC (INPUT (4 KMC) RDATA) NIL);
               WHILE NOT ATOM X ← ERRSET(READ(),T) DO EVAL CAR X;
               INC(NIL,T);
            END;

            NLIST←GET ('NEGS, 'IND);                    %   NEGATORS   %
            SACTS←GET ('SACTS, 'IND);                   %   META-ACTS, E.G. 'THINK'   %
            I←0;                                        %   INDEX INTO SET OF REPLIES   %
            DELNO←0;                                    %   CURRENT DELUSION-NUMBER   %
            FLARE←'INIT;                                %   FLARE=CURRENT FLARE TOPIC;
                                                            'INIT = NONE   %
            LIVEFLARES←GET ('FLARELIST, 'SETS);         %   FLARES NOT YET DISCUSSED   %
            SENSITIVELIST←GET ('SENSITIVELIST, 'SETS);  %   SENSITIVE TOPICS   %
            DELNLIST←GET ('DELWDS, 'NOUNS);             %   DELUSION TOPICS   %
            DELVLIST←GET ('DELWDS, 'VERBS);
            DELALIST←GET ('DELWDS, 'AMBIG);             %   DELUSION TOPICS ABOVE A CERTAIN THRESHOLD OF MISTRUST   %
            
            %   DLIM IS THE NUMBER OF "MORE GENERAL" DELUSIONS
                CURRENTLY IN THE PROGRAM   %

            DLIM←6;

                  %   LASTTOP = LAST MAIN SELF-TOPIC DISCUSSED AND NOT LEFT;
                      QWORD = PRESENT OR MOST RECENT KEYWORD TOPIC   %

            LASTTOP←QWORD←'INTROTOP;
            TERPRI NIL;
            PRINTSTR ("END INPUT PARAMETERS WITH CARRIAGE RETURN OR ALTMODE");
            TERPRI NIL;
            PRINTSTR ("SUPPRESS NON VERBAL FEATURE? [Y,N]");
            SUPPRESS←IF READ () = 'Y THEN T ELSE NIL;
            TERPRI NIL;
            PRINTSTR ("VERSION [WEAK, STRONG]");
            IF READ () EQ 'WEAK THEN
            BEGIN
               WEAK←T;
               ANGER←ANGER0←FEAR←FEAR0←MISTRUST←MISTRUST0←0;
            END
            ELSE
            BEGIN
               TERPRI NIL;
               PRINTSTR ("ANGER [LOW, MILD]");
               ANGER←(ANGER0←IF READ () = 'LOW THEN 0 ELSE 10);
               TERPRI NIL;
               PRINTSTR ("FEAR [LOW, MILD]");
               FEAR←(FEAR0←IF READ () = 'LOW THEN 0 ELSE 10);
               TERPRI NIL;
               PRINTSTR ("MISTRUST [MILD, HIGH]");
               MISTRUST←(MISTRUST0←IF READ () EQ 'MILD THEN 0 ELSE 15);
            END;
            TERPRI NIL;
            PRINTSTR ("TRACE VARIABLES? [Y,N]");
            IF READ () = 'Y THEN TRACEV←T;
      
            EOF←PERCENT;
            PRINTSTR TERPRI "ARE TWO TELETYPES BEING USED? (Y,N)";
            IF READ () EQ 'Y THEN
            BEGIN
               TALK←T;
               PRINTSTR TERPRI "WHAT DISK FILE DO YOU WANT THIS INTERVIEW SAVED ON?  (5 LETTERS ONLY)";
               FILE1 ← READ();
               FILE2 ← AT(SUBSTR(FILE1,1,5) CAT "A");		% OUTPUT ALTERNATES BETWEEN THESE TWO. %
               OUT(FILE1, NIL, T);				% INITIALIZATION %
            END
            ELSE
            BEGIN
            PRINTSTR "DO YOU WANT THIS INTERVIEW SAVED ON A FILE?(Y,N)";
            IF READ () EQ 'Y THEN
               BEGIN
               SAVE_FILE ← T;
               PRINTSTR TERPRI "WHAT FILE DO YOU WANT THIS INTERVIEW SAVED ON?(5 LETTERS ONLY)";
                FILE1 ← READ();
                FILE2 ← AT(SUBSTR(FILE1,1,5) CAT "A");
                OUT(FILE1, NIL, T);
                END;
            END;

         END;
      
         
          %
ANGERMODE   PROVIDES RESPONSES FOR HIGH ANGER LEVEL   %

      EXPR ANGERMODE ();
         IF ANGER GREATERP 17.5 THEN PROG2 (TERPRI NIL, SAY (CHOOSE ('ANGER)))
         ELSE PROG2 (TERPRI NIL, SAY (CHOOSE ('HOSTILEREPLIES)));

          %
CHECKFLARE     SCANS THE INPUT SENTENCE FOR THE FLARE WORD WHICH HAS THE
               HIGHEST WEIGHT   %
      
      EXPR  CHECKFLARE (INP, FLARELIST);
         BEGIN
            NEW NFLARE, WORD, FSET, WT, RESULT;

               %   DISTINGUISH FLARES FOUND WITHIN THE STATEMENT (NFLARE)
                   FROM MOST RECENT FLARE (FLARE)   %

            NFLARE←'INIT;            %   GET ('INIT, 'WT) = 0   %

                  %   SCAN INPUT FOR FLARES AND CHECK WHETHER WEIGHT IS
                      GREATER THAN ANY PRECEDING FLARES IN INPUT   %

            FOR WORD IN INP DO
                IF (FSET←GET (WORD, 'SET)) MEMBER (FLARELIST) THEN
                  IF (WT←GET (FSET, 'WT)) GREATERP GET (GET (NFLARE, 'SET), 'WT) THEN
                     PROG2 (NFLARE←WORD, RESULT←T);
            IF RESULT THEN

                     %   IF FLARE ALREADY BEING DISCUSSED, DISREGARD ANY 
                         VERY WEAK NEW FLARE   %

               IF NOT (FLARE = 'INIT) AND NOT ((WT←GET (GET (NFLARE, 'SET), 'WT)) GREATERP 1) THEN
                  RESULT←NIL
               ELSE
               BEGIN
                  FLARE←NFLARE;
                  WEIGHT←WT;         %   USED IN COMPUTING RISE IN FEAR   %
               END;

            RETURN (RESULT);

         END;

          %
DELREF      SCANS THE INPUT SENTENCE FOR THE FIRST DIRECT REFERENCE TO 'SELF'S
            DELUSIONAL COMPLEX AND RETURNS A FEARFUL REACTION.  IF NO SUCH REFERENCE
            IS FOUND, NIL IS RETURNED.   %

      EXPR  DELREF (INP);
         BEGIN
            NEW WORD, FOUND;
            FOUND←DELCHECK (INP);

            IF FOUND THEN
            BEGIN
               IF DELFLAG THEN 

                        %   IF DELUSIONS ALREADY BEING DISCUSSED, THEN
                            DISTINGUISH BETWEEN "STRONG" AND "AMBIGUOUS" DELUSIONAL TOPICS
                            IN COMPUTING RISE IN FEAR   %

                  IF GET (CAR (FOUND), 'STRONG) THEN FJUMP←0.4
                  ELSE FJUMP←0.2
               ELSE
               BEGIN
                  FJUMP←0.5;
 
                        %   'MAFIA' TOPIC NO LONGEV INDUCES FEARFUL REACTION,
                            SINCE DELUSION DISCUSSION HAS ALREADY BEEN EVOKED   %

                  DELNLIST←DELETE ('MAFIA, DELNLIST);

                        %   MODIFY FLARE STRUCTURES TO NOTE THAT 'MAFIA' TOPIC
                            HAS ALREADY BEEN BROUGHT UP   %

                  FLMOD ('MAFIASET);
               END;

                     %   SET (OR KEEP) DELUSION FLAG = T UNLESS 'SELF HAS
                         FINISHED DISCUSSION DELUSIONS   %

               IF NOT DELEND THEN DELFLAG←T;
               
               %   RESET SO THAT FLARES OF LOWER PRIORITY THAN THOSE WHICH 
                   MAY HAVE BEEN PREVIOUSLY MENTIONED ARE RECOGNIZED   %

               FLARE←'INIT;
               SAY (DELSTMT ());

                     %   FORGET ABOUT RECENTLY DISCUSSED SELF-TOPICS   %

               LASTTOP←QWORD←'INTROTOP;
            END
            ELSE
            IF  ('MAFIA   %   I.E. AS ALREADY USED DEL WD   %
               MEMBER INP) THEN

                     %   IF 'OTHER WANTS TO TALK ABOUT 'MAFIA' AFTER 'SELF HAS
                         FINISHED DISCUSSING DELUSIONS, REJECT TOPIC   %

               IF DELEND THEN SAY (FOUND←CHOOSE ('MAFIASET))
               ELSE SAY (FOUND←DELSTMT ());
            RETURN (FOUND);
         END;

          %
DELSTMT     CAUSES THE "NEXT" DELUSION TO BE EXPRESSED   %
     
      EXPR DELSTMT ();
         BEGIN
            NEW STMT;   SPECIAL STMT;

                  %   IN WEAK VEVSION, TALK ABOUT RACKETS RATHER THAN MAFIA   %

            IF WEAK THEN RETURN FLSTMT ('RACKETSET);

            %   IF 'SELF HAS ALREADY EXPRESSED ALL HIS DELUSIONS, HE REFERS TO 
                  PREVIOUSLY MENTIONED ONES UP TO 3 TIMES TOTAL   %

            IF DELNO = DLIM THEN DELNO←1
            ELSE DELNO←DELNO + 1;
            IF (FEAR GREATERP 12) OR (ANGER GREATERP 12) OR ((FEAR+ANGER+MISTRUST) GREATERP 20) THEN
               RETURN (PROG2 (DELFLAG←NIL, CHOOSE ('CHANGESUBJ)));
            DELFLAG←T;
            FLARE←'INIT;

                  %   SELECT DELUSION   %

            STMT←CHOOSEDEL (DELNO);

            %   IF STMT CONTAINS DELUSIONAL FLARE, DELETE AS SUCH   %

            DELCHECK (STMT);


            %   REMEMBER THE DELUSIONAL STATEMENT TO WHICH 'OTHER IS ABOUT TO RESPOND   %

            LASTSTMT←AT ("DEL" CAT DELNO);
            RETURN (STMT);
         END;

          %
DELTALK     PRODUCES RESPONSE OF 'SELF IN CONTEXT OF EXPRESSION OF DELUSIONS   %

      EXPR DELTALK (STMT);
         IF NOT SKEP THEN

                  %   NO LOCAL CONTEXT OF SKEPTICISM   %

            IF MEMBER1 (GET ('DISBELIEF, 'IND), STMT) THEN

                  %   'OTHER EXPRESSES DISBELIEF OF 'SELF'S DELUSIONS   %

            BEGIN
              AJUMP←0.3;
              FJUMP←0.1;
              SAY (CHOOSE ('BELIEVEREPLIES));
              SKEP←T;
            END

                  %   CHECK FOR SPECIFIC QUESTION ABOUT DELUSIONS
                      OR OTHER QUESTIONS   %

            ELSE SPECQUES (STMT) OR SAY (ANSWER (STMT))
         ELSE
         BEGIN

                  %   IF FOLLOW-UP TO SKEPTICAL REMARK IS REASSURANCE,
                      CONTINUE EXPRESSING DELUSIONS   %

            IF YES (STMT) THEN SAY (DELSTMT ())
            ELSE SAY (DISTRUST ());
            SKEP←NIL;
         END;

          %
FEARMODE     PROVIDES FEARFUL REACTIONS TO STATEMENTS OF 'OTHER   %

      EXPR FEARMODE ();
         BEGIN
            TERPRI NIL;
            IF FEAR GREATERP 18.4 THEN SAY ('((EXITS)))

                  %   DISTINGUISH BETWEEN QUESTIONS AND STATEMENTS OF 'OTHER   %

            ELSE QTHREAT (REMARK) OR SAY (CHOOSE ('AFRAID));
         END;

          %
FLAREREF    HANDLES FLARE REFERENCES   %

      EXPR FLAREREF (INP);
         BEGIN

                  %   CHECK FOR NEW FLARE AND RECORD AS "OLD"   %

            IF CHECKFLARE (INP, LIVEFLARES) THEN FLRECORD (GET (FLARE, 'SET));

                  %   CHECK FOR OLD FLARE   %

            IF CHECKFLARE (INP, DEADFLARES) THEN  

                     %   RESPOND TO FLARE   %

               RETURN PROG2 (SAY (FLTALK (GET (FLARE, 'SET), 'Q CONS GET (FLARE, 'SET) CONS INP)), T);
         END;

          %
FLTALK      %

      EXPR FLTALK (FLSET, INP);
         IF FEAR GREATERP 14 OR ANGER GREATERP 14 THEN
            PROG2 (FLARE←'INIT, CHOOSE ('CHANGESUBJ))

               %   TRY TO ANSWER QUESTION ABOUT FLARE   %

         ELSE ANSWER (INP);

          %
IYOUME      HANDLES INTERPERSONAL ATTITUDE STATEMENTS 

            THIS IS AN UNINTELLIGIBLE TEMPORARY ROUTINE WHICH REPRESENTS
            EXPERIMENTAL EFFORTS TO DISCOVER THE CASES WHICH MUST BE 
            DISTINGUISHED IN DETERMINING THE MEANING OF THE INPUT   %

      EXPR IYOUME (INP);
         BEGIN
            NEW S, WD, SACT, ATTITUDE, AWORD, NWORDS, COUNT, REPLY;
            SPECIAL REPLY;
            TVAL←T;
            NWORDS←0;

               %   COLLECT RELEVANT ITEMS IN INPUT   %

            FOR WD IN INP DO
               IF WD EQ 'YOU OR WD EQ 'I OR WD EQ 'ME THEN PROG2 (S←WD CONS S, IF ATTITUDE THEN COUNT←NIL)
               ELSE
               IF WD MEMBER NLIST THEN TVAL←NOT TVAL
               ELSE
               IF WD MEMBER SACTS AND NOT SACT THEN
                  PROG2 (SACT←WD CONS S, S←SUFLIST (S,2))
               ELSE
               IF NOT ATTITUDE AND ATTITUDE←GET (WD, 'ATTIT) THEN
               BEGIN
                  S←(AWORD←WD) CONS S;
                  NWORDS←0;
                  COUNT←T;
               END
               ELSE
               IF COUNT THEN NWORDS←NWORDS + 1
            UNTIL LENGTH S = 3;

               % TRANSFORM E.G. (I BELIEVE) (YOU) INTO (I BELIEVE YOU)   %

            IF SACT AND LENGTH S LESSP 2 THEN
               IF NOT ATTITUDE AND (ATTITUDE←GET (AWORD←CAR SACT, 'ATTIT))  THEN
                  S←S @ SACT
               ELSE RETURN NIL;

               %   CHECK NO. OF WORDS BETWEEN ATTITUDE AND OBJECT   %

            IF NWORDS GREATERP 3 THEN RETURN NIL;
            IF GET (AWORD, 'NEG) THEN TVAL←NOT TVAL;

               %  CHECK FOR GENERAL ATTITUDE, E.G. (YOU ANGRY)   %

            IF LENGTH S LESSP 3 THEN
               IF S[2] EQ 'YOU AND S[1] EQ AWORD AND NOT GET (AWORD, 'FLIP) AND NOT GET (AWORD, 'RELN) THEN
                  IF CAR INP EQ 'Q THEN PROG2 (INTERPERS←T, REPLY←ANSWER (INP))
                  ELSE REPLY←CHOOSE ('SEEM)
               ELSE RETURN NIL
            ELSE

               %   CHECK FOR "YOU <ATTITUDE> ME" SITUATIONS   %

            IF S[3] EQ 'YOU AND S[2] EQ AWORD AND NOT GET (AWORD, 'FLIP) AND S[1] EQ 'ME OR
               S[3] EQ 'I AND GET (S[2], 'FLIP) AND S[1] EQ 'YOU OR
               S[3] EQ 'I AND S[2] EQ 'YOU AND S[1] EQ AWORD AND NOT GET (AWORD, 'FLIP) THEN
                  IF NOT GET (AWORD, 'RELN) OR CAR S EQ 'ME THEN
                     REPLY←CHOOSE (IF TVAL THEN ATTITUDE CONS 'YMREPLIES  ELSE GET (ATTITUDE, 'OPP) CONS 'YMREPLIES)
                  ELSE NIL
            ELSE

               %   CHECK FOR "I <ATTITUDE> YOU" SITUATIONS   %

            IF S[3] EQ 'I AND S[2] EQ AWORD AND NOT GET (AWORD, 'FLIP) AND S[1] EQ 'YOU OR
               S[3] EQ 'YOU AND GET (S[2], 'FLIP) AND S[1] EQ 'ME OR
               S[3] EQ 'YOU AND S[2] EQ 'ME AND S[1] EQ AWORD AND NOT GET (AWORD, 'FLIP) THEN

                  %   TREAT REFERENCES TO SELF'S OPINION SIMILARLY TO AFFIRMATIVE
                      STATEMENTS BY THE OTHER, AS FAR AS SELF'S ANSWER IS CONCERNED   %

               IF (CAR INP EQ 'Q OR SACT) AND CAR LAST SACT EQ 'YOU OR TVAL THEN
                  REPLY←CHOOSE (ATTITUDE CONS 'IYREPLIES)
               ELSE
               BEGIN
                  REPLY←CHOOSE (GET (ATTITUDE, 'OPP) CONS 'IYREPLIES);
                  FJUMP←0.1;
                  AJUMP←0.2;
               END;
            IF REPLY THEN RETURN PROG2 (SAY (REPLY), T);
         END;
      
          %
NORMAL      HANDLES STATEMENT OF 'OTHER IN THE ABSENCE OF 
            PROVOCATIVE INPUT   %
      
      EXPR  NORMAL (STATEMENT);
         IF FEAR GREATERP 14 THEN FEARMODE ()
         ELSE
         IF ANGER GREATERP 14 THEN ANGERMODE ()
         ELSE
         IF DELFLAG THEN DELTALK (STATEMENT)
         ELSE
            PROMPT (STATEMENT);

          %
PERSREL      %

      EXPR PERSREL (INP);
         IYOUME (INP) OR APOLOG (INP) OR THREAT (INP);

          %
SELFREF     SCANS THE INPUT SENTENCE FOR DIRECT OR INDIRECT REFERENCE TO THE SENSITIVE
            AREAS OF 'SELF AND CALLS FOR THE APPROPRIATE REPLY.  IF NO SELF-REFERENCE
            IS PERCEIVED, NIL IS RETURNED.     %

      EXPR  SELFREF (INP);
         BEGIN
            NEW YOU, NEG, FOUND, ADJ, CONCEPT, WORD;

                     %   CHECK FOR DIRECT REFERENCE TO 'SELF   %

               IF ('YOU MEMBER INP) OR ('YOUR MEMBER INP) OR ('YOU?'RE MEMBER INP) THEN YOU←T;

                     %   CHECK FOR EXPLICIT NEGATORS   %

               IF MEMBER1 (NLIST, INP) THEN NEG←T;

                     %   CHECK FOR GENERAL INSULTS OR COMPLIMENTS   %

               FOR WORD IN INP DO

                     %   CHECK 'YOU-NEGATION-INSULT' COMBINATIONS   %

               FOUND←IF WORD MEMBER GET ('INSULT, 'IND) THEN
                        IF YOU THEN 
                           IF NOT NEG THEN PROG2 (AJUMP←0.8, CHOOSE ('ANGER))
                           ELSE
                              PROG2 (IF MISTRUST GREATERP 9 THEN AJUMP←0.2, CHOOSE ('DISTANCE))
                        ELSE PROG2 (AJUMP←0.3, CHOOSE ('PERS))
                     ELSE

                           %   CHECK 'YOU-NEGATION-COMPLIMENT' COMBINATIONS   %

                     IF WORD MEMBER GET ('COMPL, 'IND) THEN
                        IF YOU THEN
                           IF NOT NEG THEN
                              PROG2 (IF MISTRUST GREATERP 9 THEN AJUMP←0.2,
                                                 CHOOSE ('DISTANCE))
                           ELSE
                              PROG2 (AJUMP←0.7, CHOOSE ('HOSTILEREPLIES))
                        ELSE PROG2 (AJUMP←0.5, CHOOSE ('SENSREPLIES) @ (WORD CONS '(??)))
               UNTIL FOUND;

               IF FOUND THEN RETURN (PROG2 (SAY (FOUND), T));

                     %   CHECK FOR POSITIVE OR NEGATIVE REFERENCE TO 'SELF IN SENSITIVE AREA   %

               ADJ←ADJTYPE (INP);      %   DETERMINE PRESENCE OF POS OR NEG ADJECTIVE   %
               FOR WORD IN INP DO

                     %   'SPECIAL DENOTES PERSONAL SENSITIVE AREA, E.G. APPEARANCE   %

               IF (CONCEPT←GET (WORD, 'SET)) MEMBER SENSITIVELIST THEN
                  FOUND←IF (NOT GET (CONCEPT, 'SPECIAL)) AND (CAR (INP) EQ 'Q) AND YOU THEN
                     PROG2 (AJUMP←0.2, ANSWER (INP))
                        ELSE
                        IF YOU AND (GET (ADJ, 'TYPE) EQ 'NEG) THEN
                           IF NOT NEG THEN
                              PROG2 (AJUMP←0.7, CHOOSE ('HOSTILEREPLIES))
                           ELSE
                              PROG2 (IF MISTRUST GREATERP 9 THEN AJUMP←0.3, CHOOSE ('DISTANCE))
                        ELSE
                        IF YOU AND (GET (ADJ, 'TYPE) EQ 'POS) THEN
                           IF NOT NEG THEN
                              PROG2 (IF MISTRUST GREATERP 9 THEN AJUMP←0.3,
                                  CHOOSE ('DISTANCE))
                           ELSE 
                              PROG2 (AJUMP←0.7, CHOOSE ('HOSTILEREPLIES))
                        ELSE
                        IF YOU AND (GET (CONCEPT, 'SPECIAL) OR GET (ADJ, 'TYPE)) THEN
                           BEGIN
			   AJUMP←0.5;
			   CONCEPT←<CONCEPT>;
			   RETURN (CHOOSE ('DEFENSREPLIES) @ CONCEPT);
			   END
                        ELSE
                        IF GET (ADJ,'TYPE) THEN
                           PROG2 (AJUMP←0.5, SELFREFREPLY (ADJ, WORD))
                        ELSE
                        IF GET (CONCEPT, 'SPECIAL) THEN
                           PROG2 (AJUMP←0.4, CHOOSE ('PERS))
                        ELSE
                           BEGIN
			   AJUMP←0.2;
			   CONCEPT← <CONCEPT>;
			   RETURN (CHOOSE ('GUARD) @ CONCEPT);
			   END
                     ELSE NIL
               UNTIL FOUND;
            IF FOUND THEN RETURN (PROG2 (SAY (FOUND), T));
         END;

                  %   'TALK' ROUTINES FOR TWO TELETYPES   %


FEXPR OUT (L);			% L = (DESTINATION  FUNCTION  OPEN  CLOSE) %
   IF L[1] EQ 'DOC THEN SEND_MAIL('DOCJOB, L[2]) ELSE
   IF L[1] EQ 'OWN THEN EVAL L[2]
   ELSE BEGIN
      IF LENGTH L ≥ 3 & L[3] THEN EVAL <'OUTPUT, 'DSK:, EVAL L[1]>;
      OUTC(T, NIL);
      EVAL L[2];
      OUTC(NIL, IF LENGTH L = 4 THEN L[4] ELSE NIL);
   END;

FEXPR INP (L);			% L = (SOURCE  FUNCTION) %
   IF L[1] EQ 'DOC THEN SEND_MAIL('DOCJOB, <'SEND_MAIL, '(QUOTE HAR000), L[2]>) ALSO WAIT_FOR_MAIL(L[3])
   ELSE EVAL L[2];

EXPR READ_MESSAGE ();
   BEGIN  NEW L;
      PRINTSTR "READY:";
      TERPRI TERPRI DO NIL UNTIL CAR(L ← READCH() CONS L) EQ ALTMODE & CADR L EQ ALTMODE;
      RETURN REVERSE CDDR L
   END;

EXPR PRINT_MESSAGE (MESSAGE);	TERPRI TERPRI FOR NEW CH IN MESSAGE DO PRINC CH;

EXPR PRINT_ALL (FILE);				% COPIES FILE "FILE" TO THE CURRENTLY OPEN OUTPUT FILE. %
   BEGIN  NEW CH;
      EVAL <'INC, <'INPUT, FILE, 'DSK:, FILE>, NIL>;
      DO NIL UNTIL TYO TYI() EQ OCTAL 45 & (ATOM(CH ← ERRSET(READCH(),T))  |  PRINC CAR CH & NIL);
      INC(NIL,T)
   END;
     

00100
%             *****   AUXILIARY FUNCTIONS   *****          %


         %
ADJTYPE    RETURNS AND TRIES TO IDENTIFY ANY VALUE-TYPE MODIFIERS IN STATEMENT   %

                  %   TO BE REWRITTEN   %

      EXPR ADJTYPE (STMT);
         BEGIN
            NEW WORD, TYPE, FOUND;
            FOR WORD IN STMT DO
               FOR TYPE IN '(POS NEG AMBIG) DO
                  IF WORD MEMBER GET ('ADJLIST, TYPE) THEN
                     FOUND←PROG2 (PUTPROP (WORD, TYPE, 'TYPE), WORD)
               UNTIL FOUND
            UNTIL FOUND;
            RETURN (WORD);
         END;

          %
ANSVAR      ALTERNATIVELY SELECTS ONE OF TWO VARIANTS OF AN ANSWER   %

      EXPR ANSVAR (KEYWD);
         BEGIN
            NEW A;
            IF NULL A←GET (KEYWD, 'A) THEN RETURN
               IF FLARE EQ 'INIT THEN CHOOSE ('EXHAUST)
               ELSE FLSTMT (GET (FLARE, 'SET))
            ELSE
            IF NOT ATOM CAR A THEN

                  %   'A' CONSISTS OF A LIST OF 2 ANSWERS: ((---)(---))
                      RATHER THAN OF AN ANSWER: (---)   %

               RETURN CHOOSE (KEYWD CONS 'A)
            ELSE RETURN A;
         END;

          %
ANSWER     HANDLES QUESTIONS OF 'OTHER:
            IF NO RECOGNIZED TOPIC ABOUT 'SELF IS BEING CONTINUED AND NO REFERENCE
            TO 'SELF IS DETECTED, THE QUESTION IS TREATED AS MISCELLANEOUS;
            OTHERWISE AN ANSWER TO THE QUESTION IS ATTEMPTED   %

      EXPR ANSWER (Q);
         BEGIN
            NEW ANS, WORD, CONCEPT;

            SPECIAL ANS, QWORD;

            %   "INTERROGATIVE IMPERATIVES" ARE CONSIDERED AS QUESTIONS ABOUT 'SELF   %

            IF ('TELL MEMBER Q) THEN
               Q←('Q CONS 'YOU CONS Q)
            ELSE

                  %   STATEMENTS THAT THE 'OTHER HAS A QUESTION ARE CONSIDERED AS QUESTIONS   %

            IF MEMBER1 (GET ('QUES, 'IND), Q) THEN
               Q←'Q CONS 'QUESTION CONS Q
               ;

                  %   IF INPUT IS A QUESTION AND NO TOPIC IS CURRENTLY UNDER DISCUSSION
                      AND INPUT REFERS TO SELF, EXPECT ONLY QUESTIONS RELATING
                      TO A MAIN "SELF-TOPIC"   %

            IF CAR Q EQ 'Q AND QWORD EQ 'INTROTOP AND ('YOU MEMBER Q OR 'YOUR MEMBER Q) THEN
               ANS←ANSWER1 (Q, GET ('INTROTOP, 'Q))
            ELSE

                  %   IF ALREADY ON SOME TOPIC, CHECK FIRST FOR NEW MAIN TOPIC,
                      THEN FOR FOLLOW-UP TO LAST SUBTOPIC, THEN (UNLESS SUBTOPIC =
                      MAIN TOPIC) FOR FOLLOW-UP TO LAST MAIN TOPIC   %

            IF QWORD NEQ 'INTROTOP THEN
                (IF MEMBER1 ('(YOU YOUR), Q)   THEN ANS←ANSWER1 (Q, GET ('INTROTOP, 'Q))) OR (ANS←ANSWER2 (Q)) OR
                   IF QWORD NEQ LASTTOP THEN ANS←PROG2 (QWORD←LASTTOP, ANSWER2 (Q))
               ;
            IF NOT ANS THEN

                  %   NO QUESTIONS RECOGNIZED   %

            BEGIN
               ANS←IF CAR Q EQ 'Q THEN MISCQ (Q) ELSE MISCS (Q);

                     %   REINITIALIZE TOPIC INDICATORS   %

               LASTTOP←QWORD←'INTROTOP;
            END;
            ASCAN (ANS, Q);
            RETURN (ANS);
         END;
          %
ANSWER1     %

      EXPR ANSWER1 (Q, TOPICS);
         BEGIN
            NEW CONCEPT, SPEC, ANS;
            SPECIAL ANS, QWORD;
            %   TRY TO MATCH WORDS OF QUESTION WITH ONE OF THE SELF-TOPICS   %

               FOR CONCEPT IN TOPICS DO
                  IF MEMBER1 (CONCEPT, Q) THEN
                  BEGIN

                     %   CHECK FOR SPECIFIC QUESTION ABOUT TOPIC
                         MENTIONED IN THIS SENTENCE   %

                        FOR SPEC IN GET (LASTTOP←CAR (CONCEPT), 'Q) DO
                           IF MEMBER1 (SPEC, Q) THEN      %   QUESTION ABOUT MAIN TOPIC RECOGNIZED   %
                                  ANS←ANSVAR (QWORD←CAR SPEC)
                        UNTIL ANS;
                        
                     IF NOT ANS THEN

                           %   NO SPECIFIC QUESTION ABOUT THIS MAIN TOPIC RECOGNIZED   %

                     BEGIN

                        %   SAVE TOPIC KEY WORD   %

                        QWORD←CAR (CONCEPT);

                        %   GET ANSWER ASSCIATED WITH TOPIC KEY WORD   %

                        ANS←ANSVAR (QWORD);
                     END;
                  END
                  UNTIL ANS;
               RETURN (ANS);
         END;
          %
ANSWER2     %

      EXPR ANSWER2 (Q);
         BEGIN
            NEW CONCEPT, ANS;
            SPECIAL QWORD;

            %   CHECK FOR SPECIFIC QUESTION ABOUT TOPIC
                MENTIONED IN THE PRECEDING SENTENCE   %

                  FOR CONCEPT IN GET (QWORD, 'Q) DO
                     IF MEMBER1 (CONCEPT, Q) THEN
                        ANS←ANSVAR (QWORD←CAR CONCEPT)
                  UNTIL ANS;
            RETURN (ANS);
         END;

          %
APOLOG      RESPONDS DIFFERENTIALLY TO APOLOGIES ACCORDING TO MISTRUST LEVEL   %

      EXPR APOLOG (STMT);
         IF MEMBER1 (GET ('APOL, 'IND), STMT) THEN
         BEGIN
            IF MISTRUST GREATERP 9 THEN
               AJUMP←0.2
            ELSE ANGER ← ANGER-1;
            SAY (CHOOSE ('ACCUSE));
            RETURN (T);
         END;

          %
ASCAN       SCANS 'SELF'S ANSWER FOR MENTION OF FLARE OR MAFIA   %

      EXPR ASCAN (ANS, Q);
               BEGIN
                  IF CHECKFLARE (ANS, LIVEFLARES) THEN FLMOD (GET (FLARE, 'SET));
                  IF 'MAFIA MEMBER ANS THEN 
                  BEGIN
                     DELFLAG←T;
                     FLARE←'INIT;
                  END;
               END;

          %
BADINP   %
    
      EXPR BADINP (SENT);
         BEGIN
            TERPRI NIL;
            IF '?: ε SENT THEN
               RETURN (PROG2 (PRINTSTR (STRINGATE (SENT)), T));
         END;

         %
BLANKSKIP  RETURNS THAT PART OF SENTENCE FOLLOWING ANY SEQUENCE OF LEADING BLANKS, 
           CARRIAGE RETURNS OR LINE FEEDS   %

      EXPR BLANKSKIP (SENT);
         IF NULL SENT THEN NIL
         ELSE
         IF CAR SENT EQ BLANK OR CAR SENT EQ CR OR CAR SENT EQ LF THEN BLANKSKIP (CDR SENT)
         ELSE SENT;

          %
CHOOSE      SELECTS THE NEXT REPLY FROM THE RELEVANT GROUP   %

      EXPR  CHOOSE (REPLIES);
         BEGIN
            NEW  REPLY, RESPONSES, IND;
            SPECIAL ENDE;
            IF NOT ATOM REPLIES THEN
            BEGIN
               IND←CDR REPLIES;
               REPLIES←CAR REPLIES;
            END
            ELSE IND←'IND;
            IF NULL RESPONSES←GET (REPLIES, IND) THEN
               RETURN
                  IF REPLIES EQ 'EXHAUST THEN PROG2 (ENDE←T, '((FED UP)) ) 
                  ELSE  PROG2(CONCEPT←NIL, CHOOSE ('EXHAUST));
            REPLY←CAR RESPONSES;
            PUTPROP (REPLIES, CDR RESPONSES, IND);
            RETURN REPLY;
         END;

          %
CHOOSEDEL   CHOOSES A DELUSIONAL RESPONSE ACCORDING TO "TYPE", WHICH INDICATES
            WHETHER THE NEXT GENERAL DELUSION IS TO BE SELECTED (TYPE=NUMBER)
            OR A CERTAIN TYPE OF QUESTION IS TO BE ANSWERED   %

      EXPR CHOOSEDEL (TYPE);
         BEGIN
            NEW DEL, REPLY, FREQ, OLDF;
            IF NUMBERP (TYPE) THEN
               DEL←AT ('DEL CAT TYPE)
            ELSE DEL←TYPE;
            REPLY←IF (OLDF←GET (DEL, 'FREQ)) LESSP 3 THEN
                  BEGIN
                     NEW DELN;

                           %   RAISE FREQUENCY   %

                     PUTPROP (DEL, FREQ←OLDF+1, 'FREQ);
                     DELN←CAR (SUFLIST (GET ('DELUSIONS, DEL), FREQ-1));
                     RETURN (IF (TYPE = 1) OR (TYPE = 4) THEN   %   FOR VARIATION ONLY   %
                                GET ('PREFACE, GET (DEL, 'FREQ)) @ DELN
                             ELSE DELN);
                  END
                  ELSE
                     %   'SELF HAS MENTIONED THIS DELUSION 3 TIMES   %
                  BEGIN
                     DELFLAG←NIL;
                     DELEND←T;      %   DELUSION-END FLAG   %
                     RETURN ('(LET?'S TALK ABOUT SOMETHING ELSE?- I?'VE GIVEN
                               YOU SOME IDEA OF WHAT?'S GOING ON));
                  END;
                  RETURN (REPLY);
         END;

          %
DELCHECK    RETURNS ANY NEW DELUSION-EXPRESSIONS FOUND IN INPUT AND DELETES AS SUCH   %

      EXPR DELCHECK (INP);
         BEGIN
            NEW WORDS;
 
                  %   CHECK FOR STRONG DELUSION-NOUNS AND -VERBS
                      (AT PRESENT THE NOUN-VERB DISTINCTION IS NOT UTILIZED   %

            IF WORDS←MEMBER1 (DELNLIST, INP) THEN
               DELNLIST←DELETE (WORDS, DELNLIST)
            ELSE
            IF WORDS←MEMBER1 (DELVLIST, INP) THEN
               DELVLIST←DELETE (WORDS, DELVLIST)
            ELSE

                  %   CHECK FOR AMBIGUOUS DELUSION WORDS AT HIGH MISTRUST LEVEL  %

            IF MISTRUST GREATERP 10 AND WORDS←MEMBER1 (DELALIST, INP) THEN
               DELALIST←DELETE (WORDS, DELALIST)
               ;
            RETURN (IF WORDS AND ATOM WORDS THEN WORDS CONS NIL ELSE WORDS);
         END;


          %
DELETE      DELETES WORD WD FROM LIST L   %

      EXPR DELETE (WD, L);
         IF NULL L THEN NIL
         ELSE
         IF WD EQ CAR (L) THEN CDR (L)
         ELSE CAR (L) CONS DELETE (WD, CDR (L));

          %
DISTRUST    HANDLES FOLLOW-UPS TO LOCAL SITUATIONS OF DISTRUST   %

      EXPR DISTRUST ();
         IF (FEAR GREATERP 10) OR (ANGER GREATERP 10) OR
            ((FEAR + ANGER) GREATERP 14) THEN
            CHOOSE ('TURNOFF)
         ELSE CHOOSE ('ALOOF);

          %
FIXPTRS     TRANSFERS HIERARCHICAL POINTERS TO NEW FLARE
            TO NEXT HIGHER FLARE IN PATH   %

      EXPR FIXPTRS (FLSET);
         BEGIN
            NEW CONCEPT;
            FOR CONCEPT IN LIVEFLARES @ DEADFLARES DO
               IF GET (CONCEPT, 'NEXT) EQ FLSET THEN
                  PUTPROP (CONCEPT, GET (FLSET, 'NEXT), 'NEXT);
         END;
  
          %
FLRECORD    NOTES MENTION OF FLARE AND RAISES FEAR   %

      EXPR FLRECORD (FLSET);
         BEGIN
            FLMOD (FLSET);
            FJUMP←WEIGHT/40.0;

                  %   REINITIALIZE SELF-TOPIC INDICATORS   %

            LASTTOP←QWORD←'INTROTOP;
         END;

          %
FLMOD       MOVES NEW FLARE FROM "LIVELIST" TO "DEADLIST" AND
            ADJUSTS FLARE POINTER HIERARCHY   %

      EXPR FLMOD (FLSET);
         BEGIN
            LIVEFLARES←DELETE (FLSET, LIVEFLARES);
            DEADFLARES←(FLSET CONS DEADFLARES);
            FIXPTRS (FLSET);
         END;

          %
FLARELEAD DECIDES WHAT TYPE OF "SUSPICIOUSNESS" REPLY IS SUITED
             TO INTRODUCE THE FLARE CONCEPT   %
      
      EXPR  FLARELEAD (FLSET);
         BEGIN
            IF GET (FLSET, 'TYPE) EQ 'INSTITUTION THEN
               RETURN (CHOOSE ('NEXTFL) @ '(THE) @
                  <CAR (GET (FLSET, 'WORDS))>)
            ELSE
               RETURN (CHOOSE ('NEXTFL) @

                        %   DO NOT TREAT SINGULARS AS A GENERIC TOPIC   %

                  (IF CAR (LAST (EXPLODE (FLARE))) EQ 'S THEN <FLARE>
                   ELSE <CAR (GET (FLSET, 'WORDS))>)
                  );
         END;

          %
FLSTMT      PROVIDES NEXT STATEMENT ABOUT FLARE   %

      EXPR FLSTMT (FSET);

                  %   IF REACH 'MAFIASET THRU FLARE HIERARCHY, ENTER DELUSIONAL MODE   %

            IF (FSET EQ 'MAFIASET) AND NOT DELEND THEN
               PROG2 (DELFLAG←T, DELSTMT ())
            ELSE
            IF (NREF←GET (FSET, 'NREF)) LESSP 2 THEN
            BEGIN
               PUTPROP (FSET, NREF←(NREF+1), 'NREF);

                     %   MAKE NEXT STATEMENT ABOUT CURRENT FLARE TOPIC   %

               RETURN (CAR (SUFLIST (GET (FSET, 'STMTS), NREF-1)));
            END

                   %   GO TO NEXT FLARE TOPIC   %

            ELSE LEADON (GET (FSET, 'NEXT))
         ;
          
          %
JOIN        INSERTS HYPHENS BETWEEN WORDS OF ONE CONCEPT TO 
            MAKE ONE ATOM   %
      
      EXPR JOIN (!L);   READLIST(EXPLODEC(CAR(!L)) @ JOIN1(CDR(!L)));
      
      EXPR JOIN1 (!L);   IF NULL !L THEN NIL ELSE DASH CONS EXPLODEC(CAR(!L)) @ JOIN1(CDR(!L));

          %
LEADON      %

      EXPR LEADON (NEWSET);
         BEGIN
            IF NEWSET NEQ 'MAFIASET THEN

                  %   RECORD NEW FLARE   %

            BEGIN
               FLMOD (NEWSET);
               FLARE←CAR (GET (NEWSET, 'WORDS));
            END
            ELSE
            IF DELEND THEN

                     %   ARRIVE AT 'MAFIASET BUT THROUGH WITH DELUSIONS   %

               RETURN (PROG2 (FLARE←'INIT, CHOOSE ('FEELER)))
            ELSE
            IF WEAK OR (FEAR GREATERP 12) OR (ANGER GREATERP 12) OR
               ((FEAR + ANGER + MISTRUST) GREATERP 20) THEN

                     %   ARRIVED AT 'MAFIASET BUT DOES NOT HAVE DELUSIONS ABOUT
                         MAFIA OR IS UNWILLING TO DISCUSS THEM   %

               RETURN (CHOOSE ('CHANGESUBJ))
            ELSE
            BEGIN
               DELETE ('MAFIA, DELNLIST);
               DELFLAG←T;
               FLARE←'INIT;
            END;

                  %   RESPOND WITH NEW FLARE   %

            RETURN (FLARELEAD (NEWSET)); 
         END;

          %
MEMBER1     CHECKS WHETHER ATOMS OR GROUPS OF WORDS IN WLIST ARE PRESENT IN INPUT   %

      EXPR MEMBER1 (WLIST, SPECIAL INP);
         BEGIN
            NEW FOUND, GROUP;
            FOR GROUP IN WLIST DO
               FOUND←IF ATOM (GROUP) THEN GROUP MEMBER INP
                     ELSE
                  EVAL ('AND CONS MAPCAR (FUNCTION (LAMBDA (X); X MEMBER INP), GROUP))
               UNTIL FOUND;
            IF FOUND THEN RETURN GROUP;
         END;
    
          %
MISCQ       TRIES TO DETECT AND ANSWER CERTAIN RECOGNIZABLE QUESTIONS.
            IF IT FAILS, IT TRIES TO DISCERN WHETHER THE QUESTION CONTAINS
            INTERROGATIVE WORDS REQUIRING A SPECIFIC ANSWER, OR WHETHER IT
            REQUIRES A GENERAL YES- OR NO-TYPE ANSWER, 
            AND CALLS FOR AN APPROPRIATE REPLY   %

      EXPR MISCQ (Q);
         BEGIN
            NEW QWORD, ANS, CONCEPT;
            IF SUFLIST (Q, LENGTH Q - 3) = '(HOW ARE YOU) THEN ANS←'(ALL RIGHT)
            ELSE

                  %  INTERPERSONAL  ATTITUDE MAY HAVE BEEN SET IN IYOUME IN CONTEXT OF 'YOU <ATTITUDE>'   %

            IF INTERPERS THEN RETURN PROG2 (INTERPERS←NIL,
               IF MEMBER1 (GET ('QLIST, 'IND), Q) THEN CHOOSE ('WFEEL)
               ELSE CHOOSE ('QFEEL)   )
            ELSE

                  %   CHECK FOR QUESTION ABOUT EXTERNAL WORLD   %

            IF NOT (ANS←OBJQ (Q)) THEN
               IF 'HOW MEMBER Q THEN

                        %   UNIDENTIFIABLE "HOW-TYPE" QUESTION   %

                  FOR CONCEPT IN '(MANY MUCH LONG OFTEN) DO
                     IF CONCEPT MEMBER Q THEN ANS←CHOOSE (CONCEPT)
                  UNTIL ANS;
            IF ANS THEN RETURN (ANS)
            ELSE

                  %   IF QUESTION NOT RECOGNIZED, TRY TO ANSWER ACCORDING TO CONTEXT   %

          IF FLARE NEQ 'INIT THEN RETURN FLSTMT (GET (FLARE, 'SET))
          ELSE
          IF DELFLAG THEN RETURN DELSTMT ()
          ELSE

                  %   WH- QUESTIONS   %

            IF 'WHY MEMBER Q THEN ANS←CHOOSE ('WHY)
            ELSE
            FOR QWORD IN GET ('QLIST, 'IND) DO
            (ANS←   IF QWORD MEMBER Q THEN CHOOSE ('UNKNOWN))
               UNTIL ANS;
            IF ANS THEN RETURN (ANS)
            ELSE

                  %   MISCELLANEOUS "TELL-" QUESTION   %

            IF ('TELL MEMBER Q)  THEN RETURN '(I DON?'T KNOW ANYTHING ABOUT THAT)
            ELSE

                  %   NO CLUES - ANSWER NONCOMMITTALLY   %

            RETURN (CHOOSE ('QREPLIES));
         END;

          %
MISCS        TRIES TO DETECT AND ANSWER CERTAIN RECOGNIZABLE STATEMENTS,
             MAINLY IMPERATIVES AND EXPECTED EXPRESSIONS   %

      EXPR MISCS (S);
         IF ('JUMP MEMBER S) THEN '((EXITS))
         ELSE
         IF (CAR (S) EQ 'HI) OR (CAR (S) EQ 'HELLO) OR (CAR (S) EQ 'HOWDY) OR 
            CADR S MEMBER '(MORNING AFTERNOON EVENING) THEN '(HELLO)
         ELSE
         IF (('AM MEMBER S) AND ('DOCTOR MEMBER S) OR ('DR MEMBER S)) OR
            (('MY MEMBER S) AND ('NAME MEMBER S)) THEN
            '(GLAD TO MEET YOU)
         ELSE
         IF (('ALREADY MEMBER S) OR ('BEFORE MEMBER S)) AND
             (('SAID MEMBER S) OR ('MENTIONED MEMBER S)) THEN
                 '(I GUESS I DID)
         ELSE

               %   LOOK AT CONTEXT OF CONVERSATION   %

         IF FLARE NEQ 'INIT THEN FLSTMT (GET (FLARE, 'SET))
         ELSE
         IF DELFLAG THEN DELSTMT ()

               %   NONCOMMITTAL REPLY  %

         ELSE CHOOSE ('SREPLIES);

          %
MODIFVAR    MODIFIES AFFECT VARIABLES AFTER EACH I-O PAIR   %

      EXPR MODIFVAR ();
         BEGIN
            RAISE ();

                  %   ACCOUNT FOR NORMAL DROP IN EACH VARIABLE   %

            ANGER←IF ANGER GREATERP ANGER0 + 1 THEN ANGER - 1 ELSE ANGER0;
            IF DELFLAG THEN

                     %   ADD 5 TO BASE VALUE OF FEAR IF DELUSIONS UNDER DISCUSSION   %

               FEAR←IF FEAR GREATERP FEAR0 + 5.1 THEN FEAR - 0.1 ELSE FEAR0 + 5
            ELSE
            IF FLARE NEQ 'INIT THEN

                     %   ADD 3 TO BASE VALUE OF FEAR IF FLARES UNDER DISCUSSION   %


               FEAR←IF FEAR GREATERP FEAR0 + 3.2 THEN FEAR - 0.2 ELSE FEAR0 + 3
            ELSE
               FEAR←IF FEAR GREATERP FEAR0 + 0.3 THEN FEAR - 0.3 ELSE FEAR0;
            MISTRUST←IF MISTRUST GREATERP MISTRUST0+0.05 THEN MISTRUST - 0.05 ELSE MISTRUST0;
      IF TRACEV THEN

            %   PRINT OUT VALUES OF VARIABLES   %

      BEGIN
         TERPRI NIL;
         PRINTSTR ("      FEAR = " CAT FEAR);
         PRINTSTR ("      ANGER = " CAT ANGER);
         PRINTSTR ("      MISTRUST = " CAT MISTRUST);
      END;
            TERPRI NIL;
         END;

          %
NULLSKIP   RETURNS THAT PART OF SENT FOLLOWYNG AN SEQUENCE OF
           BLANKS, CARRIAGE RETURNS, LINE FEEDS, COMMAS OR DASHES   %

      EXPR NULLSKIP (SENT);
         IF (CHAR←CAR SENT)  EQ BLANK OR (CHAR EQ CR) OR (CHAR EQ LF) OR (CHAR EQ COMMA) OR (CHAR EQ DASH) THEN
            NULLSKIP (CDR SENT)
         ELSE SENT;

          %
OBJQ        HANDLES "OBJECTIVE"-TYPE QUESTIONS
            (ABOUT LOCAL EXTERNAL WORLD)      %

      EXPR OBJQ (Q);
         BEGIN
            NEW PAIR, FOUND;
            IF (('WHAT MEMBER Q) OR ('WHO MEMBER Q) OR ('WHICH MEMBER Q)) AND
               FOR PAIR IN GET ('OBJDATA, 'IND) DO
                  FOUND←IF <CAR (PAIR)> MEMBER1 Q THEN CADR (PAIR)
               UNTIL FOUND   THEN
               RETURN (FOUND);
         END;

          %
PROMPT      HANDLES "TELL-ABOUT-YOURSELF" QUESTIONS   %

            %   TO BE REWRITTEN (KEN REWROTE THIS 11/4/71)  %


      EXPR PROMPT (INP);
         IF MEMBER1 (GET ('DISCUSS, 'IND), INP) AND MEMBER1 (GET ('SELF, 'IND), INP) THEN
         BEGIN
            NEW ANS;
               INP←'TELL CONS INP;
            SAY (ANS←ANSWER1 (INP, GET ('INTROTOP, 'Q)));
            ASCAN (ANS, INP);
         END
         ELSE SAY (ANSWER (INP));

          %
QTHREAT     RESPONDS SUSPICIOUSLY TO QUESTIONS AT HIGH FEAR LEVEL   %

      EXPR QTHREAT (STMT);
         IF CAR (STMT) EQ 'Q THEN PROG2 (SAY (CHOOSE ('THREATQ)), T)
        ;

          %
RAISE        RAISES LEVEL OF RELEVANT AFFECT VARIABLES;
             REDUCE JUMP IF IN WEAK VERSION   %

      EXPR RAISE ();
         BEGIN
            IF FJUMP THEN
            BEGIN
               IF WEAK THEN FJUMP←0.3 * FJUMP;
               FEAR ← (FEAR + FJUMP * (20 - FEAR));
               MISTRUST ← (MISTRUST + (0.5 * FJUMP) * (20 - MISTRUST));
               MISTRUST0←MISTRUST0 + 0.1 * FJUMP * (20 - MISTRUST0);
               FJUMP←NIL;
            END;
            IF AJUMP THEN
            BEGIN
               IF WEAK THEN AJUMP←0.7 * AJUMP;
               ANGER ← (ANGER + AJUMP * (20 - ANGER));
               MISTRUST ← (MISTRUST + (0.5 * AJUMP) * (20 - MISTRUST));
               MISTRUST0←MISTRUST0 + 0.1 * AJUMP * (20 - MISTRUST0);
               AJUMP←NIL;
            END;
         END
         ;

          %
READSENT    RETURNS SCANNED SENTENCE IN THE FORM OF A LIST OF WORDS   %

    
      EXPR READSENT (SENT);

               %   SENT IS A LIST OF INPUT CHARACTERS   %

         BEGIN
            NEW CHAR;
            TERMIN←NIL;

                  %   SKIP OVER LEADING CHARACTERS WHICH AREN'T LETTERS OR NUMBERS   %

            WHILE NOT (GET (CHAR←CAR SENT, 'LET) OR NUMBERP CHAR OR NULL SENT) DO SENT←CDR SENT;
            IF NULL SENT THEN TERMIN←'ILL
            ELSE RETURN READSENT1 (SCANWD (BLANKSKIP (SENT)));
         END;

          %
READSENT1   ASSEMBLES REMAINDER OF SENTENCE STARTING AT BEGINNING OF NEXT WORD   %


      EXPR READSENT1 (WORD);

               %   WORD IS A LIST OF CHARACTERS COMPRISING 1 WORD AS DETERMINED BY SCANWD   %

         IF TERMIN THEN PROG2 (RESTSENT←NIL, IF TERMIN EQ 'ILL THEN NIL
                                             ELSE
                                             IF NULL WORD THEN NIL
                                             ELSE <READLIST (WORD)>)
         ELSE READLIST (WORD) CONS READSENT1 (SCANWD (RESTSENT));

          %
RTPAR       ELIMINATES LEADING PARENTHETICAL EXPRESSIONS FROM 'S'   %


      EXPR RTPAR (S, LENG);
         BEGIN
            NEW N;
            FOR N←1 TO LENG DO NIL
            UNTIL SUBSTR (S, N, 1) SEQ ")";
            RETURN (SUBSTR (S, N+1, 'ALL));
         END;

          %
SAY         HANDLES OUTPUT OF LIST 'STMT'   %

      EXPR SAY (STMT);
         BEGIN
            NEW ESTMT;
            STMT←STRINGATE (STMT);

                  %   IN "SUPPRESS" OR "TALK" VERSION, ELIMINATE LEADING PARENTHETICAL EXPRESSIONS   %

            IF (SUPPRESS OR TALK) AND CAR (ESTMT←EXPLODEC STMT) EQ '?( THEN
               STMT←RTPAR (STMT, LENGTH ESTMT);
            OUT (OWN, PRINTSTR STMT);
            IF TALK THEN
            BEGIN  NEW VALUES;   SPECIAL VALUES;
               OUT (FILE1, PRINTSTR STMT);
	       VALUES ← EVAL <'INP, 'DOC,
		  <'PROG, '(X),
			  <'PRINTSTR, <'QUOTE, AT STMT>>,
			  '(PRINT (QUOTE RESPONSE:)),
			  '(CLEAR_BUFFER),
			  '(SETQ X (READ)),
			  '(PRINT (QUOTE PATIENT:)),
			  '(CLEAR_BUFFER),
			  '(RETURN (LIST (QUOTE RESPONSE) X (QUOTE PATIENT) (TERPRI (TERPRI (READ)))))>, T>;
	       OUT(FILE1, PROG2(PRINT VALUES, PRINC TERPRI EOF), NIL, T);
	       SAVEJOB('HAR000,'SAV);	% SAVE THE CORE IMAGE UNDER HAR000.SAV IN CASE THE SYSTEM GOES DOWN. %

	% THIS IS THE POINT AT WHICH THE PROGRAM WILL START IF THE SYSTEM GOES DOWN. %
               '(FILE1 FILE2) ←⊗ <FILE2, FILE1>;
               OUT (FILE1, PRINT_ALL FILE2, T)
            END
            ELSE IF SAVE_FILE THEN
               BEGIN
               OUT(FILE1, PRINTSTR STMT);
               OUT(FILE1, PRINC TERPRI EOF, NIL, T);
               '(FILE1 FILE2) ←⊗ <FILE2, FILE1>;
               OUT(FILE1, PRINT_ALL FILE2,T)
               END
         END;

          %
SCANWD      RETURNS NEXT WORD IN SENT AS LIST OF CHARACTERS   %
   
      EXPR SCANWD (SENT);
         BEGIN
            NEW CHAR;
         RETURN
            IF (CHAR←CAR SENT) EQ PERIOD OR CHAR EQ '?? THEN

                     %   ILLEGAL FOR TERMINATOR TO BE FOLLOWED BY OTHER CHARACTERS   %

               PROG2 (TERMIN←IF NOT BLANKSKIP (CDR SENT) THEN CHAR ELSE 'ILL, NIL)
            ELSE
            IF CHAR EQ  BLANK OR CHAR EQ CR  OR CHAR EQ COMMA OR CHAR EQ DASH THEN
               PROG2 (RESTSENT←NULLSKIP (SENT), NIL)
            ELSE
            IF NUMBERP (CHAR) OR GET (CHAR, 'LET) THEN
               CHAR CONS SCANWD (CDR SENT)
            ELSE PROG2 (TERMIN←'ILL, NIL);
         END;
      
          %
SELFREFREPLY INTRODUCES VARIATION INTO CHOSEN "SENSITIVE" REPLY   %

      EXPR  SELFREFREPLY (ADJ, NOUN);
         BEGIN
            NEW REPLY;
            FLAG←NOT (FLAG);
            REPLY←CHOOSE ('SENSREPLIES) @
               (IF FLAG THEN <ADJ> ELSE <ADJ, NOUN>)
               @ '(??);
            RETURN (REPLY);
         END;

          %
SENTYPE     SETS UP TYPE OF SENTENCE (STATEMENT, QUESTION, ILLEGAL)
            TO RETURN FOR PROCESSING   %


      EXPR SENTYPE (SENT);
         IF TERMIN EQ 'ILL THEN '(: BAD INPUT?; TRY AGAIN?.)
         ELSE
         IF TERMIN = '?? THEN 'Q CONS SENT ELSE SENT;

          %
SPECQUES    PROVIDES ANSWERS TO SPECIFIC QUESTIONS RELATED TO THE
                    DELUSIONAL COMPLEX   %

            %  TO BE REWRITTEN   %

      EXPR  SPECQUES (INP);
         BEGIN
            NEW WORD, WD, FOUND, QA, PAIR, VALUE;
            QA←GET ('ANSWERS, LASTSTMT);
            IF QA THEN
               FOR PAIR IN QA DO
                  FOUND←MEMBER1 (CAR (PAIR), INP)
                     UNTIL FOUND;
            IF FOUND THEN

                  %   FOUND KEY WORDS ASSOCIATED WITH LAST DELUSIONAL STATEMENT   %

               VALUE←BEGIN
                        LASTSTMT←CADR (PAIR);
                        RETURN (CHOOSEDEL (CADR (PAIR)));
                     END;
            IF NOT VALUE THEN

                     %   AT ANY POINT IN DELUSION DISCUSSION, IF 'WHO' IS NOT OTHERWISE RECOGNIZED,
                         ASSUME AS REFERRING TO MAFIA   %

               IF ((WD←INP[2]) EQ 'WHO) OR (WD EQ 'WHOM) THEN VALUE←'(THE MAFIA);
            IF NOT FOUND THEN
               IF ('THEY MEMBER INP) AND (('DO MEMBER INP) OR ('ARE MEMBER INP)) AND (LENGTH (INP) LESSP 4)
                  AND (CAR (INP) EQ 'Q) THEN
                  VALUE←'(THAT?'S RIGHT);
            IF VALUE THEN
            BEGIN

                     %   DELETE ANY NEW DELUSIONAL WORDS IN 'SELF'S STATEMENT
                         FROM DELUSION LIST   %

               DELCHECK (VALUE);
               SAY (VALUE);
            END;
            RETURN (VALUE);
         END;

          %
SPECREAX    PROVIDES THE APPROPRIATE REACTION OF 'SELF TO SPECIAL TYPES 
            OF STATEMENT OF 'OTHER   %

      EXPR SPECREAX (STMT);

         IF CAR STMT EQ 'S THEN
            PROG2 (SAY (CHOOSE ('SILENCE)), T)
         ELSE
         IF 'YOU MEMBER STMT AND MEMBER1 (GET ('ABNORMAL, 'IND), STMT) THEN

               %   INSINUATION THAT 'SELF IS MENTALLY ILL   %

         BEGIN
            IF CAR STMT EQ 'Q THEN FJUMP←(AJUMP←0.3)
            ELSE FJUMP←(AJUMP←0.5);
            SAY (CHOOSE ('ALIEN));
            RETURN T;
         END;

          %
SPLIT       MAKES LIST OUT OF HYPHENATED WORDS OF AN ATOM   %

      EXPR SPLIT (JOIND);
         BEGIN
            NEW LET, WD, LST;
            FOR LET IN REVERSE (EXPLODEC (JOIND)) DO
               IF LET = DASH THEN PROG2 (LST←READLIST (WD) CONS LST, WD←NIL)
               ELSE WD←LET CONS WD;
            RETURN (READLIST (WD) CONS LST);
         END;

          %
STRINGATE   MAKES A STRING OUT OF A QUOTED LIST   %

      EXPR STRINGATE (L);
	 FOR NEW WD IN L; CAT WD CAT " ";

          %
THREAT      %

      EXPR THREAT (STMT);
         BEGIN
            NEW FOUND;
            IF FOUND←MEMBER1 (GET ('DELWDS, 'NOUNS) @ GET ('DELWDS, 'VERBS), STMT) THEN
               IF MEMBER1 (NLIST, STMT) THEN
               BEGIN
                  FEAR←FEAR-1;
                  FOUND←CHOOSE ('CAUTION);
               END
               ELSE
               IF 'I MEMBER STMT THEN
               BEGIN
                  FJUMP←0.5;
                  FOUND←CHOOSE ('PANIC);
               END
               ELSE FOUND←NIL;
            IF FOUND THEN RETURN (PROG2 (SAY (FOUND), T))
            ELSE RETURN (NIL);
         END;

          %
YES         SCANS STATEMENT OF 'OTHER FOR AFFIRMATIVE EXPRESSIONS   %

            %   TO BE REWRITTEN  %

      EXPR  YES (INP);
         IF GET ('BELIEVEREPLIES, 'IND) THEN

         %   POSITIVE ANSWER TO QUESTION IS AFFIRMATIVE--   
             APPLIES TO ALL 'BELIEVEREPLIES USED EXCEPT LAST ONE ON LIST   %

         (NOT MEMBER1 (GET ('DISBELIEF, 'IND), INP)) AND NOT ('NO MEMBER INP) AND
         (('YES MEMBER INP) OR ('CERTAINLY MEMBER INP) OR
         ('GUESS MEMBER INP) OR ('SURE MEMBER INP))
         ELSE
      
         %   NEGATIVE ANSWER TO NEGATIVE STATEMENT IS AFFIRMATIVE   %

         (NOT MEMBER1 (GET ('DISBELIEF, 'IND), INP)) AND ('NO MEMBER INP)
                                                     ;



%               *****    MAIN PROGRAM    *****               %


   INITIALIZE();

   PRINTSTR "
END INPUT WITH A PERIOD OR QUESTION MARK, FOLLOWED BY TWO ALTMODES.
SPELL OUT NUMBERS.
TO INDICATE SILENCE, TYPE 'S.'
WHEN FINISHED, TYPE 'BYE.'
";


   WHILE NOT ENDE DO
   BEGIN  NEW OK;
      INTERPERS←NIL;   %   REINITIALIZE INTERPERSONAL ATTITUDE  %
      IF TALK THEN
      BEGIN
	 IF ¬JOB_EXISTS('DOCJOB) THEN
	 BEGIN
	    PRINTSTR "THE DOCTOR HAS NOT STARTED RUNNING 'DOCJOB' YET.";
	    DO SLEEP(30) UNTIL JOB_EXISTS('DOCJOB) | PROG2(PRINTSTR "STILL HASN'T STARTED 'DOCJOB'", NIL);
	    TERPRI PRINTSTR "OK, HE JUST STARTED IT.";
	    SLEEP(30)				% MAKE SURE HE HAS TIME TO START IT UP. %
	 END;
         MESSAGE ← EXPLODEC INP(DOC, READ_MESSAGE(), NIL);
         OUT (OWN, PRINT_MESSAGE (MESSAGE));
         OK ← INP(OWN, TERPRI READ());		% T OR NIL %
      END;
      IF ¬OK THEN MESSAGE ← INP(OWN, READ_MESSAGE());
      WHILE BADINP (REMARK←SENTYPE (READSENT (MESSAGE))) DO MESSAGE ← INP(OWN, READ_MESSAGE()) ;
      IF TALK | SAVE_FILE THEN OUT (FILE1, PRINT_MESSAGE (TERPRI TERPRI MESSAGE));
      IF 'BYE MEMBER REMARK OR FEAR GREATERP 18.4 THEN ENDE ← T
      ELSE
      BEGIN
         SPECREAX (REMARK) OR DELREF (REMARK) OR SELFREF (REMARK) OR FLAREREF (REMARK)
            OR PERSREL (REMARK) OR NORMAL (REMARK);
         MODIFVAR ();
      END;
   END;
   SAY (IF (DELFLAG OR (FLARE NEQ 'INIT)) AND NOT (FEAR GREATERP 18.4) THEN
                 PROG2 (AJUMP←0.1, '((OFFENDED) GOOD BYE)) 
              ELSE '(BYE));
   TRACEV←T;
   MODIFVAR ();
END.



