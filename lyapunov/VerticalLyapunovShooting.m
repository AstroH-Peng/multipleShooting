function [correctedInitialState, period, correctedFinalState, correctedStateTransitionMatrix, exitflag, iter] = ...
    VerticalLyapunovShooting(mu, initialState, period, fixedID, tolerance, odeOptions)
%correctedInitialState = HaloShooting(mu, initialState)
%[correctedInitialState, correctedFinalState, correctedStateTransitionMatrix, exitflag, iter] = HaloShooting(mu, initialState, fixedID, tolerance, odeOptions)
%
%inputs:
%   mu:
%   initialState: initial guess. Usually from 3rd order approximation.
%   fixedID: 'Ax', 'Az', 1, or 3. 
%            This indicate which index of initialState should be fixed during the shooting. 
%   [tolerance]: tolerances used for shooting
%   [odeOptions]
%outputs:
%   correctedInitialState: modifed state
%   correctedFinalState
%   correctedStateTransitionMatrix
%   exitflag: 1 for success; -1 for too many iterations.
%   iter: iteration number before exit. If iter == maxIterationNumber, it is very possible shooting has failed.
%
%Limits:
%   The initial condition must be in the form [x0, 0, z0, 0, vy0, 0], i.e., must start from x-z plane.
%   
%
%生成Halo轨道专用的打靶法
%
% Last modified by PH at 2013-10-09:1547
% last modified by PH at 2013-10-12:1046 加入了最大迭代次数的限制，当超过最大迭代次数时，输出空数组
% last modified by PH at 2013-10-23:2225 加入一维线性搜索
% last modified by PH at 2013-10-28:2208 加入了精度控制Tol
% last modified by PH at 2013-10-29:1047 加入了Position控制，以适应L2的延拓
% last modified by PH at 2013-10-29:1500 增加了输出iter


%% input check

% ? on x-z plane
if any( initialState([2,4,6]) > 1e-6 )
    error('Initial condition should be on x-z plane.');
end

if nargin < 5
    % ? default integration tolerance
    odeOptions = odeset('RelTol',1e-9, 'AbsTol',1e-9);
    if nargin < 4
        % ? default shooting tolerance
        tolerance = 1e-7;
        if nargin < 3
            % ? default fixed component
            fixedID = 'Az'; % z0 is fixed, so that z-amplitude is fixed
        end
    end
end

if strcmpi(fixedID,'Ax')
    fixedID = 1; disp('# Ax fixed...');
elseif strcmpi(fixedID,'Az')
    fixedID = 3; disp('# Az fixed...');
end

maxIterationNumber = 1000;

initialState = reshape(initialState,6,1);

%% differential correction for the Halo orbit

disp('# Vertical Lyapunov shooting begin...');
iter = 1;
% odeOptions = odeset(odeOptions, 'Events',@(t,X)PrivateEventFirstCross(t,X,initialState));
while 1 
    
    % propagation
    [~, tempState] = ode113(@(t,X)DynamicRTBP(t,X,mu,0), [0,period/2], [initialState;reshape(eye(6),[],1)]);
    finalState = tempState(end,1:6);
%     plot3(tempState(:,1),tempState(:,2),tempState(:,3),'.-'); hold on; pause;
    
    % check target error for early stop
    b = - [finalState(2); finalState(4); finalState(6)];
    if norm(b) < tolerance
        exitflag = 1;
        disp('# Halo shooting success.');
        break;
    end
    
    % shooting
    stateTransitionMatrix = reshape( tempState(end,7:42), 6, 6 );
    temp = DynamicRTBP(0,finalState,mu,0);
    if fixedID == 1 % fix Ax
        L = [ stateTransitionMatrix( [2,4,6], [3,5] ), [temp(2);temp(4);temp(6)] ];
    elseif fixedID == 3 % fix Az
        L = [ stateTransitionMatrix( [2,4,6], [1,5] ), [temp(2);temp(4);temp(6)] ];
    else % other, fix vy
        L = [ stateTransitionMatrix( [2,4,6], [1,3] ), [temp(2);temp(4);temp(6)] ];
    end
    correction = 1 * pinv(L) * b;
    
    % update 
    if fixedID == 1 % fix Ax
        initialState(3) = initialState(3) + correction(1);
        initialState(5) = initialState(5) + correction(2);
    elseif fixedID == 3 % fix Az
        initialState(1) = initialState(1) + correction(1);
        initialState(5) = initialState(5) + correction(2);
    else % other, fix vy
        initialState(1) = initialState(1) + correction(1);
        initialState(3) = initialState(3) + correction(2);
    end
    period = period + correction(3);
    
    % stop after too many iterations
    if iter > maxIterationNumber
        exitflag = -1;
        disp('# Vertical Lyapunov shooting failed after too many iterations.');
        break;
    end
    
    % update
    iter = iter + 1;
    
end

% generate output
correctedInitialState = initialState;
correctedFinalState = finalState;
correctedStateTransitionMatrix = stateTransitionMatrix;


end




% function [value,isterminal,direction] = PrivateEventFirstCross(f,X,X0)
% % [value,isterminal,direction] = HaloEventFirstCross(f,X,X0)
% % 第一次与x-z平面相交
% % 
% % last modified by PH at 2013-10-12:1046
% % last modified by PH at 2013-11-27:1711 修改了注释部分，加入调用方法
% % last modified by PH at 2013-11-27:1958
% % 修改了对 direction 的赋值逻辑，与Position无关，第二次相次，应该与初始值的方向相同即可。
% % 要求输入初始值 X0
% % last modified by PH at 2013-11-28:2033 更新了根据 X0 对位置的判断，可以兼容 Halo 的左右两侧
% 
% 
% % 输入检测
% if ischar(X0)
%     error('We have changed: use X0 to replace Position value!');
% end
% 
% % 以 y 为事件值
% value = X(2);
% 
% % 终止
% isterminal = 1;
% 
% direction = -1; % 第一次相交，则 dy/dt 方向应该和初始值的 dy/dt 相反
% 
% end