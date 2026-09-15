macro "Measure Wall Width at Threshold [m]" {
    // Check if a selection is active
    if (selectionType() == -1) {
        exit("Error: Please draw a straight line selection across the cell wall first.");
    }

    // Set the threshold you want for the cross-over tracking
    threshold = 160;

    // Get profile data from the current straight line selection
    profile = getProfile();

    // Get line coordinates (5th argument is the line width)
    getLine(x1, y1, x2, y2, lineWidth);
    if (x1 == -1) {
        exit("Error: Please use a straight line selection.");
    }

    totalPixels = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
    pixelsPerIndex = totalPixels / profile.length;

    // Get spatial calibration (e.g., microns)
    getVoxelSize(pixelWidth, pixelHeight, depth, unit);

    // Find all points crossing below the threshold (cell wall dip)
    crossings = newArray(0);
    for (i = 0; i < profile.length; i++) {
        if (profile[i] <= threshold) {
            crossings = Array.concat(crossings, i);
        }
    }

    // Calculate width if crossover points are found
    if (crossings.length > 0) {
        startIndex = crossings[0];
        endIndex = crossings[crossings.length - 1];

        pixelWidthSpan = endIndex - startIndex;
        calibratedWidth = pixelWidthSpan * pixelsPerIndex * pixelWidth;

        // Print results to the Log window
        print("--- Cell Wall Measurement ---");
        print("Threshold: " + threshold);
        print("Start Index: " + startIndex + " | End Index: " + endIndex);
        print("Width (Pixels): " + pixelWidthSpan);
        print("Width (" + unit + "): " + calibratedWidth);

        // Log to the ImageJ Results table
        row = nResults;
        setResult("Threshold", row, threshold);
        setResult("Width (px)", row, pixelWidthSpan);
        setResult("Width (" + unit + ")", row, calibratedWidth);
        updateResults();

    } else {
        print("No points found crossing below the threshold of " + threshold);
        showMessage("No Crossover", "The profile never drops below the threshold of " + threshold);
    }
}