
#######################################################
#Start up provisorium
#
setprop("/controls/electric/battery-switch", 1);
setprop("/controls/switches/gauge-light", 1);
setprop("/controls/lighting/nav-lights", 1);

setprop("sim/messages/copilot", "Main power and lights are on");

setprop("/instrumentation/adf[0]/power-btn", 1);
setprop("/instrumentation/adf[1]/power-btn", 1);
setprop("/instrumentation/heading-indicator[0]/serviceable", 1);
setprop("/instrumentation/nav[0]/power-btn", 1);
setprop("/instrumentation/nav[1]/power-btn", 1);
setprop("/instrumentation/transponder/serviceable", 1);
setprop("/instrumentation/attitude-indicator[0]/power", 1);
setprop("/instrumentation/attitude-indicator[1]/power", 1);
setprop("/controls/switches/autopilot", 1);
setprop("/controls/switches/friction", 1);
setprop("/controls/switches/hydro-damping", 0);
setprop("/controls/switches/landinglight", 0);
setprop("/controls/switches/taxilight", 0);
setprop("/controls/switches/glass-heating", 0);
setprop("/controls/switches/rotor-heating", 0);
setprop("/controls/switches/instrument-heating", 0);
setprop("/controls/switches/fan", 0);
setprop("/controls/switches/external-suspension", 0);
setprop("/controls/switches/jettison-cargo", 0);

setprop("sim/messages/copilot", "Instruments are powered");





