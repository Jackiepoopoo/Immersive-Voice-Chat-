#ifndef IMMERSIVE_VOICE_CHAT_LOW_PASS_FILTER_H
#define IMMERSIVE_VOICE_CHAT_LOW_PASS_FILTER_H

#include <cmath>
#include <cstring>

#define _USE_MATH_DEFINES

static const int MAX_CHANNELS = 8;
static const int FILTER_ORDER = 4;

class LowPassFilter {
public:
    LowPassFilter() {
        Reset();
    }

    void Reset() {
        memset(m_prev, 0, sizeof(m_prev));
    }

    void SetCutoff(float cutoffHz, float sampleRate) {
        float rc = 1.0f / (2.0f * 3.14159265f * cutoffHz);
        float dt = 1.0f / sampleRate;
        m_alpha = dt / (rc + dt);
    }

    void ProcessBuffer(float* buffer, uint32_t sampleCount, uint16_t channelCount) {
        if (channelCount > MAX_CHANNELS) channelCount = MAX_CHANNELS;

        for (uint32_t i = 0; i < sampleCount; i++) {
            for (uint16_t ch = 0; ch < channelCount; ch++) {
                uint32_t idx = i * channelCount + ch;
                float s = buffer[idx];
                for (int pass = 0; pass < FILTER_ORDER; pass++) {
                    m_prev[ch][pass] = m_prev[ch][pass] + m_alpha * (s - m_prev[ch][pass]);
                    if (fabsf(m_prev[ch][pass]) < 1.0e-18f) m_prev[ch][pass] = 0.0f;
                    s = m_prev[ch][pass];
                }
                buffer[idx] = s;
            }
        }
    }

private:
    float m_alpha;
    float m_prev[MAX_CHANNELS][FILTER_ORDER];
};

#endif
