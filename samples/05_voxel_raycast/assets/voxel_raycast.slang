struct V2P
{
    float4 pos : SV_Position;
    float2 ndc : TEXCOORD0;
}

struct PS_Output
{
    [vk_location(0)]
    float4 frag_color : COLOR0;
}

struct Push_Constants
{
    float4x4 inv_view_proj;
    float4 cam_pos;
    int4 dims;
    float4 sun_direction;
    uint *voxels;
    int32_t tonemap_mode;
}

[vk_push_constant]
Push_Constants pc;

static const float3 BLOCK_PALETTE[6] = {
    float3(0.00, 0.00, 0.00),
    float3(0.45, 0.62, 0.28),
    float3(0.48, 0.35, 0.24),
    float3(0.42, 0.30, 0.19),
    float3(0.30, 0.48, 0.22),
    float3(0.55, 0.55, 0.58),
};

static const float3 sky_warm = float3(0.45, 0.55, 0.78);
static const float3 ground_warm = float3(0.40, 0.35, 0.18);
static const float3 sun_color = float3(1.00, 0.78, 0.45);

int voxel_index(int x, int y, int z)
{
    return x + y * pc.dims.x + z * pc.dims.x * pc.dims.y;
}

uint voxel_at(int3 c)
{
    if (any(c < 0) || any(c >= pc.dims.xyz))
    {
        return 0;
    }
    return pc.voxels[voxel_index(c.x, c.y, c.z)];
}

float solid(int3 c)
{
    return voxel_at(c) != 0 ? 1.0 : 0.0;
}

float corner_ao(float s1, float s2, float cn)
{
    if (s1 > 0.5 && s2 > 0.5)
    {
        return 0.0;
    }
    return 3.0 - (s1 + s2 + cn);
}

float face_ao(int3 c, float3 N, float3 hit_p)
{
    int3 n = int3(N);
    int3 front = c + n;

    int3 ta, tb;
    if (n.x != 0)
    {
        ta = int3(0, 1, 0);
        tb = int3(0, 0, 1);
    }
    else if (n.y != 0)
    {
        ta = int3(1, 0, 0);
        tb = int3(0, 0, 1);
    }
    else
    {
        ta = int3(1, 0, 0);
        tb = int3(0, 1, 0);
    }

    float a00 = corner_ao(solid(front - ta), solid(front - tb), solid(front - ta - tb));
    float a10 = corner_ao(solid(front + ta), solid(front - tb), solid(front + ta - tb));
    float a01 = corner_ao(solid(front - ta), solid(front + tb), solid(front - ta + tb));
    float a11 = corner_ao(solid(front + ta), solid(front + tb), solid(front + ta + tb));

    float3 f = frac(hit_p);
    float u = dot(f, float3(abs(ta)));
    float v = dot(f, float3(abs(tb)));

    float ao = lerp(lerp(a00, a10, u), lerp(a01, a11, u), v);
    return ao / 3.0;
}

bool in_shadow(float3 origin, float3 dir)
{
    int3 c = int3(floor(origin));
    int3 step = int3(sign(dir));
    float3 t_delta = abs(1.0 / dir);
    float3 t_max = (float3(c) + max(float3(step), 0.0) - origin) / dir;

    for (int i = 0; i < 256; i++)
    {
        if (voxel_at(c) != 0)
        {
            return true;
        }
        if (t_max.x < t_max.y && t_max.x < t_max.z)
        {
            c.x += step.x;
            t_max.x += t_delta.x;
        }
        else if (t_max.y < t_max.z)
        {
            c.y += step.y;
            t_max.y += t_delta.y;
        }
        else
        {
            c.z += step.z;
            t_max.z += t_delta.z;
        }
    }
    return false;
}

float3 srgb_to_linear(float3 s)
{
    float3 low = s / 12.92;
    float3 high = pow((s + 0.055) / 1.055, 2.4);
    return select(s <= 0.04045, low, high);
}

float3 tonemap_reinhard(float3 color)
{
    return color / (color + 1.0);
}

float3 tonemap_aces(float3 color)
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
    return float3(
        m[0][0] * v.x + m[0][1] * v.y + m[0][2] * v.z,
        m[1][0] * v.x + m[1][1] * v.y + m[1][2] * v.z,
        m[2][0] * v.x + m[2][1] * v.y + m[2][2] * v.z);
}

float3 tonemap_agx(float3 color)
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

float3 tonemap(float3 color, int mode)
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

[shader("vertex")]
V2P vertex_main(uint id: SV_VertexID)
{
    float2 uv = float2((id << 1) & 2, id & 2);

    V2P output;
    output.pos = float4(uv * 2.0 - 1.0, 0.0, 1.0);
    output.ndc = output.pos.xy;
    return output;
}

[shader("fragment")]
PS_Output fragment_main(V2P input)
{
    float exposure = pc.sun_direction.w;
    float tonemap_mode = pc.tonemap_mode;

    float4 near_h = mul(pc.inv_view_proj, float4(input.ndc, 0.0, 1.0));
    float4 far_h = mul(pc.inv_view_proj, float4(input.ndc, 1.0, 1.0));
    float3 near_p = near_h.xyz / near_h.w;
    float3 far_p = far_h.xyz / far_h.w;
    float3 dir = normalize(far_p - near_p);

    float3 g_origin = pc.cam_pos.xyz / pc.cam_pos.w + float3(pc.dims.xyz) * 0.5;
    float3 g_dir = dir;

    int3 c = int3(floor(g_origin));
    int3 step = int3(sign(g_dir));
    float3 t_delta = abs(1.0 / g_dir);
    float3 t_max = (float3(c) + max(float3(step), 0.0) - g_origin) / g_dir;
    int last_axis = -1;

    float t_hit = 0.0;

    PS_Output output;

    for (int i = 0; i < pc.dims.w; i++)
    {
        int voxel = voxel_at(c);
        if (voxel != 0)
        {
            float3 L = normalize(pc.sun_direction.xyz);
            float3 N = float3(0, 0, 0);
            if (last_axis == 0)
            {
                N.x = float(-step.x);
            }
            if (last_axis == 1)
            {
                N.y = float(-step.y);
            }
            if (last_axis == 2)
            {
                N.z = float(-step.z);
            }

            float3 hit_p = g_origin + g_dir * t_hit;
            float ao = face_ao(c, N, hit_p);
            float ao_b = lerp(0.35, 1.0, ao);

            float3 sp = hit_p + N * 0.02;
            float ndl = max(dot(N, L), 0.0);
            float shadow = (ndl > 0.0 && in_shadow(sp, L)) ? 0.0 : 1.0;

            float3 ambient = lerp(srgb_to_linear(ground_warm), srgb_to_linear(sky_warm), N.y * 0.5 + 0.5);
            float3 sun = srgb_to_linear(sun_color) * ndl * shadow;
            float3 albedo = srgb_to_linear(BLOCK_PALETTE[voxel]);
            float3 color = albedo * (ambient * ao_b + sun);

            color *= exp2(exposure);

            output.frag_color = float4(tonemap(color, int(tonemap_mode)), 1);
            return output;
        }
        if (t_max.x < t_max.y && t_max.x < t_max.z)
        {
            t_hit = t_max.x;
            c.x += step.x;
            t_max.x += t_delta.x;
            last_axis = 0;
        }
        else if (t_max.y < t_max.z)
        {
            t_hit = t_max.y;
            c.y += step.y;
            t_max.y += t_delta.y;
            last_axis = 1;
        }
        else
        {
            t_hit = t_max.z;
            c.z += step.z;
            t_max.z += t_delta.z;
            last_axis = 2;
        }
    }

    output.frag_color = float4(0.05, 0.05, 0.1, 1.0);
    return output;
}
