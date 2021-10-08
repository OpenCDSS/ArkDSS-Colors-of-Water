
% StateTLm
% matlab preliminary Colors of Water Transit Loss and Timing engine

% next steps
% potentially reduce structure approach to line up of all R/SR within WD
%   think about if step in at midpoint if lineup would be better
%   lineup would help with running through for a plot etc rather than having to run loops again to build a line of data
% look at getting water class records out of Pueblo sheet
% get JM2SL data in
% BELIEVE STILL NEED TO DO FLOW TEST AND ADD low/avg/high of ungaged inflows/outflows

% perhaps recompile j349 in gfortran for 365 days (leapyear?) + 35 days / 400 days * 24hr = 9600
% perhaps set up year timeline for data.. 
%  when checking for gage/diversion data just add onto what has already been collected for year
%  for diversion data, maybe hit to gather all for year and/or new day.. then process what is found vs a list of what should be ran as a color
%  would tests be entered into HB - or if running locally on JVOs machine a local file - but if in HB maybe have a new type - ie "test" rather than provisional
%  maybe for initial forecasting - take "trend" from last week and some average of last day or average of last week and project to today, but then project
%  forward maybe full trend rate for 3 days, then ramp back trend at like 75%/50%/25%/10% of
%  trend on next 4, then go constant (ie no trend and values stay same) from that value going forward?? for
%  rest of year?  Need projected values for everything so that gagediff
%  still is also based on - or else need week averages of gagediff etc?
%  What does water do that is already in the river - same releases in
%  perpuituity??  Or is this where we need some projected end of the
%  release into the HB record - ie provisional records need to go until projected end of release (or use google sheet??)
% maybe web tool looks at all HB records plus any records on a local
% machine location (ie C drive?)
% also worried about zero flows - need to check if "all of the colors of
% water" exceed total flow so that would be drying up the river even beyond
% the slush thats the native flow part; if so cut them all back or back by
% some sort of priority... that might lend to more thoughts about lining up
% full river wd zone rather than by river reach .. but would need to run admin
% once then add up all colors and see if exceed full full (pred) flows and
% if so then get into while loop where each color is cut back at no flow
% locations and run while until no exceedance of full flows..


cd C:\Projects\Ark\ColorsofWater\matlab
clear all
disp(datestr(now))
basedir=cd;basedir=[basedir '\'];
% j349dir=[basedir 'j349dir\'];
% j349dir=basedir;

readinfofile=2;  %1 reads from excel and saves mat file; 2 reads mat file;
readgageinfo=2;  %if using real gage data, 1 reads from REST, 2 reads from file - watch out currently saves into SR file
infofilename='StateTL_inputdata.xlsx';
pulldivrecrest=2;  %1 if pulling release value from HB REST; 2 reads from mat file

%rdays=155; rhours=4;
%spinupdays=60;
rdays=60; rhours=1;
spinupdays=45;
rsteps=rdays*24/rhours;
gainchangelimit=0.1;

flowcriteria=5; %to establish gage and node flows: 1 low, 2 avg, 3 high flow values from livingston; envision 4 for custom entry; 5 for actual flows; 6 average for xdays/yhours prior to now/date; 7 average between 2 dates

datestart=datenum(2017,8,20);
waterclass=[{'1403526.147 S:2 F: U:Q T:7 G: To:1700554'},{1}];  %A:Holbrook Ag Proj S:Reservoir Storage Ty:Released To River To:Holbrook Canal
waterclass=[waterclass; {'1403526.075 S:2 F: U:Q T:7 G: To:1700540'},{1}];  %A:Colo Canal Ag Proj S:Reservoir Storage Ty:Released To River To:Colorado Canal
waterclass=[waterclass; {'1403526.238 S:2 F: U:Q T:7 G: To:1700542'},{1}];  %A:Rfhighline Ag Proj S:Reservoir Storage Ty:Released To River To:Rocky Ford Highline
waterclass=[waterclass; {'1403526.313 S:2 F: U:Q T:7 G: To:1700553'},{1}];  %A:Fort Lyon  Ag Project S:Reservoir Storage Ty:Released To River To:Fort Lyon Canal
waterclass=[waterclass; {'1403526.056 S:2 F: U:Q T:7 G: To:1700552'},{1}];  %A:Catlin Ag Projectect S:Reservoir Storage Ty:Released To River To:Catlin Canal
waterclass=[waterclass; {'1403526.059 S:2 F: U:Q T:7 G: To:1700552'},{1}];  %A:Catlin Ww S:Reservoir Storage Ty:Released To River To:Catlin Canal
waterclass=[waterclass; {'1403526.006 S:2 F: U:Q T:7 G: To:1400539'},{1}];  %A:Agua Ag I&W S:Reservoir Storage Ty:Released To River To:Excelsior Ditch
waterclass=[waterclass; {'1403526.150 S:2 F: U:Q T:7 G: To:1700554'},{1}];  %A:Holbrook Ww S:Reservoir Storage Ty:Released To River To:Holbrook Canal
waterclass=[waterclass; {'1403526.217 S:2 F: U:Q T:7 G: To:1700557'},{1}];  %A:Otero Ditch Ag Proj S:Reservoir Storage Ty:Released To River To:Otero Canal
waterclass=[waterclass; {'1403526.231 S:2 F: U:Q T:7 G: To:1400618'},{1}];  %A:Pbww Nfec S:Reservoir Storage Ty:Released To River To:Comanche Pump Station

%Type 2 - return flow maintenance / well depletion stuff; include as goes to native?
waterclass=[waterclass; {'1703525.042 S:2 F: U:Q T:7 G: To:1720001'},{2}];  %	A:Colo Canal Ag I&W S:Reservoir Storage Ty:Released To River To:River Reach "Arkansas River"
waterclass=[waterclass; {'1703525.114 S:2 F: U:Q T:7 G:1707010 To:1720001'},{2}];  %	A:Olney Springs - M&I Proj S:Reservoir Storage Ty:Released To River To:River Reach "Arkansas River"
waterclass=[waterclass; {'1703525.156 S:2 F: U:Q T:7 G:1707854 To:1720001'},{2}];  %	A:Aurora Ag I&W S:Reservoir Storage Ty:Released To River To:River Reach "Arkansas River"
waterclass=[waterclass; {'1703525.157 S:2 F: U:Q T:7 G:1707003 To:1720001'},{2}];  %	A:Ccwa M&I Project S:Reservoir Storage Ty:Released To River To:River Reach "Arkansas River"
waterclass=[waterclass; {'1703525.160 S:2 F: U:Q T:7 G:1707000 To:1720001'},{2}];  %	A:Crowley City M&I Project S:Reservoir Storage Ty:Released To River To:River Reach "Arkansas River"

%Exchanges - Type 3 - this doesn't have losses but it does have routing;
%should we use the div3 assumptions on timing and/or use diversion records
%both at pueblo/meredith - or should we iterate to back it up - ie find
%release timing from us point to replicate ds point - or do we just use the
%top diversion record to calculate timing at ds point.. think this is it..
waterclass=[waterclass; {'1403526.007 S:1 F:1700558 U:0 T:4 G: To:'},{3}];  %	A:Aurora Non-Firm S:Natural Stream flow F:Rocky Ford Ditch Ty:Alternate Point Of Diversion Storage Of Alternate Point Of Diversion For The Rocky Ford Ditch (Rig I & Rig Ii)
waterclass=[waterclass; {'1403526.318 S:8 F:1004700 U:0 T:1 G: To:'},{3}];  %	A:Cspgs-Long Term S:Re-usable Water F:Colo Spgs Sewered Tm Rf Ty:Exchange Storage Of Csu Tm Reusable Return Flows In Pueblo Res By Exchange As Tracked Down Fountain Creek
waterclass=[waterclass; {'1403526.090 S:8 F:1400993 U:0 T:1 G:1407151 To:'},{3}];  % To:	A:Cwpda M&I I&W S:Re-usable Water F:Cwpda Cu Supplies Ty:Exchange
waterclass=[waterclass; {'1403526.006 S:8 F:1004700 U:0 T:1 G: To:'},{3}];  %	A:Agua Ag I&W S:Re-usable Water F:Colo Spgs Sewered Tm Rf Ty:Exchange
waterclass=[waterclass; {'1403526.176 S:1 F:1700800 U:0 T:1 G:1707700 To:'},{3}];  % To:	A:Lower Arkm&I I&W S:Natural Stream flow F:Catlin Aug St @ Timpas Creek Ty:Exchange listed quality: I
waterclass=[waterclass; {'1403526.274 S:8 F:1004701 U:0 T:1 G: To:'},{3}];  %	A:Stratmoor M&I I&W S:Re-usable Water F:Fry-Ark Return Flows Ty:Exchange Storage Record Of Stratmoor Fry-Ark Water Tracked Down Fountain Creek For Storage In Pueblo Res.
waterclass=[waterclass; {'1403526.231 S:1 F:1400535 U:0 T:4 G: To:'},{3}];  %	A:Pbww Nfec S:Natural Stream flow F:West Pueblo Ditch Ty:Alternate Point Of Diversion Alternate Point Of Diversion For The West Pueblo Ditch To The Pueblo Reservoir.  (Pbww)
% located above gage? %waterclass=[waterclass; {'1403526.231 S:1 F:1400534 U:0 T:1 G: To:'},{3}];  %	A:Pbww Nfec S:Natural Stream flow F:Hamp-Bell Ditch Ty:Exchange


datestart=datenum(2017,8,10);
figtop=2000;
waterclass=[{'1403526.091 S:2 F: U:Q T:7 G: To:6703512.034'},{1}];  %CWPDA to offset account; A:Cwpda Ag I&W S:Reservoir Storage Ty:Released To River To:John Martin ReservoirOffset Account Water Delivered By Upstream Well Associations Not Yet Charged Against Well Depletions

datestart=datenum(2018,4,01);
figtop=1500;
waterclass=[{'1403526.091 S:2 F: U:Q T:7 G: To:6703512.034'},{1}];  %CWPDA to offset account; A:Cwpda Ag I&W S:Reservoir Storage Ty:Released To River To:John Martin ReservoirOffset Account Water Delivered By Upstream Well Associations Not Yet Charged Against Well Depletions
waterclass=[waterclass; {'1403526.007 S:2 F: U:Q T:7 G: To:1700540'},{1}];  %A:Aurora Non-Firm S:Reservoir Storage Ty:Released To River To:Colorado Canal
waterclass=[waterclass; {'1403526.313 S:2 F: U:Q T:7 G: To:1700553'},{1}];  %A:Fort Lyon  Ag Project S:Reservoir Storage Ty:Released To River To:Fort Lyon Canal
waterclass=[waterclass; {'1403526.316 S:2 F: U:Q T:7 G: To:1700553'},{1}];  %A:Fort Lyon Ag Ww Co S:Reservoir Storage Ty:Released To River To:Fort Lyon Canal
waterclass=[waterclass; {'1403526.056 S:2 F: U:Q T:7 G: To:1700552'},{1}];  %A:Catlin Ag Projectect S:Reservoir Storage Ty:Released To River To:Catlin Canal
waterclass=[waterclass; {'1403526.060 S:2 F: U:Q T:7 G: To:1700552'},{1}];  %A:Catlin Ww Co S:Reservoir Storage Ty:Released To River To:Catlin Canal
waterclass=[waterclass; {'1403526.242 S:2 F: U:Q T:7 G: To:1700542'},{1}];  %A:Rfhighline Ww Co S:Reservoir Storage Ty:Released To River To:Rocky Ford Highline
waterclass=[waterclass; {'1403526.079 S:2 F: U:Q T:7 G: To:1700540'},{1}];  %A:Colo Canal Ww Co S:Reservoir Storage Ty:Released To River To:Colorado Canal
waterclass=[waterclass; {'1403526.177 S:2 F: U:Q T:7 G: To:1700552'},{1}];  %A:Lower Arkag I&W S:Reservoir Storage Ty:Released To River To:Catlin Canal
waterclass=[waterclass; {'1403526.224 S:2 F: U:Q T:7 G: To:1700541'},{1}];  %A:Oxford Ditch Ww Co S:Reservoir Storage Ty:Released To River To:Oxford Canal
waterclass=[waterclass; {'1403526.006 S:2 F: U:Q T:7 G: To:1400539'},{1}];  %A:Agua Ag I&W S:Reservoir Storage Ty:Released To River To:Excelsior Ditch
waterclass=[waterclass; {'1403526.075 S:2 F: U:Q T:7 G: To:1700540'},{1}];  %A:Colo Canal Ag Proj S:Reservoir Storage Ty:Released To River To:Colorado Canal

%waterclass=[waterclass; {'1403526.238 S:2 F: U:Q T:7 G: To:1700542'},{1}];  %A:Rfhighline Ag Proj S:Reservoir Storage Ty:Released To River To:Rocky Ford Highline
%waterclass=[waterclass; {'1403526.147 S:2 F: U:Q T:7 G: To:1700554'},{1}];  %A:Holbrook Ag Proj S:Reservoir Storage Ty:Released To River To:Holbrook Canal
%waterclass=[waterclass; {'1403526.217 S:2 F: U:Q T:7 G: To:1700557'},{1}];  %A:Otero Ditch Ag Proj S:Reservoir Storage Ty:Released To River To:Otero Canal
%waterclass=[waterclass; {'1403526.037 S:2 F: U:Q T:7 G: To:1700540'},{1}];  %A:Blm Ag I&W S:Reservoir Storage Ty:Released To River To:Colorado Canal Delivery Of 2250 Water For Deweesse Reservoir
%waterclass=[waterclass; {'1403526.072 S:2 F: U:Q T:7 G: To:1400538'},{1}];  %A:Collier Ditch Ag Proj S:Reservoir Storage Ty:Released To River To:Collier Ditch

%exchange
% 1403526.318 S:8 F:1004700 U:0 T:1 G: To:'},{3}];  %A:Cspgs-Long Term S:Re-usable Water F:Colo Spgs Sewered Tm Rf Ty:Exchange Storage Of Csu Tm Reusable Return Flows In Pueblo Res By Exchange As Tracked Down Fountain Creek
% 1403526.007 S:1 F:1700558 U:0 T:4 G: To:'},{3}];  %A:Aurora Non-Firm S:Natural Stream flow F:Rocky Ford Ditch Ty:Alternate Point Of Diversion Storage Of Alternate Point Of Diversion For The Rocky Ford Ditch (Rig I & Rig Ii)
% 1403526.176 S:1 F:1700800 U:0 T:1 G:1707700 To:'},{3}];  %A:Lower Arkm&I I&W S:Natural Stream flow F:Catlin Aug St @ Timpas Creek Ty:Exchange listed quality: I
% 1403526.231 S:1 F:1400535 U:0 T:4 G: To:'},{3}];  %A:Pbww Nfec S:Natural Stream flow F:West Pueblo Ditch Ty:Alternate Point Of Diversion Alternate Point Of Diversion For The West Pueblo Ditch To The Pueblo Reservoir.  (Pbww)
% 1403526.090 S:8 F:1400993 U:0 T:1 G:1407151 To:'},{3}];  %A:Cwpda M&I I&W S:Re-usable Water F:Cwpda Cu Supplies Ty:Exchange
% 1403526.343 S:1 F:1700800 U:0 T:1 G:1707030 To:'},{3}];  %A:Catlin Aug Association Ag I&W S:Natural Stream flow F:Catlin Aug St @ Timpas Creek Ty:Exchange

%%%%%%%%%%%%%%%%%%%%%%%%%%
%READ SUBREACH INFORMATION
%%%%%%%%%%%%%%%%%%%%%%%%%%
global SR

if readinfofile==1
    
disp('reading subreach info from file')    
  
SR.D2.WD=[17];           %WD17=pueblo gage to JMR  %may want to automate this from inputdata read
SR.D2.WD17.R=[1:8];
SR.D2.WD17.R0.SR=[1];
SR.D2.WD17.R1.SR=[1:2];
SR.D2.WD17.R2.SR=[1:8];
SR.D2.WD17.R3.SR=[1:7];
SR.D2.WD17.R4.SR=[1:3];
SR.D2.WD17.R5.SR=[1:4];
SR.D2.WD17.R6.SR=[1:4];
SR.D2.WD17.R7.SR=[1:4];
SR.D2.WD17.R8.SR=[1:2];


[infonum,infotxt,inforaw]=xlsread([basedir infofilename],'SR');
[infonumrow infonumcol]=size(infonum);
[inforawrow inforawcol]=size(inforaw);

% for i=1:inforawrow
%     if strcmp(upper(inforaw{i,1}),'Div')
%         infoheaderrow=i; break;
%     end
% end

infoheaderrow=1;

for i=1:inforawcol
    if 1==2
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'DIV'); infocol.div=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'WD'); infocol.wd=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'REACH'); infocol.reach=i;
%     elseif strcmp(upper(inforaw{infoheaderrow,i}),'LIVINGSTON SUBREACH'); infocol.livingstonsubreach=i; %delete when expanding model
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'SUBREACH'); infocol.subreach=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'SRID'); infocol.srid=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'CHANNEL LENGTH'); infocol.channellength=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'ALLUVIUM LENGTH'); infocol.alluviumlength=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'TRANSMISSIVITY'); infocol.transmissivity=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'STORAGE COEFFICIENT'); infocol.storagecoefficient=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'AQUIFER WIDTH'); infocol.aquiferwidth=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'DISPERSION-A'); infocol.dispersiona=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'DISPERSION-B'); infocol.dispersionb=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'CELERITY-A'); infocol.celeritya=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'CELERITY-B'); infocol.celerityb=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'CLOSURE'); infocol.closure=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'REACH PORTION'); infocol.reachportion=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'GAININITIAL'); infocol.gaininitial=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'WIDTH-A'); infocol.widtha=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'WIDTH-B'); infocol.widthb=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'EVAPFACTOR'); infocol.evapfactor=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'LOSSPERCENT'); infocol.losspercent=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'DS NODES'); infocol.dsnodes=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'TYPE1'); infocol.type1=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'LOW1'); infocol.low1=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'AVG1'); infocol.avg1=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'HIGH1'); infocol.high1=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'STATION1'); infocol.station1=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'PARAMETER1'); infocol.parameter1=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'WDID1'); infocol.wdid1=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'NAME1'); infocol.name1=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'TYPE2'); infocol.type2=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'LOW2'); infocol.low2=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'AVG2'); infocol.avg2=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'HIGH2'); infocol.high2=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'STATION2'); infocol.station2=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'PARAMETER2'); infocol.parameter2=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'WDID2'); infocol.wdid2=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'NAME2'); infocol.name2=i;

    end
end

k=0;
wdidk=0;
for i=infoheaderrow+1:inforawrow
    
    if ~isempty(inforaw{i,infocol.subreach}) & ~isnan(inforaw{i,infocol.subreach})
        k=k+1;
        v.di=inforaw{i,infocol.div};if ischar(v.di); v.di=str2num(v.di); end
        v.wd=inforaw{i,infocol.wd};if ischar(v.wd); v.wd=str2num(v.wd); end
        v.re=inforaw{i,infocol.reach};if ischar(v.re); v.re=str2num(v.re); end        
%         v.ls=inforaw{i,infocol.livingstonsubreach};if ischar(v.ls); v.ls=str2num(v.ls); end  %delete when expanding model
        v.sr=inforaw{i,infocol.subreach};if ischar(v.sr); v.sr=str2num(v.sr); end
        v.si=inforaw{i,infocol.srid};if ischar(v.si); v.si=str2num(v.si); end
        v.cl=inforaw{i,infocol.channellength};if ischar(v.cl); v.cl=str2num(v.cl); end
        v.al=inforaw{i,infocol.alluviumlength};if ischar(v.al); v.al=str2num(v.al); end
        v.tr=inforaw{i,infocol.transmissivity};if ischar(v.tr); v.tr=str2num(v.tr); end
        v.sc=inforaw{i,infocol.storagecoefficient};if ischar(v.sc); v.sc=str2num(v.sc); end
        v.aw=inforaw{i,infocol.aquiferwidth};if ischar(v.aw); v.aw=str2num(v.aw); end
        v.da=inforaw{i,infocol.dispersiona};if ischar(v.da); v.da=str2num(v.da); end
        v.db=inforaw{i,infocol.dispersionb};if ischar(v.db); v.db=str2num(v.db); end
        v.ca=inforaw{i,infocol.celeritya};if ischar(v.ca); v.ca=str2num(v.ca); end
        v.cb=inforaw{i,infocol.celerityb};if ischar(v.cb); v.cb=str2num(v.cb); end
        v.cls=inforaw{i,infocol.closure};if ischar(v.cls); v.cls=str2num(v.cls); end
        v.rp=inforaw{i,infocol.reachportion};if ischar(v.rp); v.rp=str2num(v.rp); end
        v.gi=inforaw{i,infocol.gaininitial};if ischar(v.gi); v.gi=str2num(v.gi); end
        v.wa=inforaw{i,infocol.widtha};if ischar(v.wa); v.wa=str2num(v.wa); end
        v.wb=inforaw{i,infocol.widthb};if ischar(v.wb); v.wb=str2num(v.wb); end
        v.ef=inforaw{i,infocol.evapfactor};if ischar(v.ef); v.ef=str2num(v.ef); end
        v.lp=inforaw{i,infocol.losspercent};if ischar(v.lp); v.lp=str2num(v.lp); end
        v.ds=inforaw{i,infocol.dsnodes};if ischar(v.ds); v.ds=str2num(v.ds); end
        v.t1=inforaw{i,infocol.type1};if ischar(v.t1); v.t1=str2num(v.t1); end
        v.l1=inforaw{i,infocol.low1};if ischar(v.l1); v.l1=str2num(v.l1); end
        v.a1=inforaw{i,infocol.avg1};if ischar(v.a1); v.a1=str2num(v.a1); end
        v.h1=inforaw{i,infocol.high1};if ischar(v.h1); v.h1=str2num(v.h1); end
        v.t2=inforaw{i,infocol.type2};if ischar(v.t2); v.t2=str2num(v.t2); end
        v.l2=inforaw{i,infocol.low2};if ischar(v.l2); v.l2=str2num(v.l2); end
        v.a2=inforaw{i,infocol.avg2};if ischar(v.a2); v.a2=str2num(v.a2); end
        v.h2=inforaw{i,infocol.high2};if ischar(v.h2); v.h2=str2num(v.h2); end
        c.di=num2str(inforaw{i,infocol.div});
        c.wd=num2str(inforaw{i,infocol.wd});
        c.re=num2str(inforaw{i,infocol.reach});
        c.sr=num2str(inforaw{i,infocol.subreach});
        c.s1=num2str(inforaw{i,infocol.station1});
        c.p1=num2str(inforaw{i,infocol.parameter1});
        c.w1=num2str(inforaw{i,infocol.wdid1});
        c.n1=num2str(inforaw{i,infocol.name1});
        c.s2=num2str(inforaw{i,infocol.station2});
        c.p2=num2str(inforaw{i,infocol.parameter2});
        c.w2=num2str(inforaw{i,infocol.wdid2});
        c.n2=num2str(inforaw{i,infocol.name2});
        
%         SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).livingstonsubreach(v.sr)=v.ls; %delete when expanding model
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).subreachid(v.sr)=v.si;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).channellength(v.sr)=v.cl;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).alluviumlength(v.sr)=v.al;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).transmissivity(v.sr)=v.tr;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).storagecoefficient(v.sr)=v.sc;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).aquiferwidth(v.sr)=v.aw;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dispersiona(v.sr)=v.da;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dispersionb(v.sr)=v.db;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).celeritya(v.sr)=v.ca;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).celerityb(v.sr)=v.cb;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).closure(v.sr)=v.cls;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).reachportion(v.sr)=v.rp;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).gaininitial(v.sr)=v.gi;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).widtha(v.sr)=v.wa;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).widthb(v.sr)=v.wb;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).evapfactor(v.sr)=v.ef;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).losspercent(v.sr)=v.lp;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dsnodes(v.sr)=v.ds;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).type(1,v.sr)=v.t1;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).low(1,v.sr)=v.l1;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).avg(1,v.sr)=v.a1;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).high(1,v.sr)=v.h1;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).station{1,v.sr}=c.s1;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).parameter{1,v.sr}=c.p1;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).name{1,v.sr}=c.n1;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).type(2,v.sr)=v.t2;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).low(2,v.sr)=v.l2;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).avg(2,v.sr)=v.a2;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).high(2,v.sr)=v.h2;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).station{2,v.sr}=c.s2;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).parameter{2,v.sr}=c.p2;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).name{2,v.sr}=c.n2;
        
        if ~strcmp(c.w1,'NaN')
            wdidk=wdidk+1;
            SR.(['D' c.di]).WDID{wdidk,1}=c.w1;
            SR.(['D' c.di]).WDID{wdidk,2}=v.di;
            SR.(['D' c.di]).WDID{wdidk,3}=v.wd;
            SR.(['D' c.di]).WDID{wdidk,4}=v.re;
            SR.(['D' c.di]).WDID{wdidk,5}=v.sr;
            SR.(['D' c.di]).WDID{wdidk,6}=1;
        end
        if ~strcmp(c.w2,'NaN')
            wdidk=wdidk+1;
            SR.(['D' c.di]).WDID{wdidk,1}=c.w2;
            SR.(['D' c.di]).WDID{wdidk,2}=v.di;
            SR.(['D' c.di]).WDID{wdidk,3}=v.wd;
            SR.(['D' c.di]).WDID{wdidk,4}=v.re;
            SR.(['D' c.di]).WDID{wdidk,5}=v.sr;
            SR.(['D' c.di]).WDID{wdidk,6}=2;
        end        
    end
end


%%%%%%%%%%%%%%%%%%
% evaporation data
% this will probably have to be refined as expand reaches or use better data

[infonum,infotxt,inforaw]=xlsread([basedir infofilename],'evap');
[infonumrow infonumcol]=size(infonum);
[inforawrow inforawcol]=size(inforaw);
SR.(['D' c.di]).(['WD' c.wd]).evap=infonum(:,1);

%%%%%%%%%%%%%%%%%%
% stage discharge data
% this will probably have to be refined as expand reaches

[infonum,infotxt,inforaw]=xlsread([basedir infofilename],'stagedischarge');
[infonumrow infonumcol]=size(infonum);
[inforawrow inforawcol]=size(inforaw);
SR.(['D' c.di]).(['WD' c.wd]).stagedischarge=infonum;

 clear c v info*

save([basedir 'StateTL_SRdata.mat'],'SR');

else
    load([basedir 'StateTL_SRdata.mat']);
end


%%%%%%%%%%%%%%%%%
% READ FLOW DATA
% much of this needs to be improved for larger application; particularly
% handling of dates
%%%%%%%%%%%%%%%%%
rdates=datestart*ones(spinupdays*24/rhours,1);
rdates=[rdates;[datestart:rhours/24:datestart+(rdays-spinupdays)-rhours/24]'];
rdatesstartid=spinupdays*24/rhours+1;
[ryear,rmonth,rday,rhour] = datevec(rdates);
rdatesday=floor(rdates);
rjulien=rdatesday-(datenum(ryear,1,1)-1);
dateend=datestart+(rdays-spinupdays)-1;
datedays=[datestart:dateend];


flowtestloc=[2,17,7,4,1];

if readgageinfo==1

switch flowcriteria
    case 1
        flow='low';
    case 2
        flow='avg';
    case 3
        flow='high';
    otherwise
        disp('reading gage data from HB using REST services')    
        d=flowtestloc(1);wd=flowtestloc(2);r=flowtestloc(3);sr=flowtestloc(4);n=flowtestloc(5);
        station=SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).station{n,sr};
        parameter=SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).parameter{n,sr};
        gageurl=['https://dwr.state.co.us/Rest/GET/api/v2/telemetrystations/telemetrytimeseriesday/?format=json&abbrev=' station '&endDate=' num2str(rmonth(end),'%02.0f') '%2F' num2str(rday(end),'%02.0f') '%2F' num2str(ryear(end)) '_23%3A00&includeThirdParty=true&parameter=' parameter '&startDate=' num2str(rmonth(1),'%02.0f') '%2F' num2str(rday(1),'%02.0f') '%2F' num2str(ryear(1))  '_00%3A00'];
        
        [datastr,scheck]=urlread(gageurl,'Timeout',30);
        if scheck==1
            commaids = strfind(datastr,',');
            measvalueids = strfind(datastr,'measValue');
            clear testvalues
            for i=1:length(measvalueids)
               commaidsafter=find(commaids>measvalueids(i));
               testvalues(i)=str2num(datastr(measvalueids(i)+11:commaids(commaidsafter(1))-1));
            end
            testvalue=mean(testvalues);
            test(1)=SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).low(n,sr);
            test(2)=SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).avg(n,sr);
            test(3)=SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).high(n,sr);
            testdiff=test-testvalue;
            [testdiffmin,testdiffminid]=min(abs(testdiff));
            switch testdiffminid
                case 1
                    flow='low';
                case 2
                    flow='avg';
                case 3
                    flow='high';
            end
        else
            error(['didnt get data for test station ' station ' to determine flow regime'])
        end
end

d=2;ds='D2';
for kwd=1:length(SR.(ds).WD)
    wd=SR.(ds).WD(kwd);wds=['WD' num2str(wd)];
    for r=0:SR.(ds).(wds).R(end)  %including top gage if put in reach 0
        rs=['R' num2str(r)];
        if flowcriteria>=4
            for sr=1:SR.(ds).(wds).(rs).SR(end)
                for n=1:SR.(ds).(wds).(rs).dsnodes(sr)
                    if strcmp(SR.(ds).(wds).(rs).station{n,sr},'NaN') | strcmp(SR.(ds).(wds).(rs).station{n,sr},'none')  %if no telemetry station then uses low/avg/high number
                        SR.(ds).(wds).(rs).Qnode(:,sr,n)=SR.(ds).(wds).(rs).(flow)(n,sr)*ones(rsteps,1);
                    else
                        station=SR.(ds).(wds).(rs).station{n,sr};
                        parameter=SR.(ds).(wds).(rs).parameter{n,sr};
                        telemetryhoururl='https://dwr.state.co.us/Rest/GET/api/v2/telemetrystations/telemetrytimeserieshour/';
                        gagedata=webread(telemetryhoururl,'format','json','abbrev',station,'parameter',parameter,'startDate',datestr(rdates(1),21),'endDate',datestr(rdates(end),21),'includeThirdParty','true');
                        for i=1:gagedata.ResultCount
                            measvalues(i)=gagedata.ResultList(i).measValue;
                            measdatestr=gagedata.ResultList(i).measDate;
                            measdatestr(11)=' ';
                            measdates(i)=datenum(measdatestr,31);
                            measunit{i}=gagedata.ResultList(i).measUnit; %check?
                        end
                        %here need to work out various Qnode options
                        %initial below assuming all data there and one hour timestep
                        Qnode(1:rdatesstartid-1,1)=measvalues(1);
                        Qnode(rdatesstartid:length(rdates),1)=measvalues;  
                        SR.(ds).(wds).(rs).Qnode(:,sr,n)=Qnode;                       
                    end
               end
            end
        else
            for n=1:max(SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).dsnodes)
                % num2str(r)]).Qnode(:,:,n)=SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).(flow)(n,:).*ones(rsteps,length(SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).SR));
                SR.(ds).(wds).(rs).Qnode(:,:,n)=repmat(SR.(ds).(wds).(rs).(flow)(n,:),rsteps,1).*ones(rsteps,length(SR.(ds).(wds).(rs).SR)); %repmat required for r2014a
            end
        end
    end
end

save([basedir 'StateTL_SRdata_withgage.mat'],'SR');

else
    load([basedir 'StateTL_SRdata_withgage.mat']);
end


%    'https://dwr.state.co.us/Rest/GET/api/v2/telemetrystations/telemetrytimeseriesday/?format=json&abbrev=ARKPUECO&endDate=04%2F27%2F2017_23%3A00&includeThirdParty=true&startDate=04%2F13%2F2017_00%3A00'
%    'https://dwr.state.co.us/Rest/GET/api/v2/telemetrystations/telemetrytimeseriesday/?format=json&abbrev=ARKPUECO&endDate=07%2F04%2F2019&includeThirdParty=false&parameter=DISCHRG&startDate=07%2F01%2F2019'

%%%%%%%%%%%%%%%%%%%%%%%%%%
% WATERCLASSES FROM/TO
%%%%%%%%%%%%%%%%%%%%%%%%%%

for w=1:length(waterclass(:,1))
    waterclassstr=waterclass{w,1};
    waterclass{w,3}=waterclassstr(1:7); %from
    
    if waterclass{w,2}<3
        tostr='To:';
    else  %exchanges
        tostr='F:';
    end
    toid=strfind(waterclassstr,tostr);
    if ~isempty(toid) & length(waterclassstr)-toid>=9        
        waterclass{w,4}=waterclassstr(toid+length(tostr):toid+length(tostr)+6); %to
    else
        error(['water class ' waterclassstr ' doesnt have To:wdid(7) at end (or F: for exchanges), figure that out!'])
    end
    
    %for wd17 - this would mess up things on fountain creek
    switch waterclass{w,4}
        case '1720001'  %Meredith outfall to Arkansas Reach instead tracking to JMR
            waterclass{w,4}='6703512';
        case {'1004700','1004701','1400993'}  %Return flows in Fountain Creek
            waterclass{w,4}='FOUMOUCO';
        case '1700800'                         %Timpas Creek Aug station
            waterclass{w,4}='TIMSWICO';
        case '1400535'                         %West Pueblo Ditch - near to Comanche pump station
            waterclass{w,4}='1400618';
    end
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RELEASE RECORDS FOR WATERCLASSES USING REST
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

divrecyearurl='https://dwr.state.co.us/Rest/GET/api/v2/structures/divrec/divrecyear/';
divrecdatayr=webread(divrecyearurl,'format','json','min-dataValue',0,'dataMeasDate',datestr(rdates(end),10),'wdid','1403526',weboptions('Timeout',30));


reswdidlist=[{'1403526'},{'1703525'}]; %release wdids pueblo, meredith, put into input data for wd17; Ftn Crk? Purg (To: reference?)?
onlypullnew=0;


divrecdayurl='https://dwr.state.co.us/Rest/GET/api/v2/structures/divrec/divrecday/';

if onlypullnew==0
    clear divrecsall
    divrecsall.date.datestart=datestart;
    divrecsall.date.dateend=dateend;
    divrecsall.date.modified=0;
end
maxdatemodified=0;
    

for reswdidl=1:length(wdidlist)
    reswdid=reswdidlist{reswdidl};
for type=[7,4,8] %release, exchange, apd(?)

divrecdata=webread(divrecdayurl,'format','json','min-dataMeasDate',datestr(datestart,23),'max-dataMeasDate',datestr(dateend,23),'min-dataValue',0.0001,'wdid',reswdid,'wcIdentifier',['*T:' num2str(type) '*'],'min-modified',datestr(divrecsall.date.modified,23),weboptions('Timeout',30));

for i=1:divrecdata.ResultCount
    wdid=divrecdata.ResultList(i).wdid;
    wcnum=divrecdata.ResultList(i).waterClassNum;
    wwdid=['W' wdid];
    wwcnum=['W' num2str(wcnum)];

    measdatestr=divrecdata.ResultList(i).dataMeasDate;
    measdatestr(11)=' ';
    measdatenum=datenum(measdatestr,31);    
    dateid=find(datedays==measdatenum);
    
    measinterval=divrecdata.ResultList(i).measInterval;
    measunits=divrecdata.ResultList(i).measUnits;
    if ~strcmp(measinterval,'Daily') | ~strcmp(measunits,'CFS')
        disp(['WARNING: skipping REST divrec ' wdid ' ' num2str(wcnum) ' with measinterval: ' measinterval ' with measunits: ' measunits]); 
    elseif isempty(dateid)
        disp(['WARNING: skipping REST divrec ' wdid ' ' num2str(wcnum) ' with measdatestr: ' measdatestr]);             
    else
        divrecsall.(wwdid).(wwcnum).wc=divrecdata.ResultList(i).wcIdentifier;  %will end up with last listed..
        divrecsall.(wwdid).(wwcnum).type=type;
        
        divrecsall.(wwdid).(wwcnum).datavalues(dateid)=divrecdata.ResultList(i).dataValue;
        divrecsall.(wwdid).(wwcnum).approvalstatus{dateid}=divrecdata.ResultList(i).approvalStatus; %check?

        modifieddatestr=divrecdata.ResultList(i).modified;
        modifieddatestr(11)=' ';
        modifieddatenum=datenum(modifieddatestr,31);    
        divrecsall.(wwdid).(wwcnum).modifieddatenum(dateid)=modifieddatenum;
        maxdatemodified=max(maxdatemodified,modifieddatenum);
    end
    
end
end
end
divrecsall.date.modified=maxdatemodified;


if pulldivrecrest==1
    disp('reading diversion data from HB using REST services')
        
    for w=1:length(waterclass(:,1))
    ws=['W' num2str(w)];
    divrecdayurl='https://dwr.state.co.us/Rest/GET/api/v2/structures/divrec/divrecday/';
    clear divrecdata
    divrecdata=webread(divrecdayurl,'format','json','min-dataMeasDate',datestr(rdates(1),23),'max-dataMeasDate',datestr(rdates(end),23),'wcIdentifier',waterclass{w,1});
    for i=1:divrecdata.ResultCount
        divrecs.(ws).datavalues(i)=divrecdata.ResultList(i).dataValue;
        divrecs.(ws).waterclassnums(i)=divrecdata.ResultList(i).waterClassNum; %use?
        measdatestr=divrecdata.ResultList(i).dataMeasDate;
        measdatestr(11)=' ';
        divrecs.(ws).dataMeasDate(i)=datenum(measdatestr,31);
        divrecs.(ws).measunits{i}=divrecdata.ResultList(i).measUnits; %check?
        divrecs.(ws).measinterval{i}=divrecdata.ResultList(i).measInterval; %check?
        divrecs.(ws).approvalstatus{i}=divrecdata.ResultList(i).approvalStatus; %check?
    end
    
    divrecs.(ws).release=zeros(rsteps,1);
    if ~strcmp(divrecs.(ws).measinterval{1},'Daily')
        error('div record measurement interval something other than Daily, need to investigate/build out')
    end
    for i=1:divrecdata.ResultCount
        if i==1 & divrecdata.ResultCount>1 & divrecs.(ws).datavalues(1)<divrecs.(ws).datavalues(2)   %attempt to push mimic start time
            hoursback=floor(divrecs.(ws).datavalues(1)*24/divrecs.(ws).datavalues(2));
            releasestartid2=find(rdates==divrecs.(ws).dataMeasDate(2));
            divrecs.(ws).release(releasestartid2-hoursback:releasestartid2-1,1)=divrecs.(ws).datavalues(2);
            divrecs.(ws).release(releasestartid2-hoursback-1,1)=divrecs.(ws).datavalues(1)*24-divrecs.(ws).datavalues(2)*hoursback;
        elseif i>1 & divrecdata.ResultCount>1 & (i==divrecdata.ResultCount | sum(divrecs.(ws).datavalues(i+1:end))==0) & divrecs.(ws).datavalues(i)<divrecs.(ws).datavalues(i-1)
            hoursforward=floor(divrecs.(ws).datavalues(i)*24/divrecs.(ws).datavalues(i-1));
            releasestartid=find(rdates==divrecs.(ws).dataMeasDate(i));
            divrecs.(ws).release(releasestartid:releasestartid+hoursforward-1,1)=divrecs.(ws).datavalues(i-1);
            divrecs.(ws).release(releasestartid+hoursforward,1)=divrecs.(ws).datavalues(i)*24-divrecs.(ws).datavalues(i-1)*hoursforward;
        else
        releasestartid=find(rdates==divrecs.(ws).dataMeasDate(i));
        divrecs.(ws).release(releasestartid:releasestartid+23,1)=divrecs.(ws).datavalues(i);
        end
    end
    end
    save([basedir 'StateTL_SRdata_divs.mat'],'divrecs');
elseif pulldivrecrest==2
    load([basedir 'StateTL_SRdata_divs.mat']);
end

%%%%%%%%%%%%%%%%%
% PROCESSING LOOP
%%%%%%%%%%%%%%%%%

d=2;ds='D2';
WDt=17;WDb=17;
Rt=1;SRt=1;Rb=8;SRb=2;
%Rt=1;SRt=1;Rb=6;SRb=4;
%srmethod='j349';
srmethod='muskingum'; %percent loss TL plus muskingum-cunge for travel time

%WATCH - currently hardwired - will need to automate in both baseflow and admin loops

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BASEFLOW LOOP ESTABLISHING CORRECTIONS TO ACTUAL FLOWS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%actually need to loop on change in gagediff until gagediff settles down
% first loop gagediff=0, but then after first add gagediff - but then that
% will change resulting gagediff added - but loop until settles down - then
% this is the gagediff that will be added in the admin loop..

for wd=WDt:WDb
    wds=['WD' num2str(wd)];
    for r=Rt:Rb
        rs=['R' num2str(r)]
        if r==Rt
            srt=SRt;
        else
            srt=1;
        end
        if r==Rb
            srb=SRb;
        else
            srb=SR.(ds).(wds).(rs).SR(end);
        end

gagediff=zeros(rsteps,1);
gagediffavg=10;

gain=SR.(ds).(wds).(rs).gaininitial(1);
% gaininirstial=SR.(ds).(wds).(rs).gaininitial(1);
% if gaininitial==-999
%     gain=SR.(ds).(wds).(['R' num2str(r-1)]).gain(end)*sum(SR.(ds).(wds).(rs).channellength)/sum(SR.(ds).(wds).(['R' num2str(r-1)]).channellength);
% else
%     gain=gaininitial;
% end
SR.(ds).(wds).(rs).gain=gain;

%while abs(gagediffavg)>gainchangelimit
     
for ii=1:5
    
for sr=srt:srb
%    if sr==1  %use this to replace top of reach with gage flow rather than calculated flow
    if and(sr==1,r==Rt)  %initialize at top given if gage or reservoir etc
        if SR.(ds).(wds).R0.type==0         %wd zone starts with gage; indicated by type in reach = 0
            Qus=SR.(ds).(wds).R0.Qnode(:,1);   %for subreach = 0 and type = gage put gage flows in wds
        else
            Qus=SR.(ds).(wds).(rs).Qnode(:,end,1);  %wd zone starts with reservoir etc - using gage at bottom of first reach
            for srtop=srt:srb                      %adding back in any intermediate diversions; but NOT CONSIDERING EVAPORATION!!! so currently need evapfactor=0 in these
                for i=1:SR.(ds).(wds).(rs).dsnodes(srtop)
                    type=SR.(ds).(wds).(rs).type(i,srtop);
                    Qnode=SR.(ds).(wds).(rs).Qnode(:,srtop,i);
                    Qus=Qus-type*Qnode;
                end
            end
        end
    elseif sr==1
        Qus=SR.(ds).(wds).(['R' num2str(r-1)]).Qdsnodes(:,end);
    end
    if gain==-999   %gain=-999 to not run J349 
        Qus=max(0,Qus);
        Qds=Qus;
        celerity=0;
        dispersion=0;
    else
        Qus=max(1,Qus);
        gainportion=gain*SR.(ds).(wds).(rs).reachportion(sr);
        if strcmp(srmethod,'j349')
            [Qds,celerity,dispersion]=runj349f(ds,wds,rs,sr,Qus,gainportion,rdays,rhours,rsteps,basedir,-999,-999);
        elseif strcmp(srmethod,'muskingum')
            [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,-999,-999);
        end
        Qds=max(0,Qds);
    end
        
    Qavg=(max(Qus,1)+max(Qds,1))/2;
    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
    evap=SR.(ds).(wds).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr); %EvapFactor = 0 to not have evap 
%    Qdsnodes=Qds-evap;
    Qdsnodes=Qds-evap+gagediff*SR.(ds).(wds).(rs).reachportion(sr);

    for i=1:SR.(ds).(wds).(rs).dsnodes(sr)
       type=SR.(ds).(wds).(rs).type(i,sr);
       Qnode=SR.(ds).(wds).(rs).Qnode(:,sr,i);
       Qdsnodes=Qdsnodes+type*Qnode;
    end
    Qdsnodes=max(0,Qdsnodes);
    
    SR.(ds).(wds).(rs).gagediffportion(:,sr)=gagediff*SR.(ds).(wds).(rs).reachportion(sr);
    SR.(ds).(wds).(rs).evap(:,sr)=evap;
    SR.(ds).(wds).(rs).Qus(:,sr)=Qus;
    SR.(ds).(wds).(rs).Qds(:,sr)=Qds;
    SR.(ds).(wds).(rs).Qdsnodes(:,sr)=Qdsnodes;    
    SR.(ds).(wds).(rs).celerity(:,sr)=celerity;    
    SR.(ds).(wds).(rs).dispersion(:,sr)=dispersion;    
    Qus=Qdsnodes;
    
end %sr

SR.(ds).(wds).(rs).gagediff=gagediff;  %this one that was applied

if or(srt>1,srb<SR.(ds).(wds).(rs).SR(end))
    gagediffavg=0;  %if partial reach so don't have gage to gage, then don't do gain iteration?
else
    Qdsgage=SR.(ds).(wds).(rs).Qnode(:,end,1);
    if Qdsgage(1,1)==-999
        gagediffavg=0;
        gagediff=0;
    else    
    gagediffnew=Qdsgage-Qdsnodes;
    gagediffchange=gagediffnew-gagediff;
%    gagediffavg=mean(gagediff(rdatesstartid:end,1));
    gagediffavg=gagediffchange(rdatesstartid-1,1);
%    gagediffavg=0; %taking out iteration loop for moment/testing
%    gain=gain+gagediffavg/2;
    gagediff=gagediffnew+gagediff;
    end
    SR.(ds).(wds).(rs).gain=[SR.(ds).(wds).(rs).gain gain];
    SR.(ds).(wds).(rs).gagediffseries(:,ii)=gagediff;
end

end %gainchange
%SR.(ds).(wds).(rs).gagediff=gagediff;  %this not the last one that was applied

    end %r
end %wd



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ADMIN LOOP WITH SIMULATED FLOWS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pred=0;  %if pred=0 subtracts water class from existing flows, if 1 adds to existing gage flows

for w=1:length(waterclass(:,1))
ws=['W' num2str(w)]
wdidfrom=waterclass{w,3};
wdidto=waterclass{w,4};
wdidfromid=find(strcmp(SR.(ds).WDID(:,1),wdidfrom));
wdidtoid=find(strcmp(SR.(ds).WDID(:,1),wdidto));
release=divrecs.(ws).release;
if waterclass{w,2}==3 %exchange
    release=release*-1;
end

WDtr=SR.(ds).WDID{wdidfromid,3};
WDbr=SR.(ds).WDID{wdidtoid,3};
Rtr=SR.(ds).WDID{wdidfromid,4};
Rbr=SR.(ds).WDID{wdidtoid,4};
if Rtr==0
    Rtr=1;SRtr=1;
else
    SRtr=SR.(ds).WDID{wdidfromid,5}+1; %watch!! wdid listed is at bottom of reach - so for from put at top of next reach, top reach 0 put into srid 1
end
SRbr=SR.(ds).WDID{wdidtoid,5};
SRtrd=SR.(ds).WDID{wdidfromid,6};
SRbrd=SR.(ds).WDID{wdidtoid,6};

srids=SR.(ds).(wds).(['R' num2str(Rb)]).subreachid(end)  %just to set size of release matrices
SR.(ds).(wds).(ws).Qusrelease(1440,srids)=0;     %just used for plotting, maybe better way..
SR.(ds).(wds).(ws).Qdsrelease(1440,srids)=0;
SR.(ds).(wds).(ws).Qdsnodesrelease(1440,srids)=0;


% release=zeros(rsteps,1);
% %release(rdatesstartid:rdatesstartid+1*24/rhours,1)=100;
% releasestartid=find(rdates==datenum(2017,8,11,13,0,0));
% releaseendid=find(rdates==datenum(2017,8,18,3,0,0));
% release(releasestartid:releaseendid,1)=100.833; %200AF/day release from about 12pm to 3am

for wd=WDtr:WDbr
    wds=['WD' num2str(wd)];
    for r=Rtr:Rbr
        rs=['R' num2str(r)]
        if r==Rtr
            srt=SRtr;
        else
            srt=1;
        end
        if r==Rbr
            srb=SRbr;
        else
            srb=SR.(ds).(wds).(rs).SR(end);
        end

for sr=srt:srb
    if and(sr==SRtr,r==Rtr)
        if pred==1 %predictive case
            Qus=SR.(ds).(wds).(rs).Qus(:,sr)+release;
        else  %administrative case
            Qus=SR.(ds).(wds).(rs).Qus(:,sr)-release;
        end
    else
    end
    
    gain=SR.(ds).(wds).(rs).gain(end);
%     if gain<0;  %if losses, distribute to release also.. %this needs to be discussed further!!
%         
%         
%     end
    if pred==1
        celerity=-999;dispersion=-999;
    else
        celerity=SR.(ds).(wds).(rs).celerity(:,sr);
        dispersion=SR.(ds).(wds).(rs).dispersion(:,sr);
    end

    if gain==-999   %gain=-999 to not run J349 
        Qus=max(0,Qus);
        Qds=Qus;
    else
        Qus=max(1,Qus);
        gainportion=gain*SR.(ds).(wds).(rs).reachportion(sr);
        if strcmp(srmethod,'j349')
            [Qds,celerity,dispersion]=runj349f(ds,wds,rs,sr,Qus,gainportion,rdays,rhours,rsteps,basedir,-999,-999);
        elseif strcmp(srmethod,'muskingum')
            [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,-999,-999);
        end
        Qds=max(0,Qds);
    end
    Qavg=(max(Qus,1)+max(Qds,1))/2;
    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
    if waterclass{w,2}==3 %exchange
        evap=0;
    else
        evap=SR.(ds).(wds).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
    end
    Qdsnodes=Qds-evap+SR.(ds).(wds).(rs).gagediff*SR.(ds).(wds).(rs).reachportion(sr);

    for i=1:SR.(ds).(wds).(rs).dsnodes(sr)
       type=SR.(ds).(wds).(rs).type(i,sr);
       Qnode=SR.(ds).(wds).(rs).Qnode(:,sr,i);
       Qdsnodes=Qdsnodes+type*Qnode;
    end
    Qdsnodes=max(0,Qdsnodes);
    
    lsr=SR.(ds).(wds).(rs).subreachid(sr);
    SR.(ds).(wds).(rs).(ws).Qusnative(:,sr)=Qus;
    SR.(ds).(wds).(rs).(ws).Qdsnative(:,sr)=Qds;
    SR.(ds).(wds).(rs).(ws).Qdsnodesnative(:,sr)=Qdsnodes;    
    if pred==1
        SR.(ds).(wds).(rs).(ws).Qusrelease(:,sr)=Qus-SR.(ds).(wds).(rs).Qus(:,sr);
        SR.(ds).(wds).(rs).(ws).Qdsrelease(:,sr)=Qds-SR.(ds).(wds).(rs).Qds(:,sr);
        SR.(ds).(wds).(rs).(ws).Qdsnodesrelease(:,sr)=Qdsnodes-SR.(ds).(wds).(rs).Qdsnodes(:,sr);

        SR.(ds).(wds).(ws).Qusrelease(:,lsr)=Qus-SR.(ds).(wds).(rs).Qus(:,sr);
        SR.(ds).(wds).(ws).Qdsrelease(:,lsr)=Qds-SR.(ds).(wds).(rs).Qds(:,sr);
        SR.(ds).(wds).(ws).Qdsnodesrelease(:,lsr)=Qdsnodes-SR.(ds).(wds).(rs).Qdsnodes(:,sr);
    else
        SR.(ds).(wds).(rs).(ws).Qusrelease(:,sr)=SR.(ds).(wds).(rs).Qus(:,sr)-Qus;
        SR.(ds).(wds).(rs).(ws).Qdsrelease(:,sr)=SR.(ds).(wds).(rs).Qds(:,sr)-Qds;
        SR.(ds).(wds).(rs).(ws).Qdsnodesrelease(:,sr)=SR.(ds).(wds).(rs).Qdsnodes(:,sr)-Qdsnodes;
        
        SR.(ds).(wds).(ws).Qusrelease(:,lsr)=SR.(ds).(wds).(rs).Qus(:,sr)-Qus;
        SR.(ds).(wds).(ws).Qdsrelease(:,lsr)=SR.(ds).(wds).(rs).Qds(:,sr)-Qds;
        SR.(ds).(wds).(ws).Qdsnodesrelease(:,lsr)=SR.(ds).(wds).(rs).Qdsnodes(:,sr)-Qdsnodes;
        
    end
    
    Qus=Qdsnodes;
    
end %sr

    end %r
end %wd

end %j - waterclass


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% test plotting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

figure('Renderer','zbuffer','Position',[349,93,1006.4,691.2]);
% plot([0 35],[0 660]);
%set(gca,'Ylim',[-200 1500],'Xlim',[0 100])
%    set(gca,'Ylim',[-200 1500],'Xlim',[0 130])
    set(gca,'Ylim',[0 figtop],'Xlim',[0 130])

 axis manual;
 set(gca,'NextPlot','replaceChildren');
 
releasestartid=25;
ts1=1100;

for wd=WDt:WDb
    wds=['WD' num2str(wd)];
%    for ts=rdatesstartid:rdatesstartid+100
%    for ts=releasestartid-24:(1440-24)
    for ts=ts1:1440
        clear plotline*
        plotline=[];
        plotlinenative=[];
        plotlinerelease=[];
        plotlinex=[];
        plotx=0;
        k=0;
    for r=Rt:Rb
        rs=['R' num2str(r)];
        if r==Rt
            srt=SRt;
        else
            srt=1;
        end
        if r==Rb
            srb=SRb;
        else
            srb=SR.(ds).(wds).(rs).SR(end);
        end

for sr=srt:srb
%     plotx=[plotx (r-1)*20+(sr-1)*3 (r-1)*20+(sr-1)*3+1 (r-1)*20+(sr-1)*3+1];    
     plotlinex=[plotlinex plotx plotx+SR.(ds).(wds).(rs).channellength(sr) plotx+SR.(ds).(wds).(rs).channellength(sr)];
     plotx=plotx+SR.(ds).(wds).(rs).channellength(sr);
     
     plotline(k+1:k+3,1)=[SR.(ds).(wds).(rs).Qus(ts,sr);SR.(ds).(wds).(rs).Qds(ts,sr);SR.(ds).(wds).(rs).Qdsnodes(ts,sr)];
     lsr=SR.(ds).(wds).(rs).subreachid(sr);
     kwr=0;kwe=1;
     for w=1:length(waterclass(:,1))
         ws=['W' num2str(w)];
         if waterclass{w,2}==3 %for exchanges add onto native line
            kwe=kwe+1;
            plotline(k+1:k+3,kwe)=[SR.(ds).(wds).(ws).Qusrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsnodesrelease(ts,lsr)];
         else
            kwr=kwr+1;
            plotlinerelease(k+1:k+3,kwr)=[SR.(ds).(wds).(ws).Qusrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsnodesrelease(ts,lsr)];
         end
          
%         plotlinerelease(k+1:k+3,w)=[SR.(ds).(wds).(ws).Qusrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsnodesrelease(ts,lsr)];
         
%         plotlinerelease.(ws)=[plotlinerelease.(ws) SR.(ds).(wds).(ws).Qusrelease(ts,lsr) SR.(ds).(wds).(ws).Qdsrelease(ts,lsr) SR.(ds).(wds).(ws).Qdsnodesrelease(ts,lsr)];
        
%          if (wd>=WDtr & r>=Rtr & sr>=SRtr) & (wd<=WDbr & r<=Rbr & sr<=SRbr)
% %         plotlinenative.(ws)=[plotlinenative SR.(ds).(wds).(rs).(ws).Qusnative(ts,sr) SR.(ds).(wds).(rs).(ws).Qdsnative(ts,sr) SR.(ds).(wds).(rs).(ws).Qdsnodesnative(ts,sr)];
%          plotlinerelease(k+1:k+3,w)=[SR.(ds).(wds).(rs).(ws).Qusrelease(ts,sr);SR.(ds).(wds).(rs).(ws).Qdsrelease(ts,sr);SR.(ds).(wds).(rs).(ws).Qdsnodesrelease(ts,sr)];
%          else
%             plotlinerelease(k+1:k+3,w)=[0;0;0];
%          end
     end
     k=k+3;

%     plotline=[plotline SR.(ds).(wds).(rs).Qdsnodes(ts,sr)];
%     plotlinenative=[plotlinenative SR.(ds).(wds).(rs).(ws).Qdsnodesnative(ts,sr)];
    
end
    end
%     plot(plotx,plotline); hold on
%     plot(plotx,plotlinenative,'r'); 
%     plot(plotx,plotlinerelease,'m'); 
    area(plotlinex,plotline); hold on
    area(plotlinex,plotlinerelease);

    text(50,1400,datestr(rdates(ts),0))
%    set(gca,'Ylim',[-200 1500],'Xlim',[0 130])
    set(gca,'Ylim',[0 figtop],'Xlim',[0 130])
ylabel('CFS','VerticalAlignment','Top')
text(00.0,0,'Pueblo Res','Rotation',90,'HorizontalAlignment','Right')
text(09.6,0,'FountainCk','Rotation',90,'HorizontalAlignment','Right')
text(15.9,0,'Excelsior ','Rotation',90,'HorizontalAlignment','Right')
text(29.5,0,'Colorado  ','Rotation',90,'HorizontalAlignment','Right')
text(34.6,0,'RFHighline','Rotation',90,'HorizontalAlignment','Right')
text(41.1,0,'Oxford    ','Rotation',90,'HorizontalAlignment','Right')
text(53.6,0,'Otero     ','Rotation',90,'HorizontalAlignment','Right')
text(59.4,0,'Catlin    ','Rotation',90,'HorizontalAlignment','Right')
text(67.9,0,'Holbrook  ','Rotation',90,'HorizontalAlignment','Right')
text(69.4,0,'Rocky Ford','Rotation',90,'HorizontalAlignment','Right')
text(90.7,0,'Fort Lyon ','Rotation',90,'HorizontalAlignment','Right')
text(110.2,0,'Las Animas','Rotation',90,'HorizontalAlignment','Right')
text(127.5,0,'JohnMartin','Rotation',90,'HorizontalAlignment','Right')
    hold off
%    F(ts-(releasestartid-25)) = getframe;
    F(ts-(ts1-1)) = getframe;
    end
end

        
% movie(F,1,8)

disp(datestr(now))


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function using TL=percent loss and travel=Muskinghum-Cunge routing using celerity and dispersion coefficients..
%
% from TLAP:
% dispersion = K(ft2/s) = Qo / (2 So Wo ) - Q (ft3/s), So - channel slope, Wo - avg stream width (ft) at Qo
% celerity =  c(ft/s) = 1/Wo * dQo / dy   - inverse of slope of stage-discharge relation at Qo
%
% from Chang: http://chang.sdsu.edu/textbookhydrologyp294.html
% X = 1/2 (1 - qo / So c dx) - qo=refernce discharge per unit width
%
% therefore:
% K = qo / 2 So
% X = 1/2 - K / (c dx)
%
% from Chang: http://chang.sdsu.edu/textbookhydrologyp292.html 
% Q (n+1/j+1) = C0 Q (n+1/j) + C1 Q (n/j) + C2 Q(n/j+1); - j in x, n in time
% C0 = (c (dt/dx) - 2X )       / (2 * (1-X) + c (dt/dx))
% C1 = (c (dt/dx) + 2X )       / (2 * (1-X) + c (dt/dx))
% C2 = (2 * (1-X) - c (dt/dx)) / (2 * (1-X) + c (dt/dx))

function [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,celerity,dispersion)
global SR

Qusavg=mean(Qus);  %watch - this would be different than TLAP; but think basing on that subreach flow might be more correct than on entire reach avg

channellength=SR.(ds).(wds).(rs).channellength(sr);
if celerity==-999
    celeritya=SR.(ds).(wds).(rs).celeritya(sr);
    celerityb=SR.(ds).(wds).(rs).celerityb(sr);
    celerity=celeritya*Qusavg^celerityb;
end
if dispersion==-999
    dispersiona=SR.(ds).(wds).(rs).dispersiona(sr);
    dispersionb=SR.(ds).(wds).(rs).dispersionb(sr);
    dispersion=dispersiona*Qusavg^dispersionb;
end

losspercent=SR.(ds).(wds).(rs).losspercent(sr);
dspercent=(1-losspercent/100);

%Muskinghum-Cunge parameters
dt=rhours * 60 * 60; %sec
dx=channellength * 5280; %ft
X = 1/2 - dispersion / (celerity * dx);
Cbot = 2 * (1-X) + celerity *(dt/dx);
C0 = (celerity * (dt/dx) - 2 * X) / Cbot;
C1 = (celerity * (dt/dx) + 2 * X) / Cbot;
C2 = ( 2 * (1-X) - celerity * (dt/dx)) / Cbot;

Qds=ones(rsteps,1);
Qds(1,1) = Qus(1,1) * dspercent; %spinup??

for n=1:rsteps-1  %Muskinghum-Cunge Routing
    Qds (n+1,1) = (C0 * Qus (n+1,1) * dspercent) + (C1 * Qus (n,1) * dspercent) + C2 * Qds(n,1);
%    Qds (n+1,1) = Qus (n+1,1) * dspercent;
end

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%function for subreach to take upstream hydrograph and subreach specific data, build input card, 
%run TLAP/j349 fortran, read output card, and return resulting downstream hydrograph

function [Qds,celerity,dispersion]=runj349f(ds,wds,rs,sr,Qus,gain,rdays,rhours,rsteps,basedir,celerity,dispersion)
global SR

Qusavg=mean(Qus);  %watch - this would be different than TLAP; but think basing on that subreach flow might be more correct
%Qusavg=(667+ARKAVOCO)/2; %current in TLAP- based on average flow for entire reach

channellength=SR.(ds).(wds).(rs).channellength(sr);
alluviumlength=SR.(ds).(wds).(rs).alluviumlength(sr);
transmissivity=SR.(ds).(wds).(rs).transmissivity(sr);
storagecoefficient=SR.(ds).(wds).(rs).storagecoefficient(sr);
aquiferwidth=SR.(ds).(wds).(rs).aquiferwidth(sr);
closure=SR.(ds).(wds).(rs).closure(sr);
if celerity==-999
    dispersiona=SR.(ds).(wds).(rs).dispersiona(sr);
    dispersionb=SR.(ds).(wds).(rs).dispersionb(sr);
    celeritya=SR.(ds).(wds).(rs).celeritya(sr);
    celerityb=SR.(ds).(wds).(rs).celerityb(sr);
    dispersion=dispersiona*Qusavg^dispersionb;
    celerity=celeritya*Qusavg^celerityb;
end
stagedischarge=SR.(ds).(wds).stagedischarge;

inputcardfilename=['StateTL_' ds wds rs 'SR' num2str(sr) '_us.dat'];
outputcardfilename=['StateTL_' ds wds rs 'SR' num2str(sr) '_ds.dat'];

fid=fopen([basedir inputcardfilename],'w');

cardstr='CDWR TIMING AND TRANSIT LOSS MODEL                                              CARD 1 GEN INFO';
    fprintf(fid,'%95s\r\n',cardstr);
cardstr='SUBREACH  UPSTREAM                                                              CARD 2 RUN INFO';
    fprintf(fid,'%95s\r\n',cardstr);
cardstr='         1         2                                                            CARD 3 INPUT SOURCE AND RUN OBJECTIVE';
    fprintf(fid,'%117s\r\n',cardstr);
cardstr='         1         0                                                            CARD 4 DESCRIB OF RUN>>> COL C=DAYS (MAX=100)';
cardstr2=num2str(rdays,'%10.0f');cardstr3=num2str(rhours,'%10.1f');
cardstr(31-length(cardstr2):30)=cardstr2;cardstr(41-length(cardstr3):40)=cardstr3;
    fprintf(fid,'%125s\r\n',cardstr);
cardstr='         2        12      2001         6        17      2001                    CARD 5 START/END DATE ARIBITRARY--NOT USED IN CALCS';
    fprintf(fid,'%131s\r\n',cardstr);
cardstr='               False       0.0                                                  CARD 6 RATING INFO AND>>>COL C= MIN FLOW';
cardstr2=num2str(length(stagedischarge),'%10.0f');
cardstr(11-length(cardstr2):10)=cardstr2;
    fprintf(fid,'%120s\r\n',cardstr);


%stage discharge
%this is currently built so that has to have minimum of 4 points and number
%of points must be divisible by 4

cardstr='                                                                                CARD 7  S VS Q (S/Q/S/Q/S ETC)';
cardstr1=num2str(stagedischarge(1,1),'%10.2f');cardstr2=num2str(stagedischarge(2,1),'%10.2f');cardstr3=num2str(stagedischarge(3,1),'%10.2f');cardstr4=num2str(stagedischarge(4,1),'%10.2f');
cardstr1a=num2str(stagedischarge(1,2),'%10.1f');cardstr2a=num2str(stagedischarge(2,2),'%10.1f');cardstr3a=num2str(stagedischarge(3,2),'%10.1f');cardstr4a=num2str(stagedischarge(4,2),'%10.1f');
cardstr(11-length(cardstr1):10)=cardstr1;cardstr(21-length(cardstr1a):20)=cardstr1a;cardstr(31-length(cardstr2):30)=cardstr2;cardstr(41-length(cardstr2a):40)=cardstr2a;
cardstr(51-length(cardstr3):50)=cardstr3;cardstr(61-length(cardstr3a):60)=cardstr3a;cardstr(71-length(cardstr4):70)=cardstr4;cardstr(81-length(cardstr4a):80)=cardstr4a;
    fprintf(fid,'%110s\r\n',cardstr);
% fidstr='%10.2f %9.1f %9.2f %9.1f %9.2f %9.1f %9.2f %9.1f %29s\r\n';
% fprintf(fid,fidstr,stagedischarge(1,1),stagedischarge(1,2),stagedischarge(2,1),stagedischarge(2,2),stagedischarge(3,1),stagedischarge(3,2),stagedischarge(4,1),stagedischarge(4,2),'CARD 7 S VS Q (S/Q/S/Q/S ETC)');
for j=1:ceil(length(stagedischarge)/4)-1
    fidstr='%10.2f %9.1f %9.2f %9.1f %9.2f %9.1f %9.2f %9.1f\r\n';
    fprintf(fid,fidstr,stagedischarge(j*4+1,1),stagedischarge(j*4+1,2),stagedischarge(j*4+2,1),stagedischarge(j*4+2,2),stagedischarge(j*4+3,1),stagedischarge(j*4+3,2),stagedischarge(j*4+4,1),stagedischarge(j*4+4,2));
end

%upstream hydrograph
%this is currently built so that number of points must be divisible by 6
for j=1:ceil(rsteps/6)
    fidstr='%10.1f %9.1f %9.1f %9.1f %9.1f %9.1f\r\n';
    fprintf(fid,fidstr,Qus((j-1)*6+1,1),Qus((j-1)*6+2,1),Qus((j-1)*6+3,1),Qus((j-1)*6+4,1),Qus((j-1)*6+5,1),Qus((j-1)*6+6,1));
end

cardstr='CDWR TIMING AND TRANSIT LOSS MODEL                                              CARD 10 GEN INFO';
    fprintf(fid,'%96s\r\n',cardstr);
cardstr='SUBREACH  DOWNSTREAM                                                            CARD 11 DS NODE';
    fprintf(fid,'%95s\r\n',cardstr);
cardstr='         2     False     False      True     False     False     False      TrueCARD 12 RULES FOR SUBREACH NOTE COL G=TRUE FOR OBS HYD FOR COMPARE';
    fprintf(fid,'%146s\r\n',cardstr);
cardstr='                                                                                CARD 13 TT, CHANNEL L, ALLUVIUM L';
cardstr2=num2str(channellength/2,'%10.2f');cardstr3=num2str(channellength,'%10.2f');cardstr4=num2str(alluviumlength,'%10.2f');
cardstr(11-length(cardstr2):10)=cardstr2;cardstr(21-length(cardstr3):20)=cardstr3;cardstr(31-length(cardstr4):30)=cardstr4;
    fprintf(fid,'%113s\r\n',cardstr);
cardstr='                             0                                                  CARD 14 AQUIFER T, S  (LAST FIELD CONSTANT 0)';
cardstr2=num2str(transmissivity,'%10.1f');cardstr3=num2str(storagecoefficient,'%10.2f');
cardstr(11-length(cardstr2):10)=cardstr2;cardstr(21-length(cardstr3):20)=cardstr3;
    fprintf(fid,'%125s\r\n',cardstr);
cardstr='                                                                                CARD 15 WAVE DISP, WAVE CEL, Closure Criteria,(BLANK), AQUIFER WIDTH';
cardstr2=num2str(dispersion,'%10.4f');cardstr3=num2str(celerity,'%10.7f');cardstr4=num2str(closure,'%10.0f');cardstr5=num2str(aquiferwidth,'%10.0f');
cardstr(11-length(cardstr2):10)=cardstr2;cardstr(21-length(cardstr3):20)=cardstr3;cardstr(31-length(cardstr4):30)=cardstr4;cardstr(51-length(cardstr5):50)=cardstr5;
    fprintf(fid,'%148s\r\n',cardstr);
cardstr='               False                                                            CARD 16 RATING INFO AND>>>COL C= MIN FLOW';
cardstr2=num2str(length(stagedischarge),'%10.0f');cardstr3=num2str(gain,'%10.2f');
cardstr(11-length(cardstr2):10)=cardstr2;cardstr(31-length(cardstr3):30)=cardstr3;
    fprintf(fid,'%121s\r\n',cardstr);

%stage discharge
%this is currently built so that has to have minimum of 4 points and number
%of points must be divisible by 4
cardstr='                                                                                CARD 17  S VS Q (S/Q/S/Q/S ETC)';
cardstr1=num2str(stagedischarge(1,1),'%10.2f');cardstr2=num2str(stagedischarge(2,1),'%10.2f');cardstr3=num2str(stagedischarge(3,1),'%10.2f');cardstr4=num2str(stagedischarge(4,1),'%10.2f');
cardstr1a=num2str(stagedischarge(1,2),'%10.1f');cardstr2a=num2str(stagedischarge(2,2),'%10.1f');cardstr3a=num2str(stagedischarge(3,2),'%10.1f');cardstr4a=num2str(stagedischarge(4,2),'%10.1f');
cardstr(11-length(cardstr1):10)=cardstr1;cardstr(21-length(cardstr1a):20)=cardstr1a;cardstr(31-length(cardstr2):30)=cardstr2;cardstr(41-length(cardstr2a):40)=cardstr2a;
cardstr(51-length(cardstr3):50)=cardstr3;cardstr(61-length(cardstr3a):60)=cardstr3a;cardstr(71-length(cardstr4):70)=cardstr4;cardstr(81-length(cardstr4a):80)=cardstr4a;
    fprintf(fid,'%111s\r\n',cardstr);
% fidstr='%10.2f %9.1f %9.2f %9.1f %9.2f %9.1f %9.2f %9.1f %29s\r\n';
% fprintf(fid,fidstr,stagedischarge(1,1),stagedischarge(1,2),stagedischarge(2,1),stagedischarge(2,2),stagedischarge(3,1),stagedischarge(3,2),stagedischarge(4,1),stagedischarge(4,2),'CARD 7 S VS Q (S/Q/S/Q/S ETC)');
for j=1:ceil(length(stagedischarge)/4)-1
    fidstr='%10.2f %9.1f %9.2f %9.1f %9.2f %9.1f %9.2f %9.1f\r\n';
    fprintf(fid,fidstr,stagedischarge(j*4+1,1),stagedischarge(j*4+1,2),stagedischarge(j*4+2,1),stagedischarge(j*4+2,2),stagedischarge(j*4+3,1),stagedischarge(j*4+3,2),stagedischarge(j*4+4,1),stagedischarge(j*4+4,2));
end

fclose(fid);

fid=fopen([basedir 'filenames'],'w');
fprintf(fid,'%s\r\n',inputcardfilename);
fprintf(fid,'%s\r\n',outputcardfilename);
fclose(fid);

[s, w] = dos([basedir 'j349.exe']);

fid=fopen([basedir outputcardfilename],'r');

k=0;  %just to get header length
while 1
	line = fgetl(fid);
	if strcmp(line,'                                                   SUMMARY OF DATA AND RESULTS'), break, end  %check to see if line starting 1900 or 2000s
    k=k+1;
end
for j=1:5
    line = fgetl(fid);
end
Qds=zeros(rsteps,1);
for j=1:rsteps
    line = fgetl(fid);
%    datechunk(j,:)=line(2:12);
    Qds(j,1)=str2num(line(42:54));
end
fclose(fid);

end








