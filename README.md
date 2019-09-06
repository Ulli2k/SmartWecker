# SmartWecker

## Präparation SD-Karte
# Download Strech (Headless) Image https://www.raspberrypi.org/documentation/installation/installing-images/README.md

	1) unzip -p 2018-06-27-raspbian-stretch-lite.zip | sudo dd of=/dev/mmcblk0 bs=4M status=progress conv=fsync
	2) auf SD Karte folgende Files in der Boot-Partition (Raspbian Stretch) erstellen

    * touch /media/ulli/boot/ssh
    * nano /media/ulli/boot/wpa_supplicant.conf
			country=DE
			ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
			update_config=1
			network={
						 ssid="Dahoam"
						 psk="passwort"
						 key_mgmt=WPA-PSK
			}
	3) Login
		ssh pi@raspberrypi
		pw: raspberry
		
		* Passwortänderung mit passwd -->	XXXXX
		* Rechnernamen ändern sudo nano /etc/hostname

## Uhrzeit ##
	sudo raspi-config
	date
	
## Sound Karte ##
	#Equalizer
		sudo apt-get install libasound2-plugin-equal
	* aplay -l --> Card 1 ist USB Soundkarte
	* sudo nano /etc/asound.conf
		pcm.!default {
				type hw
				card 1
		}
		 
		ctl.!default {
				type hw           
				card 1
		}	
	* reboot
	* wget cdn.raspberry.tips/2017/09/test-sound-raspberry-tips.wav
	* aplay test-sound-raspberry-tips.wav
	* Lautstärke über alsamixer



## SAMBA ##
	sudo apt-get install samba samba-common
	sudo nano /etc/samba/smb.conf
		[global]
		security = user
		[homes]
		browseable = yes
		read only = no

	sudo smbpasswd -a pi ##samba PW setzten

## Mount auf Laptop
	sudo nano /etc/fstab
		//wecker/homes/wecker /mnt/wecker cifs noauto,uid=1000,gid=1000,user=pi,password=didRW4m,nobrl,rw 0 0
	mount /mnt/wecker

## Mopidy ##
	wget -q -O - https://apt.mopidy.com/mopidy.gpg | sudo apt-key add -
	sudo wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/stretch.list
	sudo apt-get update
	sudo apt-get install mopidy
	sudo mopidyctl config
	* sudo nano /etc/mopidy/mopidy.conf
		ergänzen um
			 [http]
				enabled = true
				hostname = ::
				port = 6680
				static_dir =
				zeroconf = Mopidy HTTP server on $hostname

	sudo systemctl enable mopidy
	sudo systemctl start mopidy
	sudo systemctl status mopidy

	Playlists:
	* nano /var/lib/mopidy/playlists/egoFM.m3u
		#EXTM3U
		#EXTINF:-1,flash
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmflash_128/livestream.mp3?
		#EXTINF:-1,riff
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmriff_128/livestream.mp3?
		#EXTINF:-1,soul
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmsoul_128/livestream.mp3?
		#EXTINF:-1,live
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofm_192/livestream.mp3?
		#EXTINF:-1,plus
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmplus_192/livestream.mp3?
		#EXTINF:-1,pure         
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmpure_192/livestream.mp3?
		#EXTINF:-1,rap          
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmrap_192/livestream.mp3?
		#EXTINF:-1,snow         
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmsnow_192/livestream.mp3?

	* nano /var/lib/mopidy/playlists/Radio.m3u
		#EXTM3U
		#EXTINF:-1,Energy
		#EXTVLCOPT:network-caching=1000
		http://energyradio.de/muenchen
		#EXTINF:-1,Gong96.3
		#EXTVLCOPT:network-caching=1000
		http://mp3.radiogong963.c.nmdn.net/ps-radiogong963/livestream.mp3?

	sudo chown mopidy:audio /var/lib/mopidy/playlists/*

## MPD ##
	#hhttp://www.linux-community.de/ausgaben/linuxuser/2013/07/raspberry-pi-zur-miniatur-musikzentrale-ausbauen/
	sudo apt-get install mpd mpc
	sudo apt-get install mpg321 lame
	sudo apt-get install libxml-simple-perl	libjson-perl		#für FHEM

	#Musik Verzeichnis: /var/lib/mpd/music/
	
	sudo update-rc.d mpd defaults
	
	sudo nano /etc/mpd.conf
		bind_to_address         "127.0.0.1"
		auto_update    "yes"
		auto_update_depth "3"
		audio_output {
        type            "alsa"
        name            "My ALSA Device"
        device          "hw:1,0"        
        format          "44100:16:2"    
        mixer_type      "software"     # hardware/software/disabled 
        
		}

	* aplay -l --> Card 1 ist USB Soundkarte
	* sudo nano /etc/asound.conf
		pcm.!default {
				type hw
				card 1
		}
		 
		ctl.!default {
				type hw           
				card 1
		}	
	
	Playlists:
	* sudo nano /var/lib/mpd/playlists/webradio.m3u
		#EXTM3U
		
-		#EXTINF:-1,Energy
		#EXTVLCOPT:network-caching=1000
		http://energyradio.de/muenchen
		
		#EXTM3U
		#EXTINF:-1,Gong96.3
		#EXTVLCOPT:network-caching=1000
		http://mp3.radiogong963.c.nmdn.net/ps-radiogong963/livestream.mp3?
		#EXTINF:-1,flash
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmflash_128/livestream.mp3?
		#EXTINF:-1,riff
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmriff_128/livestream.mp3?
		#EXTINF:-1,soul
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmsoul_128/livestream.mp3?
		#EXTINF:-1,live
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofm_128/livestream.mp3?
		#EXTINF:-1,pure
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmpure_128/livestream.mp3?
		#EXTINF:-1,rap
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmrap_128/livestream.mp3?
		#EXTINF:-1,snow
		#EXTVLCOPT:network-caching=1000
		http://mp3ad.egofm.c.nmdn.net/egofmsnow_128/livestream.mp3?


	sudo chown mpd:audio /var/lib/mpd/playlists/*	
	mpc load webradio
		
	sudo service mpd restart 
	sudo mpc update
	
## PodCast Downloader ##
nano /home/pi/wecker/podcast2m3u.sh
	#!/bin/bash
	URL="http://www.tagesschau.de/export/podcast/hi/tagesschau-in-100-sekunden/"
	M3U="/var/lib/mpd/playlists/wakeup.m3u"
	URL2File=$(wget -q -O - $URL | sed -n 's/.*enclosure.*url="\([^"]*\)" .*/\1/p')
	cat >"$M3U" <<EOF
	#EXTM3U
	#EXTINF:-1,Meeresrauschen
	/var/lib/mpd/music/Meeresbrandung-auf-Felsen.mp3
	#EXTINF:-1,Tagesschau-100sec
	$URL2File
	#EXTINF:-1,Gong96.3
	#EXTVLCOPT:network-caching=1000
	http://mp3.radiogong963.c.nmdn.net/ps-radiogong963/livestream.mp3?
	EOF
	
sudo chmod +x /home/pi/wecker/podcast2m3u.sh

nano /etc/crontab
	10 0    * * *   mpd     /home/pi/wecker/podcast2m3u.sh > /dev/null 2>&1

## LED Strip WS2812B ##
#https://dordnung.de/raspberrypi-ledstrip/ws2812
# 3,4kOhm Widerstand in Serie der Datenleitung

	* sudo apt-get install build-essential python-dev unzip wget scons swig

	' Audio off da GPIO18 dafür auch genutzt wird
		nano /etc/modprobe.d/snd-blacklist.conf
			blacklist snd_bcm2835
		reboot

	* wget https://github.com/jgarff/rpi_ws281x/archive/master.zip 
		unzip master.zip
		cd rpi_ws281x-master
		sudo scons
		cd python
		sudo python setup.py install
		
	* test der leds
		cd ..
		sudo ./test


## Alternative LED ##
	git clone https://github.com/jazzycamel/ws28128-rpi.git


## Touch Sensoren ##
	# MPR121
	# 3.3V, SCL. SDA from Pi
	# Aufbau & Python: https://learn.adafruit.com/mpr121-capacitive-touch-sensor-on-raspberry-pi-and-beaglebone-black/overview
	# C++ Driver https://github.com/BareConductive/wiringpi-mpr121

	#I2c Aktivieren
	sudo raspi-config --> Interface --> I2c
	sudo apt-get install i2c-tools
	i2cdetect -y 1

	#Code
	sudo apt-get install wiringpi i2c-tools libi2c-dev
	git clone https://github.com/BareConductive/wiringpi-mpr121.git
	cd ~/wiringpi-mpr121/src
	make clean && make 
	sudo make install

	#eigenen Code compilieren
	gcc -o test -lwiringPi -lMPR121 main.cpp


	#Bei fehlern in dmesg
	sudo nano /etc/modprobe.d/raspi-blacklist.conf
		blacklist w1-gpio
	sudo nano /boot/config.txt
		dtoverlay=w1-gpio,pullup=1
	reboot

## 7 Segment Anzeige ##
	# TM1637
	# C Beispiel: http://learn.linksprite.com/raspberry-pi/how-to-use-4-digit-7-segment-module-on-raspberrypi/
	# 1:1 piCode: https://gist.github.com/kentros/5c0d175b22dc89137ba6dc50177c0f93

## FHEM ##
	# MPlayer Module
		https://forum.fhem.de/index.php?topic=18531.0
		
	# Shutdown über FHEM erlauben
		sudo visudo 
			Cmnd_Alias SHUTDOWN_HALT_REBOOT = /sbin/shutdown, /sbin/halt, /sbin/reboot
			fhem    ALL=NOPASSWD: SHUTDOWN_HALT_REBOOT
		



