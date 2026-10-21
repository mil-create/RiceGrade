import cv2
import numpy as np

# Grade thresholds (broken percentage)
GRADE_A_MAX = 5.0   # <=5% broken -> A
GRADE_B_MAX = 15.0  # >5% and <=15% -> B, else C

BROKEN_LENGTH_RATIO = 0.75  # broken if length < 75% of the median grain length
MIN_AREA_FRACTION = 0.2     # ignore specks smaller than 20% of the median grain area
MAX_SIDE = 1280             # resize so the long side is at most this many pixels


def _resize(img):
    scale = MAX_SIDE / max(img.shape[:2])
    if scale < 1:
        img = cv2.resize(img, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    return img


def _binary_mask(gray):
    """Otsu mask with grains white. Polarity is auto-detected from the image border."""
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    _, mask = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    border = np.concatenate([mask[0, :], mask[-1, :], mask[:, 0], mask[:, -1]])
    if border.mean() > 127:  # background is white -> invert so grains are white
        mask = cv2.bitwise_not(mask)
    return cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))


def analyze_grains(image_path, dist_thresh_factor=0.6):
    """
    Analyze rice grains in an image.

    Steps: resize -> grayscale -> blur -> Otsu (auto polarity) -> distance
    transform + watershed -> rotated bounding rectangle per grain -> drop specks
    -> classify broken (< 75% of median length) -> grade.

    dist_thresh_factor (0-1): fraction of each blob's max distance-transform
    value used to seed grains. Lower = fewer seeds (less splitting), higher =
    more seeds (more splitting).

    Returns (metrics dict, annotated BGR image).
    """
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Could not read image at {image_path}")
    img = _resize(img)
    thresh = _binary_mask(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY))

    dist = cv2.distanceTransform(thresh, cv2.DIST_L2, 5)
    # Seed grains relative to the thickest point of each connected blob, not of
    # the whole image, so one large cluster doesn't erase the seeds of small grains.
    n_labels, labels = cv2.connectedComponents(thresh)
    blob_max = np.zeros(n_labels, np.float32)
    np.maximum.at(blob_max, labels.ravel(), dist.ravel())
    sure_fg = np.uint8((dist > dist_thresh_factor * blob_max[labels]) & (thresh > 0)) * 255
    unknown = cv2.subtract(thresh, sure_fg)

    _, markers = cv2.connectedComponents(sure_fg)
    markers = markers + 1          # background = 1
    markers[unknown == 255] = 0    # unknown region for watershed to resolve
    markers = cv2.watershed(img, markers)

    shapes = []
    for label in np.unique(markers):
        if label <= 1:  # -1 = watershed boundary, 1 = background
            continue
        mask = np.uint8(markers == label) * 255
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not contours:
            continue
        contour = max(contours, key=cv2.contourArea)
        rect = cv2.minAreaRect(contour)
        w, h = rect[1]
        length, breadth = max(w, h), min(w, h)
        if breadth < 1:
            continue
        shapes.append({
            'area': float(cv2.contourArea(contour)),
            'length': float(length),
            'breadth': float(breadth),
            'box': np.intp(cv2.boxPoints(rect)),
        })

    # Drop noise specks
    if shapes:
        median_area = np.median([s['area'] for s in shapes])
        shapes = [s for s in shapes if s['area'] >= MIN_AREA_FRACTION * median_area]

    annotated_img = img.copy()
    if not shapes:
        return {
            'whole_count': 0,
            'broken_count': 0,
            'broken_percent': 0.0,
            'avg_length_breadth_ratio': 0.0,
            'grade': 'C',
            'grains': [],
        }, annotated_img

    broken_threshold = BROKEN_LENGTH_RATIO * np.median([s['length'] for s in shapes])
    broken_count = 0
    for s in shapes:
        s['broken'] = bool(s['length'] < broken_threshold)
        broken_count += s['broken']
        color = (0, 0, 255) if s['broken'] else (0, 200, 0)  # red = broken, green = whole
        cv2.drawContours(annotated_img, [s['box']], 0, color, 2)

    total = len(shapes)
    broken_percent = broken_count / total * 100.0
    avg_ratio = sum(s['length'] / s['breadth'] for s in shapes) / total

    if broken_percent <= GRADE_A_MAX:
        grade = 'A'
    elif broken_percent <= GRADE_B_MAX:
        grade = 'B'
    else:
        grade = 'C'

    metrics = {
        'whole_count': total - broken_count,
        'broken_count': broken_count,
        'broken_percent': round(broken_percent, 2),
        'avg_length_breadth_ratio': round(avg_ratio, 2),
        'grade': grade,
        'grains': [
            {k: v for k, v in s.items() if k != 'box'} for s in shapes
        ],
    }
    return metrics, annotated_img


def draw_annotated_image(image_path, grains_data=None, dist_thresh_factor=0.6):
    """Convenience wrapper: returns only the annotated image."""
    _, annotated_img = analyze_grains(image_path, dist_thresh_factor)
    return annotated_img


if __name__ == "__main__":
    import sys

    path = sys.argv[1] if len(sys.argv) > 1 else "test_rice.jpg"
    metrics, annotated = analyze_grains(path)
    print({k: v for k, v in metrics.items() if k != 'grains'})
    cv2.imwrite("annotated_rice.jpg", annotated)