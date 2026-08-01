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

    float3 origin = pc.cam_pos.xyz / pc.cam_pos.w + pc.world_offset.xyz;
    Voxel_World world = { pc.scene, pc.dims.xyz, 0 };
    Voxel_Hit hit = voxel_raycast(world, origin, dir, pc.dims.w);
    if (!hit.hit)
    {
        output.frag_color = float4(0.0, 0.0, 0.0, 1.0);
        return output;
    }

    float ao = voxel_face_ao(world, hit.cell, hit.normal, hit.position);
    float3 albedo = srgb_to_linear(palette_color(world, hit.voxel));

    const float FOG_DENSITY = 0.8;
    float distance_metres = hit.distance * pc.cam_pos.w;
    float falloff = 1.0 / (1.0 + distance_metres * distance_metres * FOG_DENSITY);

    output.frag_color = float4(albedo * lerp(0.35, 1.0, ao) * falloff, 1.0);
    return output;
}
