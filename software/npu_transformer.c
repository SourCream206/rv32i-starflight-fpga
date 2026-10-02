#include <stdint.h>

#include "model_weights.h"
#include "quantization_config.h"

#define NPU_CONTROL      (*(volatile uint32_t *)0x00060000)
#define NPU_STATUS       (*(volatile uint32_t *)0x00060004)
#define NPU_INPUT_ADDR   (*(volatile uint32_t *)0x00060008)
#define NPU_INPUT_DATA   (*(volatile uint32_t *)0x0006000C)
#define NPU_WEIGHT_ADDR  (*(volatile uint32_t *)0x00060010)
#define NPU_WEIGHT_DATA  (*(volatile uint32_t *)0x00060014)
#define NPU_BIAS_ADDR    (*(volatile uint32_t *)0x00060018)
#define NPU_BIAS_DATA    (*(volatile uint32_t *)0x0006001C)
#define NPU_SCALE        (*(volatile uint32_t *)0x00060020)
#define NPU_OUTPUT_ADDR  (*(volatile uint32_t *)0x00060024)
#define NPU_OUTPUT_DATA  (*(volatile uint32_t *)0x00060028)
#define NPU_SOFTMAX_DATA (*(volatile uint32_t *)0x0006002C)
#define NPU_SHIFT_REG    (*(volatile int32_t *)0x00060030)
#define LED_REG          (*(volatile uint32_t *)0x00040000)

#define NPU_START 1u
#define NPU_GELU 4u
#define NPU_SOFTMAX 8u

static int8_t saturate_int8(int32_t value) {
    if (value > 127)
        return 127;
    if (value < -128)
        return -128;
    return (int8_t)value;
}

static int32_t multiply_int32(int32_t left, int32_t right) {
    uint32_t magnitude_left;
    uint32_t magnitude_right;
    uint32_t product = 0;
    int negative = (left < 0) != (right < 0);

    magnitude_left = (left < 0) ? (uint32_t)(-left) : (uint32_t)left;
    magnitude_right = (right < 0) ? (uint32_t)(-right) : (uint32_t)right;
    while (magnitude_right != 0) {
        if (magnitude_right & 1u)
            product += magnitude_left;
        magnitude_left <<= 1;
        magnitude_right >>= 1;
    }
    return negative ? -(int32_t)product : (int32_t)product;
}

static uint32_t pack_int8x4(const int8_t *values) {
    return (uint32_t)(uint8_t)values[0] |
           ((uint32_t)(uint8_t)values[1] << 8) |
           ((uint32_t)(uint8_t)values[2] << 16) |
           ((uint32_t)(uint8_t)values[3] << 24);
}

static void load_vector(const int8_t *values) {
    uint32_t word;

    NPU_INPUT_ADDR = 0;
    for (word = 0; word < 4; word++)
        NPU_INPUT_DATA = pack_int8x4(values + (word << 2));
}

static void load_weights(const int8_t *weights) {
    uint32_t word;

    NPU_WEIGHT_ADDR = 0;
    for (word = 0; word < 64; word++)
        NPU_WEIGHT_DATA = pack_int8x4(weights + (word << 2));
}

static void load_biases(const int8_t *biases) {
    uint32_t word;

    NPU_BIAS_ADDR = 0;
    for (word = 0; word < 4; word++)
        NPU_BIAS_DATA = pack_int8x4(biases + (word << 2));
}

static void read_vector(int8_t *values) {
    uint32_t word;

    NPU_OUTPUT_ADDR = 0;
    for (word = 0; word < 4; word++) {
        uint32_t packed = NPU_OUTPUT_DATA;
        values[(word << 2)] = (int8_t)packed;
        values[(word << 2) + 1] = (int8_t)(packed >> 8);
        values[(word << 2) + 2] = (int8_t)(packed >> 16);
        values[(word << 2) + 3] = (int8_t)(packed >> 24);
        NPU_OUTPUT_ADDR += 4;
    }
}

static void run_projection(
    const int8_t *input,
    const int8_t *weights,
    const int8_t *biases,
    int32_t signed_shift,
    uint32_t control,
    int8_t *output
) {
    load_vector(input);
    load_weights(weights);
    load_biases(biases);
    NPU_SCALE = 0;
    NPU_SHIFT_REG = signed_shift;
    NPU_CONTROL = NPU_START | control;
    while ((NPU_STATUS & 2u) == 0) {
    }
    read_vector(output);
}

static void load_identity_matrix(void) {
    uint32_t word;

    NPU_WEIGHT_ADDR = 0;
    for (word = 0; word < 64; word++) {
        uint32_t packed = 0;
        switch (word & 15u) {
        case 0: packed = 0x00000001u; break;
        case 4: packed = 0x00000100u; break;
        case 8: packed = 0x00010000u; break;
        case 12: packed = 0x01000000u; break;
        default: break;
        }
        NPU_WEIGHT_DATA = packed;
    }
}

static void run_softmax(const int8_t *scores, uint16_t *probabilities) {
    static const int8_t zero_bias[NPU_D_MODEL] = {0};
    uint32_t index;

    load_vector(scores);
    load_identity_matrix();
    load_biases(zero_bias);
    NPU_SCALE = 0;
    NPU_SHIFT_REG = 0;
    NPU_CONTROL = NPU_START | NPU_SOFTMAX;
    while ((NPU_STATUS & 2u) == 0) {
    }
    for (index = 0; index < NPU_CONTEXT_LENGTH; index++) {
        NPU_OUTPUT_ADDR = index;
        probabilities[index] = (uint16_t)NPU_SOFTMAX_DATA;
    }
}

static void project_ffn1(const int8_t *input, int8_t *output) {
    run_projection(input, MODEL_W_FF1, MODEL_B_FF1, NPU_SHIFT_FF1, NPU_GELU, output);
    run_projection(
        input, MODEL_W_FF1 + 256, MODEL_B_FF1 + 16, NPU_SHIFT_FF1, NPU_GELU, output + 16
    );
}

static void project_vocab(const int8_t *input, int8_t *logits) {
    uint32_t tile;

    for (tile = 0; tile < 4; tile++) {
        run_projection(
            input, MODEL_W_VOCAB + (tile << 8), MODEL_B_VOCAB + (tile << 4),
            NPU_SHIFT_VOCAB, 0, logits + (tile << 4)
        );
    }
}

static int8_t token_embedding(uint32_t token, uint32_t lane, uint32_t position) {
    return saturate_int8(
        (int32_t)MODEL_TOKEN_EMBEDDING[(token << 4) + lane] +
        MODEL_POSITION_EMBEDDING[(position << 4) + lane]
    );
}

static uint32_t predict_next_token(const int8_t *context) {
    int8_t hidden[NPU_D_MODEL];
    int8_t query[NPU_CONTEXT_LENGTH][NPU_D_MODEL];
    int8_t key[NPU_CONTEXT_LENGTH][NPU_D_MODEL];
    int8_t value[NPU_CONTEXT_LENGTH][NPU_D_MODEL];
    int8_t scores[NPU_CONTEXT_LENGTH];
    uint16_t probabilities[NPU_CONTEXT_LENGTH];
    int8_t attention_value[NPU_D_MODEL];
    int8_t projected[NPU_D_MODEL];
    int8_t ffn_hidden[NPU_D_FF];
    int8_t logits[NPU_VOCAB_SIZE];
    uint32_t token_index;
    uint32_t lane;
    uint32_t best = 0;

    for (token_index = 0; token_index < NPU_CONTEXT_LENGTH; token_index++) {
        for (lane = 0; lane < NPU_D_MODEL; lane++)
            hidden[lane] = token_embedding((uint8_t)context[token_index], lane, token_index);
        run_projection(hidden, MODEL_W_Q, MODEL_B_Q, NPU_SHIFT_Q, 0, query[token_index]);
        run_projection(hidden, MODEL_W_K, MODEL_B_K, NPU_SHIFT_K, 0, key[token_index]);
        run_projection(hidden, MODEL_W_V, MODEL_B_V, NPU_SHIFT_V, 0, value[token_index]);
    }

    for (token_index = 0; token_index < NPU_CONTEXT_LENGTH; token_index++) {
        int32_t dot = 0;
        for (lane = 0; lane < NPU_D_MODEL; lane++)
            dot += multiply_int32(query[NPU_CONTEXT_LENGTH - 1][lane], key[token_index][lane]);
        scores[token_index] = saturate_int8(dot >> NPU_ATTENTION_DK_SHIFT);
    }
    run_softmax(scores, probabilities);

    for (lane = 0; lane < NPU_D_MODEL; lane++) {
        int32_t sum = 0;
        for (token_index = 0; token_index < NPU_CONTEXT_LENGTH; token_index++)
            sum += multiply_int32((int32_t)probabilities[token_index], value[token_index][lane]);
        attention_value[lane] = saturate_int8(sum >> 16);
    }

    run_projection(attention_value, MODEL_W_O, MODEL_B_O, NPU_SHIFT_O, 0, projected);
    for (lane = 0; lane < NPU_D_MODEL; lane++)
        hidden[lane] = saturate_int8((int32_t)hidden[lane] + projected[lane]);

    project_ffn1(hidden, ffn_hidden);
    run_projection(ffn_hidden, MODEL_W_FF2, MODEL_B_FF2, NPU_SHIFT_FF2, 0, projected);
    for (lane = 0; lane < NPU_D_MODEL; lane++)
        hidden[lane] = saturate_int8((int32_t)hidden[lane] + projected[lane]);

    project_vocab(hidden, logits);
    for (token_index = 1; token_index < NPU_VOCAB_SIZE; token_index++)
        if (logits[token_index] > logits[best])
            best = token_index;
    return best;
}

int main(void) {
    static const uint8_t prompt[] = "THOU ";
    int8_t context[NPU_CONTEXT_LENGTH];
    uint32_t index;
    uint32_t next_token;

    for (index = 0; index < NPU_CONTEXT_LENGTH; index++)
        context[index] = 0;
    for (index = 0; index < sizeof(prompt) - 1; index++)
        context[index] = (int8_t)(prompt[index] - 0x20u);

    while (1) {
        next_token = predict_next_token(context);
        LED_REG = next_token;
        for (index = 0; index < NPU_CONTEXT_LENGTH - 1; index++)
            context[index] = context[index + 1];
        context[NPU_CONTEXT_LENGTH - 1] = (int8_t)next_token;
    }
}
