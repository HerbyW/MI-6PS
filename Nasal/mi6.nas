# Maik Justus < fg # mjustus : de >, based on bo105.nas by Melchior FRANZ, < mfranz # aon : at >
############################################################################################################
#    Arcraft development for Flightgear by Herbert Wagner 2014-2015                            Model: MI-6PS
#    Antonov AN-12BK, AN-22A, AN-225-Mrija,
#    Tuplev Tu-95MR,
#    Mil Mi-6PS
#    Yak 58, Yak-53,
#    Berijev Be-200Altair
#    SpaceShuttle
#    Development is ongoing, see latest versions: www.github.com/HerbyW
#    
#    This file is licenced under the terms mentioned in the LICENCE.txt file.
#    Mi6dev was initially started by Moritz Röhrich (Blender3D) 2010-2012 as CC 3.0 BY NC SA.
#    The 3D-model still holds the CC 3.0 BY NC SA license, everything else is GNU GPL v3 License.
#    
#    This version is now going forward and will give you a full automatic flight control-system,
#    lots of animations, instrumentation and full Multiplayer support for Parachuters and Elephant transport.
#    Liveries, Fire fighting and SAR rescue is in preparation.
#    Removing this header is probited.    
#############################################################################################################
setprop("/sim/model/mi6/wings", 0);

setlistener("/sim/model/livery/file", func
{
  if (getprop("/sim/model/livery/file") == "Mi6")
      setprop("/sim/model/mi6/wings", 0);
    else
      setprop("/sim/model/mi6/wings", 1);
}
);


#############################################################################################################
setlistener("/controls/switches/landinglight", func
{
  if (getprop("/controls/switches/landinglight") == 1)
  {
      setprop("/controls/switches/taxilight", 0);
  }
}
);

setlistener("/controls/switches/taxilight", func
{
  if (getprop("/controls/switches/taxilight") == 1)
  {
      setprop("/controls/switches/landinglight", 0);
  }
}
);

#############################################################################################################
if (!contains(globals, "cprint")) {
  globals.cprint = func {};
}

var optarg = aircraft.optarg;
var makeNode = aircraft.makeNode;

var sin = func(a) { math.sin(a * math.pi / 180.0) }
var cos = func(a) { math.cos(a * math.pi / 180.0) }
var pow = func(v, w) { math.exp(math.ln(v) * w) }
var npow = func(v, w) { math.exp(math.ln(abs(v)) * w) * (v < 0 ? -1 : 1) }
var clamp = func(v, min = 0, max = 1) { v < min ? min : v > max ? max : v }
var normatan = func(x) { math.atan2(x, 1) * 2 / math.pi }

# timers ============================================================
var turbine_timer = aircraft.timer.new("/sim/time/hobbs/turbines", 10);
aircraft.timer.new("/sim/time/hobbs/helicopter", nil).start();

# engines/rotor =====================================================
var state = props.globals.getNode("sim/model/mi6/state");
var engine = props.globals.getNode("sim/model/mi6/engine");
var rotor = props.globals.getNode("controls/engines/engine/magnetos");
var rotor2 = props.globals.getNode("controls/engines/engine[1]/magnetos");
var rotor_rpm = props.globals.getNode("rotors/main/rpm");
var torque = props.globals.getNode("rotors/gear/total-torque", 1);
var collective = props.globals.getNode("controls/engines/engine[0]/throttle");
var turbine = props.globals.getNode("sim/model/mi6/turbine-rpm-pct", 1);
var torque_pct = props.globals.getNode("sim/model/mi6/torque-pct", 1);
var stall = props.globals.getNode("rotors/main/stall", 1);
var stall_filtered = props.globals.getNode("rotors/main/stall-filtered", 1);
var torque_sound_filtered = props.globals.getNode("rotors/gear/torque-sound-filtered", 1);
var target_rel_rpm = props.globals.getNode("controls/rotor/reltarget", 1);
var max_rel_torque = props.globals.getNode("controls/rotor/maxreltorque", 1);
var cone = props.globals.getNode("rotors/main/cone-deg", 1);
var cone1 = props.globals.getNode("rotors/main/cone1-deg", 1);
var cone2 = props.globals.getNode("rotors/main/cone2-deg", 1);
var cone3 = props.globals.getNode("rotors/main/cone3-deg", 1);
var cone4 = props.globals.getNode("rotors/main/cone4-deg", 1);

# state:
# 0 off
# 1 engine startup
# 2 engine startup with small torque on rotor
# 3 engine idle
# 4 engine accel
# 5 engine sound loop

var update_state = func {
  var s = state.getValue();
  var new_state = arg[0];
  if (new_state == (s+1)) {
    state.setValue(new_state);
    if (new_state == (1)) {
      settimer(func { update_state(2) }, 2);
      interpolate(engine, 0.03, 0.1, 0.002, 0.3, 0.02, 0.1, 0.003, 0.7, 0.03, 0.1, 0.01, 0.7);
    } else {
      if (new_state == (2)) {
        settimer(func { update_state(3) }, 3);
        rotor.setValue(1);
	rotor2.setValue(1);
        max_rel_torque.setValue(0.01);
        target_rel_rpm.setValue(0.002);
        interpolate(engine, 0.05, 0.2, 0.03, 1, 0.07, 0.1, 0.04, 0.9, 0.02, 0.5);
      } else { 
        if (new_state == (3)) {
          if (rotor_rpm.getValue() > 60) {
            #rotor is running at high rpm, so accel. engine faster
            max_rel_torque.setValue(1);
            target_rel_rpm.setValue(1.03);
            state.setValue(5);
            interpolate(engine, 1.03, 10);
          } else {
            settimer(func { update_state(4) }, 7);
            max_rel_torque.setValue(0.05);
            target_rel_rpm.setValue(0.02);
            interpolate(engine, 0.07, 0.1, 0.03, 0.25, 0.075, 0.2, 0.08, 1, 0.06,2);
          }
        } else {
          if (new_state == (4)) {
            settimer(func { update_state(5) }, 30);
            max_rel_torque.setValue(0.25);
            target_rel_rpm.setValue(0.8);
          } else {
            if (new_state == (5)) {
              max_rel_torque.setValue(1);
              target_rel_rpm.setValue(1.03);
            }
          }
        }
      }
    }
  }
}

var engines = func {
  if (props.globals.getNode("sim/crashed",1).getBoolValue()) {return; }
  var s = state.getValue();
  if (arg[0] == 1) {
    if (s == 0) {
      update_state(1);
    }
  } else {
    # engines stopped
    rotor.setValue(0);
    rotor2.setValue(0);
    state.setValue(0);
    interpolate(engine, 0, 4);
  }
}

var update_engine = func {
  if (state.getValue() > 3 ) {
    interpolate (engine,  clamp( rotor_rpm.getValue() / 80 ,0.05, target_rel_rpm.getValue() ), 0.25 );
  }
}

#var update_rotor_cone_angle = func {
# r = rotor_rpm.getValue();
# var f = 1 - r / 100;
# f = clamp (f, 0.1 , 1);
# c = cone.getValue();
# cone1.setDoubleValue( f *c *0.40 + (1-f) * c );
# cone2.setDoubleValue( f *c *0.35);
# cone3.setDoubleValue( f *c *0.30);
# cone4.setDoubleValue( f *c *0.25);
#}

# 0.50
# 0.75
# 1.00
# 1.25
var update_rotor_cone_angle = func {
  r = rotor_rpm.getValue();
  #print("r  = ", r);

  var f = r / 60;
  #print("f1 = ", f);

  f = clamp (f, 0 , 1);
  #print("f2 = ", f);

  c = cone.getValue();
  #print("c  = ", c);

  cone1.setDoubleValue( (c * 1.00) + (f * c));
  cone2.setDoubleValue( (c * 0.10) + (f * c));
  cone3.setDoubleValue( (c * 0.15) + (f * c));
  cone4.setDoubleValue( (c * 0.20) + (f * c));
}

# torquemeter
var torque_val = 0;
torque.setDoubleValue(0);

var update_torque = func(dt) {
  var f = dt / (0.2 + dt);
  torque_val = torque.getValue() * f + torque_val * (1 - f);
  torque_pct.setDoubleValue(torque_val / 9700);
}

# sound =============================================================
# stall sound
var stall_val = 0;
stall.setDoubleValue(0);

var update_stall = func(dt) {
  var s = stall.getValue();
    if (s < stall_val) {
    var f = dt / (0.3 + dt);
    stall_val = s * f + stall_val * (1 - f);
  } else {
    stall_val = s;
  }
  var c = collective.getValue();
  stall_filtered.setDoubleValue(stall_val + 0.006 * (1 - c));
}


# modify sound by torque
var torque_val = 0;

var update_torque_sound_filtered = func(dt) {
  var t = torque.getValue();
  t = clamp(t * 0.000001);
  t = t*0.25 + 0.75;
  var r = clamp(rotor_rpm.getValue()*0.02-1);
  torque_sound_filtered.setDoubleValue(t*r);
}

# skid slide sound
var Skid = {
  new : func(n) {
    var m = { parents : [Skid] };
    var soundN = props.globals.getNode("sim/sound", 1).getChild("slide", n, 1);
    var gearN = props.globals.getNode("gear", 1).getChild("gear", n, 1);

    m.compressionN = gearN.getNode("compression-norm", 1);
    m.rollspeedN = gearN.getNode("rollspeed-ms", 1);
    m.frictionN = gearN.getNode("ground-friction-factor", 1);
    m.wowN = gearN.getNode("wow", 1);
    m.volumeN = soundN.getNode("volume", 1);
    m.pitchN = soundN.getNode("pitch", 1);

    m.compressionN.setDoubleValue(0);
    m.rollspeedN.setDoubleValue(0);
    m.frictionN.setDoubleValue(0);
    m.volumeN.setDoubleValue(0);
    m.pitchN.setDoubleValue(0);
    m.wowN.setBoolValue(1);
    m.self = n;
    return m;
  },
  update : func {
    me.wowN.getBoolValue() or return;
    var rollspeed = abs(me.rollspeedN.getValue());
    me.pitchN.setDoubleValue(rollspeed * 0.6);

    var s = normatan(20 * rollspeed);
    var f = clamp((me.frictionN.getValue() - 0.5) * 2);
    var c = clamp(me.compressionN.getValue() * 2);
    me.volumeN.setDoubleValue(s * f * c * 2);
    #if (!me.self) {
    # cprint("33;1", sprintf("S=%0.3f  F=%0.3f  C=%0.3f  >>  %0.3f", s, f, c, s * f * c));
    #}
  },
};

var skid = [];
for (var i = 0; i < 3; i += 1) {
  append(skid, Skid.new(i));
}

var update_slide = func {
  forindex (var i; skid) {
    skid[i].update();
  }
}

# crash handler =====================================================
#var load = nil;
var crash = func {
  if (arg[0]) {
    # crash
    setprop("rotors/main/rpm", 0);
    setprop("rotors/main/blade[0]/flap-deg", -60);
    setprop("rotors/main/blade[1]/flap-deg", -50);
    setprop("rotors/main/blade[2]/flap-deg", -40);
    setprop("rotors/main/blade[3]/flap-deg", -30);
    setprop("rotors/main/blade[4]/flap-deg", -20);
    setprop("rotors/main/blade[5]/flap-deg", -10);
    setprop("rotors/main/blade[0]/incidence-deg", -30);
    setprop("rotors/main/blade[1]/incidence-deg", -20);
    setprop("rotors/main/blade[2]/incidence-deg", -50);
    setprop("rotors/main/blade[3]/incidence-deg", -55);
    setprop("rotors/main/blade[4]/incidence-deg", -60);
    setprop("rotors/main/blade[5]/incidence-deg", -65);
    setprop("rotors/tail/rpm", 0);
    strobe_switch.setValue(0);
    beacon_switch.setValue(0);
    nav_light_switch.setValue(0);
    rotor.setValue(0);
    rotor2.setValue(0);
    torque_pct.setValue(torque_val = 0);
    stall_filtered.setValue(stall_val = 0);
    state.setValue(0);

  } else {
    # uncrash (for replay)
    setprop("rotors/tail/rpm", 604);
    setprop("rotors/main/rpm", 120);
    for (i = 0; i < 4; i += 1) {
      setprop("rotors/main/blade[" ~ i ~ "]/flap-deg", 0);
      setprop("rotors/main/blade[" ~ i ~ "]/incidence-deg", 0);
    }
    strobe_switch.setValue(1);
    beacon_switch.setValue(1);
    rotor.setValue(1);
    rotor2.setValue(1);
    state.setValue(5);
  }
}

# "manual" rotor animation for flight data recorder replay ============
var rotor_step = props.globals.getNode("sim/model/mi6/rotor-step-deg");
var blade1_pos = props.globals.getNode("rotors/main/blade[0]/position-deg", 1);
var blade2_pos = props.globals.getNode("rotors/main/blade[1]/position-deg", 1);
var blade3_pos = props.globals.getNode("rotors/main/blade[2]/position-deg", 1);
var blade4_pos = props.globals.getNode("rotors/main/blade[3]/position-deg", 1);
var blade5_pos = props.globals.getNode("rotors/main/blade[4]/position-deg", 1);
var blade6_pos = props.globals.getNode("rotors/main/blade[5]/position-deg", 1);
var rotorangle = 0;

var rotoranim_loop = func {
  i = rotor_step.getValue();
  if (i >= 0.0) {
    blade1_pos.setValue(rotorangle);
    blade2_pos.setValue(rotorangle + 60);
    blade3_pos.setValue(rotorangle + 120);
    blade4_pos.setValue(rotorangle + 180);
    blade5_pos.setValue(rotorangle + 240);
    blade6_pos.setValue(rotorangle + 300);
    rotorangle += i;
    settimer(rotoranim_loop, 0.1);
  }
}

var init_rotoranim = func {
  if (rotor_step.getValue() >= 0.0) {
    settimer(rotoranim_loop, 0.1);
  }
}

# view management ===================================================

var elapsedN = props.globals.getNode("/sim/time/elapsed-sec", 1);
var flap_mode = 0;
var down_time = 0;
controls.flapsDown = func(v) {
  if (!flap_mode) {
    if (v < 0) {
      down_time = elapsedN.getValue();
      flap_mode = 1;
      dynamic_view.lookat(
          5,     # heading left
          -20,   # pitch up
          0,     # roll right
          0.2,   # right
          0.6,   # up
          0.85,  # back
          0.2,   # time
          55,    # field of view
      );
    } elsif (v > 0) {
      flap_mode = 2;
      var p = "/sim/view/dynamic/enabled";
      setprop(p, !getprop(p));
    }

  } else {
    if (flap_mode == 1) {
      if (elapsedN.getValue() < down_time + 0.2) {
        return;
      }
      dynamic_view.resume();
    }
    flap_mode = 0;
  }
}


# register function that may set me.heading_offset, me.pitch_offset, me.roll_offset,
# me.x_offset, me.y_offset, me.z_offset, and me.fov_offset
#
dynamic_view.register(func {
  var lowspeed = 1 - normatan(me.speedN.getValue() / 50);
  var r = sin(me.roll) * cos(me.pitch);

  me.heading_offset =           # heading change due to
    (me.roll < 0 ? -50 : -30) * r * abs(r);     #    roll left/right

  me.pitch_offset =           # pitch change due to
    (me.pitch < 0 ? -50 : -50) * sin(me.pitch) * lowspeed #    pitch down/up
    + 15 * sin(me.roll) * sin(me.roll);     #    roll

  me.roll_offset =            # roll change due to
    -15 * r * lowspeed;         #    roll
});

# main() ============================================================
var delta_time = props.globals.getNode("/sim/time/delta-realtime-sec", 1);
var adf_rotation = props.globals.getNode("/instrumentation/adf/rotation-deg", 1);
var hi_heading = props.globals.getNode("/instrumentation/heading-indicator/indicated-heading-deg", 1);

var main_loop = func {
  # adf_rotation.setDoubleValue(hi_heading.getValue());

  var dt = delta_time.getValue();
  update_torque(dt);
  update_stall(dt);
  update_torque_sound_filtered(dt);
  update_slide();
  update_engine();
  update_rotor_cone_angle();
  settimer(main_loop, 0);
}


var crashed = 0;

var doors = nil;
var config_dialog = nil;

# initialization
setlistener("/sim/signals/fdm-initialized", func {

  init_rotoranim();
  collective.setDoubleValue(1);

  setlistener("/sim/signals/reinit", func {
    cmdarg().getBoolValue() and return;
    cprint("32;1", "reinit");
    turbine_timer.stop();
    collective.setDoubleValue(1);
    crashed = 0;
  });

  setlistener("sim/crashed", func {
    cprint("31;1", "crashed ", cmdarg().getValue());
    turbine_timer.stop();
    if (cmdarg().getBoolValue()) {
      crash(crashed = 1);
    }
  });

  setlistener("/sim/freeze/replay-state", func {
    cprint("33;1", cmdarg().getValue() ? "replay" : "pause");
    if (crashed) {
      crash(!cmdarg().getBoolValue())
    }
  });

  # the attitude indicator needs pressure
  # settimer(func { setprop("engines/engine/rpm", 3000) }, 8);

  main_loop();
});

#############################################################################################################
#
# wind drift angle calculations, with help from: D-LEON
#
# wind direction:  environment/metar/base wind-dir-deg
# wind speed:      environment/metar/base wind-speed-kt
# heading:         orientation/heading-deg
# speed:           instrumentation/airspeed-indicator/indicated-speed-kt

#
#Calculate Ground Speed, Course & Wind Correction Angle
# create timer with 0.7 second interval
setprop("/autopilot/settings/heading-bug-deg", 0.001);

var TODEG = 180/math.pi;
var TORAD = math.pi/180;
var deg = func(rad){ return rad*TODEG; }
var rad = func(deg){ return deg*TORAD; }

var calc = maketimer(0.7, func

{ 
 
  var TWD 	= rad(getprop("/environment/wind-from-heading-deg"));
  var WS 	= getprop("/environment/wind-speed-kt");
  var TC 	= rad(getprop("/autopilot/settings/heading-bug-deg"));

  var TAS	= getprop("/instrumentation/airspeed-indicator/true-speed-kt");
  var MD 	= rad(getprop("/environment/magnetic-variation-deg"));  
  
  var x = WS * math.sin((TC-TWD));
  var y = TAS - (WS * math.cos((TC-TWD))); 
  
  DA = math.atan2(x,y);  
    
  if  
    (getprop("/instrumentation/airspeed-indicator/true-speed-kt") < 25 )
    { setprop("/instrumentation/drift",0 );}
  else
  { setprop("/instrumentation/drift",deg(DA)); }
  
}
);

# start the timer (with 0.7 second inverval)
calc.start();

##############################################################################################################
setprop("/autopilot/settings/target-altitude-ft", 0);

var adjustStep = func(value,amount,step=10){

if (math.abs(amount) >= step){
if (math.mod(value,step) != 0){
if (amount > 0){
value = math.ceil(value/step)*step;
}else{
value = math.floor(value/step)*step;
}
}else{
value += amount;
}
}else{
value += amount;
}
return value;
};


var adjustAlt = func(amount,step=100){

var value = getprop("/autopilot/settings/target-altitude-ft");
value = adjustStep(value,amount,100);
setprop("/autopilot/settings/target-altitude-ft",value);


};


var adjustPitch = func(amount,step=100){

var value = getprop("/autopilot/settings/vertical-speed-fpm");
value = adjustStep(value,amount,100);
setprop("/autopilot/settings/vertical-speed-fpm",value);


};
#############################################################################################################
# Autopilot setting to wing-leveler if floating pitch is activated without any active mode
var ap = func()
         { if (getprop("/autopilot/locks/heading") == "")
	   setprop("/autopilot/locks/heading", "wing-leveler"); 
	   setprop("/autopilot/locks/altitude", "gleiten");
	};
	
#############################################################################################################

setlistener("/sim/airport/closest-airport-id", func
{
  setprop("/controls/switches/metar",1);  
}
);

#############################################################################################################
# Speedfilter
#
  
setlistener("/instrumentation/airspeed-indicator/true-speed-kt", func
{  
  if (getprop("/instrumentation/airspeed-indicator/true-speed-kt") < 90 )
     setprop("/controls/flight/slowspeed", 0);
  else
  {
  if (getprop("/instrumentation/airspeed-indicator/true-speed-kt") < 130 )
     setprop("/controls/flight/slowspeed", 1);
  else setprop("/controls/flight/slowspeed", 2);
  }
});   

#############################################################################################################
#UVID-15 Control for Pressure in mmhg and inhg
# create listener

setprop("/instrumentation/altimeter/setting-hapa", getprop("/instrumentation/altimeter/setting-hpa"));

setlistener("/instrumentation/altimeter/setting-inhg", func(v)
{
  if(v.getValue())
  
    setprop("/instrumentation/altimeter/mmhg", getprop("/instrumentation/altimeter/setting-inhg") * 25.4);
    setprop("/instrumentation/altimeter/setting-inhgN", getprop("/instrumentation/altimeter/setting-inhg") + 0.005);
    setprop("/instrumentation/altimeter/setting-hapa", getprop("/instrumentation/altimeter/setting-inhg") * 33.8682715);
});
     
######################################################################################################################

#
# Air and Groundspeed selector for USVP-Instrument
#
setlistener("/controls/switches/usvp-selector-trans", func 

  { if(getprop("/controls/switches/usvp-selector-trans") > 0.5)
      {
        setprop("/instrumentation/usvp/air_ground_speed_kt", getprop("/velocities/groundspeed-kt"));
      }
      else
      {
        setprop("/instrumentation/usvp/air_ground_speed_kt", getprop("/instrumentation/airspeed-indicator/indicated-speed-kt"));
      }
  
  }
  );
 
######################################################################################################################

#
#Paratroopers
#
setlistener("/controls/paratroopers/jump-signal", func(v) {
  if(v.getValue()){
    interpolate("/controls/paratroopers/jump-signal-pos", 1, 0.25);
  }else{
    interpolate("/controls/paratroopers/jump-signal-pos", 0, 0.25);
  }
});
######################################################################################################################

# ice system

#  environment/temperature-degc
#  /sim/model/mi6/anti-ice-alpha
#  /sim/model/mi6/iceing                = float 16
#  /controls/switches/glass-heating
#  /controls/switches/rotor-heating

var ice = maketimer(15, func

  {
   if(getprop("/controls/switches/glass-heating") == 0) 
   {
     if(getprop("/environment/temperature-degc") > 1)
     {
     interpolate("/sim/model/mi6/anti-ice-alpha", 1, 14);
     }
    else
    {
      interpolate("/sim/model/mi6/anti-ice-alpha", getprop("/environment/temperature-degc") * 0.03846 + 0.90 , 14 );
    }
   }
   else 
   {
     interpolate("/sim/model/mi6/anti-ice-alpha", 1, 14);
   }
   
   if(getprop("/controls/switches/rotor-heating") == 0) 
   { 
     if(getprop("/environment/temperature-degc") > 1)
     {
     interpolate("/sim/model/mi6/anti-ice-rotor", 1, 14);
     }
    else
    {
      interpolate("/sim/model/mi6/anti-ice-rotor", getprop("/environment/temperature-degc") * 0.03846 , 14 );
    }
   }
   else 
   {
     interpolate("/sim/model/mi6/anti-ice-rotor", 1, 14);     
   }
   
  }); 
    
ice.start();

var glassice = maketimer(15, func {
  
  if(getprop("/controls/switches/glass-heating") == 0)
  
    interpolate("/sim/model/mi6/iceing", getprop("/sim/model/mi6/anti-ice-alpha"), 14);
  
  if(getprop("/controls/switches/glass-heating") == 1)
    
    interpolate("/sim/model/mi6/iceing", 1, 14);

});

glassice.start();

var rotorice = maketimer(15, func {
  
  if(getprop("/controls/switches/rotor-heating") == 0)
    
    interpolate("/controls/flight/spoilers", -1 * getprop("/sim/model/mi6/anti-ice-rotor"), 14);
  
  if(getprop("/controls/switches/rotor-heating") == 1)
    
    interpolate("/controls/flight/spoilers", 0, 14);
});

rotorice.start();
######################################################################################################################

# helper for starting heading setting for autostakeoff
# /environment/magnetic-variation-deg-korr
setprop("/environment/magnetic-variation-deg-korr", getprop("/environment/magnetic-variation-deg") * -1);

######################################################################################################################
setprop("/controls/flight/autoFS1", 0.0 );
setprop("/controls/flight/autoRS2", 0.0 );
setprop("/controls/flight/autoSF3", 0.0 );
setprop("/controls/flight/autoFM4", 0.0 );
setprop("/controls/flight/autoLC5", 0.0 );
setprop("/controls/flight/autoRH7", 0.0 );
setprop("/controls/flight/autoRS", 0.0 );

var autotakeoff = func()
  { if (getprop("/rotors/main/rpm") < 123 or getprop("position/altitude-agl-ft") > 1)
   setprop("/sim/messages/copilot", "Start Engines and wait till they have 100% RPM, then push l again");

   else {
     
   interpolate("/controls/flight/autoFS1", 10, 120 );
   setprop("/controls/gear/brake-parking", 0 );
   interpolate("/controls/flight/tilt", 0.1, 5 );
   interpolate("/controls/flight/tilt-roll", -0.015, 5 );
   setprop("/autopilot/locks/collective", 1 );
   setprop("/autopilot/locks/couple", 1 ); 
   setprop("/autopilot/locks/altitude", "gleiten");
   setprop("/controls/flight/floating-pitch", 3 );     
   setprop("/autopilot/locks/heading", "wing-leveler");
   setprop("/autopilot/internal/target-roll-deg-wl", 0 );
   setprop("instrumentation/magnetic-compass/pitch-offset-deg", getprop("/environment/magnetic-variation-deg-korr"));
   setprop("autopilot/settings/heading-bug-deg", getprop("orientation/heading-magnetic-deg"));
   setprop("/autopilot/locks/heading", "dg-heading-hold");
   setprop("/sim/messages/copilot", "All Settings for Auto Take Off in Floating Mode are made.");
   setprop("/sim/messages/copilot", "Use the left compass knob for heading control.");
   setprop("/sim/messages/copilot", "And the floating wheel for vertical speed control.");
   }
};


var autotakeoffrunway = func()
  { if (getprop("/rotors/main/rpm") < 123 or getprop("position/altitude-agl-ft") > 1)
   setprop("/sim/messages/copilot", "Start Engines and wait till they have 100% RPM, line up on runway, then push L again");

   else {
  
   interpolate("/controls/flight/autoRS2", 10, 140 );  
   setprop("/controls/gear/brake-parking", 0 );
   setprop("/autopilot/locks/collective", 0 );
   setprop("/autopilot/locks/couple", 1 );
   setprop("/controls/flight/floating-pitch", 0.0 );
   interpolate("/controls/flight/tilt", -0.08, 10 );
   interpolate("/controls/flight/tilt-roll", -0.08, 100 );
   setprop("/controls/engines/engine/throttle", 0.75 );
   setprop("/controls/engines/engine/throttle-filter", 0.29 );
   interpolate("/controls/engines/engine/throttle", 0.29 , 140 );
   interpolate("/controls/flight/stab", 0.0, 10);
   setprop("/controls/flight/elevator-trim", -0.15 );
   interpolate("/controls/flight/elevator-trim", 0.70, 140);
   setprop("/autopilot/locks/heading", "wing-leveler");
   setprop("/autopilot/internal/target-roll-deg-wl", 0 );   
   setprop("instrumentation/magnetic-compass/pitch-offset-deg", getprop("/environment/magnetic-variation-deg-korr"));
   setprop("autopilot/settings/heading-bug-deg", getprop("orientation/heading-magnetic-deg"));
   setprop("/autopilot/locks/heading", "dg-heading-hold");
   setprop("/sim/messages/copilot", "All Settings for Auto Take Off on runway are made.");
   setprop("/sim/messages/copilot", "Use the rudder to hold the runway heading.");
   setprop("/sim/messages/copilot", "We will climb 3000 ft, just use the elevator to hold a pitch of not more than 10 degree");
   }
};

setlistener("/controls/flight/autoRS2", func(v) {
  if (getprop("/controls/flight/autoRS2") == 10 )
  {
   setprop("/autopilot/locks/collective", 1 ); 
   setprop("/autopilot/locks/altitude", "altitude-hold");
   setprop("/autopilot/settings/target-altitude-ft", getprop("instrumentation/altimeter/indicated-altitude-ft") + 1800);
  }
});


var speedflight = func()
  {  if (getprop("position/altitude-agl-ft") < 500)
   setprop("/sim/messages/copilot", "We need 500 ft agl to change to Speed flight");

   else {  
   
   interpolate("/controls/flight/autoSF3", 10, 80 );
   setprop("/autopilot/locks/collective", 1 );
   setprop("/autopilot/locks/couple", 1 );
   setprop("/controls/flight/floating-pitch", 0.0 );
   interpolate("/controls/flight/tilt", -0.2, 75 );
   interpolate("/controls/flight/tilt-roll", -0.2, 75 );
   setprop("/autopilot/locks/altitude", "altitude-hold");
   setprop("/autopilot/settings/target-altitude-ft", getprop("instrumentation/altimeter/indicated-altitude-ft"));
   interpolate("/controls/flight/elevator-trim", 1, 70);
   interpolate("/controls/flight/stab", -0.15, 75);
   setprop("instrumentation/magnetic-compass/pitch-offset-deg", getprop("/environment/magnetic-variation-deg-korr"));
   setprop("autopilot/settings/heading-bug-deg", getprop("orientation/heading-magnetic-deg"));
   setprop("/autopilot/locks/heading", "dg-heading-hold");
   setprop("/sim/messages/copilot", "All Settings for changing to Speed Flight are made.");
   }
};

var floatingmode = func()
  {  if (getprop("position/altitude-agl-ft") < 100)
   setprop("/sim/messages/copilot", "We need 100 ft agl to change to Floating mode");

   else {     
  
   interpolate("/controls/flight/autoFM4", 10, 35 );
   setprop("/autopilot/locks/collective", 1 );
   setprop("/autopilot/locks/couple", 1 );
   interpolate("/controls/flight/tilt", 0.1, 35 );
   interpolate("/controls/flight/tilt-roll", -0.015, 35 );
   interpolate("/controls/flight/stab", 0.0, 35);
   setprop("/autopilot/locks/altitude", "gleiten");
   setprop("/controls/flight/floating-pitch", -3 );
   setprop("/sim/messages/copilot", "All Settings for changing to Floating Mode are made.");
   setprop("/sim/messages/copilot", "Just use the elevator to hold a pitch of not more than 10 degree");
   }
};

var landing = func()
  { if (getprop("position/altitude-agl-ft") < 500)
   setprop("/sim/messages/copilot", "We need 500 ft agl to change to Landing mode");

   else { 
  
   interpolate("/controls/flight/autoLC5", 10, 100 );
   setprop("/autopilot/locks/collective", 1 );
   setprop("/autopilot/locks/couple", 1 );
   setprop("/controls/flight/floating-pitch", 0.0 );
   interpolate("/controls/flight/tilt",  -0.07 , 70 );
   interpolate("/controls/flight/tilt-roll", -0.07, 70 );
#   interpolate("/controls/flight/stab", 0.0, 60);
   interpolate("/controls/flight/elevator-trim", 0.30, 98);
   setprop("instrumentation/magnetic-compass/pitch-offset-deg", getprop("/environment/magnetic-variation-deg-korr"));
   setprop("autopilot/settings/heading-bug-deg", getprop("orientation/heading-magnetic-deg"));
   setprop("/autopilot/locks/heading", "dg-heading-hold");
   setprop("/autopilot/locks/altitude", "altitude-hold");
   setprop("/autopilot/settings/target-altitude-ft", getprop("instrumentation/altimeter/indicated-altitude-ft"));
   setprop("/sim/messages/copilot", "All Settings for Landing Configuration are made.");
   setprop("/sim/messages/copilot", "Use vertical speed for descending to the runway");
   }
};

var holding = func()
  { if (getprop("position/altitude-agl-ft") < 50)
   setprop("/sim/messages/copilot", "We need 50 ft agl to change to Rescue mode");

   else { 
  
   interpolate("/controls/flight/autoRH7", 10, 25 );
   setprop("/autopilot/locks/collective", 1 );
   setprop("/autopilot/locks/couple", 1 );
   interpolate("/controls/flight/tilt", 0.18, 25 );
   interpolate("/controls/flight/tilt-roll", -0.025, 25 );
   interpolate("/controls/flight/stab", 0.0, 25);
   setprop("/autopilot/locks/heading", "dg-heading-hold");
   setprop("/autopilot/locks/altitude", "gleiten");
   setprop("/controls/flight/floating-pitch", 0.0 );
   setprop("/sim/messages/copilot", "All Settings for changing to Rescue Holding Mode are made.");
   setprop("/sim/messages/copilot", "Just use the elevator to hold a pitch of not more than 10 degree");
   }
};

var reset = func()
{ 
  interpolate("/controls/flight/autoRS", 1, 1, 0 , 1 );
  interpolate("/controls/flight/autoFS1", 0.0 );
  interpolate("/controls/flight/autoRS2", 0.0, 1 );
  interpolate("/controls/flight/autoSF3", 0.0, 1 );
  interpolate("/controls/flight/autoFM4", 0.0, 1 );
  interpolate("/controls/flight/autoLC5", 0.0, 1 );
  interpolate("/controls/flight/autoRH7", 0.0, 1 ); 
  
  setprop("/autopilot/locks/heading", "");
  setprop("/autopilot/locks/altitude", "");
  setprop("/autopilot/locks/speed", "");
  setprop("/autopilot/locks/collective", 0 );
  interpolate("/controls/engines/engine/throttle", 0.70 , 1 );
  setprop("/autopilot/locks/couple", 0 );
  interpolate("/controls/flight/tilt", 0.0, 1 );
  interpolate("/controls/flight/tilt-roll", 0.0, 1 );
  interpolate("/controls/flight/stab", 0.0, 1);
  setprop("/controls/flight/floating-pitch", 0.0 );
  interpolate("/controls/flight/elevator-trim", 0.0, 1 );
  interpolate("/controls/flight/aileron-trim", 0.0, 1 );
  interpolate("/controls/flight/rudder-trim", 0.0, 1 );
  
  setprop("/sim/messages/copilot", "Reset Mode !!");
  

};