#define NPU_CONTROL     (*(volatile unsigned int *)0x00060000)
#define NPU_STATUS      (*(volatile unsigned int *)0x00060004)
#define NPU_INPUT0      (*(volatile unsigned int *)0x00060008)
#define NPU_WEIGHT_ADDR (*(volatile unsigned int *)0x00060010)
#define NPU_WEIGHT_DATA (*(volatile unsigned int *)0x00060014)
#define NPU_ACCUM0      (*(volatile int *)0x00060020)
#define NPU_ACCUM1      (*(volatile int *)0x00060024)
#define NPU_ACCUM2      (*(volatile int *)0x00060028)
#define NPU_ACCUM3      (*(volatile int *)0x0006002C)
#define LEDS            (*(volatile unsigned int *)0x00040000)

int main(void) {
    NPU_INPUT0 = 0xFC03FE01;
    NPU_WEIGHT_ADDR = 0;
    NPU_WEIGHT_DATA = 0x04030201;
    NPU_WEIGHT_DATA = 0x02FD00FF;
    NPU_WEIGHT_DATA = 0xFF01807F;
    NPU_WEIGHT_DATA = 0xFB05FA08;

    NPU_CONTROL = 1;
    while ((NPU_STATUS & 2) == 0) {
    }

    if ((NPU_ACCUM0 == -10) && (NPU_ACCUM1 == -18) &&
        (NPU_ACCUM2 == 390) && (NPU_ACCUM3 == 55)) {
        LEDS = 0x3FF;
    } else {
        LEDS = 0;
    }

    while (1) {
    }
}
