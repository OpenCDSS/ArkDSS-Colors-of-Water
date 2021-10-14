%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% StateTL
% Matlab (preliminary) Colors of Water Transit Loss and Timing engine
% State of Colorado - Division of Water Resources / Colorado Water Conservation Board
%

%cd C:\Projects\Ark\ColorsofWater\matlab
clear all
runstarttime=now;
basedir=cd;basedir=[basedir '\'];
%j349dir=[basedir 'j349dir\']; %currently need to a cd where run fortran but may slow to cd at every instance
j349dir=basedir;


%%%%%%%%%%%%%%%%%%%%%%%%%%
%Run control options (on=1) fed through control file need to be in this list -
%watch out - if change variable names in code also need to change them here!
%currently - if leave out one of these from control file will assign it a zero value
controlvars={'srmethod','j349fast','j349multurf','inputfilename','rundays','fullyear','readinputfile','readevap','readstagedischarge','pullstationdata','pulllongtermstationdata','pullreleaserecs','runriverloop','runwcloop','doexchanges','runcaptureloop','runcalibloop'};
controlvars=[controlvars,{'logfilename','displaymessage','writemessage','outputfilebase','outputgage','outputwc','outputcal','outputhr','outputday','calibavggainloss'}];
controlfilename='StateTL_control.txt';


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% additional variable/run options
% potentially some these might also be put into text file

rhours=1;                  %timestep in hours
spinupdayspartialyear=30;  %days to spinup (bank/aquifer storage for j349) if partial year
spinupdaysfullyear=9;      %days to spinup if full year option ((366days+9days)*24=9000 dimension in j349)

flowcriteria=5;            %to establish gage and node flows: 1 low, 2 avg, 3 high flow values from livingston; envision 4 for custom entry; 5 for actual flows; 6 average for xdays/yhours prior to now/date; 7 average between 2 dates
iternum.j349=5;            %iterations of gageflow loop given method to iterate on gagediff (gain/loss/error correction for estimated vs actual gage flows) (had been using dynamic way to iterate but currently just number);
iternum.muskingum=5;
iternum.default=5;
pred=0;                    %if pred=0 subtracts water class from existing flows, if 1 adds to existing gage flows; not really using yet
percrule=.10;              %percent rule - TLAP currently uses 10% of average release rate as trigger amount (Livingston 2011 says 10%; past Livingston 1978 detailed using 5% believe defined as 5% of max amount at headgate)

adjustlastsrtogage=1;     %although gagediff process should be getting last sr very close to gage, this would make a final adjustment to exactly equal
inadv1a_letwaterby=1;      %this will let a single water class amt get by an internal node although wc amt exceeds initially estimated river amt - hopefully until internal river amt can be adjusted upwards by last step(ie since have no actual river data at internal node) 
inadv1b_letwaterby=0;      %not currently working - this will let a single water class amt get by an internal node although wc amt exceeds initially estimated river amt - B by temporarily increasing river amts
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
savefinalcalfile=0;  %saves final file after calibration loop, big and only need if want StateTLplot for cal after clearing

evapnew=1;           %1=use new evap method (statewide et dataset) or else old single curve
    evapstartyear=2000;
    ETfilename='StateTL_evapDiv2.mat';
    convertevap=5280/(25.4*12*86400); %convert from mm/day to cfs / mile / ft
    etostoevap=1.05;  %standard for lake evap but may want to go higher with factor...
    
avgstartyear=2000;      %if pulllongtermstationdata=1 in control file, year to start pull of daily data to establish dry/wet/avgs for filling
useregrfillforgages=0;  %will fill gages with data from closest stations using regression filling - currently believe other options better (ie 0)
    regfillwindow=28*24; %regression fill window hrs=(days*24)
trendregwindow=14*24;  %hrs to estimate trend for end filling
avgwindow=[7*24 30*24]; %2 values - 1) hrs to start to apply dry/avg/wet average within weighting, 2) hrs to start to apply straight up average     

structureurl='https://dwr.state.co.us/Rest/GET/api/v2/structures/';  %currently used to get structure coordinates just for evaporation
telemetryhoururl='https://dwr.state.co.us/Rest/GET/api/v2/telemetrystations/telemetrytimeserieshour/';  %for gages and ditch telemetry
telemetrydayurl='https://dwr.state.co.us/Rest/GET/api/v2/telemetrystations/telemetrytimeseriesday/';  %for gages and ditch telemetry
surfacewaterdayurl='https://dwr.state.co.us/Rest/GET/api/v2/surfacewater/surfacewatertsday/';  %for published daily gage/ditch data
divrecdayurl='https://dwr.state.co.us/Rest/GET/api/v2/structures/divrec/divrecday/';   %for release/diversion records
logwdidlocations=1;  %for log also document all wdid locations when pulled for evap
load([basedir 'StateTL_llave.mat']);

%%%%%%%%%%%%%%%%%%%%%%%%%%
%READ INITIAL RUN INFO
% initially have WDlist in xlsx that defines division and WDs to run in order (upper tribs first)
%%%%%%%%%%%%%%%%%%%%%%%%%%

logmc={['Running StateTL starting: ' datestr(runstarttime)]};    %log message
disp(logmc{1});    %log message

fid=fopen(controlfilename);
if fid==-1
    logmc=[logmc;'Error: Could not find text file with run control options: ' basedir controlfilename];
    errordlg(logmc)
    error(logmc{2});
else
    logmc=[logmc;'Reading text file with run control options: ' basedir controlfilename];
end

for i=1:length(controlvars)  %initially set these to zero
    eval([controlvars{i} '=0;']);
end
displaymessage=1; %default 1

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
   controlvarsid=find(strcmpi(line(1:tids(1)-1),controlvars));
   logtxt='Control file: ';
   if 1==2
   elseif ~isempty(controlvarsid)   %variables listed in controlvarsid with single value as input; text should be in single quotes
       eval([controlvars{controlvarsid} '=' line(tids(1)+1:tids(2)-1) ';']);
   elseif strcmpi(line(1:eids(1)-1),'div')   %Division - currently only set to one at a time but with a bit of code revision could run multiple
       d=str2double(line(tids(1)+1:tids(2)-1));
       ds=['D' num2str(d)];
       if length(tids)>2
            logmc=[logmc;'Warning: more than one Division listed in run options / currently not set to run multiple divisions at once (but very easily can be) - just running first listed Div'];
       end
   elseif strcmpi(line(1:eids(1)-1),'wdlist')   %WD run list in order; seperate by commas from upper tribs first to lower/mainstem
       WDlist=[];
       for i=1:length(tids)-1
            wd=str2double(line(tids(i)+1:tids(i+1)-1));
            WDlist=[WDlist,wd];
       end
   elseif strcmpi(line(1:eids(1)-1),'wdcaliblist')   %WD to calibrate if running calibloop, if multiple seperate by commas
       WDcaliblist=[];
       for i=1:length(tids)-1
            wd=str2double(line(tids(i)+1:tids(i+1)-1));
            WDcaliblist=[WDcaliblist,wd];
       end
   elseif strcmpi(line(1:eids(1)-1),'datestart')   %calib startdate year,month,day
       yearstart=str2double(line(tids(1)+1:tids(2)-1));
       if length(tids)>2
            datestart=datenum(yearstart,str2double(line(tids(2)+1:tids(3)-1)),str2double(line(tids(3)+1:tids(4)-1)));
       else
           datestart=datenum(yearstart,1,1);
       end
   elseif strcmpi(line(1:eids(1)-1),'calibstartdate')   %calib startdate year,month,day
       calibstartdate=datenum(str2double(line(tids(1)+1:tids(2)-1)),str2double(line(tids(2)+1:tids(3)-1)),str2double(line(tids(3)+1:tids(4)-1)));
   elseif strcmpi(line(1:eids(1)-1),'calibenddate')   %calib enddate year,month,day
       calibenddate=datenum(str2double(line(tids(1)+1:tids(2)-1)),str2double(line(tids(2)+1:tids(3)-1)),str2double(line(tids(3)+1:tids(4)-1)));
   else
       logtxt='WARNING: control file line not executed: ';
   end
   logmc=[logmc;logtxt line(1:tids(end)-1)];
   end
end
fclose(fid);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initial log write/display given options from control file
if writemessage==1
    fidlog=fopen(logfilename,'w');
end
for i=1:length(logmc)
    if displaymessage==1
        disp(logmc{i});
    end
    if writemessage==1
        fprintf(fidlog,'%s\r\n',logmc{i});
    end
end
if writemessage==1
    fclose(fidlog);   %for log, closing file after every write in case of crash (could speed up by removing this in domessage function)
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initial date/time work - will need improvement
% want to tag onto SR for date checks when loading mat files
% and potential flexibility to use annual based mat files if doing partial years

if fullyear==1  %whole calendar year starting on Jan1
    datestart=datenum(yearstart,1,1);
    spinupdays=spinupdaysfullyear;
    rdays=datenum(yearstart,12,31)-datestart+1+spinupdays;  %if doing whole year
else
    rundays=max(1,rundays);    %rundays is days without spinup, will override zero to one
    rundays=min(366,rundays);  %max of a year as j349 dimensions set at 9000
    spinupdays=min(spinupdayspartialyear,375-rundays);
    rdays=rundays+spinupdays;  %rdays is with spinup
end

rsteps=rdays*24/rhours;
datestid=spinupdays*24/rhours+1;
rdates=datestart*ones(spinupdays*24/rhours,1);
rdates=[rdates;[datestart:rhours/24:datestart+(rdays-spinupdays)-rhours/24]'];
[ryear,rmonth,rday,rhour] = datevec(rdates);
rdatesstr=cellstr(datestr(rdates,31));
rdatesday=floor(rdates);
rjulien=rdatesday-(datenum(ryear,1,1)-1);
dateend=datestart+(rdays-spinupdays)-1;
datedays=[datestart:dateend];

nowvec=datevec(now);
%avgdates=[datenum(avgstartyear,1,1):datenum(nowvec(1)-1,12,31)];
avgdates=[datenum(avgstartyear,1,1):datenum(nowvec(1),12,31)];



%%%%%%%%%%%%%%%%%%%%%%%%%%
%READ SUBREACH INFORMATION
%  initially have in xlsx but this will eventually all come from HB/REST
%%%%%%%%%%%%%%%%%%%%%%%%%%
global SR

if readinputfile==1

%%%%%%%%%%%%%%%%%%%%%%%%%%    
% read subreach data    
logm=['reading subreach info from file: ' basedir inputfilename];
domessage(logm,logfilename,displaymessage,writemessage)

if inputfilename(end-3:end)=='xlsx'
    inforaw=readcell([basedir inputfilename],'Sheet','SR');
else
    inforaw=readcell([basedir inputfilename]);
end
[inforawrow,inforawcol]=size(inforaw);

%[infonum,infotxt,inforaw]=xlsread([basedir inputfilename],'SR');
%[inforawrow inforawcol]=size(inforaw);

infoheaderrow=1;

for i=1:inforawcol
    if 1==2

    elseif strcmpi(inforaw{infoheaderrow,i},'WDID'); infocol.uswdid=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'NAME'); infocol.usname=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'DSWDID'); infocol.dswdid=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'DSNAME'); infocol.dsname=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'RELEASESTRUCTURE'); infocol.rels=i;       
    elseif strcmpi(inforaw{infoheaderrow,i},'BRANCH'); infocol.branch=i;
    
    elseif strcmpi(inforaw{infoheaderrow,i},'DIV'); infocol.div=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'WD'); infocol.wd=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'REACH'); infocol.reach=i;
%     elseif strcmpi(inforaw{infoheaderrow,i},'LIVINGSTON SUBREACH'); infocol.livingstonsubreach=i; %delete when expanding model
    elseif strcmpi(inforaw{infoheaderrow,i},'SUBREACH'); infocol.subreach=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'SRID'); infocol.srid=i;

    elseif strcmpi(inforaw{infoheaderrow,i},'CHANNEL LENGTH'); infocol.channellength=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'ALLUVIUM LENGTH'); infocol.alluviumlength=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'REACH PORTION'); infocol.reachportion=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'LOSSPERCENT'); infocol.losspercent=i;
        
    elseif strcmpi(inforaw{infoheaderrow,i},'TRANSMISSIVITY'); infocol.transmissivity=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'STORAGE COEFFICIENT'); infocol.storagecoefficient=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'AQUIFER WIDTH'); infocol.aquiferwidth=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'DISPERSION-A'); infocol.dispersiona=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'DISPERSION-B'); infocol.dispersionb=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'CELERITY-A'); infocol.celeritya=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'CELERITY-B'); infocol.celerityb=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'CELERITY-B'); infocol.celerityb=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'CelerityMethod'); infocol.celeritymethod=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'DispersionMethod'); infocol.dispersionmethod=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'SDNUM'); infocol.sdnum=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'CLOSURE'); infocol.closure=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'GAININITIAL'); infocol.gaininitial=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'WIDTH-A'); infocol.widtha=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'WIDTH-B'); infocol.widthb=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'EVAPFACTOR'); infocol.evapfactor=i;

    elseif strcmpi(inforaw{infoheaderrow,i},'TYPE'); infocol.type=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'STATION'); infocol.station=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'PARAMETER'); infocol.parameter=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'LOW'); infocol.low=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'AVG'); infocol.avg=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'HIGH'); infocol.high=i;

    end
end

k=0;
wdidk=0;sridk=0;
for i=infoheaderrow+1:inforawrow
    
    if ~isempty(inforaw{i,infocol.subreach}) && ~ismissing(inforaw{i,infocol.subreach})
        for j=1:inforawcol  %doing this as a quick fix for converting from xlsread to readcell
            if ismissing(inforaw{i,j})
                inforaw{i,j}=[NaN];            
            end
        end

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
        v.cm=inforaw{i,infocol.celeritymethod};if ischar(v.cm); v.cm=str2num(v.cm); end
        v.dm=inforaw{i,infocol.dispersionmethod};if ischar(v.dm); v.dm=str2num(v.dm); end 
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
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).avgflow(1,v.sr)=v.l1;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).avgflow(2,v.sr)=v.a1;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).avgflow(3,v.sr)=v.h1;
%         SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).low(1,v.sr)=v.l1;
%         SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).avg(1,v.sr)=v.a1;
%         SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).high(1,v.sr)=v.h1;
        
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
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).celeritymethod(v.sr)=v.cm;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dispersionmethod(v.sr)=v.dm;
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
        
        %wdid listing - all wdids in at least once
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
        
        % new - subreach listing; quite similar also to Rivloc.loc (may want to delete that one); includes type
        sridk=sridk+1;
        SR.(['D' c.di]).SR{sridk,1}=c.uw;
        SR.(['D' c.di]).SR{sridk,2}=c.dw;
        SR.(['D' c.di]).SR{sridk,3}=v.di;
        SR.(['D' c.di]).SR{sridk,4}=v.wd;
        SR.(['D' c.di]).SR{sridk,5}=v.re;
        SR.(['D' c.di]).SR{sridk,6}=v.sr;
        SR.(['D' c.di]).SR{sridk,7}=['D' c.di];
        SR.(['D' c.di]).SR{sridk,8}=['WD' c.wd];
        SR.(['D' c.di]).SR{sridk,9}=['R' c.re];
        SR.(['D' c.di]).SR{sridk,10}=v.t1;  %type
        
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
% SR.(ds).WDID = WDID,d,wd,r,sr, 0 if usnode (at top of wd) or 1 if dsnode (rest)

WDIDsortedbywdidlist=[];
SRsortedbywdidlist=[];
for wd=WDlist
    wdinwdidlist=find([SR.(ds).WDID{:,3}]==wd);
    WDIDsortedbywdidlist=[WDIDsortedbywdidlist;SR.(ds).WDID(wdinwdidlist,:)];
    wdinwdidlist=find([SR.(ds).SR{:,4}]==wd);
    SRsortedbywdidlist=[SRsortedbywdidlist;SR.(ds).SR(wdinwdidlist,:)];
end
SR.(ds).WDID=WDIDsortedbywdidlist;
SR.(ds).SR=SRsortedbywdidlist;

%%%%%%%%%%%%%%%%%%%%%%%%5
%WARNING / WATCH
%quick fix - for moment if using csv, still get evap (old) and stagedischarge out of xlsx
if ~strcmp(inputfilename(end-3:end),'xlsx')  
    inputfilename=[inputfilename(1:end-3) 'xlsx'];
end


% for wd=WDlist
%     wds=['WD' num2str(wd)];
%     SR.(ds).stagedischarge=infonum;
% end

clear c v info*

save([basedir 'StateTL_SRdata.mat'],'SR');

else
    load([basedir 'StateTL_SRdata.mat']);
end


%%%%%%%%%%%%%%%%%%
% Old Evaporation data - original single curve data for wd17
if evapnew~=1
    if readevap==1
        infonum=readmatrix([basedir inputfilename],'Sheet','evap');
        [infonumrow infonumcol]=size(infonum);        
        for wd=SR.(ds).WD
            wds=['WD' num2str(wd)];
            evap.(ds).(wds).evap=infonum(:,end);
        end  
        save([basedir 'StateTL_SRdataevap.mat'],'evap');
    else
        load([basedir 'StateTL_SRdataevap.mat']);
    end
    
end

%%%%%%%%%%%%%%%%%%%%%%%%
% stage discharge data
% this needs to be reworked to have for seperate reacheds (ie in wd67)

if readstagedischarge==1
    SDmat=readmatrix([basedir inputfilename],'Sheet','stagedischarge');
    [SDmatnumrow SDmatnumcol]=size(SDmat);
    
    for i=1:SDmatnumrow
        if ~isfield(SR.(ds),'stagedischarge') || ~isfield(SR.(ds).stagedischarge,['SD' num2str(SDmat(i,1))])
            SR.(ds).stagedischarge.(['SD' num2str(SDmat(i,1))])=SDmat(i,2:3);
        else
            SR.(ds).stagedischarge.(['SD' num2str(SDmat(i,1))])=[SR.(ds).stagedischarge.(['SD' num2str(SDmat(i,1))]);SDmat(i,2:3)];
        end
    end
    stagedischarge.(ds).stagedischarge=SR.(ds).stagedischarge;
    
    DMmat=readcell([basedir inputfilename],'Sheet','defaultmethod');
    [DMmatnumrow DMmatnumcol]=size(DMmat);
    for i=1:DMmatnumrow
        SR.(['D' num2str(DMmat{i,1})]).defaultmethod.(['WD' num2str(DMmat{i,2})]).(['R' num2str(DMmat{i,3})])=DMmat{i,4};
    end
    defaultmethod.(['D' num2str(DMmat{i,1})]).defaultmethod=SR.(['D' num2str(DMmat{i,1})]).defaultmethod;
    save([basedir 'StateTL_SRdatastagedis.mat'],'stagedischarge','defaultmethod');
else
    load([basedir 'StateTL_SRdatastagedis.mat']);
    SR.(ds).stagedischarge=stagedischarge.(ds).stagedischarge;
    SR.(ds).defaultmethod=defaultmethod.(ds).defaultmethod;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
% Evaporation
% NEW - using gridded statewide ET dataset
% associating gridpoint with mean of us and dswdid locations for a subreach
% basing evap as 1.05 * ETos
% using HB REST to get utm and lat/lon coordinates
% eventually will replace use of ET dataset file with pull of ET data from HB
% and also add in current years data...

if readevap==1 && evapnew==1

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Use HB REST to pull utm and lat/lon coordinates 
logm=['for evaporation, reading wdid locations from HBRest, starting: '  datestr(now)];
domessage(logm,logfilename,displaymessage,writemessage)

for wd=SR.(ds).WD
    wds=['WD' num2str(wd)];
    for r=SR.(ds).(wds).R 
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            uswdid=SR.(ds).(wds).(rs).wdid{sr};
            dswdid=SR.(ds).(wds).(rs).dswdid{sr};
            try
                uswdiddata=webread(structureurl,'format','json','fields',[{'utmX'},{'utmY'},{'latdecdeg'},{'longdecdeg'}],'wdid',uswdid,'apiKey',apikey);
                usutmx=uswdiddata.ResultList.utmX;
                usutmy=uswdiddata.ResultList.utmY;
                uslat=uswdiddata.ResultList.latdecdeg;
                uslon=uswdiddata.ResultList.longdecdeg;
            catch  %at a minimum will occur if fake wdid
                usutmx=-999;
                usutmy=-999;
                uslat=-999;
                uslon=-999;
            end
            try
                dswdiddata=webread(structureurl,'format','json','fields',[{'utmX'},{'utmY'},{'latdecdeg'},{'longdecdeg'}],'wdid',dswdid,'apiKey',apikey);
                dsutmx=dswdiddata.ResultList.utmX;
                dsutmy=dswdiddata.ResultList.utmY;
                dslat=dswdiddata.ResultList.latdecdeg;
                dslon=dswdiddata.ResultList.longdecdeg;
            catch  %at a minimum will occur if fake wdid
                dsutmx=-999;
                dsutmy=-999;
                dslat=-999;
                dslon=-999;
            end
            if isempty(usutmx)
                usutmx=-999;
                usutmy=-999;
                uslat=-999;
                uslon=-999;
            end
            if isempty(dsutmx)
                dsutmx=-999;
                dsutmy=-999;
                dslat=-999;
                dslon=-999;
            end

            
            
            if usutmx==-999 & dsutmx~=-999
                utmx=dsutmx;
                utmy=dsutmy;
                lat=dslat;
                lon=dslon;
                logm=['WARNING: no or missing location for WDID:' uswdid ' WD:' wds ' rs:' rs ' sr:' num2str(sr)];
                domessage(logm,logfilename,displaymessage,writemessage)
            elseif usutmx~=-999 & dsutmx==-999
                utmx=usutmx;
                utmy=usutmy;
                lat=uslat;
                lon=uslon;
                logm=['WARNING: no or missing location for WDID:' dswdid ' WD:' wds ' rs:' rs ' sr:' num2str(sr)];
                domessage(logm,logfilename,displaymessage,writemessage)
            elseif usutmx==-999 & dsutmx==-999
                utmx=prevutmx;  %hopefully the first two are missing
                utmy=prevutmy;
                lat=prevlat;
                lon=prevlon;
                logm=['WARNING: no or missing location for BOTH WDIDs:' uswdid ' ' dswdid ' WD:' wds ' rs:' rs ' sr:' num2str(sr)];
                domessage(logm,logfilename,displaymessage,writemessage)
            else
                utmx=(usutmx+dsutmx)/2;
                utmy=(usutmy+dsutmy)/2;
                lat=(uslat+dslat)/2;
                lon=(uslon+dslon)/2;                
            end

            evap.(ds).(wds).(rs).utmx(sr)=utmx;
            evap.(ds).(wds).(rs).utmy(sr)=utmy;
            evap.(ds).(wds).(rs).lat(sr)=lat;
            evap.(ds).(wds).(rs).lon(sr)=lon;
            prevutmx=utmx;
            prevutmy=utmy;
            prevlat=lat;
            prevlon=lon;
            
            % may want to remove these at some point as only needed for internal visualization
            evap.(ds).(wds).(rs).usutmx(sr)=usutmx;
            evap.(ds).(wds).(rs).usutmy(sr)=usutmy;
            evap.(ds).(wds).(rs).uslat(sr)=uslat;
            evap.(ds).(wds).(rs).uslon(sr)=uslon;
            evap.(ds).(wds).(rs).dsutmx(sr)=dsutmx;
            evap.(ds).(wds).(rs).dsutmy(sr)=dsutmy;
            evap.(ds).(wds).(rs).dslat(sr)=dslat;
            evap.(ds).(wds).(rs).dslon(sr)=dslon;

            if logwdidlocations %may want to do this to check if good locations, but potentially turn it off when know its good
                logm=['evap locations (utmx,utmy,lat,lon) from HBRest for subreach: ,' wds ',' rs ',' num2str(sr) ',' num2str(utmx) ',' num2str(utmy) ',' num2str(lat) ',' num2str(lon)];
                domessage(logm,logfilename,displaymessage,writemessage)
            end
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Use gridded statewide ET dataset to build et for a full time period
%
%
% %currently using just CAL_Div2 but need following commands to pull in gmratio and a few more variables that in CAL_CO
% clear
% load('CAL_CO.mat')
% CALx.years=CAL.years;
% CALx.yearid=CAL.yearid;
% CALx.monthidsall=CAL.monthidsall;
% load('CAL_Div2.mat')
% CAL.years=CALx.years;
% CAL.yearid=CALx.yearid;
% CAL.monthidsall=CALx.monthidsall;
% clear ans CALx
% save('C:\Projects\Ark\ColorsofWater\matlab\StateTL_evapDiv2.mat')

logm=['for evaporation, rebuilding full evaporation datasets starting from year: ' num2str(evapstartyear)];
domessage(logm,logfilename,displaymessage,writemessage)


logm=['loading statewide ET dataset binary file: ' ETfilename ];
domessage(logm,logfilename,displaymessage,writemessage)
load([basedir ETfilename]);
%load(['C:\Projects\Ark\ArkDSS\PET\dataprocessed\' ETfilename])

csid=find(CAL.dates==datenum(evapstartyear,1,1));  %do this here or from calling?
evap.evapstartyear=evapstartyear;
evap.yearend=CAL.yearend;
evap.dates=CAL.dates(csid:end,1);
evap.julien=CAL.julien(csid:end,1);

yearid=find(CAL.yearid==csid);
evap.years=CAL.years(yearid:end)';
evap.yearid=CAL.yearid(yearid:end)-(csid-1);
evap.yearid(1:end-1,2)=evap.yearid(2:end,1)-1;
evap.yearid(end,2)=length(evap.dates);


for i=1:365
   julienids{i}=find(evap.julien==i); 
end
julienids{366}=julienids{365};
evap.julienids=julienids;

for wd=SR.(ds).WD
    wds=['WD' num2str(wd)];
    for r=SR.(ds).(wds).R 
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            utmx=evap.(ds).(wds).(rs).utmx(sr);
            utmy=evap.(ds).(wds).(rs).utmy(sr);
            lat=evap.(ds).(wds).(rs).lat(sr);
            lon=evap.(ds).(wds).(rs).lon(sr);
            [ETrs,ETos]=COASCEETr(utmx,utmy,lat,lon,CAL,gmratio);
            evap.(ds).(wds).(rs).ETos(:,sr)=ETos(csid:end,:);
        end
        for i=1:366
            evap.(ds).(wds).(rs).ETosavg(i,:)=mean(evap.(ds).(wds).(rs).ETos(julienids{i},:));
            evap.(ds).(wds).(rs).ETosmin(i,:)=min(evap.(ds).(wds).(rs).ETos(julienids{i},:));
            evap.(ds).(wds).(rs).ETosmax(i,:)=max(evap.(ds).(wds).(rs).ETos(julienids{i},:));
        end
    end
end

save([basedir 'StateTL_SRdataevap.mat'],'evap');

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Evaporation - Attaching or rettaching to SR structure
% using whole year in anticipation of possible calendar year orientation

if readevap==1 || readinputfile==1
    if readevap~=1
        load([basedir 'StateTL_SRdataevap.mat']);
    end
    if evapnew~=1
        for wd=SR.(ds).WD
            wds=['WD' num2str(wd)];
            for r=SR.(ds).(wds).R
                rs=['R' num2str(r)];
                for sr=SR.(ds).(wds).(rs).SR
                    SR.(ds).(wds).(rs).evap(:,sr)=evap.(ds).(wds).evap;
                end
            end
        end
    else
        yearids=[];
        if yearstart<=evap.yearend
            yearid=find(evap.years==yearstart);
            yearids=evap.yearid(yearid,:);
        end
        
        for wd=SR.(ds).WD
            wds=['WD' num2str(wd)];
            for r=SR.(ds).(wds).R
                rs=['R' num2str(r)];
                if isempty(yearids)
                    %SR.(ds).(wds).(rs).evap=evap.(ds).(wds).(rs).ETosavg.*SR.(ds).(wds).(rs).evapfactor*etostoevap*convertevap;
                    SR.(ds).(wds).(rs).evap=evap.(ds).(wds).(rs).ETosavg*etostoevap*convertevap;
                    %SR.(ds).(wds).(rs).evapmin=evap.(ds).(wds).(rs).ETosmin*etostoevap*convertevap;
                    %SR.(ds).(wds).(rs).evapmax=evap.(ds).(wds).(rs).ETosmax*etostoevap*convertevap;
                else
                    SR.(ds).(wds).(rs).evap=evap.(ds).(wds).(rs).ETos(yearids(1):yearids(2),:).*SR.(ds).(wds).(rs).evapfactor*etostoevap*convertevap;
                end
                % may want to remove these at some point as only needed for internal visualization
                SR.(ds).(wds).(rs).utmx=evap.(ds).(wds).(rs).utmx;
                SR.(ds).(wds).(rs).utmy=evap.(ds).(wds).(rs).utmy;
                SR.(ds).(wds).(rs).lat=evap.(ds).(wds).(rs).lat;
                SR.(ds).(wds).(rs).lon=evap.(ds).(wds).(rs).lon;
                SR.(ds).(wds).(rs).usutmx=evap.(ds).(wds).(rs).usutmx;
                SR.(ds).(wds).(rs).usutmy=evap.(ds).(wds).(rs).usutmy;
                SR.(ds).(wds).(rs).uslat=evap.(ds).(wds).(rs).uslat;
                SR.(ds).(wds).(rs).uslon=evap.(ds).(wds).(rs).uslon;
                SR.(ds).(wds).(rs).dsutmx=evap.(ds).(wds).(rs).dsutmx;
                SR.(ds).(wds).(rs).dsutmy=evap.(ds).(wds).(rs).dsutmy;
                SR.(ds).(wds).(rs).dslat=evap.(ds).(wds).(rs).dslat;
                SR.(ds).(wds).(rs).dslon=evap.(ds).(wds).(rs).dslon;
            end
        end
        
    end
    save([basedir 'StateTL_SRdata.mat'],'SR'); 
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% READ GAGE AND TELEMETRY BASED FLOW DATA
% much of this needs to be improved for larger application; particularly handling of dates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
reststarttime=[];
if pullstationdata==1
    if pulllongtermstationdata==0
        load(['StateTL_bin_Qnode.mat']); %better way to do this?
        for wd=WDlist
            wds=['WD' num2str(wd)];
            for r=SR.(ds).(wds).R
                rs=['R' num2str(r)];
                Station.(ds).(wds).(rs)=rmfield(Station.(ds).(wds).(rs),{'Qnodemeas','modifieddatenum','Qnodefill'});
            end
        end
    else 
        clear Station
    end
    Station.date.datestart=datestart;
    Station.date.dateend=dateend;
    Station.date.rdates=rdates;
    Station.date.avgdates=avgdates;
    for wd=WDlist
        wds=['WD' num2str(wd)];
        Station.date.(ds).(wds).modified=0;
    end
else
    load(['StateTL_bin_Qnode.mat']);
end

if pullstationdata>=1
blankvalues=-999*ones(length(rdates(datestid:end)),1);
reststarttime=now;

logm=['Start pulling data from HBREST at: '  datestr(now)];
domessage(logm,logfilename,displaymessage,writemessage)


for wd=WDlist
    wds=['WD' num2str(wd)];
    modified=Station.date.(ds).(wds).modified;
    maxmodified=modified;
    if modified==0
        modifiedstr=['01/01/1950 00:00'];
    else
        %using weird/direct construction of modified date because using datenum really slows this down
       %modifiedstr=datestr(modified+1/24/60,'mm/dd/yyyy HH:MM')
        modifiedstr=num2str(modified+1);
        modifiedstr=[modifiedstr(5:6) '/' modifiedstr(7:8) '/' modifiedstr(1:4) ' ' modifiedstr(9:10) ':' modifiedstr(11:12)];
    end
    
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        if flowcriteria>=4
            for sr=SR.(ds).(wds).(rs).SR
                if strcmp(SR.(ds).(wds).(rs).station{1,sr},'NaN') | strcmp(SR.(ds).(wds).(rs).station{1,sr},'none')  %if non-telemetry station
%                    SR.(ds).(wds).(rs).Qnode(:,sr,1)=SR.(ds).(wds).(rs).(flow)(1,sr)*ones(rsteps,1);
                    Station.(ds).(wds).(rs).Qnodemeas(:,sr)=blankvalues;
                    Station.(ds).(wds).(rs).modifieddatenum(:,sr)=blankvalues;
                else
                    station=SR.(ds).(wds).(rs).station{1,sr};
                    parameter=SR.(ds).(wds).(rs).parameter{1,sr};
                    if pullstationdata==1
                        Station.(ds).(wds).(rs).Qnodemeas(:,sr)=blankvalues;
                        Station.(ds).(wds).(rs).modifieddatenum(:,sr)=blankvalues;
                    end
                     
                    RESTworked=0;
                    try
                        logm=['HBREST: reading hourly records from ' station ' from:' datestr(rdates(1),21) ' to:' datestr(rdates(end),21)];
                        domessage(logm,logfilename,displaymessage,writemessage)
                        gagedata=webread(telemetryhoururl,'format','json','abbrev',station,'parameter',parameter,'startDate',datestr(rdates(1),21),'endDate',datestr(rdates(end),21),'includeThirdParty','true','modified',modifiedstr,weboptions('Timeout',60),'apiKey',apikey);
                        RESTworked=1;
%                    catch ME
                    catch
                        if pullstationdata==1
                            logm=['WARNING: didnt return telemetry data for station:' station ' parameter:' parameter ' (issue with command, station, API, REST services, data, etc)'];
                        else
                            logm=['WARNING: - probably no new data since last REST pull - didnt return any telemetry data for station:' station ' parameter:' parameter ' for modified date: ' modifiedstr ' (probably new data beyond modified date - or could be other issue)'];
                        end
                        domessage(logm,logfilename,displaymessage,writemessage)
                        % SR.(ds).(wds).(rs).Qnode(:,sr,1)=SR.(ds).(wds).(rs).(flow)(1,sr)*ones(rsteps,1);
                    end
                    if RESTworked==1
                        for i=1:gagedata.ResultCount
                            measdatestr=gagedata.ResultList(i).measDate;
                            measdatestr(11)=' ';
                            measdateid=find(strcmp(rdatesstr(datestid:end,:),measdatestr));
                            % measunit{i}=gagedata.ResultList(i).measUnit; %check?
                            if ~isempty(measdateid)
                                Station.(ds).(wds).(rs).Qnodemeas(measdateid,sr)=gagedata.ResultList(i).measValue;
                                modifieddatestr=gagedata.ResultList(i).modified;
%                                 modifieddatestr(11)=' ';
%                                 modifieddatenum=datenum(modifieddatestr,31);
                                modifieddatenum=str2double([modifieddatestr(1:4) modifieddatestr(6:7) modifieddatestr(9:10) modifieddatestr(12:13) modifieddatestr(15:16)]);
                                Station.(ds).(wds).(rs).modifieddatenum(measdateid,sr)=modifieddatenum;
                                maxmodified=max(maxmodified,modifieddatenum);  %do as array below?
                            else
                                logm=['WARNING: telemetry datevalue outside of model daterange for station: ' station ' telemetry datestr:' measdatestr ' ignoring datapoint'];
                                domessage(logm,logfilename,displaymessage,writemessage)      
                            end
                            
                        end
                    end
                end
            end
        else
            % SR.(ds).(wds).(rs).Qnode(:,:,1)=SR.(ds).(wds).(rs).(flow)(1,:).*ones(rsteps,length(SR.(ds).(wds).(rs).SR));
            Station.(ds).(wds).(rs).Qnodemeas(:,sr)=blankvalues;
            Station.(ds).(wds).(rs).modifieddatenum(:,sr)=blankvalues;
        end
    end
    Station.date.(ds).(wds).modified=maxmodified;
end


% read of longer term daily values to establish averages using telemetrydayurl
if pulllongtermstationdata==1
    if pullstationdata==1
    for wd=WDlist
        wds=['WD' num2str(wd)];
        Station.date.(ds).(wds).avgmodified=0;
    end
    end
    
    avgdatesstr=cellstr(datestr(avgdates,31));
    blankvalues=-999*ones(length(avgdates),1);
    avgdatesvec=datevec(avgdates);
    yearleapvec=datevec([datenum(2000,1,1):datenum(2000,12,31)]);
    yearleapvec=yearleapvec(:,2:3);
    k=0;
    for i=[avgstartyear:nowvec(1)-1];
        k=k+1;
        avgyearsid{k}=find(avgdatesvec(:,1)==i);
    end
    for i=1:366
        avgdatesid{i}=find(avgdatesvec(:,2)==yearleapvec(i,1) & avgdatesvec(:,3)==yearleapvec(i,2));
    end
    avgdatesid{60}=avgdatesid{59};  %feb29=feb28    

for wd=WDlist
    wds=['WD' num2str(wd)];
    modified=Station.date.(ds).(wds).avgmodified;
    maxmodified=modified;
    if modified==0
        modifiedstr=['01/01/1950 00:00'];
    else
        %using weird/direct construction of modified date because using datenum really slows this down
       %modifiedstr=datestr(modified+1/24/60,'mm/dd/yyyy HH:MM')
        modifiedstr=num2str(modified+1);
        modifiedstr=[modifiedstr(5:6) '/' modifiedstr(7:8) '/' modifiedstr(1:4) ' ' modifiedstr(9:10) ':' modifiedstr(11:12)];
    end
    
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        if flowcriteria>=4
            for sr=SR.(ds).(wds).(rs).SR
                if strcmp(SR.(ds).(wds).(rs).station{1,sr},'NaN') | strcmp(SR.(ds).(wds).(rs).station{1,sr},'none')  %if no telemetry station then uses low/avg/high number
%                    SR.(ds).(wds).(rs).Qnode(:,sr,1)=SR.(ds).(wds).(rs).(flow)(1,sr)*ones(rsteps,1);
                    Station.(ds).(wds).(rs).Qnodemeasdaylong(:,sr)=blankvalues;
                    Station.(ds).(wds).(rs).modifieddatenumlong(:,sr)=blankvalues;
                else
                    station=SR.(ds).(wds).(rs).station{1,sr};
                    parameter=SR.(ds).(wds).(rs).parameter{1,sr};
                    if pullstationdata==1
                        Station.(ds).(wds).(rs).Qnodemeasdaylong(:,sr)=blankvalues;
                        Station.(ds).(wds).(rs).modifieddatenumlong(:,sr)=blankvalues;
                    end
                     
                    RESTworked=0;
                    try
                        logm=['HBREST: reading daily records from ' station ' from:' datestr(avgdates(1),21) ' to:' datestr(avgdates(end),21) ' to establish long term averages for filling'];
                        domessage(logm,logfilename,displaymessage,writemessage)
                        try
                            gagedata=webread(surfacewaterdayurl,'format','json','abbrev',station,'min-measDate',datestr(avgdates(1),23),'max-measDate',datestr(avgdates(end),23),'min-modified',modifiedstr(1:10),weboptions('Timeout',60),'apiKey',apikey);
                        catch
                            logm=['HBREST: couldt read long term surfacewater based records, trying telemetry based records for ' station ' '];
                            domessage(logm,logfilename,displaymessage,writemessage)
                            gagedata=webread(telemetrydayurl,'format','json','abbrev',station,'parameter',parameter,'startDate',datestr(avgdates(1),21),'endDate',datestr(avgdates(end),21),'includeThirdParty','true','modified',modifiedstr,weboptions('Timeout',60),'apiKey',apikey);
                        end
                        RESTworked=1;
%                    catch ME
                    catch
                        if pullstationdata==1
                            logm=['WARNING: didnt return daily surfacewater/telemetry data for station:' station ' parameter:' parameter ' (issue with command, station, API, REST services, data, etc)'];
                        else
                            logm=['WARNING: - probably no new data since last REST pull - didnt return any daily telemetry data for station:' station ' parameter:' parameter ' for modified date: ' modifiedstr ' (probably new data beyond modified date - or could be other issue)'];
                        end
                        domessage(logm,logfilename,displaymessage,writemessage)
                        % SR.(ds).(wds).(rs).Qnode(:,sr,1)=SR.(ds).(wds).(rs).(flow)(1,sr)*ones(rsteps,1);
                    end
                    if RESTworked==1
                        for i=1:gagedata.ResultCount
                            measdatestr=gagedata.ResultList(i).measDate;
                            measdatestr=measdatestr(1:19);  %surfacewater has more characters than telemetry (!)
                            measdatestr(11)=' ';
                            measdateid=find(strcmp(avgdatesstr,measdatestr));
                            % measunit{i}=gagedata.ResultList(i).measUnit; %check?
                            if ~isempty(measdateid)
                                if isfield(gagedata.ResultList,'value')
                                    Station.(ds).(wds).(rs).Qnodemeasdaylong(measdateid,sr)=gagedata.ResultList(i).value;  %surfacewater
                                else
                                    Station.(ds).(wds).(rs).Qnodemeasdaylong(measdateid,sr)=gagedata.ResultList(i).measValue;  %telemetry
                                end
                                modifieddatestr=gagedata.ResultList(i).modified;
%                                 modifieddatestr(11)=' ';
%                                 modifieddatenum=datenum(modifieddatestr,31);
                                modifieddatenum=str2double([modifieddatestr(1:4) modifieddatestr(6:7) modifieddatestr(9:10) modifieddatestr(12:13) modifieddatestr(15:16)]);
                                Station.(ds).(wds).(rs).modifieddatenumlong(measdateid,sr)=modifieddatenum;
                                maxmodified=max(maxmodified,modifieddatenum);  %do as array below?
                            else
                                logm=['WARNING: telemetry datevalue outside of model daterange for station: ' station ' telemetry datestr:' measdatestr ' ignoring datapoint'];
                                domessage(logm,logfilename,displaymessage,writemessage)      
                            end
                            
                        end
                    end
                end
            end
        else
            % SR.(ds).(wds).(rs).Qnode(:,:,1)=SR.(ds).(wds).(rs).(flow)(1,:).*ones(rsteps,length(SR.(ds).(wds).(rs).SR));
            Station.(ds).(wds).(rs).Qnodemeasdaylong(:,sr)=blankvalues;
            Station.(ds).(wds).(rs).modifieddatenumlong(:,sr)=blankvalues;
        end
    end
    Station.date.(ds).(wds).avgmodified=maxmodified;
end

% establishment of daily dry/avg/wet annual values for stations with telemetry 
for wd=WDlist
    wds=['WD' num2str(wd)];
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            if strcmp(SR.(ds).(wds).(rs).station{1,sr},'NaN') | strcmp(SR.(ds).(wds).(rs).station{1,sr},'none')  %if no telemetry station then uses low/avg/high number
                Station.(ds).(wds).(rs).avgQnodedaydry(:,sr)=SR.(ds).(wds).(rs).avgflow(1,sr)*ones(366,1);  %carry over from livingston - but need to base on diversion records if avail
                Station.(ds).(wds).(rs).avgQnodedayavg(:,sr)=SR.(ds).(wds).(rs).avgflow(2,sr)*ones(366,1);
                Station.(ds).(wds).(rs).avgQnodedaywet(:,sr)=SR.(ds).(wds).(rs).avgflow(3,sr)*ones(366,1);
                Station.(ds).(wds).(rs).lastdailydate=Station.date.avgdates(1);
            else
                for i=1:366
                    avgdatesids=avgdatesid{i};
                    avgdaymeas=Station.(ds).(wds).(rs).Qnodemeasdaylong(avgdatesids,sr);
                    posids=find(avgdaymeas~=-999);
                    if isempty(posids)
                        Station.(ds).(wds).(rs).avgQnodedaydry(i,sr)=-999;
                        Station.(ds).(wds).(rs).avgQnodedayavg(i,sr)=-999;
                        Station.(ds).(wds).(rs).avgQnodedaywet(i,sr)=-999;
                    else
                        [sortavgday,sortavgdayid]=sort(avgdaymeas(posids));
                        percamt=floor(length(sortavgdayid)/3); %33 percentile but with floor/ceil puts dry / wet at approx 30% / 70%
                        drydayids=posids(sort(sortavgdayid(1:max(1,percamt))));
                        avgdayids=posids(sort(sortavgdayid(min(length(sortavgdayid),max(1,percamt+1)):max(1,length(sortavgdayid)-percamt))));
                        wetdayids=posids(sort(sortavgdayid(min(length(sortavgdayid),length(sortavgdayid)-percamt+1):end)));
                        Station.(ds).(wds).(rs).avgQnodedaydry(i,sr)=mean(avgdaymeas(drydayids));
                        Station.(ds).(wds).(rs).avgQnodedayavg(i,sr)=mean(avgdaymeas(avgdayids));
                        Station.(ds).(wds).(rs).avgQnodedaywet(i,sr)=mean(avgdaymeas(wetdayids));
                    end
                end
                %need filling here in case any -999
                
                %convert quickly to hourly - here still based on 366 not 365
                Station.(ds).(wds).(rs).avgQnodedry(:,sr)=reshape(repmat(Station.(ds).(wds).(rs).avgQnodedaydry(:,sr),1,24)',[366*24,1]);
                Station.(ds).(wds).(rs).avgQnodeavg(:,sr)=reshape(repmat(Station.(ds).(wds).(rs).avgQnodedayavg(:,sr),1,24)',[366*24,1]);
                Station.(ds).(wds).(rs).avgQnodewet(:,sr)=reshape(repmat(Station.(ds).(wds).(rs).avgQnodedaywet(:,sr),1,24)',[366*24,1]);

                %additional thing for use in daily QC loop - last day with data
                hasdailyid=find(Station.(ds).(wds).(rs).Qnodemeasdaylong(:,sr)~=-999);  %could put these in avg processing loop
                if ~isempty(hasdailyid)
                    Station.(ds).(wds).(rs).lastdailydate=Station.date.avgdates(hasdailyid(end));
                else
                    Station.(ds).(wds).(rs).lastdailydate=Station.date.avgdates(1);
                end
            end
        end
    end
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% QC of hourly (telemetry) data with daily (surfacewater) sometimes 'published' data
% can also be used for some filling of missing hourly data
 

dayvshrthreshold=[0.05 0.15];
dailyid1=find(Station.date.avgdates==datestart);

if ~isempty(dailyid1)
    logm=['Attempting to QC (telemetry) data using daily (surfacewater) (sometimes worked) data'];
    domessage(logm,logfilename,displaymessage,writemessage)

    dailyid2=find(Station.date.avgdates==dateend);
    if ~isempty(dailyid2)
        dailyids=[dailyid1:dailyid2];
    else
        dailyids=[dailyid1:length(Station.date.avgdates)];
    end
    dailydates=Station.date.avgdates(dailyids);  %could potentially be different than datedays
    for i=1:length(dailydates)
        dailydateids{i}=find(rdatesday(datestid:end)==dailydates(i));
    end

for wd=WDlist
    wds=['WD' num2str(wd)];    
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            tsmeas=Station.(ds).(wds).(rs).Qnodemeas(:,sr);
            tsmeasQC=tsmeas;
            tsdaily=Station.(ds).(wds).(rs).Qnodemeasdaylong(dailyids,sr);
            for i=1:length(dailydates)
                Station.(ds).(wds).(rs).Qnodedaily(dailydateids{i},sr)=tsdaily(i);
                if tsdaily(i)~=-999  %if no daily data then skip
                    tshrdayids=dailydateids{i};
                    tshrforday=tsmeas(tshrdayids,1);
                    missingids=find(tshrforday==-999);
                    if isempty(missingids)
                        notmissingids=tshrdayids;
                    else
                        missingids=tshrdayids(missingids); %re-reference to full hourly set
                        notmissingids=setdiff(tshrdayids,missingids);
                    end
                    
                    if isempty(notmissingids) %if no hourly data, fill with daily
                        tsmeasQC(tshrdayids,1)=tsdaily(i);
                    elseif isempty(missingids) %if no missing hourly data, adjust if diff exceeds thres1 or replace if exceeds thres2
                        tshrdayperdiff=(mean(tshrforday)-tsdaily(i))/tsdaily(i);                        
                        if abs(tshrdayperdiff) >= dayvshrthreshold(2)  %replace it
                            tsmeasQC(tshrdayids,1)=tsdaily(i);
                        elseif abs(tshrdayperdiff) >= dayvshrthreshold(1)  %adjust it
                            tsmeasQC(tshrdayids,1)=tsmeas(tshrdayids,1)-((mean(tshrforday)-tsdaily(i))/mean(tshrforday))*tsmeas(tshrdayids,1); %slight variation from tshrdayperdiff so that calculates exactly
                        end
                    else %if has some missingids, 
                        tshrdayperdiff=(mean(tsmeas(notmissingids,1))-tsdaily(i))/tsdaily(i);
                        if abs(tshrdayperdiff) >= dayvshrthreshold(2)  %replace it
                            tsmeasQC(tshrdayids,1)=tsdaily(i);
                        elseif abs(tshrdayperdiff) >= dayvshrthreshold(1)  %adjust it
                            tsmeasQC(notmissingids,1)=tsmeas(notmissingids,1)-(mean(tsmeas(notmissingids,1))-tsdaily(i))/mean(tsmeas(notmissingids,1))*tsmeas(notmissingids,1);
                            tsmeasQC(missingids,1)=tsdaily(i);
                        else
                            tsmeasQC(missingids,1)=mean(tsmeas(notmissingids,1));
                        end
                        
%                         %the following would consider cases that missing should be zeros or should be mean values - but so far didnt like when put in a zero
%                         tshrdayperdiff=(mean(tsmeas(notmissingids,1))-tsdaily(i))/tsdaily(i);
%                         tshrdayperdiffwithzeros=(mean([tsmeas(notmissingids,1);zeros(length(missingids),1)])-tsdaily(i))/tsdaily(i);
%                         if abs(tshrdayperdiffwithzeros) < dayvshrthreshold(1)  %likes with zeros
%                             tsmeasQC(missingids,1)=0;
%                         elseif abs(tshrdayperdiff) < dayvshrthreshold(1)    %likes with mean
%                             tsmeasQC(missingids,1)=mean(tsmeas(notmissingids,1));
%                         elseif abs(tshrdayperdiffwithzeros) < dayvshrthreshold(2)
%                             tsmeasQC(notmissingids,1)=tsmeas(notmissingids,1)-(mean([tsmeas(notmissingids,1);zeros(length(missingids),1)])-tsdaily(i))/mean([tsmeas(notmissingids,1);zeros(length(missingids),1)])*tsmeas(notmissingids,1);
%                             tsmeasQC(missingids,1)=0;
%                         elseif abs(tshrdayperdiff) < dayvshrthreshold(2)
%                             tsmeasQC(notmissingids,1)=tsmeas(notmissingids,1)-(mean(tsmeas(notmissingids,1))-tsdaily(i))/mean(tsmeas(notmissingids,1))*tsmeas(notmissingids,1);
%                             tsmeasQC(missingids,1)=mean(tsmeas(notmissingids,1));
%                         else %just replace it
%                             tsmeasQC(tshrdayids,1)=tsdaily(i);
%                         end

                    end
                else
                    % if daily blank, then blank out hourly - if can say that not at the end of the time series
                    if dailydates(i) < Station.(ds).(wds).(rs).lastdailydate
                        tsmeasQC(dailydateids{i},1)=-999;
                    end
                end
            end
            Station.(ds).(wds).(rs).QnodeQC(:,sr)=tsmeasQC;
        end
    end
end


else  %if isempty(dailyid1)
    logm=['Warning: cannot QC hourly data with daily data - longterm daily data that has been downloaded does not include time period'];
    domessage(logm,logfilename,displaymessage,writemessage)
end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Filling of missing station data

ids=[1:rsteps-datestid+1];
SRgageids=find([SR.(ds).SR{:,10}]==0);
for wd=WDlist
    wds=['WD' num2str(wd)];    
    for r=SR.(ds).(wds).R 
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            tsmeas=Station.(ds).(wds).(rs).QnodeQC(:,sr);  %Qnodemeas/QnodeQC does not include spinup period
            tsfill=tsmeas;
%             if strcmp(wds,'WD17') && strcmp(rs,'R3') && sr==1
%                 tsfill(6500:end,sr)=-999;
%             end
            missinglist=find(tsfill==-999);
            if ~isempty(missinglist)
                
                %First - if wanting to use linear regression fill of gages from neighboring gages
                % first see if other gages on same wd, in which case sort by number of subreaches (ie in/outs) seperating
                % if not use closest gage spatially
                % one problem with this is with hourly data the timing is off..
                if SR.(ds).(wds).(rs).type(sr)==0 & useregrfillforgages==1 %0=gage
                    %find closest gage/gages
                    SRid=find(strcmp(SR.(ds).SR(:,1),SR.(ds).(wds).(rs).wdid{sr}));
                    gageids=intersect(find([SR.(ds).SR{:,4}]==wd),SRgageids);
                    if length(gageids)>1 %has other gages in wd - order gages to regress with 
                        gageids=setdiff(gageids,SRid);
                        [srdiffs,gagesortid]=sort(abs(gageids-SRid));  %sorted by number of subreaches to gage that filling
                        gageids=gageids(gagesortid);  
                    else  %if no other gages on trib uses closest spatially, eventually may want to define filling stations
                        gageids=setdiff(SRgageids,SRid);
                        for i=1:length(gageids)
                            gid=gageids(i);
                            gagedist(i)=sqrt((SR.(ds).(wds).(rs).utmx(sr)-SR.(SR.(ds).SR{gid,7}).(SR.(ds).SR{gid,8}).(SR.(ds).SR{gid,9}).utmx(SR.(ds).SR{gid,6}))^2 ...
                                - (SR.(ds).(wds).(rs).utmy(sr)-SR.(SR.(ds).SR{gid,7}).(SR.(ds).SR{gid,8}).(SR.(ds).SR{gid,9}).utmy(SR.(ds).SR{gid,6}))^2 );
                        end
                        [srdiffs,gagesortid]=sort(gagedist);
                        gageids=gageids(gagesortid(1)); %number here determines number
                    end
                    
                    for j=1:length(gageids) %may want to limit to a max number of filling stations
                        gid=gageids(j);
                        dsr=SR.(ds).SR{gid,7};
                        wdsr=SR.(ds).SR{gid,8};
                        rsr=SR.(ds).SR{gid,9};
                        srr=SR.(ds).SR{gid,6};
                        
                        tsmeasrepl=Station.(dsr).(wdsr).(rsr).QnodeQC(:,srr);                       
                        missinglistrepl=find(tsmeasrepl==-999);
                        missinglist2=intersect(missinglist,missinglistrepl);    %bad/missing in common in both sets
                        missinglist1=setdiff(missinglist,missinglist2);         %fill locations -  bad/missing in station but with good data in filling station
                        badlist=union(missinglist,missinglistrepl);             %all missing from both
                        commonlist=ids;                                         %this is considering all year; may want to isolate down to smaller periods
                        commonlist(badlist)=[];                                 %interpolation locations - good data common to both sets
                        
                        if ~isempty(commonlist) && length(commonlist)<=regfillwindow %regression fill using full list of (good) common data
                            y=tsmeas(commonlist,sr);
                            x=tsmeasrepl(commonlist,srr);
                            [yfit,m,b,R2,SEE]=regr(x,y,'linreg');
                            tsfill(missinglist1,1)=m*tsmeasrepl(missinglist1,srr)+b;
                            missinglist=missinglist2;
                        elseif ~isempty(commonlist) %regression fill using subset (window) of common data
                            for i=1:length(missinglist1)
                                missingid=missinglist1(i);
                                [mindiffs,commonsortids]=sort(abs(missingid-commonlist));
                                commonlistwindow=commonlist(commonsortids(1:regfillwindow));
                                commonlistwindow=sort(commonlistwindow);
                                y=tsmeas(commonlistwindow,sr);
                                x=tsmeasrepl(commonlistwindow,srr);
                                [yfit,m,b,R2,SEE]=regr(x,y,'linreg');
                                tsfill(missingid,1)=m*tsmeasrepl(missingid,srr)+b;
                            end
                            missinglist=missinglist2;
                         end

                    end
                        
                    % use utmx/y for tribs with single gage?
                     
                end
                
                % if not filled by regression above, now use:
                % a) gaps - 7 day interpolation, b) missing ends - 7 day trends, c) dry/avg/wet average weighted between 7-30 days, straight average after
                
                if ~isempty(missinglist)
                notblankids=setdiff(ids,missinglist);
                if ~isempty(notblankids)  %non-telemetry stations will be empty
                
                leftnumlast=0;rightnumlast=0;leftnumlastavg=0;rightnumlastavg=0;
                for j=1:length(missinglist)
                    leftnums=intersect(notblankids,[1:missinglist(j)-1]);
                    rightnums=intersect(notblankids,[min(missinglist(j)+1,ids(end)):ids(end)]);
                    samegap=1;
                    
                    %if a gap, val is just based on straight interpolation between two surrounding endpoints
                    if ~isempty(leftnums) && ~isempty(rightnums)
                        gapsize=rightnums(1)-leftnums(end);
                        gapdist=min(missinglist(j)-leftnums(end),rightnums(1)-missinglist(j));
                        val=(tsfill(rightnums(1))-tsfill(leftnums(end)))/gapsize*(missinglist(j)-(leftnums(end)))+tsfill(leftnums(end));
                        if gapdist > avgwindow(1)
                            leftx=leftnums(max(1,length(leftnums)-trendregwindow):length(leftnums));
                            rightx=rightnums(1:min(trendregwindow,length(rightnums)));
                        end
                    
                    %if missing at end of annual time series, val is based on the trend     
                    elseif ~isempty(leftnums)
                        if leftnumlast~=leftnums(end)  %will only redo if haven't already done for this chunk
                            leftx=leftnums(max(1,length(leftnums)-trendregwindow):length(leftnums));
                            leftnumlast=leftnums(end);
                            gapsize=ids(end)-leftnums(end);
                            rightx=[];
                            %first look if have a daily avg data - within next month
                            if dateend<Station.date.avgdates(end)
                                for i=1:30
                                    avgdayid=find(Station.date.avgdates==dateend+i);
                                    if ~isempty(avgdayid)
                                        avgdayval=Station.(ds).(wds).(rs).Qnodemeasdaylong(avgdayid,sr);
                                        if avgdayval~=-999
                                            break;
                                        end
                                    end
                                end
                            else
                                avgdayid=[];
                            end
                            %if have a daily leftnum in avg data interpolate (putting dec value on jan1), otherwise find trend in rightdata
                            if ~isempty(avgdayid) && avgdayval~=-999                                
                                leftm=(avgdayval-tsfill(leftnums(end)))/gapsize;
                            else                            
                                [yfit,leftm,leftb,leftR2,SEE]=regr(leftx',tsfill(leftx),'linreg');
                            end
                        end                        
                        gapdist=missinglist(j)-leftnums(end);
                        val=max(0,leftm*(gapdist)+tsfill(leftx(end)));
                    %if missing at beginning of annual time series, similarly val is based on the trend    
                    elseif ~isempty(rightnums)
                        if rightnumlast~=rightnums(1)
                            rightnumlast=rightnums(1);
                            gapsize=rightnums(1)-1;
                            rightx=rightnums(1:min(trendregwindow,length(rightnums)));
                            leftx=[];
                            %first look if have a daily avg data - within previous month
                            if datestart>Station.date.avgdates(1)
                                for i=1:30
                                    avgdayid=find(Station.date.avgdates==datestart-i);
                                    if ~isempty(avgdayid)
                                        avgdayval=Station.(ds).(wds).(rs).Qnodemeasdaylong(avgdayid,sr);
                                        if avgdayval~=-999
                                            break;
                                        end
                                    end
                                end
                            else
                                avgdayid=[];
                            end
                            %if have a daily leftnum in avg data interpolate (putting dec value on jan1), otherwise find trend in rightdata
                            if ~isempty(avgdayid) && avgdayval~=-999                                
                                rightm=(tsfill(rightnums(1))-avgdayval)/gapsize;
                            else
                                [yfit,rightm,rightb,rightR2,SEE]=regr(rightx',tsfill(rightx),'linreg');
                            end
                        end
                        gapdist=rightnums(1)-missinglist(j);
                        val=max(0,tsfill(rightx(1))-rightm*(gapdist));
                    end
                    %but if gap gets big enough (ie > 7 days), incorporate average values either weighted with interp or trend values or straight (if > 30days)
                    if gapdist > avgwindow(1)                     
                        if ~isempty(leftnums) && leftnumlastavg~=leftnums(end)
                            samegap=0;
                            leftnumlastavg=leftnums(end);
                        end
                        if ~isempty(rightnums) && rightnumlastavg~=rightnums(1)
                            samegap=0;
                            rightnumlastavg=rightnums(1);
                        end
                        avgx=[leftx rightx];
                        avgy=tsfill(avgx);
                        if samegap==0
                            clear avgtype
                            avgtype(:,1)=[Station.(ds).(wds).(rs).avgQnodedry(avgx+rjulien(1)-1,sr) ; Station.(ds).(wds).(rs).avgQnodedry(missinglist(j)+rjulien(1)-1,sr)];
                            avgtype(:,2)=[Station.(ds).(wds).(rs).avgQnodeavg(avgx+rjulien(1)-1,sr) ; Station.(ds).(wds).(rs).avgQnodeavg(missinglist(j)+rjulien(1)-1,sr)];
                            avgtype(:,3)=[Station.(ds).(wds).(rs).avgQnodewet(avgx+rjulien(1)-1,sr) ; Station.(ds).(wds).(rs).avgQnodewet(missinglist(j)+rjulien(1)-1,sr)];
                            [mindiff,flowtype]=min(abs([mean(avgtype(1:end-1,1)) mean(avgtype(1:end-1,2)) mean(avgtype(1:end-1,3))] - mean(avgy)));
                            %[yfit,avgm,avgb,avgR2,SEE]=regr(avgy(1:end-1,flowtype),regy,'linreg');
                            %regavgval= avgm * avgy(end,flowtype) + avgb;
                            avgval=avgtype(end,flowtype);
                        else
                            switch flowtype
                                case 1
                                    avgval=Station.(ds).(wds).(rs).avgQnodedry(missinglist(j)+rjulien(1)-1,sr);
                                case 2
                                    avgval=Station.(ds).(wds).(rs).avgQnodeavg(missinglist(j)+rjulien(1)-1,sr);
                                case 3
                                    avgval=Station.(ds).(wds).(rs).avgQnodewet(missinglist(j)+rjulien(1)-1,sr);          
                            end
                            %regavgval= avgm * avgval + avgb;
                        end
                        if gapdist > avgwindow(2)
                            val=avgval;
                        else
                            avgw=(gapdist-avgwindow(1))/(avgwindow(2)-avgwindow(1));
                            val=val*(1-avgw)+avgval*avgw;                            
                        end
                    end
                    tsfill(missinglist(j),1)=val;
       
                end
                end
                end

            end
            Station.(ds).(wds).(rs).Qnodefill(:,sr)=zeros(rsteps,1);
            Station.(ds).(wds).(rs).Qnodefill(datestid:end,sr)=tsfill;
            Station.(ds).(wds).(rs).Qnodefill(1:datestid,sr)=tsfill(1);
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% just for non-telemetry stations
% seperated so that all gage data is filled prior to evaluation
% base flow on avg/dry/wet amounts listed in input with 
% avg/dry/wet determination at closest gage (just one)
% filtering avg and current gage amounts by window so doesnt jump around too much 


for wd=WDlist
    wds=['WD' num2str(wd)];    
    for r=SR.(ds).(wds).R 
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            missinglist=find(Station.(ds).(wds).(rs).Qnodefill(datestid:end,sr)==-999);
            if ~isempty(missinglist)
                notblankids=setdiff(ids,missinglist);
                if isempty(notblankids)
                    %non-telemetry stations
                    %find closest gage (just one)
                    SRid=find(strcmp(SR.(ds).SR(:,1),SR.(ds).(wds).(rs).wdid{sr}));
                    gageids=intersect(find([SR.(ds).SR{:,4}]==wd),SRgageids);
                    if length(gageids)>1 %has other gages in wd - order gages to regress with 
                        gageids=setdiff(gageids,SRid);
                        [srdiffs,gagesortid]=sort(abs(gageids-SRid));  %sorted by number of subreaches to gage that filling
                        gageids=gageids(gagesortid(1)); %just using closest 
                    elseif isempty(gageids) %if no gages on reach (possible?)
                        gageids=setdiff(SRgageids,SRid);
                        for i=1:length(gageids)
                            gid=gageids(i);
                            gagedist(i)=sqrt((SR.(ds).(wds).(rs).utmx(sr)-SR.(SR.(ds).SR{gid,7}).(SR.(ds).SR{gid,8}).(SR.(ds).SR{gid,9}).utmx(SR.(ds).SR{gid,6}))^2 ...
                                - (SR.(ds).(wds).(rs).utmy(sr)-SR.(SR.(ds).SR{gid,7}).(SR.(ds).SR{gid,8}).(SR.(ds).SR{gid,9}).utmy(SR.(ds).SR{gid,6}))^2 );
                        end
                        [srdiffs,gagesortid]=sort(gagedist);
                        gageids=gageids(gagesortid(1)); %just using closest
                    end
                    gid=gageids(1);
                    dsr=SR.(ds).SR{gid,7};
                    wdsr=SR.(ds).SR{gid,8};
                    rsr=SR.(ds).SR{gid,9};
                    srr=SR.(ds).SR{gid,6};
                    
                    avgtype=[Station.(dsr).(wdsr).(rsr).avgQnodedry(:,srr) Station.(dsr).(wdsr).(rsr).avgQnodeavg(:,srr) Station.(dsr).(wdsr).(rsr).avgQnodewet(:,srr)];
                    avgy=Station.(dsr).(wdsr).(rsr).Qnodefill(datestid:end,srr);
                    for i=1:length(avgy)
                        leftids=ids(max(1,i-trendregwindow):max(1,i-1));
                        rightids=ids(i:min(length(avgy),i+trendregwindow-1));
                        filtavgtype(i,:)=mean(avgtype([leftids rightids]+rjulien(1)-1,:));
                        filtavgy(i,1)=mean(avgy([leftids rightids],1));
                    end
                    [mindiff,flowtype]=min(abs(avgtype(1:length(avgy),:) - avgy),[],2);
                    Station.(ds).(wds).(rs).Qnodefill(datestid:end,sr)=SR.(ds).(wds).(rs).avgflow(flowtype,sr);
                    Station.(ds).(wds).(rs).Qnodefill(1:datestid,sr)=SR.(ds).(wds).(rs).avgflow(flowtype(1),sr);
                end
            end
        end
    end
end

    save([basedir 'StateTL_bin_Qnode.mat'],'Station');
else
    load([basedir 'StateTL_bin_Qnode.mat']);    
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Attach station data into SR data (whether build or load)
for wd=WDlist
    wds=['WD' num2str(wd)];
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        SR.(ds).(wds).(rs).Qnode=Station.(ds).(wds).(rs).Qnodefill;
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% WATERCLASS RELEASE RECORDS USING HB REST
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



if pullreleaserecs==1
    clear WC
    WC.date.datestart=datestart;
    WC.date.dateend=dateend;
    for wd=WDlist
        wds=['WD' num2str(wd)];
        WC.date.(ds).(wds).modified=0;
    end
else
    load(['StateTL_bin_WC.mat']);
end

% this is the read of release diversion records for defined releasestructures
% eventually will probably also read diversion records at ditches at least to compare with telemetry or use if no telemetry

if pullreleaserecs>0
     logm=['reading water class release data from HB using REST services option: ' num2str(pullreleaserecs) ' starting: ' datestr(now)];
     domessage(logm,logfilename,displaymessage,writemessage)
     if isempty(reststarttime)
         reststarttime=now;
     end

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
            
%             if strcmp(wc,'1700801 S:X F: U:Q T:0 G: To:')  %REMOVE - CHANGING crooked aug station release to go to mainstem for testing
% %                wc='1700801 S:1 F:1700552 U:Q T:7 G: To:1720001';  %to riv reach
% %                wc='1700801 S:1 F:1700552 U:Q T:7 G: To:1700556';  %to Las Animas
%                 wc='1700801 S:1 F:1700552 U:Q T:7 G: To:1403526';  %exch to PR
%             end
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
    save(['StateTL_bin_WC.mat'],'WC');
end


% % - REMOVE - ADDING FAKE RELEASE FROM TWIN FOR TESTING
% wwcnum='W119999';
% WC.(ds).WC.(wwcnum).wdid='1103503';
% WC.(ds).WC.(wwcnum).wc='1103503.011 S:2 F: U:Q T:7 G: To:1403526.230';
% %WC.(ds).WC.(wwcnum).wc='1103503.011 S:2 F: U:Q T:7 G: To:1700540.012';
% WC.(ds).WC.(wwcnum).type=7;
% WC.(ds).WC.(wwcnum).to='1403526';
% %WC.(ds).WC.(wwcnum).to='1700540';
% WC.(ds).WD112.(wwcnum).datavalues=100*ones(1,15);
% WC.(ds).WD112.(wwcnum).datameasdate=(737151:737165);


if pullstationdata>0 | pullreleaserecs>0
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

% % testing
% for wd=WDlist
%     wds=['WD' num2str(wd)];
%     Rt=SR.(ds).(wds).R(1);
%     Rb=SR.(ds).(wds).R(end);
%     
%     for r=SR.(ds).(wds).R
%         rs=['R' num2str(r)];
%         for sr=SR.(ds).(wds).(rs).SR
%             if SR.(ds).(wds).(rs).type(sr)==0  %add cfs to gages
%                 SR.(ds).(wds).(rs).Qnode(:,sr)=SR.(ds).(wds).(rs).Qnode(:,sr)+500;
%             end
%         end
%     end
% end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RIVERLOOP / GAGEFLOW LOOP 
% this loop just runs on full river flows as measured at gages
% part of this loop is to establish gagediff - which represents gains/losses/errors
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    
if runriverloop==1

logm=['Starting river/gageflow loop at: '  datestr(now)];
domessage(logm,logfilename,displaymessage,writemessage)
    
    
lastwdid=[];  %tracks last wdid/connection of processed wd reaches
SR.(ds).Rivloc.loc=[]; %just tracks location listing of processed reaches
SR.(ds).Rivloc.flowwc.wcloc=[];
SR.(ds).Gageloc.loc=[];
SR.(ds).Rivloc.length=[];


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
% gaininitial=SR.(ds).(wds).(rs).gaininitial(1);
% if gaininitial==-999
%     gain=SR.(ds).(wds).(['R' num2str(r-1)]).gain(end)*sum(SR.(ds).(wds).(rs).channellength)/sum(SR.(ds).(wds).(['R' num2str(r-1)]).channellength);
% else
%     gain=gaininitial;
% end
SR.(ds).(wds).(rs).gain=gain;


% this commented outerloop is used for inadvertant diversion #3 but is broken at the moment
% this was used when I had all the loops merged together - if there was negative internal native flow then riverloop was rerun with increased internal flows
% just keeping at moment until decide what to do with inadvertant diversion correction - if yes will need riverloop into a function that can be rerun
% currently end statement at line 1407
% change=1;changecount=0;
% while change==1
%     change=0;

% zeroing of adjustment terms
% gagediffportion is combined term for gain/loss/errors
% sraddamts are used for inadvertant diversion steps so not currently used

gagediff=zeros(rsteps,1);
SR.(ds).(wds).(rs).gagediffportion=zeros(rsteps,length(SR.(ds).(wds).(rs).SR)); %guess need to restart when doing reoperation
SR.(ds).(wds).(rs).gagedifflast=zeros(rsteps,1);
SR.(ds).(wds).(rs).sraddamt=zeros(rsteps,length(SR.(ds).(wds).(rs).SR));  %this is debatable if needs to be restarted for every reoperation
SR.(ds).(wds).(rs).sraddamtus=zeros(rsteps,length(SR.(ds).(wds).(rs).SR));  %this is debatable if needs to be restarted for every reoperation
SR.(ds).(wds).(rs).sraddamtds=zeros(rsteps,length(SR.(ds).(wds).(rs).SR));  %this is debatable if needs to be restarted for every reoperation


% the following loop iterates in order to establish gagediff term
% initially gagediff=0 but gets calculated after does reach and compares result to downstream gage measurements
% has seemed to generally settled down after about 5 loops
% originally tried to have it get below a limit before stopping, but had problems with convergance on some reaches (may want to go back to that though)
% this gagediff that will be also be utilized later in the wcloop for individual water classes

for ii=1:iternum.(srmethod)
    %while abs(gagediffavg)>gainchangelimit  %used previously when drying to iterate until limit

    
for sr=SR.(ds).(wds).(rs).SR
    
    % initialize flow if at top of reach
    % for first reach - defined either by gage located within first reach or at very top of second reach (ie if reservoir at top)

    if and(sr==1,r==Rt)
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
            
            % if gage not at top of reach, the following backs up the gage flows to the top of reach
            % can have losspercent, but gain=-999 would not change timing, while evapfactor=0 would not include evap
            % so if out of reservoir, and close gage at top of second reach defining flow for reservoir, probably want gain=-999 and evapfactor=0
            % however, if tributary and first gage quite a ways down may want timing and evaporation considered 
            exchtimerem=0;
            for sri=srbb:-1:srt
                type=SR.(ds).(wds).(rs).type(1,sri);
                losspercent=SR.(ds).(wds).(rs).losspercent(sri);
                if gain==-999
                    Qus=Qds*(1+losspercent/100);
                else
                    %using single celerity value not ts to do reversal (what if full year?)
                    [celerity,dispersion]=calcceleritydisp(Qds,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),0);
                    [Qus,exchtimerem,celerity,srtime]=reversecelerity(ds,wds,rs,sr,Qds,exchtimerem,rhours,rsteps,celerity,dispersion);   
                    Qus=Qus*(1+losspercent/100);
                end
                if SR.(ds).(wds).(rs).evapfactor(sr)>0
                    Qavg=(max(Qus,minc)+max(Qds,minc))/2;
                    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
                    evap=SR.(ds).(wds).(rs).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
                    Qus=Qus+evap;
                end
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
    
    %this block seeing if inflow should be defined from by a previously modeled branch flow at a wdid connection point
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
    
    %%%%%%%%%%%%%%%%%%%%%%%
    % main portion to route subreach flow from us to ds
    
    Qus=max(0,Qus);
    Qmin=min(Qus);Qmax=max(Qus);
    
    if gain==-999   %gain=-999 to not run transittime but can have loss percent 
        losspercent=SR.(ds).(wds).(rs).losspercent(sr);
        Qds=Qus*(1-losspercent/100);
        [celerity,dispersion]=calcceleritydisp((Qus+Qds)/2,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),1);
    else
        if strcmp(srmethod,'j349') || (strcmp(srmethod,'default') && strcmp(SR.(ds).defaultmethod.(wds).(rs),'j349'))
            gainportion=gain*SR.(ds).(wds).(rs).reachportion(sr);
            Qus1=max(minj349,Qus);
            [Qds,celerity,dispersion,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Qus1,gainportion,rdays,rhours,rsteps,j349dir,-999,-999,j349multurf,-999,-999,j349fast);
            Qds=Qds-(Qus1-Qus); %timing won't be perfect for this but keeps celerity exactly calculated above (may want to do as just pure addition/subtraction)
            if ~isempty(logm)
                domessage(logm,logfilename,displaymessage,writemessage)
            end
        else
            [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,-999,-999);
        end
        
    end
    Qds=max(0,Qds);
        
    Qavg=(max(Qus,minc)+max(Qds,minc))/2;
    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
    evap=SR.(ds).(wds).(rs).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr); %EvapFactor = 0 to not have evap 
    Qds=Qds-evap+SR.(ds).(wds).(rs).gagediffportion(:,sr)+SR.(ds).(wds).(rs).sraddamt(:,sr);

    
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
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    Qds=max(0,Qds);
    
%    SR.(ds).(wds).(rs).gagediffportion(:,sr)=gagediff*SR.(ds).(wds).(rs).reachportion(sr);
%    SR.(ds).(wds).(rs).evap(:,sr)=evap;
    SR.(ds).(wds).(rs).Qusnode(:,sr)=Qusnode;    
    SR.(ds).(wds).(rs).Qus(:,sr)=Qus;
    SR.(ds).(wds).(rs).Qds(:,sr)=Qds;
    SR.(ds).(wds).(rs).celerity(:,sr)=celerity;    
    SR.(ds).(wds).(rs).dispersion(:,sr)=dispersion;    
    SR.(ds).(wds).(rs).Qmin(sr)=Qmin;  %used in WC loops for multiple linearization
    SR.(ds).(wds).(rs).Qmax(sr)=Qmax;
    SR.(ds).Rivloc.flowriv.us(:,SR.(ds).(wds).(rs).locid(sr))=Qus;
    SR.(ds).Rivloc.flowriv.ds(:,SR.(ds).(wds).(rs).locid(sr))=Qds;
%    SR.(ds).Rivloc.celerity(:,SR.(ds).(wds).(rs).locid(sr))=celerity;   

    if SR.(ds).(wds).(rs).type(sr)==0
        SR.(ds).Gageloc.flowriv(:,SR.(ds).(wds).(rs).gagelocid)=Qusnode; %or Qus
    end

    Qusnode=Qds;
end %sr

SR.(ds).(wds).(rs).gagediff=gagediff;  %this one that was applied

% calculation of gagediff gain/loss/error term
% within iterations gagediff broken out to gagediffportion for each subreach
% after last iteration, any residual amount is assigned as gagedifflast which is just applied to last subreach
% one reason that iteration is needed is because portions dont consider timing changes at individual subreaches
% had block to try to get it better using timing but seemed to have some issues (with negative amts? or dif between j349 and pure celerity?) (may want to revisit)

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
        gagediffavg=gagediffchange(datestid,1);
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
%                     [gagediffus,exchtimerem,revcelerity]=reversecelerity(ds,wds,rs,sr,gagediffds,exchtimerem,rhours,rsteps,celerity,dispersion); %using river celerity
%                 else
%                     gagediffus=gagediffds;
%                 end
%                 gagediffus=gagediffus-gagediffportion;
%                 Qavg=(max(0,gagediffus)+max(0,gagediffds))/2;  %hopefully this doesn't smeer timing
%                 width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
%                 evap=SR.(ds).(wds).(rs).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
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

% end %change
    end %r
    lastwdid=[lastwdid;SR.(ds).(wds).(rs).dswdid{sr} {ds} {wds} {rs} {sr}];
end %wd

save([basedir 'StateTL_bin_riv' srmethod '.mat'],'SR');
elseif runwcloop==1 | runcalibloop==1
    load([basedir 'StateTL_bin_riv' srmethod '.mat']);  
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

logm=['Starting water class routing loop at: '  datestr(now)];
domessage(logm,logfilename,displaymessage,writemessage)
    
    
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


% wdidtoid is index of wdid in WDID list; will be used to see if wdid is US or DS 
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
    dswdidids=find(wdidtoid>=wdidfromid);               % find instances that towdid is DS from fromwdid
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
        if isempty(SR.(ds).(wds).branch) || isempty(wdidtoidnotwd)
            branchid=[];
        else
            branchid=find([SR.(ds).(wds).branch{:,1}]==SR.D2.WDID{wdidtoidnotwd,3});
        end

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

%wsstop=0;
for w=1:length(wwcnumids)
ws=SR.(ds).WCloc.Rloc{wwcnumids(w),1};

% if wsstop==1
%     error('stop')
% %elseif strcmp(ws,'W151408') & r==2
% elseif strcmp(ws,'W151415') & r==7
%     wsstop=1;
% end

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
    

    %full river parameters, here in case get modified by action 1b 
    gain=SR.(ds).(wds).(rs).gain(end);
    Qus=SR.(ds).(wds).(rs).Qus(:,sr);
    Qds=SR.(ds).(wds).(rs).Qds(:,sr);
    celerity=SR.(ds).(wds).(rs).celerity(:,sr);
    dispersion=SR.(ds).(wds).(rs).dispersion(:,sr);
    Qmin=SR.(ds).(wds).(rs).Qmin(sr);  %used in WC loops for multiple linearization
    Qmax=SR.(ds).(wds).(rs).Qmax(sr);
    gainportion=gain*SR.(ds).(wds).(rs).reachportion(sr);

    QSRadd=-1*(min(0,Quspartial-minj349));  %amount of "potentially" negative native
    Quspartial=Quspartial+QSRadd;           %WARNING: this by itself this will cut Qusrelease (waterclass) to Qus (gage) (if exceeds)
%    Quspartial=max(minj349,Quspartial);  %WARNING: this by itself this will cut Qusrelease (waterclass) to Qus (gage) (if exceeds)
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    % INADVERTANT DIVERSIONS - ACTION 1-B
    % if individual Qusrelease (waterclass) exceeds Qus (gage-based) at interior node 
    % measure to allow Qusrelease to pass by - in case of error in gageportion or exchanges on releases
    % B - new method to "temporarily" increase river amount - NOT CURRENTLY WORKING
    QSRaddsum=sum(QSRadd(datestid:end));
    if inadv1b_letwaterby==1 && QSRaddsum>0 %if internal correction so native doesnt go negative
        SR.(ds).(wds).(rs).QSRadd(:,sr)=SR.(ds).(wds).(rs).QSRadd(:,sr)+QSRadd;  %this is going to get overwritten by subsequent water classes (??)
        Qustemp=Qus+QSRadd;

        %rerun river flows with increases
        if gain==-999   %gain=-999 to not run transittime but can have loss percent
            losspercent=SR.(ds).(wds).(rs).losspercent(sr);
            Qdstemp=max(0,Qustemp*(1-losspercent/100));
            [celerity,dispersion]=calcceleritydisp((Qustemp+Qdstemp)/2,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),1);
        else
            if strcmp(srmethod,'j349') || (strcmp(srmethod,'default') && strcmp(SR.(ds).defaultmethod.(wds).(rs),'j349'))
                Qus1=max(minj349,Qustemp);
                [Qdstemp,celerity,dispersion,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Qus1,gainportion,rdays,rhours,rsteps,j349dir,-999,-999,j349multurf,-999,-999,j349fast);
                Qdstemp=Qdstemp-(Qus1-Qustemp); %timing won't be perfect for this but keeps celerity exactly calculated above (may want to do as just pure addition/subtraction)
                if ~isempty(logm)
                    domessage(logm,logfilename,displaymessage,writemessage)
                end
            else
                [Qdstemp,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qustemp,rhours,rsteps,-999,-999);
            end
        end
%         if strcmp(ws,'W151408') & r==2
%             plot(QSRadd)
%         end
        
    end

    
    if pred==1  %not yet using - still need??
        celerity=SR.(ds).(wds).(rs).celeritya(sr)*max(minc,Quspartial).^SR.(ds).(wds).(rs).celerityb(sr);
        dispersion=SR.(ds).(wds).(rs).dispersiona(sr)*max(minc,Quspartial).^SR.(ds).(wds).(rs).dispersionb(sr);
        [celerity,dispersion]=calcceleritydisp(Quspartial,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),1);
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % routing based on partial river amount (river - release), Qmin/Qmax or celerity/disp from river or river+qsradd (action1b)    
    if gain==-999   %gain=-999 to not run timing but can still have loss percent 
        losspercent=SR.(ds).(wds).(rs).losspercent(sr);
        Qdspartial=Quspartial*(1-losspercent/100);
    else
        if strcmp(srmethod,'j349') || (strcmp(srmethod,'default') && strcmp(SR.(ds).defaultmethod.(wds).(rs),'j349'))
            [Qdspartial,celeritypartial,dispersionpartial,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Quspartial,gainportion,rdays,rhours,rsteps,j349dir,celerity,dispersion,j349multurf,Qmin,Qmax,j349fast); %celerity/disp based on gage flows / +minflow because cant have zero flow
            if ~isempty(logm)
                domessage(logm,logfilename,displaymessage,writemessage)
            end 
        else
            [Qdspartial,celeritypartial,dispersionpartial]=runmuskingum(ds,wds,rs,sr,Quspartial,rhours,rsteps,celerity,dispersion);
        end
    end
    
    Qavg=(max(Quspartial,minc)+max(Qdspartial,minc))/2;
    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
    evap=SR.(ds).(wds).(rs).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
    Qdspartial=Qdspartial-evap+SR.(ds).(wds).(rs).gagediffportion(:,sr)+SR.(ds).(wds).(rs).sraddamt(:,sr)+SR.(ds).(wds).(rs).sraddamtds(:,sr);
%    if adjustlastsrtogage==1 && sr==srtb
    if adjustlastsrtogage==1 && sr==SR.(ds).(wds).(rs).SR(end)
        Qdspartial=Qdspartial+SR.(ds).(wds).(rs).gagedifflast;
    end
    
    
    if sum(strcmp(SR.(ds).(wds).(rs).wcreducelist,ws))>0 && inadv2_reducewcpushUS==1 && sr==SR.(ds).(wds).(rs).SR(end)
        Qdspartial=Qdspartial+SR.(ds).(wds).(rs).(ws).wcreduceamtlast;
    end

    QSRdsadd=-1*(min(0,Qdspartial));  %amount of "potentially" negative native
    Qdspartial=Qdspartial+QSRdsadd;  %WARNING: though less likely this by itself could also cut release amts
%    Qdspartial=max(0,Qdspartial);  %WARNING: though less likely this by itself could also cut release amts

    %%%%%%%%%%%%%%%%%%%%%%%%%%
    % INADVERTANT DIVERSIONS - ACTION 1-B
    % also add to ds river amts if Qdspartial goes negative
    QSRdsaddsum=sum(QSRdsadd(datestid:end));
    if inadv1b_letwaterby==1 && (QSRaddsum>0 | QSRdsaddsum>0) %if internal correction so native doesnt go negative
        if QSRdsaddsum>0
            Qdstemp=Qdstemp+QSRdsadd;
        end
        Qusrelease=Qustemp-Quspartial;   %resetting partial amounts to potentially negative amounts
        Qdsrelease=Qdstemp-Qdspartial;
        Quspartial=Qus-Qusrelease;
        Qdspartial=Qds-Qdsrelease;
        logm=['To avoid cutting wc: ' ws ' Action 1-B used to temporarily increase river flow US:' num2str(QSRaddsum)  ' DS:' num2str(QSRdsaddsum) ' wd:' wds ' r:' rs ' sr:' num2str(sr)];
        domessage(logm,logfilename,displaymessage,writemessage)
    end

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
        Qusrelease=Qus-Quspartial;
        Qdsrelease=Qds-Qdspartial;
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
    if QSRaddsum>0 && inadv1a_letwaterby==1 %if internal correction so native doesnt go negate
        release=max(0,release);
        if gain==-999
            dsrelease=release;
            losspercent=SR.(ds).(wds).(rs).losspercent(sr);
            dsrelease=release*(1-losspercent/100);
        elseif strcmp(srmethod,'j349') || (strcmp(srmethod,'default') && strcmp(SR.(ds).defaultmethod.(wds).(rs),'j349'))
            Qmin=SR.(ds).(wds).(rs).Qmin(sr);
            Qmax=SR.(ds).(wds).(rs).Qmax(sr);
            [dsrelease,celerityout,dispersionout,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,release+minj349,gainportion,rdays,rhours,rsteps,j349dir,celerity,dispersion,j349multurf,Qmin,Qmax,j349fast); %celerity/disp based on gage flows - wrong but so timing the same
            dsrelease=dsrelease-minj349-gainportion;  %minflow added in and subtracted - a Qus constant 1 should have Qds constant 1
            if ~isempty(logm)
                domessage(logm,logfilename,displaymessage,writemessage)
            end
        else
            [dsrelease,celerityout,dispersionout]=runmuskingum(ds,wds,rs,sr,release,rhours,rsteps,celerity,dispersion);
        end
        dsrelease=max(0,dsrelease);
        Qavg=(max(dsrelease,minc)+max(release,minc))/2;
        width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
        evap=SR.(ds).(wds).(rs).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
        dsrelease=dsrelease-evap;  %not adding gain/loss term as this is pure release amount
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
                dispersion=SR.(ds).(wds).(rs).dispersion(:,sr);
                if strcmp(srmethod,'j349') || strcmp(srmethod,'muskingum') || (strcmp(srmethod,'default') && strcmp(SR.(ds).defaultmethod.(wds).(rs),'j349')) || (strcmp(srmethod,'default') && strcmp(SR.(ds).defaultmethod.(wds).(rs),'muskingum'))
                    [Qnegus,exchtimerem,celerity,srtime]=reversecelerity(ds,wds,rs,sr,Qnegds,exchtimerem,rhours,rsteps,celerity,dispersion); %using river celerity
                else
                    Qnegus=Qnegds;
                end
                Qavg=Qnegus;  %us and ds should be same amounts but using us to not smeer timing
                width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
                evap=SR.(ds).(wds).(rs).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
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
end %wd

SR.(ds).Rivloc.flownative.us=SR.(ds).Rivloc.flowriv.us-SR.(ds).Rivloc.flowwc.us;
SR.(ds).Rivloc.flownative.ds=SR.(ds).Rivloc.flowriv.ds-SR.(ds).Rivloc.flowwc.ds;


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
                if strcmp(srmethod,'j349') || strcmp(srmethod,'muskingum') || (strcmp(srmethod,'default') && strcmp(SR.(ds).defaultmethod.(wds).(rs),'j349')) || (strcmp(srmethod,'default') && strcmp(SR.(ds).defaultmethod.(wds).(rs),'muskingum'))
                     [QEus,exchtimerem,celerityex,srtime]=reversecelerity(ds,wds,rs,sr,QEds,exchtimerem,rhours,rsteps,-999,-999);
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

save([basedir 'StateTL_bin_wc' srmethod '.mat'],'SR');
elseif runcaptureloop==1
    load([basedir 'StateTL_bin_wc' srmethod '.mat']);  
end %runwcloop


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CAPTURE LOOP TO CHARACTERIZE AVAILABLE/CAPTURE AMT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if runcaptureloop==1
    logm=['Starting capture loop to characterize release capture amounts versus release/available amounts at: '  datestr(now)];
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
                dispersion=SR.(ds).(SR.(ds).WCloc.(ws).loc{j,2}).(SR.(ds).WCloc.(ws).loc{j,3}).dispersion(SR.(ds).WCloc.(ws).loc{j,4});
                if length(celerity)>1
                    celerity=mean(celerity(relstartids(i):relendids(i),1));
                    dispersion=mean(dispersion(relstartids(i):relendids(i),1));
                end
                SC=celerity*dt;SC2=SC*SC;SK=dispersion*dt;XFT=channellength*5280;
                if SR.(ds).WCloc.(ws).loc{j,6}==-1  %exchange - use mean travel time of wave (?)
                    srtime(i)=-1*(XFT/SC+2*SK/SC2);      %from j349 - mean travel time but go backwards if exchange
                else
                    srtime(i)=XFT/SC+2*SK/SC2-(2.78*sqrt(2*SK*XFT/(SC2*SC)+(8*SK/SC2)*(SK/SC2))); %from j349 - time to first response
                end
%                srtime(i)=srtime(i)+SR.(ds).WCloc.(ws).loc{j,6}*(channellength*5280)/celerity/dt; %in hours - will go backwards if exchange
                
            end
            
            if relendids(i)==length(releaseamt)  %release didnt end at end of period
                triggerid(i)=length(releaseamt);    %put trigger id at end
                srtimehrs=0;
            else
                avgrelease=mean(releaseamt(relstartids(i):relendids(i),1));  %will need to revise by periods if evaluating multiple releases
                triggeramt=percrule*avgrelease;
                
                %first try - route/time end of release to location of towdid to start look for trigger amt on receeding limb
                srtimehrs=floor(srtime(i)*.8); %to be conservative on test seemed like j349 was about 15% quicker that celerity value .. humn.. 
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
                        triggeramt2=percrule*mean(releaseamt(relstartids(i+1):relendids(i+1),1));
                        abovetriggerids=find(endpos*availableamt(relstartids(i+1)+srtimehrs:end,:)>=triggeramt2);
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
    logm=['Starting simulation loop for use in calibration at: '  datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)

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
                if r==Rb || SR.(ds).(wds).(['R' num2str(r+1)]).type(1)~=0  %r assuming numerical reach order here
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
        [celerity,dispersion]=calcceleritydisp((Qus+Qds)/2,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),1);
    else
        if strcmp(srmethod,'j349') || (strcmp(srmethod,'default') && strcmp(SR.(ds).defaultmethod.(wds).(rs),'j349'))
            gainportion=gain*SR.(ds).(wds).(rs).reachportion(sr);
            Qus1=max(minj349,Qus);
            Qmin=SR.(ds).(wds).(rs).Qmin(sr);
            Qmax=SR.(ds).(wds).(rs).Qmax(sr);
            [Qds,celerity,dispersion,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Qus1,gainportion,rdays,rhours,rsteps,j349dir,-999,-999,j349multurf,Qmin,Qmax,j349fast);
            Qds=Qds-(Qus1-Qus); %timing won't be perfect for this but keeps celerity exactly calculated above (may want to do as just pure addition/subtraction)
            if ~isempty(logm)
                domessage(logm,logfilename,displaymessage,writemessage)
            end
        else
            [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,-999,-999);
        end
        
    end
    Qds=max(0,Qds);
        
    Qavg=(max(Qus,minc)+max(Qds,minc))/2;
    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
    evap=SR.(ds).(wds).(rs).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr); %EvapFactor = 0 to not have evap
    
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
    %this extra save will take more time - if don't need comment out
    if savefinalcalfile==1
        save([basedir 'StateTL_bin_cal' srmethod '.mat'],'SR','WDcaliblist','ds','datestid','rsteps');
    end
end  %runcalibloop



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OUTPUT - full river / gage loop amounts
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if outputgage==1
    logm=['Starting output of files oriented by subreach/node at: '  datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)

    titlelocline=[{'atWDID'},{'Div'},{'WD'},{'Reach'},{'SubReach'},{'1-USWDID/2-DSWDID'}];
    if outputhr==1
        titledates=cellstr(datestr(rdates(datestid:end),'mm/dd/yy HH:'));
        writecell([titlelocline,titledates'],[outputfilebase srmethod '_riverhr.csv']);
        writecell([titlelocline,titledates'],[outputfilebase srmethod '_nativehr.csv']);
        writecell([titlelocline,titledates'],[outputfilebase srmethod '_gagediffhr.csv']);
        writecell([titlelocline,titledates'],[outputfilebase srmethod '_sraddhr.csv']);
        writecell([titlelocline,titledates'],[outputfilebase srmethod '_totwcreducehr.csv']);
        if runcaptureloop==1
        writecell([titlelocline,titledates'],[outputfilebase srmethod '_nativecapturehr.csv']);
        end
    end
    if outputday==1
        [yr,mh,dy,hr,mi,sec] = datevec(rdates(datestid:end));
        daymat=unique([yr,mh,dy],'rows','stable');
        titledatesday=cellstr(datestr([daymat zeros(size(daymat))],'mm/dd/yy'));
        writecell([titlelocline,titledatesday'],[outputfilebase srmethod '_riverday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilebase srmethod '_nativeday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilebase srmethod '_gagediffday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilebase srmethod '_sraddday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilebase srmethod '_totwcreduceday.csv']);
        if runcaptureloop==1
        writecell([titlelocline,titledatesday'],[outputfilebase srmethod '_nativecaptureday.csv']);
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
        logm=['writing hourly output files for river/native amounts (hourly is a bit slow), starting: ' datestr(now)];
        domessage(logm,logfilename,displaymessage,writemessage)
        writecell([loclineriver,num2cell(outputlineriver)],[outputfilebase srmethod '_riverhr.csv'],'WriteMode','append');
        writecell([loclineriver,num2cell(outputlinenative)],[outputfilebase srmethod '_nativehr.csv'],'WriteMode','append');
        writecell([loclinereach,num2cell(outputlinegagediff)],[outputfilebase srmethod '_gagediffhr.csv'],'WriteMode','append');
        writecell([loclineriver,num2cell(outputlinesradd)],[outputfilebase srmethod '_sraddhr.csv'],'WriteMode','append');
        writecell([loclineriver,num2cell(outputlinetotwcreduce)],[outputfilebase srmethod '_totwcreducehr.csv'],'WriteMode','append');
        if runcaptureloop==1
        writecell([loclineriver,num2cell(outputlinenativecapture)],[outputfilebase srmethod '_nativecapturehr.csv'],'WriteMode','append');
        end
    end
    if outputday==1
        logm=['writing daily output files for river/native amounts, starting: ' datestr(now)];
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
        writecell([loclineriver,num2cell(outputlinedayriver)],[outputfilebase srmethod '_riverday.csv'],'WriteMode','append');        
        writecell([loclineriver,num2cell(outputlinedaynative)],[outputfilebase srmethod '_nativeday.csv'],'WriteMode','append');
        writecell([loclinereach,num2cell(outputlinedaygagediff)],[outputfilebase srmethod '_gagediffday.csv'],'WriteMode','append');        
        writecell([loclineriver,num2cell(outputlinedaysradd)],[outputfilebase srmethod '_sraddday.csv'],'WriteMode','append');        
        writecell([loclineriver,num2cell(outputlinedaytotwcreduce)],[outputfilebase srmethod '_totwcreduceday.csv'],'WriteMode','append');        
        if runcaptureloop==1
        writecell([loclineriver,num2cell(outputlinedaynativecapture)],[outputfilebase srmethod '_nativecaptureday.csv'],'WriteMode','append');
        end
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OUTPUT - water class amounts
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if outputwc==1 & isfield(SR.(ds),'WCloc')
    logm=['Starting output of files ordered by water classes at: ' datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)

wwcnums=SR.(ds).WCloc.wslist;
%titlelocline=[{'WCnum'},{'WC code'},{'Div'},{'WD'},{'Reach'},{'SubReach'},{'srid'},{'1-US/2-DS'},{'WDID'}];
titlelocline=[{'WCnum'},{'WC code'},{'atWDID'},{'Div'},{'WD'},{'Reach'},{'SubReach'},{'1-USWDID/2-DSWDID'}];

if outputhr==1
    logm=['writing hourly output file by water class amounts (hourly is a bit slow), starting: ' datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)
    titledates=cellstr(datestr(rdates(datestid:end),'mm/dd/yy HH:'));
    writecell([titlelocline,titledates'],[outputfilebase srmethod '_wchr.csv']);
    writecell([titlelocline,titledates'],[outputfilebase srmethod '_wcsraddhr.csv']);
    writecell([titlelocline,titledates'],[outputfilebase srmethod '_wcreducehr.csv']);
    if runcaptureloop==1
    writecell([titlelocline,titledates'],[outputfilebase srmethod '_wccapturehr.csv']);
    end
end
if outputday==1
    logm=['writing daily output file by water class amounts, starting: ' datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)
    [yr,mh,dy,hr,mi,sec] = datevec(rdates(datestid:end));
    daymat=unique([yr,mh,dy],'rows','stable');
    titledatesday=cellstr(datestr([daymat zeros(size(daymat))],'mm/dd/yy'));
    writecell([titlelocline,titledatesday'],[outputfilebase srmethod '_wcday.csv']);
    writecell([titlelocline,titledatesday'],[outputfilebase srmethod '_wcreduceday.csv']);
    writecell([titlelocline,titledatesday'],[outputfilebase srmethod '_wcsraddday.csv']);
    if runcaptureloop==1
    writecell([titlelocline,titledatesday'],[outputfilebase srmethod '_wccaptureday.csv']);
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
        writecell([loclinewc,num2cell(outputlinewc)],[outputfilebase srmethod '_wchr.csv'],'WriteMode','append');
        writecell([loclinewc,num2cell(outputlinewcsradd)],[outputfilebase srmethod '_wcsraddhr.csv'],'WriteMode','append');
        if runcaptureloop==1
        writecell([loclinewc,num2cell(outputlinewccapture)],[outputfilebase srmethod '_wccapturehr.csv'],'WriteMode','append');
        end
           if outwcreduce==1
                writecell([loclinewcreduce,num2cell(outputlinewcreduce)],[outputfilebase srmethod '_wcreducehr.csv'],'WriteMode','append');
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
        writecell([loclinewc,num2cell(outputlinedaywc)],[outputfilebase srmethod '_wcday.csv'],'WriteMode','append');        
        writecell([loclinewc,num2cell(outputlinedaywcsradd)],[outputfilebase srmethod '_wcsraddday.csv'],'WriteMode','append');
        if runcaptureloop==1
        writecell([loclinewc,num2cell(outputlinedaywccapture)],[outputfilebase srmethod '_wccaptureday.csv'],'WriteMode','append');
        end
        if outwcreduce==1
            writecell([loclinewcreduce,num2cell(outputlinedaywcreduce)],[outputfilebase srmethod '_wcreduceday.csv'],'WriteMode','append');             
        end
    end
end

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OUTPUT - comparison of gage and simulated amounts at gage
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if outputcal==1 & runcalibloop==1
    logm=['Starting output of files listing just at gage locations at: ' datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)

    titlelocline=[{'WDID'},{'Abbrev'},{'Div'},{'WD'},{'Reach'},{'SubReach'},{'1-Gage/2-Sim'}];
    if outputhr==1
        titledates=cellstr(datestr(rdates(datestid:end),'mm/dd/yy HH:'));
        writecell([titlelocline,titledates'],[outputfilebase srmethod '_calhr.csv']);
    end
    if outputday==1
        [yr,mh,dy,hr,mi,sec] = datevec(rdates(datestid:end));
        daymat=unique([yr,mh,dy],'rows','stable');
        titledatesday=cellstr(datestr([daymat zeros(size(daymat))],'mm/dd/yy'));
        writecell([titlelocline,titledatesday'],[outputfilebase srmethod '_calday.csv']);
    end
    iadd=0;
    for wd=WDcaliblist
        wds=['WD' num2str(wd)];
        wdsids=intersect(find(strcmp(SR.(ds).Gageloc.loc(:,1),ds)),find(strcmp(SR.(ds).Gageloc.loc(:,2),wds)));
        for i=1:length(wdsids)
            j=wdsids(i);
            loclinegage(2*(i+iadd)-1,:)=[SR.(ds).Gageloc.loc(j,5:6),SR.(ds).Gageloc.loc(j,1:4),{1}];  %includes both gage and simulated on subseqent lines
            loclinegage(2*(i+iadd),:)=  [SR.(ds).Gageloc.loc(j,5:6),SR.(ds).Gageloc.loc(j,1:4),{2}];
            outputlinegage(2*(i+iadd)-1,:)=SR.(ds).Gageloc.flowgage(datestid:end,j)';
            outputlinegage(2*(i+iadd),:)=SR.(ds).Gageloc.flowcal(datestid:end,j)';
        end
        iadd=i;
    end
    if outputhr==1
        logm=['writing hourly output files for gage and simulated (calibration) amounts (hourly is a bit slow), starting: ' datestr(now)];
        domessage(logm,logfilename,displaymessage,writemessage)
        writecell([loclinegage,num2cell(outputlinegage)],[outputfilebase srmethod '_calhr.csv'],'WriteMode','append');
    end
    if outputday==1
        logm=['writing daily output files for gage and simulated (calibration) amounts, starting: ' datestr(now)];
        domessage(logm,logfilename,displaymessage,writemessage)
        for i=1:length(daymat(:,1))
            dayids=find(yr==daymat(i,1) & mh==daymat(i,2) & dy==daymat(i,3));
            outputlinedaygage(:,i)=mean(outputlinegage(:,dayids),2);
        end
        writecell([loclinegage,num2cell(outputlinedaygage)],[outputfilebase srmethod '_calday.csv'],'WriteMode','append');        
    end
end

%%%%%%%%%%%%%%%%%%%%%
% END of mainline script

logm=['Done Running StateTL endtime: ' datestr(now) ' elapsed (DD:HH:MM:SS): ' datestr(now-runstarttime,'DD:HH:MM:SS')];    %log message
if displaymessage~=1;disp(logm);end
domessage(logm,logfilename,displaymessage,writemessage)

% if runcalibloop~=1
% msgbox(logm,'StateTL - Colors of Water Model Engine')
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function to calculate celerity and dispersion based on Q
% has option to calculate 1 mean number or time series

function [celerity,dispersion]=calcceleritydisp(Q,celeritya,celerityb,dispersiona,dispersionb,celeritymethod,dispersionmethod,celerityts)
minc=1;  %minimum flow value (cfs) to use to calculate celerity and dispersion

% adjust Q time series - depending if finding single value or time series of celerity
if celerityts==1
    Q=max(minc,Q);
else
    posids=find(Q>=minc);
    if ~isempty(posids)
        Q=mean(Q(posids));
    else
        Q=minc;
    end
end

if celeritymethod==1
    celerity=celeritya*Q.^celerityb;
elseif celeritymethod==2
    celerity=celeritya*Q+celerityb;
else
    errordlg('Error - couldnt figure out method to use to calc celerity, currently 1=ca*Q^cb (ie PR-JMR), 2=ca*Q+cb (ie JMR-SL)')
end    

if dispersionmethod==1
    dispersion=dispersiona*Q.^dispersionb;
elseif celeritymethod==2
    dispersion=10.^(dispersiona*(log10(Q).^2)+dispersionb*log10(Q));
else
    errordlg('Error - couldnt figure out method to use to calc dispersion, currently 1=da*Q^db (ie PR-JMR), 2=10^(da*(logQ^2)+db*logQ) (ie JMR-SL)')
end  
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% muskingum function using TL=percent loss and travel=Muskinghum-Cunge routing using celerity and dispersion coefficients..
%
% some background:
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
    celerityts=1; %indicating time series of celerity values
    [celerity,dispersion]=calcceleritydisp(Qus,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),celerityts);
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

function [Qds,celerity,dispersion,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Qus,gain,rdays,rhours,rsteps,j349dir,celerity,dispersion,j349multurf,Qmin,Qmax,j349fast)
global SR
logm='';

if j349fast==1
    inputcardfilename=['StateTL_j349input_us.dat'];
    outputcardfilename=['StateTL_j349output_ds.dat'];
    outputbinfilename=['StateTL_j349output_ds.bin'];
else
    inputcardfilename=['tStateTL_' ds wds rs 'SR' num2str(sr) '_us.dat'];
    outputcardfilename=['tStateTL_' ds wds rs 'SR' num2str(sr) '_ds.dat'];    
end
filenamesfilename='StateTL_filenames.dat';  %changed this from just filenames

qckmultnum=10; %j349 currently set to take table of 10 Q/C/K values (changed from 8 to 10)
nursf=20; %number of flow urfs to force (max 20), 0 to not force

channellength=SR.(ds).(wds).(rs).channellength(sr);
alluviumlength=SR.(ds).(wds).(rs).alluviumlength(sr);
transmissivity=SR.(ds).(wds).(rs).transmissivity(sr);
storagecoefficient=SR.(ds).(wds).(rs).storagecoefficient(sr);
aquiferwidth=SR.(ds).(wds).(rs).aquiferwidth(sr);
closure=SR.(ds).(wds).(rs).closure(sr);

if j349multurf==0   %single urf linearization
    if length(celerity)>1
        %     if j349multurf=>0
        %         celeritymult=celerity;
        %         dispersionmult=dispersion;
        %     end
        posids=find(Qus>0);        %currently j349 only works with a single celerity (change??!!)
        celerity=mean(celerity(posids));
        dispersion=mean(dispersion(posids));
    elseif celerity==-999
        %basing celerity on subreach Qus - this is slightly different than TLAP (based on average flow for entire reach) but think it better
        celerityts=0; %indicating single value rather than time series
        [celerity,dispersion]=calcceleritydisp(Qus,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),celerityts);
    end
    Qmin=-999;
    Qmax=-999;

else   %multiple urf linearization
    if Qmin==-999
        Qmin=min(Qus);Qmax=max(Qus);  %what if bad spikes in Q?
        if Qmin==Qmax
            Qmax=Qmin+1;
        end
    end
    Qmulta=(Qmax-Qmin)/(qckmultnum-1);
    Qmult=[Qmin:Qmulta:Qmax];
    celerityts=1; %indicating time series of celerity values
    [celeritymult,dispersionmult]=calcceleritydisp(Qmult,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),celerityts);
    
    %the following numbers would be concerning... but, this is currently required because larger numbers mess up formating - could fix that if larger numbers really required
    if max(dispersionmult)>=10000
        exceedids=find(dispersionmult>=10000);
        dispersionmult(exceedids)=9999;
        logm=[logm 'WARNING: D:' ds ' WD:' wds ' R:' rs ' SR:' num2str(sr) ' dispersion exceeded/limited to 10000'];
    end
    if max(celeritymult)>=100
        exceedids=find(celeritymult>=100);
        celeritymult(exceedids)=99;
        logm=[logm 'WARNING: D:' ds ' WD:' wds ' R:' rs ' SR:' num2str(sr) ' celerity exceeded/limited to 100'];
    end
    celerity=mean(celeritymult);
    dispersion=mean(dispersionmult);
end


stagedischarge=SR.(ds).stagedischarge.(['SD' num2str(SR.(ds).(wds).(rs).sdnum(sr))]);

fid=fopen([j349dir inputcardfilename],'w');

cardstr='CDWR TIMING AND TRANSIT LOSS MODEL                                              CARD 1 GEN INFO';
    fprintf(fid,'%95s\r\n',cardstr);
cardstr='SUBREACH  UPSTREAM                                                              CARD 2 RUN INFO';
    fprintf(fid,'%95s\r\n',cardstr);
cardstr='         1         2                                                            CARD 3 INPUT SOURCE AND RUN OBJECTIVE, COl C=j349fast';
cardstr2=num2str(j349fast,'%10.0f');
cardstr(31-length(cardstr2):30)=cardstr2;
    fprintf(fid,'%133s\r\n',cardstr);
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
% Next Line - control options
%           ICASE,ZLOSS,ZPLOT,ZPRINT,ZPUNCH,ZMULT,ZDSQO,ZOUTPUT
%           ICASE - CODE TO SELECT STREAM-AQUIFER BOUNDARY CONDITION     00036800
%           ZLOSS - IDENTIFIES USE OF DIV. AND DEPL. OPTION              00036900
%           ZPLOT, ZPRINT, ZPUNCH- IDENTIFIES USE OF OUTPUT OPTIONS      00037000
%           ZMULT - IDENTIFIES USE OF MULTIPLE LINEARIZATION             00037100
if j349multurf==0
cardstr='         2     False     False      True     False     False     False      TrueCARD 12 RULES FOR SUBREACH NOTE COL G=TRUE FOR OBS HYD FOR COMPARE';
    fprintf(fid,'%146s\r\n',cardstr);
else
cardstr='         2     False     False      True     False      True     False      TrueCARD 12 RULES FOR SUBREACH NOTE COL 6=TRUE FOR MULTIPLE LINEARIZATION';
    fprintf(fid,'%149s\r\n',cardstr);
end
cardstr='                                                                                CARD 13 TT, CHANNEL L, ALLUVIUM L';
cardstr2=num2str(channellength/2,'%10.2f');cardstr3=num2str(channellength,'%10.2f');cardstr4=num2str(alluviumlength,'%10.2f');
cardstr(11-length(cardstr2):10)=cardstr2;cardstr(21-length(cardstr3):20)=cardstr3;cardstr(31-length(cardstr4):30)=cardstr4;
    fprintf(fid,'%113s\r\n',cardstr);
cardstr='                             0                                                  CARD 14 AQUIFER T, S  (LAST FIELD CONSTANT 0)';
cardstr2=num2str(transmissivity,'%10.1f');cardstr3=num2str(storagecoefficient,'%10.2f');
cardstr(11-length(cardstr2):10)=cardstr2;cardstr(21-length(cardstr3):20)=cardstr3;
    fprintf(fid,'%125s\r\n',cardstr);
cardstr='                                                                                CARD 15 WAVE DISP, WAVE CEL, Closure Criteria,(BLANK), AQUIFER WIDTH';
cardstr2=num2str(dispersion,'%10.4f');cardstr3=num2str(celerity,'%10.6f');cardstr4=num2str(closure,'%10.0f');cardstr5=num2str(aquiferwidth,'%10.0f');
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

if j349multurf>0
    
cardstr='                                                                                CARD 18 QMIN, QMAX, NURSF (number of URFS to force) for multiple linearization';
cardstr1=num2str(Qmin,'%10.1f');cardstr2=num2str(Qmax,'%10.1f');cardstr3=num2str(nursf,'%10.0f');    
cardstr(11-length(cardstr1):10)=cardstr1;cardstr(21-length(cardstr2):20)=cardstr2;cardstr(31-length(cardstr3):30)=cardstr3;    
    fprintf(fid,'%158s\r\n',cardstr);

cardstr='                                                                                CARD 19  Celerity VS Q (10 C/Q/ pairs)';
cardstr1=num2str(celeritymult(1),'%10.6f');cardstr2=num2str(celeritymult(2),'%10.6f');cardstr3=num2str(celeritymult(3),'%10.6f');cardstr4=num2str(celeritymult(4),'%10.6f');
cardstr1a=num2str(Qmult(1),'%10.1f');cardstr2a=num2str(Qmult(2),'%10.1f');cardstr3a=num2str(Qmult(3),'%10.1f');cardstr4a=num2str(Qmult(4),'%10.1f');
cardstr(11-length(cardstr1):10)=cardstr1;cardstr(21-length(cardstr1a):20)=cardstr1a;cardstr(31-length(cardstr2):30)=cardstr2;cardstr(41-length(cardstr2a):40)=cardstr2a;
cardstr(51-length(cardstr3):50)=cardstr3;cardstr(61-length(cardstr3a):60)=cardstr3a;cardstr(71-length(cardstr4):70)=cardstr4;cardstr(81-length(cardstr4a):80)=cardstr4a;
    fprintf(fid,'%118s\r\n',cardstr);
%might need to make the following formats dynamic for larger values
j=1;    
fidstr='%10.6f %9.1f %9.6f %9.1f %9.6f %9.1f %9.6f %9.1f\r\n';
    fprintf(fid,fidstr,celeritymult(j*4+1),Qmult(j*4+1),celeritymult(j*4+2),Qmult(j*4+2),celeritymult(j*4+3),Qmult(j*4+3),celeritymult(j*4+4),Qmult(j*4+4));
j=2;  %to do 10 pairs
fidstr='%10.6f %9.1f %9.6f %9.1f\r\n';
    fprintf(fid,fidstr,celeritymult(j*4+1),Qmult(j*4+1),celeritymult(j*4+2),Qmult(j*4+2));

cardstr='                                                                                CARD 20  Wave Dispersion VS Q (10 K/Q/ pairs)';
cardstr1=num2str(dispersionmult(1),'%10.4f');cardstr2=num2str(dispersionmult(2),'%10.4f');cardstr3=num2str(dispersionmult(3),'%10.4f');cardstr4=num2str(dispersionmult(4),'%10.4f');
cardstr1a=num2str(Qmult(1),'%10.1f');cardstr2a=num2str(Qmult(2),'%10.1f');cardstr3a=num2str(Qmult(3),'%10.1f');cardstr4a=num2str(Qmult(4),'%10.1f');
cardstr(11-length(cardstr1):10)=cardstr1;cardstr(21-length(cardstr1a):20)=cardstr1a;cardstr(31-length(cardstr2):30)=cardstr2;cardstr(41-length(cardstr2a):40)=cardstr2a;
cardstr(51-length(cardstr3):50)=cardstr3;cardstr(61-length(cardstr3a):60)=cardstr3a;cardstr(71-length(cardstr4):70)=cardstr4;cardstr(81-length(cardstr4a):80)=cardstr4a;
    fprintf(fid,'%125s\r\n',cardstr);
%might need to make the following formats dynamic for larger values
j=1;
fidstr='%10.4f %9.1f %9.4f %9.1f %9.4f %9.1f %9.4f %9.1f\r\n';
    fprintf(fid,fidstr,dispersionmult(j*4+1),Qmult(j*4+1),dispersionmult(j*4+2),Qmult(j*4+2),dispersionmult(j*4+3),Qmult(j*4+3),dispersionmult(j*4+4),Qmult(j*4+4));
j=2;  %to do 10 pairs
fidstr='%10.4f %9.1f %9.4f %9.1f\r\n';
    fprintf(fid,fidstr,dispersionmult(j*4+1),Qmult(j*4+1),dispersionmult(j*4+2),Qmult(j*4+2));
    
end

fclose(fid);

fid=fopen([j349dir filenamesfilename],'w');
fprintf(fid,'%s\r\n',inputcardfilename);
fprintf(fid,'%s\r\n',outputcardfilename);
if j349fast==1
    fprintf(fid,'%s\r\n',outputbinfilename);
end
fclose(fid);

[s, w] = dos([j349dir 'StateTL_j349.exe']);  %changed this from just j349.exe


if j349fast==1
   fid=fopen([j349dir outputbinfilename],'r');
   Qds=fread(fid,inf,'float32'); %even though compiled 64bit, seems output as 32bit REAL*4 rather than REAL*8
   %hopefully its the right length etc..
   if length(Qds)~=rsteps
        errordlg(['ERROR: Qds read from j349 binary file not same length as rsteps for D:' ds ' WD:' wds ' R:' rs ' SR:' num2str(sr)])
        error(['ERROR: Qds read from j349 binary file not same length as rsteps for D:' ds ' WD:' wds ' R:' rs ' SR:' num2str(sr)])
   end
else

fid=fopen([j349dir outputcardfilename],'r');

k=0;  %just to get header length
while 1
	line = fgetl(fid);
	if strcmp(line,'1 NOTE: CLOSURE WAS NOT OBTAINED IN ITERATION LOOP IN SUBROUTINE QBANK.  COMPUTATIONS ARE TERMINATED.')
        %future - if this happens need way to increase closure value and rerun
        % probably just want to set as one default number for everywhere to start
        errordlg(['ERROR: did not meet closure, increase closure on D:' ds ' WD:' wds ' R:' rs ' SR:' num2str(sr)])
        error(['ERROR: did not meet closure, increase closure on D:' ds ' WD:' wds ' R:' rs ' SR:' num2str(sr)])
    end
    
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

end  %fast
fclose(fid);

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function to route exchanges or other water from DS to US (in reverse time) using same celerity coefficients..
%


function [QEus,srtimerem,celerity,srtime]=reversecelerity(ds,wds,rs,sr,QEds,exchtimerem,rhours,rsteps,celerity,dispersion)
global SR


if celerity==-999
    Qriv=(SR.(ds).(wds).(rs).Qus(:,sr)+SR.(ds).(wds).(rs).Qds(:,sr))/2;
    posids=find(QEds<0);  %using time with exchange (QEds should be negative) to calc avg; if spaces or periods may want to break down by period(?), could have celerity time series but time gets complicated..
    Qdstot=-1*QEds+Qriv;  %for celerity adding river to exchange amount (ie timing if the exchange would have been released from us)
    Qdsavg=mean(Qdstot(posids));
    [celerity,dispersion]=calcceleritydisp(Qdsavg,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),0);
elseif length(celerity)>1
    posids=find(QEds<0);
    celerity=mean(celerity(posids));
    dispersion=mean(dispersion(posids));
end

%believe celerity is in ft/s
channellength=SR.(ds).(wds).(rs).channellength(sr);
dt=rhours * 60 * 60; %sec
%srtime=(channellength*5280)/celerity/dt;  %in hours 
srtime=(channellength*5280)/(celerity*dt)+2*dispersion/(celerity^2)/dt;  %NEW - this from TLAP line 00109400 TMEAN=XFT/SC+2*SK/SC2; in hours

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


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to calculate Rso (clear sky envelope) for ASCE Standardized Reference ET
%
% Equations from ASCE-EWRI (2005)
% ASCE-EWRI. 2005. The ASCE Standardized Reference Evapotranspiration Equation. Edited by R.G. Allen; I.A. Walter; R.L. Elliott; calc.T.A. Howell; D. Itenfisu; M.E. Jensen; and R.L. Snyder. Environmental and Water Resources Institute of the American Society of Civil Engineers.
% Complex Rso as recommended by Allen 2009 - uses vapor pressure

function [Rso,Rsosimple,calc]=ASCErso(vaporpres,julien,latrad,elevm)


calc.ea=vaporpres;                                                   %actual vapor pressure calced from datalogger based on hourly calc.T/RHs

calc.dr=1+0.033*cos(2*pi/365*julien);                                %ASCE Eq 23 - inverse relative earth-sun distance factor (squared) (unitless)
calc.solardec=0.409*sin(2*pi/365*julien-1.39);                       %ASCE Eq 24 - solar declination (radians)
calc.sunsetangle=acos(-1*tan(latrad).*tan(calc.solardec));                %ASCE Eq 27 - sunset hour angle (radians)
calc.Ra=24/pi*4.92*calc.dr.*(calc.sunsetangle.*sin(latrad).*sin(calc.solardec)+sin(calc.sunsetangle).*cos(latrad).*cos(calc.solardec));  %ASCE Eq 21 - extraterrestrial radiation (MJ/m/d)
Rsosimple=(0.75+0.00002*elevm)*calc.Ra;                              %ASCE Eq 19 - simplified clear sky short wave radiation (MJ/m/d)

calc.P=101.3*((293-0.0065*elevm)/293).^5.26;                         %ASCE Eq 3 - Atmospheric Pressure (kPa)
calc.W=0.14*calc.ea*calc.P+2.1;                                                %ASCE Eq D.3 - Precipitable water in the atmosphere (mm)
calc.sinB24=sin(0.85+0.3*latrad*sin(2*pi/365*julien-1.39)-0.42*(latrad).^2); %ASCE Eq D.5 - sin of angle of sun above the horizon during daylight period (radians)
calc.Kt=1.0;                                                         %turbidity coefficient where 1.0 for clean air and <0.5 for extremely turbid, dusty, or polluted air
calc.KB=0.98*exp(-0.00146*calc.P./(calc.Kt*calc.sinB24)-0.075*(calc.W./calc.sinB24).^(0.4));  %ASCE Eq D.2 - clearness index for direct beam radiation
calc.KD=0.35-0.36*calc.KB;                                                %ASCE Eq D.4 - transmissivity index for diffuse radiation using equation for daily data
Rso=(calc.KB+calc.KD).*calc.Ra;                                                %ASCE Eq D.1 - clear sky short wave radiation

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to calculate ASCE Standardized Reference ET
%
% Equations from ASCE-EWRI (2005)
% ASCE-EWRI. 2005. The ASCE Standardized Reference Evapotranspiration Equation. Edited by R.G. Allen; I.A. Walter; R.L. Elliott; calc.T.A. Howell; D. Itenfisu; M.E. Jensen; and R.L. Snyder. Environmental and Water Resources Institute of the American Society of Civil Engineers.
% Using complex Rso as recommended by Allen 2009

function [ETrs,ETos,Tdew,Rso,Rsosimple,calc]=ASCEetr(tmax,tmin,vaporpres,solar,wind,julien,latrad,elevm,negETr,complexRso)

calc.eoTmax= 0.6108*exp(17.27*tmax./(tmax+237.3));                   %ASCE Eq 7 - saturation vapor pressure (Tmax) (KPa)
calc.eoTmin= 0.6108*exp(17.27*tmin./(tmin+237.3));                   %ASCE Eq 7 - saturation vapor pressure (Tmin) (KPa)
calc.es=(calc.eoTmax+calc.eoTmin)/2;                                           %ASCE Eq 6 - saturation vapor pressure
%calc.ea=(calc.eoTmin.*CMfull.(s).RH.max+calc.eoTmax.*CMfull.(s).RH.min)/2;    %ASCE Eq 11 - actual vapor pressure from relative humidity
calc.ea=vaporpres;                                                   %actual vapor pressure calced from datalogger based on hourly calc.T/RHs
Tdew=(116.91+237.3*log(calc.ea))./(16.78-log(calc.ea));                   %ASCE Eq D.7

calc.dr=1+0.033*cos(2*pi/365*julien);                                %ASCE Eq 23 - inverse relative earth-sun distance factor (squared) (unitless)
calc.solardec=0.409*sin(2*pi/365*julien-1.39);                       %ASCE Eq 24 - solar declination (radians)
calc.sunsetangle=acos(-1*tan(latrad).*tan(calc.solardec));                %ASCE Eq 27 - sunset hour angle (radians)
calc.Ra=24/pi*4.92*calc.dr.*(calc.sunsetangle.*sin(latrad).*sin(calc.solardec)+sin(calc.sunsetangle).*cos(latrad).*cos(calc.solardec));  %ASCE Eq 21 - extraterrestrial radiation (MJ/m/d)
Rsosimple=(0.75+0.00002*elevm)*calc.Ra;                              %ASCE Eq 19 - simplified clear sky short wave radiation (MJ/m/d)

calc.P=101.3*((293-0.0065*elevm)/293).^5.26;                         %ASCE Eq 3 - Atmospheric Pressure (kPa)
calc.W=0.14*calc.ea*calc.P+2.1;                                                %ASCE Eq D.3 - Precipitable water in the atmosphere (mm)
calc.sinB24=sin(0.85+0.3*latrad*sin(2*pi/365*julien-1.39)-0.42*(latrad).^2); %ASCE Eq D.5 - sin of angle of sun above the horizon during daylight period (radians)
calc.Kt=1.0;                                                         %turbidity coefficient where 1.0 for clean air and <0.5 for extremely turbid, dusty, or polluted air
calc.KB=0.98*exp(-0.00146*calc.P./(calc.Kt*calc.sinB24)-0.075*(calc.W./calc.sinB24).^(0.4));  %ASCE Eq D.2 - clearness index for direct beam radiation
calc.KD=0.35-0.36*calc.KB;                                                %ASCE Eq D.4 - transmissivity index for diffuse radiation using equation for daily data
Rso=(calc.KB+calc.KD).*calc.Ra;                                                %ASCE Eq D.1 - clear sky short wave radiation

calc.T=(tmax+tmin)/2;                                                %ASCE Eq 2 - mean air temperature (Celsius)
calc.psychro=0.000665*calc.P;                                             %ASCE Eq 4 - psychrometric constant (kPa/C)
calc.slopesatvaptempcurve=2503*exp(17.27*calc.T./(calc.T+237.3))./((calc.T+237.3).^2); %ASCE Eq 5 - slope of the saturation vapor pressure-temperature curve

calc.Rns=(1-0.23)*solar;                                             %ASCE Eq 16  - net short wave radiation
if nargin>=10
    if strcmp(complexRso,'n')
        calc.fcd=1.35*solar./Rsosimple-0.35;                                %ASCE Eq 18 - cloudiness function using simple Rso
    else
        calc.fcd=1.35*solar./Rso-0.35;                                       %ASCE Eq 18 - cloudiness function using full Rso
    end
else
    calc.fcd=1.35*solar./Rso-0.35;                                       %ASCE Eq 18 - cloudiness function using full Rso
end
%     calc.fcd=1.35*solar./Rso-0.35;                                       %ASCE Eq 18 - cloudiness function using full Rso

lowfcdids=find(calc.fcd<0.05);
calc.fcd(lowfcdids)=0.05*ones(size(lowfcdids));
highfcdids=find(calc.fcd>1.0);
calc.fcd(highfcdids)=1.0*ones(size(highfcdids));
%calc.Rnl=4.901E-9*calc.fcd.*(0.34-0.14*(calc.ea.^(0.5))).*(((tmax+273.16)^.4.+(tmin+273.16)^.4)/2); %ASCE Eq 17 - net long wave radiation (using calc.ea from RH)
calc.Rnl=4.901E-9*calc.fcd.*(0.34-0.14*(calc.ea.^(0.5))).*(((tmax+273.16).^4+(tmin+273.16).^4)/2); %ASCE Eq 17 - net long wave radiation (using calc.ea from Tdew)
calc.Rn=calc.Rns-calc.Rnl;                                                     %ASCE Eq 15 - net radiation (MJ/m2/d)
%u2=CMfull.(s).wind.run*1000/24/60/60; %wind speedat 2m in m/s - could need ASCE Eq 33 if not at 2m
calc.CnETos=900;calc.CdETos=0.34;
ETos=(0.408*calc.slopesatvaptempcurve.*(calc.Rn-0)+calc.psychro*(calc.CnETos./(calc.T+273)).*wind.*(calc.es-calc.ea)) ...
    ./ (calc.slopesatvaptempcurve+calc.psychro*(1+calc.CdETos*wind));              %ASCE Eq 1 - standardized reference crop evapotranspiration for short surface (mm/d)
calc.CnETrs=1600;calc.CdETrs=0.38;
ETrs=(0.408*calc.slopesatvaptempcurve.*(calc.Rn-0)+calc.psychro*(calc.CnETrs./(calc.T+273)).*wind.*(calc.es-calc.ea)) ...
    ./ (calc.slopesatvaptempcurve+calc.psychro*(1+calc.CdETrs*wind));              %ASCE Eq 1 - standardized reference crop evapotranspiration for tall surface (mm/d)

%ETos=max(ETos,0); %sometimes goes negative particularly in deep winter - potential "dew" conditions causing - but shouldnt subtract from ETref at crop
%ETrs=max(ETrs,0);

if strcmp(negETr,'n')
    calc.EToswithneg=ETos;
    calc.ETrswithneg=ETrs;
    nanids=isnan(ETrs);
    ETos=max(ETos,0); %sometimes goes negative particularly in deep winter - potential "dew" conditions causing - but feel shouldnt subtract from ETref at crop
    ETrs=max(ETrs,0);  %this removes nans
    ETos(nanids)=nan;  %putting nans back in..
    ETrs(nanids)=nan;
end

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Overall Function to find ASCE reference ET given gridpoint location
%

function [ETrs,ETos]=COASCEETr(utmx,utmy,lat,lon,CAL,gmratio)
    lapserate=1.5;  %lapse rate from Strong et al (2017) and for average annual tmean in Division 2
    TRexponent=1.5;
    stationdistlimit=2.5; %distance in miles below which the closest station will be used straight up without gridded data
    
    if lon>0
        lon=-1*lon;
    end
    lonids=find(gmratio.gmptslon<lon);
    latids=find(gmratio.gmptslat<lat);
    if lon==-999 || isempty(lonids) || isempty(latids) || length(lonids)==length(gmratio.gmptslon) || length(latids)==length(gmratio.gmptslat)
        errormsg=['No grid location found for Lon: ' num2str(lon)  ' Lat: ' num2str(lat) ' Sorry have to stop!'];
        errordlg(errormsg);
        error(errormsg);
    end
    xids=[lonids(end) lonids(end)+1 lonids(end)+1 lonids(end)];
    yids=[latids(1)-1 latids(1)-1 latids(1) latids(1)];
    boxutmxpts=[gmratio.gmptsutmx(latids(1)-1,lonids(end)) gmratio.gmptsutmx(latids(1)-1,lonids(end)+1) gmratio.gmptsutmx(latids(1),lonids(end)+1) gmratio.gmptsutmx(latids(1),lonids(end))];
    boxutmypts=[gmratio.gmptsutmy(latids(1)-1,lonids(end)) gmratio.gmptsutmy(latids(1)-1,lonids(end)+1) gmratio.gmptsutmy(latids(1),lonids(end)+1) gmratio.gmptsutmy(latids(1),lonids(end))];
    for i=1:4
        dist(i)=((utmx-boxutmxpts(i))^2+(utmy-boxutmypts(i))^2)^(1/2);
    end
    zerodist=find(dist==0);
    if ~isempty(zerodist)
        distp=zeros(1,4);
        distp(zerodist,1)=1;
    else
        for i=1:4
        distp(i)=(1/dist(i))/sum(1./dist);  %inverse distance percentage for 4 grid pts
        end
    end
    ptelevm=gmratio.gmptselevm(yids(1),xids(1))*distp(1)+gmratio.gmptselevm(yids(2),xids(2))*distp(2)+gmratio.gmptselevm(yids(3),xids(3))*distp(3)+gmratio.gmptselevm(yids(4),xids(4))*distp(4);
    ptelevft=ptelevm*3.28084;  %elevation ft
    latrad=pi/180*lat;
    
    [mindist mindistid]=min(dist);gmxpt=xids(mindistid);gmypt=yids(mindistid);
    
    if isempty(gmxpt) | isempty(gmypt) %NEED TO INVESTIGATE HOW TO IDENTIFY THAT BAD COORDINATES
        errormsg=['No grid location found for Lon: ' num2str(lon)  ' Lat: ' num2str(lat) ' Sorry have to stop!'];
        errordlg(errormsg);
        error(errormsg);
    end
    
    closelist=gmratio.stations.closelist{gmxpt,gmypt};
    p=gmratio.stations.p{gmxpt,gmypt};
    dists=gmratio.stations.dists{gmxpt,gmypt};
    coaglist=gmratio.stations.coaglist{gmxpt,gmypt};
    pc=gmratio.stations.pc{gmxpt,gmypt};
    cdists=gmratio.stations.cdists{gmxpt,gmypt};
    noaalist=gmratio.stations.noaalist{gmxpt,gmypt};
    pn=gmratio.stations.pn{gmxpt,gmypt};
    ndists=gmratio.stations.ndists{gmxpt,gmypt};

if dists(1)<=stationdistlimit
    closedistids=find(dists<=stationdistlimit);
    if length(closedistids)==1
        closelist=closelist(1);
        p=1;
    else
        closelist=closelist(closedistids);
        clear p
        for i=1:length(closedistids)
            p(i)=(1/dists(i))/sum(1./dists(closedistids));
        end
    end
    if length(closelist)==1 %single station options with no correction
        s=closelist{1};
        ETrs=CAL.(s).ETcal.ETrs;
        ETos=CAL.(s).ETcal.ETos;
        tmax=CAL.(s).ETcal.tmax;
        tmin=CAL.(s).ETcal.tmin;
        precip=CAL.(s).ETcal.precip;
    else  %more than one close station
        ETrs=0; ETos=0; tmax=0;tmin=0;precip=0;
        for i=1:length(closelist)
            s=closelist{i};
            ETrs=ETrs+CAL.(s).ETcal.ETrs*p(i);
            ETos=ETos+CAL.(s).ETcal.ETos*p(i);
            tmax=tmax+CAL.(s).ETcal.tmax*p(i);
            tmin=tmin+CAL.(s).ETcal.tmin*p(i);
            precip=precip+CAL.(s).ETcal.precip*p(i);
        end
        tmax=max(tmax,tmin);
    end
else
    gmrsodiffratio=squeeze(gmratio.gmrsodiffratio(gmxpt,gmypt,:));
    gmwindratio=squeeze(gmratio.gmwindratio(gmxpt,gmypt,:));
    gmprecipratio=squeeze(gmratio.gmprecipratio(gmxpt,gmypt,:));
    
    %%%%%%%%%%%%%%%%%%
    %lapse rate based corrections
    %
    tmax=0;tmin=0;tdewk=0;
    for i=1:length(closelist)
        s=closelist{i};
        tmin=tmin+(CAL.(s).ETcal.tmin+lapserate*(CAL.(s).loc.elev-ptelevft)/1000)*p(i);
        tmax=tmax+(CAL.(s).ETcal.tmax+lapserate*(CAL.(s).loc.elev-ptelevft)/1000)*p(i);
        tdewk=tdewk+(CAL.(s).ETcal.tmin-CAL.(s).ETcal.Tdew)*p(i);
    end
    tmax=max(tmin,tmax);
    Tdew=tmin-tdewk; %ASCE Eq D.8
    ea=0.6108*exp(17.27*Tdew./(Tdew+237.3));  %ASCE Eq 8 - vapor pressure from dew point temperature
    [Rso,Rsosimple,calc]=ASCErso(ea,CAL.julien,latrad,ptelevm); %ASCE Eq D.1 - clear sky short wave radiation (function)
    
        
    %%%%%%%%%%%%%%%%%%
    % SOLAR
    %
        crsodiff=0;
        for i=1:length(coaglist)
            cs=coaglist{i};
            crsodiff=crsodiff+(CAL.(cs).ETcal.Rso-CAL.(cs).ETcal.solar)*pc(i);
        end
        for i=1:12
            monthids=CAL.monthidsall{i};
            solar(monthids,1)=Rso(monthids,1)-crsodiff(monthids,1)*gmrsodiffratio(i);
        end        
    
    %%%%%%%%%%
    % WIND
    %
        mtstations=0;
        for i=1:length(closelist)
            c=closelist{i};
            mtstations=mtstations+CAL.(c).loc.mts;
        end
        wind=0;
        if mtstations>1
            for i=1:length(coaglist)
                cs=coaglist{i};
                wind=wind+CAL.(cs).ETcal.wind*pc(i);
            end
        else
            for i=1:length(coaglist)
                cs=coaglist{i};
                wind=wind+CAL.(cs).ETcal.wind*pc(i);
            end
            for i=1:12
                monthids=CAL.monthidsall{i};
                wind(monthids,1)=wind(monthids,1)*gmwindratio(i);
            end
        end
        

    %%%%%%%%%%
    % PRECIP
    
        precip=0;
        for i=1:length(noaalist)
            ns=noaalist{1};
            precip=precip+CAL.(ns).ETcal.precip*pn(i);
        end
        for i=1:12
            monthids=CAL.monthidsall{i};
            precip(monthids,1)=precip(monthids,1)*gmprecipratio(i);
        end
        
        
     %%%%%%%%%%%%%%
     % ETrs
     
     [ETrs,ETos,Tdew,Rso,Rsosimple,calc]=ASCEetr(tmax,tmin,ea,solar,wind,CAL.julien,latrad,ptelevm,'n');
     
end

end




