#define SENSOR_X     (*(volatile int*)0x00020000)
#define BUTTONS      (*(volatile unsigned int*)0x00000004)
#define HEX_DISPLAYS (*(volatile int*)0x00030000)
#define LEDS         (*(volatile unsigned int*)0x00040000)
#define VIDEO_PLAYER_X      (*(volatile unsigned int*)0x00050000)
#define VIDEO_ASTEROID_X    (*(volatile unsigned int*)0x00050004)
#define VIDEO_ASTEROID_Y    (*(volatile unsigned int*)0x00050008)
#define VIDEO_ASTEROID_DEPTH (*(volatile unsigned int*)0x0005000C)

static void delay(void) {
    volatile unsigned int count;
    for (count = 0; count < 20000; count = count + 1) {
    }
}

int main() {
    unsigned int player_x = 320;
    unsigned int asteroid_x = 320;
    unsigned int asteroid_y = 180;
    unsigned int asteroid_depth = 220;

    while (1) {
        int tilt_value = SENSOR_X;
        int magnitude = (tilt_value < 0) ? -tilt_value : tilt_value;
        int level = magnitude >> 5;

        if (level > 9) {
            level = 9;
        }

        if (tilt_value < 0) {
            HEX_DISPLAYS = (level << 8) | (level << 4) | level;
        } else {
            HEX_DISPLAYS = (level << 20) | (level << 16) | (level << 12);
        }

        if (tilt_value < -128 && player_x > 10)
            player_x = player_x - 4;
        else if (tilt_value > 128 && player_x < 630)
            player_x = player_x + 4;

        if (BUTTONS & 1) {
            asteroid_x = player_x;
            asteroid_y = 180;
            asteroid_depth = 240;
        } else if (asteroid_depth > 4) {
            asteroid_depth = asteroid_depth - 4;
        } else {
            asteroid_depth = 240;
            asteroid_x = (asteroid_x + 73) & 0x3ff;
            if (asteroid_x > 600)
                asteroid_x = 80;
        }

        VIDEO_PLAYER_X = player_x;
        VIDEO_ASTEROID_X = asteroid_x;
        VIDEO_ASTEROID_Y = asteroid_y;
        VIDEO_ASTEROID_DEPTH = asteroid_depth;
        LEDS = (BUTTONS & 1) ? 0x3FFu : 0x000u;
        delay();
    }
}