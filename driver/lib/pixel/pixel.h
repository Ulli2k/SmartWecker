
#include "../WS2811/ws2812-rpi.h"

namespace as {

  class PIXEL {

    NeoPixel pixel;

  public:
    PIXEL(uint16_t count=60) : pixel(count) { }

    void begin() {
      pixel.clear();
      setBrightness(0.1);
      pixel.show();
    }

    void setPixelRange(uint8_t start, uint8_t end, uint8_t R, uint8_t G, uint8_t B) {
      for(uint8_t i=start;i<=end;i++) {
        pixel.setPixelColor(i,R,G,B);
      }
    	pixel.show();
    }
    void setPixel( uint8_t pos, uint8_t R, uint8_t G, uint8_t B) {
    	pixel.setPixelColor(pos,R,G,B);
    	pixel.show();
    }

    void setClearRange(uint8_t start, uint8_t end) {
      for(uint8_t i=start;i<=end;i++) {
        pixel.clearLEDBuffer(i);
      }
      pixel.show();
    }

    void setClear() {
      pixel.clear();
      pixel.show();
    }

    void setClear(unsigned int i) {
      pixel.clearLEDBuffer(i);
      pixel.show();
    }

    void setBrightness(float value) {
      pixel.setBrightness(value);
      pixel.show();
    }

  };
  extern PIXEL Pixel;
};
