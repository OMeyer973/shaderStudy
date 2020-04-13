Shader "custom/RaymarchDonutShader"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
	}
		SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0

			#include "UnityCG.cginc"

			// initialization of builtin uniforms
			uniform sampler2D _CameraDepthTexture;
			uniform float4x4 _CamFrustum, _CamToWorld;
			// render
			uniform float _maxDistance;
			uniform int _maxIterations;
			uniform float _accuracy;
			// raymarched scene geometry
			uniform float4 _sphere;
			uniform float3 _torusPos;
			uniform float2 _torusSize;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 ray : TEXCOORD1; // ray direction
			};

			// vertex shader
			///////////////////////////////////////////////////////
			v2f vert(appdata v)
			{
				v2f o;
				half index = v.vertex.z;
				v.vertex.z = 0;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;

				o.ray = _CamFrustum[(int)index].xyz;
				o.ray /= abs(o.ray.z); // normalize the ray
				o.ray = mul(_CamToWorld, o.ray);

				return o;
			}

			// fragment shader
			///////////////////////////////////////////////////////

			// SDFs
			// s: radius
			float sdSphere(float3 p, float s)
			{
				return length(p) - s;
			}

			// t.x: major radius, t.y: minor radius
			float sdTorus(float3 p, float2 t)
			{
				float2 q = float2(length(p.xz) - t.x, p.y);
				return length(q) - t.y;
			}
			
			// Union
			float opU(float d1, float d2)
			{
				return min(d1, d2);
			}

			// returns the distance of the point p to the raymached scene
			float distanceField(float3 p)
			{
				float sphere = sdSphere(p - _sphere.xyz, _sphere.w);
				float torus = sdTorus(p - _torusPos, _torusSize);
				//torus = sdTorus(p, float2(4,1));
				return opU(sphere, torus);
			}

			// returns the normal of the surface at the given surface point p
			// the normal of the sdf is the gradient of the sdf
			float3 getNormal(float3 p)
			{
				const float2 offset = float2(0.001, 0.0);
				float3 n = float3( // normal vector
					distanceField(p + offset.xyy) - distanceField(p - offset.xyy),
					distanceField(p + offset.yxy) - distanceField(p - offset.yxy),
					distanceField(p + offset.yyx) - distanceField(p - offset.yyx)
				);
				return normalize(n);
			}

			// returns the color of the raymarched scene
			// - marches along the ray emitted from the camera in the direction dicted by the frustum
			// param : ray origin, ray direction
			float4 rayMarching(float3 ro, float3 rd)
			{
				float4 result = float4(rd, 1);
				float t = 0; // traveled distance along the ray
				for (int i = 0; i < _maxIterations; i++)
				{
					if (t > _maxDistance)
					{
						// hit nothing : show background
						break;
					}

					float3 p = ro + rd * t; // current position along
					// check for hit in distance field
					float d = distanceField(p); // distance to the SDF
					if (d < _accuracy) // ray hit something !
					{
						// shading !
						float3 n = getNormal(p);
						result = float4(n,1);
						break;
					}
					t += d;
				}
				return result;

			}

			// main function
			float4 frag(v2f i) : SV_Target
			{
				float3 rayDirection = normalize(i.ray.xyz);
				float3 rayOrigin = _WorldSpaceCameraPos;
				return rayMarching(rayOrigin, rayDirection);
			}
			ENDCG
		}
	}
}
