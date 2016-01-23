classdef Vehicle
    
    properties(Constant, Access = private)
        ConversionFactors = [.3048,...  %ft/m
            2.20462,... %lbm/kg
            0.224809];    %lbf/N
        UnitConversionIndex = {'Mass', 2;...   %index of proper conversion factor
            'FuelMass', 2;...
            'FuelMassDot', 2;...
            'Sv',1;...
            'Thrust', 3;...
            }
    end
    
    properties
        Mass %total mass of vehicle
        FuelMass
        FuelMassDot %fuel consumption rate
        Sv %1x9 3D state vector [position velocity acceleration]
        Thrust %thrust generated by vehicle
    end
    
    properties(Dependent)
        Units %Unit system used (Metric, English)
        CoordinateSystem %Coordinate system used (Cartesian, Spherical)
        %        g %earth's gravitational acceleration felt by vehicle
    end
    
    properties(Access = private)
        PrivateUnits = 'Metric';
        PrivateCoordinateSystem = 'Cartesian';
    end
    
    methods
        
        %       Ctor******************************************************
        function obj = Vehicle(mass,fuelmass,fuelmassdot,sv,Thrust,CS,Units)
            if nargin > 0
                switch(CS)
                    case 'Cartesian'
                    case 'Spherical'
                        obj.PrivateCoordinateSystem = CS;
                    otherwise
                        error('Vehicle:InvalidCoordinateSystem',...
                            'Coordinate System ''%s'' is not supported',...
                            CS);
                end
                switch(Units)
                    case 'Metric'
                    case 'English'
                        obj.PrivateUnits = Units;
                    otherwise
                        error('Vehicle:InvalidUnits',...
                            'Units ''%s'' is not supported', Units);
                end
                obj.Mass = mass;
                obj.FuelMass = fuelmass;
                obj.FuelMassDot = fuelmassdot;
                obj.Sv = sv;
                obj.Thrust = Thrust;
            else
                obj.Mass = 0;
                obj.FuelMass = 0;
                obj.FuelMassDot = 0;
                obj.Sv = [0 0 0 0 0 0 0 0 0];
                obj.Thrust = 0;
            end
        end
        %       /Ctor*****************************************************
        
        %       Get Functions*********************************************
        function units = get.Units(obj)
            units = obj.PrivateUnits;
        end
        
        function coordinatesystem = get.CoordinateSystem(obj)
            coordinatesystem = obj.PrivateCoordinateSystem;
        end
        %       /Get Functions********************************************
        
        %       Set Functions*********************************************
        function obj = set.Units(obj,newUnits)
            switch(newUnits)
                case 'Metric'
                    if ~strcmp(obj.PrivateUnits, newUnits)
                        obj.PrivateUnits = newUnits;
                        obj =convertPropertyUnits(obj,1./obj.ConversionFactors);
                    end
                case 'English'
                    if ~strcmp(obj.PrivateUnits, newUnits)
                        obj.PrivateUnits = newUnits;
                        obj = convertPropertyUnits(obj,obj.ConversionFactors);
                    end
                otherwise
                    error('Vehicle:InvalidUnits',...
                        'Units ''%s'' is not supported', newUnits);
            end
        end
        
        function obj = set.CoordinateSystem(obj,newCS)
            switch(newCS)
                case 'Cartesian'
                    if ~strcmp(obj.PrivateCoordinateSystem, newCS)
                        obj = convertPropertyCoordinates(obj,newCS);
                        obj.PrivateCoordinateSystem = newCS;
                    end
                case 'Spherical'
                    if ~strcmp(obj.PrivateCoordinateSystem, newCS)
                        obj = convertPropertyCoordinates(obj,newCS);
                        obj.PrivateCoordinateSystem = newCS;
                    end
                    
                otherwise
                    error('Vehicle:InvalidCoordinateSystem',...
                        'Coordinate System ''%s'' is not supported',...
                        newCS);
            end
        end
        
        function obj = set.Mass(obj,mass)
            if mass<0
                error('Mass must be non-negative');
            else
                obj.Mass = mass;
            end
        end
        
        function obj = set.FuelMass(obj,mass)
            if mass<0
                error('Mass must be non-negative');
            else
                obj.FuelMass = mass;
            end
        end
        
        function obj = set.Sv(obj,sv)
            if ~isequal(size(sv),[1,9])
                error('Vehicle:InvalidValue',...
                    'State vector must be 1x9 vector');
            else
                obj.Sv = sv;
            end
        end
        
        function obj = set.Thrust(obj,T)
            if isnumeric(T)
                obj.Thrust = T;
            else
                error('Vehicle:InvalidValue',...
                    'Thrust value must be numeric');
            end
        end
        %       /Set Functions********************************************
        
        %       Additional Functions**************************************
        function struct = homework1_propagate(obj,tspan)
            
            % Define celestial body constants
            g0 = 9.81; %m/s^2
            R0 = 6400000; %m
            
           y0 = zeros(3,1);
           y0(1) = obj.Sv(3);
           y0(2) = obj.Sv(6);
           y0(3) = obj.Mass;
            
            sol = ode45(@(t,y) hw1_prop_eq(t,y,g0,R0,...
                obj.Thrust,obj.FuelMassDot),...
                tspan,y0);
            
            
            xint = linspace(tspan(1),tspan(2),1000);
            [y,yp] = deval(sol, xint);
            struct.position = y(1,:);
            struct.velocity = y(2,:);
            struct.acceleration = yp(2,:);
            struct.mass = y(3,:);
            struct.time = xint/(24*3600);
            
            %define ode function to pass to ode45
            function dy = hw1_prop_eq(~,y,g0,R0,Thrust,fuelMassDot)
                dy = zeros(2,1);
                dy(1) = y(2);
                dy(2) = -g0*R0^2/y(1)^2 + Thrust/(y(3));
                dy(3) = fuelMassDot;
            end
        end
        %       /Additional Functions*************************************
    end %/methods
    
    %       Helper Functions******************************************
    methods(Access = private)
        function obj = convertPropertyUnits(obj,cf)
            for prop=obj.UnitConversionIndex'
                if ~strcmp(prop{1}, 'Sv')
                    obj.(prop{1}) = obj.(prop{1})*cf(prop{2});
                else
                    if strcmp(obj.PrivateCoordinateSystem, 'Cartesian')
                        obj.(prop{1}) = obj.(prop{1})*cf(prop{2});
                    elseif strcmp(obj.PrivateCoordinateSystem, 'Spherical')
                        sv = obj.Sv;
                        obj.Sv(3) = sv(3)*cf(prop{2});
                        obj.Sv(6) = sv(6)*cf(prop{2});
                        obj.Sv(9) = sv(9)*cf(prop{2});
                    end
                end
            end
        end
        
        function obj = convertPropertyCoordinates(obj,newCS)
            sv = obj.Sv;
            switch(obj.PrivateCoordinateSystem)
                case 'Cartesian'
                    if strcmp(newCS, 'Spherical')
                        [az,el,r] = cart2sph(sv(1),sv(2),sv(3));
                        [vaz,vel,vr] = cart2sph(sv(4),sv(5),sv(6));
                        [aaz, ael, ar] = cart2sph(sv(7),sv(8),sv(9));
                        obj.Sv = [az,el,r,vaz,vel,vr,aaz,ael,ar];
                    end
                case 'Spherical'
                    if strcmp(newCS, 'Cartesian')
                        [x,y,z] = sph2cart(sv(1),sv(2),sv(3));
                        [vx,vy,vz] = sph2cart(sv(4),sv(5),sv(6));
                        [ax,ay,az] = sph2cart(sv(7),sv(8),sv(9));
                        obj.Sv = [x,y,z,vx,vy,vz,ax,ay,az];
                    end
            end
        end
    end
    
end