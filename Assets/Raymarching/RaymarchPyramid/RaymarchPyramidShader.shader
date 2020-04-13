Shader "custom/RaymarchShader"
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
			uniform sampler2D _CameraDepthTexture;
			// render
			uniform float4x4 _CamFrustum, _CamToWorld;
			uniform float _maxDistance;
			uniform int _maxIterations = 512;
			uniform float _accuracy = 0.01;
			// raymarched scene geometry
			uniform float4 _sphere;
			uniform float _smoothFactor;
			uniform float _angularOffset;
			uniform float _groundHeight;
			// light
			uniform float3 _lightDirection, _lightColor;
			uniform float  _lightIntensity;
			// material
			uniform float3 _groundColor;
			uniform float3 _sphereColors[8];
			uniform float _colorIntensity;
			//shadow
			uniform float2 _shadowDistance;
			uniform float _shadowIntensity;
			uniform float _shadowSharpness;
			uniform float _aOStepSize;
			uniform int _aOIterations;
			uniform float _aOIntensity;
			// reflections
			uniform int _reflexionCount;
			uniform float _reflexionIntensity;
			uniform float _envReflIntensity;
			uniform samplerCUBE _reflexionCube;



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



			// Rotation with angle (in radians) and axis (x, y or z only)
			// from https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
			float3x3 AngleAxis3x3(float angle, float3 axis)
			{
				float c, s;
				sincos(angle, s, c);

				float t = 1 - c;
				float x = axis.x;
				float y = axis.y;
				float z = axis.z;

				return float3x3(
					t * x * x + c, t * x * y - s * z, t * x * z + s * y,
					t * x * y + s * z, t * y * y + c, t * y * z - s * x,
					t * x * z - s * y, t * y * z + s * x, t * z * z + c
					);
			}
			
			// rotates the vertex v around the Y axis by rad radiants
			float3 rotateY(float3 v, float rad) {
				float cosY = cos(rad);
				float sinY = sin(rad);
				float3x3 rotMat = float3x3 (cosY, 0, sinY, 0, 0, 0, -sinY, 0, cosY);
				return mul(v, AngleAxis3x3(rad, float3(0, 1, 0)));
			}

			// finite number of repetitions
			// c : number of rep, l : translate of each rep
			float3 opRepLim(in float3 p, in float c, in float3 l)
			{
				return p - c * clamp(round(p / c), -l, l);
			}

			float3 mod(float3 x, float3 y) {
				return x - y * floor(x / y);
			}

			float opRep(in float3 p, in float3 c)
			{
				return mod(p + 0.5 * c, c) - 0.5 * c;
			}

			// returns the color and distance of the point p to the raymached scene
			// xyz = color, w = distance
			float4 distanceField(float3 p)
			{
				float4 ground = float4(_groundColor, sdPlane(p, float4(0, 1, 0, -_groundHeight)));
				p = mul(p, AngleAxis3x3(1.570796326794897, float3(1, 0, 0)));
				p /= 2;
				//p *= abs(p.z);
				//p = opRep(p, float3(0, 0, 0));
				p.z *= 5;
				float id = round(p.z / 5);
				p = opRepLim(p, 3, float3(2, 2, 5));
				p = mul(p, AngleAxis3x3(id * 3.14159 *.2, float3(0, 0, 1)));
				//p.xy *= pow(abs(id)+1, .5)*.5;
				p.xy *= pow(abs(id)+1,1);
				float4 prisms = float4(_sphereColors[0], sdTriPrism(p- _sphere.xyz, float2(_sphere.w, _sphere.w)));
				/*
				for (int i = 1; i < 8; i++)
				{
					float4 newPrism = float4(_sphereColors[i], sdTriPrism(rotateY(pRepeated, _angularOffset * i) - _sphere.xyz, float2(_sphere.w, _sphere.w)));

					prisms = opUS(newPrism, prisms, _smoothFactor);
				}*/

				return opUS(ground, prisms, _smoothFactor);
			}

			// returns the normal of the surface at the given surface point p
			// the normal of the sdf is the gradient of the sdf
			float3 getNormal(float3 p)
			{
				const float2 offset = float2(0.001, 0.0);
				float3 n = float3( // normal vector
					distanceField(p + offset.xyy).w - distanceField(p - offset.xyy).w,
					distanceField(p + offset.yxy).w - distanceField(p - offset.yxy).w,
					distanceField(p + offset.yyx).w - distanceField(p - offset.yyx).w
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
					float h = distanceField(ro + rd * t).w;
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
					float h = distanceField(ro + rd * t).w;
					if (h < _accuracy)
					{
						return 0;
					}
					result = min(result, k * h / t);
					t += h;
				}
				// smoothen self shadow
				float sss = clamp(dot(n, -_lightDirection), 0, 1);
				result = min(result, sss);

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
					ao += max(0.0, (dist - distanceField(p + n * dist).w) / dist);
				}
				return 1 - ao * _aOIntensity;
			}

			// param : point to shade, surface normal, color of the given point
			float3 shading(float3 p, float3 n, fixed3 c)
			{
				float3 color = c.rgb * _colorIntensity;
				// directional light
				//phong lighting
				float3 light = (c.rgb * _lightColor.xyz * dot(n, -_lightDirection) * .5 + .5) * _lightIntensity;
				// hard shadow
				float shadow = softShadow(p, n, -_lightDirection, _shadowDistance.x, _shadowDistance.y, _shadowSharpness) * .5 + .5;
				shadow = max(0.0, pow(shadow, _shadowIntensity));
				// ambient occlusion
				float ao = ambientOcclusion(p, n);
				ao = pow(ao, .5);
				
				// smoothen self shadow

				return color * light * shadow * ao;
			}


			// returns true when the ray hit something 
			// also register the hit point position in the inout parameter p
			// also register the hit point color in the inout parameter c
			// - marches along the ray emitted from the camera in the direction dicted by the frustum
			// param : ray origin, ray direction, 
			// depth of the non raymarched unity scene, 
			// max render distance, max marching steps,
			// point where the ray has hit
			bool rayMarching(float3 ro, float3 rd, float depth, float maxDist, int maxIter, inout float3 p, inout fixed3 c)
			{
				bool hit;
				float t = 0; // traveled distance along the ray
				for (int i = 0; i < maxIter; i++)
				{
					if (t > maxDist || t >= depth)
					{
						// hit nothing : show background
						hit = false;
						break;
					}

					p = ro + rd * t; // current position along
					// check for hit in distance field
					float4 d = distanceField(p); // distance to the SDF
					if (d.w < _accuracy) // ray hit something !
					{
						c = d.rgb;
						hit = true;
						break;
					}
					t += d.w * .5;
				}
				return hit;

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
				fixed4 result;
				float3 hitPosition = 0;
				fixed3 hitColor = fixed3(0, 0, 0);

				bool hit = rayMarching(rayOrigin, rayDirection, depth, _maxDistance, _maxIterations, hitPosition, hitColor);
				if (hit)
				{
					result = fixed4(0, 0, 0, 1);
					// shading !
					float3 n = getNormal(hitPosition);
					float3 s = shading(hitPosition, n, hitColor);
					result = fixed4(s, 1);

					uint mipLevel = 2;
					float invMipLevel = .5f;
					bool reflectEnv = false;

					for (int i = 0; i < _reflexionCount; i++) { // reflections
					
						// reflected ray
						rayDirection = normalize(reflect(rayDirection, n));
						rayOrigin = hitPosition + rayDirection * .01;
						hit = rayMarching(rayOrigin, n, _maxDistance * invMipLevel, _maxDistance * invMipLevel, _maxIterations / mipLevel, hitPosition, hitColor);
						
						if (hit) // reflected ray hit
						{
							// shading !
							n = getNormal(hitPosition);
							s = shading(hitPosition, n, hitColor);
							result += fixed4(s * _reflexionIntensity, 0) * invMipLevel;
						}
						else { // reflected ray missed
							break; // time to draw the env reflexion
						}
						mipLevel *= 2;
						invMipLevel *= .5;
					}
					// draw the env reflexion even if the last reflexion cast was a hit
					// so everybody gets a free fake reflexion level yay !
					// this reflexion is physically false if the last reflected ray hit a surface 
					// but it can also prevent some artifacts so we might aswell take it
					if (_reflexionCount>0)
					{
						// env reflexion
						result += fixed4(texCUBE(_reflexionCube, rayDirection).rgb * _envReflIntensity, 0);
					}
				}
				else // miss 
				{
					result = fixed4(0,0,0,0);
				}
				
				// returns wichever is closer to the camera :
				// raymarched stuff or non ray-marched stuff
				return float4(c * (1 - result.w) + result.xyz * result.w, 1.0);
			}




			ENDCG
		}
	}
}
