public float3 srgb_to_linear(float3 srgb)
{
    float3 low = srgb / 12.92;
    float3 high = pow((srgb + 0.055) / 1.055, 2.4);
    return select(srgb <= 0.04045, low, high);
}

public float3 rgb_to_hsv(float3 rgb)
{
    float max_channel = max(rgb.r, max(rgb.g, rgb.b));
    float min_channel = min(rgb.r, min(rgb.g, rgb.b));
    float range = max_channel - min_channel;

    float hue = 0.0;
    if (range > 0.0)
    {
        if (max_channel == rgb.r)
        {
            hue = (rgb.g - rgb.b) / range;
        }
        else if (max_channel == rgb.g)
        {
            hue = 2.0 + (rgb.b - rgb.r) / range;
        }
        else
        {
            hue = 4.0 + (rgb.r - rgb.g) / range;
        }
        hue = frac(hue / 6.0);
    }

    float saturation = select(max_channel > 0.0, range / max_channel, 0.0);
    return float3(hue, saturation, max_channel);
}
public float3 hsv_to_rgb(float3 hsv)
{
    float hue = hsv.x * 6.0;
    float saturation = hsv.y;
    float value = hsv.z;

    float chroma = value * saturation;
    float hue_mod2 = hue - 2.0 * floor(hue * 0.5);
    float second = chroma * (1.0 - abs(hue_mod2 - 1.0));
    float offset = value - chroma;

    float3 rgb;
    if (hue < 1.0)
    {
        rgb = float3(chroma, second, 0.0);
    }
    else if (hue < 2.0)
    {
        rgb = float3(second, chroma, 0.0);
    }
    else if (hue < 3.0)
    {
        rgb = float3(0.0, chroma, second);
    }
    else if (hue < 4.0)
    {
        rgb = float3(0.0, second, chroma);
    }
    else if (hue < 5.0)
    {
        rgb = float3(second, 0.0, chroma);
    }
    else
    {
        rgb = float3(chroma, 0.0, second);
    }

    return rgb + offset;
}
