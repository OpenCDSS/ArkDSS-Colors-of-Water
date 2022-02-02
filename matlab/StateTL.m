%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% StateTL
% Matlab (preliminary) Colors of Water Transit Loss and Timing engine
% State of Colorado - Division of Water Resources / Colorado Water Conservation Board
%
% cd C:\Projects\Ark\ColorsofWater\matlab
% deployed as function - but when using as .m, may want to remove start/end function/end statements

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function statement for when deployed
% if using as a function from matlab - be sure to type clear all first
% function StateTL(varargin)  %end near line 5500
% clear SR WC
% %%% StateTL('-f','caltest6','-c','2018','-s','-d','-p')

% comment next lines if using as function
clear all
varargin=[];
% varargin=[{'-f'} {'foldertest1'}];
% varargin=[{'-f'} {'\calibration\caltest8'} {'-c'} {'2018'} {'-s'} {'-d'} {'-nw'}];
% varargin=[{'-f'} {'caltestc3_1722020'} {'-c'} {'2020'} {'-s'} {'-d'} {'-p'} {'-m'}];
% varargin=[{'-f'} {['caltestx_' num2str(mmm)]} {'-c'} {'2018'} {'-p'} ];
% varargin=[{'-f'} {'caltest6_wd17stil715'} {'-c'} {'2018,3,15,7,15,WD171,172,17'} {'-s'} {'-d'} {'-p'} {'-m'}];
% varargin=[{'-r'} {'2019'}];
% varargin=[{'-b'} {'2019'}];
% varargin=[{'-f'} {'obstest1'} {'-g'} {'2018,3,15,7,15,WD171,172,17'}];
% varargin=[{'-g'} {'2018'}];
% varargin=[{'-g'}];

runstarttime=now;
basedir=cd;basedir=[basedir '\'];


%%%%%%%%%%%%%%%%%%%%%%%%%%
%Run control options (on=1) fed through control file need to be in this list -
%watch out - if change variable names in code also need to change them here!
%currently - if leave out one of these from control file will assign it a zero value
controlvars={'srmethod','j349fast','j349multurf','j349musk','inputfilename','rundays','fullyear','readinputfile','newnetwork','readevap','readstagedischarge','pullstationdata','multiyrstation','pulllongtermstationdata','pullreleaserecs','runriverloop','runwcloop','doexchanges','runcaptureloop','runobsloop','runcalibloop','stubcelerity','stubdispersion'};
controlvars=[controlvars,{'copydatafiles','savefinalmatfile','logfilename','displaymessage','writemessage','outputfilebase','outputgage','outputwc','outputcal','outputhr','outputday','outputnet','calibavggainloss','calibtype','plotcalib'}];
controlfilename='StateTL_control.txt';


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% additional variable/run options
% potentially some these might also be put into text file

rhours=1;                  %timestep in hours
spinupdayspartialyear=30;  %days to spinup (bank/aquifer storage for j349) if partial year
%spinupdaysfullyear=9;      %days to spinup if full year option ((366days+9days)*24=9000 dimension in j349)
spinupdaysfullyear=0;      %days to spinup if full year option ((366days+9days)*24=9000 dimension in j349)
spindowndays=9;            %spindowndays to account for muskingum routing and use of loss percentages (for 50 mile reach 200 hours generall contains muskingum lag)

flowcriteria=5;            %to establish gage and node flows: 1 low, 2 avg, 3 high flow values from livingston; envision 4 for custom entry; 5 for actual flows; 6 average for xdays/yhours prior to now/date; 7 average between 2 dates
iternum=5;                 %iterations of gageflow loop (previously by method but not currently) to iterate on gagediff (gain/loss/error correction for estimated vs actual gage flows) (had been using dynamic way to iterate but currently just number);

pred=0;                    %if pred=0 subtracts water class from existing flows, if 1 adds to existing gage flows; not really using yet
percrule=.10;              %percent rule - TLAP currently uses 10% of average release rate as trigger amount (Livingston 2011 says 10%; past Livingston 1978 detailed using 5% believe defined as 5% of max amount at headgate)
urfwrapbacktype=1;         %if 0 will not wrap back any tail of bank storage urf, 1 will wrap back with equal proportions, 2 wrap back with proportion based on amount
urfwrapback=.99;           %if wrapping back, wrap back portion

adjustlastsrtogage=1;     %although gagediff process should be getting last sr very close to gage, this would make a final adjustment to exactly equal
inadv1a_letwaterby=0;      %currently 1 - this will let a single water class amt get by an internal node although wc amt exceeds initially estimated river amt - hopefully until internal river amt can be adjusted upwards by last step(ie since have no actual river data at internal node) 
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

evapnew=1;           %1=use new evap method (statewide et dataset) or else old single curve
    evapstartyear=2000;
    ETfilename=[basedir 'StateTLdata\StateTL_evapDiv2.mat'];
    convertevap=5280/(25.4*12*86400); %convert from mm/day to cfs / mile / ft
    etostoevap=1.05;  %standard for lake evap but may want to go higher with factor...
    
avgstartyear=2000;      %if pulllongtermstationdata=1 in control file, year to start pull of daily data to establish dry/wet/avgs for filling
useregrfillforgages=0;  %will fill gages with data from closest stations using regression filling - currently believe other options better (ie 0)
    regfillwindow=28*24; %regression fill window hrs=(days*24)
trendregwindow=14*24;  %hrs to estimate trend for end filling
avgwindow=[7*24 30*24]; %2 values - 1) hrs to start to apply dry/avg/wet average within weighting, 2) hrs to start to apply straight up average     
dayvshrthreshold=[0.01 0.25];  %2 percent difference thresholds to apply daily improved data to hourly telemetry data, <first - dont adjust, >=first-adjust hourly data so daily mean equals daily data, >=second-replace hourly data with daily data 
outputcalregr=1;  %output calibration stats file if doing calibration loop
calibmovingavgdays=14;  %running average window size in days if using movingavg for calibration; 14days will avg 1 week before and after point; also using in bank storage method to average gains for evaporation calc
   movingavgwindow=ceil(calibmovingavgdays*24/rhours); %running average window size in hrs; currently using 2-weeks
filllongtermwithzero=2;  %1 fills zeros in year with some diversion recs with zeros, 2 fills all other years too (except for beyond nov of previous yr)
printcalibplots=1;         %for calib plots only, save to calib folder and close

structureurl='https://dwr.state.co.us/Rest/GET/api/v2/structures/';  %currently used to get structure coordinates just for evaporation
telemetryhoururl='https://dwr.state.co.us/Rest/GET/api/v2/telemetrystations/telemetrytimeserieshour/';  %for gages and ditch telemetry
telemetrydayurl='https://dwr.state.co.us/Rest/GET/api/v2/telemetrystations/telemetrytimeseriesday/';  %for gages and ditch telemetry
surfacewaterdayurl='https://dwr.state.co.us/Rest/GET/api/v2/surfacewater/surfacewatertsday/';  %for published daily gage/ditch data
divrecdayurl='https://dwr.state.co.us/Rest/GET/api/v2/structures/divrec/divrecday/';   %for release/diversion records
llavefile=[basedir 'StateTLdata\StateTL_llave.mat'];
musicfile=[basedir 'StateTLdata\handel.mat'];

gisfile='Source_Water_Route_Framework.gdb';  %GIS source water framework file - will look for in folder or StateTLdata folder, or ask
rivlayer='Source_Water_Route_Framework';     %layer name with river lines
conflayer='Stream_Mile_Confluence_Points';   %layer name with confluence points


logwdidlocations=1;  %for log also document all wdid locations when pulled for evap

if isdeployed
   endmusic=0;
else
   endmusic=1;    
end

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
calibstart=0;calibend=0;

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
   elseif strcmpi(line(1:eids(1)-1),'calibstart')   %calib startdate month,day - will later use yearstart
       calibstart=[str2double(line(tids(1)+1:tids(2)-1)),str2double(line(tids(2)+1:tids(3)-1))];
   elseif strcmpi(line(1:eids(1)-1),'calibend')   %calib enddate month,day - will later use yearstart
       calibend=[str2double(line(tids(1)+1:tids(2)-1)),str2double(line(tids(2)+1:tids(3)-1))];
   elseif strcmpi(line(1:eids(1)-1),'multiyrlist')   %Range of years to pull station data for first,last
       multiyrlist=[str2double(line(tids(1)+1:tids(2)-1)),str2double(line(tids(2)+1:tids(3)-1))];
       multiyrs=[multiyrlist(1):multiyrlist(2)];   
   else
       logtxt='WARNING: control file line not executed: ';
   end
   logmc=[logmc;logtxt line(1:tids(end)-1)];
   end
end
fclose(fid);

if calibstart(1,1)~=0
    calibstartdate=datenum(yearstart,calibstart(1),calibstart(2));
end
if calibend(1,1)~=0
    calibenddate=datenum(yearstart,calibend(1),calibend(2));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% interpretation of command line arguments if given
% as a start; may pass datadirectory and calibration command options
% current example:
% from matlab: StateTL('-f','\calibration\Par.1','-c','2018,04,02,04,20,WD17')
% compiled: StateTL -f \calibration\Par.1 -c 2018,04,02,04,20,WD17
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%

datadir=basedir;
datafiledir=basedir;
cmdlineargs={};

if isempty(varargin)
    logmc=[logmc;'Data directory not defined, all files in: ' basedir];
else
    logmcv='Additional options were defined by command line arguments:';
    for i=1:length(varargin)
        logmcv=[logmcv ' ' varargin{i}];
    end
    logmc=[logmc;logmcv];

    %first command line input argument generally defines folder to put data into
    varloop=1;ccmd=0;bcmd=0;
    i=1;
    while varloop==1
        switch lower(varargin{i})

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % option-f defines data folder, must have folder listed after cmd, \folder or \folder\folder indicates same level as matlab folder, folder or folder\folder indicates put folder below matlab folder
            case '-f'
                cmdlineargs=[cmdlineargs {'f'}];
                if length(varargin)>i
                    cmdtxt=varargin{i+1};
                    if cmdtxt(1)~='-' %indicating another command
                        i=i+1;
                        if cmdtxt(1)=='\'  %if first char is '\' backup one level to place folder at some level as matlab folder
                            slashids=find(basedir=='\');
                            datadir=[basedir(1:slashids(end-1)-1) cmdtxt];
                        else
                            datadir=[basedir cmdtxt];
                        end
                        if datadir(end)~='\'
                            datadir=[datadir '\'];
                        end
                        logmc=[logmc;'Command Line Option -f: datadir=' datadir];

                        %check if folder (make if not) or if inputfilename already in folder
                        if isfolder(datadir) %if inputfilename is in folder, use that as input (otherwise use one in basedir)
                            if isfile([datadir inputfilename])
                                inputfilename=[datadir inputfilename];
                                logmc=[logmc;'Inputfile in folder: ' inputfilename];
                            end
                        else
                            mkdir(datadir);  %mkdir if data directory doesnt exist, debating if would want to copy in inputfile
                            logmc=[logmc;'Data folder created: ' datadir];
                        end

                        % if also copydatafiles=1 then copy datafiles from main matlab folder into command line specified folder
                        % (to avoid potential issues with multiple instances)
                        if copydatafiles==1
                            datafiledir=datadir;
                            logmc=[logmc;'Copying datafiles from: ' basedir ' to ' datadir ' starting:' datestr(now)];
                            copyfile([basedir 'StateTL_data_subreach.mat'],[datadir 'StateTL_data_subreach.mat'],'f');
                            copyfile([basedir 'StateTL_data_evap.mat'],[datadir 'StateTL_data_evap.mat'],'f');
                            copyfile([basedir 'StateTL_data_networklocs.mat'],[datadir 'StateTL_data_networklocs.mat'],'f');
                            copyfile([basedir 'StateTL_data_stagedis.mat'],[datadir 'StateTL_data_stagedis.mat'],'f');
                            copyfile([basedir 'StateTL_data_qnode.mat'],[datadir 'StateTL_data_qnode.mat'],'f');
                            copyfile([basedir 'StateTL_data_release.mat'],[datadir 'StateTL_data_release.mat'],'f');
                            logmc=[logmc;'Copying datafiles done: ' datestr(now) ' file: StateTL_data_subreach.mat,StateTL_data_evap.mat,StateTL_data_stagedis.mat,StateTL_data_qnode.mat,StateTL_data_release.mat'];
                        else
                            datafiledir=basedir;
                        end

                        % output and log to data folder
                        outputfilebase=[datadir outputfilebase];
                        logfilename=[datadir logfilename];
                        logmc=[logmc;'output directory and basename: ' outputfilebase];
                        logmc=[logmc;'logfilename directory: ' logfilename];

                    else
                        logmc=[logmc;'Warning Command Line Option -f but no folder listed before next command option'];
                    end
                else
                    logmc=[logmc;'Warning Command Line Option -f but no folder listed afterwards'];
                    varloop=0;
                end


            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % option-c defines do calibration - can have optional additional arguments of year,sm,sd,em,ed,WDxx,xx2 / year / WDxx / year,WDxx /
            case {'-c','-g'}


                if bcmd==0  %if build command previously issued - let those options govern these
                    readstagedischarge=0;
                    readevap=0;
                    pullstationdata=0;
                    pulllongtermstationdata=0;
                    pullreleaserecs=0;
                    logmc=[logmc;'calibration command option: readstagedischarge=0'];
                    logmc=[logmc;'calibration command option: readevap=0'];
                    logmc=[logmc;'calibration command option: pullstationdata=0'];
                    logmc=[logmc;'calibration command option: pulllongtermstationdata=0'];
                    logmc=[logmc;'calibration command option: pullreleaserecs=0'];
                end

                if strcmpi(varargin{i},'-c')
                cmdlineargs=[cmdlineargs {'c'}];
                ccmd=1;

                readinputfile=2;  %will read new inputfile but not save mat file
                newnetwork=0;
                runriverloop=2;
                runwcloop=0;
                doexchanges=0;
                runcaptureloop=0;
                runcalibloop=1;
                runobsloop=0;
                displaymessage=0;
                writemessage=1;
                outputgage=0;
                outputwc=0;
                outputcal=1;

                %ergg not great - but repeat options verbatim here for log file
                logmc=[logmc;'calibration command option: readinputfile=2'];
                logmc=[logmc;'calibration command option: newnetwork=0'];
                logmc=[logmc;'calibration command option: runriverloop=2'];
                logmc=[logmc;'calibration command option: runwcloop=0'];
                logmc=[logmc;'calibration command option: doexchanges=0'];
                logmc=[logmc;'calibration command option: runcaptureloop=0'];
                logmc=[logmc;'calibration command option: runcalibloop=1'];
                logmc=[logmc;'calibration command option: runobsloop=1'];
                logmc=[logmc;'calibration command option: displaymessage=0'];
                logmc=[logmc;'calibration command option: writemessage=1'];
                logmc=[logmc;'calibration command option: outputgage=0'];
                logmc=[logmc;'calibration command option: outputwc=0'];
                else
                cmdlineargs=[cmdlineargs {'g'}];
                    %for observation loop
                    runobsloop=1;
                    logmc=[logmc;'observations command option: runobsloop=1'];
                    readinputfile=0;
                    newnetwork=0;
                    runriverloop=0;
                    runwcloop=0;
                    doexchanges=0;
                    runcaptureloop=0;
                    runcalibloop=0;
                    displaymessage=0;
                    writemessage=1;
                    outputgage=0;
                    outputwc=0;
                    outputcal=0;

                    %ergg not great - but repeat options verbatim here for log file
                    logmc=[logmc;'observation command option: readinputfile=0'];
                    logmc=[logmc;'observation command option: newnetwork=0'];
                    logmc=[logmc;'observation command option: runriverloop=0'];
                    logmc=[logmc;'observation command option: runwcloop=0'];
                    logmc=[logmc;'observation command option: doexchanges=0'];
                    logmc=[logmc;'observation command option: runcaptureloop=0'];
                    logmc=[logmc;'observation command option: runcalibloop=0'];
                    logmc=[logmc;'observation command option: displaymessage=0'];
                    logmc=[logmc;'observation command option: writemessage=1'];
                    logmc=[logmc;'observation command option: outputgage=0'];
                    logmc=[logmc;'observation command option: outputwc=0'];
                    logmc=[logmc;'observation command option: outputcal=0'];

                end

                if length(varargin)>i
                    cmdtxt=varargin{i+1};
                    if cmdtxt(1)~='-' %indicating another command
                        i=i+1;
                        cids=find(cmdtxt==',');
                        tids=[cids,length(cmdtxt)+1];
                        if (isempty(cids) && ~strcmp(cmdtxt(1:2),'WD')) || length(cids)==1
                            yearstart=str2double(cmdtxt(1:tids(1)-1));
                            calibstartdate=datenum(yearstart,calibstart(1),calibstart(2));
                            calibenddate=datenum(yearstart,calibend(1),calibend(2));
                            logmc=[logmc;'calibration command line argument: yearstart=' num2str(yearstart)];
                            logmc=[logmc;'calibration command line argument: calibration start=' datestr(calibstartdate,23)];
                            logmc=[logmc;'calibration command line argument: calibration end=' datestr(calibenddate,23)];
                            if length(cids)==1
                                WDcaliblist=str2double(cmdtxt(tids(1)+3:tids(2)-1)); %counting on WD and just a single calibration reach
                                logmc=[logmc;'calibration command line argument: WDcaliblist=' num2str(WDcaliblist)];
                            end
                        elseif ~isempty(cids)
                            yearstart=str2double(cmdtxt(1:tids(1)-1));
                            if strcmp(cmdtxt(tids(1)+1:tids(1)+2),'WD')
                                calibstartdate=datenum(yearstart,calibstart(1),calibstart(2));
                                calibenddate=datenum(yearstart,calibend(1),calibend(2));
                                tk=1;
                            else
                                calibstartdate=datenum(yearstart,str2double(cmdtxt(tids(1)+1:tids(2)-1)),str2double(cmdtxt(tids(2)+1:tids(3)-1)));
                                calibenddate=datenum(yearstart,str2double(cmdtxt(tids(3)+1:tids(4)-1)),str2double(cmdtxt(tids(4)+1:tids(5)-1)));
                                tk=5;
                            end
                            logmc=[logmc;'calibration command line argument: yearstart=' num2str(yearstart)];
                            logmc=[logmc;'calibration command line argument: calibration start=' datestr(calibstartdate,23)];
                            logmc=[logmc;'calibration command line argument: calibration end=' datestr(calibenddate,23)];
                            
                            if length(tids)>tk
                                clear WDcaliblist
                                for k=tk:length(tids)-1
                                    if k==tk
                                        tks=3;
                                    else
                                        tks=1;
                                    end
                                    WDcaliblist(k-tk+1)= str2double(cmdtxt(tids(k)+tks:tids(k+1)-1));
                                end
                                logmc=[logmc;'calibration command line argument: WDcaliblist=' num2str(WDcaliblist)];
                            end
                        else
                            WDcaliblist=str2double(cmdtxt(3:end));
                            logmc=[logmc;'calibration command line argument: WDcaliblist=' num2str(WDcaliblist)];
                        end
                    end
                elseif multiyrstation==1
                    cmdlineargs=[cmdlineargs {'m'}];
                end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % option -b defines build base binary files, as typically if switching to a new year or period
            % in this case, evaporation and long term station data would not be rebuilt (only required if change in network)
            % option -r defines rebuild base binary files, as typically to rebuid after a change in the river networks
            % in this case, evaporation and long term station data be rebuilt (so slower)
            % - both can have optional additional arguments of year / year,sm,sd,em,ed
            case {'-b','-r'}
                bcmd=1;
                if strcmpi(varargin{i},'-b')
                cmdlineargs=[cmdlineargs {'b'}];
                    readinputfile=0;
                    newnetwork=0;
                    readstagedischarge=0;
                    readevap=0;
                    pullstationdata=1;
                    pulllongtermstationdata=0;
                    pullreleaserecs=1;
                    logmc=[logmc;'build command option: readinputfile=0'];
                    logmc=[logmc;'build command option: newnetwork=0'];
                    logmc=[logmc;'build command option: readstagedischarge=0'];
                    logmc=[logmc;'build command option: readevap=0'];
                    logmc=[logmc;'build command option: pullstationdata=1'];
                    logmc=[logmc;'build command option: pulllongtermstationdata=0'];
                    logmc=[logmc;'build command option: pullreleaserecs=1'];
                else
                cmdlineargs=[cmdlineargs {'r'}];
                    readinputfile=1;
                    newnetwork=1;
                    readstagedischarge=1;
                    readevap=1;
                    pullstationdata=1;
                    pulllongtermstationdata=1;
                    pullreleaserecs=1;
                    logmc=[logmc;'rebuild command option: readinputfile=1'];
                    logmc=[logmc;'rebuild command option: newnetwork=1'];
                    logmc=[logmc;'rebuild command option: readstagedischarge=1'];
                    logmc=[logmc;'rebuild command option: readevap=1'];
                    logmc=[logmc;'rebuild command option: pullstationdata=1'];
                    logmc=[logmc;'rebuild command option: pulllongtermstationdata=1'];
                    logmc=[logmc;'rebuild command option: pullreleaserecs=1'];
                end
                
                if ccmd==0  %if calibration command previously issued - let calib options govern
                    runriverloop=0;
                    runwcloop=0;
                    doexchanges=0;
                    runcaptureloop=0;
                    runcalibloop=0;
                    outputgage=0;
                    outputwc=0;
                    outputcal=0;

                    logmc=[logmc;'build/rebuild command option: runriverloop=0'];
                    logmc=[logmc;'build/rebuild command option: runwcloop=0'];
                    logmc=[logmc;'build/rebuild command option: doexchanges=0'];
                    logmc=[logmc;'build/rebuild command option: runcaptureloop=0'];
                    logmc=[logmc;'build/rebuild command option: runcalibloop=0'];
                    logmc=[logmc;'build/rebuild command option: outputgage=0'];
                    logmc=[logmc;'build/rebuild command option: outputwc=0'];
                    logmc=[logmc;'build/rebuild command option: outputcal=0'];
                end
                if length(varargin)>i
                    cmdtxt=varargin{i+1};
                    if cmdtxt(1)~='-' %indicating another command
                        i=i+1;
                        cids=find(cmdtxt==',');
                        if isempty(cids)
                            yearstart=str2double(cmdtxt(1:end));
                            fullyear=1;
                            logmc=[logmc;'build/rebuild command line argument: yearstart=' num2str(yearstart)];
                            logmc=[logmc;'build/rebuild command line argument: fullyear=' num2str(1)];
                        elseif ~isempty(cids)
                            tids=[cids,length(cmdtxt)+1];
                            yearstart=str2double(cmdtxt(1:tids(1)-1));
                            datestart=datenum(yearstart,str2double(cmdtxt(tids(1)+1:tids(2)-1)),str2double(cmdtxt(tids(2)+1:tids(3)-1)));
                            dateend=datenum(yearstart,str2double(cmdtxt(tids(3)+1:tids(4)-1)),str2double(cmdtxt(tids(4)+1:tids(5)-1)));
                            rundays=round(dateend-datestart+1);
                            rundayjulien=(datestart-datenum(yearstart,1,1)+1);
                            logmc=[logmc;'build/rebuild command line argument: yearstart=' num2str(yearstart)];
                            logmc=[logmc;'build/rebuild command line argument: datestart=' datestr(datestart,23)];
                            logmc=[logmc;'build/rebuild command line argument: rundays=' num2str(rundays)];

                        end
                    end
                end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % option-s overrides savefinalmatfile to save final mat files from calibration or control loops (used for plotting etc)
            case '-s'
                cmdlineargs=[cmdlineargs {'s'}];
                savefinalmatfile=1;
                logmc=[logmc;'save command option: savefinalmatfile=1'];

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % option-d overrides displaymessage to display output to screen
            case '-d'
                cmdlineargs=[cmdlineargs {'d'}];
                displaymessage=1;
                logmc=[logmc;'display command option: displaymessage=1'];

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % option-nd overrides displaymessage to NOT display output to screen
            case '-nd'
                cmdlineargs=[cmdlineargs {'nd'}];
                displaymessage=0;
                logmc=[logmc;'display command option: displaymessage=0'];

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % option-w overrides writemessage to write output to logfile
            case '-w'
                cmdlineargs=[cmdlineargs {'w'}];
                writemessage=1;
                logmc=[logmc;'write command option: writemessage=1'];

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % option-nd overrides displaymessage to NOT display output to screen
            case '-nw'
                cmdlineargs=[cmdlineargs {'nw'}];
                writemessage=0;
                logmc=[logmc;'write command option: writemessage=0'];

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % option-m plays music after run - even in deployed (needs handel.mat)
            case '-m'
                cmdlineargs=[cmdlineargs {'m'}];
                endmusic=1;
                logmc=[logmc;'command option: endmusic=1'];

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % option-p plots some calibration figures - in conjunction with calibration command only
            case '-p'
                cmdlineargs=[cmdlineargs {'p'}];
                plotcalib=1;
                logmc=[logmc;'command option: plotcalib=1;'];

            otherwise
                logmc=[logmc;['Warning command line option: ' varargin{i} ' could not be interpreted and was skipped']];

        end

        if length(varargin)==i
            varloop=0;
        else
            i=i+1;
        end

    end
end

if newnetwork==1 && readinputfile==0
    logmc=[logmc;'change command option: since netnetwork=1 then readinputfile=1'];
end


j349dir=datadir;   %if datadir will write fortran i/o there, fortran codes now using a command line argument to use datadir
logmc=[logmc;'J349 read/write directory: ' j349dir];
%%

if newnetwork==1 || readevap==1 || pullstationdata>=1 || pullreleaserecs>0
    logmc=[logmc;'reading api llave: ' llavefile];
    load(llavefile);
end

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
    rundays=datenum(yearstart,12,31)-datestart+1;
    rdays=rundays+spinupdays+spindowndays;  %if doing whole year
else
    rundays=max(1,rundays);    %rundays is days without spinup, will override zero to one
    rundays=min(366,rundays);  %max of a year as j349 dimensions set at 9000
    spinupdays=min(spinupdayspartialyear,375-rundays-spindowndays);
    rdays=rundays+spinupdays+spindowndays;  %rdays is with spinup
end

runsteps=rundays*24/rhours;
rsteps=rdays*24/rhours;
datestid=spinupdays*24/rhours+1;
dateendid=datestid+runsteps-1;
rundates=[datestart:rhours/24:datestart+rundays-rhours/24]';
rdates=[datestart*ones(spinupdays*24/rhours,1);rundates;rundates(end)*ones(spindowndays*24/rhours,1)];
[ryear,rmonth,rundays,rhour] = datevec(rdates);
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

if readinputfile>0

%%%%%%%%%%%%%%%%%%%%%%%%%%    
% read subreach data    
logm=['reading subreach info from file: ' inputfilename];
domessage(logm,logfilename,displaymessage,writemessage)

if strcmp(inputfilename(end-3:end),'xlsx') || strcmp(inputfilename(end-2:end),'xls')
    if ~isfile(inputfilename) && strcmp(inputfilename(end-2:end),'xls')
       inputfilename=[inputfilename 'x']; %perhaps entered as xls rather than xlsx
    end
    inforaw=readcell([inputfilename],'Sheet','SR');
else
    inforaw=readcell([inputfilename]);
end
[inforawrow,inforawcol]=size(inforaw);

%[infonum,infotxt,inforaw]=xlsread([inputfilename],'SR');
%[inforawrow inforawcol]=size(inforaw);

infoheaderrow=1;

for i=1:inforawcol
    if 1==2

    elseif strcmpi(inforaw{infoheaderrow,i},'WDID'); infocol.wdid=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'NAME'); infocol.name=i;
%     elseif strcmpi(inforaw{infoheaderrow,i},'DSWDID'); infocol.dswdid=i;
%     elseif strcmpi(inforaw{infoheaderrow,i},'DSNAME'); infocol.dsname=i;
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
    elseif strcmpi(inforaw{infoheaderrow,i},'stublength'); infocol.stublength=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'stubloss'); infocol.stubloss=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'GNIS_ID'); infocol.gnisid=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'Conf_ID'); infocol.confid=i;

    elseif strcmpi(inforaw{infoheaderrow,i},'TRANSMISSIVITY'); infocol.transmissivity=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'STORAGE COEFFICIENT'); infocol.storagecoefficient=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'AQUIFER WIDTH'); infocol.aquiferwidth=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'DISPERSION-A'); infocol.dispersiona=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'DISPERSION-B'); infocol.dispersionb=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'CELERITY-A'); infocol.celeritya=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'CELERITY-B'); infocol.celerityb=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'CelerityMethod'); infocol.celeritymethod=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'DispersionMethod'); infocol.dispersionmethod=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'URFThreshold'); infocol.urfthreshold=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'SDNUM'); infocol.sdnum=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'CLOSURE'); infocol.closure=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'GAININITIAL'); infocol.gaininitial=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'WIDTH-A'); infocol.widtha=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'WIDTH-B'); infocol.widthb=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'EVAPFACTOR'); infocol.evapfactor=i;
    elseif strcmpi(inforaw{infoheaderrow,i},'DefaultMethod'); infocol.defaultmethod=i;

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
    
    if ~isempty(inforaw{i,infocol.subreach}) && ~ismissing(inforaw{i,infocol.subreach}) %WATCH!! - last WDID in WD must not have subreach id!!!
        for j=1:inforawcol  %doing this as a quick fix for converting from xlsread to readcell
            if ismissing(inforaw{i,j})
                inforaw{i,j}=[NaN];            
            end
        end

        k=k+1;
        v.di=inforaw{i,infocol.div};if ischar(v.di); v.di=str2num(v.di); end
        v.wd=inforaw{i,infocol.wd};if ischar(v.wd); v.wd=str2num(v.wd); end
        v.re=inforaw{i,infocol.reach};if ischar(v.re); v.re=str2num(v.re); end        
        v.sr=inforaw{i,infocol.subreach};if ischar(v.sr); v.sr=str2num(v.sr); end
        v.si=inforaw{i,infocol.srid};if ischar(v.si); v.si=str2num(v.si); end
        c.di=num2str(inforaw{i,infocol.div});
        c.wd=num2str(inforaw{i,infocol.wd});
        c.re=num2str(inforaw{i,infocol.reach});
 
        c.uw=num2str(inforaw{i,infocol.wdid});
        c.un=num2str(inforaw{i,infocol.name});
        c.dw=num2str(inforaw{i+1,infocol.wdid});  %WATCH!! - dswdid currently must be in order with downstream wdid listed below upstream wdid
        c.dn=num2str(inforaw{i+1,infocol.name});  %WATCH!! - dsname currently must be in order with downstream wdid listed below upstream wdid
        c.ds=num2str(inforaw{i,infocol.station});
        c.dp=num2str(inforaw{i,infocol.parameter});
        c.br=num2str(inforaw{i,infocol.branch});
        c.ws=num2str(inforaw{i,infocol.gnisid});
        c.dm=num2str(inforaw{i,infocol.defaultmethod});

        v.uc=inforaw{i,infocol.confid};if ischar(v.uc); v.uc=str2num(v.uc); end; 
        v.dc=inforaw{i+1,infocol.confid};if ischar(v.dc); v.dc=str2num(v.dc); end  %WATCH!! - dc confid currently must be in order with downstream wdid listed below upstream wdid
        
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
        v.sle=inforaw{i,infocol.stublength};if ischar(v.sle); v.sle=str2num(v.sle); end
        v.slp=inforaw{i,infocol.stubloss};if ischar(v.slp); v.slp=str2num(v.slp); end
        v.tr=inforaw{i,infocol.transmissivity};if ischar(v.tr); v.tr=str2num(v.tr); end
        v.sc=inforaw{i,infocol.storagecoefficient};if ischar(v.sc); v.sc=str2num(v.sc); end
        v.aw=inforaw{i,infocol.aquiferwidth};if ischar(v.aw); v.aw=str2num(v.aw); end
        v.da=inforaw{i,infocol.dispersiona};if ischar(v.da); v.da=str2num(v.da); end
        v.db=inforaw{i,infocol.dispersionb};if ischar(v.db); v.db=str2num(v.db); end
        v.ca=inforaw{i,infocol.celeritya};if ischar(v.ca); v.ca=str2num(v.ca); end
        v.cb=inforaw{i,infocol.celerityb};if ischar(v.cb); v.cb=str2num(v.cb); end 
        v.cm=inforaw{i,infocol.celeritymethod};if ischar(v.cm); v.cm=str2num(v.cm); end
        v.dm=inforaw{i,infocol.dispersionmethod};if ischar(v.dm); v.dm=str2num(v.dm); end
        v.ut=inforaw{i,infocol.urfthreshold};if ischar(v.ut); v.ut=str2num(v.ut); end
        v.sd=inforaw{i,infocol.sdnum};if ischar(v.sd); v.sd=str2num(v.sd); end
        v.cls=inforaw{i,infocol.closure};if ischar(v.cls); v.cls=str2num(v.cls); end
        v.gi=inforaw{i,infocol.gaininitial};if ischar(v.gi); v.gi=str2num(v.gi); end
        v.wa=inforaw{i,infocol.widtha};if ischar(v.wa); v.wa=str2num(v.wa); end
        v.wb=inforaw{i,infocol.widthb};if ischar(v.wb); v.wb=str2num(v.wb); end
        v.ef=inforaw{i,infocol.evapfactor};if ischar(v.ef); v.ef=str2num(v.ef); end

        %if not there then fill value with zero (may want to do for others)
        if ismissing(v.uc); v.uc=0; end  %us confid
        if ismissing(v.dc); v.dc=0; end  %ds confid
        if ismissing(v.cl); v.cl=0; end  %channellength
        if ismissing(v.al); v.al=0; end  %alluviumlength
        if ismissing(v.rp); v.rp=0; end  %reachportion
        if ismissing(v.lp); v.lp=0; end  %losspercent
        if ismissing(v.sle); v.sle=0; end  %stublength
        if ismissing(v.slp); v.slp=0; end  %stub losspercent




        % if have blanks in for avg flow rates, change value to -999
        if isnan(v.l1)
            v.l1=-999;
        end
        if isnan(v.a1)
            v.a1=-999;
        end
        if isnan(v.h1)
            v.h1=-999;
        end

           
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
            SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).SR=unique([SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).SR v.sr],'stable');
        else
            SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).SR=v.sr;
        end
        

        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).subreachid(v.sr)=v.si;
        
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).wdid{1,v.sr}=c.uw;        
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).name{1,v.sr}=c.un;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dswdid{1,v.sr}=c.dw;        
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
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).stublength(v.sr)=v.sle;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).stubloss(v.sr)=v.slp;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).transmissivity(v.sr)=v.tr;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).storagecoefficient(v.sr)=v.sc;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).aquiferwidth(v.sr)=v.aw;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dispersiona(v.sr)=v.da;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dispersionb(v.sr)=v.db;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).celeritya(v.sr)=v.ca;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).celerityb(v.sr)=v.cb;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).celeritymethod(v.sr)=v.cm;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dispersionmethod(v.sr)=v.dm;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).urfthreshold(v.sr)=v.ut;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).sdnum(v.sr)=v.sd;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).closure(v.sr)=v.cls;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).gaininitial(v.sr)=v.gi;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).widtha(v.sr)=v.wa;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).widthb(v.sr)=v.wb;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).evapfactor(v.sr)=v.ef;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).gnisid{1,v.sr}=c.ws;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).confid(v.sr)=v.uc;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).dsconfid(v.sr)=v.dc;
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).defaultmethod{1,v.sr}=c.dm;



        if v.rs==1  % releasestructures - structures with Type:7 records that define releases to ds or us exchange
            if isempty(SR.(['D' c.di]).(['WD' c.wd]).releasestructures)
                SR.(['D' c.di]).(['WD' c.wd]).releasestructures={c.uw};
            else
                SR.(['D' c.di]).(['WD' c.wd]).releasestructures=[SR.(['D' c.di]).(['WD' c.wd]).releasestructures,{c.uw}];
            end
        end
        
        if ~isnan(v.br)
            if isempty(SR.(['D' c.di]).(['WD' c.wd]).branch)
                SR.(['D' c.di]).(['WD' c.wd]).branch=[{v.br} {c.uw} {v.re} {v.sr}];
            else
                SR.(['D' c.di]).(['WD' c.wd]).branch=[SR.(['D' c.di]).(['WD' c.wd]).branch;{v.br} {c.uw} {v.re} {v.sr}];
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

%         %redoing a WDID list with reaches referenced instead to us wdid (for network file) - someday switch regular WDID to same (need changes in routing code)
%         SR.(['D' c.di]).WDID2{wdidk-1,1}=c.uw;
%         SR.(['D' c.di]).WDID2{wdidk-1,2}=v.di;
%         SR.(['D' c.di]).WDID2{wdidk-1,3}=v.wd;
%         SR.(['D' c.di]).WDID2{wdidk-1,4}=v.re;
%         SR.(['D' c.di]).WDID2{wdidk-1,5}=v.sr;
%         SR.(['D' c.di]).WDID2{wdidk-1,6}=0;  %indicates usnode
%         SR.(['D' c.di]).WDID2{wdidk,1}=c.dw;
%         SR.(['D' c.di]).WDID2{wdidk,2}=v.di;
%         SR.(['D' c.di]).WDID2{wdidk,3}=v.wd;
%         SR.(['D' c.di]).WDID2{wdidk,4}=v.re;
%         SR.(['D' c.di]).WDID2{wdidk,5}=v.sr;
%         SR.(['D' c.di]).WDID2{wdidk,6}=1;  %indicates dsnode
       

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
SR.(ds).SRfull=SR.(ds).SR;
SR.(ds).SR=SRsortedbywdidlist;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% calculation of bankurf for new matlab based bank storage
% new - calculating both using j349 method and glover bank storage method (see BuRec EM31 document)
% new - now having bankurf as value in ft2/s ready to multiply by delta stage (H-head)
% cumvalue in ft2 for storage volume limitations

%initial glover type bank storage parameters
K=1000; %hydraulic conductivity in ft/day
Dbank=10;   %average thickness of bank materials in ft
T=K*Dbank/(3600*24); %transmissibility of bank materials in ft2/s
t=[.5:1:(rsteps-0.5)]*3600;


logm=['calculating bank storage urfs'];
domessage(logm,logfilename,displaymessage,writemessage)
for wd=SR.(ds).WD
    wds=['WD' num2str(wd)];
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            XL=SR.(ds).(wds).(rs).aquiferwidth(sr); %J349 XL = aquifer width


            % Glover bank storage F=H L T / sqrt(pi T/SS t) - infinite / *(1-exp(-(2*XL)2/(4 T/SS t)) for aquifer boundary case
%             W=XL/1.5;  %for glover solution currently seem like may need to decrease XL to be more similar to j349
%             T=SR.(ds).(wds).(rs).transmissivity(sr)/(3600*24);  %actual T in ft/s - j349 appears to have units screwed up
%             bankurfg= 2*SR.(ds).(wds).(rs).alluviumlength(sr)*5280*T ./ sqrt(pi()* T /SR.(ds).(wds).(rs).storagecoefficient(sr)*t).*(1-exp(-1*(2*W)^2 ./ (4*T/SR.(ds).(wds).(rs).storagecoefficient(sr)*t))); %ft2/s
%             bankurfgcum=cumsum(bankurfg); %ft2/s
            

            %j349 bank storage

            ALPHA=(SR.(ds).(wds).(rs).transmissivity(sr)/24.)*rhours/SR.(ds).(wds).(rs).storagecoefficient(sr); %ALPHA as written in J349 (wrong units)

%            T=SR.(ds).(wds).(rs).transmissivity(sr);
%             XL=XL*XLmult(mmm);
%             T=T*Tmult(mmm);
%            ALPHA=(T/24.)*rhours/SR.(ds).(wds).(rs).storagecoefficient(sr);

%            actualT=SR.(ds).(wds).(rs).transmissivity(sr)/(3600*24);
%            actualK=actualT/Dbank*3600*24;  %in ft/day
%            ALPHA=(T)*rhours*3600/SR.(ds).(wds).(rs).storagecoefficient(sr); %if reexpressed correctly as actual T
            
            for NT=1:rsteps
                TIME=NT-.5;
                N=0;
                D=0;
                X1=1;
                %%%%%%%%%%%%%%%%
                % J349 Case 1
                % DUSRF(NT)=-1./sqrt(pi()*ALPHA*TIME);

                %%%%%%%%%%%%%%%%
                % J349 Case 2
                while X1>0.001
                    N=N+1;
                    DD=D;
                    C1=(2*N-1)*pi()/(2.*XL);
                    D=D+exp(-C1^2*ALPHA*TIME);
                    X1=abs(DD-D);
                    DUSRF(NT)=(2./XL)*D;
                    if N>100
                        disp(['Warning: bank urf broke out at NT:' num2str(NT) ' X1:' num2str(X1) ])
                        break
                    end
                end
            end

            %OK - only way could figure out with correct units was to unitize first ordinate and use first ordinate of glover solution to scale
            bankurf=DUSRF/DUSRF(1);
%            bankurf=bankurf*bankurfg(1);
            bankurf=bankurf*2*SR.(ds).(wds).(rs).alluviumlength(sr)*5280*T ./ sqrt(pi()* T /SR.(ds).(wds).(rs).storagecoefficient(sr)*1800); %1800=t(sec) at 0.5hr
            bankurfcum=cumsum(bankurf); %ft2/s

            if urfwrapbacktype>0
%                 %glover based urfs
%                 cburf=bankurfgcum/bankurfgcum(end);
%                 urfwrapids=find(cburf>=urfwrapback);
%                 if isempty(urfwrapids)
%                     urfwrapid=length(bankurf);
%                 else
%                     urfwrapid=urfwrapids(1);  %ie includes first one over limit
%                 end
%                 bankurfg=bankurfg(1:urfwrapid);  %has values rather than unitized
%                 bankurfgcum=bankurfgcum(1:urfwrapid);

               %j349 based urfs 
                cburf=bankurfcum/bankurfcum(end);
                urfwrapids=find(cburf>=urfwrapback);
                if isempty(urfwrapids)
                    urfwrapid=length(bankurf);
                else
                    urfwrapid=urfwrapids(1);  %ie includes first one over limit
                end
                bankurf=bankurf(1:urfwrapid);
                bankurfcum=bankurfcum(1:urfwrapid);
%                 urfwraptot=cburf(urfwrapid);
%                 urfwrapamt=1-urfwraptot;
%                 if urfwrapbacktype==2
%                     bankurf=bankurf(1:urfwrapid)/urfwraptot;
%                 else
%                     bankurf=bankurf(1:urfwrapid)+urfwrapamt/urfwrapid;
%                 end
%                 bankurf=bankurf/sum(bankurf);
            end
           
            SR.(ds).(wds).(rs).bankurf{sr}=bankurf';
            SR.(ds).(wds).(rs).bankurfcum{sr}=bankurfcum'*(rhours*3600); %ft2
%             SR.(ds).(wds).(rs).bankurfg{sr}=bankurfg';
%             SR.(ds).(wds).(rs).bankurfgcum{sr}=bankurfgcum'*(rhours*3600); %ft2
            
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%
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

if readinputfile==1  %not save if readinputfile==2 
    save([datafiledir 'StateTL_data_subreach.mat'],'SR');
end

else
    load([datafiledir 'StateTL_data_subreach.mat']);
        
end


if newnetwork==1

if ~isfolder(gisfile)
%     if isfolder(['StateTLdata\' gisfile])
%         gisfile=[basedir 'StateTLdata\' gisfile];
    if isfolder(['C:\DATA\GIS\' gisfile])
        gisfile=['C:\DATA\GIS\' gisfile];
    else
        gisfile = uigetdir('Select Source_Water_Route_Framework.gdb geodatabase');
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% For nodes with confluence IDs in inputdata (as defined in confshp)
% use these to determine x,y
confshp = readgeotable(gisfile,Layer=conflayer);

mstruct=defaultm('utm');
mstruct.zone='13N';
mstruct=defaultm(mstruct);
grs80props=referenceEllipsoid('grs80'); %for needed parameters appears same as wgs84
mstruct.geoid(1)=grs80props.SemimajorAxis;
mstruct.geoid(2)=grs80props.Eccentricity;

SRloc(1).a=[];
ds='D2';
for wd=SR.(ds).WD
    wds=['WD' num2str(wd)];
    for r=SR.(ds).(wds).R 
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            wdid=SR.(ds).(wds).(rs).wdid{sr};
            dswdid=SR.(ds).(wds).(rs).dswdid{sr};
            confid=SR.(ds).(wds).(rs).confid(sr);
            dsconfid=SR.(ds).(wds).(rs).dsconfid(sr);
            if ~isfield(SRloc,['W' wdid])
                confidid=[];
                if confid~=0
                    confidid=find(confshp.Con_ID==confid);
                    if ~isempty(confidid)
                    utmx=confshp.Shape.X(confidid);
                    utmy=confshp.Shape.Y(confidid);
                    [lat,lon] = minvtran(mstruct,utmx,utmy);
                    SRloc.(['W' wdid]).name=SR.(ds).(wds).(rs).name{sr};
                    SRloc.(['W' wdid]).utmx=utmx;
                    SRloc.(['W' wdid]).utmy=utmy;
                    SRloc.(['W' wdid]).lat=lat;
                    SRloc.(['W' wdid]).lon=lon;
                    SRloc.(['W' wdid]).WD={wds};
                    SRloc.(['W' wdid]).(wds).gnisid=SR.(ds).(wds).(rs).gnisid{sr};
                    else
                        logm=['WARNING: in GIS didnt find confid:' num2str(confid) ' for wdid:' wdid ' ' SR.(ds).(wds).(rs).name{sr}];
                        domessage(logm,logfilename,displaymessage,writemessage)
                    end
                end
                if isempty(confidid)
                    SRloc.(['W' wdid]).name=SR.(ds).(wds).(rs).name{sr};
                    SRloc.(['W' wdid]).utmx=-999;
                    SRloc.(['W' wdid]).utmy=-999;
                    SRloc.(['W' wdid]).lat=-999;
                    SRloc.(['W' wdid]).lon=-999;
                    SRloc.(['W' wdid]).WD={wds};
                    SRloc.(['W' wdid]).(wds).gnisid=SR.(ds).(wds).(rs).gnisid{sr};                    
                end
            elseif ~isfield(SRloc.(['W' wdid]),wds)
                SRloc.(['W' wdid]).WD=[SRloc.(['W' wdid]).WD {wds}];
                SRloc.(['W' wdid]).(wds).gnisid=SR.(ds).(wds).(rs).gnisid{sr};
            end
            if ~isfield(SRloc,['W' dswdid])
                confidid=[];
                if dsconfid~=0
                    confidid=find(confshp.Con_ID==dsconfid);
                    if ~isempty(confidid)
                    utmx=confshp.Shape.X(confidid);
                    utmy=confshp.Shape.Y(confidid);
                    [lat,lon] = minvtran(mstruct,utmx,utmy);
                    SRloc.(['W' dswdid]).name=SR.(ds).(wds).(rs).dsname{sr};
                    SRloc.(['W' dswdid]).utmx=utmx;
                    SRloc.(['W' dswdid]).utmy=utmy;
                    SRloc.(['W' dswdid]).lat=lat;
                    SRloc.(['W' dswdid]).lon=lon;
                    SRloc.(['W' dswdid]).WD={wds};
                    SRloc.(['W' dswdid]).(wds).gnisid=SR.(ds).(wds).(rs).gnisid{sr};                    
                    else
                        logm=['WARNING: in GIS didnt find confid:' num2str(dsconfid) ' for wdid:' dswdid ' ' SR.(ds).(wds).(rs).dsname{sr}];
                        domessage(logm,logfilename,displaymessage,writemessage)
                    end
                end
                if isempty(confidid)
                    SRloc.(['W' dswdid]).name=SR.(ds).(wds).(rs).dsname{sr};
                    SRloc.(['W' dswdid]).utmx=-999;
                    SRloc.(['W' dswdid]).utmy=-999;
                    SRloc.(['W' dswdid]).lat=-999;
                    SRloc.(['W' dswdid]).lon=-999;
                    SRloc.(['W' dswdid]).WD={wds};
                    SRloc.(['W' dswdid]).(wds).gnisid=SR.(ds).(wds).(rs).gnisid{sr};                    
                end
            elseif ~isfield(SRloc.(['W' dswdid]),wds)
                SRloc.(['W' dswdid]).WD=[SRloc.(['W' dswdid]).WD {wds}];
                SRloc.(['W' dswdid]).(wds).gnisid=SR.(ds).(wds).(rs).gnisid{sr};
            end
       end
    end
end

SRloc = rmfield(SRloc,'a');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Use HB REST to pull utm and lat/lon coordinates for wdids in HB
wdids=fieldnames(SRloc);
for i=1:length(wdids)
    wwdid=wdids{i};
    if SRloc.(wwdid).utmx==-999
        wdid=wwdid(2:end);
        try
            wdiddata=webread(structureurl,'format','json','fields',[{'utmX'},{'utmY'},{'latdecdeg'},{'longdecdeg'}],'wdid',wdid,'apiKey',apikey);
            SRloc.(wwdid).utmx=wdiddata.ResultList.utmX;
            SRloc.(wwdid).utmy=wdiddata.ResultList.utmY;
            SRloc.(wwdid).lat=wdiddata.ResultList.latdecdeg;
            SRloc.(wwdid).lon=wdiddata.ResultList.longdecdeg;
        catch  %at a minimum will occur if fake wdid
            logm=['WARNING: no or missing location for wdid:' wdid ' ' SRloc.(wwdid).name];
            domessage(logm,logfilename,displaymessage,writemessage)
        end
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Determine channel length, alluvium length, portion
% using source water framework river lines
rivshp = readgeotable(gisfile,Layer=rivlayer);
rivshptab = geotable2table(rivshp,["utmx" "utmy"]);  %this converts map maplineshape objects into linestring texts

gnisidprev='';
for i=1:length(wdids)
    wwdid=wdids{i};
    wdss=SRloc.(wwdid).WD;
    for j=1:length(wdss)
        wds=wdss{j};
        gnisid=SRloc.(wwdid).(wds).gnisid;
        utmx=SRloc.(wwdid).utmx;
        utmy=SRloc.(wwdid).utmy;
        if ~strcmp(gnisid,gnisidprev)
            gnisidid=find(rivshptab.GNIS_ID==gnisid);
            rivutmx=rivshptab.utmx{gnisidid};
            rivutmy=rivshptab.utmy{gnisidid};
            rivdist=sqrt((rivutmx(2:end)-rivutmx(1:end-1)).^2+(rivutmy(2:end)-rivutmy(1:end-1)).^2);
            rivdist=[0 rivdist];
            rivdist=cumsum(rivdist)/0.3048/5280; %distance in miles
            gnisidprev=gnisid;
        end
        ptdist=sqrt((rivutmx-utmx).^2+(rivutmy-utmy).^2);
        [mindist,mindistid]=min(ptdist);
        SRloc.(wwdid).(wds).strmile=rivdist(mindistid);
    end
end


for wd=SR.(ds).WD
    wds=['WD' num2str(wd)];
    for r=SR.(ds).(wds).R 
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            wdid=SR.(ds).(wds).(rs).wdid{sr};
            wwdid=['W' wdid];
            dswdid=SR.(ds).(wds).(rs).dswdid{sr};
            dswwdid=['W' dswdid];
            SRloc.(ds).(wds).(rs).usutmx(sr)=SRloc.(wwdid).utmx;
            SRloc.(ds).(wds).(rs).usutmy(sr)=SRloc.(wwdid).utmy;
            SRloc.(ds).(wds).(rs).uslat(sr)=SRloc.(wwdid).lat;
            SRloc.(ds).(wds).(rs).uslon(sr)=SRloc.(wwdid).lon;

            SRloc.(ds).(wds).(rs).dsutmx(sr)=SRloc.(dswwdid).utmx;
            SRloc.(ds).(wds).(rs).dsutmy(sr)=SRloc.(dswwdid).utmy;
            SRloc.(ds).(wds).(rs).dslat(sr)=SRloc.(dswwdid).lat;
            SRloc.(ds).(wds).(rs).dslon(sr)=SRloc.(dswwdid).lon;

            if SRloc.(wwdid).utmx==-999
                SRloc.(ds).(wds).(rs).utmx(sr)=SRloc.(dswwdid).utmx;
                SRloc.(ds).(wds).(rs).utmy(sr)=SRloc.(dswwdid).utmy;
                SRloc.(ds).(wds).(rs).lat(sr)=SRloc.(dswwdid).lat;
                SRloc.(ds).(wds).(rs).lon(sr)=SRloc.(dswwdid).lon;
            elseif SRloc.(dswwdid).utmx==-999
                SRloc.(ds).(wds).(rs).utmx(sr)=SRloc.(wwdid).utmx;
                SRloc.(ds).(wds).(rs).utmy(sr)=SRloc.(wwdid).utmy;
                SRloc.(ds).(wds).(rs).lat(sr)=SRloc.(wwdid).lat;
                SRloc.(ds).(wds).(rs).lon(sr)=SRloc.(wwdid).lon;
            else
                SRloc.(ds).(wds).(rs).utmx(sr)=(SRloc.(wwdid).utmx+SRloc.(dswwdid).utmx)/2;
                SRloc.(ds).(wds).(rs).utmy(sr)=(SRloc.(wwdid).utmy+SRloc.(dswwdid).utmy)/2;
                SRloc.(ds).(wds).(rs).lat(sr)=(SRloc.(wwdid).lat+SRloc.(dswwdid).lat)/2;
                SRloc.(ds).(wds).(rs).lon(sr)=(SRloc.(wwdid).lon+SRloc.(dswwdid).lon)/2;
            end

            SRloc.(ds).(wds).(rs).channellength(sr)=SRloc.(wwdid).(wds).strmile-SRloc.(dswwdid).(wds).strmile;
            SRloc.(ds).(wds).(rs).sralluviumlength(sr)=sqrt((SRloc.(wwdid).utmx-SRloc.(dswwdid).utmx).^2+(SRloc.(wwdid).utmy-SRloc.(dswwdid).utmy).^2)/0.3048/5280;
        end
        wdid1=SR.(ds).(wds).(rs).wdid{1};
        wwdid1=['W' wdid1];
        SRloc.(ds).(wds).(rs).reachalluviumlength=sqrt((SRloc.(wwdid1).utmx-SRloc.(dswwdid).utmx).^2+(SRloc.(wwdid1).utmy-SRloc.(dswwdid).utmy).^2);
    end
end

    save([datafiledir 'StateTL_data_networklocs.mat'],'SRloc');
else
    load([datafiledir 'StateTL_data_networklocs.mat']);
end



%%%%%%%%%%%%%%%%%%
% Old Evaporation data - original single curve data for wd17
if evapnew~=1
    if readevap==1
        infonum=readmatrix([inputfilename],'Sheet','evap');
        [infonumrow infonumcol]=size(infonum);        
        for wd=SR.(ds).WD
            wds=['WD' num2str(wd)];
            evap.(ds).(wds).evap=infonum(:,end);
        end  
        save([datafiledir 'StateTL_data_evap.mat'],'evap');
    else
        load([datafiledir 'StateTL_data_evap.mat']);
    end
    
end

%%%%%%%%%%%%%%%%%%%%%%%%
% stage discharge data
% this needs to be reworked to have for seperate reacheds (ie in wd67)
% also reading here div record corrections
%    explicit corrections/adjustments to hydrobase diversion records



if readstagedischarge==1
    % stagedischarge
    SDmat=readmatrix([inputfilename],'Sheet','stagedischarge');
    [SDmatnumrow SDmatnumcol]=size(SDmat);
    
    clear stagedischarge
    stagedischarge.(ds).a=1;
    for i=1:SDmatnumrow
        if ~isfield(stagedischarge.(ds),'stagedischarge') || ~isfield(stagedischarge.(ds).stagedischarge,['SD' num2str(SDmat(i,1))])
            stagedischarge.(ds).stagedischarge.(['SD' num2str(SDmat(i,1))])=SDmat(i,2:3);
        else
            stagedischarge.(ds).stagedischarge.(['SD' num2str(SDmat(i,1))])=[stagedischarge.(ds).stagedischarge.(['SD' num2str(SDmat(i,1))]);SDmat(i,2:3)];
        end
    end
    %extrapolate SD curves just in case
    SDmax=1000000;
    SDfields=fieldnames(stagedischarge.(ds).stagedischarge);
    for i=1:length(SDfields)
        SDv=stagedischarge.(ds).stagedischarge.(SDfields{i});
        SDlen=length(SDv(:,1));
        SDv(SDlen+1,1)=SDv(SDlen,1)+(SDv(SDlen,1)-SDv(SDlen-1,1))/(SDv(SDlen,2)-SDv(SDlen-1,2))*(SDmax-SDv(SDlen,2));
        SDv(SDlen+1,2)=SDmax;
        stagedischarge.(ds).stagedischarge.(SDfields{i})=SDv;
    end
    stagedischarge.(ds)=rmfield(stagedischarge.(ds),'a');
    SR.(ds).stagedischarge=stagedischarge.(ds).stagedischarge;
    
    %loss percents between wdids
    LPmat=readcell([inputfilename],'Sheet','loss');
    [LPmatrow LPmatcol]=size(LPmat);
    LPmatheaderrow=1;

    for i=1:LPmatcol
        if 1==2
        elseif strcmpi(LPmat{LPmatheaderrow,i},'WDID'); LPcol.wdid=i;
        elseif strcmpi(LPmat{LPmatheaderrow,i},'DSWDID'); LPcol.dswdid=i;
        elseif strcmpi(LPmat{LPmatheaderrow,i},'Name'); LPcol.name=i;
        elseif strcmpi(LPmat{LPmatheaderrow,i},'LossPercent'); LPcol.losspercent=i;
        end
    end
    k=0;
    for i=LPmatheaderrow+1:LPmatrow
        if ~ismissing(LPmat{i,LPcol.wdid})
            k=k+1;
            wdidloss.(ds).wdid{k}=num2str(LPmat{i,LPcol.wdid});
            wdidloss.(ds).dswdid{k}=num2str(LPmat{i,LPcol.dswdid});
            wdidloss.(ds).name{k}=num2str(LPmat{i,LPcol.name});
            wdidloss.(ds).losspercent{k}=num2str(LPmat{i,LPcol.losspercent});
        end
    end

    %diversion record correct
    DCmat=readcell([inputfilename],'Sheet','divcorrect');
    [DCmatrow DCmatcol]=size(DCmat);
    DCmatheaderrow=1;

    for i=1:DCmatcol
        if 1==2
        elseif strcmpi(DCmat{DCmatheaderrow,i},'WDID'); DCcol.wdid=i;
        elseif strcmpi(DCmat{DCmatheaderrow,i},'WCnum'); DCcol.wcnum=i;
        elseif strcmpi(DCmat{DCmatheaderrow,i},'WCidentifier'); DCcol.wcid=i;
        elseif strcmpi(DCmat{DCmatheaderrow,i},'start'); DCcol.start=i;
        elseif strcmpi(DCmat{DCmatheaderrow,i},'end'); DCcol.end=i;
        elseif strcmpi(DCmat{DCmatheaderrow,i},'newamt'); DCcol.newamt=i;
        elseif strcmpi(DCmat{DCmatheaderrow,i},'comment'); DCcol.comment=i;
        end
    end
    k=0;
    for i=DCmatheaderrow+1:DCmatrow
        if ~ismissing(DCmat{i,DCcol.wdid})
            k=k+1;
            divcorrect.(ds).wdid{k}=num2str(DCmat{i,DCcol.wdid});
            divcorrect.(ds).wcnum{k}=num2str(DCmat{i,DCcol.wcnum});
            divcorrect.(ds).wcid{k}=num2str(DCmat{i,DCcol.wcid});
            divcorrect.(ds).comment{k}=DCmat{i,DCcol.comment};
            divcorrect.(ds).start(k)=datenum(DCmat{i,DCcol.start});
            divcorrect.(ds).end(k)=datenum(DCmat{i,DCcol.end});
            divcorrect.(ds).newamt(k)=DCmat{i,DCcol.newamt};
        end
    end


    %gage/station record correct
    GCmat=readcell([inputfilename],'Sheet','gagecorrect');
    [GCmatrow GCmatcol]=size(GCmat);
    GCmatheaderrow=1;

    for i=1:GCmatcol
        if 1==2
        elseif strcmpi(GCmat{GCmatheaderrow,i},'Abbrev'); GCcol.abbrev=i;
        elseif strcmpi(GCmat{GCmatheaderrow,i},'start'); GCcol.start=i;
        elseif strcmpi(GCmat{GCmatheaderrow,i},'end'); GCcol.end=i;
        elseif strcmpi(GCmat{GCmatheaderrow,i},'newamt'); GCcol.newamt=i;
        elseif strcmpi(GCmat{GCmatheaderrow,i},'comment'); GCcol.comment=i;
        end
    end
    k=0;
    for i=GCmatheaderrow+1:GCmatrow   %need to add in ability to have 999 in gstart or gend..
        if ~ismissing(GCmat{i,GCcol.abbrev})
            k=k+1;
            gagecorrect.(ds).station{k}=num2str(GCmat{i,GCcol.abbrev});
            gagecorrect.(ds).comment{k}=GCmat{i,GCcol.comment};
            gstart=GCmat{i,GCcol.start};           
            sids=find(gstart=='/');
            cids=find(gstart==':');
            gagecorrect.(ds).year(k)=str2double(gstart(sids(2)+1:cids(1)-1));
            gagecorrect.(ds).start{k}=[gstart(sids(2)+1:cids(1)-1) '-' gstart(1:sids(1)-1) '-' gstart(sids(1)+1:sids(2)-1) ' ' gstart(cids(1)+1:end) ':00:00'];
            gend=GCmat{i,GCcol.end};
            sids=find(gend=='/');
            cids=find(gend==':');
            gagecorrect.(ds).end{k}=[gend(sids(2)+1:cids(1)-1) '-' gend(1:sids(1)-1) '-' gend(sids(1)+1:sids(2)-1) ' ' gend(cids(1)+1:end) ':00:00'];
            gagecorrect.(ds).newamt(k)=GCmat{i,GCcol.newamt};
        end
    end
    save([datafiledir 'StateTL_data_stagedis.mat'],'stagedischarge','wdidloss','divcorrect','gagecorrect');
    clear LP* DC* GC*
else
    load([datafiledir 'StateTL_data_stagedis.mat']);
    SR.(ds).stagedischarge=stagedischarge.(ds).stagedischarge;
end




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
% Evaporation
% NEW - using gridded statewide ET dataset
% associating gridpoint with mean of us and dswdid locations for a subreach
% basing evap as 1.05 * ETos
% using HB REST to get utm and lat/lon coordinates
% eventually will replace use of ET dataset file with pull of ET data from HB
% and also add in current years data...

if (newnetwork==1 && evapnew==1) || (readevap==1 && evapnew==1)

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
load([ETfilename]);
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
            utmx=SRloc.(ds).(wds).(rs).utmx(sr);
            utmy=SRloc.(ds).(wds).(rs).utmy(sr);
            lat=SRloc.(ds).(wds).(rs).lat(sr);
            lon=SRloc.(ds).(wds).(rs).lon(sr);
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

save([datafiledir 'StateTL_data_evap.mat'],'evap');

end




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Evaporation - Attach or rettach to SR structure
% using whole year in anticipation of possible calendar year orientation
% if newnetwork then also readevap but not viceversa

if readinputfile>0 || readevap==1 || newnetwork==1
    if readevap~=1
        load([datafiledir 'StateTL_data_evap.mat']);
    end
    if evapnew~=1
        for wd=SR.(ds).WD
            wds=['WD' num2str(wd)];
            for r=SR.(ds).(wds).R
                rs=['R' num2str(r)];
                for sr=SR.(ds).(wds).(rs).SR
                    SR.(ds).(wds).(rs).evapday(:,sr)=evap.(ds).(wds).evap;
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
                    %SR.(ds).(wds).(rs).evapday=evap.(ds).(wds).(rs).ETosavg.*SR.(ds).(wds).(rs).evapfactor*etostoevap*convertevap;
                    SR.(ds).(wds).(rs).evapday=evap.(ds).(wds).(rs).ETosavg*etostoevap*convertevap;
                    %SR.(ds).(wds).(rs).evapmin=evap.(ds).(wds).(rs).ETosmin*etostoevap*convertevap;
                    %SR.(ds).(wds).(rs).evapmax=evap.(ds).(wds).(rs).ETosmax*etostoevap*convertevap;
                else
                    SR.(ds).(wds).(rs).evapday=evap.(ds).(wds).(rs).ETos(yearids(1):yearids(2),:)*etostoevap*convertevap;
                end
            end
        end
        
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% network locations - Attach or rettach  to SR structure
% could potentially do with evaporation below but possibility of updating evap while not network

if newnetwork==1 || readinputfile>0

    for wd=SR.(ds).WD
        wds=['WD' num2str(wd)];
        for r=SR.(ds).(wds).R
            rs=['R' num2str(r)];
            alluviumlengthchanged=0;
            for sr=SR.(ds).(wds).(rs).SR
                if SR.(ds).(wds).(rs).channellength(sr)==0
                    SR.(ds).(wds).(rs).channellength(sr)=SRloc.(ds).(wds).(rs).channellength(sr);
                end
                if SR.(ds).(wds).(rs).alluviumlength(sr)==0
                    SR.(ds).(wds).(rs).sralluviumlength(sr)=SRloc.(ds).(wds).(rs).sralluviumlength(sr);
                else
                    SR.(ds).(wds).(rs).sralluviumlength(sr)=SR.(ds).(wds).(rs).alluviumlength(sr);
                    alluviumlengthchanged=1;
                end
                if SR.(ds).(wds).(rs).channellength(sr)<=0
                    logm=['WARNING: channellength for ' ds ' ' wds ' ' rs ' ' num2str(sr) ' calced: ' num2str(SR.(ds).(wds).(rs).channellength(sr)) ' reset to 0.01 mile'];
                    domessage(logm,logfilename,displaymessage,writemessage)
                    SR.(ds).(wds).(rs).channellength(sr)=0.01;
                end
                if SR.(ds).(wds).(rs).sralluviumlength(sr)<=0  %need to set alluviumlengthchanged=1??
                    logm=['WARNING: sralluviumlength for ' ds ' ' wds ' ' rs ' ' num2str(sr) ' calced: ' num2str(SR.(ds).(wds).(rs).alluviumlength(sr)) ' reset to 0.01 mile'];
                    domessage(logm,logfilename,displaymessage,writemessage)
                    SR.(ds).(wds).(rs).sralluviumlength(sr)=0.01;
                end
            end

            SRloc.(ds).(wds).(rs).reachportion=SR.(ds).(wds).(rs).channellength/sum(SR.(ds).(wds).(rs).channellength);
            reachportionchanged=0;
            for sr=SR.(ds).(wds).(rs).SR
                if SR.(ds).(wds).(rs).reachportion(sr)==0
                    SR.(ds).(wds).(rs).reachportion(sr)=SRloc.(ds).(wds).(rs).reachportion(sr);
                else
                    reachportionchanged=1;
                end
            end
            if reachportionchanged==1  %if user provides some but not all reaches may override so sum equals 1
                SR.(ds).(wds).(rs).reachportion=SR.(ds).(wds).(rs).reachportion/sum(SR.(ds).(wds).(rs).reachportion);
            end
            if alluviumlengthchanged==1 %if user provides subreach alluvium length than use sralluvium lenghts; otherwise scale alluvium lenghts as srlen/sum(srlen)*reachlen
                SR.(ds).(wds).(rs).alluviumlength=SR.(ds).(wds).(rs).sralluviumlength;
            else
                SR.(ds).(wds).(rs).alluviumlength=SR.(ds).(wds).(rs).sralluviumlength/sum(SR.(ds).(wds).(rs).sralluviumlength)*SRloc.(ds).(wds).(rs).reachalluviumlength/0.3048/5280;
            end
            %new - using losspercent in percent per mile but converting here to percent
            SR.(ds).(wds).(rs).losspercent=SR.(ds).(wds).(rs).losspercent.*SR.(ds).(wds).(rs).channellength;

            SR.(ds).(wds).(rs).utmx=SRloc.(ds).(wds).(rs).utmx;
            SR.(ds).(wds).(rs).utmy=SRloc.(ds).(wds).(rs).utmy;
            SR.(ds).(wds).(rs).lat=SRloc.(ds).(wds).(rs).lat;
            SR.(ds).(wds).(rs).lon=SRloc.(ds).(wds).(rs).lon;
%             % at this point below only potentially needed for internal visualization
%             SR.(ds).(wds).(rs).usutmx=SRloc.(ds).(wds).(rs).usutmx;
%             SR.(ds).(wds).(rs).usutmy=SRloc.(ds).(wds).(rs).usutmy;
%             SR.(ds).(wds).(rs).uslat=SRloc.(ds).(wds).(rs).uslat;
%             SR.(ds).(wds).(rs).uslon=SRloc.(ds).(wds).(rs).uslon;
%             SR.(ds).(wds).(rs).dsutmx=SRloc.(ds).(wds).(rs).dsutmx;
%             SR.(ds).(wds).(rs).dsutmy=SRloc.(ds).(wds).(rs).dsutmy;
%             SR.(ds).(wds).(rs).dslat=SRloc.(ds).(wds).(rs).dslat;
%             SR.(ds).(wds).(rs).dslon=SRloc.(ds).(wds).(rs).dslon;
        end
    end

end


    if readinputfile<2  %not save if readinputfile==2 (ie for calibration), saves both reattached evap and network
        save([datafiledir 'StateTL_data_subreach.mat'],'SR');
    end

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% READ GAGE AND TELEMETRY BASED FLOW DATA
% much of this needs to be improved for larger application; particularly handling of dates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
reststarttime=[];


if pullstationdata==1
    if pulllongtermstationdata==0
        load([datafiledir 'StateTL_data_qnode.mat']); %better way to do this?
        for wd=WDlist
            wds=['WD' num2str(wd)];
            for r=SR.(ds).(wds).R
                rs=['R' num2str(r)];
                Station.(ds).(wds).(rs)=rmfield(Station.(ds).(wds).(rs),{'Qmeas','Qmeasflag','modifieddate','Qqc','Qqcflag','Qfill','Qfillflag','Qdaily','Qstatdaily','Qdivdaily'});
            end
        end
    else 
        clear Station
    end
    Station.date.yearstart=yearstart;
    Station.date.datestart=datestart;
    Station.date.dateend=dateend;
    Station.date.rdates=rdates;
    Station.date.datestid=datestid;
    Station.date.dateendid=dateendid;
    Station.date.rdatesstr=rdatesstr;
    Station.date.rdatesday=rdatesday;
    Station.date.rjulien=rjulien;
    Station.date.avgdates=avgdates;
    
    
    for wd=WDlist
        wds=['WD' num2str(wd)];
        Station.date.(ds).(wds).modified=0;
    end

    if multiyrstation~=1
        multiyrs=yearstart;
    else
        %putting yearstart at beginning of multiyr list
        firstyrid=find(multiyrs==yearstart);
        if isempty(firstyrid)
            logm=['WARNING: muliyr option chosen but current year not within multiyr set: adding yearstart to end of multiyr list'];
            domessage(logm,logfilename,displaymessage,writemessage)
        else
            multiyrs(firstyrid)=[];
        end
        multiyrs=[multiyrs,yearstart];
        Station.date.multiyrs=multiyrs;
        
        for myr=multiyrs
            if fullyear==1  %whole calendar year starting on Jan1
                datestart=datenum(myr,1,1);
                spinupdays=spinupdaysfullyear;
                rundays=datenum(myr,12,31)-datestart+1;
                rdays=rundays+spinupdays+spindowndays;  %if doing whole year
            else
                datestart=datenum(myr,1,rundayjulien);
                rundays=max(1,rundays);    %rundays is days without spinup, will override zero to one
                rundays=min(366,rundays);  %max of a year as j349 dimensions set at 9000
                spinupdays=min(spinupdayspartialyear,375-rundays-spindowndays);
                rdays=rundays+spinupdays+spindowndays;  %rdays is with spinup
            end
            runsteps=rundays*24/rhours;
            rsteps=rdays*24/rhours;
            datestid=spinupdays*24/rhours+1;
            dateendid=datestid+runsteps-1;
            rundates=[datestart:rhours/24:datestart+rundays-rhours/24]';
            rdates=[datestart*ones(spinupdays*24/rhours,1);rundates;rundates(end)*ones(spindowndays*24/rhours,1)];
            [ryear,rmonth,rundays,rhour] = datevec(rdates);
            rdatesstr=cellstr(datestr(rdates,31));
            rdatesday=floor(rdates);
            rjulien=rdatesday-(datenum(ryear,1,1)-1);
            dateend=datestart+(rdays-spinupdays)-1;
            datedays=[datestart:dateend];
            myrstr=['Y' num2str(myr)];
            Station.(myrstr).date.datestart=datestart;
            Station.(myrstr).date.dateend=dateend;
            Station.(myrstr).date.runsteps=runsteps;
            Station.(myrstr).date.rsteps=rsteps;
            Station.(myrstr).date.rdates=rdates;
            Station.(myrstr).date.datestid=datestid;
            Station.(myrstr).date.dateendid=dateendid;
            Station.(myrstr).date.rdatesstr=rdatesstr;
            Station.(myrstr).date.rdatesday=rdatesday;
            Station.(myrstr).date.rjulien=rjulien;
            Station.(myrstr).date.datedays=datedays;
            for wd=WDlist
                wds=['WD' num2str(wd)];
                Station.(myrstr).date.(ds).(wds).modified=0;
            end
        end
    end
else
    load([datafiledir 'StateTL_data_qnode.mat']);
end

if pullstationdata>=1

reststarttime=now;
logm=['Start pulling data from HBREST at: '  datestr(reststarttime)];
domessage(logm,logfilename,displaymessage,writemessage)

%probabaly in operations may not want to worry about any multiyr data if pullstationdata==2
for myr=multiyrs

    %multiyear - setting dates for next loop
    if multiyrstation==1
        myrstr=['Y' num2str(myr)];
        datestart=Station.(myrstr).date.datestart;
        dateend=Station.(myrstr).date.dateend;
        runsteps=Station.(myrstr).date.runsteps;
        rsteps=Station.(myrstr).date.rsteps;
        rdates=Station.(myrstr).date.rdates;
        datestid=Station.(myrstr).date.datestid;
        dateendid=Station.(myrstr).date.dateendid;
        rdatesstr=Station.(myrstr).date.rdatesstr;
        rdatesday=Station.(myrstr).date.rdatesday;
        rjulien=Station.(myrstr).date.rjulien;
        datedays=Station.(myrstr).date.datedays;
        logm=['Pulling/processing multiyear hourly data for year: '  num2str(myr)];
        domessage(logm,logfilename,displaymessage,writemessage)
    end

    blankvalues=-999*ones(runsteps,1);

for wd=WDlist
    wds=['WD' num2str(wd)];
    if multiyrstation==1
        modified=Station.(myrstr).date.(ds).(wds).modified;
    else
        modified=Station.date.(ds).(wds).modified;
    end
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
            if multiyrstation==1
                if pullstationdata==2
                    Station.(ds).(wds).(rs).Qmeas=Station.(myrstr).(ds).(wds).(rs).Qmeas;
                    Station.(ds).(wds).(rs).modifieddate=Station.(myrstr).(ds).(wds).(rs).modifieddate;
                    Station.(ds).(wds).(rs).Qmeasflag=Station.(myrstr).(ds).(wds).(rs).Qmeasflag;
                    Station.(ds).(wds).(rs).Qdaily=[];
                    Station.(ds).(wds).(rs).Qstatdaily=[];
                    Station.(ds).(wds).(rs).Qdivdaily=[];
                    Station.(ds).(wds).(rs).Qqc=[];
                    Station.(ds).(wds).(rs).Qqcflag=[];
                    Station.(ds).(wds).(rs).Qfill=Station.(myrstr).(ds).(wds).(rs).Qfill;
                    Station.(ds).(wds).(rs).Qfillflag=Station.(myrstr).(ds).(wds).(rs).Qfillflag;
                elseif myr~=multiyrs(1)  %only need to clear on second pass once variable exists
                    Station.(ds).(wds).(rs).Qmeas=[];
                    Station.(ds).(wds).(rs).modifieddate=[];
                    Station.(ds).(wds).(rs).Qmeasflag=[];
                    Station.(ds).(wds).(rs).Qdaily=[];
                    Station.(ds).(wds).(rs).Qstatdaily=[];
                    Station.(ds).(wds).(rs).Qdivdaily=[];
                    Station.(ds).(wds).(rs).Qqc=[];
                    Station.(ds).(wds).(rs).Qqcflag=[];
                    Station.(ds).(wds).(rs).Qfill=[];
                    Station.(ds).(wds).(rs).Qfillflag=[];
                end
            end

            for sr=SR.(ds).(wds).(rs).SR
                if strcmp(SR.(ds).(wds).(rs).station{1,sr},'NaN') | strcmp(SR.(ds).(wds).(rs).station{1,sr},'none')  %if non-telemetry station
%                    SR.(ds).(wds).(rs).Qnode(:,sr,1)=SR.(ds).(wds).(rs).(flow)(1,sr)*ones(rsteps,1);
                    Station.(ds).(wds).(rs).Qmeas(:,sr)=blankvalues;
                    Station.(ds).(wds).(rs).Qmeasflag(:,sr)=blankvalues+999;  %hr flag 0 = missing
                    Station.(ds).(wds).(rs).modifieddate(:,sr)=blankvalues;
                else
                    station=SR.(ds).(wds).(rs).station{1,sr};
                    parameter=SR.(ds).(wds).(rs).parameter{1,sr};
                    if pullstationdata==1
                        Station.(ds).(wds).(rs).Qmeas(:,sr)=blankvalues;
                        Station.(ds).(wds).(rs).modifieddate(:,sr)=blankvalues;
                        Station.(ds).(wds).(rs).Qmeasflag(:,sr)=blankvalues+999;  %hr flag 0 = missing
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
                            measdateid=find(strcmp(rdatesstr(datestid:dateendid,:),measdatestr));
                            % measunit{i}=gagedata.ResultList(i).measUnit; %check?
                            if ~isempty(measdateid)
                                Station.(ds).(wds).(rs).Qmeas(measdateid,sr)=gagedata.ResultList(i).measValue;
                                Station.(ds).(wds).(rs).Qmeasflag(measdateid,sr)=1; %hr flag 1 = hourly telemetry 
                                modifieddatestr=gagedata.ResultList(i).modified;
%                                 modifieddatestr(11)=' ';
%                                 modifieddate=datenum(modifieddatestr,31);
                                modifieddate=str2double([modifieddatestr(1:4) modifieddatestr(6:7) modifieddatestr(9:10) modifieddatestr(12:13) modifieddatestr(15:16)]);
                                Station.(ds).(wds).(rs).modifieddate(measdateid,sr)=modifieddate;
                                maxmodified=max(maxmodified,modifieddate);  %do as array below?
                            else
                                logm=['WARNING: telemetry datevalue outside of model daterange for station: ' station ' telemetry datestr:' measdatestr ' ignoring datapoint'];
                                domessage(logm,logfilename,displaymessage,writemessage)      
                            end
                            
                        end
                    end

                % Apply gage corrections
                % if wdid in table shows a gage correction
                if sum(strcmp(gagecorrect.(ds).station,station))>0
                    gagecorid=find(strcmp(gagecorrect.(ds).station,station));
                    for i=1:length(gagecorid)
                        if gagecorrect.(ds).year(gagecorid(i))==myr
                        if strcmp(gagecorrect.(ds).start{gagecorid(i)},'999')
                            startdateid=1;
                        else
                            startdateid=find(strcmp(rdatesstr(datestid:dateendid,:),gagecorrect.(ds).start{gagecorid(i)}));
                        end
                        if strcmp(gagecorrect.(ds).end{gagecorid(i)}==999,'999')
                            enddateid=runsteps;
                        else
                            enddateid=find(strcmp(rdatesstr(datestid:dateendid,:),gagecorrect.(ds).end{gagecorid(i)}));
                        end
                        Station.(ds).(wds).(rs).Qmeas(startdateid:enddateid,sr)=gagecorrect.(ds).newamt(gagecorid(i));
                        Station.(ds).(wds).(rs).Qmeasflag(startdateid:enddateid,sr)=8;  %flag 8 = record correction value
                        logm=['Correction: correcting station ' station ' from: ' datestr(gagecorrect.(ds).start(gagecorid(i))) ' to: ' datestr(gagecorrect.(ds).end(gagecorid(i))) ' with amt: ' num2str(gagecorrect.(ds).newamt(gagecorid(i)))];
                        domessage(logm,logfilename,displaymessage,writemessage)
                        end
                    end
                end


                end
            end
        else
            % SR.(ds).(wds).(rs).Qnode(:,:,1)=SR.(ds).(wds).(rs).(flow)(1,:).*ones(rsteps,length(SR.(ds).(wds).(rs).SR));
            Station.(ds).(wds).(rs).Qmeas(:,sr)=blankvalues;
            Station.(ds).(wds).(rs).modifieddate(:,sr)=blankvalues;
            Station.(ds).(wds).(rs).Qmeasflag(:,sr)=blankvalues+999;  %hr flag 0 = blank
        end
    end

    if multiyrstation==1
        Station.(myrstr).date.(ds).(wds).modified=maxmodified;
    else
        Station.date.(ds).(wds).modified=maxmodified;
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% read of daily values from both surfacewater and diversion record URLs
% first use collecting over long term to establish averages for filling
% but also now using to QC hourly and for record where no telemetry (ie use div record)

if pulllongtermstationdata==1
    logm=['Pulling long term station data'];
    domessage(logm,logfilename,displaymessage,writemessage)
    if pullstationdata==1
    for wd=WDlist
        wds=['WD' num2str(wd)];
        Station.date.(ds).(wds).avgmodified=0;
    end
    end
    
    avgdatesstr=cellstr(datestr(avgdates,31));
    blankvaluesday=-999*ones(length(avgdates),1);
    avgdatesvec=datevec(avgdates);
    yearleapvec=datevec([datenum(2000,1,1):datenum(2000,12,31)]);
    yearleapvec=yearleapvec(:,2:3);
    avgyears=(avgstartyear:nowvec(1));
    lastnovid=find(avgdates==datenum(nowvec(1)-1,11,1));

    k=0;
    for i=[avgstartyear:nowvec(1)]
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
                if pullstationdata==1
                    Station.(ds).(wds).(rs).Qdaylong(:,sr)=blankvaluesday;
                    Station.(ds).(wds).(rs).Qstatdaylong(:,sr)=blankvaluesday;
                    Station.(ds).(wds).(rs).Qdivdaylong(:,sr)=blankvaluesday;
                    Station.(ds).(wds).(rs).modifieddatelong(:,sr)=blankvaluesday;
                    Station.(ds).(wds).(rs).Qdaylongflag(:,sr)=blankvaluesday+999;  %day flag 0 = blank/missing
                end

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % first - REST read of published station data (or telemetry data if none) for telemetry based stations
                if ~strcmp(SR.(ds).(wds).(rs).station{1,sr},'NaN') && ~strcmp(SR.(ds).(wds).(rs).station{1,sr},'none')  %if telemetry station
                    station=SR.(ds).(wds).(rs).station{1,sr};
                    parameter=SR.(ds).(wds).(rs).parameter{1,sr};
                    RESTworked=0;
                    try
                        logm=['HBREST: reading daily surfacewater records from ' station ' from:' datestr(avgdates(1),21) ' to:' datestr(avgdates(end),21) ' and modified: ' modifiedstr(1:10) ' for long term averages and for data QC'];
                        domessage(logm,logfilename,displaymessage,writemessage)
                        try
                            gagedata=webread(surfacewaterdayurl,'format','json','abbrev',station,'min-measDate',datestr(avgdates(1),23),'max-measDate',datestr(avgdates(end),23),'min-modified',modifiedstr(1:10),weboptions('Timeout',60),'apiKey',apikey);
                        catch
                            logm=['HBREST: couldt read long term surfacewater based records, trying telemetry based records for ' station ' '];
                            domessage(logm,logfilename,displaymessage,writemessage)
                            gagedata=webread(telemetrydayurl,'format','json','abbrev',station,'parameter',parameter,'startDate',datestr(avgdates(1),21),'endDate',datestr(avgdates(end),21),'includeThirdParty','true','modified',modifiedstr,weboptions('Timeout',60),'apiKey',apikey);
                        end
                        RESTworked=1;
                    %catch ME
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
                                    Station.(ds).(wds).(rs).Qstatdaylong(measdateid,sr)=gagedata.ResultList(i).value;  %surfacewater
                                    Station.(ds).(wds).(rs).Qdaylong(measdateid,sr)=gagedata.ResultList(i).value;  %surfacewater
                                    Station.(ds).(wds).(rs).Qdaylongflag(measdateid,sr)=3+i/100000;  %day flag 3=surfacewater day
                                else
                                    Station.(ds).(wds).(rs).Qstatdaylong(measdateid,sr)=gagedata.ResultList(i).measValue;  %telemetry
                                    Station.(ds).(wds).(rs).Qdaylong(measdateid,sr)=gagedata.ResultList(i).measValue;  %telemetry
                                    Station.(ds).(wds).(rs).Qdaylongflag(measdateid,sr)=2+i/100000;  %day flag 2=telemetry day
                                end
                                modifieddatestr=gagedata.ResultList(i).modified;
%                                 modifieddatestr(11)=' ';
%                                 modifieddate=datenum(modifieddatestr,31);
                                modifieddate=str2double([modifieddatestr(1:4) modifieddatestr(6:7) modifieddatestr(9:10) modifieddatestr(12:13) modifieddatestr(15:16)]);
                                Station.(ds).(wds).(rs).modifieddatelong(measdateid,sr)=modifieddate;
                                maxmodified=max(maxmodified,modifieddate);  %do as array below?
                            else
                                logm=['WARNING: telemetry datevalue outside of model daterange for station: ' station ' telemetry datestr:' measdatestr ' ignoring datapoint'];
                                domessage(logm,logfilename,displaymessage,writemessage)      
                            end
                            
                        end
                    end
                end


                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % second - REST read of published diversion data for diversion and release structures
                % currently - if gage type=0, could also be top reservoir (ie PR/JMR) or top aug station so can also have records (just have to waste time looking for gage records)
                % so first, look for XQ0 records - will get aug stations right, most headgate diversions
                % if no XQ0: get Total(Diversion) records for outflows/type==-1/diversions
                %            get sum of T:7/L/E for type 1 (inflows) or type 0 (gages but could be res/aug stations at top of reach)'
                % if type=0 or 1 , instead of summing T7/L/E records could potentially use Total Release if many fixed up in HBDMC (most screwed up) (also right now PR Total Release includes bessemmer etc plus transfers)


                divwdid=SR.(ds).(wds).(rs).wdid{sr};
                if SR.(ds).(wds).(rs).type(1,sr)~=0 || (r==1 && sr==1)  %WATCH - this says top aug/res has to be in r=1/sr=1 as trying to exclude gages (ie must exclude 6700904 / ARKGRACO)
                RESTworked=0;
                multiplemeasdateid=0;
                RESTworkedyr=zeros(1,length(avgyears));

                % first try XQ0 record..
                % currently will get kicked for real gages; may want to still want to call non-gages a type=2 or something
                divwci=[divwdid ' S:X F: U:Q T:0 G: To:'];
                logm=['HBREST: first attempting to read XQ0: ' divwci ' from: ' datestr(avgdates(1),23) ' to ' datestr(avgdates(end),23) ' and modified: ' modifiedstr(1:10) ];
                domessage(logm,logfilename,displaymessage,writemessage)
                try
                    divrecdata=webread(divrecdayurl,'format','json','wdid',divwdid,'wcIdentifier',divwci,'min-datameasdate',datestr(avgdates(1),23),'max-datameasdate',datestr(avgdates(end),23),'min-modified',modifiedstr(1:10),weboptions('Timeout',60),'apiKey',apikey);
                    RESTworked=1;
                catch
                    %didnt get XQ0 record
                end

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % if no XQ0 record.. get divtotal or T:7/L/E records

                if SR.(ds).(wds).(rs).type(sr)==-1 && RESTworked==0  %outflow - looking for total diversion record
                    logm=['HBREST: reading daily diversion records (divtotal) for ' divwdid ' from: ' datestr(avgdates(1),23) ' to ' datestr(avgdates(end),23) ' and modified: ' modifiedstr(1:10) ];
                    domessage(logm,logfilename,displaymessage,writemessage)
                    divwcnum=['1' divwdid];
                    try
                        divrecdata=webread(divrecdayurl,'format','json','waterClassNum',divwcnum,'wdid',divwdid,'min-datameasdate',datestr(avgdates(1),23),'max-datameasdate',datestr(avgdates(end),23),'min-modified',modifiedstr(1:10),weboptions('Timeout',60),'apiKey',apikey);
                        RESTworked=1;
                    catch
                        %didnt get Total Diversion Record
                    end
                elseif RESTworked==0 %type 0 (gage or res/augstation) or inflow - looking for T7/L/E release records
                    logm=['HBREST: reading daily release records (T:7/L/E) for ' divwdid ' from: ' datestr(avgdates(1),23) ' to ' datestr(avgdates(end),23) ' and modified: ' modifiedstr(1:10) ];
                    domessage(logm,logfilename,displaymessage,writemessage)
                    divrecdata1.ResultList=[];
                    divrecdata2.ResultList=[];
                    divrecdata3.ResultList=[];
                    try
                        divwci='*T:7*';
                        divrecdata1=webread(divrecdayurl,'format','json','wdid',divwdid,'wcIdentifier',divwci,'min-datameasdate',datestr(avgdates(1),23),'max-datameasdate',datestr(avgdates(end),23),'min-modified',modifiedstr(1:10),weboptions('Timeout',60),'apiKey',apikey);
                        RESTworked=1;
                    catch
                        %didnt get Release type 7
                    end
                    try
                        divwci='*T:E*';
                        divrecdata2=webread(divrecdayurl,'format','json','wdid',divwdid,'wcIdentifier',divwci,'min-datameasdate',datestr(avgdates(1),23),'max-datameasdate',datestr(avgdates(end),23),'min-modified',modifiedstr(1:10),weboptions('Timeout',60),'apiKey',apikey);
                        RESTworked=1;
                    catch
                        %didnt get type E
                    end
                    try
                        divwci='*T:L*';
                        divrecdata3=webread(divrecdayurl,'format','json','wdid',divwdid,'wcIdentifier',divwci,'min-datameasdate',datestr(avgdates(1),23),'max-datameasdate',datestr(avgdates(end),23),'min-modified',modifiedstr(1:10),weboptions('Timeout',60),'apiKey',apikey);
                        RESTworked=1;
                    catch
                        %didnt get type L
                    end
                    if RESTworked==1
                        divrecdata.ResultList=[divrecdata1.ResultList;divrecdata2.ResultList;divrecdata3.ResultList];
                        divrecdata.ResultCount=length(divrecdata.ResultList);
                    end
                end


                if RESTworked==0  %previously had a catch for this
                    if pullstationdata==1
                        logm=['WARNING: didnt return daily diversion records data for wdid:' divwdid ' (issue with command, station, API, REST services, data, etc)'];
                    else
                        logm=['WARNING: - probably no new data since last REST pull - didnt return any daily tdiversion records for wdid:' divwdid ' for modified date: ' modifiedstr(1:10) ' (probably new data beyond modified date - or could be other issue)'];
                    end
                    domessage(logm,logfilename,displaymessage,writemessage)
                else  %if RESTworked==1
                    for i=1:divrecdata.ResultCount
                        userec=0;
                        wdid=divrecdata.ResultList(i).wdid;
                        wcnum=divrecdata.ResultList(i).waterClassNum;
                        wwcnum=['W' num2str(wcnum)];
                        wc=divrecdata.ResultList(i).wcIdentifier;
                        tid=strfind(wc,'T:');
                        type=wc(tid+2);

                        if strcmp(wc(9:end),'S:X F: U:Q T:0 G: To:') %XQ0 record
                            userec=1;
                        elseif SR.(ds).(wds).(rs).type(sr)==-1 && strcmp(wwcnum,['W1' divwdid]) %for diversion with wcnum that signals wc of 'Total (Diversion)' record usually like XQ0 record but also when no XQ0
                            userec=2;
                        elseif SR.(ds).(wds).(rs).type(sr)~=-1 && ( strcmp(type,'7') | strcmp(type,'L') | strcmp(type,'E') ) %for release with type= 7/Released to Stream, L/Release of Dominion and Control, or E/Release of Excess Diversion
                            userec=3;
                        else
                            logm=['WARNING: - REST pull returned something that wasnt total diversion record or T7/L/E release, very confused']
                            domessage(logm,logfilename,displaymessage,writemessage)
                        end

                        if userec>=1  %testing for date, unit, daily
                            measdatestr=divrecdata.ResultList(i).dataMeasDate;
                            measdatestr(11)=' ';
                            %                                measdatenum=datenum(measdatestr,31);
                            measdateid=find(strcmp(avgdatesstr,measdatestr));
                            measinterval=divrecdata.ResultList(i).measInterval;
                            measunits=divrecdata.ResultList(i).measUnits;
                            if ~strcmp(measinterval,'Daily') | ~strcmp(measunits,'CFS')
                                logm=['WARNING: skipping REST divrec ' wdid ' ' num2str(wcnum) ' with measinterval: ' measinterval ' with measunits: ' measunits];
                                domessage(logm,logfilename,displaymessage,writemessage)
                                userec=0;
                            elseif isempty(measdateid)
                                logm=['WARNING: skipping REST divrec ' wdid ' ' num2str(wcnum) ' with measdatestr: ' measdatestr ' datevalue outside of model daterange'];
                                domessage(logm,logfilename,displaymessage,writemessage)
                                userec=0;
                            end
                        end
                        if userec>=1
                            if sum(multiplemeasdateid==measdateid)  %checking if some combination of Type:7/L/E
                                Station.(ds).(wds).(rs).Qdivdaylong(measdateid,sr)=Station.(ds).(wds).(rs).Qdivdaylong(measdateid,sr)+divrecdata.ResultList(i).dataValue;
                                Station.(ds).(wds).(rs).Qdaylong(measdateid,sr)=Station.(ds).(wds).(rs).Qdaylong(measdateid,sr)+divrecdata.ResultList(i).dataValue;
                                Station.(ds).(wds).(rs).Qdaylongflag(measdateid,sr)=7+i/100000;  %day flag 7 = sum of type 7/L/E div records
                            else
                                Station.(ds).(wds).(rs).Qdivdaylong(measdateid,sr)=divrecdata.ResultList(i).dataValue;
                                Station.(ds).(wds).(rs).Qdaylong(measdateid,sr)=divrecdata.ResultList(i).dataValue;
                                Station.(ds).(wds).(rs).Qdaylongflag(measdateid,sr)=3+userec+i/100000;  %day flag 4 = XQ0 div record, flag 5=divtotal record, flag 6=single type7/L/E record
                            end
                            multiplemeasdateid=[multiplemeasdateid measdateid];
                            modifieddatestr=divrecdata.ResultList(i).modified;
                            %                                 modifieddatestr(11)=' ';
                            %                                 modifieddate=datenum(modifieddatestr,31);
                            modifieddate=str2double([modifieddatestr(1:4) modifieddatestr(6:7) modifieddatestr(9:10) modifieddatestr(12:13) modifieddatestr(15:16)]);
                            Station.(ds).(wds).(rs).modifieddatelong(measdateid,sr)=modifieddate;
                            maxmodified=max(maxmodified,modifieddate);
                            userecyr=avgdatesvec(measdateid,1);
                            RESTworkedyr(userecyr-avgstartyear+1)=1;
                        end
                    end

                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % WATCH - Assign zeros to still missing records
                    % fill with zero if they had some other usable div record during year (so doesnt fill with trend etc)
                    % also if filllongtermwithzero==2 fill other years too with zero if had at least one year with div record
                    % for current year, limit zeroing to records before last record date
                    % for previous year, limit zeroing to Nov1 in case div records for current water year not published
                    RESTworkedyrids=find(RESTworkedyr==1);
                    if filllongtermwithzero>=1 && ~isempty(RESTworkedyrids)
                        for i=1:length(RESTworkedyrids)
                            avgyearsids=avgyearsid{RESTworkedyrids(i)}';
                            yrmissingids=find(Station.(ds).(wds).(rs).Qdaylong(avgyearsids,sr)==-999);
                            if RESTworkedyrids(i)==length(avgyears)  %condition for current year
                                firstofyearids=find(avgyearsids<multiplemeasdateid(end));
                                yrmissingids=intersect(yrmissingids,firstofyearids);
                            elseif RESTworkedyrids(i)==(length(avgyears)-1)
                                firstofyearids=find(avgyearsids<lastnovid);
                                yrmissingids=intersect(yrmissingids,firstofyearids);
                            end
                            if ~isempty(yrmissingids)
                                Station.(ds).(wds).(rs).Qdaylong(avgyearsids(yrmissingids),sr)=0;
                                Station.(ds).(wds).(rs).Qdaylongflag(avgyearsids(yrmissingids),sr)=9;  %day flag 9 = missing values assigned zero within year that had some div records
                            end
                        end
                        if filllongtermwithzero==2  %fill other years too with zero
                            missingids=find(Station.(ds).(wds).(rs).Qdaylong(1:max(lastnovid-1,multiplemeasdateid(end)),sr)==-999);
                            if ~isempty(missingids)
                                Station.(ds).(wds).(rs).Qdaylong(missingids,sr)=0;
                                Station.(ds).(wds).(rs).Qdaylongflag(missingids,sr)=9;  %day flag 9 = missing values assigned zero to all missing years because other years did have div records
                            end
                        end
                    end

                end  %REST worked
                end  %not gage - excluding gages but not top res/aug station

                % Apply diversion corrections
                % if wdid in table shows a diversion correction
                if sum(strcmp(divcorrect.(ds).wdid,divwdid))>0
                    divcorid=find(strcmp(divcorrect.(ds).wdid,divwdid));
                    for i=1:length(divcorid)
                        if divcorrect.(ds).start(divcorid(i))==999
                            startdateid=1;
                        else
                            startdateid=find(avgdates==divcorrect.(ds).start(divcorid(i)));
                        end
                        if divcorrect.(ds).end(divcorid(i))==999
                            enddateid=length(avgdates);
                        else
                            enddateid=find(avgdates==divcorrect.(ds).end(divcorid(i)));
                        end
                        Station.(ds).(wds).(rs).Qdaylong(startdateid:enddateid,sr)=divcorrect.(ds).newamt(divcorid(i));
                        Station.(ds).(wds).(rs).Qdaylongflag(startdateid:enddateid,sr)=8;  %flag 8 = div record correction value
                        logm=['Correction: correcting wdid ' divwdid ' from: ' datestr(divcorrect.(ds).start(divcorid(i))) ' to: ' datestr(divcorrect.(ds).end(divcorid(i))) ' with amt: ' num2str(divcorrect.(ds).newamt(divcorid(i)))];
                        domessage(logm,logfilename,displaymessage,writemessage)
                    end
                end

            end
        else
            % SR.(ds).(wds).(rs).Qnode(:,:,1)=SR.(ds).(wds).(rs).(flow)(1,:).*ones(rsteps,length(SR.(ds).(wds).(rs).SR));
            Station.(ds).(wds).(rs).Qdaylong(:,sr)=blankvaluesday;
            Station.(ds).(wds).(rs).Qstatdaylong(:,sr)=blankvaluesday;
            Station.(ds).(wds).(rs).Qdivdaylong(:,sr)=blankvaluesday;
            Station.(ds).(wds).(rs).Qdaylongflag(:,sr)=blankvaluesday+999;
            Station.(ds).(wds).(rs).modifieddatelong(:,sr)=blankvaluesday;
        end
    end
    Station.date.(ds).(wds).avgmodified=maxmodified;
end

% establishment of daily dry/avg/wet annual values for stations with telemetry
logm=['Estimation of daily dry/avg/wet averages'];
domessage(logm,logfilename,displaymessage,writemessage)

for wd=WDlist
    wds=['WD' num2str(wd)];
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            for i=1:366
                avgdatesids=avgdatesid{i};
                avgdaymeas=Station.(ds).(wds).(rs).Qdaylong(avgdatesids,sr);
                posids=find(avgdaymeas~=-999);
                if isempty(posids)
                    Station.(ds).(wds).(rs).Qavgdryday(i,sr)=SR.(ds).(wds).(rs).avgflow(1,sr);
                    Station.(ds).(wds).(rs).Qavgavgday(i,sr)=SR.(ds).(wds).(rs).avgflow(2,sr);
                    Station.(ds).(wds).(rs).Qavgwetday(i,sr)=SR.(ds).(wds).(rs).avgflow(3,sr);
                else
                    [sortavgday,sortavgdayid]=sort(avgdaymeas(posids));
                    percamt=floor(length(sortavgdayid)/3); %33 percentile but with floor/ceil puts dry / wet at approx 30% / 70%
                    drydayids=posids(sort(sortavgdayid(1:max(1,percamt))));
                    avgdayids=posids(sort(sortavgdayid(min(length(sortavgdayid),max(1,percamt+1)):max(1,length(sortavgdayid)-percamt))));
                    wetdayids=posids(sort(sortavgdayid(min(length(sortavgdayid),length(sortavgdayid)-percamt+1):end)));
                    Station.(ds).(wds).(rs).Qavgdryday(i,sr)=median(avgdaymeas(drydayids)); %changed this from mean to median
                    Station.(ds).(wds).(rs).Qavgavgday(i,sr)=median(avgdaymeas(avgdayids));
                    Station.(ds).(wds).(rs).Qavgwetday(i,sr)=median(avgdaymeas(wetdayids));
                end
            end
            %need filling here in case any -999

            %additional thing for use in daily QC loop - last day with data
            hasdailyid=find(Station.(ds).(wds).(rs).Qdaylong(:,sr)~=-999);  %could put these in avg processing loop
            if ~isempty(hasdailyid)
                Station.(ds).(wds).(rs).lastdailydate=Station.date.avgdates(hasdailyid(end));
            else
                Station.(ds).(wds).(rs).lastdailydate=Station.date.avgdates(1);
            end
            %convert quickly to hourly - here still based on 366 not 365
            Station.(ds).(wds).(rs).Qavgdry(:,sr)=reshape(repmat(Station.(ds).(wds).(rs).Qavgdryday(:,sr),1,24)',[366*24,1]);
            Station.(ds).(wds).(rs).Qavgavg(:,sr)=reshape(repmat(Station.(ds).(wds).(rs).Qavgavgday(:,sr),1,24)',[366*24,1]);
            Station.(ds).(wds).(rs).Qavgwet(:,sr)=reshape(repmat(Station.(ds).(wds).(rs).Qavgwetday(:,sr),1,24)',[366*24,1]);
        end
    end
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% QC of hourly (telemetry) data with daily (surfacewater ie 'published' and diversion records)
% can also be used for some filling of missing hourly data
 
logm=['QC of hourly (telemetry) data with daily surfacewater and diversion records'];
domessage(logm,logfilename,displaymessage,writemessage)

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
        dailydateids{i}=find(rdatesday(datestid:dateendid)==dailydates(i));
    end

for wd=WDlist
    wds=['WD' num2str(wd)];    
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            tsmeas=Station.(ds).(wds).(rs).Qmeas(:,sr);
            tsmeasQC=tsmeas;
            tsdaily=Station.(ds).(wds).(rs).Qdaylong(dailyids,sr);
            tsdailyflag=Station.(ds).(wds).(rs).Qdaylongflag(dailyids,sr);
            tsflagQC=Station.(ds).(wds).(rs).Qmeasflag(:,sr);
            for i=1:length(dailydates)
                Station.(ds).(wds).(rs).Qdaily(dailydateids{i},sr)=tsdaily(i);
                Station.(ds).(wds).(rs).Qstatdaily(dailydateids{i},sr)=Station.(ds).(wds).(rs).Qstatdaylong(dailyids(i),sr);
                Station.(ds).(wds).(rs).Qdivdaily(dailydateids{i},sr)=Station.(ds).(wds).(rs).Qdivdaylong(dailyids(i),sr);
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
                        tsflagQC(tshrdayids,1)=tsdailyflag(i)+10; %flag +10=fill with daily
                    elseif isempty(missingids) %if no missing hourly data, adjust if diff exceeds thres1 or replace if exceeds thres2
                        tshrdayperdiff=(mean(tshrforday)-tsdaily(i))/tsdaily(i);                        
                        if abs(tshrdayperdiff) >= dayvshrthreshold(2)  %replace it
                            tsmeasQC(tshrdayids,1)=tsdaily(i);
                            tsflagQC(tshrdayids,1)=tsdailyflag(i)+20; %flag +20=replaced with daily
                        elseif abs(tshrdayperdiff) >= dayvshrthreshold(1)  %adjust it
                            tsmeasQC(tshrdayids,1)=tsmeas(tshrdayids,1)-((mean(tshrforday)-tsdaily(i))/mean(tshrforday))*tsmeas(tshrdayids,1); %slight variation from tshrdayperdiff so that calculates exactly
                            tsflagQC(tshrdayids,1)=tsdailyflag(i)+30; %flag +30=adjusted with daily
                        end
                    else %if has some missingids, 
                        tshrdayperdiff=(mean(tsmeas(notmissingids,1))-tsdaily(i))/tsdaily(i);
                        if abs(tshrdayperdiff) >= dayvshrthreshold(2)  %replace it
                            tsmeasQC(tshrdayids,1)=tsdaily(i);
                            tsflagQC(tshrdayids,1)=tsdailyflag(i)+20; %flag +20=replaced with daily
                        elseif abs(tshrdayperdiff) >= dayvshrthreshold(1)  %adjust it
                            tsmeasQC(notmissingids,1)=tsmeas(notmissingids,1)-(mean(tsmeas(notmissingids,1))-tsdaily(i))/mean(tsmeas(notmissingids,1))*tsmeas(notmissingids,1);
                            tsmeasQC(missingids,1)=tsdaily(i);
                            tsflagQC(tshrdayids,1)=tsdailyflag(i)+30; %flag +30=adjusted with daily
                        else
                            tsmeasQC(missingids,1)=mean(tsmeas(notmissingids,1));
                            tsflagQC(tshrdayids,1)=tsdailyflag(i)+40; %flag +40=filled with mean of non-missing hourly
                        end
                        
%                         %commented out - the following would consider cases that missing should be zeros or should be mean values - but so far didnt like when put in a zero
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
                    % WATCH - SHOULD THIS BE MISSING OR ZERO??
                    if dailydates(i) < Station.(ds).(wds).(rs).lastdailydate
                        tsmeasQC(dailydateids{i},1)=-999;
%                        tsmeasQC(dailydateids{i},1)=0;
                        tsflagQC(dailydateids{i},1)=tsflagQC(dailydateids{i},1)+50; %flag +50=hourly zeroed due to blank daily, has hr code as base
                    end
                end
            end
            Station.(ds).(wds).(rs).Qqc(:,sr)=tsmeasQC;
            Station.(ds).(wds).(rs).Qqcflag(:,sr)=tsflagQC;
        end
    end
end


else  %if isempty(dailyid1)
    logm=['Warning: cannot QC hourly data with daily data - longterm daily data that has been downloaded does not include time period'];
    domessage(logm,logfilename,displaymessage,writemessage)
end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Filling of missing station data

logm=['Filling missing station data'];
domessage(logm,logfilename,displaymessage,writemessage)


ids=[1:runsteps];
SRgageids=find([SR.(ds).SR{:,10}]==0);
for wd=WDlist
    wds=['WD' num2str(wd)];    
    for r=SR.(ds).(wds).R 
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            tsmeas=Station.(ds).(wds).(rs).Qqc(:,sr);  %Qmeas/Qqc does not include spinup period
            tsfill=tsmeas;
%             if strcmp(wds,'WD17') && strcmp(rs,'R3') && sr==1
%                 tsfill(6500:end,sr)=-999;
%             end
            missinglist=find(tsfill==-999);
            tsflag=Station.(ds).(wds).(rs).Qqcflag(:,sr);
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
                        
                        tsmeasrepl=Station.(dsr).(wdsr).(rsr).Qqc(:,srr);                       
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
                            tsflag(missinglist1,1)=Station.(ds).(wds).(rs).Qqcflag(missinglist1,sr)+100;  %flag +100 regression fill1
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
                                tsflag(missingid,1)=Station.(ds).(wds).(rs).Qqcflag(missingid,sr)+200;  %flag +200 regression fill2
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
                        valflag=300;  %hr flag +300 smallgap interpolation
                    
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
                                        avgdayval=Station.(ds).(wds).(rs).Qdaylong(avgdayid,sr);
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
                        valflag=400;  %hr flag +400 smallgap trend1
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
                                        avgdayval=Station.(ds).(wds).(rs).Qdaylong(avgdayid,sr);
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
                        valflag=500;  %hr flag +500 smallgap trend2
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
                            avgtype(:,1)=[Station.(ds).(wds).(rs).Qavgdry(avgx+rjulien(1)-1,sr) ; Station.(ds).(wds).(rs).Qavgdry(missinglist(j)+rjulien(1)-1,sr)];
                            avgtype(:,2)=[Station.(ds).(wds).(rs).Qavgavg(avgx+rjulien(1)-1,sr) ; Station.(ds).(wds).(rs).Qavgavg(missinglist(j)+rjulien(1)-1,sr)];
                            avgtype(:,3)=[Station.(ds).(wds).(rs).Qavgwet(avgx+rjulien(1)-1,sr) ; Station.(ds).(wds).(rs).Qavgwet(missinglist(j)+rjulien(1)-1,sr)];
                            [mindiff,flowtype]=min(abs([mean(avgtype(1:end-1,1)) mean(avgtype(1:end-1,2)) mean(avgtype(1:end-1,3))] - mean(avgy)));
                            %[yfit,avgm,avgb,avgR2,SEE]=regr(avgy(1:end-1,flowtype),regy,'linreg');
                            %regavgval= avgm * avgy(end,flowtype) + avgb;
                            avgval=avgtype(end,flowtype);
                        else
                            switch flowtype
                                case 1
                                    avgval=Station.(ds).(wds).(rs).Qavgdry(missinglist(j)+rjulien(1)-1,sr);
                                case 2
                                    avgval=Station.(ds).(wds).(rs).Qavgavg(missinglist(j)+rjulien(1)-1,sr);
                                case 3
                                    avgval=Station.(ds).(wds).(rs).Qavgwet(missinglist(j)+rjulien(1)-1,sr);          
                            end
                            %regavgval= avgm * avgval + avgb;
                        end
                        if gapdist > avgwindow(2)
                            val=avgval;
                            valflag=600;  %hr flag +600 largegap avg
                        else
                            avgw=(gapdist-avgwindow(1))/(avgwindow(2)-avgwindow(1));
                            val=val*(1-avgw)+avgval*avgw;                            
                            valflag=700;  %hr flag +700 mediumgap weighted
                        end
                    end
                    tsfill(missinglist(j),1)=val;
                    tsflag(missinglist(j),1)=Station.(ds).(wds).(rs).Qqcflag(missinglist(j),sr)+valflag;  %hr flag +300+700 various gapfilling
       
                end
                end
                end

            end
            Station.(ds).(wds).(rs).Qfill(:,sr)=tsfill;
            Station.(ds).(wds).(rs).Qfillflag(:,sr)=tsflag;
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Filling of fully blank years using given average flows
% seperated so that surrounding gage data is filled prior to evaluation
% now basing flow on longterm avg/dry/wet amounts based on avg/dry/wet determination at closest gage (just one)
% filtering avg and current gage amounts by window so doesnt jump around too much
% previously had based flow on avg/dry/wet amounts listed in input - but this now gets integrated into long term averages

logm=['Filling of fully blank years using given average flows'];
domessage(logm,logfilename,displaymessage,writemessage)

for wd=WDlist
    wds=['WD' num2str(wd)];    
    for r=SR.(ds).(wds).R 
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            missinglist=find(Station.(ds).(wds).(rs).Qfill(:,sr)==-999);
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
                    
                    avgtype=[Station.(dsr).(wdsr).(rsr).Qavgdry(:,srr) Station.(dsr).(wdsr).(rsr).Qavgavg(:,srr) Station.(dsr).(wdsr).(rsr).Qavgwet(:,srr)];
                    avgy=Station.(dsr).(wdsr).(rsr).Qfill(:,srr);
                    for i=1:length(avgy)
                        leftids=ids(max(1,i-trendregwindow):max(1,i-1));
                        rightids=ids(i:min(length(avgy),i+trendregwindow-1));
                        filtavgtype(i,:)=mean(avgtype([leftids rightids]+rjulien(1)-1,:));
                        filtavgy(i,1)=mean(avgy([leftids rightids],1));
                    end
                    [mindiff,flowtype]=min(abs(avgtype(1:length(avgy),:) - avgy),[],2);

                    %this starts out using avgflow rates - will only use long-term averages then if have a -999 in for avgflows
                    Station.(ds).(wds).(rs).Qfill(:,sr)=SR.(ds).(wds).(rs).avgflow(flowtype,sr);
                    Station.(ds).(wds).(rs).Qfillflag(runsteps,sr)=900; %day flag 900 all missing for year and filled with defined average flowrates
                    
                    %now fill any remaining (if -999 specified for avgflow) with long term averages
                    missingids=find(Station.(ds).(wds).(rs).Qfill(:,sr)==-999);  %in case -999 in one but not all flow type
                    if ~isempty(missingids)
                        logm=['Filling ' ds ' ' wds ' ' rs ' ' num2str(sr) ' with longterm average flows'];
                        domessage(logm,logfilename,displaymessage,writemessage)

                        avgflows=[Station.(ds).(wds).(rs).Qavgdry(:,sr) Station.(ds).(wds).(rs).Qavgavg(:,sr) Station.(ds).(wds).(rs).Qavgwet(:,sr)];
                        if dateend-datestart+1==365  %not leap year
                            avgflows=[avgflows(1:1416,:) ; avgflows(1441:end,:)];
                        end
%                        avgflow(:,1)=avgflows(:,flowtype);  %unfortunately not working like this..
                        for i=1:length(flowtype)
                            avgflow(i,1)=avgflows(i,flowtype(i));
                        end
                        Station.(ds).(wds).(rs).Qfill(missingids,sr)=avgflow(missingids,1);
                        Station.(ds).(wds).(rs).Qfillflag(missingids,sr)=800;  %day flag 800 all missing for year so fill with average from longtermaverage
                    end

                    %and finally fill any still missing with zero - ie long term averages never had any data to work on
                    missingids=find(Station.(ds).(wds).(rs).Qfill(:,sr)==-999);
                    if ~isempty(missingids)
                        logm=['Warning: filling ' wds ' ' rs ' sr:' num2str(sr) ' for: ' num2str(length(missingids)) 'days with zero (couldnt figure anything else out)'];
                        domessage(logm,logfilename,displaymessage,writemessage)       
                        Station.(ds).(wds).(rs).Qfill(missingids,sr)=0;
                        Station.(ds).(wds).(rs).Qfillflag(missingids,sr)=1000;  %day flag 1000 remaining missing for year filled with zero!
                    end
                end
            end
        end
    end
end

if multiyrstation==1
    for wd=WDlist
        wds=['WD' num2str(wd)];
        for r=SR.(ds).(wds).R
            rs=['R' num2str(r)];
            myrstr=['Y' num2str(myr)];
            Station.(myrstr).(ds).(wds).(rs).Qmeas=Station.(ds).(wds).(rs).Qmeas;
            Station.(myrstr).(ds).(wds).(rs).modifieddate=Station.(ds).(wds).(rs).modifieddate;
            Station.(myrstr).(ds).(wds).(rs).Qmeasflag=Station.(ds).(wds).(rs).Qmeasflag;
%             Station.(myrstr).(ds).(wds).(rs).Qdaily=Station.(ds).(wds).(rs).Qdaily;  %these next five dont actually need to record..
%             Station.(myrstr).(ds).(wds).(rs).Qstatdaily=Station.(ds).(wds).(rs).Qstatdaily;
%             Station.(myrstr).(ds).(wds).(rs).Qdivdaily=Station.(ds).(wds).(rs).Qdivdaily;
%             Station.(myrstr).(ds).(wds).(rs).Qqc=Station.(ds).(wds).(rs).Qqc;
%            Station.(myrstr).(ds).(wds).(rs).Qqcflag=Station.(ds).(wds).(rs).Qqcflag;
            Station.(myrstr).(ds).(wds).(rs).Qfill=Station.(ds).(wds).(rs).Qfill;
            Station.(myrstr).(ds).(wds).(rs).Qfillflag=Station.(ds).(wds).(rs).Qfillflag;
        end
    end
end

end %multyrs

    save([datafiledir 'StateTL_data_qnode.mat'],'Station');
else
    load([datafiledir 'StateTL_data_qnode.mat']);    
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Attach station data into SR data (whether build or load)
%
% also here - reduce Qnodes for stubloss if on stub
% currently for stubloss defaulting to muskingum
% for stubloss - first do muskingum which can cause some inherent loss if really spiky
% if that inherent loss exceeds stubloss than leave it at the higher inherent loss (ie min function for loss2)
% but for really spikey stuff this can mean that dont have any loss during nonspikey times

for wd=WDlist
    wds=['WD' num2str(wd)];
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        if multiyrstation==1
            myrstr=['Y' num2str(yearstart)];
            SR.(ds).(wds).(rs).Qnode(1:datestid,:)=repmat(Station.(myrstr).(ds).(wds).(rs).Qfill(1,:),datestid,1);
            SR.(ds).(wds).(rs).Qnode(datestid:dateendid,:)=Station.(myrstr).(ds).(wds).(rs).Qfill;
            SR.(ds).(wds).(rs).Qnode(dateendid:rsteps,:)=repmat(Station.(myrstr).(ds).(wds).(rs).Qfill(end,:),rsteps-dateendid+1,1);
        else
            SR.(ds).(wds).(rs).Qnode(1:datestid,:)=repmat(Station.(ds).(wds).(rs).Qfill(1,:),datestid,1);
            SR.(ds).(wds).(rs).Qnode(datestid:dateendid,:)=Station.(ds).(wds).(rs).Qfill;
            SR.(ds).(wds).(rs).Qnode(dateendid:rsteps,:)=repmat(Station.(ds).(wds).(rs).Qfill(end,:),rsteps-dateendid+1,1);
        end
        for sr=SR.(ds).(wds).(rs).SR
            if SR.(ds).(wds).(rs).stubloss(sr)~=0
                stubloss=SR.(ds).(wds).(rs).stubloss(sr);
                Qus=SR.(ds).(wds).(rs).Qnode(:,sr);
%                Qus=SR.(ds).(wds).(rs).Qnode(:,sr)*(1-losspercent/100);
               [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,stubcelerity,stubdispersion,1);
               loss2=min(1,(1-stubloss/100)*sum(Qus)/sum(Qds));
               SR.(ds).(wds).(rs).Qnode(:,sr)=Qds*loss2;
            end
        end
    end
end
%clear Station
%temporary holbrook outfall correction?..
%SR.D2.WD17.R6.Qnode(1:3291+9*24,3)=0;

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
    load([datafiledir 'StateTL_data_release.mat']);
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
        divwci='*T:7*';  %for the moment just Type 7 not including others like L release of domininion and control (may want to track that one) 
        divrecdata=webread(divrecdayurl,'format','json','min-datameasdate',datestr(datestart,23),'max-datameasdate',datestr(dateend,23),'min-dataValue',0.0001,'wdid',reswdid,'wcIdentifier',divwci,'min-modified',datestr(modified+1/24/60,'mm/dd/yyyy HH:MM'),weboptions('Timeout',30),'apiKey',apikey);
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
            elseif type==7   % | type==1 exchange / leave as str - strcmp(type,'L') | strcmp(type,'E') %release of dominion and control / excess diversion  
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
                modifieddate=datenum(modifieddatestr,31);
                WC.(ds).(wds).(wwcnum).modifieddate(dateid)=modifieddate;
                maxmodified=max(maxmodified,modifieddate);
            else  %not type 7
                logm=['WARNING: REST releaserec wasnt type 7 (?) ' wdid ' ' num2str(wcnum) ' with measdatestr: ' measdatestr];
                domessage(logm,logfilename,displaymessage,writemessage)

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
    save([datafiledir 'StateTL_data_release.mat'],'WC');
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
    WC.(ds).(wds).(wcnum).release=zeros(rsteps,1);
   
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

% have also had this up above to reduce records pull, but then cant flip around checking reaches..
% if running calibration, reduce WDlist to those at or upstream of calib reaches
if runcalibloop==1
    WDlistcalibidmax=0;
    for i=1:length(WDcaliblist)
        WDlistcalibid=find(WDlist==WDcaliblist(i));
        WDlistcalibidmax=max([WDlistcalibidmax; WDlistcalibid]);
    end
    if WDlistcalibidmax~=0
        WDlist=WDlist(1:WDlistcalibidmax);
    else
        logmc=[logmc;'Error: Could not figure out which reach to calibrate: ' basedir controlfilename];
        errordlg(logmc); error(logmc{end});
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RIVERLOOP / GAGEFLOW LOOP 
% this loop just runs on full river flows as measured at gages
% part of this loop is to establish gagediff - which represents gains/losses/errors
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    
if runriverloop>0

logm=['Starting river/gageflow loop at: '  datestr(now)];
domessage(logm,logfilename,displaymessage,writemessage)
    
    
lastwdid=[];  %tracks last wdid/connection of processed wd reaches
SR.(ds).Rivloc.loc=[]; %just tracks location listing of processed reaches
SR.(ds).Rivloc.flowwc.wcloc=[];
SR.(ds).Gageloc.loc=[];
SR.(ds).Rivloc.length=[];

nids1=[datestid:nhrs:dateendid];
nids2=nids1+nhrs-1;


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
        if strcmp(SR.(ds).(wds).(rs).station{sr},'NaN')
            abbrev=SR.(ds).(wds).(rs).name{sr};
            spaceids=find(abbrev==' ');
            if ~isempty(spaceids)
                abbrev=abbrev(1:spaceids(1)-1);
            end
        else
            abbrev=SR.(ds).(wds).(rs).station(sr);
        end
        %these track if, under calibration, there will be a simulated gage amount different from observations
        if r==1 || r==2 && sum(SR.(ds).(wds).R1.channellength)<= 1.0  %change here if this condition is changed in calibloop 
            gagesim=0;
        else
            gagesim=1;
        end
        SR.(ds).Gageloc.loc=[SR.(ds).Gageloc.loc;[{ds} {wds} {rs} {r} SR.(ds).(wds).(rs).wdid(sr) abbrev {num2str(gagesim)}]];
        SR.(ds).(wds).(rs).gagelocid=length(SR.(ds).Gageloc.loc(:,1));  %currently having rule that only 1 gage per reach - typically at top but not bottom
        SR.(ds).Gageloc.flowgage(:,SR.(ds).(wds).(rs).gagelocid)=SR.(ds).(wds).(rs).Qnode(:,sr);
    end
end

SR.(ds).(wds).(rs).wcreduceamtlast=zeros(rsteps,1);
        

SR.(ds).(wds).(rs).wcreducelist=[];
negnativeussumsumprevious=0;
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

for ii=1:iternum
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
                if SR.(ds).(wds).(rs).evapfactor(sri)>0
                    Qavg=(max(Qus,minc)+max(Qds,minc))/2;
                    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sri))+SR.(ds).(wds).(rs).widthb(sri));
                    evap=SR.(ds).(wds).(rs).evapday(rjulien,sri)*SR.(ds).(wds).(rs).evapfactor(sri).*width.*SR.(ds).(wds).(rs).channellength(sri);
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
    negnativeussum=sum(negnativeus(datestid:dateendid,1));
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
        addamtsum=sum(addamt(datestid:dateendid,1));
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

    if ii>1
%        gainmeth='movingavg';
        gainmeth=calibavggainloss;
        x=(1:rsteps)';
        y=SR.(ds).(wds).(rs).gagediffportion(:,sr)+SR.(ds).(wds).(rs).sraddamt(:,sr);
        [avggains,m,b,R2,SEE]=regr(x,y,gainmeth,movingavgwindow);
        SR.(ds).(wds).(rs).avggains(:,sr)=avggains;
    else
        avggains=0;
    end
    
    
    if strcmp(srmethod,'none') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'none')) % not run transittime but can have loss percent 
        losspercent=SR.(ds).(wds).(rs).losspercent(sr);
        Qds=Qus*(1-losspercent/100);
        [celerity,dispersion]=calcceleritydisp((Qus+Qds)/2,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),1);

    elseif strcmp(srmethod,'j349') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'j349'))

        gainportion=gain*SR.(ds).(wds).(rs).reachportion(sr);
        Qus1=max(minj349,Qus);
        if j349musk==1
            [Qdsm,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus1,rhours,rsteps,-999,-999);
            [Qds,celerity2,dispersion2,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Qus1,Qdsm,gainportion,rdays,rhours,rsteps,j349dir,-999,-999,j349multurf,-999,-999,j349fast);
        else
            [Qds,celerity,dispersion,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Qus1,0,gainportion,rdays,rhours,rsteps,j349dir,-999,-999,j349multurf,-999,-999,j349fast);
        end
        Qds=Qds-(Qus1-Qus); %timing won't be perfect for this but keeps celerity exactly calculated above (may want to do as just pure addition/subtraction)
        if ~isempty(logm)
            domessage(logm,logfilename,displaymessage,writemessage)
        end

    elseif strcmp(srmethod,'bank') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'bank'))
        [Qds,celerity,dispersion,stage,Qdstail]=runbank(ds,wds,rs,sr,Qus,rhours,rsteps,-999,-999,0);
        SR.(ds).(wds).(rs).stage(:,sr)=stage';

    else
        [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,-999,-999);
        losspercent=SR.(ds).(wds).(rs).losspercent(sr);
        loss2=min(1,(1-losspercent/100)*sum(Qus)/sum(Qds));
        Qds=Qds*loss2;
    end

    Qavg=(max(Qus,minc)+max(Qds+avggains,minc))/2;
    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
    evap=SR.(ds).(wds).(rs).evapday(rjulien,sr)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr); %EvapFactor = 0 to not have evap
    Qds=Qds-evap+SR.(ds).(wds).(rs).gagediffportion(:,sr)+SR.(ds).(wds).(rs).sraddamt(:,sr);
    Qds=max(0,Qds);

%     %subtract from gagediffportion the amount that Qds goes negative - potentially gagediff will magnify
%     Qdiffadd=-1*min(0,Qds); %these will be positive
%     sumQdiffadd=sum(Qdiffadd);
%     SR.(ds).(wds).(rs).sumQdiffadd(sr)=sumQdiffadd;
%     if sumQdiffadd>0 && ii>1
%         Qds=max(0,Qds);
% %        Qds=Qds+Qdsadd;
%         gagediff=gagediff-Qdiffadd;
%     end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    % INADVERTANT DIVERSIONS - ACTION 3b
    % also checking at Qds - shouldnt happen here much if at all but I guess just in case
    if inadv3a_increaseint == 1
    Qdsnative=Qds-SR.(ds).(wds).(rs).Qdswc(:,sr);
    negnativeds=-1*min(0,Qdsnative);
    negnativedssum=sum(negnativeds(datestid:dateendid,1));
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
        addamtsum=sum(addamt(datestid:dateendid,1));
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
    SR.(ds).(wds).(rs).evap(:,sr)=evap;
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
%        gagediffavg=mean(gagediffnew(datestid:dateendid,1));
        gagediff=gagediffnew+gagediff;

        if ii<iternum
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
%                 evap=SR.(ds).(wds).(rs).evapday(rjulien,sr)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
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

if runriverloop==1  %not save if riverloop=2 (ie for calibration)
    save([basedir 'StateTL_bin_riv' srmethod '.mat'],'SR');
end
elseif runwcloop>0 | runcalibloop>0
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


if runwcloop>0

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
        Qusrelease=SR.(ds).(fromWDs).(fromRs).(ws).Qdsrelease(:,fromsr);
    else  %if not parked
        Qusrelease=WC.(ds).(wds).(ws).release;
    end
    if SR.(ds).(wds).(rs).stubloss(SRtr)~=0
        stubloss=SR.(ds).(wds).(rs).stubloss(SRtr);
        [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qusrelease,rhours,rsteps,stubcelerity,stubdispersion,1);
        loss2=min(1,(1-stubloss/100)*sum(Qusrelease)/sum(Qds));
        Qusrelease=Qds*loss2;
    end
else  %new - OK??? - WATCH
%    Qusnodepartial=SR.(ds).(wds).(['R' num2str(r-1)]).(ws).Qdspartial(:,end);
    Qusrelease=SR.(ds).(wds).(['R' num2str(r-1)]).(ws).Qdsrelease(:,end);  %when restarting a r-reach dont include effect of previous SRadd
    Qusnodepartial=SR.(ds).(wds).(rs).Qusnode(:,1)-Qusrelease;
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
        SR.(ds).(wdsnew).(rsnew).(ws).Qdsrelease(:,sr)=-1*Qusrelease;
        SR.(ds).(wdsnew).(ws).Qusnoderelease(:,lsr)=zeros(rsteps,1);
        SR.(ds).(wdsnew).(ws).Qusrelease(:,lsr)=zeros(rsteps,1);
        SR.(ds).(wdsnew).(ws).Qdsrelease(:,lsr)=-1*Qusrelease;
%        SR.(ds).WCloc.(ws)=[SR.(ds).WCloc.(ws);[{ds},{wdsnew},{rs},{sr},{lsr},{2}]];  %type=1release,2exchange - instead putting this in in exchange loop
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %if want to do something with missing releases (ie put into Qusrelease) put an else here
        
    end
    
else
for sr=srtt:srtb
    if and(sr==SRtr,r==Rtr)
        Qusnodepartial=SR.(ds).(wds).(rs).Qus(:,sr); %this makes Qusnoderelease=0
        if pred==1 %predictive case
            Quspartial=SR.(ds).(wds).(rs).Qus(:,sr)+Qusrelease;
        else  %administrative case
            Quspartial=SR.(ds).(wds).(rs).Qus(:,sr)-Qusrelease;
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
        Qusrelease=Qusrelease-SR.(ds).(wds).(rs).(ws).wcreduceamt(:,sr);        
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

    losspercent=SR.(ds).(wds).(rs).losspercent(sr);


    QSRadd=-1*(min(0,Quspartial-minj349));  %amount of "potentially" negative native
    Quspartial=Quspartial+QSRadd;           %WARNING: this by itself this will cut Qusrelease (waterclass) to Qus (gage) (if exceeds)
%    Quspartial=max(minj349,Quspartial);  %WARNING: this by itself this will cut Qusrelease (waterclass) to Qus (gage) (if exceeds)
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    % INADVERTANT DIVERSIONS - ACTION 1-B
    % if individual Qusrelease (waterclass) exceeds Qus (gage-based) at interior node 
    % measure to allow Qusrelease to pass by - in case of error in gageportion or exchanges on releases
    % B - new method to "temporarily" increase river amount - NOT CURRENTLY WORKING
    QSRaddsum=sum(QSRadd(datestid:dateendid));
    if inadv1b_letwaterby==1 && QSRaddsum>0 %if internal correction so native doesnt go negative
        SR.(ds).(wds).(rs).QSRadd(:,sr)=SR.(ds).(wds).(rs).QSRadd(:,sr)+QSRadd;  %this is going to get overwritten by subsequent water classes (??)
        Qustemp=Qus+QSRadd;

        %rerun river flows with increases
        if gain==-999   %gain=-999 to not run transittime but can have loss percent
            losspercent=SR.(ds).(wds).(rs).losspercent(sr);
            Qdstemp=max(0,Qustemp*(1-losspercent/100));
            [celerity,dispersion]=calcceleritydisp((Qustemp+Qdstemp)/2,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),1);
        else
            if strcmp(srmethod,'j349') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'j349'))
                Qus1=max(minj349,Qustemp);
                [Qdstemp,celerity,dispersion,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Qus1,gainportion,rdays,rhours,rsteps,j349dir,-999,-999,j349multurf,-999,-999,j349fast);
                Qdstemp=Qdstemp-(Qus1-Qustemp); %timing won't be perfect for this but keeps celerity exactly calculated above (may want to do as just pure addition/subtraction)
                if ~isempty(logm)
                    domessage(logm,logfilename,displaymessage,writemessage)
                end
            else
                [Qdstemp,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qustemp,rhours,rsteps,-999,-999);
                losspercent=SR.(ds).(wds).(rs).losspercent(sr);
                loss2=min(1,(1-losspercent/100)*sum(Qustemp)/sum(Qdstemp));
                Qdstemp=Qdstemp*loss2;
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

    if j349musk==0 && (strcmp(srmethod,'j349') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'j349')))
        [Qdspartial,celeritypartial,dispersionpartial,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Quspartial,0,gainportion,rdays,rhours,rsteps,j349dir,celerity,dispersion,j349multurf,Qmin,Qmax,j349fast); %celerity/disp based on gage flows / +minflow because cant have zero flow
        if ~isempty(logm)
            domessage(logm,logfilename,displaymessage,writemessage)
        end
        
        Qavg=(max(Quspartial,minc)+max(Qdspartial+SR.(ds).(wds).(rs).avggains(:,sr),minc))/2;
        width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
        evap=SR.(ds).(wds).(rs).evapday(rjulien,sr)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
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
        QSRdsaddsum=sum(QSRdsadd(datestid:dateendid));
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



        %%%%%%%%%%%%%%%%%%%%%%%%%%
        % INADVERTANT DIVERSIONS - ACTION 1
        % if individual Qusrelease (waterclass) exceeds Qus (gage-based) at interior node
        % temporary measure to avoid cuting Qusrelease until reoperations deal with it
        % as could be that we just arent estimating interior node amount correctly given return flows etc
        SR.(ds).(wds).(rs).QSRadd(:,sr)=SR.(ds).(wds).(rs).QSRadd(:,sr)+QSRadd;  %this is going to get overwritten by subsequent water classes (??)
        %    SR.(ds).(wds).(rs).QSRaddcum(:,1:sr)=cumsum(SR.(ds).(wds).(rs).QSRadd(:,1:sr),2);  %this is what might get added back in as effect would go downstream
        QSRaddsum=sum(QSRadd(datestid:dateendid));
        if QSRaddsum>0 && inadv1a_letwaterby==1 %if internal correction so native doesnt go negate
            Qusrelease=max(0,Qusrelease);
            if gain==-999
                dsrelease=Qusrelease;
                losspercent=SR.(ds).(wds).(rs).losspercent(sr);
                dsrelease=Qusrelease*(1-losspercent/100);
            elseif strcmp(srmethod,'j349') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'j349'))
                Qmin=SR.(ds).(wds).(rs).Qmin(sr);
                Qmax=SR.(ds).(wds).(rs).Qmax(sr);
                if j349musk==1
                    [Qdsm,celerityout,dispersionout]=runmuskingum(ds,wds,rs,sr,Qusrelease+minj349,rhours,rsteps,celerity,dispersion);
                else
                    Qdsm=0;
                end
                [dsrelease,celerityout,dispersionout,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Qusrelease+minj349,Qdsm,gainportion,rdays,rhours,rsteps,j349dir,celerity,dispersion,j349multurf,Qmin,Qmax,j349fast); %celerity/disp based on gage flows - wrong but so timing the same
                dsrelease=dsrelease-minj349-gainportion;  %minflow added in and subtracted - a Qus constant 1 should have Qds constant 1
                if ~isempty(logm)
                    domessage(logm,logfilename,displaymessage,writemessage)
                end
            else
                [dsrelease,celerityout,dispersionout]=runmuskingum(ds,wds,rs,sr,Qusrelease,rhours,rsteps,celerity,dispersion);
                losspercent=SR.(ds).(wds).(rs).losspercent(sr);
                loss2=min(1,(1-losspercent/100)*sum(Qusrelease)/sum(dsrelease));
                dsrelease=dsrelease*loss2;
            end
            dsrelease=max(0,dsrelease);
            Qavg=(max(dsrelease,minc)+max(Qusrelease,minc))/2;
            width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
            evap=SR.(ds).(wds).(rs).evapday(rjulien,sr)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
            dsrelease=dsrelease-evap;  %not adding gain/loss term as this is pure release amount
            dsrelease=max(0,dsrelease);
            SR.(ds).(wds).(rs).(ws).QSRadded(:,sr)=1;
            QSRaddus=max(0,Qusrelease-Qusrelease);
            QSRaddds=max(0,dsrelease-Qdsrelease);
            SR.(ds).(wds).(rs).(ws).QSRaddus(:,sr)=QSRaddus;
            SR.(ds).(wds).(rs).(ws).QSRaddds(:,sr)=QSRaddds;
            Qusrelease=max(Qusrelease,Qusrelease);  %Qusrelease/Qdsrelease max of partial/cut method and just running release by itself
            Qdsrelease=max(dsrelease,Qdsrelease);
            Qdspartial=SR.(ds).(wds).(rs).Qds(:,sr)-Qdsrelease;
            logm=['To avoid cutting wc: ' ws ' total wcamount exceeding river: ' num2str(QSRaddsum) ' added US:' num2str(sum(QSRaddus(datestid:dateendid))) ' added DS:' num2str(sum(QSRaddds(datestid:dateendid))) ' wd:' wds ' r:' rs ' sr:' num2str(sr)];
            domessage(logm,logfilename,displaymessage,writemessage)
        else
            SR.(ds).(wds).(rs).(ws).QSRadded(:,sr)=0;
            SR.(ds).(wds).(rs).(ws).QSRaddus(:,sr)=zeros(rsteps,1);
            SR.(ds).(wds).(rs).(ws).QSRaddds(:,sr)=zeros(rsteps,1);
        end

    else
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % muskinghum and straight routings

        if strcmp(srmethod,'none') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'none')) %not run timing but can still have loss percent
            Qdsrelease=Qusrelease;
            Qdsrelease=Qdsrelease * (1-losspercent/100);
        elseif j349musk==1 && (strcmp(srmethod,'j349') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'j349')))
            Qusavgyear=mean(SR.(ds).(wds).(rs).Qus(:,sr));  %heres one of the problems with this method
            [Qdsm,celerityt,dispersiont]=runmuskingum(ds,wds,rs,sr,Qusrelease+Qusavgyear,rhours,rsteps,celerity,dispersion);
            [Qdsrelease,celerityt,dispersiont,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Qusrelease,Qdsm,0,rdays,rhours,rsteps,j349dir,celerity,dispersion,j349multurf,Qmin,Qmax,j349fast); %celerity/disp based on gage flows / +minflow because cant have zero flow
            if ~isempty(logm)
                domessage(logm,logfilename,displaymessage,writemessage)
            end
            Qdsrelease=Qdsrelease-Qusavgyear;
        elseif strcmp(srmethod,'bank') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'bank'))
            [Qdsrelease,celerityt,dispersiont,stage,Qdstail]=runbank(ds,wds,rs,sr,Qusrelease,rhours,rsteps,celerity,dispersion,1);
        else
            [Qdsrelease,celerityt,dispersiont]=runmuskingum(ds,wds,rs,sr,Qusrelease,rhours,rsteps,celerity,dispersion);
            loss2=min(1,(1-losspercent/100)*sum(Qusrelease)/sum(Qdsrelease));
            Qdsrelease=Qdsrelease*loss2;
        end

        evap=SR.(ds).(wds).(rs).evap(:,sr).*Qusrelease./max(SR.(ds).(wds).(rs).Qus(:,sr),minc);  %scale evap with total evap (instead of just the additional evap that this single release would cause - as its a tradgeity of the commons issue)
        Qdsrelease=Qdsrelease-evap;
        Qdsrelease=max(0,Qdsrelease);
        Qdspartial=Qds-Qdsrelease;
        Qdspartial=max(0,Qdspartial);
        Qusnoderelease=Qusrelease;
    end


    Qusnoderelease=max(0,Qusnoderelease);
    Qusrelease=max(0,Qusrelease);  %this seems to happen in muskingham - reason?? - need to worry about lost negative amount??
    Qdsrelease=max(0,Qdsrelease);    
    
    if sum(strcmp(SR.(ds).(wds).(rs).wcreducelist,ws))>0 && inadv2_reducewcpushUS==1 && sr==SR.(ds).(wds).(rs).SR(end)
        Qdspartial=Qdspartial+SR.(ds).(wds).(rs).(ws).wcreduceamtlast;
        Qdsrelease=Qdsrelease-SR.(ds).(wds).(rs).(ws).wcreduceamtlast;
        Qdsrelease=max(0,Qdsrelease);
    end    
    
    SR.(ds).(wds).(rs).(ws).Qusnodepartial(:,sr)=Qusnodepartial;
    SR.(ds).(wds).(rs).(ws).Quspartial(:,sr)=Quspartial;
    SR.(ds).(wds).(rs).(ws).Qdspartial(:,sr)=Qdspartial;
    
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
    Qusrelease=Qdsrelease;
    
        
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
    parklistid=find(strcmp(SR.(ds).(pwds).park(:,1),ws));
    parktype=SR.(ds).(pwds).park{parklistid,7};  %this was needed when broke from routing loop
    if parktype==2  %for us exchange through internal confluence, placing routed exchange amount at end of US WDreach - cant do this like this like regular us exchange since upper tribs already executed
        parklsr=SR.(ds).(pwds).(['R' num2str(SR.(ds).(pwds).R(end))]).subreachid(end);
        SR.(ds).(pwds).(prs).(ws).Qusnoderelease(:,psr)=zeros(rsteps,1);
        SR.(ds).(pwds).(prs).(ws).Qusrelease(:,psr)=zeros(rsteps,1);
%        SR.(ds).(pwds).(prs).(ws).Qdsrelease(:,psr)=SR.(ds).(wds).(ws).Qdsrelease(:,lsr);
        SR.(ds).(pwds).(prs).(ws).Qdsrelease(:,psr)=-1*SR.(ds).(wds).(rs).(ws).Qdsrelease(:,sr); %-1 for exchange - (or might this also be used for some sort of release?) 
        SR.(ds).(pwds).(ws).Qusnoderelease(:,parklsr)=zeros(rsteps,1);
        SR.(ds).(pwds).(ws).Qusrelease(:,parklsr)=zeros(rsteps,1);
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
negnativedssum=sum(negnativeds(datestid:dateendid,:));

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
        negnativeussum=sum(negnativeus(datestid:dateendid,:));
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
                if strcmp(srmethod,'none') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'none'))
                    Qnegus=Qnegds;
                else
                    [Qnegus,exchtimerem,celerity,srtime]=reversecelerity(ds,wds,rs,sr,Qnegds,exchtimerem,rhours,rsteps,celerity,dispersion); %using river celerity
                end
                Qavg=Qnegus;  %us and ds should be same amounts but using us to not smeer timing
                width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
                evap=SR.(ds).(wds).(rs).evapday(rjulien,sr)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
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
    negnativeussumsum=sum(sum(negnativeus(datestid:dateendid,:)));
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
    negnativeussumsum=sum(sum(negnativeus(datestid:dateendid,:)));
    if negnativeussumsum-negnativeussumsumprevious>sraddamtlimit
        change=1;
        changecount=changecount+1;
        negnativeussumsumprevious=negnativeussumsum;
        logm=['Reoperating both gage and admin loops count:' num2str(changecount) ' to reduce internal negative flow amounts totaling:' num2str(sum(negnativeussumsum)) ' wd:' wds ' r:' rs];
        domessage(logm,logfilename,displaymessage,writemessage)
    end    
end
    end %r

% %muskinghum dspercent correction    
% if ~(strcmp(srmethod,'j349') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'j349')))
% wwcnumids=find(strcmp(SR.(ds).WCloc.Rloc(:,3),wds));
% for w=1:length(wwcnumids)
% ws=SR.(ds).WCloc.Rloc{wwcnumids(w),1};
%     for r=SR.(ds).(wds).R
%         rs=['R' num2str(r)];
%     %
% 
%     a=sum(SR.(ds).(wds).(ws).Qdsrelease(datestid:dateendid,end))/sum(SR.(ds).(wds).(ws).Qusrelease(datestid:dateendid,1));
%     end
%end
%end


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
                if strcmp(srmethod,'j349') || strcmp(srmethod,'muskingum') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'j349')) || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'muskingum'))
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

if runwcloop==1 %not save if riverloop=2 (ie for calibration)
    save([basedir 'StateTL_bin_wc' srmethod '.mat'],'SR');
end
elseif runcaptureloop>0
    load([basedir 'StateTL_bin_wc' srmethod '.mat']);  
end %runwcloop


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CAPTURE LOOP TO CHARACTERIZE AVAILABLE/CAPTURE AMT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%

if runcaptureloop>0
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
%        releaseamt(1:datestid-1,1)=0;  %just in case (??)
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
                    srtime(i)=max(0,XFT/SC+2*SK/SC2-(2.78*sqrt(2*SK*XFT/(SC2*SC)+(8*SK/SC2)*(SK/SC2)))); %from j349 - time to first response
                end
                %WARNING REDO - believe srtime above needs to be divided by dt
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
                    if ~isempty(abovezeroids)
                    triggerupid(i)=abovezeroids(1);
                    if triggerupid(i)==1
                        triggeramt2=percrule*mean(releaseamt(relstartids(i+1):relendids(i+1),1));
                        abovetriggerids=find(endpos*availableamt(relstartids(i+1)+srtimehrs:end,:)>=triggeramt2);
                        if ~isempty(abovetriggerids)
                        triggerupid(i)=abovetriggerids(1);
                        end
                    end
                    triggerupid(i)=triggerupid(i)+relstartids(i+1)+srtimehrs-1;
                    else
                        triggerupid(i)=length(releaseamt);
                    end
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

    if savefinalmatfile==1 && runcalibloop==0
        logm=['Writing final capture loop binary, its a big file, starting:' datestr(now)];
        domessage(logm,logfilename,displaymessage,writemessage)

        save([datadir 'StateTL_out_allcapture.mat'],'SR','ds','datestid','dateendid','rsteps');

        logm=['Finished writing final capture loop binary at:' datestr(now)];
        domessage(logm,logfilename,displaymessage,writemessage)
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OBSERVATION LOOP JUST TO OUTPUT GAGE VALUES FOR CALIBRATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
if runobsloop>0
    logm=['Starting observation loop for use in calibration at: '  datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)

    %averages of gagediff etc taken with calibration period that is potentially within larger run period
    calibstid=find(rdates==calibstartdate);
    calibendid=find(rdates==calibenddate);
    if isempty(calibstid)
        calibstid=datestid;
        logm=['for observation/calibration loop, calibdatestart:' datestr(calibstartdate) ' not within current data period, so starting calibration period at:' datestr(rdates(calibstid))];
        domessage(logm,logfilename,displaymessage,writemessage)
    end
    if isempty(calibendid)
        calibendid=dateendid;
        logm=['for observation/calibration loop, calibdateend:' datestr(calibenddate) ' not within current data period, so ending calibration period at:' datestr(rdates(calibendid))];
        domessage(logm,logfilename,displaymessage,writemessage)
    end

j=0;jids=[];
if ~isfield(SR.(ds),'Gageloc')  %river loop wasnt run first
SR.(ds).Gageloc.loc=[];
for wd=WDcaliblist
    wds=['WD' num2str(wd)];
    Rt=SR.(ds).(wds).R(1);
    Rb=SR.(ds).(wds).R(end);    
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        for sr=SR.(ds).(wds).(rs).SR
            if SR.(ds).(wds).(rs).type(sr)==0
                j=j+1;
                if strcmp(SR.(ds).(wds).(rs).station{sr},'NaN')
                    abbrev=SR.(ds).(wds).(rs).name{sr};
                    spaceids=find(abbrev==' ');
                    if ~isempty(spaceids)
                        abbrev=abbrev(1:spaceids(1)-1);
                    end
                else
                    abbrev=SR.(ds).(wds).(rs).station(sr);
                end
                %these track if, under calibration, there will be a simulated gage amount different from observations
                if r==1 || r==2 && sum(SR.(ds).(wds).R1.channellength)<= 1.0  %change here if this condition is changed in calibloop
                    gagesim=0;
                else
                    gagesim=1;
                    jids=[jids j];
                end
                SR.(ds).Gageloc.loc=[SR.(ds).Gageloc.loc;[{ds} {wds} {rs} {r} SR.(ds).(wds).(rs).wdid(sr) abbrev {num2str(gagesim)}]];
                SR.(ds).(wds).(rs).gagelocid=length(SR.(ds).Gageloc.loc(:,1));  %currently having rule that only 1 gage per reach - typically at top but not bottom
                SR.(ds).Gageloc.flowgage(:,SR.(ds).(wds).(rs).gagelocid)=SR.(ds).(wds).(rs).Qnode(:,sr);
                if sum(strcmp(cmdlineargs,'m'))>0  %get multiyear gage data
                    for myr=multiyrs
                        myrstr=['Y' num2str(myr)];
                        SR.(ds).Gageloc.(myrstr).flowgage(:,SR.(ds).(wds).(rs).gagelocid)=Station.(myrstr).(ds).(wds).(rs).Qfill(:,sr);
                    end
                end
            end
        end
    end
end
else  %riverloop was also run
for wd=WDcaliblist
    wds=['WD' num2str(wd)];
    Rt=SR.(ds).(wds).R(1);
    Rb=SR.(ds).(wds).R(end);    
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];
        gagelocid=SR.(ds).(wds).(rs).gagelocid;
        gagesim=SR.(ds).Gageloc.loc{gagelocid,7};
        if gagesim==1
            jids=[jids SR.(ds).(wds).(rs).gagelocid];
        end
        if sum(strcmp(cmdlineargs,'m'))>0  %get multiyear gage data
            for myr=multiyrs
                myrstr=['Y' num2str(myr)];
                SR.(ds).Gageloc.(myrstr).flowgage(:,SR.(ds).(wds).(rs).gagelocid)=Station.(myrstr).(ds).(wds).(rs).Qfill(:,1); %here assuming gages in sr=1
            end
        end
    end
end
end

for i=1:length(jids)
    j=jids(i);
    loclinegage(i,:)=[SR.(ds).Gageloc.loc(j,5:6),SR.(ds).Gageloc.loc(j,1:4)];
    outputlinegage(i,:)=SR.(ds).Gageloc.flowgage(calibstid:calibendid,j)';
    if sum(strcmp(cmdlineargs,'m'))>0  %get multiyear gage data
        for myr=multiyrs
            myrstr=['Y' num2str(myr)];
            outputlinegagemulti.(myrstr)(i,:)=SR.(ds).Gageloc.(myrstr).flowgage(calibstid:calibendid,j)';
        end
    end
end

titlelocline=[{'WDID'},{'Abbrev'},{'Div'},{'WD'},{'Reach'},{'Reachnum'}];

if outputhr==1
    titledates=cellstr(datestr(rdates(calibstid:calibendid),'mm/dd/yy HH:'));
    logm=['writing hourly output files for gage/observation amounts (hourly is a bit slow), starting: ' datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)
    writecell([[titlelocline,titledates'];[loclinegage,num2cell(outputlinegage)]],[outputfilebase '_gagehr.csv']);
    if sum(strcmp(cmdlineargs,'m'))>0  %get multiyear gage data
        for myr=multiyrs
            myrstr=['Y' num2str(myr)];
            writecell([[titlelocline,titledates'];[loclinegage,num2cell(outputlinegagemulti.(myrstr))]],[outputfilebase '_' myrstr 'gagehr.csv']);
        end
    end
end

if outputday==1
    [yr,mh,dy,hr,mi,sec] = datevec(rdates(calibstid:calibendid));
    daymat=unique([yr,mh,dy],'rows','stable');
    titledatesday=cellstr(datestr([daymat zeros(size(daymat))],'mm/dd/yy'));
    for i=1:length(daymat(:,1))
        dayids=find(yr==daymat(i,1) & mh==daymat(i,2) & dy==daymat(i,3));
        outputlinedaygage(:,i)=mean(outputlinegage(:,dayids),2);
        if sum(strcmp(cmdlineargs,'m'))>0  %get multiyear gage data
            for myr=multiyrs
                myrstr=['Y' num2str(myr)];
                outputlinedaygagemulti.(myrstr)(:,i)=mean(outputlinegagemulti.(myrstr)(:,dayids),2);
            end
        end
    end
    logm=['writing daily output files for gage and simulated (calibration) amounts, starting: ' datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)
    writecell([[titlelocline,titledatesday'];[loclinegage,num2cell(outputlinedaygage)]],[outputfilebase '_gageday.csv']);
    if sum(strcmp(cmdlineargs,'m'))>0  %get multiyear gage data
        for myr=multiyrs
            myrstr=['Y' num2str(myr)];
            writecell([[titlelocline,titledatesday'];[loclinegage,num2cell(outputlinedaygagemulti.(myrstr))]],[outputfilebase '_' myrstr 'gageday.csv']);
        end
    end
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CALIBRATION LOOP TO COMPARE PREDICTED GAGE HYDROGRAPHS TO ACTUAL
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%

if runcalibloop>0
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
    if isempty(calibendid)
        calibendid=dateendid;
        logm=['for calibration loop, calibdateend:' datestr(calibenddate) ' not within current data period, so ending calibration period at:' datestr(rdates(calibendid))];
        domessage(logm,logfilename,displaymessage,writemessage)
    end
    if ~(strcmp(calibavggainloss,'mean') | strcmp(calibavggainloss,'linreg') | strcmp(calibavggainloss,'movingavg') | strcmp(calibavggainloss,'movingmedian'))
        logm=['for calibration loop, could not figure out how to average gagediff etc given listed option:' calibavggainloss ' (looking for movingavg movingmedian mean or linreg)'];
        domessage(logm,logfilename,displaymessage,writemessage)
        error(logm)
    end
    if strcmp(calibavggainloss,'movingavg') | strcmp(calibavggainloss,'movingmedian')
        logm=['for calibration loop, with option: ' calibavggainloss ' using window of: ' num2str(calibmovingavgdays) ' days for gain/loss term'];
        domessage(logm,logfilename,displaymessage,writemessage)
    end

x=(1:(calibendid-calibstid+1))';

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
        %for calibration loop - take moving average or average or linear regression of gagediffportion and sraddamt and other gain/loss/error terms over defined period
        gagediffportion=SR.(ds).(wds).(rs).gagediffportion;

        % particular perhaps odd condition that if is top and <1 mile to gage in next reach, then start calibration from next gage
        % this is in particular for pueblo res and JMR that records often missing something that is shown in actual gage but want to use records (rather than gage) to start aug stations etc
        % otherwise use average (ie moving average) or regression of gainloss term
        if r==1 && Rb>1 && sum(SR.(ds).(wds).(rs).channellength)<= 1.0  
            SR.(ds).(wds).(rs).gagediffportioncal=gagediffportion;
        else
%             y=gagediffportion(calibstid:calibendid,:);
%             [yfit,m,b,R2,SEE]=regr(x,y,calibavggainloss,movingavgwindow);
%             gagediffportion(calibstid:calibendid,:)=yfit;
            gagediffportion(calibstid:calibendid,:)=SR.(ds).(wds).(rs).avggains(calibstid:calibendid,:);
            SR.(ds).(wds).(rs).gagediffportioncal=gagediffportion;
        end

        if inadv3a_increaseint == 1
            sraddamt=SR.(ds).(wds).(rs).sraddamt;
            y=sraddamt(calibstid:calibendid,:);
            [yfit,m,b,R2,SEE]=regr(x,y,calibavggainloss,movingavgwindow);
            sraddamt(calibstid:calibendid,:)=yfit;
            SR.(ds).(wds).(rs).sraddamtcal=sraddamt;SR.(ds).(wds).(rs).sraddamtm=m;SR.(ds).(wds).(rs).sraddamtb=b;SR.(ds).(wds).(rs).sraddamtR2=R2;
        elseif inadv3b_increaseint == 1
            sraddamtds=SR.(ds).(wds).(rs).sraddamtds;
            sraddamtus=SR.(ds).(wds).(rs).sraddamtus;
            y=sraddamtds(calibstid:calibendid,:);
            [yfit,m,b,R2,SEE]=regr(x,y,calibavggainloss,movingavgwindow);
            sraddamtds(calibstid:calibendid,:)=yfit;
            SR.(ds).(wds).(rs).sraddamtdscal=sraddamtds;SR.(ds).(wds).(rs).sraddamtdsm=m;SR.(ds).(wds).(rs).sraddamtdsb=b;SR.(ds).(wds).(rs).sraddamtdsR2=R2;
            y=sraddamtus(calibstid:calibendid,:);
            [yfit,m,b,R2,SEE]=regr(x,y,calibavggainloss,movingavgwindow);
            sraddamtus(calibstid:calibendid,:)=yfit;
            SR.(ds).(wds).(rs).sraddamtuscal=sraddamtus;SR.(ds).(wds).(rs).sraddamtusm=m;SR.(ds).(wds).(rs).sraddamtusb=b;SR.(ds).(wds).(rs).sraddamtusR2=R2;
        end
        if adjustlastsrtogage==1
            gagedifflast=SR.(ds).(wds).(rs).gagedifflast;
            y=gagedifflast(calibstid:calibendid,1);
            [yfit,m,b,R2,SEE]=regr(x,y,calibavggainloss,movingavgwindow);
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
    

    
    %this block seeing if inflow should be defined from by a previously modeled branch flow at a wdid connection point
    if type==1 && strcmp(SR.(ds).(wds).(rs).station{sr},'NaN')  && ~isempty(lastwdid)
        branchid=find(strcmp(lastwdid(:,1),SR.(ds).(wds).(rs).wdid(sr)));
        if ~isempty(branchid)  && isfield(SR.(ds).(lastwdid{branchid,3}).(lastwdid{branchid,4}),'Qdscal')
            SR.(ds).(wds).(rs).Qnode(:,sr)=SR.(ds).(lastwdid{branchid,3}).(lastwdid{branchid,4}).Qdscal(:,lastwdid{branchid,5});
        end
    else
        branchid=[];
    end


    Qnode=SR.(ds).(wds).(rs).Qnode(:,sr);  %if branchid above and that branch also calibrated this will be coming from branch
    %new setup - going from Qusnode to Qus (after usnodes) then to Qds
    Qus=Qusnode+type*Qnode;
    if inadv3b_increaseint == 1
        Qus=Qus+sraddamtus(:,sr);
    end

    if sr==1 && r~=Rt && strcmp(calibtype,'reach') %if going on reach basis, reset upper amt to gage amt
        Qus=SR.(ds).(wds).(rs).Qnode(:,1);
    end

    Qus=max(0,Qus);

    if strcmp(srmethod,'none') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'none')) % to not run transittime but can have loss percent 
        losspercent=SR.(ds).(wds).(rs).losspercent(sr);
        Qds=Qus*(1-losspercent/100);
        [celerity,dispersion]=calcceleritydisp((Qus+Qds)/2,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),1);
    elseif strcmp(srmethod,'j349') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'j349'))

        gainportion=gain*SR.(ds).(wds).(rs).reachportion(sr);
        Qus1=max(minj349,Qus);
        Qmin=SR.(ds).(wds).(rs).Qmin(sr);
        Qmax=SR.(ds).(wds).(rs).Qmax(sr);
        if j349musk==1
            [Qdsm,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus1,rhours,rsteps,-999,-999);
        else
            Qdsm=0;
        end
        [Qds,celerity2,dispersion2,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Qus1,Qdsm,gainportion,rdays,rhours,rsteps,j349dir,-999,-999,j349multurf,Qmin,Qmax,j349fast);
        Qds=Qds-(Qus1-Qus); %timing won't be perfect for this but keeps celerity exactly calculated above (may want to do as just pure addition/subtraction)
        if ~isempty(logm)
            domessage(logm,logfilename,displaymessage,writemessage)
        end

    elseif strcmp(srmethod,'bank') || (strcmp(srmethod,'default') && strcmp(SR.(ds).(wds).(rs).defaultmethod{sr},'bank'))
        [Qds,celerity,dispersion,stage,Qdstail]=runbank(ds,wds,rs,sr,Qus,rhours,rsteps,-999,-999,0);

    else
        [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,-999,-999);
        losspercent=SR.(ds).(wds).(rs).losspercent(sr);
        loss2=min(1,(1-losspercent/100)*sum(Qus)/sum(Qds));
        Qds=Qds*loss2;
    end
    avggains=SR.(ds).(wds).(rs).avggains(:,sr);
    Qavg=(max(Qus,minc)+max(Qds+avggains,minc))/2;
    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
    evap=SR.(ds).(wds).(rs).evapday(rjulien,sr)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr); %EvapFactor = 0 to not have evap
    Qds=Qds-evap+gagediffportion(:,sr);
    Qds=max(0,Qds);

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
    if savefinalmatfile==1
        logm=['Writing final calibration loop binary, its a big file, starting:' datestr(now)];
        domessage(logm,logfilename,displaymessage,writemessage)

        save([datadir 'StateTL_out_allcal.mat'],'SR','WDcaliblist','ds','datestid','dateendid','rsteps');
        
        logm=['Finished writing final calibration loop binary at:' datestr(now)];
        domessage(logm,logfilename,displaymessage,writemessage)

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
        titledates=cellstr(datestr(rdates(datestid:dateendid),'mm/dd/yy HH:'));
        writecell([titlelocline,titledates'],[outputfilebase '_riverhr.csv']);
        writecell([titlelocline,titledates'],[outputfilebase '_nativehr.csv']);
        writecell([titlelocline,titledates'],[outputfilebase '_gagediffhr.csv']);
        writecell([titlelocline,titledates'],[outputfilebase '_sraddhr.csv']);
        writecell([titlelocline,titledates'],[outputfilebase '_totwcreducehr.csv']);
        if runcaptureloop>0
        writecell([titlelocline,titledates'],[outputfilebase '_nativecapturehr.csv']);
        end
    end
    if outputday==1
        [yr,mh,dy,hr,mi,sec] = datevec(rdates(datestid:dateendid));
        daymat=unique([yr,mh,dy],'rows','stable');
        titledatesday=cellstr(datestr([daymat zeros(size(daymat))],'mm/dd/yy'));
        writecell([titlelocline,titledatesday'],[outputfilebase '_riverday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilebase '_nativeday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilebase '_gagediffday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilebase '_sraddday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilebase '_totwcreduceday.csv']);
        if runcaptureloop>0
        writecell([titlelocline,titledatesday'],[outputfilebase '_nativecaptureday.csv']);
        end
    end
    for i=1:length(SR.(ds).Rivloc.loc(:,1))
        loclineriver(2*i-1,:)=[SR.(ds).Rivloc.loc(i,5),SR.(ds).Rivloc.loc(i,1:4),{2}];  %includes both ds/us sides of wdids and reaches - us of reach is ds of uswdid
        loclineriver(2*i,:)=  [SR.(ds).Rivloc.loc(i,6),SR.(ds).Rivloc.loc(i,1:4),{1}];
%        outputlineriver(2*i-1,:)=SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).Qus(datest:end,SR.(ds).Rivloc.loc{i,4})';
%        outputlineriver(2*i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).Qds(datest:end,SR.(ds).Rivloc.loc{i,4})';
        outputlineriver(2*i-1,:)=SR.(ds).Rivloc.flowriv.us(datestid:dateendid,i)';
        outputlinenative(2*i-1,:)=SR.(ds).Rivloc.flownative.us(datestid:dateendid,i)';
        outputlineriver(2*i,:)=SR.(ds).Rivloc.flowriv.ds(datestid:dateendid,i)';
        outputlinenative(2*i,:)=SR.(ds).Rivloc.flownative.ds(datestid:dateendid,i)';
        outputlinesradd(2*i-1,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).sraddamtus(datestid:dateendid,SR.(ds).Rivloc.loc{i,4})';
        outputlinesradd(2*i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).sraddamtds(datestid:dateendid,SR.(ds).Rivloc.loc{i,4})';
        if runcaptureloop>0
        outputlinenativecapture(2*i-1,:)=SR.(ds).Rivloc.flownativecapture.us(datestid:dateendid,i)';
        outputlinenativecapture(2*i,:)=SR.(ds).Rivloc.flownativecapture.ds(datestid:dateendid,i)';
        end

        outputlinetotwcreduce(2*i-1,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).wcreduceamt(datestid:dateendid,SR.(ds).Rivloc.loc{i,4})';
        if SR.(ds).Rivloc.loc{i,4}==SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).SR(end)
            outputlinetotwcreduce(2*i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).wcreduceamtlast(datestid:dateendid,1)';
        else
          outputlinetotwcreduce(2*i,:)=zeros(length(yr),1);
        end

%        loclinereach(i,:)=  [SR.(ds).Rivloc.loc(i,6),SR.(ds).Rivloc.loc(i,1:4),{1}];  %this will list the dswdid with a 1 to say upstream of wdid 
        loclinereach(i,:)=  [SR.(ds).Rivloc.loc(i,5),SR.(ds).Rivloc.loc(i,1:4),{2}];  %this will list the uswdid with a 2 to say downstream of wdid 
        outputlinegagediff(i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).gagediffportion(datestid:dateendid,SR.(ds).Rivloc.loc{i,4})';
%        outputlinetotwcreduce(i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).wcreduceamt(datest:end,SR.(ds).Rivloc.loc{i,4})';
%        outputlineSRadd(i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).QSRadd(datest:end,SR.(ds).Rivloc.loc{i,4})';

    end
    if outputhr==1
        logm=['writing hourly output files for river/native amounts (hourly is a bit slow), starting: ' datestr(now)];
        domessage(logm,logfilename,displaymessage,writemessage)
        writecell([loclineriver,num2cell(outputlineriver)],[outputfilebase '_riverhr.csv'],'WriteMode','append');
        writecell([loclineriver,num2cell(outputlinenative)],[outputfilebase '_nativehr.csv'],'WriteMode','append');
        writecell([loclinereach,num2cell(outputlinegagediff)],[outputfilebase '_gagediffhr.csv'],'WriteMode','append');
        writecell([loclineriver,num2cell(outputlinesradd)],[outputfilebase '_sraddhr.csv'],'WriteMode','append');
        writecell([loclineriver,num2cell(outputlinetotwcreduce)],[outputfilebase '_totwcreducehr.csv'],'WriteMode','append');
        if runcaptureloop>0
        writecell([loclineriver,num2cell(outputlinenativecapture)],[outputfilebase '_nativecapturehr.csv'],'WriteMode','append');
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
            if runcaptureloop>0
            outputlinedaynativecapture(:,i)=mean(outputlinenativecapture(:,dayids),2);
            end
        end
        writecell([loclineriver,num2cell(outputlinedayriver)],[outputfilebase '_riverday.csv'],'WriteMode','append');        
        writecell([loclineriver,num2cell(outputlinedaynative)],[outputfilebase '_nativeday.csv'],'WriteMode','append');
        writecell([loclinereach,num2cell(outputlinedaygagediff)],[outputfilebase '_gagediffday.csv'],'WriteMode','append');        
        writecell([loclineriver,num2cell(outputlinedaysradd)],[outputfilebase '_sraddday.csv'],'WriteMode','append');        
        writecell([loclineriver,num2cell(outputlinedaytotwcreduce)],[outputfilebase '_totwcreduceday.csv'],'WriteMode','append');        
        if runcaptureloop>0
        writecell([loclineriver,num2cell(outputlinedaynativecapture)],[outputfilebase '_nativecaptureday.csv'],'WriteMode','append');
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
    titledates=cellstr(datestr(rdates(datestid:dateendid),'mm/dd/yy HH:'));
    writecell([titlelocline,titledates'],[outputfilebase '_wchr.csv']);
    writecell([titlelocline,titledates'],[outputfilebase '_wcsraddhr.csv']);
    writecell([titlelocline,titledates'],[outputfilebase '_wcreducehr.csv']);
    if runcaptureloop>0
    writecell([titlelocline,titledates'],[outputfilebase '_wccapturehr.csv']);
    end
end
if outputday==1
    logm=['writing daily output file by water class amounts, starting: ' datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)
    [yr,mh,dy,hr,mi,sec] = datevec(rdates(datestid:dateendid));
    daymat=unique([yr,mh,dy],'rows','stable');
    titledatesday=cellstr(datestr([daymat zeros(size(daymat))],'mm/dd/yy'));
    writecell([titlelocline,titledatesday'],[outputfilebase '_wcday.csv']);
    writecell([titlelocline,titledatesday'],[outputfilebase '_wcreduceday.csv']);
    writecell([titlelocline,titledatesday'],[outputfilebase '_wcsraddday.csv']);
    if runcaptureloop>0
    writecell([titlelocline,titledatesday'],[outputfilebase '_wccaptureday.csv']);
    end
end


for w=1:length(wwcnums)
    ws=wwcnums{w};
    clear loclinewc outputlinewc outputlinedaywc outputlinewcsradd outputlinedaywcsradd outputlinewcreduce outputlinedaywcreduce loclinewcreduce outputlinewccapture outputlinedaywccapture
    outwcreduce=0;k=0;
    for i=1:length(SR.(ds).WCloc.(ws).loc(:,1))  %JVO said wanted both us and ds of WDID (??) - OK then
        if SR.(ds).WCloc.(ws).loc{i,6}==1 %release - list from us to ds
           loclinewc(2*i-1,:)=[{ws},{SR.(ds).WCloc.(ws).wc},SR.(ds).WCloc.(ws).loc(i,7),SR.(ds).WCloc.(ws).loc(i,1:4),{2}];
           outputlinewc(2*i-1,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).Qusrelease(datestid:dateendid,SR.(ds).WCloc.(ws).loc{i,4})';
           loclinewc(2*i,:)=[{ws},{SR.(ds).WCloc.(ws).wc},SR.(ds).WCloc.(ws).loc(i,8),SR.(ds).WCloc.(ws).loc(i,1:4),{1}];
           outputlinewc(2*i,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).Qdsrelease(datestid:dateendid,SR.(ds).WCloc.(ws).loc{i,4})';
           outputlinewcsradd(2*i-1,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).QSRaddus(datestid:dateendid,SR.(ds).WCloc.(ws).loc{i,4})';
           outputlinewcsradd(2*i,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).QSRaddds(datestid:dateendid,SR.(ds).WCloc.(ws).loc{i,4})';
                      
           if isfield(SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws),'wcreduceamt')
               outwcreduce=1;k=k+1;
                loclinewcreduce(k,:)=[{ws},{SR.(ds).WCloc.(ws).wc},SR.(ds).WCloc.(ws).loc(i,7),SR.(ds).WCloc.(ws).loc(i,1:4),{2}]; %lists usreach/ds wdid
                outputlinewcreduce(k,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).wcreduceamt(datestid:dateendid,SR.(ds).WCloc.(ws).loc{i,4})';
                if R.(ds).WCloc.(ws).loc{i,4}==SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).SR(end)
                    k=k+1;
                    loclinewcreduce(k,:)=[{ws},{SR.(ds).WCloc.(ws).wc},SR.(ds).WCloc.(ws).loc(i,7),SR.(ds).WCloc.(ws).loc(i,1:4),{1}]; %lists dsreach/us wdid
                    outputlinewcreduce(k,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).wcreduceamtlast(datestid:dateendid,1)';
                end
           end
           
        else  %exchange - list from ds to us - if ok from us to ds could delete these
           loclinewc(2*i-1,:)=[{ws},{SR.(ds).WCloc.(ws).wc},SR.(ds).WCloc.(ws).loc(i,8),SR.(ds).WCloc.(ws).loc(i,1:4),{1}];
           outputlinewc(2*i-1,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).Qdsrelease(datestid:dateendid,SR.(ds).WCloc.(ws).loc{i,4})';
           loclinewc(2*i,:)=[{ws},{SR.(ds).WCloc.(ws).wc},SR.(ds).WCloc.(ws).loc(i,7),SR.(ds).WCloc.(ws).loc(i,1:4),{2}];
           outputlinewc(2*i,:)=SR.(ds).(SR.(ds).WCloc.(ws).loc{i,2}).(SR.(ds).WCloc.(ws).loc{i,3}).(ws).Qusrelease(datestid:dateendid,SR.(ds).WCloc.(ws).loc{i,4})';
           outputlinewcsradd(2*i-1,:)=zeros(1,runsteps);
           outputlinewcsradd(2*i,:)=zeros(1,runsteps);   
        end
        
           %this is repeating wc output but changing to capture amount at destination.. need/want??
           %if remove above switch for exchanges would need to switch where captureamt placed for exchanges
           if runcaptureloop>0
           if i==length(SR.(ds).WCloc.(ws).loc(:,1))
               outputlinewccapture(2*i-1,:)=outputlinewc(2*i-1,:);
               outputlinewccapture(2*i,:)=SR.(ds).WCloc.(ws).captureamt(datestid:dateendid,:)';
           else
               outputlinewccapture(2*i-1,:)=outputlinewc(2*i-1,:);
               outputlinewccapture(2*i,:)=outputlinewc(2*i,:);
           end
           end
        
    end 
    
    if outputhr==1
        writecell([loclinewc,num2cell(outputlinewc)],[outputfilebase '_wchr.csv'],'WriteMode','append');
        writecell([loclinewc,num2cell(outputlinewcsradd)],[outputfilebase '_wcsraddhr.csv'],'WriteMode','append');
        if runcaptureloop>0
        writecell([loclinewc,num2cell(outputlinewccapture)],[outputfilebase '_wccapturehr.csv'],'WriteMode','append');
        end
           if outwcreduce==1
                writecell([loclinewcreduce,num2cell(outputlinewcreduce)],[outputfilebase '_wcreducehr.csv'],'WriteMode','append');
           end
    end

    if outputday==1
        for i=1:length(daymat(:,1))
            dayids=find(yr==daymat(i,1) & mh==daymat(i,2) & dy==daymat(i,3));
            outputlinedaywc(:,i)=mean(outputlinewc(:,dayids),2);
            outputlinedaywcsradd(:,i)=mean(outputlinewcsradd(:,dayids),2);
            if runcaptureloop>0
            outputlinedaywccapture(:,i)=mean(outputlinewccapture(:,dayids),2);
            end
           if outwcreduce==1
                outputlinedaywcreduce(:,i)=mean(outputlinewcreduce(:,dayids),2);
           end
        end
        writecell([loclinewc,num2cell(outputlinedaywc)],[outputfilebase '_wcday.csv'],'WriteMode','append');        
        writecell([loclinewc,num2cell(outputlinedaywcsradd)],[outputfilebase '_wcsraddday.csv'],'WriteMode','append');
        if runcaptureloop>0
        writecell([loclinewc,num2cell(outputlinedaywccapture)],[outputfilebase '_wccaptureday.csv'],'WriteMode','append');
        end
        if outwcreduce==1
            writecell([loclinewcreduce,num2cell(outputlinedaywcreduce)],[outputfilebase '_wcreduceday.csv'],'WriteMode','append');             
        end
    end
end

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OUTPUT - comparison of gage and simulated amounts at gage
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%

if outputcal==1 & runcalibloop>0
    logm=['Starting output of files listing just at gage locations at: ' datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)

    titlelocline=[{'WDID'},{'Abbrev'},{'Div'},{'WD'},{'Reach'},{'ReachNum'},{'1-Gage/2-Sim'}];
    if outputhr==1
%        titledates=cellstr(datestr(rdates(datestid:dateendid),'mm/dd/yy HH:'));
        titledates=cellstr(datestr(rdates(calibstid:calibendid),'mm/dd/yy HH:'));
        writecell([titlelocline,titledates'],[outputfilebase '_calhr.csv']);
        

    end
    if outputday==1
%        [yr,mh,dy,hr,mi,sec] = datevec(rdates(datestid:dateendid));
        [yr,mh,dy,hr,mi,sec] = datevec(rdates(calibstid:calibendid));
        daymat=unique([yr,mh,dy],'rows','stable');
        titledatesday=cellstr(datestr([daymat zeros(size(daymat))],'mm/dd/yy'));
        writecell([titlelocline,titledatesday'],[outputfilebase '_calday.csv']);
        if plotcalib==1
            k=0;
            for i=daymat(1,2):daymat(end,2)
                k=k+1;
                dids=find(daymat(:,2)==i);
                dxtic(k)=dids(1);
                dxticlabel{k}=[num2str(i) '/' num2str(daymat(dids(1),3))];
            end
            k=0;
            for i=mh(1):mh(end)
                k=k+1;
                dids=find(mh==i);
                hrxtic(k)=dids(1);
                hrxticlabel{k}=[num2str(i) '/' num2str(dy(dids(1)))];
            end
        end
    end

    if outputcalregr==1
        titleregrline=[{'m-hour'},{'R2-hour'},{'SEE-hour'},{'m-day'},{'R2-day'},{'SEE-day'}];
        writecell([titlelocline(1:end-1),titleregrline],[outputfilebase '_calstats.csv']);
    end
    iadd=0;
    for wd=WDcaliblist
        wds=['WD' num2str(wd)];
        wdsids=intersect(find(strcmp(SR.(ds).Gageloc.loc(:,1),ds)),find(strcmp(SR.(ds).Gageloc.loc(:,2),wds)));
        wdsids=intersect(wdsids,find(strcmp(SR.(ds).Gageloc.loc(:,7),'1')));

        for i=1:length(wdsids)
            j=wdsids(i);
%             loclinegage(2*(i+iadd)-1,:)=[SR.(ds).Gageloc.loc(j,5:6),SR.(ds).Gageloc.loc(j,1:4),{1}];  %includes both gage and simulated on subseqent lines
%             loclinegage(2*(i+iadd),:)=  [SR.(ds).Gageloc.loc(j,5:6),SR.(ds).Gageloc.loc(j,1:4),{2}];
            loclinegage(i+iadd,:)=  [SR.(ds).Gageloc.loc(j,5:6),SR.(ds).Gageloc.loc(j,1:4),{2}];
            x=SR.(ds).Gageloc.flowgage(calibstid:calibendid,j);
            y=SR.(ds).Gageloc.flowcal(calibstid:calibendid,j);
%             outputlinegage(2*(i+iadd)-1,:)=x';
%             outputlinegage(2*(i+iadd),:)=y';
            outputlinegage(i+iadd,:)=x';
            outputlinecal(i+iadd,:)=y';
            if outputcalregr==1
                [yfit,m,b,R2,SEE]=regr(x,y,'leastsquares');
                loclinegageregr(i+iadd,:)=[SR.(ds).Gageloc.loc(j,5:6),SR.(ds).Gageloc.loc(j,1:4)];
                outputlinegageregr(i+iadd,1)=m;
                outputlinegageregr(i+iadd,2)=R2;
                outputlinegageregr(i+iadd,3)=SEE;
                if plotcalib==1
                    tit=[loclinegageregr{i+iadd,1} '-' loclinegageregr{i+iadd,2}];
                    figure; hold on;
                    figmin=min([min(x),min(y)]);
                    figmax=max([max(x),max(y),1]);
                    plot(x,'b','LineWidth',1); hold on;
                    plot(y,'r','LineWidth',1)
                    set(gca,'XLim',[1 length(x)],'YLim',[figmin figmax],'Box','on')
                    title(['Gage and Sim Hourly Data-' tit ' blue=gage/red=sim'])
                    ylabel('Observed Simulated Flow Rate (cfs)')
                    if outputday==1  %since only do tic calc in daily above
                        set(gca,'XTick',hrxtic,'XTickLabel',hrxticlabel)
                        xlabel(['Dates in ' num2str(yearstart)])
                    else
                        xlabel('Hours since start of calibration')
                    end

                    if printcalibplots==1
                        eval(['print -dpng -r200 ' datadir 'calibhour1_fig' num2str(i+iadd) '_' tit])
                        close
                    end
                    figure; hold on;
                    plot(x,y,'b.');
                    plot([min(x) max(x)],[m*min(x) m*max(x)])
                    text(.7*max(x),.9*max(y),['R2:' num2str(R2) '-m:' num2str(m)])
                    title(['Gage(x) vs Sim(y) Hourly Data-' tit]);
                    xlabel('Observed (Gage) Hourly Data (cfs)')
                    ylabel('Simulated Hourly Data (cfs)')
                    if printcalibplots==1
                        eval(['print -dpng -r200 ' datadir 'calibhour2_fig' num2str(i+iadd) '_' tit])
                        close
                    end
                end
            end
        end
        iadd=i;
    end
    if outputhr==1
        logm=['writing hourly output files for gage and simulated (calibration) amounts (hourly is a bit slow), starting: ' datestr(now)];
        domessage(logm,logfilename,displaymessage,writemessage)
%        writecell([loclinegage,num2cell(outputlinegage)],[outputfilebase '_calhr.csv'],'WriteMode','append');
        writecell([loclinegage,num2cell(outputlinecal)],[outputfilebase '_calhr.csv'],'WriteMode','append');
    end
    if outputday==1 || outputcalregr==1
        logm=['writing daily output files for gage and simulated (calibration) amounts, starting: ' datestr(now)];
        domessage(logm,logfilename,displaymessage,writemessage)
        for i=1:length(daymat(:,1))
            dayids=find(yr==daymat(i,1) & mh==daymat(i,2) & dy==daymat(i,3));
            outputlinedaygage(:,i)=mean(outputlinegage(:,dayids),2);
            outputlinedaycal(:,i)=mean(outputlinecal(:,dayids),2);
        end
        if outputday==1
%            writecell([loclinegage,num2cell(outputlinedaygage)],[outputfilebase '_calday.csv'],'WriteMode','append');
            writecell([loclinegage,num2cell(outputlinedaycal)],[outputfilebase '_calday.csv'],'WriteMode','append');
        end
        if outputcalregr==1
        iadd=0;
        for wd=WDcaliblist
        wds=['WD' num2str(wd)];
        wdsids=intersect(find(strcmp(SR.(ds).Gageloc.loc(:,1),ds)),find(strcmp(SR.(ds).Gageloc.loc(:,2),wds)));
        wdsids=intersect(wdsids,find(strcmp(SR.(ds).Gageloc.loc(:,7),'1')));
            for i=1:length(wdsids)
%                 x=outputlinedaygage(2*(i+iadd)-1,:)';
%                 y=outputlinedaygage(2*(i+iadd),:)';
                x=outputlinedaygage(i+iadd,:)';
                y=outputlinedaycal(i+iadd,:)';
                [yfit,m,b,R2,SEE]=regr(x,y,'leastsquares');
                outputlinegageregrday(i+iadd,1)=m;
                outputlinegageregrday(i+iadd,2)=R2;
                outputlinegageregrday(i+iadd,3)=SEE;
                if plotcalib==1
                    tit=[loclinegageregr{i+iadd,1} '-' loclinegageregr{i+iadd,2}];
                    figure; hold on;
                    figmin=min([min(x),min(y)]);
                    figmax=max([max(x),max(y),1]);
                    plot(x,'b','LineWidth',1); hold on;
                    plot(y,'r','LineWidth',1)
                    set(gca,'YLim',[figmin figmax],'Box','on')
                    title(['Gage and Sim Daily Data-' tit ' blue=gage/red=sim'])
                    set(gca,'XTick',dxtic,'XTickLabel',dxticlabel)
                    xlabel(['Dates in ' num2str(yearstart)])
                    ylabel('Observed Simulated Flow Rate (cfs)')
                    if printcalibplots==1
                        eval(['print -dpng -r200 ' datadir 'calibday1_fig' num2str(i+iadd) '_' tit])
                        close
                    end
                    figure; hold on;
                    plot(x,y,'b.');
                    plot([min(x) max(x)],[m*min(x) m*max(x)])
                    text(.7*max(x),.9*max(y),['R2:' num2str(R2) '-m:' num2str(m)])
                    
                    title(['Gage(x) vs Sim(y) Daily Data-' tit]);
                    xlabel('Observed (Gage) Daily Data (cfs)')
                    ylabel('Simulated Daily Data (cfs)')
                    if printcalibplots==1
                        eval(['print -dpng -r200 ' datadir 'calibday2_fig' num2str(i+iadd) '_' tit])
                        close
                    end
                end
            end
            iadd=i;
        end
            writecell([loclinegageregr,num2cell(outputlinegageregr),num2cell(outputlinegageregrday)],[outputfilebase '_calstats.csv'],'WriteMode','append');
        end
    end
end
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OUTPUT - output of river network file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if outputnet==1
    logm=['Starting output of network file with spatial info: ' datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)

    rivcell=SR.(ds).SRfull; %if want to use SR sorted/reduced to WDlist then remove full
    titleline=[{'US-WDID'},{'DS-WDID'},{'Div'},{'WD'},{'Reach'},{'SubReach'},{'Divstr'},{'WDstr'},{'Reachstr'},{'Type'},...
        {'USWDIDname'},{'DSWDIDname'},{'channellength'},{'alluviumlength'},{'reachportion'},...
        {'US-utmx'},{'US-utmy'},{'US-lat'},{'US-lon'},{'DS-utmx'},{'DS-utmy'},{'DS-lat'},{'DS-lon'},{'mid-utmx'},{'mid-utmy'},{'mid-lat'},{'mid-lon'}];

    for i=1:length(rivcell(:,1))
        ds=rivcell{i,7};
        wds=rivcell{i,8};
        rs=rivcell{i,9};
        sr=rivcell{i,6};
        k=11;
        rivcell(i,k)=SR.(ds).(wds).(rs).name(sr);k=k+1;
        rivcell(i,k)=SR.(ds).(wds).(rs).dsname(sr);k=k+1;
        rivcell{i,k}=SR.(ds).(wds).(rs).channellength(sr);k=k+1;
        rivcell{i,k}=SR.(ds).(wds).(rs).alluviumlength(sr);k=k+1;
        rivcell{i,k}=SR.(ds).(wds).(rs).reachportion(sr);k=k+1;
        rivcell{i,k}=SRloc.(ds).(wds).(rs).usutmx(sr);k=k+1;
        rivcell{i,k}=SRloc.(ds).(wds).(rs).usutmy(sr);k=k+1;
        rivcell{i,k}=SRloc.(ds).(wds).(rs).uslat(sr);k=k+1;
        rivcell{i,k}=SRloc.(ds).(wds).(rs).uslon(sr);k=k+1;
        rivcell{i,k}=SRloc.(ds).(wds).(rs).dsutmx(sr);k=k+1;
        rivcell{i,k}=SRloc.(ds).(wds).(rs).dsutmy(sr);k=k+1;
        rivcell{i,k}=SRloc.(ds).(wds).(rs).dslat(sr);k=k+1;
        rivcell{i,k}=SRloc.(ds).(wds).(rs).dslon(sr);k=k+1;
        rivcell{i,k}=SRloc.(ds).(wds).(rs).utmx(sr);k=k+1;
        rivcell{i,k}=SRloc.(ds).(wds).(rs).utmy(sr);k=k+1;
        rivcell{i,k}=SRloc.(ds).(wds).(rs).lat(sr);k=k+1;
        rivcell{i,k}=SRloc.(ds).(wds).(rs).lon(sr);k=k+1;
    end
    writecell([titleline;rivcell],[outputfilebase '_network.csv']);
end



% Delete copied datafiles - primarily for calibration
% if command lines args: folder and calibration and copydatefiles==1 - then redelete those data files...
if sum(strcmp(cmdlineargs,'f')) && sum(strcmp(cmdlineargs,'c')) && copydatafiles==1
    logmc=[logmc;'Deleting previously copied datafiles from: ' datafiledir ' starting:' datestr(now)];
    delete([datafiledir 'StateTL_data_subreach.mat']);
    delete([datafiledir 'StateTL_data_evap.mat']);
    delete([datafiledir 'StateTL_data_networklocs.mat']);
    delete([datafiledir 'StateTL_data_stagedis.mat']);
    delete([datafiledir 'StateTL_data_qnode.mat']);
    delete([datafiledir 'StateTL_data_release.mat']);
end


%%

%%%%%%%%%%%%%%%%%%%%%
% END of mainline script

logm=['Done Running StateTL endtime: ' datestr(now) ' elapsed (DD:HH:MM:SS): ' datestr(now-runstarttime,'DD:HH:MM:SS')];    %log message
if displaymessage~=1;disp(logm);end
domessage(logm,logfilename,displaymessage,writemessage)

if endmusic==1
    load(musicfile);
%     sound(y, Fs);
%     sound(y, 2*Fs);
    sound(y(1:floor(length(y)/2)), Fs);
end

% if ~isdeployed
% msgbox(logm,'StateTL - Colors of Water Model Engine')
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% deployed as function with following end statement

%end %StateTL as deployed function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% runbank - function that may replace j349 functionality
% simple version doesnt consider gains and evap and Qds as part of bankflow calculation
% first determines bankflow based on stage changes, 

function [Qds,celerity,dispersion,stage,Qdstail]=runbank(ds,wds,rs,sr,Qus,rhours,rsteps,celerity,dispersion,upstage)
global SR
minc=1;
if nargin==9
    upstage=0;
end

sd=SR.(ds).stagedischarge.(['SD' num2str(SR.(ds).(wds).(rs).sdnum(sr))]);
sdlen=length(sd(:,1));
bankurf=SR.(ds).(wds).(rs).bankurf{sr};
urflen=length(bankurf);

% conversion from stage to flow,
% to about equal J349, found flow= changeS(ft)*alluviumlength(mi)*5280*2*aquiferwidth(ft)*storagecoff/(dt*3600) (although j349 never used alluvium length and storagecoeff)
%bankurf=bankurf*SR.(ds).(wds).(rs).alluviumlength(sr)*5280*2*SR.(ds).(wds).(rs).aquiferwidth(sr)*SR.(ds).(wds).(rs).storagecoefficient(sr)/(rhours*3600);

Qds=Qus;

for j=1:1
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % interpolate stage from Q
    Qavg=(max(Qus,minc)+max(Qds,minc))/2;
if upstage==1
    posids=find(Qus(:,1)>0);
    Qfullavg=mean(SR.(ds).(wds).(rs).Qus(posids,sr));
    Qusavg=mean(Qus(posids,1));
    Qadd=max(0,Qfullavg-Qusavg);
    for i=1:length(Qus)
        sdids=find(sd(:,2)<=(Qus(i)+Qadd));
        sdid=sdids(end);
        stage(i)=(sd(min(sdlen,sdid+1),1)-sd(sdid,1))/(sd(min(sdlen,sdid+1),2)-sd(sdid,2))*((Qus(i)+Qadd)-sd(sdid,2))+sd(sdid,1);
    end

elseif upstage==2
%    Qfull=(max(SR.(ds).(wds).(rs).Qus(:,sr),minc)+max(SR.(ds).(wds).(rs).Qds(:,sr),minc))/2;
    Qfull=max(SR.(ds).(wds).(rs).Qus(:,sr),minc);
    stagefull=SR.(ds).(wds).(rs).stage(:,sr);
    stage=stagefull.*Qus./Qfull;
elseif upstage==3
    Qfull=(max(SR.(ds).(wds).(rs).Qus(:,sr),minc)+max(SR.(ds).(wds).(rs).Qds(:,sr),minc))/2;
    Quspartial=Qfull-Qavg;
    for i=1:length(Qus)
        sdids=find(sd(:,2)<=Quspartial(i));
        sdid=sdids(end);
        stage1(i)=(sd(min(sdlen,sdid+1),1)-sd(sdid,1))/(sd(min(sdlen,sdid+1),2)-sd(sdid,2))*(Quspartial(i)-sd(sdid,2))+sd(sdid,1);
        sdids=find(sd(:,2)<=Qfull(i));
        sdid=sdids(end);
        stage2(i)=(sd(min(sdlen,sdid+1),1)-sd(sdid,1))/(sd(min(sdlen,sdid+1),2)-sd(sdid,2))*(Qfull(i)-sd(sdid,2))+sd(sdid,1);
        stage(i)=max(0,stage2(i)-stage1(i));
    end
else
    for i=1:length(Qus)
        sdids=find(sd(:,2)<=Qus(i));
        sdid=sdids(end);
        stage(i)=(sd(min(sdlen,sdid+1),1)-sd(sdid,1))/(sd(min(sdlen,sdid+1),2)-sd(sdid,2))*(Qavg(i)-sd(sdid,2))+sd(sdid,1);
    end
end


changeS(2:rsteps)=stage(2:rsteps)-stage(1:rsteps-1);
changeQ(2:rsteps)=Qus(2:rsteps)-Qus(1:rsteps-1);
bankflow=zeros(rsteps+urflen,1);
for i=2:rsteps
    if changeS(i)~=0
    lag=changeS(i)*bankurf(:,1);
    %spike control - flow rate into bank shouldnt exceed change in actual flow rate causing increase in stage - but not sure if doing anything now at this point
    if changeS(i)>0  %increase in stage / flow into bank
        for ii=1:urflen
            if lag(ii)>changeQ(i)
                lag(ii)=changeQ(i);
            else
                break
            end
        end
    else             %decrease in stage / flow out of bank
        for ii=1:urflen
            if lag(ii)<changeQ(i)
                lag(ii)=changeQ(i);
            else
                break
            end
        end
    end
    bankflow(i:i+urflen-1,1)=bankflow(i:i+urflen-1,1)+lag;
    end
end

Qdsbank=Qus-bankflow(1:rsteps,1);
Qdstail=sum(bankflow(rsteps+1:end,1));

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% route Qus after bankflow to Qds location
% if celerity==-999
%     Qavg=(max(Qus,minc)+max(Qdsbank,minc))/2;
%     [celerity,dispersion]=calcceleritydisp(Qavg,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),1);
% end
% % longer series to capture muskingham tail
% Qdsbanklong=Qdsbank(end)*ones(rsteps+24*7,1);
% Qdsbanklong(1:rsteps,1)=Qdsbank(1:rsteps,1);
% celeritylong=celerity(end)*ones(rsteps+24*7,1);
% celeritylong(1:rsteps,1)=celerity(1:rsteps,1);
% dispersionlong=dispersion(end)*ones(rsteps+24*7,1);
% dispersionlong(1:rsteps,1)=dispersion(1:rsteps,1);
% [Qdsm,celerityt,dispersiont]=runmuskingum(ds,wds,rs,sr,Qdsbanklong,rhours,rsteps+24*7,celeritylong,dispersionlong);
%Qds=Qdsm(1:rsteps);
%Qdstail=sum(Qdsm(rsteps+1:end,1))-Qdstail;

[Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qdsbank,rhours,rsteps,celerity,dispersion);

end




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

function [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,celerity,dispersion,stub)
global SR

if nargin==9
    stub=0;
end

minc=1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% adding extra time to add to end to then ensure that sum(Qds)=sum(Qus)
% problem with this is that musk is will correct at bad spike but then unitization will spread that out
%radd=200;  % 200 will handle 50miles at 2/200 celerity/dispersion
%Qus=[Qus;Qus(end)*ones(radd,1)];

%posids=find(Qus>0);        %at least for wc releases this limits to release times; could potentially have celerity time series as time ser..
%Qusavg=mean(Qus(posids));  %orig single celerity / as add to time series length - may need to do this on smaller time steps??

%when commented out above; trying celerity/dispersion as time series ... NOT SURE IF CORRECT TO DO WITH CHANGING CELERITY/DISPERSION??
% negids=find(Qus<0); - %commenting these two out for speed but may want in for safety
% Qus(negids)=0;

if stub==0
    channellength=SR.(ds).(wds).(rs).channellength(sr);    
else
    channellength=SR.(ds).(wds).(rs).stublength(sr);
end


if celerity==-999
    celerityts=1; %indicating time series of celerity values
    [celerity,dispersion]=calcceleritydisp(Qus,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),celerityts);
% elseif length(celerity)==rsteps
%     celerity=[celerity;celerity(end)*ones(radd,1)];
%     dispersion=[dispersion;dispersion(end)*ones(radd,1)];
elseif length(celerity)==1
    celerity=celerity*ones(rsteps,1);
    dispersion=dispersion*ones(rsteps,1);
%     celerity=celerity*ones(rsteps+radd,1);
%     dispersion=dispersion*ones(rsteps+radd,1);
end


%Muskinghum-Cunge parameters
dt=rhours * 60 * 60; %sec
dx=channellength * 5280; %ft
X = 1/2 - dispersion ./ (celerity * dx);
Cbot = 2 * (1-X) + celerity *(dt/dx);
C0 = (celerity * (dt/dx) - 2 * X) ./ Cbot;
C1 = (celerity * (dt/dx) + 2 * X) ./ Cbot;
C2 = ( 2 * (1-X) - celerity * (dt/dx)) ./ Cbot;

%Qds=ones(rsteps+radd,1);
Qds=ones(rsteps,1);
Qds(1,1) = Qus(1,1);


for n=1:rsteps-1  %Muskinghum-Cunge Routing
    Qds (n+1,1) = (C0(n,1) * Qus (n+1,1)) + (C1(n,1) * Qus (n,1)) + C2(n,1) * Qds(n,1);

    %correction to tamp down spike that occurs at steps in flow
    if C0(n,1) <= 0
        if Qus (n+1,1) > Qus (n,1)
            Qds (n+1,1) = max(Qds(n,1),Qds(n+1,1));
        elseif Qus (n+1,1) < Qus (n,1)
            Qds (n+1,1) = min(Qds(n,1),Qds(n+1,1));
        end
    elseif C2(n,1)<=0 && n>1
        if Qus (n,1) > Qus (n-1,1)
            Qds (n+1,1) = min(Qus(n+1,1),Qds(n+1,1));
        elseif Qus (n,1) < Qus (n-1,1)
            Qds (n+1,1) = max(Qus(n+1,1),Qds(n+1,1));
        end
    end

end

% Qds=sum(Qus)/sum(Qds)*Qds(1:rsteps,1);
% celerity=celerity(1:rsteps,1);
% dispersion=dispersion(1:rsteps,1);

% SC=celerity*dt;SC2=SC*SC;SK=dispersion*dt;XFT=channellength*5280;
% srtime=XFT/SC+2*SK/SC2-(2.78*sqrt(2*SK*XFT/(SC2*SC)+(8*SK/SC2)*(SK/SC2))); %from j349 - time to first response

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%function for subreach to take upstream hydrograph and subreach specific data, build input card, 
%run TLAP/j349 fortran, read output card, and return resulting downstream hydrograph

function [Qds,celerity,dispersion,Qmin,Qmax,logm]=runj349f(ds,wds,rs,sr,Qus,Qdsin,gain,rdays,rhours,rsteps,j349dir,celerity,dispersion,j349multurf,Qmin,Qmax,j349fast)
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
minj349=1; %this is repeated from above, may want to pass into function

channellength=SR.(ds).(wds).(rs).channellength(sr);
alluviumlength=SR.(ds).(wds).(rs).alluviumlength(sr);
transmissivity=SR.(ds).(wds).(rs).transmissivity(sr);
storagecoefficient=SR.(ds).(wds).(rs).storagecoefficient(sr);
aquiferwidth=SR.(ds).(wds).(rs).aquiferwidth(sr);
closure=SR.(ds).(wds).(rs).closure(sr);
urfthreshold=SR.(ds).(wds).(rs).urfthreshold(sr);


if j349multurf==0 || urfthreshold==-999  %single urf linearization
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
    celerityts=1; %indicating time series of celerity values
    if Qmin==-999
        Qmin=min(Qus);Qmax=max(Qus);  %what if bad spikes in Q?
        if Qmin==Qmax
            Qmax=Qmin+1;
        end
    end
    qcdrepl=0;
    if Qmax<=urfthreshold  %if Qmax below urfthreshold (ie threshold prob set too high) run as single urf
        Qmult=urfthreshold;
        j349multurf=0;
        celerityts=0;
    elseif Qmin>=urfthreshold  %Qmin larger than threshold
        Qmulta=(Qmax-Qmin)/(qckmultnum-2);
        Qmult=[urfthreshold Qmin:Qmulta:Qmax];
    else
        Qmulta=(Qmax-urfthreshold)/(qckmultnum-2);
        Qmult=[minj349 urfthreshold:Qmulta:Qmax];
        qcdrepl=1;
    end
    [celeritymult,dispersionmult]=calcceleritydisp(Qmult,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),celerityts);
    if qcdrepl==1
        celeritymult(1)=celeritymult(2);
        dispersionmult(1)=dispersionmult(2);
    end

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

srtitlefull='                    ';
srtitlepart=[ds ' ' wds ' ' rs ' SR' num2str(sr)];
srtitlefull(1:length(srtitlepart))=srtitlepart;

fid=fopen([j349dir inputcardfilename],'w');

cardstr=['CDWR TIMING AND TRANSIT LOSS MODEL ' srtitlefull '                         CARD 1 GEN INFO'];
    fprintf(fid,'%95s\r\n',cardstr);
cardstr='SUBREACH  UPSTREAM                                                              CARD 2 RUN INFO';
    fprintf(fid,'%95s\r\n',cardstr);

if length(Qdsin)>1
    cardstr='         1         3                                                            CARD 3 INPUT SOURCE AND RUN OBJECTIVE, COl C=j349fast';
else
    cardstr='         1         2                                                            CARD 3 INPUT SOURCE AND RUN OBJECTIVE, COl C=j349fast';
end
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
for j=1:floor(length(stagedischarge)/4)-1  %wont include last extrapolated value..
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
for j=1:floor(length(stagedischarge)/4)-1
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


%downstream hydrograph (precomputed using muskingum etc
%this is currently built so that number of points must be divisible by 6
if length(Qdsin)>1
    for j=1:ceil(rsteps/6)
        fidstr='%10.1f %9.1f %9.1f %9.1f %9.1f %9.1f\r\n';
        fprintf(fid,fidstr,Qdsin((j-1)*6+1,1),Qdsin((j-1)*6+2,1),Qdsin((j-1)*6+3,1),Qdsin((j-1)*6+4,1),Qdsin((j-1)*6+5,1),Qdsin((j-1)*6+6,1));
    end
end


fclose(fid);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % the following uses a small file to list filenames
% %  - without command line arguments this has to be saved in root directory which risks messup if multiple instances running
% %  - currently turned off to instead use command line arguments
% fid=fopen([filenamesfilename],'w');
% fprintf(fid,'%s\r\n',[j349dir inputcardfilename]);
% fprintf(fid,'%s\r\n',[j349dir outputcardfilename]);
% if j349fast==1
%     fprintf(fid,'%s\r\n',[j349dir outputbinfilename]);
% end
% fclose(fid);
% [s, w] = dos(['StateTL_j349.exe']);  %changed this from just j349.exe

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% the following uses command line arguments to pass input/output filenames
% appears the double quotes will work (but not single quotes) for passing filenames with potential whitespaces
if j349fast==1
    [s, w] = dos(['StateTL_j349.exe -f "' [j349dir inputcardfilename] '" "' [j349dir outputcardfilename] '" "' [j349dir outputbinfilename]]);
else
    [s, w] = dos(['StateTL_j349.exe -f "' [j349dir inputcardfilename] '" "' [j349dir outputcardfilename]]);
end

if j349fast==1
   fid=fopen([j349dir outputbinfilename],'r');
   Qds=fread(fid,inf,'float32'); %even though compiled 64bit, seems output as 32bit REAL*4 rather than REAL*8
   %hopefully its the right length etc..
   if length(Qds)~=rsteps
        errordlg(['ERROR: Qds read from j349 binary file not same length (' num2str(length(Qds)) ') as rsteps(' num2str(rsteps) ') for D:' ds ' WD:' wds ' R:' rs ' SR:' num2str(sr)])
        error(['ERROR: Qds read from j349 binary file not same length (' num2str(length(Qds)) ') as rsteps(' num2str(rsteps) ') for D:' ds ' WD:' wds ' R:' rs ' SR:' num2str(sr)])
   end

%     %testing spike correction
%     for j=1:rsteps
%     if j>1
%     if Qus (j,1) > Qus (j-1,1)
%         Qds (j,1) = max(Qds(j-1,1),Qds(j,1));
%     elseif Qus (j,1) < Qus (j-1,1)
%         Qds (j,1) = min(Qds(j-1,1),Qds(j,1));
%     end
%     end
%     end

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
    
%	if strcmp(line,'                                                   SUMMARY OF DATA AND RESULTS'), break, end  %check to see if line starting 1900 or 2000s
    if strcmp(line,'    DATE     TIME   DISCHARGE   DISCHARGE    DISCHARGE     AND LOSSES    DISCHARGE   DEPLETIONS    STAGE       STAGE       STAGE')
       break;
    end

    k=k+1;
end
line = fgetl(fid);

Qds=zeros(rsteps,1);
for j=1:rsteps
    line = fgetl(fid);
%    datechunk(j,:)=line(2:12);
    Qds(j,1)=str2num(line(42:54));

%     %testing spike correction
%     if j>1
%     if Qus (j,1) > Qus (j-1,1)
%         Qds (j,1) = max(Qds(j-1,1),Qds(j,1));
%     elseif Qus (j,1) < Qus (j-1,1)
%         Qds (j,1) = min(Qds(j-1,1),Qds(j,1));
%     end
%     end

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
function [yfit,m,b,R2,SEE]=regr(x,y,meth,windowsize)

if strcmp(meth,'linreg')
   X=[ones(length(x),1) x];M=X\y;m=M(2,:);b=M(1,:);yfit=m.*x+b;R2=1-sum((y-yfit).^2)./sum((y-mean(y)).^2);SEE=(sum((x-y).^(2))./(length(x)-1)).^(0.5);
elseif strcmp(meth,'leastsquares') %x and y need to be in columns not rows
    if sum(sum(x))==0 || sum(sum(y))==0
        yfit=zeros(size(x));m=0;R2=0;SEE=0;b=0;
    else
        m=x\y;yfit=m.*x;R2 = 1 - sum((y - yfit).^2)./sum((y - mean(y)).^2);SEE=(sum((x-y).^(2))./(length(x)-1)).^(0.5);b=zeros(1,length(m));
    end
elseif strcmp(meth,'mean')
    b=mean(y);yfit=b.*ones(size(y));m=zeros(1,length(b));R2=zeros(1,length(b));SEE=zeros(1,length(b));
elseif strcmp(meth,'movingavg')    
%    %using filter - easy but isnt quite centered
%    yfit=filter(ones(1,windowSize)/windowSize,1,y);
    %centered moving average
    halfx=floor(windowsize/2);
    for i=1:length(y)
        yfit(i,:)=mean(y(max(1,i-halfx):min(length(y),i+halfx),:));
    end
    b=mean(y);m=zeros(1,length(b));R2=zeros(1,length(b));SEE=zeros(1,length(b));
elseif strcmp(meth,'movingmedian')    
    %centered moving median
    halfx=floor(windowsize/2);
    for i=1:length(y)
        yfit(i,:)=median(y(max(1,i-halfx):min(length(y),i+halfx),:));
    end
    b=median(y);m=zeros(1,length(b));R2=zeros(1,length(b));SEE=zeros(1,length(b));
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


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% just to save some of work on the bank method - eventually probabaly delete it all

function [Qds,celerity,dispersion,stage,Qdstail]=runbanksavework(ds,wds,rs,sr,Qus,rhours,rsteps,celerity,dispersion,upstage)
global SR
minc=1;
if nargin==9
    upstage=0;
    usegloverurf=0;
elseif nargin==10
    usegloverurf=0;
end


sd=SR.(ds).stagedischarge.(['SD' num2str(SR.(ds).(wds).(rs).sdnum(sr))]);
sdlen=length(sd(:,1));
if usegloverurf==1
bankurf=SR.(ds).(wds).(rs).bankurfg{sr};
%bankurfcum=SR.(ds).(wds).(rs).bankurfgcum{sr};
else
bankurf=SR.(ds).(wds).(rs).bankurf{sr};
end
urflen=length(bankurf);
% conversion from stage to flow,
% to about equal J349, found flow= changeS(ft)*alluviumlength(mi)*5280*2*aquiferwidth(ft)*storagecoff/(dt*3600) (although j349 never used alluvium length and storagecoeff)
%bankurf=bankurf*SR.(ds).(wds).(rs).alluviumlength(sr)*5280*2*SR.(ds).(wds).(rs).aquiferwidth(sr)*SR.(ds).(wds).(rs).storagecoefficient(sr)/(rhours*3600);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% interpolate stage from Q

if upstage==1
    Qusfull=max(SR.(ds).(wds).(rs).Qus(:,sr),minc);
    stagefull=SR.(ds).(wds).(rs).stage(:,sr);
    stage=stagefull.*Qus./Qusfull;
elseif upstage==2
    Qusfull=max(SR.(ds).(wds).(rs).Qus(:,sr),Qus);
    Quspartial=Qusfull-Qus;
    for i=1:length(Qus)
        sdids=find(sd(:,2)<=Quspartial(i));
        sdid=sdids(end);
        stage1(i)=(sd(min(sdlen,sdid+1),1)-sd(sdid,1))/(sd(min(sdlen,sdid+1),2)-sd(sdid,2))*(Quspartial(i)-sd(sdid,2))+sd(sdid,1);
        sdids=find(sd(:,2)<=Qusfull(i));
        sdid=sdids(end);
        stage2(i)=(sd(min(sdlen,sdid+1),1)-sd(sdid,1))/(sd(min(sdlen,sdid+1),2)-sd(sdid,2))*(Qusfull(i)-sd(sdid,2))+sd(sdid,1);
        stage(i)=max(0,stage2(i)-stage1(i));
    end
else
    for i=1:length(Qus)
        sdids=find(sd(:,2)<=Qus(i));
        sdid=sdids(end);
        stage(i)=(sd(min(sdlen,sdid+1),1)-sd(sdid,1))/(sd(min(sdlen,sdid+1),2)-sd(sdid,2))*(Qus(i)-sd(sdid,2))+sd(sdid,1);
    end
end


changeS(2:rsteps)=stage(2:rsteps)-stage(1:rsteps-1);
changeQ(2:rsteps)=Qus(2:rsteps)-Qus(1:rsteps-1);
bankflow=zeros(rsteps+urflen,1);
for i=2:rsteps
    if changeS(i)~=0
    lag=changeS(i)*bankurf(:,1);
    if changeS(i)>0  %increase in stage / flow into bank
        lag(1)=min(lag(1),changeQ(i)); %spike control - flow rate into bank shouldnt exceed change in actual flow rate causing increase in stage, could speed up if only looking at first ordinate
    else             %decrease in stage / flow out of bank
        lag(1)=max(lag(1),changeQ(i)); %spike control - flow rate into bank shouldnt exceed change in actual flow rate causing increase in stage, could speed up if only looking at first ordinate
    end
    bankflow(i:i+urflen-1,1)=bankflow(i:i+urflen-1,1)+lag;
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% find bankflow as a function of change in stage
trackbankstorage=0;
if trackbankstorage==1

aqvconst=2*SR.(ds).(wds).(rs).alluviumlength(sr)*5280*SR.(ds).(wds).(rs).aquiferwidth(sr)/1.5*SR.(ds).(wds).(rs).storagecoefficient(sr);
bankstorage=stage(1)*aqvconst*ones(rsteps+urflen,1);

for i=2:rsteps
    if bankflow(i,1)>0  %increase in stage / flow into bank
        flowlimit=10*aqvconst-bankstorage(i-1,1); %limit flow volume to remaining capacity in ft3
%        flowlimit=max(stage(1:i))*aqvconst-bankstorage(i-1,1); %limit flow volume to remaining capacity in ft3
        bankflow(i,1)=min(bankflow(i,1),flowlimit);
    elseif bankflow(i,1)<0  %decrease in stage / flow out of bank
        flowlimit=bankstorage(i-1,1); %limit flow to storage (above level of stage??)
        bankflow(i,1)=max(bankflow(i,1),-1*flowlimit);
    end
    bankstorage(i,1)=bankstorage(i-1,1)+bankflow(i,1)*(rhours*3600);
end

else
bankstorage=[];    
end

Qdsbank=Qus-bankflow(1:rsteps,1);
Qdstail=sum(bankflow(rsteps+1:end,1));


% old try
% for i=2:rsteps
%     if changeS(i)>0  %increase in stage / flow into bank
%         flowlimit=stage(i)*aqvconst-bankstorage(i-1,1); %limit flow volume to remaining capacity in ft3
%         flowlimids=find([changeS(i)*bankurfcum(:,1);flowlimit+1]>flowlimit);
%         flowlimid=flowlimids(1)-1;
%         if flowlimid>0
%             lag=changeS(i)*bankurf(1:flowlimid,1);
% %             lag(1)=min(lag(1),changeQ(i)); %spike control - flow rate into bank shouldnt exceed change in actual flow rate causing increase in stage, speeds up if only looking at first ordinate but might extend to additional ordinates
%         else
%             flowlimid=1;
%             lag=0;
%         end
%     elseif changeS(i)<0  %decrease in stage / flow out of bank
%         flowlimit=bankstorage(i-1,1); %limit flow to storage (above level of stage??)
%         flowlimids=find([-1*changeS(i)*bankurfcum(:,1);flowlimit+1]>flowlimit);
%         flowlimid=flowlimids(1)-1;
%         if flowlimid>0
%             lag=changeS(i)*bankurf(1:flowlimid,1);
% %             lag(1)=max(lag(1),changeQ(i)); %spike control - flow rate out of bank shouldnt exceed change in actual flow rate causing increase in stage, speeds up if only looking at first ordinate but might extend to additional ordinates
%         else
%             flowlimid=1;
%             lag=0;
%         end
%     else
%         flowlimid=1;
%         lag=0;
%     end
%     bankflow(i:i+flowlimid-1,1)=bankflow(i:i+flowlimid-1,1)+lag;
%     bankstorage(i:i+flowlimid-1,1)=bankstorage(i:i+flowlimid-1,1)+lag*(rhours*3600);
% end
% Qdsbank=Qus-bankflow(1:rsteps,1);
% Qdstail=sum(bankflow(rsteps+1:end,1));
% 
% else
% 
% 
% 
% bankstorage=[];    
% end




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% route Qus after bankflow to Qds location
if celerity==-999
    Qavg=(max(Qus,minc)+max(Qdsbank,minc))/2;
    [celerity,dispersion]=calcceleritydisp(Qavg,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),1);
end
% longer series to capture muskingham tail
Qdsbanklong=Qdsbank(end)*ones(rsteps+24*7,1);
Qdsbanklong(1:rsteps,1)=Qdsbank(1:rsteps,1);
celeritylong=celerity(end)*ones(rsteps+24*7,1);
celeritylong(1:rsteps,1)=celerity(1:rsteps,1);
dispersionlong=dispersion(end)*ones(rsteps+24*7,1);
dispersionlong(1:rsteps,1)=dispersion(1:rsteps,1);

[Qdsm,celerityt,dispersiont]=runmuskingum(ds,wds,rs,sr,Qdsbanklong,rhours,rsteps+24*7,celeritylong,dispersionlong);
Qds=Qdsm(1:rsteps);
Qdstail=sum(Qdsm(rsteps+1:end,1))-Qdstail;


% %j349 - time to first response
dt=rhours * 60 * 60; %sec
dx=SR.(ds).(wds).(rs).channellength(sr) * 5280; %ft
SC=celerity*dt;SC2=SC.*SC;SK=dispersion*dt;
TT=dx./SC+2*SK./SC2-(2.78*sqrt(2*SK*dx./(SC2.*SC)+(8*SK./SC2).*(SK./SC2))); %from j349 - time to first response
TTAVG=(1.5+TT)/2;  %current j349 but may want to remove this
NSR=TTAVG/dt+.501;
nadj(:,1)=floor(NSR);
nadj(:,2)=ceil(NSR)-NSR;
nadj(:,3)=ceil(NSR);
nadj(:,4)=NSR-floor(NSR);

Qds=zeros(rsteps+max(nadj(:,3)),1);
for i=1:rsteps
   Qds(i+nadj(i,1))=Qds(i+nadj(i,1))+Qdsm(i)*nadj(i,2);
   Qds(i+nadj(i,3))=Qds(i+nadj(i,3))+Qdsm(i)*nadj(i,4);
end
%Qdstail=sum(Qds(rsteps+1:end,1));
Qds=Qds(1:rsteps,1);

Qbeg1=sum(Qds(1:1+nadj(1,1),1));
Qds(1:1+nadj(1,1),1)=Qdsm(1);
Qbeg2=sum(Qds(1:1+nadj(1,1),1));
Qdstail=Qdstail-(Qbeg2-Qbeg1)-Qbanktail;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save of work on runbanksimple function that iterated

%function [Qds,celerity,dispersion,stage]=runbanksimple2(ds,wds,rs,sr,Qus,avggains,rhours,rsteps,rjulien,celerity,dispersion,fast,upstage)
%global SR
minc=1;
bankinterlim=1e-10;
fast=1;
if nargin==12
    upstage=0;
end

sd=SR.(ds).stagedischarge.(['SD' num2str(SR.(ds).(wds).(rs).sdnum(sr))]);
sdlen=length(sd(:,1));
bankurf=SR.(ds).(wds).(rs).bankurf{sr};
urflen=length(bankurf);
% conversion from stage to flow,
% to about equal J349, found flow= changeS(ft)*alluviumlength(mi)*5280*2*aquiferwidth(ft)*storagecoff/(dt*3600) (although j349 never used alluvium length and storagecoeff)
flowurf=bankurf*SR.(ds).(wds).(rs).alluviumlength(sr)*5280*1*SR.(ds).(wds).(rs).aquiferwidth(sr)*SR.(ds).(wds).(rs).storagecoefficient(sr)/(rhours*3600);

Qds=Qus;

% if fast~=1
%     if upstage==1
%         evap=SR.(ds).(wds).(rs).evap(:,sr).*Qus./SR.(ds).(wds).(rs).Qus(:,sr);
%         Qds=max(0,Qus-evap);
%     else
%         for i=1:3
%             Qavg=(max(Qus,minc)+max(Qds,minc))/2;
%             width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
%             evap=SR.(ds).(wds).(rs).evapday(rjulien,sr)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr); %EvapFactor = 0 to not have evap
%             Qds=max(0,Qus-evap);
%         end
%     end
% end


sumQds=sum(Qds);
for j=1:10
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % interpolate stage from Q
    Qavg=(max(Qus,minc)+max(Qds,minc))/2;
    if upstage==1
        Qfull=(max(SR.(ds).(wds).(rs).Qus(:,sr),max(Qus,minc))+max(SR.(ds).(wds).(rs).Qds(:,sr),max(Qus,minc)))/2;
        Qpartial=max(0,Qfull-Qavg);
        for i=1:length(Qus)
            sdids=find(sd(:,2)<=Qpartial(i));
            sdid=sdids(end);
            stage1(i)=(sd(min(sdlen,sdid+1),1)-sd(sdid,1))/(sd(min(sdlen,sdid+1),2)-sd(sdid,2))*(Qpartial(i)-sd(sdid,2))+sd(sdid,1);
            sdids=find(sd(:,2)<=Qfull(i));
            sdid=sdids(end);
            stage2(i)=(sd(min(sdlen,sdid+1),1)-sd(sdid,1))/(sd(min(sdlen,sdid+1),2)-sd(sdid,2))*(Qfull(i)-sd(sdid,2))+sd(sdid,1);
            stage(i)=max(0,stage2(i)-stage1(i));
        end
    else
        for i=1:length(Qus)
            sdids=find(sd(:,2)<=Qavg(i));
            sdid=sdids(end);
            stage(i)=(sd(min(sdlen,sdid+1),1)-sd(sdid,1))/(sd(min(sdlen,sdid+1),2)-sd(sdid,2))*(Qavg(i)-sd(sdid,2))+sd(sdid,1);
        end
    end



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % find bankflow as a function of change in stage
    changeS(2:rsteps)=stage(2:rsteps)-stage(1:rsteps-1);
    changeQ(2:rsteps)=Qavg(2:rsteps)-Qavg(1:rsteps-1);
    bankflow=zeros(rsteps+urflen,1);
    for i=2:rsteps
        lag=changeS(i)*flowurf(:,1);
        if lag(1)>0  %spike control - flow rate into bank shouldnt exceed change in actual flow rate causing increase in stage, could speed up if only looking at first ordinate
            lag=min(lag,changeQ(i));
        elseif lag(1)<0
            lag=max(lag,changeQ(i));
        end
        bankflow(i:i+urflen-1,1)=bankflow(i:i+urflen-1,1)+lag;
    end
    Qbank=Qus;
    Qbank(rsteps+urflen,1)=0;
    Qbank=Qbank-bankflow;
    Qdsbank=Qbank(1:rsteps,1);
%     if fast~=1
%         if upstage==1
%             evap=SR.(ds).(wds).(rs).evap(:,sr).*Qus./SR.(ds).(wds).(rs).Qus(:,sr);
%             Qdsbank=max(0,Qbank(1:rsteps,1)-evap);
%         else
%             for i=1:3
%                 Qavg=(max(Qus,minc)+max(Qdsbank+avggains,minc))/2;  %Qds considers both bankflow and avggains for width/evap calc, but Qdsbank doesnt include gains
%                 width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
%                 evap=SR.(ds).(wds).(rs).evapday(rjulien,sr)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr); %EvapFactor = 0 to not have evap
%                 Qdsbank=max(0,Qbank(1:rsteps,1)-evap);
%             end
%         end
%     end
    sumQdsnew=sum(Qdsbank);
    Qdsdiff=(sumQdsnew-sumQds)/sumQdsnew;
    sumQds=sumQdsnew;
    if fast==1
        Qds=Qdsbank;
    else
        Qds=Qdsbank+avggains;
    end
    if abs(Qdsdiff) < bankinterlim
        disp(['SR: ' num2str(sr) ' j: ' num2str(j) ' Qdsdiff: ' num2str(Qdsdiff)])
        break;
    end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% route Qus after bankflow to Qds location
if celerity==-999
    Qavg=(max(Qus,minc)+max(Qds,minc))/2;
    [celerity,dispersion]=calcceleritydisp(Qavg,SR.(ds).(wds).(rs).celeritya(sr),SR.(ds).(wds).(rs).celerityb(sr),SR.(ds).(wds).(rs).dispersiona(sr),SR.(ds).(wds).(rs).dispersionb(sr),SR.(ds).(wds).(rs).celeritymethod(sr),SR.(ds).(wds).(rs).dispersionmethod(sr),1);
end
% longer series to capture muskingham tail
Qdsbanklong=Qdsbank(end)*ones(rsteps+24*7,1);
Qdsbanklong(1:rsteps,1)=Qdsbank(1:rsteps,1);
celeritylong=celerity(end)*ones(rsteps+24*7,1);
celeritylong(1:rsteps,1)=celerity(1:rsteps,1);
dispersionlong=dispersion(end)*ones(rsteps+24*7,1);
dispersionlong(1:rsteps,1)=dispersion(1:rsteps,1);

[Qdsm,celerityt,dispersiont]=runmuskingum(ds,wds,rs,sr,Qdsbanklong,rhours,rsteps+24*7,celeritylong,dispersionlong);
Qds=Qdsm(1:rsteps);
Qdstail=sum(Qbank(rsteps+1:end,1))+sum(Qdsm(rsteps+1:end,1)-Qdsbanklong(rsteps+1:end,1));
%end

end







