struct V2P
{
    float4 pos : SV_Position;
    float3 color : COLOR0;
}

struct PS_Output
{
    [vk_location(0)]
    float4 frag_color : COLOR0;
}

struct Vertex
{
    float3 position;
    float3 color;
}

struct Mesh_Push_Constants
{
    float4x4 mvp;
    Vertex *vertices;
}

[vk_push_constant]
Mesh_Push_Constants pc;

[shader("vertex")]
V2P vertex_main(uint vertex_index: SV_VertexID)
{
    let vertex = pc.vertices[vertex_index];

    V2P output;
    output.pos = mul(pc.mvp, float4(vertex.position, 1.0));
    output.color = vertex.color;
    return output;
}

[shader("fragment")]
PS_Output fragment_main(V2P input)
{
    PS_Output output;
    output.frag_color = float4(input.color, 1.0);
    return output;
}
