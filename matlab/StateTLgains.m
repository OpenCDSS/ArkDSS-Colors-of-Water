%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% StateTLgains
% prelinary file to build average gain/loss/error term over multiple years
%
% cd C:\Projects\Ark\ColorsofWater\matlab
%%%%%%%%%%%%%%

clear all

runstarttime=now;
basedir=cd;basedir=[basedir '\'];


%%%%%%%%%%%%%%%%%%%%%%%%%%
%Run control options (on=1) fed through control file need to be in this list -
%watch out - if change variable names in code also need to change them here!
%currently - if leave out one of these from control file will assign it a zero value
controlvars={'srmethod','j349fast','j349multurf','j349musk','inputfilename','rundays','fullyear','readinputfile','newnetwork','readevap','readstagedischarge','pullstationdata','multiyrstation','pulllongtermstationdata','pullreleaserecs','runriverloop','runwcloop','doexchanges','runcaptureloop','rungageloop','runcalibloop','stubcelerity','stubdispersion'};
controlvars=[controlvars,{'copydatafiles','savefinalmatfile','logfilename','displaymessage','writemessage','outputfilebase','outputriv','outputwc','outputcal','outputcalregr','outputnet','outputgain','outputhr','outputday','outputmat','calibavggainloss','calibtype','gainsavgwindowdays','plotcalib'}];
controlfilename='StateTL_control.txt';

spinupdays=0
spindowndays=9;
mindays=365;
rhours=1;
rdays=mindays+spinupdays+spindowndays;  %rdays is with spinup
rsteps=rdays*24/rhours;

%%%%%%%%%%%%%%%%%%%%%%%%%%
%READ INITIAL RUN INFO
% initially have WDlist in xlsx that defines division and WDs to run in order (upper tribs first)
%%%%%%%%%%%%%%%%%%%%%%%%%%

logmc={['Running StateTLgains starting: ' datestr(runstarttime)]};    %log message
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

movingavgwindow=ceil(gainsavgwindowdays*24/rhours); %running average window size in hrs; currently using 2-weeks

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


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% use compiled version of StateTL to calculate gains for each year
% those will progressively be saved into StateTL_data_gainsyr.mat under gainsyr.Y20xx.D2.WDxx.Rx.gagediffportion and gagedifflast

for i=multiyrs
    cmdlinearg=['StateTL -e ' num2str(i)];
    logm=['StateTLgains issuing command line argument: ' cmdlinearg ' ' datestr(now)];
    domessage(logm,logfilename,displaymessage,writemessage)

    [s,w] = dos(cmdlinearg,'-echo');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% build avg gains using average of 


logm=['StateTLgains calculating median of multiyrs calculated gains'];
domessage(logm,logfilename,displaymessage,writemessage)

load('StateTL_data_gainsyr.mat')
load('StateTL_data_subreach.mat')

for wd=WDlist
    wds=['WD' num2str(wd)];    
    for r=SR.(ds).(wds).R
        rs=['R' num2str(r)];

% %using average        
% k=0;
% gainsum=0;
% gainlastsum=0;
% for i=multiyrs
%     k=k+1;
%     gainsum=gainsum+gainsyr.(['Y' num2str(i)]).(ds).(wds).(rs).gagediffportion;
%     gainlastsum=gainlastsum+gainsyr.(['Y' num2str(i)]).(ds).(wds).(rs).gagedifflast;
% end
% gains.(ds).(wds).(rs).gagediffportion=gainsum/k;
% gains.(ds).(wds).(rs).gagedifflast=gainlastsum/k;

%using median - to control spikes
k=0;
clear gainmat gainlastmat
for i=multiyrs
    k=k+1;
    gainmat(:,:,k)=gainsyr.(['Y' num2str(i)]).(ds).(wds).(rs).gagediffportion(1:rsteps,:);
    gainlastmat(:,k)=gainsyr.(['Y' num2str(i)]).(ds).(wds).(rs).gagedifflast(1:rsteps,1);
end
gains.(ds).(wds).(rs).gagediffportion=median(gainmat,3);
gains.(ds).(wds).(rs).gagedifflast=median(gainlastmat,2);

%for leapyears
gains.(ds).(wds).(rs).gagediffportion(rsteps+1:rsteps+24,:)=gains.(ds).(wds).(rs).gagediffportion(end-23:end,:);
gains.(ds).(wds).(rs).gagedifflast(rsteps+1:rsteps+24,1)=gains.(ds).(wds).(rs).gagediffportion(end-23:end,1);


    end
end

logm=['StateTLgains saving gains file to: ' [basedir 'StateTLdata\StateTL_data_gains.mat']];
domessage(logm,logfilename,displaymessage,writemessage)

save([basedir 'StateTLdata\StateTL_data_gains.mat'],'gains')


logm=['Done Running StateTLgains endtime: ' datestr(now) ' elapsed (DD:HH:MM:SS): ' datestr(now-runstarttime,'DD:HH:MM:SS')];    %log message
if displaymessage~=1;disp(logm);end
domessage(logm,logfilename,displaymessage,writemessage)


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





