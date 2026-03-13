# Off-axis Digital Holography Real-time Processing System

This MATLAB-based GUI application provides a real-time solution for capturing, processing, and reconstructing off-axis digital holograms. It supports both live camera feeds (GigE Vision) and local image sequences.

## 🚀 Features

* **Dual Mode Support**: Seamlessly switch between **Live GigE Camera** and **Local Folder** (TIFF sequences).
* **Real-time Demodulation**: High-speed FFT-based filtering to recover complex light fields (Intensity & Phase).
* **Intuitive UI**: Isolated control panel to prevent overlap with visualization plots.
* **Data Export**: One-click saving of the recovered complex amplitude as `.mat` files for post-analysis.

## 🛠 Prerequisites

* **MATLAB**: R2021a or later recommended.
* **Toolboxes**:
* Image Processing Toolbox
* Image Acquisition Toolbox (for Live mode)
* MATLAB Support Package for GigE Vision Hardware (for Lucid/GigE cameras).



## 📖 How to Use

### 1. Initialization

1. Run the script `HolographyApp.m`.
2. The **Control Settings** panel will appear on the left, and four display axes on the right.

### 2. Configuration

* **Data Source Mode**:
* Select `Live` to connect to your GigE camera (e.g., Lucid ATP013S-W).
* Select `Folder` to process pre-recorded `.tiff` files.


* **Exposure Time (us)**: Set the camera exposure (only for Live mode).
* **Filter Range (px)**: Adjust the radius of the frequency domain filter window (standard is 80px).

### 3. Execution

1. **Auto Calibrate**:
* Click this first. The system will capture a frame, perform a full-field FFT, and automatically identify the +1 order spectral centroid.
* It will initialize the coordinate system and plot the baseline interferogram and spectrum.


2. **Run System**:
* Click to start real-time processing.
* The **Interferogram**, **FFT Spectrum**, **Recovered Intensity**, and **Recovered Phase** will update continuously.


3. **Stop System**: Click the same button (now red) to pause the loop.

### 4. Data Saving

* Click **Save Current Field** to export the current complex amplitude ($E = A \cdot e^{i\phi}$) to a `.mat` file in the root directory.

## 🔬 Algorithm Workflow

The system follows these core steps:

1. **FFT**: Transform the cropped interferogram to the frequency domain.
2. **Filtering**: Extract the +1 order sideband using a Hanning window centered at the detected centroid.
3. **Demodulation**: Shift the spectrum to the center (baseband) and perform an inverse FFT (IFFT).
4. **Visualization**: Display the squared magnitude (Intensity) and the argument (Phase).

## 👤 Author

* **Developed by**: Arlen Diego
* **Contact**: arlen_diego@163.com


Copyright (c) 2026 Arlen Diego. All rights reserved. Only for academic evaluation.
