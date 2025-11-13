

Microphone Calibration Toolkit
Description
This MATLAB toolkit comprises several scripts designed for analyzing, calculating, and plotting microphone sensitivities . It includes functions for processing individual microphone and speaker  data, calculating the sensitivity of GRAS microphones at 1 kHz, and combining and visualizing sensitivity data from multiple recordings.


Prerequisites
MATLAB (R2019b or newer recommended)
Signal Processing Toolbox
You need to have taken recordings using the 1/8th inch microphone beforehand with the speaker you are using as well as the 1 khz calibration tone. Convert those recordings to Mat files (first convert to nodaq or new tdms files). 
Folder Scructure: 
1) Folder with Scripts: functions and pipelines need to be in same script
2) 3 Folders with Recordings: 1)1 Khz tone recordings- reccommend at least 5 recordings 2) Grass microphone recordings with speaker and gras microphone : at least 5 recordings 3) Mic recordings

Usage
Each script is designed to be run individually depending on the stage of the calibration process. It is a live script so I would reccommend running it section by section. 

analyzeMicrophoneSensitivity_regularMic.m - Loads and analyzes microphone recordings to determine sensitivity.
calculateGrasMicrophoneSensitivity_1khz.m - Calculates the sensitivity of GRAS microphones at 1 kHz from calibration data.
processCalibrationData_gras.m - Processes calibration data and computes mean power spectral density.
combineAndPlotSensitivities.m - Combines sensitivity data from various angles and plots them on a polar coordinate system.
Run each script in MATLAB by navigating to the script in the Current Folder window, right-clicking on the file, and selecting Run. Alternatively, type the script name in the Command Window.

Files
analyzeMicrophoneSensitivity_regularMic.m - This script loads calibration data and processes it to analyze the sensitivity of regular microphones by comparing against a reference.
calculateGrasMicrophoneSensitivity_1khz.m - Calculates the sensitivity at 1 kHz for GRAS microphones using RMS values from loaded waveform data.
processCalibrationData_gras.m - Computes the mean PSD for calibration data and saves the results, with options for visualizing the data.
combineAndPlotSensitivities.m - Reads sensitivity data from different angles, combines them, and plots the results on a polar plot for visual analysis at specific frequencies.
Contributing
Feel free to fork the repository and submit pull requests. You can also open an issue for bugs, feature requests, or other concerns.

Authors
Your Name
License
This project is licensed under the MIT License - see the LICENSE.md file for details.

Acknowledgments
Thanks to anyone whose code was used as inspiration. Special thanks to the Moss lab and contributors like Nikita Finger for edits and testing.