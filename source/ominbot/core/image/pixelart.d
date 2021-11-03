module ominbot.core.image.pixelart;

import dlib.image;

import std.uni;
import std.format;
import std.random;
import std.algorithm;
import std.exception;

import ominbot.core.image.card;
import ominbot.core.image.edges;
import ominbot.core.image.utils;


@safe:



/// Pixel art generator learning by edge detection.
class PixelArtGenerator {

    enum outputSize = Position(102, 76);
    enum shapeStart = outputSize/4;

    Line[][4][string] data;

    /// Add lines to model for the given key.
    void feed(string key, Line[] lines) {

        import std.math, std.range;

        Line[][4] collection;

        // Make the key case-insensitive
        key = key.toLower;

        // Group lines by orientation
        foreach (lineLong; lines) {

            // Scale the line down and chunk it if it's still too big
            auto lineChunks = lineLong.scaleDown(1.0 * outputSize.y / edgeDetectionSize).chunks(15);

            // Add the line
            foreach (i, line; lineChunks.enumerate) {

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
    void generate(SuperImage output, string key) const {

        import std.stdio;

        const corner = addShape(output, key);
        fillShape(output, corner, ColorPalette.init.primary);

    }

    /// Add some shape to the given image.
    /// Returns: Position of the third corner of the image. Used to locate image center in order to fill it.
    Position addShape(SuperImage output, string key) const {

        const borderColor = ColorPalette.init.line;

        const entryPtr = key.toLower in data;

        enforce!ImageException(entryPtr, key.format!"No data in the image model for key '%s'");

        auto entry = cast() *entryPtr;

        enforce!ImageException(entry[0].length || entry[2].length,
            key.format!"No horizontal data in the image model for key '%s'");
        enforce!ImageException(entry[1].length || entry[3].length,
            key.format!"No vertical data in the image model for key '%s'");

        Position end = shapeStart;
        Position thirdCorner;
        auto direction = 0;
        auto ended = false;

        // If the line wasn't finished after the process ended
        scope (exit) if (!ended) () @trusted {

            // Connect the ends
            output.drawLine(borderColor, shapeStart.tupleof, end.tupleof);

        }();

        // Lay lines until the shape is finished
        while (direction < 4) {

            const lineSet = entry[direction];
            const line = lineSet.length
                ? entry[direction].choice
                : entry[(direction+2)%4].choice.reverse;

            const drawnLine = output.drawLine(end, line, borderColor);

            // Check if the line ended
            if (!ended && direction != 0) {

                ended = drawnLine.canFind(shapeStart);

            }

            end += line[$-1];

            debug assert(direction.predSwitch(
                0, line[$-1].x >= 0,
                1, line[$-1].y >= 0,
                2, line[$-1].x <= 0,
                3, line[$-1].y <= 0,
            ), format!"line %s has an invalid direction"(line));

            direction += cast(int) direction.predSwitch(
                0, end.x >= outputSize.x * 3 / 4,
                1, end.y >= outputSize.y * 3 / 4,
                2, end.x <= outputSize.x * 1 / 4,
                3, end.y <= outputSize.y * 1 / 4,
            );

            if (direction == 3) thirdCorner = end;

        }

        return thirdCorner;

    }

    /// Fill the shape by iterating looking for an empty pixel between first and third corner and filling everything
    /// that can be found.
    void fillShape(SuperImage output, Position thirdCorner, Color4f color) @trusted const {

        import std.container;

        DList!Position queue;

        // Find pixels to fill, ignore if not found
        try queue ~= findEmpty(output, thirdCorner);
        catch (ImageException) return;

        // Run until the queue is emptied
        while (!queue.empty) {

            auto top = queue.front;
            queue.removeFront;

            // Ignore colored pixels
            if (output[top.x, top.y].a != 0) continue;

            // Draw
            output[top.x, top.y] = color;

            // Add neighbors
            foreach (neighbor; [
                Position(+1,  0),
                Position( 0, +1),
                Position(-1,  0),
                Position( 0, -1),
            ]) {

                auto position = top + neighbor;

                // Ignore if out of bounds
                if (position.x < 0 || position.y < 0) continue;
                if (position.x >= output.width || position.y >= output.height) continue;

                queue ~= position;

            }

        }

    }

    /// Find an empty pixel in a line.
    /// Throws: `ImageException` if not found.
    private Position findEmpty(SuperImage output, Position thirdCorner) @trusted const {

        import std.math;

        /// Number of pixels to be travelled
        const incrementPer = thirdCorner / shapeStart;

        // Current iterator position
        auto position = shapeStart;

        // Counter of changes per pixel
        Position counter;

        while (position != thirdCorner) {

            // count the position
            counter += 1;

            // Update position
            if (counter.x >= incrementPer.x && position.x != thirdCorner.x) {
                position.x += sgn(thirdCorner.x - position.x);
                counter.x = 0;
            }
            if (counter.y >= incrementPer.y && position.x != thirdCorner.x) {
                position.y += sgn(thirdCorner.y - position.y);
                counter.y = 0;
            }

            // Check if empty
            if (output[position.tupleof].a == 0) return position;

        }

        throw new ImageException("No empty pixel found in image.");

    }

}

@system
unittest {

    auto gen = new PixelArtGenerator;

    foreach (key; ["gold", "lemon"]) {

        auto file = key.format!"resources/unittest-%s.png";
        auto source = loadImage(file);
        auto output = image(PixelArtGenerator.outputSize.tupleof, 4);

        gen.feed(key, source.findBorders);

        gen.generate(output, key);
        output.savePNG(key.format!"resources/bot-unittest-pixelart-%s.png");

    }

    ItemCard card = {
        id: 123,
        name: ["gold", "lemon"],
        palette: ColorPalette(
            color3(0xfbcb4e),
            color3(0xeeaa33),
        )
    };

    card.render(gen).savePNG("resources/bot-unittest-pixelart-card.png");

}
