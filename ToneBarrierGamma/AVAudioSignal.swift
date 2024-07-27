//
//  AudioSignal.swift
//  ToneBarrier
//
//  Created by James Alan Bush on 4/29/23.
//

import Foundation
import AVFoundation
import AVKit
import SwiftUI
import Combine
import ObjectiveC
import Dispatch
import Accelerate
import GameKit
import Algorithms

var octave:       Float32 = Float32(440.0 * 2.0)
/**
 The lowest frequency (or note) of a tone pair and/or tone-pair dyad. This fundamental frequency is the basis for 'harmonic' and 'octave', and the combination tones.
 */
var root:         Float32 = Float32(octave * 0.5)
var harmonic:     Float32 = Float32(root * (3.0/2.0))

var root_:        Float32 = Float32(root  *  2.0)
var harmonic_:    Float32 = Float32(root_ * (3.0/2.0))
var amplitude:    Float32 = Float32(0.25)
var envelope:     Float32 = Float32(1.0)
let tau:          Double  = Double(Double.pi * 2.0)
let theta:        Float32 = Float32(Float32.pi / 2.0)
let trill:        Float32 = Float32.zero
let tremolo:      Float32 = Float32(1.0)
var split:        Int32   = Int32(2)
var duration:     Int32   = Int32.zero

@objc class AVAudioSignal: NSObject {
    private static let shared = AVAudioSignal()
    let audio_engine: AVAudioEngine = AVAudioEngine()
    
    override init() {
        let main_mixer_node: AVAudioMixerNode = audio_engine.mainMixerNode
        let audio_format: AVAudioFormat       = AVAudioFormat(standardFormatWithSampleRate: audio_engine.mainMixerNode.outputFormat(forBus: Int.zero).sampleRate, channels: audio_engine.mainMixerNode.outputFormat(forBus: Int.zero).channelCount )!
        let buffer_length: Int32              = Int32(audio_format.sampleRate) * Int32(audio_format.channelCount)
        
        func pianoNoteFrequency() -> Float32 {
            let c: Float32 = Float32.random(in: (0.5...1.0))
            let f: Float32 = 440.0 * pow(2.0, (floor(c * 88.0) - 49.0) / 12.0)
            
            return f
        }
    
        let tetradBuffer = TetradBuffer(bufferLength: Int(buffer_length))
        var s = tetradBuffer.generateSignalSamplesIterator()

        func numbers(count: Int) -> [[Float32]] {
            let allNumbers: [[Float32]] = ({ (operation: (Int) -> (() -> [[Float32]])) in
                operation(count)()
            })( { number in
                var channels: [[Float32]] = [Array(repeating: Float32.zero, count: count), Array(repeating: Float32.zero, count: count)]
                //print(#function)
                for i in 0..<number {
                    if let leftSample = s.0.next(), let rightSample = s.1.next() {
                        channels[0][i] = leftSample
                        channels[1][i] = rightSample
                    } else {
//                        tetradBuffer.resetIterator()
                        s = tetradBuffer.generateSignalSamplesIterator()
                        channels[0][i] = Float32(s.0.next()!)
                        channels[1][i] = Float32(s.1.next()!)
                    }
                }
            
                return {
                    channels
                }
            })
            return allNumbers
        }
        
        let audio_source_node: AVAudioSourceNode = AVAudioSourceNode(format: audio_format, renderBlock: { _, _, frameCount, audioBufferList in
            //print(#function)
            let signalSamples    = numbers(count: Int(frameCount))
            let ablPointer       = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let leftChannelData  = ablPointer[0]
            let rightChannelData = ablPointer[1]
            let leftBuffer:  UnsafeMutableBufferPointer<Float32> = UnsafeMutableBufferPointer(leftChannelData)
            let rightBuffer: UnsafeMutableBufferPointer<Float32> = UnsafeMutableBufferPointer(rightChannelData)
            signalSamples.withUnsafeBufferPointer { sourceBuffer in
                ([Float32]([Float32](sourceBuffer[0]))).withUnsafeBufferPointer { leftSourceBuffer in
                    leftBuffer.baseAddress!.initialize(from: leftSourceBuffer.baseAddress!, count: Int(frameCount))
                }
                ([Float32]([Float32](sourceBuffer[1]))).withUnsafeBufferPointer { rightSourceBuffer in
                    rightBuffer.baseAddress!.initialize(from: rightSourceBuffer.baseAddress!, count: Int(frameCount))
                }
            }
            
            return noErr
        })
        
        let reverb: AVAudioUnitReverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(AVAudioUnitReverbPreset.largeChamber)
        reverb.wetDryMix = 50.0
        
        audio_engine.attach(audio_source_node)
        audio_engine.attach(reverb)
        
        audio_engine.connect(audio_source_node, to: reverb, format: audio_format)
        audio_engine.connect(reverb, to: main_mixer_node, format: audio_format)
    }
}
