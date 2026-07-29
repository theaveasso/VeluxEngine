public struct Voxel_World
{
    public uint *scene;
    public int3 dims;
    public uint out_of_bounds;
}

public struct Voxel_Hit
{
    public bool hit;
    public int3 cell;
    public float3 normal;
    public float distance;
    public uint voxel;
}

public static const int PALETTE_SLOTS = 256;

public float3 palette_color(Voxel_World world, uint index)
{
    int packed = world.scene[index];
    return float3(packed & 0xFF, (packed >> 8) & 0xFF, (packed >> 16) & 0xFF) / 255.0;
}

public uint voxel_at(Voxel_World world, int3 cell)
{
    if (any(cell < 0) || any(cell >= world.dims))
    {
        return world.out_of_bounds;
    }
    return world.scene[PALETTE_SLOTS + cell.x + cell.y * world.dims.x + cell.z * world.dims.x * world.dims.y];
}

public float voxel_solid(Voxel_World world, int3 cell)
{
    return voxel_at(world, cell) != 0 ? 1.0 : 0.0;
}

public Voxel_Hit voxel_raycast(Voxel_World world, float3 origin, float3 direction, int max_steps)
{
    Voxel_Hit result;
    result.hit = false;
    result.cell = int3(0);
    result.normal = float3(0.0);
    result.distance = 0.0;
    result.voxel = 0;

    int3 cell = int3(floor(origin));
    int3 step = int3(sign(direction));
    float3 t_delta = abs(1.0 / direction);
    float3 t_max = (float3(cell) + max(float3(step), 0.0) - origin) / direction;

    int last_axis = -1;
    float travelled = 0.0;

    for (int i = 0; i < max_steps; i++)
    {
        uint voxel = voxel_at(world, cell);
        if (voxel != 0)
        {
            result.hit = true;
            result.cell = cell;
            result.voxel = voxel;
            result.distance = travelled;

            if (last_axis == 0)
            {
                result.normal.x = float(-step.x);
            }
            else if (last_axis == 1)
            {
                result.normal.y = float(-step.y);
            }
            else if (last_axis == 2)
            {
                result.normal.z = float(-step.z);
            }
            return result;
        }

        if (t_max.x < t_max.y && t_max.x < t_max.z)
        {
            travelled = t_max.x;
            cell.x += step.x;
            t_max.x += t_delta.x;
            last_axis = 0;
        }
        else if (t_max.y < t_max.z)
        {
            travelled = t_max.y;
            cell.y += step.y;
            t_max.y += t_delta.y;
            last_axis = 1;
        }
        else
        {
            travelled = t_max.z;
            cell.z += step.z;
            t_max.z += t_delta.z;
            last_axis = 2;
        }
    }
    return result;
}
