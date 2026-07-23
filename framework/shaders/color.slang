public float3 srgb_to_linear(float3 s)
{
    float3 low = s / 12.92;
    float3 high = pow((s + 0.055) / 1.055, 2.4);
    return select(s <= 0.04045, low, high);
}
