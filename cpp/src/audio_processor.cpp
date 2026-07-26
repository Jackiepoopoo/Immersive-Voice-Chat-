// Voice Occlusion Audio Processor
// Handles real-time DSP for voice occlusion effects

#include "audio_processor.h"
#include "module.h"
#include <cmath>
#include <cstring>

namespace VoiceOcclusion {

// Static instance
AudioProcessor* AudioProcessor::s_Instance = nullptr;

AudioProcessor::AudioProcessor()
    : m_Enabled(true)
    , m_OcclusionLevel(0.0f)
    , m_Strength(1.0f)
    , m_SampleRate(48000)
    , m_BufferSize(1024)
    , m_PrevSample(0.0f)
{
}

AudioProcessor::~AudioProcessor()
{
}

bool AudioProcessor::Initialize()
{
    if (s_Instance)
    {
        return true;
    }
    
    s_Instance = new AudioProcessor();
    
    VO_PRINT("Audio processor initialized");
    VO_PRINT("Sample rate: %d Hz", s_Instance->m_SampleRate);
    VO_PRINT("Buffer size: %d samples", s_Instance->m_BufferSize);
    
    return true;
}

void AudioProcessor::Shutdown()
{
    if (s_Instance)
    {
        delete s_Instance;
        s_Instance = nullptr;
    }
    
    VO_PRINT("Audio processor shutdown");
}

AudioProcessor* AudioProcessor::GetInstance()
{
    return s_Instance;
}

void AudioProcessor::SetOcclusionLevel(float level)
{
    m_OcclusionLevel = Clamp(level, 0.0f, 1.0f);
}

void AudioProcessor::SetEnabled(bool enabled)
{
    m_Enabled = enabled;
}

void AudioProcessor::SetStrength(float strength)
{
    m_Strength = Clamp(strength, 0.0f, 1.0f);
}

void AudioProcessor::SetSampleRate(int sampleRate)
{
    m_SampleRate = sampleRate;
}

void AudioProcessor::SetBufferSize(int bufferSize)
{
    m_BufferSize = bufferSize;
}

float AudioProcessor::GetOcclusionLevel() const
{
    return m_OcclusionLevel;
}

bool AudioProcessor::IsEnabled() const
{
    return m_Enabled;
}

float AudioProcessor::GetStrength() const
{
    return m_Strength;
}

void AudioProcessor::ProcessBuffer(float* buffer, int numSamples, int numChannels)
{
    if (!m_Enabled || m_OcclusionLevel <= 0.0f)
    {
        return;
    }
    
    // Calculate effective occlusion with strength modifier
    float effectiveOcclusion = m_OcclusionLevel * m_Strength;
    
    // Calculate cutoff frequency based on occlusion
    // Clear: 2000 Hz, Fully occluded: 200 Hz
    float cutoffFreq = 2000.0f - (effectiveOcclusion * 1800.0f);
    
    // Apply low-pass filter to each channel
    for (int ch = 0; ch < numChannels; ch++)
    {
        ApplyLowPassFilter(buffer + ch, numSamples, numChannels, cutoffFreq);
    }
}

void AudioProcessor::ApplyLowPassFilter(float* buffer, int numSamples, int numChannels, float cutoffFreq)
{
    // Simple first-order low-pass filter (RC filter)
    // H(z) = (1 - alpha) / (1 - alpha * z^-1)
    
    float rc = 1.0f / (2.0f * M_PI * cutoffFreq);
    float dt = 1.0f / m_SampleRate;
    float alpha = dt / (rc + dt);
    
    // Process samples
    float prevSample = m_PrevSample;
    
    for (int i = 0; i < numSamples; i++)
    {
        int idx = i * numChannels;
        float sample = buffer[idx];
        
        // Apply filter
        float filtered = prevSample + alpha * (sample - prevSample);
        buffer[idx] = filtered;
        
        prevSample = filtered;
    }
    
    m_PrevSample = prevSample;
}

float AudioProcessor::Clamp(float value, float min, float max)
{
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

// Alternative: Apply simple volume reduction based on occlusion
void AudioProcessor::ApplyVolumeReduction(float* buffer, int numSamples, int numChannels)
{
    if (!m_Enabled || m_OcclusionLevel <= 0.0f)
    {
        return;
    }
    
    float effectiveOcclusion = m_OcclusionLevel * m_Strength;
    float volume = 1.0f - (effectiveOcclusion * 0.85f); // Reduce by up to 85%
    
    for (int i = 0; i < numSamples * numChannels; i++)
    {
        buffer[i] *= volume;
    }
}

// Muffled effect: combination of low-pass filter and volume reduction
void AudioProcessor::ApplyMuffledEffect(float* buffer, int numSamples, int numChannels)
{
    if (!m_Enabled || m_OcclusionLevel <= 0.0f)
    {
        return;
    }
    
    // Apply volume reduction first
    ApplyVolumeReduction(buffer, numSamples, numChannels);
    
    // Then apply low-pass filter
    float effectiveOcclusion = m_OcclusionLevel * m_Strength;
    float cutoffFreq = 1500.0f - (effectiveOcclusion * 1300.0f);
    
    for (int ch = 0; ch < numChannels; ch++)
    {
        ApplyLowPassFilter(buffer + ch, numSamples, numChannels, cutoffFreq);
    }
}

} // namespace VoiceOcclusion
