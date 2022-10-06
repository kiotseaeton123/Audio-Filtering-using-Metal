//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

//winnie houng
//blake miller
//jadon strong

import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    // thse properties are for interfaceing with the API
    // the user can access these arrays at any time and plot them if they like
    var timeData:[Float]
    var fftData:[Float]
//    var equalizedArray:[Float] = Array(repeating: 0.0, count: 20)
    var maxIndices:[Int]
    
    
    private let USE_C_SINE = false

    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        maxIndices = Array.init(repeating: 0, count: 2)
    }
    
    @objc
    private lazy var fileReader:AudioFileReader? = {
        if let url=Bundle.main.url(forResource: "satisfaction", withExtension: "mp3"){
            var tmpFileReader:AudioFileReader? = AudioFileReader.init(audioFileURL: url, samplingRate: Float(audioManager!.samplingRate), numChannels: audioManager!.numOutputChannels)
            
            tmpFileReader!.currentTime = 0.0
            print("audio file succesfully loaded for \(url)")
            return tmpFileReader
        }else{
            print("could not initialize audio")
            return nil
        }
    }()
    
    
    
    func startProcessingSinewaveForPlayback(withFreq:Float=18000.0){
            sineFrequency = withFreq

                    // Two examples are given that use either objective c or that use swift
            //   the swift code for loop is slightly slower thatn doing this in c,
            //   but the implementations are very similar
            if let manager = self.audioManager{
                
                if USE_C_SINE {
                    // c for loop
                    manager.setOutputBlockToPlaySineWave(sineFrequency)
                }else{
                    // swift for loop
                    manager.outputBlock = self.handleSpeakerQueryWithSinusoid
                }
                
                
            }
        }
    
    func startAudioProcessing(withFps:Double){
        // setup the microphone to copy to circualr buffer
        if let manager = self.audioManager{
            
//            manager.inputBlock = self.handleSpeakerQueryWithAudioFile
            
            manager.outputBlock = self.handleSpeakerQueryWithAudioFile
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                                 selector: #selector(self.runEveryInterval),
                                 userInfo: nil,
                                 repeats: true)
//            Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
//                                 selector: #selector(self.runEqualizerInterval),
//                                 userInfo: nil,
//                                 repeats: true)
        }
    }
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps:Double){
        // setup the microphone to copy to circualr buffer
        if let manager = self.audioManager{
            manager.inputBlock = self.handleMicrophone
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                                 selector: #selector(self.runEveryInterval),
                                 userInfo: nil,
                                 repeats: true)
//            Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
//                                 selector: #selector(self.runEqualizerInterval),
//                                 userInfo: nil,
//                                 repeats: true)
        }
    }
    
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager{
            manager.play()
        }
    }
    func pause(){
        self.audioManager?.pause()
    }
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    private lazy var outputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    // NONE for this model
    
    //==========================================
    // MARK: Model Callback Methods
    @objc
    private func runEveryInterval(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData,
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            
        }
    }
    private func indexToFreq(index:Int)->Float{
        return (Float(audioManager!.samplingRate) / Float(BUFFER_SIZE)) * Float(index)
    }
//    func findDoppler2(playedFreq: Int) -> String{
//        var leftMax: Float = 0
//        var leftMaxIdx: Int = 0
//        var rightMax: Float = 0
//        var rightMaxIdx: Int = 0
//        let playedIndex = playedFreq / (48000 / BUFFER_SIZE)
//        
//        vDSP_maxvi(&fftData[playedIndex-1000], 1, &leftMax, &leftMaxIdx, vDSP_Length(1000))
//        vDSP_maxvi(&fftData[playedIndex], 1, &rightMax, &rightMaxIdx, vDSP_Length(1000))
//    
//        if(rightMax>leftMax){
//            return "toward: \(rightMax)"
//        }
//        else{
//            return "away: \(leftMax)"
//        }
//    }
    func findDoppler(playedFreq: Int) -> String{
        var largestMax: Float = -1000.0
        var secondMax: Float = -1000.0
        let playedIndex = playedFreq / (48000 / BUFFER_SIZE)
        var index: Int = 0
        var largestIndex: Int = 0
        var secondIndex: Int = 0
        let windowSize = 15
        let captureRange = 30
        let sensitivity :Int = 17
        
        for i in playedIndex-captureRange ..< (playedIndex+captureRange - windowSize){
            var temp_max:Float = -1000.0
            var temp_index: vDSP_Length = 0
            //store frame in tempFrame
            var tempFrame:[Float] = Array(fftData[i ..< (i + windowSize)])
            //find max in frame
            vDSP_maxvi(&tempFrame, 1, &temp_max, &temp_index, vDSP_Length(windowSize))
            index = Int(temp_index)
//            print(i + index)
            //check if frame is local max
            if(index == windowSize/2){

                if(temp_max > secondMax){
                    
                    secondMax = temp_max
                    secondIndex = index + i
                    
                    if(secondMax > largestMax){
                        let tempMax = largestMax
                        let tempIndex = largestIndex
                        
                        largestMax = temp_max
                        largestIndex = index + i
                        
                        secondMax = tempMax
                        secondIndex = tempIndex
                    }
                }
                else if(temp_max > largestMax){
                    largestMax = temp_max
                    largestIndex = index + i
                }
            }
            
        }
        print("largest: \(fftData[largestIndex])")
        print("2nd: \(fftData[secondIndex])")
        
        let returnMe: [Float] = [Float(largestIndex), Float(secondIndex)]
        if(returnMe[1]>(Float(playedIndex)+Float(sensitivity))){
            return "Toward Freq: \(playedFreq), 2nd: \(returnMe[1] * Float((48000 / BUFFER_SIZE)))"
        }
        else if(returnMe[1]<(Float(playedIndex)-Float(sensitivity))){
            return "Away Freq: \(playedFreq), 2nd: \(returnMe[1] * Float((48000 / BUFFER_SIZE)))"
        }
        else{
            return "Stationary Freq: \(playedFreq), 2nd: \(returnMe[1] * Float((48000 / BUFFER_SIZE)))"
        }
    
    }
    
    
    
    func findLoudest() -> [Float]{
        
        var largestMax: Float = -1000.0
        var secondMax: Float = -1000.0
        
        var index: Int = 0
        var largestIndex: Int = 0
        var secondIndex: Int = 0
        
        for i in 0 ..< (fftData.count - 8){
            var temp_max:Float = -1000.0
            var temp_index: vDSP_Length = 0
            //store frame in tempFrame
            var tempFrame:[Float] = Array(fftData[i ..< (i + 8)])
            //find max in frame
            vDSP_maxvi(&tempFrame, 1, &temp_max, &temp_index, vDSP_Length(8))
            index = Int(temp_index)
//            print(i + index)
            //check if frame is local max
            if(index == 4){

                if(temp_max > secondMax){
                    
                    secondMax = temp_max
                    secondIndex = index + i
                    
                    if(secondMax > largestMax){
                        let tempMax = largestMax
                        let tempIndex = largestIndex
                        
                        largestMax = temp_max
                        largestIndex = index + i
                        
                        secondMax = tempMax
                        secondIndex = tempIndex
                    }
                }
                else if(temp_max > largestMax){
                    largestMax = temp_max
                    largestIndex = index + i
                }
            }
            
        }
//        print(max)
//        print(printIndex)
        let returnMe: [Float] = [Float(largestIndex), Float(secondIndex)]
        return returnMe
    }
    
//    @objc
//    private func runEqualizerInterval(){        
//        let interval = 20
//        for segment in stride(from: 0, to: interval, by: 1){
//            var segmentArray: [Float] = Array(fftData[segment*BUFFER_SIZE/(interval*2) ..< (segment * BUFFER_SIZE/(interval*2)) + BUFFER_SIZE/(interval*2)])
//
//            var maxVal: Float = 0.0
//            vDSP_maxv(&segmentArray, 1, &maxVal, vDSP_Length(segmentArray.count))
//            equalizedArray[segment] = maxVal
//
//        }
//    }
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    //    _     _     _     _     _     _     _     _     _     _
    //   / \   / \   / \   / \   / \   / \   / \   / \   / \   /
    //  /   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/
    var sineFrequency:Float = 0.0 { // frequency in Hz (changeable by user)
        didSet{
            
            if let manager = self.audioManager {
                if USE_C_SINE {
                    // if using objective c: this changes the frequency in the novocaine block
                    manager.sineFrequency = sineFrequency
                    
                }else{
                    // if using swift for generating the sine wave: when changed, we need to update our increment
                    phaseIncrement = Float(2*Double.pi*Double(sineFrequency)/manager.samplingRate)
                }
            }
        }
    }
    
    // SWIFT SINE WAVE
    // everything below here is for the swift implementation
    // this can be deleted when using the objective c implementation
    private var phase:Float = 0.0
    private var phaseIncrement:Float = 0.0
    private var sineWaveRepeatMax:Float = Float(2*Double.pi)
    
    func changeFrequency(withFreq: Float){
        if let manager = self.audioManager{
            phaseIncrement = Float(2*Double.pi*Double(withFreq)/manager.samplingRate)

        }

    }
    
    private func handleSpeakerQueryWithSinusoid(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        // while pretty fast, this loop is still not quite as fast as
        // writing the code in c, so I placed a function in Novocaine to do it for you
        // use setOutputBlockToPlaySineWave() in Novocaine
        if let arrayData = data{
            var i = 0
            while i<numFrames{
                arrayData[i] = sin(phase)*50
                phase += phaseIncrement
                if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                i+=1
            }
        }
    }
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    private func handleSpeakerQueryWithAudioFile(data: Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        
        if let file = self.fileReader{
            file.retrieveFreshAudio(data, numFrames: numFrames, numChannels: numChannels)
        }
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
        self.inputBuffer?.fetchInterleavedData(data, withNumSamples: Int64((numFrames)))

    }
    
    private func handleSpeaker(data: Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){

        self.outputBuffer?.fetchInterleavedData(data, withNumSamples: Int64((numFrames)))
    }
    
}
