import color;

public float3 sky_color(float3 direction, float3 sun_direction)
{
    float h = saturate(direction.y);

    float3 horizon = srgb_to_linear(float3(0.80, 0.88, 1.00));
    float3 sky = srgb_to_linear(float3(0.08, 0.16, 0.38));
    float3 zenith = srgb_to_linear(float3(0.015, 0.035, 0.12));

    float3 color;

    if (h < 0.5)
    {
        float t = h / 0.5;
        color = lerp(horizon, sky, t);
    }
    else
    {
        float t = (h - 0.5) / 0.5;
        color = lerp(sky, zenith, t);
    }

    float s = max(
        dot(direction, normalize(sun_direction)),
        0.0);

    float3 sun_color = srgb_to_linear(float3(1.0, 0.45, 0.15));

    color += sun_color * pow(s, 8.0) * 0.15;
    color += sun_color * pow(s, 512.0) * 4.0;
    return color;
}
