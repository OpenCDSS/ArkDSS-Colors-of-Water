%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% StateTL
% Matlab (preliminary) Colors of Water Transit Loss and Timing engine
%


cd C:\Projects\Ark\ColorsofWater\matlab
clear all
disp(datestr(now))
basedir=cd;basedir=[basedir '\'];
% j349dir=[basedir 'j349dir\'];
% j349dir=basedir;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% runoptions
% - need to put most of this into input file or text file

readinfofile=2;  %1 reads from excel and saves mat file; 2 reads mat file;
readgageinfo=2;  %if using real gage data, 1 reads from REST, 2 reads from file - watch out currently saves into SR file
infofilename='StateTL_inputdata.xlsx';
pullnewdivrecs=2;  %0 if want to repull all from REST, 1 if only pull new/modified from REST for same period, 2 load from saved mat file
plotmovie=0;
doexchanges=1;

datestart=datenum(2018,4,01);
figtop=1500;
%rdays=155; rhours=4;
%spinupdays=60;
rdays=60; rhours=1;
spinupdays=45;
rsteps=rdays*24/rhours;
gainchangelimit=0.1;

flowcriteria=5; %to establish gage and node flows: 1 low, 2 avg, 3 high flow values from livingston; envision 4 for custom entry; 5 for actual flows; 6 average for xdays/yhours prior to now/date; 7 average between 2 dates


%PROCESSING OPTIONS - currently hardwired - will need to automate in both baseflow and admin loops
reswdidlist.D2.WD17=[{'1403526'},{'1703525'},{'1703511'}]; %release wdids pueblo, meredith, put into input data for wd17; Ftn Crk? Purg (To: reference?)?
reswdidlist.D2.WD172=[{'1700801'}]; %release wdids pueblo, meredith, put into input data for wd17; Ftn Crk? Purg (To: reference?)?
reswdidlist.D2.WD10=[{'1003657'}]; %
reswdidlist.D2.WD11=[{'1109999'}]; %
reswdidlist.D2.WD112=[{'1103503'}]; %
%reswdidlist=[{'1403526'},{'1703525'},{'1703511'}]; %release wdids pueblo, meredith, put into input data for wd17; Ftn Crk? Purg (To: reference?)?

d=2;ds='D2';
WDlist=[112,11,10,172,17]; %could be [17,67] etc but needs to be in order of top/tribs to bottom
%srmethod='j349';
srmethod='muskingum'; %percent loss TL plus muskingum-cunge for travel time
pred=0;  %if pred=0 subtracts water class from existing flows, if 1 adds to existing gage flows



%%%%%%%%%%%%%%%%%%%%%%%%%%
%READ SUBREACH INFORMATION
%%%%%%%%%%%%%%%%%%%%%%%%%%
global SR

if readinfofile==1

%%%%%%%%%%%%%%%%%%%%%%%%%%    
% read subreach data    
disp('reading subreach info from file')

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
        c.di=num2str(inforaw{i,infocol.div});
        c.wd=num2str(inforaw{i,infocol.wd});
        c.re=num2str(inforaw{i,infocol.reach});
        c.sr=num2str(inforaw{i,infocol.subreach});
        
        SR.(['D' c.di]).WD=[];  %just for looks - these three are just to maintain order so don't have to reorder
        SR.(['D' c.di]).(['WD' c.wd]).R=[];
        SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).SR=[];
        
        %  SR.(['D' c.di]).(['WD' c.wd]).(['R' c.re]).livingstonsubreach(v.sr)=v.ls; %delete when expanding model
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
       
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% just to add numbers of WD, R, and SR for looping etc
Dlist=fieldnames(SR);
for i=1:length(Dlist)
    dls=Dlist{i};
    WDlisti=fieldnames(SR.(dls));
    for j=2:length(WDlisti)
        wds=WDlisti{j};
        wd=str2double(wds(3:end));
        SR.(dls).WD(j-1)=wd;
        Rlistj=fieldnames(SR.(dls).(wds));
        for k=2:length(Rlistj)
            rs=Rlistj{k};
            r=str2double(rs(2:end));
            if r>0
               SR.(dls).(wds).R=[SR.(dls).(wds).R,r]; 
            end
            numsr=length(SR.(dls).(wds).(rs).subreachid);  %WATCH - if change that 'subreachid' row heading will need to change here, can use any of variables
            SR.(dls).(wds).(rs).SR=[1:numsr];
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Read WDIDs located at nodes
% CHANGE - currently in main SR table but need to redo here as seperate table - seperated out so can do here..
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
        c.di=num2str(inforaw{i,infocol.div});
        c.wd=num2str(inforaw{i,infocol.wd});
        c.re=num2str(inforaw{i,infocol.reach});
        c.sr=num2str(inforaw{i,infocol.subreach});
        v.t1=inforaw{i,infocol.type1};if ischar(v.t1); v.t1=str2num(v.t1); end
        v.l1=inforaw{i,infocol.low1};if ischar(v.l1); v.l1=str2num(v.l1); end
        v.a1=inforaw{i,infocol.avg1};if ischar(v.a1); v.a1=str2num(v.a1); end
        v.h1=inforaw{i,infocol.high1};if ischar(v.h1); v.h1=str2num(v.h1); end
        v.t2=inforaw{i,infocol.type2};if ischar(v.t2); v.t2=str2num(v.t2); end
        v.l2=inforaw{i,infocol.low2};if ischar(v.l2); v.l2=str2num(v.l2); end
        v.a2=inforaw{i,infocol.avg2};if ischar(v.a2); v.a2=str2num(v.a2); end
        v.h2=inforaw{i,infocol.high2};if ischar(v.h2); v.h2=str2num(v.h2); end
        c.s1=num2str(inforaw{i,infocol.station1});
        c.p1=num2str(inforaw{i,infocol.parameter1});
        c.w1=num2str(inforaw{i,infocol.wdid1});
        c.n1=num2str(inforaw{i,infocol.name1});
        c.s2=num2str(inforaw{i,infocol.station2});
        c.p2=num2str(inforaw{i,infocol.parameter2});
        c.w2=num2str(inforaw{i,infocol.wdid2});
        c.n2=num2str(inforaw{i,infocol.name2});   

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

%%%%%%%%%%%%%%%%%%
% stage discharge data
% this will have to be expanded as expand reaches

[infonum,infotxt,inforaw]=xlsread([basedir infofilename],'stagedischarge');
[infonumrow infonumcol]=size(infonum);
[inforawrow inforawcol]=size(inforaw);

for wd=WDlist
    wds=['WD' num2str(wd)];
    SR.(ds).(wds).stagedischarge=infonum;
end

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


flowtestloc=[2,17,7,4,1];

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
                        try
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
                        catch
                            disp(['WARNING: didnt get telemetry data for gage: ' station ' parameter: ' parameter ' have to use flow rate for conditions: ' flow ])
                            SR.(ds).(wds).(rs).Qnode(:,sr,n)=SR.(ds).(wds).(rs).(flow)(n,sr)*ones(rsteps,1);
                        end
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
        
for reswdidl=1:length(reswdidlist.(ds).(wds))
    reswdid=reswdidlist.(ds).(wds){reswdidl};
    %for type=[7,4,8] %release, exchange, apd(?)
    %divrecdata=webread(divrecdayurl,'format','json','min-datameasdate',datestr(datestart,23),'max-datameasdate',datestr(dateend,23),'min-dataValue',0.0001,'wdid',reswdid,'wcIdentifier',['*T:' num2str(type) '*'],'min-modified',datestr(WC.date.modified,23),weboptions('Timeout',30));
    
    try
        disp(['Using HBREST for  ' reswdid ' from: ' datestr(datestart,23) ' to ' datestr(dateend,23) ' and modified: ' datestr(modified) ]);
        divrecdata=webread(divrecdayurl,'format','json','min-datameasdate',datestr(datestart,23),'max-datameasdate',datestr(dateend,23),'min-dataValue',0.0001,'wdid',reswdid,'min-modified',datestr(modified+1/24/60,'mm/dd/yyyy HH:MM'),weboptions('Timeout',30));
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
    
    for r=Rt:Rb
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


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ADMIN LOOP FOR WATERCLASSES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SR.(ds).WCloc.wslist=[];
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
if ~isfield(SR.(ds).WCloc,ws)
    SR.(ds).WCloc.wslist=[SR.(ds).WCloc.wslist,{ws}];
    SR.(ds).WCloc.(ws)=[];
end

%disp(['running admin loop for D:' ds ' WD:' wds ' wc:' ws]) 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% routing of water classes
%  WATCH!-currently requires WDID list to be in spatial order to know whats going upstream
%         may want to change that to ordered lists 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

wdinwdidlist=find([SR.(ds).WDID{:,3}]==wd);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   the next/first block is looking for water classes that were passed from another WDreach
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
%    fromlsr=SR.(ds).(wds).park{parkwcid,8};
%    release=SR.(ds).(fromWD).(ws).Qdsnodesrelease(:,fromlsr);
    fromRs=SR.(ds).(wds).park{parkwcid,5};
    fromsr=SR.(ds).(wds).park{parkwcid,6};
    release=SR.(ds).(fromWDs).(fromRs).(ws).Qdsnodesrelease(:,fromsr);
else
    wdidfrom=WC.(ds).WC.(ws).wdid;
    wdidfromid=intersect(find(strcmp(SR.(ds).WDID(:,1),wdidfrom)),wdinwdidlist);
    release=WC.(ds).(wds).(ws).release;
end
    
wdidto=WC.(ds).WC.(ws).to;
wdidtoid=find(strcmp(SR.(ds).WDID(:,1),wdidto));
wdidtoidwd=intersect(wdidtoid,wdinwdidlist);

parkwdidid=0;
exchtype=0;
if isempty(wdidtoid)                                    %wdid To: listed in divrecs not in inputdata listing of wdids
    wdidtoid=wdidfromid;
    disp(['WARNING: not routing (either exchange or missing) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ' sum: ' num2str(sum(release)) ]);
else
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
        wdidtoids=find(strcmp(SR.(ds).WDID(:,1),[wdidto(1:2) '*']));  %looking for internal connection point within current WD
        connectionid=intersect(wdidtoids,wdinwdidlist);
        if ~isempty(connectionid)      %us exchange from DS branch within WD (exchtype=3)
            exchtype=3;
            SR.(ds).EXCH.(ws).wdidtoid=wdidtoid;
            SR.(ds).EXCH.(ws).WDto=SR.(ds).WDID{wdidtoid(1),3};
            wdidtoid=connectionid;
            parkwdidid=setdiff(wdidtoids,wdinwdidlist);
            parktype=2;  %2 push DS releases to internal node
            SR.(ds).EXCH.(ws).wdidfromid=parkwdidid;
            SR.(ds).EXCH.(ws).WDfrom=SR.(ds).WDID{parkwdidid,3};
            SR.(ds).EXCH.(ws).exchtype=3;            
            disp(['routing: ' ws ' ' WC.(ds).WC.(ws).wc ' To:' wdidto(1:2) '*' ' US exchange first routing with TL to internal confluence point within WD reach']);
            disp(['WARNING: exchange not yet routing (external to WD) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ' sum: ' num2str(sum(release)) ]);
            
        elseif ~isempty(wdidtoidwd)                    %us exchange within WD (exchtype=1)
            exchtype=1;
            SR.(ds).EXCH.(ws).wdidtoid=wdidtoidwd(end);  %last in list in case multiple reach listing (will go to lowest)
            SR.(ds).EXCH.(ws).wdidfromid=wdidfromid;
            SR.(ds).EXCH.(ws).WDfrom=wd;
            SR.(ds).EXCH.(ws).WDto=wd;
            SR.(ds).EXCH.(ws).exchtype=1;
            wdidtoid=wdidfromid;  %leaving it there
            disp(['WARNING: exchange not yet routing (internal to WD) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ' sum: ' num2str(sum(release)) ]);
        else                                           %us exchange in different WD (exchtype=2)
            exchtype=2;
            SR.(ds).EXCH.(ws).wdidtoid=wdidtoid(end);
            SR.(ds).EXCH.(ws).wdidfromid=wdidfromid;
            SR.(ds).EXCH.(ws).WDfrom=wd;
            SR.(ds).EXCH.(ws).WDto=SR.(ds).WDID{wdidtoid(1),3};
            SR.(ds).EXCH.(ws).exchtype=2;
            wdidtoid=wdidfromid;
%            wdidtoid=wdinwdidlist(end);
            disp(['WARNING: exchange not yet routing (external to WD) To: ' wdidto ' Ty: ' num2str(WC.(ds).WC.(ws).type) ' for  ' ws(2:end) ' ' WC.(ds).WC.(ws).wc ' sum: ' num2str(sum(release)) ]);    
        end

    end       
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
% if WC.(ds).WC.(ws).type==1 %exchange (?)  %exchange defined by upstream record - not using anymore??
%     release=release*-1;
% end
srids=SR.(ds).(wds).(['R' num2str(Rb)]).subreachid(end);  %just to set size of release matrices
SR.(ds).(wds).(ws).Qusrelease(length(rdates),srids)=0;     %just used for plotting, maybe better way..
SR.(ds).(wds).(ws).Qdsrelease(length(rdates),srids)=0;
SR.(ds).(wds).(ws).Qdsnodesrelease(length(rdates),srids)=0;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



if wdidtoid==wdidfromid   %CONDITON FOR EXCHANGES (or missing releases) - Exchanges try to put into Qdsnodes of US reach so consistent (missing gets parked in Qus)
    rs=['R' num2str(SR.(ds).WDID{wdidfromid,4})];
    sr=SR.(ds).WDID{wdidfromid,5};
    if exchtype<=2  %for in-district exchange putting into Qdsnodes of reach above node rather than Qus of reach below node
        wdsnew=wds;
        if SR.(ds).WDID{wdidfromid,4}==0 %at top of wd
            wdidnewid=setdiff(find(strcmp(SR.(ds).WDID(:,1),wdidfrom)),wdinwdidlist);
            wdsnew=['WD' num2str(SR.(ds).WDID{wdidnewid,3})];
            rs=['R' num2str(SR.(ds).WDID{wdidnewid,4})];
            sr=SR.(ds).WDID{wdidnewid,5};
        end 
        lsr=SR.(ds).(wdsnew).(rs).subreachid(sr);
        SR.(ds).(wdsnew).(rs).(ws).Qusrelease(:,sr)=zeros(length(rdates),1);
        SR.(ds).(wdsnew).(rs).(ws).Qdsrelease(:,sr)=zeros(length(rdates),1);
        SR.(ds).(wdsnew).(rs).(ws).Qdsnodesrelease(:,sr)=release;
        SR.(ds).(wdsnew).(ws).Qusrelease(:,lsr)=zeros(length(rdates),1);
        SR.(ds).(wdsnew).(ws).Qdsrelease(:,lsr)=zeros(length(rdates),1);
        SR.(ds).(wdsnew).(ws).Qdsnodesrelease(:,lsr)=release;
        SR.(ds).WCloc.(ws)=[SR.(ds).WCloc.(ws);[{ds},{wdsnew},{rs},{sr},{lsr},{2}]];  %type=1release,2exchange
    else
        lsr=SR.(ds).(wds).(rs).subreachid(sr);
        SR.(ds).(wds).(rs).(ws).Qusrelease(:,sr)=release;
        SR.(ds).(wds).(rs).(ws).Qdsrelease(:,sr)=zeros(length(rdates),1);
        SR.(ds).(wds).(rs).(ws).Qdsnodesrelease(:,sr)=zeros(length(rdates),1);
%         SR.(ds).(wds).(ws).Qusrelease(:,lsr)=release;    %for missing at pueblo res this currently puts lsr at 0
%         SR.(ds).(wds).(ws).Qdsrelease(:,lsr)=zeros(length(rdates),1);
%         SR.(ds).(wds).(ws).Qdsnodesrelease(:,lsr)=zeros(length(rdates),1);
        SR.(ds).WCloc.(ws)=[SR.(ds).WCloc.(ws);[{ds},{wds},{rs},{sr},{lsr},{2}]];  %type=1release,2exchange
    end
else
    
WDtr=SR.(ds).WDID{wdidfromid,3};
WDbr=SR.(ds).WDID{wdidtoid,3};
Rtr=SR.(ds).WDID{wdidfromid,4};
Rbr=SR.(ds).WDID{wdidtoid,4};
if Rtr==0
    Rtr=1;SRtr=1;
else
    SRtr=SR.(ds).WDID{wdidfromid,5}+1; %WATCH!! wdid listed is at bottom of reach - so for releases from starts at top of next reach, top reach 0 put into srid 1 (WARNING IF from wdid ever be at bottom of Reach?)
end
SRbr=SR.(ds).WDID{wdidtoid,5};
SRtrd=SR.(ds).WDID{wdidfromid,6};
SRbrd=SR.(ds).WDID{wdidtoid,6};
    

for wd=WDtr:WDbr
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
%            [Qds,celerity,dispersion]=runj349f(ds,wds,rs,sr,Qus,gainportion,rdays,rhours,rsteps,basedir,-999,-999); %celerity/disp based on gage-release (ie partial) flows
            [Qds,celerity,dispersion]=runj349f(ds,wds,rs,sr,Qus,gainportion,rdays,rhours,rsteps,basedir,celerity,dispersion); %celerity/disp based on gage flows
        elseif strcmp(srmethod,'muskingum')
%            [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,-999,-999);
            [Qds,celerity,dispersion]=runmuskingum(ds,wds,rs,sr,Qus,rhours,rsteps,celerity,dispersion);
        end
        Qds=max(0,Qds);
    end
    Qavg=(max(Qus,1)+max(Qds,1))/2;
    width=10.^((log10(Qavg)*SR.(ds).(wds).(rs).widtha(sr))+SR.(ds).(wds).(rs).widthb(sr));
    if WC.(ds).WC.(ws).type==1 %exchange
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
    Qdsnodes=max(0,Qdsnodes);  %this can reduce or eliminate the water class if estimated node flow (at internal sr's) is less than water class flow amount 
    
    SR.(ds).(wds).(rs).(ws).Quspartial(:,sr)=Qus;
    SR.(ds).(wds).(rs).(ws).Qdspartial(:,sr)=Qds;
    SR.(ds).(wds).(rs).(ws).Qdsnodespartial(:,sr)=Qdsnodes;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    % calc of actual WC amount
    if pred~=1  %if not prediction, wc amounts are gage amount - "partial" (gage-wcrelease) amount 
        Qusrelease=SR.(ds).(wds).(rs).Qus(:,sr)-Qus;
        Qdsrelease=SR.(ds).(wds).(rs).Qds(:,sr)-Qds;
        Qdsnodesrelease=SR.(ds).(wds).(rs).Qdsnodes(:,sr)-Qdsnodes;
    else        %if prediction, wc amounts are "partial" (gage+wcrelease) amount - gage amount 
        Qusrelease=Qus-SR.(ds).(wds).(rs).Qus(:,sr);
        Qdsrelease=Qds-SR.(ds).(wds).(rs).Qds(:,sr);
        Qdsnodesrelease=Qdsnodes-SR.(ds).(wds).(rs).Qdsnodes(:,sr);
    end
    
    % wc listed within R at sr position
    SR.(ds).(wds).(rs).(ws).Qusrelease(:,sr)=Qusrelease;
    SR.(ds).(wds).(rs).(ws).Qdsrelease(:,sr)=Qdsrelease;
    SR.(ds).(wds).(rs).(ws).Qdsnodesrelease(:,sr)=Qdsnodesrelease;
    
    % wc listed within WD at subreachid position (only for movie plotting?)
    lsr=SR.(ds).(wds).(rs).subreachid(sr);
    SR.(ds).(wds).(ws).Qusrelease(:,lsr)=Qusrelease;
    SR.(ds).(wds).(ws).Qdsrelease(:,lsr)=Qdsrelease;
    SR.(ds).(wds).(ws).Qdsnodesrelease(:,lsr)=Qdsnodesrelease;

    % WCloc.ws listing locations of WC as cell/strings (sr/lsr/type(1-release/2-exch) is num)
    SR.(ds).WCloc.(ws)=[SR.(ds).WCloc.(ws);[{ds},{wds},{rs},{sr},{lsr},{1}]];
 
    Qus=Qdsnodes;
    
end %sr

    end %r
end %wd
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% parking - transfering waterclass from one WD to another
%   for releases, ds WDreach should then pick up, for exchanges probably wait for exchange loop
if parkwdidid ~= 0  %placing park - place wcnum and park parameters in downstream WDreach 
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
        SR.(ds).(pwds).park=[{ws},{parkwdid},{parkwdidid},{wds},{rs},{sr},{parktype},{lsr}];
    else
        SR.(ds).(pwds).park=[SR.(ds).(pwds).park;{ws},{parkwdid},{parkwdidid},{wds},{rs},{sr},{parktype},{lsr}];        
    end
    if parktype==2  %for us exchange through internal confluence, placing routed exchange amount at end of US WDreach
        parklsr=SR.(ds).(pwds).(['R' num2str(SR.(ds).(pwds).R(end))]).subreachid(end);
        SR.(ds).(pwds).(prs).(ws).Qusrelease(:,psr)=zeros(length(rdates),1);
        SR.(ds).(pwds).(prs).(ws).Qdsrelease(:,psr)=zeros(length(rdates),1);
%        SR.(ds).(pwds).(prs).(ws).Qdsnodesrelease(:,psr)=SR.(ds).(wds).(ws).Qdsnodesrelease(:,lsr);  %(is it right to put into dsnodes?)
        SR.(ds).(pwds).(prs).(ws).Qdsnodesrelease(:,psr)=SR.(ds).(wds).(rs).(ws).Qdsnodesrelease(:,sr);  %(is it right to put into dsnodes?)
        SR.(ds).(pwds).(ws).Qusrelease(:,parklsr)=zeros(length(rdates),1);
        SR.(ds).(pwds).(ws).Qdsrelease(:,parklsr)=zeros(length(rdates),1);
        SR.(ds).(pwds).(ws).Qdsnodesrelease(:,parklsr)=SR.(ds).(wds).(ws).Qdsnodesrelease(:,lsr);  %(is it right to be dsnodes?)
    elseif parktype==3
        
        SRtr=SR.(ds).WDID{wdidfromid,5}+1;

    wdidfromid=SR.(ds).EXCH.(ws).wdidfromid;
    wdidtoid=SR.(ds).EXCH.(ws).wdidtoid;
    WDb=SR.(ds).EXCH.(ws).WDfrom;
    
    wdidfromlocs=SR.(ds).WDID(wdidfromid,:);
    wdidtolocs=SR.(ds).WDID(wdidtoid,:);
    wdidfrom=wdidfromlocs{1,1};
    Rb=wdidfromlocs{1,4};SRb=wdidfromlocs{1,5};
    
    
    if WDb==wdidtolocs{1,3}
        Rt=wdidtolocs{1,4};SRt=wdidtolocs{1,5};
    else
        Rt=0;SRt=1;
    end
    
    if Rb==0
        parkwdidid=setdiff(find(strcmp(SR.(ds).WDID(:,1),SR.(ds).WDID(wdidfromid,1))),find([SR.(ds).WDID{:,3}]==WDb));  %looking for id of same WDID in different WD
        parkwdidlocs=SR.(ds).WDID(parkwdidid,:);
        pwds=['WD' num2str(parkwdidlocs{1,3})];
        prs=['WD' num2str(parkwdidlocs{1,4})];
        psr=parkwdidlocs{1,5};
        SR.(ds).(pwds).(prs).(ws).Qusrelease(:,psr)=zeros(length(rdates),1);
        SR.(ds).(pwds).(prs).(ws).Qdsrelease(:,psr)=zeros(length(rdates),1);
        SR.(ds).(pwds).(prs).(ws).Qdsnodesrelease(:,psr)=SR.(ds).(['WD' num2str(WDb)]).(['R' num2str(Rb)]).Qusrelease(:,SRb);  %(is it right to be dsnodes?)
    end
    end
    
    
end

end %j - waterclass
end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ADMIN LOOP - EXCHANGES - FOR WATERCLASSES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if doexchanges==1 & isfield(SR.(ds),'EXCH') 
wwcnums=fieldnames(SR.(ds).EXCH);

for w=1:length(wwcnums)
    ws=wwcnums{w};
    wdidfromid=SR.(ds).EXCH.(ws).wdidfromid;
    wdidtoid=SR.(ds).EXCH.(ws).wdidtoid;
    WDb=SR.(ds).EXCH.(ws).WDfrom;
    
    wdidfromlocs=SR.(ds).WDID(wdidfromid,:);
    wdidtolocs=SR.(ds).WDID(wdidtoid,:);
    wdidfrom=wdidfromlocs{1,1};
    Rb=wdidfromlocs{1,4};SRb=wdidfromlocs{1,5};
    
    
    if WDb==wdidtolocs{1,3}
        Rt=wdidtolocs{1,4};SRt=wdidtolocs{1,5};
    else
        Rt=0;SRt=1;
    end
    
    if Rb==0
        parkwdidid=setdiff(find(strcmp(SR.(ds).WDID(:,1),SR.(ds).WDID(wdidfromid,1))),find([SR.(ds).WDID{:,3}]==WDb));  %looking for id of same WDID in different WD
        parkwdidlocs=SR.(ds).WDID(parkwdidid,:);
        pwds=['WD' num2str(parkwdidlocs{1,3})];
        prs=['WD' num2str(parkwdidlocs{1,4})];
        psr=parkwdidlocs{1,5};
        SR.(ds).(pwds).(prs).(ws).Qusrelease(:,psr)=zeros(length(rdates),1);
        SR.(ds).(pwds).(prs).(ws).Qdsrelease(:,psr)=zeros(length(rdates),1);
        SR.(ds).(pwds).(prs).(ws).Qdsnodesrelease(:,psr)=SR.(ds).(['WD' num2str(WDb)]).(['R' num2str(Rb)]).Qusrelease(:,SRb);  %(is it right to be dsnodes?)
        
        SR.(ds).(pwds).(prs).(ws).Qusrelease(:,psr)=zeros(length(rdates),1);
        SR.(ds).(pwds).(prs).(ws).Qdsrelease(:,psr)=zeros(length(rdates),1);
        SR.(ds).(pwds).(prs).(ws).Qdsnodesrelease(:,psr)=SR.(ds).(wds).(ws).Qdsnodesrelease(:,lsr);  %(is it right to be dsnodes?)
        
        
    else
    
    for r=Rb:-1:Rt
        rs=['R' num2str(r)];    
    
    
    
    wdtop=SR.(ds).EXCH.(ws).WDto;
    wdbot=SR.(ds).EXCH.(ws).WDfrom;
    
    wds=['WD' num2str(wd)];
    Rt=SR.(ds).(wds).R(1);
    Rb=SR.(ds).(wds).R(end);
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
     plotlinex=[plotlinex plotx plotx+SR.(ds).(wds).(rs).channellength(sr) plotx+SR.(ds).(wds).(rs).channellength(sr)];
     plotx=plotx+SR.(ds).(wds).(rs).channellength(sr);
     
     plotline(k+1:k+3,1)=[SR.(ds).(wds).(rs).Qus(ts,sr);SR.(ds).(wds).(rs).Qds(ts,sr);SR.(ds).(wds).(rs).Qdsnodes(ts,sr)];
     lsr=SR.(ds).(wds).(rs).subreachid(sr);
     kwr=0;kwe=1;
     for w=1:length(wwcnums)
         ws=wwcnums{w};
         if isfield(SR.(ds).(wds),ws)
         if WC.(ds).WC.(ws).type==1 %for exchanges add onto native line
            kwe=kwe+1;
            plotline(k+1:k+3,kwe)=[SR.(ds).(wds).(ws).Qusrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsnodesrelease(ts,lsr)];
         else
            kwr=kwr+1;
            plotlinerelease(k+1:k+3,kwr)=[SR.(ds).(wds).(ws).Qusrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsrelease(ts,lsr);SR.(ds).(wds).(ws).Qdsnodesrelease(ts,lsr)];
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








