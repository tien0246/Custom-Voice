#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import "fishhook/fishhook.h"
#import "SoundTouch.h"
#import "Settings/SettingsView.mm"

#define pitchKey @"pitchKey"
#define tempoKey @"tempoKey"
#define rateKey  @"rateKey"

soundtouch::SoundTouch *soundTouchPtr = NULL;
static OSStatus (*orig_AudioUnitRender)(
    AudioUnit,
    AudioUnitRenderActionFlags*,
    const AudioTimeStamp*,
    UInt32,
    UInt32,
    AudioBufferList*
);

static OSStatus hooked_AudioUnitRender(
    AudioUnit inUnit,
    AudioUnitRenderActionFlags* ioActionFlags,
    const AudioTimeStamp* inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList* ioData
) {
    OSStatus status = orig_AudioUnitRender(inUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
    if (status != noErr) return status;
    
    AudioStreamBasicDescription asbd;
    UInt32 asbdSize = sizeof(asbd);
    OSStatus fmtStatus = AudioUnitGetProperty(inUnit,
                                              kAudioUnitProperty_StreamFormat,
                                              kAudioUnitScope_Output,
                                              inBusNumber,
                                              &asbd,
                                              &asbdSize);
    if (fmtStatus == noErr) {
        NSLog(@"Bus %u Format: sr=%.2f, fmtID=%u, ch=%u, bits=%u, flags=0x%X",
              (unsigned)inBusNumber,
              asbd.mSampleRate,
              (unsigned)asbd.mFormatID,
              (unsigned)asbd.mChannelsPerFrame,
              (unsigned)asbd.mBitsPerChannel,
              (unsigned)asbd.mFormatFlags);
    }
    
    if (!soundTouchPtr) {
        NSLog(@"SoundTouch not initialized.");
        return status;
    }
    
    if (fmtStatus == noErr && asbd.mFormatID == kAudioFormatLinearPCM) {        
        soundTouchPtr->setSampleRate(asbd.mSampleRate);
        soundTouchPtr->setChannels(asbd.mChannelsPerFrame);
        
        if (ioData && ioData->mNumberBuffers > 0) {
            for (UInt32 b = 0; b < ioData->mNumberBuffers; b++) {
                AudioBuffer buffer = ioData->mBuffers[b];
                if (!buffer.mData || buffer.mDataByteSize == 0) continue;
                
                UInt32 numSamples = buffer.mDataByteSize / (asbd.mBitsPerChannel / 8);
                float *inBuffer = (float *)malloc(numSamples * sizeof(float));
                float *outBuffer = (float *)malloc(numSamples * sizeof(float));
                if (!inBuffer || !outBuffer) { free(inBuffer); free(outBuffer); continue; }
                
                if ((asbd.mFormatFlags & kAudioFormatFlagIsFloat) && asbd.mBitsPerChannel == 32) {
                    memcpy(inBuffer, buffer.mData, numSamples * sizeof(float));
                } else if (!(asbd.mFormatFlags & kAudioFormatFlagIsFloat) && asbd.mBitsPerChannel == 16) {
                    SInt16* intSamples = (SInt16*)buffer.mData;
                    for (UInt32 i = 0; i < numSamples; ++i) {
                        inBuffer[i] = intSamples[i] / 32768.0f;
                    }
                } else {
                    free(inBuffer); free(outBuffer);
                    continue;
                }
                
                soundTouchPtr->putSamples(inBuffer, numSamples);
                uint totalReceived = 0;
                uint received = 0;
                while (totalReceived < numSamples) {
                    received = soundTouchPtr->receiveSamples(outBuffer + totalReceived, numSamples - totalReceived);
                    if (received == 0) break;
                    totalReceived += received;
                }
                
                if ((asbd.mFormatFlags & kAudioFormatFlagIsFloat) && asbd.mBitsPerChannel == 32) {
                    memcpy(buffer.mData, outBuffer, totalReceived * sizeof(float));
                } else if (!(asbd.mFormatFlags & kAudioFormatFlagIsFloat) && asbd.mBitsPerChannel == 16) {
                    SInt16* intSamples = (SInt16*)buffer.mData;
                    for (UInt32 i = 0; i < totalReceived; ++i) {
                        float processed = outBuffer[i];
                        if (processed > 1.0f) processed = 1.0f;
                        else if (processed < -1.0f) processed = -1.0f;
                        intSamples[i] = (SInt16)(processed * 32767.0f);
                    }
                    for (UInt32 i = totalReceived; i < numSamples; ++i) {
                        intSamples[i] = 0;
                    }
                }
                
                // NSLog(@"Processed %u samples on bus %u", totalReceived, (unsigned)inBusNumber);
                
                free(inBuffer);
                free(outBuffer);
            }
        }
    }
    
    return status;
}

__attribute__((constructor))
static void initialize_hooks() {
    NSLog(@"Loaded");
    
    soundTouchPtr = new soundtouch::SoundTouch();
    if (soundTouchPtr) {
        float initPitch = [[NSUserDefaults standardUserDefaults] floatForKey:pitchKey] ?: 1.0f;
        float initTempo = [[NSUserDefaults standardUserDefaults] floatForKey:tempoKey] ?: 1.0f;
        float initRate  = [[NSUserDefaults standardUserDefaults] floatForKey:rateKey]  ?: 1.0f;
        
        soundTouchPtr->setPitch(initPitch);
        soundTouchPtr->setTempo(initTempo);
        soundTouchPtr->setRate(initRate);
        
        NSLog(@"Initialized SoundTouch with Pitch: %.2f, Tempo: %.2f, Rate: %.2f", initPitch, initTempo, initRate);
    } else {
        NSLog(@"Failed to initialize SoundTouch");
    }
    
    struct rebinding bindings[] = {
        {"AudioUnitRender", (void *)hooked_AudioUnitRender, (void **)&orig_AudioUnitRender}
    };
    rebind_symbols(bindings, 1);
}