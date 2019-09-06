
# $Id: 00_Wecker.pm 2015-08-03 20:10:00Z Ulli $
#TODO: sendpool integrieren für mehrere Wecker. Keine Sendekonflikte (CUL)

package main;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);

sub Wecker_Define($$);

sub Wecker_Set($@);
sub Wecker_Get($@);
sub Wecker_Attr(@);
sub Wecker_Parse($$);

sub Wecker_PushButton($$$);
sub Wecker_updateOperationState($$);
sub Wecker_setOperationState($$$$);
sub Wecker_OperationStateTimeOut($);

sub Wecker_setLight($$$);
sub Wecker_setClock($$);

my %sets = (
  "raw" 							=> "",
  "reset"    					=> "noArg",
  "clock"							=> "noArg",
  "clock_clear"				=> "noArg",
#  "clock_setDots"	=> "",
  "clock_brightness"	=> "slider,0,1,7",
#  "clock_digits"	=> "",
  "light"							=> "colorpicker,RGB",
  "light_clear"				=> "noArg",
#	"led_left"	=> "colorpicker,RGB",
#	"led_right"	=> "colorpicker,RGB",
#  "led_group_1"     	=> "colorpicker,RGB",
#  "led_group_2"     	=> "colorpicker,RGB",
#  "led_group_3"     	=> "colorpicker,RGB",  
  "led_brightness"		=> "slider,0,10,100",
  "Alarm"							=> "on,off,pre,snooze,hard",
  "operation"					=> "standby,goToBed",
);


my %gets = (    # Name, Data to send to the CUL, Regexp for the answer
  "raw"      						=> ["", '.*'],
);

my %TriggerMapping = (
  "01"		=> "lUp",  
  "00"		=> "lDown",
  "03"		=> "rUp",
  "04"		=> "rDown", 
  "07"		=> "lTop",
  "08"		=> "rTop",
); 

my $Wecker_Default_OperationStateTimeOut				= "5";

#Light
my @Wecker_LightGroups													= ( "1", "2", "3", "4" ); #Top, Bottom, Left, Right, 5-> Bottom Mid Light
my $Wecker_Default_LightColor										= "FCF4E2";	#White
my $Wecker_Default_LedBrightness								= "10"; #% 0-100

#Clock
my $Wecker_Default_ClockBrightness							= "1"; #0-7
my $Wecker_Clock_State													= "1"; #1=on, 0=off

#Music
my $Wecker_Default_MediaPlayerDevice						= "MediaPlayer";
my $Wecker_Default_MusicPlaylist								= "webradio";
my $Wecker_Default_MusicVolume									= "70";

#Alarm
my @Wecker_Default_AlarmOnOffLightColor					= ("FF0000", "00FF00");
my $Wecker_Default_SnoozeTimeSec								= "5"; #sec
my $Wecker_Default_PreAlarmMusicVolume					= $Wecker_Default_MusicVolume;
my $Wecker_Default_PreAlarmMusicPlaylist				= "wakeup";
#my $Wecker_OperationState_LightGroup						= "5";
my @Wecker_PreAlarmSunRise											= ('030100','0B0300','190601','230902','2F0D03','370F03','401204','481405','521806',
																									 '591007','622108','6E2508','772809','7F2A09','882D0A','90300A','96320A','9D330A','A6360A','B0390A',
																									 'B0450A','B9480B','C1580B','CB610B','D3650C','D6740C','DC770B','DC810B','E5860B','ED8E12','F2A113',
																									 'F2B013','F5B51A','F9BA22','FBBD29','FEC232','FFC742','FECC55','FED166','FDD473',
																									 'FDD880','FEDD8C','FDDF97','FDE4A7','FDEABC','FDEEC8','FDF0D1','FDF3DA','FCF4E2');
my @Wecker_PreAlarmBrightness										= ('10', '20', '30', '40', '50', '60');


sub Wecker_Initialize($) {
  my ($hash) = @_;

  require "$attr{global}{modpath}/FHEM/DevIo.pm";


	$hash->{ParseFn}							= "Wecker_Parse";
  $hash->{ReadFn}								= "Wecker_Read";
  $hash->{WriteFn} 							= "Wecker_Write";
  $hash->{ReadyFn} 							= "Wecker_Ready";

# Normal devices
  $hash->{DefFn}        				= "Wecker_Define";
#  $hash->{GetFn}        				= "Wecker_Get";
  $hash->{SetFn}        				= "Wecker_Set";
  $hash->{AttrFn}       				= "Wecker_Attr";
  $hash->{AttrList} 						= " Light_Color"
  																." OperationStateTimeOut"	#sec
  																." MediaPlayer_Device MediaPlayer_Volume MediaPlayer_DefaultPlaylist"
  																." Alarm_SnoozeTimeSec Alarm_DeviceMapping"
  																." Alarm_PreAlarmFile Alarm_AlarmFile Alarm_PreAlarmVolume"
  																." Alarm_HardAlarmFile"
  																." $readingFnAttributes";
  #$hash->{ShutdownFn} 					= "Wecker_Shutdown";
}

#####################################

sub Wecker_Define($$) {
#define <name> Wecker <device/none> <DeviceID> 
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

#  if(@a == 3 || @a == 4) {
#    my $msg = "wrong syntax: define <name> Wecker { <pty-file> } <DeviceID>";
#    Log3 undef, 2, $msg;
#    return $msg;
#  }

  DevIo_CloseDev($hash);

  my $name = $a[0];
  my $dev = (@a == 4 ? $a[2] : "UNIX:STREAM:/home/pi/wecker/wecker.uds");
  my $devID = (@a == 4 ? $a[3] : "01");
  return "DeviceID must be [00-99] a value with two digits." if($devID !~ m/^[0-9][1-9]$/);
	
  #check if DeviceID and ModuleID is already defined in combination
  foreach my $d (keys %defs) {
		next if($d eq $name);
		if($defs{$d}{TYPE} eq "Wecker" && $defs{$d}{NAME} ne $name && $hash->{DeviceName} eq $dev) {
      my $m = "$name: Cannot define multiple Wecker devices.";
      Log3 $name, 1, $m;
      return $m;
    }
	}

	%{$hash->{Sets}} = %sets;
  $hash->{DeviceID} = $devID;
	$hash->{DeviceName} = $dev;
	$hash->{helper}{OperationTimeOutState} = "standby";
	
  if($dev eq "none") {
    Log3 $name, 1, "$name device is none, commands will be echoed only";
    $attr{$name}{dummy} = 1;
    return undef;
  }
  	
  return DevIo_OpenDev($hash, 0, "Wecker_DoInit");
}

#####################################
sub Wecker_DoInit($) {

  my $hash = shift;
  my $name = $hash->{NAME};
  my $to = 0.1; #weit time for next try to initialize/reset the satellite
	
	if(ReadingsVal($hash->{NAME},"state","") ne "opened") { 
		readingsSingleUpdate($hash, "state", "opened", 1);
	 # Reset the counter
		delete($hash->{XMIT_TIME});
		delete($hash->{NR_CMD_LAST_H});
	}
		
	Wecker_Clear($hash);
	
	readingsSingleUpdate($hash, "state", "initialized", 1);
	
	Wecker_putAllToStandby($hash);

  return undef;
}

sub Wecker_putAllToStandby($) {

  my $hash = shift;
  
	Wecker_setClock($hash, undef);
	Wecker_setLight($hash, "clear", undef);
	Wecker_setMusic($hash, "stop",undef);
	Wecker_setAlarm($hash,"off");
	
	delete $hash->{READINGS}{"light"}; 
	delete $hash->{READINGS}{"raw"}; 
}

sub Wecker_Clear($) {
  my $hash = shift;

  # Clear the pipe
  $hash->{RA_Timeout} = 1;
  for(;;) {
    my ($err, undef) = Wecker_ReadAnswer($hash, "Clear", 0, undef);
    last if($err);
  }
  delete($hash->{RA_Timeout});
  
  RemoveInternalTimer($hash);
}

sub Wecker_ResetDevice($)
{
  my ($hash) = @_;
	
	Log3 $hash->{NAME},4, "$hash->{NAME}: reset device";
			
	DevIo_CloseDev($hash);
	return  DevIo_OpenDev($hash, 0, "Wecker_DoInit");
}

#####################################
sub Wecker_Write(@) {
	#my ($hash, $fn, $cmd, $regexAnswer, $initCmd) = @_;
  my ($hash, $msg, $noPrefix ,$nocr) = @_;
  return if(!$hash);
  my $name = $hash->{NAME};
  my $devID = $hash->{DeviceID};
  
	$msg =~ s/^\s+|\s+$//g; #löscht Leerzeichen
	$msg =~ s/\v//g; #löscht \r\n
	return if(!length($msg));
	$msg = $devID . $msg;

	if(ReadingsVal($hash->{NAME},"state","") eq "disconnected") {
		Log3 $name, 1, "$name: SW: <$msg> skipped due to disconnected device.";
		return;
	}
  
	if(defined($hash->{IODev})) { # logical Device
		IOWrite($hash,$msg);
  } else {
		Log3 $name, 4, "$name: SW: <$msg>";
		$msg .= "\n" unless($nocr);
		$hash->{USBDev}->write($msg)    if($hash->{USBDev});
		syswrite($hash->{TCPDev}, $msg) if($hash->{TCPDev});
		syswrite($hash->{DIODev}, $msg) if($hash->{DIODev});
	}
  # Some linux installations are broken with 0.001, T01 returns no answer
  select(undef, undef, undef, 0.2); #Für Wecker erhöht da sonst die Funktionen wie LEDs nicht hinter her kommen!
}
########################################
sub Wecker_Set($@) {
  my ($hash, @a) = @_;

  return "\"set Wecker\" needs at least one parameter" if(@a < 2);
  
  #problematic...does not work with predefined sets values!?
  #return "Unknown argument $a[1], choose one of " . join(" ", sort keys %sets)
  #	if(!defined($sets{$a[1]}));

  my $name = shift @a;
  my $cmd = shift @a;
  my $arg = join(" ", @a);
  my $setReading=1;

  my $list = join(" ", map { $hash->{Sets}{$_} eq "" ? $_ : "$_:$hash->{Sets}{$_}" } sort keys %{$hash->{Sets}});
  return $list if( $cmd eq '?' || $cmd eq '');


	###### set commands ######
  Log3 $name, 4, "set $name $cmd $arg";

  if($cmd eq "raw") {
    Wecker_Write($hash, $arg);
  	
  } elsif ($cmd =~ m/reset/i) {
    return Wecker_ResetDevice($hash);

	} elsif ($cmd =~ m/operation/i) {
		if($arg =~ m/standby/) {
			Wecker_putAllToStandby($hash);
			Wecker_setOperationState($hash,"standby",undef,undef); #erzwinge "standby"
		} elsif($arg =~ m/goToBed/) {
			Wecker_updateOperationState($hash, $arg); #Voraussetztung Status "standby"
		}
		$setReading=undef;
		
	} elsif ($cmd =~ m/Alarm/i) {
		return "Unknown argument $cmd, respect syntax <....>" if($arg !~ m/^(on|off|pre|snooze|hard)$/i);
		Wecker_setOperationState($hash, "alarm", $arg, 0);
	
  } elsif ($cmd =~ m/^clock$/i) {
    Wecker_setClock($hash,"on");
    $setReading=undef;

  } elsif ($cmd =~ m/^clock_clear$/i) {
    Wecker_setClock($hash, "off");
    $setReading=undef;
    
#  } elsif ($cmd =~ m/^clock_setDots$/i) {
#	  return "Unknown argument $cmd, respect syntax <....>" if($arg !~ m/^[0\.]{4}$/i);
#    Wecker_Write($hash, "cp" . $arg);
      
  } elsif ($cmd =~ m/^clock_brightness$/i) {
    return "Unknown argument $cmd, respect syntax <0-7>" if($arg !~ m/^[0-7]$/i);
    Wecker_Write($hash, "cb" . $arg);

#  } elsif ($cmd =~ m/^clock_digits$/i) {
#	  #return "Unknown argument $cmd, respect syntax <1.2.3.4.>" if($arg !~ m/^(\d[ \.]){8}$/i);
#    Wecker_Write($hash, "c" . $arg);
      
#  } elsif ($cmd =~ m/^led_group_.$/i) {
#	  return "Unknown argument $cmd, respect syntax <FFFFFF>" if($arg !~ m/^[0-9A-F]{6}$/i);
#		my $grID = substr($cmd,-1,1);
#    Wecker_Write($hash, "lg" . $grID . $arg);

# } elsif ($cmd =~ m/^led_(left|right)$/i) {
#		my $side = (split('_',$cmd))[1];
#    Wecker_setLight($hash,$side,$arg);

 } elsif ($cmd =~ m/^light$/i) {
    Wecker_setLight($hash, "on", $arg); 
  
 } elsif ($cmd =~ m/^led_brightness$/i) {
    return "Unknown argument $cmd, respect syntax <0-100>t" if($arg !~ m/^\d{1,3}$/i);
    $arg=100 if($arg > 100);
    Wecker_Write($hash, "lb" . $arg);
    
 } elsif ($cmd =~ m/^light_clear$/i) {
 	 Wecker_setLight($hash, "clear", undef); 
   $setReading=undef;
 } 
  
 readingsSingleUpdate($hash,$cmd, $arg,0) if($setReading);
  
 return undef;
}

#####################################

sub Wecker_Get($@) {
  my ($hash, $name, $cmd, @msg ) = @_;
  my $arg = join(" ", @msg);
  my $type = $hash->{TYPE};
  

  return "\"get $type\" needs at least one parameter" if(!defined($name) || $name eq "");
#  if(!defined($gets{$cmd})) {
#    my @list = map { $_ =~ m/^(raw)$/ ? $_ : "$_:noArg" } sort keys %gets;
#    return "Unknown argument $cmd, choose one of " . join(" ", @list);
#  }

	return "No $cmd for devices which are defined as none." if(IsDummy($hash->{NAME}));
	
	my ($err, $rmsg);
	
	if ($cmd eq "raw") {
    Wecker_SimpleWrite($hash, $gets{$arg}[0]);
    ($err, $rmsg) = Wecker_ReadAnswer($hash, $arg, 1, $gets{$arg}[1]); #Dispatchs all commands
    if(!defined($rmsg)) {
      #DevIo_Disconnected($hash);
      $rmsg = "No answer. $err";	
		}
	}
	return;
}
 
#####################################
sub
Wecker_Attr(@)
{

  return undef;
}

#####################################
sub
Wecker_Ready($)
{
  my ($hash) = @_;

  return DevIo_OpenDev($hash, 1, "Wecker_DoInit")
                if(ReadingsVal($hash->{NAME},"state","") eq "disconnected");

  # This is relevant for windows/USB only
  my $po = $hash->{USBDev};
  my ($BlockingFlags, $InBytes, $OutBytes, $ErrorFlags);
  if($po) {
    ($BlockingFlags, $InBytes, $OutBytes, $ErrorFlags) = $po->status;
  }
  return ($InBytes && $InBytes>0);
}
#####################################

#####################################
# called from the global loop, when the select for hash->{FD} reports data
sub Wecker_Read($) {
  my ($hash) = @_;

  my $buf = DevIo_SimpleRead($hash);
  return "" if(!defined($buf));
  my $name = $hash->{NAME};

  my $pdata = $hash->{PARTIAL};
  Log3 $name, 5, "$name/RAW: $pdata/$buf";
  $pdata .= $buf;

  while($pdata =~ m/\n/) {
    my $rmsg;
    ($rmsg,$pdata) = split("\n", $pdata, 2);
    $rmsg =~ s/\v//g;
   	$rmsg =~ s/^\s+|\s+$//g; #remove white space
    if($rmsg) {
	    #find right device with same DeviceID
	    Wecker_Parse($hash,$rmsg);
  	}
  }
  $hash->{PARTIAL} = $pdata;
}

sub Wecker_Parse($$) {
	my ($hash, $rmsg) = @_;
	my $dmsg = $rmsg;
	my $name = $hash->{NAME};
	my $dispatch = 1;
	
	my $devID = ($rmsg =~ m/^[0-9]{2}/ ? substr($rmsg,0,2) : undef);
	return if($devID ne $hash->{DeviceID});
	
 	$dmsg = substr($rmsg,2,length($rmsg)-2);
	    
	# Commands which can only be received from the main physical Module/Device
  if ( $dmsg =~ m/^N[0-9]{2}[0-1]/) {
  	Wecker_UpdateReading($hash, substr($dmsg,1,2), substr($dmsg,3,1));
  	$dispatch = 0;
  }
  
	
	$hash->{"${name}_MSGCNT"}++;
  $hash->{"${name}_TIME"} = TimeNow();

  return if(!$dispatch);
  $hash->{RAWMSG} = $rmsg;

	my %addvals = (RAWMSG => $dmsg);
	#Log3 $hash->{NAME},1, "Dispatch: $rmsg";
  my $found = Dispatch($hash, $dmsg, \%addvals);
}


#####################################
# This is a direct read for commands like get
# IMPORTANT: ReadAnswer beachtet DeviceID!! Fügt diese dem Regex hinzu
sub Wecker_ReadAnswer($$$$) {

  my ($hash, $arg, $alwaysDispatch, $regexp) = @_;
	my $devID=$hash->{DeviceID};
	
  return ("No FD", undef)
        if(!$hash || ($^O !~ /Win/ && !defined($hash->{FD})));

  my ($mdata, $rin) = ("", '');
  my $buf;
  my $to = 3;		                                       # 3 seconds timeout
  $to = $hash->{RA_Timeout} if($hash->{RA_Timeout});  # ...or less
  for(;;) {

    if($^O =~ m/Win/ && $hash->{USBDev}) {
      $hash->{USBDev}->read_const_time($to*1000); # set timeout (ms)
      # Read anstatt input sonst funzt read_const_time nicht.
      $buf = $hash->{USBDev}->read(999);
      return ("Timeout reading answer for get $arg", undef)
        if(length($buf) == 0);

    } else {
      return ("Device lost when reading answer for get $arg", undef)
        if(!$hash->{FD});
			
      vec($rin, $hash->{FD}, 1) = 1;
      my $nfound = select($rin, undef, undef, $to);
      if($nfound < 0) {
        next if ($! == EAGAIN() || $! == EINTR() || $! == 0);
        my $err = $!;
        DevIo_Disconnected($hash);
        return("Wecker_ReadAnswer $arg: $err", undef);
      }
      return ("Timeout reading answer for get $arg", undef)
        if($nfound == 0);
      $buf = DevIo_SimpleRead($hash);
      return ("No data", undef) if(!defined($buf));

    }

    if(defined($buf)) {
      Log3 $hash->{NAME}, 5, "Wecker/RAW (ReadAnswer): $buf";
      $mdata .= $buf;
    }

    # Dispatch data in the buffer before the proper answer.
    while(($mdata =~ m/^([^\n]*\n)(.*)/s)) {
	    my $line = $mdata;
	    $mdata = $2;
    	$hash->{PARTIAL} = $mdata; # for recursive calls
      
      my $regexLine = $line;
			$regexLine =~ s/^$devID//;
      if(($regexp && $regexLine !~ m/$regexp/)) {
      	 $line =~ s/[\n\r]+//g;
      	 Wecker_Parse($hash,$line);
      	 #CallFn($hash->{NAME}, "ParseFn", $hash, $line);
      	 $mdata = $hash->{PARTIAL};
      } else {
        return (undef, $line);
      }
    }
  }
}


#Trigger: N<Pin><0:low,1:high/click,2:doubleClick,3:longClick>
sub Wecker_UpdateReading($$$) {

	my ($hash, $id, $value) = @_;
	my $name = $hash->{NAME};	
	my @TriggerValueArray = ("low", "pulse", "doublePulse", "longPulse");
	
	my $readingName = $TriggerMapping{$id};
	my $readingValue = $TriggerValueArray[$value];

	if(defined($readingName ) && defined($readingValue)) {
	 	Wecker_PushButton($hash, $readingName, $readingValue);
	}
}

sub Wecker_updateReadingAlias($) {

	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $aVal = AttrVal($name, "readingAlias", undef);
	
	if($aVal) {
		my @a = split(",", $aVal);
		foreach my $val (@a) {
			my @names = split(/:/, $val);
			$hash->{READINGS}{$names[1]} = delete $hash->{READINGS}{$names[0]};
			$hash->{READINGS}{$names[1] . "_Value"} = delete $hash->{READINGS}{$names[0]. "_Value"} if(defined($hash->{READINGS}{$names[0]. "_Value"}));
		}
	}	
}


sub Wecker_PushButton($$$) {
	my ($hash, $readingName, $readingValue) = @_;
	my $name	= $hash->{NAME};
	
	Log3 $name, 5, "$name: (PushButton) $name>$readingName|$readingValue";
	return if($readingValue !~ m/pulse/); #proceed just with pulse triggers
	
	Wecker_updateOperationState($hash, $readingName);
}

sub Wecker_updateOperationState($$) {

	my ($hash, $event) = @_;
	my $name	= $hash->{NAME};

	my $doUpdateOperationEvent;
	my $OperationState											= ReadingsVal($name, "state", "initialized");
		 $OperationState 											= "standby" if($OperationState eq "initialized");
	my $newState 														= $OperationState;		 
	my $activateOperationTimeOut 						= 1;

	my $MediaPlayerDeviceName								= AttrVal($name, "MediaPlayer_Device", $Wecker_Default_MediaPlayerDevice);
	my $LightColor 													= AttrVal($name, "Light_Color", $Wecker_Default_LightColor);


	Log3 $name, 5, "$name: (updateOperationState) $OperationState>$event";
	
	############################################################ STANDBY ############################################################
	if($OperationState eq "standby") {

		if($event eq "lTop") {
			my $OnOff = ( (ReadingsVal($name, "Light", "off") eq "off") ? "on" : "off");
			Wecker_setLight($hash, $OnOff, $LightColor);

			$newState = (($OnOff eq "on") ? "light" : "standby");

		} elsif($event eq "rTop") {
			my $OnOff = ( (ReadingsVal($MediaPlayerDeviceName, "state", undef) ne "play") ? "on" : "off");
			Wecker_setMusic($hash, $OnOff,undef);

			$newState = (($OnOff eq "on") ? "music" : "standby");
			$activateOperationTimeOut = 0;

		} elsif($event =~ m/(lUp|rUp)/) {
			if(!$Wecker_Clock_State) { #Show Clock for some time @Night with turned off Clock
				$newState = "clockShow";
				Wecker_setClock($hash,"on");
				$hash->{helper}{OperationTimeOutRecover} = "recoverFromClockShow";			
			}
		} elsif($event =~ m/(lDown|rDown)/) {
			$newState = "alarmConfig";
			Wecker_setAlarm($hash, "show " . ($event eq "lDown" ? "left" : "right"));
			$hash->{helper}{OperationTimeOutRecover} = "recoverFromAlarmConfig";
			
		} elsif($event eq "goToBed") {
			$newState = "goToBed";
			Wecker_setAlarm($hash, "show next");
			Wecker_setLight($hash, "setBrightness", "10");
			Wecker_setLight($hash, "on", $LightColor);
			$hash->{helper}{OperationTimeOutRecover} = "recoverFromGoToBed";
			$hash->{helper}{OperationTimeOutSec} = 30*60; # 30min		
		
		} elsif($event eq "recoverFromGoToBed") {
			Wecker_setLight($hash, "clear", undef);
			Wecker_setClock($hash, "off");
		
		} elsif($event eq "recoverFromAlarmConfig") {
			Wecker_setClock($hash, undef);
			Wecker_setLight($hash, "recover", $LightColor);

		} elsif($event eq "recoverFromClockShow") {
			Wecker_setClock($hash, "off");

		}
				
	############################################################ LIGHT ############################################################
	} elsif($OperationState =~ m/light/) {
	
		if($event eq "lTop") {
			Wecker_setLight($hash, "shift", $LightColor);

		} elsif($event =~ m/(lUp|lDown)/) {
			Wecker_setLight($hash, ( ($event eq "lUp") ? "up" : "down"), $LightColor);
		}
		
	############################################################ MUSIK ############################################################
	} elsif($OperationState =~ m/music/) {
		my %cmdTranslate = 	(	"lUp" 		=> "volumeUp",
													"lDown"		=> "volumeDown",
													"rUp"			=> "next",
													"rDown"		=> "previous",
													"rTop"		=> "stop",																							
												);
		Wecker_setMusic($hash, $cmdTranslate{$event}, undef) if(defined($cmdTranslate{$event}));

		if($event eq "rTop") {
			$newState = "standby";
			$hash->{helper}{OperationTimeOutState} = "standby";
			$activateOperationTimeOut = 0;			
	
		} elsif ($event eq "lTop") {
			$newState = "standby";
			$hash->{helper}{OperationTimeOutState} = "music";
			$doUpdateOperationEvent = "lTop";
			
		} else {
			$activateOperationTimeOut = 0;
		}

	############################################################ ALARM ############################################################
	} elsif($OperationState =~ m/^alarm$/) {
		
		$activateOperationTimeOut = 0;	
		
		if($event =~ m/(on|off|pre|snooze|hard)/) {
			Wecker_setAlarm($hash,$event);
			Wecker_setClock($hash,"on");
			$newState = "standby" if($event eq "off");
			
		} elsif ($event =~ m/rTop/) {
			$newState = "standby";
			Wecker_setAlarm($hash, "off");
		
		} elsif ($event =~ m/lTop/) {
			Wecker_setLight($hash, "toggle", $LightColor);
			
		} elsif ($event =~ m/(Up|Down)/) {
			Wecker_setAlarm($hash, "snooze");
		}
	
	} elsif($OperationState =~ m/^alarmConfig$/) {

		Log3 $name, 1, "$name: alarmconfig $event";

		if($event =~ m/Down/) {
			Wecker_setAlarm($hash, "show " . ($event eq "lDown" ? "left" : "right"));
	
		} elsif($event =~ m/Up/) {
			Wecker_setAlarm($hash, "skipToggle " . ($event eq "lUp" ? "left" : "right"));
			Wecker_setAlarm($hash, "show " . ($event eq "lUp" ? "left" : "right"));
		}
		
		$hash->{helper}{OperationTimeOutRecover} = "recoverFromAlarmConfig";
	
	############################################################ GoToBed ############################################################
	} elsif($OperationState =~ m/^goToBed$/) {	
		$newState = "standby";
		$doUpdateOperationEvent = "recoverFromGoToBed";
	
	###############################################################################################################################
	}
	
	Wecker_setOperationState($hash, ($newState ne $OperationState ? $newState : undef), $doUpdateOperationEvent, $activateOperationTimeOut);
}

sub Wecker_setOperationState($$$$) {
	my ($hash, $newState, $doUpdateOperationEvent, $activateOperationTimeOut) = @_;
	my $name	= $hash->{NAME};
	my $OperationStateTimeOut = AttrVal($name, "OperationStateTimeOut", $Wecker_Default_OperationStateTimeOut); #sec
	$OperationStateTimeOut = $hash->{helper}{OperationTimeOutSec} if(defined($hash->{helper}{OperationTimeOutSec}));
	delete $hash->{helper}{OperationTimeOutSec};
	
	readingsSingleUpdate($hash,"state", $newState,1) if($newState);
	
	if($doUpdateOperationEvent) {
		Wecker_updateOperationState($hash, $doUpdateOperationEvent);
	} else {
		RemoveInternalTimer($hash, "Wecker_OperationStateTimeOut");
		InternalTimer(gettimeofday()+$OperationStateTimeOut, "Wecker_OperationStateTimeOut", $hash, 0) if($activateOperationTimeOut);
	}
}

sub Wecker_OperationStateTimeOut($) {
  my $hash = shift;
  
  Wecker_setOperationState($hash, $hash->{helper}{OperationTimeOutState}, $hash->{helper}{OperationTimeOutRecover}, undef);
  delete $hash->{helper}{OperationTimeOutRecover};
  
  #readingsSingleUpdate($hash,"state", $hash->{helper}{OperationTimeOutState}, 1);
	#if($hash->{helper}{OperationTimeOutRecover}) {
  #	Wecker_updateOperationState($hash,$hash->{helper}{OperationTimeOutRecover});
  #	delete $hash->{helper}{OperationTimeOutRecover};
  #}
}

sub Wecker_setAlarm($$) {
	my ($hash, $event) = @_;
	my $name	= $hash->{NAME};
	
	my $Alarm_SnoozeTimeSec				= AttrVal($name, "Alarm_SnoozeTimeSec", $Wecker_Default_SnoozeTimeSec);
	my $PreAlarmVolume						= AttrVal($name, "Alarm_PreAlarmVolume", $Wecker_Default_PreAlarmMusicVolume);
	my $PreAlarmFile							= AttrVal($name, "Alarm_PreAlarmFile", "$Wecker_Default_PreAlarmMusicPlaylist|0|0");
	my $AlarmFile									= AttrVal($name, "Alarm_AlarmFile", "$Wecker_Default_PreAlarmMusicPlaylist|1|0");
	my $HardAlarmFile							= AttrVal($name, "Alarm_HardAlarmFile", "$Wecker_Default_PreAlarmMusicPlaylist|3|0");
	

	if($event eq "pre") {
		my $PreAlarmTimeOfAlarmClockDevice	= AttrVal(ReadingsVal($name,"activeAlarmClock",undef), "PreAlarmTimeInSec", undef);

		Wecker_setLight($hash,((defined($PreAlarmTimeOfAlarmClockDevice)) ? "fade $PreAlarmTimeOfAlarmClockDevice" : "fade"), undef);
		Wecker_setLight($hash, Wecker_getAlarmLight($name), $Wecker_Default_AlarmOnOffLightColor[1]); #Alarm Side Color
		
		Wecker_setMusic($hash, "volume",$PreAlarmVolume);
		Wecker_setMusic($hash, (($PreAlarmFile =~ m/.+\|[0-9]\|[0-9]/) ? "playlist" : "playfile"), $PreAlarmFile);
		Wecker_setMusic($hash, "repeat","1");
		readingsSingleUpdate($hash, "Alarm", "pre", 1);
		
	} elsif ($event eq "on") {
		Wecker_setMusic($hash, "volume", undef);
		Wecker_setMusic($hash, (($AlarmFile =~ m/.+\|[0-9]\|[0-9]/) ? "playlist" : "playfile"), $AlarmFile);	
		readingsSingleUpdate($hash, "Alarm", "on", 1);

	} elsif ($event eq "hard") {
			Wecker_setMusic($hash, "volume", "100");
			Wecker_setMusic($hash, (($HardAlarmFile =~ m/.+\|[0-9]\|[0-9]/) ? "playlist" : "playfile"),$HardAlarmFile);
			Wecker_setMusic($hash, "repeat",1);	
	
	} elsif ($event eq "snooze") {
		Wecker_setMusic($hash,"mute",undef);
		RemoveInternalTimer($hash, "Wecker_snoozeFinished");
		InternalTimer(gettimeofday()+$Alarm_SnoozeTimeSec, "Wecker_snoozeFinished", $hash, 0);
		readingsSingleUpdate($hash, "Alarm", "snooze", 1);
		
	} elsif ($event eq "unsnooze") {
		Wecker_setMusic($hash,"unmute",undef);
		readingsSingleUpdate($hash, "Alarm", "on", 1);		
	
	} elsif ($event eq "off") {
		Wecker_setLight($hash, "clear", undef);
		Wecker_setMusic($hash,"stop",undef);
		readingsSingleUpdate($hash, "Alarm", "off", 1);
		delete $hash->{READINGS}{activeAlarmClock};
		
	} elsif ($event =~ m/^show/) {
		
		my $printClock=0;		
		my $SelectClock = (split(' ',$event,2))[1];
		$SelectClock = "left" if(!defined($SelectClock));
		
		my $AlarmDevMapping	= AttrVal($name, "Alarm_DeviceMapping", undef);
		if(!defined($AlarmDevMapping)) { Log3 $name, 1, "$name: Alarm_DeviceMapping must be defined"; return; }		
		my @AlarmClockDeviceNames = split(',', $AlarmDevMapping, 2);
		$AlarmClockDeviceNames[0] =~ s/^\s+|\s+$//g; #remove white space
		$AlarmClockDeviceNames[1] =~ s/^\s+|\s+$//g; #remove white space

		my ($lNextAlarmClock, $lNextAlarmInSec, $lNextAlarmActive) = Wecker_getNextAlarm($defs{$AlarmClockDeviceNames[0]});
		Log3 $hash->{NAME}, 4, "$hash->{NAME}: Wecker_getNextAlarm $lNextAlarmClock " . ($lNextAlarmActive?"active":"inactive");
		my ($rNextAlarmClock, $rNextAlarmInSec, $rNextAlarmActive) = Wecker_getNextAlarm($defs{$AlarmClockDeviceNames[1]});
		Log3 $hash->{NAME}, 4, "$hash->{NAME}: Wecker_getNextAlarm $rNextAlarmClock " . ($rNextAlarmActive?"active":"inactive");
		
		if($SelectClock =~ m/(left|right)/) {
			Wecker_setClock($hash, (($SelectClock eq "left") ? $lNextAlarmClock : $rNextAlarmClock));
			
		} else {
			my $minAlarmClock = undef;
			$minAlarmClock = $lNextAlarmClock 																															if(defined($lNextAlarmClock) && !defined($rNextAlarmClock));
			$minAlarmClock = $rNextAlarmClock 																															if(!defined($lNextAlarmClock) && defined($rNextAlarmClock));
			$minAlarmClock = (($lNextAlarmInSec < $rNextAlarmInSec) ? $lNextAlarmClock : $rNextAlarmClock) 	if(defined($lNextAlarmClock) && defined($rNextAlarmClock));
			$minAlarmClock = (($lNextAlarmActive) 									? $lNextAlarmClock : $rNextAlarmClock) 	if($lNextAlarmActive ne $rNextAlarmActive);
		
			Wecker_setClock($hash, $minAlarmClock);
		}

		Wecker_setLight($hash, "left", $Wecker_Default_AlarmOnOffLightColor[$lNextAlarmActive]);
		Wecker_setLight($hash, "right", $Wecker_Default_AlarmOnOffLightColor[$rNextAlarmActive]);
	
	} elsif ($event =~ m/^skipToggle/) {
	
		my $SelectClock = (split(' ',$event,2))[1];
		$SelectClock = "left" if(!defined($SelectClock));
		
		my $AlarmDevMapping	= AttrVal($name, "Alarm_DeviceMapping", undef);
		if(!defined($AlarmDevMapping)) { Log3 $name, 1, "$name: Alarm_DeviceMapping must be defined"; return; }		
		my @AlarmClockDeviceNames = split(',', $AlarmDevMapping, 2);
		$AlarmClockDeviceNames[0] =~ s/^\s+|\s+$//g; #remove white space
		$AlarmClockDeviceNames[1] =~ s/^\s+|\s+$//g; #remove white space
		
		my $AlarmDevice = ($SelectClock eq "left" ? $AlarmClockDeviceNames[0] : $AlarmClockDeviceNames[1]);
			
		my $AlarmStatus = (ReadingsVal($AlarmDevice,"skip","none") eq "none" ? "on" : "off");
		fhem("set " . $AlarmDevice . " skip " . ($AlarmStatus eq "on" ? " NextAlarm" : " None"));
		
		Log3 $name, 1, "$name: skipToggle $AlarmDevice to $AlarmStatus";
		
	}
}

sub Wecker_getNextAlarm($) {
	
	my ($AlarmClockHash) = @_;
	my ($NextAlarmClock, $NextAlarmInSec, $NextAlarmActive) = (undef, undef, 0);
	my %alarmday = 	(	"1"     => "AlarmTime1_Monday",
										"2"     => "AlarmTime2_Tuesday",
										"3"     => "AlarmTime3_Wednesday",
										"4"     => "AlarmTime4_Thursday",
										"5"     => "AlarmTime5_Friday",
										"6"     => "AlarmTime6_Saturday",
										"0"     => "AlarmTime7_Sunday",
										"8"     => "AlarmTime8_Holiday",
										"9"     => "AlarmTime9_Vacation"
									);
	my ($SecNow, $MinNow, $HourNow) = localtime(time);
  my $NowinSec = ($HourNow * 3600) + ($MinNow * 60) + $SecNow;									
	my $AlarmWeekdayReadingToday 		= $alarmday{$AlarmClockHash->{helper}{Today}};
	my $AlarmWeekdayReadingTomorrow = $alarmday{$AlarmClockHash->{helper}{Tomorrow}};
	
	my ($ToDayClock, $ToDayInSec) 										= Wecker_getAlarmByReading($AlarmClockHash, $NowinSec	, "AlarmToday");
	my ($ToDayWeekdayClock, $ToDayWeekdayInSec) 			= Wecker_getAlarmByReading($AlarmClockHash, $NowinSec	, $AlarmWeekdayReadingToday );
	my ($TomorrowClock, $TomorrowInSec) 							= Wecker_getAlarmByReading($AlarmClockHash, 0					, "AlarmTomorrow");
	my ($TomorrowWeekdayClock, $TomorrowWeekdayInSec) = Wecker_getAlarmByReading($AlarmClockHash, 0					, $AlarmWeekdayReadingTomorrow);

	#Today
	if($ToDayClock) { #Time is set, in the future and active
		($NextAlarmClock, $NextAlarmInSec, $NextAlarmActive) = ($ToDayClock, $ToDayInSec, 1);
	} elsif(!$ToDayClock && $ToDayWeekdayClock) { #Time is set, in the future but deaktivated!
		($NextAlarmClock, $NextAlarmInSec, $NextAlarmActive) = ($ToDayWeekdayClock, $ToDayWeekdayInSec, 0);

	#Tomorrow
	} else {
		
		if($TomorrowClock && $TomorrowInSec < $NowinSec) {
			($NextAlarmClock, $NextAlarmInSec, $NextAlarmActive) = ($TomorrowClock, $TomorrowInSec, 1);
		} elsif(!$TomorrowClock && $TomorrowWeekdayClock) { #Time is set, in the future but deaktivated!
			($NextAlarmClock, $NextAlarmInSec, $NextAlarmActive) = ($TomorrowWeekdayClock, $TomorrowWeekdayInSec, 0);
		} else {
		}
	}
	
	$NextAlarmActive = 0 if(ReadingsVal($AlarmClockHash->{NAME}, "skip", "none") ne "none");
	$NextAlarmActive = 0 if(ReadingsVal($AlarmClockHash->{NAME}, "state", "OK") eq "deactivated");
	
	return ($NextAlarmClock, $NextAlarmInSec, $NextAlarmActive);
}

#Return undef if AlarmTime is not set "00:00" or Time is in the past
sub Wecker_getAlarmByReading($$$) {
	my ($hash, $timeInSec, $reading) = @_;
  my $AlarmIn = undef;
  
	my $value = ReadingsVal($hash->{NAME}, $reading, "");
	
  if ($value =~ /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/) {
      $value =~ /^([0-9]|0[0-9]|1?[0-9]|2[0-3]):([0-5]?[0-9])$/;
      my $AlarminSec = ($1 * 3600) + ($2 * 60);
      
    	if(($timeInSec < $AlarminSec)) {
				$AlarmIn = $AlarminSec - $timeInSec;
				$AlarmIn = undef if($AlarmIn < 0); #Time is over
			}
	}
	return (($AlarmIn?$value:undef), $AlarmIn);
}

sub Wecker_getAlarmLight($) {
	my $name 						= shift;
	my $alarmDev 				= ReadingsVal($name,"activeAlarmClock","");
	my $AlarmDevMapping	= AttrVal($name, "Alarm_DeviceMapping", undef);
	
	return (($AlarmDevMapping =~ m/^$alarmDev/) ? "left" : "right");
}

sub Wecker_snoozeFinished($) {
  my $hash = shift;
  Wecker_setAlarm($hash, "unsnooze");
}

sub Wecker_setClock($$) {

	my ($hash, $event) = @_;
	my $name	= $hash->{NAME};
	
	my $ClockBrightness = ReadingsVal($name, "clock_brightness", $Wecker_Default_ClockBrightness);
	
	if(!defined($event)) {
		Wecker_setClock($hash,($Wecker_Clock_State?"on":"off"));

	} elsif ($event =~ m/^on$/) {
		Wecker_Write($hash, "cb" . $ClockBrightness);
		Wecker_Write($hash, "c");
		$Wecker_Clock_State=1;
			
	} elsif ($event =~ m/^off$/) {
		Wecker_Write($hash, "cc");
		$Wecker_Clock_State=0;
		
	} else {
		if($event =~ m/^[0-9]{1,2}:[0-9]{2}/) { #Time to Clock 09:00
			my @t = split(':',$event);
			$event = 	($t[0] > 9 ? substr($t[0],0,1) . " " . substr($t[0],1,1) : "0 " . int($t[0])) . "." .
						 		($t[1] > 9 ? substr($t[1],0,1) . " " . substr($t[1],1,1) : "0 " . int($t[1])) . " ";
			#Log3 $hash->{NAME}, 1, "$hash->{NAME}: Wecker_setClock with $event";
				
		}

		Wecker_Write($hash, "c" . $event);
	}
}

sub Wecker_setMusic($$$) {
	my ($hash, $event, $arg) = @_;
	my $name	= $hash->{NAME};
	$arg = "" if(!defined($arg));

	return if(!defined($event));
	my $MediaPlayerDeviceName			= AttrVal($name, "MediaPlayer_Device", $Wecker_Default_MediaPlayerDevice);
	my $MediaPlayerVolume					= AttrVal($name, "MediaPlayer_Volume", $Wecker_Default_MusicVolume);
	my $MediaPlaylist 						= AttrVal($name, "MediaPlayer_DefaultPlaylist", $Wecker_Default_MusicPlaylist);
	
	if(!defined($defs{$MediaPlayerDeviceName})) {
		readingsSingleUpdate($hash, "Music", "off", 1);
		return;
	}
	
	if($event =~ m/^play/) {
		fhem("set $MediaPlayerDeviceName $event $arg");
		fhem("set $MediaPlayerDeviceName mute off");	
		fhem("set $MediaPlayerDeviceName repeat 0");	
		readingsSingleUpdate($hash, "Music", "on", 1);

	} elsif ($event eq "on") {
		fhem("set $MediaPlayerDeviceName volume $MediaPlayerVolume");
		fhem("set $MediaPlayerDeviceName playlist " . ($arg?$arg:"$MediaPlaylist|0|0"));
		fhem("set $MediaPlayerDeviceName mute off");	
		fhem("set $MediaPlayerDeviceName repeat 0");	
		readingsSingleUpdate($hash, "Music", "on", 1);
		
	} elsif ($event eq "repeat") {
		fhem("set $MediaPlayerDeviceName repeat " . ($arg?$arg:"1"));
	
	} elsif ($event =~ m/(unmute|mute)/) {
		fhem("set $MediaPlayerDeviceName mute " . ($event eq "mute" ? "on" : "off"));
	
	} elsif ($event =~ m/(stop|off)/) {
		fhem("set $MediaPlayerDeviceName stop");	
		readingsSingleUpdate($hash, "Music", "off", 1);
		
	} elsif ($event eq "volume" && !$arg) {
		fhem("set $MediaPlayerDeviceName volume $MediaPlayerVolume");
		
	}	elsif ($event =~ m/(volume|volumeUp|volumeDown|next|previous)/) {
		fhem("set $MediaPlayerDeviceName $event $arg");

	}
}

sub Wecker_setLight($$$) {
	my ($hash, $event, $arg) = @_;
	my $name	= $hash->{NAME};
	
	$hash->{helper}{iLightGroup} = 0 if(!defined($hash->{helper}{iLightGroup}));
	my $LightGroupID 		= $Wecker_LightGroups[$hash->{helper}{iLightGroup}];
	my $LightBrightness = ReadingsVal($name, "led_brightness", $Wecker_Default_LedBrightness);
	
	if($event eq "on") {
		$hash->{helper}{iLightGroup} = 0;
		$LightGroupID = $Wecker_LightGroups[0];

		Wecker_Write($hash, "lb" . $LightBrightness); #reset Brightness
		#select(undef,undef,undef,0.1);
		Wecker_Write($hash, "lg" .$LightGroupID . $arg);
		readingsSingleUpdate($hash, "Light", "on", 1);

	} elsif($event eq "off") {
		Wecker_Write($hash, "lcg" .$LightGroupID);
		RemoveInternalTimer($hash, "Wecker_LightFade");
		readingsSingleUpdate($hash, "Light", "off", 1);		
		
	} elsif($event eq "toggle") {
		my $OnOff = ReadingsVal($name, "Light", "off");
		Wecker_setLight($hash, ($OnOff eq "off" ? "on" : "off"), $arg);
	
	} elsif($event eq "recover") {
		Wecker_Write($hash, "lc");
		Wecker_Write($hash, "lg" .$LightGroupID . $arg) if(ReadingsVal($name, "Light", "off") eq "on");
			
	} elsif($event eq "clear") {
		Wecker_Write($hash, "lc");
		RemoveInternalTimer($hash, "Wecker_LightFade");
		readingsSingleUpdate($hash, "Light", "off", 1);				
		
	} elsif( $event eq "shift") {
		#Switch to Next Light Group
		Wecker_Write($hash, "lcg" . $LightGroupID . $arg);
		$hash->{helper}{iLightGroup} += 1;
		$hash->{helper}{iLightGroup} = 0 if($#Wecker_LightGroups < $hash->{helper}{iLightGroup});
		$LightGroupID = $Wecker_LightGroups[$hash->{helper}{iLightGroup}];
		Wecker_Write($hash, "lg" . $LightGroupID . $arg);

	} elsif($event =~ m/(up|down)/) {
		
		$LightBrightness += ($event eq "up" ? 10 : -10);
	 	$LightBrightness = 100 if($LightBrightness > 100);
		$LightBrightness = 10 if($LightBrightness < 10);
					
		Wecker_Write($hash, "lb" . $LightBrightness);
		readingsSingleUpdate($hash, "led_brightness", $LightBrightness,1);	
		
	} elsif($event =~ m/setBrightness/) {
		Wecker_Write($hash, "lb" . $arg);
		readingsSingleUpdate($hash, "led_brightness", $arg, 1);
			
	} elsif($event =~ m/(left|right|bottom|top)/) {
		my %cmdTranslate = 	(	"top"			=> "0",			#CAUTION: Array Index!
													"bottom"	=> "1",
													"left" 		=> "2",
													"right"		=> "3",								
												);
		$LightGroupID = $Wecker_LightGroups[$cmdTranslate{$event}];
		Wecker_Write($hash, "lg" . $LightGroupID . $arg);
		
	} elsif($event =~ m/^fade/) {
		my $FadeDuration 															= int((split(' ',$event,2))[1]);
		$FadeDuration		 															= $#Wecker_PreAlarmSunRise if(!defined($FadeDuration) || $FadeDuration == 0);
		$hash->{helper}{iFadeDelay} 									= int($FadeDuration/$#Wecker_PreAlarmSunRise);
		$hash->{helper}{iFadeBrightnessCounterSteps} 	= int($#Wecker_PreAlarmSunRise/$#Wecker_PreAlarmBrightness); #49 / 6 = int = 8
		$hash->{helper}{iFadeCounter} 								= 0;
		
		Wecker_setLight($hash, "setBrightness", $Wecker_PreAlarmBrightness[0]);
		Wecker_setLight($hash, "on", $Wecker_PreAlarmSunRise[0]);
		
		RemoveInternalTimer($hash, "Wecker_LightFade");
		InternalTimer(gettimeofday()+($hash->{helper}{iFadeDelay}), "Wecker_LightFade", $hash, 0);		
	
	}

}
	
sub Wecker_LightFade($) {
  my $hash = shift;
  my $name	= $hash->{NAME};
	
	my $LightBrightness = ReadingsVal($name, "led_brightness", $Wecker_Default_LedBrightness);
		
	$hash->{helper}{iFadeCounter}++;
	my $newBrightness = $Wecker_PreAlarmBrightness[int( ($hash->{helper}{iFadeCounter}+1) / $hash->{helper}{iFadeBrightnessCounterSteps})];  #+1 wegen dem index 0
	if($newBrightness ne $LightBrightness) {
		Wecker_setLight($hash, "setBrightness", $newBrightness);
	}
	
	Wecker_setLight($hash, "top", $Wecker_PreAlarmSunRise[$hash->{helper}{iFadeCounter}]);
	
	my $done=1;
	if(($hash->{helper}{iFadeCounter}+1) <= $#Wecker_PreAlarmSunRise) {
		InternalTimer(gettimeofday()+($hash->{helper}{iFadeDelay}), "Wecker_LightFade", $hash, 0);		
		$done = 0;
	}
	
#	Log3 $hash->{NAME}, 1, "$hash->{NAME}: Wecker_LightFade <" . $hash->{helper}{iFadeCounter} . "|Brightness: $newBrightness " . int(($hash->{helper}{iFadeCounter}+1) / $hash->{helper}{iFadeBrightnessCounterSteps}) ."|done: $done|" . $Wecker_PreAlarmSunRise[$hash->{helper}{iFadeCounter}] .">";
}


1;

=pod
=begin html

<a name="Wecker"></a>
<h3>Wecker</h3>
<ul>
  The Wecker is a family of RF devices sold by <a href="http://jeelabs.com">jeelabs.com</a>.

  It is possible to attach more than one device in order to get better
  reception, fhem will filter out duplicate messages.<br><br>

  This module provides the IODevice for:
  <ul>
  <li><a href="#PCA301">PCA301</a> modules that implement the PCA301 protocol.</li>
  <li><a href="#LaCrosse">LaCrosse</a> modules that implement the IT+ protocol (Sensors like TX29DTH, TX35, ...).</li>
  <li>LevelSender for measuring tank levels</li>
  <li>EMT7110 energy meter</li>
  <li>Other Sensors like WT440XH (their protocol gets transformed to IT+)</li>
  </ul>

  <br>
  Note: this module may require the Device::SerialPort or Win32::SerialPort module if you attach the device via USB
  and the OS sets strange default parameters for serial devices.

  <br><br>

  <a name="Wecker_Define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; Wecker &lt;device&gt;</code> <br>
    <br>
    USB-connected devices:<br><ul>
      &lt;device&gt; specifies the serial port to communicate with the Wecker.
      The name of the serial-device depends on your distribution, under
      linux the cdc_acm kernel module is responsible, and usually a
      /dev/ttyACM0 device will be created. If your distribution does not have a
      cdc_acm module, you can force usbserial to handle the Wecker by the
      following command:<ul>modprobe usbserial vendor=0x0403
      product=0x6001</ul>In this case the device is most probably
      /dev/ttyUSB0.<br><br>

      You can also specify a baudrate if the device name contains the @
      character, e.g.: /dev/ttyACM0@57600<br><br>

      If the baudrate is "directio" (e.g.: /dev/ttyACM0@directio), then the
      perl module Device::SerialPort is not needed, and fhem opens the device
      with simple file io. This might work if the operating system uses sane
      defaults for the serial parameters, e.g. some Linux distributions and
      OSX.  <br>

    </ul>
    <br>
  </ul>

  <a name="Wecker_Set"></a>
  <b>Set</b>
  <ul>
    <li>raw &lt;data&gt;<br>
        send &lt;data&gt; to the Wecker. Depending on the sketch running on the Wecker, different commands are available. Most of the sketches support the v command to get the version info and the ? command to get the list of available commands.
    </li><br>

    <li>reset<br>
        force a device reset closing and reopening the device.
    </li><br>

    <li>LaCrossePairForSec &lt;sec&gt; [ignore_battery]<br>
       enable autocreate of new LaCrosse sensors for &lt;sec&gt; seconds. If ignore_battery is not given only sensors
       sending the 'new battery' flag will be created.
    </li><br>

    <li>flash [hexFile]<br>
    The Wecker needs the right firmware to be able to receive and deliver the sensor data to fhem. In addition to the way using the
    arduino IDE to flash the firmware into the Wecker this provides a way to flash it directly from FHEM.

    There are some requirements:
    <ul>
      <li>avrdude must be installed on the host<br>
      On a Raspberry PI this can be done with: sudo apt-get install avrdude</li>
      <li>the flashCommand attribute must be set.<br>
        This attribute defines the command, that gets sent to avrdude to flash the Wecker.<br>
        The default is: avrdude -p atmega328P -c arduino -P [PORT] -D -U flash:w:[HEXFILE] 2>[LOGFILE]<br>
        It contains some place-holders that automatically get filled with the according values:<br>
        <ul>
          <li>[PORT]<br>
            is the port the Wecker is connectd to (e.g. /dev/ttyUSB0)</li>
          <li>[HEXFILE]<br>
            is the .hex file that shall get flashed. There are three options (applied in this order):<br>
            - passed in set flash<br>
            - taken from the hexFile attribute<br>
            - the default value defined in the module<br>
          </li>
          <li>[LOGFILE]<br>
            The logfile that collects information about the flash process. It gets displayed in FHEM after finishing the flash process</li>
        </ul>
      </li>
    </ul>

    </li><br>

    <li>led &lt;on|off&gt;<br>
    Is used to disable the blue activity LED
    </li><br>

    <li>beep<br>
    ...
    </li><br>

    <li>setReceiverMode<br>
    ...
    </li><br>

  </ul>

  <a name="Wecker_Get"></a>
  <b>Get</b>
  <ul>
  </ul>
  <br>

  <a name="Wecker_Attr"></a>
  <b>Attributes</b>
  <ul>
    <li>Clients<br>
      The received data gets distributed to a client (e.g. LaCrosse, EMT7110, ...) that handles the data.
      This attribute tells, which are the clients, that handle the data. If you add a new module to FHEM, that shall handle
      data distributed by the Wecker module, you must add it to the Clients attribute.</li>

    <li>MatchList<br>
      can be set to a perl expression that returns a hash that is used as the MatchList<br>
      <code>attr myWecker MatchList {'5:AliRF' => '^\\S+\\s+5 '}</code></li>

    <li>initCommands<br>
      Space separated list of commands to send for device initialization.<br>
      This can be used e.g. to bring the LaCrosse Sketch into the data rate toggle mode. In this case initCommands would be: 30t
    </li>

    <li>flashCommand<br>
      See "Set flash"
    </li><br>


  </ul>
  <br>
</ul>

=end html
=cut
