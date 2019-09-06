/*
###############################################################################
#                                                                             #
# WS2812-RPi                                                                  #
# ==========                                                                  #
# A C++ library for driving WS2812 RGB LED's (known as 'NeoPixels' by         #
#     Adafruit) directly from a Raspberry Pi with accompanying Python wrapper #
# Copyright (C) 2014 Rob Kent                                                 #
#                                                                             #
# This program is free software: you can redistribute it and/or modify        #
# it under the terms of the GNU General Public License as published by        #
# the Free Software Foundation, either version 3 of the License, or           #
# (at your option) any later version.                                         #
#                                                                             #
# This program is distributed in the hope that it will be useful,             #
# but WITHOUT ANY WARRANTY; without even the implied warranty of              #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
# GNU General Public License for more details.                                #
#                                                                             #
# You should have received a copy of the GNU General Public License           #
# along with this program.  If not, see <http://www.gnu.org/licenses/>.       #
#                                                                             #
###############################################################################
*/

#include "ws2812-rpi.h"
#include "../pixel/pixel.h"

using namespace as;

int main(int argc, char **argv){
    NeoPixel *n=new NeoPixel(60);
    // PIXEL Pixel(60);
    // Pixel.begin();


unsigned int num;

n->clear();
printf("Cleared\n");
n->setBrightness(0.2);
printf("set Brightness\n");
n->show();

 while ( scanf("%u", &num ) == 1 ) {
         printf("We just read %u\n", num);
//	n->effectsDemo();
	n->clear();
	n->setPixelColor(num,255,0,0);
	n->show();
  // Pixel.setPixel(num, 255, 0, 0);
	printf("set\n");
  }
//
delete n;

   return 0;
}
