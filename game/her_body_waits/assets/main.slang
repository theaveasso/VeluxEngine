import voxel;
import color;

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
    float4 world_offset;
    uint *scene;
}

[vk_push_constant]
Push_Constants pc;

static const float3 SUN_DIRECTION = normalize(float3(0.42, 0.82, 0.38));
static const float3 SUN_COLOR = float3(1.00, 0.94, 0.80) * 2.6;
static const float3 SKY_ZENITH = float3(0.24, 0.42, 0.78);
static const float3 SKY_HORIZON = float3(0.78, 0.84, 0.92);
static const float3 GROUND_BOUNCE = float3(0.32, 0.27, 0.21);
static const int SHADOW_STEPS = 384;
static const float EXPOSURE = 0.85;

float3 sky_color(float3 direction)
{
    float height = direction.y * 0.5 + 0.5;
    float3 base = lerp(GROUND_BOUNCE, SKY_HORIZON, smoothstep(0.42, 0.52, height));
    base = lerp(base, SKY_ZENITH, saturate((height - 0.5) * 2.0));

    float disc = pow(saturate(dot(direction, SUN_DIRECTION)), 512.0);
    return base + SUN_COLOR * disc;
}

float3 tonemap(float3 value)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return saturate((value * (a * value + b)) / (value * (c * value + d) + e));
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
    PS_Output output;

    float4 near_h = mul(pc.inv_view_proj, float4(input.ndc, 0.0, 1.0));
    float4 far_h = mul(pc.inv_view_proj, float4(input.ndc, 1.0, 1.0));
    float3 near_p = near_h.xyz / near_h.w;
    float3 far_p = far_h.xyz / far_h.w;
    float3 direction = normalize(far_p - near_p);

    float voxel_size = pc.cam_pos.w;
    float3 origin = pc.cam_pos.xyz / voxel_size + pc.world_offset.xyz;

    Voxel_World world = { pc.scene, pc.dims.xyz, 0 };
    Voxel_Hit hit = voxel_raycast(world, origin, direction, pc.dims.w);

    if (!hit.hit)
    {
        output.frag_color = float4(tonemap(sky_color(direction) * EXPOSURE), 1.0);
        return output;
    }

    float3 albedo = srgb_to_linear(palette_color(world, hit.voxel));
    float occlusion = voxel_face_ao(world, hit.cell, hit.normal, hit.position);
    float ambient_strength = lerp(0.28, 1.0, occlusion);

    float n_dot_l = max(dot(hit.normal, SUN_DIRECTION), 0.0);
    float shadow = 1.0;
    if (n_dot_l > 0.0)
    {
        float3 shadow_origin = hit.position + hit.normal * 0.05;
        Voxel_Hit blocker = voxel_raycast(world, shadow_origin, SUN_DIRECTION, SHADOW_STEPS);
        shadow = blocker.hit ? 0.0 : 1.0;
    }

    float3 ambient = lerp(GROUND_BOUNCE, SKY_HORIZON, hit.normal.y * 0.5 + 0.5);
    float3 lit = albedo * (ambient * ambient_strength * 0.7 + SUN_COLOR * n_dot_l * shadow);

    float distance_metres = hit.distance * voxel_size;
    float fog = 1.0 - exp(-distance_metres * 0.012);
    lit = lerp(lit, sky_color(direction), fog);

    output.frag_color = float4(tonemap(lit * EXPOSURE), 1.0);
    return output;
}
