/// Performs border recognition and saves the data as a list of vectors.

///
/// It can later try to draw an image using the borders it learnt from the original image.
module ominbot.core.image_model;

import std.conv;

import dlib.math;
import dlib.image;

import ominbot.core.image.utils;

// TODO: convert images to PNG with ffmpeg or smth else after download, JPGs are troublesome.

struct Line {

    /// Position where the line starts.
    uint position;

    /// Length of the line.
    uint length;

}

struct AreaFactory {

    Line[][] lines;
    Color4f color;
    size_t size;

    /// Last set Y position.
    size_t lastY;

    /// If true, this area was invalidated.
    bool invalid;
    debug Vector2i anchor;

    Area makeArea() {

        return Area(lines, color, size);

    }

}

struct Area {

    Line[][] lines;
    Color4f color;
    size_t size;

}

/// Search the image for borders and pick the most important areas from it.
///
/// Found areas will be scaled to 64×64.
Area[] findBorders(string path) {

    import std.stdio, std.format;
    import std.algorithm;

    const threshold = 0.06;
    const maxIntensity = 0.5;
    const targetWidth = 128;

    auto image = loadImage(path);
    auto scale = cast(float) targetWidth / image.width;
    auto edgeImage = image.edgeDetectSobel(3/8.0).scaleMax(targetWidth, to!uint(image.height * scale));

    // TODO: Choose the largest areas

    // Areas found within the image.
    AreaFactory*[] result;

    // Previous area entries
    auto previousLineAreas = new AreaFactory*[image.width];

    // Note: we're starting from indexes (1, 1) since we can't find anything on the border
    // TODO: somehow determine which areas are closed and which are not, remove unclosed areas

    foreach (y; 1..edgeImage.height) {

        // Currently developed area
        AreaFactory* area;

        // If there's still a working area set at the end
        scope (success) if (area) {

            // It must be invalidated
            area.invalid = true;

        }

        foreach (x; 1..edgeImage.width) {

            void assertValidPosition() {

                debug assert(
                    y+1 == area.anchor.y + area.lines.length,
                    format!"invalid y in %s: (%s, %s) %s+%s"(path, x, y, area.anchor.y, area.lines.length)
                );

            }

            // Get the intensity. Note: r = g = b
            const intensity = edgeImage[x, y].r;

            // Get neighbor intensity
            const intensityLeft = edgeImage[x - 1, y].r;
            const intensityTop = edgeImage[x, y - 1].r;

            /// Intensity neighbors need to have to count as edges.
            const edgeIntensity = min(maxIntensity, intensity + threshold);

            /// Intensity this pixel needs to count as an edge of its top or left neighbor.
            const stopIntensity = min(maxIntensity, intensityLeft + threshold, intensityTop + threshold);

            scope (success) {

                // Update previous line data
                previousLineAreas[x] = area;

            }

            // Not in any area
            if (area is null) {

                const invalidPosition = intensityLeft < edgeIntensity
                    || intensity >= stopIntensity;

                // If we're not in a valid position to start a new area
                if (invalidPosition) continue;

                writefln!"%s %s: start"(x, y);

                // There is an existing line above
                if (auto other = previousLineAreas[x]) {

                    // Use it
                    area = other;

                    // Add a line if this we're continuing this area on another row
                    if (area.lastY != y) {

                        area.lines ~= [Line(x, 1)];

                    }

                    else area.lines[$-1] ~= Line(x, 1);


                    area.lastY = y;

                    assertValidPosition();

                    continue;

                }

                // The area starts here
                if (intensityTop >= edgeIntensity) {

                    import std.random;

                    result ~= new AreaFactory();
                    area = result[$-1];
                    area.lines ~= [Line(x, 1)];
                    area.lastY = y;

                    debug area.anchor = Vector2i(0, y);

                    assertValidPosition();

                    // TODO: detect color
                    area.color = hsv(uniform(0, 360), 1, 0.5, 0.5);
                    continue;

                }

            }

            // Developing an area
            else {

                // Check if we should continue an area above
                auto other = previousLineAreas[x];

                // Nothing above, this is not a valid area
                if (!other && intensityTop < edgeIntensity) {

                    // TODO: actually invalidate this
                    // currently, it invalidates too much
                    area = null;
                    continue;

                }

                // Line ends here
                if (intensity >= stopIntensity) {

                    area = null;
                    continue;

                }

                writefln!"%s %s: continue"(x, y);

                scope (success) {

                    // Add this pixel
                    area.lines[$-1][$-1].length += 1;

                    assertValidPosition();

                }


                // Line merges with another area
                if (other) {

                    import std.array;

                    // Ignore if this is the current area
                    if (area == other) continue;

                    // We need to merge into the other area to prevent references to dead areas in zig-zag patterns

                    // Start a new line
                    if (other.lastY != y) {

                        other.lines ~= null;
                        other.lastY += 1;

                    }

                    import std.stdio;
                    writefln!"merge";
                    writefln!"A: %s + %s = %s"(area.anchor, area.lines.length, area.lastY);
                    writefln!"B: %s + %s = %s"(other.anchor, other.lines.length, other.lastY);

                    // Update position of the other area
                    other.lastY = y;

                    // Replace the old area with the new one
                    area.invalid = true;
                    scope (exit) area = other;

                    // This area is bigger, increase size of the other one
                    if (area.lines.length > other.lines.length) {

                        const diff = area.lines.length - other.lines.length;

                        debug other.anchor = area.anchor;
                        other.lines = replicate(cast(Line[][]) [null], diff) ~ other.lines;

                    }

                    const indexDiff = other.lines.length - area.lines.length;

                    // Add this are to the other one
                    foreach_reverse (i, line; area.lines) {

                        other.lines[i+indexDiff] ~= area.lines[i];

                    }

                    // Update previous references to the area
                    foreach (ref entry; previousLineAreas[0..x]) {

                        if (entry == area) entry = other;

                    }

                }

            }

        }

    }

    debug foreach (area; result) {

        if (area.invalid) continue;

        drawArea(edgeImage, area.anchor, area.makeArea);

    }
    static size_t n;
    edgeImage.savePNG(text("resources/bot-unittest-border", n++, ".png"));


    import std.array;

    return result
        .filter!"a.invalid"
        .map!"a.makeArea"
        .array;

}

unittest {

    import std.stdio;

    // Images from Pixabay
    foreach (image; ["resources/unittest-gold.png", "resources/unittest-lemon.png"]) {

        foreach (area; findBorders(image)) {

            //writeln(area);

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

/// Draw the given area on the image; modifies in place.
void drawArea(SuperImage image, Vector2i reference, Area area) {

    auto position = reference;

    foreach (line; area.lines) {

        // Advance to the next line at the end
        scope (success) position.y += 1;

        // Draw each part
        foreach (part; line) {

            // Get the new X position
            position.x = reference.x + part.position;

            const end = position.x + part.length;

            // Draw it otherwise
            foreach (x; position.x .. end) {

                image[x, position.y] = combinePixels(image[x, position.y], area.color);

            }

        }

    }

}

unittest {

    auto image = loadImage("resources/unittest-lemon.png")
        .edgeDetectSobel(3/8.0)
        .scaleMax(32, 32);

    image.drawArea(
        Vector2i(7, 12),
        Area(
            [
                [Line(2, 0), Line(3, 1)],
                [Line(1, 0), Line(5, 1)],
                [Line(0, 0), Line(7, 1)],
                [Line(0, 0), Line(7, 1)],
                [Line(0, 0), Line(7, 1)],
                [Line(0, 0), Line(8, 1)],
                [Line(0, 0), Line(7, 1)],
                [Line(0, 0), Line(7, 1)],
                [Line(1, 0), Line(5, 1)],
                [Line(3, 0), Line(3, 1)],
            ],
            color4(0x00daffaa),
        ),
    );

    image.savePNG("resources/bot-unittest-area.png");

}
