%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% StateTL
% Matlab (preliminary) Colors of Water Transit Loss and Timing engine
%
% Major version changes starting June 2021
% 


cd C:\Projects\Ark\ColorsofWater\matlab
clear all
runstarttime=now;
basedir=cd;basedir=[basedir '\'];
%j349dir=[basedir 'j349dir\']; %currently need to a cd where run fortran but may slow to cd at every instance
j349dir=basedir;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% runoptions
% - most of this will be put into text file to drive run

%control options (on=1) fed through control file need to be in this list -
%watch out - if change variable names in code also need to change them here!
%currently - if leave out one of these from control file will assign it a zero value
controlvars={'srmethod','infofilename','readinfofile','readevap','readstagedischarge','pullstationdata','pullreleaserecs','runriverloop','runwcloop','doexchanges','runcaptureloop','runcalibloop'};
controlvars=[controlvars,{'outputfilename','outputgage','outputwc','outputcal','outputhr','outputday','calibavggainloss'}];
controlfilename='StateTL_control.txt';


%Methods - these currently override method for all reaches, but planning default method by Reach that would run if not overrided  
%srmethod='j349';       %dynamic j349/Livinston method
srmethod='muskingum';   %percent loss TL plus muskingum-cunge for travel time

% Date - will be reworked - j349 currently only works for 60 days at 1hour - may alter fortran to run full calendar year at 1 hour without spinup
% also this needs to be integrated into SR structure
datestart=datenum(2018,4,01);

infofilename='StateTL_inputdata.xlsx';
readinfofile=0;  %1 reads from excel and saves mat file; other reads mat file;
    readevap=0;   %if reading info file, dont have to reread evap/SD (ie for calibration) 
    readstagedischarge=0;
pullstationdata=0;  %read gage and telemetry basd flow data; 1 reads from REST, other reads from file
pullreleaserecs=0;  %0 load from saved mat file, 1 if want to repull all from REST, 2 if only pull new/modified from REST for same period
runriverloop=1;  %1 runs / 0 etc not run
runwcloop=1;
   doexchanges=1;
runcaptureloop=1;  %loop to characterize potential capture vs available amt.
runcalibloop=1;

outputfilename='StateTL_inadv1new_';  %will add srmethod + gage/wc/etc + hour/day + .csv
outputgage=1;  %output river amounts by reach
outputwc=1;  %output waterclass amounts by reach
outputcal=1;  %output calibration amounts by gage location
    outputhr=0;  %output on hour timestep
    outputday=1;  %output on day timestep
    
WDcaliblist=[17];
calibstartdate=datenum(2018,4,02);
calibenddate=datenum(2018,4,15);
calibavggainloss='linreg'; %currently mean or linreg - method to establish gain/loss/error correction for period that might be like we will do future forecasting
calibavggainloss='mean';




pred=0;  %if pred=0 subtracts water class from existing flows, if 1 adds to existing gage flows
percrule=.10;  %percent rule - TLAP currently uses 10% of average release rate as trigger amount (Livingston 2011 says 10%; past Livingston 1978 detailed using 5% believe defined as 5% of max amount at headgate)

flowcriteria=5; %to establish gage and node flows: 1 low, 2 avg, 3 high flow values from livingston; envision 4 for custom entry; 5 for actual flows; 6 average for xdays/yhours prior to now/date; 7 average between 2 dates
iternum.j349=5;  %iterations of gageflow loop given method to iterate on gagediff (gain/loss/error correction for estimated vs actual gage flows) (had been using dynamic way to iterate but currently just number);
iternum.muskingum=5;

adjustlastsrtogage=1;     %although gagediff process should be getting last sr very close to gage, this would make a final adjustment to exactly equal
inadv1_letwaterby=1;      %this will let a single water class amt get by an internal node although wc amt exceeds initially estimated river amt - hopefully until internal river amt can be adjusted upwards by last step(ie since have no actual river data at internal node) 
inadv2_reducewcpushUS=0;        %this will attempt to reduce wc amts at upstream location (within R-reach) if native flow goes negative at gage - CURRENTLY SEEMS TO PRODUCE SOME OSCILLATIONS
    wcreduceamtlimit=0;  %limit of sum in negative native flow at gage above which will add wc reductions and reoperate
    iternative=10;        %iteration limit for above
inadv2b_reducewclastatgage=0;    %this applies water class reducation at ds end of reach rather than push up - this will also occur if above option hits iteration limit and also uses amtlimit  - THIS IS ACTING A LOT SMOOTHER THAN PUSHING US
inadv3a_increaseint=0;     %last step to then increase internal node river flow amounts above those initially estimated - this option is attitude that problem is from inadvertant diversion and so pushes up a reach - but doesnt seem to work quite as well as b option
    nhrs=1;              %number of hours to average over to increase river flow amounts for above operation
    sraddamtlimit=10;     %limit of reachwide sum in negative native flows above which will adjust internal flows and reoperate
inadv3b_increaseint=0;    %currently using over 3a; similar step as 3a / only use one or other / but keeps correction at us or ds location where wcs exceed native / acting a bit better than 3a
minc=1;              %minimum flow applied to celerity, dispersion, and evaporation calculations (dont want to have a zero celerity for reverse operations etc) / this is also seperately in j349/musk functions
minj349=1;           %minimum flow for j349 application - TLAP uses 1.0
gainchangelimit=0.1;

logfilename='StateTL_runlog.txt';  %log filename
    displaymessage=1;  %1=display messages to screen
    writemessage=0; %1=write messages to logfile
    
logm=['Running StateTL starting: ' datestr(runstarttime)];    %log message
disp(logm);    %log message
if writemessage==1;fidlog=fopen(logfilename,'w');fprintf(fidlog,'%s\r\n',logm);fclose(fidlog);end


apikey='D2D7AF63-C286-40A8-9';  %this is KT1 personal - will want to get one for this tool or cdss etc


rdays=60; rhours=1;
spinupdays=45;
rsteps=rdays*24/rhours;
datestid=spinupdays*24/rhours+1;
rdates=datestart*ones(spinupdays*24/rhours,1);
rdates=[rdates;[datestart:rhours/24:datestart+(rdays-spinupdays)-rhours/24]'];
[ryear,rmonth,rday,rhour] = datevec(rdates);
rdatesday=floor(rdates);
rjulien=rdatesday-(datenum(ryear,1,1)-1);
dateend=datestart+(rdays-spinupdays)-1;
datedays=[datestart:dateend];

%date.datestart=datestart;


%%%%%%%%%%%%%%%%%%%%%%%%%%
%READ INITIAL RUN INFO
% initially have WDlist in xlsx that defines division and WDs to run in order (upper tribs first)
%%%%%%%%%%%%%%%%%%%%%%%%%%


fid=fopen(controlfilename);
if fid==-1
    logm=['Error: Could not find text file with run control options: ' basedir controlfilename];
    domessage(logm,logfilename,displaymessage,writemessage)
    error(logm);
else
    logm=['Reading text file with run control options: ' basedir controlfilename];
    domessage(logm,logfilename,displaymessage,writemessage)    
end

for i=1:length(controlvars)  %initially set these to zero
    eval([controlvars{i} '=0;']);
end

while 1
   line = fgetl(fid);
   if ~ischar(line), break, end
   if ~isempty(line) && ~strcmp(line(1),'#') && ~strcmp(line(1),'%')   %starting # or % taken as comment line wont be executed
   eids=find(line=='=');                             %an equal sign signals end of variable name
   cids=find(line==',');                            %commas can seperate multiple values
   sids=find(line==';');                             %if semi-colon take as end of data, so can put comments on line afterwards
   if ~isempty(sids)                                 %if no semi-colon will take full line to end, so no spaces or comments after data value
       cids=cids(find(cids<sids(1)));
       tids=[eids(1),cids,sids(1)];
   else
       tids=[eids(1),cids,length(line)+1];
   end
   controlvarsid=find(strcmp(lower(line(1:tids(1)-1)),controlvars));
   logtxt='Control file: ';
   if 1==2
   elseif ~isempty(controlvarsid)   %variables listed in controlvarsid with single value as input; text should be in single quotes
       eval([controlvars{controlvarsid} '=' line(tids(1)+1:tids(2)-1) ';']);
   elseif strcmp(lower(line(1:eids(1)-1)),'div')   %Division - currently only set to one at a time but with a bit of code revision could run multiple
       d=str2double(line(tids(1)+1:tids(2)-1));
       ds=['D' num2str(d)];
       if length(tids)>2
            logm=['Warning: more than one Division listed in run options / currently not set to run multiple divisions at once (but very easily can be) - just running first listed Div'];
            domessage(logm,logfilename,displaymessage,writemessage)
       end
   elseif strcmp(lower(line(1:eids(1)-1)),'wdlist')   %WD run list in order; seperate by commas from upper tribs first to lower/mainstem
       WDlist=[];
       for i=1:length(tids)-1
            wd=str2double(line(tids(i)+1:tids(i+1)-1));
            WDlist=[WDlist,wd];
       end
   elseif strcmp(lower(line(1:eids(1)-1)),'wdcaliblist')   %WD to calibrate if running calibloop, if multiple seperate by commas
       WDcaliblist=[];
       for i=1:length(tids)-1
            wd=str2double(line(tids(i)+1:tids(i+1)-1));
            WDcaliblist=[WDcaliblist,wd];
       end
   elseif strcmp(lower(line(1:eids(1)-1)),'datestart')   %calib startdate year,month,day
       datestart=datenum(str2double(line(tids(1)+1:tids(2)-1)),str2double(line(tids(2)+1:tids(3)-1)),str2double(line(tids(3)+1:tids(4)-1)));
   elseif strcmp(lower(line(1:eids(1)-1)),'calibstartdate')   %calib startdate year,month,day
       calibstartdate=datenum(str2double(line(tids(1)+1:tids(2)-1)),str2double(line(tids(2)+1:tids(3)-1)),str2double(line(tids(3)+1:tids(4)-1)));
   elseif strcmp(lower(line(1:eids(1)-1)),'calibenddate')   %calib enddate year,month,day
       calibenddate=datenum(str2double(line(tids(1)+1:tids(2)-1)),str2double(line(tids(2)+1:tids(3)-1)),str2double(line(tids(3)+1:tids(4)-1)));
   else
       logtxt='WARNING: control file line not executed: ';
   end
   logm=[logtxt line(1:tids(end)-1)];
   domessage(logm,logfilename,displaymessage,writemessage)
   end
end
fclose(fid);

% logm=['reading WD run list from file: ' basedir infofilename];
% domessage(logm,logfilename,displaymessage,writemessage)
% 
% inforaw=readcell([basedir infofilename],'Sheet','WDlist');
% [inforawrow inforawcol]=size(inforaw);
% 
% infoheaderrow=1;
% for i=1:inforawcol
%     if 1==2
%     elseif strcmp(upper(inforaw{infoheaderrow,i}),'DIV'); infocol.div=i;
%     elseif strcmp(upper(inforaw{infoheaderrow,i}),'WD'); infocol.wd=i;
%     end
% end
% k=0;
% for i=infoheaderrow+1:inforawrow
%     if ~isempty(inforaw{i,infocol.div}) & ~ismissing(inforaw{i,infocol.div})
%         k=k+1;
%         v.di=inforaw{i,infocol.div};if ischar(v.di); v.di=str2num(v.di); end
%         v.wd=inforaw{i,infocol.wd};if ischar(v.wd); v.wd=str2num(v.wd); end
%         
%         if k==1
%            d=v.di;
%            WDlist=v.wd;
%         else
%            if d~=v.di
%                error('Stopping - more than one Division listed in run options / currently not set to run multiple divisions at once (but very easily can be)')
%            end
%            WDlist=[WDlist,v.wd];
%         end
%     end
% end
% ds=['D' num2str(d)];
% 

%%%%%%%%%%%%%%%%%%%%%%%%%%
%READ SUBREACH INFORMATION
%  initially have in xlsx but this will eventually all come from HB/REST
%%%%%%%%%%%%%%%%%%%%%%%%%%
global SR

if readinfofile==1
    if readevap~=1 | readstagedischarge~=1  %if not rereading - this should have seperate evap and stagedischarge structures
        load([basedir 'StateTL_SRdataevapsd.mat']);
    end
    
    

%%%%%%%%%%%%%%%%%%%%%%%%%%    
% read subreach data    
logm=['reading subreach info from file: ' basedir infofilename];
domessage(logm,logfilename,displaymessage,writemessage)


% inforaw=readcell([basedir infofilename],'Sheet','SR');
% [inforawrow inforawcol]=size(inforaw);

[infonum,infotxt,inforaw]=xlsread([basedir infofilename],'SR');
[inforawrow inforawcol]=size(inforaw);

infoheaderrow=1;

for i=1:inforawcol
    if 1==2

    elseif strcmp(upper(inforaw{infoheaderrow,i}),'WDID'); infocol.uswdid=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'NAME'); infocol.usname=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'DSWDID'); infocol.dswdid=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'DSNAME'); infocol.dsname=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'RELEASESTRUCTURE'); infocol.rels=i;       
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'BRANCH'); infocol.branch=i;
    
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'DIV'); infocol.div=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'WD'); infocol.wd=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'REACH'); infocol.reach=i;
%     elseif strcmp(upper(inforaw{infoheaderrow,i}),'LIVINGSTON SUBREACH'); infocol.livingstonsubreach=i; %delete when expanding model
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'SUBREACH'); infocol.subreach=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'SRID'); infocol.srid=i;

    elseif strcmp(upper(inforaw{infoheaderrow,i}),'CHANNEL LENGTH'); infocol.channellength=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'ALLUVIUM LENGTH'); infocol.alluviumlength=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'REACH PORTION'); infocol.reachportion=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'LOSSPERCENT'); infocol.losspercent=i;
        
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'TRANSMISSIVITY'); infocol.transmissivity=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'STORAGE COEFFICIENT'); infocol.storagecoefficient=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'AQUIFER WIDTH'); infocol.aquiferwidth=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'DISPERSION-A'); infocol.dispersiona=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'DISPERSION-B'); infocol.dispersionb=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'CELERITY-A'); infocol.celeritya=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'CELERITY-B'); infocol.celerityb=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'SDNUM'); infocol.sdnum=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'CLOSURE'); infocol.closure=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'GAININITIAL'); infocol.gaininitial=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'WIDTH-A'); infocol.widtha=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'WIDTH-B'); infocol.widthb=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'EVAPFACTOR'); infocol.evapfactor=i;

    elseif strcmp(upper(inforaw{infoheaderrow,i}),'TYPE'); infocol.type=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'STATION'); infocol.station=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'PARAMETER'); infocol.parameter=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'LOW'); infocol.low=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'AVG'); infocol.avg=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'HIGH'); infocol.high=i;

    end
end

k=0;
wdidk=0;
for i=infoheaderrow+1:inforawrow
    
    if ~isempty(inforaw{i,infocol.subreach}) & ~ismissing(inforaw{i,infocol.subreach})
        k=k+1;
        v.di=inforaw{i,infocol.div};if ischar(v.di); v.di=str2num(v.di); end
        v.wd=inforaw{i,infocol.wd};if ischar(v.wd); v.wd=str2num(v.wd); end
        v.re=inforaw{i,infocol.reach};if ischar(v.re); v.re=str2num(v.re); end        
%         v.ls=inforaw{i,infocol.livingstonsubreach};if ischar(v.ls); v.ls=str2num(v.ls); end  %delete when expanding model
        v.sr=inforaw{i,infocol.subreach};if ischar(v.sr); v.sr=str2num(v.sr); end
        v.si=inforaw{i,infocol.srid};if ischar(v.si); v.si=str2num(v.si); end
        c.di=num2str(inforaw{i,infocol.div});
        c.wd=num2str(inforaw{i,infocol.wd});
        c.re=num2str(inforaw{i,infocol.reach});
        c.sr=num2str(inforaw{i,infocol.subreach});
        
        c.uw=num2str(inforaw{i,infocol.uswdid});
        c.un=num2str(inforaw{i,infocol.usname});
        c.dw=num2str(inforaw{i,infocol.dswdid});
        c.dn=num2str(inforaw{i,infocol.dsname});
        c.ds=num2str(inforaw{i,infocol.station});
        c.dp=num2str(inforaw{i,infocol.parameter});
        c.br=num2str(inforaw{i,infocol.branch});

        v.t1=inforaw{i,infocol.type};if ischar(v.t1); v.t1=str2num(v.t1); end
        v.l1=inforaw{i,infocol.low};if ischar(v.l1); v.l1=str2num(v.l1); end
        v.a1=inforaw{i,infocol.avg};if ischar(v.a1); v.a1=str2num(v.a1); end
        v.h1=inforaw{i,infocol.high};if ischar(v.h1); v.h1=str2num(v.h1); end
        v.rs=inforaw{i,infocol.rels};if ischar(v.rs); v.rs=str2num(v.rs); end
        v.br=inforaw{i,infocol.branch};if ischar(v.br); v.br=str2num(v.br); end
        
        v.cl=inforaw{i,infocol.channellength};if ischar(v.cl); v.cl=str2num(v.cl); end
        v.al=inforaw{i,infocol.alluviumlength};if ischar(v.al); v.al=str2num(v.al); end
        v.rp=inforaw{i,infocol.reachportion};if ischar(v.rp); v.rp=str2num(v.rp); end
        v.lp=inforaw{i,infocol.losspercent};if ischar(v.lp); v.lp=str2num(v.lp); end
        v.tr=inforaw{i,infocol.transmissivity};if ischar(v.tr); v.tr=str2num(v.tr); end
        v.sc=inforaw{i,infocol.storagecoefficient};if ischar(v.sc); v.sc=str2num(v.sc); end
        v.aw=inforaw{i,infocol.aquiferwidth};if ischar(v.aw); v.aw=str2num(v.aw); end
        v.da=inforaw{i,infocol.dispersiona};if ischar(v.da); v.da=str2num(v.da); end
        v.db=inforaw{i,infocol.dispersionb};if ischar(v.db); v.db=str2num(v.db); end
        v.ca=inforaw{i,infocol.celeritya};if ischar(v.ca); v.ca=str2num(v.ca); end
        v.cb=inforaw{i,infocol.celerityb};if ischar(v.cb); v.cb=str2num(v.cb); end
        v.sd=inforaw{i,infocol.sdnum};if ischar(v.sd); v.sd=str2num(v.sd); end
        v.cls=inforaw{i,infocol.closure};if ischar(v.cls); v.cls=str2num(v.cls); end
        v.gi=inforaw{i,infocol.gaininitial};if ischar(v.gi); v.gi=str2num(v.gi); end
        v.wa=inforaw{i,infocol.widtha};if ischar(v.wa); v.wa=str2num(v.wa); end
        v.wb=inforaw{i,infocol.widthb};if ischar(v.wb); v.wb=str2num(v.wb); end
        v.ef=inforaw{i,infocol.evapfactor};if ischar(v.ef); v.ef=str2num(v.ef); end
           
        %terrible, fix this and remove subsequent loop
        if ~isfield(SR,['D' c.di])
            SR.(['D' c.di])=[];
        end
        if isfield(SR.(['D' c.di]),'WD')
            SR.(['D' c.di]).WD=unique([SR.(['D' c.di]).WD v.wd],'stable');
        else
            SR.(['D' c.di]).WD=v.wd;
        end
        if ~isfield(SR.(['D' c.di]),'WDID') %not a great way to do this but just to have a pretty order
            SR.(['D' c.di]).WDID=[];
        end
        if ~isfield(SR.(['D' c.di]),['WD' c.wd])
            SR.(['D' c.di]).(['WD' c.wd])=[];
        end
        if isfield(SR.(['D' c.di]).(['WD' c.wd]),'R')
            SR.(['D' c.di]).(['WD' c.wd]).R=unique([SR.(['D' c.di]).(['WD' c.wd]).R v.re],'stable');
        else
            SR.(['D' c.di]).(['WD' c.wd]).R=v.re;
        end
        if ~isfield(SR.(['D' c.di]).(['WD' c.wd]),'releasestructures')
            SR.(['D' c.di]).(['WD' c.wd]).releasestructures=[];
        end
        if ~isfield(SR.(['D' c.di]).(['WD' c.wd]),'branch')
            SR.(['D' c.di]).(['WD' c.wd]).branch=[];
        end
        if ~isfield(SR.(['D' c.di]).(['WD' c.wd]),['R' c.re])
            SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re])=[];
        end
        if isfield(SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]),'SR')
            SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).SR=[SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).SR v.sr];  %may want to check if duplicates
        else
            SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).SR=v.sr;
        end
        

        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).subreachid(v.sr)=v.si;
        
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).wdid{1,v.sr}=c.uw;        
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).name{1,v.sr}=c.un;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dswdid{1,v.sr}=c.dw;  %this could get reduced last in list (remove ids) (but currently if not in order in reading that would mess up)        
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dsname{1,v.sr}=c.dn;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).station{1,v.sr}=c.ds;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).parameter{1,v.sr}=c.dp;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).type(1,v.sr)=v.t1;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).low(1,v.sr)=v.l1;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).avg(1,v.sr)=v.a1;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).high(1,v.sr)=v.h1;
        
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).channellength(v.sr)=v.cl;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).alluviumlength(v.sr)=v.al;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).reachportion(v.sr)=v.rp;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).losspercent(v.sr)=v.lp;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).transmissivity(v.sr)=v.tr;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).storagecoefficient(v.sr)=v.sc;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).aquiferwidth(v.sr)=v.aw;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dispersiona(v.sr)=v.da;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dispersionb(v.sr)=v.db;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).celeritya(v.sr)=v.ca;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).celerityb(v.sr)=v.cb;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).sdnum(v.sr)=v.sd;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).closure(v.sr)=v.cls;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).gaininitial(v.sr)=v.gi;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).widtha(v.sr)=v.wa;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).widthb(v.sr)=v.wb;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).evapfactor(v.sr)=v.ef;
  
        
        
        if v.rs==1  % releasestructures - structures with Type:7 records that define releases to ds or us exchange
            if isempty(SR.(['D' c.di]).(['WD' c.wd]).releasestructures)
                SR.(['D' c.di]).(['WD' c.wd]).releasestructures={c.uw};
            else
                SR.(['D' c.di]).(['WD' c.wd]).releasestructures=[SR.(['D' c.di]).(['WD' c.wd]).releasestructures,{c.uw}];
            end
        end
        
        if ~isnan(v.br)
            if isempty(SR.(['D' c.di]).(['WD' c.wd]).branch)
                SR.(['D' c.di]).(['WD' c.wd]).branch=[{v.br} {c.dw} {v.re} {v.sr}];
            else
                SR.(['D' c.di]).(['WD' c.wd]).branch=[SR.(['D' c.di]).(['WD' c.wd]).branch;{v.br} {c.dw} {v.re} {v.sr}];
            end
        end

        if v.re==1 & v.sr==1
            wdidk=wdidk+1;
            SR.(['D' c.di]).WDID{wdidk,1}=c.uw;
            SR.(['D' c.di]).WDID{wdidk,2}=v.di;
            SR.(['D' c.di]).WDID{wdidk,3}=v.wd;
            SR.(['D' c.di]).WDID{wdidk,4}=v.re;
            SR.(['D' c.di]).WDID{wdidk,5}=v.sr;
            SR.(['D' c.di]).WDID{wdidk,6}=0;  %indicates usnode
        end
        
        wdidk=wdidk+1;
        SR.(['D' c.di]).WDID{wdidk,1}=c.dw;
        SR.(['D' c.di]).WDID{wdidk,2}=v.di;
        SR.(['D' c.di]).WDID{wdidk,3}=v.wd;
        SR.(['D' c.di]).WDID{wdidk,4}=v.re;
        SR.(['D' c.di]).WDID{wdidk,5}=v.sr;
        SR.(['D' c.di]).WDID{wdidk,6}=1;  %indicates dsnode
        
    end
end

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % currently just to add numbers of WD, R, and SR for looping etc
% % at some point may want to find order and create SR numbers using wdid connections (in which case have to do above above)
% Dlist=fieldnames(SR);
% for i=1:length(Dlist)
%     dls=Dlist{i};
%     WDlisti=fieldnames(SR.(dls));
%     for j=3:length(WDlisti)  %first two fields should be WD and WDID
%         wds=WDlisti{j};
%         wd=str2double(wds(3:end));
%         SR.(dls).WD(j-2)=wd;
%         Rlistj=fieldnames(SR.(dls).(wds));
%         for k=4:length(Rlistj) %first fields should be R and releasestructures and branch
%             rs=Rlistj{k};
%             r=str2double(rs(2:end));
%             if r>0
%                SR.(dls).(wds).R=[SR.(dls).(wds).R,r]; 
%             end
%             numsr=length(SR.(dls).(wds).(rs).subreachid);  %WATCH - if change that 'subreachid' row heading will need to change here, can use any of variables
%             SR.(dls).(wds).(rs).SR=[1:numsr];
%         end
%     end
% end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Reorder WDID list by wdlist - CURRENTLY IMPORTANT FOR ROUTING
WDIDsortedbywdidlist=[];
for wd=WDlist
    wdinwdidlist=find([SR.(ds).WDID{:,3}]==wd);
    WDIDsortedbywdidlist=[WDIDsortedbywdidlist;SR.(ds).WDID(wdinwdidlist,:)];
end
SR.(ds).WDID=WDIDsortedbywdidlist;

%%%%%%%%%%%%%%%%%%
% Evaporation data
% this will have to be refined as expand reaches into new areas or use better data
if readevap==1
    [infonum,infotxt,inforaw]=xlsread([basedir infofilename],'evap');
    [infonumrow infonumcol]=size(infonum);
    [inforawrow inforawcol]=size(inforaw);
    for wd=WDlist
        wds=['WD' num2str(wd)];
        SR.(ds).(wds).evap=infonum(:,1);
        evap.(ds).(wds).evap=SR.(ds).(wds).evap;
    end
    
else
    for wd=WDlist
        wds=['WD' num2str(wd)];
        SR.(ds).(wds).evap=evap.(ds).(wds).evap;
    end
    
end

%%%%%%%%%%%%%%%%%%%%%%%%
% stage discharge data
% [infonum,infotxt,inforaw]=xlsread([basedir infofilename],'stagedischarge');
% [infonumrow infonumcol]=size(infonum);
% [inforawrow inforawcol]=size(inforaw);

if readstagedischarge==1
    SDmat=readmatrix([basedir infofilename],'Sheet','stagedischarge');
    [SDmatnumrow SDmatnumcol]=size(SDmat);
    
    for i=1:SDmatnumrow
        if ~isfield(SR.(ds),'stagedischarge') || ~isfield(SR.(ds).stagedischarge,['SD' num2str(SDmat(i,1))])
            SR.(ds).stagedischarge.(['SD' num2str(SDmat(i,1))])=SDmat(i,2:3);
        else
            SR.(ds).stagedischarge.(['SD' num2str(SDmat(i,1))])=[SR.(ds).stagedischarge.(['SD' num2str(SDmat(i,1))]);SDmat(i,2:3)];
        end
    end
    stagedischarge.(ds).stagedischarge=SR.(ds).stagedischarge;
else
    SR.(ds).stagedischarge=stagedischarge.(ds).stagedischarge;
end

% for wd=WDlist
%     wds=['WD' num2str(wd)];
%     SR.(ds).stagedischarge=infonum;
% end

clear c v info*

save([basedir 'StateTL_SRdata.mat'],'SR');
save([basedir 'StateTL_SRdataevapsd.mat'],'evap','stagedischarge');

else
    load([basedir 'StateTL_SRdata.mat']);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% READ GAGE AND TELEMETRY BASED FLOW DATA
% much of this needs to be improved for larger application; particularly handling of dates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

flowtestloc=[2,17,8,1];


if pullstationdata==1

switch flowcriteria
    case 1
        flow='low';
    case 2
        flow='avg';
    case 3
        flow='high';
    otherwise
        reststarttime=now;
        logm=['reading station (gage/telemetry) data from HB using REST services starting: ' datestr(reststarttime)];
        domessage(logm,logfilename,displaymessage,writemessage)

        d=flowtestloc(1);wd=flowtestloc(2);r=flowtestloc(3);sr=flowtestloc(4);
        station=SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).station{1,sr};
        parameter=SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).parameter{1,sr};
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
            test(1)=SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).low(1,sr);
            test(2)=SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).avg(1,sr);
            test(3)=SR.(['D' num2str(d)]).(['WD' num2str(wd)]).(['R' num2str(r)]).high(1,sr);
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

for wd=SR.(ds).WD
    wds=['WD' num2str(wd)];
    for r=SR.(ds).(wds).R 
        rs=['R' num2str(r)];
        if flowcriteria>=4
            for sr=SR.(ds).(wds).(rs).SR
                if strcmp(SR.(ds).(wds).(rs).station{1,sr},'NaN') | strcmp(SR.(ds).(wds).(rs).station{1,sr},'none')  %if no telemetry station then uses low/avg/high number
                    SR.(ds).(wds).(rs).Qnode(:,sr,1)=SR.(ds).(wds).(rs).(flow)(1,sr)*ones(rsteps,1);
                else
                    station=SR.(ds).(wds).(rs).station{1,sr};
                    parameter=SR.(ds).(wds).(rs).parameter{1,sr};
                    telemetryhoururl='https://dwr.state.co.us/Rest/GET/api/v2/telemetrystations/telemetrytimeserieshour/';
                    try
                        gagedata=webread(telemetryhoururl,'format','json','abbrev',station,'parameter',parameter,'startDate',datestr(rdates(1),21),'endDate',datestr(rdates(end),21),'includeThirdParty','true','apiKey',apikey);
                        for i=1:gagedata.ResultCount
                            measvalues(i)=gagedata.ResultList(i).measValue;
                            measdatestr=gagedata.ResultList(i).measDate;
                            measdatestr(11)=' ';
                            measdates(i)=datenum(measdatestr,31);
                            measunit{i}=gagedata.ResultList(i).measUnit; %check?
                        end
                        %here need to work out various Qnode options
                        %initial below assuming all data there and one hour timestep
                        Qnode(1:datestid-1,1)=measvalues(1);
                        Qnode(datestid:length(rdates),1)=measvalues;
                        SR.(ds).(wds).(rs).Qnode(:,sr,1)=Qnode;
                    catch
                        logm=['WARNING: didnt get telemetry data for gage: ' station ' parameter: ' parameter ' have to use flow rate for conditions: ' flow ];
                        domessage(logm,logfilename,displaymessage,writemessage)
                        SR.(ds).(wds).(rs).Qnode(:,sr,1)=SR.(ds).(wds).(rs).(flow)(1,sr)*ones(rsteps,1);
                    end
                end
            end
        else
            %                SR.(ds).(wds).(rs).Qnode(:,:,1)=repmat(SR.(ds).(wds).(rs).(flow)(1,:),rsteps,1).*ones(rsteps,length(SR.(ds).(wds).(rs).SR)); %repmat required for r2014a
            SR.(ds).(wds).(rs).Qnode(:,:,1)=SR.(ds).(wds).(rs).(flow)(1,:).*ones(rsteps,length(SR.(ds).(wds).(rs).SR));
        end
        Stations.(ds).(wds).(rs).Qnode=SR.(ds).(wds).(rs).Qnode;  %to save seperately
    end
end

save([basedir 'StateTL_SRdata_withgage.mat'],'SR');
save([basedir 'StateTL_Qnode.mat'],'Stations');

else
    load([basedir 'StateTL_Qnode.mat']);
    if readinfofile==1  %if reload SR data need to reattach gage data...
        for wd=SR.(ds).WD
            wds=['WD' num2str(wd)];
            for r=SR.(ds).(wds).R
                rs=['R' num2str(r)];
                SR.(ds).(wds).(rs).Qnode=Stations.(ds).(wds).(rs).Qnode;
            end
        end
        save([basedir 'StateTL_SRdata_withgage.mat'],'SR');
    else
        load([basedir 'StateTL_SRdata_withgage.mat']);        
    end    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% WATERCLASS RELEASE RECORDS USING HB REST
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

divrecdayurl='https://dwr.state.co.us/Rest/GET/api/v2/structures/divrec/divrecday/';

if pullreleaserecs==1
    clear WC
    WC.date.datestart=datestart;
    WC.date.dateend=dateend;
    for wd=WDlist
        wds=['WD' num2str(wd)];
        WC.date.(ds).(wds).modified=0;
    end
else
    load(['StateTL_WC.mat']);
end



if pullreleaserecs>0
     logm=['reading water class release data from HB using REST services option: ' num2str(pullreleaserecs) ' starting: ' datestr(now)];
     domessage(logm,logfilename,displaymessage,writemessage)

    for wd=WDlist
        wds=['WD' num2str(wd)];
        modified=WC.date.(ds).(wds).modified;
        maxmodified=modified;
        
    if isfield(SR.(ds).(wds),'releasestructures')
for j=1:length(SR.(ds).(wds).releasestructures)
    reswdid=SR.(ds).(wds).releasestructures{j};
    %for type=[7,4,8] %release, exchange, apd(?)
    %divrecdata=webread(divrecdayurl,'format','json','min-datameasdate',datestr(datestart,23),'max-datameasdate',datestr(dateend,23),'min-dataValue',0.0001,'wdid',reswdid,'wcIdentifier',['*T:' num2str(type) '*'],'min-modified',datestr(WC.date.modified,23),weboptions('Timeout',30));
    
    try
        logm=['Using HBREST for  ' reswdid ' from: ' datestr(datestart,23) ' to ' datestr(dateend,23) ' and modified: ' datestr(modified) ];
        domessage(logm,logfilename,displaymessage,writemessage)
                
        divrecdata=webread(divrecdayurl,'format','json','min-datameasdate',datestr(datestart,23),'max-datameasdate',datestr(dateend,23),'min-dataValue',0.0001,'wdid',reswdid,'min-modified',datestr(modified+1/24/60,'mm/dd/yyyy HH:MM'),weboptions('Timeout',30),'apiKey',apikey);
%        divrecdata=webread(divrecdayurl,'format','json','min-datameasdate',datestr(datestart,23),'max-datameasdate',datestr(dateend,23),'min-dataValue',0.0001,'wdid',reswdid,'min-modified',datestr(modified+1/24/60,'mm/dd/yyyy HH:MM'),weboptions('Timeout',30,'CertificateFilename',''));
        
        for i=1:divrecdata.ResultCount
            wdid=divrecdata.ResultList(i).wdid;
            wcnum=divrecdata.ResultList(i).waterClassNum;
            wwcnum=['W' num2str(wcnum)];
            
            wc=divrecdata.ResultList(i).wcIdentifier;
            
            if strcmp(wc,'1700801 S:X F: U:Q T:0 G: To:')  %REMOVE - CHANGING crooked aug station release to go to mainstem for testing
%                wc='1700801 S:1 F:1700552 U:Q T:7 G: To:1720001';  %to riv reach
%                wc='1700801 S:1 F:1700552 U:Q T:7 G: To:1700556';  %to Las Animas
                wc='1700801 S:1 F:1700552 U:Q T:7 G: To:1403526';  %exch to PR
            end
            tid=strfind(wc,'T:');
            type=str2double(wc(tid+2));
            
            measdatestr=divrecdata.ResultList(i).dataMeasDate;
            measdatestr(11)=' ';
            measdatenum=datenum(measdatestr,31);
            dateid=find(datedays==measdatenum);
            
            measinterval=divrecdata.ResultList(i).measInterval;
            measunits=divrecdata.ResultList(i).measUnits;
            
            if ~strcmp(measinterval,'Daily') | ~strcmp(measunits,'CFS')
                logm=['WARNING: skipping REST divrec ' wdid ' ' num2str(wcnum) ' with measinterval: ' measinterval ' with measunits: ' measunits];
                domessage(logm,logfilename,displaymessage,writemessage)
            elseif isempty(dateid)
                logm=['WARNING: skipping REST divrec ' wdid ' ' num2str(wcnum) ' with measdatestr: ' measdatestr];
                domessage(logm,logfilename,displaymessage,writemessage)
            elseif type==7   % | type==1 | type==4   %release, exchange, apd(?)
                WC.(ds).WC.(wwcnum).wdid=wdid;
                WC.(ds).WC.(wwcnum).wc=wc;  %will end up with last listed..
                WC.(ds).WC.(wwcnum).type=type;
                                
                if type==7
                    tostr='To:';
                else  %exchanges, apd
                    tostr='F:';
                end
                toid=strfind(wc,tostr);
                if ~isempty(toid) & length(wc)-toid>=9
                    WC.(ds).WC.(wwcnum).to=wc(toid+length(tostr):toid+length(tostr)+6); %to
                else
                    error(['water class ' waterclassstr ' doesnt have To:wdid(7) at end (or F: for exchanges), figure that out!'])
                end
                
                WC.(ds).(wds).(wwcnum).datavalues(dateid)=divrecdata.ResultList(i).dataValue;
                WC.(ds).(wds).(wwcnum).datameasdate(dateid)=measdatenum;
                WC.(ds).(wds).(wwcnum).approvalstatus{dateid}=divrecdata.ResultList(i).approvalStatus; %check?
                
                modifieddatestr=divrecdata.ResultList(i).modified;
                modifieddatestr(11)=' ';
                modifieddatenum=datenum(modifieddatestr,31);
                WC.(ds).(wds).(wwcnum).modifieddatenum(dateid)=modifieddatenum;
                maxmodified=max(maxmodified,modifieddatenum);
            end
            
        end
    catch ME
        logm=['WARNING: didnt find new records using REST for  ' reswdid ' with pullnewdivrecs: ' num2str(pullreleaserecs) ' and modified: ' datestr(WC.date.(ds).(wds).modified) ];
        domessage(logm,logfilename,displaymessage,writemessage)   
    end
    %end
    
end
    end

    WC.date.(ds).(wds).modified=maxmodified;
    end
    save(['StateTL_WC.mat'],'WC');
end


% - REMOVE - ADDING FAKE RELEASE FROM TWIN FOR TESTING
wwcnum='W119999';
WC.(ds).WC.(wwcnum).wdid='1103503';
WC.(ds).WC.(wwcnum).wc='1103503.011 S:2 F: U:Q T:7 G: To:1403526.230';
%WC.(ds).WC.(wwcnum).wc='1103503.011 S:2 F: U:Q T:7 G: To:1700540.012';
WC.(ds).WC.(wwcnum).type=7;
WC.(ds).WC.(wwcnum).to='1403526';
%WC.(ds).WC.(wwcnum).to='1700540';
WC.(ds).WD112.(wwcnum).datavalues=100*ones(1,15);
WC.(ds).WD112.(wwcnum).datameasdate=(737151:737165);


if pullstationdata==1 | pullreleaserecs>0
    logm=['Done pulling data from HBREST at: ' datestr(now) ' elapsed (DD:HH:MM:SS): ' datestr(now-reststarttime,'DD:HH:MM:SS')];    %log message
    domessage(logm,logfilename,displaymessage,writemessage)  
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DIVERSION RECORD CONVERT DAILY TO HOURLY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for wd=WDlist
    wds=['WD' num2str(wd)];
    if isfield(WC.(ds),wds)
    wwcnums=fieldnames(WC.(ds).(wds));
    WC.(ds).(wds).wwcnums=wwcnums;
    SR.(ds).(wds).wwcnums=wwcnums; %not sure if need here..

for k=1:length(wwcnums)
    wcnum=wwcnums{k};
    datavalues=WC.(ds).(wds).(wcnum).datavalues;
    if length(datavalues)<length(datedays) %front padding should be good but potentially not back padding
        datavalues(length(datedays))=0;
    end
    WC.(ds).(wds).(wcnum).release=zeros(length(rdates),1);
   
    for i=1:length(datedays)
        if     datavalues(i)>0 & i>1 && length(datedays)>i && datavalues(i-1)==0 && datavalues(i+1) > datavalues(i)
            hoursback=floor(datavalues(i)*24/datavalues(i+1));
            releasestartid2=find(rdates==WC.(ds).(wds).(wcnum).datameasdate(i+1));
            WC.(ds).(wds).(wcnum).release(releasestartid2-hoursback:releasestartid2-1,1)=datavalues(i+1);
            WC.(ds).(wds).(wcnum).release(releasestartid2-hoursback-1,1)=datavalues(i)*24-datavalues(i+1)*hoursback;
        elseif datavalues(i)>0 & i>1 && length(datedays)>i && datavalues(i+1)==0 && datavalues(i-1) > datavalues(i)
            hoursforward=floor(datavalues(i)*24/datavalues(i-1));
            releasestartid=find(rdates==WC.(ds).(wds).(wcnum).datameasdate(i));
            WC.(ds).(wds).(wcnum).release(releasestartid:releasestartid+hoursforward-1,1)=datavalues(i-1);
            WC.(ds).(wds).(wcnum).release(releasestartid+hoursforward,1)=datavalues(i)*24-datavalues(i-1)*hoursforward;
        elseif datavalues(i)>0
            releasestartid=find(rdates==WC.(ds).(wds).(wcnum).datameasdate(i));
            WC.(ds).(wds).(wcnum).release(releasestartid:releasestartid+23,1)=datavalues(i); 
        end
    end
end
    end
end


%%%%%%%%%%%%%%%%%%
% PROCESSING LOOPS
%%%%%%%%%%%%%%%%%%


    
if runriverloop==1

lastwdid=[];  %tracks last wdid/connection of processed wd reaches
SR.(ds).Rivloc.loc=[]; %just tracks location listing of processed reaches
SR.(ds).Rivloc.flowwc.wcloc=[];
SR.(ds).Gageloc.loc=[];
SR.(ds).Rivloc.length=[];


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BASEFLOW / GAGEFLOW LOOP ESTABLISHING CORRECTIONS TO ACTUAL FLOWS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%actually need to loop on change in gagediff until gagediff settles down
% first loop gagediff=0, but then after first add gagediff - but then that
% will change resulting gagediff added - but loop until settles down - then
% this is the gagediff that will be added in the admin loop..


for wd=WDlist
    wds=['WD' num2str(wd)];
    Rt=SR.(ds).(wds).R(1);
    Rb=SR.(ds).(wds).R(end);
    
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        logm=['running gageflow loop on D:' ds ' WD:' wds ' R:' rs];
        domessage(logm,logfilename,displaymessage,writemessage)

            
%         if r==Rt   %used for code work limiting reaches
%             srt=SRt;
%         else
%             srt=1;
%         end
%         if r==Rb
%             srb=SRb;
%         else
%             srb=SR.(ds).(wds).(rs).SR(end);
%         end
        
        srt=SR.(ds).(wds).(rs).SR(1);
        srb=SR.(ds).(wds).(rs).SR(end);
        
%to build loc listing that is used in output and related to total river and wc flows
for sr=SR.(ds).(wds).(rs).SR
    SR.(ds).Rivloc.loc=[SR.(ds).Rivloc.loc;[{ds} {wds} {rs} {sr} SR.(ds).(wds).(rs).wdid{sr} SR.(ds).(wds).(rs).dswdid{sr}]];
    SR.(ds).Rivloc.length=[SR.(ds).Rivloc.length SR.(ds).(wds).(rs).channellength(sr)];
    SR.(ds).(wds).(rs).locid(sr)=length(SR.(ds).Rivloc.loc(:,1));      %this will be used for flowriv and flowwc
    SR.(ds).Rivloc.flowwc.us(1:rsteps,SR.(ds).(wds).(rs).locid(sr))=0;  %variable to sum total wc release amounts within river
    SR.(ds).Rivloc.flowwc.ds(1:rsteps,SR.(ds).(wds).(rs).locid(sr))=0;  %variable to sum total wc release amounts within river
    SR.(ds).Rivloc.flowwccapture.us(1:rsteps,SR.(ds).(wds).(rs).locid(sr))=0;  %variable to sum total wc release amounts within river - for use later when reduce available to capture amts
    SR.(ds).Rivloc.flowwccapture.ds(1:rsteps,SR.(ds).(wds).(rs).locid(sr))=0;  %variable to sum total wc release amounts within river
    SR.(ds).(wds).(rs).Qusnodewc(:,sr)=zeros(rsteps,1);  %also variable to sum total wc release amounts
    SR.(ds).(wds).(rs).Quswc(:,sr)=zeros(rsteps,1);
    SR.(ds).(wds).(rs).Qdswc(:,sr)=zeros(rsteps,1);
    SR.(ds).(wds).(rs).wcreduceamt(:,sr)=zeros(rsteps,1);
    if SR.(ds).(wds).(rs).type(sr)==0
        SR.(ds).Gageloc.loc=[SR.(ds).Gageloc.loc;[{ds} {wds} {rs} {sr} SR.(ds).(wds).(rs).wdid{sr} SR.(ds).(wds).(rs).station{sr}]];
        SR.(ds).(wds).(rs).gagelocid=length(SR.(ds).Gageloc.loc(:,1));  %currently having rule that only 1 gage per reach - typically at top but not bottom
        SR.(ds).Gageloc.flowgage(:,SR.(ds).(wds).(rs).gagelocid)=SR.(ds).(wds).(rs).Qnode(:,sr);
    end
end

SR.(ds).(wds).(rs).wcreduceamtlast=zeros(rsteps,1);
        

SR.(ds).(wds).(rs).wcreducelist=[];
negnativeussumsumprevious=0;
nids1=[datestid:nhrs:rsteps];
nids2=nids1+nhrs-1;
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

change=1;changecount=0;
while change==1
    change=0;

gagediff=zeros(rsteps,1);
SR.(ds).(wds).(rs).gagediffportion=zeros(rsteps,length(SR.(ds).(wds).(rs).SR)); %guess need to restart when doing reoperation
SR.(ds).(wds).(rs).gagedifflast=zeros(rsteps,1);
SR.(ds).(wds).(rs).sraddamt=zeros(rsteps,length(SR.(ds).(wds).(rs).SR));  %this is debatable if needs to be restarted for every reoperation
SR.(ds).(wds).(rs).sraddamtus=zeros(rsteps,length(SR.(ds).(wds).(rs).SR));  %this is debatable if needs to be restarted for every reoperation
SR.(ds).(wds).(rs).sraddamtds=zeros(rsteps,length(SR.(ds).(wds).(rs).SR));  %this is debatable if needs to be restarted for every reoperation

for ii=1:iternum.(srmethod)
    
for sr=SR.(ds).(wds).(rs).SR
%    if sr==1  %use this to replace top of reach with gage flow rather than calculated flow
    if and(sr==1,r==Rt)  %initialize at top given if gage or reservoir etc
        if SR.(ds).(wds).(rs).type(1)==0                                        %if wd zone starts with gage indicated by type = 0
            Qusnode=SR.(ds).(wds).(rs).Qnode(:,1);   
        else                                                                     %otherwise will look for gage somewhere else in top reach or at top of next reach
            gageid=find(SR.(ds).(wds).(rs).type==0);
            if ~isempty(gageid)
                Qds=SR.(ds).(wds).(rs).Qnode(:,gageid(1));
                srbb=gageid(1)-1;
            else
                if r==Rb | SR.(ds).(wds).(['R' num2str(r+1)]).type~=0  %r assuming numerical reach order here
                    error(['STOP - for WD:' wds ' didnt find gage to initialize flow either in top reach or start of second reach'])
                end
                Qds=SR.(ds).(wds).(['R' num2str(r+1)]).Qnode(:,1);
                srbb=srb;
            end
            for sri=srbb:-1:srt                             %adding back in any intermediate diversions; but currently NOT CONSIDERING EVAPORATION or transittime or gain/losscorrection!!! currently need evapfactor=0 and gain=-999 in these (fix/expand?)
                type=SR.(ds).(wds).(rs).type(1,sri);
                losspercent=SR.(ds).(wds).(rs).losspercent(sri);
                Qus=Qds*(1+losspercent/100);
                Qnode=SR.(ds).(wds).(rs).Qnode(:,sri);
                Qusnode=Qus-type*Qnode;
                Qds=Qusnode;
            end
            
        end
    elseif sr==1
         Qusnode=SR.(ds).(wds).(['R' num2str(r-1)]).Qds(:,end);
    end
    
    %type -1=outflow/1=inflow/0=gage etc
    type=SR.(ds).(wds).(rs).type(1,sr);
    
    %this block seeing if inflow should be defined from by a modeled branch flow at a wdid connection point
    if type==1 && strcmp(SR.(ds).(wds).(rs).station{sr},'NaN')  && ~isempty(lastwdid)
        branchid=find(strcmp(lastwdid(:,1),SR.(ds).(wds).(rs).wdid(sr)));
        if ~isempty(branchid)
            SR.(ds).(wds).(rs).Qnode(:,sr)=SR.(ds).(lastwdid{branchid,3}).(lastwdid{branchid,4}).Qds(:,lastwdid{branchid,5});
        end
    else
        branchid=[];
    end
    
    Qnode=SR.(ds).(wds).(rs).Qnode(:,sr);  %if branchid above this will be coming from branch
    %new setup - going from Qusnode to Qus (after usnodes) then to Qds
    Qus=Qusnode+type*Qnode;

    %%%%%%%%%%%%%%%%%%%%%%%%%%
    % INADVERTANT DIVERSIONS - ACTION 3a
    % after know what totalwcreleases are and have potentially reduced those where indicated by gage
    % then if native (river-totalwcreleases) negative at internal then increase river flow at that node
    % thinking that internal portion isnt as pure as length based ratio
    if inadv3a_increaseint == 1
    Qusnative=Qus-SR.(ds).(wds).(rs).Quswc(:,sr);
    negnativeus=-1*min(0,Qusnative);
    negnativeussum=sum(negnativeus(datestid:end,1));
    if sr>1 && negnativeussum>0
        if strcmp(wds,'WD17') & strcmp(rs,'R3') & sr==3
            error('stop')
        end
        addamt=zeros(rsteps,1);
        for i=1:length(nids1)
            negnatussumi=sum(negnativeus(nids1(i):nids2(i),1));
            if negnatussumi>0
               addamt(nids1(i):nids2(i),1)=negnatussumi/nhrs*ones(nhrs,1);
            end
        end
        SR.(ds).(wds).(rs).sraddamt(:,sr-1)=SR.(ds).(wds).(rs).sraddamt(:,sr-1)+addamt; %looking at Qus - adding to sraddamt/Qds of previous sr
        SR.(ds).(wds).(rs).Qds(:,sr-1)=SR.(ds).(wds).(rs).Qds(:,sr-1)+addamt;
        Qusnode=Qusnode+addamt;
        Qus=Qus+addamt;
        SR.(ds).(wds).(rs).gagediffportion(:,sr)=SR.(ds).(wds).(rs).gagediffportion(:,sr)-addamt; %this is needed only because gagediff isn't changed on last iteration loop..pushes adjustment from previous sr to current
    end
    end
    
    if ii>1 && inadv3b_increaseint == 1
        Qus4=max(Qus,SR.(ds).(wds).(rs).Quswc(:,sr));
        addamt=Qus4-Qus;
        addamtsum=sum(addamt(datestid:end,1));
        if addamtsum>0
            logm=['To avoid internal negative native flow, added US: ' num2str(addamtsum) ' for wd:' wds ' r:' rs ' sr:' num2str(sr)];
            domessage(logm,logfilename,displaymessage,writemessage)
            SR.(ds).(wds).(rs).sraddamtus(:,sr)=addamt;
            Qus=Qus4;
        end        
    end
    
    Qus=max(0,Qus);
    

    
    
    if gain==-999   %gain=-999 to not run transittime but can have loss percent 
        losspercent=SR.(ds).(wds).(rs).losspercent(sr);
        Qds=Qus*(1-losspercent/100);
        celerity=SR.(ds).(wds).(rs).celeritya(sr)*max(minc,(Qus+Qds)/2).^SR.(ds).(wds).(rs).celerityb(sr);
        dispersion=SR.(ds).(wds).(rs).dispersiona(sr)*max(minc,(Qus+Qds)/2).^SR.(ds).(wds).(rs).dispersionb(sr);
    else
%         celerity=SR.(ds).(wds).(rs).celeritya(sr)*max(minc,Qus).^SR.(ds).(wds).(rs).celerityb(sr);
%         dispersion=SR.(ds).(wds).(rs).dispersiona(sr)*max(minc,Qus).^SR.(ds).(wds).(rs).dispersionb(sr);
        if strcmp(srmethod,'j349')
            gainportion=gain*SR.(ds).(wds).(rs).reachportion(sr);
            Qus1=max(minj349,Qus);
            [Qds,celerity,dispersion]=runj349f(ds,wds,rs,sr,Qus1,gainportion,rdays,rhours,rsteps,j349dir,-999,-999);
            Qds=Qds-(Qus1-Qus); %timing won't be perfect for this but keeps celerity exactly calculated above (may want to do as just pure addition/subtraction)
        elseif strcmp(srmethod,'muskingum')
            [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,-999,-999);
        end
        
    end
    Qds=max(0,Qds);
        
    Qavg=(max(Qus,minc)+max(Qds,minc))/2;
    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
    evap=SR.(ds).(wds).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr); %EvapFactor = 0 to not have evap 
    Qds=Qds-evap+SR.(ds).(wds).(rs).gagediffportion(:,sr)+SR.(ds).(wds).(rs).sraddamt(:,sr);
%    Qds=Qds-evap+gagediff*SR.(ds).(wds).(rs).reachportion(sr);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    % INADVERTANT DIVERSIONS - ACTION 3b
    % also checking at Qds - shouldnt happen here much if at all but I guess just in case
    if inadv3a_increaseint == 1
    Qdsnative=Qds-SR.(ds).(wds).(rs).Qdswc(:,sr);
    negnativeds=-1*min(0,Qdsnative);
    negnativedssum=sum(negnativeds(datestid:end,1));
    if sr<srb && negnativedssum>0
        if strcmp(wds,'WD17') & strcmp(rs,'R3') & sr==3
            error('stop')
        end
        addamt=zeros(rsteps,1);
        for i=1:length(nids1)
            negnatdssumi=sum(negnativeds(nids1(i):nids2(i),1));
            if negnatdssumi>0
               addamt(nids1(i):nids2(i),1)=negnatdssumi/nhrs*ones(nhrs,1);
            end
        end
        SR.(ds).(wds).(rs).sraddamt(:,sr)=SR.(ds).(wds).(rs).sraddamt(:,sr)+addamt; %looking at Qds - adding to same sr
        Qds=Qds+addamt;
        SR.(ds).(wds).(rs).gagediffportion(:,sr+1)=SR.(ds).(wds).(rs).gagediffportion(:,sr+1)-addamt; %this is needed only because gagediff isn't changed on last iteration loop..pushes adjustment from current sr to next
    end
    end
    
    if ii>1 && inadv3b_increaseint == 1
        Qds4=max(Qds,SR.(ds).(wds).(rs).Qdswc(:,sr));
        addamt=Qds4-Qds;
        addamtsum=sum(addamt(datestid:end,1));
        if addamtsum>0
            logm=['To avoid internal negative native flow, added DS: ' num2str(addamtsum) ' for wd:' wds ' r:' rs ' sr:' num2str(sr)];
            domessage(logm,logfilename,displaymessage,writemessage)
            SR.(ds).(wds).(rs).sraddamtds(:,sr)=addamt;
            Qds=Qds4;
        end
    end

    Qds=max(0,Qds);
    
%    SR.(ds).(wds).(rs).gagediffportion(:,sr)=gagediff*SR.(ds).(wds).(rs).reachportion(sr);
    SR.(ds).(wds).(rs).evap(:,sr)=evap;
    SR.(ds).(wds).(rs).Qusnode(:,sr)=Qusnode;    
    SR.(ds).(wds).(rs).Qus(:,sr)=Qus;
    SR.(ds).(wds).(rs).Qds(:,sr)=Qds;
    SR.(ds).(wds).(rs).celerity(:,sr)=celerity;    
    SR.(ds).(wds).(rs).dispersion(:,sr)=dispersion;    
    SR.(ds).Rivloc.flowriv.us(:,SR.(ds).(wds).(rs).locid(sr))=Qus;
    SR.(ds).Rivloc.flowriv.ds(:,SR.(ds).(wds).(rs).locid(sr))=Qds;
%    SR.(ds).Rivloc.celerity(:,SR.(ds).(wds).(rs).locid(sr))=celerity;   

    if SR.(ds).(wds).(rs).type(sr)==0
        SR.(ds).Gageloc.flowriv(:,SR.(ds).(wds).(rs).gagelocid)=Qusnode; %or Qus
    end

    Qusnode=Qds;
end %sr

SR.(ds).(wds).(rs).gagediff=gagediff;  %this one that was applied

if or(srt>1,srb<SR.(ds).(wds).(rs).SR(end))
    gagediffavg=0;  %if partial reach so don't have gage to gage, then don't do gain iteration?
else
    if r==Rb  %last reach will not end in gage
        gagediffavg=0;
        gagediff=0;        
    else
        Qdsgage=SR.(ds).(wds).(['R' num2str(r+1)]).Qnode(:,1);
        gagediffnew=Qdsgage-Qds;
        gagediffchange=gagediffnew-gagediff;
        gagediffavg=gagediffchange(datestid-1,1);
        gagediff=gagediffnew+gagediff;

        if ii<iternum.(srmethod)
            SR.(ds).(wds).(rs).gagediffportion=gagediff*SR.(ds).(wds).(rs).reachportion;
%             %reverse gagediff with evaporation to determine portion to apply within each reach
%             gagediffds=gagediff;
%             exchtimerem=0;
%             for sr=srb:-1:srt
%                 gagediffportion=gagediffds*SR.(ds).(wds).(rs).reachportion(sr)/sum(SR.(ds).(wds).(rs).reachportion(1:sr));
%                 SR.(ds).(wds).(rs).gagediffportion(:,sr)=gagediffportion;
%                 celerity=SR.(ds).(wds).(rs).celerity(:,sr);
%                 if or(strcmp(srmethod,'j349'),strcmp(srmethod,'muskingum'))
%                     [gagediffus,exchtimerem,revcelerity]=reversecelerity(ds,wds,rs,sr,gagediffds,exchtimerem,rhours,rsteps,celerity); %using river celerity
%                 else
%                     gagediffus=gagediffds;
%                 end
%                 gagediffus=gagediffus-gagediffportion;
%                 Qavg=(max(0,gagediffus)+max(0,gagediffds))/2;  %hopefully this doesn't smeer timing
%                 width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
%                 evap=SR.(ds).(wds).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
%                 gagediffus=gagediffus+evap;
%                 gagediffds=gagediffus;
%             end
        elseif adjustlastsrtogage==1
            SR.(ds).(wds).(rs).gagedifflast=gagediffnew;
            SR.(ds).(wds).(rs).Qds(:,end)=Qdsgage;
            SR.(ds).Rivloc.flowriv.ds(:,SR.(ds).(wds).(rs).locid(sr))=Qdsgage;
        end
        

    end
    SR.(ds).(wds).(rs).gain=[SR.(ds).(wds).(rs).gain gain];
    SR.(ds).(wds).(rs).gagediffseries(:,ii)=gagediff;
end

end %ii iteration on gainchange

end %change
    end %r
    lastwdid=[lastwdid;SR.(ds).(wds).(rs).dswdid{sr} {ds} {wds} {rs} {sr}];
end %wd

save([basedir 'StateTL_SR' srmethod '.mat'],'SR');
elseif runwcloop==1 | runcalibloop==1
    load([basedir 'StateTL_SR' srmethod '.mat']);  
end %river/gage loop


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% (INTERNAL) ADMIN LOOP FOR WATERCLASSES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ROUTING OF WATER CLASSES
%   new - put above main wc loops build WCloc list first
%   primarily for inadvertant diversion correction so if have to iterate don't have to iterate on this portion
%
%  WATCH!-currently requires WDID list to be in spatial order to know whats going upstream
%         may want to change that to ordered lists 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


if runwcloop==1

SR.(ds).WCloc.wslist=[];
SR.(ds).WCloc.Rloc=[];

for wd=WDlist
    wds=['WD' num2str(wd)];
    if ~isfield(SR.(ds).(wds),'wwcnums')
        logm=['no water classes identified (admin loop not run) for D:' ds ' WD:' wds];
        domessage(logm,logfilename,displaymessage,writemessage)
    else
    wwcnums=SR.(ds).(wds).wwcnums;
    Rt=SR.(ds).(wds).R(1);
    Rb=SR.(ds).(wds).R(end);
    logm=['running admin loop to pre-establish routing for D:' ds ' WD:' wds];
    domessage(logm,logfilename,displaymessage,writemessage)


for w=1:length(wwcnums)
ws=wwcnums{w};
% if ~isfield(SR.(ds).WCloc,ws)  %if here will include missing WCs as empty
%     SR.(ds).WCloc.wslist=[SR.(ds).WCloc.wslist,{ws}];
%     SR.(ds).WCloc.(ws)=[];
% end

wdinwdidlist=find([SR.(ds).WDID{:,3}]==wd);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   the next/first block is looking for water classes passed from another WDreach
%   these could have been passed from an upstream release or
%   from an exchange that was first routed down an upstream reach

parkwcid=0;
if isfield(SR.(ds).(wds),'park')
    parkwcid=find(strcmp(SR.(ds).(wds).park(:,1),ws));
end
if parkwcid~=0
    wdidfrom=SR.(ds).(wds).park{parkwcid,2};
    wdidfromid=SR.(ds).(wds).park{parkwcid,3};
    fromWDs=SR.(ds).(wds).park{parkwcid,4};
    fromRs=SR.(ds).(wds).park{parkwcid,5};
    fromsr=SR.(ds).(wds).park{parkwcid,6};
else  %if not parked
    wdidfrom=WC.(ds).WC.(ws).wdid;
    wdidfromid=intersect(find(strcmp(SR.(ds).WDID(:,1),wdidfrom)),wdinwdidlist);
end
    
wdidto=WC.(ds).WC.(ws).to;
wdidtoid=find(strcmp(SR.(ds).WDID(:,1),wdidto));
wdidtoidwd=intersect(wdidtoid,wdinwdidlist);

parkwdidid=0;
exchtype=0;
if isempty(wdidtoid)                                    %wdid To: listed in divrecs but cant find To:wdid in network list of wdids
    wdidtoid=wdidfromid;
    logm=['WARNING: not routing (either exchange or missing) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ];
    domessage(logm,logfilename,displaymessage,writemessage)
else
    if ~isfield(SR.(ds).WCloc,ws)
        SR.(ds).WCloc.wslist=[SR.(ds).WCloc.wslist,{ws}];
        SR.(ds).WCloc.(ws).wc=WC.(ds).WC.(ws).wc;
        SR.(ds).WCloc.(ws).wdid=WC.(ds).WC.(ws).wdid;
        SR.(ds).WCloc.(ws).type=WC.(ds).WC.(ws).type;
        SR.(ds).WCloc.(ws).to=WC.(ds).WC.(ws).to;
        SR.(ds).WCloc.(ws).loc=[];
        SR.(ds).WCloc.(ws).srtime=0;        
        
    end
    dswdidids=find(wdidtoid>=wdidfromid);
    if ~isempty(dswdidids)                              %DS RELEASE TO ROUTE (could include US Exchange that is first routed to end of WD)
        if SR.(ds).WDID{wdidtoid(dswdidids(1)),3} == wd %DS release located in same WD - so route to first node that is at or below release point
            wdidtoid=wdidtoid(dswdidids(1));            %if multiple points (could be multiple reach defs or same wdid at top of next ds reach)
        else                                            %DS release located in different WD - so route to bottom of WD and park into next WD
            wdidtoid=wdinwdidlist(end);
            parkwdidid=find(strcmp(SR.(ds).WDID(:,1),SR.(ds).WDID(wdidtoid,1)));
            parkwdidid=setdiff(parkwdidid,wdinwdidlist);
            parktype=1;  %1 push DS to end of reach
            logm=['routing: ' ws ' ' WC.(ds).WC.(ws).wc ' To:' wdidto ' external to WD reach, routing to end of WD reach'];
            domessage(logm,logfilename,displaymessage,writemessage)
        end
    elseif isempty(dswdidids)                             %US EXCHANGE RELEASE - ONLY ROUTING HERE IF FIRST DOWN TO MID-WD BRANCH
        wdidtoidnotwd=setdiff(wdidtoid,wdinwdidlist);
        branchid=find([SR.(ds).(wds).branch{:,1}]==SR.D2.WDID{wdidtoidnotwd,3});

        if ~isempty(branchid)      %us exchange from DS branch within WD (exchtype=3)
            exchtype=3;
            SR.(ds).EXCH.(ws).wdidtoid=wdidtoid;
            SR.(ds).EXCH.(ws).WDto=SR.(ds).WDID{wdidtoid(1),3};
            wdidbranch=SR.(ds).(wds).branch{branchid,2};
            wdidtoids=find(strcmp(SR.(ds).WDID(:,1),wdidbranch));
            parkwdidid=setdiff(wdidtoids,wdinwdidlist);
            wdidtoid=intersect(wdidtoids,wdinwdidlist);
            parktype=2;  %2 push DS releases to internal node
            SR.(ds).EXCH.(ws).wdidfromid=parkwdidid;
            SR.(ds).EXCH.(ws).WDfrom=SR.(ds).WDID{parkwdidid,3};
            SR.(ds).EXCH.(ws).exchtype=3;            
            logm=['routing: ' ws ' ' WC.(ds).WC.(ws).wc ' To Confluence:' wdidbranch ' US exchange first routing with TL to internal confluence point within WD reach'];
            domessage(logm,logfilename,displaymessage,writemessage)
            logm=['Exchange: (external to WD) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ];
            domessage(logm,logfilename,displaymessage,writemessage)
         
        elseif ~isempty(wdidtoidwd)                    %us exchange within WD (exchtype=1)
            exchtype=1;
            SR.(ds).EXCH.(ws).wdidtoid=wdidtoidwd(end);  %last in list in case multiple reach listing (will go to lowest) - remember that wdid is listed "above" subreach so sr will be next one after
            SR.(ds).EXCH.(ws).wdidfromid=wdidfromid;
            SR.(ds).EXCH.(ws).WDfrom=wd;
            SR.(ds).EXCH.(ws).WDto=wd;
            SR.(ds).EXCH.(ws).exchtype=1;
            wdidtoid=wdidfromid;  %leaving it there
            logm=['Exchange: (external to WD) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ];
            domessage(logm,logfilename,displaymessage,writemessage)
        else                                           %us exchange in different WD (exchtype=2)
            exchtype=2;
            SR.(ds).EXCH.(ws).wdidtoid=wdidtoid(end);
            SR.(ds).EXCH.(ws).wdidfromid=wdidfromid;
            SR.(ds).EXCH.(ws).WDfrom=wd;
            SR.(ds).EXCH.(ws).WDto=SR.(ds).WDID{wdidtoid(1),3};
            SR.(ds).EXCH.(ws).exchtype=2;
            wdidtoid=wdidfromid;
%            wdidtoid=wdinwdidlist(end);
            logm=['Exchange: (external to WD) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ];
            domessage(logm,logfilename,displaymessage,writemessage)
        end

    end       
end


WDtr=SR.(ds).WDID{wdidfromid,3};
WDbr=SR.(ds).WDID{wdidtoid,3};
Rtr=SR.(ds).WDID{wdidfromid,4};
Rbr=SR.(ds).WDID{wdidtoid,4};
SRtr=SR.(ds).WDID{wdidfromid,5}+SR.(ds).WDID{wdidfromid,6};  %new ordering - if col6=1 then sr=dswdid / col6=0 then sr=uswdid, so for from sr add 0 or 1 to move to top of next sr
SRbr=SR.(ds).WDID{wdidtoid,5};


if wdidtoid==wdidfromid   %EXCHANGES (or missing releases)
    if exchtype>0
        SR.(ds).WCloc.Rloc=[SR.(ds).WCloc.Rloc;[{ws},{ds},{wds},{['R' num2str(Rtr)]},{SRtr},{SRbr},{Rtr},{Rbr},{SRtr},{SRbr},{wdidfrom},{wdidto},{wdidfromid},{wdidtoid}]];
    end
else
    
wd=WDtr;
    wds=['WD' num2str(wd)];
    for r=Rtr:Rbr
        rs=['R' num2str(r)];
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
        SR.(ds).WCloc.Rloc=[SR.(ds).WCloc.Rloc;[{ws},{ds},{wds},{rs},{srt},{srb},{Rtr},{Rbr},{SRtr},{SRbr},{wdidfrom},{wdidto},{wdidfromid},{wdidtoid}]];

for sr=srt:srb
    % WCloc.ws listing locations of WC as cell/strings (sr/lsr/type(1-release/-1 - exch) is num)
    lsr=SR.(ds).(wds).(rs).subreachid(sr);
    SR.(ds).WCloc.(ws).loc=[SR.(ds).WCloc.(ws).loc;[{ds},{wds},{rs},{sr},{lsr},{1},{SR.(ds).(wds).(rs).wdid{sr}},{SR.(ds).(wds).(rs).dswdid{sr}}]];
    
end %sr

    end %r
%end %wd
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% parking - transfering waterclass from one WD to another
%   for releases, ds WDreach should then pick up, for exchanges waits for exchange loop
if parkwdidid ~= 0  %placing park - place wcnum and park parameters in downstream WDreach
    SR.(ds).(wds).(ws).parkwdidid=parkwdidid; %this is needed for process/admin loop
    parkwdid=SR.(ds).WDID{parkwdidid,1};
    parkWD=SR.(ds).WDID{parkwdidid,3};
    pwds=['WD' num2str(parkWD)];
    parkR=SR.(ds).WDID{parkwdidid,4};
    prs=['R' num2str(parkR)];
    psr=SR.(ds).WDID{parkwdidid,5};
    
    lsr=SR.(ds).(wds).(rs).subreachid(sr);
%    parklsr=SR.(ds).(['WD' num2str(SR.(ds).WDID{wdidtoid,3})]).(['R' num2str(SR.(ds).WDID{wdidtoid,4})]).subreachid(SR.(ds).WDID{wdidtoid,5}); %this should also work - keep in case above breaks down

    if ~isfield(SR.(ds).(pwds),'wwcnums')
        SR.(ds).(pwds).wwcnums={ws};
    else
        SR.(ds).(pwds).wwcnums=[SR.(ds).(pwds).wwcnums;{ws}];
    end    
    if ~isfield(SR.(ds).(pwds),'park')
        SR.(ds).(pwds).park=[{ws},{parkwdid},{parkwdidid},{wds},{rs},{sr},{parktype},{lsr}];  %this is destination wdidid but source wds,rs,sr
    else
        SR.(ds).(pwds).park=[SR.(ds).(pwds).park;{ws},{parkwdid},{parkwdidid},{wds},{rs},{sr},{parktype},{lsr}];        
    end
  
end

end %j - waterclass
end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PRIMARY WATER CLASS /  ADMIN LOOP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% for i=1:length(SR.(ds).(wds).(rs).wcreducelist)
%     ws=SR.(ds).(wds).(rs).wcreducelist{i};
%     SR.(ds).(wds).(rs).(ws).wcreduce=zeros(1,length(SR.(ds).(wds).(rs).SR));
%     SR.(ds).(wds).(rs).(ws).wcreduceamt=zeros(rsteps,length(SR.(ds).(wds).(rs).SR));
% end

for wd=WDlist
    wds=['WD' num2str(wd)];
    Rt=SR.(ds).(wds).R(1);
    Rb=SR.(ds).(wds).R(end);
    logm=['running admin loop for D:' ds ' WD:' wds];
    domessage(logm,logfilename,displaymessage,writemessage)

    
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        logm=['running admin loop on D:' ds ' WD:' wds ' R:' rs];
        domessage(logm,logfilename,displaymessage,writemessage)

changewc=1;changewccount=0;
while changewc==1
    changewccount=changewccount+1;
    changewc=0;
    if changewccount==1
        logm=['running admin loop on D:' ds ' WD:' wds ' R:' rs];
        domessage(logm,logfilename,displaymessage,writemessage)
    else
        logm=['Reoperating admin loop, count: ' num2str(changewccount) ' on D:' ds ' WD:' wds ' R:' rs];
        domessage(logm,logfilename,displaymessage,writemessage)
    end

wwcnumids=intersect(find(strcmp(SR.(ds).WCloc.Rloc(:,3),wds)),find(strcmp(SR.(ds).WCloc.Rloc(:,4),rs)));
wwcnums=SR.(ds).WCloc.Rloc(wwcnumids,1);

%will refresh to zero every time reoperate
for sr=SR.(ds).(wds).(rs).SR
SR.(ds).(wds).(rs).QSRadd(:,sr)=zeros(rsteps,1);
SR.(ds).(wds).(rs).Qusnodewc(:,sr)=zeros(rsteps,1);  %also variable to sum total wc release amounts
SR.(ds).(wds).(rs).Quswc(:,sr)=zeros(rsteps,1);
SR.(ds).(wds).(rs).Qdswc(:,sr)=zeros(rsteps,1);
SR.(ds).Rivloc.flowwc.us(1:rsteps,SR.(ds).(wds).(rs).locid(sr))=0;  %variable to sum total wc release amounts within river - not sure if need now with above
SR.(ds).Rivloc.flowwc.ds(1:rsteps,SR.(ds).(wds).(rs).locid(sr))=0;  %variable to sum total wc release amounts within river
end

for w=1:length(wwcnumids)
ws=SR.(ds).WCloc.Rloc{wwcnumids(w),1};
srtt=SR.(ds).WCloc.Rloc{wwcnumids(w),5};
srtb=SR.(ds).WCloc.Rloc{wwcnumids(w),6};
Rtr=SR.(ds).WCloc.Rloc{wwcnumids(w),7};
Rtb=SR.(ds).WCloc.Rloc{wwcnumids(w),8};
SRtr=SR.(ds).WCloc.Rloc{wwcnumids(w),9};
SRtb=SR.(ds).WCloc.Rloc{wwcnumids(w),10};
wdidfrom=SR.(ds).WCloc.Rloc{wwcnumids(w),11};
wdidto=SR.(ds).WCloc.Rloc{wwcnumids(w),12};
wdidfromid=SR.(ds).WCloc.Rloc{wwcnumids(w),13};
wdidtoid=SR.(ds).WCloc.Rloc{wwcnumids(w),14};

logm=['running admin loop on waterclass:' ws ' ' WC.D2.WC.(ws).wc];
domessage(logm,logfilename,displaymessage,writemessage)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% If r is top reach within WD get original or parked release

if r==Rtr
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %look to see if "parked" water passed from upstream WD
    parkwcid=0;
    if isfield(SR.(ds).(wds),'park')
        parkwcid=find(strcmp(SR.(ds).(wds).park(:,1),ws));
    end
    if parkwcid~=0
        fromWDs=SR.(ds).(wds).park{parkwcid,4};
        fromRs=SR.(ds).(wds).park{parkwcid,5};
        fromsr=SR.(ds).(wds).park{parkwcid,6};
        release=SR.(ds).(fromWDs).(fromRs).(ws).Qdsrelease(:,fromsr);
    else  %if not parked
        release=WC.(ds).(wds).(ws).release;
    end
else  %new - OK??? - WATCH
%    Qusnodepartial=SR.(ds).(wds).(['R' num2str(r-1)]).(ws).Qdspartial(:,end);
    release=SR.(ds).(wds).(['R' num2str(r-1)]).(ws).Qdsrelease(:,end);  %when restarting a r-reach dont include effect of previous SRadd
    Qusnodepartial=SR.(ds).(wds).(rs).Qusnode(:,1)-release;
end  
    
        
if wdidtoid==wdidfromid   %EXCHANGES
    rsnew=['R' num2str(SR.(ds).WDID{wdidfromid,4})];
    sr=SR.(ds).WDID{wdidfromid,5};
    exchtype=SR.(ds).EXCH.(ws).exchtype;
    if exchtype==1 | exchtype==2  %for us exchanges putting into Qds of reach above node rather than Qus of reach below node
        wdinwdidlist=find([SR.(ds).WDID{:,3}]==wd);
        wdsnew=wds;
        if SR.(ds).WDID{wdidfromid,6}==0 %uswdid/top of wd - push into us wd
            wdidnewid=setdiff(find(strcmp(SR.(ds).WDID(:,1),wdidfrom)),wdinwdidlist);
            wdsnew=['WD' num2str(SR.(ds).WDID{wdidnewid,3})];
            rsnew=['R' num2str(SR.(ds).WDID{wdidnewid,4})];
            sr=SR.(ds).WDID{wdidnewid,5};
            SR.(ds).EXCH.(ws).wdidfromid=wdidnewid;
            SR.(ds).EXCH.(ws).WDfrom=SR.(ds).WDID{wdidnewid,3};
        end 
        lsr=SR.(ds).(wdsnew).(rsnew).subreachid(sr);
        SR.(ds).(wdsnew).(rsnew).(ws).Qusnoderelease(:,sr)=zeros(rsteps,1);
        SR.(ds).(wdsnew).(rsnew).(ws).Qusrelease(:,sr)=zeros(rsteps,1);
        SR.(ds).(wdsnew).(rsnew).(ws).Qdsrelease(:,sr)=-1*release;
        SR.(ds).(wdsnew).(ws).Qusnoderelease(:,lsr)=zeros(rsteps,1);
        SR.(ds).(wdsnew).(ws).Qusrelease(:,lsr)=zeros(rsteps,1);
        SR.(ds).(wdsnew).(ws).Qdsrelease(:,lsr)=-1*release;
%        SR.(ds).WCloc.(ws)=[SR.(ds).WCloc.(ws);[{ds},{wdsnew},{rs},{sr},{lsr},{2}]];  %type=1release,2exchange - instead putting this in in exchange loop
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %if want to do something with missing releases (ie put into Qusrelease) put an else here
        
    end
    
else
for sr=srtt:srtb
    if and(sr==SRtr,r==Rtr)
        Qusnodepartial=SR.(ds).(wds).(rs).Qus(:,sr); %this makes Qusnoderelease=0
        if pred==1 %predictive case
            Quspartial=SR.(ds).(wds).(rs).Qus(:,sr)+release;
        else  %administrative case
            Quspartial=SR.(ds).(wds).(rs).Qus(:,sr)-release;
        end
    else
        type=SR.(ds).(wds).(rs).type(1,sr);
        Qnode=SR.(ds).(wds).(rs).Qnode(:,sr);
        Quspartial=Qusnodepartial+type*Qnode+SR.(ds).(wds).(rs).sraddamtus(:,sr);
    end
    %reduce WC based on negative native at gage
%    if isfield(SR.(ds).(wds).(rs),ws) && isfield(SR.(ds).(wds).(rs).(ws),'wcreduce') && SR.(ds).(wds).(rs).(ws).wcreduce(sr)==1
    if sum(strcmp(SR.(ds).(wds).(rs).wcreducelist,ws))>0 && inadv2_reducewcpushUS==1
        Quspartial=Quspartial+SR.(ds).(wds).(rs).(ws).wcreduceamt(:,sr);
        release=release-SR.(ds).(wds).(rs).(ws).wcreduceamt(:,sr);        
    end
    
    gain=SR.(ds).(wds).(rs).gain(end);
    if pred==1
        celerity=SR.(ds).(wds).(rs).celeritya(sr)*max(minc,Quspartial).^SR.(ds).(wds).(rs).celerityb(sr);
        dispersion=SR.(ds).(wds).(rs).dispersiona(sr)*max(minc,Quspartial).^SR.(ds).(wds).(rs).dispersionb(sr);
    else
        celerity=SR.(ds).(wds).(rs).celerity(:,sr);
        dispersion=SR.(ds).(wds).(rs).dispersion(:,sr);
    end
    
    QSRadd=-1*(min(0,Quspartial));  %amount of "potentially" negative native
    Quspartial=max(0,Quspartial);  %WARNING: this by itself this would cut Qusrelease (waterclass) to Qus (gage) (if exceeds)
        
    if gain==-999   %gain=-999 to not run timing but can still have loss percent 
        losspercent=SR.(ds).(wds).(rs).losspercent(sr);
        Qdspartial=Quspartial*(1-losspercent/100);
    else
        if strcmp(srmethod,'j349')
            gainportion=gain*SR.(ds).(wds).(rs).reachportion(sr);
            [Qdspartial,celeritypartial,dispersionpartial]=runj349f(ds,wds,rs,sr,Quspartial+minj349,gainportion,rdays,rhours,rsteps,j349dir,celerity,dispersion); %celerity/disp based on gage flows / +minflow because cant have zero flow
            Qdspartial=Qdspartial-minj349;
        elseif strcmp(srmethod,'muskingum')
            [Qdspartial,celeritypartial,dispersionpartial]=runmuskingum(ds,wds,rs,sr,Quspartial,rhours,rsteps,celerity,dispersion);
        end
    end
    Qdspartial=max(0,Qdspartial);
    Qavg=(max(Quspartial,minc)+max(Qdspartial,minc))/2;
    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
    evap=SR.(ds).(wds).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
    Qdspartial=Qdspartial-evap+SR.(ds).(wds).(rs).gagediffportion(:,sr)+SR.(ds).(wds).(rs).sraddamt(:,sr)+SR.(ds).(wds).(rs).sraddamtds(:,sr);
%    if adjustlastsrtogage==1 && sr==srtb
    if adjustlastsrtogage==1 && sr==SR.(ds).(wds).(rs).SR(end)
        Qdspartial=Qdspartial+SR.(ds).(wds).(rs).gagedifflast;
    end
    
    
    if sum(strcmp(SR.(ds).(wds).(rs).wcreducelist,ws))>0 && inadv2_reducewcpushUS==1 && sr==SR.(ds).(wds).(rs).SR(end)
        Qdspartial=Qdspartial+SR.(ds).(wds).(rs).(ws).wcreduceamtlast;
    end

    
    Qdspartial=max(0,Qdspartial);    

    SR.(ds).(wds).(rs).(ws).Qusnodepartial(:,sr)=Qusnodepartial;
    SR.(ds).(wds).(rs).(ws).Quspartial(:,sr)=Quspartial;
    SR.(ds).(wds).(rs).(ws).Qdspartial(:,sr)=Qdspartial;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % calc of WC release amount from river - partial
    if pred~=1  %if not prediction, wc amounts are gage amount - "partial" (gage-wcrelease) amount 
%         Qusnoderelease=SR.(ds).(wds).(rs).Qusnode(:,sr)-Qusnodepartial+SR.(ds).(wds).(rs).QSRaddcum(:,sr)-QSRadd; %for usnode, would not add QSR on first reach that QSR occurred
%         Qusrelease=SR.(ds).(wds).(rs).Qus(:,sr)-Quspartial+SR.(ds).(wds).(rs).QSRaddcum(:,sr);
%         Qdsrelease=SR.(ds).(wds).(rs).Qds(:,sr)-Qdspartial+SR.(ds).(wds).(rs).QSRaddcum(:,sr);
        Qusnoderelease=SR.(ds).(wds).(rs).Qusnode(:,sr)-Qusnodepartial; %for usnode, would not add QSR on first reach that QSR occurred
        Qusrelease=SR.(ds).(wds).(rs).Qus(:,sr)-Quspartial;
        Qdsrelease=SR.(ds).(wds).(rs).Qds(:,sr)-Qdspartial;
    else        %if prediction, wc amounts are "partial" (gage+wcrelease) amount - gage amount 
        Qusnoderelease=Qusnodepartial-SR.(ds).(wds).(rs).Qusnode(:,sr);
        Qusrelease=Quspartial-SR.(ds).(wds).(rs).Qus(:,sr);
        Qdsrelease=Qdspartial-SR.(ds).(wds).(rs).Qds(:,sr);
    end
    
    Qusnoderelease=max(0,Qusnoderelease);
    Qusrelease=max(0,Qusrelease);  %this seems to happen in muskingham - reason?? - need to worry about lost negative amount??
    Qdsrelease=max(0,Qdsrelease);
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    % INADVERTANT DIVERSIONS - ACTION 1
    % if individual Qusrelease (waterclass) exceeds Qus (gage-based) at interior node 
    % temporary measure to avoid cuting Qusrelease until reoperations deal with it
    % as could be that we just arent estimating interior node amount correctly given return flows etc
    SR.(ds).(wds).(rs).QSRadd(:,sr)=SR.(ds).(wds).(rs).QSRadd(:,sr)+QSRadd;  %this is going to get overwritten by subsequent water classes (??)
%    SR.(ds).(wds).(rs).QSRaddcum(:,1:sr)=cumsum(SR.(ds).(wds).(rs).QSRadd(:,1:sr),2);  %this is what might get added back in as effect would go downstream   
    QSRaddsum=sum(QSRadd(datestid:end));
    if QSRaddsum>0 && inadv1_letwaterby==1 %if internal correction so native doesnt go negate
        release=max(0,release);
        if gain==-999
            dsrelease=release;
            losspercent=SR.(ds).(wds).(rs).losspercent(sr);
            dsrelease=release*(1-losspercent/100);
        elseif strcmp(srmethod,'muskingum')
            [dsrelease,celerityout,dispersionout]=runmuskingum(ds,wds,rs,sr,release,rhours,rsteps,celerity,dispersion);
        elseif strcmp(srmethod,'j349')
            [dsrelease,celerityout,dispersionout]=runj349f(ds,wds,rs,sr,release+minj349,gainportion,rdays,rhours,rsteps,j349dir,celerity,dispersion); %celerity/disp based on gage flows - wrong but so timing the same
            dsrelease=dsrelease-minj349-gainportion;  %minflow added in and subtracted - a Qus constant 1 should have Qds constant 1
        end
        dsrelease=max(0,dsrelease);
        Qavg=(max(dsrelease,minc)+max(release,minc))/2;
        width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
        evap=SR.(ds).(wds).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
        dsrelease=dsrelease-evap;
        dsrelease=max(0,dsrelease);
        SR.(ds).(wds).(rs).(ws).QSRadded(:,sr)=1;
        QSRaddus=max(0,release-Qusrelease);
        QSRaddds=max(0,dsrelease-Qdsrelease);
        SR.(ds).(wds).(rs).(ws).QSRaddus(:,sr)=QSRaddus;
        SR.(ds).(wds).(rs).(ws).QSRaddds(:,sr)=QSRaddds;
        Qusrelease=max(release,Qusrelease);  %Qusrelease/Qdsrelease max of partial/cut method and just running release by itself
        Qdsrelease=max(dsrelease,Qdsrelease);
        Qdspartial=SR.(ds).(wds).(rs).Qds(:,sr)-Qdsrelease;
        logm=['To avoid cutting wc: ' ws ' total wcamount exceeding river: ' num2str(QSRaddsum) ' added US:' num2str(sum(QSRaddus(datestid:end))) ' added DS:' num2str(sum(QSRaddds(datestid:end))) ' wd:' wds ' r:' rs ' sr:' num2str(sr)];
        domessage(logm,logfilename,displaymessage,writemessage)
    else
        SR.(ds).(wds).(rs).(ws).QSRadded(:,sr)=0;
        SR.(ds).(wds).(rs).(ws).QSRaddus(:,sr)=zeros(rsteps,1);
        SR.(ds).(wds).(rs).(ws).QSRaddds(:,sr)=zeros(rsteps,1);
    end
    
    if sum(strcmp(SR.(ds).(wds).(rs).wcreducelist,ws))>0 && inadv2_reducewcpushUS==1 && sr==SR.(ds).(wds).(rs).SR(end)
        Qdspartial=Qdspartial+SR.(ds).(wds).(rs).(ws).wcreduceamtlast;
        Qdsrelease=Qdsrelease-SR.(ds).(wds).(rs).(ws).wcreduceamtlast;
        Qdsrelease=max(0,Qdsrelease);
    end    
    
    
    % wc listed within R at sr position
    SR.(ds).(wds).(rs).(ws).Qusnoderelease(:,sr)=Qusnoderelease;
    SR.(ds).(wds).(rs).(ws).Qusrelease(:,sr)=Qusrelease;
    SR.(ds).(wds).(rs).(ws).Qdsrelease(:,sr)=Qdsrelease;
    
    %total of all wc releases
    SR.(ds).(wds).(rs).Qusnodewc(:,sr)=SR.(ds).(wds).(rs).Qusnodewc(:,sr)+Qusnoderelease;
    SR.(ds).(wds).(rs).Quswc(:,sr)=SR.(ds).(wds).(rs).Quswc(:,sr)+Qusrelease;
    SR.(ds).(wds).(rs).Qdswc(:,sr)=SR.(ds).(wds).(rs).Qdswc(:,sr)+Qdsrelease;
    
    % wc listed within WD at subreachid position (only for movie plotting?)
    lsr=SR.(ds).(wds).(rs).subreachid(sr);
    SR.(ds).(wds).(ws).Qusnoderelease(:,lsr)=Qusnoderelease;
    SR.(ds).(wds).(ws).Qusrelease(:,lsr)=Qusrelease;
    SR.(ds).(wds).(ws).Qdsrelease(:,lsr)=Qdsrelease;

    % WCloc.ws listing locations of WC as cell/strings (sr/lsr/type(1-release/2-exch) is num)
    SR.(ds).Rivloc.flowwc.us(:,SR.(ds).(wds).(rs).locid(sr))=SR.(ds).Rivloc.flowwc.us(:,SR.(ds).(wds).(rs).locid(sr))+Qusrelease;
    SR.(ds).Rivloc.flowwc.ds(:,SR.(ds).(wds).(rs).locid(sr))=SR.(ds).Rivloc.flowwc.ds(:,SR.(ds).(wds).(rs).locid(sr))+Qdsrelease;
    %this has Rivloc column, wc-id, line within WCloc.ws to get SR nodes
    SR.(ds).Rivloc.flowwc.wcloc=[SR.(ds).Rivloc.flowwc.wcloc;{SR.(ds).(wds).(rs).locid(sr)} {ws} {length(SR.(ds).WCloc.(ws).loc(:,1))}];
    
    Qusnodepartial=Qdspartial;
    release=Qdsrelease;
    
        
end %sr
  
end %if

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% parking - transfering waterclass amt from one WD to another - currently only for release/exchange through internal confluence
if r==Rtb && isfield(SR.(ds).(wds),ws) && isfield(SR.(ds).(wds).(ws),'parkwdidid')  %placing park - place wcnum and park parameters in downstream WDreach
    parkwdidid=SR.(ds).(wds).(ws).parkwdidid;    
    did=SR.(ds).WDID{parkwdidid,1};
    parkWD=SR.(ds).WDID{parkwdidid,3};
    pwds=['WD' num2str(parkWD)];
    parkR=SR.(ds).WDID{parkwdidid,4};
    prs=['R' num2str(parkR)];
    psr=SR.(ds).WDID{parkwdidid,5};   
    lsr=SR.(ds).(wds).(rs).subreachid(sr);
%    parklsr=SR.(ds).(['WD' num2str(SR.(ds).WDID{wdidtoid,3})]).(['R' num2str(SR.(ds).WDID{wdidtoid,4})]).subreachid(SR.(ds).WDID{wdidtoid,5}); %this should also work - keep in case above breaks down
    parktype=SR.(ds).(pwds).park{7};  %this was needed when broke from routing loop
    if parktype==2  %for us exchange through internal confluence, placing routed exchange amount at end of US WDreach - cant do this like this like regular us exchange since upper tribs already executed
        parklsr=SR.(ds).(pwds).(['R' num2str(SR.(ds).(pwds).R(end))]).subreachid(end);
        SR.(ds).(pwds).(prs).(ws).Qusnoderelease(:,psr)=zeros(length(rdates),1);
        SR.(ds).(pwds).(prs).(ws).Qusrelease(:,psr)=zeros(length(rdates),1);
%        SR.(ds).(pwds).(prs).(ws).Qdsrelease(:,psr)=SR.(ds).(wds).(ws).Qdsrelease(:,lsr);
        SR.(ds).(pwds).(prs).(ws).Qdsrelease(:,psr)=-1*SR.(ds).(wds).(rs).(ws).Qdsrelease(:,sr); %-1 for exchange - (or might this also be used for some sort of release?) 
        SR.(ds).(pwds).(ws).Qusnoderelease(:,parklsr)=zeros(length(rdates),1);
        SR.(ds).(pwds).(ws).Qusrelease(:,parklsr)=zeros(length(rdates),1);
        SR.(ds).(pwds).(ws).Qdsrelease(:,parklsr)=-1*SR.(ds).(wds).(ws).Qdsrelease(:,lsr);
    end 
end


end %w

%native as river minus total of all wc releases
SR.(ds).(wds).(rs).Qusnodenative=SR.(ds).(wds).(rs).Qusnode-SR.(ds).(wds).(rs).Qusnodewc;
SR.(ds).(wds).(rs).Qusnative=SR.(ds).(wds).(rs).Qus-SR.(ds).(wds).(rs).Quswc;
SR.(ds).(wds).(rs).Qdsnative=SR.(ds).(wds).(rs).Qds-SR.(ds).(wds).(rs).Qdswc;


%%%%%%%%%%%%%%%%%%%%%%%%%%
% INADVERTANT DIVERSIONS - ACTION 2
% if native (river-totalwcreleases) negative at gage then seems there was an actual inadvertant diversion
% so try to reduce wc releases where they are going negative at internal node upstream
    
negnativeds=-1*min(0,SR.(ds).(wds).(rs).Qdsnative(:,end));
negnativedssum=sum(negnativeds(datestid:end,:));

if r~=Rb && negnativedssum>wcreduceamtlimit

    if inadv2_reducewcpushUS==1 && changewccount<iternative
        %fthis option pushes wc reduction upstream to most likely upstream spots to reduce wcs
        %would not push upstream on last iteration but just apply last/end correction
        changewc=1;
        logm=['Negative Native Flow at end of wd:' wds ' r:' rs ' total amount:' num2str(negnativedssum) ' will reoperate admin loop'];
        domessage(logm,logfilename,displaymessage,writemessage)
        
        %finding water classes that are running in stream both at end where gage
        srnb=SR.(ds).(wds).(rs).SR(end);
        wwcnumids=intersect(find(strcmp(SR.(ds).WCloc.Rloc(:,3),wds)),find(strcmp(SR.(ds).WCloc.Rloc(:,4),rs)));
        wwcnumids=intersect(find([SR.(ds).WCloc.Rloc{:,6}]==srnb),wwcnumids);
        
        %trying to find best upstream spots to reduce wcs
        negnativeus=-1*min(0,SR.(ds).(wds).(rs).Qusnative);
        negnativeussum=sum(negnativeus(datestid:end,:));
        negnativeussumoutflows=-1*min(0,negnativeussum.*SR.(ds).(wds).(rs).type); %just at outflow nodes
        clear negnativeussumdifRf
        negnativeussumdiff(1)=negnativeussumoutflows(1);  %thinking increase from previous node is potentially attributable to inadvertant at us node
        if length(negnativeussum)>1
            for i=length(negnativeussum):-1:2
                negnativeussumdiff(i)=max(0,negnativeussumoutflows(i)-sum(negnativeussumoutflows(1:i-1)));
            end
        end
        if sum(negnativeussumdiff)==0
            wcreduceperc=ones(1,length(negnativeussumdiff))/length(negnativeussumdiff);
        else
            wcreduceperc=negnativeussumdiff/sum(negnativeussumdiff);
        end
        wcreducepercids=find(wcreduceperc>0);
        
        for i=1:length(wcreducepercids)
            exchtimerem=0;
            srnt=wcreducepercids(i);
            wcreducepercent=wcreduceperc(wcreducepercids(i));
            Qnegds=negnativeds*wcreducepercent;
            
            for sr=srnb:-1:srnt
                celerity=SR.(ds).(wds).(rs).celerity(:,sr);
                if or(strcmp(srmethod,'j349'),strcmp(srmethod,'muskingum'))
                    [Qnegus,exchtimerem,celerity,srtime]=reversecelerity(ds,wds,rs,sr,Qnegds,exchtimerem,rhours,rsteps,celerity); %using river celerity
                else
                    Qnegus=Qnegds;
                end
                Qavg=Qnegus;  %us and ds should be same amounts but using us to not smeer timing
                width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
                evap=SR.(ds).(wds).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
                Qnegus=Qnegus+evap;
                Qnegds=Qnegus;
            end
            
            %finding water classes that are also running in stream at given (top) node for reduction
            wwcnumidst=intersect(find([SR.(ds).WCloc.Rloc{:,5}]<=srnt),wwcnumids);
            
            SR.(ds).(wds).(rs).wcreduceamt(:,srnt)=SR.(ds).(wds).(rs).wcreduceamt(:,srnt)+Qnegus;
            
            for w=1:length(wwcnumidst)
                ws=SR.(ds).WCloc.Rloc{wwcnumidst(w),1};
                if ~isfield(SR.(ds).(wds).(rs).(ws),'wcreduce')
                    SR.(ds).(wds).(rs).wcreducelist=[SR.(ds).(wds).(rs).wcreducelist {ws}];
                    SR.(ds).(wds).(rs).(ws).wcreduce=zeros(1,length(SR.(ds).(wds).(rs).SR));
                    SR.(ds).(wds).(rs).(ws).wcreduceamt=zeros(rsteps,length(SR.(ds).(wds).(rs).SR));
                    SR.(ds).(wds).(rs).(ws).wcreduceamtlast=zeros(rsteps,1);
                end
                wcportion=wcreducepercent*SR.(ds).(wds).(rs).(ws).Qusrelease(:,sr)./SR.(ds).(wds).(rs).Quswc(:,sr);
                wcreduceamt=Qnegus.*wcportion;
                nanids=find(isnan(wcreduceamt));
                wcreduceamt(nanids)=0;
                SR.(ds).(wds).(rs).(ws).wcreduce(:,srnt)=1;
                SR.(ds).(wds).(rs).(ws).wcreduceamt(:,srnt)=SR.(ds).(wds).(rs).(ws).wcreduceamt(:,srnt)+wcreduceamt;
                logm=['Reducing WC:' ws ' by additional:' num2str(sum(wcreduceamt)) ' total:' num2str(sum(SR.(ds).(wds).(rs).(ws).wcreduceamt(:,srnt))) ' wd:' wds ' r:' rs ' sr: ' num2str(srnt) ' iteration: ' num2str(changewccount)];
                domessage(logm,logfilename,displaymessage,writemessage)

            end
        end
        
        
    elseif inadv2b_reducewclastatgage==1 | (inadv2_reducewcpushUS==1 && changewccount==iternative)
        %eiter with this option only or on last iteration of previous option - find final adjustment just to apply at very end rather than working it back up
        logm=['Negative Native Flow at end of wd:' wds ' r:' rs ' total amount:' num2str(negnativedssum) ' will just reduce wc at end of R-reach and not reoperate admin loop'];
        domessage(logm,logfilename,displaymessage,writemessage)
        %finding water classes that are running in stream both at end where gage
        srnb=SR.(ds).(wds).(rs).SR(end);
        wwcnumids=intersect(find(strcmp(SR.(ds).WCloc.Rloc(:,3),wds)),find(strcmp(SR.(ds).WCloc.Rloc(:,4),rs)));
        wwcnumids=intersect(find([SR.(ds).WCloc.Rloc{:,6}]==srnb),wwcnumids);
        SR.(ds).(wds).(rs).wcreduceamtlast=negnativeds;
        for w=1:length(wwcnumids)
            ws=SR.(ds).WCloc.Rloc{wwcnumids(w),1};
            wcportion=SR.(ds).(wds).(rs).(ws).Qdsrelease(:,end)./SR.(ds).(wds).(rs).Qdswc(:,end);
            wcreduceamt=negnativeds.*wcportion;
            nanids=find(isnan(wcreduceamt));
            wcreduceamt(nanids)=0;
            SR.(ds).(wds).(rs).(ws).wcreduceamtlast(:,1)=wcreduceamt; 
            logm=['Reducing WC:' ws ' by additional:' num2str(sum(wcreduceamt)) ' wd:' wds ' r:' rs ' at DS end of last sr'];
            domessage(logm,logfilename,displaymessage,writemessage)
        end
        
    end
    if inadv2_reducewcpushUS==1 && changewccount==iternative
        logm=['Stopping reoperation to reduce water classes as hit iteration limit: ' num2str(changewccount)];
        domessage(logm,logfilename,displaymessage,writemessage)
    end
end

end  %change wc

if inadv3a_increaseint==1 
    negnativeus=-1*min(0,SR.(ds).(wds).(rs).Qusnative);
    negnativeussumsum=sum(sum(negnativeus(datestid:end,:)));
    if negnativeussumsum-negnativeussumsumprevious>sraddamtlimit
        change=1;
        changecount=changecount+1;
        negnativeussumsumprevious=negnativeussumsum;
        logm=['Reoperating both gage and admin loops count:' num2str(changecount) ' to reduce internal negative flow amounts totaling:' num2str(sum(negnativeussumsum)) ' wd:' wds ' r:' rs];
        domessage(logm,logfilename,displaymessage,writemessage)
    end    
end

if inadv3b_increaseint==1 
    negnativeus=-1*min(0,SR.(ds).(wds).(rs).Qusnative);
    negnativeussumsum=sum(sum(negnativeus(datestid:end,:)));
    if negnativeussumsum-negnativeussumsumprevious>sraddamtlimit
        change=1;
        changecount=changecount+1;
        negnativeussumsumprevious=negnativeussumsum;
        logm=['Reoperating both gage and admin loops count:' num2str(changecount) ' to reduce internal negative flow amounts totaling:' num2str(sum(negnativeussumsum)) ' wd:' wds ' r:' rs];
        domessage(logm,logfilename,displaymessage,writemessage)
    end    
end
    end %r
    lastwdid=[lastwdid;SR.(ds).(wds).(rs).dswdid{sr} {ds} {wds} {rs} {sr}];
end %wd

SR.(ds).Rivloc.flownative.us=SR.(ds).Rivloc.flowriv.us-SR.(ds).Rivloc.flowwc.us;
SR.(ds).Rivloc.flownative.ds=SR.(ds).Rivloc.flowriv.ds-SR.(ds).Rivloc.flowwc.ds;


if 1==2 %will cut this out
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % ADMIN LOOP FOR WATERCLASSES
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% 
% for wd=WDlist
%     wds=['WD' num2str(wd)];
%     if ~isfield(SR.(ds).(wds),'wwcnums')
%         disp(['no water classes identified (admin loop not run) for D:' ds ' WD:' wds]) 
%     else
%     wwcnums=SR.(ds).(wds).wwcnums;
%     Rt=SR.(ds).(wds).R(1);
%     Rb=SR.(ds).(wds).R(end);
%     disp(['running admin loop for D:' ds ' WD:' wds]) 
% 
% for w=1:length(wwcnums)
% ws=wwcnums{w};
% % if ~isfield(SR.(ds).WCloc,ws)  %if here will include missing WCs as empty
% %     SR.(ds).WCloc.wslist=[SR.(ds).WCloc.wslist,{ws}];
% %     SR.(ds).WCloc.(ws)=[];
% % end
% 
% %disp(['running admin loop for D:' ds ' WD:' wds ' wc:' ws]) 
% 
% 
% wdinwdidlist=find([SR.(ds).WDID{:,3}]==wd);
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %   the next/first block is looking for water classes that were passed from another WDreach
% %   these could have been passed from an upstream release or
% %   from an exchange that was first routed down an upstream reach
% 
% parkwcid=0;
% if isfield(SR.(ds).(wds),'park')
%     parkwcid=find(strcmp(SR.(ds).(wds).park(:,1),ws));
% end
% if parkwcid~=0
%     wdidfrom=SR.(ds).(wds).park{parkwcid,2};
%     wdidfromid=SR.(ds).(wds).park{parkwcid,3};
%     fromWDs=SR.(ds).(wds).park{parkwcid,4};
% %    fromlsr=SR.(ds).(wds).park{parkwcid,8};
% %    release=SR.(ds).(fromWD).(ws).Qdsrelease(:,fromlsr);
%     fromRs=SR.(ds).(wds).park{parkwcid,5};
%     fromsr=SR.(ds).(wds).park{parkwcid,6};
%     release=SR.(ds).(fromWDs).(fromRs).(ws).Qdsrelease(:,fromsr);
% else  %if not parked
%     wdidfrom=WC.(ds).WC.(ws).wdid;
%     wdidfromid=intersect(find(strcmp(SR.(ds).WDID(:,1),wdidfrom)),wdinwdidlist);
%     release=WC.(ds).(wds).(ws).release;
% end
%     
% wdidto=WC.(ds).WC.(ws).to;
% wdidtoid=find(strcmp(SR.(ds).WDID(:,1),wdidto));
% wdidtoidwd=intersect(wdidtoid,wdinwdidlist);
% 
% parkwdidid=0;
% exchtype=0;
% if isempty(wdidtoid)                                    %wdid To: listed in divrecs but cant find To:wdid in network list of wdids
%     wdidtoid=wdidfromid;
%     disp(['WARNING: not routing (either exchange or missing) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ' sum: ' num2str(sum(release)) ]);
% else
%     if ~isfield(SR.(ds).WCloc,ws)
%         SR.(ds).WCloc.wslist=[SR.(ds).WCloc.wslist,{ws}];
%         SR.(ds).WCloc.(ws)=[];
%     end
%     dswdidids=find(wdidtoid>=wdidfromid);
%     if ~isempty(dswdidids)                              %DS RELEASE TO ROUTE (could include US Exchange that is first routed to end of WD)
%         if SR.(ds).WDID{wdidtoid(dswdidids(1)),3} == wd %DS release located in same WD - so route to first node that is at or below release point
%             wdidtoid=wdidtoid(dswdidids(1));            %if multiple points (could be multiple reach defs or same wdid at top of next ds reach)
%         else                                            %DS release located in different WD - so route to bottom of WD and park into next WD
%             wdidtoid=wdinwdidlist(end);
%             parkwdidid=find(strcmp(SR.(ds).WDID(:,1),SR.(ds).WDID(wdidtoid,1)));
%             parkwdidid=setdiff(parkwdidid,wdinwdidlist);
%             parktype=1;  %1 push DS to end of reach
%             disp(['routing: ' ws ' ' WC.(ds).WC.(ws).wc ' To:' wdidto ' external to WD reach, routing to end of WD reach']);
%         end  
%     elseif isempty(dswdidids)                             %US EXCHANGE RELEASE - ONLY ROUTING HERE IF FIRST DOWN TO MID-WD BRANCH
%         wdidtoidnotwd=setdiff(wdidtoid,wdinwdidlist);
%         branchid=find(SR.(ds).(wds).branch{:,1}==SR.D2.WDID{wdidtoidnotwd,3});
% 
%         if ~isempty(branchid)      %us exchange from DS branch within WD (exchtype=3)
%             exchtype=3;
%             SR.(ds).EXCH.(ws).wdidtoid=wdidtoid;
%             SR.(ds).EXCH.(ws).WDto=SR.(ds).WDID{wdidtoid(1),3};
%             wdidbranch=SR.(ds).(wds).branch{branchid,2};
%             wdidtoids=find(strcmp(SR.(ds).WDID(:,1),wdidbranch));
%             parkwdidid=setdiff(wdidtoids,wdinwdidlist);
%             wdidtoid=intersect(wdidtoids,wdinwdidlist);
%             parktype=2;  %2 push DS releases to internal node
%             SR.(ds).EXCH.(ws).wdidfromid=parkwdidid;
%             SR.(ds).EXCH.(ws).WDfrom=SR.(ds).WDID{parkwdidid,3};
%             SR.(ds).EXCH.(ws).exchtype=3;            
%             disp(['routing: ' ws ' ' WC.(ds).WC.(ws).wc ' To Confluence:' wdidbranch ' US exchange first routing with TL to internal confluence point within WD reach']);
%             disp(['Exchange: (external to WD) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ' sum: ' num2str(sum(release)) ]);    
%             
%         elseif ~isempty(wdidtoidwd)                    %us exchange within WD (exchtype=1)
%             exchtype=1;
%             SR.(ds).EXCH.(ws).wdidtoid=wdidtoidwd(end);  %last in list in case multiple reach listing (will go to lowest) - remember that wdid is listed "above" subreach so sr will be next one after
%             SR.(ds).EXCH.(ws).wdidfromid=wdidfromid;
%             SR.(ds).EXCH.(ws).WDfrom=wd;
%             SR.(ds).EXCH.(ws).WDto=wd;
%             SR.(ds).EXCH.(ws).exchtype=1;
%             wdidtoid=wdidfromid;  %leaving it there
%             disp(['Exchange: (internal to WD) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ' sum: ' num2str(sum(release)) ]);
%         else                                           %us exchange in different WD (exchtype=2)
%             exchtype=2;
%             SR.(ds).EXCH.(ws).wdidtoid=wdidtoid(end);
%             SR.(ds).EXCH.(ws).wdidfromid=wdidfromid;
%             SR.(ds).EXCH.(ws).WDfrom=wd;
%             SR.(ds).EXCH.(ws).WDto=SR.(ds).WDID{wdidtoid(1),3};
%             SR.(ds).EXCH.(ws).exchtype=2;
%             wdidtoid=wdidfromid;
% %            wdidtoid=wdinwdidlist(end);
%             disp(['Exchange: (external to WD) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ' sum: ' num2str(sum(release)) ]);    
%         end
% 
%     end       
% end
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     
% % if WC.(ds).WC.(ws).type==1 %exchange (?)  %exchange defined by upstream record - not using anymore??
% %     release=release*-1;
% % end
% srids=SR.(ds).(wds).(['R' num2str(Rb)]).subreachid(end);  %just to set size of release matrices
% SR.(ds).(wds).(ws).Qusnoderelease(length(rdates),srids)=0;     %just used for plotting, maybe better way..
% SR.(ds).(wds).(ws).Qusrelease(length(rdates),srids)=0;
% SR.(ds).(wds).(ws).Qdsrelease(length(rdates),srids)=0;
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% if wdidtoid==wdidfromid   %EXCHANGES (or missing releases) - Exchanges put into Qds of US reach so consistent (not currently had been: missing gets parked in Qus)
%     rs=['R' num2str(SR.(ds).WDID{wdidfromid,4})];
%     sr=SR.(ds).WDID{wdidfromid,5};
%     if exchtype==1 | exchtype==2  %for us exchanges putting into Qds of reach above node rather than Qus of reach below node
%         wdsnew=wds;
%         if SR.(ds).WDID{wdidfromid,6}==0 %uswdid/top of wd - push into us wd
%             wdidnewid=setdiff(find(strcmp(SR.(ds).WDID(:,1),wdidfrom)),wdinwdidlist);
%             wdsnew=['WD' num2str(SR.(ds).WDID{wdidnewid,3})];
%             rs=['R' num2str(SR.(ds).WDID{wdidnewid,4})];
%             sr=SR.(ds).WDID{wdidnewid,5};
%             SR.(ds).EXCH.(ws).wdidfromid=wdidnewid;
%             SR.(ds).EXCH.(ws).WDfrom=SR.(ds).WDID{wdidnewid,3};
%         end 
%         lsr=SR.(ds).(wdsnew).(rs).subreachid(sr);
%         SR.(ds).(wdsnew).(rs).(ws).Qusnoderelease(:,sr)=zeros(length(rdates),1);
%         SR.(ds).(wdsnew).(rs).(ws).Qusrelease(:,sr)=zeros(length(rdates),1);
%         SR.(ds).(wdsnew).(rs).(ws).Qdsrelease(:,sr)=-1*release;
%         SR.(ds).(wdsnew).(ws).Qusnoderelease(:,lsr)=zeros(length(rdates),1);
%         SR.(ds).(wdsnew).(ws).Qusrelease(:,lsr)=zeros(length(rdates),1);
%         SR.(ds).(wdsnew).(ws).Qdsrelease(:,lsr)=-1*release;
% %        SR.(ds).WCloc.(ws)=[SR.(ds).WCloc.(ws);[{ds},{wdsnew},{rs},{sr},{lsr},{2}]];  %type=1release,2exchange - instead putting this in in exchange loop
%         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         %if want to do something with missing releases (ie put into Qusrelease) put an else here
%         
%     end
% else
%     
% WDtr=SR.(ds).WDID{wdidfromid,3};
% WDbr=SR.(ds).WDID{wdidtoid,3};
% Rtr=SR.(ds).WDID{wdidfromid,4};
% Rbr=SR.(ds).WDID{wdidtoid,4};
% SRtr=SR.(ds).WDID{wdidfromid,5}+SR.(ds).WDID{wdidfromid,6};  %new ordering - if col6=1 then sr=dswdid / col6=0 then sr=uswdid, so for from sr add 0 or 1 to move to top of next sr
% SRbr=SR.(ds).WDID{wdidtoid,5};
% 
% % if Rtr==0  %WATCH!! wdid listed is at bottom of reach - so for releases from starts at top of next reach, top reach 0 put into srid 1
% %     Rtr=1;SRtr=1;
% % elseif SRtr==SR.(ds).(wds).(['R' num2str(Rtr)]).SR(end)  %not sure if this condition would ever happen (wdid at bottom of Reach) currently no instances
% %     Rtr=Rtr+1;SRt=1;
% % else
% %     SRtr=SRtr+1;
% % end
%         
%     
% 
% %for wd=WDtr:WDbr  %remove as should now just be in one wd?
% wd=WDtr;
%     wds=['WD' num2str(wd)];
%     for r=Rtr:Rbr
%         rs=['R' num2str(r)];
%         if r==Rtr
%             srt=SRtr;
%         else
%             srt=1;
%         end
%         if r==Rbr
%             srb=SRbr;
%         else
%             srb=SR.(ds).(wds).(rs).SR(end);
%         end
% 
% for sr=srt:srb
%     if and(sr==SRtr,r==Rtr)
%         Qusnodepartial=SR.(ds).(wds).(rs).Qus(:,sr); %this makes Qusnoderelease=0
%         if pred==1 %predictive case
%             Quspartial=SR.(ds).(wds).(rs).Qus(:,sr)+release;
%         else  %administrative case
%             Quspartial=SR.(ds).(wds).(rs).Qus(:,sr)-release;
%         end
%     else
%         type=SR.(ds).(wds).(rs).type(1,sr);
%         Qnode=SR.(ds).(wds).(rs).Qnode(:,sr);
%         Quspartial=Qusnodepartial+type*Qnode;
%     end
%     
%     gain=SR.(ds).(wds).(rs).gain(end);
% %     if gain<0;  %if losses, distribute to release also.. %this needs to be discussed further!!
% %         
% %         
% %     end
%     if pred==1
%         celerity=-999;dispersion=-999;
%     else
%         celerity=SR.(ds).(wds).(rs).celerity(:,sr);
%         dispersion=SR.(ds).(wds).(rs).dispersion(:,sr);
%     end
%         
%     if gain==-999   %gain=-999 to not run J349 
%         Quspartial=max(0,Quspartial);  %WARNING: this effectively cuts Qusrelease (waterclass) to Qus (gage); 
%         Qdspartial=Quspartial;
%         SR.(ds).(wds).(rs).QSRadd(:,sr)=zeros(length(rdates),1);
%     else
%         SR.(ds).(wds).(rs).QSRadd(:,sr)=-1*(min(1,Quspartial)-1);  %amount to add to SR - internal "potential" inadvertant diversion
%         Quspartial=max(1,Quspartial);  %WARNING: this effectively cuts Qusrelease (waterclass) to Qus (gage); using one needed for for j349
%         
%         gainportion=gain*SR.(ds).(wds).(rs).reachportion(sr);
%         if strcmp(srmethod,'j349')
% %            [Qdspartial,celerity,dispersion]=runj349f(ds,wds,rs,sr,Quspartial,gainportion,rdays,rhours,rsteps,basedir,-999,-999); %celerity/disp based on gage-release (ie partial) flows
%             [Qdspartial,celerity,dispersion]=runj349f(ds,wds,rs,sr,Quspartial,gainportion,rdays,rhours,rsteps,j349dir,celerity,dispersion); %celerity/disp based on gage flows
%         elseif strcmp(srmethod,'muskingum')
% %            [Qdspartial,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Quspartial,rhours,rsteps,-999,-999);
%             [Qdspartial,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Quspartial,rhours,rsteps,celerity,dispersion);
%         end
%         Qdspartial=max(0,Qdspartial);
%         
%     end
%     Qavg=(max(Quspartial,1)+max(Qdspartial,1))/2;
%     width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
%     if WC.(ds).WC.(ws).type==1 %exchange
%         evap=0;
%     else
%         evap=SR.(ds).(wds).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
%     end
%     Qdspartial=Qdspartial-evap+SR.(ds).(wds).(rs).gagediff*SR.(ds).(wds).(rs).reachportion(sr);
%     Qdspartial=max(0,Qdspartial);
% 
%     SR.(ds).(wds).(rs).(ws).Qusnodepartial(:,sr)=Qusnodepartial;
%     SR.(ds).(wds).(rs).(ws).Quspartial(:,sr)=Quspartial;
%     SR.(ds).(wds).(rs).(ws).Qdspartial(:,sr)=Qdspartial;
%     
%     %%%%%%%%%%%%%%%%%%%%%%%%%%
%     % calc of actual WC amount
%     if pred~=1  %if not prediction, wc amounts are gage amount - "partial" (gage-wcrelease) amount 
%         Qusnoderelease=SR.(ds).(wds).(rs).Qusnode(:,sr)-Qusnodepartial;
%         Qusrelease=SR.(ds).(wds).(rs).Qus(:,sr)-Quspartial;
%         Qdsrelease=SR.(ds).(wds).(rs).Qds(:,sr)-Qdspartial;
%     else        %if prediction, wc amounts are "partial" (gage+wcrelease) amount - gage amount 
%         Qusnoderelease=Qusnodepartial-SR.(ds).(wds).(rs).Qusnode(:,sr);
%         Qusrelease=Quspartial-SR.(ds).(wds).(rs).Qus(:,sr);
%         Qdsrelease=Qdspartial-SR.(ds).(wds).(rs).Qds(:,sr);
%     end
%     
%     Qusnoderelease=max(0,Qusnoderelease);
%     Qusrelease=max(0,Qusrelease);  %this seems to happen in muskingham - reason?? - need to worry about lost negative amount??
%     Qdsrelease=max(0,Qdsrelease);
%     
%     % wc listed within R at sr position
%     SR.(ds).(wds).(rs).(ws).Qusnoderelease(:,sr)=Qusnoderelease;
%     SR.(ds).(wds).(rs).(ws).Qusrelease(:,sr)=Qusrelease;
%     SR.(ds).(wds).(rs).(ws).Qdsrelease(:,sr)=Qdsrelease;
%     
%     % wc listed within WD at subreachid position (only for movie plotting?)
%     lsr=SR.(ds).(wds).(rs).subreachid(sr);
%     SR.(ds).(wds).(ws).Qusnoderelease(:,lsr)=Qusnoderelease;
%     SR.(ds).(wds).(ws).Qusrelease(:,lsr)=Qusrelease;
%     SR.(ds).(wds).(ws).Qdsrelease(:,lsr)=Qdsrelease;
% 
%     % WCloc.ws listing locations of WC as cell/strings (sr/lsr/type(1-release/2-exch) is num)
%     SR.(ds).WCloc.(ws)=[SR.(ds).WCloc.(ws);[{ds},{wds},{rs},{sr},{lsr},{1},{SR.(ds).(wds).(rs).wdid{sr}},{SR.(ds).(wds).(rs).dswdid{sr}}]];
%     SR.(ds).Rivloc.flowwc.us(:,SR.(ds).(wds).(rs).locid(sr))=SR.(ds).Rivloc.flowwc.us(:,SR.(ds).(wds).(rs).locid(sr))+Qusrelease;
%     SR.(ds).Rivloc.flowwc.ds(:,SR.(ds).(wds).(rs).locid(sr))=SR.(ds).Rivloc.flowwc.ds(:,SR.(ds).(wds).(rs).locid(sr))+Qdsrelease;
%     %this has Rivloc column, wc-id, line within WCloc.ws to get SR nodes
%     SR.(ds).Rivloc.flowwc.wcloc=[SR.(ds).Rivloc.flowwc.wcloc;{SR.(ds).(wds).(rs).locid(sr)} {ws} {length(SR.(ds).WCloc.(ws)(:,1))}];
%     
%     Qusnodepartial=Qdspartial;
%     
% end %sr
% 
%     end %r
% %end %wd
% end
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % parking - transfering waterclass from one WD to another
% %   for releases, ds WDreach should then pick up, for exchanges waits for exchange loop
% if parkwdidid ~= 0  %placing park - place wcnum and park parameters in downstream WDreach 
%     parkwdid=SR.(ds).WDID{parkwdidid,1};
%     parkWD=SR.(ds).WDID{parkwdidid,3};
%     pwds=['WD' num2str(parkWD)];
%     parkR=SR.(ds).WDID{parkwdidid,4};
%     prs=['R' num2str(parkR)];
%     psr=SR.(ds).WDID{parkwdidid,5};
%     
%     lsr=SR.(ds).(wds).(rs).subreachid(sr);
% %    parklsr=SR.(ds).(['WD' num2str(SR.(ds).WDID{wdidtoid,3})]).(['R' num2str(SR.(ds).WDID{wdidtoid,4})]).subreachid(SR.(ds).WDID{wdidtoid,5}); %this should also work - keep in case above breaks down
% 
%     if ~isfield(SR.(ds).(pwds),'wwcnums')
%         SR.(ds).(pwds).wwcnums={ws};
%     else
%         SR.(ds).(pwds).wwcnums=[SR.(ds).(pwds).wwcnums;{ws}];
%     end    
%     if ~isfield(SR.(ds).(pwds),'park')
%         SR.(ds).(pwds).park=[{ws},{parkwdid},{parkwdidid},{wds},{rs},{sr},{parktype},{lsr}];  %this is destination wdidid but source wds,rs,sr
%     else
%         SR.(ds).(pwds).park=[SR.(ds).(pwds).park;{ws},{parkwdid},{parkwdidid},{wds},{rs},{sr},{parktype},{lsr}];        
%     end
%     if parktype==2  %for us exchange through internal confluence, placing routed exchange amount at end of US WDreach - cant do this like this like regular us exchange since upper tribs already executed
%         parklsr=SR.(ds).(pwds).(['R' num2str(SR.(ds).(pwds).R(end))]).subreachid(end);
%         SR.(ds).(pwds).(prs).(ws).Qusnoderelease(:,psr)=zeros(length(rdates),1);
%         SR.(ds).(pwds).(prs).(ws).Qusrelease(:,psr)=zeros(length(rdates),1);
% %        SR.(ds).(pwds).(prs).(ws).Qdsrelease(:,psr)=SR.(ds).(wds).(ws).Qdsrelease(:,lsr);
%         SR.(ds).(pwds).(prs).(ws).Qdsrelease(:,psr)=-1*SR.(ds).(wds).(rs).(ws).Qdsrelease(:,sr); %-1 for exchange - (or might this also be used for some sort of release?) 
%         SR.(ds).(pwds).(ws).Qusnoderelease(:,parklsr)=zeros(length(rdates),1);
%         SR.(ds).(pwds).(ws).Qusrelease(:,parklsr)=zeros(length(rdates),1);
%         SR.(ds).(pwds).(ws).Qdsrelease(:,parklsr)=-1*SR.(ds).(wds).(ws).Qdsrelease(:,lsr);
%     end
%     
%     
% end
% 
% end %j - waterclass
% end
% end
% 
% SR.(ds).Rivloc.flownative.us=SR.(ds).Rivloc.flowriv.us-SR.(ds).Rivloc.flowwc.us;
% SR.(ds).Rivloc.flownative.ds=SR.(ds).Rivloc.flowriv.ds-SR.(ds).Rivloc.flowwc.ds;
% 
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ADMIN LOOP - EXCHANGES - FOR WATERCLASSES
%    currently thinking that need to route exchanges from downstream/Type7 to upstream (in reverse time) (rather than ds from type1 record)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if doexchanges==1 & isfield(SR.(ds),'EXCH') 
wwcnums=fieldnames(SR.(ds).EXCH);

for w=1:length(wwcnums)
    ws=wwcnums{w};

%     if ~isfield(SR.(ds).WCloc,ws)
%         SR.(ds).WCloc.wslist=[SR.(ds).WCloc.wslist,{ws}];
%         SR.(ds).WCloc.(ws)=[];
%     end
    wdidfromid=SR.(ds).EXCH.(ws).wdidfromid;
    wdidtoid=SR.(ds).EXCH.(ws).wdidtoid;
    wdidelist=[wdidtoid,wdidfromid];
    WDelist=SR.(ds).EXCH.(ws).WDto;
    while WDelist(end)~=SR.(ds).EXCH.(ws).WDfrom  %routing down finding WDs and connection pts
        wdidwdlist=find([SR.(ds).WDID{:,3}]==WDelist(end));
        wdidelist(end,2)=wdidwdlist(end);
        wdididnextwd=setdiff(find(strcmp(SR.(ds).WDID(:,1),SR.(ds).WDID{wdidwdlist(end),1})),wdidwdlist);
        nextwd=SR.(ds).WDID{wdididnextwd,3};
        wdidelist=[wdidelist;[wdididnextwd,wdidfromid]];
        WDelist=[WDelist,nextwd];
    end
    WDelist=fliplr(WDelist);      %relisting listing from bottom to top..
    wdidelist=flipud(wdidelist);
    SR.(ds).EXCH.(ws).WDelist=WDelist;
    SR.(ds).EXCH.(ws).wdidelist=wdidelist;
    
    wds=['WD' num2str(SR.(ds).WDID{wdidfromid,3})];
    rs=['R' num2str(SR.(ds).WDID{wdidfromid,4})];
    sr=SR.(ds).WDID{wdidfromid,5};
    QEds=SR.(ds).(wds).(rs).(ws).Qdsrelease(:,sr);
    
    k=0;
    exchtimerem=0;
    
    for wd=WDelist
        if sum(WDlist==wd) == 0
            logm=['Warning: Not running exchange loop on waterclass:' ws ' through wd:' num2str(wd) ' as wd not in WDlist and dont have river flows/celerity..  wc:' SR.(ds).WCloc.(ws).wc];
            domessage(logm,logfilename,displaymessage,writemessage) 
        else
        logm=['running exchange loop on waterclass:' ws ' through wd:' num2str(wd) ' wc:' SR.(ds).WCloc.(ws).wc];
        domessage(logm,logfilename,displaymessage,writemessage) 

        k=k+1;
        wds=['WD' num2str(wd)];
        wdididt=wdidelist(k,1);
        wdididb=wdidelist(k,2);
        Rtr=SR.(ds).WDID{wdididt,4};
        Rbr=SR.(ds).WDID{wdididb,4};
        SRtr=SR.(ds).WDID{wdididt,5}+SR.(ds).WDID{wdididt,6};
        SRbr=SR.(ds).WDID{wdididb,5};

        for r=Rbr:-1:Rtr
            rs=['R' num2str(r)];
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
            
            for sr=srb:-1:srt
                celerity=SR.(ds).(wds).(rs).celerity(:,sr);                
                if or(strcmp(srmethod,'j349'),strcmp(srmethod,'muskingum'))
                     [QEus,exchtimerem,celerityex,srtime]=reversecelerity(ds,wds,rs,sr,QEds,exchtimerem,rhours,rsteps,-999);
                else
                    QEus=QEds;
                end
                
                SR.(ds).(wds).(rs).(ws).Qusnoderelease(:,sr)=QEus;
                SR.(ds).(wds).(rs).(ws).Qusrelease(:,sr)=QEus;
                SR.(ds).(wds).(rs).(ws).Qdsrelease(:,sr)=QEds;
                QEds=QEus;
                
                % wc listed within WD at subreachid position (only for movie plotting?)
                lsr=SR.(ds).(wds).(rs).subreachid(sr);
                SR.(ds).(wds).(ws).Qusnoderelease(:,lsr)=QEus;
                SR.(ds).(wds).(ws).Qusrelease(:,lsr)=QEus;
                SR.(ds).(wds).(ws).Qdsrelease(:,lsr)=QEds;
                
                % WCloc.ws listing locations of WC as cell/strings (sr/lsr/type(1-release/-1 -exch) is num)
                SR.(ds).WCloc.(ws).loc=[SR.(ds).WCloc.(ws).loc;[{ds},{wds},{rs},{sr},{lsr},{-1},{SR.(ds).(wds).(rs).wdid{sr}},{SR.(ds).(wds).(rs).dswdid{sr}}]];
                SR.(ds).WCloc.(ws).srtime=SR.(ds).WCloc.(ws).srtime-srtime;
            end
        end
        end
    end


end
end

save([basedir 'StateTL_SR' srmethod 'wc.mat'],'SR');
elseif runcaptureloop==1
    load([basedir 'StateTL_SR' srmethod 'wc.mat']);  
end %runwcloop


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CAPTURE LOOP TO CHARACTERIZE AVAILABLE/CAPTURE AMT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if runcaptureloop==1
    logm=['running capture loop to characterize release capture amounts versus release/available amounts'];
    domessage(logm,logfilename,displaymessage,writemessage)
    dt=rhours * 60 * 60; %sec
    
%for j=1:length(SR.(ds).Rivloc.loc(:,1))
for m=1:length(SR.(ds).WDID(:,1))  %WDID list (as opposed to SR.(ds).Rivloc.loc{:,6}) has dups but will get all us nodes in case exchange to one

%    towdid=SR.(ds).Rivloc.loc{j,6};
    towdid=SR.(ds).WDID{m,1};
    wcrlocids=find(strcmp(SR.(ds).WCloc.Rloc(:,12),towdid));
    wwcnums=unique(SR.(ds).WCloc.Rloc(wcrlocids,1),'stable');
    
    if ~isempty(wwcnums)
    for w=1:length(wwcnums)
        ws=wwcnums{w};
        
        if SR.(ds).WCloc.(ws).loc{1,6}==1
            releaseamt=SR.(ds).(SR.(ds).WCloc.(ws).loc{1,2}).(SR.(ds).WCloc.(ws).loc{1,3}).(ws).Qusrelease(:,(SR.(ds).WCloc.(ws).loc{1,4}));
        else %exchange
            releaseamt=SR.(ds).(SR.(ds).WCloc.(ws).loc{1,2}).(SR.(ds).WCloc.(ws).loc{1,3}).(ws).Qdsrelease(:,(SR.(ds).WCloc.(ws).loc{1,4}));
        end        
        releaseamt(1:datestid-1,1)=0;  %just in case (??)
        if SR.(ds).WCloc.(ws).loc{1,6}==1
            availableamt=SR.(ds).(SR.(ds).WCloc.(ws).loc{end,2}).(SR.(ds).WCloc.(ws).loc{end,3}).(ws).Qdsrelease(:,(SR.(ds).WCloc.(ws).loc{end,4}));
        else %exchange
            availableamt=SR.(ds).(SR.(ds).WCloc.(ws).loc{end,2}).(SR.(ds).WCloc.(ws).loc{end,3}).(ws).Qusrelease(:,(SR.(ds).WCloc.(ws).loc{end,4}));
        end        
        captureamt=availableamt;
        
        startpos=SR.(ds).WCloc.(ws).loc{1,6};endpos=SR.(ds).WCloc.(ws).loc{end,6}; %will be a -1 if an exchange        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % identifying when to lop off capture amt
        %the following is as long as it is in case there are multiple releases (ie with zero release in between) in period
        ispos=startpos*releaseamt>0;
        isposchange=[ispos(1);ispos(2:end)-ispos(1:end-1)];
        relstartids=find(isposchange==1);
        relendids=find(isposchange==-1);
        if length(relendids)<length(relstartids)
            relendids=[relendids;length(releaseamt)+1];
        end
        relendids=relendids-1;
        
        
        if SR.(ds).WCloc.(ws).loc{1,6}==1  %not starting as exchange     
        
        clear triggerid triggerupid
        for i=1:length(relstartids)
            srtime(i)=0;
            for j=1:length(SR.(ds).WCloc.(ws).loc(:,1))
                channellength=SR.(ds).(SR.(ds).WCloc.(ws).loc{j,2}).(SR.(ds).WCloc.(ws).loc{j,3}).channellength(SR.(ds).WCloc.(ws).loc{j,4});
                celerity=SR.(ds).(SR.(ds).WCloc.(ws).loc{j,2}).(SR.(ds).WCloc.(ws).loc{j,3}).celerity(SR.(ds).WCloc.(ws).loc{j,4});
                if length(celerity)>1
                    celerity=mean(celerity(relstartids(i):relendids(i),1));
                end
                srtime(i)=srtime(i)+SR.(ds).WCloc.(ws).loc{j,6}*(channellength*5280)/celerity/dt; %in hours - will go backwards if exchange
            end
            
            if relendids(i)==length(releaseamt)  %release didnt end at end of period
                triggerid(i)=length(releaseamt);    %put trigger id at end
                srtimehrs=0;
            else
                avgrelease=mean(releaseamt(relstartids(i):relendids(i),1));  %will need to revise by periods if evaluating multiple releases
                triggeramt=percrule*avgrelease;
                
                %first try - route/time end of release to location of towdid to start look for trigger amt on receeding limb
                srtimehrs=floor(srtime(i)*.85); %to be conservative on test seemed like j349 was about 15% quicker that celerity value .. humn.. 
                if relendids(i)+srtimehrs > length(releaseamt)  %if estimated time exceeds end; back up to where can just in case..
                    srtimehrs=length(releaseamt)-relendids(i);
                end
                belowtriggerids=find(endpos*availableamt(relendids(i)+srtimehrs:end,:)<=triggeramt);
                if isempty(belowtriggerids)
                    triggerid(i)=length(releaseamt);  %put trigger id at end
                else
                    triggerid(i)=belowtriggerids(1)+relendids(i)+srtimehrs-1;
                end
            end
            if triggerid(i)<length(releaseamt)
                if i==length(relstartids)
                    triggerupid(i)=length(releaseamt);
                else
                    abovezeroids=find(endpos*availableamt(relstartids(i+1)+srtimehrs:end,:)>0);
                    triggerupid(i)=abovezeroids(1);
                    if triggerupid(i)==1
                        abovetriggerids=find(endpos*availableamt(relstartids(i+1)+srtimehrs:end,:)>=triggeramt);
                        triggerupid(i)=abovetriggerids(1);
                    end
                    triggerupid(i)=triggerupid(i)+relstartids(i+1)+srtimehrs-1;
                end
                captureamt(triggerid(i):triggerupid(i))=0;
            else
                triggerupid(i)=length(releaseamt);
            end            
        end
                
        else  %exchange from bottom to top
            srtime=SR.(ds).WCloc.(ws).srtime;
            triggerid=0;triggerupid=0; 
        end
        
        if srtime(1)>0
            captureamt(1:relstartids(1),1)=0;   %sometimes some little noise before release even starts
        else
            captureamt(1:max(1,relstartids(1)+floor(srtime(1)/.8)),1)=0;  %in case exchange (that has release portion) back up before release time - and 0.8 to be conservative
        end
        
        clear Qusnoderelease Qusrelease Qdsrelease
        for j=1:length(SR.(ds).WCloc.(ws).loc(:,1))
            SR.(ds).WCloc.(ws).Qusrelease(:,j)=SR.(ds).(SR.(ds).WCloc.(ws).loc{j,2}).(SR.(ds).WCloc.(ws).loc{j,3}).(ws).Qusrelease(:,SR.(ds).WCloc.(ws).loc{j,4});
            SR.(ds).WCloc.(ws).Qdsrelease(:,j)=SR.(ds).(SR.(ds).WCloc.(ws).loc{j,2}).(SR.(ds).WCloc.(ws).loc{j,3}).(ws).Qdsrelease(:,SR.(ds).WCloc.(ws).loc{j,4});
            
            
            rivloc=SR.(ds).(SR.(ds).WCloc.(ws).loc{j,2}).(SR.(ds).WCloc.(ws).loc{j,3}).locid((SR.(ds).WCloc.(ws).loc{j,4}));
            
            
            if SR.(ds).WCloc.(ws).loc{j,6}==1  %not including exchanges
                if j==length(SR.(ds).WCloc.(ws).loc(:,1))
                    SR.(ds).Rivloc.flowwccapture.us(:,rivloc)=SR.(ds).Rivloc.flowwccapture.us(:,rivloc)+SR.(ds).WCloc.(ws).Qusrelease(:,j);
                    SR.(ds).Rivloc.flowwccapture.ds(:,rivloc)=SR.(ds).Rivloc.flowwccapture.ds(:,rivloc)+captureamt;
                else
                    SR.(ds).Rivloc.flowwccapture.us(:,rivloc)=SR.(ds).Rivloc.flowwccapture.us(:,rivloc)+SR.(ds).WCloc.(ws).Qusrelease(:,j);
                    SR.(ds).Rivloc.flowwccapture.ds(:,rivloc)=SR.(ds).Rivloc.flowwccapture.ds(:,rivloc)+SR.(ds).WCloc.(ws).Qdsrelease(:,j);
                end
            else  %exchange  %any desire to add up exchanges? if so captureamt added to us not ds
            end
        end
        
        SR.(ds).WCloc.(ws).releaseamt=releaseamt;
        SR.(ds).WCloc.(ws).availableamt=availableamt;
        SR.(ds).WCloc.(ws).captureamt=captureamt;
        SR.(ds).WCloc.(ws).triggerid=triggerid;
        SR.(ds).WCloc.(ws).triggerupid=triggerupid;
        SR.(ds).WCloc.(ws).srtime=srtime;

    end
    end
end

for j=1:length(SR.(ds).Rivloc.loc(:,1))
    SR.(ds).Rivloc.flownativecapture.us(:,j)=SR.(ds).Rivloc.flowriv.us(:,j)-SR.(ds).Rivloc.flowwccapture.us(:,j);
    SR.(ds).Rivloc.flownativecapture.ds(:,j)=SR.(ds).Rivloc.flowriv.ds(:,j)-SR.(ds).Rivloc.flowwccapture.ds(:,j);
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CALIBRATION LOOP TO COMPARE PREDICTED GAGE HYDROGRAPHS TO ACTUAL
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if runcalibloop==1
    %averages of gagediff etc taken with calibration period that is potentially within larger run period
    calibstid=find(rdates==calibstartdate);
    calibendid=find(rdates==calibenddate);
    if isempty(calibstid)
        calibstid=datestid;
        logm=['for calibration loop, calibdatestart:' datestr(calibstartdate) ' not within current data period, so starting calibration period at:' datestr(rdates(calibstid))];
        domessage(logm,logfilename,displaymessage,writemessage)
    end
    if isempty(calibstid)
        calibendid=rsteps;
        logm=['for calibration loop, calibdateend:' datestr(calibenddate) ' not within current data period, so ending calibration period at:' datestr(rdates(calibendid))];
        domessage(logm,logfilename,displaymessage,writemessage)
    end
    if ~(strcmp(calibavggainloss,'mean') | strcmp(calibavggainloss,'linreg'))
        logm=['for calibration loop, could not figure out how to average gagediff etc given listed option:' calibavggainloss ' (looking for mean or linreg)'];
        domessage(logm,logfilename,displaymessage,writemessage)
        error(logm)
    end

for wd=WDcaliblist
    wds=['WD' num2str(wd)];
    logm=['running calibration loop on D:' ds ' WD:' wds ' from ' datestr(rdates(calibstid)) ' to ' datestr(rdates(calibendid))];
    domessage(logm,logfilename,displaymessage,writemessage)

    Rt=SR.(ds).(wds).R(1);
    Rb=SR.(ds).(wds).R(end);
    
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        srt=SR.(ds).(wds).(rs).SR(1);
        srb=SR.(ds).(wds).(rs).SR(end);

        gain=SR.(ds).(wds).(rs).gaininitial(1);
        

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %for calibration loop - take average or linear regression of gagediffportion and sraddamt and other gain/loss/error terms over defined period
        x=(1:(calibendid-calibstid+1))';
        
        gagediffportion=SR.(ds).(wds).(rs).gagediffportion;
        y=gagediffportion(calibstid:calibendid,:);
        [yfit,m,b,R2,SEE]=regr(x,y,calibavggainloss);
        gagediffportion(calibstid:calibendid,:)=yfit;
        SR.(ds).(wds).(rs).gagediffportioncal=gagediffportion;SR.(ds).(wds).(rs).gagediffportionm=m;SR.(ds).(wds).(rs).gagediffportionb=b;SR.(ds).(wds).(rs).gagediffportionR2=R2;
        
        if inadv3a_increaseint == 1
            sraddamt=SR.(ds).(wds).(rs).sraddamt;
            y=sraddamt(calibstid:calibendid,:);
            [yfit,m,b,R2,SEE]=regr(x,y,calibavggainloss);
            sraddamt(calibstid:calibendid,:)=yfit;
            SR.(ds).(wds).(rs).sraddamtcal=sraddamt;SR.(ds).(wds).(rs).sraddamtm=m;SR.(ds).(wds).(rs).sraddamtb=b;SR.(ds).(wds).(rs).sraddamtR2=R2;
        elseif inadv3b_increaseint == 1
            sraddamtds=SR.(ds).(wds).(rs).sraddamtds;
            sraddamtus=SR.(ds).(wds).(rs).sraddamtus;
            y=sraddamtds(calibstid:calibendid,:);
            [yfit,m,b,R2,SEE]=regr(x,y,calibavggainloss);
            sraddamtds(calibstid:calibendid,:)=yfit;
            SR.(ds).(wds).(rs).sraddamtdscal=sraddamtds;SR.(ds).(wds).(rs).sraddamtdsm=m;SR.(ds).(wds).(rs).sraddamtdsb=b;SR.(ds).(wds).(rs).sraddamtdsR2=R2;
            y=sraddamtus(calibstid:calibendid,:);
            [yfit,m,b,R2,SEE]=regr(x,y,calibavggainloss);
            sraddamtus(calibstid:calibendid,:)=yfit;
            SR.(ds).(wds).(rs).sraddamtuscal=sraddamtus;SR.(ds).(wds).(rs).sraddamtusm=m;SR.(ds).(wds).(rs).sraddamtusb=b;SR.(ds).(wds).(rs).sraddamtusR2=R2;
        end
        if adjustlastsrtogage==1
            gagedifflast=SR.(ds).(wds).(rs).gagedifflast;
            y=gagedifflast(calibstid:calibendid,1);
            [yfit,m,b,R2,SEE]=regr(x,y,calibavggainloss);
            gagedifflast(calibstid:calibendid,1)=yfit;
            SR.(ds).(wds).(rs).gagedifflastcal=gagedifflast;SR.(ds).(wds).(rs).gagedifflastm=m;SR.(ds).(wds).(rs).gagedifflastb=b;SR.(ds).(wds).(rs).gagedifflastR2=R2;
        end
        
        
       
for sr=SR.(ds).(wds).(rs).SR
    gain=SR.(ds).(wds).(rs).gaininitial(sr);
    
    if and(sr==1,r==Rt)  %initialize at top given if gage or reservoir etc
        if SR.(ds).(wds).(rs).type(1)==0                                        %if wd zone starts with gage indicated by type = 0
            Qusnode=SR.(ds).(wds).(rs).Qnode(:,1);   
        else                                                                     %otherwise will look for gage somewhere else in top reach or at top of next reach
            gageid=find(SR.(ds).(wds).(rs).type==0);
            if ~isempty(gageid)
                Qds=SR.(ds).(wds).(rs).Qnode(:,gageid(1));
                srbb=gageid(1)-1;
            else
                if r==Rb | SR.(ds).(wds).(['R' num2str(r+1)]).type~=0  %r assuming numerical reach order here
                    error(['STOP - for WD:' wds ' didnt find gage to initialize flow either in top reach or start of second reach'])
                end
                Qds=SR.(ds).(wds).(['R' num2str(r+1)]).Qnode(:,1);
                srbb=srb;
            end
            for sri=srbb:-1:srt                             %adding back in any intermediate diversions; but currently NOT CONSIDERING EVAPORATION or transittime or gain/losscorrection!!! currently need evapfactor=0 and gain=-999 in these (fix/expand?)
                type=SR.(ds).(wds).(rs).type(1,sri);
                losspercent=SR.(ds).(wds).(rs).losspercent(sri);
                Qus=Qds*(1+losspercent/100);
                Qnode=SR.(ds).(wds).(rs).Qnode(:,sri);
                Qusnode=Qus-type*Qnode;
                Qds=Qusnode;
            end
            
        end
    end
    
    %type -1=outflow/1=inflow/0=gage etc
    type=SR.(ds).(wds).(rs).type(1,sr);
    
    %this block seeing if inflow should be defined from by a modeled branch flow at a wdid connection point
%     if type==1 && strcmp(SR.(ds).(wds).(rs).station{sr},'NaN')  && ~isempty(lastwdid)
%         branchid=find(strcmp(lastwdid(:,1),SR.(ds).(wds).(rs).wdid(sr)));
%         if ~isempty(branchid)
%             SR.(ds).(wds).(rs).Qnode(:,sr)=SR.(ds).(lastwdid{branchid,3}).(lastwdid{branchid,4}).Qds(:,lastwdid{branchid,5});
%         end
%     else
%         branchid=[];
%     end
    
    Qnode=SR.(ds).(wds).(rs).Qnode(:,sr);  %if branchid above this will be coming from branch
    %new setup - going from Qusnode to Qus (after usnodes) then to Qds
    Qus=Qusnode+type*Qnode;
    if inadv3b_increaseint == 1
        Qus=Qus+sraddamtus(:,sr);
    end
    Qus=max(0,Qus);
    
    if gain==-999   %gain=-999 to not run transittime but can have loss percent 
        losspercent=SR.(ds).(wds).(rs).losspercent(sr);
        Qds=Qus*(1-losspercent/100);
        celerity=SR.(ds).(wds).(rs).celeritya(sr)*max(minc,(Qus+Qds)/2).^SR.(ds).(wds).(rs).celerityb(sr);
        dispersion=SR.(ds).(wds).(rs).dispersiona(sr)*max(minc,(Qus+Qds)/2).^SR.(ds).(wds).(rs).dispersionb(sr);
    else
%         celerity=SR.(ds).(wds).(rs).celeritya(sr)*max(minc,Qus).^SR.(ds).(wds).(rs).celerityb(sr);
%         dispersion=SR.(ds).(wds).(rs).dispersiona(sr)*max(minc,Qus).^SR.(ds).(wds).(rs).dispersionb(sr);
        if strcmp(srmethod,'j349')
            gainportion=gain*SR.(ds).(wds).(rs).reachportion(sr);
            Qus1=max(minj349,Qus);
            [Qds,celerity,dispersion]=runj349f(ds,wds,rs,sr,Qus1,gainportion,rdays,rhours,rsteps,j349dir,-999,-999);
            Qds=Qds-(Qus1-Qus); %timing won't be perfect for this but keeps celerity exactly calculated above (may want to do as just pure addition/subtraction)
        elseif strcmp(srmethod,'muskingum')
            [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,-999,-999);
        end
        
    end
    Qds=max(0,Qds);
        
    Qavg=(max(Qus,minc)+max(Qds,minc))/2;
    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
    evap=SR.(ds).(wds).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr); %EvapFactor = 0 to not have evap
    
    Qds=Qds-evap+gagediffportion(:,sr);
    if inadv3a_increaseint == 1
        Qds=Qds+sraddamt(:,sr);
    elseif inadv3b_increaseint == 1
        Qds=Qds+sraddamtds(:,sr);
    end    
    if adjustlastsrtogage==1 && sr==srb
        Qds=Qds+gagedifflast;
    end
    Qds=max(0,Qds);
    
    SR.(ds).(wds).(rs).Qusnodecal(:,sr)=Qusnode;    
    SR.(ds).(wds).(rs).Quscal(:,sr)=Qus;
    SR.(ds).(wds).(rs).Qdscal(:,sr)=Qds;    
    SR.(ds).Rivloc.flowriv.uscal(:,SR.(ds).(wds).(rs).locid(sr))=Qus;
    SR.(ds).Rivloc.flowriv.dscal(:,SR.(ds).(wds).(rs).locid(sr))=Qds;
    if SR.(ds).(wds).(rs).type(sr)==0
        SR.(ds).Gageloc.flowcal(:,SR.(ds).(wds).(rs).gagelocid)=Qusnode; %or Qus
    end

    Qusnode=Qds;           
end %sr
    end %r
end %wd
    
end  %runcalibloop

%save([basedir 'StateTL__ind3' srmethod '.mat'],'SR');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OUTPUT - full river / gage loop amounts
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if outputgage==1
    titlelocline=[{'atWDID'},{'Div'},{'WD'},{'Reach'},{'SubReach'},{'1-USWDID/2-DSWDID'}];
    if outputhr==1
        titledates=cellstr(datestr(rdates(datestid:end),'mm/dd/yy HH:'));
        writecell([titlelocline,titledates'],[outputfilename srmethod '_riverhr.csv']);
        writecell([titlelocline,titledates'],[outputfilename srmethod '_nativehr.csv']);
        writecell([titlelocline,titledates'],[outputfilename srmethod '_gagediffhr.csv']);
        writecell([titlelocline,titledates'],[outputfilename srmethod '_sraddhr.csv']);
        writecell([titlelocline,titledates'],[outputfilename srmethod '_totwcreducehr.csv']);
        if runcaptureloop==1
        writecell([titlelocline,titledates'],[outputfilename srmethod '_nativecapturehr.csv']);
        end
    end
    if outputday==1
        [yr,mh,dy,hr,mi,sec] = datevec(rdates(datestid:end));
        daymat=unique([yr,mh,dy],'rows','stable');
        titledatesday=cellstr(datestr([daymat zeros(size(daymat))],'mm/dd/yy'));
        writecell([titlelocline,titledatesday'],[outputfilename srmethod '_riverday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilename srmethod '_nativeday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilename srmethod '_gagediffday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilename srmethod '_sraddday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilename srmethod '_totwcreduceday.csv']);
        if runcaptureloop==1
        writecell([titlelocline,titledatesday'],[outputfilename srmethod '_nativecaptureday.csv']);
        end
    end
    for i=1:length(SR.(ds).Rivloc.loc(:,1))
        loclineriver(2*i-1,:)=[SR.(ds).Rivloc.loc(i,5),SR.(ds).Rivloc.loc(i,1:4),{2}];  %includes both ds/us sides of wdids and reaches - us of reach is ds of uswdid
        loclineriver(2*i,:)=  [SR.(ds).Rivloc.loc(i,6),SR.(ds).Rivloc.loc(i,1:4),{1}];
%        outputlineriver(2*i-1,:)=SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).Qus(datest:end,SR.(ds).Rivloc.loc{i,4})';
%        outputlineriver(2*i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).Qds(datest:end,SR.(ds).Rivloc.loc{i,4})';
        outputlineriver(2*i-1,:)=SR.(ds).Rivloc.flowriv.us(datestid:end,i)';
        outputlinenative(2*i-1,:)=SR.(ds).Rivloc.flownative.us(datestid:end,i)';
        outputlineriver(2*i,:)=SR.(ds).Rivloc.flowriv.ds(datestid:end,i)';
        outputlinenative(2*i,:)=SR.(ds).Rivloc.flownative.ds(datestid:end,i)';
        outputlinesradd(2*i-1,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).sraddamtus(datestid:end,SR.(ds).Rivloc.loc{i,4})';
        outputlinesradd(2*i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).sraddamtds(datestid:end,SR.(ds).Rivloc.loc{i,4})';
        if runcaptureloop==1
        outputlinenativecapture(2*i-1,:)=SR.(ds).Rivloc.flownativecapture.us(datestid:end,i)';
        outputlinenativecapture(2*i,:)=SR.(ds).Rivloc.flownativecapture.ds(datestid:end,i)';
        end

        outputlinetotwcreduce(2*i-1,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).wcreduceamt(datestid:end,SR.(ds).Rivloc.loc{i,4})';
        if SR.(ds).Rivloc.loc{i,4}==SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).SR(end)
            outputlinetotwcreduce(2*i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).wcreduceamtlast(datestid:end,1)';
        else
          outputlinetotwcreduce(2*i,:)=zeros(length(yr),1);
        end

%        loclinereach(i,:)=  [SR.(ds).Rivloc.loc(i,6),SR.(ds).Rivloc.loc(i,1:4),{1}];  %this will list the dswdid with a 1 to say upstream of wdid 
        loclinereach(i,:)=  [SR.(ds).Rivloc.loc(i,5),SR.(ds).Rivloc.loc(i,1:4),{2}];  %this will list the uswdid with a 2 to say downstream of wdid 
        outputlinegagediff(i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).gagediffportion(datestid:end,SR.(ds).Rivloc.loc{i,4})';
%        outputlinetotwcreduce(i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).wcreduceamt(datest:end,SR.(ds).Rivloc.loc{i,4})';
%        outputlineSRadd(i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).QSRadd(datest:end,SR.(ds).Rivloc.loc{i,4})';

    end
    if outputhr==1
        logm=['writing hourly output files for river/native amounts (hourly is a bit slow)'];
        domessage(logm,logfilename,displaymessage,writemessage)
        writecell([loclineriver,num2cell(outputlineriver)],[outputfilename srmethod '_riverhr.csv'],'WriteMode','append');
        writecell([loclineriver,num2cell(outputlinenative)],[outputfilename srmethod '_nativehr.csv'],'WriteMode','append');
        writecell([loclinereach,num2cell(outputlinegagediff)],[outputfilename srmethod '_gagediffhr.csv'],'WriteMode','append');
        writecell([loclineriver,num2cell(outputlinesradd)],[outputfilename srmethod '_sraddhr.csv'],'WriteMode','append');
        writecell([loclineriver,num2cell(outputlinetotwcreduce)],[outputfilename srmethod '_totwcreducehr.csv'],'WriteMode','append');
        if runcaptureloop==1
        writecell([loclineriver,num2cell(outputlinenativecapture)],[outputfilename srmethod '_nativecapturehr.csv'],'WriteMode','append');
        end
    end
    if outputday==1
        logm=['writing daily output files for river/native amounts'];
        domessage(logm,logfilename,displaymessage,writemessage)
        for i=1:length(daymat(:,1))
            dayids=find(yr==daymat(i,1) & mh==daymat(i,2) & dy==daymat(i,3));
            outputlinedayriver(:,i)=mean(outputlineriver(:,dayids),2);
            outputlinedaynative(:,i)=mean(outputlinenative(:,dayids),2);
            outputlinedaygagediff(:,i)=mean(outputlinegagediff(:,dayids),2);
            outputlinedaysradd(:,i)=mean(outputlinesradd(:,dayids),2);
            outputlinedaytotwcreduce(:,i)=mean(outputlinetotwcreduce(:,dayids),2);
            if runcaptureloop==1
            outputlinedaynativecapture(:,i)=mean(outputlinenativecapture(:,dayids),2);
            end
        end
        writecell([loclineriver,num2cell(outputlinedayriver)],[outputfilename srmethod '_riverday.csv'],'WriteMode','append');        
        writecell([loclineriver,num2cell(outputlinedaynative)],[outputfilename srmethod '_nativeday.csv'],'WriteMode','append');
        writecell([loclinereach,num2cell(outputlinedaygagediff)],[outputfilename srmethod '_gagediffday.csv'],'WriteMode','append');        
        writecell([loclineriver,num2cell(outputlinedaysradd)],[outputfilename srmethod '_sraddday.csv'],'WriteMode','append');        
        writecell([loclineriver,num2cell(outputlinedaytotwcreduce)],[outputfilename srmethod '_totwcreduceday.csv'],'WriteMode','append');        
        if runcaptureloop==1
        writecell([loclineriver,num2cell(outputlinedaynativecapture)],[outputfilename srmethod '_nativecaptureday.csv'],'WriteMode','append');
        end
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OUTPUT - water class amounts
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if outputwc==1 & isfield(SR.(ds),'WCloc')

wwcnums=SR.(ds).WCloc.wslist;
%titlelocline=[{'WCnum'},{'WC code'},{'Div'},{'WD'},{'Reach'},{'SubReach'},{'srid'},{'1-US/2-DS'},{'WDID'}];
titlelocline=[{'WCnum'},{'WC code'},{'atWDID'},{'Div'},{'WD'},{'Reach'},{'SubReach'},{'1-USWDID/2-DSWDID'}];

if outputhr==1
    logm=['writing hourly output file by water class amounts (hourly is a bit slow)'];
    domessage(logm,logfilename,displaymessage,writemessage)
    titledates=cellstr(datestr(rdates(datestid:end),'mm/dd/yy HH:'));
    writecell([titlelocline,titledates'],[outputfilename srmethod '_wchr.csv']);
    writecell([titlelocline,titledates'],[outputfilename srmethod '_wcsraddhr.csv']);
    writecell([titlelocline,titledates'],[outputfilename srmethod '_wcreducehr.csv']);
    if runcaptureloop==1
    writecell([titlelocline,titledates'],[outputfilename srmethod '_wccapturehr.csv']);
    end
end
if outputday==1
    logm=['writing daily output file by water class amounts'];
    domessage(logm,logfilename,displaymessage,writemessage)
    [yr,mh,dy,hr,mi,sec] = datevec(rdates(datestid:end));
    daymat=unique([yr,mh,dy],'rows','stable');
    titledatesday=cellstr(datestr([daymat zeros(size(daymat))],'mm/dd/yy'));
    writecell([titlelocline,titledatesday'],[outputfilename srmethod '_wcday.csv']);
    writecell([titlelocline,titledatesday'],[outputfilename srmethod '_wcreduceday.csv']);
    writecell([titlelocline,titledatesday'],[outputfilename srmethod '_wcsraddday.csv']);
    if runcaptureloop==1
    writecell([titlelocline,titledatesday'],[outputfilename srmethod '_wccaptureday.csv']);
    end
end


for w=1:length(wwcnums)
    ws=wwcnums{w};
    clear loclinewc outputlinewc outputlinedaywc outputlinewcsradd outputlinedaywcsradd outputlinewcreduce outputlinedaywcreduce loclinewcreduce outputlinewccapture outputlinedaywccapture
    outwcreduce=0;k=0;
    for i=1:length(SR.(ds).WCloc.(ws).loc(:,1))  %JVO said wanted both us and ds of WDID (??) - OK then
        if SR.(ds).WCloc.(ws).loc{i,6}==1 %release - list from us to ds
           loclinewc(2*i-1,:)=[{ws},{SR.(ds).WCloc.(ws).wc},SR.(ds).WCloc.(ws).loc(i,7),SR.(ds).WCloc.(ws).loc(i,1:4),{2}];
           outputlinewc(2*i-1,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).Qusrelease(datestid:end,SR.(ds).WCloc.(ws).loc{i,4})';
           loclinewc(2*i,:)=[{ws},{SR.(ds).WCloc.(ws).wc},SR.(ds).WCloc.(ws).loc(i,8),SR.(ds).WCloc.(ws).loc(i,1:4),{1}];
           outputlinewc(2*i,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).Qdsrelease(datestid:end,SR.(ds).WCloc.(ws).loc{i,4})';
           outputlinewcsradd(2*i-1,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).QSRaddus(datestid:end,SR.(ds).WCloc.(ws).loc{i,4})';
           outputlinewcsradd(2*i,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).QSRaddds(datestid:end,SR.(ds).WCloc.(ws).loc{i,4})';
                      
           if isfield(SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws),'wcreduceamt')
               outwcreduce=1;k=k+1;
                loclinewcreduce(k,:)=[{ws},{SR.(ds).WCloc.(ws).wc},SR.(ds).WCloc.(ws).loc(i,7),SR.(ds).WCloc.(ws).loc(i,1:4),{2}]; %lists usreach/ds wdid
                outputlinewcreduce(k,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).wcreduceamt(datestid:end,SR.(ds).WCloc.(ws).loc{i,4})';
                if R.(ds).WCloc.(ws).loc{i,4}==SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).SR(end)
                    k=k+1;
                    loclinewcreduce(k,:)=[{ws},{SR.(ds).WCloc.(ws).wc},SR.(ds).WCloc.(ws).loc(i,7),SR.(ds).WCloc.(ws).loc(i,1:4),{1}]; %lists dsreach/us wdid
                    outputlinewcreduce(k,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).wcreduceamtlast(datestid:end,1)';
                end
           end
           
        else  %exchange - list from ds to us - if ok from us to ds could delete these
           loclinewc(2*i-1,:)=[{ws},{SR.(ds).WCloc.(ws).wc},SR.(ds).WCloc.(ws).loc(i,8),SR.(ds).WCloc.(ws).loc(i,1:4),{1}];
           outputlinewc(2*i-1,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).Qdsrelease(datestid:end,SR.(ds).WCloc.(ws).loc{i,4})';
           loclinewc(2*i,:)=[{ws},{SR.(ds).WCloc.(ws).wc},SR.(ds).WCloc.(ws).loc(i,7),SR.(ds).WCloc.(ws).loc(i,1:4),{2}];
           outputlinewc(2*i,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).Qusrelease(datestid:end,SR.(ds).WCloc.(ws).loc{i,4})';
           outputlinewcsradd(2*i-1,:)=zeros(1,length(rdates(datestid:end)));
           outputlinewcsradd(2*i,:)=zeros(1,length(rdates(datestid:end)));   
        end
        
           %this is repeating wc output but changing to capture amount at destination.. need/want??
           %if remove above switch for exchanges would need to switch where captureamt placed for exchanges
           if runcaptureloop==1
           if i==length(SR.(ds).WCloc.(ws).loc(:,1))
               outputlinewccapture(2*i-1,:)=outputlinewc(2*i-1,:);
               outputlinewccapture(2*i,:)=SR.(ds).WCloc.(ws).captureamt(datestid:end,:)';
           else
               outputlinewccapture(2*i-1,:)=outputlinewc(2*i-1,:);
               outputlinewccapture(2*i,:)=outputlinewc(2*i,:);
           end
           end
        
    end 
    
    if outputhr==1
        writecell([loclinewc,num2cell(outputlinewc)],[outputfilename srmethod '_wchr.csv'],'WriteMode','append');
        writecell([loclinewc,num2cell(outputlinewcsradd)],[outputfilename srmethod '_wcsraddhr.csv'],'WriteMode','append');
        if runcaptureloop==1
        writecell([loclinewc,num2cell(outputlinewccapture)],[outputfilename srmethod '_wccapturehr.csv'],'WriteMode','append');
        end
           if outwcreduce==1
                writecell([loclinewcreduce,num2cell(outputlinewcreduce)],[outputfilename srmethod '_wcreducehr.csv'],'WriteMode','append');
           end
    end

    if outputday==1
        for i=1:length(daymat(:,1))
            dayids=find(yr==daymat(i,1) & mh==daymat(i,2) & dy==daymat(i,3));
            outputlinedaywc(:,i)=mean(outputlinewc(:,dayids),2);
            outputlinedaywcsradd(:,i)=mean(outputlinewcsradd(:,dayids),2);
            if runcaptureloop==1
            outputlinedaywccapture(:,i)=mean(outputlinewccapture(:,dayids),2);
            end
           if outwcreduce==1
                outputlinedaywcreduce(:,i)=mean(outputlinewcreduce(:,dayids),2);
           end
        end
        writecell([loclinewc,num2cell(outputlinedaywc)],[outputfilename srmethod '_wcday.csv'],'WriteMode','append');        
        writecell([loclinewc,num2cell(outputlinedaywcsradd)],[outputfilename srmethod '_wcsraddday.csv'],'WriteMode','append');
        if runcaptureloop==1
        writecell([loclinewc,num2cell(outputlinedaywccapture)],[outputfilename srmethod '_wccaptureday.csv'],'WriteMode','append');
        end
        if outwcreduce==1
            writecell([loclinewcreduce,num2cell(outputlinedaywcreduce)],[outputfilename srmethod '_wcreduceday.csv'],'WriteMode','append');             
        end
    end
end

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OUTPUT - comparison of gage and simulated amounts at gage
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if outputcal==1 & runcalibloop==1
    titlelocline=[{'WDID'},{'Abbrev'},{'Div'},{'WD'},{'Reach'},{'SubReach'},{'1-Gage/2-Sim'}];
    if outputhr==1
        titledates=cellstr(datestr(rdates(datestid:end),'mm/dd/yy HH:'));
        writecell([titlelocline,titledates'],[outputfilename srmethod '_calhr.csv']);
    end
    if outputday==1
        [yr,mh,dy,hr,mi,sec] = datevec(rdates(datestid:end));
        daymat=unique([yr,mh,dy],'rows','stable');
        titledatesday=cellstr(datestr([daymat zeros(size(daymat))],'mm/dd/yy'));
        writecell([titlelocline,titledatesday'],[outputfilename srmethod '_calday.csv']);
    end
    for wd=WDcaliblist
        wds=['WD' num2str(wd)];
        wdsids=intersect(find(strcmp(SR.(ds).Gageloc.loc(:,1),ds)),find(strcmp(SR.(ds).Gageloc.loc(:,2),wds)));
        for i=1:length(wdsids)
            j=wdsids(i);
            loclinegage(2*i-1,:)=[SR.(ds).Gageloc.loc(j,5:6),SR.(ds).Rivloc.loc(j,1:4),{1}];  %includes both gage and simulated on subseqent lines
            loclinegage(2*i,:)=  [SR.(ds).Gageloc.loc(j,5:6),SR.(ds).Rivloc.loc(j,1:4),{2}];
            outputlinegage(2*i-1,:)=SR.(ds).Gageloc.flowgage(datestid:end,j)';
            outputlinegage(2*i,:)=SR.(ds).Gageloc.flowcal(datestid:end,j)';
        end
    end
    if outputhr==1
        logm=['writing hourly output files for gage and simulated (calibration) amounts (hourly is a bit slow)'];
        domessage(logm,logfilename,displaymessage,writemessage)
        writecell([loclinegage,num2cell(outputlinegage)],[outputfilename srmethod '_calhr.csv'],'WriteMode','append');
    end
    if outputday==1
        logm=['writing daily output files for gage and simulated (calibration) amounts'];
        domessage(logm,logfilename,displaymessage,writemessage)
        for i=1:length(daymat(:,1))
            dayids=find(yr==daymat(i,1) & mh==daymat(i,2) & dy==daymat(i,3));
            outputlinedaygage(:,i)=mean(outputlinegage(:,dayids),2);
        end
        writecell([loclinegage,num2cell(outputlinedaygage)],[outputfilename srmethod '_calday.csv'],'WriteMode','append');        
    end
end

%%%%%%%%%%%%%%%%%%%%%
% END of mainline script

logm=['Done Running StateTL endtime: ' datestr(now) ' elapsed (DD:HH:MM:SS): ' datestr(now-runstarttime,'DD:HH:MM:SS')];    %log message
if displaymessage~=1;disp(logm);end
domessage(logm,logfilename,displaymessage,writemessage)

%%%%%%%%%%%%%%%%%%%%%%%%%%



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

minc=1;
%posids=find(Qus>0);        %at least for wc releases this limits to release times; could potentially have celerity time series as time ser..
%Qusavg=mean(Qus(posids));  %orig single celerity / as add to time series length - may need to do this on smaller time steps??

%when commented out above; trying celerity/dispersion as time series ... NOT SURE IF CORRECT TO DO WITH CHANGING CELERITY/DISPERSION??
% negids=find(Qus<0); - %commenting these two out for speed but may want in for safety
% Qus(negids)=0;

channellength=SR.(ds).(wds).(rs).channellength(sr);
if celerity==-999
    celeritya=SR.(ds).(wds).(rs).celeritya(sr);
    celerityb=SR.(ds).(wds).(rs).celerityb(sr);
%    celerity=celeritya*Qusavg^celerityb;
    celerity=celeritya*max(minc,Qus).^celerityb;
end
if dispersion==-999
    dispersiona=SR.(ds).(wds).(rs).dispersiona(sr);
    dispersionb=SR.(ds).(wds).(rs).dispersionb(sr);
%    dispersion=dispersiona*Qusavg^dispersionb;
    dispersion=dispersiona*max(minc,Qus).^dispersionb;
end

losspercent=SR.(ds).(wds).(rs).losspercent(sr);
dspercent=(1-losspercent/100);

%Muskinghum-Cunge parameters
dt=rhours * 60 * 60; %sec
dx=channellength * 5280; %ft
X = 1/2 - dispersion ./ (celerity * dx);
Cbot = 2 * (1-X) + celerity *(dt/dx);
C0 = (celerity * (dt/dx) - 2 * X) ./ Cbot;
C1 = (celerity * (dt/dx) + 2 * X) ./ Cbot;
C2 = ( 2 * (1-X) - celerity * (dt/dx)) ./ Cbot;

Qds=ones(rsteps,1);
Qds(1,1) = Qus(1,1) * dspercent; %spinup??

for n=1:rsteps-1  %Muskinghum-Cunge Routing
    Qds (n+1,1) = (C0(n) * Qus (n+1,1) * dspercent) + (C1(n) * Qus (n,1) * dspercent) + C2(n) * Qds(n,1);
%    Qds (n+1,1) = (C0 * Qus (n+1,1) * dspercent) + (C1 * Qus (n,1) * dspercent) + C2 * Qds(n,1);
%    Qds (n+1,1) = Qus (n+1,1) * dspercent;
end

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%function for subreach to take upstream hydrograph and subreach specific data, build input card, 
%run TLAP/j349 fortran, read output card, and return resulting downstream hydrograph

function [Qds,celerity,dispersion]=runj349f(ds,wds,rs,sr,Qus,gain,rdays,rhours,rsteps,j349dir,celerity,dispersion)
global SR


channellength=SR.(ds).(wds).(rs).channellength(sr);
alluviumlength=SR.(ds).(wds).(rs).alluviumlength(sr);
transmissivity=SR.(ds).(wds).(rs).transmissivity(sr);
storagecoefficient=SR.(ds).(wds).(rs).storagecoefficient(sr);
aquiferwidth=SR.(ds).(wds).(rs).aquiferwidth(sr);
closure=SR.(ds).(wds).(rs).closure(sr);
if length(celerity)>1
    posids=find(Qus>0);        %currently j349 only works with a single celerity (change??!!)
    celerity=mean(celerity(posids));
    dispersion=mean(dispersion(posids));
elseif celerity==-999
    minc=1;   
    Qusavg=max(minc,mean(Qus));  %watch - this would be different than TLAP; but think basing on that subreach flow might be more correct
    %Qusavg=(667+ARKAVOCO)/2; %current in TLAP- based on average flow for entire reach
    dispersiona=SR.(ds).(wds).(rs).dispersiona(sr);
    dispersionb=SR.(ds).(wds).(rs).dispersionb(sr);
    celeritya=SR.(ds).(wds).(rs).celeritya(sr);
    celerityb=SR.(ds).(wds).(rs).celerityb(sr);
    dispersion=dispersiona*Qusavg^dispersionb;
    celerity=celeritya*Qusavg^celerityb;
end

stagedischarge=SR.(ds).stagedischarge.(['SD' num2str(SR.(ds).(wds).(rs).sdnum(sr))]);

inputcardfilename=['StateTL_' ds wds rs 'SR' num2str(sr) '_us.dat'];
outputcardfilename=['StateTL_' ds wds rs 'SR' num2str(sr) '_ds.dat'];

fid=fopen([j349dir inputcardfilename],'w');

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

fid=fopen([j349dir 'filenames'],'w');
fprintf(fid,'%s\r\n',inputcardfilename);
fprintf(fid,'%s\r\n',outputcardfilename);
fclose(fid);

[s, w] = dos([j349dir 'j349.exe']);

fid=fopen([j349dir outputcardfilename],'r');

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



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function to route exchanges or other water from DS to US (in reverse time) using same celerity coefficients..
%


function [QEus,srtimerem,celerity,srtime]=reversecelerity(ds,wds,rs,sr,QEds,exchtimerem,rhours,rsteps,celerity)
global SR


if celerity==-999
    Qriv=(SR.(ds).(wds).(rs).Qus(:,sr)+SR.(ds).(wds).(rs).Qds(:,sr))/2;
    posids=find(QEds<0);  %using time with exchange (QEds should be negative) to calc avg; if spaces or periods may want to break down by period(?), could have celerity time series but time gets complicated..
    Qdstot=-1*QEds+Qriv;  %for celerity adding river to exchange amount (ie timing if the exchange would have been released from us)
    Qdsavg=mean(Qdstot(posids));
    celeritya=SR.(ds).(wds).(rs).celeritya(sr);
    celerityb=SR.(ds).(wds).(rs).celerityb(sr);
    celerity=celeritya*Qdsavg^celerityb;
elseif length(celerity)>1
    posids=find(QEds<0);
    celerity=mean(celerity(posids));
end

%believe celerity is in ft/s
channellength=SR.(ds).(wds).(rs).channellength(sr);
dt=rhours * 60 * 60; %sec
srtime=(channellength*5280)/celerity/dt;  %back in hours

%try to deal with things being in hours
srtimeadj=srtime+exchtimerem;  %add in fractional hours remaining from last subreach
srtimehrs=round(srtimeadj);
srtimerem=srtimeadj-srtimehrs;

%QEus=zeros(1,rsteps);
%QEus(1:rsteps-srtimehrs)=QEds(1+srtimehrs:end);
QEus=zeros(rsteps,1);
QEus(1:rsteps-srtimehrs,1)=QEds(1+srtimehrs:end,1);

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function to take messages and display to screen and/or write to logfile
% currently closing file after writing in case error crashes
% could eventually remove to potentially speed up

function domessage(logm,logfilename,displaymessage,writemessage)
if displaymessage==1
    disp(logm);
end
if writemessage==1
    fidlog=fopen(logfilename,'a');
    fprintf(fidlog,'%s\r\n',logm);
    fclose(fidlog);
end

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function just to find mean, linear regression, or least squares regression
%
function [yfit,m,b,R2,SEE]=regr(x,y,meth)

if strcmp(meth,'linreg')
   X=[ones(length(x),1) x];M=X\y;m=M(2,:);b=M(1,:);yfit=m.*x+b;R2=1-sum((y-yfit).^2)./sum((y-mean(y)).^2);SEE=(sum((x-y).^(2))./(length(x)-1)).^(0.5);
elseif strcmp(meth,'leastsquares')
   m=x\y;yfit=m.*x;R2 = 1 - sum((y - yfit).^2)./sum((y - mean(y)).^2);SEE=(sum((x-y).^(2))./(length(x)-1)).^(0.5);b=zeros(1,length(m));
elseif strcmp(meth,'mean')
    b=mean(y);yfit=b.*ones(size(y));m=zeros(1,length(b));R2=zeros(1,length(b));SEE=zeros(1,length(b));
else
    error(['could not figure out regression method given listed option:' meth ' (looking for mean, linreg, or leastsquares)'])    
end

end







