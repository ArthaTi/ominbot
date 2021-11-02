module ominbot.core.image.pixelart;

import dlib.image;

import std.format;
import std.random;
import std.exception;
import std.algorithm;

import ominbot.core.image.edges;
import ominbot.core.image.utils;


@safe:


/// Pixel art generator learning by edge detection.
class PixelArtGenerator {

    Line[][4][string] data;

    /// Add lines to model for the given key.
    void feed(string key, Line[] lines) {

        import std.math, std.range;

        Line[][4] collection;

        // Group lines by orientation
        foreach (lineLong; lines) {

            // Chunk the line if it's over 15 pixels long
            foreach (i, line; lineLong.chunks(15).enumerate) {

                const firstPoint = line[0];

                // Make the line relative
                if (i) line = line.map!(a => a - firstPoint).array;

                const lastPoint  = line[$-1];
                const horizontal = abs(lastPoint.x) > abs(lastPoint.y);
                const direction  = horizontal
                    ? (lastPoint.x > 0 ? 0 : 2)
                    : (lastPoint.y > 0 ? 1 : 3);
                // Direction is clockwise, starting from right

                collection[direction] ~= line;

            }

        }

        // Key already exists
        if (auto entry = key in data) {

            // Add each line
            foreach (i; 0..4) {

                (*entry)[i] ~= collection[i];

            }

        }

        // Add the data
        else data[key] = collection;

    }

    /// Generate an image for given key.
    /// Throws: `ImageException` if there wasn't enough data in the model to make an image.
    SuperImage generate(string key) @trusted {

        import std.stdio;

        auto entryPtr = key in data;

        enforce!ImageException(entryPtr, key.format!"No data in the image model for key '%s'");

        auto entry = *entryPtr;

        enforce!ImageException(entry[0].length || entry[2].length,
            key.format!"No horizontal data in the image model for key '%s'");
        enforce!ImageException(entry[1].length || entry[3].length,
            key.format!"No vertical data in the image model for key '%s'");

        auto output = image(edgeDetectionSize, edgeDetectionSize, 4);

        // Lay a shape
        {

            auto end = Position(edgeDetectionSize/4, edgeDetectionSize/4);

            auto direction = 0;

            // Lay lines until the shape is finished
            while (direction < 4) {

                const lineSet = entry[direction];
                const line = lineSet.length
                    ? entry[direction].choice
                    : entry[(direction+2)%4].choice.reverse;
                const start = end;

                end += line[$-1];

                debug assert(direction.predSwitch(
                    0, line[$-1].x >= 0,
                    1, line[$-1].y >= 0,
                    2, line[$-1].x <= 0,
                    3, line[$-1].y <= 0,
                ), format!"line %s has an invalid direction"(line));

                output.drawLine(start, line, Color4f(1, 1, 1, 1));

                direction += cast(int) direction.predSwitch(
                    0, end.x >= edgeDetectionSize * 3 / 4,
                    1, end.y >= edgeDetectionSize * 3 / 4,
                    2, end.x <= edgeDetectionSize * 1 / 4,
                    3, end.y <= edgeDetectionSize * 1 / 4,
                );

            }

        }


        return output;

    }

}

@system
unittest {

    auto gen = new PixelArtGenerator;

    foreach (key; ["gold", "lemon"]) {

        auto file = key.format!"resources/unittest-%s.png";
        auto source = loadImage(file);

        gen.feed(key, source.findBorders);

        gen.generate(key).savePNG(key.format!"resources/bot-unittest-pixelart-%s.png");

    }

}
