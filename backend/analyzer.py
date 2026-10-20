import cv2
import numpy as np

# Grade thresholds (broken percentage)
GRADE_A_MAX = 5.0   # <=5% broken -> A
GRADE_B_MAX = 15.0  # >5% and <=15% -> B
# else -> C

def analyze_grains(image_path, dist_thresh_factor=0.7):
    """
    Analyze rice grains in an image.

    Steps:
    1. Convert to grayscale
    2. Apply Gaussian blur
    3. Apply Otsu's thresholding
    4. Distance transform + watershed to split touching grains
    5. Find contours and compute per-grain length, breadth, area
    6. Classify grains as whole/broken based on length < 75% of median length

    Args:
        image_path (str): Path to input image
        dist_thresh_factor (float): Factor for distance transform threshold (0-1).
                                    Lower values increase markers (more splitting),
                                    higher values decrease markers (less splitting).
                                    Default 0.7.

    Returns:
        dict: Metrics containing:
              'whole_count': int,
              'broken_count': int,
              'broken_percent': float,
              'avg_length_breadth_ratio': float,
              'grade': str,
              'grains': list of grain dicts (each with area, length, breadth, broken)
        numpy.ndarray: Annotated image with contours and bounding boxes drawn
    """
    # Read image
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Could not read image at {image_path}")

    # Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Apply Gaussian blur to reduce noise
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    # Apply Otsu's thresholding (binary inverse so grains are white on black)
    _, thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # Distance transform
    dist_transform = cv2.distanceTransform(thresh, cv2.DIST_L2, 5)

    # Sure foreground area (local maxima of distance transform)
    _, sure_fg = cv2.threshold(dist_transform, dist_thresh_factor * dist_transform.max(), 255, 0)
    sure_fg = np.uint8(sure_fg)

    # Unknown region (area to be determined by watershed)
    unknown = cv2.subtract(thresh, sure_fg)

    # Marker labelling
    _, markers = cv2.connectedComponents(sure_fg)
    # Add one to all labels so that background is not 0, but 1
    markers = markers + 1
    # Mark the unknown region with zero
    markers[unknown == 255] = 0

    # Apply watershed
    markers = cv2.watershed(img, markers)

    # Prepare list to hold grain data and annotated image
    grains = []
    annotated_img = img.copy()

    # Loop through all unique markers (excluding background=1 and boundaries=-1)
    unique_labels = np.unique(markers)
    for label in unique_labels:
        if label == 1 or label == -1:
            continue

        # Create mask for current grain
        mask = np.uint8(markers == label) * 255

        # Find contours
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if len(contours) == 0:
            continue

        # Take the largest contour (should be only one per grain)
        contour = max(contours, key=cv2.contourArea)

        # Compute properties
        area = cv2.contourArea(contour)
        x, y, w, h = cv2.boundingRect(contour)
        length = max(w, h)
        breadth = min(w, h)

        grains.append({
            'area': area,
            'length': length,
            'breadth': breadth
        })

        # Draw contour and bounding box on annotated image
        cv2.drawContours(annotated_img, [contour], -1, (0, 255, 0), 2)  # Green contour
        cv2.rectangle(annotated_img, (x, y), (x + w, y + h), (0, 0, 255), 2)  # Red bounding box

    # If no grains found, return empty metrics
    if not grains:
        metrics = {
            'whole_count': 0,
            'broken_count': 0,
            'broken_percent': 0.0,
            'avg_length_breadth_ratio': 0.0,
            'grade': 'C',
            'grains': []
        }
        return metrics, annotated_img

    # Classification based on length < 75% of median length
    lengths = [g['length'] for g in grains]
    median_length = np.median(lengths)
    broken_threshold = 0.75 * median_length

    whole_count = 0
    broken_count = 0
    total_ratio = 0.0
    for g in grains:
        g['broken'] = g['length'] < broken_threshold
        if g['broken']:
            broken_count += 1
        else:
            whole_count += 1
        total_ratio += g['length'] / g['breadth']

    broken_percent = (broken_count / len(grains)) * 100.0
    avg_length_breadth_ratio = total_ratio / len(grains)

    # Determine grade
    if broken_percent <= GRADE_A_MAX:
        grade = 'A'
    elif broken_percent <= GRADE_B_MAX:
        grade = 'B'
    else:
        grade = 'C'

    metrics = {
        'whole_count': whole_count,
        'broken_count': broken_count,
        'broken_percent': round(broken_percent, 2),
        'avg_length_breadth_ratio': round(avg_length_breadth_ratio, 2),
        'grade': grade,
        'grains': grains
    }

    return metrics, annotated_img

def draw_annotated_image(image_path, grains_data, dist_thresh_factor=0.7):
    """
    Draw annotations on the original image using pre-computed grain data.

    Args:
        image_path (str): Path to original image
        grains_data (list): List of grain dictionaries from analyze_grains
        dist_thresh_factor (float): Factor for distance transform threshold (0-1).
                                    Lower values increase markers (more splitting),
                                    higher values decrease markers (less splitting).
                                    Default 0.7.

    Returns:
        numpy.ndarray: Annotated image
    """
    # We need to reconstruct contours and bounding boxes from grains_data?
    # Since analyze_grains already returns the annotated image, this function
    # is redundant unless we want to re-draw from just the measurements.
    # For simplicity, we'll have analyze_grains return the annotated image directly.
    # This function is kept for interface completeness but will just call analyze_grains.
    _, annotated_img = analyze_grains(image_path, dist_thresh_factor)
    return annotated_img

if __name__ == "__main__":
    # Example usage (requires a test image named 'test_rice.jpg' in the same directory)
    try:
        metrics, annotated = analyze_grains("test_rice.jpg")
        print(f"Found {len(metrics['grains'])} grains")
        print(f"Whole: {metrics['whole_count']}, Broken: {metrics['broken_count']}")
        print(f"Broken %: {metrics['broken_percent']}%")
        print(f"Avg L/B ratio: {metrics['avg_length_breadth_ratio']}")
        print(f"Grade: {metrics['grade']}")

        # Save annotated image
        cv2.imwrite("annotated_rice.jpg", annotated)
        print("Annotated image saved as 'annotated_rice.jpg'")
    except Exception as e:
        print(f"Error: {e}")