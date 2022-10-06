//
//  BViewController.swift
//  AudioLabSwift
//
//  Created by zhongyuan liu on 10/5/22.
//  Copyright © 2022 Eric Larson. All rights reserved.
//

import UIKit
import Metal

class BViewController: UIViewController {

    @IBOutlet weak var toneSlider: UISlider!
    @IBOutlet weak var magnitudeLabel: UILabel!
    
    
    struct AudioConstants{
            static let AUDIO_BUFFER_SIZE = 1024*8
        }//8192/2=4096
        
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
                                numPointsInGraph: 1000)
                
                graph.makeGrids()
            }
            
            audio.startProcessingSinewaveForPlayback()
            audio.startMicrophoneProcessing(withFps: 10)
    //        audio.startAudioProcessing(withFps: 10)
            audio.play()
            
            // run the loop for updating the graph peridocially
            Timer.scheduledTimer(timeInterval: 0.05, target: self,
                selector: #selector(self.updateGraph),
                userInfo: nil,
                repeats: true)
            Timer.scheduledTimer(timeInterval: 0.2, target: self,
                                 selector: #selector(self.updateLabel),
                userInfo: nil,
                repeats: true)
           
        }

//
    @IBAction func changeFrequency(_ sender: Any) {
        let frequency = 15000 + (toneSlider.value * 5000)
        audio.startProcessingSinewaveForPlayback(withFreq: frequency)
    }
    //    @IBAction func changeFrequency(_ sender: Any) {
////        audio.startProcessingSinewaveForPlayback(withFreq: 20000.0)
////        audio.changeFrequency(withFreq: 18000.0)
//    }
    
        
    
    @objc
    func updateLabel(){
        var frequency = 15000 + (toneSlider.value * 5000)
        frequency = frequency/Float((48000/AudioConstants.AUDIO_BUFFER_SIZE))
        magnitudeLabel.text = audio.findDoppler(playedFreq: Int(frequency))
    }
    // periodically, update the graph with refreshed FFT Data
        @objc
        func updateGraph(){
            self.graph?.updateGraph(
                data: Array(self.audio.fftData[2500...3500]),
                forKey: "fft"
            )
            
            
            
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



    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
