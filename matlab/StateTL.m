%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% StateTL
% Matlab (preliminary) Colors of Water Transit Loss and Timing engine
%
%
% Major version changes starting June 2021
% 


cd C:\Projects\Ark\ColorsofWater\matlab
clear all
disp(datestr(now))
basedir=cd;basedir=[basedir '\'];
%j349dir=[basedir 'j349dir\']; %currently need to a cd where run fortran but may slow to cd at every instance
j349dir=basedir;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% runoptions
% - most of this will be put into text file to drive run

readinfofile=2;  %1 reads from excel and saves mat file; 2 reads mat file;
readgageinfo=2;  %if using real gage data, 1 reads from REST, 2 reads from file - watch out currently saves into SR file
infofilename='StateTL_inputdata.xlsx';
pullnewdivrecs=2;  %0 if want to repull all from REST, 1 if only pull new/modified from REST for same period, 2 load from saved mat file
plotmovie=1;  %this will probably be moved to a seperate plotting script - will add plot command to pick wc and plot wc-time for locations
    figtop=1500;
doexchanges=1;

%Methods - these currently override method for all reaches, but planning default method by Reach that would run if not overrided  
srmethod='j349';       %dynamic j349/Livinston method
%srmethod='muskingum';   %percent loss TL plus muskingum-cunge for travel time
pred=0;  %if pred=0 subtracts water class from existing flows, if 1 adds to existing gage flows
flowcriteria=5; %to establish gage and node flows: 1 low, 2 avg, 3 high flow values from livingston; envision 4 for custom entry; 5 for actual flows; 6 average for xdays/yhours prior to now/date; 7 average between 2 dates
iternum.j349=5;  %iterations of gageflow loop given method (had been using dynamic way to iterate but currently just number);
iternum.muskingum=3;
iternative=10;
inadv1_letwaterby=1;
inadv2_reducewc=1;
minc=1;              %minimum flow applied to celerity, dispersion, and evaporation calculations (dont want to have a zero celerity for reverse operations etc) / this is also seperately in j349/musk functions
minj349=1;           %minimum flow for j349 application - TLAP uses 1.0
gainchangelimit=0.1;

outputfilename='StateTL_outnewwcreduce_';  %will add srmethod + gage/wc/etc + hour/day + .csv
outputgage=0;  %output waterclass amounts by reach
    outputgagehr=1;  %output on hour timestep
    outputgageday=1;  %output on day timestep
outputwc=0;  %output waterclass amounts by reach
    outputwchr=1;  %output on hour timestep
    outputwcday=1;  %output on day timestep


apikey='D2D7AF63-C286-40A8-9';  %this is KT1 personal - will want to get one for this tool or cdss etc

% Date - will be reworked - j349 currently only works for 60 days at 1hour - may alter fortran to run full calendar year at 1 hour without spinup
datestart=datenum(2018,4,01);
rdays=60; rhours=1;
spinupdays=45;
rsteps=rdays*24/rhours;
datest=spinupdays*24/rhours+1;


%%%%%%%%%%%%%%%%%%%%%%%%%%
%READ INITIAL RUN INFO
% initially have WDlist in xlsx that defines division and WDs to run in order (upper tribs first)
%%%%%%%%%%%%%%%%%%%%%%%%%%
disp(['reading WD run list from file: ' basedir infofilename] )
inforaw=readcell([basedir infofilename],'Sheet','WDlist');
[inforawrow inforawcol]=size(inforaw);

infoheaderrow=1;
for i=1:inforawcol
    if 1==2
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'DIV'); infocol.div=i;
    elseif strcmp(upper(inforaw{infoheaderrow,i}),'WD'); infocol.wd=i;
    end
end
k=0;
for i=infoheaderrow+1:inforawrow
    if ~isempty(inforaw{i,infocol.div}) & ~ismissing(inforaw{i,infocol.div})
        k=k+1;
        v.di=inforaw{i,infocol.div};if ischar(v.di); v.di=str2num(v.di); end
        v.wd=inforaw{i,infocol.wd};if ischar(v.wd); v.wd=str2num(v.wd); end
        
        if k==1
           d=v.di;
           WDlist=v.wd;
        else
           if d~=v.di
               error('Stopping - more than one Division listed in run options / currently not set to run multiple divisions at once (but very easily can be)')
           end
           WDlist=[WDlist,v.wd];
        end
    end
end
ds=['D' num2str(d)];


%%%%%%%%%%%%%%%%%%%%%%%%%%
%READ SUBREACH INFORMATION
%  initially have in xlsx but this will eventually all come from HB/REST
%%%%%%%%%%%%%%%%%%%%%%%%%%
global SR

if readinfofile==1

%%%%%%%%%%%%%%%%%%%%%%%%%%    
% read subreach data    
disp(['reading subreach info from file: ' basedir infofilename] )

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

[infonum,infotxt,inforaw]=xlsread([basedir infofilename],'evap');
[infonumrow infonumcol]=size(infonum);
[inforawrow inforawcol]=size(inforaw);

for wd=WDlist
    wds=['WD' num2str(wd)];
    SR.(ds).(wds).evap=infonum(:,1);
end

%%%%%%%%%%%%%%%%%%%%%%%%
% stage discharge data

% [infonum,infotxt,inforaw]=xlsread([basedir infofilename],'stagedischarge');
% [infonumrow infonumcol]=size(infonum);
% [inforawrow inforawcol]=size(inforaw);

SDmat=readmatrix([basedir infofilename],'Sheet','stagedischarge');
[SDmatnumrow SDmatnumcol]=size(SDmat);

for i=1:SDmatnumrow
    if ~isfield(SR.(ds),'stagedischarge') || ~isfield(SR.(ds).stagedischarge,['SD' num2str(SDmat(i,1))])
        SR.(ds).stagedischarge.(['SD' num2str(SDmat(i,1))])=SDmat(i,2:3);
    else
        SR.(ds).stagedischarge.(['SD' num2str(SDmat(i,1))])=[SR.(ds).stagedischarge.(['SD' num2str(SDmat(i,1))]);SDmat(i,2:3)];
    end    
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



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% READ GAGE AND TELEMETRY BASED FLOW DATA
% much of this needs to be improved for larger application; particularly handling of dates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rdates=datestart*ones(spinupdays*24/rhours,1);
rdates=[rdates;[datestart:rhours/24:datestart+(rdays-spinupdays)-rhours/24]'];
rdatesstartid=spinupdays*24/rhours+1;
[ryear,rmonth,rday,rhour] = datevec(rdates);
rdatesday=floor(rdates);
rjulien=rdatesday-(datenum(ryear,1,1)-1);
dateend=datestart+(rdays-spinupdays)-1;
datedays=[datestart:dateend];


flowtestloc=[2,17,8,1];

if readgageinfo==1 | readinfofile==1  %unfortunately, currently if reload SR data also need to reload gage data... (fix at somepoint - load gage data into intermediate file)   

switch flowcriteria
    case 1
        flow='low';
    case 2
        flow='avg';
    case 3
        flow='high';
    otherwise
        disp('reading gage data from HB using REST services')    
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
                        Qnode(1:rdatesstartid-1,1)=measvalues(1);
                        Qnode(rdatesstartid:length(rdates),1)=measvalues;
                        SR.(ds).(wds).(rs).Qnode(:,sr,1)=Qnode;
                    catch
                        disp(['WARNING: didnt get telemetry data for gage: ' station ' parameter: ' parameter ' have to use flow rate for conditions: ' flow ])
                        SR.(ds).(wds).(rs).Qnode(:,sr,1)=SR.(ds).(wds).(rs).(flow)(1,sr)*ones(rsteps,1);
                    end
                end
            end
        else
            %                SR.(ds).(wds).(rs).Qnode(:,:,1)=repmat(SR.(ds).(wds).(rs).(flow)(1,:),rsteps,1).*ones(rsteps,length(SR.(ds).(wds).(rs).SR)); %repmat required for r2014a
            SR.(ds).(wds).(rs).Qnode(:,:,1)=SR.(ds).(wds).(rs).(flow)(1,:).*ones(rsteps,length(SR.(ds).(wds).(rs).SR));
        end
    end
end

save([basedir 'StateTL_SRdata_withgage.mat'],'SR');

else
    load([basedir 'StateTL_SRdata_withgage.mat']);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% WATERCLASS RELEASE RECORDS USING HB REST
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

divrecdayurl='https://dwr.state.co.us/Rest/GET/api/v2/structures/divrec/divrecday/';

if pullnewdivrecs==0
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



if pullnewdivrecs<2
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
        disp(['Using HBREST for  ' reswdid ' from: ' datestr(datestart,23) ' to ' datestr(dateend,23) ' and modified: ' datestr(modified) ]);
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
                disp(['WARNING: skipping REST divrec ' wdid ' ' num2str(wcnum) ' with measinterval: ' measinterval ' with measunits: ' measunits]);
            elseif isempty(dateid)
                disp(['WARNING: skipping REST divrec ' wdid ' ' num2str(wcnum) ' with measdatestr: ' measdatestr]);
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
        disp(['WARNING: didnt find new records using REST for  ' reswdid ' with pullnewdivrecs: ' num2str(pullnewdivrecs) ' and modified: ' datestr(WC.date.(ds).(wds).modified) ]);
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

lastwdid=[];  %tracks last wdid/connection of processed wd reaches
SR.(ds).Rivloc.loc=[]; %just tracks location listing of processed reaches
SR.(ds).WCloc.wslist=[];
SR.(ds).WCloc.Rloc=[];
SR.(ds).Rivloc.flowwc.wcloc=[];


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Routing of water classes
%   new - put above other loops to build WCloc list first purely for inadvertant diversion correction
%   so can do both gageflow and admin together on a R-reach by reach basis
%
%  WATCH!-currently requires WDID list to be in spatial order to know whats going upstream
%         may want to change that to ordered lists 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for wd=WDlist
    wds=['WD' num2str(wd)];
    if ~isfield(SR.(ds).(wds),'wwcnums')
        disp(['no water classes identified (admin loop not run) for D:' ds ' WD:' wds]) 
    else
    wwcnums=SR.(ds).(wds).wwcnums;
    Rt=SR.(ds).(wds).R(1);
    Rb=SR.(ds).(wds).R(end);
    disp(['running admin loop for D:' ds ' WD:' wds]) 

for w=1:length(wwcnums)
ws=wwcnums{w};
% if ~isfield(SR.(ds).WCloc,ws)  %if here will include missing WCs as empty
%     SR.(ds).WCloc.wslist=[SR.(ds).WCloc.wslist,{ws}];
%     SR.(ds).WCloc.(ws)=[];
% end

%disp(['running admin loop for D:' ds ' WD:' wds ' wc:' ws]) 


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
    disp(['WARNING: not routing (either exchange or missing) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ]);
else
    if ~isfield(SR.(ds).WCloc,ws)
        SR.(ds).WCloc.wslist=[SR.(ds).WCloc.wslist,{ws}];
        SR.(ds).WCloc.(ws)=[];
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
            disp(['routing: ' ws ' ' WC.(ds).WC.(ws).wc ' To:' wdidto ' external to WD reach, routing to end of WD reach']);
        end  
    elseif isempty(dswdidids)                             %US EXCHANGE RELEASE - ONLY ROUTING HERE IF FIRST DOWN TO MID-WD BRANCH
        wdidtoidnotwd=setdiff(wdidtoid,wdinwdidlist);
        branchid=find(SR.(ds).(wds).branch{:,1}==SR.D2.WDID{wdidtoidnotwd,3});

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
            disp(['routing: ' ws ' ' WC.(ds).WC.(ws).wc ' To Confluence:' wdidbranch ' US exchange first routing with TL to internal confluence point within WD reach']);
            disp(['Exchange: (external to WD) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ]);    
            
        elseif ~isempty(wdidtoidwd)                    %us exchange within WD (exchtype=1)
            exchtype=1;
            SR.(ds).EXCH.(ws).wdidtoid=wdidtoidwd(end);  %last in list in case multiple reach listing (will go to lowest) - remember that wdid is listed "above" subreach so sr will be next one after
            SR.(ds).EXCH.(ws).wdidfromid=wdidfromid;
            SR.(ds).EXCH.(ws).WDfrom=wd;
            SR.(ds).EXCH.(ws).WDto=wd;
            SR.(ds).EXCH.(ws).exchtype=1;
            wdidtoid=wdidfromid;  %leaving it there
            disp(['Exchange: (internal to WD) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ]);
        else                                           %us exchange in different WD (exchtype=2)
            exchtype=2;
            SR.(ds).EXCH.(ws).wdidtoid=wdidtoid(end);
            SR.(ds).EXCH.(ws).wdidfromid=wdidfromid;
            SR.(ds).EXCH.(ws).WDfrom=wd;
            SR.(ds).EXCH.(ws).WDto=SR.(ds).WDID{wdidtoid(1),3};
            SR.(ds).EXCH.(ws).exchtype=2;
            wdidtoid=wdidfromid;
%            wdidtoid=wdinwdidlist(end);
            disp(['Exchange: (external to WD) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ]);    
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
    % WCloc.ws listing locations of WC as cell/strings (sr/lsr/type(1-release/2-exch) is num)
    lsr=SR.(ds).(wds).(rs).subreachid(sr);
    SR.(ds).WCloc.(ws)=[SR.(ds).WCloc.(ws);[{ds},{wds},{rs},{sr},{lsr},{1},{SR.(ds).(wds).(rs).wdid{sr}},{SR.(ds).(wds).(rs).dswdid{sr}}]];
    
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
        disp(['running gageflow loop on D:' ds ' WD:' wds ' R:' rs]) 
            
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
    SR.(ds).(wds).(rs).locid(sr)=length(SR.(ds).Rivloc.loc(:,1));      %this will be used for flowriv and flowwc
    SR.(ds).Rivloc.flowwc.us(1:rsteps,SR.(ds).(wds).(rs).locid(sr))=0;  %variable to sum total wc release amounts within river - note that dimensions reversed
    SR.(ds).Rivloc.flowwc.ds(1:rsteps,SR.(ds).(wds).(rs).locid(sr))=0;  %variable to sum total wc release amounts within river
    SR.(ds).(wds).(rs).Qusnodewc(:,sr)=zeros(rsteps,1);  %also variable to sum total wc release amounts
    SR.(ds).(wds).(rs).Quswc(:,sr)=zeros(rsteps,1);
    SR.(ds).(wds).(rs).Qdswc(:,sr)=zeros(rsteps,1);
end
        

gagediff=zeros(rsteps,1);
SR.(ds).(wds).(rs).gagediffportion=zeros(rsteps,length(SR.(ds).(wds).(rs).SR));
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

change=1;
while change==1
    change=0;

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
    Qus=max(0,Qus);
    
    if gain==-999   %gain=-999 to not run transittime but can have loss percent 
        losspercent=SR.(ds).(wds).(rs).losspercent(sr);
        Qds=Qus*(1-losspercent/100);
        celeritya=SR.(ds).(wds).(rs).celeritya(sr);
        celerityb=SR.(ds).(wds).(rs).celerityb(sr);
        celerity=celeritya*(max(minc,(Qus+Qds)/2)).^celerityb;
        dispersiona=SR.(ds).(wds).(rs).dispersiona(sr);
        dispersionb=SR.(ds).(wds).(rs).dispersionb(sr);
        dispersion=dispersiona*(max(minc,(Qus+Qds)/2)).^dispersionb;    
    else
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
    Qds=Qds-evap+SR.(ds).(wds).(rs).gagediffportion(:,sr);
%    Qds=Qds-evap+gagediff*SR.(ds).(wds).(rs).reachportion(sr);
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
        gagediffavg=gagediffchange(rdatesstartid-1,1);
        gagediff=gagediffnew+gagediff;
        
        if ii<iternum.(srmethod)
%            SR.(ds).(wds).(rs).gagediffportion=gagediff*SR.(ds).(wds).(rs).reachportion;
            %reverse gagediff with evaporation to determine portion to apply within each reach
            gagediffds=gagediff;
            exchtimerem=0;
            for sr=srb:-1:srt
                gagediffportion=gagediffds*SR.(ds).(wds).(rs).reachportion(sr)/sum(SR.(ds).(wds).(rs).reachportion(1:sr));
                SR.(ds).(wds).(rs).gagediffportion(:,sr)=gagediffportion;
                celerity=SR.(ds).(wds).(rs).celerity(:,sr);
                if or(strcmp(srmethod,'j349'),strcmp(srmethod,'muskingum'))
                    [gagediffus,exchtimerem,celerity]=reversecelerity(ds,wds,rs,sr,gagediffds,exchtimerem,rhours,rsteps,celerity); %using river celerity
                else
                    gagediffus=gagediffds;
                end
                gagediffus=gagediffus-gagediffportion;
                Qavg=(max(0,gagediffus)+max(0,gagediffds))/2;  %hopefully this doesn't smeer timing
                width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
                evap=SR.(ds).(wds).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
                gagediffus=gagediffus+evap;
                gagediffds=gagediffus;
            end
        end
        

    end
    SR.(ds).(wds).(rs).gain=[SR.(ds).(wds).(rs).gain gain];
    SR.(ds).(wds).(rs).gagediffseries(:,ii)=gagediff;
end

end %ii iteration on gainchange

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% (INTERNAL) ADMIN LOOP FOR WATERCLASSES
%   now internal to process loop but just working on one reach at a time
%   this is so that can re-run gage loop if calculated native flows go negative
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

changewc=1;changewccount=0;
while changewc==1
    changewc=0;
    if changewccount==0
        disp(['running admin loop on D:' ds ' WD:' wds ' R:' rs])
    else
        disp(['Reoperating admin loop, count: ' num2str(changewccount) ' on D:' ds ' WD:' wds ' R:' rs])
    end

wwcnumids=intersect(find(strcmp(SR.(ds).WCloc.Rloc(:,3),wds)),find(strcmp(SR.(ds).WCloc.Rloc(:,4),rs)));
wwcnums=SR.(ds).WCloc.Rloc(wwcnumids,1);

%will refresh to zero every time reoperate
for sr=SR.(ds).(wds).(rs).SR
SR.(ds).(wds).(rs).QSRadd(:,sr)=zeros(rsteps,1);
SR.(ds).(wds).(rs).Qusnodewc(:,sr)=zeros(rsteps,1);  %also variable to sum total wc release amounts
SR.(ds).(wds).(rs).Quswc(:,sr)=zeros(rsteps,1);
SR.(ds).(wds).(rs).Qdswc(:,sr)=zeros(rsteps,1);
SR.(ds).Rivloc.flowwc.us(1:rsteps,SR.(ds).(wds).(rs).locid(sr))=0;  %variable to sum total wc release amounts within river - note that dimensions reversed - not sure if need now with above
SR.(ds).Rivloc.flowwc.ds(1:rsteps,SR.(ds).(wds).(rs).locid(sr))=0;  %variable to sum total wc release amounts within river
end

for w=1:length(wwcnumids)
ws=SR.(ds).WCloc.Rloc{wwcnumids(w),1};
srt=SR.(ds).WCloc.Rloc{wwcnumids(w),5};
srb=SR.(ds).WCloc.Rloc{wwcnumids(w),6};
Rtr=SR.(ds).WCloc.Rloc{wwcnumids(w),7};
Rtb=SR.(ds).WCloc.Rloc{wwcnumids(w),8};
SRtr=SR.(ds).WCloc.Rloc{wwcnumids(w),9};
SRtb=SR.(ds).WCloc.Rloc{wwcnumids(w),10};
wdidfrom=SR.(ds).WCloc.Rloc{wwcnumids(w),11};
wdidto=SR.(ds).WCloc.Rloc{wwcnumids(w),12};
wdidfromid=SR.(ds).WCloc.Rloc{wwcnumids(w),13};
wdidtoid=SR.(ds).WCloc.Rloc{wwcnumids(w),14};

disp(['running admin loop on waterclass:' ws])

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
for sr=srt:srb
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
        Quspartial=Qusnodepartial+type*Qnode;
    end
    %reduce WC based on negative native at gage
    if isfield(SR.(ds).(wds).(rs),ws) && isfield(SR.(ds).(wds).(rs).(ws),'wcreduce') && SR.(ds).(wds).(rs).(ws).wcreduce(sr)==1
        Quspartial=Quspartial+SR.(ds).(wds).(rs).(ws).wcreduceamt(:,sr);
        release=release-SR.(ds).(wds).(rs).(ws).wcreduceamt(:,sr);        
    end
    
    gain=SR.(ds).(wds).(rs).gain(end);
    if pred==1
        celerity=-999;dispersion=-999;
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
    Qdspartial=Qdspartial-evap+SR.(ds).(wds).(rs).gagediffportion(:,sr);
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
    SR.(ds).(wds).(rs).QSRadd(:,sr)=SR.(ds).(wds).(rs).QSRadd(:,sr)+QSRadd;  %currently just for output file - this is going to get overwritten by subsequent water classes (??)
%    SR.(ds).(wds).(rs).QSRaddcum(:,1:sr)=cumsum(SR.(ds).(wds).(rs).QSRadd(:,1:sr),2);  %this is what might get added back in as effect would go downstream   
    QSRaddsum=sum(QSRadd(datest:end));
    if QSRaddsum>0 && inadv1_letwaterby==1 %if internal correction so native doesnt go negate
        release=max(0,release);
        if gain==-999
            dsrelease=release;
            losspercent=SR.(ds).(wds).(rs).losspercent(sr);
            dsrelease=release*(1-losspercent/100);
        elseif strcmp(srmethod,'muskingum')
            [dsrelease,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,release,rhours,rsteps,celerity,dispersion);
        elseif strcmp(srmethod,'j349')
            [dsrelease,celerity,dispersion]=runj349f(ds,wds,rs,sr,release+minj349,gainportion,rdays,rhours,rsteps,j349dir,celerity,dispersion); %celerity/disp based on gage flows - wrong but so timing the same
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
        disp(['To avoid cutting wc: ' ws ' total wcamount exceeding river: ' num2str(QSRaddsum) ' added US:' num2str(sum(QSRaddus(datest:end))) ' added DS:' num2str(sum(QSRaddds(datest:end))) ' wd:' wds ' r:' rs ' sr:' num2str(sr)])
    else
        SR.(ds).(wds).(rs).(ws).QSRadded(:,sr)=0;
        SR.(ds).(wds).(rs).(ws).QSRaddus(:,sr)=zeros(rsteps,1);
        SR.(ds).(wds).(rs).(ws).QSRaddds(:,sr)=zeros(rsteps,1);
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
    SR.(ds).Rivloc.flowwc.wcloc=[SR.(ds).Rivloc.flowwc.wcloc;{SR.(ds).(wds).(rs).locid(sr)} {ws} {length(SR.(ds).WCloc.(ws)(:,1))}];
    
    Qusnodepartial=Qdspartial;
    release=Qdsrelease;
    
end %sr
  
end %if

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% parking - transfering waterclass amt from one WD to another - currently only for release/exchange through internal confluence
if r==Rtb && isfield(SR.(ds).(wds),ws) && isfield(SR.(ds).(wds).(ws),parkwdidid)  %placing park - place wcnum and park parameters in downstream WDreach
    parkwdidid=SR.(ds).(wds).(ws).parkwdidid;    
    did=SR.(ds).WDID{parkwdidid,1};
    parkWD=SR.(ds).WDID{parkwdidid,3};
    pwds=['WD' num2str(parkWD)];
    parkR=SR.(ds).WDID{parkwdidid,4};
    prs=['R' num2str(parkR)];
    psr=SR.(ds).WDID{parkwdidid,5};   
    lsr=SR.(ds).(wds).(rs).subreachid(sr);
%    parklsr=SR.(ds).(['WD' num2str(SR.(ds).WDID{wdidtoid,3})]).(['R' num2str(SR.(ds).WDID{wdidtoid,4})]).subreachid(SR.(ds).WDID{wdidtoid,5}); %this should also work - keep in case above breaks down
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
    
negnativeds=-1*min(0,SR.(ds).(wds).(rs).Qdsnative);
negnativedssum=sum(negnativeds(datest:end,:));

if r~=Rb & negnativedssum(1,end)>0 & inadv2_reducewc==1
    %trying to find best upstream spots to reduce wcs
    disp(['Negative Native Flow at end of wd:' wds ' r:' rs ' total amount:' num2str(negnativedssum(1,end))]);
    negnativeus=-1*min(0,SR.(ds).(wds).(rs).Qusnative);
    negnativeussum=sum(negnativeus(datest:end,:));
    negnativeussumoutflows=-1*min(0,negnativeussum.*SR.(ds).(wds).(rs).type); %just at outflow nodes
    clear negnativeussumdiff
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

    srb=length(wcreduceperc);
    for i=1:length(wcreducepercids)
        exchtimerem=0;
        srt=wcreducepercids(i);
        wcreducepercent=wcreduceperc(wcreducepercids(i));
        Qnegds=negnativeds(:,end)*wcreducepercent;
        
        for sr=srb:-1:srt
            celerity=SR.(ds).(wds).(rs).celerity(:,sr);
            if or(strcmp(srmethod,'j349'),strcmp(srmethod,'muskingum'))
                [Qnegus,exchtimerem,celerity]=reversecelerity(ds,wds,rs,sr,Qnegds,exchtimerem,rhours,rsteps,celerity); %using river celerity
            else
                Qnegus=Qnegds;
            end
            Qavg=Qnegus;  %us and ds should be same amounts but using us to not smeer timing
            width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
            evap=SR.(ds).(wds).evap(rjulien,1)*SR.(ds).(wds).(rs).evapfactor(sr).*width.*SR.(ds).(wds).(rs).channellength(sr);
            Qnegus=Qnegus+evap;
            Qnegds=Qnegus;
        end
        
        %finding water classes that are running in stream both at given node for reduction and at end where gage 
        wwcnumids=intersect(find(strcmp(SR.(ds).WCloc.Rloc(:,3),wds)),find(strcmp(SR.(ds).WCloc.Rloc(:,4),rs)));
        wwcnumids=intersect(find([SR.(ds).WCloc.Rloc{:,5}]<=srt),wwcnumids);
        wwcnumids=intersect(find([SR.(ds).WCloc.Rloc{:,6}]==srb),wwcnumids); %wc also has to be in stream at end where gage (?)
%        wwcnumids=intersect(find([SR.(ds).WCloc.Rloc{:,6}]>=srb),wwcnumids);
             
        for w=1:length(wwcnumids)
            ws=SR.(ds).WCloc.Rloc{wwcnumids(w),1};
            if ~isfield(SR.(ds).(wds).(rs).(ws),'wcreduce')
                numsrs=length(SR.(ds).(wds).(rs).SR);
                SR.(ds).(wds).(rs).(ws).wcreduce(1,numsrs)=0;
                SR.(ds).(wds).(rs).(ws).wcreduceamt(:,numsrs)=zeros(rsteps,1);
            end
                
            wcportion=wcreducepercent*SR.(ds).(wds).(rs).(ws).Qusrelease(:,sr)./SR.(ds).(wds).(rs).Quswc(:,sr);
            wcreduceamt=Qnegus.*wcportion;
            nanids=find(isnan(wcreduceamt));
            wcreduceamt(nanids)=0;
            SR.(ds).(wds).(rs).(ws).wcreduce(:,srt)=1; 
            SR.(ds).(wds).(rs).(ws).wcreduceamt(:,srt)=SR.(ds).(wds).(rs).(ws).wcreduceamt(:,srt)+wcreduceamt;
            if sum(wcreduceamt)>10  %WATCH - is this OK limit?
                changewc=1;  %WATCH - is this OK limit and/or need to cap iterations?
                disp(['Reducing WC:' ws ' by additional:' num2str(sum(wcreduceamt)) ' total:' num2str(sum(SR.(ds).(wds).(rs).(ws).wcreduceamt(:,srt))) ' wd:' wds ' r:' rs ' sr: ' num2str(srt) ' will reoperate admin loop']);
            end
        end
    end 
end
if changewccount < iternative  %WATCH - is this OK cap on iterations?
    changewccount=changewccount+1;
else
    disp(['Stopping reoperation to reduce wcs as hit iterations: ' num2str(changewccount)]);
    changewc=0;
end
end

end %change
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
%                 celerity=SR.(ds).(wds).(rs).celerity(:,sr);
%                 channellength=SR.(ds).(wds).(rs).channellength(:,sr);    
%                QEus=QEds;  %NEED EXCHANGE METHOD/FUNCION HERE - wont alter amounts but will alter timing
                
                if or(strcmp(srmethod,'j349'),strcmp(srmethod,'muskingum'))
%                    [QEus]=reversecelerity(QEds);
                     [QEus,exchtimerem,celerity]=reversecelerity(ds,wds,rs,sr,QEds,exchtimerem,rhours,rsteps,-999);
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
                
                % WCloc.ws listing locations of WC as cell/strings (sr/lsr/type(1-release/2-exch) is num)
                SR.(ds).WCloc.(ws)=[SR.(ds).WCloc.(ws);[{ds},{wds},{rs},{sr},{lsr},{2},{SR.(ds).(wds).(rs).wdid{sr}},{SR.(ds).(wds).(rs).dswdid{sr}}]];
  
            end
        end
    end


end
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OUTPUT - full river / gage loop amounts
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if outputgage==1
    titlelocline=[{'atWDID'},{'Div'},{'WD'},{'Reach'},{'SubReach'},{'1-USWDID/2-DSWDID'}];
    if outputgagehr==1
        titledates=cellstr(datestr(rdates(datest:end),'mm/dd/yy HH:'));
        writecell([titlelocline,titledates'],[outputfilename srmethod '_riverhr.csv']);
        writecell([titlelocline,titledates'],[outputfilename srmethod '_nativehr.csv']);
        writecell([titlelocline,titledates'],[outputfilename srmethod '_gagediffhr.csv']);
        writecell([titlelocline,titledates'],[outputfilename srmethod '_gagediffhr.csv']);
        writecell([titlelocline,titledates'],[outputfilename srmethod '_SRaddhr.csv']);
    end
    if outputgageday==1
        [yr,mh,dy,hr,mi,sec] = datevec(rdates(datest:end));
        daymat=unique([yr,mh,dy],'rows','stable');
        titledatesday=cellstr(datestr([daymat zeros(size(daymat))],'mm/dd/yy'));
        writecell([titlelocline,titledatesday'],[outputfilename srmethod '_riverday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilename srmethod '_nativeday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilename srmethod '_gagediffday.csv']);
        writecell([titlelocline,titledatesday'],[outputfilename srmethod '_SRaddday.csv']);
    end
    for i=1:length(SR.(ds).Rivloc.loc(:,1))
        loclineriver(2*i-1,:)=[SR.(ds).Rivloc.loc(i,5),SR.(ds).Rivloc.loc(i,1:4),{2}];  %includes both ds/us sides of wdids and reaches - us of reach is ds of uswdid
        loclineriver(2*i,:)=  [SR.(ds).Rivloc.loc(i,6),SR.(ds).Rivloc.loc(i,1:4),{1}];
%        outputlineriver(2*i-1,:)=SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).Qus(datest:end,SR.(ds).Rivloc.loc{i,4})';
%        outputlineriver(2*i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).Qds(datest:end,SR.(ds).Rivloc.loc{i,4})';
        outputlineriver(2*i-1,:)=SR.(ds).Rivloc.flowriv.us(datest:end,i)';
        outputlinenative(2*i-1,:)=SR.(ds).Rivloc.flownative.us(datest:end,i)';
        outputlineriver(2*i,:)=SR.(ds).Rivloc.flowriv.ds(datest:end,i)';
        outputlinenative(2*i,:)=SR.(ds).Rivloc.flownative.ds(datest:end,i)';

%        loclinereach(i,:)=  [SR.(ds).Rivloc.loc(i,6),SR.(ds).Rivloc.loc(i,1:4),{1}];  %this will list the dswdid with a 1 to say upstream of wdid 
        loclinereach(i,:)=  [SR.(ds).Rivloc.loc(i,5),SR.(ds).Rivloc.loc(i,1:4),{2}];  %this will list the uswdid with a 2 to say downstream of wdid 
        outputlinegagediff(i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).gagediffportion(datest:end,SR.(ds).Rivloc.loc{i,4})';
        outputlineSRadd(i,:)=  SR.(ds).(SR.(ds).Rivloc.loc{i,2}).(SR.(ds).Rivloc.loc{i,3}).QSRadd(datest:end,SR.(ds).Rivloc.loc{i,4})';

    end
    if outputgagehr==1
        disp('writing hourly output files for river/native amounts (hourly is a bit slow)')
        writecell([loclineriver,num2cell(outputlineriver)],[outputfilename srmethod '_riverhr.csv'],'WriteMode','append');
        writecell([loclineriver,num2cell(outputlinenative)],[outputfilename srmethod '_nativehr.csv'],'WriteMode','append');
        writecell([loclinereach,num2cell(outputlinegagediff)],[outputfilename srmethod '_gagediffhr.csv'],'WriteMode','append');
        writecell([loclinereach,num2cell(outputlineSRadd)],[outputfilename srmethod '_SRaddhr.csv'],'WriteMode','append');
    end
    if outputgageday==1
        disp('writing daily output files for river/native amounts')
        for i=1:length(daymat(:,1))
            dayids=find(yr==daymat(i,1) & mh==daymat(i,2) & dy==daymat(i,3));
            outputlinedayriver(:,i)=mean(outputlineriver(:,dayids),2);
            outputlinedaynative(:,i)=mean(outputlinenative(:,dayids),2);
            outputlinedaygagediff(:,i)=mean(outputlinegagediff(:,dayids),2);
            outputlinedaySRadd(:,i)=mean(outputlineSRadd(:,dayids),2);
        end
        writecell([loclineriver,num2cell(outputlinedayriver)],[outputfilename srmethod '_riverday.csv'],'WriteMode','append');        
        writecell([loclineriver,num2cell(outputlinedaynative)],[outputfilename srmethod '_nativeday.csv'],'WriteMode','append');        
        writecell([loclinereach,num2cell(outputlinedaygagediff)],[outputfilename srmethod '_gagediffday.csv'],'WriteMode','append');        
        writecell([loclinereach,num2cell(outputlinedaySRadd)],[outputfilename srmethod '_SRaddday.csv'],'WriteMode','append');        
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OUTPUT - water class amounts
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if outputwc==1 & isfield(SR.(ds),'WCloc')

wwcnums=SR.(ds).WCloc.wslist;
%titlelocline=[{'WCnum'},{'WC code'},{'Div'},{'WD'},{'Reach'},{'SubReach'},{'srid'},{'1-US/2-DS'},{'WDID'}];
titlelocline=[{'WCnum'},{'WC code'},{'atWDID'},{'Div'},{'WD'},{'Reach'},{'SubReach'},{'1-USWDID/2-DSWDID'}];

if outputwchr==1
    disp('writing hourly output file by water class amounts (hourly is a bit slow)')
    titledates=cellstr(datestr(rdates(datest:end),'mm/dd/yy HH:'));
    writecell([titlelocline,titledates'],[outputfilename srmethod '_wchr.csv']);
    writecell([titlelocline,titledates'],[outputfilename srmethod '_wcsraddhr.csv']);
    writecell([titlelocline,titledates'],[outputfilename srmethod '_wcreducehr.csv']);
end
if outputwcday==1
    disp('writing daily output file by water class amounts')
    [yr,mh,dy,hr,mi,sec] = datevec(rdates(datest:end));
    daymat=unique([yr,mh,dy],'rows','stable');
    titledatesday=cellstr(datestr([daymat zeros(size(daymat))],'mm/dd/yy'));
    writecell([titlelocline,titledatesday'],[outputfilename srmethod '_wcday.csv']);
    writecell([titlelocline,titledatesday'],[outputfilename srmethod '_wcreduceday.csv']);
end


for w=1:length(wwcnums)
    ws=wwcnums{w};
    clear loclinewc outputlinewc outputlinedaywc outputlinewcsradd outputlinedaywcsradd outputlinewcreduce outputlinedaywcreduce loclinewcreduce
    outwcreduce=0;k=0;
    for i=1:length(SR.(ds).WCloc.(ws)(:,1))  %JVO said wanted both us and ds of WDID (??) - OK then
        if SR.(ds).WCloc.(ws){i,6}==1 %release - list from us to ds
           loclinewc(2*i-1,:)=[{ws},{WC.(ds).WC.(ws).wc},SR.(ds).WCloc.(ws)(i,7),SR.(ds).WCloc.(ws)(i,1:4),{2}];
           outputlinewc(2*i-1,:)=SR.(ds).(SR.(ds).WCloc.(ws){i,2}).(SR.(ds).WCloc.(ws){i,3}).(ws).Qusrelease(datest:end,SR.(ds).WCloc.(ws){i,4})';
           loclinewc(2*i,:)=[{ws},{WC.(ds).WC.(ws).wc},SR.(ds).WCloc.(ws)(i,8),SR.(ds).WCloc.(ws)(i,1:4),{1}];
           outputlinewc(2*i,:)=SR.(ds).(SR.(ds).WCloc.(ws){i,2}).(SR.(ds).WCloc.(ws){i,3}).(ws).Qdsrelease(datest:end,SR.(ds).WCloc.(ws){i,4})';
           outputlinewcsradd(2*i-1,:)=SR.(ds).(SR.(ds).WCloc.(ws){i,2}).(SR.(ds).WCloc.(ws){i,3}).(ws).QSRaddus(datest:end,SR.(ds).WCloc.(ws){i,4})';
           outputlinewcsradd(2*i,:)=SR.(ds).(SR.(ds).WCloc.(ws){i,2}).(SR.(ds).WCloc.(ws){i,3}).(ws).QSRaddds(datest:end,SR.(ds).WCloc.(ws){i,4})';
           
           if isfield(SR.(ds).(SR.(ds).WCloc.(ws){i,2}).(SR.(ds).WCloc.(ws){i,3}).(ws),'wcreduceamt')
               outwcreduce=1;k=k+1;
                loclinewcreduce(k,:)=[{ws},{WC.(ds).WC.(ws).wc},SR.(ds).WCloc.(ws)(i,7),SR.(ds).WCloc.(ws)(i,1:4),{1}]; %lists us wdid
                outputlinewcreduce(k,:)=SR.(ds).(SR.(ds).WCloc.(ws){i,2}).(SR.(ds).WCloc.(ws){i,3}).(ws).wcreduceamt(datest:end,SR.(ds).WCloc.(ws){i,4})';
           end
           
        else  %exchange - list from ds to us - if ok from us to ds could delete these
           loclinewc(2*i-1,:)=[{ws},{WC.(ds).WC.(ws).wc},SR.(ds).WCloc.(ws)(i,8),SR.(ds).WCloc.(ws)(i,1:4),{1}];
           outputlinewc(2*i-1,:)=SR.(ds).(SR.(ds).WCloc.(ws){i,2}).(SR.(ds).WCloc.(ws){i,3}).(ws).Qdsrelease(datest:end,SR.(ds).WCloc.(ws){i,4})';
           loclinewc(2*i,:)=[{ws},{WC.(ds).WC.(ws).wc},SR.(ds).WCloc.(ws)(i,7),SR.(ds).WCloc.(ws)(i,1:4),{2}];
           outputlinewc(2*i,:)=SR.(ds).(SR.(ds).WCloc.(ws){i,2}).(SR.(ds).WCloc.(ws){i,3}).(ws).Qusrelease(datest:end,SR.(ds).WCloc.(ws){i,4})';
           outputlinewcsradd(2*i-1,:)=zeros(1,length(rdates(datest:end)));
           outputlinewcsradd(2*i,:)=zeros(1,length(rdates(datest:end)));
        end
    end 
    
    if outputwchr==1
        writecell([loclinewc,num2cell(outputlinewc)],[outputfilename srmethod '_wchr.csv'],'WriteMode','append');
        writecell([loclinewc,num2cell(outputlinewcsradd)],[outputfilename srmethod '_wcsraddhr.csv'],'WriteMode','append');
           if outwcreduce==1
                writecell([loclinewcreduce,num2cell(outputlinewcreduce)],[outputfilename srmethod '_wcreducehr.csv'],'WriteMode','append');
           end
    end

    if outputwcday==1
        for i=1:length(daymat(:,1))
            dayids=find(yr==daymat(i,1) & mh==daymat(i,2) & dy==daymat(i,3));
            outputlinedaywc(:,i)=mean(outputlinewc(:,dayids),2);
            outputlinedaywcsradd(:,i)=mean(outputlinewcsradd(:,dayids),2);
           if outwcreduce==1
                outputlinedaywcreduce(:,i)=mean(outputlinewcreduce(:,dayids),2);
           end
        end
        writecell([loclinewc,num2cell(outputlinedaywc)],[outputfilename srmethod '_wcday.csv'],'WriteMode','append');        
        writecell([loclinewc,num2cell(outputlinedaywcsradd)],[outputfilename srmethod '_wcsraddday.csv'],'WriteMode','append');             
        if outwcreduce==1
            writecell([loclinewcreduce,num2cell(outputlinedaywcreduce)],[outputfilename srmethod '_wcreduceday.csv'],'WriteMode','append');             
        end
    end
end

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% test plotting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if plotmovie==1
    
Rt=1;SRt=1;Rb=8;SRb=2;
%Rt=1;SRt=1;Rb=6;SRb=4;


figure('Renderer','zbuffer','Position',[349,93,1006.4,691.2]);
% plot([0 35],[0 660]);
%set(gca,'Ylim',[-200 1500],'Xlim',[0 100])
%    set(gca,'Ylim',[-200 1500],'Xlim',[0 130])
    set(gca,'Ylim',[0 figtop],'Xlim',[0 130])

 axis manual;
 set(gca,'NextPlot','replaceChildren');
 
releasestartid=25;
ts1=1100;

ds='D2';

%for wd=WDlist(2)
for wd=17
    wds=['WD' num2str(wd)];
    wwcnums=WC.(ds).(wds).wwcnums;
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
     plotlinex=[plotlinex plotx plotx plotx+SR.(ds).(wds).(rs).channellength(sr)];
     plotx=plotx+SR.(ds).(wds).(rs).channellength(sr);
     
     plotline(k+1:k+3,1)=[SR.(ds).(wds).(rs).Qusnode(ts,sr);SR.(ds).(wds).(rs).Qus(ts,sr);SR.(ds).(wds).(rs).Qds(ts,sr)];
     lsr=SR.(ds).(wds).(rs).subreachid(sr);
     kwr=0;kwe=1;
     for w=1:length(wwcnums)
         ws=wwcnums{w};
         if isfield(SR.(ds).(wds),ws)
         if WC.(ds).WC.(ws).type==1 %for exchanges add onto native line
            kwe=kwe+1;
            plotline(k+1:k+3,kwe)=[SR.(ds).(wds).(ws).Qusnoderelease(ts,lsr);SR.(ds).(wds).(ws).Qusrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsrelease(ts,lsr)];
         else
            kwr=kwr+1;
            if length(SR.(ds).(wds).(ws).Qusrelease(ts,:))>=lsr
                plotlinerelease(k+1:k+3,kwr)=[SR.(ds).(wds).(ws).Qusnoderelease(ts,lsr);SR.(ds).(wds).(ws).Qusrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsrelease(ts,lsr)];
            else
                plotlinerelease(k+1:k+3,kwr)=[0,0,0];
            end
                
         end
          
%         plotlinerelease(k+1:k+3,w)=[SR.(ds).(wds).(ws).Qusrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsnodesrelease(ts,lsr)];
         
%         plotlinerelease.(ws)=[plotlinerelease.(ws) SR.(ds).(wds).(ws).Qusrelease(ts,lsr) SR.(ds).(wds).(ws).Qdsrelease(ts,lsr) SR.(ds).(wds).(ws).Qdsnodesrelease(ts,lsr)];
        
%          if (wd>=WDtr & r>=Rtr & sr>=SRtr) & (wd<=WDbr & r<=Rbr & sr<=SRbr)
% %         plotlinenative.(ws)=[plotlinenative SR.(ds).(wds).(rs).(ws).Quspartial(ts,sr) SR.(ds).(wds).(rs).(ws).Qdspartial(ts,sr) SR.(ds).(wds).(rs).(ws).Qdsnodespartial(ts,sr)];
%          plotlinerelease(k+1:k+3,w)=[SR.(ds).(wds).(rs).(ws).Qusrelease(ts,sr);SR.(ds).(wds).(rs).(ws).Qdsrelease(ts,sr);SR.(ds).(wds).(rs).(ws).Qdsnodesrelease(ts,sr)];
%          else
%             plotlinerelease(k+1:k+3,w)=[0;0;0];
%          end
         end
     end
     k=k+3;

%     plotline=[plotline SR.(ds).(wds).(rs).Qdsnodes(ts,sr)];
%     plotlinenative=[plotlinenative SR.(ds).(wds).(rs).(ws).Qdsnodespartial(ts,sr)];
    
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
end
        
% reversecelerity(F,1,8)

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

cmin=1;
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
    celerity=celeritya*max(cmin,Qus).^celerityb;
end
if dispersion==-999
    dispersiona=SR.(ds).(wds).(rs).dispersiona(sr);
    dispersionb=SR.(ds).(wds).(rs).dispersionb(sr);
%    dispersion=dispersiona*Qusavg^dispersionb;
    dispersion=dispersiona*max(cmin,Qus).^dispersionb;
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

cmin=1;   
Qusavg=max(cmin,mean(Qus));  %watch - this would be different than TLAP; but think basing on that subreach flow might be more correct
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


function [QEus,srtimerem,celerity]=reversecelerity(ds,wds,rs,sr,QEds,exchtimerem,rhours,rsteps,celerity)
global SR

channellength=SR.(ds).(wds).(rs).channellength(sr);

if celerity==-999
    Qriv=(SR.(ds).(wds).(rs).Qus(:,sr)+SR.(ds).(wds).(rs).Qds(:,sr))/2;
    posids=find(QEds<0);  %using time with exchange (QEds should be negative) to calc avg; if spaces or periods may want to break down by period(?), could have celerity time series but time gets complicated..
    Qdstot=-1*QEds+Qriv;  %for celerity adding river to exchange amount (ie timing if the exchange would have been released from us)
    Qdsavg=mean(Qdstot(posids));
    celeritya=SR.(ds).(wds).(rs).celeritya(sr);
    celerityb=SR.(ds).(wds).(rs).celerityb(sr);
    celerity=celeritya*Qdsavg^celerityb;
end

%believe celerity is in ft/s
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





