/// Lets the bot *feel*...
///
/// Inspired by https://en.wikipedia.org/wiki/Emotion#Multi-dimensional_analysis
module ominbot.core.emotions;

import std.conv;
import std.math;
import std.traits;
import std.algorithm;

import ominbot.core.params;


@safe:


enum EmotionType {

    // Activated pleasant
    interest,
    amusement,
    pride,
    joy,
    pleasure,

    // Calm pleasant
    contentment,
    love,
    admiration,
    relief,
    compassion,

    // Calm unpleasant
    sadness,
    guilt,
    regret,
    shame,
    disappointment,

    // Activated unpleasant
    fear,
    disgust,
    contempt,
    hate,
    anger,

}

// TODO: dorcelessness and nage

/// Number of emotions known by omin.
enum emotionCount = EnumMembers!EmotionType.length;

/// Length of the arc of any single emotion on the emotion wheel.
enum emotionStepArc = 2*PI / emotionCount;

/// Determines Omin's emotions.
struct Emotions {

    /// Angle of the emotion. In radians. See `name`.
    ///
    /// Angle can change quickly on low emotion intensity, but would barely be affected by input on high intensity.
    double angle = 0;

    /// Intensity of the emotion. This is a value from -255 to 255.
    short intensity;

    /// Normalize the `angle`.
    void normalize() {

        angle = angleNorm();

        // Make intensity positive
        if (intensity < 0) {

            angle = (angle + PI) % (2 * PI);
            intensity = to!short(intensity * -1);

        }

    }

    /// Return the current angle, normalized.
    double angleNorm() const
    out (r; r >= 0)
    out (r; r < 2 * PI)
    do {

        const circle = 2 * PI;

        // Reduce to 2π
        auto result = angle % circle;

        // Invert if negative
        if (result < 0) result = circle - result;

        return result % circle;

    }

    /// Ditto.
    EmotionType type() const
    out(r; r < emotionCount)
    do {

        Emotions clone = this;
        clone.normalize();

        return cast(EmotionType) floor(clone.angle / emotionStepArc);

    }

    /// Set the current emotion type.
    EmotionType type(EmotionType newValue) {

        angle = (newValue + 0.5) * emotionStepArc;
        normalize();

        return newValue;

    }

    unittest {

        Emotions e;
        e.type = EmotionType.interest;
        assert(e.type == EmotionType.interest);

        e.type = EmotionType.sadness;
        assert(e.type == EmotionType.sadness);

    }

    /// Get the current pleasure.
    short pleasure() const
    out (r; -255 <= r && r <= 255)
    do {

        return clamp(sin(angle) * intensity, -255, 255)
            .to!short;

    }

    /// Get the current activation.
    short activation() const
    out (r; -255 <= r && r <= 255)
    do {

        return clamp(cos(angle) * intensity, -255, 255)
            .to!short;

    }

    /// Change the emotions.
    /// Params:
    ///     changeX = Change on the X axis — positive values make the target happier, negative sadden them.
    ///     changeY = Change on the Y axis — positive values make the target more active, negative calm them down.
    void move(short changeX, short changeY) {

        // Get the current values
        const pleasureBefore = pleasure;
        const activationBefore = activation;

        // Update the angle
        const pleasureAfter = cast(float) clamp(pleasureBefore + changeX, -255, 255);
        const activationAfter = cast(float) clamp(activationBefore + changeY, -255, 255);
        const targetAngle = PI/2 - atan2(activationAfter / 255.0, pleasureAfter / 255.0);

        // Set the new angle
        const angleModifier = clamp(1 - intensity.abs/255.0, 0.1, 0.4);
        angle += (targetAngle - angle) * angleModifier;

        // Update the intensity
        const intensityChange = sin(angle) * changeX + cos(angle) * changeY;
        intensity = clamp(intensity + intensityChange, -255, 255).to!short;

    }

    /// Get a string representation of the state.
    string toString() const {

        import std.format;

        Emotions clone = this;
        clone.normalize();

        if (clone.intensity == 0) return "Emotions(none)";

        return format!"Emotions(%s°, %s%% %s)"(clone.angleNorm * 180 / PI, clone.intensity * 100 / 255, type);

    }

}
