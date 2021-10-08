
% TLAPm
% matlab deployment of TLAP tool

% next steps
% potentially reduce structure approach to line up of all R/SR within Z
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
% full river zone rather than by river reach .. but would need to run admin
% once then add up all colors and see if exceed full full (pred) flows and
% if so then get into while loop where each color is cut back at no flow
% locations and run while until no exceedance of full flows..


cd C:\Projects\Ark\ColorsofWater\matlab
clear all
disp(datestr(now))
basedir=cd;basedir=[basedir '\'];
% j349dir=[basedir 'j349dir\'];
% j349dir=basedir;

readinfofile=2;  %1 reads from excel and saves mat file; 2 reads mat file
readgageinfo=1;  %if using real gage data, 1 reads from REST, 2 reads from file - watch out currently saves into SR file
infofilename='TLAPm_inputdata.xlsx';
pulldivrecrest=1;  %1 if pulling release value from HB REST; 2 reads from mat file

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
  
SR.D2.Z=[2];           %Z2=pueblo gage to JMR  %may want to automate this from inputdata read
SR.D2.Z2.R=[1:8];
SR.D2.Z2.R0.SR=[1];
SR.D2.Z2.R1.SR=[1:2];
SR.D2.Z2.R2.SR=[1:8];
SR.D2.Z2.R3.SR=[1:7];
SR.D2.Z2.R4.SR=[1:3];
SR.D2.Z2.R5.SR=[1:4];
SR.D2.Z2.R6.SR=[1:4];
SR.D2.Z2.R7.SR=[1:4];
SR.D2.Z2.R8.SR=[1:2];


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
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'ZONE'); infocol.zone=i;
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
        v.zo=inforaw{i,infocol.zone};if ischar(v.zo); v.zo=str2num(v.zo); end
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
        c.zo=num2str(inforaw{i,infocol.zone});
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
        
%         SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).livingstonsubreach(v.sr)=v.ls; %delete when expanding model
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).subreachid(v.sr)=v.si;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).channellength(v.sr)=v.cl;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).alluviumlength(v.sr)=v.al;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).transmissivity(v.sr)=v.tr;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).storagecoefficient(v.sr)=v.sc;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).aquiferwidth(v.sr)=v.aw;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).dispersiona(v.sr)=v.da;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).dispersionb(v.sr)=v.db;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).celeritya(v.sr)=v.ca;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).celerityb(v.sr)=v.cb;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).closure(v.sr)=v.cls;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).reachportion(v.sr)=v.rp;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).gaininitial(v.sr)=v.gi;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).widtha(v.sr)=v.wa;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).widthb(v.sr)=v.wb;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).evapfactor(v.sr)=v.ef;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).dsnodes(v.sr)=v.ds;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).type(1,v.sr)=v.t1;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).low(1,v.sr)=v.l1;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).avg(1,v.sr)=v.a1;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).high(1,v.sr)=v.h1;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).station{1,v.sr}=c.s1;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).parameter{1,v.sr}=c.p1;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).name{1,v.sr}=c.n1;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).type(2,v.sr)=v.t2;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).low(2,v.sr)=v.l2;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).avg(2,v.sr)=v.a2;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).high(2,v.sr)=v.h2;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).station{2,v.sr}=c.s2;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).parameter{2,v.sr}=c.p2;
        SR.(['D' c.di]).(['Z' c.zo]).(['R' c.re]).name{2,v.sr}=c.n2;
        
        if ~strcmp(c.w1,'NaN')
            wdidk=wdidk+1;
            SR.(['D' c.di]).WDID{wdidk,1}=c.w1;
            SR.(['D' c.di]).WDID{wdidk,2}=v.di;
            SR.(['D' c.di]).WDID{wdidk,3}=v.zo;
            SR.(['D' c.di]).WDID{wdidk,4}=v.re;
            SR.(['D' c.di]).WDID{wdidk,5}=v.sr;
            SR.(['D' c.di]).WDID{wdidk,6}=1;
        end
        if ~strcmp(c.w2,'NaN')
            wdidk=wdidk+1;
            SR.(['D' c.di]).WDID{wdidk,1}=c.w2;
            SR.(['D' c.di]).WDID{wdidk,2}=v.di;
            SR.(['D' c.di]).WDID{wdidk,3}=v.zo;
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
SR.(['D' c.di]).(['Z' c.zo]).evap=infonum(:,1);

%%%%%%%%%%%%%%%%%%
% stage discharge data
% this will probably have to be refined as expand reaches

[infonum,infotxt,inforaw]=xlsread([basedir infofilename],'stagedischarge');
[infonumrow infonumcol]=size(infonum);
[inforawrow inforawcol]=size(inforaw);
SR.(['D' c.di]).(['Z' c.zo]).stagedischarge=infonum;

 clear c v info*

save([basedir 'TLAPm_SRdata.mat'],'SR');

else
    load([basedir 'TLAPm_SRdata.mat']);
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

flowtestloc=[2,2,7,4,1];

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
        d=flowtestloc(1);z=flowtestloc(2);r=flowtestloc(3);sr=flowtestloc(4);n=flowtestloc(5);
        station=SR.(['D' num2str(d)]).(['Z' num2str(z)]).(['R' num2str(r)]).station{n,sr};
        parameter=SR.(['D' num2str(d)]).(['Z' num2str(z)]).(['R' num2str(r)]).parameter{n,sr};
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
            test(1)=SR.(['D' num2str(d)]).(['Z' num2str(z)]).(['R' num2str(r)]).low(n,sr);
            test(2)=SR.(['D' num2str(d)]).(['Z' num2str(z)]).(['R' num2str(r)]).avg(n,sr);
            test(3)=SR.(['D' num2str(d)]).(['Z' num2str(z)]).(['R' num2str(r)]).high(n,sr);
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
for kz=1:length(SR.(ds).Z)
    z=SR.(ds).Z(kz);zs=['Z' num2str(z)];
    for r=0:SR.(ds).(zs).R(end)  %including top gage if put in reach 0
        rs=['R' num2str(r)];
        if flowcriteria>=4
            for sr=1:SR.(ds).(zs).(rs).SR(end)
                for n=1:SR.(ds).(zs).(rs).dsnodes(sr)
                    if strcmp(SR.(ds).(zs).(rs).station{n,sr},'NaN') | strcmp(SR.(ds).(zs).(rs).station{n,sr},'none')  %if no telemetry station then uses low/avg/high number
                        SR.(ds).(zs).(rs).Qnode(:,sr,n)=SR.(ds).(zs).(rs).(flow)(n,sr)*ones(rsteps,1);
                    else
                        station=SR.(ds).(zs).(rs).station{n,sr};
                        parameter=SR.(ds).(zs).(rs).parameter{n,sr};
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
                        SR.(ds).(zs).(rs).Qnode(:,sr,n)=Qnode;                       
                    end
               end
            end
        else
            for n=1:max(SR.(['D' num2str(d)]).(['Z' num2str(z)]).(['R' num2str(r)]).dsnodes)
                % num2str(r)]).Qnode(:,:,n)=SR.(['D' num2str(d)]).(['Z' num2str(z)]).(['R' num2str(r)]).(flow)(n,:).*ones(rsteps,length(SR.(['D' num2str(d)]).(['Z' num2str(z)]).(['R' num2str(r)]).SR));
                SR.(ds).(zs).(rs).Qnode(:,:,n)=repmat(SR.(ds).(zs).(rs).(flow)(n,:),rsteps,1).*ones(rsteps,length(SR.(ds).(zs).(rs).SR)); %repmat required for r2014a
            end
        end
    end
end

save([basedir 'TLAPm_SRdata_withgage.mat'],'SR');

else
    load([basedir 'TLAPm_SRdata_withgage.mat']);
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
    
    %for z2 - this would mess up things on fountain creek
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
    save([basedir 'TLAPm_SRdata_divs.mat'],'divrecs');
elseif pulldivrecrest==2
    load([basedir 'TLAPm_SRdata_divs.mat']);
end

%%%%%%%%%%%%%%%%%
% PROCESSING LOOP
%%%%%%%%%%%%%%%%%

d=2;ds='D2';
Zt=2;Zb=2;
Rt=1;SRt=1;Rb=8;SRb=2;
%Rt=1;SRt=1;Rb=6;SRb=4;

%WATCH - currently hardwired - will need to automate in both baseflow and admin loops

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BASEFLOW LOOP ESTABLISHING CORRECTIONS TO ACTUAL FLOWS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%actually need to loop on change in gagediff until gagediff settles down
% first loop gagediff=0, but then after first add gagediff - but then that
% will change resulting gagediff added - but loop until settles down - then
% this is the gagediff that will be added in the admin loop..

for z=Zt:Zb
    zs=['Z' num2str(z)];
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
            srb=SR.(ds).(zs).(rs).SR(end);
        end

gagediff=zeros(rsteps,1);
gagediffavg=10;

gain=SR.(ds).(zs).(rs).gaininitial(1);
% gaininitial=SR.(ds).(zs).(rs).gaininitial(1);
% if gaininitial==-999
%     gain=SR.(ds).(zs).(['R' num2str(r-1)]).gain(end)*sum(SR.(ds).(zs).(rs).channellength)/sum(SR.(ds).(zs).(['R' num2str(r-1)]).channellength);
% else
%     gain=gaininitial;
% end
SR.(ds).(zs).(rs).gain=gain;

%while abs(gagediffavg)>gainchangelimit
     
for ii=1:5
    
for sr=srt:srb
%    if sr==1  %use this to replace top of reach with gage flow rather than calculated flow
    if and(sr==1,r==Rt)  %initialize at top given if gage or reservoir etc
        if SR.(ds).(zs).R0.type==0         %zone starts with gage; indicated by type in reach = 0
            Qus=SR.(ds).(zs).R0.Qnode(:,1);   %for subreach = 0 and type = gage put gage flows in zs
        else
            Qus=SR.(ds).(zs).(rs).Qnode(:,end,1);  %zone starts with reservoir etc - using gage at bottom of first reach
            for srtop=srt:srb                      %adding back in any intermediate diversions; but NOT CONSIDERING EVAPORATION!!! so currently need evapfactor=0 in these
                for i=1:SR.(ds).(zs).(rs).dsnodes(srtop)
                    type=SR.(ds).(zs).(rs).type(i,srtop);
                    Qnode=SR.(ds).(zs).(rs).Qnode(:,srtop,i);
                    Qus=Qus-type*Qnode;
                end
            end
        end
    elseif sr==1
        Qus=SR.(ds).(zs).(['R' num2str(r-1)]).Qdsnodes(:,end);
    end
    if gain==-999   %gain=-999 to not run J349 
        Qus=max(0,Qus);
        Qds=Qus;
        celerity=0;
        dispersion=0;
    else
        Qus=max(1,Qus);
        gainportion=gain*SR.(ds).(zs).(rs).reachportion(sr);
        [Qds,celerity,dispersion]=TLAPwritecard(ds,zs,rs,sr,Qus,gainportion,rdays,rhours,rsteps,basedir,-999,-999);
        Qds=max(0,Qds);
    end
        
    Qavg=(max(Qus,1)+max(Qds,1))/2;
    width=10.^((log10(Qavg)*SR.(ds).(zs).(rs).widtha(sr))+SR.(ds).(zs).(rs).widthb(sr));
    evap=SR.(ds).(zs).evap(rjulien,1)*SR.(ds).(zs).(rs).evapfactor(sr).*width.*SR.(ds).(zs).(rs).channellength(sr); %EvapFactor = 0 to not have evap 
%    Qdsnodes=Qds-evap;
    Qdsnodes=Qds-evap+gagediff*SR.(ds).(zs).(rs).reachportion(sr);

    for i=1:SR.(ds).(zs).(rs).dsnodes(sr)
       type=SR.(ds).(zs).(rs).type(i,sr);
       Qnode=SR.(ds).(zs).(rs).Qnode(:,sr,i);
       Qdsnodes=Qdsnodes+type*Qnode;
    end
    Qdsnodes=max(0,Qdsnodes);
    
    SR.(ds).(zs).(rs).gagediffportion(:,sr)=gagediff*SR.(ds).(zs).(rs).reachportion(sr);
    SR.(ds).(zs).(rs).evap(:,sr)=evap;
    SR.(ds).(zs).(rs).Qus(:,sr)=Qus;
    SR.(ds).(zs).(rs).Qds(:,sr)=Qds;
    SR.(ds).(zs).(rs).Qdsnodes(:,sr)=Qdsnodes;    
    SR.(ds).(zs).(rs).celerity(:,sr)=celerity;    
    SR.(ds).(zs).(rs).dispersion(:,sr)=dispersion;    
    Qus=Qdsnodes;
    
end %sr

SR.(ds).(zs).(rs).gagediff=gagediff;  %this one that was applied

if or(srt>1,srb<SR.(ds).(zs).(rs).SR(end))
    gagediffavg=0;  %if partial reach so don't have gage to gage, then don't do gain iteration?
else
    Qdsgage=SR.(ds).(zs).(rs).Qnode(:,end,1);
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
    SR.(ds).(zs).(rs).gain=[SR.(ds).(zs).(rs).gain gain];
    SR.(ds).(zs).(rs).gagediffseries(:,ii)=gagediff;
end

end %gainchange
%SR.(ds).(zs).(rs).gagediff=gagediff;  %this not the last one that was applied

    end %r
end %z



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

Ztr=SR.(ds).WDID{wdidfromid,3};
Zbr=SR.(ds).WDID{wdidtoid,3};
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

srids=SR.(ds).(zs).(['R' num2str(Rb)]).subreachid(end)  %just to set size of release matrices
SR.(ds).(zs).(ws).Qusrelease(1440,srids)=0;     %just used for plotting, maybe better way..
SR.(ds).(zs).(ws).Qdsrelease(1440,srids)=0;
SR.(ds).(zs).(ws).Qdsnodesrelease(1440,srids)=0;


% release=zeros(rsteps,1);
% %release(rdatesstartid:rdatesstartid+1*24/rhours,1)=100;
% releasestartid=find(rdates==datenum(2017,8,11,13,0,0));
% releaseendid=find(rdates==datenum(2017,8,18,3,0,0));
% release(releasestartid:releaseendid,1)=100.833; %200AF/day release from about 12pm to 3am

for z=Ztr:Zbr
    zs=['Z' num2str(z)];
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
            srb=SR.(ds).(zs).(rs).SR(end);
        end

for sr=srt:srb
    if and(sr==SRtr,r==Rtr)
        if pred==1 %predictive case
            Qus=SR.(ds).(zs).(rs).Qus(:,sr)+release;
        else  %administrative case
            Qus=SR.(ds).(zs).(rs).Qus(:,sr)-release;
        end
    else
    end
    
    gain=SR.(ds).(zs).(rs).gain(end);
%     if gain<0;  %if losses, distribute to release also.. %this needs to be discussed further!!
%         
%         
%     end
    if pred==1
        celerity=-999;dispersion=-999;
    else
        celerity=SR.(ds).(zs).(rs).celerity(:,sr);
        dispersion=SR.(ds).(zs).(rs).dispersion(:,sr);
    end

    if gain==-999   %gain=-999 to not run J349 
        Qus=max(0,Qus);
        Qds=Qus;
    else
        Qus=max(1,Qus);
        gainportion=gain*SR.(ds).(zs).(rs).reachportion(sr);
        [Qds,celerity,dispersion]=TLAPwritecard(ds,zs,rs,sr,Qus,gainportion,rdays,rhours,rsteps,basedir,celerity,dispersion);
        Qds=max(0,Qds);
    end
    Qavg=(max(Qus,1)+max(Qds,1))/2;
    width=10.^((log10(Qavg)*SR.(ds).(zs).(rs).widtha(sr))+SR.(ds).(zs).(rs).widthb(sr));
    if waterclass{w,2}==3 %exchange
        evap=0;
    else
        evap=SR.(ds).(zs).evap(rjulien,1)*SR.(ds).(zs).(rs).evapfactor(sr).*width.*SR.(ds).(zs).(rs).channellength(sr);
    end
    Qdsnodes=Qds-evap+SR.(ds).(zs).(rs).gagediff*SR.(ds).(zs).(rs).reachportion(sr);

    for i=1:SR.(ds).(zs).(rs).dsnodes(sr)
       type=SR.(ds).(zs).(rs).type(i,sr);
       Qnode=SR.(ds).(zs).(rs).Qnode(:,sr,i);
       Qdsnodes=Qdsnodes+type*Qnode;
    end
    Qdsnodes=max(0,Qdsnodes);
    
    lsr=SR.(ds).(zs).(rs).subreachid(sr);
    SR.(ds).(zs).(rs).(ws).Qusnative(:,sr)=Qus;
    SR.(ds).(zs).(rs).(ws).Qdsnative(:,sr)=Qds;
    SR.(ds).(zs).(rs).(ws).Qdsnodesnative(:,sr)=Qdsnodes;    
    if pred==1
        SR.(ds).(zs).(rs).(ws).Qusrelease(:,sr)=Qus-SR.(ds).(zs).(rs).Qus(:,sr);
        SR.(ds).(zs).(rs).(ws).Qdsrelease(:,sr)=Qds-SR.(ds).(zs).(rs).Qds(:,sr);
        SR.(ds).(zs).(rs).(ws).Qdsnodesrelease(:,sr)=Qdsnodes-SR.(ds).(zs).(rs).Qdsnodes(:,sr);

        SR.(ds).(zs).(ws).Qusrelease(:,lsr)=Qus-SR.(ds).(zs).(rs).Qus(:,sr);
        SR.(ds).(zs).(ws).Qdsrelease(:,lsr)=Qds-SR.(ds).(zs).(rs).Qds(:,sr);
        SR.(ds).(zs).(ws).Qdsnodesrelease(:,lsr)=Qdsnodes-SR.(ds).(zs).(rs).Qdsnodes(:,sr);
    else
        SR.(ds).(zs).(rs).(ws).Qusrelease(:,sr)=SR.(ds).(zs).(rs).Qus(:,sr)-Qus;
        SR.(ds).(zs).(rs).(ws).Qdsrelease(:,sr)=SR.(ds).(zs).(rs).Qds(:,sr)-Qds;
        SR.(ds).(zs).(rs).(ws).Qdsnodesrelease(:,sr)=SR.(ds).(zs).(rs).Qdsnodes(:,sr)-Qdsnodes;
        
        SR.(ds).(zs).(ws).Qusrelease(:,lsr)=SR.(ds).(zs).(rs).Qus(:,sr)-Qus;
        SR.(ds).(zs).(ws).Qdsrelease(:,lsr)=SR.(ds).(zs).(rs).Qds(:,sr)-Qds;
        SR.(ds).(zs).(ws).Qdsnodesrelease(:,lsr)=SR.(ds).(zs).(rs).Qdsnodes(:,sr)-Qdsnodes;
        
    end
    
    Qus=Qdsnodes;
    
end %sr

    end %r
end %z

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

for z=Zt:Zb
    zs=['Z' num2str(z)];
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
            srb=SR.(ds).(zs).(rs).SR(end);
        end

for sr=srt:srb
%     plotx=[plotx (r-1)*20+(sr-1)*3 (r-1)*20+(sr-1)*3+1 (r-1)*20+(sr-1)*3+1];    
     plotlinex=[plotlinex plotx plotx+SR.(ds).(zs).(rs).channellength(sr) plotx+SR.(ds).(zs).(rs).channellength(sr)];
     plotx=plotx+SR.(ds).(zs).(rs).channellength(sr);
     
     plotline(k+1:k+3,1)=[SR.(ds).(zs).(rs).Qus(ts,sr);SR.(ds).(zs).(rs).Qds(ts,sr);SR.(ds).(zs).(rs).Qdsnodes(ts,sr)];
     lsr=SR.(ds).(zs).(rs).subreachid(sr);
     kwr=0;kwe=1;
     for w=1:length(waterclass(:,1))
         ws=['W' num2str(w)];
         if waterclass{w,2}==3 %for exchanges add onto native line
            kwe=kwe+1;
            plotline(k+1:k+3,kwe)=[SR.(ds).(zs).(ws).Qusrelease(ts,lsr);SR.(ds).(zs).(ws).Qdsrelease(ts,lsr);SR.(ds).(zs).(ws).Qdsnodesrelease(ts,lsr)];
         else
            kwr=kwr+1;
            plotlinerelease(k+1:k+3,kwr)=[SR.(ds).(zs).(ws).Qusrelease(ts,lsr);SR.(ds).(zs).(ws).Qdsrelease(ts,lsr);SR.(ds).(zs).(ws).Qdsnodesrelease(ts,lsr)];
         end
          
%         plotlinerelease(k+1:k+3,w)=[SR.(ds).(zs).(ws).Qusrelease(ts,lsr);SR.(ds).(zs).(ws).Qdsrelease(ts,lsr);SR.(ds).(zs).(ws).Qdsnodesrelease(ts,lsr)];
         
%         plotlinerelease.(ws)=[plotlinerelease.(ws) SR.(ds).(zs).(ws).Qusrelease(ts,lsr) SR.(ds).(zs).(ws).Qdsrelease(ts,lsr) SR.(ds).(zs).(ws).Qdsnodesrelease(ts,lsr)];
        
%          if (z>=Ztr & r>=Rtr & sr>=SRtr) & (z<=Zbr & r<=Rbr & sr<=SRbr)
% %         plotlinenative.(ws)=[plotlinenative SR.(ds).(zs).(rs).(ws).Qusnative(ts,sr) SR.(ds).(zs).(rs).(ws).Qdsnative(ts,sr) SR.(ds).(zs).(rs).(ws).Qdsnodesnative(ts,sr)];
%          plotlinerelease(k+1:k+3,w)=[SR.(ds).(zs).(rs).(ws).Qusrelease(ts,sr);SR.(ds).(zs).(rs).(ws).Qdsrelease(ts,sr);SR.(ds).(zs).(rs).(ws).Qdsnodesrelease(ts,sr)];
%          else
%             plotlinerelease(k+1:k+3,w)=[0;0;0];
%          end
     end
     k=k+3;

%     plotline=[plotline SR.(ds).(zs).(rs).Qdsnodes(ts,sr)];
%     plotlinenative=[plotlinenative SR.(ds).(zs).(rs).(ws).Qdsnodesnative(ts,sr)];
    
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



