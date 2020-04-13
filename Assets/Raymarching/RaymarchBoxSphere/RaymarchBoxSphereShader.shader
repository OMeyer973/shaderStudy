Shader "custom/RaymarchBoxSphereShader"
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
			#include "DistanceFunctions.cginc"

			// non raymarched scene
			sampler2D _MainTex;
			// initialization of builtin uniforms
			uniform sampler2D _CameraDepthTexture;
			uniform float4x4 _CamFrustum, _CamToWorld;
			// render
			uniform float _maxDistance;
			uniform int _maxIterations;
			uniform float _accuracy;
			// raymarched scene geometry
			uniform float4 _sphere;
			uniform float4 _box;
			uniform float _smoothFactor;
			uniform float _thickness;
			uniform float _groundHeight;
			// light
			uniform float3 _lightDirection, _lightColor;
			uniform float  _lightIntensity;
			// material
			uniform float4 _mainColor;
			// shadow
			uniform float2 _shadowDistance;
			uniform float _shadowIntensity;
			uniform float _shadowSharpness;
			uniform float _aOStepSize;
			uniform int _aOIterations;
			uniform float _aOIntensity;

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
			float sdBoxSphere(float3 p) {
				float box = sdBox(p - _box.xyz, _box.www);
				float sphereIn = sdSphere(p - _sphere.xyz, _sphere.w);
				float sphereOut = sdSphere(p - _sphere.xyz, _sphere.w * (1 + _thickness));
				float boxSphere = opSS(sphereIn, box, _smoothFactor);
				return opIS(boxSphere, sphereOut, _smoothFactor);
			}

			// returns the distance of the point p to the raymached scene
			float distanceField(float3 p)
			{
				float ground = sdPlane(p, float4(0, 1, 0, -_groundHeight));
				float boxSphere = sdBoxSphere(p);

				//return ground;
				return opU(boxSphere, ground);
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

			// calculates the hard shadow for a given point on the surface of the raymarched scene.
			// - here, ray origin is the point of the surface and ray direction is the direction of the light from this point
			// - basically if we can "see" the light from this point we return 1, else 0
			// param : ray origin, ray direction, min distance & max distance to shadow casters
			float hardShadow(float3 ro, float3 rd, float mint, float maxt)
			{
				for (float t = mint; t < maxt;)
				{
					float h = distanceField(ro + rd * t);
					if (h < _accuracy)
					{
						return 0;
					}
					t += h;
				}
				return 1;
			}
			// calculates the hard shadow for a given point on the surface of the raymarched scene.
			// - cf hard shadow
			// param : ray origin, normal, ray direction, min distance & max distance to shadow casters, softness
			float softShadow(float3 ro, float3 n, float3 rd, float mint, float maxt, float k)
			{
				float result = 1.0;
				for (float t = mint; t < maxt;)
				{
					float h = distanceField(ro + rd * t);
					if (h < _accuracy)
					{
						return 0;
					}
					result = min(result, k * h / t);
					t += h;
				}
				return result;
			}

			// ambient occlusion
			float ambientOcclusion(float3 p, float3 n)
			{
				float ao = 0;
				float dist = 0;
				for (int i = 1; i < _aOIterations; i++)
				{
					dist = _aOStepSize * i;
					ao += max(0.0, (dist - distanceField(p + n * dist)) / dist);
				}
				return 1 - ao * _aOIntensity;
			}

			float3 shading(float3 p, float3 n)
			{
				float3 color = _mainColor.rgb;
				// directional light
				//phong lighting
				float3 light = (_mainColor.rgb * _lightColor.xyz * dot(n, -_lightDirection) * .5 + .5) * _lightIntensity;
				// hard shadow
				float shadow = softShadow(p, n, -_lightDirection, _shadowDistance.x, _shadowDistance.y, _shadowSharpness) * .5 + .5;
				// ambient occlusion
				float ao = ambientOcclusion(p, n);
				ao = pow(ao, .5);
				return color * light * pow(shadow, _shadowIntensity) * ao;
			}


			// returns the color of the raymarched scene
			// - marches along the ray emitted from the camera in the direction dicted by the frustum
			// param : ray origin, ray direction, depth of the unity scene
			float4 rayMarching(float3 ro, float3 rd, float depth)
			{
				float4 result = float4(1, 1, 1, 1);
				float t = 0; // traveled distance along the ray
				for (int i = 0; i < _maxIterations; i++)
				{
					if (t > _maxDistance || t >= depth)
					{
						// hit nothing : show background
						result = float4(rd, 0);
						break;
					}

					float3 p = ro + rd * t; // current position along
					// check for hit in distance field
					float d = distanceField(p); // distance to the SDF
					if (d < _accuracy) // ray hit something !
					{
						// shading !
						float3 n = getNormal(p);
						float3 c = shading(p, n);
						result = float4(c, _mainColor.a);

						//result = float4(s,s,s, 1);
						break;
					}
					t += d;
				}
				return result;

			}

			// main function
			float4 frag(v2f i) : SV_Target
			{
				// conserving non-raymarched stuff
				float3 c = tex2D(_MainTex, i.uv); // color of the non raymarched scene
				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r); // depth from the depth buffer
				depth *= length(i.ray);

				// computing raymarched scene
				float3 rayDirection = normalize(i.ray.xyz);
				float3 rayOrigin = _WorldSpaceCameraPos;
				float4 result = rayMarching(rayOrigin, rayDirection, depth);

				// returns wichever is closer to the camera :
				// raymarched stuff or non ray-marched stuff
				return float4(c * (1 - result.w) + result.xyz * result.w, 1.0);
			}
			ENDCG
		}
	}
}
