
#ifndef _MY_CLOCK_HEADER_
#define _MY_CLOCK_HEADER_

#include <time.h>
#include "../TM1637/TM1637.h"

namespace as {

  class CLOCK {

    uint8_t CLK;
    uint8_t DIO;
    uint8_t oldHour;
    uint8_t oldMin;
    uint8_t oldSec;
    bool points[4];
    bool clockActive;

  public:
    CLOCK(uint8_t clk=29, uint8_t dio=28) {
      points[0] = points[1] = points[2] = points[3] = false;
      clockActive = true,
      oldHour = oldMin = 0;
      CLK = clk;
      DIO = dio;
    }

    void begin() {
      if(wiringPiSetup()==-1) {
         printf("setup wiringPi failed!\n");
    	 return;
      }

      pinMode(CLK,INPUT);
      pinMode(DIO,INPUT);
      delay(200);
      TM1637_init(CLK,DIO);
      setBrightness(BRIGHT_TYPICAL);
      TM1637_point(POINT_OFF);
      TM1637_clearDisplay();
    }

    void clearClock() {
      activateClock(false);
    }

    void activateClock(bool on) {
      clockActive=on;
      if(!on) { TM1637_clearDisplay(); return; }
      oldHour = oldMin = 0;
      clockPoll();
    }

    void setBrightness(uint8_t value) { // 0...7
      TM1637_set((value>7 ? 7 : value),0x40,0xc0);//BRIGHT_TYPICAL = 2,BRIGHT_DARKEST = 0,BRIGHTEST = 7;
    }

    void setPoint(uint8_t pos, bool on) {
      points[pos] = on;
    }

    void poll() {
      if(clockActive)
        clockPoll();
    }

    void setValues(uint8_t Nr0, bool P0, uint8_t Nr1, bool P1, uint8_t Nr2, bool P2, uint8_t Nr3, bool P3) {
      TM1637_point(P0);
      TM1637_display(0,Nr0);
      TM1637_point(P1);
      TM1637_display(1,Nr1);
      TM1637_point(P2);
      TM1637_display(2,Nr2);
      TM1637_point(P3);
      TM1637_display(3,Nr3);
    }

  private:
    void setPointOnOff(uint8_t pos) {
      TM1637_point((points[pos]) ? POINT_ON : POINT_OFF);
    }

    void clockPoll() {
      struct tm *info;
      time_t rawtime;
      time(&rawtime);
      info = localtime(&rawtime);
      uint8_t hour = info->tm_hour;
      uint8_t min = info->tm_min;
      uint8_t sec = info->tm_sec;

      /* hours */
      if(hour!=oldHour) {
        setPointOnOff(0);
        TM1637_display(0,(hour < 10) ? 0x7f : hour/10);
      }

      if(hour!=oldHour || oldSec != sec) {
        setPoint(1,(sec & 0x01));
        setPointOnOff(1);
        TM1637_display(1,hour%10);
      }

      /* minutes */
      if(min != oldMin) {
        setPointOnOff(2);
        TM1637_display(2,min/10);
        setPointOnOff(3);
        TM1637_display(3,min%10);
      }
      TM1637_point(POINT_OFF);
      oldHour = hour;
      oldMin = min;
      oldSec = sec;
    }
  };
  extern CLOCK Clock;
}
#endif
