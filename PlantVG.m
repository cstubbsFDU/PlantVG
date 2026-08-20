function [] = PlantVG()

%%%% Current Version 1.0 (2026-08-20) %%%%
clc; clear all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Read in Image and Cell Data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[file1,location1] = uigetfile('*.*','Select the Cross Section Image');
fullpath1 = string(location1) + string(file1);
I = imread(fullpath1);
BW = imbinarize(I(:,:,1));

[file2,location2] = uigetfile('*.*','Select the Longitudinal Image');
fullpath2 = string(location2) + string(file2);
J = imread(fullpath2);
BW_J = imbinarize(J(:,:,1));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Get Wall Thickness, Radius, & Voxel Depth %%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
prompt = {'Vovel depth (pixels):','Wall thickness (pixels):','Wall thickness random variation +/- (pixels)', 'Radius (in pixels):','Cell Length Factor (multiply all cell lengths by this number)','Output file name', 'Downsample Factor', 'Number of Models to Create'};
dlgtitle = 'Input';
fieldsize = [1 45; 1 45; 1 45; 1 45; 1 45; 1 45; 1 45; 1 45];
definput = {'100','4','0', '2','1.0', 'Output Voxel Mesh', '1', '1'};
dialogue_answer = inputdlg(prompt,dlgtitle,fieldsize,definput);

voxelDepth = str2num(dialogue_answer{1});
wallThickness = str2num(dialogue_answer{2});
wallVariation = str2num(dialogue_answer{3});
radius = str2num(dialogue_answer{4});
lengthFactor = str2num(dialogue_answer{5});

dsf = ceil(str2num(dialogue_answer{7}));
model_quant = ceil(str2num(dialogue_answer{8}));
origDepth = ceil(voxelDepth); %save originally input depth
bufferDepth = ceil(2 * radius + wallThickness);
voxelDepth = origDepth + bufferDepth; %add a buffer so we can crop out the first few slices that are prone to significant noise
sliceBuffer = ceil(radius + wallThickness);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Find the Boundaries of the Cells %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialize variables
isCorrect = false;
current_BW = BW; % Start with the original image

while ~isCorrect
    % Find and trace the inside of each region
    BW_filled = imfill(current_BW, "holes");
    boundaries = bwboundaries(BW_filled);
    
    % Plot boundaries for user inspection
    figure;
    imshow(BW_filled);
    hold on;
    for i = 1:size(boundaries, 1)
        plot(boundaries{i}(:, 2), boundaries{i}(:, 1), 'LineWidth', 1.5);
    end
    hold off;
    pause(2);

    % Prompt the user in the Command Window
    prompt = 'Do the boundaries look correct? (y/n): ';
    response = input(prompt, 's');
    
    close; % Close the figure window before proceeding
    
    if strcmpi(response, 'y')
        isCorrect = true;
        disp('Boundaries accepted!');
    else
        % Invert the original image and try again
        current_BW = ~current_BW;
        disp('Inverting image and retrying...');
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Find the Cell Lengths %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialize variables
isCorrect = false;
current_BW_J = BW_J; % Start with the original image

while ~isCorrect
    % Find and trace the inside of each cell
    BW_filled_J = imfill(current_BW_J, "holes");
    boundariesLong = bwboundaries(BW_filled_J);
    
    countedCell = zeros(size(boundariesLong, 1), 1);
    heightPre = [];
    n = 1;
    
    for i = 1:size(boundariesLong, 1)
        % Make sure the cell isn't cropped by the image edges
        if max(boundariesLong{i}(:, 1)) < size(current_BW_J, 1) && min(boundariesLong{i}(:, 1)) > 1 
            heightPre(n) = max(boundariesLong{i}(:, 1)) - min(boundariesLong{i}(:, 1));
            countedCell(i) = 1;
            n = n + 1;
        end
    end
    
    % Plot boundaries for user inspection
    figure;
    imshow(BW_filled_J);
    hold on;
    for i = 1:size(boundariesLong, 1)
        if countedCell(i) == 1
            plot(boundariesLong{i}(:, 2), boundariesLong{i}(:, 1), 'LineWidth', 1.5);
        end
    end
    hold off;
    pause(2);

    % Prompt the user in the Command Window
    prompt = 'Do the cell boundaries look correct? (y/n): ';
    response = input(prompt, 's');
    
    close; % Close the figure window before proceeding
    
    if strcmpi(response, 'y')
        isCorrect = true;
        disp('Boundaries accepted!');
    else
        % Invert the original image and try again
        current_BW_J = ~current_BW_J;
        disp('Inverting image and retrying...');
    end
end
 
hist(lengthFactor*heightPre);
title('Click the lower and upper cell length filter...')
[filtervalx, filtervaly] = ginput(2);
n = 1;
for i = 1:size(heightPre,2)
    if heightPre(i) > filtervalx(1) && heightPre(i) < filtervalx(2)
        height(n) = heightPre(i);
        n = n + 1;
    end
end
close

height = lengthFactor*height;

Avg = mean(height);
Std = std(height);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Get Length Distribution %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Define the display names for the dialog box on a single line
listOptions = {'Normal', 'Chi-square', 'Exponential', 'Gamma', 'Poisson', 'Uniform', 'Weibull'};

% Open the selection dialog box
[indx, tf] = listdlg('PromptString', 'Select a probability distribution:', ...
                    'SelectionMode', 'single', ...
                    'ListString', listOptions);

% Check if the user made a selection (did not press Cancel)
if tf
    % Map the user's selection to MATLAB's official cdf distribution names
    switch listOptions{indx}
        case 'Normal'
            distributionSelection = 'Normal';
        case 'Chi-square'
            distributionSelection = 'Chisquare';
        case 'Exponential'
            distributionSelection = 'Exponential';
        case 'Gamma'
            distributionSelection = 'Gamma';
        case 'Poisson'
            distributionSelection = 'Poisson';
        case 'Uniform'
            distributionSelection = 'Uniform';
        case 'Weibull'
            distributionSelection = 'Weibull';
    end
end
    

% Fit parameters for Normal, Chisquare, Exponential, Gamma, Poisson,
% Uniform, or Weibull distribution to the transposed height vector
pd = fitdist(height', distributionSelection);
params = pd.Params;

%%%
%From here, we can loop the entire process to create the desired number of
%models

for quant = 1:model_quant
    model_name = string(dialogue_answer{6}) + '-' + num2str(quant);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% Create End Cap Array %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Build the end cap array
    numcaps = size(boundaries, 1);
    endCapArray = zeros(numcaps, voxelDepth);
    
    % Step through each row/boundary
    for i = 1:numcaps
        current_pos = round(rand() * Avg); % Random initial offset
        
        while current_pos <= voxelDepth
            if current_pos >= 1 && current_pos <= voxelDepth
                endCapArray(i, current_pos) = 1;
            end
            
            % Generate the next distance step based on the distribution selection
            switch lower(distributionSelection)
                case 'normal'
                    % params(1) = mean, params(2) = std
                    step_size = round(normrnd(params(1), params(2)));
                    
                case 'chi-square'
                    % params(1) = degrees of freedom
                    step_size = round(chi2rnd(params(1)));
                    
                case 'exponential'
                    % params(1) = mean (mu)
                    step_size = round(exprnd(params(1)));
                    
                case 'gamma'
                    % params(1) = shape (a), params(2) = scale (b)
                    step_size = round(gamrnd(params(1), params(2)));
                    
                case 'poisson'
                    % params(1) = mean rate (lambda)
                    step_size = round(poissrnd(params(1)));
                    
                case 'uniform'
                    % params(1) = lower bound, params(2) = upper bound
                    step_size = round(unifrnd(params(1), params(2)));
                    
                case 'weibull'
                    % params(1) = scale (a), params(2) = shape (b)
                    step_size = round(wblrnd(params(1), params(2)));
                    
                otherwise
                    % Fallback default
                    step_size = round(normrnd(Avg, Std));
            end
            
            % Ensure step size is at least 1 to prevent infinite loops
            if step_size < 1
                step_size = 1; 
            end
            
            current_pos = current_pos + step_size;
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% Build Voxel Matrix Cell by Cell %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    VoxelMatrix = zeros(size(BW,1), size(BW,2), voxelDepth);
    % each loop cycles through one cell
    for i = 1:size(boundaries,1)
       if size(boundaries{i},1) > 4 % make sure boundary is actually an area
           Voxboundary = boundaries{i};
           if size(Voxboundary,1) > 2
               endCapVector = endCapArray(i,:);
              
               %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
               %%%% Per-Cell Wall Thickness Randomization %%%%%%%%%%%%%%%%%%%%%%%
               %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
               % Generate a random variation strictly between -wallVariation and +wallVariation
               % If wallVariation is 0, this safely evaluates to 0.
               currentVariation = round((rand() * 2 * wallVariation) - wallVariation);
               cellWallThickness = wallThickness + currentVariation;
               
               % Ensure thickness doesn't drop below a minimum threshold (e.g., 1 pixel)
               if cellWallThickness < 1
                   cellWallThickness = 1;
               end
               
               %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
               %%%% Create Base Mask for Inner and Outer Curves %%%%%%%%%%%%%%%%%%%%%%
               %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              
               % create inner cell mask
               innerMask = poly2mask(Voxboundary(:,2), Voxboundary(:,1), size(VoxelMatrix,1), size(VoxelMatrix,2));
               innerMask = double(innerMask);
    
               % create outer cell mask based on the cell-specific wall thickness
               outerMask = zeros(size(VoxelMatrix,1), size(VoxelMatrix,2)); 
               [xi,yi] = meshgrid(1:size(BW,2), 1:size(BW,1));
               
               for n = 1:size(Voxboundary,1)
                   mask = sqrt((xi - Voxboundary(n,2)).^2 + (yi - Voxboundary(n,1)).^2) <= cellWallThickness;
                   outerMask = outerMask + mask;
               end
    
               % include the inside of the cell in the mask
               outerMask = outerMask + innerMask;
               
               %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
               %%%% Generate Pixel Subtraction Arrays %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
               %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              
               subInner = zeros(size(endCapVector,2),1);
               subOuter = zeros(size(endCapVector,2),1);
               fillArray = zeros(size(endCapVector,2),1);
               
               % Use cellWallThickness instead of global wallThickness here:
               thk = round(cellWallThickness / 2);
               ri = radius;
               ro = radius + thk;
              
               for k = 1:size(endCapVector,2)
                   if endCapVector(k) == 1
              
                       % calculate inner pixel subtraction value
                       for j = 1:ri
                           if k - thk - ri + j > 0 && k + thk + ri - j < size(endCapVector,2) + 1 
                            subInner(k - thk - ri + j) = sin(j*pi/2/ri)*ri;
                            subInner(k + thk + ri - j) = sin(j*pi/2/ri)*ri;
                           end
                       end
                       if k - thk > 0 && k + thk < size(endCapVector,2) + 1 
                        subInner(k-thk:k+thk) = ri;
                       end
              
                       % calculate outer pixel subtraction value (using cellWallThickness)
                       for j = 1:ri + thk
                           if k - thk - ri + j > 0 && k + thk + ri - j < size(endCapVector,2) + 1 
                               subOuter(k - ro + j) = sin(j*pi/2/(ri + cellWallThickness))*(ri+thk);
                               subOuter(k + ro - j) = sin(j*pi/2/(ri + cellWallThickness))*(ri+thk);
                           end
                       end
              
                       % add the cap and fills
                       if k - thk > 0 && k + thk < size(endCapVector,2) + 1 
                        fillArray(k - thk: k + thk) = 1;
                       end
                   end
              
               end
              
               %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
               %%%% Create Layer Image Based on Erosion %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
               %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
               for k = 1:size(endCapVector,2)
                   %erode outer mask
                   LayerImage = outerMask;
                   for j = 1:subOuter(k)
                       % Fill holes
                       mask2out = imfill(LayerImage, 'holes');
                       % Get outer perimeter.
                       perimImage = bwperim(mask2out);
                       % Set those pixels to false/0/black.
                       LayerImage(perimImage) = 0;
                   end
              
                   %if it's not supposed to be filled, erode inner mask and delete it out
                   if fillArray(k) == 0
                       LayerIn = innerMask;
                       for j = 1:subInner(k)
                           % Fill holes
                           mask2in = imfill(LayerIn, 'holes');
                           % Get outer perimeter.
                           perimImage = bwperim(mask2in);
                           % Set those pixels to false/0/black.
                           LayerIn(perimImage) = 0;
                       end
                       LayerImage(LayerIn==1)=0;
                   end
              
                   VoxelMatrix(:,:,k) = VoxelMatrix(:,:,k) + LayerImage;
              
               end
           end
       end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% Write the Tiff File %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %write the voxel matrix.  We need to crop out the first few slices, as well
    %as the edges, to avoid artifacts.  Then downsample if that option is
    %selected based on dsf value
    
    Xmin = sliceBuffer;
    Ymin = sliceBuffer;
    Xmax = size(BW,1) - sliceBuffer;
    Ymax = size(BW,2) - sliceBuffer;
    
    outputMatrix = VoxelMatrix(Xmin:dsf:Xmax,Ymin:dsf:Ymax,bufferDepth:dsf:voxelDepth);
    outputMatrix = uint8(outputMatrix * 255); %make it uint so ImageJ can read the tiff files
    
    imwrite(outputMatrix(:,:,1), model_name +'.tiff','WriteMode','overwrite')
    for i = 2:size(outputMatrix,3)
       imwrite(outputMatrix(:,:,i),model_name +'.tiff','WriteMode','append')
    end    
    

%output info
disp(string(model_quant) + ' ' + string(dialogue_answer{6}) + ' model(s) successfully created as a ' + num2str(size(outputMatrix,1)) + ' x ' + num2str(size(outputMatrix,2)) + ' x ' + num2str(size(outputMatrix,3)) + ' voxel TIFF and INP file(s)');

end
