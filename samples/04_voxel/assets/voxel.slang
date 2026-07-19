struct V2P
{
    float4 pos : SV_Position;
    float3 normal : NORMAL0;
    float3 color : COLOR0;
    float ao : TEXCOORD1;
}

struct PS_Output
{
    [vk_location(0)]
    float4 frag_color : COLOR0;
}

struct Voxel_Vertex
{
    uint data0;
    uint data1;
}

struct Push_Constants
{
    float4x4 mvp;
    Voxel_Vertex *vertices;
}

[vk_push_constant]
Push_Constants pc;

static const float3 NORMALS[6] = {
    float3(+1, 0, 0),
    float3(-1, 0, 0),
    float3(0, +1, 0),
    float3(0, -1, 0),
    float3(0, 0, +1),
    float3(0, 0, -1),
};

static const float AO_LEVELS[4] = { 0.35, 0.55, 0.80, 1.00 };

static const float3 BLOCK_PALLETTE[6] = {
    float3(0.00, 0.00, 0.00),
    float3(0.45, 0.62, 0.28),
    float3(0.48, 0.35, 0.24),
    float3(0.42, 0.30, 0.19),
    float3(0.30, 0.48, 0.22),
    float3(0.55, 0.55, 0.58),
};

static const float3 sky_warm = float3(0.45, 0.55, 0.78);
static const float3 ground_warm = float3(0.40, 0.55, 0.78);
static const float3 sun_color = float3(1.00, 0.78, 0.45);

[shader("vertex")]
V2P vertex_main(uint vertex_index: SV_VertexID)
{
    Voxel_Vertex v = pc.vertices[vertex_index];
    float x = float(v.data0 & 0xFFu);
    float y = float((v.data0 >> 8) & 0xFFu);
    float z = float((v.data0 >> 16) & 0xFFu);
    uint normal = uint(v.data0 >> 24) & 0x7u;
    uint ao = uint(v.data0 >> 27) & 0x3u;
    uint block = v.data1 & 0xFFFF;

    V2P output;
    output.pos = mul(pc.mvp, float4(x, y, z, 1.0));
    output.normal = NORMALS[normal];
    output.color = BLOCK_PALLETTE[block];
    output.ao = AO_LEVELS[ao];
    return output;
}

[shader("fragment")]
PS_Output fragment_main(V2P input)
{
    float3 L = normalize(float3(0.50, 0.55, 0.35));
    float3 N = normalize(input.normal);

    float3 ambient = lerp(ground_warm, sky_warm, N.y * 0.5 + 0.5);
    float3 sun = sun_color * max(dot(N, L), 0) * 0.85;
    float3 light = ambient + sun;
    float3 color = input.color * light * input.ao;

    PS_Output output;
    output.frag_color = float4(color, 1.0);
    return output;
}
