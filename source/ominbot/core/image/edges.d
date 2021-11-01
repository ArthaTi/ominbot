/// Performs edge detection.
module ominbot.core.image.edges;

import std.conv;
import std.range;
import std.algorithm;
import std.container;

import dlib.math;
import dlib.image;

import ominbot.core.image.utils;

// TODO: convert images to PNG with ffmpeg or smth else after download, JPGs are troublesome.


@safe:


private {

    enum edgeDetectionSize = 128;

}


struct Position {

    int x, y;

    int opCmp(ref const Position other) const {

        const cmpY = y - other.y;

        return cmpY ? cmpY : x - other.x;

    }

    Position opBinary(string op)(ref const Position other) const {

        import std.format;

        return Position(
            mixin(op.format!"x %s other.x"),
            mixin(op.format!"y %s other.y"),
        );

    }

}

struct Line {

    Position[] points;

    /// Direction of the line, 0..8, 0 — top, 2 — right, 4 — bottom...
    int direction;

}

/// Search the image for borders and pick the most important areas from it.
///
/// Found lines will be scaled down to `edgeDetectionSize`.
Line[] findBorders(bool absolutePoints = false)(SuperImage image) @trusted {

    import std.stdio, std.format;

    const targetWidth = edgeDetectionSize;
    const brightThreshold = 0.5;

    auto scale = cast(float) targetWidth / image.width;
    auto edgeImage = image
        .edgeDetectSobel(3/8.0)
        .downscale(targetWidth, to!uint(image.height * scale));

    auto brightPoints = redBlackTree!Position;

    // Search the image for bright points
    foreach (color, x, y; edgeImage) {

        if (color.r >= brightThreshold) {

            brightPoints.insert(Position(x, y));

        }

    }

    Line[] result;

    while (!brightPoints.empty) {

        result ~= findLines!absolutePoints(edgeImage, brightPoints, brightPoints.front);

    }

    return result;

}

@system
unittest {

    import std.path;
    import std.stdio;
    import std.algorithm;

    // Images from Pixabay
    foreach (path; ["resources/unittest-gold.png", "resources/unittest-lemon.png"]) {

        double distanceFromCenter(Position pos) {

            const center = edgeDetectionSize/2;

            // Note: no need for square root
            return (center - pos.x)^^2 + (center - pos.y)^^2;

        }

        auto image = loadImage(path);
        auto newImage = .image(edgeDetectionSize, edgeDetectionSize);
        auto lines = findBorders!true(image)
            .sort!("a.points.length < b.points.length");

        foreach (line; lines) {

            newImage.drawLine(Position(), line);

        }

        newImage
            .downscaleMax(32, 32)
            .savePNG("resources".buildPath("bot-" ~ path.baseName));

    }

}

void drawLine(SuperImage image, Position position, Line line) @trusted {

    foreach (point; line.points) {

        auto p = position + point;
        auto previous = image[p.x, p.y];

        image[p.x, p.y] = alphaOver(previous, hsv(line.direction % 4 * 90.0, 1, 1, 0.2));

    }

}

/// Find lines in the image starting from some point in the tree.
private Line[] findLines(bool absolutePoints = false)(SuperImage image, RedBlackTree!Position unvisited, Position start)
    @trusted
do {

    enum absolutePoints = true;

    enum minIntensityMult = 0.7;
    enum minIntensity = 0.25;

    enum intensityStep = (1 - minIntensityMult) / 3;

    struct Cursor {

        Position end;
        float intensity;

        Position[] points = [Position(0, 0)];
        size_t direction = 0;

        // Appearance count of each direction
        size_t[8] directionCount;

    }

    Line[] result;

    auto cursors = absolutePoints
        ? [Cursor(start, image[start.x, start.y].r, [start])]
        : [Cursor(start, image[start.x, start.y].r)];

    Position[] neighbors = [
        {  0,  -1 },
        { +1,  -1 },
        { +1,   0 },
        { +1,  +1 },
        {  0,  +1 },
        { -1,  +1 },
        { -1,   0 },
        { -1,  -1 },
    ];

    // While there are cursors to check
    while (cursors.length) {

        auto cursor = cursors.front;
        cursors.popFront;

        // We will iterate on all directions starting from the our current directions, away from it
        auto directions = neighbors
            .cycle.takeExactly(8*3)
            .radial(8 + cursor.direction)
            .take(7);

        // Remove the pixel from the queue
        unvisited.removeKey(cursor.end);

        bool addedCursors;

        // Failed to add cursors, add to result.
        scope (exit) if (!addedCursors) {

            result ~= Line(cursor.points, cursor.directionCount[].maxIndex.to!int);

        }

        // Get other directions to check
        foreach (i, direction; directions.enumerate) {

            // How far from the original direction are we turning
            const distance = (i+1)/2;

            // Calculate the minimum intensity
            const localMin = max(
                cursor.intensity * (minIntensity + distance*intensityStep),
                minIntensity
            );

            const position = cursor.end + direction;

            // Check if within bounds
            if (position.x < 0 || position.y < 0) continue;
            if (position.x >= image.width || position.y >= image.height) continue;

            const intensity = image[position.x, position.y].r;

            image[position.x, position.y] = Color4f.zero;

            // Target pixel meets our requirements
            if (intensity >= minIntensity) {

                // 1 3 5 -> +1;  2 4 6 -> -1
                const directionMult = i % 2 * 2 - 1;
                const pointPosition = absolutePoints
                    ? position
                    : cursor.points[$-1] + direction;
                const newDirection = (cursor.direction + directionMult*distance) % neighbors.length;

                auto directionCount = cursor.directionCount;
                directionCount[newDirection]++;

                assert(directionMult == 1 || directionMult == -1);

                cursors ~= Cursor(
                    position,
                    cursor.intensity/2 + intensity/2,
                    cursor.points ~ pointPosition,
                    newDirection,
                    directionCount,
                );
                addedCursors = true;

            }

        }

    }

    return result;

}
