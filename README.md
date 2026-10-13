**** Plant Voxel Generator (PlantVG) ****

PlantVG is a custom computational tool designed to generate fully three-dimensional (3D) voxel finite element models of herbaceous stem cellular microstructure using only a pair of 2D optical microscopy or computed tomography (CT) slices (transverse and longitudinal).

For example files, see the "Examples" folders of input slices and output voxel meshes.

There are 3 ways to use this program:

1. Download and run the standalone html file.
2. Run it using Google Colab (Python script), here: https://colab.research.google.com/github/cstubbsFDU/PlantVG/blob/main/PlantVG_Colab.ipynb
3. Donwnload the PlantVG.m file and run it within your Matlab environment.

For a detailed explanation of the process and code, download and open the explainer html file: "PlantVG_ How the Plant Voxel Generator Works.html"



**** Cell Wall Thickness Measurements ****

To use this ImageJ macro, simply download the and install the file into ImageJ.

Make sure to set the threshold value (defined on line 8) to the greyscale value that defines the transition from cell to cell wall for your specific sample.
Alternatively, no threshold value modification is needed on a binarized image.
