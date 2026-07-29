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
    public float3 position;
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

float corner_ao(float side_a, float side_b, float corner)
{
    if (side_a > 0.5 && side_b > 0.5)
    {
        return 0.0;
    }
    return 3.0 - (side_a + side_b + corner);
}

public float voxel_face_ao(Voxel_World world, int3 cell, float3 normal, float3 hit_point)
{
    int3 normal_cell = int3(normal);
    int3 front = cell + normal_cell;

    int3 tangent_a, tangent_b;
    if (normal_cell.x != 0)
    {
        tangent_a = int3(0, 1, 0);
        tangent_b = int3(0, 0, 1);
    }
    else if (normal_cell.y != 0)
    {
        tangent_a = int3(1, 0, 0);
        tangent_b = int3(0, 0, 1);
    }
    else
    {
        tangent_a = int3(1, 0, 0);
        tangent_b = int3(0, 1, 0);
    }

    float corner_00 = corner_ao(
        voxel_solid(world, front - tangent_a),
        voxel_solid(world, front - tangent_b),
        voxel_solid(world, front - tangent_a - tangent_b));
    float corner_10 = corner_ao(
        voxel_solid(world, front + tangent_a),
        voxel_solid(world, front - tangent_b),
        voxel_solid(world, front + tangent_a - tangent_b));
    float corner_01 = corner_ao(
        voxel_solid(world, front - tangent_a),
        voxel_solid(world, front + tangent_b),
        voxel_solid(world, front - tangent_a + tangent_b));
    float corner_11 = corner_ao(
        voxel_solid(world, front + tangent_a),
        voxel_solid(world, front + tangent_b),
        voxel_solid(world, front + tangent_a + tangent_b));

    float3 fractional = frac(hit_point);
    float along_a = dot(fractional, float3(abs(tangent_a)));
    float along_b = dot(fractional, float3(abs(tangent_b)));

    float occlusion = lerp(lerp(corner_00, corner_10, along_a), lerp(corner_01, corner_11, along_a), along_b);
    return occlusion / 3.0;
}

public Voxel_Hit voxel_raycast(Voxel_World world, float3 origin, float3 direction, int max_steps)
{
    Voxel_Hit result;
    result.hit = false;
    result.cell = int3(0);
    result.normal = float3(0.0);
    result.position = origin;
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
            result.position = origin + direction * travelled;

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
