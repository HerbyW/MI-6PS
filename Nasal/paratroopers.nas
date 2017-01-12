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


##########################################################
#      DE L'HAMAIDE Clément for Douglas DC-3 C47         # modified by HerbyW 01/2015 and D-LEON
##########################################################

var jumper = aircraft.light.new("/controls/paratroopers/trigger", [0.5,0.5], "/controls/paratroopers/jump-signal");		# Création du signal qui larguera les parachutistes toutes les 3.5 secondes


var listener_id = setlistener("/sim/weight[1]/weight-lb" , func {setprop("/controls/paratroopers/paratroopers", getprop("/sim/weight[1]/weight-lb") / 120)},  0, 0);



setlistener("/controls/paratroopers/trigger/state", func(state){								# On écoute le switch qui déclenche le signal
  if(state.getValue()){													# Si un parachutiste saute
    if(getprop("/sim/model/door-positions/c/position-norm") < 0.75){						# Si la porte cargo n'est pas ouverte
      jumper.switch(0);													# On annule le larguage des parachutistes
      setprop("/controls/paratroopers/trigger/state", 0);
      setprop("/sim/messages/copilot", "Paratroopers door is closed ! Paratroopers can't jump");				# On indique le problème
    }else{														# Sinon si la porte est ouverte
      var nb_para = getprop("/controls/paratroopers/paratroopers") - 1;							# On calcul combien il reste de parachutiste
      setprop("/controls/paratroopers/paratroopers", nb_para);								# On attribut le nombre de parachutiste à la propriété
      var weight = getprop("/sim/weight[1]/weight-lb") - 120;							# On calcul le poids des parachutistes restant
      setprop("/sim/weight[1]/weight-lb", weight);									# On attribut le poids restant à la propriété
      if(getprop("/controls/paratroopers/paratroopers") > 0){								# Si il reste encore des parachutistes
        setprop("/sim/messages/copilot", getprop("/controls/paratroopers/paratroopers")~" Paratroopers remaining");	# On indique le nombre de parachutistes restant  
      }else{                                                     							# Sinon
        jumper.switch(0);                                            							# On arrête le signal de saut
        setprop("/sim/messages/copilot", "There are no Paratroopers inside");							# On indique qu'il n'y a plus de parachutistes
      }
    }
  }
});


#################################################
# Water loading for watercanon by HerbyW 10-2015
#################################################
var Wweight = 0;
var Wload = 1;

var waterloading = maketimer( 1, func
{
     if(getprop("/sim/model/mi6/waterpipe") > 0 and Wload < 220 )
             {  
                if(getprop("/fdm/jsbsim/environment/terrain-solid") == 0)
		    {
                        if(getprop("/position/gear-agl-m") < 12.7)
			    {
			       var Wweight = getprop("/sim/weight[2]/weight-lb") + Wweight + 100;
                               setprop("/sim/messages/copilot", "Water is loading ...");
			       interpolate("/sim/weight[2]/weight-lb", Wweight, 1);
			       Wload = Wload + 1;
                            }
                    }
              }
});

waterloading.start();

#################################################
# Water dropping with watercanon by HerbyW 10-2015
var Wdrop = 100;

var waterdropping = maketimer( 1, func
{
  if (getprop("/controls/switches/hydro-damping") == 1)    
  {
    
  if(getprop("/sim/model/mi6/watercanon") >0 and (getprop("/sim/weight[2]/weight-lb") > 101))
  {
    var Wdrop = getprop("/sim/weight[2]/weight-lb") - 100;
    setprop("/sim/messages/copilot", "Water is dropping ...");
    interpolate("/sim/weight[2]/weight-lb", Wdrop, 1);
    Wload = Wload - 1;
  } 
    if(getprop("/sim/weight[2]/weight-lb") < 101 and getprop("/sim/model/mi6/watercanon") >0)
    {
      setprop("/sim/messages/copilot", "Water is out");
      setprop("/sim/model/mi6/watercanon", 0);
    }
  }
  else
  { if (getprop("/sim/model/mi6/watercanon") >0)
    {
    setprop("/sim/model/mi6/watercanon", 0);
    setprop("/sim/messages/copilot", "Watercanon has no power"); 
    }
  }
});  

waterdropping.start();

#  "sim/model/mi6/waterpipe"                   >0
#  "fdm/jsbsim/environment/terrain-solid"      == 0
#  "position/gear-agl-m"                       < 12.7