public float3 tonemap_reinhard(float3 color)
{
    return color / (color + 1.0);
}

public float3 tonemap_aces(float3 color)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return saturate((color * (a * color + b)) / (color * (c * color + d) + e));
}

float3 agx_default_contrast_approximation(float3 x)
{
    float3 x2 = x * x;
    float3 x4 = x2 * x2;
    float3 x6 = x4 * x2;
    return 15.5 * x6 - 40.14 * x4 * x + 31.96 * x4 - 6.868 * x2 * x + 0.4298 * x2 + 0.1191 * x - 0.00232;
}

float3 mul_matrix3x3(float3x3 m, float3 v)
{
    float3 result = float3(
        m[0][0] * v.x + m[0][1] * v.y + m[0][2] * v.z,
        m[1][0] * v.x + m[1][1] * v.y + m[1][2] * v.z,
        m[2][0] * v.x + m[2][1] * v.y + m[2][2] * v.z);
    return result;
}

public float3 tonemap_agx(float3 color)
{
    float3x3 input_matrix = float3x3(
        0.842479062253094, 0.042328258469531, 0.042375654905705,
        0.078433614410084, 0.878468636469772, 0.078433614410084,
        0.079142846350375, 0.079166127460543, 0.879142846350375);

    float3x3 output_matrix = float3x3(
        1.19687900512017, -0.052896851757456, -0.052971635514443,
        -0.098020881140136, 1.15190312990417, -0.098043450117124,
        -0.099029744079720, -0.098961176844950, 1.15107545118753);

    color = mul_matrix3x3(input_matrix, color);
    color = clamp(
        log2(max(color, float3(1e-6))),
        -12.47393,
        4.026069);

    color = (color + 12.47393) / (4.026069 + 12.47393);
    color = agx_default_contrast_approximation(color);

    color = mul_matrix3x3(output_matrix, color);
    color = pow(clamp(color, 0.0, 1.0), float3(2.2));

    return color;
}

public float3 tonemap(float3 color, int mode)
{
    switch (mode)
    {
    case 0:
        return tonemap_reinhard(color);
    case 1:
        return tonemap_aces(color);
    default:
        return tonemap_agx(color);
    }
}
