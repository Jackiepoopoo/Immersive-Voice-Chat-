// Immersive Voice Chat Audio Processor Header
// Real-time DSP for voice occlusion effects

#ifndef IMMERSIVE_VOICE_CHAT_AUDIO_PROCESSOR_H
#define IMMERSIVE_VOICE_CHAT_AUDIO_PROCESSOR_H

#define _USE_MATH_DEFINES
#include <cmath>

namespace ImmersiveVoiceChat {

class AudioProcessor
{
public:
    ~AudioProcessor();
    
    // Singleton access
    static bool Initialize();
    static void Shutdown();
    static AudioProcessor* GetInstance();
    
    // Configuration
    void SetOcclusionLevel(float level);    // 0.0 = clear, 1.0 = fully occluded
    void SetEnabled(bool enabled);
    void SetStrength(float strength);       // 0.0 = no effect, 1.0 = full effect
    void SetSampleRate(int sampleRate);
    void SetBufferSize(int bufferSize);
    
    // Getters
    float GetOcclusionLevel() const;
    bool IsEnabled() const;
    float GetStrength() const;
    
    // Audio processing
    void ProcessBuffer(float* buffer, int numSamples, int numChannels);
    void ApplyVolumeReduction(float* buffer, int numSamples, int numChannels);
    void ApplyMuffledEffect(float* buffer, int numSamples, int numChannels);
    
private:
    AudioProcessor();
    
    // Low-pass filter implementation
    void ApplyLowPassFilter(float* buffer, int numSamples, int numChannels, float cutoffFreq);
    
    // Utility
    float Clamp(float value, float min, float max);
    
    // State
    static AudioProcessor* s_Instance;
    
    bool m_Enabled;
    float m_OcclusionLevel;
    float m_Strength;
    int m_SampleRate;
    int m_BufferSize;
    
    // Filter state
    float m_PrevSample;
};

} // namespace ImmersiveVoiceChat

#endif // IMMERSIVE_VOICE_CHAT_AUDIO_PROCESSOR_H
