//
//  ViewController.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

//winnie houng
//blake miller
//jadon strong

import UIKit
import Metal

class ViewController: UIViewController {
    
    @IBOutlet weak var frequencyLabel: UILabel!
    
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*8
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.view)
    }()
    
    override func viewWillDisappear(_ animated: Bool) {
        audio.pause()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let graph = self.graph{
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            
            // add in graphs for display
            graph.addGraph(withName: "fft",
                            shouldNormalizeForFFT: true,
                            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)

            graph.makeGrids() 
        }
        
        
        audio.startMicrophoneProcessing(withFps: 10)
//        audio.startAudioProcessing(withFps: 10)
        audio.play()
        
        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
       
    }

    
    // periodically, update the graph with refreshed FFT Data
    @objc
    func updateGraph(){
        self.graph?.updateGraph(
            data: self.audio.fftData,
            forKey: "fft"
        )
        
        let frequencies:[Float] = audio.findLoudest()
        
        frequencyLabel.text = "Frequencies: \(Int(frequencies[0]) * 48000 / AudioConstants.AUDIO_BUFFER_SIZE) \(Int(frequencies[1]) * 48000 / AudioConstants.AUDIO_BUFFER_SIZE)"
        
//        self.graph?.updateGraph(
//            data: self.audio.equalizedArray,
//            forKey: "equalize"
//        )
////
//        self.graph?.updateGraph(
//            data: self.audio.timeData,
//            forKey: "time"
//        )
    }
    

}

