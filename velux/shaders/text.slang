struct Glyph {
    float4 rect;
    float4 uv;
    uint   color;
    uint   pad;
}

struct Push_Constants
{
    float2 scale;
    float2 bias;
    Glyph* instances;
    uint   atlas;
    uint   pad;
}

[vk_push_constant]
Push_Constants pc;

[[vk::binding(0, 0)]]
Sampler2D atlas_textures[];

struct V2P
{
    float4 position : SV_Position;
    float2 uv       : TEXCOORD0;
    float4 color    : COLOR0;
}

struct PS_Output
{
    [vk_location(0)]
    float4 frag_color : COLOR0;
}

[shader("vertex")]
V2P vertex_main(uint id : SV_VertexID)
{
    Glyph g = pc.instances[id / 6];
    uint c = id % 6;

    float2 t = float2(
        (c == 1 || c == 2 || c == 4) ? 1.0 : 0.0,
        (c == 2 || c == 4 || c == 5) ? 1.0 : 0.0);

    float2 p = lerp(g.rect.xy, g.rect.zw, t);

    V2P output;
    output.position = float4(p * pc.scale + pc.bias, 0.0, 1.0);
    output.uv = lerp(g.uv.xy, g.uv.zw, t);
    output.color = float4(
        float((g.color >>  0) & 0xFF),
        float((g.color >>  8) & 0xFF),
        float((g.color >> 16) & 0xFF),
        float((g.color >> 24) & 0xFF)) / 255.0;
    return output;
}

[shader("fragment")]
PS_Output fragment_main(V2P input)
{
    float a = atlas_textures[pc.atlas].Sample(input.uv).r * input.color.a;
    PS_Output output;
    output.frag_color = float4(input.color.rgb * a, a);
    return output;
}
