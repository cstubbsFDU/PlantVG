Plant Voxel Generator (PlantVG)

PlantVG is a custom MATLAB-based computational tool designed to generate fully three-dimensional (3D) voxel finite element models of herbaceous stem cellular microstructure using only a pair of 2D optical microscopy or computed tomography (CT) slices (transverse and longitudinal). Simply donwload the PlantVG.m and run it within your Matlab environment.

For example files, see the "Examples" folders of input slices and output voxel meshes.

There is also a ported Python version hosted on Google Colab, here: https://colab.research.google.com/github/cstubbsFDU/PlantVG/blob/main/PlantVG_Colab.ipynb


CellWallThicknessMeasurements

To use this ImageJ macro, simply download the and install the file into ImageJ.

Make sure to set the threshold value (defined on line 8) to the greyscale value that defines the transition from cell to cell wall for your specific sample.
Alternatively, no threshold value modification is needed on a binarized image.
