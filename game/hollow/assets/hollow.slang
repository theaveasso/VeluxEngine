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
    uint *scene;
}

[vk_push_constant]
Push_Constants pc;

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
    float3 dir = normalize(far_p - near_p);

    float3 origin = pc.cam_pos.xyz / pc.cam_pos.w + float3(pc.dims.xyz) * 0.5;
    Voxel_World world = { pc.scene, pc.dims.xyz, 0 };
    Voxel_Hit hit = voxel_raycast(world, origin, dir, pc.dims.w);
    if (!hit.hit)
    {
        output.frag_color = float4(0.0, 0.0, 0.0, 1.0);
        return output;
    }

    output.frag_color = float4(srgb_to_linear(palette_color(world, hit.voxel)), 1.0);
    return output;
}
