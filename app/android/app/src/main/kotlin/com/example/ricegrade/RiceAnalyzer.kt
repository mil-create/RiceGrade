package com.example.ricegrade

import android.util.Base64
import org.opencv.android.OpenCVLoader
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.MatOfByte
import org.opencv.core.MatOfPoint
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.Rect
import org.opencv.core.Scalar
import org.opencv.core.Size
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import java.math.BigDecimal
import java.math.RoundingMode

/** On-device port of backend/analyzer.py. */
object RiceAnalyzer {
    // Grade thresholds (broken percentage)
    private const val GRADE_A_MAX = 5.0 // <=5% broken -> A
    private const val GRADE_B_MAX = 15.0 // >5% and <=15% -> B, else C

    private const val BROKEN_LENGTH_RATIO = 0.75 // broken if length < 75% of the median grain length
    private const val MIN_AREA_FRACTION = 0.2 // ignore specks smaller than 20% of the median grain area
    private const val MAX_SIDE = 1280.0 // resize so the long side is at most this many pixels

    private val GREEN = Scalar(0.0, 200.0, 0.0) // BGR
    private val RED = Scalar(0.0, 0.0, 255.0) // BGR

    private val loaded: Boolean by lazy { OpenCVLoader.initLocal() }

    private class Shape(
        val area: Double,
        val length: Double,
        val breadth: Double,
        val box: MatOfPoint,
    )

    private fun resize(img: Mat): Mat {
        val scale = MAX_SIDE / maxOf(img.rows(), img.cols())
        if (scale >= 1) return img
        val out = Mat()
        Imgproc.resize(img, out, Size(), scale, scale, Imgproc.INTER_AREA)
        img.release()
        return out
    }

    /** Otsu mask with grains white. Polarity is auto-detected from the image border. */
    private fun binaryMask(gray: Mat): Mat {
        val blurred = Mat()
        Imgproc.GaussianBlur(gray, blurred, Size(5.0, 5.0), 0.0)
        val mask = Mat()
        Imgproc.threshold(blurred, mask, 0.0, 255.0, Imgproc.THRESH_BINARY + Imgproc.THRESH_OTSU)
        blurred.release()

        val rows = mask.rows()
        val cols = mask.cols()
        val borderSum = Core.sumElems(mask.row(0)).`val`[0] +
            Core.sumElems(mask.row(rows - 1)).`val`[0] +
            Core.sumElems(mask.col(0)).`val`[0] +
            Core.sumElems(mask.col(cols - 1)).`val`[0]
        if (borderSum / (2 * rows + 2 * cols) > 127) { // background is white -> invert so grains are white
            Core.bitwise_not(mask, mask)
        }

        val opened = Mat()
        val kernel = Mat.ones(3, 3, CvType.CV_8U)
        Imgproc.morphologyEx(mask, opened, Imgproc.MORPH_OPEN, kernel)
        kernel.release()
        mask.release()
        return opened
    }

    private fun median(values: List<Double>): Double {
        val sorted = values.sorted()
        val mid = sorted.size / 2
        return if (sorted.size % 2 == 1) sorted[mid] else (sorted[mid - 1] + sorted[mid]) / 2
    }

    private fun round2(x: Double): Double = BigDecimal(x).setScale(2, RoundingMode.HALF_EVEN).toDouble()

    private fun encodePng(img: Mat): String {
        val buf = MatOfByte()
        Imgcodecs.imencode(".png", img, buf)
        val encoded = Base64.encodeToString(buf.toArray(), Base64.NO_WRAP)
        buf.release()
        return encoded
    }

    /**
     * Analyze rice grains in an image.
     *
     * Steps: resize -> grayscale -> blur -> Otsu (auto polarity) -> distance
     * transform + watershed -> rotated bounding rectangle per grain -> drop specks
     * -> classify broken (< 75% of median length) -> grade.
     *
     * distThreshFactor (0-1): fraction of each blob's max distance-transform
     * value used to seed grains. Lower = fewer seeds (less splitting), higher =
     * more seeds (more splitting).
     */
    fun analyze(path: String, distThreshFactor: Double = 0.6): Map<String, Any> {
        check(loaded) { "OpenCV native library failed to load" }

        val raw = Imgcodecs.imread(path)
        require(!raw.empty()) { "Could not read image at $path" }
        val img = resize(raw)
        val rows = img.rows()
        val cols = img.cols()
        val n = rows * cols

        val gray = Mat()
        Imgproc.cvtColor(img, gray, Imgproc.COLOR_BGR2GRAY)
        val thresh = binaryMask(gray)
        gray.release()

        val distMat = Mat()
        Imgproc.distanceTransform(thresh, distMat, Imgproc.DIST_L2, 5)
        val dist = FloatArray(n).also { distMat.get(0, 0, it) }
        val threshPx = ByteArray(n).also { thresh.get(0, 0, it) }
        distMat.release()

        // Seed grains relative to the thickest point of each connected blob, not of
        // the whole image, so one large cluster doesn't erase the seeds of small grains.
        val labelsMat = Mat()
        val nLabels = Imgproc.connectedComponents(thresh, labelsMat)
        val labels = IntArray(n).also { labelsMat.get(0, 0, it) }
        labelsMat.release()
        val blobMax = FloatArray(nLabels)
        for (i in 0 until n) {
            if (dist[i] > blobMax[labels[i]]) blobMax[labels[i]] = dist[i]
        }

        val sureFgPx = ByteArray(n)
        for (i in 0 until n) {
            if (threshPx[i].toInt() != 0 && dist[i] > distThreshFactor * blobMax[labels[i]]) {
                sureFgPx[i] = 255.toByte()
            }
        }
        thresh.release()
        val sureFg = Mat(rows, cols, CvType.CV_8U).also { it.put(0, 0, sureFgPx) }

        val markersMat = Mat()
        Imgproc.connectedComponents(sureFg, markersMat)
        sureFg.release()
        val markers = IntArray(n).also { markersMat.get(0, 0, it) }
        for (i in 0 until n) {
            markers[i] += 1 // background = 1
            // unknown = thresh - sure_fg: region for watershed to resolve
            if (threshPx[i].toInt() != 0 && sureFgPx[i].toInt() == 0) markers[i] = 0
        }
        markersMat.put(0, 0, markers)
        Imgproc.watershed(img, markersMat)
        markersMat.get(0, 0, markers)
        markersMat.release()

        // Bounding box per label so each grain mask is built only over its own region.
        val maxLabel = markers.maxOrNull() ?: 1
        val minX = IntArray(maxLabel + 1) { Int.MAX_VALUE }
        val minY = IntArray(maxLabel + 1) { Int.MAX_VALUE }
        val maxX = IntArray(maxLabel + 1) { -1 }
        val maxY = IntArray(maxLabel + 1) { -1 }
        for (y in 0 until rows) {
            for (x in 0 until cols) {
                val label = markers[y * cols + x]
                if (label <= 1) continue // -1 = watershed boundary, 1 = background
                if (x < minX[label]) minX[label] = x
                if (x > maxX[label]) maxX[label] = x
                if (y < minY[label]) minY[label] = y
                if (y > maxY[label]) maxY[label] = y
            }
        }

        var shapes = mutableListOf<Shape>()
        for (label in 2..maxLabel) {
            if (maxX[label] < 0) continue
            val roi = Rect(minX[label], minY[label], maxX[label] - minX[label] + 1, maxY[label] - minY[label] + 1)
            val maskPx = ByteArray(roi.width * roi.height)
            for (y in 0 until roi.height) {
                val rowOffset = (roi.y + y) * cols + roi.x
                for (x in 0 until roi.width) {
                    if (markers[rowOffset + x] == label) maskPx[y * roi.width + x] = 255.toByte()
                }
            }
            val mask = Mat(roi.height, roi.width, CvType.CV_8U).also { it.put(0, 0, maskPx) }
            val contours = mutableListOf<MatOfPoint>()
            val hierarchy = Mat()
            Imgproc.findContours(
                mask, contours, hierarchy, Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE,
                Point(roi.x.toDouble(), roi.y.toDouble()),
            )
            mask.release()
            hierarchy.release()
            if (contours.isEmpty()) continue

            val contour = contours.maxBy { Imgproc.contourArea(it) }
            val contour2f = MatOfPoint2f(*contour.toArray())
            val rect = Imgproc.minAreaRect(contour2f)
            contour2f.release()
            val length = maxOf(rect.size.width, rect.size.height)
            val breadth = minOf(rect.size.width, rect.size.height)
            val area = Imgproc.contourArea(contour)
            contours.forEach { it.release() }
            if (breadth < 1) continue

            val corners = Mat()
            Imgproc.boxPoints(rect, corners)
            val pts = FloatArray(8).also { corners.get(0, 0, it) }
            corners.release()
            val box = MatOfPoint(
                *Array(4) { Point(pts[2 * it].toInt().toDouble(), pts[2 * it + 1].toInt().toDouble()) },
            )
            shapes.add(Shape(area, length, breadth, box))
        }

        // Drop noise specks
        if (shapes.isNotEmpty()) {
            val medianArea = median(shapes.map { it.area })
            shapes = shapes.filter { it.area >= MIN_AREA_FRACTION * medianArea }.toMutableList()
        }

        val annotated = img
        if (shapes.isEmpty()) {
            val result = mapOf<String, Any>(
                "whole_count" to 0,
                "broken_count" to 0,
                "broken_percent" to 0.0,
                "avg_length_breadth_ratio" to 0.0,
                "grade" to "C",
                "annotated_image_base64" to encodePng(annotated),
            )
            annotated.release()
            return result
        }

        val brokenThreshold = BROKEN_LENGTH_RATIO * median(shapes.map { it.length })
        var brokenCount = 0
        for (s in shapes) {
            val broken = s.length < brokenThreshold
            if (broken) brokenCount++
            Imgproc.drawContours(annotated, listOf(s.box), 0, if (broken) RED else GREEN, 2) // red = broken, green = whole
            s.box.release()
        }

        val total = shapes.size
        val brokenPercent = brokenCount.toDouble() / total * 100.0
        val avgRatio = shapes.sumOf { it.length / it.breadth } / total

        val grade = when {
            brokenPercent <= GRADE_A_MAX -> "A"
            brokenPercent <= GRADE_B_MAX -> "B"
            else -> "C"
        }

        val result = mapOf<String, Any>(
            "whole_count" to total - brokenCount,
            "broken_count" to brokenCount,
            "broken_percent" to round2(brokenPercent),
            "avg_length_breadth_ratio" to round2(avgRatio),
            "grade" to grade,
            "annotated_image_base64" to encodePng(annotated),
        )
        annotated.release()
        return result
    }
}
