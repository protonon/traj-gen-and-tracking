% A simple linear dynamics model
% continous model always discretized

classdef Linear < Model

    properties   
        % parameters structure
        PAR
        % constraints structure
        CON
        % cost function structure (handle and weight matrix)
        COST
        % fields necessary for simulation and plotting, noise etc.
        SIM
        % observation matrix
        C        
    end
    
    % Fields pertaining to state evolution and measurements
    properties
        % A and B matrices
        A, B
        % discrete A and B matrices
        Ad, Bd
    end
    
    methods
        
        % copies the parameter values inside the structure
        function set.PAR(obj, STR)  
            
            % create A and B matrices
            if ~obj.SIM.discrete
                obj.A = STR.A;
                obj.B = STR.B;                
            else
                obj.Ad = STR.Ad;
                obj.Bd = STR.Bd;
            end
            obj.C = STR.C;
                     
        end
        
        % copies the constraint values inside the structure
        function set.CON(obj, STR)
            
            % TODO:
            obj.CON = STR;
            
        end 
        
        % set the simulation parameters
        function set.SIM(obj, sim)
            
            obj.SIM.discrete = sim.discrete;
            obj.SIM.dimx = sim.dimx;
            obj.SIM.dimu = sim.dimu;
            obj.SIM.dimy = sim.dimy;
            obj.SIM.h = sim.h;
            obj.SIM.eps = sim.eps;
            assert(strcmpi(sim.int,'Euler') || strcmpi(sim.int,'RK4'),...
                   'Please input Euler or RK4 as integration method');
            obj.SIM.int = sim.int;
        end
        
        % change the cost function
        % TODO: assert Q and R matrices are of correct size
        function set.COST(obj, STR)
            obj.COST.Q = STR.Q;
            obj.COST.R = STR.R;
            obj.COST.fnc = @(x1,x2) diag((x1-x2)'*STR.Q*(x1-x2));
        end
        
    end
    
    methods
        
        % constructor for convenience
        % TODO: divide into several methods?
        function obj = Linear(par,con,cost,sim)
            
            obj.SIM = sim;
            % set object parameter
            obj.PAR = par;
            % set object constraints
            obj.CON = con;    
            % cost function handle
            obj.COST = cost;
            
            % create discrete matrices
            if ~obj.SIM.discrete
                obj.SIM.discrete = true;
                obj.discretizeMatrices();
            end
        end
        
        function obj = discretizeMatrices(obj)
            
            dimu = obj.SIM.dimu;
            dimx = obj.SIM.dimx;
            h = obj.SIM.h;
            % trick to get discrete time versions
            Mat = [obj.A, obj.B; zeros(dimu, dimx + dimu)];
            MD = expm(h * Mat);
            obj.Ad = MD(1:dimx,1:dimx);
            obj.Bd = MD(1:dimx,dimx+1:end);
        end
        
        % provides nominal model
        function x_next = nominal(obj,t,x,u)

            x_next = obj.Ad*x + obj.Bd*u;        
            
        end
        
        % provides actual model
        function x_next = actual(obj,t,x,u)
                                  
            a = 0;
            %a = 0.01*ones(size(x,1),1);
            % time varying drift
            x_next = obj.Ad*x + obj.Bd*u + a*sin(2*pi*t);        
            % constant drift
            %x_next = obj.Ad*x + obj.Bd*u + a;        
        end
        
        % TODO: isn't output controllability enough?
        function assertControllability(obj)
            
            % make sure the system is controllable/reachable
            % otherwise give an error
            
            % construct controllability Kalman matrix
            Ad = obj.Ad;
            Bd = obj.Bd;
            dimx = obj.SIM.dimx;
            dimu = obj.SIM.dimu;
            K = zeros(dimx,dimx*dimu);
            for i = 0:dimx-1
                K(:,(dimx*i+1):(dimx*i+dimu)) = (Ad^i)*Bd;
            end
            assert(rank(K) == dimx, 'System is not controllable!');
        end
        
        % Creates a dmp trajectory
        % numbf: number of basis functions to use
        % TODO: extend for multiple outputs
        function [dmp,s] = dmpTrajectory(obj,t,numbf,goal,yin,ref)
            
            h = obj.SIM.h;
            N = length(t);
            % make a DMP that smoothens x_des
            pat = 'd';
            % scaling
            tau = 1;
            % ensure that phase decays
            exponent = 2;
            ax = exponent/(tau*t(end));            
            can = Canonical(h,ax,tau,N,pat);
            
            % create different DMPs, one for each dimension
            alpha = 25;
            beta = 25/4;

            % create the dmp trajectory
            dmp = discreteDMP(can,alpha,beta,goal,yin,numbf);
            % learn the weights using regression
            dmp.setWeights(ref);
            % evolve the DMP
            [x,s] = dmp.evolve();         
            % add accelerations
            %s = [s; 0, diff(s(2,:))/h];
            
            figure;
            plot(t,ref,'-',t,s(1,:),'-.',t,x);
            legend('reference trajectory','state y','phase');
            title('DMP trajectory');

        end

        % create inputs using feedback law
        % ref is the reference trajectory
        function Traj = generateInputs(obj,t,ref,varargin)
            
            % check controllability
            obj.assertControllability();

            % calculate the optimal feedback law
            s = ref;
            Q = obj.COST.Q;
            R = obj.COST.R;
            C = obj.C;
            N = length(t)-1;
            h = t(2) - t(1);
            if obj.SIM.discrete
                Ad = obj.Ad;
                Bd = obj.Bd;
                lqr = LQR(Q,R,Q,Ad,Bd,C,N,h,true);
            else
                A = obj.A;
                B = obj.B;
                lqr = LQR(Q,R,Q,A,B,C,N,h);
            end
            % form sbar 
            sbar = C'*((C*C')\s);
            
            if nargin <= 3
                [K,uff] = lqr.computeFinHorizonTracking(sbar);
            else
                [K,uff] = lqr.computeErrorForm(sbar);
            end
            
            Traj = Trajectory(t,s,uff,K);
        end
        
        % create a dmp trajectory and inputs using feedback law
        % ref is the reference trajectory
        function [Traj,dmp] = generateDMP(obj,t,yin,ref)
            
            % check controllability
            obj.assertControllability();
             
            % optional: make DMPs that smoothens x_des
            % one for each output
            goal = ref(:,end);
            numbf = 20;      
            [dmp,s] = obj.dmpTrajectory(t,numbf,goal,yin,ref);
            s = s(1,:);

            % calculate the optimal feedback law
            Q = obj.COST.Q;
            R = obj.COST.R;
            C = obj.C;
            N = length(t)-1;
            h = t(2) - t(1);
            if obj.SIM.discrete
                Ad = obj.Ad;
                Bd = obj.Bd;
                lqr = LQR(Q,R,Q,Ad,Bd,C,N,h,true);
            else
                A = obj.A;
                B = obj.B;
                lqr = LQR(Q,R,Q,A,B,C,N,h);
            end
            % form sbar 
            sbar = C'*((C*C')\s);
            [K,uff] = lqr.computeErrorForm(sbar);
            
            Traj = Trajectory(t,ref,uff,K);
        end
        
    end
end