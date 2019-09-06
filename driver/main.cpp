

//gcc -o test -lwiringPi lib/MPR121/MPR121.cpp main.cpp && sudo ./test
//g++ -o wecker -Wall -Wno-unused-but-set-variable -lwiringPi -lrt -Wno-write-strings -DDEVICE_ID=1 lib/MPR121/MPR121.cpp lib/TM1637/TM1637.cpp lib/WS2811/ws2812-rpi.cpp globals.cpp main.cpp && sudo ./wecker
// gpio readall
// Interrupt Pin: echo "7" > /sys/class/gpio/export
//		sudo cat /sys/kernel/debug/gpio

#include <signal.h>
#include "globals.h"
#include "lib/messages/messages.h"
#include "lib/clock/clock.h"
#include "lib/touch/touch.h"
#include "lib/pixel/pixel.h"

using namespace as;

uint8_t pixelGroups[5][2] = { /*start,end*/
	{11,58},
	{0,10},
	{6,10},
	{0,4},
	{5,5}
};

uint8_t convertHex2Int(char *hex) {
	char buf[3] = { hex[0], hex[1], 0x0 };
	return (int)strtol(buf, NULL, 16);
}

void killSignal(int signalnummer) {
	Clock.clearClock();
	Pixel.setClear();
	printf("Kill-Signal received <%i>\n",signalnummer);
	exit(1);
}

int main(void) {

	char cmd[MAX_MESSAGE_LENGTH];

	if (SIG_ERR == signal(SIGINT, killSignal)) { printf("Signal declaration failed!\n"); exit(1); }
	if (SIG_ERR == signal(SIGTERM, killSignal)) { printf("Signal declaration failed!\n"); exit(1); }
	//if (SIG_ERR == signal(SIGABRT, killSignal)) { printf("Signal declaration failed!\n"); exit(1); }

	Clock.begin();
	Touch.begin();
	Pixel.begin();
	Msg.begin();

	while(true) {
		if(!Msg.poll()) {
			Clock.clearClock();
			Msg.begin();
		}
		Clock.poll();
		Touch.poll();

		if(Msg.getMessage(cmd)) {
			char *p = cmd;
			if(cmd[0] >= '0' && cmd[0] <= '9' && cmd[1] >= '0' && cmd[1] <= '9') p+=2; //jump over Device ID
			switch(p[0]) {
				case 'l': //LED
					if(p[1] == 'c') { //lc
						if(p[2] == 'g') { //lcg<1-3>
							Pixel.setClearRange(pixelGroups[p[3]-'0'-1][0],pixelGroups[p[3]-'0'-1][1]);
						} else if(p[2] >= '0' && p[2] <= '9') {
							Pixel.setClear(atoi(p+2));
						} else {
							Pixel.setClear();
						}
					} else if(p[1] == 'b') { //lb0.1
						Pixel.setBrightness(atoi(p+2)/100.);
					} else if(p[1] == 'g') { //lg<1-3><R:hex><G:hex><B:hex>
						Pixel.setPixelRange(pixelGroups[p[2]-'0'-1][0],pixelGroups[p[2]-'0'-1][1],convertHex2Int(p+3),convertHex2Int(p+5),convertHex2Int(p+7));
					} else {
						Pixel.setPixel(((p[1]-'0')*10+(p[2]-'0')), convertHex2Int(p+3),convertHex2Int(p+5),convertHex2Int(p+7));
					}
				break;
				case 'c': //Clock
					if(p[1] == 'p') {
						Clock.setPoint(0, p[2]=='.');
						Clock.setPoint(1, p[3]=='.');
						Clock.setPoint(2, p[4]=='.');
						Clock.setPoint(3, p[5]=='.');
						Clock.activateClock(true);
					} else if(p[1] == 'b') {
						Clock.setBrightness(atoi(p+2));
					} else if(p[1] >= '0' && p[1] <= '9') {
						Clock.activateClock(false);
						Clock.setValues(p[1]-'0',p[2]=='.',p[3]-'0',p[4]=='.',p[5]-'0',p[6]=='.',p[7]-'0',p[8]=='.');
					} else if(p[1] == 'c') {
						Clock.clearClock();
					} else {
						Clock.activateClock(true);
					}
					// Pixel.demo();
				break;
				case 'a':
					Msg.sendMessage("Hallo\0",7);
				break;
			}
			// printf("Cmd: %s\n",cmd);fflush(stdout);
			// Msg.sendMessage("danke",5);
		}
	}

	return(0);
}
