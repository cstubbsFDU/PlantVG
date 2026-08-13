import io
import cv2
import numpy as np
import scipy.stats as stats
from skimage.measure import find_contours
from skimage.draw import polygon
from scipy.ndimage import binary_fill_holes
import streamlit as st

st.set_page_config(
    page_title="PlantVG 3D Voxel Generator", layout="centered"
)


def bwperim(image):
    """Equivalent to MATLAB's bwperim (finds perimeter of binary objects)."""
    padded = np.pad(image, 1, mode="constant", constant_values=0)
    kernel = np.ones((3, 3), dtype=np.uint8)
    eroded = cv2.erode(padded.astype(np.uint8), kernel, iterations=1)
    perim = padded.astype(np.uint8) - eroded
    return perim[1:-1, 1:-1].astype(bool)


def process_images(
    img_cross,
    img_long,
    wall_color,
    voxel_depth,
    wall_thickness,
    radius,
    length_factor,
    dist_choice,
    dsf,
    model_quant,
    output_name,
):
    # 1. Preprocess Images
    bw_cross = img_cross[:, :, 0] > 127
    bw_long = img_long[:, :, 0] > 127

    if wall_color == "White":
        bw_cross = ~bw_cross

    # Buffers setup
    orig_depth = int(voxel_depth)
    buffer_depth = int(2 * radius + wall_thickness)
    total_voxel_depth = orig_depth + buffer_depth
    slice_buffer = int(radius + wall_thickness)

    # 2. Find Longitudinal Cell Heights
    bw_filled_long = binary_fill_holes(bw_long)
    # skimage find_contours alternative to bwboundaries
    contours_long = find_contours(bw_filled_long.astype(float), 0.5)

    height_pre = []
    for contour in contours_long:
        # contour is Nx2 (row, col) i.e., (y, x)
        y_vals = contour[:, 0]
        if np.max(y_vals) < bw_long.shape[0] - 1 and np.min(y_vals) > 1:
            height_pre.append(np.max(y_vals) - np.min(y_vals))

    if not height_pre:
        st.error(
            "No valid longitudinal cells found. Check image or thresholding."
        )
        return None, None

    height_pre = np.array(height_pre) * length_factor
    avg_h, std_h = np.mean(height_pre), np.std(height_pre)

    # Fit distribution
    dist_map = {
        "Normal": stats.norm,
        "Chi-square": stats.chi2,
        "Exponential": stats.expon,
        "Gamma": stats.gamma,
        "Poisson": stats.poisson,
        "Uniform": stats.uniform,
        "Weibull": stats.weibull_min,
    }

    selected_dist = dist_map.get(dist_choice, stats.norm)
    # Fit parameters to data
    fit_params = selected_dist.fit(height_pre)

    # 3. Find Cross-Section Boundaries
    bw_filled_cross = binary_fill_holes(bw_cross)
    contours_cross = find_contours(bw_filled_cross.astype(float), 0.5)

    generated_models = {}

    for quant in range(1, model_quant + 1):
        model_filename = f"{output_name}-{quant}.tiff"

        # End Cap Array Construction
        num_caps = len(contours_cross)
        end_cap_array = np.zeros((num_caps, total_voxel_depth), dtype=int)

        for i in range(num_caps):
            step_length = round(np.random.normal(avg_h, std_h))
            for j in range(total_voxel_depth):
                # CDF check
                if np.random.rand() < selected_dist.cdf(
                    step_length, *fit_params
                ):
                    end_cap_array[i, j] = 1
                    step_length = 0
                step_length += 1

        # Voxel Matrix Cell by Cell Construction
        voxel_matrix = np.zeros(
            (bw_cross.shape[0], bw_cross.shape[1], total_voxel_depth),
            dtype=float,
        )

        xi, yi = np.meshgrid(
            np.arange(1, bw_cross.shape[1] + 1),
            np.arange(1, bw_cross.shape[0] + 1),
        )

        for i, contour in enumerate(contours_cross):
            if len(contour) > 4:
                vox_boundary = contour  # format: (y, x)
                end_cap_vector = end_cap_array[i]

                # Inner cell mask
                rr, cc = polygon(
                    vox_boundary[:, 0],
                    vox_boundary[:, 1],
                    voxel_matrix.shape[:2],
                )
                inner_mask = np.zeros(voxel_matrix.shape[:2], dtype=float)
                inner_mask[rr, cc] = 1.0

                # Outer cell mask
                outer_mask = np.zeros(voxel_matrix.shape[:2], dtype=float)
                for n in range(len(vox_boundary)):
                    mask = (
                        np.sqrt(
                            (xi - vox_boundary[n, 1]) ** 2
                            + (yi - vox_boundary[n, 0]) ** 2
                        )
                        <= wall_thickness
                    )
                    outer_mask += mask.astype(float)

                outer_mask = outer_mask + inner_mask

                # Pixel subtraction arrays
                sub_inner = np.zeros(len(end_cap_vector))
                sub_outer = np.zeros(len(end_cap_vector))
                fill_array = np.zeros(len(end_cap_vector))
                thk = round(wall_thickness / 2)
                ri = radius
                ro = radius + thk

                for k in range(len(end_cap_vector)):
                    if end_cap_vector[k] == 1:
                        for j in range(1, int(ri) + 1):
                            idx1 = k - thk - int(ri) + j - 1
                            idx2 = k + thk + int(ri) - j - 1
                            val = np.sin(j * np.pi / 2 / ri) * ri
                            if 0 <= idx1 < len(end_cap_vector):
                                sub_inner[idx1] = val
                            if 0 <= idx2 < len(end_cap_vector):
                                sub_inner[idx2] = val

                        if (
                            0 <= k - thk < len(end_cap_vector)
                            and 0 <= k + thk < len(end_cap_vector)
                        ):
                            sub_inner[k - thk : k + thk + 1] = ri

                        for j in range(1, int(ri + thk) + 1):
                            idx1 = k - ro + j - 1
                            idx2 = k + ro - j - 1
                            val = (
                                np.sin(j * np.pi / 2 / (ri + wall_thickness))
                                * (ri + thk)
                            )
                            if 0 <= idx1 < len(end_cap_vector):
                                sub_outer[idx1] = val
                            if 0 <= idx2 < len(end_cap_vector):
                                sub_outer[idx2] = val

                        if (
                            0 <= k - thk < len(end_cap_vector)
                            and 0 <= k + thk < len(end_cap_vector)
                        ):
                            fill_array[k - thk : k + thk + 1] = 1

                # Layer image generation via erosion
                for k in range(len(end_cap_vector)):
                    layer_image = outer_mask.copy()
                    for _ in range(int(sub_outer[k])):
                        mask2out = binary_fill_holes(layer_image > 0)
                        perim_image = bwperim(mask2out)
                        layer_image[perim_image] = 0

                    if fill_array[k] == 0:
                        layer_in = inner_mask.copy()
                        for _ in range(int(sub_inner[k])):
                            mask2in = binary_fill_holes(layer_in > 0)
                            perim_image = bwperim(mask2in)
                            layer_in[perim_image] = 0
                        layer_image[layer_in == 1] = 0

                    voxel_matrix[:, :, k] += layer_image

        # Crop and Downsample
        xmin = slice_buffer
        ymin = slice_buffer
        xmax = bw_cross.shape[0] - slice_buffer
        ymax = bw_cross.shape[1] - slice_buffer

        output_matrix = voxel_matrix[
            xmin : xmax : dsf, ymin : ymax : dsf, buffer_depth::dsf
        ]
        output_matrix = np.clip(output_matrix * 255, 0, 255).astype(np.uint8)

        generated_models[model_filename] = output_matrix

    return generated_models, height_pre


# --- Streamlit UI Layout ---
st.title("🌱 PlantVG 3D Voxel Generator")
st.markdown(
    "Upload cross-section and longitudinal microscope slices to generate 3D cellular voxel stacks."
)

with st.sidebar:
    st.header("1. Input Images")
    cross_file = st.file_uploader(
        "Cross Section Image", type=["png", "jpg", "tif", "tiff"]
    )
    long_file = st.file_uploader(
        "Longitudinal Image", type=["png", "jpg", "tif", "tiff"]
    )

    wall_color = st.selectbox(
        "Are the cell walls black or white?", ("Black", "White")
    )

    st.header("2. Parameters")
    voxel_depth = st.number_input("Voxel depth (pixels)", value=100)
    wall_thickness = st.number_input("Wall thickness (pixels)", value=4)
    radius = st.number_input("Radius (in pixels)", value=2.0)
    length_factor = st.number_input(
        "Cell Length Factor", value=1.0, format="%.2f"
    )
    output_name = st.text_input("Output file name", value="Output_Voxel_Mesh")
    dsf = st.number_input("Downsample Factor", value=1, min_value=1)
    model_quant = st.number_input(
        "Number of Models to Create", value=1, min_value=1
    )
    dist_choice = st.selectbox(
        "Probability Distribution",
        [
            "Normal",
            "Chi-square",
            "Exponential",
            "Gamma",
            "Poisson",
            "Uniform",
            "Weibull",
        ],
    )

if cross_file and long_file:
    if st.button("Generate Voxel Models", type="primary"):
        with st.spinner(
            "Processing images and calculating 3D matrices... Please wait."
        ):
            img_cross = cv2.imdecode(
                np.frombuffer(cross_file.read(), np.uint8), cv2.IMREAD_COLOR
            )
            img_long = cv2.imdecode(
                np.frombuffer(long_file.read(), np.uint8), cv2.IMREAD_COLOR
            )

            models, heights = process_images(
                img_cross,
                img_long,
                wall_color,
                voxel_depth,
                wall_thickness,
                radius,
                length_factor,
                dist_choice,
                int(dsf),
                int(model_quant),
                output_name,
            )

            if models:
                st.success(
                    f"Successfully generated {len(models)} model(s)!"
                )

                for name, matrix in models.items():
                    # Save stack into memory as multi-page TIFF bytes
                    tiff_io = io.BytesIO()
                    # Use OpenCV or tifffile to save multi-page stack
                    import tifffile

                    tifffile.imwrite(tiff_io, matrix.transpose(2, 0, 1))

                    st.download_button(
                        label=f"📥 Download {name}",
                        data=tiff_io.getvalue(),
                        file_name=name,
                        mime="image/tiff",
                    )
