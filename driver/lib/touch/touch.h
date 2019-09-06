
#ifndef _MY_TOUCH_HEADER_
#define _MY_TOUCH_HEADER_

#include "../../globals.h"
#include "../MPR121/MPR121.h"

#define MPR121_IRQ_PIN		11// --> 11 -> Pin26
#define numElectrodes 		12

namespace as {

  extern void TouchInterrupt(void);

  class TOUCH {

    uint8_t i2c_addr;
    uint8_t IRQ;

  public:
    TOUCH(uint8_t irq=MPR121_IRQ_PIN, uint8_t addr = 0x5A) : i2c_addr(addr), IRQ(irq) { }

    void begin() {
    	if(!MPR121.begin(i2c_addr)){
    		printf("error setting up MPR121");
        switch(MPR121.getError()) {
          case NO_ERROR:
            printf("no error");
            break;
          case ADDRESS_UNKNOWN:
            printf("incorrect address");
            break;
          case READBACK_FAIL:
            printf("readback failure");
            break;
          case OVERCURRENT_FLAG:
            printf("overcurrent on REXT pin");
            break;
          case OUT_OF_RANGE:
            printf("electrode out of range");
            break;
          case NOT_INITED:
            printf("not initialised");
            break;
          default:
            printf("unknown error");
            break;
          }
    		}
        // pin 4 is the MPR121 interrupt on the Bare Touch Board
        MPR121.setInterruptPin(IRQ);
        //export GPIO Pin for Interrupt
        char buf[40];
        sprintf(buf,"echo \"%d\" > /sys/class/gpio/export",IRQ);
        system(buf);
        if ( wiringPiISR (IRQ, INT_EDGE_BOTH, &TouchInterrupt) < 0 ) {
            printf ("Unable to setup ISR: %s\n", strerror (errno));
        }

    		// this is the touch threshold - setting it low makes it more like a proximity trigger
    		// default value is 40 for touch
    		MPR121.setTouchThreshold(40);
    		// this is the release threshold - must ALWAYS be smaller than the touch threshold
    		// default value is 20 for touch
    		MPR121.setReleaseThreshold(20);
    		// initial data update
    		MPR121.updateTouchData();
        printf("Touch initialized %d %d.\n",i2c_addr,IRQ);
    }

    void poll() {
      char buf[MAX_MESSAGE_LENGTH];
      buf[0] = 0x0;

    	if(MPR121.touchStatusChanged()) {
    		 MPR121.updateTouchData();
    		 for(uint8_t i=0; i<numElectrodes; i++){
    			 if(MPR121.isNewTouch(i)){
               sprintf(buf,"%02dN%02d%d\r",DEVICE_ID,i,1);
    			 } else if(MPR121.isNewRelease(i)){
               sprintf(buf,"%02dN%02d%d\r",DEVICE_ID,i,0);
    			 }
           if(buf[0]) {
              printf(buf);printf("\r\n");
              Msg.sendMessage(buf,strlen(buf)); //01N011
              buf[0] = 0x0;
           }
    		 }
     }
    }

  };
  extern TOUCH Touch;
}
#endif
