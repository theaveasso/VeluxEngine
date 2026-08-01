public static const float FAR_AWAY = 1e9;

public struct Sky_Palette
{
    public float3 horizon;
    public float3 zenith;
}

public Sky_Palette sky_palette_night()
{
    Sky_Palette palette;
    palette.horizon = float3(0.0100, 0.0153, 0.0331);
    palette.zenith = float3(0.0016, 0.0023, 0.0060);
    return palette;
}

public Sky_Palette sky_palette_day()
{
    Sky_Palette palette;
    palette.horizon = float3(0.4771, 0.6383, 0.8900);
    palette.zenith = float3(0.0509, 0.1707, 0.6921);
    return palette;
}

public Sky_Palette sky_palette_lerp(Sky_Palette a, Sky_Palette b, float t)
{
    Sky_Palette palette;
    palette.horizon = lerp(a.horizon, b.horizon, t);
    palette.zenith = lerp(a.zenith, b.zenith, t);
    return palette;
}

public float3 sky_gradient(float3 direction, Sky_Palette palette)
{
    float height = saturate(direction.y * 0.5 + 0.5);
    return lerp(palette.horizon, palette.zenith, smoothstep(0.35, 1.0, height));
}

public float3 sky_disc(float3 direction, float3 light_direction, float3 light_color, float sharpness, float intensity)
{
    float alignment = saturate(dot(direction, light_direction));
    return light_color * pow(alignment, sharpness) * intensity;
}

public float ground_plane_hit(float3 origin, float3 direction, float height)
{
    if (direction.y >= -0.0001) return FAR_AWAY;

    float distance = (height - origin.y) / direction.y;
    return distance > 0.0 ? distance : FAR_AWAY;
}

public float3 grid_albedo(float3 position, float cell_size, float3 base_color, float3 line_color)
{
    float2 coordinate = position.xz / cell_size;
    float2 derivative = fwidth(coordinate);
    float2 distance_in_pixels = abs(frac(coordinate - 0.5) - 0.5) / derivative;

    float line_mask = 1.0 - saturate(min(distance_in_pixels.x, distance_in_pixels.y));
    return lerp(base_color, line_color, line_mask);
}

public float3 apply_fog(float3 lit, float3 sky, float distance, float density)
{
    float amount = 1.0 - exp(-distance * density);
    return lerp(lit, sky, amount);
}
