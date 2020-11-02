function SRhdplot(HD,VARopt)
% =======================================================================
% Plot the HD shocks computed with SR (sign restriction procedure)
% =======================================================================
% SRhdplot(HD,VARopt)
% -----------------------------------------------------------------------
% INPUT
%   - HD: structure from SR
%   - VARopt: options of the VAR (from VARmodel and SR)
% =======================================================================
% VAR Toolbox 3.0
% Ambrogio Cesa Bianchi, March 2020
% ambrogio.cesabianchi@gmail.com
% -----------------------------------------------------------------------


%% Check inputs
%================================================
if ~exist('VARopt','var')
    error('You need to provide VAR options (VARopt from VARmodel)');
end
% If there is VARopt check that vnames and snames are not empty
vnames = VARopt.vnames;
snames = VARopt.snames;
if isempty(vnames)
    error('You need to add label for endogenous variables in VARopt');
end
if isempty(snames)
    error('You need to add label for shocks in VARopt');
end
% If there is no date specified, plot from first available observation
datesnum = VARopt.datesnum;
datestxt = VARopt.datestxt;
firstdate = VARopt.firstdate;
if isempty(snames)
    fo = 1;
else
    if isempty(VARopt.datesnum)
        error('Need to input a vector of dates VARoption.datesnum')
        
    end
    fo = find(firstdate==datesnum);
end


%% Check inputs and define some parameters
%===============================================
filename = [VARopt.figname 'HD_'];
quality = VARopt.quality;
suptitle = VARopt.suptitle;
pick = VARopt.pick;

% Initialize HD matrix
nshocks = length(snames); [x, nvars, ~] = size(HD.shock);

% If one shock is chosen, set the right value for nshocks
if pick<0 || pick>nvars
    error('The selected shock is non valid')
else
    if pick==0
        pick=1;
    else
        nshocks = pick;
    end
end


%% Plot
%================================================
FigSize(VARopt.FigSize(1),VARopt.FigSize(2))
for ii=pick:nvars
    colormap winter
    H = BarPlot(squeeze(HD.shock(fo:end,:,ii))); hold on; 
    h = plot(sum(squeeze(HD.shock(fo:end,:,ii)),2),'-k','LineWidth',2,'MArker','*');
    xlim([0 x-fo+1+1]);
    if VARopt.datestype==1
        if ~isempty(VARopt.firstdate); DatesPlot(VARopt.firstdate,x-fo+1,8,VARopt.frequency); end
    elseif VARopt.dates_type==2
        set(gca,'Xtick',[1:x-fo+1]);
        set(gca,'XtickLabel',datestxt(fo:end,1),'XTickLabelRotation',45);
    end
	set(gca,'Layer','top');
    title([vnames{ii}], 'FontWeight','bold','FontSize',10); 
    % Save
    FigName = [filename num2str(ii)];
%     if quality 
%         if suptitle==1
%             Alphabet = char('a'+(1:nvars)-1);
%             SupTitle([Alphabet(jj) ') HD of '  vnames{ii}])
%         end
%         opt = LegOption; opt.handle = [H(1,:) h];
%         LegSubplot([snames {'Data'}],opt);
%         set(gcf, 'Color', 'w');
%         export_fig(FigName,'-pdf','-painters')
%     else
        legend([H(1,:) h],[snames {'Data'}],'Location','NorthWest')
        set(gcf, 'Color', 'w');
        export_fig(FigName,'-pdf','-painters')
%         print('-dpdf','-r100',FigName);
%     end
    clf('reset');
end

close all