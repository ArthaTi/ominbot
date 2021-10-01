/// Performs border recognition and saves the data as a list of vectors.
///
/// It can later try to draw an image using the borders it learnt from the original image.
module omin.core.image_model;

import std.conv;

import dlib.math;
import dlib.image;

// TODO: convert images to PNG with ffmpeg or smth else after download, JPGs are troublesome.

struct Line {

    /// Length of the line.
    uint length;

    /// If true, this line is visible, if false, it's not.
    bool draws;

}

struct Area {

    Line[] borders;
    Color4f color;

}

/// Search the image for borders and pick the most important areas from it.
///
/// Found areas will be scaled to 64×64.
Area[] findBorders(string path) {

    import std.range;
    import std.typecons;

    struct Cursor {

        /// Direction the cursor came from, corresponds to a `neighbors` vector.
        int directionFrom;

        /// Position of the cursor.
        Vector2i position;

        /// Area developed by the cursor.
        Area area;

        /// This is the mean of the last intensity value and the intensity of the cursor position.
        float intensity = 1;

    }

    const neighbors = [
        Vector2i(+1,  0),
        Vector2i(+1, +1),
        Vector2i( 0, +1),
        Vector2i(-1, +1),
        Vector2i(-1,  0),
        Vector2i(-1, -1),
        Vector2i( 0, -1),
        Vector2i(+1, -1),
    ].cycle();

    const targetWidth = 128;

    auto image = loadImage(path);
    auto scale = cast(float) targetWidth / image.width;
    auto edgeImage = image.edgeDetectSobel(3/8.0).scaleMax(targetWidth, to!uint(image.height * scale));

    // TODO: Choose the largest area

    // Areas found within the image.
    Area[] areas;

    // Create cursors to traverse the image
    Cursor[] cursors;

    static size_t n;
    edgeImage.savePNG(text("resources/bot-unittest-border", n++, ".png"));

    return areas;

}

unittest {

    import std.stdio;

    foreach (image; ["resources/unittest-gold.png", "resources/unittest-lemon.png"]) {

        // Image from https://pixabay.com/photos/gold-ingots-treasure-bullion-513062
        foreach (area; findBorders(image)) {

            writeln(area);

        }

    }

}

/// Downscale the given image to target size, interpolating to maximum neighbor.
SuperImage scaleMax(SuperImage input, uint w, uint h) {

    import std.math, std.algorithm;

    /// Input pixels per output pixel
    const pixelsX = ceil(cast(float) input.width / w).to!uint;
    const pixelsY = ceil(cast(float) input.height / h).to!uint;
    const pixelDensity = pixelsX * pixelsY;

    auto output = input.createSameFormat(w, h);

    foreach (ref pixel, x, y; output) {

        auto sumPixel = Color4f(0, 0, 0, 1);
        auto maxPixel = Color4f(0, 0, 0, 1);

        foreach (iy; pixelsY*y .. pixelsY*y + pixelsY)
        foreach (ix; pixelsX*x .. pixelsX*x + pixelsX) {

            const inputPixel = input[ix, iy];

            sumPixel += inputPixel;
            maxPixel = Color4f(
                max(maxPixel.r, inputPixel.r),
                max(maxPixel.g, inputPixel.g),
                max(maxPixel.b, inputPixel.b),
            );

        }

        // Get the size intensity of this pixel
        auto intensity = sumPixel.arrayof[0..3].sum / pixelDensity;

        // Remove under or over intensified points
        // This should preserve only lines, and remove any messy points
        pixel = sumPixel / pixelDensity;

    }

    return output;

}
