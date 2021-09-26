module ominbot.core.image.utils;

import std.conv;
import std.algorithm;

import dlib.math;
import dlib.image;

/// Combine two images. Modifies the first image in place.
void addImage(SuperImage a, const ImageRegion b, uint offsetX, uint offsetY, float scale = 1) @trusted {

    foreach (y; 0 .. to!int(b.height * scale)) {

        const ay = y + offsetY;
        const by = b.ystart + to!int(y / scale);

        if (ay >= a.height) break;

        foreach (x; 0 .. to!int(b.width * scale)) {

            const ax = x + offsetX;
            const bx = b.xstart + to!int(x / scale);

            if (ax >= a.width) break;

            const black = vec4(0, 0, 0, 1);

            const aPixel = a[ax, ay];
            const aAlpha = aPixel[3];
            const aTransparent = aPixel * vec4(1, 1, 1, 0);

            const bPixel = (cast() b.img)[bx, by];
            const bAlpha = bPixel[3];
            const bTransparent = bPixel * vec4(1, 1, 1, 0);

            a[ax, ay] = Color4f(
                + aTransparent * (1 - bAlpha)
                + bTransparent * bAlpha
                + black * max(aAlpha, bAlpha)
            );

        }

    }

}
