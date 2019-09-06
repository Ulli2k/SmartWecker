

#include "globals.h"
#include "lib/messages/messages.h"
#include "lib/clock/clock.h"
#include "lib/touch/touch.h"
#include "lib/pixel/pixel.h"

namespace as {
  MESSAGES Msg(1,0); //1sec delay per loop
  CLOCK Clock;
  TOUCH Touch;
  PIXEL Pixel(59);

  void TouchInterrupt(void) {
     Touch.poll();
  }
};
