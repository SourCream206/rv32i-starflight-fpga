#define NPU_CONTROL     (*(volatile unsigned int *)0x00060000)
#define NPU_STATUS      (*(volatile unsigned int *)0x00060004)
#define NPU_INPUT_ADDR  (*(volatile unsigned int *)0x00060008)
#define NPU_INPUT_DATA  (*(volatile unsigned int *)0x0006000C)
#define NPU_WEIGHT_ADDR (*(volatile unsigned int *)0x00060010)
#define NPU_WEIGHT_DATA (*(volatile unsigned int *)0x00060014)
#define NPU_BIAS_ADDR   (*(volatile unsigned int *)0x00060018)
#define NPU_BIAS_DATA   (*(volatile unsigned int *)0x0006001C)
#define NPU_SCALE       (*(volatile unsigned int *)0x00060020)
#define NPU_OUTPUT_ADDR (*(volatile unsigned int *)0x00060024)
#define NPU_OUTPUT_DATA (*(volatile unsigned int *)0x00060028)
#define NPU_SOFTMAX_DATA (*(volatile unsigned int *)0x0006002C)
#define LEDS            (*(volatile unsigned int *)0x00040000)

int main(void) {
    unsigned int word;

    NPU_INPUT_ADDR = 0;
    for (word = 0; word < 4; word = word + 1)
        NPU_INPUT_DATA = 0x01010101;

    NPU_WEIGHT_ADDR = 0;
    for (word = 0; word < 64; word = word + 1) {
        unsigned int packed_weights = 0;
        switch (word & 15u) {
        case 0:
            packed_weights = 0x00000001;
            break;
        case 4:
            packed_weights = 0x00000100;
            break;
        case 8:
            packed_weights = 0x00010000;
            break;
        case 12:
            packed_weights = 0x01000000;
            break;
        default:
            break;
        }
        NPU_WEIGHT_DATA = packed_weights;
    }

    NPU_BIAS_ADDR = 0;
    for (word = 0; word < 4; word = word + 1)
        NPU_BIAS_DATA = 0;
    NPU_SCALE = 0;
    NPU_CONTROL = 9;
    while ((NPU_STATUS & 2) == 0) {
    }

    NPU_OUTPUT_ADDR = 0;
    if ((NPU_OUTPUT_DATA == 0x01010101) && (NPU_SOFTMAX_DATA == 4095)) {
        LEDS = 0x3FF;
    } else {
        LEDS = 0;
    }

    while (1) {
    }
}
