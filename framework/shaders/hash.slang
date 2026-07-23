public uint pcg_hash(uint value)
{
    uint state = value * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

public float2 hash_cell(int3 cell)
{
    uint mixed = pcg_hash(uint(cell.x) * 73856093u ^ uint(cell.y) * 19349663u ^ uint(cell.z) * 83492791u);
    uint mixed_again = pcg_hash(mixed);
    return float2(float(mixed), float(mixed_again)) / 4294967296.0;
}
