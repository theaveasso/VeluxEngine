import color;
import tonemap;
import world;

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
    float4 sun;
    uint *scene;
}

[vk_push_constant]
Push_Constants pc;

static const float3 SUN_HIGH_COLOR = float3(1.00, 0.97, 0.90);
static const float3 SUN_LOW_COLOR = float3(1.00, 0.42, 0.14);
static const float3 MOON_COLOR = float3(0.75, 0.82, 1.00);

static const float SUN_DISC_SHARPNESS = 512.0;
static const float SUN_DISC_INTENSITY = 4.0;
static const float MOON_DISC_SHARPNESS = 2048.0;
static const float MOON_DISC_INTENSITY = 1.5;

static const float3 SUN_LIGHT_COLOR = float3(1.00, 0.95, 0.85);
static const float SUN_LIGHT_STRENGTH = 2.60;
static const float3 MOON_LIGHT_COLOR = float3(0.55, 0.65, 0.95);
static const float MOON_LIGHT_STRENGTH = 0.22;

static const float3 GROUND_BASE = float3(0.10, 0.11, 0.13);
static const float3 GROUND_LINE = float3(0.20, 0.22, 0.26);
static const float GRID_CELL_SIZE = 4.0;

static const float AMBIENT_STRENGTH = 0.5;
static const float FOG_DENSITY = 0.008;
static const float EXPOSURE = 1.0;

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
    float3 origin = pc.cam_pos.xyz;

    float3 sun_direction = pc.sun.xyz;
    float3 moon_direction = -sun_direction;
    float day = pc.sun.w;

    Sky_Palette palette = sky_palette_lerp(sky_palette_night(), sky_palette_day(), day);

    float3 sun_tint = lerp(
        srgb_to_linear(SUN_LOW_COLOR),
        srgb_to_linear(SUN_HIGH_COLOR),
        saturate(sun_direction.y * 3.0));

    float3 sky = sky_gradient(direction, palette);
    sky += sky_disc(direction, sun_direction, sun_tint, SUN_DISC_SHARPNESS, SUN_DISC_INTENSITY) * day;
    sky += sky_disc(direction, moon_direction, srgb_to_linear(MOON_COLOR), MOON_DISC_SHARPNESS, MOON_DISC_INTENSITY) * (1.0 - day);

    float ground_distance = ground_plane_hit(origin, direction, 0.0);
    if (ground_distance >= FAR_AWAY)
    {
        output.frag_color = float4(tonemap_aces(sky * EXPOSURE), 1.0);
        return output;
    }

    float3 position = origin + direction * ground_distance;
    float3 normal = float3(0.0, 1.0, 0.0);

    float3 albedo = grid_albedo(
        position,
        GRID_CELL_SIZE,
        srgb_to_linear(GROUND_BASE),
        srgb_to_linear(GROUND_LINE));

    float sun_lambert = max(dot(normal, sun_direction), 0.0) * day;
    float moon_lambert = max(dot(normal, moon_direction), 0.0) * (1.0 - day);

    float3 ambient = lerp(palette.horizon, palette.zenith, normal.y * 0.5 + 0.5) * AMBIENT_STRENGTH;
    float3 key = srgb_to_linear(SUN_LIGHT_COLOR) * SUN_LIGHT_STRENGTH * sun_lambert
        + srgb_to_linear(MOON_LIGHT_COLOR) * MOON_LIGHT_STRENGTH * moon_lambert;

    float3 lit = albedo * (ambient + key);
    lit = apply_fog(lit, sky, ground_distance, FOG_DENSITY);

    output.frag_color = float4(tonemap_aces(lit * EXPOSURE), 1.0);
    return output;
}
