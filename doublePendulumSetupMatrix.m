function setup = doublePendulumSetupMatrix()
    %Simulation Parameters
    setup.dt = 10e-6;
    setup.Tstop = 5;
    setup.t = 0:setup.dt:setup.Tstop;
    setup.N = length(setup.t);
    
    %Initial Conditions
    thetaPB = -pi/2;
    thetaSB = -pi/2;
    omegaPB = 0;
    omegaSB = 0;
    
    %Double Pendulum Parameters
    setup.m1 = 0.3;
    setup.m2 = 0.2;
    setup.l1 = 0.2115;
    setup.l2 = 0.1813;
    
    thetaPerb = 0.1;
    
    setup.xTrue0 = [thetaPB;thetaSB;omegaPB;omegaSB];
    setup.x0 = [thetaPB*(1+thetaPerb);thetaSB*(1-thetaPerb);omegaPB;omegaSB];
    
    %Simulation Functions
    setup.stateFcn = @(x,dt)doublePendulumModel(x,dt,...
        setup.l1,setup.l2,...
        setup.m1,setup.m2);
    setup.measFcn = @doublePendulumMeasurement;
end

%Double Pendulum
function xPred = doublePendulumModel(x,dt,l1,l2,m1,m2)
    xPred = x + dt * doublePendulumDerivatives(x,l1,l2,m1,m2);
end

function f = doublePendulumDerivatives(x,l1,l2,m1,m2)
    %Model Parameters
    g = 9.81;

    %State Extraction
    theta1 = x(1,:);
    omega1 = x(3,:);
    theta2 = x(2,:);
    omega2 = x(4,:);

    vel_num1 = -g*(2*m1+m2).*sin(theta1)-m2*g.*sin(theta1-2*theta2) ...
        -2*sin(theta1-theta2).*m2.*(omega2.^2*l2+omega1.^2*l1.*cos(theta1-theta2));
    vel_den1 = l1*(2*m1+m2-m2*cos(2*theta1-2*theta2));

    vel_num2 = 2*sin(theta1-theta2).*(omega1.^2*l1*(m1+m2)+g*(m1+m2)*cos(theta1) ...
        +omega2.^2*l2*m2.*cos(theta1-theta2));
    vel_den2 = l2*(2*m1+m2-m2*cos(2*theta1-2*theta2));

    %Damping Coefficients
    c1 = 0.15;
    c2 = 0.15;

    f3 = (vel_num1./vel_den1) - (c1 * omega1);
    f4 = (vel_num2./vel_den2) - (c2 * omega2);

    f = [omega1; omega2; f3; f4];
end

function y = doublePendulumMeasurement(x)
    y = x(1:2,:);
end