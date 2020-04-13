// Sphere
// s: radius
float sdSphere(float3 p, float s)
{
	return length(p) - s;
}

// Box
// b: size of box in x/y/z
float sdBox(float3 p, float3 b)
{
    float3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) +
		length(max(d, 0.0));
}

// infinite plane
// n.xyz : normap of plane
// ,.w * offset of the plane
float sdPlane(float3 p, float4 n)
{
    return dot(p, n.xyz) + n.w;
}

// BOOLEAN OPERATORS //
// Union
float opU(float d1, float d2)
{
	return min(d1, d2);
}

// Subtraction
float opS(float d1, float d2)
{
	return max(-d1, d2);
}

// Intersection
float opI(float d1, float d2)
{
	return max(d1, d2);
}

// Mod Position Axis
// returns the id of the "instance"
// actual mod is a side effect on the p parameter
float pMod1 (inout float p, float size)
{
	float halfsize = size * 0.5;
	float c = floor((p+halfsize)/size);
	p = fmod(p+halfsize,size)-halfsize;
	p = fmod(-p+halfsize,size)-halfsize;
	return c;
}

// SMOOTH BOOLEAN OPERATORS
// smooth union
float4 opUS(float4 d1, float4 d2, float k)
{
    float h = clamp(0.5 + 0.5 * (d2.w - d1.w) / k, 0.0, 1.0);
    float3 color = lerp(d2.rgb, d1.rgb, h);
    float dist = lerp(d2.w, d1.w, h) - k * h * (1.0 - h);
    return float4(color, dist);
}

// smooth substraction
float opSS(float d1, float d2, float k)
{
    float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0);
    return lerp(d2, -d1, h) + k * h * (1.0 - h);
}

// smooth intersection
float opIS(float d1, float d2, float k)
{
    float h = clamp(0.5 - 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return lerp(d2, d1, h) + k * h * (1.0 - h);
}