# Audio-Filtering-using-Metal

- takes fft from incoming audio stream
- displays frequency of 2 loudest tones on UI
- distinguishes Doppler Shifts in frequency to microphone

Follows Model-View-Controller Pattern
- audio saving and analysis done in AudioModel, using blocks on serial queue
- viewController gets analysis results(fft frames) and displays
