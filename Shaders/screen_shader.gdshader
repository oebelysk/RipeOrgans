shader_type canvas_item;

uniform float shake: hint_range(0, 10) = 0.015;
uniform float noiseQuality: hint_range(0.1, 250, 0.1) = 250;
uniform float noiseIntensity: hint_range(0, 0.05, 0.001) = 0.001;
uniform float offsetIntensity: hint_range(0, 0.05, 0.0001) = 0.0045;
uniform float colorOffsetIntensity: hint_range(0.1, 1.5, 0.001) = 0.2;
uniform float pixelSize: hint_range(1, 1024) = 200.0;
uniform float grainIntensity: hint_range(0, 1) = 0.04; // Intensity of film grain

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D overlay_texture : hint_default_transparent;
uniform bool use_overlay = true; // Toggle for using overlay texture
uniform bool use_lens_distortion = true; // Toggle for using lens distortion

uniform vec4 overlay_color : source_color = vec4(1.0, 1.0, 1.0, 10.0); // Allow changing overlay color
uniform float lens_distortion_strength: hint_range(0, 0.1) = 0.05; // Strength of lens distortion effect

varying vec2 previous_pos; // Previous fragment position

float rand(vec2 co)
{
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float verticalBar(float pos, float uvY, float offset)
{
    float edge0 = (pos - shake);
    float edge1 = (pos + shake);

    float x = smoothstep(edge0, pos, uvY) * offset;
    x -= smoothstep(pos, edge1, uvY) * offset;
    return x;
}

void fragment() {
    vec2 iResolution = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 uv = FRAGCOORD.xy / iResolution.xy;

    // Calculate velocity
    vec2 velocity = uv - previous_pos;

    // Add color offset distortion
    vec2 offsetR = vec2(0.006 * sin(TIME), 0.0) * colorOffsetIntensity;
    vec2 offsetG = vec2(0.0073 * cos(TIME * 0.97), 0.0) * colorOffsetIntensity;

    float r = texture(screen_texture, uv + offsetR).r;
    float g = texture(screen_texture, uv + offsetG).g;
    float b = texture(screen_texture, uv).b;

    vec4 tex = vec4(r, g, b, 1.0);

    // Add film grain
    float grain = rand(uv * TIME) * 2.0 - 1.0; // Range from -1 to 1
    tex.rgb += grainIntensity * grain;


    // Apply final color
    COLOR = tex;

    // Store current position for next frame
    previous_pos = FRAGCOORD.xy / iResolution.xy;
}
