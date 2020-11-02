function [IR, VAR] = VARir(VAR,VARopt)
% =========================================================================
% Compute impulse responses (IRs) for a VAR model estimated with the 
% VARmodel.m function. Four identification schemes can be specified: 
% zero contemporaneous restrictions, zero long-run restrictions, sign 
% restrictions, and external instrumenmts.
% =========================================================================
% [IRF, VAR] = VARir(VAR,VARopt)
% -------------------------------------------------------------------------
% INPUT
%   - VAR: structure, result of VARmodel.m
%   - VARopt: options of the VAR (result of VARmodel.m)
% -------------------------------------------------------------------------
% OUTPUT
%   - IRF(t,j,k): matrix with 't' steps, containing the IRF of 'j' variable 
%       to 'k' shock
%   - VAR: structure including VAR estimation results. Not here that the 
%       struicture VAR is an output of VARmodel. This fucntion adds to VAR
%       some additional results, e.g. VAR.B is the strcutral impact matrix
% =========================================================================
% VAR Toolbox 3.0
% Ambrogio Cesa Bianchi, March 2020
% ambrogio.cesabianchi@gmail.com
% -------------------------------------------------------------------------
% Notes:
% -----
% This code follows the notation as in the lecture notes available at
% https://sites.google.com/site/ambropo/MatlabCodes
% -----
% Specifically if Y, u, and e are [NxT] matrices, the following is true:
% -----
% Reduced form VAR    -->  Y = F*Y(-1) + u    (F => Ft' from VARmodel function) 
% Structural form VAR -->  Y = F*Y(-1) + Be     
% Where:
% 	u = B*e  -->  e = inv(B)*u  -->  e = IRF.B\transpose(VAR.residuals);
% -----
% Impulse responses:
%   IRF(1) = B*e          where "e" is impulse in the code
%   IRF(j) = H(j)*IRF(1)  where H(j)=H^j and for j=2,...,nsteps
% -----


%% Check inputs
%==========================================================================
if ~exist('VAR','var')
    error('You need to provide VAR structure, result of VARmodel');
end
IV = VARopt.IV;
if strcmp(VARopt.ident,'iv')
    if isempty(IV)
        error('You need to provide the data for the instrument in VARopt (IV)');
    end
end


%% Retrieve and initialize variables 
%==========================================================================
nsteps = VARopt.nsteps;
impact = VARopt.impact;
shut   = VARopt.shut;
recurs = VARopt.recurs;
Fcomp  = VAR.Fcomp;
nvar   = VAR.nvar;
nlag   = VAR.nlag;
sigma  = VAR.sigma;
IR     = nan(nsteps,nvar,nvar);


%% Compute Wold representation
%==========================================================================
% Initialize Wold multipliers
PSI = zeros(nvar,nvar,nsteps);
% Re-write F matrix to compute multipliers
VAR.Fp = zeros(nvar,nvar,nlag);
I = VAR.const+1;
for ii=1:nsteps
    if ii<=nlag
        VAR.Fp(:,:,ii) = VAR.F(:,I:I+nvar-1);
    else
        VAR.Fp(:,:,ii) = zeros(nvar,nvar);
    end
    I = I + nvar;
end
% Compute multipliers
PSI(:,:,1) = eye(nvar);
for ii=2:nsteps
    jj=1;
    aux = 0;
    while jj<ii
        aux = aux + PSI(:,:,ii-jj)*VAR.Fp(:,:,jj);
        jj=jj+1;
    end
    PSI(:,:,ii) = aux;
end
% Update VAR with Wold multipliers
VAR.PSI = PSI;


%% Identification: Recover B matrix
%==========================================================================
% B matrix is recovered with Cholesky decomposition
if strcmp(VARopt.ident,'rec')
    [out, chol_flag] = chol(sigma);
    if chol_flag~=0; error('VCV is not positive definite'); end
    B = out';
    IVflag = 0;
% B matrix is recovered with Cholesky on cumulative IR to infinity
elseif strcmp(VARopt.ident,'bq')
    Finf_big = inv(eye(length(Fcomp))-Fcomp); % from the companion
    Finf = Finf_big(1:nvar,1:nvar);
    D  = chol(Finf*sigma*Finf')'; % identification: u2 has no effect on y1 in the long run
    B = Finf\D;
    IVflag = 0;
% B matrix is recovered with SR.m
elseif strcmp(VARopt.ident,'sr')
    if isempty(VAR.B)
        error('You need to provide the B matrix with SR.m and/or SignRestrictions.m')
    else
        B = VAR.B;
    end
    IVflag = 0;
% B matrix is recovered with external instrument IV
elseif strcmp(VARopt.ident,'iv')
    % Recover residuals (first variable is the one to be instrumented - order matters!)
    up = VAR.resid(:,1);     % residuals to be instrumented
    uq = VAR.resid(:,2:end); % residulas for second stage 

    % Make sample of IV comparable with up and uq
    [aux, fo, lo] = CommonSample([up IV(VAR.nlag+1:end,:)]);
    p = aux(:,1);
    q = uq(end-length(p)+1:end,:); pq = [p q];
    Z = aux(:,2:end);

    % Run first stage regression and fitted
    FirstStage = OLSmodel(p,Z);
    p_hat = FirstStage.yhat;

    % Recover first column of B matrix with second stage regressions
    b(1,1) = 1;  % Impact IR is normalized to 1
    sqsp = zeros(size(q,2),1);
    for ii=2:nvar
        SecondStage = OLSmodel(q(:,ii-1),p_hat);
        b(ii,1) = SecondStage.beta(2);
        sqsp(ii-1) = SecondStage.beta(2);
    end
    sigma_b = (1/(length(pq)-VAR.ntotcoeff))*...
        (pq-repmat(mean(pq),size(pq,1),1))'*...
        (pq-repmat(mean(pq),size(pq,1),1));
    s21s11 = sqsp; 
    S11 = sigma_b(1,1);
    S21 = sigma_b(2:end,1);
    S22 = sigma_b(2:end,2:end);
    Q = s21s11*S11*s21s11'-(S21*s21s11'+s21s11*S21')+S22;
    sp = sqrt(S11-(S21-s21s11*S11)'*(Q\(S21-s21s11*S11)));
    % Rescale b vector
    b = b*sp;
    B = zeros(nvar,nvar);
    B(:,1) = b;
% If none of the above, you've done somerthing wrong :)    
else
    disp('---------------------------------------------')
    disp('Identification incorrectly specified.')
    disp('Choose one of the following options:');
    disp('- rec: zero contemporaneous restrictions');
    disp('- bq:  zero long-run restrictions');
    disp('- sr:  sign restrictions');
    disp('- iv:  external instrument');
    disp('---------------------------------------------')
    error('ERROR. See details above');
end


%% Compute the impulse response
%==========================================================================
for mm=1:nvar
    % Set to zero a row of the companion matrix if "shut" is selected
    if shut~=0
        Fcomp(shut,:) = 0;
    end
    % Initialize the impulse response vector
    response = zeros(nvar, nsteps);
    % Create the impulse vector
    impulse = zeros(nvar,1); 
    % Set the size of the shock
    if impact==0
        impulse(mm,1) = 1; % one stdev shock
    elseif impact==1
        impulse(mm,1) = 1/B(mm,mm); % unitary shock
    else
        error('Impact must be either 0 or 1');
    end
    % First period impulse response (=impulse vector)
    response(:,1) = B*impulse;
    % Shut down the response if "shut" is selected
    if shut~=0
        response(shut,1) = 0;
    end
    % Recursive computation of impulse response
    if strcmp(recurs,'wold')
        for kk = 2:nsteps
            response(:,kk) = PSI(:,:,kk)*B*impulse;
        end
    elseif strcmp(recurs,'comp')
        for kk = 2:nsteps
            FcompN = Fcomp^(kk-1);
            response(:,kk) = FcompN(1:nvar,1:nvar)*B*impulse;
        end
    end
    IR(:,:,mm) = response';
end
% Update VAR with structural impact matrix
VAR.B = B;   
if strcmp(VARopt.ident,'iv')
    VAR.FirstStage = FirstStage;
    VAR.sigma_b = sigma_b;
    VAR.b = b;
end

