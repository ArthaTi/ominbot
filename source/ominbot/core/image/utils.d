module ominbot.core.image.utils;

import std.conv;
import std.algorithm;
import std.exception;

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

            const aPixel = a[ax, ay];
            const bPixel = (cast() b.img)[bx, by];

            a[ax, ay] = combinePixels(aPixel, bPixel);

        }

    }

}

/// Mixes two pixels into one, placing pixel B over pixel A.
///
/// If pixel B is opaque, will return pixel B.
Color4f combinePixels(Color4f a, Color4f b) {

    const black = vec4(0, 0, 0, 1);

    const aAlpha = a[3];
    const aTransparent = a * vec4(1, 1, 1, 0);

    const bAlpha = b[3];
    const bTransparent = b * vec4(1, 1, 1, 0);

    return Color4f(
        + aTransparent * (1 - bAlpha)
        + bTransparent * bAlpha
        + black * max(aAlpha, bAlpha)
    );

}

/// Upscale the image with the nearest-neighbor algorithm.
SuperImage upscale(SuperImage a, uint scale) {

    auto output = a.createSameFormat(a.width * scale, a.height * scale);

    foreach (y; 0..a.height)
    foreach (x; 0..a.width) {

        const outputX = scale * x;
        const outputY = scale * y;

        foreach (yy; outputY .. outputY + scale)
        foreach (xx; outputX .. outputX + scale) {

            output[xx, yy] = a[x, y];

        }

    }

    return output;

}

/// Downscale the given image to target size.
SuperImage downscale(SuperImage input, uint w, uint h) @trusted {

    import std.math, std.algorithm;

    /// Input pixels per output pixel
    const pixelsX = ceil(cast(float) input.width / w).to!uint;
    const pixelsY = ceil(cast(float) input.height / h).to!uint;
    const pixelDensity = pixelsX * pixelsY;

    auto output = input.createSameFormat(w, h);

    foreach (ref pixel, x, y; output) {

        auto sumPixel = Color4f(0, 0, 0, 1);

        foreach (iy; pixelsY*y .. pixelsY*y + pixelsY)
        foreach (ix; pixelsX*x .. pixelsX*x + pixelsX) {

            const inputPixel = input[ix, iy];

            sumPixel += inputPixel;

        }

        pixel = sumPixel / pixelDensity;

    }

    return output;

}

/// Downscale the given image to target size, getting the maximum value for each channel.
SuperImage downscaleMax(SuperImage input, uint w, uint h) @trusted {

    import std.math, std.algorithm;

    /// Input pixels per output pixel
    const pixelsX = ceil(cast(float) input.width / w).to!uint;
    const pixelsY = ceil(cast(float) input.height / h).to!uint;
    const pixelDensity = pixelsX * pixelsY;

    auto output = input.createSameFormat(w, h);

    foreach (ref pixel, x, y; output) {

        foreach (iy; pixelsY*y .. pixelsY*y + pixelsY)
        foreach (ix; pixelsX*x .. pixelsX*x + pixelsX) {

            const inputPixel = input[ix, iy];

            pixel = Color4f(
                max(pixel.r, inputPixel.r),
                max(pixel.g, inputPixel.g),
                max(pixel.b, inputPixel.b),
            );

        }

    }

    return output;

}

class ImageException : Exception {

    mixin basicExceptionCtors;

}
