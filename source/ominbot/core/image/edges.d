/// Performs edge detection.
module ominbot.core.image.edges;

import std.conv;
import std.range;
import std.traits;
import std.algorithm;
import std.container;

import dlib.math;
import dlib.image;

import ominbot.core.image.utils;

// TODO: convert images to PNG with ffmpeg or smth else after download, JPGs are troublesome.


@safe:


enum edgeDetectionSize = 128;

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

    Position opBinary(string op, T)(T other) const
    if (isNumeric!T) {

        import std.format;

        return Position(
            cast(int) mixin(op.format!"x %s other"),
            cast(int) mixin(op.format!"y %s other"),
        );

    }

    unittest {

        assert(Position(3, 2) / size_t(2) == Position(1, 1));

    }

    Position opOpAssign(string op)(const Position other) {

        import std.format;

        mixin(op.format!"x %s= other.x;");
        mixin(op.format!"y %s= other.y;");

        return this;

    }

}

alias Line = const(Position)[];

Line reverse(const Line line) {

    const lastPoint = line[$-1];

    Line result;
    return line.retro
        .map!(a => a - lastPoint)
        .array;

}

unittest {

    Line line = [
        Position(0, 0),
        Position(10, 0),
        Position(20, 0),
        Position(20, 10)
    ];

    assert(line.reverse == [
        Position(0, 0),
        Position(0, -10),
        Position(-10, -10),
        Position(-20, -10),
    ]);

    assert(line.reverse.reverse == line);

}

Line scaleDown(const Line line, float scale) {

    const chunkCount = to!int(1/scale).max(1);

    Position lastPosition;
    Position accumulator;
    Line result = [Position()];

    foreach (chunk; line[1..$].chunks(chunkCount)) {

        scope (exit) {

            result ~= accumulator / chunkCount + result[$-1];
            accumulator = Position();

        }

        foreach (point; chunk) {

            accumulator += point - lastPosition;
            lastPosition = point;

        }

    }


    return result;

}

unittest {

    Line line1 = [
        Position(0, 0),
        Position(1, 0),
        Position(2, 0),
        Position(2, 1),
        Position(2, 2),
    ];

    assert(line1.scaleDown(0.5) == [
        Position(0, 0),
        Position(1, 0),
        Position(1, 1),
    ]);

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
            .sort!("a.length < b.length");

        foreach (line; lines) {

            newImage.drawLine(Position(), line, Color4f(1, 1, 1, 0.1));

        }

        newImage
            .downscaleMax(32, 32)
            .savePNG("resources".buildPath("bot-" ~ path.baseName));

    }

}

void drawLine(SuperImage image, Position position, Line line, Color4f color) @trusted {

    foreach (point; line) {

        auto p = position + point;
        auto previous = image[p.x, p.y];

        if (p.x < 0 || p.y < 0) continue;
        if (p.x >= image.width || p.y >= image.height) continue;

        image[p.x, p.y] = alphaOver(previous, color);

    }

}

/// Find lines in the image starting from some point in the tree.
private Line[] findLines(bool absolutePoints = false)(SuperImage image, RedBlackTree!Position unvisited, Position start)
    @trusted
do {

    enum minIntensityMult = 0.7;
    enum minIntensity = 0.25;

    enum intensityStep = (1 - minIntensityMult) / 3;

    struct Cursor {

        Position end;
        float intensity;

        Line line = [Position(0, 0)];
        size_t direction = 0;

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

            result ~= cursor.line;

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
                    : cursor.line[$-1] + direction;
                const newDirection = (cursor.direction + directionMult*distance) % neighbors.length;

                assert(directionMult == 1 || directionMult == -1);

                cursors ~= Cursor(
                    position,
                    cursor.intensity/2 + intensity/2,
                    cursor.line ~ pointPosition,
                    newDirection,
                );
                addedCursors = true;

            }

        }

    }

    return result;

}
