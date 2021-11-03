C     Program J349 with modifications by P.R. Jordan, Kansas, Nov. 1984 - Feb. 1985, and some earlier ones by Ken Schriner.
C         kt indicates modification by K.L. Thompson, Colorado DWR, 2021
C
C
C******************* NEED TO LOAD LIBRARY IMSLIB77D WITH THIS PROGRAM ****************************************
C
C
C   !!!!    THIS VERSION OF THE PROGRAM HAS FUNCTION JNWYDY ALTERED SO IT WILL RETURN NUMBER     ! ! ! !
C     !!!    OF DAY CONSECUTIVE FROM OCTOBER 1, 1900. OTHER PARTS OF PROGRAM ARE CHANGED
C            TO GIVE NUMBER OF DAY OF MODEL RUN.  SHOULD ELIMINATE PROBLEM
C           OF WRONG DAY NUMBERS WHEN A DIVERSION STARTS IN SECOND WATER YEAR OF MODEL RUN ("CARD" INPUT).
C                           ALSO HAS SEVERAL OTHER MODIFICATIONS.
C          P.R. Jordan 2/20/85
C
C              !!!!!!!!!         !!!!!!!!!!!!          !!!!!!!!!!!!!!!!!!!!
C
C
C
C     J349--STREAMFLOW ROUTING WITH LOSSES TO BANK STORAGE OR WELLS     00000100
C                                                                       00000200
C     ******************************************************************00000300
C     *                                                                *00000400
C     *                                                                *00000500
C     * J349:  STREAMFLOW ROUTING WITH LOSSES TO BANK STORAGE AND WELLS*00000600
C     *                                                                *00000700
C     *                GULF COAST HYDROSCIENCE CENTER                  *00000800
C     *                   U. S. GEOLOGICAL SURVEY                      *00000900
C     *          DATE OF LAST PROGRAM UPDATE: JUL 06, 1978             *00001000
C     *                                                                *00001100
C     *             MODIFIDED FOR MULTI-LINEAR ROUTING                 *00001200
C     *                                                                *00001300
C     ******************************************************************00001400
C
C
C
C
C
C
C                                                                       00001500
C     J349 CAPABILITIES:                                                00001600
C             1) TO COMPUTE THE BANK STORAGE DISCHARGE HYDROGRAPH FOR A 00001700
C                REACH                                                  00001800
C                OR                                                     00001900
C             2) TO COMPUTE A DOWNSTREAM DISCHARGE HYDROGRAPH AND A BANK00002000
C                STORAGE DISCHARGE HYDROGRAPH                           00002100
C                                                                       00002200
C                                                                       00002300
C     LOGICAL PARAMETERS                                                00002400
C        ZCARDS- HYDROGRAPH DATA COMES FROM CARDS                       00002500
C        ZDISK - HYDROGRAPH DATA COMES FROM DATA SET ON DISK            00002600
C        ZFLOW - UPSTREAM AND DOWNSTREAM DISCHARGE IS KNOWN             00002700
C        ZROUTE- ONLY UPSTREAM DISCHARGE IS KNOWN                       00002800
C        ZLOSS - IDENTIFIES APPLICATION OF DIVERSION OPTION             00002900
C        ZPRINT, ZPLOT, ZPUNCH- IDENTIFIES SELECTED OUTOUT OPTIONS      00003000
C        ZUSHFT, ZDSHFT- IDENTIFIES USE OF (UP-DOWN)STREAM SHIFT OPTION 00003100
C        ZBEGIN, ZEND- IDENTIFIES BEGINNING AND ENDING OF STUDY PERIOD  00003200
C        ZMULT - IDENTIFIES MULTI-LINEARIZATION OPTION                  00003300
C        ZDSQO--ALLOWS FOR INPUT OF DS OBSERVED FLOW FOR HYDRGRAPH COMPARISON.   G. KUHN, 3-18-87
C        ZOUTPUT--ALLOWS FOR NO PRINT IF DAILY(HOURLY, ETC.) VALUES.             G. KUHN, 3-18-87
C        ZFAST - option to speed up execution using binary for Qds output         kt fast option
C        ZCMDOPT - command line option if '-f' then filenames via cmd line        kt cmd arg
C                                                                       00003400
C     SELECTED ARRAYS IN TIME DIMENSION                                 00003500
C        USQ   - UPSTREAM DISCHARGE HYDROGRAPH.                         00003600
C        USS   - UPSTREAM STAGE HYDROGRAPH.                             00003700
C        DSQ   - INITIAL DOWNSTREAM HYDROGRAPH.                         00003800
C        DSS   - DOWNSTREAM STAGE HYDROGRAPH.                           00003900
C        DSQ1  - COMPUTED DOWNSTREAM DISCHARGE HYDROGRAPH.              00004000
C        DUSRF - STREAM-AQUIFER UNIT RESPONSE FUNCTION.                 00004100
C        UR    - STREAMFLOW ROUTING UNIT RESPONSE FUNCTION.             00004200
C                                                                       00004300
C     MODEL UNITS, UNLESS STATED OTHERWISE                              00004400
C        LENGTH     - FEET                                              00004500
C        TIME       - HOURS                                             00004600
C        FLOW RATE  - CUBIC FEET PER SECOND                             00004700
C        VOLUME     - CUBIC FEET PER SECOND-DAYS                        00004800
C                                                                       00004900
C                                                                       00005000
      IMPLICIT LOGICAL(Z)                                               00005100
      INTEGER OPFILE,C,P,PU,US,DS                                       00005200
      CHARACTER *4 STANO1(2),STANO2(2),STANM1(17),STANM2(17),INFO(20)   00005300  kt stop line
      CHARACTER *200 FILENAME                                                     kt filename from 40 to 200 to enable folders
      CHARACTER *2 CMDOPT                                                         kt cmd line option
      DIMENSION IAV(10), LREC(10)                                       00005400
      CHARACTER *4 IWARN (9000)
      CHARACTER *4 IW0, IW1, IW2
      DIMENSION UR(20,100), DUSRF(9000), QLIN(20), NRESP(20), ITT(20)   00005600
      DIMENSION SRAT(2,20), QRAT(2,20), SHIFT(2,9000)                   00005700
      DIMENSION X(25), QLOSS(25), ISTRT(25), IEND(25)                   00005800
      DIMENSION USS(9000), DSS(9000), DELS(9000), S(9000)               00005900
      DIMENSION USQ(9000),DSQ(18000),DSQ1(9000),SQLOSS(18000),QI(18000) 00006000
C     NEW VARIABLE DSQO, OBSERVED DS. DISCHARGE, CREATED TO KEEP UNCHANGED
C     FOR OUTPUT AND PRINTED NEXT TO COMPUTED DS. DISCHARGE FOR COMPARISON.  G. KUHN, 9-26-85.
C
      DIMENSION DSQO(9000)
C
      DIMENSION AC0(20), AXK(20), C0RAT(10), C0QRAT(10),                00006100
     1XKRAT(10), XKQRAT(10)                                             00006200
      REAL *8 UR
      COMMON /ZLOGIC/ ZBEGIN,ZEND,ZPLOT,ZROUTE,ZFLOW,ZLOSS,ZDISK,ZCARDS,00006300
     1ZWARN,ZPRINT,ZPUNCH,ZUSHFT,ZDSHFT,ZMULT,ZDSQO,ZOUTPUT,ZFAST       00006400  kt fast option
      COMMON /PLT/ INITMO,INITDY,INITYR,LASTMO,LASTDY,LASTYR,NRECDS,STAN00006500
     1O1,STANM1,STANO2,STANM2,INFO,JYEAR                                00006600
      COMMON /RESFCT/ UR,DUSRF,QLIN,NURS,NRO,NRESP,ITT,NUR1,            00006700
     1                NSTAIL,NATAIL                                     00006800
      COMMON /FILES/ ID21,ID22,ID23,ID24,ID25,ID26,ID27,ID28,ID29,ID30  00006900
      COMMON /DISCHA/ USQ,DSQ,DSQ1,QI,SQLOSS,USQB,DSQB,TOLRNC,DSQO      00007000
      COMMON /STAGES/ USS,DSS,DELS                                      00007100
      COMMON /TIMEPR/ TMAX,ITMAX,DT,NTS,KR,NDT24,NRCHS,NSR,KTSTRT,N1ST,N00007200
     12ND,NLST,IQBEG,IQEND,KCNT,IBEGR                                   00007300  KCNT and IBEGR added 2/12/85 PRJ
      COMMON /PARAM/ TT,TLAG,CHLGTH,ALLGTH,T,SS,ALPHA,XK,XKA,XL,CZERO,SO00007400
     1ILMS, TTCUM                                                       00007500  TTCUM ADDED 2/85 PRJ
      COMMON /LOSS/ X,QLOSS,ISTRT,IEND,NLOSS                            00007600
      COMMON /RATING/ SRAT,QRAT,SHIFT,NUSRP,NDSRP                       00007700
      COMMON /URPARM/ AC0,AXK,QMIN,QMAX,C0RAT,C0QRAT,XKRAT,XKQRAT,NURSF 00007800  kt added NURSF - number of URFs to Force
      COMMON /VOL/ QILOST, WELCUM, QLSCUM, USREL1                       00007900   WELCUM, QLSCUM, and USREL1 added 2/10/85 PRJ
      COMMON /WARN/ IWARN,IW0,IW1,IW2                                   00008000
      COMMON /UNITS/ C,P,PU,US,DS,NDIM,MDIM                             00008100
c      WRITE(*,1)
c1     FORMAT(5X,'TYPE IN INPUT FILENAME:')
c      READ(*,2)FILENAME
c2     FORMAT(A40)
c      OPEN(7,FILE=FILENAME)
c      WRITE(*,3)
c3     FORMAT(5X,'TYPE IN OUTPUT FILENAME:')
c      READ(*,2)FILENAME
c      OPEN(10,FILE=FILENAME)
  1   format (a200)                                                               kt moved orig statement
  2   format (a40)                                                                kt copied/changed to line 2 for other statement
      CALL GET_COMMAND_ARGUMENT(1,CMDOPT)                                         kt added - use '-f' on command line to use cmd line for filenames
      IF (CMDOPT.EQ.'-f') THEN                                                    kt cmd arg
         ZCMDOPT=.TRUE.                                                           kt cmd arg
      ELSE                                                                        kt cmd arg
         ZCMDOPT=.FALSE.                                                          kt cmd arg
      END IF                                                                      kt cmd arg
      IF (ZCMDOPT) THEN                                                           kt cmd arg
         CALL GET_COMMAND_ARGUMENT(2,FILENAME)                                    kt cmd arg
      ELSE                                                                        kt cmd arg
         open (22,file='StateTL_filenames.dat',status='old')                      kt moved orig statement
         read (22,1) filename                                                     kt moved orig statement
      END IF                                                                      kt cmd arg
      OPEN(7,FILE=FILENAME)
      IF (ZCMDOPT) THEN                                                           kt cmd arg
         CALL GET_COMMAND_ARGUMENT(3,FILENAME)                                    kt cmd arg
      ELSE                                                                        kt cmd arg
         read (22,1) filename                                                     kt moved orig statement
      END IF                                                                      kt cmd arg
	  OPEN(10,FILE=FILENAME)                                                      kt even in fast option leaving open in case of closure error
      CONTINUE
C                                                                       00008200
C                                                                       00008300
  999 CALL START
C
      IF (.NOT.ZFAST) GO TO 5                                                     kt fast option
      IF (ZCMDOPT) THEN                                                           kt cmd arg
         CALL GET_COMMAND_ARGUMENT(4,FILENAME)                                    kt cmd arg
      ELSE                                                                        kt cmd arg
         read (22,1) filename                                                     kt moved orig statement
      END IF                                                                      kt cmd arg
	  OPEN(12,FILE=FILENAME,ACCESS='STREAM')                                      kt fast option   
C
    5 IF (ZCARDS) GO TO 10                                              00008500  kt fast option
      IF (NRECDS.LE.0) NRECDS=20                                        00008600
C             IF DISK OPTION - DEFINE FILES                             00008700
      CALL SETUP (NRECDS)                                               00008800
      ZBORT=.FALSE.                                                     00008900
      GO TO 20                                                          00009000
C                                                                       00009100
C             IF CARDS OPTION - INPUT UPSTREAM HYDROGRAPH DATA          00009200
   10 CALL READQ (USQ)
C   10 READ (7,240) (USQ(NT),NT=N1ST,NLST) 
   20 KCNT=0                                                            00009400
C                                                                       00009500
C             BEGIN NEW REACH                                           00009600
   30 CONTINUE                                                          00009700
      KR=KR+1                                                           00009800
      KCNT=KCNT+1                                                       00009900
C             INPUT AND COMPUTE REACH PARAMETERS                        00010000
      CALL REACH                                                        00010100
C             COMPUTE MODEL PARAMETERS                                  00010200
      IQBS=USQB/100.                                                    00010300
      NY=0                                                              00010400
      ZBEGIN=.TRUE.                                                     00010500
      ZEND=.FALSE.                                                      00010600
      IQF=IQBEG                                                         00010700
      JYEAR=INITYR                                                      00010800
      JMON=INITMO                                                       00010900
      JDAY=INITDY                                                       00011000
      IF (IQF.GT.92) JYEAR=JYEAR-1                                      00011100
      LYEAR=JYEAR-1                                                     00011200
      IF (ZCARDS) GO TO 70                                              00011300
C                                                                       00011400
C             DISK INPUT                                                00011500
C                COMPUTE MODEL PARAMETERS                               00011600
      READ (7,280) IPFILE,NOUTFL                                        00011700
      OPFILE=NOUTFL                                                     00011800
      N1ST=IQF                                                          00011900
      JIN=IPFILE-20                                                     00012000
      JOUT=OPFILE-20                                                    00012100
      IAV(JOUT)=2                                                       00012200
      CALL DABSAH (IPFILE,JYEAR,IAV(JIN),ZBORT,LREC(JIN))               00012300
      IF (ZBORT) GO TO 230                                              00012400
      IF (ZROUTE) GO TO 40                                              00012500
      CALL DABSAH (OPFILE,JYEAR,IAV(JOUT),ZBORT,LREC(JOUT))             00012600
      IF (ZBORT) GO TO 230                                              00012700
C                BEGIN NEW TIME STEP                                    00012800
   40 CONTINUE                                                          00012900
C             INPUT FLOW DATA FROM DISK FOR UPSTREAM STATION            00013000
      WRITE (10,340) IPFILE,IAV(JIN)                                    00013100
      CALL QINPUT (IPFILE,IAV(JIN),ITEMS,USQ,JYEAR,JMON,JDAY)           00013200
      WRITE (10,350) ITEMS,JMON,JDAY,JYEAR                              00013300
      IF (JYEAR.NE.LYEAR+1) GO TO 240                                   00013400
      LYEAR=JYEAR                                                       00013500
      IF (IQEND.LT.93.AND.JYEAR.EQ.LASTYR) GO TO 50                     00013600
      IF (IQEND.GT.92.AND.JYEAR.EQ.LASTYR-1) GO TO 50                   00013700
      NLST=ITEMS                                                        00013800
      GO TO 60                                                          00013900
   50 NLST=IQEND                                                        00014000
      ZEND=.TRUE.                                                       00014100
   60 NY=NY+1                                                           00014200
      ITMAX=NLST-N1ST+1                                                 00014300
      NTS=ITMAX                                                         00014400
      N2ND=N1ST+1                                                       00014500
C                                                                       00014600
C             COMPUTE UPSTREAM STAGE HYDROGRAPH                         00014700
   70 CALL RATNG (USQ,USS,USQB,US)                                      00014800
      IF (ZFLOW) GO TO 90                                               00014900
C                                                                       00015000
C             INPUT DIVERSIONS AND DEPLETIONS, IF ANY                   00015100
      IF (ZLOSS) CALL DIVRSN                                            00015200
C                                                                       00015300
C             COMPUTE DOWNSTREAM DISCHARGE HYDROGRAPH                   00015400
C                BASE FLOW, DIVERSIONS AND DEPLETIONS ARE INCLUDED,     00015500
C                BANK STORAGE DISCHARGE IS NOT.                         00015600
      CALL CVOLUT (DSQ,USQ,UR,N1ST,NLST,NRO,NURS,QLIN,ITT,NRESP)        00015700
      DO 80 NT=N1ST,NLST                                                00015800
      DSQ(NT)=DSQ(NT)+DSQB-USQB                                         00015900
      IF (DSQ(NT).LT.DSQB) DSQ(NT)=DSQB                                 00016000
      DSQ1(NT)=DSQ(NT)+SQLOSS(NT)                                       00016100
      IWARN(NT)=IW0                                                     00016200
      IF (DSQ1(NT).GE.0.0) GO TO 80                                     00016300
      SQLOSS(NT)=-DSQ(NT)                                               00016400
      DSQ1(NT)=0.0                                                      00016500
      IWARN(NT)=IW2                                                     00016600
   80 CONTINUE                                                          00016700
      GO TO 120                                                         00016800
C                                                                       00016900
C             INPUT DOWNSTREAM HYDROGRAPH FOR BANK STORAGE ONLY PROBLEM 00017000
   90 IF (ZCARDS) GO TO 100                                             00017100
C                DISK OPTION                                            00017200
      WRITE (10,360) OPFILE,IAV(JOUT)                                   00017300
      CALL QINPUTB (OPFILE,IAV(JOUT),ITEMZ,DSQ,KYEAR,KMON,KDAY)         00017400  kt changed to larger dim B function
      WRITE (10,370) ITEMZ,KMON,KDAY,KYEAR                              00017500
      IF (KYEAR.NE.JYEAR) GO TO 260                                     00017600
      GO TO 110                                                         00017700
C                CARD OPTION                                            00017800
  100 CALL READQB (DSQ)                                                           kt changed to larger dim B function
  110 CALL MOVEB (DSQ,DSQ1,N1ST,NLST,0,0)                               00018000  kt changed to mixed dim B function
  120 CONTINUE                                                          00018100
C             SKIP BANK STORAGE COMPUTATIONS FOR IMPERMEABLE AQUIFER    00018200
      IF (ALPHA.GT.1.) GO TO 130                                        00018300
      CALL RATNG (DSQ1,DSS,DSQB,DS)                                     00018400
      QILOST=0.0                                                        00018500
      IF (.NOT.ZFAST) WRITE (10,300)                                    00018600  kt fast option
      GO TO 140                                                         00018700
C                                                                       00018800
C             COMPUTE BANK STORAGE DISCHARGE AND DOWNSTREAM DISCHARGE   00018900
  130 CALL QBANK                                                        00019000
  140 IF (ZCARDS) GO TO 180                                             00019100
C                                                                       00019200
C             DISK OPTION                                               00019300
      IF (ZFLOW) GO TO 150                                              00019400
      IF (JOUT.LE.5) GO TO 250                                          00019500
C                OUTPUT DATA AND RESULTS                                00019600
      IF (ZBEGIN.AND.IQBEG.GT.1) CALL FILL (DSQ,1,N1ST-1,99999.)        00019700
      IF (ZEND.AND.IQEND.LT.ITEMS) CALL FILL (DSQ,NLST+1,ITEMS,99999.)  00019800
      WRITE (10,380) OPFILE,IAV(JOUT)                                   00019900
      CALL QOUTPT (OPFILE,IAV(JOUT),ITEMS,DSQ1,10,1,JYEAR)              00020000
      WRITE (10,390) ITEMS,JYEAR                                        00020100
  150 CALL OUTPUT                                                       00020200
      IF (ZPLOT) CALL PLOTIT (.TRUE.,ZEND,ZBEGIN,IQBS,USQ,DSQ1,QI)      00020300
C                PREPARE FOR NEXT YEAR'S DATA AND COMPUTATIONS          00020400
      ZBEGIN=.FALSE.                                                    00020500
      N1ST=1                                                            00020600
      N2ND=N1ST+1                                                       00020700
      IF (ZFLOW.AND.ZEND) GO TO 190                                     00020800
      IF (ZFLOW) GO TO 170                                              00020900
      IF (.NOT.ZEND) GO TO 160                                          00021000
      NRECDS=IAV(JOUT)-1                                                00021100
C                WRITE HEADER INFORMATION                               00021200
      WRITE (OPFILE,2) NRECDS,STANO2,STANM2                             00021300  kt changed from line 1 to 2
      GO TO 190                                                         00021400
  160 CONTINUE                                                          00021500
      CALL MOVE (DSQ,DSQ,1,NSTAIL,0,ITEMS)                              00021600
      CALL FILL (DSQ,NSTAIL+1,NSTAIL+ITEMS,0.0)                           00021700
      CALL MOVE (SQLOSS,SQLOSS,1,ITEMS,0,ITEMS)                         00021740
      CALL FILL (SQLOSS,ITEMS+1,MDIM,0.0)                               00021750
      CALL FILL (QI,1,ITEMS,0.0)                                        00021760
  170 CONTINUE                                                          00021800
C                RETURN FOR ANOTHER YEAR OF COMPUTATIONS                00021900
      GO TO 40                                                          00022000
C                                                                       00022100
C             CARD OPTION                                               00022200
C                OUTPUT DATA AND RESULTS                                00022300
  180 CONTINUE                                                          00022400
      ZEND=.TRUE.                                                       00022500
      CALL OUTPUT                                                       00022600
      IF (ZPLOT) CALL PLOTIT (.TRUE.,.TRUE.,.TRUE.,IQBS,USQ,DSQ1,QI)    00022700
C             CHECK FOR MORE DOWNSTREAM REACHES                         00022800
  190 IF (KCNT.EQ.NRCHS) GO TO 270                                      00022900
C                                                                       00023000
C             PREPARE FOR NEW REACH                                     00023100
      ZBEGIN=.TRUE.                                                     00023200
      ZEND=.FALSE.                                                      00023300
      ZWARN=.FALSE.                                                     00023400
      USQB=DSQB                                                         00023500
      DO 200 J=1,20                                                     00023600
      QRAT(US,J)=QRAT(DS,J)                                             00023700
      SRAT(US,J)=SRAT(DS,J)                                             00023800
  200 CONTINUE                                                                    kt warning fix
      NUSPR=NDSRP                                                       00023900
      STANO1(1)=STANO2(1)                                               00024000
      STANO1(2)=STANO2(2)                                               00024100
      DO 203 I=1,17                                                     00120300
      STANM1(I)=STANM2(I)                                               00120400
  203 CONTINUE  
      DO 210 NT=1,NDIM                                                  00024300
      USQ(NT)=DSQ1(NT)                                                  00024400
      USS(NT)=DSS(NT)                                                   00024500
      DELS(NT)=0.0                                                      00024600
      DSQ1(NT)=0.0                                                      00024700
      DSS(NT)=0.0                                                       00024800
  210 CONTINUE                                                                    kt warning fix
      ZUSHFT=ZDSHFT                                                     00024900
      DO 220 K=1,NDIM                                                   00025000
      SHIFT(US,K)=SHIFT(DS,K)                                           00025100
      SHIFT(DS,K)=0.0                                                   00025200
  220 CONTINUE                                                                    kt warning fix
      CALL FILL (SQLOSS,1,MDIM,0.0)                                     00025300
      CALL FILL (QI,1,MDIM,0.0)                                         00025400
      CALL FILL (DSQ,1,MDIM,0.0)                                        00025500
      GO TO 30                                                          00025600
C                                                                       00025700
C             ERROR MESSAGES                                            00025800
  230 WRITE (10,290)                                                    00025900
      GO TO 270                                                         00026000
  240 WRITE (10,310)                                                    00026100
      GO TO 270                                                         00026200
  250 WRITE (10,320)                                                    00026300
      GO TO 270                                                         00026400
  260 WRITE (10,330)                                                    00026500
  270 CONTINUE                                                          00026600
      STOP                                                              00026700
C                                                                       00026800
C                                                                       00026900
  280 FORMAT (8G10.0)                                                   00027000
  290 FORMAT ('1','*** RUN ABORTED IN MAIN****(AFTER CALLING DABSAH)')  00027100
  300 FORMAT ('1','  NOTE: TRANSMISSIVITY IS TOO LOW FOR A SIGNIFICANT A00027200
     1MOUNT OF STEAM-AQUIFER FLOW')                                     00027300
  310 FORMAT ('1','*** RUN ABORTED IN MAIN****(THE PERIOD OF RECORD READ00027400
     1 BY QINPUT IN THE IPFILE WAS NOT THE ONE SPECIFIED)')             00027500
  320 FORMAT ('1','*** RUN ABORTED IN MAIN****(AFTER TRYING TO WRITE IN 00027600
     1A PROTECTED FILE)')                                               00027700
  330 FORMAT ('1','*** RUN ABORTED IN MAIN****(THE PERIOD OF RECORD READ00027800
     1 BY QINPUT IN THE OPFILE WAS NOT THE ONE SPECIFIED)')             00027900
  340 FORMAT ('0',////,' UPSTREAM STATION DISCHARGE DATA'/1X,31(1H-)/10X00028000
     1,'DISCHARGE DATA CAME FROM DATA SET NO.',I3,', RECORD NO.',I3)    00028100
  350 FORMAT (' ',09X,'THERE ARE',I4,' DAILY VALUES - BEGINNING',2I3,I5)00028200
  360 FORMAT ('0',////,' DOWNSTREAM STATION DISCHARGE DATA'/1X,33(1H-)/100028300
     10X,'DISCHARGE DATA CAME FROM DATA SET NO.',I3,', RECORD NO.',I3)  00028400
  370 FORMAT (' ',09X,'THERE ARE',I4,' DAILY VALUES - BEGINNING',2I3,I5)00028500
  380 FORMAT ('0',////,' DOWNSTREAM STATION DISCHARGE DATA'/1X,33(1H-)/100028600
     10X,'DISCHARGE DATA WAS OUTPUT ON DATA SET NO.',I3,', RECORD NO.',I00028700
     23)                                                                00028800
  390 FORMAT (' ',09X,'THERE ARE',I4,' DAILY VALUES - BEGINNING OCT. 1,'00028900
     1,I5)                                                              00029000
      END                                                               00029100
      SUBROUTINE DATAIN
C                                                                       00029300
C     DATAIN-                                                           00029400
C       START -MODEL RUN BEGINS IN THIS ENTRY.  OPERATIONS INCLUDE      00029500
C              INITIALIZATION, DATA INPUT, PARAMETER COMPUTATION AND    00029600
C              OUTPUT ON LINE PRINTER                                   00029700
C       DIVRSN-INPUTS STREAMFLOW LOSS DATA AND COMPUTES SQLOSS ARRAY    00029800
C       READQ -INPUTS FLOW DATA FROM CARDS                              00029900
C       REACH -INPUTS REACH PARAMETERS AND OPTION DATA. OUTPUTS INFO    00030000
C              ON LINE PRINTER                                          00030100
C       QINPUT-PROGRAMMED BY J O SHEARMAN.  INPUTS HYDROGRAPH DATA FROM 00030200
C              DISK                                                     00030300
C       QOUTPT-PROGRAMMED BY J O SHEARMAN.  OUTPUTS HYDROGRAPH DATA ON  00030400
C              DISK                                                     00030500
      IMPLICIT LOGICAL(Z)                                               00005100
      INTEGER OPFILE,C,P,PU,US,DS                                       00005200
      DIMENSION A(9000), AB(18000)                                                kt changed A to smaller dim, AB to larger dim
      CHARACTER *4 STANO1(2),STANO2(2),STANM1(17),STANM2(17),INFO(20)        00005300
      DIMENSION IAV(10), LREC(10)                                       00005400
      CHARACTER *4 IWARN (9000)
      CHARACTER*10   TEST_ZMULT
      CHARACTER *4 IW0, IW1, IW2
      DIMENSION UR(20,100), DUSRF(9000), QLIN(20), NRESP(20), ITT(20)    00005600
      DIMENSION SRAT(2,20), QRAT(2,20), SHIFT(2,9000)                    00005700
      DIMENSION X(25), QLOSS(25), ISTRT(25), IEND(25)                   00005800
      DIMENSION USS(9000), DSS(9000), DELS(9000), S(9000)               00005900
      DIMENSION USQ(9000),DSQ(18000),DSQ1(9000),SQLOSS(18000),QI(18000) 00006000
      DIMENSION DSQO(9000)
      DIMENSION AC0(20), AXK(20), C0RAT(10), C0QRAT(10),                00006100
     1XKRAT(10), XKQRAT(10)                                             00006200
      REAL *8 UR
      COMMON /ZLOGIC/ ZBEGIN,ZEND,ZPLOT,ZROUTE,ZFLOW,ZLOSS,ZDISK,ZCARDS,00006300
     1ZWARN,ZPRINT,ZPUNCH,ZUSHFT,ZDSHFT,ZMULT,ZDSQO,ZOUTPUT,ZFAST       00006400  kt fast option
      COMMON /PLT/ INITMO,INITDY,INITYR,LASTMO,LASTDY,LASTYR,NRECDS,STAN00006500
     1O1,STANM1,STANO2,STANM2,INFO,JYEAR                                00006600
      COMMON /RESFCT/ UR,DUSRF,QLIN,NURS,NRO,NRESP,ITT,NUR1,            00006700
     1                NSTAIL,NATAIL                                     00006800
      COMMON /FILES/ ID21,ID22,ID23,ID24,ID25,ID26,ID27,ID28,ID29,ID30  00006900
      COMMON /DISCHA/ USQ,DSQ,DSQ1,QI,SQLOSS,USQB,DSQB,TOLRNC,DSQO      00007000
      COMMON /STAGES/ USS,DSS,DELS                                      00007100
      COMMON /TIMEPR/ TMAX,ITMAX,DT,NTS,KR,NDT24,NRCHS,NSR,KTSTRT,N1ST,N00007200
     12ND,NLST,IQBEG,IQEND,KCNT,IBEGR                                   00007300  KCNT and IBEGR added 2/12/85 PRJ
      COMMON /PARAM/ TT,TLAG,CHLGTH,ALLGTH,T,SS,ALPHA,XK,XKA,XL,CZERO,SO00007400
     1ILMS, TTCUM                                                       00007500  TTCUM ADDED 2/85 PRJ
      COMMON /LOSS/ X,QLOSS,ISTRT,IEND,NLOSS                            00007600
      COMMON /RATING/ SRAT,QRAT,SHIFT,NUSRP,NDSRP                       00007700
      COMMON /URPARM/ AC0,AXK,QMIN,QMAX,C0RAT,C0QRAT,XKRAT,XKQRAT,NURSF 00007800  kt added NURSF
      COMMON /VOL/ QILOST, WELCUM, QLSCUM, USREL1                       00007900   WELCUM, QLSCUM, and USREL1 added 2/10/85 PRJ
      COMMON /WARN/ IWARN,IW0,IW1,IW2                                   00008000
      COMMON /UNITS/ C,P,PU,US,DS,NDIM,MDIM                             00008100
C                                                                       00033300
C     ARRAYS IN TIME DIMENSION                                          00033400
C        USQ   - UPSTREAM DISCHARGE HYDROGRAPH.                         00033500
C        DSQ   - INITIAL DOWNSTREAM HYDROGRAPH.                         00033600
C        SQLOSS- SUM OF STREAMFLOW LOSSES TO DIVERSIONS AND DEPLETIONS. 00033700
C                                                                       00033800
C     INPUT PARAMETERS                                                  00033900
C        START                                                          00034000
C          INFO  - INFORMATION CARD                                     00034100
C          STANO1, STANM1- UPSTREAM STATION NUMBER AND NAME             00034200
C          ISOURC- CODE TO IDENTIFY LOCATION OF HYDROGRAPH DATA         00034300
C          IDDATA- CODE TO IDENTIFY MODEL OBJECTIVE                     00034400
C          IFAST - kt read option to speed up execution by reducing output        kt fast option
C          NRCHS - NUMBER OF REACHES IN THIS MODEL RUN                  00034500
C          NPREVR- NUMBER OF PREVIOUS REACHS                            00034600
C          ITMAX - NUMBER OF DAYS IN MODEL RUN                          00034700
C          DT    - LENGTH OF TIME STEP, in hours                        00034800
C          INITMO, INITDY, INITYR- STARTING DATE OF RUN                 00034900
C          LASTMO, LASTDY, LASTYR- ENDING DATE OF RUN                   00035000
C          NRECDS- NUMBER OF RECORDS ON DISK DATA SET                   00035100
C          NUSRP - NUMBER OF COORDINATES IN UPSTREAM RATING TABLE       00035200
C          ZUSHFT- IDENTIFIES USE OF UPSTREAM RATING SHIFT              00035300
C          USQB  - UPSTREAM STATION MINIMUM FLOW DURING RUN             00035400
C          SRAT, QRAT- STAGE-DISCHARGE AT COORDINATE OF RATING TABLE    00035500
C          SHIFT - STAGE ADJUSTMENT TO RATING TABLE ON GIVEN DAY        00035600
C        DIVRSN                                                         00035700
C          NLOSS - NUMBER OF DIVERSIONS OR PUMPING WELLS IN REACH       00035800
C          X     - DISTANCE OF DIVERSION OR WELL FROM STREAM            00035900
C          QLOSS - DISCHARGE OF DIVERSION OR DEPLETION                  00036000
C          JIMO, JIDY, JIYR- STARTING DATE OF DIV. OR DEPL.             00036100
C          JLMO, JLDY, JLYR- ENDING DATE OF DIV. OR DEPL.               00036200
C        READQ                                                          00036300
C          A     - DISCHARGE                                            00036400
C        REACH                                                          00036500
C          INFO  - AS ABOVE                                             00036600
C          STANO2, STANM2- DOWNSTREAM STATION NUMBER AND NAME           00036700
C          ICASE - CODE TO SELECT STREAM-AQUIFER BOUNDARY CONDITION     00036800
C          ZLOSS - IDENTIFIES USE OF DIV. AND DEPL. OPTION              00036900
C          ZPLOT, ZPRINT, ZPUNCH- IDENTIFIES USE OF OUTPUT OPTIONS      00037000
C          ZMULT - IDENTIFIES USE OF MULTIPLE LINEARIZATION             00037100
C          TT    - ESTIMATE TRAVEL TIME OF FLOOD WAVE                   00037200
C                  LATER, CALCULATED TIME TO FIRST RESPONSE (IN HOURS)
C         TTCUM   - TRAVEL TIME TO FIRST RESPONSE, CUMULATIVE FROM START OF FIRST REACH, IN DAYS      PRJ 2/8/85
C          CHLGTH- CHANNEL LENGTH OF REACH IN MILES                     00037300
C          ALLGTH- ALLUVIAL LENGTH OF REACH IN MILES                    00037400
C          T     - TRANSMISSIVITY OF AQUIFER IN SQ. FT. PER DAY         00037500
C          SS    - STORAGE COEFFICIENT OF AQUIFER                       00037600
C          SOILRT- BANK STORAGE RETAINED BY SOIL                        00037700
C          XK    - WAVE DISPERSION COEFFICIENT                          00037800
C          CZERO - WAVE CELERITY                                        00037900
C          TOLRNC- ERROR CRITERIA FOR CLOSURE                           00038000
C          XKA   - RETARDATION COEFFICIENT OF STREAM-AQUIFER BOUNDARY   00038100
C          XL    - WIDTH OF AQUIFER (ONE SIDE)                          00038200
C          QMIN & QMAX - EXPECTED LIMITS IN STREAM DISCHARGE            00038300
C          NURSF - NUMBER OF ROUTING URFS TO FORCE (ZERO IF NOT FORCE)  00038301  kt added comment, note this is only for MULTIPLE LINEARIZATION
C          C0RAT & C0QRAT - WAVE CELERITY - DISCHARGE TABLE             00038400
C          XKRAT & XKQRAT - DISPERSION COEF - DISCHARGE TABLE           00038500
C          NDSRP, ZDSHFT, DSQB, SRAT, QRAT, SHIFT- AS ABOVE EXCEPT      00038600
C                                                  DOWNSTREAM STATION   00038700
C        QINPUT AND QOUTPT                                              00038800
C          IFILE - DATA SET NUMBER                                      00038900
C          IAVI, IAVO- RECORD NUMBER ON DATA SET                        00039000
C          JMON, JDAY, JYEAR- BEGINNING DATE ON RECORD                  00039100
C          ITEMS - NUMBER OF DAYS IN DISCHARGE DATA ARRAY               00039200
C          A     - DISCHARGE                                            00039300
C                                                                       00039400
C           -----                                                       00039600
      ENTRY START
      DO 10 NT=1,NDIM                                                   00039700
      S(NT)=0.0                                                         00039800
      USQ(NT)=0.0                                                       00039900
      USS(NT)=0.0                                                       00040000
      DSS(NT)=0.0                                                       00040100
      DELS(NT)=0.0                                                      00040200
      DUSRF(NT)=0.0                                                     00040300
      DSQO(NT)=0.0
      DSQ1(NT)=0.0                                                      00040400
   10 CONTINUE                                                                    kt warning fix
      DO 40 I=1,2                                                       00040500
      DO 20 J=1,20                                                      00040600
      QRAT(I,J)=0.0                                                     00040700
      SRAT(I,J)=0.0                                                     00040800
   20 CONTINUE                                                                    kt warning fix
      DO 30 J=1,NDIM                                                    00040900
      SHIFT(I,J)=0.0                                                    00041000
   30 CONTINUE                                                                    kt warning fix
   40 CONTINUE                                                          00041100
      DO 42 I = 1,MDIM
      QI (I) = 0.0
      DSQ (I) = 0.0
      SQLOSS (I) = 0.0
   42 CONTINUE
      DO 44 I = 1,10
      C0RAT (I) = 0.0
      C0QRAT (I) = 0.0
      XKRAT (I) = 0.0
      XKQRAT (I) = 0.0
   44 CONTINUE
      DO 46 I = 1,20
      ITT (I) = 0
      NRESP (I) = 0
      QLIN (I) = 0
   46 CONTINUE
C
       TTCUM = 0.0                                                           PRJ 2/8/85
       WELCUM = 0.0                                                          PRJ 2/8/85
       QLSCUM = 0.0                                                         PRJ 2/11/85
C***(WELCUM is loss to wells, cumulative from first reach, in cfs-days)      PRJ 2/8/85
C
C             INPUT DATA FROM CARDS                                     00042200
      READ (7,140,END=50) INFO                                          00042300
      READ (7,250,END=50) STANO1,STANM1                                 00042400
      READ (7,161,END=50) ISOURC,IDDATA,IFAST                           00042500  kt fast option
      READ (7,162,END=50) NRCHS,NPREVR,ITMAX,DT                         00042600
      READ (7,161,END=50) INITMO,INITDY,INITYR,LASTMO,LASTDY,LASTYR,
     &NRECDS                                                            00042700
      READ (7,163,END=50) NUSRP,ZUSHFT,USQB                             00042800
      READ (7,160,END=50) (SRAT(US,K),QRAT(US,K),K=1,NUSRP)             00042900
      IF (ISOURC.NE.2.AND.ZUSHFT) READ (7,160) (SHIFT(US,L),L=1,ITMAX)  00043000
C                                                                       00043100
      TMAX=FLOAT(ITMAX)                                                 00043200
      IQBEG=JNWYDY(INITMO,INITDY,INITYR)                                00043300
      IBEGR = IQBEG                                                          2/20/85 PRJ
      IQEND=JNWYDY(LASTMO,LASTDY,LASTYR)                                00043400
      IQEND = IQEND - IQBEG + 1                                             2/20/85 PRJ
      IQBEG = 1                                                             2/20/85 PRJ
C
C
C        TESTING, JNWYDY SEEMS TO RETURN VARIBLE RESULTS   (comment probably by Ken Schriner in 1981)
C
C
C
C
C
      IQBEG1=IQBEG-1                                                    00043500
      IQEND1=IQBEG1+ITMAX                                               00043600
      KR=NPREVR                                                         00043700
      KTSTRT=KR+1                                                       00043800
      ZFLOW=.FALSE.                                                     00043900
      ZROUTE=.FALSE.                                                    00044000
      ZDISK=.FALSE.                                                     00044100
      ZCARDS=.FALSE.                                                    00044200
      ZWARN=.FALSE.                                                     00044300
      IF (IDDATA.EQ.1) ZFLOW=.TRUE.                                     00044400
      IF (IDDATA.NE.1) ZROUTE=.TRUE.                                    00044500
      IF (ISOURC.EQ.2) ZDISK=.TRUE.                                     00044600
      IF (ISOURC.NE.2) ZCARDS=.TRUE.                                    00044700
      IF (IFAST.EQ.1) ZFAST=.TRUE.                                      00044400  kt fast option
      IF (ZDISK) DT=24.0                                                00044800
      NDT24=24./DT+.5                                                   00044900
      NTS=TMAX*24./DT+.001                                              00045000
      IF (ZDISK) NTS=365                                                00045100
      N1ST=1                                                            00045200
      N2ND=N1ST+1                                                       00045300
      NLST=NTS                                                          00045400
C             PRINT DATA                                                00045500
      IF (ZFAST) GO TO 50                                                        kt fast option
      WRITE (10,150) INFO                                               00045600
      WRITE (10,170) INITMO,INITDY,INITYR,LASTMO,LASTDY,LASTYR          00045700
      IF (ZROUTE) WRITE (10,180)                                        00045800
      IF (ZFLOW) WRITE (10,190)                                         00045900
      WRITE (10,200) DT,NRCHS,NPREVR                                    00046000
      WRITE (10,210) USQB                                               00046100
      WRITE (10,220)                                                    00046200
      WRITE (10,230) (SRAT(US,K),QRAT(US,K),K=1,NUSRP)
      IF (.NOT.ZUSHFT) GO TO 50                                         00046400
      WRITE (10,380)                                                    00046500
      WRITE (10,390) (L,SHIFT(US,L-IQBEG1),L=IQBEG,IQEND1)              00046600
   50 CONTINUE                                                          00046700
      RETURN
C                                                                       00046900
      ENTRY DIVRSN                                                      00047000
C           ------                                                      00047100
      READ (7,164) NLOSS
      IF (NLOSS.LE.0) RETURN                                            00047300
C        REMOVED CARD   B 168                                           00047400
C        REMOVED CARD   B 169                                           00047500
C        REMOVED CARD   B 170                                           00047600
   60 CONTINUE                                                          00047700
      DO 120 N=1,NLOSS                                                  00047800
C             READ DATA FROM CARDS                                      00047900
      READ (7,999) X(N),QLOSS(N),JIMO,JIDY,JIYR,JLMO,JLDY,JLYR          00048000
  999 FORMAT (2F10.0,6I10)
C             COMPUTE TIME PARAMETERS                                   00048100
      ISTRT(N)=JNWYDY(JIMO,JIDY,JIYR)                                   00048200
      ISTRT(N) = ISTRT(N) - IBEGR  + 1                                     added 2/20/85 PRJ
C      IF (JIYR.EQ.1980.AND.JIMO.GE.10) ISTRT(N)=ISTRT(N)+366             good only for model run starting in 1980
C      IF (JIYR.EQ.1981) ISTRT(N)=ISTRT(N)+366                            good only for model run starting in 1980
      IEND(N)=JNWYDY(JLMO,JLDY,JLYR)                                    00048300
      IEND(N) = IEND(N) - IBEGR  + 1                                      added 2/20/85 PRJ
C      IF (JLYR.EQ.1980.AND.JLMO.GE.10) IEND(N)=IEND(N)+366               good only for model run starting in 1980
C      IF (JLYR.EQ.1981) IEND(N)=IEND(N)+366                              good only for model run starting in 1980
      IF (X(N).GT.10.AND.ALPHA.LT.1.0) GO TO 120                        00048400
      IF (IEND(N).GT.ISTRT(N)) GO TO 70                                 00048500
      IF (IEND(N).EQ.ISTRT(N).AND.JIYR.EQ.JLYR) GO TO 70                00048550
C     IEND1=IEND(N)+365                                                 00048600   not needed if JNWYDY consecutive from 1900
C     IF (MOD(JLYR,4).EQ.0) IEND1=IEND1+1                               00048700   not needed if JNWYDY consecutive from 1900
      GO TO 80                                                          00048800
   70 IEND1=IEND(N)                                                     00048900
   80 I0=(IQBEG-1)*NDT24                                                00049000
      I1=(ISTRT(N)-1)*NDT24+1-I0                                        00049100
      I2=IEND1*NDT24-I0                                                 00049200
      IF (X(N).GT.10.) GO TO 100                                        00049300
C             DIRECT DIVERSIONS                                         00049400
      DO 90 NT=I1,I2                                                    00049500
      SQLOSS(NT)=SQLOSS(NT)+QLOSS(N)                                    00049600
   90 CONTINUE                                                                    kt warning fix
      GO TO 120                                                         00049700
C             STREAM DEPLETION (CAUSED BY WELL PUMPAGE)                 00049800
  100 I0=0                                                              00049900
      IDEL=I2-I1                                                        00050000
      I22=I2+IDEL+1                                                     00050100
      DO 110 NT=I1,I22                                                  00050200
      I0=I0+1                                                           00050300
      TIME=FLOAT(I0)                                                    00050400
      ARG1=X(N)/SQRT(4.*ALPHA*TIME)                                     00050500
      IF (ARG1.GT.3.8) GO TO 110                                        00050600
      WELLOS=erfc(ARG1)*QLOSS(N)                                        00050700
C
C
      SQLOSS(NT)=SQLOSS(NT)+WELLOS                                      00050800
       IF(NT.LE.I2) WELCUM = WELCUM +(SQLOSS(NT)  /  NDT24)              PRJ 2/12/85 **  The "IF" makes the program
C                                                                               correct only when well pumping continues
C                                                                               to the end date of the model run.  **
C      WRITE(10,109) WELLOS, WELCUM, NT, N                                  FOR DEBUGGING 2/12/85 PRJ  NOW "C"
C109  FORMAT(2X,'WELLOS=',F9.5,'WELCUM=',F9.4,'NT=',I5,'N=',I3)                FOR DEBUGGING 2/12/85 PRJ,  NOW "C"
      IF (IDEL+NT+1.GT.I22) GO TO 110                                   00050900
C             STREAM DEPLETION (AFTER PUMPING, DURING WELL RECOVERY)    00051000
      SQLOSS(NT+IDEL+1)=SQLOSS(NT+IDEL+1)-WELLOS                        00051100
  110 CONTINUE                                                          00051200
  120 CONTINUE                                                          00051300
      RETURN                                                            00051400
C                                                                       00051500
      ENTRY READQ (A)
C           -----                                                       00051700
      READ (7,240) (A(NT),NT=N1ST,NLST)                                 00051800
      RETURN                                                            00051900
C                                                                       00052000
      ENTRY READQB (AB)                                                           kt added B function for larger dim
C           -----                                                       00051700  kt added B function for larger dim
      READ (7,240) (AB(NT),NT=N1ST,NLST)                                00051800  kt added B function for larger dim
      RETURN                                                            00051900  kt added B function for larger dim
C                                                                       00052000  kt added B function for larger dim
      ENTRY REACH                                                       00052100
C           -----                                                       00052200
C             READ DATA FROM CARDS                                      00052300
      READ (7,140) INFO                                                 00052400
      READ (7,250) STANO2,STANM2                                        00052500
C--------
C     READ (7,165) ICASE, ZLOSS, ZPLOT, ZPRINT, ZPUNCH, ZMULT
C--------ZMULT is a new variable added when the multi linear routing was installed
C--------and thus does not appear in many data sets.  This is the fix used:
C--------Apparently, Harris interpreted a blank field as .FALSE. when reading
C--------with an L format.  The Pr1me, however, crashes with format/data mismatch.
C--------Thus we parse the area that ZMULT would occupy and decide whether it is
C--------empty or not.  If it is, make ZMULT false. If there is a 'T' anywhere
C--------in the field ZMULT will be true.     jbs   6/83
      READ(7,'(I10,4L10,A10,2L10)')ICASE,ZLOSS,ZPLOT,ZPRINT,ZPUNCH,
     *TEST_ZMULT,ZDSQO,ZOUTPUT
c** initialize to false
      ZMULT = .FALSE.
      DO 99871 ITESTT=1,10
         IF (TEST_ZMULT(ITESTT:ITESTT).EQ.'T') ZMULT = .TRUE.
99871 CONTINUE
C--------
      READ (7,160) TT,CHLGTH,ALLGTH                                     00052700
      READ (7,160) T,SS,SOILRT                                          00052800
      READ (7,160) XK,CZERO,TOLRNC,XKA,XL                               00052900
      READ (7,166) NDSRP, ZDSHFT, DSQB
      READ (7,160) (SRAT(DS,K),QRAT(DS,K),K=1,NDSRP)                    00053100
      IF (ZCARDS.AND.ZDSHFT) READ (7,160) (SHIFT(DS,L),L=1,ITMAX)       00053200
      IF (.NOT.ZMULT) GO TO 121                                         00053300
      READ (7,167) QMIN,QMAX,NURSF                                      00053400  kt added NURSF
      READ (7,160) (C0RAT(I),C0QRAT(I),I=1,10)                          00053500  kt increased from 8 to 10
      READ (7,160) (XKRAT(I),XKQRAT(I),I=1,10)                          00053600  kt increased from 8 to 10
C                                                                       00053700
C   NEW STATEMENT TO READ OBSERVED DS DISCHARGE IF AVAIL. AND INCLUDE IN OUTPUT FOR COMPARISON TO MODELED DS Q.
C   LOGICAL VARIABLE ZDSQO ( IN COLS. 61-70 OF CARD TYPE 12) TESTS FOR DS Q.  G. KUHN, 11-7-85.
C
  121 IF (ZDSQO) READ (7,240) (DSQO(NT),NT=N1ST,NLST) 
C
  122 TTEST=TT                                                          00053800
      TLAG=TT                                                           00053900
      IF (ZROUTE) CALL UNRESP(ZMULT)                                    00054000
       TTDAY = TT/24.                                                     PRJ 2/8/85
       TTCUM = TTCUM + TTDAY                                              PRJ 2/8/85
      TTAVG=(TLAG+TT)/2.                                                00054100
      NSR=TTAVG/DT+.501                                                 00054200
      ITTAVG=TT/DT+.501                                                 00054300
      NSTAIL=NRO-1+ITTAVG                                               00054400
      NATAIL=0                                                          00054500
      NUR1=1                                                            00054600
      SOILMS=1.00-SOILRT                                                00054700
      IF (SS.LE.0.0) SS=.15                                             00054800
      ALPHA=(T/24.)*DT/SS                                               00054900
      IF (DSQB.LE.0.0) ZWARN=.TRUE.                                     00055000
C             PRINT DATA                                                00055100
      IF (ZFAST) GO TO 128                                                        kt fast option
      WRITE (10,260) INFO,KR                                            00055200
      WRITE (10,270) CHLGTH,ALLGTH                                      00055300
      WRITE (10,280) TTEST                                              00055400
      IF (ZROUTE) WRITE (10,290) TT,TTCUM,TLAG,TTAVG                     00055500  TTCUM added PRJ 2/8/85
      WRITE (10,300) NSR,T,SS                                           00055600
      IF (ICASE.EQ.1) WRITE (10,310)                                    00055700
      IF (ICASE.EQ.2) WRITE (10,320) XL                                 00055800
      IF (ICASE.EQ.3) WRITE (10,330) XKA                                00055900
      IF (ZROUTE) WRITE (10,340) SOILRT                                 00056000
      WRITE (10,350) DSQB                                               00056100
      IF (ZWARN) WRITE (10,400)                                         00056200
      N=NRESP(1)                                                        00056300
      IF (ZROUTE.AND.ZMULT) GO TO 124                                   00056400
      WRITE (10,355) CZERO,XK                                           00056500
      IF (ZROUTE) WRITE (10,360) (J,UR(1,J),J=1,N)                      00056600
      GO TO 128                                                         00056700
  124 WRITE (10,361) QMIN,QMAX                                          00056800
      IF (NURSF.GT.0) WRITE (10,363) NURSF                                        kt added to write NURSF 
      WRITE (10,362) (C0RAT(I),C0QRAT(I),XKRAT(I),XKQRAT(I),I=1,10)     00056900  kt increased from 8 to 10
      WRITE (10,365)                                                    00057000
      DO 126 I=1,NURS                                                   00057100
      N=NRESP(I)                                                        00057200
      WRITE(10,368) I,AC0(I),AXK(I),ITT(I),QLIN(I),(J,UR(I,J),J=1,N)    00057300
  126 CONTINUE                                                                    kt warning fix
  128 CONTINUE                                                          00057400
      CALL AQTYPE (ICASE)                                               00057500
      IF (ZFAST) GO TO 130                                                        kt fast option
      WRITE (10,370)                                                    00057600
      WRITE (10,230) (SRAT(DS,K),QRAT(DS,K),K=1,NDSRP)
      IF (.NOT.ZDSHFT) GO TO 130                                        00057800
      WRITE (10,380)                                                    00057900
      WRITE (10,390) (L,SHIFT(DS,L-IQBEG1),L=IQBEG,IQEND1)              00058000
  130 CONTINUE                                                          00058100
      ZWARN=.FALSE.                                                     00058200
      RETURN                                                            00058300
C                                                                       00058400
      ENTRY QINPUT(IFILE,IAVI,ITEMS,A,JYR,JMON,JDAY)                    00058500
C           ------                                                      00058600
      READ (IFILE,REC=IAVI) JMON,JDAY,JYR,ITEMS,(A(I),I=1,ITEMS)            00058700
      IAVI=IAVI+1                                                       00058800
      RETURN                                                            00058900
C                                                                       00059000
      ENTRY QINPUTB(IFILE,IAVI,ITEMS,AB,JYR,JMON,JDAY)                  00058500  kt added B function for larger dim
C           ------                                                      00058600  kt added B function for larger dim
      READ (IFILE,REC=IAVI) JMON,JDAY,JYR,ITEMS,(AB(I),I=1,ITEMS)       00058700  kt added B function for larger dim
      IAVI=IAVI+1                                                       00058800  kt added B function for larger dim
      RETURN                                                            00058900  kt added B function for larger dim
C                                                                       00059000  kt added B function for larger dim
      ENTRY QOUTPT(IFILE,IAVO,ITEMS,A,JMON,JDAY,JYR)                    00059100
C           ------                                                      00059200
      WRITE (IFILE,REC=IAVO) JMON,JDAY,JYR,ITEMS,(A(I),I=1,ITEMS)           00059300
      IAVO=IAVO+1                                                       00059400
      RETURN                                                            00059500
C                                                                       00059600
C                                                                       00059700
C                                                                       00059800
C                                                                       00059900
  140 FORMAT (20A4)                                                     00060000
  150 FORMAT ('1',130(1H=)/26X,20A4/1X,130(1H=))                        00060100
  160 FORMAT (8G10.0)                                                   00060200
  161 FORMAT (7I10)
  162 FORMAT (3I10,F10.1)
  163 FORMAT (I10,L10,F10.1)
  164 FORMAT (8I10)
  165 FORMAT (I10,5L10)
  166 FORMAT (I10,L10,F10.0)
  167 FORMAT (G10.0,G10.0,I10)                                                    kt added
  170 FORMAT ('0','PROPERTIES AND CHARACTERISTICS OF MODEL RUN'/1X,43(1H00060300
     1-)/10X,'BEGINNING DATE',38X,I2,'/',I2,'/',I4/10X,'ENDING DATE',41X00060400
     2,I2,'/',I2,'/',I4)                                                00060500
  180 FORMAT (' ',9X,'OBJECTIVES ARE TO COMPUTE - FOR EACH REACH',08X,'100060600
     1) DOWNSTREAM HYDROGRAPH'/60X,'2) BANK STORAGE DISCHARGE HYDROGRAPH00060700
     2')                                                                00060800
  190 FORMAT (' ',9X,'OBJECTIVE IS TO COMPUTE A BANK STORAGE DISCHARGE H00060900
     1YDROGRAPH FOR EACH REACH')                                        00061000
  200 FORMAT (' ',9X,'LENGTH OF TIME STEP   (HOURS)',F29.1/10X,'NUMBER O00061100
     1F REACHES IN THIS RUN',I27/10X,'NUMBER OF UPSTREAM REACHES',I30)  00061200
  210 FORMAT (' ',9X,'BASE FLOW AT UPSTREAM STATION   (CFS)',F21.1)     00061300
  220 FORMAT ('0',//' UPSTREAM STATION DATA',39X,'RATING TABLE'/1X,21(1H00061400
     1-),39X,12(1H-)/55X,'STAGE',12X,'DISCHARGE')                       00061500
  230 FORMAT (' ',39X,2F20.2/(40X,2F20.2))                              00061600
  240 FORMAT (6G10.0)                                                   00061700
  250 FORMAT (2A4,2X,17A4)                                              00061800
  260 FORMAT ('1',130(1H-)/10X,20A4,'   (REACH NO.',I3,')'/1X,130(1H-)//00061900
     11X,'PROPERTIES AND CHARACTERISTICS OF REACH'/1X,39(1H-))          00062000
  270 FORMAT (' ',9X,'LENGTH OF CHANNEL  (MILES)',F32.1/10X,'LENGTH OF A00062100
     1LLUVIUM  (MILES)',F31.1)                                          00062200
  280 FORMAT (' ',9X,'TRAVEL TIME  (ESTIMATED HOURS)',F28.1)            00062300
  290 FORMAT (' ',9X,'TRAVEL TIME TO BEGINNING OF RESPONSE  (HOURS)',F1300062400
     &.1,5X,'Cumulative from start of first reach =',F9.2,'  DAYS'         added for TTCUM   PRJ 2/8/85
     1  /10X,'TRAVEL TIME TO CENTER OF RESPONSE  (HOURS)',F16.1/10X,'TRA00062500
     2VEL TIME BETWEEN BREAKS IN HYDROGRAPHS  (HOURS)',F8.1)            00062600
  300 FORMAT (' ',9X,'NUMBER OF SUBREACHES USED IN COMPUTATIONS',I15/09X00062700
     1,' TRANSMISSIVITY OF AQUIFER (SQ.FT./DAY)',F20.1/09X,' STORAGE COE00062800
     2FFICIENT OF AQUIFER (CU.FT./CU.FT.)',F13.2)                       00062900
  310 FORMAT (' ',9X,'AQUIFER IS ASSUMED TO BE SEMI-INFINITE',16X,'CASE 00063000
     11')                                                               00063100
  320 FORMAT (' ',9X,'AQUIFER IS ASSUMED TO BE',F7.0,' (FT) WIDE'/20X,'(00063200
     1STREAM TO BOUNDARY)',23X,'CASE 2')                                00063300
  330 FORMAT (' ',9X,'AQUIFER IS ASSUMED TO BE SEMI-INFINITE'/15X,'WITH 00063400
     1A SEMI-PERVIOUS BED UNDER STREAM',10X,'CASE 3'/15X,'RETARDATION CO00063500
     2EF (FT)',F32.1)                                                   00063600
  340 FORMAT (' ',9X,'SOIL RETENTION FACTOR    ',F34.2)                 00063700
  350 FORMAT (' ',9X,'BASE FLOW AT DOWNSTREAM STATION',F27.1)           00063800
  355 FORMAT (' ',9X,'WAVE CELERITY',F46.2/                             00063900
     110X,'WAVE DISPERSION COEFFICIENT',F31.1)                          00064000
  360 FORMAT (' ',09X,'FLOW ROUTING UNIT-RESPONSE FUNCTION',10X,'NUMBER'00064100
     1,10X,'ORDINATE',/,57X,I2,F20.6/(57X,I2,F20.6))                    00064200
  361 FORMAT (' ',9X,'MINIMUN EXPECTED DISCHARGE TO BE ROUTED',F19.1/   00064300
     110X,'MAXIMUN EXPECTED DISCHARGE TO BE ROUTED',F19.1)              00064400
  362 FORMAT (' ',9X,'CELERITY AND DISPERSION RATING TABLE      W. CELER00064500
     1ITY  DISCHARGE       DISP. COEF.  DISCHARGE'/                     00064600
     251X,F10.2,F11.1,F18.1,F11.1/(51X,F10.2,F11.1,F18.1,F11.1))        00064700
  363 FORMAT (' ',9X,'NUM OF ROUTING UNIT-RESPONSE FUNCTIONS FORCED TO:'         kt added for NURSF
     1,I9)                                                                       kt added for NURSF
  365 FORMAT (' ',9X,'FAMILY OF FLOW ROUTING UNIT-RESPONSE FUNCTIONS'/  00064800
     1            15X,'NO.  W. CELERITY  DISP.COEF  TRAVEL TIME  DISCHAR00064900
     2GE',25X,'ORDINATES'/21X,' FT/SEC     SQ FT/SEC   TIME STEPS  CU FT00065000
     3/SEC')                                                            00065100
  368 FORMAT (' ',14X,I2,F10.2,F14.1,I9,F15.1,3X,5(I3,1H),F6.4,2X)/     00065200
     1(68X,5(I3,1H),F6.4,2X)))                                          00065300
  370 FORMAT ('0',//' DOWNSTREAM STATION DATA',37X,'RATING TABLE'/1X,23(00065400
     11H-),37X,12(1H-)/55X,'STAGE',12X,'DISCHARGE')                     00065500
  380 FORMAT ('0',60X,'SHIFT TABLE'/61X,11(1H-)/51X,'JULIAN WR-YR DAY)  00065600
     1  SHIFT(FT)')                                                     00065700
  390 FORMAT (' ',15X,7(I4,1H),F6.2,5X)/(16X,7(I4,1H),F6.2,5X)))        00065800
  400 FORMAT (' ',9X,'WARNING: MINIMUM FLOW DATA INDICATES STREAM MAY NO00065900
     1T BE IN HYDRAULIC CONTACT WITH AQUIFER.')                         00066000
      END                                                               00066100
      SUBROUTINE QBANK                                                  00066200
C                                                                       00066300
C     QBANK-- ITERATES BY ADJUSTING THE BANK STORAGE DISCHARGE AND      00066400
C             DOWNSTREAM DISCHARGE  UNTIL CHANGES BETWEEN SUCCESSIVE    00066500
C             ITERATIONS ARE SUFFICIENTLY SMALL.                        00066600
C             IF DOWNSTREAM DISCHARGE HYDROGRAPH IS KNOWN, BANK STORAGE 00066700
C             DISCHARGE IS COMPUTED ALONE.                              00066800
C                                                                       00066900
      IMPLICIT LOGICAL(Z)                                               00067000
      INTEGER OPFILE,C,P,PU,US,DS                                       00067100
      CHARACTER *4 STANO1(2),STANO2(2),STANM1(17),STANM2(17),INFO(20)        00067200
      DIMENSION UR(20,100), DUSRF(9000), QLIN(20), NRESP(20), ITT(20)    00067300
      REAL *8 UR
      DIMENSION Q(18000)                                                 00067400
      DIMENSION USS(9000), DSS(9000), DELS(9000), S(9000)                   00067500
      DIMENSION USQ(9000),DSQ(18000),DSQ1(9000),SQLOSS(18000),QI(18000) 00067600  kt fixed DSQ array size typo
      DIMENSION DSQO(9000)                                              00067601  kt added DSQO dim
      COMMON /ZLOGIC/ ZBEGIN,ZEND,ZPLOT,ZROUTE,ZFLOW,ZLOSS,ZDISK,ZCARDS,00067700
     1ZWARN,ZPRINT,ZPUNCH,ZUSHFT,ZDSHFT,ZMULT,ZDSQO,ZOUTPUT,ZFAST       00067800  kt fast option
      COMMON /PLT/ INITMO,INITDY,INITYR,LASTMO,LASTDY,LASTYR,NRECDS,STAN00067900
     1O1,STANM1,STANO2,STANM2,INFO,JYEAR                                00068000
      COMMON /RESFCT/ UR,DUSRF,QLIN,NURS,NRO,NRESP,ITT,NUR1,            00068100
     1                NSTAIL,NATAIL                                     00068200
      COMMON /DISCHA/ USQ,DSQ,DSQ1,QI,SQLOSS,USQB,DSQB,TOLRNC,DSQO      00068300  kt added DSQO
      COMMON /STAGES/ USS,DSS,DELS                                      00068400
      COMMON /TIMEPR/ TMAX,ITMAX,DT,NTS,KR,NDT24,NRCHS,NSR,KTSTRT,N1ST,N00068500
     12ND,NLST,IQBEG,IQEND,KCNT,IBEGR                                   00068600  KCNT and IBEGR added 2/12/85 PRJ
      COMMON /PARAM/ TT,TLAG,CHLGTH,ALLGTH,T,SS,ALPHA,XK,XKA,XL,CZERO,SO00068700
     1ILMS, TTCUM                                                       00068800  TTCUM ADDED 2/85 PRJ
      COMMON /VOL/ QILOST, WELCUM, QLSCUM, USREL1                       00068900   WELCUM, QLSCUM, and USREL1 added 2/10/85 PRJ
      COMMON /UNITS/ C,P,PU,US,DS,NDIM,MDIM                             00069000
C                                                                       00069100
C     ARRAYS IN TIME DIMENSION                                          00069200
C        S     - STAGE HYDROGRAPH AT CENTER OF SUBREACH.                00069300
C        DELS  - CHANGE IN S( ) BETWEEN TIME STEPS.                     00069400
C        QI    - BANK STORAGE DISCHARGE.                                00069500
C        Q     - TEMPORARY QI.                                          00069600
C                                                                       00069700
C             INITIALIZE                                                00069800
      IF (ZFLOW) GO TO 10                                               00069900
      IF (ZFAST) GO TO 10                                                         kt fast option
      WRITE (10,200)                                                    00070000
      JYEAR1=JYEAR+1                                                    00070100
      IF (ZROUTE.AND.ZDISK) WRITE (10,210) JYEAR1                       00070200
      IF (ZROUTE) WRITE (10,220)                                        00070300
   10 CONTINUE                                                          00070400
      IF (.NOT.ZBEGIN) GO TO 20                                         00070500
      CONST1=(ALLGTH*5280.)/(DT*3600.)                                  00070600
      CONST2=DT*3600.                                                   00070700
      TTEMP2=(T/24.)*DT*2.                                              00070800
      RNSR=1.0                                                          00070900
      NTS2=2*NTS                                                        00071000
      NADJ=NSR                                                          00071100
      DSAV1=0.0                                                         00071200
      DSAV2=0.0                                                         00071300
      DSAV3=0.0                                                         00071400
      QILOS1=0.0                                                        00071500
      QILOST=0.0                                                        00071600
      IF (NSR.EQ.0) GO TO 20                                            00071700
      RNSR=1./FLOAT(NSR)                                                00071800
   20 ITER=1                                                            00071900
      IF (ZROUTE) ITER=10                                               00072000
C                                                                       00072100
C             ITERATE                                                   00072200
      DO 120 I=1,ITER                                                   00072300
      CALL FILLB (DELS,N1ST,NLST,0.0)                                   00072400  kt changed to smaller dim B function
      CALL FILL (Q,N1ST,NLST+NUR1,0.0)                                  00072500
      TEST=0.0                                                          00072600
      SQI2=0.                                                           00072700
      SDSQ12=0.                                                         00072800
      SQA2=0.0                                                          00072900
      QILOS2=0.0                                                        00073000
C                                                                       00073100
C             COMPUTE BANK STORAGE DISCHARGE                            00073200
      CALL RATNG (DSQ1,DSS,DSQB,DS)                                     00073300
C      IF (NSR.LT.1) GO TO 30                                            00073400  kt warning fix
      NSRM = MAX(NSR,1)                                                           kt warning fix
      DO 50 N=1,NSRM                                                    00073500  kt warning fix, changed NSR to NSRM
   30 CALL MEANS (N,S)                                                  00073600
      DO 40 NT=N2ND,NLST                                                00073700
      DELS(NT)=S(NT)-S(NT-1)+DELS(NT)                                   00073800
   40 CONTINUE                                                                    kt warning fix
C
      IF (NSR.LT.1) GO TO 51
C        THIS AND '51' ADDED 12-13-85 IN ORDER TO RUN ON PRIMOS REV 9.4.4--GKUHN.
   50 CONTINUE                                                          00073900
   51 IF (NSR.EQ.0) GO TO 60                                            00074000
      CALL MULT (DELS,N1ST,NLST,RNSR)                                   00074100
   60 DELS(1)=(DSAV1+DSAV2+DSAV3+DELS(2)+DELS(3)+DELS(4))/6.            00074200
      CALL CONVOL (Q,DELS,DUSRF,N1ST,NLST,NUR1,0)                       00074300
      LAST=NLST                                                         00074400
      IF (.NOT.ZEND) LAST=NLST+NATAIL                                   00074500
      CALL MULTB (Q,N1ST,LAST,TTEMP2)                                   00074600  kt changed to larger dim B function
C                                                                       00074700
      IF (ZROUTE) GO TO 80                                              00074800
C             ADJUST FOR WATER RETAINED BY SOIL                         00074900
      DO 70 NT=N1ST,NLST                                                00075000
      IF (Q(NT).LE.0.0) GO TO 70                                        00075100
      QILOST=QILOST+Q(NT)*(1.00-SOILMS)                                 00075200
      Q(NT)=Q(NT)*SOILMS                                                00075300
      QI(NT)=Q(NT)                                                      00075400
   70 CONTINUE                                                                    kt warning fix
      GO TO 140                                                         00075500
C             COMPUTE ADJUSTMENTS FOR DOWNSTREAM HYDROGRAPH             00075600
   80 DO 110 NT=N1ST,NLST                                               00075700
      IF (Q(NT).LE.0.0) GO TO 90                                        00075800
      QILOS2=QILOS2+Q(NT)*(1.00-SOILMS)                                 00075900
      Q(NT)=Q(NT)*SOILMS                                                00076000
   90 FLOW=(QI(NT)-Q(NT))*CONST1                                        00076100
      FLOWA=ABS(FLOW)                                                   00076200
      IF (FLOWA.GT.TEST) TEST=FLOWA                                     00076300
      QI(NT)=Q(NT)                                                      00076400
      MT=NT+NADJ                                                        00076500
      IF (MT.GT.NLST) GO TO 100                                         00076600
      DSQ1(MT)=DSQ1(MT)-FLOW                                            00076700
      IF (DSQ1(MT).LT.0.0) DSQ1(MT)=0.0                                 00076800
  100 SDSQ12=SDSQ12+DSQ1(NT)                                            00076900
      SQA2=SQA2+FLOWA                                                   00077000
      SQI2=SQI2+QI(NT)*CONST1                                           00077100
  110 CONTINUE                                                                    kt warning fix
      SQA2=SQA2*CONST2/86400.                                           00077200
      SDSQ12=SDSQ12*CONST2/86400.                                       00077300
      SQI2=SQI2*CONST2/86400.                                           00077400
      IF (.NOT.ZFAST) WRITE (10,230) I,TEST,SQA2,SQI2,SDSQ12            00077500  kt fast option
C             LEAVE ITERATION LOOP IF TOLERANCE IS MET                  00077600
      IF (TEST.LT.TOLRNC) GO TO 130                                     00077700
  120 CONTINUE                                                          00077800
C                                                                       00077900
      WRITE (10,250)                                                    00078000
      STOP                                                              00078100
  130 IF (.NOT.ZFAST) WRITE (10,240) I,TOLRNC,TEST,NADJ                 00078200  kt fast option
      CALL RATNG (DSQ1,DSS,DSQB,DS)                                     00078300
      QILOST=QILOST+QILOS2                                              00078400
      DSAV3=DELS(NLST-2)                                                00078500
      DSAV2=DELS(NLST-1)                                                00078600
      DSAV1=DELS(NLST)                                                  00078700
  140 CONTINUE                                                          00078800
      IF (ZCARDS) GO TO 190                                             00078900
C                                                                       00079000
C             DISK OPTION --                                            00079100
C             DATA OVERLAPING WATER YEAR ENDS ARE SAVED AND USED        00079200
      QILOST=QILOST+QILOS1                                              00079300
      QILOS1=0.0                                                        00079400
C             ADJUST DSQ1 FOR PREVIOUS QI TAIL                          00079500
C             COMPUTE QI LOST TO SOIL DURING THE PERIOD OF QI TAIL      00079600
C             ADD PREVIOUS QI TAIL TO BEGINNING OF NEW QI ARRAY         00079700
C             MOVE Q TAIL AND 20 LEAD-IN VALUES INTO QI TAIL            00079800
C        NOTE:  QI TAIL IS SAVED IN THE LAST HALF OF THE QI ARRAY       00079900
      DO 170 NT=1,NATAIL                                                00080000
      IF (ZFLOW) GO TO 150                                              00080100
      MT=NT-NADJ                                                        00080200
      DSQ1(NT)=DSQ1(NT)+QI(MT+NDIM)*CONST1                              00080300
  150 CONTINUE                                                          00080400
      IF (Q(NT+NLST).LE.0.0) GO TO 160                                  00080500
      QILOS1=QILOS1+Q(NT+NLST)*(1.00-SOILMS)                            00080600
      Q(NT+NLST)=Q(NT+NLST)*SOILMS                                      00080700
  160 QI(NT)=QI(NT)+QI(NT+NDIM)                                         00080800
      QI(NT+NDIM)=Q(NT+NLST)                                            00080900
  170 CONTINUE                                                                    kt warning fix
      IF (ZFLOW) GO TO 190                                              00081000
      IF (NLST.LE.20) GO TO 190                                         00081100
      NDIM20=NDIM-20                                                    00081200
      NLST20=NLST-20                                                    00081300
      DO 180 NT=1,20                                                    00081400
      QI(NDIM20+NT)=QI(NLST20+NT)                                       00081500
  180 CONTINUE                                                                    kt warning fix
  190 CONTINUE                                                          00081600
C                                                                       00081700
C                                                                       00081800
C                                                                       00081900
      RETURN                                                            00082000
C                                                                       00082100
  200 FORMAT ('1')                                                      00082200
  210 FORMAT ('0',20X,I4,' WATER YEAR')                                 00082300
  220 FORMAT ('0',1X,'SUMMARY OF ITERATION DATA FOR ROUTING OPTION'/2X,400082400
     14(1H-)//23X,'CHANGES BETWEEN ITERATIONS',18X,'VOLUMES AT END OF IT00082500
     2ERATION'/15X,43(1H-),06X,35(1H-)//' ITERATION        MAXIMUM CHANG00082600
     3E          ABSOLUTE CHANGE       NET VOLUME         VOLUME OF FLOW00082700
     4'/'    NO.                 IN                      IN             00082800
     5     OF                   AT',/,'              BANK STORAGE DISCHA00082900
     6RGE    BANK STORAGE VOLUME    BANK STORAGE      DOWNSTREAM STATION00083000
     7',/,'                      (CFS)                 (CFS - DAYS)     00083100
     8   (CFS - DAYS)        (CFS - DAYS)')                             00083200
  230 FORMAT ('0',I5,F20.1,F26.0,F20.0,F21.0)                           00083300
  240 FORMAT ('0',' CLOSURE WAS OBTAINED AFTER ',I2,' ITERATIONS',/,5X,'00083400
     1CRITERIA FOR CLOSURE',F24.1,' CFS',/,5X,'GREATEST CHANGE IN LAST I00083500
     2TERATION ',F10.1,' CFS',//,' BANK STORAGE DISCHARGE AFFECTED DOWNS00083600
     3TREAM ROUTED DISCHARGE',I3,' TIME STEPS LATER.')                  00083700
  250 FORMAT ('1',' NOTE: CLOSURE WAS NOT OBTAINED IN ITERATION LOOP IN 00083800
     1SUBROUTINE QBANK.  COMPUTATIONS ARE TERMINATED.'/8X,'TRY A SMALLER00083900
     2 TRANSMISSIVITY VALUE.')                                          00084000
      END                                                               00084100
      SUBROUTINE AQTYPE (ICASE)                                         00084200
C                                                                       00084300
C     AQTYPE- COMPUTES THE  'DERIVATIVE OF THE UNIT STEP RESPONSE       00084400
C             FUNCTION' FOR EITHER OF THREE BOUNDARY CONDITIONS.        00084500
C             PRINTS RESULTS.                                           00084600
C                                                                       00084700
      INTEGER OPFILE,C,P,PU,US,DS                                       00084800
      DIMENSION UR(20,100), DUSRF(9000), QLIN(20), NRESP(20), ITT(20)    00084900
      REAL *8 UR
C      COMMON /ZLOGIC/ ZBEGIN,ZEND,ZPLOT,ZROUTE,ZFLOW,ZLOSS,ZDISK,ZCARDS,00067700  kt fast option
C     1ZWARN,ZPRINT,ZPUNCH,ZUSHFT,ZDSHFT,ZMULT,ZDSQO,ZOUTPUT,ZFAST       00067800  kt fast option
      COMMON /RESFCT/ UR,DUSRF,QLIN,NURS,NRO,NRESP,ITT,NUR1,            00085000
     1                NSTAIL,NATAIL                                     00085100
      COMMON /TIMEPR/ TMAX,ITMAX,DT,NTS,KR,NDT24,NRCHS,NSR,KTSTRT,N1ST,N00085200
     12ND,NLST,IQBEG,IQEND,KCNT,IBEGR                                   00085300  KCNT and IBEGR added 2/12/85 PRJ
      COMMON /PARAM/ TT,TLAG,CHLGTH,ALLGTH,T,SS,ALPHA,XK,XKA,XL,CZERO,SO00085400
     1ILMS, TTCUM                                                       00085500  TTCUM ADDED 2/85 PRJ
      COMMON /UNITS/ C,P,PU,US,DS,NDIM,MDIM                             00085600
C                                                                       00085700
      CALL FILLB (DUSRF,1,NTS,0.0)                                      00085800  kt changed to smaller dim B function
      IF (ALPHA.LT.1.) RETURN                                           00085900
C      IF (ZFAST) GO TO 5                                                          kt fast option
      GO TO 5                                                                     kt fast option hardwired
      WRITE (10,190)                                                    00086000
    5 CONTINUE                                                                    kt fast option
      IF (ICASE.EQ.1) GO TO 10                                          00086100
      IF (ICASE.EQ.2) GO TO 30                                          00086200
      IF (ICASE.EQ.3) GO TO 70                                          00086300
C             CASE 1                                                    00086400
C             ------                                                    00086500
   10 CONTINUE                                                          00086600
      DO 20 NT=1,NTS                                                    00086700
      TIME=FLOAT(NT)-.5                                                 00086800
      DUSRF(NT)=-1./SQRT(3.1416*ALPHA*TIME)                             00086900
      IF (DUSRF(NT).GT.-1.E-20) GO TO 140                               00087000
   20 CONTINUE                                                          00087100
      GO TO 140                                                         00087200
C             CASE 2                                                    00087300
C             ------                                                    00087400
   30 CONTINUE                                                          00087500
      I=0                                                               00087600
      DO 60 NT=1,NTS                                                    00087700
      TIME=FLOAT(NT)-.5                                                 00087800
      N=0                                                               00087900
      D=0.                                                              00088000
   40 DD=D                                                              00088100
      IF (N.EQ.25) GO TO 50                                             00088200
      N=N+1                                                             00088300
      C1=FLOAT(2*N-1)*3.1416/(2.*XL)                                    00088400
      D=D+EXP(-C1**2*ALPHA*TIME)                                        00088500
      X1=ABS(DD-D)                                                      00088600
      IF (X1.GT..001) GO TO 40                                          00088700
      DUSRF(NT)=-(2./XL)*D                                              00088800
      IF (DUSRF(NT).GT.-1.E-20) GO TO 140                               00088900
      GO TO 60                                                          00089000
   50 I=I+1                                                             00089100
      DUSRF(NT)=-1./SQRT(3.1416*ALPHA*TIME)                             00089200
   60 CONTINUE                                                          00089300
      GO TO 140                                                                    kt fast option hardwiring
      IF (I.GE.1) WRITE (10,220) I                                      00089400
      GO TO 140                                                         00089500
C             CASE 3                                                    00089600
C             ------                                                    00089700
   70 CONTINUE                                                          00089800
      DO 80 NT=1,NTS                                                    00089900
      TIME=FLOAT(NT)-.5                                                 00090000
      ARG1=SQRT(ALPHA*TIME)/XKA                                         00090100
      IF (ARG1.GT.3.8) GO TO 90                                         00090200
      DUSRF(NT)=-(1./XKA)*EXP(ARG1**2.)*erfc(ARG1)                      00090300
   80 CONTINUE                                                                    kt warning fix
   90 IF (NT.EQ.NTS) GO TO 140                                          00090400
      X1=DUSRF(1)/22.63                                                 00090500
      IF (X1.LT.DUSRF(NT-1)) GO TO 140                                  00090600
      NT1=NT-1                                                          00090700
      WRITE (10,230) NT1                                                00090800
C             FIND CORRESPONDING LOCATION ON FUNCTION CURVE OF CASE 1   00090900
      NT1=NT                                                            00091000
      DRF1=DUSRF(NT-1)                                                  00091100
      DO 100 I=1,50                                                     00091200
      K=I-1                                                             00091300
      TIME=FLOAT(NT1+K)-.5                                              00091400
      DRF2=-1./SQRT(3.1416*ALPHA*TIME)                                  00091500
      IF (DUSRF(NT-1).LT.DRF2) GO TO 110                                00091600
      DRF1=DRF2                                                         00091700
  100 CONTINUE                                                                    kt warning fix
      I=0                                                               00091800
      GO TO 120                                                         00091900
  110 D=(DRF1+DRF2)/2.                                                  00092000
      IF (DUSRF(NT-1).GT.D) GO TO 120                                   00092100
      I=I-1                                                             00092200
  120 CONTINUE                                                          00092300
C             CONTINUE COMPUTATIONS ASSUMING CASE 1                     00092400
      DO 130 NT=NT1,NTS                                                 00092500
      TIME=FLOAT(NT+I)-.5                                               00092600
      DUSRF(NT)=-1./SQRT(3.1416*ALPHA*TIME)                             00092700
      IF (DUSRF(NT).GT.-1.E-20) GO TO 140                               00092800
  130 CONTINUE                                                          00092900
C             COMPUTE VALUE OF RESPONSE FUNCTION AFTER DECAYING THROUGH 00093000
C                 4.5 HALF-LIVES.  THE SYSTEM'S RESPONSE IS IGNORED    00093100
C                  AFTER 4.5 HALF-LIVES (1ST VALUE*(1/(2**4.5))).       00093200
C
C           CHANGE HALF-LIVES TO 18.5 FROM 4.5.  GKUHN, 6/6/86.
C           THIS CAUSES MORE UNIT-RESPONSE ORDINATES TO BE COMPUTED.
C
  140 X1=DUSRF(1)/370728.                                                 00093400
      IF (X1.GT.DUSRF(NTS)) GO TO 170                                   00093500
      DO 150 NT=1,NTS                                                   00093600
      IF (X1.LT.DUSRF(NT)) GO TO 160                                    00093700
  150 CONTINUE                                                          00093800
  160 NUR1=NT                                                           00093900
C             PRINT RESULTS                                             00094000
C      IF (ZFAST) GO TO 181                                                        kt fast option
      GO TO 181                                                                    kt fast option hardwiring
      WRITE (10,210) NUR1                                               00094100
      GO TO 180                                                         00094200
  170 NUR1=NTS                                                          00094300
      GO TO 181                                                                    kt fast option hardwiring
      WRITE (10,210) NUR1                                               00094100
  180 WRITE (10,200) (NT,DUSRF(NT),NT=1,NUR1)                           00094400
  181 CONTINUE                                                                    kt fast option
      NATAIL=NUR1-1                                                     00094500
C                                                                       00094600
C                                                                       00094700
C                                                                       00094800
      RETURN                                                            00094900
C                                                                       00095000
  190 FORMAT (' ',09X,'STREAM-AQUIFER UNIT-RESPONSE FUNCTION')          00095100
  200 FORMAT (' ',15X,6(I4,1H),F10.6,3X)/(16X,6(I4,1H),F10.6,3X)))      00095200
  210 FORMAT (' ',15X,'NOTE: THIS RESPONSE FUNCTION (EXPONENTIAL DECAY T00095300
     1YPE IS EVALUATED FOR 18.5 HALF-LIVES.'/22X,'IT HAS',I4,' ORDINATES00095400
     2.')                                                                00095500
  220 FORMAT (' ',15X,'NOTE: CLOSURE WAS NOT OBTAINED FOR THE FIRST',I3,00095600
     1' NUMBERS.'/22X,'COMPUTATIONS WERE MADE USING CASE 1 CONDITIONS FO00095700
     2R THESE NUMBERS.')                                                00095800
  230 FORMAT (' ',15X,'NOTE: ARGUMENT OF ERFC GOT LARGER THAN 3.8.'/22X,00095900
     1'COMPUTATIONS WERE MADE USING CASE 1 ASSUMPTIONS FOR NUMBERS GREAT00096000
     2ER THAN',I4,'.')                                                  00096100
      END                                                               00096200
      SUBROUTINE TABL (X1,Y1,X,Y,NQ)                                    00096300
C                                                                       00096400
C     1 OCT 76                                                          00096500
C                                                                       00096600
C     LINEAR INTERPOLATION ROUTINE                                      00096700
C                                                                       00096800
      DIMENSION X(10), Y(10), Y1(10)                                    00096900
      NQ=0                                                              00097000
      IF (X1.LT.0.) GO TO 40                                            00097100
      IF (X1.LT.X(1)) GO TO 30                                          00097200
      DO 20 I=1,7                                                       00097300
      IF (X(I+1).LE.0) GO TO 40                                         00097400
      IF (X1.GE.X(I).AND.X1.LT.X(I+1)) GO TO 10                         00097500
      IF (X1.LT.X(I).AND.X1.GT.X(I+1)) GO TO 10                         00097600
      IF (I.EQ.7.AND.NQ.EQ.0) GO TO 10                                  00097650
      GO TO 20                                                          00097700
   10 NQ=NQ+1                                                           00097800
      Y1(NQ)=Y(I)+(((Y(I+1)-Y(I))/(X(I+1)-X(I)))*(X1-X(I)))             00097900
   20 CONTINUE                                                          00098000
      RETURN                                                            00098100
   30 NQ=1                                                              00098200
      Y1(NQ)=(Y(1)/X(1))*X1                                             00098300
   40 IF (NQ.NE.0) RETURN                                               00098400
      WRITE (1,50)                                                      00098500
      STOP                                                              00098600
C                                                                       00098700
   50 FORMAT (1H ,30HVARIABLE OUT OF RANGE OF TABLE)                    00098800
      END                                                               00098900
      SUBROUTINE UNRESP (ZMULT)                                         00099000
C                                                                       00099100
C     UNRESP- COMPUTES RESPONSE FUNCTION(S) BY DIFFUSION ANALOGY        00099200
C                                                                       00099300
C        ZMULT=.FALSE. - SINGLE RESPONSE FUNCTION (LINEAR)              00099400
C             =.TRUE.  - FAMILY OF RESPONSE FUNCTIONS (MULTI-LINEAR)    00099500
C                                                                       00099600
      INTEGER OPFILE,C,P,PU,US,DS
      LOGICAL ZMULT,ZORDER                                              00099800
      REAL *8 BIGNUM, H
      REAL *8 URSUM,REO
      REAL *8 REDUCE
      REAL *8 SUM, POWER
      REAL K                                                            00099900
      DIMENSION CC(20), BPC(10), CBP(10), Q2T(10), BPW(10), WBP(10),    00100000  kt dim Q2T 5 to 10
     1Q1T(20)                                                           00100100
      DIMENSION USQ(9000),DSQ(18000),DSQ1(9000),SQLOSS(18000),QI(18000) 00100200
      DIMENSION AC0(20), AXK(20), C0RAT(10), C0QRAT(10),                00100300
     1XKRAT(10), XKQRAT(10)                                             00100400
      DIMENSION DUMMY(10)                                               00100401  kt added dummy arg
      COMMON /URPARM/ AC0,AXK,QMIN,QMAX,C0RAT,C0QRAT,XKRAT,XKQRAT,NURSF 00100500  kt added NURSF
      DIMENSION UR(20,100), DUSRF(9000), QLIN(20), NRESP(20), ITT(20)    00100600
      REAL *8 UR
      COMMON /RESFCT/ UR,DUSRF,QLIN,NURS,NRO,NRESP,ITT,NUR1,            00100700
     1                NSTAIL,NATAIL                                     00100800
      COMMON /TIMEPR/ TMAX,ITMAX,DT,NTS,KR,NDT24,NRCHS,NSR,KTSTRT,N1ST,N00100900
     12ND,NLST,IQBEG,IQEND,KCNT,IBEGR                                   00101000  KCNT and IBEGR added 2/12/85 PRJ
      COMMON /PARAM/ TT,TLAG,CHLGTH,ALLGTH,T,SS,ALPHA,XK,XKA,XL,CZERO,SO00101100
     1ILMS, TTCUM                                                       00101200  TTCUM ADDED 2/85 PRJ
      COMMON /UNITS/ C,P,PU,US,DS,NDIM,MDIM                             00101300
      EQUIVALENCE (X,CHLGTH),(K,XK),(C,LCARD),(LPRNT,P),(DT,RI)         00101400
      EQUIVALENCE (C0RAT(1),CBP(1)),(C0QRAT(1),BPC(1)),                 00101500
     1            (XKRAT(1),WBP(1)),(XKQRAT(1),BPW(1))                  00101600
      DATA BIGNUM /1.0E+25/
C                                                                       00101700
C     INITIALIZE UNIT RESPONSE ARRAY.                                   00101800
      DO 10 J = 1,100
      DO 20 I = 1,20
      UR (I,J) = 0.0
   20 CONTINUE
   10 CONTINUE
      NURS=1                                                            00102000
      TTSUM=0.0                                                         00102100
      TMSUM=0.0                                                         00102200
      NRF=1                                                             00102300
      ITT(1)=0                                                          00102400
C     NURS=NUMBER OF UNIT RESPONSE FUNCTIONS.                           00102500
C     NRF=RESPONSE FUNCTION NUMBER.                                     00102600
C     NRO=NUMBER OF ORDINATES IN RESPONSE FUNCTION.                     00102700
      SUM=0.0                                                           00102800
   30 IF (ZMULT) GO TO 40                                               00102900
      GO TO 160                                                         00103000
   40 ZORDER=.FALSE.                                                    00103100
      NQ=1                                                              00103200
      CALL TABL (QMIN,DUMMY,BPC,CBP,NQ)                                 00103300  kt dummy arg
      CMIN=DUMMY(1)                                                               kt dummy arg
      NQ=1                                                              00103400
      CALL TABL (QMAX,DUMMY,BPC,CBP,NQ)                                 00103500  kt dummy arg
      CMAX=DUMMY(1)                                                               kt dummy arg
      TMIN0=((5280.*X)/CMAX)/3600.                                      00103600
      TMAX0=((5280.*X)/CMIN)/3600.                                      00103700
      NURS=(TMAX0-TMIN0)/RI+0.501                                       00103800
      IF (NURS.LE.1) NURS=2                                             G. KUHN, 5-1-86  kt changed from EQ to LE
      IF (RI.EQ.24.) NURS=20                                            00103900
      IF (NURSF.GT.0) NURS=NURSF                                                 kt added to force number of URFs, max 20
   50 IF (NURS.GT.20) NURS=20                                           00104000
      TCHK=(TMAX0-TMIN0)/(NURS-1)                                       00104100
      IF (NURS.LT.20) TCHK=RI                                           00104200
   60 TNEXT=TMAX0                                                       00104300
      NRF=0                                                             00104400
      DO 100 NN=1,NURS                                                  00104500
      IF (NN.LT.NURS) GO TO 70                                          00104600
      CLRTY=CMAX                                                        00104700
      NQ=1                                                              00104800
      GO TO 80                                                          00104900
   70 CLRTY=((5280.*X)/TNEXT)/3600.                                     00105000
      NQ=5                                                              00105100
   80 CALL TABL (CLRTY,Q2T,CBP,BPC,NQ)                                  00105200
      IF (NQ.GT.1) ZORDER=.TRUE.                                        00105300
      DO 90 LL=1,NQ                                                     00105400
      NRF=NRF+1                                                         00105500
      CC(NRF)=CLRTY                                                     00105600
      Q1T(NRF)=Q2T(LL)                                                  00105700
   90 CONTINUE                                                                    kt warning fix
      TNEXT=TNEXT-TCHK                                                  00105800
  100 CONTINUE                                                          00105900
      IF (NRF.LE.20) GO TO 110                                          00106000
      TCHK=(NRF/20)*RI                                                  00106100
      GO TO 60                                                          00106200
  110 NURS=NRF                                                          00106300
C     ORDER CELERITY AND DISCHARGE ON INCREASING DISCHARGE.             00106400
      IF (.NOT.ZORDER) GO TO 130                                        00106500
      IP2=NURS-1                                                        00106600
      DO 120 NRF=1,IP2                                                  00106700  kt warning fix
      IP1=NRF+1                                                         00106800
      DO 115 J=IP1,NURS                                                 00106900
      IF (Q1T(NRF).LE.Q1T(J)) GO TO 120                                 00107000
      TEMP=Q1T(NRF)                                                     00107100
      Q1T(NRF)=Q1T(J)                                                   00107200
      Q1T(J)=TEMP                                                       00107300
      TEMP=CC(NRF)                                                      00107400
      CC(NRF)=CC(J)                                                     00107500
      CC(J)=TEMP                                                        00107600
  115 CONTINUE                                                                    kt warning fix
  120 CONTINUE                                                          00107700
C        GENERATE FLAGGING TABLE, QLIN=LINEARIZATION DISCHARGE OF Q.    00107800
  130 LF=NURS-1                                                         00107900
      DO 140 NRF=1,LF                                                   00108000
      QLIN(NRF)=(Q1T(NRF)+Q1T(NRF+1))/2.                                00108100
  140 CONTINUE                                                                    kt warning fix
      QLIN(NURS)=Q1T(NURS)                                              00108200
      NRF=1                                                             00108300
  150 Q3T=Q1T(NRF)                                                      00108400
C        FIND DISPERSION COEFFICIENT.                                   00108500
      CALL TABL (Q3T,DUMMY,BPW,WBP,NQ)                                  00108600  kt dummy arg 
      K=DUMMY(1)                                                                  kt dummy arg
      CZERO=CC(NRF)                                                     00108700
      AC0(NRF)=CZERO                                                    00108800
      AXK(NRF)=K                                                        00108900
  160 SK = 3600. * K
      SC=3600.*CZERO                                                    00109100
      XFT=5280.*X                                                       00109200
      SC2=SC*SC                                                         00109300
      TMEAN=XFT/SC+2*SK/SC2                                             00109400
      TT=TMEAN-(2.78*SQRT(2.*SK*XFT/(SC2*SC)+(8.*SK/SC2)*(SK/SC2)))     00109500
      TTSUM=TTSUM+TT                                                    00109600
      TMSUM=TMSUM+TMEAN                                                 00109700
      TLAG=TMEAN                                                        00109800
      IF (TT.LE.0.0) TT=0.0                                             00109900
      TT1=TT/RI                                                         00110000
      ITT(NRF)=IFIX(TT1+0.5)                                            00110100
      TT1=ITT(NRF)*RI                                                   00110200
      TIME=TT1                                                          00110300
      IF (TIME.LE.0.0) TIME=0.001                                       00110400
      TINT=0.1                                                          00110500
      ILIM=IFIX((1.0/TINT)+0.5)                                         00110600
      ICYCLE=0                                                          00110700
      URSUM=0.0                                                         00110800
      NRO=1                                                             00110900
      NFLAG=0                                                           00111000
      JNO=0                                                             00111100
  170 POWER=SC*TIME-XFT                                                 00111200
      POWER=-(POWER*POWER)                                              00111300
      POWER=POWER/(4.*SK*TIME)                                          00111400
      IF (POWER.LT.-170.) POWER=-170.                                   00111500
      H=(BIGNUM/(2.*SQRT(3.1415927*SK)))*XFT/(TIME**(3./2.))
      H = H * BIGNUM
      H=H*DEXP(POWER)                                                    00111700
      IF (NFLAG.EQ.1) GO TO 210                                         00111800
      JNO=JNO+1                                                         00111900
      ICYCLE=ICYCLE+1                                                   00112000
      URSUM=URSUM+H                                                     00112100
      IF (JNO.GT.ILIM) GO TO 200                                        00112200
  180 REO=TINT*URSUM                                                    00112300
      UR(NRF,NRO)=UR(NRF,NRO)+TINT*REO                                  00112400
      IF (ICYCLE.EQ.ILIM) GO TO 220                                     00112500
  190 TIME=TIME+RI*TINT                                                 00112600
      GO TO 170                                                         00112700
  200 NFLAG=1                                                           00112800
      TIME=TIME-RI                                                      00112900
      IF (TIME.LE.0.0) TIME=0.001                                       00113000
      GO TO 170                                                         00113100
  210 TIME=TIME+RI                                                      00113200
      NFLAG=0                                                           00113300
      URSUM=URSUM-H                                                     00113400
      GO TO 180                                                         00113500
  220 IF (UR(NRF,NRO).LT.0.0) UR(NRF,NRO)=0.0                           00113600
      SUM=SUM+UR(NRF,NRO)                                               00113700
C     SUM CHECK DELETED BY J SHEARMAN 6/30/78                           00113850
C     IF (SUM.GE.1.00) GO TO 240                                        00113800
      REDUCE = UR(NRF,NRO)/BIGNUM
      IF (REDUCE.LT.1.0E+21.AND.(UR(NRF,NRO)/SUM).LT.0.002)
     *    GO TO 230                                                     00114000
      IF (NRO.EQ.100) GO TO 240                                         00114100
      ICYCLE=0                                                          00114200
      NRO=NRO+1                                                         00114300
      GO TO 190                                                         00114400
  230 SUM=SUM-UR(NRF,NRO)                                               00114500
      NRO=NRO-1                                                         00114600
  240 CONTINUE                                                          00114700
  260 CONTINUE                                                          00114800
      DO 270 I=1,NRO                                                    00114900
      UR(NRF,I)=UR(NRF,I)/SUM                                           00115000
  270 CONTINUE                                                          00115100
      IF (ZMULT) GO TO 290                                              00115200
      NRESP(1)=NRO                                                      00115300
      RETURN                                                            00115400
  290 CONTINUE                                                          00115500
      NRESP(NRF)=NRO                                                    00115600
      NRF=NRF+1                                                         00115700
      IF (NRF.GT.NURS) GO TO 300                                        00115800
      NRO=1                                                             00115900
      SUM=0.0                                                           00116000
      GO TO 150                                                         00116100
  300 CONTINUE                                                          00116200
      TT=TTSUM/NURS                                                     00116300
      TLAG=TMSUM/NURS                                                   00116400
      RETURN                                                            00116500
C                                                                       00116600
      END                                                               00116700
      SUBROUTINE UTILIT                                                 00116800
C                                                                       00116900
C     UTILIT- PROGRAMMED BY J O SHEARMAN.  A UTILITY PROGRAM TO PROVIDE 00117000
C             1) FILL AN ARRAY WITH A CONSTANT;                         00117100
C             THE FOLLOWING SERVICES:                                   00117200
C             2) MULTIPLY AN ARRAY BY A CONSTANT;                       00117300
C             3) MOVE ONE ARRAY TO ANOTHER ARRAY, WITH OFFSETS;         00117400
C             4) ADD TWO ARRAYS;                                        00117500
C             5) CONVOLUTE TWO ARRAYS, ACCUMULATE RESULT IN A THIRD;    00117600
C             6) FIND MINIMUM AND MAXIMUM VALUES IN AN ARRAY.           00117700
C             7) CONVOLUTE WITH A FAMILY OF RESPONSE FUNCTIONS          00117800
C        CONVOL CONVOLUTES ELEMENTS I1 THRU I2 OF ARRAY B (THE          00117900
C        INPUT FUNCTION) WITH ELEMENTS 1 THRU NRO OF ARRAY C (THE       00118000
C        RESPONSE FUNCTION) AND ACCUMULATES THE RESULT IN ARRAY A       00118100
C        (THE OUTPUT FUNCTION),WHICH MAY BE LAGGED BY LAG TIME          00118200
C        INTERVALS.                                                     00118300
C                                                                       00118400
      DIMENSION A (9000), B(9000), CUTIL(9000)                                   kt added smaller dim
      DIMENSION AB (18000), BB(18000), CUTILB (18000)                            kt changed larger dim vars to name B
      DIMENSION CCC(20,100), QLIN(20), LAG(20), NRESP(20)
      REAL *8 CCC
      ENTRY FILL(AB,I1,I2,VALU)                                         00118700  kt changed FILL function for larger dims
C           ----                                                        00118800
      DO 10 I=I1,I2                                                     00118900
      AB(I)=VALU                                                        00119000  kt changed FILL function for larger dims
   10 CONTINUE                                                          00119100
      RETURN                                                            00119200
C                                                                       00119300
      ENTRY FILLB(A,I1,I2,VALU)                                         00118700  kt added B function for smaller dims
C           ----                                                        00118800  kt added B function for smaller dims
      DO 15 I=I1,I2                                                     00118900  kt added B function for smaller dims
      A(I)=VALU                                                         00119000  kt added B function for smaller dims
   15 CONTINUE                                                          00119100  kt added B function for smaller dims
      RETURN                                                            00119200  kt added B function for smaller dims
C                                                                       00119300  kt added B function for smaller dims
      ENTRY MULT(A,I1,I2,VALU)                                          00119400
C           ----                                                        00119500
      DO 20 I=I1,I2                                                     00119600
      A(I)=A(I)*VALU                                                    00119700
   20 CONTINUE                                                          00119800
      RETURN                                                            00119900
C                                                                       00120000
      ENTRY MULTB(AB,I1,I2,VALU)                                        00119400  kt added B function for larger dims
C           ----                                                        00119500  kt added B function for larger dims
      DO 25 I=I1,I2                                                     00119600  kt added B function for larger dims
      AB(I)=AB(I)*VALU                                                  00119700  kt added B function for larger dims
   25 CONTINUE                                                          00119800  kt added B function for larger dims
      RETURN                                                            00119900  kt added B function for larger dims
C                                                                       00120000  kt added B function for larger dims
      ENTRY MOVE(BB,AB,I1,I2,ISHFTA,ISHFTB)                             00120100  kt changed MOVE function to larger dims
C           ----                                                        00120200 
      DO 30 I=I1,I2                                                     00120300
      AB(I+ISHFTA)=BB(I+ISHFTB)                                         00120400  kt changed MOVE function to larger dims
   30 CONTINUE                                                          00120500
      RETURN                                                            00120600
C                                                                       00120700
      ENTRY MOVEB(BB,A,I1,I2,ISHFTA,ISHFTB)                             00120100  kt added B function for mix of dims
C           ----                                                        00120200  kt added B function for mix of dims
      DO 35 I=I1,I2                                                     00120300  kt added B function for mix of dims
      A(I+ISHFTA)=BB(I+ISHFTB)                                          00120400  kt added B function for mix of dims
   35 CONTINUE                                                          00120500  kt added B function for mix of dims
      RETURN                                                            00120600  kt added B function for mix of dims
C                                                                       00120700  kt added B function for mix of dims
      ENTRY ADD (CUTIL,B,A,I1,I2)
C           ---                                                         00120900
      DO 40 I=I1,I2                                                     00121000
      A(I)=B(I)+CUTIL(I)
   40 CONTINUE                                                          00121200
      RETURN                                                            00121300
C                                                                       00121400
      ENTRY CONVOL(AB,B,CUTIL,I1,I2,NRO,LAG0)                                     kt changed CONVOL function to mix of dims
C           ------                                                      00121600
      DO 50 I=I1,I2                                                     00121700
      DO 45 J=1,NRO                                                     00121800  kt warning fix
      K=I+J-1+LAG0                                                      00121900
      AB(K) = AB(K) + B(I)*CUTIL(J)                                               kt changed CONVOL function to mix of dims
   45 CONTINUE                                                                    kt warning fix
   50 CONTINUE                                                          00122100
      RETURN                                                            00122200
C                                                                       00122300
      ENTRY PMM(XMN,XMX,A,N)                                            00122400
C           ---                                                         00122500
      IF (N.LT.2) GO TO 70                                              00122600
      XMN=A(1)                                                          00122700
      XMX=XMN                                                           00122800
      DO 60 I=2,N                                                       00122900
      IF (A(I).LT.XMN) XMN=A(I)                                         00123000
      IF (A(I).GT.XMX) XMX=A(I)                                         00123100
   60 CONTINUE                                                          00123200
      RETURN                                                            00123300
   70 IF (N.LT.1) GO TO 80                                              00123400
      XMN=A(1)                                                          00123500
      XMX=XMN                                                           00123600
      RETURN                                                            00123700
   80 XMN=0.                                                            00123800
      XMX=0.                                                            00123900
      RETURN                                                            00124000
C                                                                       00124100
      ENTRY CVOLUT(AB,B,CCC,I1,I2,NRO,NURS,QLIN,LAG,NRESP)                         kt changed CVOLUT function to mix of dims
C           ------                                                      00124300
      IF (NURS.GT.1) GO TO 100                                          00124400
      L=1                                                               00124500
      DO 90 I=I1,I2                                                     00124600
      DO 85 J=1,NRO                                                     00124700  kt warning fix
      K=I+J-1+LAG(L)                                                    00124800
      AB(K)=AB(K) + B(I) * CCC(L,J)                                               kt changed CVOLUT function to mix of dims
   85 CONTINUE                                                                    kt warning fix
   90 CONTINUE                                                          00125000
      RETURN                                                            00125100
  100 DO 160 I=I1,I2                                                    00125200
      QB=B(I)                                                           00125300
      DO 110 LL=1,NURS                                                  00125400
      IF (QB.LE.QLIN(LL)) GO TO 120                                     00125500
  110 CONTINUE                                                          00125600
      L=NURS                                                            00125700
      GO TO 130                                                         00125800
  120 L=LL                                                              00125900
  130 IF (L.EQ.1) GO TO 140                                             00126000
      QB=QB-QLIN(L-1)                                                   00126100
  140 NRO=NRESP(L)                                                      00126200
      DO 150 J=1,NRO                                                    00126300
      K=I+J-1+LAG(L)                                                    00126400
      AB(K) = AB(K) + QB * CCC(L,J)                                               kt changed CVOLUT function to mix of dims
  150 CONTINUE                                                          00126600
      IF (L.EQ.1) GO TO 160                                             00126700
      QB=QLIN(L-1)                                                      00126800
      L=L-1                                                             00126900
      GO TO 130                                                         00127000
  160 CONTINUE                                                          00127100
      RETURN                                                            00127200
      END                                                               00127300
      SUBROUTINE RATNG (Q2,S2,BFLOW,IPASS)
C                                                                       00127500
C     RATNG-  COMPUTES A STAGE HYDROGRAPH FROM A STATION'S DISCHARGE    00127600
C             HYDROGRAPH AND RATING TABLE.                              00127700
C                                                                       00127800
      DIMENSION SRAT(2,20), QRAT(2,20), SHIFT(2,9000)                   00127900
      DIMENSION S2 (9000), Q2 (9000)
      COMMON /TIMEPR/ TMAX,ITMAX,DT,NTS,KR,NDT24,NRCHS,NSR,KTSTRT,N1ST,N00128100
     12ND,NLST,IQBEG,IQEND,KCNT,IBEGR                                   00128200  KCNT and IBEGR added 2/12/85 PRJ
      COMMON /RATING/ SRAT,QRAT,SHIFT,NUSRP,NDSRP                       00128300
C                                                                       00128400
C        COMPUTE STAGE FROM DISCHARGE                                   00128500
      J=IPASS
      IF (J.EQ.1) NRP = NUSRP
      IF (J.EQ.2) NRP = NDSRP
      NRP1=NRP-1                                                        00128800
      DO 30 NT=N1ST,NLST                                                00128900
      FLOW=Q2(NT)                                                       00129000
      DO 10 K1=1,NRP1                                                   00129100
      K=NRP-K1                                                          00129200
      IF (FLOW.GT.QRAT(J,K)) GO TO 20                                   00129300
   10 CONTINUE                                                          00129400
   20 CONTINUE                                                          00129500
      X1=(SRAT(J,K+1)-SRAT(J,K))/(QRAT(J,K+1)-QRAT(J,K))                00129600
      X2=FLOW-QRAT(J,K)                                                 00129700
      STAGE=SRAT(J,K)+X1*X2                                             00129800
      M=FLOAT(NT-1)/FLOAT(NDT24)+.99                                    00129900
      IF (M.EQ.0) M=1                                                   00130000
      S2(NT)=STAGE-SHIFT(J,M)                                           00130100
   30 CONTINUE                                                          00130200
C                                                                       00130300
      RETURN                                                            00130400
      END                                                               00130500
      SUBROUTINE MEANS (N,S)                                            00130600
C                                                                       00130700
C     MEANS-  COMPUTES A STAGE HYDROGRAPH AT THE CENTER OF A SUBREACH.  00130800
C             A SUBREACH'S LENGTH IS EQUAL TO THE DISTANCE A FLOOD WAVE 00130900
C             TRAVELS IN ONE TIME STEP                                  00131000
C                                                                       00131100
      DIMENSION USS(9000), DSS(9000), DELS(9000), S(9000)               00131200
      COMMON /STAGES/ USS,DSS,DELS                                      00131300
      COMMON /TIMEPR/ TMAX,ITMAX,DT,NTS,KR,NDT24,NRCHS,NSR,KTSTRT,N1ST,N00131400
     12ND,NLST,IQBEG,IQEND,KCNT,IBEGR                                   00131500  KCNT and IBEGR added 2/12/85 PRJ
C                                                                       00131600
C             NO. OF SUBREACHES EQUAL TO ZERO                           00131700
      IF (NSR.GT.0) GO TO 20                                            00131800
      DO 10 NT=N1ST,NLST                                                00131900
      S(NT)=(USS(NT)+DSS(NT))/2.                                        00132000
   10 CONTINUE                                                                    kt warning fix
      RETURN                                                            00132100
C             NO. OF SUBREACHES GREATER THAN ZERO                       00132200
   20 CONTINUE                                                          00132300
      DO 30 NT=N1ST,NLST                                                00132400
      N1=NT-N                                                           00132500
      N2=N1+1                                                           00132600
      N3=N1+NSR                                                         00132700
      N4=N3+1                                                           00132800
      IF (N1.LT.1) N1=N1ST                                              00132900
      IF (N1.LT.N1ST) N1=N1ST                                           00133000
      IF (N2.LT.N1ST) N2=N1ST                                           00133100
      IF (N3.GT.NLST) N3=NLST                                           00133200
      IF (N4.GT.NLST) N4=NLST                                           00133300
      US1=(USS(N1)+USS(N2))/2.                                          00133400
      DS1=(DSS(N3)+DSS(N4))/2.                                          00133500
      S(NT)=US1+((DS1-US1)*((FLOAT(N)-.5)/NSR))                         00133600
   30 CONTINUE                                                          00133700
      RETURN                                                            00133800
      END                                                               00133900
      SUBROUTINE SETUP (NYEARS)                                         00134000
C                                                                       00134100
C     SETUP-  PROGRAMMED BY J O SHEARMAN.  DEFINES FILES FOR DISK       00134200
C                                                                       00134300
      INTEGER OPFILE,C,P,PU,US,DS                                       00134400
      COMMON /FILES/ ID21,ID22,ID23,ID24,ID25,ID26,ID27,ID28,ID29,ID30  00134500
      COMMON /UNITS/ C,P,PU,US,DS,NDIM,MDIM                             00134600
C             CREATE SPACE ON DIRECT ACCESS FILES AS FOLLOWS:           00134800
C                 1) REQUESTED SPACE (NYEARS) ON OUTPUT FILES (26-30)   00134900
C                 2) 100 YEARS ON INPUT FILES (21-25)                   00135000
      DO 10 I=1,5                                                       00135100
      IGO=I                                                             00135200
      IF ((NYEARS-20*I).LE.0) GO TO 20                                  00135300
   10 CONTINUE                                                          00135400
      IGO=5                                                             00135500
   20 GO TO (30,40), IGO                                                 00135600
   30 CONTINUE                                                          00135700
C             CREATE SPACE FOR  20,40,60,80,100 YEARS FOR OUTPUT FILES               00135800
      OPEN (UNIT=36,ACCESS='DIRECT',RECL=1552)
      OPEN (UNIT=37,ACCESS='DIRECT',RECL=1552)
      OPEN (UNIT=38,ACCESS='DIRECT',RECL=1552)
      OPEN (UNIT=39,ACCESS='DIRECT',RECL=1552)
      OPEN (UNIT=30,ACCESS='DIRECT',RECL=1553)
      GO TO 80                                                          00136100
   40 CONTINUE                                                          00136200
   80 NYEARS=20*IGO                                                     00138200
C             CREATE SPACE FOR 100 YEARS FOR INPUT FILES                00138300
      OPEN (UNIT=31,ACCESS='DIRECT',RECL=1552)
      OPEN (UNIT=32,ACCESS='DIRECT',RECL=1552)
      OPEN (UNIT=33,ACCESS='DIRECT',RECL=1552)
      OPEN (UNIT=34,ACCESS='DIRECT',RECL=1552)
      OPEN (UNIT=35,ACCESS='DIRECT',RECL=1552)
      WRITE (10,90) NYEARS
      RETURN                                                            00138700
C                                                                       00138800
C                                                                       00138900
   90 FORMAT ('0',9HSPACE FOR,I4,48H YEARS HAS BEEN ALLOCATED FOR OUTPUT00139000
     1 HYDROGRAPHS)                                                     00139100
      END                                                               00139200
      SUBROUTINE PRPLOT                                                 00139300
C                                                                       00139400
C     PRPLOT- SUBPROGRAM OF ENTRIES TO CONSTRUCT A PAGE SIZE            00139500
C             LINE PRINTER PLOT OF TIME ARRAY DATA.  ALSO SUPPORTS      00139600
C             SUBPROGRAM PLOTIT.                                        00139700
C                                                                       00139800
      IMPLICIT LOGICAL (K,W)
      CHARACTER*1 GRID (56000), CH                                               kt changed INTEGER *2 to CHARACTER*1
      DIMENSION NSCALE(5), ABNOS(26), X(1), Y(1)                        00140000
      CHARACTER*1 NOS (10)
      CHARACTER*1 WL                                                             kt changed INTEGER *2 to CHARACTER*1
      CHARACTER *36 LABEL
      CHARACTER*1 ILABEL                                                         kt changed INTEGER *2 to CHARACTER*1
      CHARACTER *36 ALABEL
      DIMENSION ILABEL (36)
      LOGICAL ERR1, ERR3, ERR5
      CHARACTER*1 VC,HC,FOR1(19),FOR2(15),FOR3(19),NC,BL,HF,HF1                  kt changed INTEGER *2 to CHARACTER*1
      CHARACTER *24 FOX1, FOX3
      CHARACTER *16 FOX2
      INTEGER *2 VCR
      EQUIVALENCE (VC,VCR)
      EQUIVALENCE (LABEL,ILABEL(1))
      INTEGER FILE                                                      00140800
      COMMON/COMON/GRID
      DATA HC/'-'/,NC/'+'/,BL/' '/,HF/'F'/,HF1/'.'/                     00140900
      DATA VC / 'I' /
      DATA FOX1/'(1XA1,F9.2,  121A1)     '/
      DATA FOX2/'(1XA1, 9X121A1) '/
      DATA FOX3/'(1H0F  . ,  F   . )     '/
      DATA KPLOT1/.FALSE./,KPLOT2/.FALSE./                              00141400
      DATA KABSC,KORD,KBOTGL/3*.FALSE./                                 00141500
      DATA NOS /'0','1','2','3','4','5','6','7','8','9'/
C                                                                       00141600
      ENTRY PLOT1(NSCALE,NHL,NSBH,NVL,NSBV)                             00141700
      IFL=FILE                                                          00141800
      ERR1=.FALSE.                                                      00141900
      ERR3=.FALSE.                                                      00142000
      ERR5=.FALSE.                                                      00142100
      KPLOT1=.TRUE.                                                     00142200
      KPLOT2=.FALSE.                                                    00142300
      NH=IABS(NHL)                                                      00142400
      NSH=IABS(NSBH)                                                    00142500
      NV=IABS(NVL)                                                      00142600
      NSV=IABS(NSBV)                                                    00142700
      NSCL=NSCALE(1)                                                    00142800
      IF (NH*NSH*NV*NSV .NE. 0) GO TO 10
      KPLOT=.FALSE.                                                     00143000
      ERR1=.TRUE.                                                       00143100
      RETURN                                                            00143200
   10 KPLOT=.TRUE.                                                      00143300
      IF (NV.LE.25) GO TO 20                                            00143400
      KPLOT=.FALSE.                                                     00143500
      ERR3=.TRUE.                                                       00143600
      RETURN                                                            00143700
   20 CONTINUE                                                          00143800
      NVM=NV-1                                                          00143900
      NVP=NV+1                                                          00144000
      NDH=NH*NSH                                                        00144100
      NDHP=NDH+1                                                        00144200
      NDV=NV*NSV                                                        00144300
      NDVP=NDV+1                                                        00144400
      NIMG=(NDHP*NDVP)                                                  00144500
      IF (NDV.LE.120) GO TO 30                                          00144600
      KPLOT=.FALSE.                                                     00144700
      ERR5=.TRUE.                                                       00144800
      RETURN                                                            00144900
   30 CONTINUE                                                          00145000
      IF (NSCL.EQ.0) GO TO 40                                           00145100
      FSY=10.**NSCALE(2)                                                00145200
      FSX=10.**NSCALE(4)                                                00145300
      IY=MIN0(IABS(NSCALE(3)),7)+1                                      00145400
      IX=MIN0(IABS(NSCALE(5)),9)+1                                      00145500
      GO TO 50                                                           00145600
   40 FSY=1.                                                            00145700
      FSX=1.                                                            00145800
      IY=4                                                              00145900
      IX=4                                                              00146000
   50 FOX1(10:10)=NOS(IY)                                                  00146100
      NA=MIN0(IX,NSV)-1                                                 00146200
      NS=NA-MIN0(NA,120-NDV)                                            00146300
      NB=11-NS+NA                                                       00146400
      I1=NB/10                                                          00146500
      I2=NB-I1*10                                                       00146600
      FOX3(6:6)=NOS(I1+1)                                                 00146700
      FOX3(7:7)=NOS(I2+1)                                                 00146800
      FOX3(9:9)=NOS(NA+1)                                                 00146900
      IF (NV.GT.0) GO TO 70                                             00147000
      DO 60 J=11,18                                                     00147100
      FOX3(J:J)=' '                                                        00147200
   60 CONTINUE                                                                    kt warning fix
      GO TO 80                                                          00147300
   70 I1=NV/10                                                          00147400
      I2=NV-I1*10                                                       00147500
      FOX3(11:11)=NOS(I1+1)                                                00147600
      FOX3(12:12)=NOS(I2+1)                                                00147700
      FOX3(13:13)= 'F'
      I1=NSV/100                                                        00147900
      I3=NSV-I1*100                                                     00148000
      I2=I3/10                                                          00148100
      I3=I3-I2*10                                                       00148200
      FOX3(14:14)=NOS(I1+1)                                                00148300
      FOX3(15:15)=NOS(I2+1)                                                00148400
      FOX3(16:16)=NOS(I3+1)                                                00148500
      FOX3(17:17)='.'
      FOX3(18:18)=FOX3(9:9)                                                  00148700
   80 IF (KPLOT1) RETURN                                                00148800
      KPLOT1=.TRUE.                                                     00148900
C                                                                       00149000
      ENTRY PLOT2 (XMAX,XMIN,YMAX,YMIN,INTP)                                     kt changed P to INTP
      IFL=INTP                                                                   kt changed P to INTP
      KPLOT2=.TRUE.                                                     00149300
      IF (KPLOT1) GO TO 90                                              00149400
      NSCL=0                                                            00149500
      NH=5                                                              00149600
      NSH=10                                                            00149700
      NV=10                                                             00149800
      NSV=10                                                            00149900
      GO TO 10                                                          00150000
   90 CONTINUE                                                          00150100
      IF (KPLOT) GO TO 100                                              00150200
      IF (ERR1) WRITE (IFL,300)                                         00150300
      IF (ERR3) WRITE (IFL,310)                                         00150400
      IF (ERR5) WRITE (IFL,320)                                         00150500
      RETURN                                                            00150600
  100 YMX=YMAX                                                          00150700
      DH=(YMAX-YMIN)/FLOAT(NDH)                                         00150800
      DV=(XMAX-XMIN)/FLOAT(NDV)                                         00150900
      DO 110 I=1,NVP                                                    00151000
      ABNOS(I)=(XMIN+FLOAT((I-1)*NSV)*DV)*FSX                           00151100
  110 CONTINUE
      DO 120 I=1,NIMG                                                   00151200
      GRID (I) = BL
  120 CONTINUE                                                                    kt warning fix
      DO 160 I=1,NDHP                                                   00151400
      I2=I*NDVP                                                         00151500
      I1=I2-NDV                                                         00151600
      KNHOR=MOD(I-1,NSH).NE.0                                           00151700
      IF (KNHOR) GO TO 140                                              00151800
      DO 130 J=I1,I2                                                    00151900
      GRID (J) = HC
  130 CONTINUE
  140 CONTINUE                                                          00152100
      DO 155 J=I1,I2,NSV                                                00152200
      IF (KNHOR) GO TO 150                                              00152300  kt warning fix
      GRID (J) = NC
      GO TO 160                                                         00152500
  150 GRID (J) = VC
  155 CONTINUE                                                                    kt warning fix
  160 CONTINUE                                                          00152700
      XMIN1=XMIN-DV/2.                                                  00152800
      YMIN1=YMIN-DH/2.                                                  00152900
      RETURN                                                            00153000
C                                                                       00153100
      ENTRY PLOT3(CH,X,Y,N3)                                            00153200
      IF (KPLOT2) GO TO 180                                             00153300
  170 WRITE (IFL,330)                                                   00153400
  180 CONTINUE                                                          00153500
      IF (.NOT.KPLOT) RETURN                                            00153600
      IF (N3.GT.0) GO TO 190                                            00153700
      KPLOT=.FALSE.                                                     00153800
      WRITE (IFL,340)                                                   00153900
      RETURN                                                            00154000
  190 DO 260 I=1,N3                                                     00154100
C      IF (DV) 210,200,210                                               00154200  kt warning fix 
      IF (DV.EQ.0) THEN                                                           kt warning fix
        GO TO 200                                                                 kt warning fix
      ELSE                                                                        kt warning fix
        GO TO 210                                                                 kt warning fix
      END IF                                                                      kt warning fix
  200 DUM1=0                                                            00154300
      GO TO 220                                                         00154400
  210 CONTINUE                                                          00154500
      DUM1=(X(I)-XMIN1)/DV                                              00154600
C  220 IF (DH) 240,230,240                                               00154700  kt warning fix
  220 IF (DH.EQ.0) THEN                                                           kt warning fix
        GO TO 230                                                                 kt warning fix
      ELSE                                                                        kt warning fix
        GO TO 240                                                                 kt warning fix
      END IF                                                                      kt warning fix
  230 DUM2=0                                                            00154800
      GO TO 250                                                         00154900
  240 CONTINUE                                                          00155000
      DUM2=(Y(I)-YMIN1)/DH                                              00155100
  250 CONTINUE                                                          00155200
      IF (DUM1.LT.0..OR.DUM2.LT.0.) GO TO 260                           00155300
      IF (DUM1.GE.NDVP.OR.DUM2.GE.NDHP) GO TO 260                       00155400
      NX=1+INT(DUM1)                                                    00155500
      NY=1+INT(DUM2)                                                    00155600
      J=(NDHP-NY)*NDVP+NX                                               00155700
      GRID (J) = CH
  260 CONTINUE                                                          00155900
      RETURN                                                            00156000
C                                                                       00156100
      ENTRY PLOT4 (NL,ALABEL)
      LABEL =ALABEL
      IF (.NOT.KPLOT) RETURN                                            00156400
      IF (.NOT.KPLOT2) GO TO 170                                        00156500
      DO 280 I=1,NDHP                                                   00156600
      IF (I.EQ.NDHP.AND.KBOTGL) GO TO 280                               00156700
      WL=BL                                                             00156800
C      IF (I.LE.NL)WL=CHAR(ILABEL(I))                                              kt added CHAR()
      IF (I.LE.NL)WL=ILABEL(I)
      I2=I*NDVP                                                         00157000
      I1=I2-NDV                                                         00157100
      IF (MOD(I-1,NSH).EQ.0.AND..NOT.KORD) GO TO 270                    00157200
      WRITE (IFL,FOX2,ERR=272) WL,(GRID(J),J=I1,I2)
      GO TO 280                                                         00157400
  270 CONTINUE                                                          00157500
      ORDNO=(YMX-FLOAT(I-1)*DH)*FSY                                     00157600
      IF (I.EQ.NDHP) ORDNO=YMIN                                         00157700
      WRITE (IFL,FOX1,ERR=271)WL,ORDNO,(GRID(J),J=I1,I2)
      GO TO 280
  271 WRITE (1,3271)
 3271 FORMAT (1X,'THE ERR IS IN FOX1')
      GO TO 280
  272 WRITE (1,3272)
 3272 FORMAT (1X,'THE ERR IS IN FOX2')
  280 CONTINUE                                                          00157900
      IF (KABSC) GO TO 290                                              00158000
      WRITE (IFL,FOX3,ERR=283) (ABNOS(J),J=1,NVP)                               00158100
      GO TO 290
  283 WRITE (1,3283) FOX3
 3283 FORMAT (1X,'THE ERR IS IN FOX3',
     &       /1X,A24)
  290 RETURN                                                            00158200
C                                                                       00158300
      ENTRY OMIT(LSW)                                                   00158400
      KABSC=MOD(LSW,2).EQ.1                                             00158500
      KORD=MOD(LSW,4).GE.2                                              00158600
      KBOTGL=LSW.GE.4                                                   00158700
      RETURN                                                            00158800
C                                                                       00158900
  300 FORMAT (T5,'SOME PLOT1 ARG. ILLEGALLY 0')                         00159000
  310 FORMAT (T5,'NO. OF VERTICAL LINES >25')                           00159100
  320 FORMAT (T5,'WIDTH OF GRAPH >121')                                 00159200
  330 FORMAT (T5,'PLOT2 MUST BE CALLED')                                00159300
  340 FORMAT (T5,'PLOT3, ARG2 ) 0')                                     00159400
      END                                                               00159500
      SUBROUTINE PLOTIT (ZFILE2,ZEND,ZBEGIN,MINQ,Q1,Q2,Q3)              00159600
C                                                                       00159700
C     PLOTIT- PROGRAMMED BY J O SHEARMAN.  A LINE PRINTER PLOT IS MADE  00159800
C             OF THE HYDROGRAPH DATA.  A LINE IS GIVEN FOR EACH         00159900
C             TIME STEP.                                                00160000
      IMPLICIT LOGICAL(Z)                                               00160100
      INTEGER OPFILE,C,P,PU,US,DS                                       00160200
      CHARACTER *4 STANO1(2),STANO2(2),STANM1(17),STANM2(17),INFO(20)        00160300
      CHARACTER *1 GRID (56000)
      DIMENSION Q3(1), Q3LOG(9000)                                      00160500
      DIMENSION Q1(1), Q2(1),Q1LOG(9000),Q2LOG(9000),XI(9000), NSCALE(5)00160600
     1, MINQA(5)                                                        00160700
      DIMENSION IYEAR(9000),IDAY(9000),IMON(9000),TIME(9000),IHOUR(9000)00160800
      DIMENSION MODAYS (12)
      COMMON /PLT/ INITMO,INITDY,INITYR,LASTMO,LASTDY,LASTYR,NRECDS,STAN00160900
     1O1,STANM1,STANO2,STANM2,INFO,JYEAR                                00161000
      COMMON /TIMEPR/ TMAX,ITMAX,DT,NTS,KR,NDT24,NRCHS,NSR,KTSTRT,N1ST,N00161100
     12ND,NLST,IQBEG,IQEND,KCNT,IBEGR                                   00161200  KCNT and IBEGR added 2/12/85 PRJ
      COMMON / DAYSMO / MODAYS
      COMMON /B2/ IYEAR,IDAY,IMON,TIME                                  00161400
      COMMON /UNITS/ C,P,PU,US,DS,NDIM,MDIM                             00161500
      COMMON/COMON/GRID
C ********  NEXT STATEMENT ADDED BY CLAUDE BAKER TO RE-INITIALIZE AND
C         AVOID PROBLEM OF OVERFLOW IN SUBROUTINE PRPLOT ***12/11/84***
       DATA NSCALE/0,0,0,0,0/
C                                                                       00161800
C                                                                       00161900
      NSCALE (1) = 1
      IQF=N1ST                                                          00162000
      IQL=NLST                                                          00162100
      IF (.NOT.ZBEGIN) GO TO 40                                         00162200
      XMIN=0.0                                                          00162300
      MINLO=1                                                           00162400
      IF (MINQ.LT.MINLO) GO TO 20                                       00162500
      DO 10 J=1,3                                                       00162600
      MINHI=10**J                                                       00162700
      IF (MINQ.GE.MINLO.AND.MINQ.LT.MINHI) GO TO 20                     00162800
      XMIN=XMIN+1.0                                                     00162900
      MINLO=MINHI                                                       00163000
   10 CONTINUE                                                          00163100
   20 MINQ=MINLO                                                        00163200
      XMAX=XMIN+4.0                                                     00163300
      DO 30 J=1,5                                                       00163400
      MINQA(J)=MINQ*10**(J-1)                                           00163500
   30 CONTINUE                                                          00163600
      WRITE (10,100) KR,STANO1,STANM1,STANO2,STANM2,INITMO,INITDY,INITYR00163700
     1,LASTMO,LASTDY,LASTYR                                              00163800
      GO TO 50                                                          00163900
   40 WRITE (10,110)                                                    00164000
      CALL DATE (DT,NLST,DT,10,1,JYEAR)                                 00164100
   50 WRITE (10,120) IMON(N1ST),IDAY(N1ST),IYEAR(N1ST),IMON(NLST),IDAY(N00164200
     1LST),IYEAR(NLST)                                                   00164300
      WRITE (10,70)                                                     00164400
      WRITE (10,80)
      WRITE (10,90) MINQA
      DO 60 I=IQF,IQL                                                   00164700
      XI(I)=IQL-I+IQF                                                   00164800
      IF (Q1(I).LE.0.0) Q1(I)=0.001                                     00164900
      Q1LOG(I)=ALOG10(Q1(I))                                            00165000
      IF (Q3(I).LE.0.0) Q3(I)=0.001                                     00165100
      Q3LOG(I)=ALOG10(Q3(I))                                            00165200
      IF (Q2(I).LE.0.0) Q2(I)=0.001                                     00165300
      Q2LOG(I)=ALOG10(Q2(I))                                            00165400
   60 CONTINUE                                                          00165500
      NPTS=IQL-IQF+1                                                    00165600
      NLINES=NPTS                                                       00165700
      IF (ZBEGIN) NLINES=NLINES-1                                       00165800
      XQ1=IQF                                                           00165900
      XQ2=IQL                                                           00166000
      CALL PLOT1 (NSCALE,NLINES,1,4,30)                                 00166100
      CALL PLOT2 (XMAX,XMIN,XQ2,XQ1,P)
C      CALL PLOT3 ('I',Q3LOG(IQF),XI(IQF),NPTS)                          00166300
C      CALL PLOT3 ('U',Q1LOG(IQF),XI(IQF),NPTS)                          00166400
C      CALL PLOT3 ('D',Q2LOG(IQF),XI(IQF),NPTS)                          00166500
      CALL OMIT (3)                                                     00166600
      CALL PLOT4 (5,' DATE                               ')             00166700  kt added end padding so matches function dim
      WRITE (10,90) MINQA
      WRITE (10,80)
      NSCALE (1) = 0
      RETURN                                                            00167000
C                                                                       00167100
C                                                                       00167200
C                                                                       00167300
C                                                                       00167400
   70 FORMAT ('0',10X,'SYMBOLS:  U - UPSTREAM HYDROGRAPH'/21X,'D - DOWNS00167500
     1TREAM HYDROGRAPH'/21X,'I - BANK STORAGE DISCHARGE HYDROGRAPH (AQUI00167600
     2FER TO STREAM ONLY)')                                             00167700
   80 FORMAT (//65X,13HDISCHARGE,CFS)                                   00167800
   90 FORMAT (9X,I3,4(23X,I7))                                          00167900
  100 FORMAT ('1',130(1H-)/1X,'REACH NO.',I3,':',9X,'BEGINS AT GAGING ST00168000
     1ATION ',2A4,2X,17A4/1X,'                        ENDS AT GAGING STA00168100
     2TION ',2A4,2X,17A4//1X,'TOTAL STUDY PERIOD:   BEGINS ',I2,'/',I2,'00168200
     3/',I4/1X,'                        ENDS ',I2,'/',I2,'/',I4/1X,130(100168300
     4H-))                                                              00168400
  110 FORMAT ('1')                                                      00168500
  120 FORMAT ('0'/1X,130(1H.)/' THIS SIMULATION PERIOD BEGINS ',I2,'/',I00168600
     12,'/',I4,2X,'AND ENDS ',I2,'/',I2,'/',I4/1X,130(1H.))             00168700
      END                                                               00168800
      SUBROUTINE DATE (DD,NORDS,FTIME,INITM,INITD,INITY)                00168900
C                                                                       00169000
C     DATE-   PROGRAMMED BY J O SHEARMAN.  COMPUTES AN ARRAY OF DATE    00169100
C             AND TIME VALUES FOR A GIVEN TIME STEP AND STUDY PERIOD    00169200
C                                                                       00169300
      DIMENSION IYEAR(9000),IDAY(9000),IMON(9000),TIME(9000),IHOUR(9000)00169400
      DIMENSION MODAYS (12)
      COMMON / DAYSMO / MODAYS
      COMMON /B2/ IYEAR,IDAY,IMON,TIME                                  00169600
      IYEAR(1)=INITY                                                    00169700
      IF (MOD(INITY,4).EQ.0) MODAYS(2)=29                               00169800
      IDAY(1)=INITD                                                     00169900
      IMON(1)=INITM                                                     00170000
      NOMON=INITM                                                       00170100
      TIME(1)=FTIME                                                     00170200
      DO 10 J=2,NORDS                                                   00170300
      TIME(J)=TIME(J-1)+DD                                              00170400
      IDAY(J)=IDAY(J-1)                                                 00170500
      IMON(J)=IMON(J-1)                                                 00170600
      IYEAR(J)=IYEAR(J-1)                                               00170700
      IF (TIME(J).LE.24.0) GO TO 10                                     00170800
      TIME(J)=TIME(J)-24.0                                              00170900
      IDAY(J)=IDAY(J)+1                                                 00171000
      IF (IDAY(J).LE.MODAYS(NOMON)) GO TO 10                            00171100
      IDAY(J)=1                                                         00171200
      NOMON=NOMON+1                                                     00171300
      IF (NOMON.GT.12) NOMON=1                                          00171400
      IMON(J)=NOMON                                                     00171500
      IF (NOMON.GT.1) GO TO 10                                          00171600
      IYEAR(J)=IYEAR(J)+1                                               00171700
      MODAYS(2)=28                                                      00171800
      NYEAR=IYEAR(J)                                                    00171900
      IF (MOD(NYEAR,4).EQ.0) MODAYS(2)=29                               00172000
   10 CONTINUE                                                          00172100
      IF (MODAYS(2).EQ.29) MODAYS(2)=28                                 00172200
      MODAYS(2)=28                                                      00172300
      RETURN                                                            00172400
      END                                                               00172500
      SUBROUTINE DABSAH (IFILE,IYEAR,IREC,ABORT,NRECDS)                 00172600
C                                                                       00172700
C     DABSAH- PROGRAMMED BY J O SHEARMAN.  DETERMINES LOCATION OF       00172800
C             SELECTED DATA INSIDE A DISK DATA SET                      00172900
C                                                                       00173000
      DIMENSION ISKIP(2)                                                00173100
      LOGICAL ABORT                                                     00173200
      READ (IFILE,REC=1) NRECDS                                             00173300
      READ (IFILE,REC=2) ISKIP,IYRLO                                        00173400
      IF (IYEAR.LT.IYRLO) GO TO 90                                      00173500
      IF (IYEAR.NE.IYRLO) GO TO 10                                      00173600
      IREC=2                                                            00173700
      RETURN                                                            00173800
   10 IREC=2+IYEAR-IYRLO                                                00173900
      IRECLO=2                                                          00174000
      IF (IREC.GT.NRECDS) GO TO 20                                      00174100
      READ (IFILE,REC=IREC) ISKIP,MIDYR                                     00174200
      IF (IYEAR.EQ.MIDYR) RETURN                                        00174300
      IRECHI=IREC                                                       00174400
      IYRHI=MIDYR                                                       00174500
      GO TO 40                                                          00174600
   20 READ (IFILE,REC=NRECDS) ISKIP,IYRHI                                   00174700
      IF (IYEAR.GT.IYRHI) GO TO 90                                      00174800
      IF (IYEAR.NE.IYRHI) GO TO 30                                      00174900
      IREC=NRECDS                                                       00175000
      RETURN                                                            00175100
   30 IRECHI=NRECDS                                                     00175200
   40 IREC=IRECHI-IYRHI+IYEAR                                           00175300
      IF (IREC.LT.IRECLO) GO TO 50                                      00175400
      READ (IFILE,REC=IREC) ISKIP,MIDYR                                     00175500
      IF (IYEAR.EQ.MIDYR) RETURN                                        00175600
      IRECLO=IREC                                                       00175700
      IYRLO=MIDYR                                                       00175800
   50 DO 80 IDO=1,10                                                    00175900
      IF (IRECLO.EQ.IRECHI-1) GO TO 90                                  00176000
      IREC=(IRECLO+IRECHI)/2                                            00176100
      READ (IFILE,REC=IREC) ISKIP,MIDYR                                     00176200
      IF (IYEAR.EQ.MIDYR) RETURN                                        00176300
      INCYR=IYEAR-MIDYR                                                 00176400
      JREC=IREC+(INCYR-ISIGN(1,INCYR))                                  00176500
      IF (JREC.LE.IRECLO.OR.JREC.GE.IRECHI) GO TO 60                    00176600
      READ (IFILE,REC=JREC) ISKIP,JYEAR                                     00176700
      IF (IYEAR.NE.JYEAR) GO TO 60                                      00176800
      IREC=JREC                                                         00176900
      RETURN                                                            00177000
   60 IF (MIDYR.GT.IYEAR) GO TO 70                                      00177100
      IRECLO=IREC                                                       00177200
      GO TO 80                                                          00177300
   70 IRECHI=IREC                                                       00177400
   80 CONTINUE                                                          00177500
   90 WRITE (1,100) IYEAR,IFILE                                         00177600
      ABORT=.TRUE.                                                      00177700
      RETURN                                                            00177800
C                                                                       00177900
  100 FORMAT (1H0,I4,25H (INITY) NOT IN FILE NO. ,I2)                   00178000
      END                                                               00178100
      FUNCTION JNWYDY (JMON,JDAY,JYEAR)                                 00178200
C                                                                       00178300
C     JNWYDY- PROGRAMMED BY J O SHEARMAN AND P R JORDAN.                00178400
C             NUMBERS DAYS  CONSECUTIVELY FROM OCT 1, 1900               00178500
C                                                                       00178600
      DIMENSION MODAYS (12)
      COMMON / DAYSMO / MODAYS
      IWTRYR=JYEAR                                                      00178800
      IF (JMON.GT.9) IWTRYR=IWTRYR+1                                    00178900
      LEAP=0                                                            00179000
      IF (MOD(IWTRYR,4).EQ.0) LEAP=1                                    00179100
      JNWYDY=JDAY+92                                                    00179200
      IF (JMON.EQ.1) GO TO 20                                           00179300
      MOS=JMON-1                                                        00179400
      DO 10 I=1,MOS                                                     00179500
      JNWYDY=JNWYDY+MODAYS(I)                                           00179600
   10 CONTINUE                                                                    kt warning fix
   20 IF (JNWYDY.GT.365) JNWYDY=JNWYDY-(LEAP+365)                       00179700 done because 92 was added to JDAY
      IF (JMON.GT.2) JNWYDY=JNWYDY+LEAP                                 00179800
      NYR = IWTRYR - 1901                                                added 2/20/85 PRJ
      NLEAP = NYR/4                                                     added 2/20/85 PRJ
      NPREV = NYR * 365 + NLEAP                                         added 2/20/85 PRJ
      JNWYDY = JNWYDY + NPREV                                           added 2/20/85 PRJ
      RETURN                                                            00179900
      END                                                               00180000
      SUBROUTINE OUTPUT                                                 00180100
C                                                                       00180200
C     OUTPUT- PRINTS AND PLOTS HYDROGRAPHS, COMPUTES AND PRINTS MASS    00180300
C             BALANCE FOR REACH.                                        00180400
C                                                                       00180500
      IMPLICIT LOGICAL(Z)                                               00180600
      INTEGER OPFILE,C,P,PU,US,DS                                       00180700
      CHARACTER *4 STANO1(2),STANO2(2),STANM1(17),STANM2(17),INFO(20)        00180800
      INTEGER NSCALE (5)
      CHARACTER *1 GRID (56000)
      CHARACTER *4 IWARN (9000)
      CHARACTER *4 IW0, IW1, IW2
      DIMENSION USS(9000), DSS(9000), DELS(9000), S(9000)               00181200
      DIMENSION X(25), QLOSS(25), ISTRT(25), IEND(25)                   00181300
      DIMENSION USQ(9000),DSQ(18000),DSQ1(9000),SQLOSS(18000),QI(18000)    00181400
C     NEW VARIABLE.  SEE MAIN.
      DIMENSION DSQO(9000)
C
      DIMENSION IYEAR(9000),IDAY(9000),IMON(9000),TIME(9000),IHOUR(9000)00181500
      COMMON /ZLOGIC/ ZBEGIN,ZEND,ZPLOT,ZROUTE,ZFLOW,ZLOSS,ZDISK,ZCARDS,00181600
     1ZWARN,ZPRINT,ZPUNCH,ZUSHFT,ZDSHFT,ZMULT,ZDSQO,ZOUTPUT,ZFAST       00181700  kt fast option
      COMMON /PLT/ INITMO,INITDY,INITYR,LASTMO,LASTDY,LASTYR,NRECDS,STAN00181800
     1O1,STANM1,STANO2,STANM2,INFO,JYEAR                                00181900
      COMMON /DISCHA/ USQ,DSQ,DSQ1,QI,SQLOSS,USQB,DSQB,TOLRNC,DSQO      00182000
      COMMON /STAGES/ USS,DSS,DELS                                      00182100
      COMMON /TIMEPR/ TMAX,ITMAX,DT,NTS,KR,NDT24,NRCHS,NSR,KTSTRT,N1ST,N00182200
     12ND,NLST,IQBEG,IQEND,KCNT,IBEGR                                   00182300  KCNT and IBEGR added 2/12/85 PRJ
      COMMON /PARAM/ TT,TLAG,CHLGTH,ALLGTH,T,SS,ALPHA,XK,XKA,XL,CZERO,SO00182400
     1ILMS, TTCUM                                                       00182500  TTCUM ADDED 2/85 PRJ
      COMMON /LOSS/ X,QLOSS,ISTRT,IEND,NLOSS                            00182600
      COMMON /VOL/ QILOST, WELCUM, QLSCUM, USREL1                       00182700  WELCUM, QLSCUM, and USREL1 added 2/10/85 PRJ
      COMMON /B2/ IYEAR,IDAY,IMON,TIME                                  00182800
      COMMON /WARN/ IWARN,IW0,IW1,IW2                                   00182900
      COMMON /UNITS/ C,P,PU,US,DS,NDIM,MDIM                             00183000
      COMMON/COMON/GRID
      DATA NSCALE / 0,0,0,0,0 /
C                                                                       00183100
C     PARAMETERS                                                        00183200
C        QIVOL - NET VOLUME OF BANK STORAGE DISCAHARGE.                 00183300
C        QIAVOL- ABSOLUTE VOLUME OF BANK STORAGE DISCHARGE.             00183400
C        QLSVOL- VOLUME LOST TO DIVERSIONS AND WELLS.                   00183500
C        UBQVOL- VOLUME OF BASE FLOW AT UPSTREAM STATION.               00183600
C        DBQVOL- VOLUME OF BASE FLOW AT DOWNSTREAM STATION.             00183700
C        QILSVO- VOLUME LOST TO SOIL.                                   00183800
C        VOLSTO- VOLUME OF BANK STORAGE REMAINING IN AQUIFER.           00183900
C        VOLOUT- VOLUME OF WATER LEAVING STREAM TO BANK STORAGE.        00184000
C        VOLIN - VOLUME OF WATER ENTERING STREAM FROM BANK STORAGE.     00184100
C                                                                       00184200
      IF (.NOT.ZBEGIN) GO TO 10                                         00184300
      QLSVOL=0.0                                                        00184400
      USQVOL=0.0                                                        00184500
      DSQVOL=0.0                                                        00184600
      DSQ1VO=0.0                                                        00184700
      QIVOL=0.0                                                         00184800
      QIAVOL=0.0                                                        00184900
      QILSVO=0.0                                                        00185000
      UBQVOL=0.0                                                        00185100
      DBQVOL=0.0                                                        00185200
      CONST1=(ALLGTH*5280.)/(DT*3600.)                                  00185300
      CONST2=DT*3600.                                                   00185400
      CONST3=ALLGTH*5280.                                               00185500
      IF (.NOT.ZPRINT) GO TO 70                                         00185600
C                                                                       00185700
C             PRINT HEADER INFORMATION                                  00185800
      CALL DATE (DT,NLST,DT,INITMO,INITDY,INITYR)                       00186100  kt moved above fast option
      IF (ZFAST) GO TO 55                                                         kt fast option
      WRITE (10,260) KR,STANO1,STANM1,STANO2,STANM2,INITMO,INITDY,INITYR00185900
     1,LASTMO,LASTDY,LASTYR                                              00186000
      GO TO 20                                                          00186200
   10 IF (.NOT.ZPRINT) GO TO 70                                         00186300
      WRITE (10,280)                                                    00186400
      CALL DATE (DT,NLST,DT,10,1,JYEAR)                                 00186500
C             PRINT DATE INFORMATION                                    00186600
   20 WRITE (10,290) IMON(N1ST),IDAY(N1ST),IYEAR(N1ST),IMON(NLST),IDAY(N00186700
     1LST),IYEAR(NLST)                                                   00186800
      IF (ZROUTE) GO TO 40                                              00186900
C             PRINT TIME ARRAY DATA FOR FLOW OPTION                     00187000
      WRITE (10,270)                                                    00187100
      DO 30 NT=N1ST,NLST                                                00187200
      QI(NT)=QI(NT)*CONST1                                              00187300
      IHOUR(NT)=TIME(NT)*100.+.501                                      00187400
      WRITE (10,330) IMON(NT),IDAY(NT),IYEAR(NT),IHOUR(NT),USQ(NT),DSQ(N00187500
     1T),USS(NT),DSS(NT),DELS(NT),QI(NT)                                 00187600
   30 CONTINUE                                                                    kt warning fix
      GO TO 70                                                          00187700
   40 IF (.NOT.ZLOSS.OR.NLOSS.EQ.0) GO TO 50                            00187800
C             PRINT SUMMARY OF LOSSES                                   00187900
      WRITE (10,300)                                                    00188000
      WRITE (10,310) (X(N),QLOSS(N),ISTRT(N),IEND(N),N=1,NLOSS)         00188100
C             PRINT TIME ARRAY DATA FOR ROUTE OPTION                    00188200
C
C  50 WRITE (10,320)                                                    00188300
C     NEW WRITE STATEMENT REARRANGES OUTPUT AND ADDS DSQO VARIABLE.  G KUHN, 9-26-85.
C
   50 WRITE (10,321)
C
   55 SUMUSQ=0.0                                                                  kt fast option
      SUMDSQO=0.0
      SUMPRED=0.0
      SUMDSQ=0.0
      SUMQI=0.0
      SUMLOSS=0.0
      DO 62 NT=N1ST,NLST                                                00188400
      QI(NT)=QI(NT)*CONST1                                              00188500
      IHOUR(NT)=TIME(NT)*100.+.501                                      00188600
      IF (IWARN(NT).NE.IW2.AND.DSQ1(NT).LT.DSQB) IWARN(NT)=IW1          00188700
      IF (.NOT.ZOUTPUT) GO TO 61                                        ADDED 3/24/86, G.KUHN
C
C     NEW WRITE STATEMENT REARRANGES OUTPUT, G.KUHN, 9-26-85.
C
C  60 WRITE (10,340) IMON(NT),IDAY(NT),IYEAR(NT),IHOUR(NT),USQ(NT),DSQ(N00188800
C    1T),USS(NT),DSS(NT),DELS(NT),SQLOSS(NT),QI(NT),DSQ1(NT),IWARN(NT)   00188900
C
   58 IF (.NOT.ZFAST) GO TO 60
      WRITE (12) DSQ1(NT)
      GO TO 61

   60 WRITE (10,341) IMON(NT),IDAY(NT),IYEAR(NT),IHOUR(NT),USQ(NT),
     *DSQO(NT),DSQ1(NT),IWARN(NT),DSQ(NT),QI(NT),SQLOSS(NT),USS(NT),
     *DSS(NT),DELS(NT)
C
C     NEW STEP TO SUM OBSERVED AND PREDICTED STREAMFLOWS AND PRINT THEM.  G. KUHN 11-12-85.
C
   61 SUMUSQ=SUMUSQ+USQ(NT)
      SUMDSQO=SUMDSQO+DSQO(NT)
      DSQO(NT)=0.0
      SUMPRED=SUMPRED+DSQ1(NT)
      SUMDSQ=SUMDSQ+DSQ(NT)
      SUMQI=SUMQI+QI(NT)
      SUMLOSS=SUMLOSS+SQLOSS(NT)
   62 CONTINUE                                                                    kt warning fix
C
      IF (ZFAST) GO TO 80                                                         kt fast option
      WRITE (10,342)
      WRITE (10,343) SUMUSQ,SUMDSQO,SUMPRED,SUMDSQ,SUMQI,SUMLOSS
C
      WRITE (10,350)                                                     00189000
   70 CONTINUE                                                          00189100
C             PUNCH DOWNSTREAM HYDROGRAPH OUT ON CARDS                  00189200
      IF (.NOT.ZPUNCH) GO TO 80                                         00189300
      WRITE (PU,200) (DSQ1(NT),NT=N1ST,NLST)                            00189400
   80 CONTINUE                                                          00189500
C                                                                       00189600
C             PLOT BANK STORAGE DISCHARGE HYDROGRAPH                    00189700
      IF (.NOT.ZPLOT) GO TO 130                                         00189800
      DO 90 NT=1,NLST                                                   00189900
      TIME(NT)=FLOAT(NT)*DT/24.                                         00190000
   90 CONTINUE                                                                    kt warning fix
      IF (.NOT.ZBEGIN) GO TO 120                                        00190100
      XMIN=0.0                                                          00190200
      K100=100                                                          00190300
      K=1                                                               00190400
  100 IF (K100.GE.NLST) GO TO 110                                       00190500
      K=K+1                                                             00190600
      K100=K*100                                                        00190700
      GO TO 100                                                         00190800
  110 XMAX=FLOAT(K100)*DT/24.                                           00190900
      YMIN=0.0                                                          00191000
      CALL PMM (AMIN,AMAX,USQ,NLST)                                     00191100
      IYMAX=IFIX(AMAX/100.+.9999)                                       00191200
      YMAX=FLOAT(IYMAX)*100.                                            00191300
      YMIN=-0.3*(YMAX-YMIN)                                             00191400
      YMAX=ABS(2.*YMIN/3.)                                              00191500
  120 CONTINUE                                                          00191600
      WRITE (10,190) KR                                                 00191700
      CALL PLOT1 (NSCALE,5,10,10,10)                                    00191800
      CALL PLOT2 (XMAX,XMIN,YMAX,YMIN,P)
C      CALL PLOT3 ('.',TIME,QI,NLST)                                     00192000
      CALL OMIT (-3)                                                    00192100
      CALL PLOT4 (36,'          BANK STORAGE DISCHARGE CFS')            00192200
      WRITE (10,210)                                                    00192300
C                                                                       00192400
C            ACCUMULATION AND MASS BALANCE COMPUTATIONS                 00192500
  130 DO 140 NT=N1ST,NLST                                               00192600
      QIVOL=QIVOL+QI(NT)*CONST2                                         00192700
      QIAVOL=QIAVOL+ABS(QI(NT))*CONST2                                  00192800
      QLSVOL=QLSVOL+SQLOSS(NT)*CONST2                                   00192900
      USQVOL=USQVOL+USQ(NT)*CONST2                                      00193000
      DSQVOL=DSQVOL+DSQ(NT)*CONST2                                      00193100
      DSQ1VO=DSQ1VO+DSQ1(NT)*CONST2                                     00193200
  140 CONTINUE                                                                    kt warning fix
      DBQVOL=DBQVOL+DSQB*FLOAT(NLST-N1ST+1)*CONST2                      00193300
      UBQVOL=UBQVOL+USQB*FLOAT(NLST-N1ST+1)*CONST2                      00193400
      QILSVO=QILSVO+QILOST*CONST3                                       00193500
      IF (ZEND) GO TO 150                                               00193600
      RETURN                                                            00193700
C             COMPUTE FINAL VOLUMES                                     00193800
  150 QLSVOL=QLSVOL/86400.                                              00193900
C  ***   WELCUM not changed because it already is in units of cfs-days     PRJ 2/12/85
      USQVOL=USQVOL/86400.                                              00194000
      DSQVOL=DSQVOL/86400.                                              00194100
      DSQ1VO=DSQ1VO/86400.                                              00194200
      UBQVOL=UBQVOL/86400.                                              00194300
      DBQVOL=DBQVOL/86400.                                              00194400
      QIVOL=QIVOL/86400.                                                00194500
      QIAVOL=QIAVOL/86400.                                              00194600
      QILSVO=QILSVO/86400.                                              00194700
      USQREL=USQVOL-UBQVOL                                              00194800
      DSQREL=DSQ1VO-DBQVOL                                              00194900
C             COMPUTE BANK STORAGE VALUES                               00195000
      QLSTOT=QIVOL+QLSVOL                                               00195100
       IF (KCNT.EQ.1) USREL1 = USQREL                                         ADDED 2/11/85 PRJ
C      WRITE (10,218) USREL1                                                        for debugging 2/11/85 PRJ NOW "C"
 218   FORMAT (25X,'FIRST REACH RELEASE OR FLOOD VOLUME = ',F9.1,        FORMAT NOW USED LATER 2/85 PRJ
     & ' CFS-DAYS')                                                             continuation, PRJ 2/85
       QLSCUM = QLSCUM + QLSTOT                                               ADDED 2/11/85 PRJ
       QLEXWE = QLSCUM - WELCUM                                               ADDED 2/11/85 PRJ
      IF (USREL1.EQ.0.0) GO TO 159                                            ADDED 1/23/86, G. KUHN
       EXWEPC = 100*QLEXWE/USREL1                                                 ADDED 2/11/85 PRJ
  159 QX=(QIAVOL+ABS(QIVOL))/2.                                         00195200
C      IF (QIVOL) 160,170,170                                            00195300  kt warning fix
      IF (QIVOL.LT.0) THEN                                                        kt warning fix
        GO TO 160                                                                 kt warning fix
      ELSE                                                                        kt warning fix
        GO TO 170                                                                 kt warning fix
      END IF                                                                      kt warning fix
  160 VOLOUT=QX                                                         00195400
      VOLIN=QIAVOL-VOLOUT                                               00195500
      GO TO 180                                                         00195600
  170 VOLIN=QX                                                          00195700
      VOLOUT=QIAVOL-VOLIN                                               00195800
  180 VOLSTO=-1.*QIVOL-QILSVO                                           00195900
C             PRINT VOLUME DATA  AND MASS BALANCE                       00196000
      IF (ZFAST) GO TO 181                                                        kt fast option
      WRITE (10,250)                                                    00196100
      IF (ZROUTE) WRITE (10,220) USQVOL,DSQVOL,DSQ1VO,UBQVOL,DBQVOL,USQR00196200
     1EL,QLSTOT,DSQREL,VOLOUT,VOLSTO,QILSVO,VOLIN,QIVOL,QLSVOL           00196300
C
      IF (ZROUTE) WRITE (10,218) USREL1                                   PRJ 2/85
       IF (ZROUTE) WRITE(10,221) WELCUM                                   PRJ 2/8/85
       IF (ZROUTE) WRITE(10,222)QLSCUM, QLEXWE, EXWEPC                         PRJ 2/11/85
C
      IF (ZFLOW) WRITE (10,230) USQVOL,DSQVOL,UBQVOL,DBQVOL,USQREL,DSQRE00196400
     1L,VOLOUT,VOLSTO,QILSVO,VOLIN,QIVOL                                 00196500
      WRITE (10,240)                                                    00196600
  181 CONTINUE                                                                    kt fast option
C                                                                       00196700
C                                                                       00196800
C                                                                       00196900
      RETURN                                                            00197000
C                                                                       00197100
  190 FORMAT ('1',35X,'BANK STORAGE DISCHARGE HYDROGRAPH OF REACH NO.',I00197200
     13/)                                                               00197300
  200 FORMAT (6F10.1)                                                   00197400
  210 FORMAT (' ',55X,' D A Y S  ')                                     00197500
  220 FORMAT ('0','TOTAL',F25.2,50X,'TOTAL (W/O BANK STORAGE + LOSSES)',00197600
     1F17.2/81X,'TOTAL (W/  BANK STORAGE + LOSSES)',F17.2/' BASE FLOW',F00197700
     221.2,50X,'BASE FLOW',F41.2/' RELEASE OR FLOOD',F14.2,5X,'STREAMFLO00197800
     3W LOSS OR GAIN',F17.2,5X,'RELEASE OR FLOOD',F34.2/36X,40(1H-)//36X00197900
     4,'BANK STORAGE:'/38X,'FLOW FROM STREAM',F22.2/38X,'STORED IN AQUIF00198000
     5ER',F21.2/38X,'LOST TO SOIL',F26.2/38X,'RETURNED TO STREAM',F20.2/00198100
     638X,'NET BANK STORAGE DISCHARGE',F12.2//36X,'DIVERSIONS AND WELL L00198200
     7OSSES',F14.2)                                                     00198300
C
  221   FORMAT('0',20X,'WELL LOSS, CUMULATIVE FROM FIRST REACH =',          PRJ 2/8/85
     &  F12.2,2X,'CFS-DAYS')                                                 PRJ 2/8/85
  222   FORMAT(40X,'CUMULATIVE TOTAL LOSS =',F9.2,' CFS-DAYS',/              PRJ 2/85
     &  9X,'CUMULATIVE LOSS EXCLUDING WELL LOSS =',F9.2,' CFS-DAYS            PRJ 2/85
     & = ',F7.2,' PERCENT OF FIRST-REACH RELEASE OR FLOOD VOLUME')                          PRJ 2/85
  230 FORMAT ('0','TOTAL',F25.2,50X,'TOTAL',F45.2/' BASE FLOW',F21.2,50X00198400
     1,'BASE FLOW',F41.2/' RELEASE OR FLOOD',F14.2,5X,'                 00198500
     2    ',24X,'RELEASE OR FLOOD',F34.2/1X,35X,40(1H-)//36X,'BANK STORA00198600
     3GE:'/38X,'FLOW FROM STREAM',F22.2/38X,'STORED IN AQUIFER',F21.2/3800198700
     4X,'LOST TO SOIL',F26.2/38X,'RETURNED TO STREAM',F20.2/38X,'NET BAN00198800
     5K STORAGE DISCHARGE',F12.2)                                       00198900
  240 FORMAT ('0',5X,'NOTE: UNLESS STATED OTHERWISE'/12X,'(-) INDICATES 00199000
     1FLOW FROM STREAM'/12X,'(+) INDICATES FLOW INTO STREAM')           00199100
  250 FORMAT ('1',47X,'VOLUME  OF  FLOW (CFS-DAYS)'/48X,27(1H-)//' UPSTR00199200
     1EAM STATION',19X,'REACH',40X,'DOWNSTREAM STATION'/1X,30(1H-),5X,4000199300
     2(1H-),5X,50(1H-))                                                 00199400
  260 FORMAT ('1',130(1H-)/1X,'REACH NO.',I3,':',9X,'BEGINS AT GAGING ST00199500
     1ATION ',2A4,2X,17A4/1X,'                        ENDS AT GAGING STA00199600
     2TION ',2A4,2X,17A4//1X,'TOTAL STUDY PERIOD:   BEGINS ',I2,'/',I2,'00199700
     3/',I4/1X,'                        ENDS ',I2,'/',I2,'/',I4/1X,130(100199800
     4H-))                                                              00199900
  270 FORMAT ('0','    DATE     TIME  UPSTREAM   DOWNSTREAM   UPSTREAM  00200000
     1 DOWNSTREAM  CHANGE IN   BANK STORAGE'/1X,'                   DISC00200100
     2HARGE  DISCHARGE    STAGE      STAGE       STAGE       DISCHARGE')00200200
  280 FORMAT ('1')                                                      00200300
  290 FORMAT ('0'/1X,130(1H.)/' THIS SIMULATION PERIOD BEGINS ',I2,'/',I00200400
     12,'/',I4,2X,'AND ENDS ',I2,'/',I2,'/',I4/1X,130(1H.))             00200500
  300 FORMAT ('0',//44X,'SUMMARY OF STREAMFLOW DIVERSIONS AND DEPLETIONS00200600
     1'/44X,47(1H-)/1X,28X,'DISTANCE FROM STREAM       DISCHARGE    STAR00200700
     2TING DAY       ENDING DAY '/1X,28X,'       FEET                   00200800
     3CFS     NUMBER OF DAY FROM BEGINNING OF MODEL RUN')               00200900   changed 2/20/85 PRJ
  310 FORMAT (' ',27X,F12.2,F22.2,I16,I17)                              00201000
C 320 FORMAT ('0',/51X,'SUMMARY OF DATA AND RESULTS'/51X,27(1H-)/1X,'   00201100
C    1 DATE     TIME   UPSTREAM   DOWNSTREAM       UPSTREAM  DOWNSTREAM 00201200
C    2 CHANGE IN  DIVERSIONS    BANK STORAGE   DOWNSTREAM'/1X,'         00201300
C    3           DISCHARGE  DISCHARGE        STAGE     STAGE       STAGE00201400
C    4      AND           DISCHARGE      DISCHARGE'/1X,'                00201500
C    5               W/O BANK STORAGE                                  D00201600
C    6EPLETIONS                   (FINAL)'/1X,'                         00201700
C    7      AND LOSSES')                                                00201800
C
C     NEW FORMAT STATEMENT, G.KUHN, 9-26-85.
C
  321 FORMAT (1H0,/,51X,27HSUMMARY OF DATA AND RESULTS,/,51X,27(1H-),/,3
     *3X,8HOBSERVED,4X,9HPREDICTED,4X,13HDOWNST. Q W/O,4X,4HBANK,6X,10HD
     *IVERSIONS,28X,6HCHANGE,/,20X,8HUPSTREAM,4X,10HDOWNSTREAM,3X,10HDOW
     *NSTREAM,3X,12HBANK STORAGE,4X,7HSTORAGE,7X,3HAND,7X,8HUPSTREAM,3X,
     *10HDOWNSTREAM,6X,2HIN,/,4X,4HDATE,5X,4HTIME,3X,9HDISCHARGE,3X,9HDI
     *SCHARGE,4X,9HDISCHARGE,5X,10HAND LOSSES,4X,9HDISCHARGE,3X,10HDEPLE
     *TIONS,4X,5HSTAGE,7X,5HSTAGE,7X,5HSTAGE,/)
C
  330 FORMAT (' ',I3,'/',I2,'/',I4,I6,F11.2,F12.2,F10.2,F13.2,F11.3,F14.00201900
     12)                                                                00202000
C 340 FORMAT (' ',I3,'/',I2,'/',I4,I6,F11.2,F13.2,F13.2,F12.2,F11.3,F13.00202100
C    12,F13.2,F17.2,A4)                                                 00202200
C
C     NEW FORMAT STATEMENT, G.KUHN, 9-26-85.
C
  341 FORMAT (1X,I2,1H/,I2,1H/,I4,I6,F11.2,F12.2,F13.2,A4,F11.2,F14.2,
     *F12.2,F11.2,2F12.2)
C
  342 FORMAT (21X,7H-------,5X,7H-------,6X,7H-------,8X,7H-------,
     *7X,7H-------,5X,7H-------,/,1X,14HCOLUMN TOTALS:)
  343 FORMAT (1H+,14X,F13.2,F12.2,F13.2,F15.2,F14.2,F12.2)
C
  350 FORMAT ('0','FOOTNOTE: *  DOWNSTREAM DISCHARGE IS LESS THAN SPECIF00202300
     1IED MINIMUM FLOW.'/10X,'        THIS MAY BE CAUSED BY THE MODEL WH00202400
     2EN A SHARP RISE IN STAGE OCCURS.'/10X,'        OR'/10X,'        TH00202500
     3IS MAY ALSO BE CAUSED BY A HIGH DIVERSION OR DEPLETION.'//10X,' **00202600
     4 DIVERSIONS AND DEPLETIONS WERE REDUCED TO PREVENT NEGATIVE FLOW A00202700
     5T ONSET.'/10X,'        DOWNSTREAM DISCHARGES SHOWN RESULT FROM BAN00202800
     6K STORAGE.')                                                      00202900
      END                                                               00203000
C
C
C    [06-22-06 LEP, this ERFC function had been commented out, citing
C                   some unnamed error. since we did not have the obj file
C                   to link to for external method, needed to add it back.
C				  may consider porting other erfc to replace this method
C                   if this is inadequate.
      FUNCTION ERFC (ZZZ)
C
C
C              THE COMPLIMENTARY ERROR FUNCTION         
C              PROGRAMMED BY KENNETH J SCHRINER 7/13/81     
C              TO REPLACE A CALL TO THE IBM SYSTEM ERFC     
C
C
      REAL SUM, TERM, ZZZ                                   
      INTEGER FACT                                         
      SUM = 0.0                                            
      N = 0                                                
   10 N = N + 1                                             
      TERM = ((-1.)**N) * (ZZZ**(2. * N + 1))               
      FACT = 1                                             
      DO 20 I = 1,N                                        
      FACT = FACT * I                                       
   20 CONTINUE                                             
      TERM = TERM / (FACT * (2*N + 1))                     
      SUM = SUM + TERM                                     
      ERFC = 1. - SUM                                      
      IF (ABS (TERM) .LE. .00001) RETURN                    
      GO TO 10                                              
      END                                                   
      BLOCK DATA                                                        00203100
C                                                                       00203200
      INTEGER OPFILE,C,P,PU,US,DS                                       00203300
      CHARACTER *4 IWARN (9000)
      CHARACTER *4 IW0, IW1, IW2
      DIMENSION MODAYS (12)
      COMMON / DAYSMO / MODAYS
      COMMON /WARN/ IWARN,IW0,IW1,IW2                                   00203600
      COMMON /UNITS/ C,P,PU,US,DS,NDIM,MDIM                             00203700
      DATA NDIM/9000/,MDIM/18000/                                       00203800  %kt changed for 400 800 to 1600 3200 etc
      DATA C/7/,P/10/,PU/7/,US/1/,DS/2/
C--------------- "C" changed to 7 to reflect Pr1me file system.    jbs  6/83
C--------------- "P" changed to 10                    jbs  6/83
      DATA IW0/'    '/,IW1/'   *'/,IW2/'  **'/                          00204000
      DATA MODAYS/31,28,31,30,31,30,31,31,30,31,30,31/                  00204100
C                                                                       00204200
C     NOTE: IF DIMENSIONS ARE CHANGED; NDIM & MDIM MUST ALSO BE CHANGED 00204300
C                                                                       00204400
      END                                                               00204500
 